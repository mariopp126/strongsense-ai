import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/core/theme/ss_theme.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/features/settings/settings_screen.dart';
import 'package:strongsense/l10n/app_localizations.dart';
import 'package:strongsense/state/providers.dart';
import 'package:strongsense_core/strongsense_core.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.delegates,
  theme: SsTheme.light(),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings exposes backup, CSV and import actions', (
    tester,
  ) async {
    final database = await AppDatabase.memory();
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(userName: 'Test', onboardingComplete: true),
        ),
        initialProgramProvider.overrideWithValue(ProgramSeed.powerbuilding()),
        initialActiveSessionProvider.overrideWithValue(null),
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

    final exportTile = find.text('Export backup (JSON)');
    await tester.scrollUntilVisible(
      exportTile,
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(exportTile, findsOneWidget);
    expect(find.text('Export sessions (CSV)'), findsOneWidget);
    expect(find.text('Import backup (JSON)'), findsOneWidget);
    expect(find.text('Delete all data'), findsOneWidget);
  });
}
