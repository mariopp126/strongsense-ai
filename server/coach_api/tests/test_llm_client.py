"""LLM provider client unit tests (respx, no real network)."""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import httpx
import pytest
from app.config import Settings
from app.llm import (
    LlmClient,
    LlmNotConfiguredError,
    LlmUnavailableError,
    PlanParseError,
    PlanSchemaError,
    TokenUsage,
    _anthropic_messages_url,
    _openai_chat_url,
    extract_json_payload,
    parse_model_plan,
    resolve_profiles,
)
from app.schemas import CoachRequest

from conftest import (
    FALLBACK_BASE_URL,
    PRIMARY_BASE_URL,
    anthropic_response,
    error_response,
    model_plan_from_example,
    openai_response,
)


@pytest.fixture
def request_obj(request_example: dict[str, Any]) -> CoachRequest:
    return CoachRequest.model_validate(request_example)


@pytest.fixture
def configured(
    make_settings: Callable[..., Settings],
    llm_overrides: Callable[..., Any],
) -> Settings:
    return make_settings(**llm_overrides())


# ---------------------------------------------------------------------------
# URL + parsing helpers
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("base", "expected"),
    [
        ("https://api.openai.com/v1", "https://api.openai.com/v1/chat/completions"),
        ("https://api.openai.com/v1/", "https://api.openai.com/v1/chat/completions"),
        (
            "https://api.openai.com/v1/chat/completions",
            "https://api.openai.com/v1/chat/completions",
        ),
    ],
)
def test_openai_chat_url(base: str, expected: str) -> None:
    assert _openai_chat_url(base) == expected


@pytest.mark.parametrize(
    ("base", "expected"),
    [
        ("https://api.anthropic.com", "https://api.anthropic.com/v1/messages"),
        ("https://api.anthropic.com/", "https://api.anthropic.com/v1/messages"),
        ("https://api.anthropic.com/v1", "https://api.anthropic.com/v1/messages"),
        ("https://proxy.anthropic.test/v1/messages", "https://proxy.anthropic.test/v1/messages"),
    ],
)
def test_anthropic_messages_url(base: str, expected: str) -> None:
    assert _anthropic_messages_url(base) == expected


def test_extract_json_payload_plain() -> None:
    assert extract_json_payload('{"a": 1}') == {"a": 1}


def test_extract_json_payload_fences() -> None:
    assert extract_json_payload('```json\n{"a": 1}\n```') == {"a": 1}
    assert extract_json_payload('```\n{"a": 1}\n```') == {"a": 1}


def test_extract_json_payload_with_prose() -> None:
    assert extract_json_payload('Here you go: {"a": 1} Enjoy!') == {"a": 1}


@pytest.mark.parametrize("text", ["", "   ", "no json here", "[1, 2, 3]"])
def test_extract_json_payload_invalid(text: str) -> None:
    with pytest.raises(PlanParseError):
        extract_json_payload(text)


def test_parse_model_plan_schema_error() -> None:
    with pytest.raises(PlanSchemaError):
        parse_model_plan('{"summary": "only summary"}')


def test_parse_model_plan_ignores_extra_fields(
    response_example: dict[str, Any],
) -> None:
    raw = dict(response_example["plan"])
    raw["serverOnlySource"] = "llm"
    plan = parse_model_plan(json.dumps(raw))
    assert plan.deload is False


def test_token_usage_merged() -> None:
    merged = TokenUsage(10, 5, 15).merged(TokenUsage(0, 0, 0))
    assert merged == TokenUsage(10, 5, 15)


# ---------------------------------------------------------------------------
# OpenAI-compatible client
# ---------------------------------------------------------------------------


async def test_openai_success(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
    respx_router: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    openai_route.mock(return_value=openai_response(plan_payload))

    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)

    assert result.provider == "openai_compatible"
    assert result.model == "test-model"
    assert result.plan.rpeCap == 8.5
    assert result.latency_ms >= 0
    assert result.usage == TokenUsage(100, 50, 150)

    sent = openai_route.calls.last.request
    assert sent.headers["authorization"] == "Bearer sk-test-secret-key-do-not-log"
    body = json.loads(sent.content)
    assert body["model"] == "test-model"
    assert body["temperature"] == 0.4
    assert body["max_tokens"] == 900
    assert body["response_format"]["type"] == "json_schema"
    assert [message["role"] for message in body["messages"]] == ["system", "user"]


async def test_openai_json_schema_falls_back_to_json_object(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    openai_route.side_effect = [error_response(400), openai_response(plan_payload)]

    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)

    assert result.plan.summary == plan_payload["summary"]
    assert openai_route.call_count == 2
    first = json.loads(openai_route.calls[0].request.content)
    second = json.loads(openai_route.calls[1].request.content)
    assert first["response_format"]["type"] == "json_schema"
    assert second["response_format"] == {"type": "json_object"}


