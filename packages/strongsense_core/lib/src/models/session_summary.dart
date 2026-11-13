import '../json/json_utils.dart';

/// Per-lift numbers for a completed session.
class LiftSummary {
  const LiftSummary({
    required this.exerciseId,
    required this.exercise,
    required this.topSetKg,
    required this.topSetReps,
    required this.topSetRpe,
    required this.e1rmKg,
    required this.volumeKg,
    required this.setsCompleted,
    required this.setsPlanned,
    required this.missedSets,
  });

  factory LiftSummary.fromJson(Map<String, dynamic> json) => LiftSummary(
    exerciseId: json.requireString('exerciseId'),
    exercise: json.requireString('exercise'),
    topSetKg: json.requireDouble('topSetKg'),
    topSetReps: json.requireInt('topSetReps'),
    topSetRpe: json.requireDouble('topSetRpe'),
    e1rmKg: json.requireDouble('e1rmKg'),
    volumeKg: json.requireDouble('volumeKg'),
    setsCompleted: json.requireInt('setsCompleted'),
    setsPlanned: json.requireInt('setsPlanned'),
    missedSets: json.requireInt('missedSets'),
  );

  final String exerciseId;
  final String exercise;
  final double topSetKg;
  final int topSetReps;
  final double topSetRpe;
  final double e1rmKg;
  final double volumeKg;
  final int setsCompleted;
  final int setsPlanned;
  final int missedSets;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'exerciseId': exerciseId,
    'exercise': exercise,
    'topSetKg': topSetKg,
    'topSetReps': topSetReps,
    'topSetRpe': topSetRpe,
    'e1rmKg': e1rmKg,
    'volumeKg': volumeKg,
    'setsCompleted': setsCompleted,
    'setsPlanned': setsPlanned,
    'missedSets': missedSets,
  };
}

/// Aggregate numbers for a completed session.
class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.dayId,
    required this.date,
    required this.totalVolumeKg,
    required this.setsCompleted,
    required this.setsPlanned,
    required this.missedSets,
    required this.durationMin,
    required this.perLift,
    this.avgRpe,
    this.sessionRpe,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    final avg = json.optDouble('avgRpe');
    return SessionSummary(
      sessionId: json.requireString('sessionId'),
      dayId: json.requireString('dayId'),
      date: parseDateOnly(json.requireString('date')),
      totalVolumeKg: json.requireDouble('totalVolumeKg'),
      setsCompleted: json.requireInt('setsCompleted'),
      setsPlanned: json.requireInt('setsPlanned'),
      avgRpe: avg,
      sessionRpe: json.optDouble('sessionRpe'),
      missedSets: json.requireInt('missedSets'),
      durationMin: json.requireInt('durationMin'),
      perLift: json
          .optMapList('perLift')
          .map(LiftSummary.fromJson)
          .toList(growable: false),
    );
  }

  final String sessionId;
  final String dayId;
  final DateTime date;
  final double totalVolumeKg;
  final int setsCompleted;
  final int setsPlanned;
  final double? avgRpe;
  final double? sessionRpe;
  final int missedSets;
  final int durationMin;
  final List<LiftSummary> perLift;

  double get completionRatio =>
      setsPlanned == 0 ? 0 : setsCompleted / setsPlanned;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'dayId': dayId,
    'date': formatDateOnly(date),
    'totalVolumeKg': totalVolumeKg,
    'setsCompleted': setsCompleted,
    'setsPlanned': setsPlanned,
    'avgRpe': avgRpe,
    'sessionRpe': sessionRpe,
    'missedSets': missedSets,
    'durationMin': durationMin,
    'perLift': perLift.map((lift) => lift.toJson()).toList(growable: false),
  };
}
