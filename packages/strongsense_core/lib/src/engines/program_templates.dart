import '../models/coach_context.dart';
import '../models/enums.dart';
import '../models/program.dart';
import '../models/program_template.dart';
import '../models/session.dart';
import 'training_math.dart';

/// One of the main lifts a template progresses.
class _Lift {
  const _Lift(this.id, this.name, this.defaultKg);

  final String id;
  final String name;
  final double defaultKg;
}

const Map<String, _Lift> _mainLifts = <String, _Lift>{
  'ex-squat': _Lift('ex-squat', 'Squat', 75),
  'ex-bench': _Lift('ex-bench', 'Bench Press', 75),
  'ex-deadlift': _Lift('ex-deadlift', 'Conventional Deadlift', 80),
  'ex-ohp': _Lift('ex-ohp', 'Overhead Press', 40),
};

/// A selectable program template.
class ProgramTemplateDefinition {
  const ProgramTemplateDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.dayCount,
    required this.mainLiftByDay,
    required this.build,
    required this.advance,
  });

  final String id;
  final String name;
  final String description;
  final int dayCount;

  /// The primary lift trained on each day id (used by progression).
  final Map<String, String> mainLiftByDay;
  final TrainingProgram Function(
    ProgramTemplateState state,
    Increments increments,
  )
  build;
  final ProgramTemplateState Function(
    ProgramTemplateState state,
    Session session,
    int completedSessions,
    Increments increments,
  )
  advance;

  /// Derive the initial training maxes from the current program's main lifts.
  ProgramTemplateState initialState(
    TrainingProgram current,
    Increments increments,
  ) {
    return ProgramTemplateState(
      templateId: id,
      week: 1,
      trainingMaxKg: _deriveTrainingMaxes(current, increments),
    );
  }
}

/// Registry of built-in templates.
abstract final class ProgramTemplates {
  static const String fiveThreeOneId = '5_3_1';
  static const String gzclpId = 'gzclp';
  static const String blockPeriodizationId = 'block_periodization';

  static final List<ProgramTemplateDefinition>
  all = <ProgramTemplateDefinition>[
    ProgramTemplateDefinition(
      id: fiveThreeOneId,
      name: '5/3/1',
      description:
          'Four-day strength template with weekly 5/3/1 waves and a deload.',
      dayCount: 4,
      mainLiftByDay: const <String, String>{
        '531-day-1': 'ex-squat',
        '531-day-2': 'ex-bench',
        '531-day-3': 'ex-deadlift',
        '531-day-4': 'ex-ohp',
      },
      build: _buildFiveThreeOne,
      advance: (state, session, completedSessions, increments) => _advanceCycle(
        state,
        session,
        completedSessions,
        increments,
        _mainLiftByDayFiveThreeOne,
      ),
    ),
    const ProgramTemplateDefinition(
      id: gzclpId,
      name: 'GZCLP',
      description:
          'Four-day linear progression with T1 5x3, T2 3x10 and T3 3x15.',
      dayCount: 4,
      mainLiftByDay: <String, String>{
        'gzclp-day-1': 'ex-squat',
        'gzclp-day-2': 'ex-bench',
        'gzclp-day-3': 'ex-deadlift',
        'gzclp-day-4': 'ex-ohp',
      },
      build: _buildGzclp,
      advance: _advanceGzclp,
    ),
    ProgramTemplateDefinition(
      id: blockPeriodizationId,
      name: 'Block Periodization',
      description: 'Four-day block with volume, intensity and deload weeks.',
      dayCount: 4,
      mainLiftByDay: const <String, String>{
        'block-day-1': 'ex-squat',
        'block-day-2': 'ex-bench',
        'block-day-3': 'ex-deadlift',
        'block-day-4': 'ex-ohp',
      },
      build: _buildBlock,
      advance: (state, session, completedSessions, increments) => _advanceCycle(
        state,
        session,
        completedSessions,
        increments,
        _mainLiftByDayBlock,
      ),
    ),
  ];

  static ProgramTemplateDefinition? byId(String id) {
    for (final template in all) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }
}

const Map<String, String> _mainLiftByDayFiveThreeOne = <String, String>{
  '531-day-1': 'ex-squat',
  '531-day-2': 'ex-bench',
  '531-day-3': 'ex-deadlift',
  '531-day-4': 'ex-ohp',
};

const Map<String, String> _mainLiftByDayBlock = <String, String>{
  'block-day-1': 'ex-squat',
  'block-day-2': 'ex-bench',
  'block-day-3': 'ex-deadlift',
  'block-day-4': 'ex-ohp',
};

