import '../json/json_utils.dart';
import 'check_in.dart';
import 'enums.dart';
import 'personal_record.dart';
import 'program.dart';
import 'readiness.dart';

/// Per-lift load increments, in kilograms.
class Increments {
  const Increments({
    this.benchKg = 2.5,
    this.squatKg = 5.0,
    this.deadliftKg = 5.0,
    this.accessoryKg = 2.5,
  });

  factory Increments.fromJson(Map<String, dynamic> json) => Increments(
    benchKg: json.optDouble('benchKg') ?? 2.5,
    squatKg: json.optDouble('squatKg') ?? 5.0,
    deadliftKg: json.optDouble('deadliftKg') ?? 5.0,
    accessoryKg: json.optDouble('accessoryKg') ?? 2.5,
  );

  final double benchKg;
  final double squatKg;
  final double deadliftKg;
  final double accessoryKg;

  /// Rounding increment for an exercise, based on its id/name.
  double forExercise(String exerciseId, String name) {
    final haystack = '$exerciseId $name'.toLowerCase();
    if (haystack.contains('bench') || haystack.contains('spoto')) {
      return benchKg;
    }
    if (haystack.contains('squat')) {
      return squatKg;
    }
    if (haystack.contains('deadlift') || haystack.contains('dead lift')) {
      return deadliftKg;
    }
    return accessoryKg;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'benchKg': benchKg,
    'squatKg': squatKg,
    'deadliftKg': deadliftKg,
    'accessoryKg': accessoryKg,
  };
}

/// Training-related settings included in the coach context.
class TrainingSettings {
  const TrainingSettings({
    this.unit = Unit.kg,
    this.increments = const Increments(),
  });

  factory TrainingSettings.fromJson(Map<String, dynamic> json) =>
      TrainingSettings(
        unit: Unit.fromWire(json.optString('unit') ?? 'kg'),
        increments: json.optMap('increments') == null
            ? const Increments()
            : Increments.fromJson(json.requireMap('increments')),
      );

  final Unit unit;
  final Increments increments;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'unit': unit.wire,
    'increments': increments.toJson(),
  };
}

/// Limits mirrored by the server and the client safety clamp.
class TrainingConstraints {
  const TrainingConstraints({
    this.maxLoadDeltaPct = 5.0,
    this.minLoadDeltaPct = -10.0,
    this.maxSetsDelta = 2,
    this.rpeCapMax = 9.0,
    this.maxTips = 12,
  });

  factory TrainingConstraints.fromJson(Map<String, dynamic> json) =>
      TrainingConstraints(
        maxLoadDeltaPct: json.optDouble('maxLoadDeltaPct') ?? 5.0,
        minLoadDeltaPct: json.optDouble('minLoadDeltaPct') ?? -10.0,
        maxSetsDelta: json.optInt('maxSetsDelta') ?? 2,
        rpeCapMax: json.optDouble('rpeCapMax') ?? 9.0,
        maxTips: json.optInt('maxTips') ?? 12,
      );

  final double maxLoadDeltaPct;
  final double minLoadDeltaPct;
  final int maxSetsDelta;
  final double rpeCapMax;
  final int maxTips;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'maxLoadDeltaPct': maxLoadDeltaPct,
    'minLoadDeltaPct': minLoadDeltaPct,
    'maxSetsDelta': maxSetsDelta,
    'rpeCapMax': rpeCapMax,
    'maxTips': maxTips,
  };
}

/// How one lift performed in the previous session.
class LastLiftContext {
  const LastLiftContext({
    required this.exerciseId,
    required this.topSetKg,
    required this.topSetReps,
    required this.topSetRpe,
    required this.e1rmKg,
    required this.missedSets,
  });

  factory LastLiftContext.fromJson(Map<String, dynamic> json) =>
      LastLiftContext(
        exerciseId: json.requireString('exerciseId'),
        topSetKg: json.requireDouble('topSetKg'),
        topSetReps: json.requireInt('topSetReps'),
        topSetRpe: json.requireDouble('topSetRpe'),
        e1rmKg: json.requireDouble('e1rmKg'),
        missedSets: json.requireInt('missedSets'),
      );

  final String exerciseId;
  final double topSetKg;
  final int topSetReps;
  final double topSetRpe;
  final double e1rmKg;
  final int missedSets;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'exerciseId': exerciseId,
    'topSetKg': topSetKg,
    'topSetReps': topSetReps,
    'topSetRpe': topSetRpe,
    'e1rmKg': e1rmKg,
    'missedSets': missedSets,
  };
}

/// Summary of the most recent session for the same day.
class LastSessionContext {
  const LastSessionContext({
    required this.date,
    required this.classification,
    required this.perLift,
  });

  factory LastSessionContext.fromJson(Map<String, dynamic> json) =>
      LastSessionContext(
        date: parseDateOnly(json.requireString('date')),
        classification: SessionClassification.fromWire(
          json.requireString('classification'),
        ),
        perLift: json
            .optMapList('perLift')
            .map(LastLiftContext.fromJson)
            .toList(growable: false),
      );

  final DateTime date;
  final SessionClassification classification;
  final List<LastLiftContext> perLift;

