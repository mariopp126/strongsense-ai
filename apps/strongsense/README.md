# StrongSense AI — Flutter app

The client for StrongSense AI. One Flutter codebase targets **Android, iOS and
the web** (installable PWA). It is local-first: the deterministic coach always
works offline, and the optional AI layer lives in the Python service.

## Run

```powershell
flutter pub get
flutter run -d chrome --web-port 5173
```

For Android:

```powershell
flutter emulators --launch Pixel_7_Pro
flutter run -d emulator-5554
```

## Build

```powershell
flutter build web --release
flutter build apk --release
```

## Test

```powershell
flutter analyze --fatal-infos
flutter test
```

## Configuration

Everything is configured in-app under **Settings**. The AI coach is optional:
set the server URL (default `http://127.0.0.1:8080`) and enable the switch.
On the Android emulator the client automatically maps `localhost` to
`10.0.2.2`; on a physical device use your machine's LAN IP and start the
server on `0.0.0.0`.

## Structure

```
lib/
├── core/       theme, router, responsive shell, shared widgets
├── data/       sembast database, repositories, coach API client/services
├── features/   onboarding, home, checkin, workout, summary, coach, history, settings, program
├── l10n/       English/Spanish strings
└── state/      Riverpod providers and controllers
```

The deterministic domain logic (readiness, auto-regulation, progression,
safety bounds) lives in the sibling package [`packages/strongsense_core`](../../packages/strongsense_core).
