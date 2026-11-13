import '../json/json_utils.dart';

/// Best estimated one-rep max for a lift.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.e1rmKg,
    required this.date,
    this.weightKg = 0,
    this.reps = 0,
    this.sessionId,
  });

  /// Contract shape (`{exerciseId, e1rmKg, date}`).
  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    exerciseId: json.requireString('exerciseId'),
    e1rmKg: json.requireDouble('e1rmKg'),
    date: parseDateOnly(json.requireString('date')),
    weightKg: json.optDouble('weightKg') ?? 0,
    reps: json.optInt('reps') ?? 0,
    sessionId: json.optString('sessionId'),
  );

  factory PersonalRecord.fromStorageJson(Map<String, dynamic> json) =>
      PersonalRecord.fromJson(json);

  final String exerciseId;
  final double e1rmKg;
  final DateTime date;
  final double weightKg;
  final int reps;
  final String? sessionId;

  /// Contract shape — the server rejects unknown fields.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'exerciseId': exerciseId,
    'e1rmKg': e1rmKg,
    'date': formatDateOnly(date),
  };

  /// Full shape used for local persistence and export.
  Map<String, dynamic> toStorageJson() => <String, dynamic>{
    'exerciseId': exerciseId,
    'e1rmKg': e1rmKg,
    'date': formatDateOnly(date),
    'weightKg': weightKg,
    'reps': reps,
    'sessionId': sessionId,
  };
}