async def test_openai_markdown_fences_and_preamble_accepted(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    fenced = "```json\n" + json.dumps(plan_payload) + "\n```"
    openai_route.mock(return_value=openai_response(fenced))
    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.summary == plan_payload["summary"]


async def test_openai_repair_retry_on_invalid_json(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    openai_route.side_effect = [
        openai_response("this is not json"),
        openai_response(plan_payload),
    ]
    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.rpeCap == 8.5
    assert openai_route.call_count == 2
    repair_body = json.loads(openai_route.calls[1].request.content)
    assert repair_body["messages"][-1]["role"] == "user"
    assert "rejected" in repair_body["messages"][-1]["content"]
    # Usage of both calls is accumulated.
    assert result.usage == TokenUsage(200, 100, 300)


async def test_openai_repair_retry_on_schema_invalid(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    openai_route.side_effect = [
        openai_response({"summary": "missing required fields"}),
        openai_response(plan_payload),
    ]
    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.deload is False
    assert openai_route.call_count == 2


async def test_openai_repair_exhausted(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.side_effect = [
        openai_response("still not json"),
        openai_response("still not json either"),
    ]
    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert "invalid plan" in exc_info.value.errors[0].reason
    assert openai_route.call_count == 2


async def test_openai_retry_on_429_then_success(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    openai_route.side_effect = [error_response(429), openai_response(plan_payload)]
    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.summary == plan_payload["summary"]
    assert openai_route.call_count == 2


async def test_openai_retry_on_500_then_success(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    openai_route.side_effect = [error_response(500), openai_response(plan_payload)]
    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.rpeCap == 8.5
    assert openai_route.call_count == 2


async def test_openai_429_exhausted(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=error_response(429))
    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert "HTTP 429" in exc_info.value.errors[0].reason
    assert openai_route.call_count == 2


async def test_openai_timeout(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.mock(side_effect=httpx.ReadTimeout("timed out"))
    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert "timed out" in exc_info.value.errors[0].reason


async def test_openai_network_error(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.mock(side_effect=httpx.ConnectError("no route"))
    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert "network error" in exc_info.value.errors[0].reason


async def test_openai_http_401_not_retried(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=error_response(401))
    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert "HTTP 401" in exc_info.value.errors[0].reason
    assert openai_route.call_count == 1


async def test_openai_missing_choices(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=httpx.Response(200, json={"choices": []}))
    with pytest.raises(LlmUnavailableError):
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)


async def test_openai_non_json_http_body(
    configured: Settings,
    request_obj: CoachRequest,
    openai_route: Any,
) -> None:
    openai_route.mock(return_value=httpx.Response(200, content=b"<html>nope</html>"))
    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert "non-JSON" in exc_info.value.errors[0].reason


async def test_openai_content_parts(
    configured: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
) -> None:
    plan_payload = model_plan_from_example(response_example)
    text = json.dumps(plan_payload)
    openai_route.mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [
                    {"message": {"content": [{"type": "text", "text": text}]}}
                ]
            },
        )
    )
    result = await LlmClient(configured, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.rpeCap == 8.5


# ---------------------------------------------------------------------------
# Anthropic client
# ---------------------------------------------------------------------------


@pytest.fixture
def anthropic_settings(
    make_settings: Callable[..., Settings],
) -> Settings:
    return make_settings(
        llm_provider="anthropic",
        llm_base_url="https://anthro.test",
        llm_model="claude-test",
        llm_api_key="sk-ant-test",
    )


async def test_anthropic_success(
    anthropic_settings: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    respx_router: Any,
) -> None:
    route = respx_router.post("https://anthro.test/v1/messages").mock(
        return_value=anthropic_response(model_plan_from_example(response_example))
    )
    result = await LlmClient(anthropic_settings, backoff_seconds=0.0).generate(request_obj)
    assert result.provider == "anthropic"
    assert result.model == "claude-test"
    assert result.usage == TokenUsage(120, 60, 180)
    request = route.calls.last.request
    assert request.headers["x-api-key"] == "sk-ant-test"
    assert request.headers["anthropic-version"] == "2023-06-01"
    body = json.loads(request.content)
    assert body["model"] == "claude-test"
    assert body["max_tokens"] == 900
    assert "expert strength coach" in body["system"]
    assert body["messages"][0]["role"] == "user"
    assert "response_format" not in body


async def test_anthropic_fence_stripping(
    anthropic_settings: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    respx_router: Any,
) -> None:
    text = "```json\n" + json.dumps(model_plan_from_example(response_example)) + "\n```"
    respx_router.post("https://anthro.test/v1/messages").mock(
        return_value=anthropic_response(text)
    )
    result = await LlmClient(anthropic_settings, backoff_seconds=0.0).generate(request_obj)
    assert result.plan.rpeCap == 8.5


async def test_anthropic_retry_on_429(
    anthropic_settings: Settings,
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    respx_router: Any,
) -> None:
    route = respx_router.post("https://anthro.test/v1/messages")
    route.side_effect = [
        error_response(429),
        anthropic_response(model_plan_from_example(response_example)),
    ]
    result = await LlmClient(anthropic_settings, backoff_seconds=0.0).generate(request_obj)
    assert route.call_count == 2
    assert result.plan.deload is False


async def test_anthropic_http_error(
    anthropic_settings: Settings,
    request_obj: CoachRequest,
    respx_router: Any,
) -> None:
    respx_router.post("https://anthro.test/v1/messages").mock(
        return_value=error_response(500)
    )
    with pytest.raises(LlmUnavailableError):
        await LlmClient(anthropic_settings, backoff_seconds=0.0).generate(request_obj)


async def test_anthropic_missing_text_block(
    anthropic_settings: Settings,
    request_obj: CoachRequest,
    respx_router: Any,
) -> None:
    respx_router.post("https://anthro.test/v1/messages").mock(
        return_value=httpx.Response(200, json={"content": []})
    )
    with pytest.raises(LlmUnavailableError):
        await LlmClient(anthropic_settings, backoff_seconds=0.0).generate(request_obj)


# ---------------------------------------------------------------------------
# Primary + fallback orchestration
# ---------------------------------------------------------------------------


async def test_fallback_used_when_primary_fails(
    make_settings: Callable[..., Settings],
    llm_overrides: Callable[..., Any],
    fallback_overrides: dict[str, Any],
    request_obj: CoachRequest,
    response_example: dict[str, Any],
    openai_route: Any,
    fallback_route: Any,
) -> None:
    settings = make_settings(**llm_overrides(), **fallback_overrides)
    openai_route.mock(return_value=error_response(500))
    fallback_route.mock(return_value=openai_response(model_plan_from_example(response_example)))

    result = await LlmClient(settings, backoff_seconds=0.0).generate(request_obj)

    assert result.model == "fallback-model"
    assert result.provider == "openai_compatible"
    assert openai_route.call_count == 2
    assert fallback_route.call_count == 1
    authorization = fallback_route.calls.last.request.headers["authorization"]
    assert authorization.startswith("Bearer sk-fallback")


async def test_all_providers_fail(
    make_settings: Callable[..., Settings],
    llm_overrides: Callable[..., Any],
    fallback_overrides: dict[str, Any],
    request_obj: CoachRequest,
    openai_route: Any,
    fallback_route: Any,
) -> None:
    settings = make_settings(**llm_overrides(), **fallback_overrides)
    openai_route.mock(return_value=error_response(500))
    fallback_route.mock(return_value=error_response(401))

    with pytest.raises(LlmUnavailableError) as exc_info:
        await LlmClient(settings, backoff_seconds=0.0).generate(request_obj)
    error = exc_info.value
    assert error.last_provider == "openai_compatible"
    assert error.last_model == "fallback-model"
    assert len(error.attempted) == 2
    assert len(error.errors) == 2


async def test_no_provider_configured_raises(
    make_settings: Callable[..., Settings],
    request_obj: CoachRequest,
) -> None:
    settings = make_settings()
    with pytest.raises(LlmNotConfiguredError):
        await LlmClient(settings).generate(request_obj)


async def test_latency_budget_exhausted_before_call(
    make_settings: Callable[..., Settings],
    llm_overrides: Callable[..., Any],
    request_obj: CoachRequest,
) -> None:
    settings = make_settings(**llm_overrides(), llm_timeout_seconds=0.001)
    with pytest.raises(LlmUnavailableError):
        await LlmClient(settings).generate(request_obj)


def test_resolve_profiles_primary_then_fallback(
    make_settings: Callable[..., Settings],
    llm_overrides: Callable[..., Any],
    fallback_overrides: dict[str, Any],
) -> None:
    settings = make_settings(**llm_overrides(), **fallback_overrides)
    profiles = resolve_profiles(settings)
    assert [profile.model for profile in profiles] == ["test-model", "fallback-model"]
    assert "sk-test-secret-key-do-not-log" not in repr(profiles)


def test_resolve_profiles_skips_misconfigured(
    make_settings: Callable[..., Settings],
) -> None:
    assert resolve_profiles(make_settings()) == []


def test_primary_base_url_constant_matches_fixture() -> None:
    assert PRIMARY_BASE_URL.endswith("/v1")
    assert FALLBACK_BASE_URL.endswith("/v1")
