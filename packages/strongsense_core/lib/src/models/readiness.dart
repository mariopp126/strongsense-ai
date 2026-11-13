import '../json/json_utils.dart';
import 'enums.dart';

/// Result of the readiness engine for one check-in.
class ReadinessReport {
  const ReadinessReport({
    required this.score,
    required this.band,
    required this.advice,
    required this.components,
    this.appliedCaps = const <String>[],
  });

  /// Rehydrates the subset of the report that crosses the HTTP contract.
  factory ReadinessReport.fromJson(Map<String, dynamic> json) {
    final score = json.requireInt('score');
    final band = ReadinessBand.fromWire(json.requireString('band'));
    return ReadinessReport(
      score: score,
      band: band,
      advice: adviceForBand(band),
      components: json.requireDoubleMap('components'),
    );
  }

  final int score;
  final ReadinessBand band;
  final ReadinessAdvice advice;

  /// Per-component scores (0..100) used by the explainability UI.
  final Map<String, double> components;

  /// Human-readable reasons a cap was applied (for example "pain severity cap").
  final List<String> appliedCaps;

  static ReadinessAdvice adviceForBand(ReadinessBand band) {
    switch (band) {
      case ReadinessBand.green:
        return ReadinessAdvice.push;
      case ReadinessBand.amber:
        return ReadinessAdvice.maintain;
      case ReadinessBand.orange:
        return ReadinessAdvice.reduce;
      case ReadinessBand.red:
        return ReadinessAdvice.recover;
    }
  }

  bool get isGreen => band == ReadinessBand.green;
  bool get isRed => band == ReadinessBand.red;

  /// Contract shape — only the fields the server understands.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'score': score,
    'band': band.wire,
    'components': components,
  };

  ReadinessReport copyWith({
    int? score,
    ReadinessBand? band,
    ReadinessAdvice? advice,
    Map<String, double>? components,
    List<String>? appliedCaps,
  }) {
    return ReadinessReport(
      score: score ?? this.score,
      band: band ?? this.band,
      advice: advice ?? this.advice,
      components: components ?? this.components,
      appliedCaps: appliedCaps ?? this.appliedCaps,
    );
  }
}
