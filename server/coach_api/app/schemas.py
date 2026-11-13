"""Pydantic v2 models for the StrongSense Coach API contract, version 1.

The JSON wire names in ``docs/contract/contract.md`` are camelCase and are used
verbatim as Python field names so that serialization needs no aliases.

Two families of models live here:

* Request/response models (``CoachRequest``, ``CoachContext``, ``CoachPlan``, ...)
  are strict: unknown fields are forbidden and every documented numeric range and
  string length is enforced at the boundary.
* ``ModelPlan`` is the *raw* LLM output model. It is intentionally permissive about
  numeric ranges and text lengths because the safety clamp in ``app.safety`` must
  see out-of-range values and fix them instead of rejecting the model's answer.
"""

from __future__ import annotations

from datetime import date
from enum import StrEnum
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field, model_validator

CONTRACT_VERSION = 1
SERVICE_NAME = "strongsense-coach-api"
SERVICE_VERSION = "0.1.0"

#: Server-owned disclaimer. Model output never supplies this text and the safety
#: clamp always overwrites whatever the LLM wrote.
DISCLAIMER = (
    "StrongSense AI provides general training guidance, not medical advice. "
    "Stop and seek professional care if you feel sharp pain, numbness or a joint gives way."
)

# Hard contract bounds (contract.md section 5).
LOAD_DELTA_MIN_NORMAL = -10.0
LOAD_DELTA_MAX_NORMAL = 5.0
LOAD_DELTA_MIN_DELOAD = -40.0
LOAD_DELTA_MAX_DELOAD = 0.0
RPE_CAP_MIN = 6.5
RPE_CAP_MAX = 9.0
RPE_CAP_MAX_DELOAD = 7.0
SETS_DELTA_MIN = -2
SETS_DELTA_MAX = 2
MAX_TIPS = 12
MAX_TIP_TITLE = 80
MAX_TIP_BODY = 480
MAX_SUMMARY = 600
MAX_EXPLANATION = 600
MAX_FLAGS = 8
MAX_FLAG_LEN = 160
MAX_ADJUSTMENTS = 12
MAX_REPS_HINT = 80
MAX_REASON = 240
MAX_SUBSTITUTE = 60


class Unit(StrEnum):
    """Display unit; all loads are kilograms on the wire."""

    KG = "kg"
    LB = "lb"


class Role(StrEnum):
    """Training role of an exercise inside a program day."""

    MAIN = "main"
    VARIATION = "variation"
    ACCESSORY = "accessory"


class ReadinessBand(StrEnum):
    """Readiness traffic-light band."""

    GREEN = "green"
    AMBER = "amber"
    ORANGE = "orange"
    RED = "red"


class SessionClassification(StrEnum):
    """How a completed session felt."""

    EASY = "easy"
    NORMAL = "normal"
    HARD = "hard"
    NONE = "none"


class PlanSource(StrEnum):
    """Where a coach plan came from."""

    RULES = "rules"
    LLM = "llm"
    RULES_FALLBACK = "rules_fallback"


class TipCategory(StrEnum):
    """Coach tip category."""

    TECHNIQUE = "technique"
    RECOVERY = "recovery"
    NUTRITION = "nutrition"
    PROGRAMMING = "programming"


class PainArea(StrEnum):
    """Body area the athlete flagged as painful during check-in."""

    LOWER_BACK = "lower_back"
    KNEE = "knee"
    SHOULDER = "shoulder"
    ELBOW = "elbow"
    WRIST = "wrist"
    HIP = "hip"
    OTHER = "other"


# ---------------------------------------------------------------------------
# Base classes
# ---------------------------------------------------------------------------


class StrictModel(BaseModel):
    """Base model for every contract payload: unknown fields are rejected."""

    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------------------
# Request: CoachContext (contract.md section 3)
# ---------------------------------------------------------------------------


