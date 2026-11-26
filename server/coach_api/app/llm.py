"""LLM provider abstraction for the coach service.

Two wire protocols are supported:

* ``openai_compatible`` — any ``{base}/chat/completions`` endpoint (OpenAI, DeepSeek,
  Groq, OpenRouter, Together, Gemini-compatible gateways, Ollama, ...).
* ``anthropic`` — the native ``{base}/v1/messages`` endpoint.

Both share the same behaviour:

* request one JSON plan with a bounded timeout and temperature,
* retry once with a small backoff on HTTP 429/5xx/timeouts,
* strip markdown fences and parse/validate the JSON,
* make exactly one "repair" call when the model answered with invalid JSON or a JSON
  object that does not match the plan schema,
* raise typed ``LlmError`` subclasses instead of leaking provider payloads.
"""

from __future__ import annotations

import asyncio
import json
import re
import time
from dataclasses import dataclass
from typing import Any

import httpx
from pydantic import SecretStr, ValidationError

from app.config import PROVIDER_ANTHROPIC, Settings
from app.prompt import build_messages
from app.schemas import CoachRequest, ModelPlan

RETRY_BACKOFF_SECONDS = 0.25
MAX_ATTEMPTS = 2
MIN_BUDGET_SECONDS = 0.5
ANTHROPIC_VERSION = "2023-06-01"
#: Provider error messages are only used for diagnostics; keep them short and single-line.
MAX_REASON_CHARS = 240
#: Fragments that mean the 429 is a quota exhaustion rather than a short burst.
TERMINAL_QUOTA_MARKERS = ("per day", "daily limit", "quota exceeded")

_JSON_SCHEMA_RESPONSE_FORMAT: dict[str, Any] = {
    "type": "json_schema",
    "json_schema": {
        "name": "coach_plan",
        "strict": False,
        "schema": {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "readinessExplanation": {"type": "string"},
                "rpeCap": {"type": "number"},
                "deload": {"type": "boolean"},
                "adjustments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "exerciseId": {"type": "string"},
                            "exercise": {"type": "string"},
                            "loadDeltaPct": {"type": "number"},
                            "setsDelta": {"type": "integer"},
                            "repsHint": {"type": ["string", "null"]},
                            "reason": {"type": "string"},
                            "substituteWith": {"type": ["string", "null"]},
                        },
                        "required": ["exerciseId", "loadDeltaPct", "setsDelta"],
                    },
                },
                "tips": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "title": {"type": "string"},
                            "body": {"type": "string"},
                            "category": {
                                "type": "string",
                                "enum": ["technique", "recovery", "nutrition", "programming"],
                            },
                        },
                        "required": ["title", "body", "category"],
                    },
                },
                "flags": {"type": "array", "items": {"type": "string"}},
            },
            "required": [
                "summary",
                "readinessExplanation",
                "rpeCap",
                "deload",
                "adjustments",
                "tips",
                "flags",
            ],
        },
    },
}


# ---------------------------------------------------------------------------
# Typed errors
# ---------------------------------------------------------------------------


class LlmError(Exception):
    """Base class for every LLM related failure."""

    code = "llm_error"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class LlmNotConfiguredError(LlmError):
    """No usable provider profile is configured."""

    code = "llm_not_configured"


class LlmProviderError(LlmError):
    """One provider attempt failed (HTTP error, timeout, invalid JSON, ...)."""

    code = "llm_unavailable"

    def __init__(self, provider: str, reason: str) -> None:
        super().__init__(f"{provider}: {reason}")
        self.provider = provider
        self.reason = reason


class LlmUnavailableError(LlmError):
    """Every configured provider failed."""

    code = "llm_unavailable"

    def __init__(self, errors: list[LlmProviderError], attempted: list[ProviderProfile]) -> None:
        super().__init__("All configured AI providers failed.")
        self.errors = errors
        self.attempted = attempted

    @property
    def last_provider(self) -> str:
        return self.attempted[-1].name if self.attempted else ""

    @property
    def last_model(self) -> str:
        return self.attempted[-1].model if self.attempted else ""


