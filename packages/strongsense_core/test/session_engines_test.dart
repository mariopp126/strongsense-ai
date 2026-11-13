import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('E1rm', () {
    test('Epley formula', () {
      expect(E1rm.epley(100, 5), closeTo(116.6667, 0.001));
      expect(E1rm.epley(0, 5), 0);
      expect(E1rm.epley(100, 0), 0);
    });

    test('caps unreliable rep counts', () {
      expect(E1rm.epley(100, 12), closeTo(140, 0.001));
      expect(E1rm.epley(100, 30), closeTo(140, 0.001));
    });
  });

  group('SessionClassifier', () {
    test('returns none when nothing was completed', () {
      final session = sessionWithBenchSets(logs: const <SetLog>[]);

      expect(
        SessionClassifier.classify(session: session),
        SessionClassification.none,
      );
    });

    test('classifies an easy session', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          for (var index = 0; index < 4; index++)
            benchLog(index: index, rpe: 7),
        ],
      );

      expect(
        SessionClassifier.classify(
          session: session,
          mainExerciseIds: const <String>{'ex-bench'},
        ),
        SessionClassification.easy,
      );
    });

    test('classifies a normal session', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          for (var index = 0; index < 4; index++)
            benchLog(index: index, rpe: 8),
        ],
      );

      expect(
        SessionClassifier.classify(
          session: session,
          mainExerciseIds: const <String>{'ex-bench'},
        ),
        SessionClassification.normal,
      );
    });

    test('classifies a hard session when reps are missed', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          for (var index = 0; index < 4; index++)
            benchLog(index: index, rpe: 7),
          benchLog(index: 4, reps: 4, rpe: 7),
        ],
      );

      expect(
        SessionClassifier.classify(
          session: session,
          mainExerciseIds: const <String>{'ex-bench'},
        ),
        SessionClassification.hard,
      );
    });

    test('classifies a high-RPE session as hard', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          for (var index = 0; index < 4; index++)
            benchLog(index: index, rpe: 9),
        ],
      );

      expect(
        SessionClassifier.classify(
          session: session,
          mainExerciseIds: const <String>{'ex-bench'},
        ),
        SessionClassification.hard,
      );
    });

    test('falls back to missed-set analysis without RPE data', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          for (var index = 0; index < 3; index++)
            benchLog(index: index, rpe: null),
        ],
      );

      expect(
        SessionClassifier.classify(session: session),
        SessionClassification.normal,
      );
    });
  });

  group('SessionSummaryCalculator', () {
    test('computes volume, e1RM, missed sets and duration', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          benchLog(index: 0, reps: 5, rpe: 8),
          benchLog(index: 1, reps: 5, rpe: 8),
          benchLog(index: 2, reps: 5, rpe: 8),
          benchLog(index: 3, reps: 4, rpe: 9),
        ],
        completedAt: DateTime(2026, 11, 14, 10, 50),
      );

      final summary = SessionSummaryCalculator.summarize(
        session: session,
        day: dayById('day-2'),
      );

      expect(summary.totalVolumeKg, 1425);
      expect(summary.setsCompleted, 4);
      expect(summary.setsPlanned, 4);
      expect(summary.missedSets, 1);
      expect(summary.durationMin, 50);
      expect(summary.avgRpe, closeTo(8.25, 0.001));

      final bench = summary.perLift.firstWhere(
        (lift) => lift.exerciseId == 'ex-bench',
      );
      expect(bench.topSetKg, 75);
      expect(bench.topSetReps, 5);
      expect(bench.e1rmKg, closeTo(87.5, 0.001));
      expect(bench.volumeKg, 1425);
      expect(bench.missedSets, 1);
    });

    test('returns zero volume for an empty session', () {
      final session = sessionWithBenchSets(logs: const <SetLog>[]);

      final summary = SessionSummaryCalculator.summarize(
        session: session,
        day: dayById('day-2'),
      );

      expect(summary.totalVolumeKg, 0);
      expect(summary.setsCompleted, 0);
      expect(summary.missedSets, 0);
    });
  });
}
