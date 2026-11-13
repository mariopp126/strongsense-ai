# ADR 0001 — Flutter for web and mobile

- Status: Accepted
- Date: 2026-11-13

## Context

The product must ship as a mobile app **and** a web app. The original prototype was a
single-file React component (kept in `docs/reference/`), but it was a design reference,
not a stack decision. A solo maintainer needs one codebase and one release pipeline.

## Decision

Build the client in **Flutter 3.41 / Dart 3.11**:

- Android, iOS and web from one codebase.
- The web build is a PWA (installable, offline-capable).
- Custom widgets reproduce the reference design rather than porting React.

## Consequences

**Positive**

- One UI implementation, one test suite, one design system.
- Native Android/iOS builds without a second app.
- Strong offline story (assets, local database, no JS runtime caveats).

**Negative**

- Flutter web ships a larger initial bundle than a hand-rolled React app.
- iOS builds require macOS in CI or locally; this Windows machine can only build web/Android.
- Dart is less common than TypeScript for contributors.

**Alternatives considered**

- React + PWA + Capacitor: two ecosystems, weaker native feel.
- React Native + React web: duplicated UI and state.