# ---------------------------------------------------------------------------
# Raw response parsing
# ---------------------------------------------------------------------------


class PlanParseError(Exception):
    """The model's answer was not parseable JSON."""


class PlanSchemaError(Exception):
    """The model's answer was JSON but not a valid plan object."""


_FENCE_START_RE = re.compile(r"^```[A-Za-z0-9_-]*\s*")
_FENCE_END_RE = re.compile(r"\s*```$")


def extract_json_payload(text: str) -> dict[str, Any]:
    """Strip markdown fences and return the JSON object inside ``text``."""
    if not isinstance(text, str) or not text.strip():
        raise PlanParseError("model response was empty")
    cleaned = text.strip().lstrip("\ufeff")
    if cleaned.startswith("```"):
        cleaned = _FENCE_START_RE.sub("", cleaned, count=1)
        cleaned = _FENCE_END_RE.sub("", cleaned, count=1).strip()
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError:
        # Be forgiving about a short preamble/epilogue around the JSON object.
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start == -1 or end <= start:
            raise PlanParseError("model response was not valid JSON") from None
        try:
            parsed = json.loads(cleaned[start : end + 1])
        except json.JSONDecodeError as exc:
            raise PlanParseError("model response was not valid JSON") from exc
    if not isinstance(parsed, dict):
        raise PlanParseError("model response was not a JSON object")
    return parsed


def parse_model_plan(text: str) -> ModelPlan:
    """Parse + schema-validate raw model text into a permissive ``ModelPlan``."""
    payload = extract_json_payload(text)
    try:
        return ModelPlan.model_validate(payload)
    except ValidationError as exc:
        details = "; ".join(
            f"{'.'.join(str(part) for part in error['loc'])}: {error['msg']}"
            for error in exc.errors()[:5]
        )
        raise PlanSchemaError(f"model JSON did not match the plan schema ({details})") from exc


# ---------------------------------------------------------------------------
# Profiles and results
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class ProviderProfile:
    """One configured provider (``api_key`` is a ``SecretStr`` and repr-safe)."""

    name: str
    base_url: str
    model: str
    api_key: SecretStr | None = None


@dataclass(frozen=True)
class TokenUsage:
    """Token usage reported by the provider (0 when unknown)."""

    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0

    def merged(self, other: TokenUsage) -> TokenUsage:
        prompt = self.prompt_tokens + other.prompt_tokens
        completion = self.completion_tokens + other.completion_tokens
        total = self.total_tokens + other.total_tokens
        if total == 0 and (prompt or completion):
            total = prompt + completion
        return TokenUsage(prompt_tokens=prompt, completion_tokens=completion, total_tokens=total)


@dataclass(frozen=True)
class ChatResult:
    """One provider response: raw text plus token usage."""

    text: str
    usage: TokenUsage


@dataclass(frozen=True)
class LlmPlanResult:
    """A validated raw plan plus the provider that produced it."""

    plan: ModelPlan
    provider: str
    model: str
    latency_ms: int
    usage: TokenUsage


def resolve_profiles(settings: Settings) -> list[ProviderProfile]:
    """Return configured provider profiles, primary first then fallback."""
    profiles: list[ProviderProfile] = []
    if settings.primary_configured:
        profiles.append(
            ProviderProfile(
                name=settings.llm_provider,
                base_url=settings.llm_base_url,
                model=settings.llm_model,
                api_key=settings.llm_api_key,
            )
        )
    if settings.fallback_configured:
        profiles.append(
            ProviderProfile(
                name=settings.llm_fallback_provider,
                base_url=settings.llm_fallback_base_url,
                model=settings.llm_fallback_model,
                api_key=settings.llm_fallback_api_key,
            )
        )
    return profiles


# ---------------------------------------------------------------------------
# HTTP plumbing
# ---------------------------------------------------------------------------


