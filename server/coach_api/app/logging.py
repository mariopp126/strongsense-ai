"""Structured, secret-free logging for the coach service.

Only whitelisted metadata is emitted: request ids, method, path, status, latency and
LLM provider/usage facts. Request and response bodies, headers and API keys are
never logged.
"""

from __future__ import annotations

import json
import logging
import re
import sys
import uuid
from datetime import UTC, datetime
from typing import Any

LOGGER_NAME = "strongsense.coach"
REQUEST_ID_HEADER = "X-Request-ID"

_REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9._:-]{8,128}$")
_CONFIGURED_ATTR = "_strongsense_configured"


class JsonFormatter(logging.Formatter):
    """Render a log record as a single JSON object on one line."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": _utc_timestamp(),
            "level": record.levelname,
            "logger": record.name,
            "event": record.getMessage(),
        }
        event_data = getattr(record, "event_data", None)
        if isinstance(event_data, dict):
            payload.update(event_data)
        exc_type = getattr(record, "exc_type", None)
        if exc_type:
            # Exception *type* only: messages may contain request data.
            payload["errorType"] = str(exc_type)
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str)


def _utc_timestamp() -> str:
    return datetime.now(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def configure_logging(level: str = "INFO") -> logging.Logger:
    """Configure the service logger exactly once per process."""
    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(level.upper())
    if not getattr(logger, _CONFIGURED_ATTR, False):
        handler = logging.StreamHandler(stream=sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        # Keep propagation so test harnesses (caplog) and root handlers can observe.
        logger.propagate = True
        setattr(logger, _CONFIGURED_ATTR, True)
    return logger


def get_logger() -> logging.Logger:
    """Return the service logger."""
    return logging.getLogger(LOGGER_NAME)


def new_request_id() -> str:
    """Generate a random request id."""
    return uuid.uuid4().hex


def resolve_request_id(candidate: str | None) -> str:
    """Echo a well-formed client supplied request id, otherwise generate one."""
    if candidate is not None and _REQUEST_ID_RE.match(candidate.strip()):
        return candidate.strip()
    return new_request_id()


def log_request_completed(
    *,
    request_id: str,
    method: str,
    path: str,
    status: int,
    latency_ms: int,
    extra: dict[str, Any] | None = None,
) -> None:
    """Emit one structured line for a finished request."""
    event: dict[str, Any] = {
        "requestId": request_id,
        "method": method,
        "path": path,
        "status": status,
        "latencyMs": latency_ms,
    }
    if extra:
        for key, value in extra.items():
            if value is None:
                continue
            event[key] = value
    get_logger().info("request.completed", extra={"event_data": event})


def log_startup(summary: dict[str, Any]) -> None:
    """Emit the safe startup summary."""
    get_logger().info("service.startup", extra={"event_data": summary})


def log_server_error(*, request_id: str, method: str, path: str, exc_type: str) -> None:
    """Log an unhandled exception without its message or body."""
    get_logger().error(
        "request.failed",
        extra={
            "event_data": {
                "requestId": request_id,
                "method": method,
                "path": path,
                "errorType": exc_type,
            }
        },
    )
