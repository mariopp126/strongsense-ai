/// Small numeric helpers shared by the engines.
abstract final class TrainingMath {
  /// Rounds [value] to the nearest [increment] (for example 2.5 kg plates).
  static double roundToIncrement(double value, double increment) {
    if (increment <= 0) {
      return value;
    }
    final rounded = (value / increment).round() * increment;
    // Avoid floating point noise like 77.50000000000001.
    return double.parse(rounded.toStringAsFixed(2));
  }

  /// Applies a percentage delta to [base] and rounds to [increment].
  static double applyPercent(
    double base,
    double percent, {
    required double increment,
  }) {
    final raw = base * (1 + percent / 100);
    return roundToIncrement(raw < 0 ? 0 : raw, increment);
  }

  static double clamp(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  static int clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