Map<String, double> _deriveTrainingMaxes(
  TrainingProgram current,
  Increments increments,
) {
  final result = <String, double>{};
  for (final lift in _mainLifts.values) {
    double? top;
    for (final day in current.days) {
      final exercise = day.exerciseById(lift.id);
      if (exercise == null) {
        continue;
      }
      for (final target in exercise.setTargets) {
        final load = target.loadKg;
        if (load != null && (top == null || load > top)) {
          top = load;
        }
      }
    }
    final increment = increments.forExercise(lift.id, lift.name);
    result[lift.id] = TrainingMath.roundToIncrement(
      top ?? lift.defaultKg,
      increment,
    );
  }
  return result;
}

double _pct(
  double trainingMax,
  double pct,
  _Lift lift,
  Increments increments,
) => TrainingMath.roundToIncrement(
  trainingMax * pct / 100,
  increments.forExercise(lift.id, lift.name),
);

List<SetTarget> _sets(int count, int reps, double? load) =>
    List<SetTarget>.generate(
      count,
      (_) => SetTarget(reps: reps, loadKg: load),
      growable: false,
    );

ProgramExercise _main(String id, List<SetTarget> sets) {
  final lift = _mainLifts[id]!;
  return ProgramExercise(
    id: id,
    name: lift.name,
    role: ExerciseRole.main,
    setTargets: sets,
  );
}

ProgramExercise _accessory(String id, String name, List<SetTarget> sets) =>
    ProgramExercise(
      id: id,
      name: name,
      role: ExerciseRole.accessory,
      setTargets: sets,
    );

// ---------------------------------------------------------------------------
// 5/3/1
// ---------------------------------------------------------------------------

