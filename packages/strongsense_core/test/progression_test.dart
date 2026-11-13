import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('ProgressionEngine', () {
    test('increases the load after a clean session at RPE 8', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          for (var index = 0; index < 4; index++)
            benchLog(index: index, rpe: 8),
        ],
      );

      final next = ProgressionEngine.nextTopLoads(
        session: session,
        day: dayById('day-2'),
        increments: const Increments(),
      );

      // 75 * 1.025 = 76.875 -> 77.5 kg
      expect(next['ex-bench'], 77.5);
    });

    test('repeats the load after a single missed set', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          benchLog(index: 0),
          benchLog(index: 1),
          benchLog(index: 2),
          benchLog(index: 3, reps: 4, rpe: 8.5),
        ],
      );

      final next = ProgressionEngine.nextTopLoads(
        session: session,
        day: dayById('day-2'),
        increments: const Increments(),
      );

      expect(next['ex-bench'], 75);
    });

    test('backs off after a very hard, missed session', () {
      final session = sessionWithBenchSets(
        logs: <SetLog>[
          benchLog(index: 0, reps: 4, rpe: 9.5),
          benchLog(index: 1, reps: 4, rpe: 9.5),
          benchLog(index: 2, reps: 5, rpe: 9),
        ],
      );

      final next = ProgressionEngine.nextTopLoads(
        session: session,
        day: dayById('day-2'),
        increments: const Increments(),
      );

      // 75 * 0.975 = 73.125 -> 72.5 kg
      expect(next['ex-bench'], 72.5);
    });

    test('skips exercises with no completed load', () {
      final session = sessionWithBenchSets(logs: const <SetLog>[]);

      final next = ProgressionEngine.nextTopLoads(
        session: session,
        day: dayById('day-2'),
        increments: const Increments(),
      );

      expect(next, isEmpty);
    });
  });
}
