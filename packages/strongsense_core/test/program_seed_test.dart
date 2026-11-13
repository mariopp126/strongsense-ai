import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProgramSeed', () {
    final program = ProgramSeed.powerbuilding();

    test('contains the three powerlifting days', () {
      expect(program.days.length, 3);
      expect(program.days.map((day) => day.title).toList(), <String>[
        'Squat & Lower Body',
        'Bench & Upper Body',
        'Deadlift & Shoulders',
      ]);
      expect(program.isDefault, isTrue);
    });

    test('prescribes the reference loads', () {
      final squat = program.dayById('day-1')!.exerciseById('ex-squat')!;
      expect(squat.role, ExerciseRole.main);
      expect(squat.setTargets.length, 4);
      expect(squat.setTargets.every((target) => target.reps == 5), isTrue);
      expect(squat.setTargets.every((target) => target.loadKg == 75), isTrue);

      final bench = program.dayById('day-2')!.exerciseById('ex-bench')!;
      expect(bench.setTargets.length, 4);
      expect(bench.setTargets.first.loadKg, 75);

      final deadlift = program.dayById('day-3')!.exerciseById('ex-deadlift')!;
      expect(
        deadlift.setTargets.map((target) => target.loadKg).toList(),
        <double>[80, 70, 70],
      );
    });

    test('keeps rep ranges for accessories', () {
      final calf = program.dayById('day-1')!.exerciseById('ex-calf-raise')!;
      expect(calf.setTargets.length, 4);
      expect(calf.setTargets.first.reps, 15);
      expect(calf.setTargets.first.repsMax, 20);
    });

    test('has one main lift per day', () {
      for (final day in program.days) {
        expect(day.mainExercises.length, 1, reason: day.id);
      }
    });

    test('round-trips through JSON', () {
      final decoded = TrainingProgram.fromJson(program.toJson());

      expect(decoded.days.length, 3);
      expect(decoded.dayById('day-2')!.exerciseById('ex-bench'), isNotNull);
    });
  });
}
