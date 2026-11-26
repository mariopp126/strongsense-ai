# Data model

All weights are stored in **kilograms** (canonical) and converted for display.
Dates are stored as `YYYY-MM-DD`; timestamps as ISO-8601 UTC.
Enums use their snake_case `wire` value on disk and on the wire.

## Entities

### Training program

```json
{
  "id": "program-powerbuilding-3day",
  "name": "Powerbuilding 3-Day",
  "isDefault": true,
  "days": [
    {
      "id": "day-2",
      "title": "Bench & Upper Body",
      "focus": "upper",
      "exercises": [
        {
          "id": "ex-bench",
          "name": "Bench Press",
          "role": "main",
          "setTargets": [
            { "reps": 5, "repsMax": null, "loadKg": 75.0, "rpeCap": null }
          ]
        }
      ]
    }
  ]
}
```

- `role`: `main` | `variation` | `accessory`.
- `setTargets`: one entry per prescribed set; repeats encode straight sets,
  `repsMax` encodes a range such as 15–20, and `loadKg: null` marks machine or
  bodyweight accessories.

### Check-in

```json
{
  "sleepQuality": 4,
  "sleepHours": 7.5,
  "energy": 3,
  "motivation": 4,
  "soreness": 2,
  "stress": 2,
  "painAreas": ["shoulder"],
  "painSeverity": 4,
  "timeAvailableMin": 60,
  "bodyWeightKg": 82.5,
  "notes": ""
}
```

- `sleepQuality`, `energy`, `motivation`, `soreness`, `stress`: 1–5.
- `painSeverity`: 0–10; `painAreas` from `lower_back`, `knee`, `shoulder`, `elbow`,
  `wrist`, `hip`, `other`.
- `timeAvailableMin`: 10–240.

### Readiness report (computed, not persisted)

```json
{
  "score": 69,
  "band": "amber",
  "components": {
    "sleep": 75,
    "energy": 50,
    "stress": 75,
    "soreness": 75,
    "motivation": 75
  }
}
```

The app also keeps `advice` and `appliedCaps` in memory for the explainability UI;
they are not part of the wire contract.

### Session

```json
{
  "id": "session-1763072400123456",
  "dayId": "day-2",
  "date": "2026-11-14",
  "startedAt": "2026-11-14T14:00:00.000Z",
  "status": "completed",
  "checkIn": { "...": "CheckIn" },
  "setLogs": [
    {
      "exerciseId": "ex-bench",
      "setIndex": 0,
      "targetReps": 5,
      "targetLoadKg": 76.0,
      "reps": 5,
      "loadKg": 76.0,
      "rpe": 8,
      "completed": true,
      "skipped": false,
      "notes": ""
    }
  ],
  "notes": "Felt strong",
  "completedAt": "2026-11-14T15:05:00.000Z",
  "sessionRpe": 8.0
}
```

- `status`: `planned` | `in_progress` | `completed`. Only `in_progress` sessions are
  offered as "resume" on the home screen.
- A `SetLog` is unique by `(exerciseId, setIndex)`.
- Missing reps are derived: `completed && reps < targetReps && !skipped`.

### Session summary (computed at finish)

```json
{
  "sessionId": "session-1763072400123456",
  "dayId": "day-2",
  "date": "2026-11-14",
  "totalVolumeKg": 1425.0,
  "setsCompleted": 4,
  "setsPlanned": 4,
  "avgRpe": 8.25,
  "sessionRpe": 8.0,
  "missedSets": 1,
  "durationMin": 50,
  "perLift": [
    {
      "exerciseId": "ex-bench",
      "exercise": "Bench Press",
      "topSetKg": 75.0,
      "topSetReps": 5,
      "topSetRpe": 8.0,
      "e1rmKg": 87.5,
      "volumeKg": 1425.0,
      "setsCompleted": 4,
      "setsPlanned": 4,
      "missedSets": 1
    }
  ]
}
```

- Volume = Σ `loadKg × reps` over completed sets.
- e1RM uses Epley (`load × (1 + reps / 30)`, reps capped at 12 for accuracy).
- Duration = `completedAt − startedAt` in minutes.

### Coach plan

The wire shape is defined in [`contract/contract.md`](contract/contract.md).
Persisted as `{ "generatedAt": "...", "plan": { ...CoachPlan } }` under the session id
when a workout starts, and under the stable key `latest` as soon as a check-in plan is
generated (so the Coach tab and Home teaser can show it before the workout starts).

### Settings

```json
{
  "unit": "kg",
  "language": "en",
  "increments": {
    "benchKg": 2.5,
    "squatKg": 5.0,
    "deadliftKg": 5.0,
    "accessoryKg": 2.5
  },
  "deloadPolicy": "every_fourth_week",
  "coachEnabled": false,
  "coachBaseUrl": "http://127.0.0.1:8080",
  "theme": "system",
  "onboardingComplete": true,
  "userName": "Mario",
  "bodyWeightKg": 82.5
}
```

## Sembast stores

| Store | Key | Notes |
|---|---|---|
| `settings` | `app` | Single record |
| `programs` | `default` | Seeded on first launch |
| `sessions` | session id | Sorted by `startedAt` string |
| `coach_plans` | session id / `latest` | Latest plan shown in the Coach tab |

`meta.schemaVersion` is reserved for migrations; v0.1 is version 1. Repository reads
are defensive: a corrupt record is skipped instead of crashing the history.

## Backup format

Settings → Data exports a versioned JSON snapshot:

```json
{
  "format": "strongsense.backup",
  "schemaVersion": 1,
  "exportedAt": "2026-11-26T18:04:52.598Z",
  "settings": { "...AppSettings..." },
  "program": { "...TrainingProgram..." },
  "sessions": [ { "...Session..." } ],
  "coachPlans": [ { "key": "latest", "generatedAt": "...", "plan": { "...CoachPlan..." } } ]
}
```

`BackupDocument.decode` validates `format`, `schemaVersion`, unique session ids and
unique coach-plan keys before any repository is touched. Import offers two modes:

- **Merge** keeps the current settings and program and unions sessions/plans by id/key,
  keeping the newest record on conflict (`completedAt`/`startedAt` for sessions,
  `generatedAt` for plans).
- **Replace** uses the backup for settings, program, sessions and coach plans.

CSV export flattens sessions to one row per set (UTF-8 BOM, CRLF, RFC 4180 escaping),
which opens directly in Excel or Google Sheets.


## Derived data (not stored)

- **Personal records**: best e1RM per exercise across completed sessions
  (`RecordsCalculator`).
- **Weekly stats**: sessions and volume in the last 7 days.
- **Next day**: the program day after the most recent completed session.
- **Block week**: `(completed sessions ÷ 3) + 1`, used for the week-4 deload.
- **Next targets**: `ProgressionEngine.nextTopLoads` recomputed from the finished session.