class SetTarget(StrictModel):
    """One prescribed set of an exercise."""

    reps: int = Field(ge=1, le=100)
    repsMax: int | None = Field(default=None, ge=1, le=100)
    loadKg: float | None = Field(default=None, ge=0.0)
    rpeCap: float | None = Field(default=None, ge=0.0, le=10.0)

    @model_validator(mode="after")
    def _validate_reps_range(self) -> SetTarget:
        if self.repsMax is not None and self.repsMax < self.reps:
            raise ValueError("repsMax must be greater than or equal to reps")
        return self


class ProgramExercise(StrictModel):
    """An exercise inside the athlete's program day."""

    id: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=160)
    role: Role
    setTargets: list[SetTarget] = Field(default_factory=list, max_length=20)


class ProgramDay(StrictModel):
    """The session the athlete is about to train."""

    id: str = Field(min_length=1, max_length=80)
    title: str = Field(min_length=1, max_length=160)
    exercises: list[ProgramExercise] = Field(default_factory=list, max_length=30)

    @model_validator(mode="after")
    def _validate_unique_exercise_ids(self) -> ProgramDay:
        ids = [exercise.id for exercise in self.exercises]
        if len(ids) != len(set(ids)):
            raise ValueError("programDay.exercises[].id values must be unique")
        return self


class CheckIn(StrictModel):
    """Subjective readiness check-in for today's session."""

    sleepQuality: int = Field(ge=1, le=5)
    sleepHours: float = Field(ge=0.0, le=14.0)
    energy: int = Field(ge=1, le=5)
    motivation: int = Field(ge=1, le=5)
    soreness: int = Field(ge=1, le=5)
    stress: int = Field(ge=1, le=5)
    painAreas: list[PainArea] = Field(default_factory=list, max_length=7)
    painSeverity: int = Field(ge=0, le=10)
    timeAvailableMin: int = Field(ge=10, le=240)


class Readiness(StrictModel):
    """Deterministic readiness score computed by the app."""

    score: float = Field(ge=0.0, le=100.0)
    band: ReadinessBand
    components: dict[str, float] = Field(default_factory=dict)

    @model_validator(mode="after")
    def _validate_components(self) -> Readiness:
        if len(self.components) > 20:
            raise ValueError("readiness.components must contain at most 20 entries")
        for key, value in self.components.items():
            if len(key) > 60:
                raise ValueError("readiness.components keys must be at most 60 characters")
            if not 0.0 <= value <= 100.0:
                raise ValueError("readiness.components values must be between 0 and 100")
        return self


class LiftResult(StrictModel):
    """Per-lift result of the last session."""

    exerciseId: str = Field(min_length=1, max_length=80)
    topSetKg: float = Field(ge=0.0)
    topSetReps: int = Field(ge=1, le=100)
    topSetRpe: float = Field(ge=0.0, le=10.0)
    e1rmKg: float = Field(ge=0.0)
    missedSets: int = Field(ge=0, le=20)


class LastSession(StrictModel):
    """The most recently completed session (if any)."""

    date: date
    classification: SessionClassification
    perLift: list[LiftResult] = Field(default_factory=list, max_length=20)


class RecentSession(StrictModel):
    """A compact summary of one of the last sessions."""

    date: date
    dayId: str = Field(min_length=1, max_length=80)
    classification: SessionClassification
    avgRpe: float = Field(ge=0.0, le=10.0)
    volumeKg: float = Field(ge=0.0)
    missedSets: int = Field(ge=0, le=50)


class PersonalRecord(StrictModel):
    """Best estimated one-rep max for a lift."""

    exerciseId: str = Field(min_length=1, max_length=80)
    e1rmKg: float = Field(ge=0.0)
    date: date


class Increments(StrictModel):
    """Smallest sensible load jump per lift family, in kilograms."""

    benchKg: float = Field(ge=0.0, le=100.0)
    squatKg: float = Field(ge=0.0, le=100.0)
    deadliftKg: float = Field(ge=0.0, le=100.0)
    accessoryKg: float = Field(ge=0.0, le=100.0)


class ContextSettings(StrictModel):
    """Athlete settings snapshot included in the context."""

    unit: Unit
    increments: Increments


