# ADR 0003 — Rules-first coaching with an optional Python AI proxy

- Status: Accepted
- Date: 2026-11-13

## Context

The product promises AI tips and adaptive training. An LLM-only design would require
internet, a key and money for every session, and would produce inconsistent or unsafe
numbers. A rules-only design cannot produce rich, contextual coaching language.

## Decision

1. **Deterministic logic lives in the app** (`packages/strongsense_core`). Readiness,
   matrix, deload, progression and safety bounds always produce a complete plan offline.
2. **The AI is an enrichment layer** behind a **Python/FastAPI** proxy. The app sends the
   structured context plus its baseline plan; the service prompts an LLM, validates the
   JSON and returns a plan.
3. **The provider is swappable** (any OpenAI-compatible endpoint or native Anthropic) and
   the key never leaves the server.

## Consequences

**Positive**

- Training is free, instant, private and works without a key.
- AI quality can improve without touching training correctness.
- No provider lock-in; fallback provider supported.

**Negative**

- Two languages to maintain (Dart + Python).
- The safety clamp exists in both languages; shared fixtures are required to prevent drift.
- The user must run or deploy a small service to use AI features.

## Why not a Dart server?

Keeping one language would be nice, but Python/FastAPI has the strongest LLM tooling and
the maintainer requested it. The server has no training rules, so the duplication is
limited to validation and clamping.
