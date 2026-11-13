"""Safety clamp unit tests (contract section 5)."""

from __future__ import annotations

import json
from typing import Any

import pytest
from app.safety import (
    ClampReport,
    _involves_flagged_joint,
    _round_load_delta,
    clamp_plan,
)
from app.schemas import (
    DISCLAIMER,
    CoachContext,
    ModelAdjustment,
    ModelPlan,
    ModelTip,
    PainArea,
    ProgramExercise,
    Role,
    TipCategory,
)


def make_context(request_example: dict[str, Any]) -> CoachContext:
    return CoachContext.model_validate(json.loads(json.dumps(request_example["context"])))


def make_plan(response_example: dict[str, Any], **overrides: Any) -> ModelPlan:
    payload = {key: response_example["plan"][key] for key in (
        "summary",
        "readinessExplanation",
        "rpeCap",
        "deload",
        "adjustments",
        "tips",
        "flags",
    )}
    payload.update(overrides)
    return ModelPlan.model_validate(payload)


def make_adjustment(**overrides: Any) -> dict[str, Any]:
    values: dict[str, Any] = {
        "exerciseId": "ex-bench",
        "exercise": "Bench Press",
        "loadDeltaPct": 1.0,
        "setsDelta": 0,
        "repsHint": "5 reps",
        "reason": "test",
        "substituteWith": None,
    }
    values.update(overrides)
    return values


# ---------------------------------------------------------------------------
# Rounding / clamp helpers
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (0.0, 0.0),
        (1.0, 1.0),
        (1.25, 1.5),
        (-1.25, -1.5),
        (1.24, 1.0),
        (2.3, 2.5),
        (-2.3, -2.5),
        (0.1, 0.0),
        (-0.1, 0.0),
        (4.75, 5.0),
        (-9.75, -10.0),
    ],
)
def test_round_load_delta(value: float, expected: float) -> None:
    assert _round_load_delta(value) == expected


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


def test_safe_plan_is_unchanged(
    request_example: dict[str, Any],
    response_example: dict[str, Any],
) -> None:
    plan, report = clamp_plan(make_plan(response_example), make_context(request_example))
    assert report == ClampReport(clamped=False, dropped_adjustments=0, clamps=[])
    assert plan.rpeCap == 8.5
    assert plan.deload is False
    assert [a.exerciseId for a in plan.adjustments] == [
        "ex-bench",
        "ex-spoto",
        "ex-triceps-pushdown",
    ]
    assert plan.disclaimer == DISCLAIMER
    assert len(plan.tips) == 4


# ---------------------------------------------------------------------------
# Numeric clamps
# ---------------------------------------------------------------------------


def test_load_delta_normal_bounds_and_rounding(
    request_example: dict[str, Any],
) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            ModelAdjustment(exerciseId="ex-bench", exercise="Bench", loadDeltaPct=25.0),
            ModelAdjustment(exerciseId="ex-spoto", exercise="Spoto", loadDeltaPct=-50.0),
            ModelAdjustment(exerciseId="ex-cs-row", exercise="Row", loadDeltaPct=4.3),
        ],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert [a.loadDeltaPct for a in plan.adjustments] == [5.0, -10.0, 4.5]
    assert report.clamped is True


def test_sets_delta_clamped(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            ModelAdjustment(exerciseId="ex-bench", exercise="Bench", setsDelta=6),
            ModelAdjustment(exerciseId="ex-spoto", exercise="Spoto", setsDelta=-9),
        ],
    )
    plan, _ = clamp_plan(raw, make_context(request_example))
    assert [a.setsDelta for a in plan.adjustments] == [2, -2]


def test_rpe_cap_clamped_both_ways(request_example: dict[str, Any]) -> None:
    context = make_context(request_example)
    high = ModelPlan(summary="s", readinessExplanation="e", rpeCap=11.0)
    low = ModelPlan(summary="s", readinessExplanation="e", rpeCap=4.0)
    high_plan, high_report = clamp_plan(high, context)
    low_plan, low_report = clamp_plan(low, context)
    assert high_plan.rpeCap == 9.0
    assert low_plan.rpeCap == 6.5
    assert high_report.clamped is True
    assert low_report.clamped is True


# ---------------------------------------------------------------------------
# Unknown exercises / adjustment cap
# ---------------------------------------------------------------------------


def test_unknown_exercise_adjustment_dropped(
    request_example: dict[str, Any],
) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            make_adjustment_model(exerciseId="ex-does-not-exist"),
            make_adjustment_model(exerciseId="ex-bench"),
        ],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert [a.exerciseId for a in plan.adjustments] == ["ex-bench"]
    assert report.dropped_adjustments == 1
    assert any("unknown exerciseId" in entry for entry in report.clamps)


