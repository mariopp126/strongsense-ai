import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../data/repositories/coach_plan_repository.dart';
import '../data/repositories/session_repository.dart';

/// Owns the active session (draft or completed-but-not-dismissed).
class SessionController extends StateNotifier<Session?> {
  SessionController({
    required SessionRepository repository,
    required CoachPlanRepository coachPlanRepository,
    Session? initial,
  }) : _repository = repository,
       _coachPlanRepository = coachPlanRepository,
       super(initial);

  final SessionRepository _repository;
  final CoachPlanRepository _coachPlanRepository;

  /// Creates a session from the resolved plan and persists it immediately.
  Future<Session> start({
    required CheckIn checkIn,
    required SessionPlan plan,
  }) async {
    final now = DateTime.now();
    final session = Session(
      id: 'session-${now.microsecondsSinceEpoch}',
      dayId: plan.day.id,
      date: DateTime(now.year, now.month, now.day),
      startedAt: now,
      checkIn: checkIn,
      setLogs: <SetLog>[
        for (final exercise in plan.exercises)
          for (var index = 0; index < exercise.sets.length; index++)
            SetLog(
              exerciseId: exercise.exerciseId,
              setIndex: index,
              targetReps: exercise.sets[index].reps,
              targetLoadKg: exercise.sets[index].loadKg,
              reps: exercise.sets[index].reps,
              loadKg: exercise.sets[index].loadKg,
            ),
      ],
    );

    state = session;
    await _repository.save(session);
    await _coachPlanRepository.save(session.id, plan.coach);
    return session;
  }

  Future<void> load(String id) async {
    if (state?.id == id) {
      return;
    }
    state = await _repository.byId(id);
  }

  Future<void> toggleSet(String exerciseId, int setIndex) async {
    final current = state;
    if (current == null) {
      return;
    }
    final logs = current.setLogs
        .map(
          (log) => log.exerciseId == exerciseId && log.setIndex == setIndex
              ? log.copyWith(completed: !log.completed, skipped: false)
              : log,
        )
        .toList(growable: false);
    await _update(current.copyWith(setLogs: logs));
  }

  Future<void> markSkipped(String exerciseId, int setIndex) async {
    final current = state;
    if (current == null) {
      return;
    }
    final logs = current.setLogs
        .map(
          (log) => log.exerciseId == exerciseId && log.setIndex == setIndex
              ? log.copyWith(skipped: true, completed: true)
              : log,
        )
        .toList(growable: false);
    await _update(current.copyWith(setLogs: logs));
  }

  Future<void> updateSet(
    String exerciseId,
    int setIndex, {
    int? reps,
    double? loadKg,
    double? rpe,
  }) async {
    final current = state;
    if (current == null) {
      return;
    }
    final logs = current.setLogs
        .map(
          (log) => log.exerciseId == exerciseId && log.setIndex == setIndex
              ? log.copyWith(reps: reps, loadKg: loadKg, rpe: rpe)
              : log,
        )
        .toList(growable: false);
    await _update(current.copyWith(setLogs: logs));
  }

  Future<SessionSummary> finish({
    required ProgramDay day,
    double? sessionRpe,
    String notes = '',
  }) async {
    final current = state;
    if (current == null) {
      throw StateError('No active session to finish');
    }

    final completed = current.copyWith(
      status: SessionStatus.completed,
      completedAt: DateTime.now(),
      sessionRpe: sessionRpe,
      notes: notes,
    );
    state = completed;
    await _repository.save(completed);

    return SessionSummaryCalculator.summarize(session: completed, day: day);
  }

  Future<void> discard() async {
    final current = state;
    if (current == null) {
      return;
    }
    await _repository.delete(current.id);
    state = null;
  }

  /// Clears the in-memory session once the summary has been dismissed.
  void clear() {
    state = null;
  }

  Future<void> _update(Session session) async {
    state = session;
    await _repository.save(session);
  }
}
