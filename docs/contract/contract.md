# Coach API Contract — v1

The app and the Python coach service exchange JSON over HTTP. This document is the
single source of truth. Shared example payloads live next to it and are loaded by
**both** the Dart and Python test suites, so the two implementations cannot drift
silently.

- Contract version: **1**
- Service: `server/coach_api` (FastAPI)
- Content type: `application/json; charset=utf-8`
- Base URL (local): `http://127.0.0.1:8080`

## 1. Principles

1. **Offline-first.** The Flutter app always computes a deterministic `baselinePlan`
   locally and can train with the server off.
2. **AI enriches, rules decide.** The server never invents training progression rules;
   it asks an LLM for tips/adjustments and then **validates and clamps** them.
3. **Clamped twice.** The server clamps before transport; the client clamps again
   before applying. Shared fixtures prove both clamp identically.
4. **No PII.** The context contains training data only. No names, emails, or device IDs.
5. **Additive changes only** within v1: new optional fields are allowed; removing or
   retyping fields requires `contractVersion: 2` and a `409` for unknown versions.

## 2. Endpoints

### `GET /health`

```json
{
  "status": "ok",
  "service": "strongsense-coach-api",
  "version": "0.1.0",
  "contractVersion": 1,
  "llmConfigured": true,
  "providers": [{ "name": "openai_compatible", "model": "gpt-4.1-mini" }]
}
```

Never returns keys. `llmConfigured` is `false` when no provider is configured; the app
then shows "AI not configured on server" and keeps using the offline coach.

### `POST /v1/coach/plan`

Request body: [`coach-request.example.json`](coach-request.example.json)

| Field | Type | Required | Notes |
|---|---|---|---|
| `contractVersion` | integer | yes | Must be `1`. |
| `locale` | string | no | BCP-47, e.g. `en`, `es`. Defaults to `en`. |
| `context` | object | yes | `CoachContext`, see §3. |
| `baselinePlan` | object | no | The app's deterministic rules plan. When present the server compares the AI plan against it and reports `meta.clamped` / `meta.droppedAdjustments`. |
| `forceRules` | boolean | no | `true` skips the LLM and returns the baseline plan unchanged with `source: "rules"`. |

Success `200`: [`coach-response.example.json`](coach-response.example.json)

| Field | Type | Notes |
|---|---|---|
| `contractVersion` | integer | `1`. |
| `source` | enum | `llm`, `rules` (only with `forceRules`), or `rules_fallback`. |
| `plan` | object | `CoachPlan`, see §4. `plan.source` must equal the envelope `source`. |
| `meta` | object | `provider`, `model`, `latencyMs`, `clamped`, `droppedAdjustments`. |

Error body:

```json
{ "detail": { "code": "llm_unavailable", "message": "The AI coach is temporarily unavailable." } }
```

| Status | `code` | When |
|---|---|---|
| 400 | `invalid_request` | Malformed or out-of-range payload. |
| 401 | `unauthorized` | `COACH_API_TOKEN` configured and the bearer token is missing/wrong. |
| 409 | `contract_version_unsupported` | `contractVersion` is not `1`. |
| 413 | `payload_too_large` | Body over 256 KB. |
| 429 | `rate_limited` | Per-client request budget exceeded. |
| 503 | `llm_not_configured` | No provider configured and `forceRules` is false. |
| 503 | `llm_unavailable` | Every configured provider failed. |

## 3. `CoachContext`

See [`coach-request.example.json`](coach-request.example.json).

| Field | Type | Notes |
|---|---|---|
| `date` | `YYYY-MM-DD` | Session date. |
| `blockWeek` | integer 1–52 | Week in the current block. |
| `unit` | `kg` \| `lb` | Display unit; all loads are kg on the wire. |
| `programDay` | object | `{id, title, exercises:[{id, name, role, setTargets}]}`. |
| `programDay.exercises[].role` | enum | `main`, `variation`, `accessory`. |
| `programDay.exercises[].setTargets[]` | object | `{reps:int, repsMax:int?, loadKg:number?, rpeCap:number?}`. `repsMax` encodes a range such as `15-20`. `loadKg` is `null` for machine/bodyweight accessories. |
| `checkIn` | object | `sleepQuality` 1–5, `sleepHours` 0–14, `energy` 1–5, `motivation` 1–5, `soreness` 1–5, `stress` 1–5, `painAreas` array of `lower_back\|knee\|shoulder\|elbow\|wrist\|hip\|other`, `painSeverity` 0–10, `timeAvailableMin` 10–240. |
| `readiness` | object | `score` 0–100, `band` `green\|amber\|orange\|red`, `components` map of 0–100 values. |
| `lastSession` | object \| null | `{date, classification: easy\|normal\|hard\|none, perLift:[{exerciseId, topSetKg, topSetReps, topSetRpe, e1rmKg, missedSets}]}`. |
| `recentSessions` | array | Up to 6 `{date, dayId, classification, avgRpe, volumeKg, missedSets}`. |
| `personalRecords` | array | `{exerciseId, e1rmKg, date}`. |
| `settings` | object | `{unit, increments:{benchKg, squatKg, deadliftKg, accessoryKg}}`. |
| `constraints` | object | Must match §5: `{maxLoadDeltaPct, minLoadDeltaPct, maxSetsDelta, rpeCapMax, maxTips}`. |

