import 'dart:convert';
import 'dart:io';

import 'package:strongsense_core/strongsense_core.dart';

/// Reads a shared contract fixture. Tests run with the package as cwd, so the
/// repository root is two levels up.
Map<String, dynamic> loadFixture(String name) {
  final file = File('../../docs/contract/$name');
  if (!file.existsSync()) {
    throw StateError('Missing contract fixture: ${file.absolute.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Fixture $name is not a JSON object');
  }
  return decoded;
}

CoachRequest loadExampleRequest() =>
    CoachRequest.fromJson(loadFixture('coach-request.example.json'));

CoachContext loadExampleContext() => loadExampleRequest().context;

CoachPlan loadUnsafeModelOutput() =>
    CoachPlan.fromModelJson(loadFixture('unsafe-ai-output.example.json'));

CheckIn checkInAllFives({
  int timeAvailableMin = 60,
  int painSeverity = 0,
  List<PainArea> painAreas = const <PainArea>[],
}) => CheckIn(
  sleepQuality: 5,
  sleepHours: 8,
  energy: 5,
  motivation: 5,
  soreness: 1,
  stress: 1,
  painAreas: painAreas,
  painSeverity: painSeverity,
  timeAvailableMin: timeAvailableMin,
);

CheckIn checkInAmber({
  int timeAvailableMin = 60,
  int painSeverity = 0,
  List<PainArea> painAreas = const <PainArea>[],
}) => CheckIn(
  sleepQuality: 4,
  sleepHours: 7.5,
  energy: 3,
  motivation: 4,
  soreness: 2,
  stress: 2,
  painAreas: painAreas,
  painSeverity: painSeverity,
  timeAvailableMin: timeAvailableMin,
);

CheckIn checkInOrange({int timeAvailableMin = 60}) => CheckIn(
  sleepQuality: 3,
  sleepHours: 7,
  energy: 3,
  motivation: 3,
  soreness: 3,
  stress: 3,
  painSeverity: 0,
  timeAvailableMin: timeAvailableMin,
);

CheckIn checkInRed({int timeAvailableMin = 60}) => CheckIn(
  sleepQuality: 1,
  sleepHours: 5,
  energy: 1,
  motivation: 1,
  soreness: 5,
  stress: 5,
  painSeverity: 0,
  timeAvailableMin: timeAvailableMin,
);

ProgramDay dayById(String dayId) {
  final day = ProgramSeed.powerbuilding().dayById(dayId);
  if (day == null) {
    throw StateError('Unknown program day $dayId');
  }
  return day;
}

CoachContext buildContext({
  String dayId = 'day-2',
  required CheckIn checkIn,
  int blockWeek = 2,
  SessionClassification lastClassification = SessionClassification.none,
  List<LastLiftContext> lastLifts = const <LastLiftContext>[],
  List<RecentSessionSummary> recentSessions = const <RecentSessionSummary>[],
  List<PersonalRecord> personalRecords = const <PersonalRecord>[],
  TrainingSettings settings = const TrainingSettings(),
}) {
  final hasLastSession =
      lastClassification != SessionClassification.none || lastLifts.isNotEmpty;
  return CoachContext(
    date: DateTime(2026, 11, 14),
    blockWeek: blockWeek,
    programDay: dayById(dayId),
    checkIn: checkIn,
    readiness: ReadinessEngine.compute(checkIn),
    lastSession: hasLastSession
        ? LastSessionContext(
            date: DateTime(2026, 11, 9),
            classification: lastClassification,
            perLift: lastLifts,
          )
        : null,
    recentSessions: recentSessions,
    personalRecords: personalRecords,
    settings: settings,
  );
}

LastLiftContext liftContext({
  required String exerciseId,
  double topSetKg = 75,
  int topSetReps = 5,
  double topSetRpe = 8,
  int missedSets = 0,
}) => LastLiftContext(
  exerciseId: exerciseId,
  topSetKg: topSetKg,
  topSetReps: topSetReps,
  topSetRpe: topSetRpe,
  e1rmKg: E1rm.epley(topSetKg, topSetReps),
  missedSets: missedSets,
);

Adjustment? adjustmentFor(CoachPlan plan, String exerciseId) {
  for (final adjustment in plan.adjustments) {
    if (adjustment.exerciseId == exerciseId) {
      return adjustment;
    }
  }
  return null;
}

PlannedExercise? plannedFor(SessionPlan plan, String exerciseId) {
  for (final exercise in plan.exercises) {
    if (exercise.exerciseId == exerciseId) {
      return exercise;
    }
  }
  return null;
}

Session sessionWithBenchSets({
  required List<SetLog> logs,
  DateTime? completedAt,
}) {
  final startedAt = DateTime(2026, 11, 14, 10);
  return Session(
    id: 'session-1',
    dayId: 'day-2',
    date: DateTime(2026, 11, 14),
    startedAt: startedAt,
    status: SessionStatus.completed,
    checkIn: checkInAmber(),
    setLogs: logs,
    completedAt: completedAt,
  );
}

SetLog benchLog({
  required int index,
  int reps = 5,
  double loadKg = 75,
  double? rpe = 8,
  int targetReps = 5,
  bool completed = true,
}) => SetLog(
  exerciseId: 'ex-bench',
  setIndex: index,
  targetReps: targetReps,
  targetLoadKg: loadKg,
  reps: reps,
  loadKg: loadKg,
  rpe: rpe,
  completed: completed,
);