TrainingProgram _buildFiveThreeOne(
  ProgramTemplateState state,
  Increments increments,
) {
  final week = state.week.clamp(1, 4);
  final scheme = switch (week) {
    2 => const <({int reps, double pct})>[
      (reps: 3, pct: 70),
      (reps: 3, pct: 80),
      (reps: 3, pct: 90),
    ],
    3 => const <({int reps, double pct})>[
      (reps: 5, pct: 75),
      (reps: 3, pct: 85),
      (reps: 1, pct: 95),
    ],
    4 => const <({int reps, double pct})>[
      (reps: 5, pct: 40),
      (reps: 5, pct: 50),
      (reps: 5, pct: 60),
    ],
    _ => const <({int reps, double pct})>[
      (reps: 5, pct: 65),
      (reps: 5, pct: 75),
      (reps: 5, pct: 85),
    ],
  };

  List<SetTarget> mainSets(String id) {
    final lift = _mainLifts[id]!;
    final trainingMax = state.trainingMaxKg[id] ?? lift.defaultKg;
    return <SetTarget>[
      for (final set in scheme)
        SetTarget(
          reps: set.reps,
          loadKg: _pct(trainingMax, set.pct, lift, increments),
        ),
    ];
  }

  double accessoryLoad(String id, double pct) {
    final lift = _mainLifts[id]!;
    final trainingMax = state.trainingMaxKg[id] ?? lift.defaultKg;
    return _pct(trainingMax, pct, lift, increments);
  }

  return TrainingProgram(
    id: 'program-531',
    name: '5/3/1',
    template: state,
    days: <ProgramDay>[
      ProgramDay(
        id: '531-day-1',
        title: 'Squat 5/3/1',
        focus: 'lower',
        exercises: <ProgramExercise>[
          _main('ex-squat', mainSets('ex-squat')),
          _accessory(
            'ex-rdl',
            'Romanian Deadlift',
            _sets(3, 10, accessoryLoad('ex-squat', 50)),
          ),
          _accessory(
            'ex-leg-press',
            'Leg Press',
            _sets(3, 10, accessoryLoad('ex-squat', 50)),
          ),
          _accessory('ex-calf-raise', 'Calf Raises', _sets(4, 15, null)),
        ],
      ),
      ProgramDay(
        id: '531-day-2',
        title: 'Bench 5/3/1',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _main('ex-bench', mainSets('ex-bench')),
          _accessory(
            'ex-incline-db-press',
            'Incline DB Press',
            _sets(3, 10, accessoryLoad('ex-bench', 50)),
          ),
          _accessory(
            'ex-chest-supported-row',
            'Chest-Supported Rows',
            _sets(3, 10, null),
          ),
          _accessory(
            'ex-triceps-pushdown',
            'Triceps Rope Pushdowns',
            _sets(3, 12, null),
          ),
        ],
      ),
      ProgramDay(
        id: '531-day-3',
        title: 'Deadlift 5/3/1',
        focus: 'full',
        exercises: <ProgramExercise>[
          _main('ex-deadlift', mainSets('ex-deadlift')),
          _accessory(
            'ex-front-squat',
            'Front Squat',
            _sets(3, 8, accessoryLoad('ex-deadlift', 50)),
          ),
          _accessory(
            'ex-hamstring-curl',
            'Hamstring Curls',
            _sets(3, 12, null),
          ),
          _accessory('ex-ab-wheel', 'Ab Wheel', _sets(3, 10, null)),
        ],
      ),
      ProgramDay(
        id: '531-day-4',
        title: 'OHP 5/3/1',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _main('ex-ohp', mainSets('ex-ohp')),
          _accessory('ex-pull-up', 'Pull-Ups', _sets(3, 8, null)),
          _accessory(
            'ex-cable-lateral-raise',
            'Cable Lateral Raises',
            _sets(3, 15, null),
          ),
          _accessory('ex-db-curl', 'Dumbbell Bicep Curls', _sets(3, 12, null)),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// GZCLP
// ---------------------------------------------------------------------------

TrainingProgram _buildGzclp(ProgramTemplateState state, Increments increments) {
  List<SetTarget> t1(String id) {
    final lift = _mainLifts[id]!;
    final trainingMax = state.trainingMaxKg[id] ?? lift.defaultKg;
    return _sets(5, 3, _pct(trainingMax, 100, lift, increments));
  }

  List<SetTarget> t2(String id) {
    final lift = _mainLifts[id]!;
    final trainingMax = state.trainingMaxKg[id] ?? lift.defaultKg;
    return _sets(3, 10, _pct(trainingMax, 65, lift, increments));
  }

  List<SetTarget> t3(String id, {double pct = 50}) {
    final lift = _mainLifts[id]!;
    final trainingMax = state.trainingMaxKg[id] ?? lift.defaultKg;
    return _sets(3, 15, _pct(trainingMax, pct, lift, increments));
  }

  return TrainingProgram(
    id: 'program-gzclp',
    name: 'GZCLP',
    template: state,
    days: <ProgramDay>[
      ProgramDay(
        id: 'gzclp-day-1',
        title: 'Squat / Bench',
        focus: 'full',
        exercises: <ProgramExercise>[
          _main('ex-squat', t1('ex-squat')),
          _accessory('ex-bench', 'Bench Press (T2)', t2('ex-bench')),
          _accessory('ex-lat-pulldown', 'Lat Pulldowns (T3)', t3('ex-bench')),
          _accessory(
            'ex-row-t3',
            'Chest-Supported Rows (T3)',
            _sets(3, 15, null),
          ),
        ],
      ),
      ProgramDay(
        id: 'gzclp-day-2',
        title: 'Bench / Squat',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _main('ex-bench', t1('ex-bench')),
          _accessory('ex-squat', 'Squat (T2)', t2('ex-squat')),
          _accessory(
            'ex-chest-supported-row',
            'Chest-Supported Rows (T3)',
            _sets(3, 15, null),
          ),
          _accessory(
            'ex-triceps-pushdown',
            'Triceps Pushdowns (T3)',
            _sets(3, 15, null),
          ),
        ],
      ),
      ProgramDay(
        id: 'gzclp-day-3',
        title: 'Deadlift / OHP',
        focus: 'full',
        exercises: <ProgramExercise>[
          _main('ex-deadlift', t1('ex-deadlift')),
          _accessory('ex-ohp', 'Overhead Press (T2)', t2('ex-ohp')),
          _accessory('ex-db-curl', 'Dumbbell Curls (T3)', _sets(3, 15, null)),
          _accessory(
            'ex-hamstring-curl',
            'Hamstring Curls (T3)',
            _sets(3, 15, null),
          ),
        ],
      ),
      ProgramDay(
        id: 'gzclp-day-4',
        title: 'OHP / Deadlift',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _main('ex-ohp', t1('ex-ohp')),
          _accessory('ex-deadlift', 'Deadlift (T2)', t2('ex-deadlift')),
          _accessory(
            'ex-cable-lateral-raise',
            'Lateral Raises (T3)',
            _sets(3, 15, null),
          ),
          _accessory('ex-pull-up', 'Pull-Ups (T3)', _sets(3, 8, null)),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Block periodization
// ---------------------------------------------------------------------------

TrainingProgram _buildBlock(ProgramTemplateState state, Increments increments) {
  final week = state.week.clamp(1, 4);
  final scheme = switch (week) {
    3 => (count: 5, reps: 5, pct: 80.0),
    4 => (count: 3, reps: 5, pct: 60.0),
    _ => (count: 4, reps: 8, pct: 70.0),
  };

  List<SetTarget> mainSets(String id) {
    final lift = _mainLifts[id]!;
    final trainingMax = state.trainingMaxKg[id] ?? lift.defaultKg;
    final load = _pct(trainingMax, scheme.pct, lift, increments);
    return _sets(scheme.count, scheme.reps, load);
  }

  return TrainingProgram(
    id: 'program-block',
    name: 'Block Periodization',
    template: state,
    days: <ProgramDay>[
      ProgramDay(
        id: 'block-day-1',
        title: 'Squat Block',
        focus: 'lower',
        exercises: <ProgramExercise>[
          _main('ex-squat', mainSets('ex-squat')),
          _accessory('ex-rdl', 'Romanian Deadlift', _sets(3, 10, null)),
          _accessory('ex-leg-press', 'Leg Press', _sets(3, 12, null)),
          _accessory('ex-calf-raise', 'Calf Raises', _sets(4, 15, null)),
        ],
      ),
      ProgramDay(
        id: 'block-day-2',
        title: 'Bench Block',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _main('ex-bench', mainSets('ex-bench')),
          _accessory(
            'ex-incline-db-press',
            'Incline DB Press',
            _sets(3, 10, null),
          ),
          _accessory(
            'ex-chest-supported-row',
            'Chest-Supported Rows',
            _sets(3, 12, null),
          ),
          _accessory(
            'ex-triceps-pushdown',
            'Triceps Pushdowns',
            _sets(3, 12, null),
          ),
        ],
      ),
      ProgramDay(
        id: 'block-day-3',
        title: 'Deadlift Block',
        focus: 'full',
        exercises: <ProgramExercise>[
          _main('ex-deadlift', mainSets('ex-deadlift')),
          _accessory('ex-front-squat', 'Front Squat', _sets(3, 8, null)),
          _accessory(
            'ex-hamstring-curl',
            'Hamstring Curls',
            _sets(3, 12, null),
          ),
          _accessory('ex-ab-wheel', 'Ab Wheel', _sets(3, 10, null)),
        ],
      ),
      ProgramDay(
        id: 'block-day-4',
        title: 'OHP Block',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _main('ex-ohp', mainSets('ex-ohp')),
          _accessory('ex-pull-up', 'Pull-Ups', _sets(3, 8, null)),
          _accessory(
            'ex-cable-lateral-raise',
            'Lateral Raises',
            _sets(3, 15, null),
          ),
          _accessory('ex-db-curl', 'Dumbbell Curls', _sets(3, 12, null)),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Progression
// ---------------------------------------------------------------------------

ProgramTemplateState _advanceCycle(
  ProgramTemplateState state,
  Session session,
  int completedSessions,
  Increments increments,
  Map<String, String> mainLiftByDay,
) {
  const dayCount = 4;
  const cycleLength = dayCount * 4;
  final maxes = Map<String, double>.from(state.trainingMaxKg);
  var week = ((completedSessions ~/ dayCount) % 4) + 1;

  final completedInCycle = completedSessions % cycleLength;
  if (completedSessions > 0 && completedInCycle == 0) {
    final mainId = mainLiftByDay[session.dayId];
    if (_sessionSucceeded(session, mainId)) {
      for (final lift in _mainLifts.values) {
        final current = maxes[lift.id] ?? lift.defaultKg;
        final increment = increments.forExercise(lift.id, lift.name);
        maxes[lift.id] = TrainingMath.roundToIncrement(
          current + increment,
          increment,
        );
      }
    }
    week = 1;
  }

  return state.copyWith(week: week, trainingMaxKg: maxes);
}

ProgramTemplateState _advanceGzclp(
  ProgramTemplateState state,
  Session session,
  int completedSessions,
  Increments increments,
) {
  final maxes = Map<String, double>.from(state.trainingMaxKg);
  final mainId = const <String, String>{
    'gzclp-day-1': 'ex-squat',
    'gzclp-day-2': 'ex-bench',
    'gzclp-day-3': 'ex-deadlift',
    'gzclp-day-4': 'ex-ohp',
  }[session.dayId];
  final lift = mainId == null ? null : _mainLifts[mainId];
  if (mainId != null && lift != null && _sessionSucceeded(session, mainId)) {
    final increment = increments.forExercise(lift.id, lift.name);
    final current = maxes[lift.id] ?? lift.defaultKg;
    maxes[lift.id] = TrainingMath.roundToIncrement(
      current + increment,
      increment,
    );
  }
  return state.copyWith(week: 1, trainingMaxKg: maxes);
}

bool _sessionSucceeded(Session session, String? mainId) {
  if (mainId == null) {
    return false;
  }
  final logs = session.setLogs
      .where((log) => log.exerciseId == mainId && log.completed && !log.skipped)
      .toList(growable: false);
  if (logs.isEmpty || logs.any((log) => log.isMissed)) {
    return false;
  }
  final rpes = logs
      .where((log) => log.rpe != null)
      .map((log) => log.rpe!)
      .toList(growable: false);
  final average = rpes.isEmpty
      ? null
      : rpes.fold<double>(0, (sum, rpe) => sum + rpe) / rpes.length;
  return average == null || average <= 9.0;
}
