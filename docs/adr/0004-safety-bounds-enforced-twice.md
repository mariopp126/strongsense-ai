# ADR 0004 — Safety bounds are enforced twice

- Status: Accepted
- Date: 2026-11-13

## Context

LLM output is untrusted. A model can suggest a 25 % jump, six extra sets, an exercise
that is not in the session, or an RPE of 11. The app must never apply such a plan, even
if the server is compromised, misconfigured, or bypassed by a future client.

## Decision

Apply the same deterministic clamp in two places:

1. **Server** (`server/coach_api/app/safety.py`) — before the plan leaves the service.
2. **Client** (`packages/strongsense_core/lib/src/engines/safety_bounds.dart`) — before
   the app applies the plan.

The bounds live in [`docs/contract/contract.md`](../contract/contract.md) and are
verified against the same fixtures by both test suites, including the deliberately
unsafe [`unsafe-ai-output.example.json`](../contract/unsafe-ai-output.example.json).

The server also **owns the disclaimer text**; the model cannot supply it.

## Consequences

**Positive**

- A bad model response degrades to less detail, never to an unsafe session.
- The app is safe with a hostile or buggy server.
- The contract fixtures make drift a test failure.

**Negative**

- Two implementations to keep in sync.
- A server-side clamp can mask a model regression from telemetry.
- The client clamp adds a small amount of code to the app bundle.

## Rules of thumb

- Never let model output bypass `SafetyBounds.clamp`.
- Never let a model add or rename exercises.
- When pain is flagged, load never increases on the affected lift.
- When a deload is due, the model cannot cancel it.
