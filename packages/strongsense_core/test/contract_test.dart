import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('CoachContract v1', () {
    test('parses the example request and preserves the context', () {
      final request = loadExampleRequest();

      expect(request.locale, 'en');
      expect(request.context.programDay.id, 'day-2');
      expect(request.context.programDay.title, 'Bench & Upper Body');
      expect(request.context.programDay.exercises.length, 6);
      expect(request.context.checkIn.sleepQuality, 4);
      expect(request.context.readiness.band, ReadinessBand.amber);
      expect(request.baselinePlan, isNotNull);
      expect(request.baselinePlan!.source, CoachSource.rules);
    });

    test('context serialization matches the contract fixture exactly', () {
      final request = loadExampleRequest();
      final fixture = loadFixture('coach-request.example.json');
      final expectedContext = fixture['context'] as Map<String, dynamic>;

      expect(request.context.toJson(), equals(expectedContext));
    });

    test('request round-trips through JSON', () {
      final request = loadExampleRequest();
      final decoded = CoachRequest.fromJson(request.toJson());

      expect(decoded.locale, request.locale);
      expect(decoded.context.programDay.id, request.context.programDay.id);
      expect(decoded.baselinePlan!.source, CoachSource.rules);
      expect(decoded.toJson()['contractVersion'], CoachContract.version);
    });

    test('parses the example response', () {
      final response = CoachResponse.fromJson(
        loadFixture('coach-response.example.json'),
      );

      expect(response.source, CoachSource.llm);
      expect(response.plan.source, CoachSource.llm);
      expect(response.plan.deload, isFalse);
      expect(response.plan.adjustments.length, 3);
      expect(response.meta.model, 'gpt-4.1-mini');
      expect(response.meta.clamped, isFalse);
      expect(response.plan.disclaimer, isNotEmpty);
    });

    test('rejects an unsupported contract version', () {
      final json = loadFixture('coach-request.example.json');
      json['contractVersion'] = 2;

      expect(() => CoachRequest.fromJson(json), throwsFormatException);
    });

    test('rejects a response whose plan source disagrees', () {
      final json = loadFixture('coach-response.example.json');
      final plan = json['plan'] as Map<String, dynamic>;
      plan['source'] = 'rules';

      expect(() => CoachResponse.fromJson(json), throwsFormatException);
    });

    test('parses the health payload', () {
      final health = CoachHealth.fromJson(<String, dynamic>{
        'status': 'ok',
        'service': 'strongsense-coach-api',
        'version': '0.1.0',
        'contractVersion': 1,
        'llmConfigured': true,
        'providers': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'openai_compatible',
            'model': 'gpt-4.1-mini',
          },
        ],
      });

      expect(health.isOk, isTrue);
      expect(health.llmConfigured, isTrue);
      expect(health.primaryModel, 'gpt-4.1-mini');
    });
  });
}
