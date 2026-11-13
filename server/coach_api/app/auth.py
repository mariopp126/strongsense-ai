"""Optional bearer-token authentication for the plan endpoint."""

from __future__ import annotations

import secrets
from typing import TYPE_CHECKING

from fastapi import HTTPException, Request

if TYPE_CHECKING:  # pragma: no cover - typing only
    from pydantic import SecretStr

BEARER_PREFIX = "bearer "
UNAUTHORIZED_MESSAGE = "Missing or invalid bearer token."


def extract_bearer_token(authorization_header: str | None) -> str | None:
    """Return the token from an ``Authorization: Bearer <token>`` header."""
    if not authorization_header:
        return None
    scheme, _, token = authorization_header.partition(" ")
    if scheme.lower() != "bearer":
        return None
    token = token.strip()
    return token or None


def verify_bearer_token(authorization_header: str | None, expected: SecretStr | None) -> bool:
    """Constant-time check of the bearer token.

    When no token is configured authentication is disabled and everything is
    allowed. When a token *is* configured, a missing or wrong token is rejected.
    """
    expected_value = expected.get_secret_value() if expected is not None else None
    if not expected_value:
        return True
    provided = extract_bearer_token(authorization_header)
    if provided is None:
        return False
    return secrets.compare_digest(
        provided.encode("utf-8"),
        expected_value.encode("utf-8"),
    )


async def require_auth(request: Request) -> None:
    """FastAPI dependency enforcing the optional ``COACH_API_TOKEN``."""
    settings = request.app.state.settings
    if not verify_bearer_token(request.headers.get("authorization"), settings.coach_api_token):
        raise HTTPException(
            status_code=401,
            detail={"code": "unauthorized", "message": UNAUTHORIZED_MESSAGE},
            headers={"WWW-Authenticate": "Bearer"},
        )
