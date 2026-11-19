"""Tests for GET /health."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def test_health_when_not_configured(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body == {
        "status": "ok",
        "service": "strongsense-coach-api",
        "version": "0.1.0",
        "contractVersion": 1,
        "llmConfigured": False,
        "providers": [],
        "cacheBackend": "memory",
    }


def test_health_when_configured(
    make_client: Callable[..., TestClient],
    llm_overrides: Callable[..., dict[str, Any]],
    fallback_overrides: dict[str, Any],
) -> None:
    with make_client(**llm_overrides(), **fallback_overrides) as client:
        response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["llmConfigured"] is True
    assert body["contractVersion"] == 1
    assert body["cacheBackend"] == "memory"
    assert body["providers"] == [
        {"name": "openai_compatible", "model": "test-model"},
        {"name": "openai_compatible", "model": "fallback-model"},
    ]


def test_health_never_exposes_secrets(
    make_client: Callable[..., TestClient],
    llm_overrides: Callable[..., dict[str, Any]],
) -> None:
    with make_client(
        **llm_overrides(),
        coach_api_token="super-secret-token",
    ) as client:
        response = client.get("/health")
    raw = response.text
    assert "sk-test-secret-key-do-not-log" not in raw
    assert "super-secret-token" not in raw
    assert "apiKey" not in raw
    assert "api_key" not in raw


def test_health_anthropic_without_key_is_not_configured(
    make_client: Callable[..., TestClient],
    make_settings: Callable[..., Any],
) -> None:
    settings = make_settings(
        llm_provider="anthropic",
        llm_base_url="https://api.anthropic.test",
        llm_model="claude-test",
        llm_api_key=None,
    )
    from app.main import create_app

    with TestClient(create_app(settings)) as client:
        body = client.get("/health").json()
    assert body["llmConfigured"] is False
    assert body["providers"] == []


def test_health_openai_compatible_without_key_is_configured(
    make_client: Callable[..., TestClient],
) -> None:
    # Local Ollama-style endpoints do not require an API key.
    with make_client(
        llm_provider="openai_compatible",
        llm_base_url="http://127.0.0.1:11434/v1",
        llm_model="llama3.1:8b",
        llm_api_key=None,
    ) as client:
        body = client.get("/health").json()
    assert body["llmConfigured"] is True
    assert body["providers"] == [{"name": "openai_compatible", "model": "llama3.1:8b"}]


def test_health_has_request_id_header(client: TestClient) -> None:
    response = client.get("/health")
    assert response.headers.get("X-Request-ID")
    assert len(response.headers["X-Request-ID"]) == 32
