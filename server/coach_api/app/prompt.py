"""Prompt construction for the coach LLM call.

The prompt is deliberately deterministic and compact: the model receives the full
(JSON) session context plus the app's baseline plan, and is asked for one strict JSON
object. The safety clamp runs after the model call, so the prompt asks for the
contract bounds but the server never trusts the answer.
"""

from __future__ import annotations

import json
from typing import Any

from app.schemas import (
    LOAD_DELTA_MAX_DELOAD,
    LOAD_DELTA_MAX_NORMAL,
    LOAD_DELTA_MIN_DELOAD,
    LOAD_DELTA_MIN_NORMAL,
    MAX_ADJUSTMENTS,
    MAX_EXPLANATION,
    MAX_FLAGS,
    MAX_SUMMARY,
    MAX_TIP_BODY,
    MAX_TIP_TITLE,
    MAX_TIPS,
    RPE_CAP_MAX,
    RPE_CAP_MAX_DELOAD,
    RPE_CAP_MIN,
    SETS_DELTA_MAX,
    SETS_DELTA_MIN,
    CoachRequest,
)

PROMPT_VERSION = 1

SYSTEM_PROMPT = f"""You are an expert strength coach for drug-free powerlifting and powerbuilding.
You write short, practical, evidence-based session adjustments for athletes who train
with a structured program. The athlete's app already decided the training program and
computed a deterministic baseline plan; your job is to enrich that plan with today's
load/set/effort adjustments and coaching tips.

Hard rules:
1. Reply with ONE JSON object and nothing else. No markdown fences, no prose before or
   after, no comments. Any other output is a protocol violation.
2. Write every user-facing string in the athlete's locale (BCP-47 language tag provided
   in the user message).
3. Never diagnose, treat or claim to be a medical professional. If the athlete reports
   pain, stay conservative, suggest lower load/volume or a safer substitution, and keep
   any medical statements general (no diagnosis, no treatment plan).
4. Only reference exercises by the exact exerciseId values present in programDay.
5. Respect the safety bounds:
   - loadDeltaPct: normal plans {LOAD_DELTA_MIN_NORMAL} to {LOAD_DELTA_MAX_NORMAL};
     deload plans {LOAD_DELTA_MIN_DELOAD} to {LOAD_DELTA_MAX_DELOAD}; round to 0.5.
   - setsDelta: {SETS_DELTA_MIN} to {SETS_DELTA_MAX} per exercise.
   - rpeCap: {RPE_CAP_MIN} to {RPE_CAP_MAX} (deload plans: at most {RPE_CAP_MAX_DELOAD}).
   - At most {MAX_TIPS} tips, title <= {MAX_TIP_TITLE} chars, body <= {MAX_TIP_BODY} chars.
   - summary and readinessExplanation <= {MAX_EXPLANATION} chars each.
   - At most {MAX_FLAGS} flags, each <= 160 chars.
   - At most {MAX_ADJUSTMENTS} adjustments.
6. Prefer small changes. When the readiness data is ambiguous, choose the option that is
   less likely to cause harm (lower load, lower RPE, fewer sets).
7. Set "deload" to true only when the training data (readiness band, missed sets, high
   soreness/pain, block position) indicates a deload is appropriate. A deload plan must
   reduce loads and cap RPE at {RPE_CAP_MAX_DELOAD}.

The response JSON object has exactly these keys:
{{
  "summary": string,
  "readinessExplanation": string,
  "rpeCap": number,
  "deload": boolean,
  "adjustments": [
    {{
      "exerciseId": string,
      "exercise": string,
      "loadDeltaPct": number,
      "setsDelta": integer,
      "repsHint": string | null,
      "reason": string,
      "substituteWith": string | null
    }}
  ],
  "tips": [{{ "title": string, "body": string, "category":
    "technique"|"recovery"|"nutrition"|"programming" }}],
  "flags": [string]
}}
Do not include a "disclaimer" field; the server supplies it. Do not include "source".
"""


def build_system_prompt(locale: str) -> str:
    """Return the system prompt with the requested locale made explicit."""
    return SYSTEM_PROMPT + f"\nAthlete locale (BCP-47): {locale}\n"


def build_messages(request: CoachRequest) -> list[dict[str, str]]:
    """Build the chat messages (system + user) for the coach LLM call."""
    return [
        {"role": "system", "content": build_system_prompt(request.locale)},
        {"role": "user", "content": build_user_prompt(request)},
    ]


def build_user_prompt(request: CoachRequest) -> str:
    """Build the user message: context + baseline plan + explicit task."""
    baseline_payload: dict[str, Any] | None = None
    if request.baselinePlan is not None:
        baseline_payload = request.baselinePlan.model_dump(mode="json")
        # The disclaimer is server-owned; never ask the model to reproduce it.
        baseline_payload.pop("disclaimer", None)
    payload: dict[str, Any] = {
        "task": "coach_plan",
        "contractVersion": request.contractVersion,
        "locale": request.locale,
        "context": request.context.model_dump(mode="json"),
        "baselinePlan": baseline_payload,
    }
    exercise_ids = [exercise.id for exercise in request.context.programDay.exercises]
    task = (
        f"Produce today's coaching JSON for locale '{request.locale}'. "
        "Allowed exerciseId values: "
        + (", ".join(exercise_ids) if exercise_ids else "(none)")
        + ". Use the baseline plan as the starting point when it is present. "
        f"Keep summary and readinessExplanation at most {MAX_SUMMARY} characters each, "
        f"at most {MAX_TIPS} tips, at most {MAX_FLAGS} flags and at most "
        f"{MAX_ADJUSTMENTS} adjustments. Respond with the JSON object only."
    )
    return (
        "SESSION CONTEXT AND BASELINE PLAN (JSON):\n"
        + json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        + "\n\nTASK:\n"
        + task
    )
