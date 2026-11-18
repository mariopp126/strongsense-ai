import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/features/program/set_target_draft.dart';
import 'package:strongsense_core/strongsense_core.dart';

void main() {
  group('SetTargetDraft.fromTarget', () {
    test('round-trips the seeded deadlift back-off sets', () {
      const targets = <SetTarget>[
        SetTarget(reps: 5, loadKg: 80),
        SetTarget(reps: 5, loadKg: 70),
        SetTarget(reps: 5, loadKg: 70),
      ];

      final restored = targets
          .map(
            (target) => SetTargetDraft.fromTarget(target, Unit.kg).toTarget(),
          )
          .toList();

      expect(restored, hasLength(3));
      expect(restored[0].loadKg, 80);
      expect(restored[1].loadKg, 70);
      expect(restored[2].loadKg, 70);
      expect(restored.every((target) => target.reps == 5), isTrue);
    });

    test('round-trips a rep range', () {
      const target = SetTarget(reps: 15, repsMax: 20);

      final draft = SetTargetDraft.fromTarget(target, Unit.kg);
      expect(draft.reps, '15');
      expect(draft.repsMax, '20');

      final restored = draft.toTarget();
      expect(restored.reps, 15);
      expect(restored.repsMax, 20);
      expect(restored.loadKg, isNull);
      expect(restored.rpeCap, isNull);
    });

    test('blank optional fields map to null', () {
      final draft = SetTargetDraft(
        unit: Unit.kg,
        reps: '10',
        repsMax: '',
        load: '',
        rpe: '',
      );

      final target = draft.toTarget();
      expect(target.reps, 10);
      expect(target.repsMax, isNull);
      expect(target.loadKg, isNull);
      expect(target.rpeCap, isNull);
    });

    test('converts loads from pounds back to kilograms', () {
      final draft = SetTargetDraft(unit: Unit.lb, reps: '5', load: '165');

      expect(draft.toTarget().loadKg, closeTo(74.84, 0.01));
      expect(SetTargetDraft.fromTarget(draft.toTarget(), Unit.lb).load, '165');
    });

    test('accepts comma as decimal separator', () {
      final draft = SetTargetDraft(unit: Unit.kg, reps: '5', rpe: '8,5');

      expect(draft.toTarget().rpeCap, 8.5);
    });
  });

  group('SetTargetDraft.validate', () {
    test('requires reps', () {
      final draft = SetTargetDraft(unit: Unit.kg);

      expect(draft.validate(), containsPair('reps', 'required'));
    });

    test('rejects reps outside 1-100', () {
      expect(
        SetTargetDraft(unit: Unit.kg, reps: '0').validate(),
        containsPair('reps', 'range'),
      );
      expect(
        SetTargetDraft(unit: Unit.kg, reps: '101').validate(),
        containsPair('reps', 'range'),
      );
    });

    test('requires max reps to be at least reps', () {
      final draft = SetTargetDraft(unit: Unit.kg, reps: '10', repsMax: '8');

      expect(draft.validate(), containsPair('repsMax', 'repsMax'));
    });

    test('rejects loads outside 0-1000 kg', () {
      expect(
        SetTargetDraft(unit: Unit.kg, reps: '5', load: '-1').validate(),
        containsPair('load', 'loadRange'),
      );
      expect(
        SetTargetDraft(unit: Unit.kg, reps: '5', load: '1001').validate(),
        containsPair('load', 'loadRange'),
      );
    });

    test('rejects RPE outside 1-10', () {
      expect(
        SetTargetDraft(unit: Unit.kg, reps: '5', rpe: '11').validate(),
        containsPair('rpe', 'rpeRange'),
      );
    });

    test('toTarget throws for invalid drafts', () {
      final draft = SetTargetDraft(unit: Unit.kg, reps: 'nope');

      expect(draft.toTarget, throwsArgumentError);
      expect(draft.isValid, isFalse);
    });
  });
}
