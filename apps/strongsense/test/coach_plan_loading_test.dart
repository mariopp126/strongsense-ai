import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:strongsense/core/theme/ss_theme.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/data/remote/coach_api_client.dart';
import 'package:strongsense/features/checkin/checkin_screen.dart';
import 'package:strongsense/l10n/app_localizations.dart';
import 'package:strongsense/state/providers.dart';
import 'package:strongsense_core/strongsense_core.dart';

class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream<List<int>>.empty(), 500);
}

class _FakeCoachApiClient extends CoachApiClient {
  _FakeCoachApiClient(this.response)
    : super(baseUrl: 'http://fake', client: _NoopHttpClient());

  final CoachResponse response;
  int calls = 0;

  @override
  Future<CoachResponse> requestPlan(CoachRequest request) async {
    calls += 1;
    return response;
  }
}

CoachPlan _aiPlan() => const CoachPlan(
  source: CoachSource.llm,
  summary: 'AI plan from the check-in',
  readinessExplanation: 'Built from the check-in data.',
  rpeCap: 8.5,
  deload: false,
  adjustments: <Adjustment>[],
  tips: <CoachTip>[],
  flags: <String>[],
  disclaimer: SafetyBounds.disclaimer,
);

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.delegates,
  theme: SsTheme.light(),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('check-in persists the AI plan as the latest plan', (
    tester,
  ) async {
    final database = await AppDatabase.memory();
    final client = _FakeCoachApiClient(
      CoachResponse(
        source: CoachSource.llm,
        plan: _aiPlan(),
        meta: const CoachMeta(model: 'fake-model'),
      ),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            coachEnabled: true,
            coachBaseUrl: 'http://fake',
            onboardingComplete: true,
            userName: 'Test',
          ),
        ),
        initialProgramProvider.overrideWithValue(ProgramSeed.powerbuilding()),
        initialActiveSessionProvider.overrideWithValue(null),
        coachApiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const CheckinScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('See my plan');
    await tester.scrollUntilVisible(
      button,
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(client.calls, 1);

    final saved = await tester.runAsync(
      () => container.read(coachPlanRepositoryProvider).latest(),
    );
    expect(saved, isNotNull);
    expect(saved!.plan.summary, 'AI plan from the check-in');
    expect(saved.plan.source, CoachSource.llm);

    final latest = await tester.runAsync(
      () => container.read(latestCoachPlanProvider.future),
    );
    expect(latest, isNotNull);
    expect(latest!.plan.summary, 'AI plan from the check-in');
  });
}
