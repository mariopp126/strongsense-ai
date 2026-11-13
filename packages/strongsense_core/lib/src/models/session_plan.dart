import 'coach_plan.dart';
import 'enums.dart';
import 'program.dart';
import 'readiness.dart';

/// A resolved set the user will actually perform.
class PlannedSet {
  const PlannedSet({
    required this.reps,
    this.repsMax,
    this.loadKg,
    this.rpeCap,
    this.adjusted = false,
  });

  final int reps;
  final int? repsMax;
  final double? loadKg;
  final double? rpeCap;

  /// True when the value differs from the raw program prescription.
  final bool adjusted;

  String get repsLabel => repsMax == null ? '$reps' : '$reps-$repsMax';

  PlannedSet copyWith({
    int? reps,
    int? repsMax,
    double? loadKg,
    double? rpeCap,
    bool? adjusted,
  }) {
    return PlannedSet(
      reps: reps ?? this.reps,
      repsMax: repsMax ?? this.repsMax,
      loadKg: loadKg ?? this.loadKg,
      rpeCap: rpeCap ?? this.rpeCap,
      adjusted: adjusted ?? this.adjusted,
    );
  }
}

/// A resolved exercise for the session, including substitutions.
class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    required this.name,
    required this.role,
    required this.sets,
    this.substitutedFor,
    this.notes,
  });

  final String exerciseId;
  final String name;
  final ExerciseRole role;
  final List<PlannedSet> sets;

  /// Original exercise name when a pain-aware substitution is active.
  final String? substitutedFor;
  final String? notes;

  bool get isSubstituted => substitutedFor != null;

  PlannedExercise copyWith({
    List<PlannedSet>? sets,
    String? name,
    String? substitutedFor,
  }) {
    return PlannedExercise(
      exerciseId: exerciseId,
      name: name ?? this.name,
      role: role,
      sets: sets ?? this.sets,
      substitutedFor: substitutedFor ?? this.substitutedFor,
      notes: notes,
    );
  }
}

/// The complete plan for one session: resolved sets + coach commentary.
class SessionPlan {
  const SessionPlan({
    required this.day,
    required this.readiness,
    required this.coach,
    required this.exercises,
    required this.blockWeek,
    this.isDeload = false,
  });

  final ProgramDay day;
  final ReadinessReport readiness;
  final CoachPlan coach;
  final List<PlannedExercise> exercises;
  final int blockWeek;
  final bool isDeload;

  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);

  double get totalPlannedVolumeKg => exercises.fold<double>(
    0,
    (sum, exercise) =>
        sum +
        exercise.sets.fold<double>(
          0,
          (inner, set) => inner + ((set.loadKg ?? 0) * set.reps),
        ),
  );

  CoachSource get source => coach.source;
}
