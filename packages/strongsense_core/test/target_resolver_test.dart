import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('TargetResolver', () {
    test('uses the program loads for a first session', () {
      final context = buildContext(checkIn: checkInAllFives());
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);
      final bench = plannedFor(sessionPlan, 'ex-bench')!;

      expect(bench.sets.length, 4);
      expect(bench.sets.first.loadKg, 75);
      expect(bench.sets.first.reps, 5);
      expect(bench.sets.first.rpeCap, 8.5);
    });

    test('applies a green/easy load increase', () {
      final context = buildContext(
        checkIn: checkInAllFives(),
        lastClassification: SessionClassification.easy,
        lastLifts: <LastLiftContext>[liftContext(exerciseId: 'ex-bench')],
      );
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);
      final bench = plannedFor(sessionPlan, 'ex-bench')!;

      // 75 * 1.025 = 76.875 -> 77.5 kg
      expect(bench.sets.first.loadKg, 77.5);
      expect(bench.sets.first.adjusted, isTrue);
    });

    test('carries the last performed loads and preserves back-offs', () {
      final context = buildContext(
        dayId: 'day-3',
        checkIn: checkInAllFives(),
        lastLifts: <LastLiftContext>[
          liftContext(
            exerciseId: 'ex-deadlift',
            topSetKg: 85,
            topSetReps: 5,
            topSetRpe: 8,
          ),
        ],
      );
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);
      final deadlift = plannedFor(sessionPlan, 'ex-deadlift')!;

      expect(deadlift.sets.length, 3);
      expect(deadlift.sets[0].loadKg, 85);
      expect(deadlift.sets[1].loadKg, 75);
      expect(deadlift.sets[2].loadKg, 75);
    });

    test('adds a working set when the plan asks for it', () {
      final context = buildContext(
        checkIn: checkInAllFives(),
        lastClassification: SessionClassification.normal,
        lastLifts: <LastLiftContext>[liftContext(exerciseId: 'ex-bench')],
      );
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);
      final bench = plannedFor(sessionPlan, 'ex-bench')!;

      expect(bench.sets.length, 5);
    });

    test('drops the last accessory when time is under 45 minutes', () {
      final context = buildContext(
        checkIn: checkInAllFives(timeAvailableMin: 40),
      );
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);

      expect(sessionPlan.exercises.length, 5);
      expect(plannedFor(sessionPlan, 'ex-db-curl'), isNull);
    });

    test('keeps only the main lifts when time is under 30 minutes', () {
      final context = buildContext(
        checkIn: checkInAllFives(timeAvailableMin: 25),
      );
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);

      expect(sessionPlan.exercises.length, 2);
      expect(
        sessionPlan.exercises.every(
          (exercise) => exercise.role != ExerciseRole.accessory,
        ),
        isTrue,
      );
    });

    test('renames the exercise when a substitution is active', () {
      final context = buildContext(
        checkIn: checkInAllFives(
          painSeverity: 4,
          painAreas: <PainArea>[PainArea.shoulder],
        ),
      );
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);
      final bench = plannedFor(sessionPlan, 'ex-bench')!;

      expect(bench.name, 'Close-Grip Bench Press');
      expect(bench.substitutedFor, 'Bench Press');
      expect(bench.isSubstituted, isTrue);
    });

    test('applies the plan RPE cap to every set', () {
      final context = buildContext(checkIn: checkInOrange());
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);

      for (final exercise in sessionPlan.exercises) {
        for (final set in exercise.sets) {
          expect(set.rpeCap, plan.rpeCap);
        }
      }
    });

    test('never produces fewer than one set per exercise', () {
      final context = buildContext(checkIn: checkInRed(), dayId: 'day-3');
      final plan = AutoregulationEngine.evaluate(context).plan;

      final sessionPlan = TargetResolver.resolve(context: context, plan: plan);

      expect(sessionPlan.exercises, isNotEmpty);
      for (final exercise in sessionPlan.exercises) {
        expect(exercise.sets.length, greaterThanOrEqualTo(1));
      }
    });
  });
}
