import '../models/enums.dart';
import '../models/program.dart';

/// The default 3-day powerbuilding program from the original design reference:
/// squat, bench press and deadlift plus supporting accessories.
abstract final class ProgramSeed {
  static TrainingProgram powerbuilding() => TrainingProgram(
    id: 'program-powerbuilding-3day',
    name: 'Powerbuilding 3-Day',
    isDefault: true,
    days: <ProgramDay>[
      ProgramDay(
        id: 'day-1',
        title: 'Squat & Lower Body',
        focus: 'lower',
        exercises: <ProgramExercise>[
          _exercise('ex-squat', 'Squat', ExerciseRole.main, _sets4(5, 75)),
          _exercise(
            'ex-pause-squat',
            'Pause Squats',
            ExerciseRole.variation,
            _sets3(3, 60),
          ),
          _exercise(
            'ex-leg-press',
            'Leg Press',
            ExerciseRole.accessory,
            _sets3(12),
          ),
          _exercise(
            'ex-leg-extension',
            'Leg Extensions',
            ExerciseRole.accessory,
            _sets3(15),
          ),
          _exercise(
            'ex-calf-raise',
            'Calf Raises',
            ExerciseRole.accessory,
            _sets4Range(15, 20),
          ),
        ],
      ),
      ProgramDay(
        id: 'day-2',
        title: 'Bench & Upper Body',
        focus: 'upper',
        exercises: <ProgramExercise>[
          _exercise(
            'ex-bench',
            'Bench Press',
            ExerciseRole.main,
            _sets4(5, 75),
          ),
          _exercise(
            'ex-spoto',
            'Spoto Press',
            ExerciseRole.variation,
            _sets3(4, 65),
          ),
          _exercise(
            'ex-chest-supported-row',
            'Chest-Supported Rows',
            ExerciseRole.accessory,
            _sets3Range(10, 12),
          ),
          _exercise(
            'ex-lat-pulldown',
            'Lat Pulldowns',
            ExerciseRole.accessory,
            _sets3Range(10, 12),
          ),
          _exercise(
            'ex-triceps-pushdown',
            'Triceps Rope Pushdowns',
            ExerciseRole.accessory,
            _sets3Range(12, 15),
          ),
          _exercise(
            'ex-db-curl',
            'Dumbbell Bicep Curls',
            ExerciseRole.accessory,
            _sets3Range(12, 15),
          ),
        ],
      ),
      ProgramDay(
        id: 'day-3',
        title: 'Deadlift & Shoulders',
        focus: 'full',
        exercises: <ProgramExercise>[
          _exercise(
            'ex-deadlift',
            'Conventional Deadlift',
            ExerciseRole.main,
            const <SetTarget>[
              SetTarget(reps: 5, loadKg: 80),
              SetTarget(reps: 5, loadKg: 70),
              SetTarget(reps: 5, loadKg: 70),
            ],
          ),
          _exercise(
            'ex-goblet-squat',
            'Goblet Squats',
            ExerciseRole.accessory,
            _sets3(10),
          ),
          _exercise(
            'ex-hamstring-curl',
            'Hamstring Curls',
            ExerciseRole.accessory,
            _sets3(12),
          ),
          _exercise(
            'ex-db-shoulder-press',
            'Seated DB Shoulder Press',
            ExerciseRole.accessory,
            _sets3Range(10, 12),
          ),
          _exercise(
            'ex-cable-lateral-raise',
            'Cable Lateral Raises',
            ExerciseRole.accessory,
            _sets3(15),
          ),
        ],
      ),
    ],
  );

  static ProgramExercise _exercise(
    String id,
    String name,
    ExerciseRole role,
    List<SetTarget> targets,
  ) => ProgramExercise(id: id, name: name, role: role, setTargets: targets);

  static List<SetTarget> _sets4(int reps, double loadKg) =>
      List<SetTarget>.generate(
        4,
        (_) => SetTarget(reps: reps, loadKg: loadKg),
        growable: false,
      );

  static List<SetTarget> _sets3(int reps, [double? loadKg]) =>
      List<SetTarget>.generate(
        3,
        (_) => SetTarget(reps: reps, loadKg: loadKg),
        growable: false,
      );

  static List<SetTarget> _sets4Range(int reps, int repsMax) =>
      List<SetTarget>.generate(
        4,
        (_) => SetTarget(reps: reps, repsMax: repsMax),
        growable: false,
      );

  static List<SetTarget> _sets3Range(int reps, int repsMax) =>
      List<SetTarget>.generate(
        3,
        (_) => SetTarget(reps: reps, repsMax: repsMax),
        growable: false,
      );
}