def _openai_chat_url(base_url: str) -> str:
    base = base_url.strip().rstrip("/")
    if base.endswith("/chat/completions"):
        return base
    return f"{base}/chat/completions"


def _anthropic_messages_url(base_url: str) -> str:
    base = base_url.strip().rstrip("/")
    if base.endswith("/messages"):
        return base
    if base.endswith("/v1"):
        return f"{base}/messages"
    return f"{base}/v1/messages"


def _authorization_headers(api_key: SecretStr | None) -> dict[str, str]:
    if api_key is None:
        return {}
    value = api_key.get_secret_value().strip()
    if not value:
        return {}
    return {"Authorization": f"Bearer {value}"}


def _response_json(response: httpx.Response, provider: str) -> dict[str, Any]:
    try:
        payload = response.json()
    except ValueError as exc:
        raise LlmProviderError(provider, "provider returned a non-JSON HTTP body") from exc
    if not isinstance(payload, dict):
        raise LlmProviderError(provider, "provider returned an unexpected HTTP body")
    return payload


def _provider_error_detail(response: httpx.Response) -> str:
    """Return a short, single-line provider error message for diagnostics.

    Providers such as Gemini wrap errors in a list (``[{"error": {...}}]``) instead
    of the OpenAI ``{"error": {...}}`` object, so both shapes are accepted. The
    message is never returned to the app; it only appears in server logs.
    """
    try:
        payload = response.json()
    except ValueError:
        return ""

    message = ""
    candidate: Any = payload
    if isinstance(payload, list) and payload:
        candidate = payload[0]
    if isinstance(candidate, dict):
        error = candidate.get("error")
        if isinstance(error, dict):
            message = str(error.get("message") or "")
        elif isinstance(error, str):
            message = error
        if not message:
            message = str(candidate.get("message") or "")

    message = " ".join(message.split())
    if len(message) > MAX_REASON_CHARS:
        message = message[: MAX_REASON_CHARS - 1].rstrip() + "…"
    return message


def _retry_after_seconds(response: httpx.Response) -> float | None:
    """Parse a ``Retry-After`` header expressed in seconds, when present."""
    raw = response.headers.get("retry-after")
    if not raw:
        return None
    try:
        seconds = float(raw)
    except ValueError:
        return None
    return seconds if seconds >= 0 else None


def _is_terminal_quota(detail: str) -> bool:
    """True when a 429 is a quota exhaustion that a short retry cannot fix."""
    lowered = detail.lower()
    return any(marker in lowered for marker in TERMINAL_QUOTA_MARKERS)


def _usage_from_openai(payload: dict[str, Any]) -> TokenUsage:
    usage = payload.get("usage")
    if not isinstance(usage, dict):
        return TokenUsage()
    return TokenUsage(
        prompt_tokens=_as_int(usage.get("prompt_tokens")),
        completion_tokens=_as_int(usage.get("completion_tokens")),
        total_tokens=_as_int(usage.get("total_tokens")),
    )


def _usage_from_anthropic(payload: dict[str, Any]) -> TokenUsage:
    usage = payload.get("usage")
    if not isinstance(usage, dict):
        return TokenUsage()
    prompt = _as_int(usage.get("input_tokens"))
    completion = _as_int(usage.get("output_tokens"))
    return TokenUsage(
        prompt_tokens=prompt,
        completion_tokens=completion,
        total_tokens=prompt + completion,
    )


def _as_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return 0