  LastLiftContext? liftById(String exerciseId) {
    for (final lift in perLift) {
      if (lift.exerciseId == exerciseId) {
        return lift;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': formatDateOnly(date),
    'classification': classification.wire,
    'perLift': perLift.map((lift) => lift.toJson()).toList(growable: false),
  };
}

/// Compact history entry sent to the coach.
class RecentSessionSummary {
  const RecentSessionSummary({
    required this.date,
    required this.dayId,
    required this.classification,
    required this.avgRpe,
    required this.volumeKg,
    required this.missedSets,
  });

  factory RecentSessionSummary.fromJson(Map<String, dynamic> json) =>
      RecentSessionSummary(
        date: parseDateOnly(json.requireString('date')),
        dayId: json.requireString('dayId'),
        classification: SessionClassification.fromWire(
          json.requireString('classification'),
        ),
        avgRpe: json.requireDouble('avgRpe'),
        volumeKg: json.requireDouble('volumeKg'),
        missedSets: json.requireInt('missedSets'),
      );

  final DateTime date;
  final String dayId;
  final SessionClassification classification;
  final double avgRpe;
  final double volumeKg;
  final int missedSets;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': formatDateOnly(date),
    'dayId': dayId,
    'classification': classification.wire,
    'avgRpe': avgRpe,
    'volumeKg': volumeKg,
    'missedSets': missedSets,
  };
}

/// Everything the coach needs about one upcoming session.
class CoachContext {
  const CoachContext({
    required this.date,
    required this.blockWeek,
    required this.programDay,
    required this.checkIn,
    required this.readiness,
    required this.settings,
    this.lastSession,
    this.recentSessions = const <RecentSessionSummary>[],
    this.personalRecords = const <PersonalRecord>[],
    this.constraints = const TrainingConstraints(),
  });

  factory CoachContext.fromJson(Map<String, dynamic> json) => CoachContext(
    date: parseDateOnly(json.requireString('date')),
    blockWeek: json.requireInt('blockWeek'),
    programDay: ProgramDay.fromJson(json.requireMap('programDay')),
    checkIn: CheckIn.fromJson(json.requireMap('checkIn')),
    readiness: ReadinessReport.fromJson(json.requireMap('readiness')),
    lastSession: json.optMap('lastSession') == null
        ? null
        : LastSessionContext.fromJson(json.requireMap('lastSession')),
    recentSessions: json
        .optMapList('recentSessions')
        .map(RecentSessionSummary.fromJson)
        .toList(growable: false),
    personalRecords: json
        .optMapList('personalRecords')
        .map(PersonalRecord.fromJson)
        .toList(growable: false),
    settings: json.optMap('settings') == null
        ? const TrainingSettings()
        : TrainingSettings.fromJson(json.requireMap('settings')),
    constraints: json.optMap('constraints') == null
        ? const TrainingConstraints()
        : TrainingConstraints.fromJson(json.requireMap('constraints')),
  );

  final DateTime date;

  /// Week within the current training block (1-based).
  final int blockWeek;
  final ProgramDay programDay;
  final CheckIn checkIn;
  final ReadinessReport readiness;
  final LastSessionContext? lastSession;
  final List<RecentSessionSummary> recentSessions;
  final List<PersonalRecord> personalRecords;
  final TrainingSettings settings;
  final TrainingConstraints constraints;

  Unit get unit => settings.unit;

  CoachContext copyWith({
    DateTime? date,
    int? blockWeek,
    ProgramDay? programDay,
    CheckIn? checkIn,
    ReadinessReport? readiness,
    LastSessionContext? lastSession,
    bool clearLastSession = false,
    List<RecentSessionSummary>? recentSessions,
    List<PersonalRecord>? personalRecords,
    TrainingSettings? settings,
    TrainingConstraints? constraints,
  }) {
    return CoachContext(
      date: date ?? this.date,
      blockWeek: blockWeek ?? this.blockWeek,
      programDay: programDay ?? this.programDay,
      checkIn: checkIn ?? this.checkIn,
      readiness: readiness ?? this.readiness,
      lastSession: clearLastSession ? null : (lastSession ?? this.lastSession),
      recentSessions: recentSessions ?? this.recentSessions,
      personalRecords: personalRecords ?? this.personalRecords,
      settings: settings ?? this.settings,
      constraints: constraints ?? this.constraints,
    );
  }

  /// Contract v1 wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': formatDateOnly(date),
    'blockWeek': blockWeek,
    'unit': settings.unit.wire,
    'programDay': _programDayToJson(),
    'checkIn': _checkInToJson(),
    'readiness': readiness.toJson(),
    'lastSession': lastSession?.toJson(),
    'recentSessions': recentSessions
        .map((session) => session.toJson())
        .toList(growable: false),
    'personalRecords': personalRecords
        .map((record) => record.toJson())
        .toList(growable: false),
    'settings': settings.toJson(),
    'constraints': constraints.toJson(),
  };

  Map<String, dynamic> _programDayToJson() => <String, dynamic>{
    'id': programDay.id,
    'title': programDay.title,
    'exercises': programDay.exercises
        .map(
          (exercise) => <String, dynamic>{
            'id': exercise.id,
            'name': exercise.name,
            'role': exercise.role.wire,
            'setTargets': exercise.setTargets
                .map((target) => target.toJson())
                .toList(growable: false),
          },
        )
        .toList(growable: false),
  };

  Map<String, dynamic> _checkInToJson() => <String, dynamic>{
    'sleepQuality': checkIn.sleepQuality,
    'sleepHours': checkIn.sleepHours,
    'energy': checkIn.energy,
    'motivation': checkIn.motivation,
    'soreness': checkIn.soreness,
    'stress': checkIn.stress,
    'painAreas': checkIn.painAreas
        .map((area) => area.wire)
        .toList(growable: false),
    'painSeverity': checkIn.painSeverity,
    'timeAvailableMin': checkIn.timeAvailableMin,
  };
}
