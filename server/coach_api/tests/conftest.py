"""Shared pytest fixtures for the StrongSense coach API tests.

No test touches the network: provider HTTP calls are mocked with respx (or replaced by
plain fakes), and ``.env`` is never read (``_env_file=None``).
"""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import httpx
import pytest
import respx
from app import llm
from app.config import Settings
from app.main import create_app
from app.schemas import DISCLAIMER
from fastapi.testclient import TestClient

REPO_ROOT = Path(__file__).resolve().parents[3]
CONTRACT_DIR = REPO_ROOT / "docs" / "contract"

PRIMARY_BASE_URL = "https://llm.test/v1"
FALLBACK_BASE_URL = "https://fallback.test/v1"
TEST_API_KEY = "sk-test-secret-key-do-not-log"
TEST_API_TOKEN = "test-bearer-token"

PLAN_KEYS = (
    "summary",
    "readinessExplanation",
    "rpeCap",
    "deload",
    "adjustments",
    "tips",
    "flags",
)


# ---------------------------------------------------------------------------
# Contract fixtures
# ---------------------------------------------------------------------------


def load_contract_json(name: str) -> dict[str, Any]:
    """Load one of the shared JSON fixtures from docs/contract."""
    return json.loads((CONTRACT_DIR / name).read_text(encoding="utf-8"))


@pytest.fixture(scope="session")
def contract_dir() -> Path:
    assert CONTRACT_DIR.is_dir(), f"contract fixtures missing at {CONTRACT_DIR}"
    return CONTRACT_DIR


@pytest.fixture(scope="session")
def request_example() -> dict[str, Any]:
    return load_contract_json("coach-request.example.json")


@pytest.fixture(scope="session")
def response_example() -> dict[str, Any]:
    return load_contract_json("coach-response.example.json")


@pytest.fixture(scope="session")
def unsafe_example() -> dict[str, Any]:
    return load_contract_json("unsafe-ai-output.example.json")


@pytest.fixture
def plan_payload(request_example: dict[str, Any]) -> dict[str, Any]:
    """A mutable copy of the contract request example."""
    return json.loads(json.dumps(request_example))


def model_plan_from_example(response_example: dict[str, Any]) -> dict[str, Any]:
    """The response example's plan, reduced to the raw LLM output shape.

    Returns a deep copy so tests may mutate nested adjustments safely.
    """
    return json.loads(json.dumps({key: response_example["plan"][key] for key in PLAN_KEYS}))


# ---------------------------------------------------------------------------
# HTTP mock helpers
# ---------------------------------------------------------------------------


def openai_response(
    content: str | dict[str, Any],
    *,
    model: str = "test-model",
    prompt_tokens: int = 100,
    completion_tokens: int = 50,
) -> httpx.Response:
    """Build a fake OpenAI-compatible chat completion response."""
    text = json.dumps(content) if isinstance(content, dict) else content
    return httpx.Response(
        200,
        json={
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": text},
                    "finish_reason": "stop",
                }
            ],
            "usage": {
                "prompt_tokens": prompt_tokens,
                "completion_tokens": completion_tokens,
                "total_tokens": prompt_tokens + completion_tokens,
            },
        },
    )


def anthropic_response(
    content: str | dict[str, Any],
    *,
    input_tokens: int = 120,
    output_tokens: int = 60,
) -> httpx.Response:
    """Build a fake Anthropic messages response."""
    text = json.dumps(content) if isinstance(content, dict) else content
    return httpx.Response(
        200,
        json={
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "model": "claude-test",
            "content": [{"type": "text", "text": text}],
            "stop_reason": "end_turn",
            "usage": {"input_tokens": input_tokens, "output_tokens": output_tokens},
        },
    )


def error_response(status: int, body: dict[str, Any] | None = None) -> httpx.Response:
    return httpx.Response(status, json=body or {"error": {"message": "provider error"}})


@pytest.fixture
def respx_router() -> Any:
    """respx mock router; unmatched requests are left to fail loudly."""
    with respx.mock(assert_all_called=False) as router:
        yield router


@pytest.fixture
def openai_route(respx_router: Any) -> Any:
    return respx_router.post(f"{PRIMARY_BASE_URL}/chat/completions")


@pytest.fixture
def fallback_route(respx_router: Any) -> Any:
    return respx_router.post(f"{FALLBACK_BASE_URL}/chat/completions")


# ---------------------------------------------------------------------------
# Settings / app / client factories
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _no_retry_sleep(monkeypatch: pytest.MonkeyPatch) -> None:
    """Never sleep in retry/backoff paths during tests."""
    monkeypatch.setattr(llm, "RETRY_BACKOFF_SECONDS", 0.0)


@pytest.fixture
def make_settings() -> Callable[..., Settings]:
    """Factory for isolated ``Settings`` objects that ignore ``.env``/environ."""

    def _make(**overrides: Any) -> Settings:
        values: dict[str, Any] = {
            "_env_file": None,
            "app_env": "test",
            "coach_host": "127.0.0.1",
            "coach_port": 8080,
            "coach_api_token": None,
            "allowed_origins": "http://localhost:5173,http://127.0.0.1:5173",
            "max_requests_per_min": 0,
            "llm_provider": "",
            "llm_base_url": "",
            "llm_api_key": None,
            "llm_model": "",
            "llm_timeout_seconds": 5.0,
            "llm_temperature": 0.4,
            "llm_max_tokens": 900,
            "llm_fallback_provider": "",
            "llm_fallback_base_url": "",
            "llm_fallback_api_key": None,
            "llm_fallback_model": "",
        }
        values.update(overrides)
        return Settings(**values)

    return _make


@pytest.fixture
def llm_overrides() -> Callable[..., dict[str, Any]]:
    """Factory for primary-provider settings overrides."""

    def _make(**overrides: Any) -> dict[str, Any]:
        values: dict[str, Any] = {
            "llm_provider": "openai_compatible",
            "llm_base_url": PRIMARY_BASE_URL,
            "llm_model": "test-model",
            "llm_api_key": TEST_API_KEY,
        }
        values.update(overrides)
        return values

    return _make


@pytest.fixture
def fallback_overrides() -> dict[str, Any]:
    return {
        "llm_fallback_provider": "openai_compatible",
        "llm_fallback_base_url": FALLBACK_BASE_URL,
        "llm_fallback_model": "fallback-model",
        "llm_fallback_api_key": "sk-fallback-test-key",
    }


@pytest.fixture
def make_app(make_settings: Callable[..., Settings]) -> Callable[..., Any]:
    """Factory for FastAPI apps with custom settings."""

    def _make(**settings_overrides: Any) -> Any:
        return create_app(make_settings(**settings_overrides))

    return _make


@pytest.fixture
def make_client(make_app: Callable[..., Any]) -> Callable[..., TestClient]:
    """Factory for TestClient instances bound to custom settings."""

    def _make(**settings_overrides: Any) -> TestClient:
        return TestClient(make_app(**settings_overrides))

    return _make


@pytest.fixture
def client(make_client: Callable[..., TestClient]) -> Any:
    with make_client() as test_client:
        yield test_client


@pytest.fixture
def llm_client(make_client: Callable[..., TestClient], llm_overrides: Callable[..., Any]) -> Any:
    with make_client(**llm_overrides()) as test_client:
        yield test_client


@pytest.fixture
def plan_url() -> str:
    return "/v1/coach/plan"


@pytest.fixture(scope="session")
def disclaimer() -> str:
    return DISCLAIMER
