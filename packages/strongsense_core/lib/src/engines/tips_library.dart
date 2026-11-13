import '../models/coach_context.dart';
import '../models/coach_plan.dart';
import '../models/enums.dart';

/// Curated, deterministic tips used when the AI is unavailable (or disabled).
abstract final class TipsLibrary {
  static const int maxRulesTips = 4;

  static List<CoachTip> build({
    required CoachContext context,
    required bool isDeload,
  }) {
    final tips = <CoachTip>[];
    final band = context.readiness.band;
    final last =
        context.lastSession?.classification ?? SessionClassification.none;

    switch (band) {
      case ReadinessBand.green:
        tips.add(
          const CoachTip(
            title: 'Green light — earn the top set',
            body:
                'Readiness is high. Keep the prescribed RPE cap and let bar speed decide whether you add load. A fast, clean set is the green light for progress; a grinder is not.',
            category: TipCategory.programming,
          ),
        );
      case ReadinessBand.amber:
        tips.add(
          const CoachTip(
            title: 'Amber day — execute, do not test',
            body:
                'Keep every working set at the prescribed RPE and stop the session with a rep in reserve. The goal today is consistent quality, not a new personal record.',
            category: TipCategory.programming,
          ),
        );
      case ReadinessBand.orange:
        tips.add(
          const CoachTip(
            title: 'Orange day — reduce and stay technical',
            body:
                'Cut the load and one set from the main lift. Move with intent, keep rest periods honest, and treat today as a deposit toward the next heavy session.',
            category: TipCategory.recovery,
          ),
        );
      case ReadinessBand.red:
        tips.add(
          const CoachTip(
            title: 'Red day — recovery session only',
            body:
                'Use technique loads around 60 percent, two sets per main lift and no accessories. If you feel worse once you start, stop and recover; training through a red day rarely pays.',
            category: TipCategory.recovery,
          ),
        );
    }

    final components = context.readiness.components;
    if ((components['sleep'] ?? 100) < 60) {
      tips.add(
        const CoachTip(
          title: 'Sleep debt shows up under the bar',
          body:
              'Short sleep lowers your tolerance for volume. Keep the main lift, trim the last accessory, and aim for a longer night before your next heavy session.',
          category: TipCategory.recovery,
        ),
      );
    }
    if ((components['energy'] ?? 100) < 60) {
      tips.add(
        const CoachTip(
          title: 'Fuel the first half of the session',
          body:
              'Low energy is easiest to manage early. Take an extra two to three minutes before your first working set and keep the warm-up short but thorough.',
          category: TipCategory.recovery,
        ),
      );
    }
    if ((components['stress'] ?? 100) < 60) {
      tips.add(
        const CoachTip(
          title: 'Keep the session boring on purpose',
          body:
              'When stress is high, decision fatigue is real. Follow the written sets, use the same rest periods and skip optional extras. Consistency beats a heroic one-off.',
          category: TipCategory.programming,
        ),
      );
    }
    if ((components['soreness'] ?? 100) < 60) {
      tips.add(
        const CoachTip(
          title: 'Sore but mobile? Warm into it',
          body:
              'Use five to eight minutes of easy movement and ramp-up sets before judging the session. If the first working set still hurts, reduce the load instead of pushing through.',
          category: TipCategory.recovery,
        ),
      );
    }

    if (context.checkIn.painSeverity >= 4) {
      tips.add(
        const CoachTip(
          title: 'Pain is a veto, not a challenge',
          body:
              'Sharp, local or radiating pain is different from muscular fatigue. Swap or skip the affected lift, keep the range pain-free, and get it assessed if it persists beyond a week.',
          category: TipCategory.recovery,
        ),
      );
    }

    if (context.checkIn.timeAvailableMin < 30) {
      tips.add(
        const CoachTip(
          title: 'Short session: main lifts only',
          body:
              'With under 30 minutes, prioritise the competition lift and its variation. Skip accessories rather than rushing your rest periods; the main work is what drives progress.',
          category: TipCategory.programming,
        ),
      );
    } else if (context.checkIn.timeAvailableMin < 45) {
      tips.add(
        const CoachTip(
          title: '45-minute session: trim one accessory',
          body:
              'Drop the last accessory and keep the rest of the plan unchanged. Shortening rest periods below the plan is usually a false economy.',
          category: TipCategory.programming,
        ),
      );
    }

    if (last == SessionClassification.hard) {
      tips.add(
        const CoachTip(
          title: 'Repeat before you progress',
          body:
              'Your last session was hard. Repeat the same working load and aim for cleaner reps before adding weight; the progression is already earned when the same load feels easier.',
          category: TipCategory.programming,
        ),
      );
    } else if (last == SessionClassification.easy) {
      tips.add(
        const CoachTip(
          title: 'Bank the small progression',
          body:
              'Last session moved well. Take the small load increase the plan suggests, then keep the reps strict. Small, repeatable jumps beat occasional heroic attempts.',
          category: TipCategory.programming,
        ),
      );
    }

    if (isDeload) {
      tips.add(
        const CoachTip(
          title: 'Deload means deload',
          body:
              'Keep the load light and the sets short. The adaptation from the previous weeks happens while you recover, not while you add more fatigue.',
          category: TipCategory.recovery,
        ),
      );
    }

    tips.addAll(_techniqueTipFor(context));

    final seen = <String>{};
    final unique = <CoachTip>[];
    for (final tip in tips) {
      if (seen.add(tip.title)) {
        unique.add(tip);
      }
      if (unique.length >= maxRulesTips) {
        break;
      }
    }
    return unique;
  }

  static List<CoachTip> _techniqueTipFor(CoachContext context) {
    final ids = context.programDay.exercises
        .map((exercise) => '${exercise.id} ${exercise.name}'.toLowerCase())
        .toList(growable: false);

    if (ids.any((id) => id.contains('bench'))) {
      return const <CoachTip>[
        CoachTip(
          title: 'Bench setup: feet, arch, unrack',
          body:
              'Plant your feet, pull your shoulder blades down and back, then unrack without losing upper-back tension. The same setup on every set is what makes your numbers predictable.',
          category: TipCategory.technique,
        ),
      ];
    }
    if (ids.any((id) => id.contains('squat'))) {
      return const <CoachTip>[
        CoachTip(
          title: 'Squat: brace before you descend',
          body:
              'Take a full breath into your belly and brace before the first inch of movement. Keep the bar over mid-foot and drive the floor apart on the way up.',
          category: TipCategory.technique,
        ),
      ];
    }
    if (ids.any((id) => id.contains('deadlift'))) {
      return const <CoachTip>[
        CoachTip(
          title: 'Deadlift: wedge, then push',
          body:
              'Set the bar over mid-foot, pull the slack out, then push the floor away instead of yanking. Keep the bar close and finish tall rather than leaning back.',
          category: TipCategory.technique,
        ),
      ];
    }
    return const <CoachTip>[];
  }
}
