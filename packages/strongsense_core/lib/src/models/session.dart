import '../json/json_utils.dart';
import 'check_in.dart';
import 'enums.dart';

/// One logged set inside a session.
class SetLog {
  const SetLog({
    required this.exerciseId,
    required this.setIndex,
    required this.targetReps,
    this.targetLoadKg,
    this.reps,
    this.loadKg,
    this.rpe,
    this.completed = false,
    this.skipped = false,
    this.notes = '',
  });

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
    exerciseId: json.requireString('exerciseId'),
    setIndex: json.requireInt('setIndex'),
    targetReps: json.requireInt('targetReps'),
    targetLoadKg: json.optDouble('targetLoadKg'),
    reps: json.optInt('reps'),
    loadKg: json.optDouble('loadKg'),
    rpe: json.optDouble('rpe'),
    completed: json.optBool('completed') ?? false,
    skipped: json.optBool('skipped') ?? false,
    notes: json.optString('notes') ?? '',
  );

  final String exerciseId;
  final int setIndex;
  final int targetReps;
  final double? targetLoadKg;
  final int? reps;
  final double? loadKg;
  final double? rpe;
  final bool completed;
  final bool skipped;
  final String notes;

  double get volumeKg => (reps ?? 0) * (loadKg ?? 0);

  /// True when the user did fewer reps than prescribed.
  bool get isMissed =>
      completed && reps != null && reps! < targetReps && !skipped;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'exerciseId': exerciseId,
    'setIndex': setIndex,
    'targetReps': targetReps,
    'targetLoadKg': targetLoadKg,
    'reps': reps,
    'loadKg': loadKg,
    'rpe': rpe,
    'completed': completed,
    'skipped': skipped,
    'notes': notes,
  };

  SetLog copyWith({
    int? reps,
    double? loadKg,
    double? rpe,
    bool? completed,
    bool? skipped,
    String? notes,
  }) {
    return SetLog(
      exerciseId: exerciseId,
      setIndex: setIndex,
      targetReps: targetReps,
      targetLoadKg: targetLoadKg,
      reps: reps ?? this.reps,
      loadKg: loadKg ?? this.loadKg,
      rpe: rpe ?? this.rpe,
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      notes: notes ?? this.notes,
    );
  }
}

/// A training session (one program day performed on one date).
class Session {
  const Session({
    required this.id,
    required this.dayId,
    required this.date,
    required this.startedAt,
    required this.checkIn,
    required this.setLogs,
    this.status = SessionStatus.inProgress,
    this.notes = '',
    this.completedAt,
    this.sessionRpe,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json.requireString('id'),
    dayId: json.requireString('dayId'),
    date: parseDateOnly(json.requireString('date')),
    startedAt: DateTime.parse(json.requireString('startedAt')).toLocal(),
    status: SessionStatus.fromWire(json.requireString('status')),
    checkIn: CheckIn.fromJson(json.requireMap('checkIn')),
    setLogs: json
        .optMapList('setLogs')
        .map(SetLog.fromJson)
        .toList(growable: false),
    notes: json.optString('notes') ?? '',
    completedAt: json.optString('completedAt') == null
        ? null
        : DateTime.parse(json.requireString('completedAt')).toLocal(),
    sessionRpe: json.optDouble('sessionRpe'),
  );

  final String id;
  final String dayId;
  final DateTime date;
  final DateTime startedAt;
  final SessionStatus status;
  final CheckIn checkIn;
  final List<SetLog> setLogs;
  final String notes;
  final DateTime? completedAt;
  final double? sessionRpe;

  bool get isCompleted => status == SessionStatus.completed;

  List<SetLog> get completedSets =>
      setLogs.where((set) => set.completed).toList(growable: false);

  List<SetLog> get missedSets =>
      setLogs.where((set) => set.isMissed).toList(growable: false);

  int get plannedSetCount => setLogs.length;

  int get completedSetCount => completedSets.length;

  double get totalVolumeKg =>
      completedSets.fold(0, (sum, set) => sum + set.volumeKg);

  double? get averageRpe {
    final withRpe = completedSets
        .where((set) => set.rpe != null)
        .toList(growable: false);
    if (withRpe.isEmpty) {
      return null;
    }
    final total = withRpe.fold<double>(0, (sum, set) => sum + (set.rpe ?? 0));
    return total / withRpe.length;
  }

  Session copyWith({
    SessionStatus? status,
    List<SetLog>? setLogs,
    String? notes,
    DateTime? completedAt,
    double? sessionRpe,
  }) {
    return Session(
      id: id,
      dayId: dayId,
      date: date,
      startedAt: startedAt,
      status: status ?? this.status,
      checkIn: checkIn,
      setLogs: setLogs ?? this.setLogs,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      sessionRpe: sessionRpe ?? this.sessionRpe,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'dayId': dayId,
    'date': formatDateOnly(date),
    'startedAt': formatTimestamp(startedAt),
    'status': status.wire,
    'checkIn': checkIn.toStorageJson(),
    'setLogs': setLogs.map((set) => set.toJson()).toList(growable: false),
    'notes': notes,
    'completedAt': completedAt == null ? null : formatTimestamp(completedAt!),
    'sessionRpe': sessionRpe,
  };
}
