"""FastAPI application for the StrongSense coach service.

Endpoints:

* ``GET /health`` — service status, configured providers (never keys).
* ``POST /v1/coach/plan`` — validated, clamped LLM coach plan.

The app is stateless: nothing is persisted. Cross cutting concerns are all
middlewares so they apply to every route (and to each other's error responses):
body-size guard, per-client rate limit, CORS, then request-id logging.
"""

from __future__ import annotations

import hashlib
import json
import math
import time
from contextlib import suppress
from typing import Any

from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint

from app.auth import extract_bearer_token, require_auth
from app.cache import build_cache, cache_key_for
from app.coach import CoachError, generate_plan
from app.config import Settings, get_settings
from app.logging import (
    REQUEST_ID_HEADER,
    configure_logging,
    log_request_completed,
    log_server_error,
    log_startup,
    resolve_request_id,
)
from app.ratelimit import RateLimiter
from app.schemas import (
    CONTRACT_VERSION,
    SERVICE_VERSION,
    CoachRequest,
    CoachResponse,
    Health,
    ProviderInfo,
    validation_issues,
)

MAX_BODY_BYTES = 256 * 1024
PLAN_PATH = "/v1/coach/plan"
PAYLOAD_TOO_LARGE_MESSAGE = "Request body exceeds the 256 KB limit."
RATE_LIMITED_MESSAGE = "Too many requests. Retry shortly."

# Map status codes onto the contract error codes for plain HTTPExceptions.
_STATUS_CODE_MAP: dict[int, str] = {
    400: "invalid_request",
    401: "unauthorized",
    403: "forbidden",
    404: "not_found",
    405: "method_not_allowed",
    409: "conflict",
    413: "payload_too_large",
    415: "unsupported_media_type",
    422: "invalid_request",
    429: "rate_limited",
    500: "internal_error",
    503: "llm_unavailable",
}


async def _send_json(
    send: Any,
    status: int,
    payload: dict[str, Any],
    headers: dict[str, str] | None = None,
) -> None:
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    raw_headers = [
        (b"content-type", b"application/json; charset=utf-8"),
        (b"content-length", str(len(body)).encode("ascii")),
    ]
    if headers:
        raw_headers.extend(
            (key.lower().encode("latin-1"), value.encode("latin-1"))
            for key, value in headers.items()
        )
    await send({"type": "http.response.start", "status": status, "headers": raw_headers})
    await send({"type": "http.response.body", "body": body})


def _error_payload(code: str, message: str) -> dict[str, Any]:
    return {"detail": {"code": code, "message": message}}


def _header_from_scope(scope: dict[str, Any], name: bytes) -> str | None:
    for key, value in scope.get("headers", []):
        if key.lower() == name:
            return value.decode("latin-1")
    return None


class _PayloadTooLarge(Exception):
    """Raised while streaming a body that exceeds the size cap."""


class BodySizeLimitMiddleware:
    """Reject request bodies larger than ``max_bytes`` with a 413 JSON error."""

    def __init__(self, app: Any, max_bytes: int = MAX_BODY_BYTES) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        declared = _header_from_scope(scope, b"content-length")
        if declared is not None:
            try:
                declared_bytes = int(declared)
            except ValueError:
                declared_bytes = 0
            if declared_bytes > self.max_bytes:
                await _send_json(
                    send,
                    413,
                    _error_payload("payload_too_large", PAYLOAD_TOO_LARGE_MESSAGE),
                )
                return

        received = 0
        response_started = False

        async def limited_receive() -> Any:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    raise _PayloadTooLarge
            return message

        async def tracking_send(message: dict[str, Any]) -> None:
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracking_send)
        except _PayloadTooLarge:
            if not response_started:
                await _send_json(
                    send,
                    413,
                    _error_payload("payload_too_large", PAYLOAD_TOO_LARGE_MESSAGE),
                )


class RateLimitMiddleware:
    """Apply the per-client token bucket to the plan endpoint only."""

    def __init__(self, app: Any, limiter: RateLimiter, path: str = PLAN_PATH) -> None:
        self.app = app
        self.limiter = limiter
        self.path = path

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] != "http" or scope.get("path") != self.path:
            await self.app(scope, receive, send)
            return
        key = _client_rate_limit_key(scope)
        allowed, retry_after = self.limiter.allow(key)
        if allowed:
            await self.app(scope, receive, send)
            return
        retry_after_seconds = max(1, math.ceil(retry_after))
        await _send_json(
            send,
            429,
            _error_payload("rate_limited", RATE_LIMITED_MESSAGE),
            headers={"retry-after": str(retry_after_seconds)},
        )


def _client_rate_limit_key(scope: dict[str, Any]) -> str:
    client = scope.get("client")
    host = str(client[0]) if client else "unknown"
    authorization = _header_from_scope(scope, b"authorization")
    token = extract_bearer_token(authorization)
    if not token:
        return host
    digest = hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
    return f"{host}|{digest}"


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Assign ``X-Request-ID`` and emit one structured log line per request.

    This middleware is the outermost layer, so it also converts unexpected
    exceptions into the contract's 500 error envelope while keeping the request id
    on the response. (Exception handlers registered for ``Exception`` in Starlette
    run in ``ServerErrorMiddleware`` *outside* user middleware, which is why the
    conversion happens here.)
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        request_id = resolve_request_id(request.headers.get(REQUEST_ID_HEADER))
        request.state.request_id = request_id
        started = time.perf_counter()
        try:
            response = await call_next(request)
            status = response.status_code
            body: dict[str, Any] | None = None
        except Exception as exc:  # noqa: BLE001 - last line of defence
            log_server_error(
                request_id=request_id,
                method=request.method,
                path=request.url.path,
                exc_type=type(exc).__name__,
            )
            status = 500
            body = _error_payload("internal_error", "Internal server error.")
            response = JSONResponse(status_code=status, content=body)
        else:
            status = response.status_code
        latency_ms = int((time.perf_counter() - started) * 1000)
        response.headers[REQUEST_ID_HEADER] = request_id
        llm_event = getattr(request.state, "llm_event", None)
        log_request_completed(
            request_id=request_id,
            method=request.method,
            path=request.url.path,
            status=status,
            latency_ms=latency_ms,
            extra=llm_event if isinstance(llm_event, dict) else None,
        )
        return response


