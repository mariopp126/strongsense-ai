"""Safety clamp for raw LLM coach plans (contract.md section 5).

The clamp is deliberately the *only* place where model output becomes a plan the app
may apply. It implements the contract bounds exactly:

* load delta: normal ``[-10, +5]``, deload ``[-40, 0]``; always rounded to 0.5
* sets delta: ``[-2, +2]``
* RPE cap: ``[6.5, 9.0]``, deload additionally ``<= 7.0``
* adjustments for exercises that are not in today's program are dropped
* pain rule: ``painSeverity >= 4`` + involved flagged joint => ``loadDeltaPct <= 0``
* tips: at most ``min(12, constraints.maxTips)``; title <= 80, body <= 480 (truncated)
* summary / readiness explanation <= 600 chars (truncated)
* flags: at most 8, each <= 160 chars (truncated)
* the disclaimer is always the server-owned constant.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from app.schemas import (
    DISCLAIMER,
    LOAD_DELTA_MAX_DELOAD,
    LOAD_DELTA_MAX_NORMAL,
    LOAD_DELTA_MIN_DELOAD,
    LOAD_DELTA_MIN_NORMAL,
    MAX_ADJUSTMENTS,
    MAX_EXPLANATION,
    MAX_FLAG_LEN,
    MAX_FLAGS,
    MAX_REASON,
    MAX_REPS_HINT,
    MAX_SUBSTITUTE,
    MAX_SUMMARY,
    MAX_TIP_BODY,
    MAX_TIP_TITLE,
    MAX_TIPS,
    RPE_CAP_MAX,
    RPE_CAP_MAX_DELOAD,
    RPE_CAP_MIN,
    SETS_DELTA_MAX,
    SETS_DELTA_MIN,
    Adjustment,
    CoachContext,
    CoachPlan,
    ModelAdjustment,
    ModelPlan,
    ModelTip,
    PainArea,
    PlanSource,
    ProgramExercise,
    Tip,
)

#: Lower-cased keyword fragments used to decide whether a lift involves a joint.
#: Deliberately heuristic and conservative: an unknown lift that matches no keyword
#: still gets the pain clamp when ``other`` is the flagged area.
_JOINT_KEYWORDS: dict[PainArea, tuple[str, ...]] = {
    PainArea.SHOULDER: (
        "bench",
        "press",
        "overhead",
        "ohp",
        "dip",
        "fly",
        "raise",
        "pulldown",
        "pull-down",
        "pull-up",
        "pullup",
        "push",
        "row",
    ),
    PainArea.ELBOW: (
        "curl",
        "pushdown",
        "push-down",
        "triceps",
        "skull",
        "extension",
        "bench",
        "press",
        "row",
        "pull",
    ),
    PainArea.WRIST: ("bench", "press", "curl", "wrist", "pushdown", "push-down", "row"),
    PainArea.KNEE: (
        "squat",
        "lunge",
        "leg press",
        "leg extension",
        "leg curl",
        "deadlift",
        "step-up",
        "split squat",
    ),
    PainArea.HIP: (
        "squat",
        "deadlift",
        "lunge",
        "hip",
        "leg press",
        "good morning",
        "thrust",
        "sumo",
    ),
    PainArea.LOWER_BACK: (
        "deadlift",
        "squat",
        "row",
        "good morning",
        "hinge",
        "thrust",
        "leg press",
        "overhead",
        "sumo",
    ),
}


@dataclass
class ClampReport:
    """What the clamp changed, for logging and ``meta``."""

    clamped: bool = False
    dropped_adjustments: int = 0
    clamps: list[str] = field(default_factory=list)

    def note(self, reason: str) -> None:
        """Record that the clamp changed something."""
        self.clamped = True
        self.clamps.append(reason)


def clamp_plan(plan: ModelPlan, context: CoachContext) -> tuple[CoachPlan, ClampReport]:
    """Clamp a raw model plan into a contract-valid ``CoachPlan``.

    Returns the plan and a report describing every change. The report's ``clamped``
    flag is what ends up in ``meta.clamped``.
    """
    report = ClampReport()
    deload = bool(plan.deload)
    load_min = LOAD_DELTA_MIN_DELOAD if deload else LOAD_DELTA_MIN_NORMAL
    load_max = LOAD_DELTA_MAX_DELOAD if deload else LOAD_DELTA_MAX_NORMAL
    rpe_ceiling = min(RPE_CAP_MAX, RPE_CAP_MAX_DELOAD) if deload else RPE_CAP_MAX

    rpe_cap = _clamp_rpe(plan.rpeCap, rpe_ceiling, report)
    adjustments = _clamp_adjustments(
        plan.adjustments,
        context,
        load_min=load_min,
        load_max=load_max,
        report=report,
    )
    tips = _clamp_tips(plan.tips, context.constraints.maxTips, report)
    flags = _clamp_flags(plan.flags, report)

    summary = _truncate(plan.summary, MAX_SUMMARY, "summary", report)
    explanation = _truncate(
        plan.readinessExplanation,
        MAX_EXPLANATION,
        "readinessExplanation",
        report,
    )

    clamped_plan = CoachPlan(
        source=PlanSource.LLM,
        summary=summary,
        readinessExplanation=explanation,
        rpeCap=rpe_cap,
        deload=deload,
        adjustments=adjustments,
        tips=tips,
        flags=flags,
        disclaimer=DISCLAIMER,
    )
    return clamped_plan, report


# ---------------------------------------------------------------------------
# Individual clamps
# ---------------------------------------------------------------------------


def _clamp_rpe(value: float, ceiling: float, report: ClampReport) -> float:
    rpe = float(value)
    if rpe < RPE_CAP_MIN:
        report.note(f"rpeCap raised from {rpe} to {RPE_CAP_MIN}")
        return RPE_CAP_MIN
    if rpe > ceiling:
        report.note(f"rpeCap clamped from {rpe} to {ceiling}")
        return ceiling
    return rpe


def _clamp_adjustments(
    adjustments: list[ModelAdjustment],
    context: CoachContext,
    *,
    load_min: float,
    load_max: float,
    report: ClampReport,
) -> list[Adjustment]:
    known = {exercise.id: exercise for exercise in context.programDay.exercises}
    pain_areas = list(context.checkIn.painAreas)
    pain_severity = context.checkIn.painSeverity
    result: list[Adjustment] = []

    for raw in adjustments:
        if len(result) >= MAX_ADJUSTMENTS:
            report.dropped_adjustments += 1
            report.note("extra adjustment dropped (more than 12)")
            continue
        exercise = known.get(raw.exerciseId)
        if exercise is None:
            report.dropped_adjustments += 1
            report.note(f"adjustment dropped for unknown exerciseId {raw.exerciseId!r}")
            continue

        load_delta = _round_load_delta(_clamp(raw.loadDeltaPct, load_min, load_max))
        if load_delta != float(raw.loadDeltaPct):
            report.note(
                f"loadDeltaPct for {raw.exerciseId!r} clamped from "
                f"{raw.loadDeltaPct} to {load_delta}"
            )
        if (
            pain_severity >= 4
            and load_delta > 0.0
            and _involves_flagged_joint(exercise, pain_areas)
        ):
            report.note(
                f"loadDeltaPct for {raw.exerciseId!r} clamped to 0.0 by the pain rule"
            )
            load_delta = 0.0

        sets_delta = int(_clamp(raw.setsDelta, SETS_DELTA_MIN, SETS_DELTA_MAX))
        if sets_delta != raw.setsDelta:
            report.note(
                f"setsDelta for {raw.exerciseId!r} clamped from {raw.setsDelta} to {sets_delta}"
            )

        reps_hint = _truncate_optional(
            raw.repsHint, MAX_REPS_HINT, f"repsHint for {raw.exerciseId!r}", report
        )
        reason = _truncate(
            raw.reason, MAX_REASON, f"reason for {raw.exerciseId!r}", report
        )
        substitute = _truncate_optional(
            raw.substituteWith,
            MAX_SUBSTITUTE,
            f"substituteWith for {raw.exerciseId!r}",
            report,
        )
        display_name = _truncate(
            raw.exercise.strip() or exercise.name, 160, "exercise display name", report
        )
        result.append(
            Adjustment(
                exerciseId=raw.exerciseId,
                exercise=display_name,
                loadDeltaPct=load_delta,
                setsDelta=sets_delta,
                repsHint=reps_hint,
                reason=reason,
                substituteWith=substitute,
            )
        )
    return result


def _clamp_tips(
    tips: list[ModelTip],
    max_tips: int,
    report: ClampReport,
) -> list[Tip]:
    limit = min(MAX_TIPS, max_tips)
    if len(tips) > limit:
        report.note(f"tips truncated from {len(tips)} to {limit}")
    result: list[Tip] = []
    for raw in tips[:limit]:
        title = _truncate(raw.title, MAX_TIP_TITLE, "tip title", report)
        body = _truncate(raw.body, MAX_TIP_BODY, "tip body", report)
        result.append(Tip(title=title, body=body, category=raw.category))
    return result


def _clamp_flags(flags: list[str], report: ClampReport) -> list[str]:
    if len(flags) > MAX_FLAGS:
        report.note(f"flags truncated from {len(flags)} to {MAX_FLAGS}")
    result: list[str] = []
    for flag in flags[:MAX_FLAGS]:
        text = _truncate(str(flag).strip(), MAX_FLAG_LEN, "flag", report)
        if text:
            result.append(text)
    return result


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def _round_load_delta(value: float) -> float:
    """Round to the nearest 0.5 using half-away-from-zero (Dart ``num.round``)."""
    if value == 0.0:
        return 0.0
    sign = -1.0 if value < 0 else 1.0
    return sign * math.floor(abs(value) * 2.0 + 0.5) / 2.0


def _truncate(text: str, limit: int, label: str, report: ClampReport) -> str:
    if len(text) <= limit:
        return text
    report.note(f"{label} truncated from {len(text)} to {limit} characters")
    return text[:limit]


def _truncate_optional(
    text: str | None,
    limit: int,
    label: str,
    report: ClampReport,
) -> str | None:
    if text is None:
        return None
    return _truncate(text, limit, label, report)


def _involves_flagged_joint(exercise: ProgramExercise, pain_areas: list[PainArea]) -> bool:
    """Heuristically decide whether ``exercise`` loads one of the painful joints."""
    if not pain_areas:
        return False
    if PainArea.OTHER in pain_areas:
        return True
    haystack = f"{exercise.id} {exercise.name} {exercise.role.value}".lower()
    for area in pain_areas:
        for keyword in _JOINT_KEYWORDS.get(area, ()):
            if keyword in haystack:
                return True
    return False
