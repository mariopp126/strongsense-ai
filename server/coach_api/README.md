# StrongSense Coach API

Stateless FastAPI service that enriches the StrongSense AI app's deterministic
training plan with a validated, safety-clamped LLM coaching plan.

The Flutter app owns all training rules and always works offline. This service only:

1. validates the request and contract version,
2. builds a prompt from the session context + the app's `baselinePlan`,
3. calls an LLM (OpenAI-compatible or Anthropic) with a JSON schema request,
4. validates the model JSON (with one repair retry),
5. applies the contract safety clamp (`app/safety.py`),
6. returns a normalized `CoachPlan` — or the baseline as a rules fallback.

The service is **stateless**: no database, no persistence, no PII. The wire contract
lives in [`docs/contract/contract.md`](../../docs/contract/contract.md); its example
payloads are loaded by both the Dart and Python test suites.

- Service: `strongsense-coach-api` version `0.1.0`
- Contract version: `1`
- Python: 3.12+
- Local base URL: `http://127.0.0.1:8080`

---

## Quick start (Windows PowerShell)

```powershell
cd server/coach_api

# 1. Create the virtual environment and install pinned dependencies
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements-dev.txt

# 2. Configure the LLM provider (interactive, keys are never echoed)
powershell -ExecutionPolicy Bypass -File ..\..\scripts\set_keys.ps1
#    ... or manually:
Copy-Item .env.example .env
notepad .env

# 3. Run the service
.\.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8080

# 4. In another terminal (repository root): smoke test the running service
python scripts\smoke_coach.py
```

bash/macOS equivalents are the usual `python -m venv .venv`,
`source .venv/bin/activate`, `pip install -r requirements-dev.txt`,
`cp .env.example .env`, `uvicorn app.main:app --host 127.0.0.1 --port 8080`.

Without an LLM configured the service is still healthy: `GET /health` reports
`"llmConfigured": false`, `POST /v1/coach/plan` returns `503 llm_not_configured`, and
the app keeps using its offline coach.

## Endpoints

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

Never returns keys. `providers` lists the primary provider first, then the optional
fallback (`name` is the protocol, `model` the model id).

### `POST /v1/coach/plan`

Request: [`docs/contract/coach-request.example.json`](../../docs/contract/coach-request.example.json).
Response `200`: [`docs/contract/coach-response.example.json`](../../docs/contract/coach-response.example.json).

Request fields: `contractVersion` (must be `1`), `locale`, `context`, optional
`baselinePlan`, optional `forceRules`. `forceRules: true` skips the LLM and returns the
baseline plan with `source: "rules"`; when the provider fails, the baseline is returned
with `source: "rules_fallback"`.

`meta` reports `provider`, `model`, `latencyMs`, `clamped` and `droppedAdjustments`.

### Error body

Every error uses the same envelope:

```json
{ "detail": { "code": "llm_unavailable", "message": "The AI coach is temporarily unavailable." } }
```

| Status | `code` | When |
|---|---|---|
| 400 | `invalid_request` | Malformed or out-of-range payload (including a bad JSON body). |
| 401 | `unauthorized` | `COACH_API_TOKEN` configured and bearer token missing/wrong. |
| 409 | `contract_version_unsupported` | `contractVersion` is not `1`. |
| 413 | `payload_too_large` | Request body over 256 KB. |
| 429 | `rate_limited` | Per-client request budget exceeded (`Retry-After` header). |
| 503 | `llm_not_configured` | No provider configured and `forceRules` is false. |
| 503 | `llm_unavailable` | Every configured provider failed and no baseline was supplied. |

Responses always carry `X-Request-ID` (echoed from the request when well-formed,
otherwise generated). CORS is restricted to `ALLOWED_ORIGINS` (default: the local web
dev servers on port 5173).

## Safety clamp

`app/safety.py` is the only place where model output becomes an applicable plan. It
implements the contract bounds:

| Bound | Value |
|---|---|
| Load delta | normal: `-10% … +5%`, deload: `-40% … 0%`; rounded to 0.5 |
| Sets delta | `-2 … +2` per exercise |
| RPE cap | `6.5 … 9.0`; deload additionally `<= 7.0` |
| Tips | at most `min(12, constraints.maxTips)`; title <= 80, body <= 480 chars |
| Summary / readiness explanation | <= 600 chars each |
| Unknown exercise | adjustment dropped (`meta.droppedAdjustments++`) |
| Pain rule | `painSeverity >= 4` and the lift involves a flagged joint => `loadDeltaPct <= 0` |
| Deload rule | `deload: true` => load deltas clamped into `-40 … 0` and `rpeCap <= 7.0` |

Long text is truncated, not rejected. `disclaimer` is **always** replaced with the
server-owned constant, and `plan.source` always equals the envelope `source`.

The deload marker is the `deload` boolean returned by the model (part of `CoachPlan`),
not a summary-text heuristic.

## Provider configuration

Copy `.env.example` to `.env` and fill in one provider. Presets are listed in the
example file; the shape is always the same:

| Provider | `LLM_PROVIDER` | `LLM_BASE_URL` | Example model |
|---|---|---|---|
| OpenAI | `openai_compatible` | `https://api.openai.com/v1` | `gpt-4.1-mini` |
| DeepSeek | `openai_compatible` | `https://api.deepseek.com/v1` | `deepseek-chat` |
| OpenRouter | `openai_compatible` | `https://openrouter.ai/api/v1` | `openai/gpt-4.1-mini` |
| Groq | `openai_compatible` | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| Gemini (compat) | `openai_compatible` | `https://generativelanguage.googleapis.com/v1beta/openai` | `gemini-2.0-flash` |
| Ollama (local) | `openai_compatible` | `http://127.0.0.1:11434/v1` | `llama3.1:8b` |
| Anthropic | `anthropic` | `https://api.anthropic.com` | `claude-3-5-haiku-latest` |

`openai_compatible` posts to `{LLM_BASE_URL}/chat/completions` and first asks for a
`json_schema` response format, falling back to `{"type":"json_object"}` on HTTP
400/404/422. `anthropic` posts to `{LLM_BASE_URL}/v1/messages` with the system prompt.

Optional fallback: set `LLM_FALLBACK_PROVIDER`, `LLM_FALLBACK_BASE_URL`,
`LLM_FALLBACK_API_KEY`, `LLM_FALLBACK_MODEL` to a second profile with the same shape.
The primary is tried first; the fallback is tried when it fails. The whole call
(primary + fallback + one repair retry each) is bound by `LLM_TIMEOUT_SECONDS` (20 s).

## Configuration reference

| Variable | Default | Notes |
|---|---|---|
| `APP_ENV` | `development` | Free-form label; `test` disables the startup log line. |
| `COACH_HOST` | `127.0.0.1` | Used by `python -m app.main`; Docker uses `0.0.0.0`. |
| `COACH_PORT` | `8080` | Same. |
| `COACH_API_TOKEN` | empty | Optional bearer token for `/v1/coach/plan`. Empty = auth off. |
| `ALLOWED_ORIGINS` | `http://localhost:5173,http://127.0.0.1:5173` | Comma list or JSON array. |
| `MAX_REQUESTS_PER_MIN` | `30` | Per client IP (+token when present). `0` disables. |
| `LLM_PROVIDER` | empty | `openai_compatible` or `anthropic`; empty = no AI. |
| `LLM_BASE_URL` | empty | Provider base URL. |
| `LLM_API_KEY` | empty | Optional for local OpenAI-compatible endpoints. |
| `LLM_MODEL` | empty | Model id. |
| `LLM_TIMEOUT_SECONDS` | `20` | Overall call budget. |
| `LLM_TEMPERATURE` | `0.4` | Sampling temperature. |
| `LLM_MAX_TOKENS` | `900` | Response token budget. |
| `LLM_FALLBACK_*` | empty | Optional second provider profile. |

## Docker

Build from the repository root (the image only needs `requirements.txt` and `app/`):

```powershell
docker build -t strongsense-coach-api server/coach_api
docker run --rm -p 8080:8080 --env-file server/coach_api/.env strongsense-coach-api
```

The image is `python:3.12-slim`, installs pinned runtime requirements only (no build
tools or dev dependencies), runs as the non-root `coach` user, exposes port `8080`,
and has a `HEALTHCHECK` that calls `GET /health`. Never bake keys into the image: pass
them with `--env-file` or your orchestrator's secret store.

## Security notes

- Keys live only on the server (`server/coach_api/.env`). `.env` is gitignored and CI
  fails if a tracked `.env` or private key file exists.
- `COACH_API_TOKEN` is optional; when set, `/v1/coach/plan` requires
  `Authorization: Bearer <token>` (constant-time compare). `/health` stays public.
- Logs are structured JSON lines with request id, method, path, status, latency, LLM
  provider/model and token counts only. Request/response bodies, headers and keys are
  never logged.
- Bodies over 256 KB are rejected with 413 before parsing.
- Per-client token-bucket rate limiting (in-memory; the service is designed for a
  single uvicorn worker). For multiple workers/replicas put a shared limiter at the
  proxy or accept per-process budgets.
- CORS is an explicit allowlist; credentials are disabled.
- The service never stores training data and never talks to anything except the
  configured LLM endpoint.

## Testing

From `server/coach_api`:

```powershell
.\.venv\Scripts\ruff check .
.\.venv\Scripts\mypy app
.\.venv\Scripts\pytest --cov=app --cov-report=term-missing --cov-fail-under=85
```

The suite uses FastAPI's `TestClient` and `respx`; it never touches the network. It
loads the shared fixtures from `../../docs/contract/` (contract examples + the unsafe
model output) so the Python clamp is proven against the same data as the Dart client.
Coverage is enforced at 85%.

Live smoke test (server running):

```powershell
python scripts\smoke_coach.py --base-url http://127.0.0.1:8080
python scripts\smoke_coach.py --health-only
python scripts\smoke_coach.py --force-rules
```

## Project layout

```
server/coach_api/
  app/
    main.py       FastAPI app factory, routes, middleware, error handlers
    config.py     pydantic-settings configuration + provider helpers
    schemas.py    Pydantic v2 contract models (request, plan, raw model output)
    prompt.py     system + user prompt construction
    llm.py        provider clients, retries, repair retry, fallback
    safety.py     contract section 5 clamp (deload-aware)
    coach.py      orchestration (forceRules, fallback, clamping, meta)
    auth.py       optional bearer auth
    ratelimit.py  in-memory token-bucket limiter
    logging.py    structured JSON logging + request ids
  tests/          pytest suite (TestClient + respx, shared contract fixtures)
  Dockerfile
  pyproject.toml  # ruff / mypy / pytest config
  requirements*.txt
  .env.example
```