# ---------------------------------------------------------------------------
# Exception handlers: every error uses {"detail": {"code", "message"}}
# ---------------------------------------------------------------------------


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    issues = validation_issues(exc)
    details = "; ".join(
        f"{issue['loc']}: {issue['msg']}".strip(": ") for issue in issues[:5]
    )
    message = f"Invalid request payload. {details}".strip()
    return JSONResponse(status_code=400, content=_error_payload("invalid_request", message))


async def http_exception_handler(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
    detail = exc.detail
    headers = getattr(exc, "headers", None)
    if isinstance(detail, dict) and "code" in detail and "message" in detail:
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_payload(str(detail["code"]), str(detail["message"])),
            headers=headers,
        )
    code = _STATUS_CODE_MAP.get(exc.status_code, "error")
    message = detail if isinstance(detail, str) and detail else code.replace("_", " ").capitalize()
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(code, message),
        headers=headers,
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Last-resort 500 handler (normally handled by ``RequestLoggingMiddleware``)."""
    request_id = getattr(request.state, "request_id", "")
    log_server_error(
        request_id=str(request_id),
        method=request.method,
        path=request.url.path,
        exc_type=type(exc).__name__,
    )
    return JSONResponse(
        status_code=500,
        content=_error_payload("internal_error", "Internal server error."),
    )

router = APIRouter()


@router.get("/health", response_model=Health, tags=["system"], summary="Service health")
async def health(request: Request) -> Health:
    """Report service status and the configured provider/model pairs (never keys)."""
    settings: Settings = request.app.state.settings
    return Health(
        llmConfigured=settings.llm_configured,
        providers=[ProviderInfo(**provider) for provider in settings.providers()],
    )


@router.post(
    "/v1/coach/plan",
    response_model=CoachResponse,
    tags=["coach"],
    summary="Generate a validated coach plan",
    dependencies=[Depends(require_auth)],
)
async def coach_plan(payload: CoachRequest, request: Request) -> CoachResponse:
    """Validate the request, ask the LLM, clamp the plan and return it."""
    settings: Settings = request.app.state.settings
    if payload.contractVersion != CONTRACT_VERSION:
        raise HTTPException(
            status_code=409,
            detail={
                "code": "contract_version_unsupported",
                "message": f"Only contractVersion {CONTRACT_VERSION} is supported.",
            },
        )
    diagnostics: dict[str, Any] = {}
    request.state.llm_event = diagnostics
    cache = getattr(request.app.state, "cache", None)
    cache_key = cache_key_for(payload.model_dump(mode="json"))
    if cache is not None:
        cached = await cache.get(cache_key)
        if cached is not None:
            try:
                return CoachResponse.model_validate(cached)
            except Exception:
                pass
    try:
        response = await generate_plan(payload, settings, diagnostics)
    except CoachError as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail={"code": exc.code, "message": exc.message},
        ) from exc
    if cache is not None:
        with suppress(Exception):
            await cache.set(cache_key, response.model_dump(mode="json"))
    return response


# ---------------------------------------------------------------------------
# App factory
# ---------------------------------------------------------------------------


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build the FastAPI application (also used by tests)."""
    settings = settings or get_settings()
    configure_logging("INFO")
    app = FastAPI(
        title="StrongSense Coach API",
        version=SERVICE_VERSION,
        description=(
            "Stateless AI coaching service for the StrongSense AI app. "
            "The app owns the deterministic training rules; this service validates the "
            "request, asks an LLM for adjustments, clamps them to the contract bounds "
            "and returns a normalized plan."
        ),
        docs_url="/docs",
        redoc_url=None,
        openapi_url="/openapi.json",
    )
    app.state.settings = settings
    app.state.limiter = RateLimiter(settings.max_requests_per_min)
    app.state.cache = build_cache(settings)

    # Middlewares are added inside-out: the last one added is the outermost.
    app.add_middleware(BodySizeLimitMiddleware, max_bytes=MAX_BODY_BYTES)
    app.add_middleware(RateLimitMiddleware, limiter=app.state.limiter, path=PLAN_PATH)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origin_list,
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
        expose_headers=[REQUEST_ID_HEADER],
        max_age=600,
    )
    app.add_middleware(RequestLoggingMiddleware)

    app.add_exception_handler(
        RequestValidationError,
        validation_exception_handler,  # type: ignore[arg-type]
    )
    app.add_exception_handler(
        StarletteHTTPException,
        http_exception_handler,  # type: ignore[arg-type]
    )
    app.add_exception_handler(Exception, unhandled_exception_handler)

    app.include_router(router)

    if settings.app_env.lower() not in {"test", "testing"}:
        log_startup(settings.log_summary())
    return app


app = create_app()


def main() -> None:
    """Run the service with uvicorn (``python -m app.main``)."""
    import uvicorn

    settings = get_settings()
    uvicorn.run(
        "app.main:app",
        host=settings.coach_host,
        port=settings.coach_port,
        log_level="info",
    )


if __name__ == "__main__":
    main()
