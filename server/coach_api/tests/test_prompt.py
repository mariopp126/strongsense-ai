"""Prompt construction."""

from __future__ import annotations

import json
from typing import Any

from app.prompt import PROMPT_VERSION, build_messages, build_system_prompt, build_user_prompt
from app.schemas import CoachRequest


def test_build_messages_shape(request_example: dict[str, Any]) -> None:
    request = CoachRequest.model_validate(request_example)
    messages = build_messages(request)
    assert len(messages) == 2
    assert messages[0]["role"] == "system"
    assert messages[1]["role"] == "user"
    assert PROMPT_VERSION == 1


def test_system_prompt_contains_contract_rules() -> None:
    system = build_system_prompt("es")
    assert "JSON object" in system
    assert "powerlifting" in system
    assert "deload" in system
    assert "not medical advice" not in system
    assert "Athlete locale (BCP-47): es" in system
    assert "-10.0" in system and "5.0" in system
    assert "-40.0" in system and "0.0" in system
    assert "6.5" in system and "9.0" in system


def test_user_prompt_contains_context_and_baseline(request_example: dict[str, Any]) -> None:
    request = CoachRequest.model_validate(request_example)
    user = build_user_prompt(request)
    assert user.startswith("SESSION CONTEXT AND BASELINE PLAN (JSON):")
    payload_text = user.split("\n\nTASK:")[0].split("\n", 1)[1]
    payload = json.loads(payload_text)
    assert payload["task"] == "coach_plan"
    assert payload["contractVersion"] == 1
    assert payload["locale"] == "en"
    assert payload["context"]["programDay"]["id"] == "day-2"
    assert payload["context"]["checkIn"]["sleepHours"] == 7.5
    assert payload["baselinePlan"]["source"] == "rules"
    assert payload["baselinePlan"]["deload"] is False
    # The task lists allowed exercise ids.
    assert "ex-bench" in user
    assert "Respond with the JSON object only." in user


def test_user_prompt_without_baseline(request_example: dict[str, Any]) -> None:
    request_example = json.loads(json.dumps(request_example))
    del request_example["baselinePlan"]
    request = CoachRequest.model_validate(request_example)
    user = build_user_prompt(request)
    payload = json.loads(user.split("\n\nTASK:")[0].split("\n", 1)[1])
    assert payload["baselinePlan"] is None
    assert "Use the baseline plan as the starting point when it is present." in user


def test_prompt_is_deterministic(request_example: dict[str, Any]) -> None:
    request = CoachRequest.model_validate(request_example)
    assert build_messages(request) == build_messages(request)


def test_prompt_contains_no_disclaimer_text(request_example: dict[str, Any]) -> None:
    request = CoachRequest.model_validate(request_example)
    user = build_user_prompt(request)
    messages = build_messages(request)
    rendered = "\n".join(message["content"] for message in messages)
    # The model never receives the server-owned disclaimer as a template.
    assert "StrongSense AI provides general training guidance" not in rendered
    payload = json.loads(user.split("\n\nTASK:")[0].split("\n", 1)[1])
    assert "disclaimer" not in payload["baselinePlan"]
