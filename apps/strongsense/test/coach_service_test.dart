import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/data/remote/coach_api_client.dart';
import 'package:strongsense/data/services/coach_service.dart';
import 'package:strongsense_core/strongsense_core.dart';

class _FakeCoachClient extends CoachApiClient {
  _FakeCoachClient({this.response, this.error}) : super(baseUrl: 'http://fake');

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

  test('falls back to rules when the server fails', () async {
    final client = _FakeCoachClient(
      error: const CoachApiException(
        code: 'llm_unavailable',
        message: 'No provider',
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

    expect(result.aiUsed, isFalse);
    expect(result.aiError, 'No provider');
    expect(result.plan.source, CoachSource.rules);
  });
}
