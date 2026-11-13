import '../models/personal_record.dart';
import '../models/session.dart';
import 'e1rm.dart';

/// Derives personal records from completed sessions (no extra storage needed).
abstract final class RecordsCalculator {
  static List<PersonalRecord> personalRecords(Iterable<Session> sessions) {
    final best = <String, PersonalRecord>{};

    for (final session in sessions) {
      for (final set in session.setLogs) {
        if (!set.completed || set.skipped) {
          continue;
        }
        final load = set.loadKg ?? 0;
        final reps = set.reps ?? 0;
        if (load <= 0 || reps <= 0) {
          continue;
        }
        final estimate = E1rm.epley(load, reps);
        final current = best[set.exerciseId];
        if (current == null || estimate > current.e1rmKg) {
          best[set.exerciseId] = PersonalRecord(
            exerciseId: set.exerciseId,
            e1rmKg: estimate,
            date: session.date,
            weightKg: load,
            reps: reps,
            sessionId: session.id,
          );
        }
      }
    }

    final records = best.values.toList(growable: false)
      ..sort((a, b) => b.e1rmKg.compareTo(a.e1rmKg));
    return records;
  }

  static PersonalRecord? bestFor(
    String exerciseId,
    Iterable<Session> sessions,
  ) {
    for (final record in personalRecords(sessions)) {
      if (record.exerciseId == exerciseId) {
        return record;
      }
    }
    return null;
  }
}