def make_adjustment_model(**overrides: Any) -> ModelAdjustment:
    return ModelAdjustment.model_validate(make_adjustment(**overrides))


def test_adjustment_count_capped_at_12(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[make_adjustment_model() for _ in range(13)],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert len(plan.adjustments) == 12
    assert report.dropped_adjustments == 1
    assert report.clamped is True


# ---------------------------------------------------------------------------
# Tips / flags / text
# ---------------------------------------------------------------------------


def test_tips_capped_by_context_constraints(
    request_example: dict[str, Any],
) -> None:
    context = make_context(request_example)
    context = context.model_copy(
        update={"constraints": context.constraints.model_copy(update={"maxTips": 3})}
    )
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        tips=[
            ModelTip(title=f"Tip {index}", body="body", category=TipCategory.TECHNIQUE)
            for index in range(5)
        ],
    )
    plan, report = clamp_plan(raw, context)
    assert len(plan.tips) == 3
    assert report.clamped is True


def test_tip_title_and_body_truncated(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        tips=[
            ModelTip(
                title="T" * 120,
                body="B" * 900,
                category=TipCategory.TECHNIQUE,
            )
        ],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert len(plan.tips[0].title) == 80
    assert len(plan.tips[0].body) == 480
    assert report.clamped is True


def test_summary_and_explanation_truncated(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="S" * 700,
        readinessExplanation="E" * 650,
        rpeCap=8.0,
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert len(plan.summary) == 600
    assert len(plan.readinessExplanation) == 600
    assert report.clamped is True


def test_flags_capped_and_truncated(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        flags=[f"{index}" + "x" * 200 for index in range(10)],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert len(plan.flags) == 8
    assert all(len(flag) == 160 for flag in plan.flags)
    assert report.clamped is True


def test_blank_flags_are_dropped(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(summary="s", readinessExplanation="e", rpeCap=8.0, flags=["", "  ", "ok"])
    plan, _ = clamp_plan(raw, make_context(request_example))
    # Whitespace-only flags survive truncation but empty strings are dropped by the
    # strict CoachPlan min_length; only the non-empty flag is kept.
    assert plan.flags == ["ok"]


def test_adjustment_text_fields_truncated(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            ModelAdjustment(
                exerciseId="ex-bench",
                exercise="X" * 300,
                loadDeltaPct=1.0,
                repsHint="R" * 100,
                reason="Z" * 300,
                substituteWith="S" * 100,
            )
        ],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    adjustment = plan.adjustments[0]
    assert len(adjustment.exercise) == 160
    assert len(adjustment.repsHint or "") == 80
    assert len(adjustment.reason) == 240
    assert len(adjustment.substituteWith or "") == 60
    assert report.clamped is True


def test_missing_display_name_falls_back_to_program_name(
    request_example: dict[str, Any],
) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[ModelAdjustment(exerciseId="ex-bench", exercise="", loadDeltaPct=1.0)],
    )
    plan, _ = clamp_plan(raw, make_context(request_example))
    assert plan.adjustments[0].exercise == "Bench Press"


# ---------------------------------------------------------------------------
# Pain rule
# ---------------------------------------------------------------------------


def test_pain_rule_clamps_involved_lifts(
    request_example: dict[str, Any],
) -> None:
    context = make_context(request_example)
    context = context.model_copy(
        update={
            "checkIn": context.checkIn.model_copy(
                update={"painAreas": [PainArea.SHOULDER], "painSeverity": 6}
            )
        }
    )
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            ModelAdjustment(exerciseId="ex-bench", exercise="Bench Press", loadDeltaPct=4.0),
            ModelAdjustment(
                exerciseId="ex-db-curl",
                exercise="Dumbbell Bicep Curls",
                loadDeltaPct=2.0,
            ),
            ModelAdjustment(exerciseId="ex-spoto", exercise="Spoto Press", loadDeltaPct=3.0),
        ],
    )
    plan, report = clamp_plan(raw, context)
    by_id = {adjustment.exerciseId: adjustment for adjustment in plan.adjustments}
    # Shoulder pain clamps pressing movements to no increase.
    assert by_id["ex-bench"].loadDeltaPct == 0.0
    assert by_id["ex-spoto"].loadDeltaPct == 0.0
    # A curl does not involve the shoulder, so its small increase stays.
    assert by_id["ex-db-curl"].loadDeltaPct == 2.0
    assert any("pain rule" in entry for entry in report.clamps)


def test_pain_rule_does_not_apply_below_severity_threshold(
    request_example: dict[str, Any],
) -> None:
    context = make_context(request_example)
    context = context.model_copy(
        update={
            "checkIn": context.checkIn.model_copy(
                update={"painAreas": [PainArea.SHOULDER], "painSeverity": 3}
            )
        }
    )
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            ModelAdjustment(exerciseId="ex-bench", exercise="Bench Press", loadDeltaPct=4.0)
        ],
    )
    plan, _ = clamp_plan(raw, context)
    assert plan.adjustments[0].loadDeltaPct == 4.0


