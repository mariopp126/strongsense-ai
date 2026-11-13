import '../models/coach_context.dart';
import '../models/coach_plan.dart';
import '../models/enums.dart';
import '../models/session_plan.dart';
import 'training_math.dart';

/// Turns a [CoachPlan] into the actual sets the user will see.
///
/// The load delta is always relative to the base working load: the load the
/// user actually used last time (scaled to preserve back-off structure), or the
/// program prescription on a first session.
abstract final class TargetResolver {
  static SessionPlan resolve({
    required CoachContext context,
    required CoachPlan plan,
  }) {
    final adjustments = <String, Adjustment>{
      for (final adjustment in plan.adjustments)
        adjustment.exerciseId: adjustment,
    };

    final resolved = <PlannedExercise>[];
    for (final exercise in context.programDay.exercises) {
      if (exercise.setTargets.isEmpty) {
        continue;
      }

      final adjustment = adjustments[exercise.id];
      final lastLift = context.lastSession?.liftById(exercise.id);
      final programTop = exercise.setTargets.fold<double>(
        0,
        (maximum, target) =>
            (target.loadKg ?? 0) > maximum ? target.loadKg! : maximum,
      );

      final targetCount = TrainingMath.clampInt(
        exercise.setTargets.length + (adjustment?.setsDelta ?? 0),
        1,
        12,
      );
      final substitute = adjustment?.substituteWith;
      final name = substitute ?? exercise.name;
      final delta = adjustment?.loadDeltaPct ?? 0;

      final sets = <PlannedSet>[];
      for (var index = 0; index < targetCount; index++) {
        final targetIndex = index < exercise.setTargets.length
            ? index
            : exercise.setTargets.length - 1;
        final target = exercise.setTargets[targetIndex];
        final baseLoad = _baseLoad(target.loadKg, programTop, lastLift);
        final loadKg = baseLoad == null
            ? null
            : TrainingMath.applyPercent(
                baseLoad,
                delta,
                increment: context.settings.increments.forExercise(
                  exercise.id,
                  exercise.name,
                ),
              );

        sets.add(
          PlannedSet(
            reps: target.reps,
            repsMax: target.repsMax,
            loadKg: loadKg,
            rpeCap: plan.rpeCap,
            adjusted:
                delta != 0 ||
                targetCount != exercise.setTargets.length ||
                substitute != null,
          ),
        );
      }

      resolved.add(
        PlannedExercise(
          exerciseId: exercise.id,
          name: name,
          role: exercise.role,
          sets: sets,
          substitutedFor: substitute == null ? null : exercise.name,
          notes: exercise.notes,
        ),
      );
    }

    _applyTimeBudget(context.checkIn.timeAvailableMin, resolved);

    return SessionPlan(
      day: context.programDay,
      readiness: context.readiness,
      coach: plan,
      exercises: List<PlannedExercise>.unmodifiable(resolved),
      blockWeek: context.blockWeek,
      isDeload: plan.deload,
    );
  }

  static double? _baseLoad(
    double? programLoad,
    double programTop,
    LastLiftContext? lastLift,
  ) {
    if (programLoad == null) {
      return null;
    }
    if (lastLift == null || programTop <= 0 || lastLift.topSetKg <= 0) {
      return programLoad;
    }
    final scale = (lastLift.topSetKg / programTop).clamp(0.6, 1.4);
    return programLoad * scale;
  }

  /// Short sessions drop accessories rather than rushing rest periods.
  static void _applyTimeBudget(int minutes, List<PlannedExercise> exercises) {
    if (minutes < 30) {
      exercises.removeWhere(
        (exercise) => exercise.role == ExerciseRole.accessory,
      );
    } else if (minutes < 45) {
      final index = exercises.lastIndexWhere(
        (exercise) => exercise.role == ExerciseRole.accessory,
      );
      if (index >= 0) {
        exercises.removeAt(index);
      }
    }
  }
}