class _ProviderClient:
    """Shared HTTP behaviour for the concrete provider clients."""

    name: str

    def __init__(
        self,
        profile: ProviderProfile,
        *,
        temperature: float,
        max_tokens: int,
        backoff_seconds: float,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.profile = profile
        self.name = profile.name
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.backoff_seconds = max(0.0, backoff_seconds)
        self.transport = transport

    async def complete(self, messages: list[dict[str, str]], *, deadline: float) -> ChatResult:
        raise NotImplementedError  # pragma: no cover - abstract

    async def _post(
        self,
        url: str,
        headers: dict[str, str],
        payload: dict[str, Any],
        *,
        deadline: float,
    ) -> httpx.Response:
        """POST with one retry on 429/5xx/timeout, respecting the deadline.

        A 429 caused by an exhausted quota (daily quota, or a ``Retry-After`` that
        outlives the remaining budget) is not retried: the retry cannot succeed and
        would only delay the deterministic fallback.
        """
        last_reason = "request failed"
        for attempt in range(MAX_ATTEMPTS):
            remaining = deadline - time.monotonic()
            if remaining <= 0.05:
                raise LlmProviderError(self.name, "request timeout budget exhausted")
            try:
                async with httpx.AsyncClient(
                    timeout=httpx.Timeout(remaining),
                    transport=self.transport,
                ) as client:
                    response = await client.post(url, headers=headers, json=payload)
            except httpx.TimeoutException as exc:
                last_reason = "request timed out"
                if not await self._wait_before_retry(attempt, deadline):
                    raise LlmProviderError(self.name, last_reason) from exc
                continue
            except httpx.TransportError as exc:
                last_reason = "network error talking to provider"
                if not await self._wait_before_retry(attempt, deadline):
                    raise LlmProviderError(self.name, last_reason) from exc
                continue
            if response.status_code == 429 or response.status_code >= 500:
                detail = _provider_error_detail(response)
                last_reason = f"provider returned HTTP {response.status_code}"
                if detail:
                    last_reason = f"{last_reason}: {detail}"
                retry_after = _retry_after_seconds(response)
                exceeds_budget = retry_after is not None and retry_after > max(
                    0.0, deadline - time.monotonic()
                )
                if exceeds_budget and retry_after is not None:
                    last_reason = f"{last_reason} (retry after {retry_after:.0f}s)"
                terminal = response.status_code == 429 and (
                    _is_terminal_quota(detail) or exceeds_budget
                )
                if terminal or not await self._wait_before_retry(attempt, deadline):
                    raise LlmProviderError(self.name, last_reason)
                continue
            return response
        raise LlmProviderError(self.name, last_reason)

    async def _wait_before_retry(self, attempt: int, deadline: float) -> bool:
        if attempt + 1 >= MAX_ATTEMPTS:
            return False
        delay = self.backoff_seconds * (attempt + 1)
        if delay <= 0.0:
            return True
        if time.monotonic() + delay >= deadline:
            return False
        await asyncio.sleep(delay)
        return True


class OpenAiCompatibleClient(_ProviderClient):
    """Client for any OpenAI-compatible ``/chat/completions`` endpoint."""

    async def complete(self, messages: list[dict[str, str]], *, deadline: float) -> ChatResult:
        url = _openai_chat_url(self.profile.base_url)
        headers = {"Content-Type": "application/json"}
        headers.update(_authorization_headers(self.profile.api_key))
        payload: dict[str, Any] = {
            "model": self.profile.model,
            "messages": messages,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "response_format": _JSON_SCHEMA_RESPONSE_FORMAT,
        }
        response = await self._post(url, headers, payload, deadline=deadline)
        if response.status_code in (400, 404, 422):
            # Not every OpenAI-compatible gateway understands json_schema; ask for a
            # plain JSON object instead.
            fallback_payload = dict(payload)
            fallback_payload["response_format"] = {"type": "json_object"}
            response = await self._post(url, headers, fallback_payload, deadline=deadline)
        if response.status_code >= 400:
            detail = _provider_error_detail(response)
            reason = f"provider returned HTTP {response.status_code}"
            if detail:
                reason = f"{reason}: {detail}"
            raise LlmProviderError(self.name, reason)
        data = _response_json(response, self.name)
        _raise_if_openai_truncated(data, self.name)
        return ChatResult(
            text=_openai_message_text(data, self.name),
            usage=_usage_from_openai(data),
        )


class AnthropicClient(_ProviderClient):
    """Client for the native Anthropic ``/v1/messages`` endpoint."""

    async def complete(self, messages: list[dict[str, str]], *, deadline: float) -> ChatResult:
        url = _anthropic_messages_url(self.profile.base_url)
        headers = {
            "Content-Type": "application/json",
            "anthropic-version": ANTHROPIC_VERSION,
        }
        api_key = self.profile.api_key.get_secret_value() if self.profile.api_key else ""
        if api_key.strip():
            headers["x-api-key"] = api_key.strip()
        system, chat_messages = _split_for_anthropic(messages)
        payload: dict[str, Any] = {
            "model": self.profile.model,
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
            "messages": chat_messages,
            "system": system,
        }
        response = await self._post(url, headers, payload, deadline=deadline)
        if response.status_code >= 400:
            detail = _provider_error_detail(response)
            reason = f"provider returned HTTP {response.status_code}"
            if detail:
                reason = f"{reason}: {detail}"
            raise LlmProviderError(self.name, reason)
        data = _response_json(response, self.name)
        _raise_if_anthropic_truncated(data, self.name)
        return ChatResult(text=_anthropic_text(data, self.name), usage=_usage_from_anthropic(data))


def _split_for_anthropic(
    messages: list[dict[str, str]],
) -> tuple[str, list[dict[str, str]]]:
    system_parts: list[str] = []
    chat_messages: list[dict[str, str]] = []
    for message in messages:
        if message.get("role") == "system":
            system_parts.append(str(message.get("content", "")))
        else:
            chat_messages.append(
                {
                    "role": str(message["role"]),
                    "content": str(message.get("content", "")),
                }
            )
    return "\n\n".join(part for part in system_parts if part), chat_messages


TRUNCATION_REASON = (
    "provider output was truncated at LLM_MAX_TOKENS; raise LLM_MAX_TOKENS "
    "(reasoning models spend part of the budget on thinking)"
)


def _raise_if_openai_truncated(data: dict[str, Any], provider: str) -> None:
    """Reject a chat completion cut off by the token cap.

    Reasoning models (for example Gemini's thinking variants) count hidden
    reasoning tokens against ``max_tokens``. With a small budget the JSON answer
    is cut mid-object, so retrying the same request with the same cap can never
    succeed; fail with an actionable message instead.
    """
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        return
    first = choices[0]
    if isinstance(first, dict) and first.get("finish_reason") == "length":
        raise LlmProviderError(provider, TRUNCATION_REASON)


def _raise_if_anthropic_truncated(data: dict[str, Any], provider: str) -> None:
    if data.get("stop_reason") == "max_tokens":
        raise LlmProviderError(provider, TRUNCATION_REASON)


def _openai_message_text(data: dict[str, Any], provider: str) -> str:
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        raise LlmProviderError(provider, "provider response contained no choices")
    first = choices[0]
    if not isinstance(first, dict):
        raise LlmProviderError(provider, "provider response contained an unexpected choice")
    message = first.get("message")
    if not isinstance(message, dict):
        raise LlmProviderError(provider, "provider response contained no assistant message")
    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [
            str(part.get("text"))
            for part in content
            if isinstance(part, dict) and isinstance(part.get("text"), str)
        ]
        if parts:
            return "".join(parts)
    raise LlmProviderError(provider, "provider response contained no text content")


def _anthropic_text(data: dict[str, Any], provider: str) -> str:
    content = data.get("content")
    if not isinstance(content, list):
        raise LlmProviderError(provider, "provider response contained no content blocks")
    parts = [
        str(block.get("text"))
        for block in content
        if isinstance(block, dict)
        and block.get("type") == "text"
        and isinstance(block.get("text"), str)
    ]
    if not parts:
        raise LlmProviderError(provider, "provider response contained no text content")
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Orchestration client
# ---------------------------------------------------------------------------


class LlmClient:
    """Runs the primary (and optional fallback) provider for one coach request."""

    def __init__(
        self,
        settings: Settings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        backoff_seconds: float | None = None,
    ) -> None:
        self._settings = settings
        self._transport = transport
        self._backoff_seconds = (
            RETRY_BACKOFF_SECONDS if backoff_seconds is None else backoff_seconds
        )
        self._profiles = resolve_profiles(settings)

    @property
    def profiles(self) -> list[ProviderProfile]:
        return list(self._profiles)

    async def generate(self, request: CoachRequest) -> LlmPlanResult:
        """Ask the configured providers for a plan, primary first then fallback."""
        if not self._profiles:
            raise LlmNotConfiguredError("No AI provider is configured on the server.")
        messages = build_messages(request)
        started = time.monotonic()
        budget = self._settings.llm_timeout_seconds
        errors: list[LlmProviderError] = []
        attempted: list[ProviderProfile] = []
        for profile in self._profiles:
            attempted.append(profile)
            remaining = budget - (time.monotonic() - started)
            if remaining <= MIN_BUDGET_SECONDS:
                errors.append(
                    LlmProviderError(
                        profile.name,
                        "overall latency budget exhausted before this provider was tried",
                    )
                )
                continue
            deadline = time.monotonic() + remaining
            try:
                plan, usage = await self._generate_with_profile(profile, messages, deadline)
            except LlmProviderError as exc:
                errors.append(exc)
                continue
            return LlmPlanResult(
                plan=plan,
                provider=profile.name,
                model=profile.model,
                latency_ms=int((time.monotonic() - started) * 1000),
                usage=usage,
            )
        raise LlmUnavailableError(errors=errors, attempted=attempted)

    async def _generate_with_profile(
        self,
        profile: ProviderProfile,
        messages: list[dict[str, str]],
        deadline: float,
    ) -> tuple[ModelPlan, TokenUsage]:
        client = self._make_client(profile)
        try:
            chat = await client.complete(messages, deadline=deadline)
        except LlmProviderError:
            raise
        try:
            return parse_model_plan(chat.text), chat.usage
        except (PlanParseError, PlanSchemaError) as first_error:
            if deadline - time.monotonic() <= MIN_BUDGET_SECONDS:
                raise LlmProviderError(
                    profile.name,
                    f"model returned an invalid plan ({first_error})",
                ) from first_error
            repair_messages = _repair_messages(messages, chat.text, str(first_error))
            try:
                repaired = await client.complete(repair_messages, deadline=deadline)
            except LlmProviderError as exc:
                raise LlmProviderError(
                    profile.name,
                    f"model returned an invalid plan and the repair call failed ({exc.reason})",
                ) from exc
            try:
                plan = parse_model_plan(repaired.text)
            except (PlanParseError, PlanSchemaError) as second_error:
                raise LlmProviderError(
                    profile.name,
                    f"model returned an invalid plan after one repair retry ({second_error})",
                ) from second_error
            usage = chat.usage.merged(repaired.usage)
            return plan, usage

    def _make_client(self, profile: ProviderProfile) -> _ProviderClient:
        if profile.name == PROVIDER_ANTHROPIC:
            return AnthropicClient(
                profile,
                temperature=self._settings.llm_temperature,
                max_tokens=self._settings.llm_max_tokens,
                backoff_seconds=self._backoff_seconds,
                transport=self._transport,
            )
        return OpenAiCompatibleClient(
            profile,
            temperature=self._settings.llm_temperature,
            max_tokens=self._settings.llm_max_tokens,
            backoff_seconds=self._backoff_seconds,
            transport=self._transport,
        )


def _repair_messages(
    messages: list[dict[str, str]],
    raw_text: str,
    error: str,
) -> list[dict[str, str]]:
    """Ask the model to fix its previous invalid answer (one retry only)."""
    preview = raw_text[:4000]
    return [
        *messages,
        {"role": "assistant", "content": preview},
        {
            "role": "user",
            "content": (
                "Your previous reply was rejected because it was not valid JSON for the "
                f"required plan schema: {error}. Reply again with ONLY the corrected JSON "
                "object. No markdown fences, no commentary."
            ),
        },
    ]