def test_pain_rule_never_increases_load_for_other_area(
    request_example: dict[str, Any],
) -> None:
    context = make_context(request_example)
    context = context.model_copy(
        update={
            "checkIn": context.checkIn.model_copy(
                update={"painAreas": [PainArea.OTHER], "painSeverity": 8}
            )
        }
    )
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        adjustments=[
            ModelAdjustment(exerciseId="ex-bench", exercise="Bench Press", loadDeltaPct=4.0),
            ModelAdjustment(
                exerciseId="ex-cs-row",
                exercise="Chest-Supported Rows",
                loadDeltaPct=1.0,
            ),
        ],
    )
    plan, _ = clamp_plan(raw, context)
    assert all(adjustment.loadDeltaPct == 0.0 for adjustment in plan.adjustments)


def test_involves_flagged_joint_heuristics() -> None:
    bench = ProgramExercise(id="ex-bench", name="Bench Press", role=Role.MAIN)
    squat = ProgramExercise(id="ex-squat", name="Back Squat", role=Role.MAIN)
    curl = ProgramExercise(id="ex-curl", name="Dumbbell Curls", role=Role.ACCESSORY)
    unknown = ProgramExercise(id="ex-thing", name="Mystery Machine", role=Role.ACCESSORY)

    assert _involves_flagged_joint(bench, [PainArea.SHOULDER]) is True
    assert _involves_flagged_joint(bench, [PainArea.KNEE]) is False
    assert _involves_flagged_joint(squat, [PainArea.KNEE]) is True
    assert _involves_flagged_joint(squat, [PainArea.HIP]) is True
    assert _involves_flagged_joint(curl, [PainArea.ELBOW]) is True
    assert _involves_flagged_joint(curl, [PainArea.SHOULDER]) is False
    assert _involves_flagged_joint(unknown, [PainArea.OTHER]) is True
    assert _involves_flagged_joint(unknown, [PainArea.KNEE]) is False
    assert _involves_flagged_joint(bench, []) is False


# ---------------------------------------------------------------------------
# Deload rule
# ---------------------------------------------------------------------------


def test_deload_bounds_and_rpe_ceiling(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="Deload week.",
        readinessExplanation="Recovery week.",
        rpeCap=9.5,
        deload=True,
        adjustments=[
            ModelAdjustment(exerciseId="ex-bench", exercise="Bench", loadDeltaPct=3.0),
            ModelAdjustment(exerciseId="ex-spoto", exercise="Spoto", loadDeltaPct=-25.4),
        ],
    )
    plan, report = clamp_plan(raw, make_context(request_example))
    assert plan.deload is True
    assert plan.rpeCap == 7.0
    assert plan.adjustments[0].loadDeltaPct == 0.0
    assert plan.adjustments[1].loadDeltaPct == -25.5
    assert report.clamped is True
    # The result remains contract valid with the deload bounds.
    assert all(-40.0 <= adjustment.loadDeltaPct <= 0.0 for adjustment in plan.adjustments)


def test_deload_rpe_lower_bound(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(summary="s", readinessExplanation="e", rpeCap=5.0, deload=True)
    plan, _ = clamp_plan(raw, make_context(request_example))
    assert plan.rpeCap == 6.5


def test_deload_false_allows_positive_loads(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=9.0,
        deload=False,
        adjustments=[ModelAdjustment(exerciseId="ex-bench", exercise="Bench", loadDeltaPct=5.0)],
    )
    plan, _ = clamp_plan(raw, make_context(request_example))
    assert plan.adjustments[0].loadDeltaPct == 5.0
    assert plan.rpeCap == 9.0


# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------


def test_disclaimer_is_always_server_owned(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(
        summary="s",
        readinessExplanation="e",
        rpeCap=8.0,
        disclaimer="I am a doctor and this is medical advice.",  # type: ignore[call-arg]
    )
    plan, _ = clamp_plan(raw, make_context(request_example))
    assert plan.disclaimer == DISCLAIMER


def test_empty_plan_is_valid(request_example: dict[str, Any]) -> None:
    raw = ModelPlan(summary="", readinessExplanation="", rpeCap=8.0)
    plan, report = clamp_plan(raw, make_context(request_example))
    assert plan.adjustments == []
    assert plan.tips == []
    assert plan.flags == []
    assert report.clamped is False
