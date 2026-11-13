# Contributing to StrongSense AI

Thanks for helping. This project is intentionally small: a Flutter app, a pure-Dart
domain package and a Python coach proxy.

## Before you start

- Read [`docs/architecture.md`](docs/architecture.md) and
  [`docs/contract/contract.md`](docs/contract/contract.md).
- Training logic belongs in `packages/strongsense_core` (pure Dart, unit-tested).
  Do not put readiness/progression rules in UI widgets or in the Python service.
- The Python service enriches plans; it must not invent training rules.

## Development setup

```powershell
# App
cd apps/strongsense
flutter pub get

# Core
cd packages/strongsense_core
dart pub get

# Server
cd server/coach_api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
Copy-Item .env.example .env
```

## Ground rules

1. **Never commit secrets.** `.env`, keys and certificates are gitignored and CI runs a
   secrets guard.
2. **Keep the contract in sync.** If a field changes, update `docs/contract/contract.md`,
   both example payloads, the Dart codec and the Python schemas. Contract tests load the
   same fixture files.
3. **Safety bounds are non-negotiable.** Any AI-produced value passes through
   `SafetyBounds.clamp` (Dart) and `safety.clamp_plan` (Python).
4. **Offline first.** New features must not require the server to start a workout.
5. **Tests for logic.** Readiness, auto-regulation, progression, clamping and contract
   encoding need unit tests.

## Commits & branches

- Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`.
- Keep `main` green. Open a pull request for anything beyond a small fix.
- Format before committing:

```powershell
dart format apps/strongsense/lib apps/strongsense/test packages/strongsense_core
```

## Pull request checklist

- [ ] `dart analyze --fatal-infos` / `flutter analyze --fatal-infos` clean
- [ ] `dart test` and `flutter test` green
- [ ] `ruff check`, `mypy app`, `pytest` green in `server/coach_api`
- [ ] Contract updated if the wire format changed
- [ ] Screenshots for UI changes (light and dark where relevant)
- [ ] No secrets or `.env` files added
