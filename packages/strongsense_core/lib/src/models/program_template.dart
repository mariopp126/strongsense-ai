import '../json/json_utils.dart';

/// Persisted state for a program built from a template.
///
/// The days in [TrainingProgram] are materialized for [week]. Keeping the
/// template id and training maxes lets the app rebuild the next week without
/// losing the user's progression.
class ProgramTemplateState {
  const ProgramTemplateState({
    required this.templateId,
    required this.week,
    required this.trainingMaxKg,
  });

  factory ProgramTemplateState.fromJson(Map<String, dynamic> json) {
    return ProgramTemplateState(
      templateId: json.requireString('templateId'),
      week: json.requireInt('week'),
      trainingMaxKg: json.requireDoubleMap('trainingMaxKg'),
    );
  }

  final String templateId;

  /// 1-based week inside the current cycle (1..4).
  final int week;

  /// Training max per main exercise id, in kilograms.
  final Map<String, double> trainingMaxKg;

  ProgramTemplateState copyWith({
    String? templateId,
    int? week,
    Map<String, double>? trainingMaxKg,
  }) {
    return ProgramTemplateState(
      templateId: templateId ?? this.templateId,
      week: week ?? this.week,
      trainingMaxKg: trainingMaxKg ?? this.trainingMaxKg,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'templateId': templateId,
    'week': week,
    'trainingMaxKg': trainingMaxKg,
  };
}
