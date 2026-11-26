"""End-to-end POST /v1/coach/plan behaviour with mocked providers."""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import httpx
import pytest
from app.schemas import DISCLAIMER
from fastapi.testclient import TestClient

from conftest import (
    PRIMARY_BASE_URL,
    anthropic_response,
    error_response,
    model_plan_from_example,
    openai_response,
)


@pytest.fixture
def llm_client(
    make_client: Callable[..., TestClient],
    llm_overrides: Callable[..., Any],
) -> Any:
    with make_client(**llm_overrides()) as client:
        yield client


def post_plan(client: TestClient, payload: dict[str, Any]) -> Any:
    return client.post("/v1/coach/plan", json=payload)


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


def test_happy_path_returns_contract_example(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=openai_response(model_plan_from_example(response_example)))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["contractVersion"] == 1
    assert body["source"] == "llm"
    assert body["plan"] == response_example["plan"]
    assert body["plan"]["source"] == "llm"
    assert body["plan"]["disclaimer"] == DISCLAIMER
    assert body["meta"]["provider"] == "openai_compatible"
    assert body["meta"]["model"] == "test-model"
    assert body["meta"]["latencyMs"] >= 0
    assert body["meta"]["clamped"] is False
    assert body["meta"]["droppedAdjustments"] == 0
    assert response.headers.get("X-Request-ID")


def test_force_rules_skips_the_llm(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    respx_router: Any,
) -> None:
    # No provider configured and no mocked routes: forceRules must not call out.
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    with make_client() as client:
        response = post_plan(client, payload)
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "rules"
    assert body["plan"]["source"] == "rules"
    assert body["plan"]["disclaimer"] == DISCLAIMER
    assert body["plan"]["summary"] == payload["baselinePlan"]["summary"]
    assert body["meta"] == {
        "provider": "rules",
        "model": "rules",
        "latencyMs": 0,
        "clamped": False,
        "droppedAdjustments": 0,
    }
    assert respx_router.calls.call_count == 0


