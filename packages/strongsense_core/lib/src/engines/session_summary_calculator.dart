import '../models/program.dart';
import '../models/session.dart';
import '../models/session_summary.dart';
import 'e1rm.dart';

/// Turns a finished session into volume, e1RM and missed-set numbers.
abstract final class SessionSummaryCalculator {
  static SessionSummary summarize({
    required Session session,
    required ProgramDay day,
  }) {
    final logsByExercise = <String, List<SetLog>>{};
    for (final log in session.setLogs) {
      logsByExercise.putIfAbsent(log.exerciseId, () => <SetLog>[]).add(log);
    }

    final perLift = <LiftSummary>[];
    for (final exercise in day.exercises) {
      final logs = logsByExercise[exercise.id] ?? const <SetLog>[];
      if (logs.isEmpty && exercise.setTargets.isEmpty) {
        continue;
      }

      final completed = logs
          .where((log) => log.completed && !log.skipped)
          .toList(growable: false);

      var topSetKg = 0.0;
      var topSetReps = 0;
      var topSetRpe = 0.0;
      for (final log in completed) {
        final load = log.loadKg ?? 0;
        final reps = log.reps ?? 0;
        if (load > topSetKg || (load == topSetKg && reps > topSetReps)) {
          topSetKg = load;
          topSetReps = reps;
          topSetRpe = log.rpe ?? 0;
        }
      }

      final volume = completed.fold<double>(
        0,
        (sum, log) => sum + log.volumeKg,
      );
      final setsPlanned = logs.isNotEmpty
          ? logs.length
          : exercise.setTargets.length;

      perLift.add(
        LiftSummary(
          exerciseId: exercise.id,
          exercise: exercise.name,
          topSetKg: topSetKg,
          topSetReps: topSetReps,
          topSetRpe: topSetRpe,
          e1rmKg: E1rm.epley(topSetKg, topSetReps),
          volumeKg: volume,
          setsCompleted: completed.length,
          setsPlanned: setsPlanned,
          missedSets: logs.where((log) => log.isMissed).length,
        ),
      );
    }

    final totalVolume = perLift.fold<double>(
      0,
      (sum, lift) => sum + lift.volumeKg,
    );
    final completedAt = session.completedAt;
    final durationMin = completedAt == null
        ? 0
        : completedAt.difference(session.startedAt).inMinutes.clamp(0, 600);

    return SessionSummary(
      sessionId: session.id,
      dayId: session.dayId,
      date: session.date,
      totalVolumeKg: totalVolume,
      setsCompleted: session.completedSetCount,
      setsPlanned: session.setLogs.isEmpty
          ? day.exercises.fold<int>(
              0,
              (sum, exercise) => sum + exercise.setTargets.length,
            )
          : session.setLogs.length,
      avgRpe: session.averageRpe,
      sessionRpe: session.sessionRpe,
      missedSets: session.missedSets.length,
      durationMin: durationMin,
      perLift: perLift,
    );
  }
}
