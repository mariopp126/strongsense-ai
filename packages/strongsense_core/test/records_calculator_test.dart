import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('RecordsCalculator', () {
    test('keeps the best estimated 1RM per exercise', () {
      final sessions = <Session>[
        sessionWithBenchSets(
          logs: <SetLog>[benchLog(index: 0, reps: 5, loadKg: 75, rpe: 8)],
        ),
        Session(
          id: 'session-2',
          dayId: 'day-2',
          date: DateTime(2026, 11, 21),
          startedAt: DateTime(2026, 11, 21, 10),
          status: SessionStatus.completed,
          checkIn: checkInAllFives(),
          setLogs: <SetLog>[
            const SetLog(
              exerciseId: 'ex-bench',
              setIndex: 0,
              targetReps: 3,
              reps: 3,
              loadKg: 90,
              rpe: 9,
              completed: true,
            ),
          ],
        ),
      ];

      final records = RecordsCalculator.personalRecords(sessions);

      expect(records, hasLength(1));
      expect(records.single.exerciseId, 'ex-bench');
      expect(records.single.e1rmKg, closeTo(99, 0.001));
      expect(records.single.weightKg, 90);
      expect(records.single.sessionId, 'session-2');
    });

    test('ignores uncompleted and bodyweight sets', () {
      final sessions = <Session>[
        sessionWithBenchSets(
          logs: <SetLog>[
            benchLog(index: 0, completed: false),
            const SetLog(
              exerciseId: 'ex-leg-press',
              setIndex: 0,
              targetReps: 12,
              reps: 12,
              completed: true,
            ),
          ],
        ),
      ];

      expect(RecordsCalculator.personalRecords(sessions), isEmpty);
    });
  });
}
