import 'package:strongsense_core/strongsense_core.dart';

import '../repositories/session_repository.dart';

/// Builds the structured context sent to the coach from local history.
class CoachContextService {
  CoachContextService({
    required this.sessionRepository,
    required this.program,
    required this.settings,
  });

  final SessionRepository sessionRepository;
  final TrainingProgram program;
  final AppSettings settings;

  Future<CoachContext> build({
    required ProgramDay day,
    required CheckIn checkIn,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final completed = await sessionRepository.loadCompleted();

    final lastForDay = completed.where((session) => session.dayId == day.id);
    final lastSession = lastForDay.isEmpty
        ? null
        : _toLastSession(lastForDay.first, day);

    final recent = completed
        .take(6)
        .map(
          (session) => RecentSessionSummary(
            date: session.date,
            dayId: session.dayId,
            classification: SessionClassifier.classify(
              session: session,
              mainExerciseIds: _mainIdsFor(session.dayId),
            ),
            avgRpe: session.averageRpe ?? 0,
            volumeKg: session.totalVolumeKg,
            missedSets: session.missedSets.length,
          ),
        )
        .toList(growable: false);

    final records = RecordsCalculator.personalRecords(completed);
    final blockWeek = (completed.length ~/ 3) + 1;

    return CoachContext(
      date: DateTime(today.year, today.month, today.day),
      blockWeek: blockWeek,
      programDay: day,
      checkIn: checkIn,
      readiness: ReadinessEngine.compute(checkIn),
      lastSession: lastSession,
      recentSessions: recent,
      personalRecords: records,
      settings: settings.training,
      constraints: const TrainingConstraints(),
    );
  }

  LastSessionContext _toLastSession(Session session, ProgramDay day) {
    final classification = SessionClassifier.classify(
      session: session,
      mainExerciseIds: day.mainExercises.map((exercise) => exercise.id).toSet(),
    );

    final perLift = <LastLiftContext>[];
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

      var topKg = 0.0;
      var topReps = 0;
      var topRpe = 0.0;
      for (final log in logs) {
        final load = log.loadKg ?? 0;
        final reps = log.reps ?? 0;
        if (load > topKg || (load == topKg && reps > topReps)) {
          topKg = load;
          topReps = reps;
          topRpe = log.rpe ?? 0;
        }
      }
      if (topKg <= 0) {
        continue;
      }

      perLift.add(
        LastLiftContext(
          exerciseId: exercise.id,
          topSetKg: topKg,
          topSetReps: topReps,
          topSetRpe: topRpe,
          e1rmKg: E1rm.epley(topKg, topReps),
          missedSets: logs.where((log) => log.isMissed).length,
        ),
      );
    }

    return LastSessionContext(
      date: session.date,
      classification: classification,
      perLift: perLift,
    );
  }

  Set<String> _mainIdsFor(String dayId) {
    final day = program.dayById(dayId);
    return day == null
        ? const <String>{}
        : day.mainExercises.map((exercise) => exercise.id).toSet();
  }
}
