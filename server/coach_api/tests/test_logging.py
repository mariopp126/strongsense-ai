"""Structured logging: request ids, fields, and no secret/body leakage."""

from __future__ import annotations

import json
import logging
from collections.abc import Callable
from typing import Any

import app.main as main_module
import pytest
from app.logging import (
    LOGGER_NAME,
    JsonFormatter,
    configure_logging,
    new_request_id,
    resolve_request_id,
)
from fastapi.testclient import TestClient

from conftest import TEST_API_KEY, TEST_API_TOKEN, model_plan_from_example, openai_response


def _formatted_records(caplog: pytest.LogCaptureFixture) -> str:
    return "\n".join(JsonFormatter().format(record) for record in caplog.records)


# ---------------------------------------------------------------------------
# Request ids
# ---------------------------------------------------------------------------


def test_client_supplied_request_id_is_echoed(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "client-request-0001"})
    assert response.headers["X-Request-ID"] == "client-request-0001"


def test_invalid_client_request_id_is_replaced(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "bad id with spaces"})
    request_id = response.headers["X-Request-ID"]
    assert request_id != "bad id with spaces"
    assert len(request_id) == 32


@pytest.mark.parametrize(
    ("candidate", "echoed"),
    [
        (None, False),
        ("", False),
        ("short", False),
        ("valid-request-id-1", True),
        ("abc.DEF_123:xyz-000", True),
        ("has spaces in it", False),
    ],
)
def test_resolve_request_id(candidate: str | None, echoed: bool) -> None:
    resolved = resolve_request_id(candidate)
    if echoed:
        assert resolved == candidate
    else:
        assert len(resolved) == 32


def test_new_request_id_is_unique() -> None:
    assert new_request_id() != new_request_id()


# ---------------------------------------------------------------------------
# Structured request log
# ---------------------------------------------------------------------------


def test_request_log_contains_structured_fields(
    caplog: pytest.LogCaptureFixture,
    make_client: Callable[..., TestClient],
    llm_overrides: Callable[..., Any],
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    caplog.set_level(logging.INFO, logger=LOGGER_NAME)
    openai_route.mock(return_value=openai_response(model_plan_from_example(response_example)))
    with make_client(**llm_overrides()) as client:
        client.post("/v1/coach/plan", json=plan_payload, headers={"X-Request-ID": "log-test-0001"})

    events = [
        json.loads(JsonFormatter().format(record))
        for record in caplog.records
        if record.name == LOGGER_NAME and record.getMessage() == "request.completed"
    ]
    assert len(events) == 1
    event = events[0]
    assert event["requestId"] == "log-test-0001"
    assert event["method"] == "POST"
    assert event["path"] == "/v1/coach/plan"
    assert event["status"] == 200
    assert isinstance(event["latencyMs"], int)
    assert event["provider"] == "openai_compatible"
    assert event["model"] == "test-model"
    assert event["promptTokens"] == 100
    assert event["completionTokens"] == 50
    assert event["totalTokens"] == 150
    assert event["source"] == "llm"


def test_error_request_is_logged(
    caplog: pytest.LogCaptureFixture,
    client: TestClient,
) -> None:
    caplog.set_level(logging.INFO, logger=LOGGER_NAME)
    client.post("/v1/coach/plan", json={"contractVersion": 1})
    events = [
        json.loads(JsonFormatter().format(record))
        for record in caplog.records
        if record.name == LOGGER_NAME and record.getMessage() == "request.completed"
    ]
    assert events
    assert events[-1]["status"] == 400
    assert "promptTokens" not in events[-1]
    assert "provider" not in events[-1]


# ---------------------------------------------------------------------------
# No secrets or bodies in logs
# ---------------------------------------------------------------------------


def test_logs_do_not_contain_secrets_or_bodies(
    caplog: pytest.LogCaptureFixture,
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
    openai_route: Any,
) -> None:
    caplog.set_level(logging.INFO, logger=LOGGER_NAME)
    marker = "BODY-MARKER-DO-NOT-LOG-12345"
    payload = json.loads(json.dumps(plan_payload))
    payload["context"]["programDay"]["title"] = marker
    openai_route.mock(return_value=openai_response("not valid json"))
    with make_client(
        llm_provider="openai_compatible",
        llm_base_url="https://llm.test/v1",
        llm_model="test-model",
        llm_api_key=TEST_API_KEY,
        coach_api_token=TEST_API_TOKEN,
    ) as client:
        client.post(
            "/v1/coach/plan",
            json=payload,
            headers={"Authorization": f"Bearer {TEST_API_TOKEN}"},
        )
    rendered = _formatted_records(caplog)
    assert TEST_API_KEY not in rendered
    assert TEST_API_TOKEN not in rendered
    assert marker not in rendered
    assert "not valid json" not in rendered


def test_unhandled_exception_logs_type_but_not_message(
    caplog: pytest.LogCaptureFixture,
    make_app: Callable[..., Any],
    plan_payload: dict[str, Any],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    caplog.set_level(logging.INFO, logger=LOGGER_NAME)
    secret_message = "TOP-SECRET-INTERNAL-DETAIL"

    async def boom(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError(secret_message)

    monkeypatch.setattr(main_module, "generate_plan", boom)
    app = make_app()
    client = TestClient(app, raise_server_exceptions=False)
    response = client.post("/v1/coach/plan", json=plan_payload)
    assert response.status_code == 500
    rendered = _formatted_records(caplog)
    assert "RuntimeError" in rendered
    assert secret_message not in rendered


# ---------------------------------------------------------------------------
# Logger configuration
# ---------------------------------------------------------------------------


def test_configure_logging_is_idempotent() -> None:
    first = configure_logging("INFO")
    handler_count = len(first.handlers)
    second = configure_logging("INFO")
    assert second is first
    assert len(second.handlers) == handler_count
    assert second.handlers
    assert second.propagate is True


def test_json_formatter_renders_error_type() -> None:
    record = logging.LogRecord(
        name=LOGGER_NAME,
        level=logging.ERROR,
        pathname=__file__,
        lineno=1,
        msg="request.failed",
        args=(),
        exc_info=None,
    )
    record.exc_type = "RuntimeError"  # type: ignore[attr-defined]
    payload = json.loads(JsonFormatter().format(record))
    assert payload["event"] == "request.failed"
    assert payload["errorType"] == "RuntimeError"
    assert payload["level"] == "ERROR"
