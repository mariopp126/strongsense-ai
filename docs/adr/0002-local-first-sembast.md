# ADR 0002 — Local-first storage with sembast

- Status: Accepted
- Date: 2026-11-13

## Context

v0.1 is a single-user, offline-first app. Training must work in a gym basement with no
signal, and the app must start instantly without an account. The data is modest
(hundreds of sessions, thousands of sets) and needs simple queries (history, in-progress
session, per-lift records).

Candidates: `drift` (SQLite, excellent but requires WASM assets and a worker on web),
`hive`, `shared_preferences`, `sembast`.

## Decision

Use **sembast** with `sembast_web`, behind repository classes:

- File database on Android/iOS, IndexedDB on web, chosen by conditional import.
- Stores: `settings`, `programs`, `sessions`, `coach_plans`.
- Repositories are the only code that touches the database, so the storage layer can be
  swapped for a sync backend later.

## Consequences

**Positive**

- Pure Dart, no native binaries or web workers; works identically on all targets.
- Zero setup for tests: an in-memory factory.
- JSON documents match the domain codecs already needed for the HTTP contract.

**Negative**

- No SQL aggregation; charts/records are computed in Dart (fine at this scale).
- Weaker schema typing than drift; decode failures are handled defensively.
- Future multi-device sync will need a sync engine or a move to a server-backed store.

## Follow-up

Revisit drift or a server-backed repository when accounts and multi-device sync land.