class Constraints(StrictModel):
    """Clamping constraints the client asks the server to respect.

    The client sends the contract bounds from section 5. The server may only ever
    tighten them, never widen them.
    """

    maxLoadDeltaPct: float = Field(default=LOAD_DELTA_MAX_NORMAL, ge=0.0, le=5.0)
    minLoadDeltaPct: float = Field(default=LOAD_DELTA_MIN_NORMAL, ge=-40.0, le=0.0)
    maxSetsDelta: int = Field(default=SETS_DELTA_MAX, ge=0, le=2)
    rpeCapMax: float = Field(default=RPE_CAP_MAX, ge=RPE_CAP_MIN, le=RPE_CAP_MAX)
    maxTips: int = Field(default=MAX_TIPS, ge=1, le=MAX_TIPS)


class CoachContext(StrictModel):
    """Everything the coach service knows about today's session.

    Contains training data only: no names, emails or device identifiers.
    """

    date: date
    blockWeek: int = Field(ge=1, le=52)
    unit: Unit
    programDay: ProgramDay
    checkIn: CheckIn
    readiness: Readiness
    lastSession: LastSession | None = None
    recentSessions: list[RecentSession] = Field(default_factory=list, max_length=6)
    personalRecords: list[PersonalRecord] = Field(default_factory=list, max_length=50)
    settings: ContextSettings
    constraints: Constraints


# ---------------------------------------------------------------------------
# CoachPlan (contract.md section 4)
# ---------------------------------------------------------------------------


class Adjustment(StrictModel):
    """One exercise-level adjustment proposed by the coach."""

    exerciseId: str = Field(min_length=1, max_length=80)
    exercise: str = Field(min_length=1, max_length=160)
    loadDeltaPct: float = Field(ge=LOAD_DELTA_MIN_DELOAD, le=LOAD_DELTA_MAX_NORMAL)
    setsDelta: int = Field(ge=SETS_DELTA_MIN, le=SETS_DELTA_MAX)
    repsHint: str | None = Field(default=None, max_length=MAX_REPS_HINT)
    reason: str = Field(default="", max_length=MAX_REASON)
    substituteWith: str | None = Field(default=None, max_length=MAX_SUBSTITUTE)


class Tip(StrictModel):
    """A short, actionable coaching tip."""

    title: str = Field(min_length=1, max_length=MAX_TIP_TITLE)
    body: str = Field(min_length=1, max_length=MAX_TIP_BODY)
    category: TipCategory


Flag = Annotated[str, Field(min_length=1, max_length=MAX_FLAG_LEN)]


class CoachPlan(StrictModel):
    """A normalized, safety-clamped plan ready to be applied by the app.

    ``deload`` selects the safety bounds: normal plans clamp load deltas into
    ``[-10, +5]``; deload plans clamp them into ``[-40, 0]`` and force ``rpeCap <= 7``.
    """

    source: PlanSource
    summary: str = Field(default="", max_length=MAX_SUMMARY)
    readinessExplanation: str = Field(default="", max_length=MAX_EXPLANATION)
    rpeCap: float = Field(ge=RPE_CAP_MIN, le=RPE_CAP_MAX)
    deload: bool = False
    adjustments: list[Adjustment] = Field(default_factory=list, max_length=MAX_ADJUSTMENTS)
    tips: list[Tip] = Field(default_factory=list, max_length=MAX_TIPS)
    flags: list[Flag] = Field(default_factory=list, max_length=MAX_FLAGS)
    disclaimer: str = Field(default=DISCLAIMER, max_length=MAX_EXPLANATION)

    @model_validator(mode="after")
    def _validate_deload_bounds(self) -> CoachPlan:
        load_min = LOAD_DELTA_MIN_DELOAD if self.deload else LOAD_DELTA_MIN_NORMAL
        load_max = LOAD_DELTA_MAX_DELOAD if self.deload else LOAD_DELTA_MAX_NORMAL
        if self.deload and self.rpeCap > RPE_CAP_MAX_DELOAD:
            raise ValueError(f"deload rpeCap must be at most {RPE_CAP_MAX_DELOAD}")
        for adjustment in self.adjustments:
            if not load_min <= adjustment.loadDeltaPct <= load_max:
                raise ValueError(
                    "loadDeltaPct must be within "
                    f"[{load_min}, {load_max}] when deload={self.deload}"
                )
            if not _is_half_step(adjustment.loadDeltaPct):
                raise ValueError("loadDeltaPct must be rounded to 0.5")
        return self


