import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('AutoregulationEngine matrix', () {
    test('green + easy pushes the main lift', () {
      final context = buildContext(
        checkIn: checkInAllFives(),
        lastClassification: SessionClassification.easy,
        lastLifts: <LastLiftContext>[liftContext(exerciseId: 'ex-bench')],
      );

      final result = AutoregulationEngine.evaluate(context);
      final bench = adjustmentFor(result.plan, 'ex-bench');

      expect(result.isDeload, isFalse);
      expect(result.plan.rpeCap, 9.0);
      expect(bench, isNotNull);
      expect(bench!.loadDeltaPct, 2.5);
      expect(bench.setsDelta, 0);
      expect(result.plan.source, CoachSource.rules);
      expect(result.plan.disclaimer, SafetyBounds.disclaimer);
      expect(result.plan.tips, isNotEmpty);
    });

    test('green + normal adds one main set', () {
      final context = buildContext(
        checkIn: checkInAllFives(),
        lastClassification: SessionClassification.normal,
        lastLifts: <LastLiftContext>[liftContext(exerciseId: 'ex-bench')],
      );

      final result = AutoregulationEngine.evaluate(context);
      final bench = adjustmentFor(result.plan, 'ex-bench')!;

      expect(bench.loadDeltaPct, 1.5);
      expect(bench.setsDelta, 1);
    });

    test('green with no previous session holds the plan', () {
      final context = buildContext(checkIn: checkInAllFives());

      final result = AutoregulationEngine.evaluate(context);

      expect(result.plan.adjustments, isEmpty);
      expect(result.plan.rpeCap, 8.5);
    });

    test('amber + hard backs off load and volume', () {
      final context = buildContext(
        checkIn: checkInAmber(),
        lastClassification: SessionClassification.hard,
        lastLifts: <LastLiftContext>[
          liftContext(exerciseId: 'ex-bench', missedSets: 1),
        ],
      );

      final result = AutoregulationEngine.evaluate(context);
      final bench = adjustmentFor(result.plan, 'ex-bench')!;
      final row = adjustmentFor(result.plan, 'ex-chest-supported-row')!;

      expect(bench.loadDeltaPct, -5);
      expect(bench.setsDelta, -1);
      expect(row.loadDeltaPct, 0);
      expect(row.setsDelta, -1);
      expect(result.plan.rpeCap, 8.0);
    });

    test('orange readiness reduces the session', () {
      final context = buildContext(checkIn: checkInOrange());

      final result = AutoregulationEngine.evaluate(context);
      final bench = adjustmentFor(result.plan, 'ex-bench')!;

      expect(bench.loadDeltaPct, -5);
      expect(bench.setsDelta, -1);
      expect(result.plan.rpeCap, 8.0);
    });

    test('red readiness becomes a technique/deload day', () {
      final context = buildContext(checkIn: checkInRed());

      final result = AutoregulationEngine.evaluate(context);
      final bench = adjustmentFor(result.plan, 'ex-bench')!;

      expect(result.isDeload, isTrue);
      expect(result.plan.deload, isTrue);
      expect(bench.loadDeltaPct, -40);
      expect(bench.setsDelta, -2);
      expect(result.plan.rpeCap, 7.0);
    });

    test('the fourth week is a deload regardless of readiness', () {
      final context = buildContext(checkIn: checkInAllFives(), blockWeek: 4);

      final result = AutoregulationEngine.evaluate(context);

      expect(result.isDeload, isTrue);
      expect(result.plan.rpeCap, 7.0);
      expect(result.plan.flags.join(' '), contains('Deload'));
    });

    test('severe pain forces a deload', () {
      final context = buildContext(
        checkIn: checkInAllFives(
          painSeverity: 8,
          painAreas: <PainArea>[PainArea.lowerBack],
        ),
      );

      final result = AutoregulationEngine.evaluate(context);

      expect(result.isDeload, isTrue);
      expect(result.plan.flags.join(' '), contains('Severe pain'));
    });

    test('moderate pain holds the load and substitutes the lift', () {
      final context = buildContext(
        checkIn: checkInAllFives(
          painSeverity: 4,
          painAreas: <PainArea>[PainArea.shoulder],
        ),
      );

      final result = AutoregulationEngine.evaluate(context);
      final bench = adjustmentFor(result.plan, 'ex-bench');

      expect(result.isDeload, isFalse);
      expect(bench, isNotNull);
      expect(bench!.loadDeltaPct, lessThanOrEqualTo(0));
      expect(bench.substituteWith, 'Close-Grip Bench Press');
      expect(result.plan.flags.join(' '), contains('Pain reported'));
    });

    test('a short session is flagged', () {
      final context = buildContext(
        checkIn: checkInAllFives(timeAvailableMin: 25),
      );

      final result = AutoregulationEngine.evaluate(context);

      expect(result.plan.flags.join(' '), contains('Short session'));
    });
  });
}
