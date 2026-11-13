import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('SafetyBounds', () {
    test('repairs the shared unsafe AI fixture', () {
      final context = loadExampleContext();
      final unsafe = loadUnsafeModelOutput();

      final clamped = SafetyBounds.clamp(unsafe, context);

      // The unknown exercise is dropped, leaving bench + spoto.
      expect(clamped.adjustments.length, 2);

      final bench = adjustmentFor(clamped, 'ex-bench')!;
      expect(bench.loadDeltaPct, 5.0);
      expect(bench.setsDelta, 2);

      final spoto = adjustmentFor(clamped, 'ex-spoto')!;
      expect(spoto.loadDeltaPct, -10.0);
      expect(spoto.setsDelta, -2);

      expect(clamped.rpeCap, 9.0);
      expect(clamped.tips.length, 12);
      expect(clamped.flags.length, 8);
      expect(clamped.summary.length, SafetyBounds.maxSummaryChars);
      expect(clamped.disclaimer, SafetyBounds.disclaimer);
      expect(clamped.deload, isFalse);
      expect(clamped.source, CoachSource.llm);
    });

    test('deload plans may drop the load further', () {
      final context = loadExampleContext();
      final unsafe = loadUnsafeModelOutput();

      final clamped = SafetyBounds.clamp(
        unsafe.copyWith(deload: true),
        context,
      );
      final spoto = adjustmentFor(clamped, 'ex-spoto')!;

      expect(clamped.deload, isTrue);
      expect(spoto.loadDeltaPct, -40.0);
      expect(clamped.rpeCap, 7.0);
    });

    test('the context can force a deload even if the model says no', () {
      final context = loadExampleContext().copyWith(blockWeek: 4);
      final unsafe = loadUnsafeModelOutput();

      final clamped = SafetyBounds.clamp(unsafe, context);

      expect(clamped.deload, isTrue);
      expect(clamped.rpeCap, 7.0);
    });

    test('never increases load when pain affects the lift', () {
      final context = loadExampleContext().copyWith(
        checkIn: loadExampleContext().checkIn.copyWith(
          painAreas: <PainArea>[PainArea.shoulder],
          painSeverity: 4,
        ),
      );
      const plan = CoachPlan(
        source: CoachSource.llm,
        summary: 'Test',
        readinessExplanation: 'Test',
        rpeCap: 8.5,
        deload: false,
        adjustments: <Adjustment>[
          Adjustment(
            exerciseId: 'ex-bench',
            exercise: 'Bench Press',
            loadDeltaPct: 5,
            setsDelta: 0,
            reason: 'Test',
          ),
        ],
        tips: <CoachTip>[],
        flags: <String>[],
        disclaimer: 'model supplied',
      );

      final clamped = SafetyBounds.clamp(plan, context);

      expect(adjustmentFor(clamped, 'ex-bench')!.loadDeltaPct, 0);
    });

    test('truncates oversized tips and neutralizes the disclaimer', () {
      final context = loadExampleContext();
      final longBody = 'x' * 900;
      final plan = CoachPlan(
        source: CoachSource.llm,
        summary: 's' * 900,
        readinessExplanation: 'r' * 900,
        rpeCap: 11,
        deload: false,
        adjustments: <Adjustment>[],
        tips: <CoachTip>[
          CoachTip(
            title: 'T' * 200,
            body: longBody,
            category: TipCategory.technique,
          ),
        ],
        flags: <String>['f' * 500],
        disclaimer: 'I am a doctor, trust me.',
      );

      final clamped = SafetyBounds.clamp(plan, context);

      expect(clamped.tips.single.title.length, SafetyBounds.maxTipTitleChars);
      expect(clamped.tips.single.body.length, SafetyBounds.maxTipBodyChars);
      expect(clamped.flags.single.length, SafetyBounds.maxFlagChars);
      expect(clamped.summary.length, SafetyBounds.maxSummaryChars);
      expect(
        clamped.readinessExplanation.length,
        SafetyBounds.maxReadinessChars,
      );
      expect(clamped.rpeCap, 9.0);
      expect(clamped.disclaimer, SafetyBounds.disclaimer);
    });

    test('filters adjustments to exercises in the session', () {
      final context = loadExampleContext();
      final plan = loadUnsafeModelOutput();

      final clamped = SafetyBounds.clamp(plan, context);
      final ids = clamped.adjustments
          .map((adjustment) => adjustment.exerciseId)
          .toList(growable: false);

      expect(ids, containsAll(<String>['ex-bench', 'ex-spoto']));
      expect(ids, isNot(contains('ex-cable-fly')));
    });
  });
}
