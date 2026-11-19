import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:strongsense/data/remote/coach_api_client.dart';
import 'package:strongsense/data/services/coach_service.dart';
import 'package:strongsense_core/strongsense_core.dart';

class _FakeCoachClient extends CoachApiClient {
  _FakeCoachClient({
    this.response,
    this.error,
  }) // ignore: unused_element_parameter
  : super(baseUrl: 'http://fake');

  final CoachResponse? response;
  final Object? error;
  int calls = 0;

  @override
  Future<CoachResponse> requestPlan(CoachRequest request) async {
    calls += 1;
    if (error != null) {
      throw error!;
    }
    return response!;
  }

  @override
  Future<CoachHealth> health() async => const CoachHealth(
    status: 'ok',
    version: '0.1.0',
    contractVersion: 1,
    llmConfigured: true,
  );
}

CoachContext _context() {
  final day = ProgramSeed.powerbuilding().dayById('day-2')!;
  const checkIn = CheckIn(
    sleepQuality: 4,
    sleepHours: 7.5,
    energy: 3,
    motivation: 4,
    soreness: 2,
    stress: 2,
    painSeverity: 0,
    timeAvailableMin: 60,
  );
  return CoachContext(
    date: DateTime(2026, 11, 14),
    blockWeek: 1,
    programDay: day,
    checkIn: checkIn,
    readiness: ReadinessEngine.compute(checkIn),
    settings: const TrainingSettings(),
  );
}

CoachPlan _unsafeAiPlan() => const CoachPlan(
  source: CoachSource.llm,
  summary: 'Unsafe AI plan',
  readinessExplanation: 'Explanation',
  rpeCap: 11,
  deload: false,
  adjustments: <Adjustment>[
    Adjustment(
      exerciseId: 'ex-bench',
      exercise: 'Bench Press',
      loadDeltaPct: 25,
      setsDelta: 6,
      reason: 'Too much',
    ),
  ],
  tips: <CoachTip>[],
  flags: <String>[],
  disclaimer: 'model supplied',
);

void main() {
  test('uses the offline rules plan when coaching is disabled', () async {
    final client = _FakeCoachClient(response: null);
    final service = CoachService(
      settings: const AppSettings(coachEnabled: false),
      client: client,
    );

    final result = await service.generate(_context());

    expect(client.calls, 0);
    expect(result.aiUsed, isFalse);
    expect(result.plan.source, CoachSource.rules);
    expect(result.plan.disclaimer, SafetyBounds.disclaimer);
  });

  test('clamps an unsafe AI plan before returning it', () async {
    final client = _FakeCoachClient(
      response: CoachResponse(
        source: CoachSource.llm,
        plan: _unsafeAiPlan(),
        meta: const CoachMeta(model: 'fake-model'),
      ),
    );
    final service = CoachService(
      settings: const AppSettings(
        coachEnabled: true,
        coachBaseUrl: 'http://fake',
      ),
      client: client,
    );

    final result = await service.generate(_context());
    final adjustment = result.plan.adjustments.single;

    expect(client.calls, 1);
    expect(result.aiUsed, isTrue);
    expect(result.plan.source, CoachSource.llm);
    expect(adjustment.loadDeltaPct, 5);
    expect(adjustment.setsDelta, 2);
    expect(result.plan.rpeCap, 9);
    expect(result.plan.disclaimer, SafetyBounds.disclaimer);
  });

  test('sends the bearer token when one is configured', () async {
    final client = CoachApiClient(
      baseUrl: 'http://fake',
      coachToken: 'secret-token',
      client: _RecordingClient(),
    );
    // Access private headers via reflection-free behavior: construct request
    // headers through a tiny probe by checking the client would include auth.
    final headers = client.baseHeaders();
    expect(headers['Authorization'], 'Bearer secret-token');
    expect(headers['accept'], 'application/json');
  });

  test('omits the bearer token when none is configured', () {
    final client = CoachApiClient(
      baseUrl: 'http://fake',
      coachToken: '',
      client: _RecordingClient(),
    );
    expect(client.baseHeaders().containsKey('Authorization'), isFalse);
  });
}

class _RecordingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
      request: request,
    );
  }
}
