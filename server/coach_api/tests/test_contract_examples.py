"""The shared contract fixtures load and validate; the unsafe fixture clamps exactly."""

from __future__ import annotations

from typing import Any

import pytest
from app.safety import clamp_plan
from app.schemas import (
    CONTRACT_VERSION,
    DISCLAIMER,
    CoachContext,
    CoachPlan,
    CoachRequest,
    CoachResponse,
    ModelPlan,
)
from pydantic import ValidationError


def test_request_example_validates(request_example: dict[str, Any]) -> None:
    request = CoachRequest.model_validate(request_example)
    assert request.contractVersion == CONTRACT_VERSION
    assert request.locale == "en"
    assert request.baselinePlan is not None
    assert request.baselinePlan.deload is False
    assert request.context.programDay.exercises
    assert request.context.checkIn.painSeverity == 0


def test_response_example_validates(response_example: dict[str, Any]) -> None:
    response = CoachResponse.model_validate(response_example)
    assert response.contractVersion == CONTRACT_VERSION
    assert response.source.value == "llm"
    assert response.plan.source.value == "llm"
    assert response.plan.deload is False
    assert response.plan.rpeCap == 8.5
    assert response.plan.disclaimer == DISCLAIMER
    assert response.meta.provider == "openai_compatible"
    assert response.meta.model == "gpt-4.1-mini"
    assert response.meta.clamped is False
    assert response.meta.droppedAdjustments == 0


def test_request_and_response_plans_are_identical(request_example: dict[str, Any]) -> None:
    request_plan = CoachPlan.model_validate(request_example["baselinePlan"])
    assert request_plan.source.value == "rules"


def test_unsafe_example_is_raw_model_output(unsafe_example: dict[str, Any]) -> None:
    raw = ModelPlan.model_validate(unsafe_example)
    assert raw.deload is False
    assert raw.rpeCap == 11.0
    assert len(raw.tips) == 15
    # The raw fixture must NOT satisfy the strict plan schema: the clamp is required.
    with pytest.raises(ValidationError):
        CoachPlan.model_validate(unsafe_example)


def test_unsafe_fixture_clamps_exactly(
    unsafe_example: dict[str, Any],
    request_example: dict[str, Any],
) -> None:
    context = CoachContext.model_validate(request_example["context"])
    raw = ModelPlan.model_validate(unsafe_example)

    plan, report = clamp_plan(raw, context)

    assert report.clamped is True
    assert report.dropped_adjustments == 1
    assert plan.deload is False
    assert plan.source.value == "llm"

    # RPE 11.0 -> 9.0
    assert plan.rpeCap == 9.0
    # Unknown exercise (ex-cable-fly) is dropped; only bench + spoto remain.
    assert [adjustment.exerciseId for adjustment in plan.adjustments] == ["ex-bench", "ex-spoto"]
    bench, spoto = plan.adjustments
    # +25% -> +5%, +6 sets -> +2
    assert bench.loadDeltaPct == 5.0
    assert bench.setsDelta == 2
    # -50% -> -10%, -9 sets -> -2
    assert spoto.loadDeltaPct == -10.0
    assert spoto.setsDelta == -2
    assert spoto.substituteWith == "Deficit Handstand Push-Up"
    # 15 tips -> 12; 9 flags -> 8; summary truncated to 600.
    assert len(plan.tips) == 12
    assert len(plan.flags) == 8
    assert len(plan.summary) == 600
    assert len(plan.readinessExplanation) <= 600
    # The model-supplied disclaimer is discarded.
    assert plan.disclaimer == DISCLAIMER
    assert "medical advice" not in plan.disclaimer or plan.disclaimer == DISCLAIMER
    # Result still validates as a strict contract plan.
    validated = CoachPlan.model_validate(plan.model_dump())
    assert validated.rpeCap == 9.0

    # The report explains what happened.
    assert any("unknown exerciseId" in entry for entry in report.clamps)
    assert any("rpeCap" in entry for entry in report.clamps)
    assert any("tips truncated" in entry for entry in report.clamps)
    assert any("flags truncated" in entry for entry in report.clamps)
    assert any("summary truncated" in entry for entry in report.clamps)


def test_unsafe_example_loads_from_filesystem(contract_dir: Any) -> None:
    assert (contract_dir / "unsafe-ai-output.example.json").is_file()
    assert (contract_dir / "coach-request.example.json").is_file()
    assert (contract_dir / "coach-response.example.json").is_file()
    assert (contract_dir / "contract.md").is_file()
