import '../models/enums.dart';
import '../models/session.dart';

/// Classifies how hard the previous session felt for the main lifts.
abstract final class SessionClassifier {
  static const double easyRpeThreshold = 7.5;
  static const double normalRpeThreshold = 8.5;

  /// [mainExerciseIds] restricts the analysis to the competition lifts; when
  /// empty every completed set is considered.
  static SessionClassification classify({
    required Session session,
    Set<String> mainExerciseIds = const <String>{},
  }) {
    final logs = session.setLogs
        .where((set) => set.completed && !set.skipped)
        .toList(growable: false);
    if (logs.isEmpty) {
      return SessionClassification.none;
    }

    final relevant = mainExerciseIds.isEmpty
        ? logs
        : logs
              .where((set) => mainExerciseIds.contains(set.exerciseId))
              .toList(growable: false);
    if (relevant.isEmpty) {
      return SessionClassification.none;
    }

    final missed = relevant.where((set) => set.isMissed).length;
    final rpes = relevant
        .where((set) => set.rpe != null)
        .map((set) => set.rpe!)
        .toList(growable: false);

    if (rpes.isEmpty) {
      return missed == 0
          ? SessionClassification.normal
          : SessionClassification.hard;
    }

    final average = rpes.fold<double>(0, (sum, rpe) => sum + rpe) / rpes.length;

    if (missed == 0 && average <= easyRpeThreshold) {
      return SessionClassification.easy;
    }
    if (missed == 0 && average <= normalRpeThreshold) {
      return SessionClassification.normal;
    }
    return SessionClassification.hard;
  }
}
