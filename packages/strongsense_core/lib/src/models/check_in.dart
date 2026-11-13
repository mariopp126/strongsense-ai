import '../json/json_utils.dart';
import 'enums.dart';

/// Pre-session readiness questionnaire answers.
class CheckIn {
  const CheckIn({
    required this.sleepQuality,
    required this.energy,
    required this.motivation,
    required this.soreness,
    required this.stress,
    required this.painSeverity,
    required this.timeAvailableMin,
    this.sleepHours,
    this.painAreas = const <PainArea>[],
    this.bodyWeightKg,
    this.notes = '',
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    final checkIn = CheckIn(
      sleepQuality: json.requireInt('sleepQuality'),
      sleepHours: json.optDouble('sleepHours'),
      energy: json.requireInt('energy'),
      motivation: json.requireInt('motivation'),
      soreness: json.requireInt('soreness'),
      stress: json.requireInt('stress'),
      painAreas: json
          .optStringList('painAreas')
          .map(PainArea.fromWire)
          .toList(growable: false),
      painSeverity: json.requireInt('painSeverity'),
      timeAvailableMin: json.requireInt('timeAvailableMin'),
      bodyWeightKg: json.optDouble('bodyWeightKg'),
    );
    checkIn.validate();
    return checkIn;
  }

  /// 1 (terrible) .. 5 (excellent).
  final int sleepQuality;
  final double? sleepHours;

  /// 1 (empty) .. 5 (full).
  final int energy;

  /// 1 (none) .. 5 (high).
  final int motivation;

  /// 1 (none) .. 5 (very sore).
  final int soreness;

  /// 1 (calm) .. 5 (very stressed).
  final int stress;

  final List<PainArea> painAreas;

  /// 0 (no pain) .. 10 (worst imaginable).
  final int painSeverity;

  final int timeAvailableMin;
  final double? bodyWeightKg;
  final String notes;

  bool get hasPain => painSeverity > 0 || painAreas.isNotEmpty;

  void validate() {
    void inRange(String name, int value, int min, int max) {
      if (value < min || value > max) {
        throw ArgumentError('$name must be between $min and $max, got $value');
      }
    }

    inRange('sleepQuality', sleepQuality, 1, 5);
    inRange('energy', energy, 1, 5);
    inRange('motivation', motivation, 1, 5);
    inRange('soreness', soreness, 1, 5);
    inRange('stress', stress, 1, 5);
    inRange('painSeverity', painSeverity, 0, 10);
    inRange('timeAvailableMin', timeAvailableMin, 10, 240);
    final hours = sleepHours;
    if (hours != null && (hours < 0 || hours > 14)) {
      throw ArgumentError('sleepHours must be between 0 and 14, got $hours');
    }
    final weight = bodyWeightKg;
    if (weight != null && (weight < 30 || weight > 300)) {
      throw ArgumentError(
        'bodyWeightKg must be between 30 and 300, got $weight',
      );
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sleepQuality': sleepQuality,
    'sleepHours': sleepHours,
    'energy': energy,
    'motivation': motivation,
    'soreness': soreness,
    'stress': stress,
    'painAreas': painAreas.map((area) => area.wire).toList(growable: false),
    'painSeverity': painSeverity,
    'timeAvailableMin': timeAvailableMin,
    'bodyWeightKg': bodyWeightKg,
  };

  /// Full shape used for local persistence (adds free-text notes).
  Map<String, dynamic> toStorageJson() => <String, dynamic>{
    ...toJson(),
    'notes': notes,
  };

  CheckIn copyWith({
    int? sleepQuality,
    double? sleepHours,
    int? energy,
    int? motivation,
    int? soreness,
    int? stress,
    List<PainArea>? painAreas,
    int? painSeverity,
    int? timeAvailableMin,
    double? bodyWeightKg,
    String? notes,
  }) {
    return CheckIn(
      sleepQuality: sleepQuality ?? this.sleepQuality,
      sleepHours: sleepHours ?? this.sleepHours,
      energy: energy ?? this.energy,
      motivation: motivation ?? this.motivation,
      soreness: soreness ?? this.soreness,
      stress: stress ?? this.stress,
      painAreas: painAreas ?? this.painAreas,
      painSeverity: painSeverity ?? this.painSeverity,
      timeAvailableMin: timeAvailableMin ?? this.timeAvailableMin,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      notes: notes ?? this.notes,
    );
  }
}
