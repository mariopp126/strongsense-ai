import '../models/enums.dart';

/// Maps exercises to joints and suggests pain-aware substitutions.
///
/// The mapping is deliberately conservative: when a joint is flagged we keep
/// the pattern but lower the load and, when a known safe variation exists,
/// swap the exercise.
abstract final class PainGuidance {
  static const List<PainArea> _priority = <PainArea>[
    PainArea.lowerBack,
    PainArea.knee,
    PainArea.shoulder,
    PainArea.elbow,
    PainArea.wrist,
    PainArea.hip,
    PainArea.other,
  ];

  /// Joints loaded by an exercise, based on its id/name keywords.
  static Set<PainArea> jointsFor(String exerciseId, String name) {
    final haystack = '$exerciseId $name'.toLowerCase();
    final joints = <PainArea>{};

    if (_has(haystack, <String>[
      'bench',
      'spoto',
      'press',
      'pushdown',
      'pressdown',
      'lateral raise',
      'fly',
      'triceps',
    ])) {
      joints.addAll(<PainArea>{
        PainArea.shoulder,
        PainArea.elbow,
        PainArea.wrist,
      });
    }

    if (_has(haystack, <String>[
      'squat',
      'leg press',
      'leg extension',
      'lunge',
      'calf',
      'goblet',
    ])) {
      joints.addAll(<PainArea>{PainArea.knee, PainArea.hip});
    }

    if (_has(haystack, <String>[
      'deadlift',
      'rdl',
      'hamstring',
      'hip thrust',
      'good morning',
    ])) {
      joints.addAll(<PainArea>{
        PainArea.lowerBack,
        PainArea.hip,
        PainArea.knee,
      });
    }

    if (_has(haystack, <String>[
      'row',
      'pulldown',
      'pull-up',
      'chin',
      'curl',
    ])) {
      joints.addAll(<PainArea>{
        PainArea.elbow,
        PainArea.wrist,
        PainArea.shoulder,
      });
    }

    if (joints.isEmpty) {
      joints.add(PainArea.other);
    }
    return joints;
  }

  /// True when any flagged [painAreas] intersects the exercise's joints.
  static bool isAffected(
    String exerciseId,
    String name,
    Iterable<PainArea> painAreas,
  ) {
    if (painAreas.isEmpty) {
      return false;
    }
    final joints = jointsFor(exerciseId, name);
    return painAreas.any(joints.contains);
  }

  /// A replacement exercise name, or `null` when the lift should simply be
  /// loaded lighter or skipped.
  static String? substituteFor({
    required String exerciseId,
    required String name,
    required Iterable<PainArea> painAreas,
  }) {
    final haystack = '$exerciseId $name'.toLowerCase();
    final flagged = painAreas.toSet();

    for (final area in _priority) {
      if (!flagged.contains(area)) {
        continue;
      }
      switch (area) {
        case PainArea.lowerBack:
          if (_has(haystack, <String>['deadlift', 'rdl'])) {
            return 'Hip Hinge Drill (empty bar)';
          }
          if (_has(haystack, <String>['squat', 'lunge'])) {
            return 'Goblet Box Squat';
          }
          if (_has(haystack, <String>['row'])) {
            return 'Chest-Supported Row (neutral grip)';
          }
          if (_has(haystack, <String>['hamstring'])) {
            return 'Glute Bridge (light)';
          }
          return null;
        case PainArea.knee:
          if (_has(haystack, <String>[
            'squat',
            'leg press',
            'leg extension',
            'goblet',
            'lunge',
            'calf',
          ])) {
            return 'Box Squat (light)';
          }
          if (_has(haystack, <String>['deadlift', 'hamstring'])) {
            return 'Romanian Deadlift (light)';
          }
          return null;
        case PainArea.shoulder:
          if (_has(haystack, <String>['bench', 'spoto', 'fly'])) {
            return 'Close-Grip Bench Press';
          }
          if (_has(haystack, <String>['press'])) {
            return 'Landmine Press';
          }
          if (_has(haystack, <String>['lateral raise'])) {
            return 'Band External Rotation';
          }
          if (_has(haystack, <String>['row', 'pulldown'])) {
            return 'Chest-Supported Row (neutral grip)';
          }
          return null;
        case PainArea.elbow:
        case PainArea.wrist:
          if (_has(haystack, <String>[
            'bench',
            'spoto',
            'press',
            'pushdown',
            'pressdown',
            'curl',
            'row',
            'pulldown',
          ])) {
            return 'Neutral-Grip Dumbbell Variation';
          }
          return null;
        case PainArea.hip:
          if (_has(haystack, <String>['squat', 'deadlift', 'lunge'])) {
            return 'Hip Hinge Drill (empty bar)';
          }
          return null;
        case PainArea.other:
          return null;
      }
    }
    return null;
  }

  static bool _has(String haystack, List<String> needles) =>
      needles.any(haystack.contains);
}
