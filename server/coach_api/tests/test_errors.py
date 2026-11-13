"""Consistent error envelopes, 404/405/500 handling and CORS."""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import app.main as main_module
import pytest
from fastapi.testclient import TestClient


def test_unknown_route_uses_error_envelope(client: TestClient) -> None:
    response = client.get("/does-not-exist")
    assert response.status_code == 404
    assert response.json() == {
        "detail": {"code": "not_found", "message": "Not Found"}
    }


def test_wrong_method_uses_error_envelope(client: TestClient) -> None:
    response = client.get("/v1/coach/plan")
    assert response.status_code == 405
    assert response.json()["detail"]["code"] == "method_not_allowed"


def test_unhandled_exception_returns_500(
    make_app: Callable[..., Any],
    plan_payload: dict[str, Any],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def boom(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError("secret internal detail that must not leak")

    monkeypatch.setattr(main_module, "generate_plan", boom)
    app = make_app()
    client = TestClient(app, raise_server_exceptions=False)
    response = client.post("/v1/coach/plan", json=plan_payload)
    assert response.status_code == 500
    body = response.json()
    assert body == {"detail": {"code": "internal_error", "message": "Internal server error."}}
    assert "secret internal detail" not in response.text
    assert response.headers.get("X-Request-ID")


def test_request_validation_message_does_not_echo_input(
    client: TestClient,
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    marker = "SECRET-MARKER-VALUE"
    payload["context"]["blockWeek"] = marker
    response = client.post("/v1/coach/plan", json=payload)
    assert response.status_code == 400
    assert marker not in response.text


def test_cors_preflight_allowed_origin(client: TestClient) -> None:
    response = client.options(
        "/v1/coach/plan",
        headers={
            "Origin": "http://localhost:5173",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Authorization,Content-Type",
        },
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == "http://localhost:5173"
    assert "POST" in response.headers.get("access-control-allow-methods", "")


def test_cors_disallowed_origin_has_no_allow_header(client: TestClient) -> None:
    response = client.get("/health", headers={"Origin": "https://evil.example.com"})
    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers


def test_cors_allows_origin_on_validation_error(
    client: TestClient,
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload.pop("context")
    origin = "http://localhost:5173"
    response = client.post("/v1/coach/plan", json=payload, headers={"Origin": origin})
    assert response.status_code == 400
    assert response.headers.get("access-control-allow-origin") == origin


def test_openapi_metadata(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()
    assert schema["info"]["title"] == "StrongSense Coach API"
    assert schema["info"]["version"] == "0.1.0"
    assert "/health" in schema["paths"]
    assert "/v1/coach/plan" in schema["paths"]
