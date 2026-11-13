import '../models/check_in.dart';
import '../models/enums.dart';
import '../models/readiness.dart';

/// Deterministic readiness score and band.
///
/// Weights (sum to 1.0): sleep 0.30, energy 0.25, stress 0.20, soreness 0.15,
/// motivation 0.10. Stress and soreness are inverted so "1" is always good.
abstract final class ReadinessEngine {
  static const double sleepWeight = 0.30;
  static const double energyWeight = 0.25;
  static const double stressWeight = 0.20;
  static const double sorenessWeight = 0.15;
  static const double motivationWeight = 0.10;

  static const int greenThreshold = 80;
  static const int amberThreshold = 60;
  static const int orangeThreshold = 40;

  static const int severePainThreshold = 7;
  static const int moderatePainThreshold = 4;
  static const int severePainCap = 34;
  static const int moderatePainCap = 59;

  static ReadinessReport compute(CheckIn checkIn) {
    checkIn.validate();

    final sleep = _normalize(checkIn.sleepQuality);
    final energy = _normalize(checkIn.energy);
    final motivation = _normalize(checkIn.motivation);
    final stress = _normalize(checkIn.stress);
    final soreness = _normalize(checkIn.soreness);

    var score =
        100 *
        (sleepWeight * sleep +
            energyWeight * energy +
            stressWeight * (1 - stress) +
            sorenessWeight * (1 - soreness) +
            motivationWeight * motivation);

    final hours = checkIn.sleepHours;
    if (hours != null) {
      if (hours < 6) {
        score -= 5;
      } else if (hours >= 8) {
        score += 2;
      }
    }

    var rounded = score.clamp(0, 100).round();
    final caps = <String>[];

    if (checkIn.painSeverity >= severePainThreshold) {
      if (rounded > severePainCap) {
        rounded = severePainCap;
        caps.add('Severe pain caps readiness at $severePainCap');
      }
    } else if (checkIn.painSeverity >= moderatePainThreshold) {
      if (rounded > moderatePainCap) {
        rounded = moderatePainCap;
        caps.add('Pain caps readiness at $moderatePainCap');
      }
    }

    final band = bandForScore(rounded);

    return ReadinessReport(
      score: rounded,
      band: band,
      advice: ReadinessReport.adviceForBand(band),
      components: <String, double>{
        'sleep': _percent(sleep),
        'energy': _percent(energy),
        'stress': _percent(1 - stress),
        'soreness': _percent(1 - soreness),
        'motivation': _percent(motivation),
      },
      appliedCaps: caps,
    );
  }

  static ReadinessBand bandForScore(int score) {
    if (score >= greenThreshold) {
      return ReadinessBand.green;
    }
    if (score >= amberThreshold) {
      return ReadinessBand.amber;
    }
    if (score >= orangeThreshold) {
      return ReadinessBand.orange;
    }
    return ReadinessBand.red;
  }

  /// Maps a 1..5 answer to 0..1.
  static double _normalize(int answer) => (answer - 1) / 4;

  static double _percent(double value) =>
      (value * 100).clamp(0, 100).roundToDouble();
}