def _is_half_step(value: float) -> bool:
    """Return True when ``value`` is a multiple of 0.5 (within float tolerance)."""
    doubled = value * 2.0
    return abs(doubled - round(doubled)) < 1e-9


# ---------------------------------------------------------------------------
# Raw LLM output (deliberately permissive; clamped by app.safety)
# ---------------------------------------------------------------------------


class ModelAdjustment(BaseModel):
    """Raw adjustment returned by an LLM; ranges are clamped afterwards."""

    model_config = ConfigDict(extra="ignore")

    exerciseId: str = ""
    exercise: str = ""
    loadDeltaPct: float = 0.0
    setsDelta: int = 0
    repsHint: str | None = None
    reason: str = ""
    substituteWith: str | None = None


class ModelTip(BaseModel):
    """Raw tip returned by an LLM; lengths and counts are clamped afterwards."""

    model_config = ConfigDict(extra="ignore")

    title: str = ""
    body: str = ""
    category: TipCategory


class ModelPlan(BaseModel):
    """Raw JSON object an LLM is asked to return (before validation/clamping)."""

    model_config = ConfigDict(extra="ignore")

    summary: str
    readinessExplanation: str
    rpeCap: float
    deload: bool = False
    adjustments: list[ModelAdjustment] = Field(default_factory=list)
    tips: list[ModelTip] = Field(default_factory=list)
    flags: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Envelope, meta and health
# ---------------------------------------------------------------------------


class CoachRequest(StrictModel):
    """Request body of ``POST /v1/coach/plan``."""

    contractVersion: int
    locale: str = Field(default="en", min_length=2, max_length=35)
    context: CoachContext
    baselinePlan: CoachPlan | None = None
    forceRules: bool = False


class Meta(StrictModel):
    """Diagnostics about how the returned plan was produced."""

    provider: str = Field(default="", max_length=80)
    model: str = Field(default="", max_length=160)
    latencyMs: int = Field(ge=0)
    clamped: bool
    droppedAdjustments: int = Field(ge=0)


class CoachResponse(StrictModel):
    """Successful response body of ``POST /v1/coach/plan``."""

    contractVersion: int = CONTRACT_VERSION
    source: PlanSource
    plan: CoachPlan
    meta: Meta

    @model_validator(mode="after")
    def _validate_source_matches_plan(self) -> CoachResponse:
        if self.plan.source is not self.source:
            raise ValueError("plan.source must equal the envelope source")
        return self


class ProviderInfo(StrictModel):
    """A configured LLM provider as reported by ``GET /health`` (never keys)."""

    name: str = Field(min_length=1, max_length=80)
    model: str = Field(min_length=1, max_length=160)


class Health(BaseModel):
    """Response body of ``GET /health``."""

    model_config = ConfigDict(extra="forbid")

    status: str = "ok"
    service: str = SERVICE_NAME
    version: str = SERVICE_VERSION
    contractVersion: int = CONTRACT_VERSION
    llmConfigured: bool
    providers: list[ProviderInfo] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ValidationIssue = dict[str, Any]


def validation_issues(error: Any) -> list[ValidationIssue]:
    """Summarize a Pydantic/FastAPI validation error without echoing values."""
    issues: list[ValidationIssue] = []
    for item in error.errors():
        issues.append(
            {
                "loc": ".".join(str(part) for part in item.get("loc", ())),
                "type": str(item.get("type", "value_error")),
                "msg": str(item.get("msg", "invalid value")),
            }
        )
    return issues
