"""Optional bearer-token authentication."""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import pytest
from app.auth import extract_bearer_token, verify_bearer_token
from app.main import create_app
from fastapi import HTTPException
from fastapi.testclient import TestClient
from starlette.requests import Request


@pytest.mark.parametrize(
    ("header", "expected"),
    [
        (None, None),
        ("", None),
        ("Bearer abc", "abc"),
        ("bearer abc", "abc"),
        ("BEARER   abc  ", "abc"),
        ("Token abc", None),
        ("Bearer", None),
        ("Bearer ", None),
        ("abc", None),
    ],
)
def test_extract_bearer_token(header: str | None, expected: str | None) -> None:
    assert extract_bearer_token(header) == expected


def test_verify_bearer_token_disabled() -> None:
    assert verify_bearer_token(None, None) is True
    assert verify_bearer_token("Bearer whatever", None) is True


def test_verify_bearer_token_enabled() -> None:
    from pydantic import SecretStr

    expected = SecretStr("secret-token")
    assert verify_bearer_token("Bearer secret-token", expected) is True
    assert verify_bearer_token("bearer secret-token", expected) is True
    assert verify_bearer_token("Bearer wrong", expected) is False
    assert verify_bearer_token(None, expected) is False
    assert verify_bearer_token("", expected) is False


def test_auth_disabled_allows_requests(
    client: TestClient,
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    assert client.post("/v1/coach/plan", json=payload).status_code == 200


def test_auth_enabled_rejects_missing_and_wrong_tokens(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    with make_client(coach_api_token="expected-token") as client:
        missing = client.post("/v1/coach/plan", json=payload)
        wrong = client.post(
            "/v1/coach/plan",
            json=payload,
            headers={"Authorization": "Bearer nope"},
        )
        wrong_scheme = client.post(
            "/v1/coach/plan",
            json=payload,
            headers={"Authorization": f"Basic {payload}"},
        )
        allowed = client.post(
            "/v1/coach/plan",
            json=payload,
            headers={"Authorization": "Bearer expected-token"},
        )
        health = client.get("/health")
    for rejected in (missing, wrong, wrong_scheme):
        assert rejected.status_code == 401
        assert rejected.json()["detail"]["code"] == "unauthorized"
        assert rejected.headers.get("www-authenticate") == "Bearer"
    assert allowed.status_code == 200
    assert health.status_code == 200


def test_auth_rejection_before_body_validation(
    make_client: Callable[..., TestClient],
) -> None:
    with make_client(coach_api_token="expected-token") as client:
        response = client.post("/v1/coach/plan", json={"garbage": True})
    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "unauthorized"


def test_require_auth_dependency_raises_http_exception(
    make_client: Callable[..., TestClient],
) -> None:
    settings = make_client  # noqa: F841 - keep fixture for app creation below
    app = create_app_for_test()
    scope = {
        "type": "http",
        "app": app,
        "headers": [],
        "method": "POST",
        "path": "/v1/coach/plan",
    }
    request = Request(scope)
    import asyncio

    from app.auth import require_auth

    with pytest.raises(HTTPException) as exc_info:
        asyncio.run(require_auth(request))
    assert exc_info.value.status_code == 401


def create_app_for_test() -> Any:
    from app.config import Settings

    return create_app(
        Settings(
            _env_file=None,
            app_env="test",
            coach_api_token="expected-token",
        )
    )
