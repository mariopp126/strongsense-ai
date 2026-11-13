import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('ReadinessEngine', () {
    test('a perfect check-in scores 100 and is green', () {
      final report = ReadinessEngine.compute(checkInAllFives());

      expect(report.score, 100);
      expect(report.band, ReadinessBand.green);
      expect(report.advice, ReadinessAdvice.push);
      expect(report.components['sleep'], 100);
      expect(report.components['stress'], 100);
    });

    test('the worst check-in scores 0 and is red', () {
      final report = ReadinessEngine.compute(checkInRed());

      expect(report.score, 0);
      expect(report.band, ReadinessBand.red);
      expect(report.advice, ReadinessAdvice.recover);
    });

    test('uses the documented weighted formula', () {
      final report = ReadinessEngine.compute(checkInAmber());

      // 0.30*75 + 0.25*50 + 0.20*75 + 0.15*75 + 0.10*75 = 68.75 -> 69
      expect(report.score, 69);
      expect(report.band, ReadinessBand.amber);
      expect(report.components['sleep'], 75);
      expect(report.components['energy'], 50);
      expect(report.components['stress'], 75);
      expect(report.components['soreness'], 75);
      expect(report.components['motivation'], 75);
    });

    test('short sleep subtracts five points', () {
      const checkIn = CheckIn(
        sleepQuality: 5,
        sleepHours: 5,
        energy: 5,
        motivation: 5,
        soreness: 1,
        stress: 1,
        painSeverity: 0,
        timeAvailableMin: 60,
      );

      expect(ReadinessEngine.compute(checkIn).score, 95);
    });

    test('long sleep adds two points but never exceeds 100', () {
      const checkIn = CheckIn(
        sleepQuality: 5,
        sleepHours: 8.5,
        energy: 5,
        motivation: 5,
        soreness: 1,
        stress: 1,
        painSeverity: 0,
        timeAvailableMin: 60,
      );

      expect(ReadinessEngine.compute(checkIn).score, 100);
    });

    test('moderate pain caps readiness at 59', () {
      final report = ReadinessEngine.compute(
        checkInAllFives(painSeverity: 4, painAreas: <PainArea>[PainArea.knee]),
      );

      expect(report.score, 59);
      expect(report.band, ReadinessBand.orange);
      expect(report.appliedCaps, isNotEmpty);
    });

    test('severe pain caps readiness at 34', () {
      final report = ReadinessEngine.compute(
        checkInAllFives(
          painSeverity: 7,
          painAreas: <PainArea>[PainArea.lowerBack],
        ),
      );

      expect(report.score, 34);
      expect(report.band, ReadinessBand.red);
      expect(report.appliedCaps, isNotEmpty);
    });

    test('band boundaries match the contract', () {
      expect(ReadinessEngine.bandForScore(100), ReadinessBand.green);
      expect(ReadinessEngine.bandForScore(80), ReadinessBand.green);
      expect(ReadinessEngine.bandForScore(79), ReadinessBand.amber);
      expect(ReadinessEngine.bandForScore(60), ReadinessBand.amber);
      expect(ReadinessEngine.bandForScore(59), ReadinessBand.orange);
      expect(ReadinessEngine.bandForScore(40), ReadinessBand.orange);
      expect(ReadinessEngine.bandForScore(39), ReadinessBand.red);
      expect(ReadinessEngine.bandForScore(0), ReadinessBand.red);
    });

    test('rejects out-of-range answers', () {
      expect(
        () => ReadinessEngine.compute(
          const CheckIn(
            sleepQuality: 0,
            energy: 3,
            motivation: 3,
            soreness: 3,
            stress: 3,
            painSeverity: 0,
            timeAvailableMin: 60,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
