import '../json/json_utils.dart';
import 'enums.dart';

/// A single coaching tip shown in the Coach tab.
class CoachTip {
  const CoachTip({
    required this.title,
    required this.body,
    required this.category,
  });

  factory CoachTip.fromJson(Map<String, dynamic> json) => CoachTip(
    title: json.requireString('title'),
    body: json.requireString('body'),
    category: TipCategory.fromWire(json.requireString('category')),
  );

  final String title;
  final String body;
  final TipCategory category;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'body': body,
    'category': category.wire,
  };

  CoachTip copyWith({String? title, String? body, TipCategory? category}) {
    return CoachTip(
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
    );
  }
}

/// A load/volume adjustment for one exercise.
///
/// Values are intentionally *not* range-checked while decoding: AI output can
/// be out of bounds and must reach [SafetyBounds.clamp] so it can be repaired
/// instead of discarded.
class Adjustment {
  const Adjustment({
    required this.exerciseId,
    required this.exercise,
    required this.loadDeltaPct,
    required this.setsDelta,
    required this.reason,
    this.repsHint,
    this.substituteWith,
  });

  factory Adjustment.fromJson(Map<String, dynamic> json) => Adjustment(
    exerciseId: json.requireString('exerciseId'),
    exercise: json.requireString('exercise'),
    loadDeltaPct: json.requireDouble('loadDeltaPct'),
    setsDelta: json.requireInt('setsDelta'),
    repsHint: json.optString('repsHint'),
    reason: json.requireString('reason'),
    substituteWith: json.optString('substituteWith'),
  );

  final String exerciseId;
  final String exercise;

  /// Relative to the base working load, in percent.
  final double loadDeltaPct;
  final int setsDelta;

  /// Display-only guidance such as "5 reps @ RPE 8".
  final String? repsHint;
  final String reason;

  /// Optional pain-aware replacement exercise name.
  final String? substituteWith;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'exerciseId': exerciseId,
    'exercise': exercise,
    'loadDeltaPct': loadDeltaPct,
    'setsDelta': setsDelta,
    'repsHint': repsHint,
    'reason': reason,
    'substituteWith': substituteWith,
  };

  Adjustment copyWith({
    String? exercise,
    double? loadDeltaPct,
    int? setsDelta,
    String? repsHint,
    String? reason,
    String? substituteWith,
    bool clearSubstitute = false,
  }) {
    return Adjustment(
      exerciseId: exerciseId,
      exercise: exercise ?? this.exercise,
      loadDeltaPct: loadDeltaPct ?? this.loadDeltaPct,
      setsDelta: setsDelta ?? this.setsDelta,
      repsHint: repsHint ?? this.repsHint,
      reason: reason ?? this.reason,
      substituteWith: clearSubstitute
          ? null
          : (substituteWith ?? this.substituteWith),
    );
  }

  @override
  String toString() =>
      'Adjustment($exercise, ${loadDeltaPct.toStringAsFixed(1)}%, '
      '${setsDelta >= 0 ? '+' : ''}$setsDelta sets)';
}

/// The coach's session recommendation, from rules or from the LLM.
class CoachPlan {
  const CoachPlan({
    required this.source,
    required this.summary,
    required this.readinessExplanation,
    required this.rpeCap,
    required this.deload,
    required this.adjustments,
    required this.tips,
    required this.flags,
    required this.disclaimer,
  });

  factory CoachPlan.fromJson(Map<String, dynamic> json) {
    return CoachPlan._decode(json, requireSource: true);
  }

  /// Decodes raw model output that does not carry a `source` field yet.
  factory CoachPlan.fromModelJson(Map<String, dynamic> json) {
    return CoachPlan._decode(json, requireSource: false);
  }

  factory CoachPlan._decode(
    Map<String, dynamic> json, {
    required bool requireSource,
  }) {
    return CoachPlan(
      source: requireSource
          ? CoachSource.fromWire(json.requireString('source'))
          : CoachSource.llm,
      summary: json.requireString('summary'),
      readinessExplanation: json.requireString('readinessExplanation'),
      rpeCap: json.requireDouble('rpeCap'),
      deload: json.optBool('deload') ?? false,
      adjustments: json
          .optMapList('adjustments')
          .map(Adjustment.fromJson)
          .toList(growable: false),
      tips: json
          .optMapList('tips')
          .map(CoachTip.fromJson)
          .toList(growable: false),
      flags: json.optStringList('flags'),
      disclaimer: json.optString('disclaimer') ?? '',
    );
  }

  final CoachSource source;
  final String summary;
  final String readinessExplanation;

  /// Session-wide RPE ceiling.
  final double rpeCap;
  final bool deload;
  final List<Adjustment> adjustments;
  final List<CoachTip> tips;
  final List<String> flags;
  final String disclaimer;

  bool get isAi => source == CoachSource.llm;
  bool get isFallback => source == CoachSource.rulesFallback;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source.wire,
    'summary': summary,
    'readinessExplanation': readinessExplanation,
    'rpeCap': rpeCap,
    'deload': deload,
    'adjustments': adjustments
        .map((adjustment) => adjustment.toJson())
        .toList(growable: false),
    'tips': tips.map((tip) => tip.toJson()).toList(growable: false),
    'flags': flags,
    'disclaimer': disclaimer,
  };

  CoachPlan copyWith({
    CoachSource? source,
    String? summary,
    String? readinessExplanation,
    double? rpeCap,
    bool? deload,
    List<Adjustment>? adjustments,
    List<CoachTip>? tips,
    List<String>? flags,
    String? disclaimer,
  }) {
    return CoachPlan(
      source: source ?? this.source,
      summary: summary ?? this.summary,
      readinessExplanation: readinessExplanation ?? this.readinessExplanation,
      rpeCap: rpeCap ?? this.rpeCap,
      deload: deload ?? this.deload,
      adjustments: adjustments ?? this.adjustments,
      tips: tips ?? this.tips,
      flags: flags ?? this.flags,
      disclaimer: disclaimer ?? this.disclaimer,
    );
  }
}
