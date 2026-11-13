import '../json/json_utils.dart';
import 'enums.dart';

/// A single prescribed set: reps (or rep range), load and optional RPE cap.
class SetTarget {
  const SetTarget({required this.reps, this.repsMax, this.loadKg, this.rpeCap})
    : assert(reps > 0, 'reps must be positive'),
      assert(repsMax == null || repsMax >= reps, 'repsMax must be >= reps');

  factory SetTarget.fromJson(Map<String, dynamic> json) {
    final target = SetTarget(
      reps: json.requireInt('reps'),
      repsMax: json.optInt('repsMax'),
      loadKg: json.optDouble('loadKg'),
      rpeCap: json.optDouble('rpeCap'),
    );
    target.validate();
    return target;
  }

  final int reps;
  final int? repsMax;
  final double? loadKg;
  final double? rpeCap;

  String get repsLabel => repsMax == null ? '$reps' : '$reps-$repsMax';

  void validate() {
    if (reps < 1 || reps > 100) {
      throw ArgumentError('reps must be between 1 and 100, got $reps');
    }
    if (repsMax != null && (repsMax! < reps || repsMax! > 100)) {
      throw ArgumentError('repsMax must be between reps and 100, got $repsMax');
    }
    if (loadKg != null && (loadKg! < 0 || loadKg! > 1000)) {
      throw ArgumentError('loadKg must be between 0 and 1000, got $loadKg');
    }
    if (rpeCap != null && (rpeCap! < 1 || rpeCap! > 10)) {
      throw ArgumentError('rpeCap must be between 1 and 10, got $rpeCap');
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'reps': reps,
    'repsMax': repsMax,
    'loadKg': loadKg,
    'rpeCap': rpeCap,
  };

  SetTarget copyWith({
    int? reps,
    int? repsMax,
    bool clearRepsMax = false,
    double? loadKg,
    bool clearLoadKg = false,
    double? rpeCap,
    bool clearRpeCap = false,
  }) {
    return SetTarget(
      reps: reps ?? this.reps,
      repsMax: clearRepsMax ? null : (repsMax ?? this.repsMax),
      loadKg: clearLoadKg ? null : (loadKg ?? this.loadKg),
      rpeCap: clearRpeCap ? null : (rpeCap ?? this.rpeCap),
    );
  }

  @override
  String toString() => 'SetTarget($repsLabel reps, ${loadKg ?? '-'} kg)';
}

/// An exercise inside a program day.
class ProgramExercise {
  const ProgramExercise({
    required this.id,
    required this.name,
    required this.role,
    required this.setTargets,
    this.notes,
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> json) {
    final targets = json
        .requireMapList('setTargets')
        .map(SetTarget.fromJson)
        .toList(growable: false);
    return ProgramExercise(
      id: json.requireString('id'),
      name: json.requireString('name'),
      role: ExerciseRole.fromWire(json.requireString('role')),
      setTargets: targets,
      notes: json.optString('notes'),
    );
  }

  final String id;
  final String name;
  final ExerciseRole role;
  final List<SetTarget> setTargets;
  final String? notes;

  bool get isMain => role == ExerciseRole.main;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'role': role.wire,
    'setTargets': setTargets
        .map((target) => target.toJson())
        .toList(growable: false),
    if (notes != null) 'notes': notes,
  };

  ProgramExercise copyWith({
    String? name,
    ExerciseRole? role,
    List<SetTarget>? setTargets,
    String? notes,
  }) {
    return ProgramExercise(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      setTargets: setTargets ?? this.setTargets,
      notes: notes ?? this.notes,
    );
  }
}

/// One training day (for example "Bench & Upper Body").
class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.title,
    required this.focus,
    required this.exercises,
  });

  factory ProgramDay.fromJson(Map<String, dynamic> json) {
    return ProgramDay(
      id: json.requireString('id'),
      title: json.requireString('title'),
      focus: json.optString('focus') ?? '',
      exercises: json
          .requireMapList('exercises')
          .map(ProgramExercise.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String title;
  final String focus;
  final List<ProgramExercise> exercises;

  ProgramExercise? exerciseById(String exerciseId) {
    for (final exercise in exercises) {
      if (exercise.id == exerciseId) {
        return exercise;
      }
    }
    return null;
  }

  List<ProgramExercise> get mainExercises =>
      exercises.where((exercise) => exercise.isMain).toList(growable: false);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'focus': focus,
    'exercises': exercises
        .map((exercise) => exercise.toJson())
        .toList(growable: false),
  };

  ProgramDay copyWith({
    String? title,
    String? focus,
    List<ProgramExercise>? exercises,
  }) {
    return ProgramDay(
      id: id,
      title: title ?? this.title,
      focus: focus ?? this.focus,
      exercises: exercises ?? this.exercises,
    );
  }
}

/// A complete training program.
class TrainingProgram {
  const TrainingProgram({
    required this.id,
    required this.name,
    required this.days,
    this.isDefault = false,
  });

  factory TrainingProgram.fromJson(Map<String, dynamic> json) {
    return TrainingProgram(
      id: json.requireString('id'),
      name: json.requireString('name'),
      days: json
          .requireMapList('days')
          .map(ProgramDay.fromJson)
          .toList(growable: false),
      isDefault: json.optBool('isDefault') ?? false,
    );
  }

  final String id;
  final String name;
  final List<ProgramDay> days;
  final bool isDefault;

  ProgramDay? dayById(String dayId) {
    for (final day in days) {
      if (day.id == dayId) {
        return day;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'isDefault': isDefault,
    'days': days.map((day) => day.toJson()).toList(growable: false),
  };

  TrainingProgram copyWith({String? name, List<ProgramDay>? days}) {
    return TrainingProgram(
      id: id,
      name: name ?? this.name,
      days: days ?? this.days,
      isDefault: isDefault,
    );
  }
}
