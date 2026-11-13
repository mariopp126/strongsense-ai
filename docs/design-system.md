# Design system

The visual language comes from the original single-file React reference
(`docs/reference/powerbuilding_tracker_example.jsx`): a mobile-first column, sticky
dark header, slate neutrals, emerald accents, rounded cards and a segmented day
selector. This document maps those Tailwind classes to Flutter tokens.

## Color

| Token | Hex | Use |
|---|---|---|
| `slate900` | `#0F172A` | Header, hero card, dark surface |
| `slate800` | `#1E293B` | Hero gradient end, dark cards |
| `slate700` | `#334155` | Secondary dark text |
| `slate500` | `#64748B` | Muted text |
| `slate400` | `#94A3B8` | Hints, inactive nav |
| `slate300` | `#CBD5E1` | Disabled text, outlines |
| `slate200` | `#E2E8F0` | Borders, segmented track |
| `slate100` | `#F1F5F9` | Subtle chips |
| `slate50` | `#F8FAFC` | Page background |
| `emerald500` | `#10B981` | Primary accent, progress |
| `emerald600` | `#059669` | Buttons, selected icons |
| `emerald700` | `#047857` | Text on emerald tints |
| `emerald800` | `#065F46` | Strong text |
| `emerald200/100/50` | `#A7F3D0` / `#D1FAE5` / `#ECFDF5` | Checked sets, banners |
| `amber500/100/800` | `#F59E0B` / `#FEF3C7` / `#92400E` | Amber readiness, warnings |
| `orange500/100/800` | `#F97316` / `#FFEDD5` / `#9A3412` | Reduced load, missed sets |
| `red500/100/800` | `#EF4444` / `#FEE2E2` / `#991B1B` | Errors, red readiness |
| `blue500/100/800` | `#3B82F6` / `#DBEAFE` / `#1E40AF` | AI source badge |

Semantic mapping: green = push, amber = maintain, orange = reduce, red = recover.
Color is never the only signal — each band also has a label and advice text.

## Type

No custom font is bundled; the system UI font keeps the app offline and small. Scale:

| Style | Size / weight | Use |
|---|---|---|
| Display small | 30 / 900, −0.8 tracking | Onboarding title |
| Headline medium | 24 / 800 | Screen titles |
| Title large | 18 / 700 | Exercise names |
| Title medium | 16 / 700 | Card titles |
| Body large | 16 / 400 | Plan summary |
| Body medium | 14 / 400 | Supporting copy |
| Body small | 12 / 400 | Hints, reasons |
| Label small | 11 / 700 + 0.8 tracking | `SET n` labels |

## Spacing, radius, elevation

- Spacing scale: 4, 8, 12, 16, 20, 24, 32.
- Radii: 8 (small controls), 12 (inputs/buttons/set rows), 16 (cards), 20 (hero/sheets), pill.
- Borders: 1.5 px `slate200`/`outlineVariant`; checked set rows use 2 px emerald.
- Shadows: one soft shadow on the hero card and elevated set rows only.
- Content width: mobile 520 px, web 720 px centered.

## Components (reference → Flutter)

| Reference | Flutter widget | Notes |
|---|---|---|
| Sticky dark header | `AppBar` theme (`slate900`) | Title + optional subtitle |
| Day tabs | `SsDaySelector` | `AnimatedContainer`, white active pill on `slate200` track |
| Progress bar | `SsProgressBar` | 10 px, rounded, animated 500 ms |
| Exercise card | `SsExerciseCard` | White card, 16 radius, role pill |
| Set row | `SsSetRow` | Checkbox circle, `SET n`, reps, weight badge, edit icon |
| Completion banner | `SsBanner` | Emerald tint + trophy |
| Readiness summary | `SsReadinessCard` | Band color, big score, component bars |
| Plan explanation | `CoachPlanView` | Source pill, summary, expansion, adjustments, tips, flags, disclaimer |
| Stat tile | `SsStatTile` | Value + label on a tinted surface |
| Empty state | `SsEmptyState` | Icon + title + optional CTA |

## Screen blueprints

1. **Onboarding** — brand, value proposition, name, units, optional bodyweight, program preview, primary CTA.
2. **Home** — dark hero (greeting, today's day, start check-in), weekly stats, coach teaser, recent sessions, PRs.
3. **Check-in** — day selector, five sliders + sleep hours, pain chips + severity, time chips, notes, primary CTA.
4. **Plan preview** — readiness card, source badge, summary, why, adjustments, tips, flags, edit/start actions.
5. **Workout** — progress card, exercise cards with set rows, rest timer bar, finish action.
6. **Summary** — trophy, PR banner, four stat tiles, per-lift rows, next-session loads, notes, save.
7. **Coach** — latest plan with source badge and a re-check-in action.
8. **History** — sessions list and progress charts (e1RM line, volume bars).
9. **Settings** — profile, units, language, theme, AI coach, increments, program, data reset, about.
10. **Program** — read-only list of days, exercises and prescriptions.

## Responsive behavior

- `< 720 px`: bottom `NavigationBar`, single column, 16 px gutters.
- `≥ 720 px`: `NavigationRail` with brand mark, content centered at 720 px.
- Workout and check-in are full-screen pushes outside the shell on both breakpoints.
- Safe areas respected; primary actions reachable with one thumb.

## Motion

- 200 ms `easeOut` for selection and card states.
- 500 ms `easeOutCubic` for the progress bar.
- No looping animations; the only spinner is an indeterminate loader.
- Haptics on set completion (mobile).

## Accessibility

- Minimum 44–48 px touch targets.
- Every icon button has a tooltip/semantics label.
- Readiness uses text + icon + color.
- Text scaling respected; no fixed-height text containers.
- Contrast: emerald 600 on white ≈ 4.5:1; slate 500 on slate 50 ≈ 4.6:1.
- Dark theme uses the same semantic colors with adjusted surfaces.

## Copy & tone

Direct, calm, non-macho. Explain *why* a number changed. Never shame a missed set.
Examples: "Hold the current load and win on execution", "Pain is a veto, not a challenge",
"Deload means deload."
