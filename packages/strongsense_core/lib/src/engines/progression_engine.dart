import '../models/coach_context.dart';
import '../models/program.dart';
import '../models/session.dart';
import 'training_math.dart';

/// Recommends the top working load for the next session of a program day.
abstract final class ProgressionEngine {
  static const double increasePct = 2.5;
  static const double decreasePct = -2.5;

  /// All target reps hit and RPE <= 8 -> +2.5%.
  /// At most one missed set and RPE <= 9 -> repeat.
  /// Otherwise -> -2.5%.
  static Map<String, double> nextTopLoads({
    required Session session,
    required ProgramDay day,
    required Increments increments,
  }) {
    final result = <String, double>{};

    for (final exercise in day.exercises) {
      final logs = session.setLogs
          .where(
            (log) =>
                log.exerciseId == exercise.id && log.completed && !log.skipped,
          )
          .toList(growable: false);
      if (logs.isEmpty) {
        continue;
      }

      var topLoad = 0.0;
      for (final log in logs) {
        final load = log.loadKg ?? 0;
        if (load > topLoad) {
          topLoad = load;
        }
      }
      if (topLoad <= 0) {
        continue;
      }

      final missed = logs.where((log) => log.isMissed).length;
      final rpes = logs
          .where((log) => log.rpe != null)
          .map((log) => log.rpe!)
          .toList(growable: false);
      final averageRpe = rpes.isEmpty
          ? null
          : rpes.fold<double>(0, (sum, rpe) => sum + rpe) / rpes.length;

      final double percent;
      if (missed == 0 && (averageRpe == null || averageRpe <= 8.0)) {
        percent = increasePct;
      } else if (missed <= 1 && (averageRpe == null || averageRpe <= 9.0)) {
        percent = 0;
      } else {
        percent = decreasePct;
      }

      result[exercise.id] = TrainingMath.applyPercent(
        topLoad,
        percent,
        increment: increments.forExercise(exercise.id, exercise.name),
      );
    }

    return result;
  }
}