## 4. `CoachPlan`

| Field | Type | Notes |
|---|---|---|
| `source` | enum | `rules`, `llm`, `rules_fallback`. |
| `summary` | string | ≤ 600 chars. |
| `readinessExplanation` | string | ≤ 600 chars. Plain-language "why". |
| `rpeCap` | number | 6.5–9.0 after clamping. |
| `deload` | boolean | `true` switches the plan to deload bounds (see §5). |
| `adjustments` | array | ≤ 12 items. |
| `adjustments[].exerciseId` | string | Must exist in `context.programDay.exercises[].id`. |
| `adjustments[].exercise` | string | Display name. |
| `adjustments[].loadDeltaPct` | number | −10…+5, relative to the **base working load** (last completed working load, else program target). |
| `adjustments[].setsDelta` | integer | −2…+2 per exercise. |
| `adjustments[].repsHint` | string \| null | Display only, ≤ 80 chars. |
| `adjustments[].reason` | string | ≤ 240 chars. |
| `adjustments[].substituteWith` | string \| null | Optional pain-aware substitution; ≤ 60 chars. |
| `tips` | array | ≤ `constraints.maxTips` (hard cap 12). |
| `tips[].title` | string | ≤ 80 chars. |
| `tips[].body` | string | ≤ 480 chars. |
| `tips[].category` | enum | `technique\|recovery\|nutrition\|programming`. |
| `flags` | array of string | ≤ 8, each ≤ 160 chars. |
| `disclaimer` | string | **Server-owned constant**; the LLM never supplies it. |

## 5. Safety bounds (enforced by server *and* client)

| Bound | Value |
|---|---|
| Load delta | normal: `-10% … +5%`, rounded to 0.5; deload (`deload: true`): `-40% … 0%` |
| Sets delta | `-2 … +2` per exercise |
| RPE cap | `6.5 … 9.0` |
| Tips | max 12, body ≤ 480 chars, title ≤ 80 chars |
| Summary / readiness explanation | ≤ 600 chars each |
| Unknown exercise | adjustment dropped |
| Pain rule | if `painSeverity ≥ 4` and the lift involves a flagged joint, `loadDeltaPct ≤ 0` |
| Deload rule | when `deload: true`, `loadDeltaPct` is clamped into `-40% … 0%` and `rpeCap ≤ 7.0` |

The fixture [`unsafe-ai-output.example.json`](unsafe-ai-output.example.json) is raw
model output containing an unknown exercise, `+25%`, `+6` sets, `RPE 11`, 15 tips and
over-long text. Both test suites clamp it to the bounds above.

## 6. LLM providers

Configured through `server/coach_api/.env` (see `.env.example`):

- `LLM_PROVIDER=openai_compatible` — any OpenAI-compatible `/chat/completions`
  endpoint: OpenAI, DeepSeek, Groq, OpenRouter, Together, Gemini-compat, Ollama.
- `LLM_PROVIDER=anthropic` — native Anthropic `/v1/messages`.
- Optional fallback provider with `LLM_FALLBACK_*` variables (same shape).
- Keys live only on the server; the app stores only the coach base URL.

## 7. Client behavior

1. Compute the deterministic `baselinePlan` and render it immediately.
2. If coaching is enabled and a URL is set, `POST /v1/coach/plan` with the context and
   baseline, 25 s timeout, one retry on network errors.
3. On `200`, decode the plan, clamp it locally, apply it, and show the source badge
   `AI coach · <model>` (from `/health` or `meta.model`).
4. On any error/timeout, keep the baseline plan and show a non-blocking
   "AI unavailable — using offline coach" notice. Never block training on the network.
