"""Coach orchestration: request -> LLM -> validation -> safety clamp -> response.

The service is stateless. It never persists anything and it never invents training
rules: it enriches the app's deterministic baseline with an LLM plan, clamps it, and
falls back to the baseline when the provider is unavailable.
"""

from __future__ import annotations

import time
from typing import Any

from app.config import Settings
from app.llm import (
    LlmClient,
    LlmNotConfiguredError,
    LlmUnavailableError,
)
from app.safety import clamp_plan
from app.schemas import (
    CONTRACT_VERSION,
    DISCLAIMER,
    CoachPlan,
    CoachRequest,
    CoachResponse,
    Meta,
    PlanSource,
)

LLM_NOT_CONFIGURED_MESSAGE = "The AI coach is not configured on this server."
LLM_UNAVAILABLE_MESSAGE = "The AI coach is temporarily unavailable."


class CoachError(Exception):
    """An error that maps directly onto the contract error table."""

    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


async def generate_plan(
    request: CoachRequest,
    settings: Settings,
    diagnostics: dict[str, Any] | None = None,
) -> CoachResponse:
    """Produce the coach response for one request.

    ``diagnostics`` is an optional out-dict the HTTP layer uses for structured
    logging (provider/model/token usage). It never contains request data or keys.
    """
    baseline = request.baselinePlan

    if request.forceRules:
        if baseline is None:
            raise CoachError(
                status_code=400,
                code="invalid_request",
                message="forceRules requires a baselinePlan in the request body.",
            )
        plan = _with_source(baseline, PlanSource.RULES)
        _set_diagnostics(diagnostics, provider="rules", model="rules", source=PlanSource.RULES)
        return CoachResponse(
            contractVersion=CONTRACT_VERSION,
            source=PlanSource.RULES,
            plan=plan,
            meta=Meta(
                provider="rules",
                model="rules",
                latencyMs=0,
                clamped=False,
                droppedAdjustments=0,
            ),
        )

    if not settings.llm_configured:
        raise CoachError(
            status_code=503,
            code="llm_not_configured",
            message=LLM_NOT_CONFIGURED_MESSAGE,
        )

    started = time.perf_counter()
    try:
        result = await LlmClient(settings).generate(request)
    except LlmNotConfiguredError as exc:  # defensive: settings said configured
        raise CoachError(
            status_code=503,
            code="llm_not_configured",
            message=LLM_NOT_CONFIGURED_MESSAGE,
        ) from exc
    except LlmUnavailableError as exc:
        provider = exc.last_provider or "unknown"
        model = exc.last_model or "unknown"
        latency_ms = int((time.perf_counter() - started) * 1000)
        _set_diagnostics(
            diagnostics,
            provider=provider,
            model=model,
            source=PlanSource.RULES_FALLBACK,
        )
        if baseline is None:
            raise CoachError(
                status_code=503,
                code="llm_unavailable",
                message=LLM_UNAVAILABLE_MESSAGE,
            ) from exc
        plan = _with_source(baseline, PlanSource.RULES_FALLBACK)
        return CoachResponse(
            contractVersion=CONTRACT_VERSION,
            source=PlanSource.RULES_FALLBACK,
            plan=plan,
            meta=Meta(
                provider=provider,
                model=model,
                latencyMs=latency_ms,
                clamped=False,
                droppedAdjustments=0,
            ),
        )

    plan, report = clamp_plan(result.plan, request.context)
    plan = _with_source(plan, PlanSource.LLM)
    latency_ms = result.latency_ms
    if latency_ms <= 0:
        latency_ms = int((time.perf_counter() - started) * 1000)
    _set_diagnostics(
        diagnostics,
        provider=result.provider,
        model=result.model,
        promptTokens=result.usage.prompt_tokens,
        completionTokens=result.usage.completion_tokens,
        totalTokens=result.usage.total_tokens,
        source=PlanSource.LLM,
        clamped=report.clamped,
        droppedAdjustments=report.dropped_adjustments,
    )
    return CoachResponse(
        contractVersion=CONTRACT_VERSION,
        source=PlanSource.LLM,
        plan=plan,
        meta=Meta(
            provider=result.provider,
            model=result.model,
            latencyMs=latency_ms,
            clamped=report.clamped,
            droppedAdjustments=report.dropped_adjustments,
        ),
    )


def _with_source(plan: CoachPlan, source: PlanSource) -> CoachPlan:
    """Return a copy of ``plan`` with the requested source and server disclaimer.

    ``disclaimer`` is always server-owned, even for baseline plans coming back from
    the client. ``model_copy`` is used so that unrelated payload fields survive.
    """
    return plan.model_copy(update={"source": source, "disclaimer": DISCLAIMER})


def _set_diagnostics(diagnostics: dict[str, Any] | None, **values: Any) -> None:
    if diagnostics is not None:
        diagnostics.update({key: value for key, value in values.items() if value is not None})


__all__ = ["CoachError", "LLM_NOT_CONFIGURED_MESSAGE", "LLM_UNAVAILABLE_MESSAGE", "generate_plan"]
