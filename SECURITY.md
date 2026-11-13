# Security

## Secret handling

- Provider API keys are read by the Python service from `server/coach_api/.env` or
  environment variables. The file is gitignored; `.env.example` contains placeholders only.
- The Flutter app never stores or transmits provider keys. It only knows the coach server URL.
- CI runs a **secrets guard** that fails if `.env`, `*.pem`, `*.key`, `*.p12` or `*.jks`
  files are tracked.
- Logs never include request/response bodies, headers or keys. The server logs request id,
  route, status, provider, model and latency only.

## Reporting a vulnerability

Please do not open a public issue for security problems. Instead, open a private
security advisory on GitHub (Security → Advisories → Report a vulnerability) or contact
the maintainer directly. Include reproduction steps and the affected version.

## Threat model (v0.1)

| Asset | Risk | Mitigation |
|---|---|---|
| LLM API key | Leak via repo or app | Server-only `.env`, gitignore, secrets guard, no key logging |
| Coach proxy | Abuse if exposed | Optional bearer token, per-client rate limit, 256 KB body cap, 20 s upstream timeout |
| Model output | Unsafe training advice | Strict JSON schema, server + client clamps, server-owned disclaimer, deload/pain rules |
| Local training data | Loss | Local-first storage; export/import planned for v0.2 |
| Prompt injection | Model obeys text in notes | Notes are not sent; context is structured data only; system prompt fixes the output contract |

## Supported versions

| Version | Supported |
|---|---|
| 0.1.x | Yes |

## Scope

Out of scope for v0.1: accounts, multi-tenant data, payments, and clinical/medical
claims. The service is intended to run on localhost or behind an authenticated,
TLS-terminated deployment you control.