def test_force_rules_also_overwrites_disclaimer(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    payload["baselinePlan"]["disclaimer"] = "model supplied disclaimer"
    with make_client() as client:
        response = post_plan(client, payload)
    assert response.status_code == 200
    assert response.json()["plan"]["disclaimer"] == DISCLAIMER


# ---------------------------------------------------------------------------
# No provider
# ---------------------------------------------------------------------------


def test_no_provider_returns_503(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
) -> None:
    with make_client() as client:
        response = post_plan(client, plan_payload)
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "llm_not_configured"
    assert response.json()["detail"]["message"]


def test_no_provider_with_baseline_still_returns_503(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
) -> None:
    with make_client() as client:
        response = post_plan(client, plan_payload)
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "llm_not_configured"


# ---------------------------------------------------------------------------
# Provider failures -> rules fallback or 503
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("status", [429, 500, 502, 503])
def test_provider_http_failure_returns_rules_fallback(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
    status: int,
) -> None:
    openai_route.mock(return_value=error_response(status))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["source"] == "rules_fallback"
    assert body["plan"]["source"] == "rules_fallback"
    assert body["plan"]["summary"] == plan_payload["baselinePlan"]["summary"]
    assert body["plan"]["disclaimer"] == DISCLAIMER
    assert body["meta"]["clamped"] is False
    assert body["meta"]["droppedAdjustments"] == 0
    assert body["meta"]["provider"] == "openai_compatible"
    assert body["meta"]["model"] == "test-model"
    assert body["meta"]["latencyMs"] >= 0


def test_provider_timeout_returns_rules_fallback(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
) -> None:
    openai_route.mock(side_effect=httpx.ReadTimeout("timeout"))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    assert response.json()["source"] == "rules_fallback"


def test_rules_fallback_logs_provider_reason(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
    caplog: pytest.LogCaptureFixture,
) -> None:
    openai_route.mock(
        return_value=httpx.Response(
            429,
            json=[
                {
                    "error": {
                        "message": (
                            "You exceeded your current quota. "
                            "Quota exceeded for per day limit."
                        )
                    }
                }
            ],
        )
    )
    with caplog.at_level("INFO", logger="strongsense.coach"):
        response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    assert response.json()["source"] == "rules_fallback"
    assert openai_route.call_count == 1
    events = [record for record in caplog.records if record.getMessage() == "request.completed"]
    assert events
    assert "quota" in events[-1].event_data["llmError"].lower()


def test_invalid_json_returns_rules_fallback(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=openai_response("not json at all"))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    assert response.json()["source"] == "rules_fallback"


def test_schema_invalid_output_returns_rules_fallback(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=openai_response({"summary": "incomplete"}))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    assert response.json()["source"] == "rules_fallback"


def test_repair_retry_can_still_succeed(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    openai_route.side_effect = [
        openai_response("nope"),
        openai_response(model_plan_from_example(response_example)),
    ]
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    assert response.json()["source"] == "llm"
    assert openai_route.call_count == 2


@pytest.mark.parametrize("failure", ["http_500", "invalid_json", "timeout", "unsafe_schema"])
def test_provider_failure_without_baseline_returns_503(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
    failure: str,
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload.pop("baselinePlan")
    if failure == "http_500":
        openai_route.mock(return_value=error_response(500))
    elif failure == "invalid_json":
        openai_route.mock(return_value=openai_response("nope"))
    elif failure == "timeout":
        openai_route.mock(side_effect=httpx.ReadTimeout("timeout"))
    else:
        openai_route.mock(return_value=openai_response({"summary": "incomplete"}))
    response = post_plan(llm_client, payload)
    assert response.status_code == 503
    body = response.json()
    assert body["detail"]["code"] == "llm_unavailable"
    assert body["detail"]["message"]


@pytest.mark.parametrize(
    ("status", "body", "expected_message"),
    [
        (401, {"error": {"message": "bad key"}}, "rejected the configured API key"),
        (
            400,
            {"error": {"message": "Please pass a valid API key"}},
            "rejected the configured API key",
        ),
        (404, {"error": {"message": "model not found"}}, "model was not found"),
        (429, {"error": {"message": "per day quota exceeded"}}, "quota is exhausted"),
    ],
)
def test_no_baseline_failure_returns_safe_category_message(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
    status: int,
    body: dict[str, Any],
    expected_message: str,
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload.pop("baselinePlan")
    openai_route.mock(return_value=httpx.Response(status, json=body))
    response = post_plan(llm_client, payload)
    assert response.status_code == 503
    detail = response.json()["detail"]
    assert detail["code"] == "llm_unavailable"
    assert expected_message in detail["message"]
    assert "bad key" not in detail["message"]


def test_fallback_logs_llm_error_category(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    openai_route: Any,
    caplog: pytest.LogCaptureFixture,
) -> None:
    openai_route.mock(
        return_value=httpx.Response(
            429,
            json={"error": {"message": "Quota exceeded for per day limit."}},
        )
    )
    with caplog.at_level("INFO", logger="strongsense.coach"):
        response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    assert response.json()["source"] == "rules_fallback"
    events = [record for record in caplog.records if record.getMessage() == "request.completed"]
    assert events
    assert events[-1].event_data["llmErrorCategory"] == "quota_exceeded"


# ---------------------------------------------------------------------------
# Fallback provider
# ---------------------------------------------------------------------------


def test_fallback_provider_is_used(
    make_client: Callable[..., TestClient],
    llm_overrides: Callable[..., Any],
    fallback_overrides: dict[str, Any],
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    openai_route: Any,
    fallback_route: Any,
) -> None:
    openai_route.mock(return_value=error_response(500))
    fallback_route.mock(return_value=openai_response(model_plan_from_example(response_example)))
    with make_client(**llm_overrides(), **fallback_overrides) as client:
        response = post_plan(client, plan_payload)
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "llm"
    assert body["meta"]["model"] == "fallback-model"
    assert openai_route.call_count == 2
    assert fallback_route.call_count == 1


def test_fallback_provider_also_fails_returns_503_without_baseline(
    make_client: Callable[..., TestClient],
    llm_overrides: Callable[..., Any],
    fallback_overrides: dict[str, Any],
    plan_payload: dict[str, Any],
    openai_route: Any,
    fallback_route: Any,
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload.pop("baselinePlan")
    openai_route.mock(return_value=error_response(500))
    fallback_route.mock(return_value=error_response(500))
    with make_client(**llm_overrides(), **fallback_overrides) as client:
        response = post_plan(client, payload)
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "llm_unavailable"


# ---------------------------------------------------------------------------
# Clamping through the endpoint
# ---------------------------------------------------------------------------


def test_unsafe_model_output_is_clamped_end_to_end(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    unsafe_example: dict[str, Any],
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=openai_response(unsafe_example))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    body = response.json()
    plan = body["plan"]
    assert body["meta"]["clamped"] is True
    assert body["meta"]["droppedAdjustments"] == 1
    assert plan["rpeCap"] == 9.0
    assert [adjustment["exerciseId"] for adjustment in plan["adjustments"]] == [
        "ex-bench",
        "ex-spoto",
    ]
    assert plan["adjustments"][0]["loadDeltaPct"] == 5.0
    assert plan["adjustments"][0]["setsDelta"] == 2
    assert plan["adjustments"][1]["loadDeltaPct"] == -10.0
    assert plan["adjustments"][1]["setsDelta"] == -2
    assert len(plan["tips"]) == 12
    assert len(plan["flags"]) == 8
    assert plan["disclaimer"] == DISCLAIMER
    assert plan["source"] == "llm"


def test_deload_output_uses_deload_bounds(
    llm_client: TestClient,
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    raw = model_plan_from_example(response_example)
    raw["deload"] = True
    raw["rpeCap"] = 9.5
    raw["adjustments"][0]["loadDeltaPct"] = 4.0
    raw["adjustments"][1]["loadDeltaPct"] = -25.4
    openai_route.mock(return_value=openai_response(raw))
    response = post_plan(llm_client, plan_payload)
    assert response.status_code == 200
    plan = response.json()["plan"]
    assert plan["deload"] is True
    assert plan["rpeCap"] == 7.0
    assert plan["adjustments"][0]["loadDeltaPct"] == 0.0
    assert plan["adjustments"][1]["loadDeltaPct"] == -25.5
    assert all(adjustment["loadDeltaPct"] <= 0.0 for adjustment in plan["adjustments"])


def test_anthropic_provider_through_endpoint(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
    response_example: dict[str, Any],
    respx_router: Any,
) -> None:
    respx_router.post("https://anthro.test/v1/messages").mock(
        return_value=anthropic_response(model_plan_from_example(response_example))
    )
    with make_client(
        llm_provider="anthropic",
        llm_base_url="https://anthro.test",
        llm_model="claude-test",
        llm_api_key="sk-ant-test",
    ) as client:
        response = post_plan(client, plan_payload)
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "llm"
    assert body["meta"]["provider"] == "anthropic"
    assert body["meta"]["model"] == "claude-test"


def test_provider_base_url_constant() -> None:
    assert PRIMARY_BASE_URL == "https://llm.test/v1"
