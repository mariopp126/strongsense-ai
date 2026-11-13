/// Estimated one-rep max calculations.
abstract final class E1rm {
  /// Epley's formula loses accuracy far above this rep count, so charts cap it.
  static const int maxReliableReps = 12;

  /// Epley: `load * (1 + reps / 30)`.
  ///
  /// Returns `0` when [loadKg] or [reps] is not positive.
  static double epley(double loadKg, int reps) {
    if (loadKg <= 0 || reps <= 0) {
      return 0;
    }
    final effectiveReps = reps > maxReliableReps ? maxReliableReps : reps;
    return loadKg * (1 + effectiveReps / 30);
  }

  /// Estimates the load needed for [reps] at [e1rmKg] (inverse Epley).
  static double loadForReps(double e1rmKg, int reps) {
    if (e1rmKg <= 0 || reps <= 0) {
      return 0;
    }
    return e1rmKg / (1 + reps / 30);
  }
}
