import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/core/theme/ss_theme.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/data/services/notification_service.dart';
import 'package:strongsense/features/settings/settings_screen.dart';
import 'package:strongsense/l10n/app_localizations.dart';
import 'package:strongsense/state/providers.dart';
import 'package:strongsense_core/strongsense_core.dart';

class _FakeNotificationService implements NotificationService {
  bool granted = true;
  int permissionCalls = 0;
  AppSettings? lastSettings;
  int restCalls = 0;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermissions() async {
    permissionCalls += 1;
    return granted;
  }

  @override
  Future<void> syncReminders(AppSettings settings) async {
    lastSettings = settings;
  }

  @override
  Future<void> scheduleRestDone({
    required Duration rest,
    required String title,
    required String body,
  }) async {
    restCalls += 1;
  }

  @override
  Future<void> cancelRestDone() async {}
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.delegates,
  theme: SsTheme.light(),
  home: home,
);

Future<void> _pump(WidgetTester tester, {int frames = 20}) async {
  for (var index = 0; index < frames; index++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enabling training reminders requests permission and syncs', (
    tester,
  ) async {
    final database = await AppDatabase.memory();
    final notifications = _FakeNotificationService();
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(userName: 'Test', onboardingComplete: true),
        ),
        initialProgramProvider.overrideWithValue(ProgramSeed.powerbuilding()),
        initialActiveSessionProvider.overrideWithValue(null),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final reminderTile = find.text('Training reminders');
    await tester.scrollUntilVisible(
      reminderTile,
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await _pump(tester);
    expect(reminderTile, findsOneWidget);

    await tester.tap(reminderTile);
    await _pump(tester);

    expect(notifications.permissionCalls, 1);
    expect(notifications.lastSettings?.remindersEnabled, isTrue);
    expect(container.read(settingsControllerProvider).remindersEnabled, isTrue);
  });

  testWidgets('a denied permission leaves reminders disabled', (tester) async {
    final database = await AppDatabase.memory();
    final notifications = _FakeNotificationService()..granted = false;
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(userName: 'Test', onboardingComplete: true),
        ),
        initialProgramProvider.overrideWithValue(ProgramSeed.powerbuilding()),
        initialActiveSessionProvider.overrideWithValue(null),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final reminderTile = find.text('Training reminders');
    await tester.scrollUntilVisible(
      reminderTile,
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await _pump(tester);

    await tester.tap(reminderTile);
    await _pump(tester);

    expect(notifications.permissionCalls, 1);
    expect(
      container.read(settingsControllerProvider).remindersEnabled,
      isFalse,
    );
  });
}
