import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/core/theme/ss_theme.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/features/settings/settings_screen.dart';
import 'package:strongsense/l10n/app_localizations.dart';
import 'package:strongsense/state/providers.dart';
import 'package:strongsense_core/strongsense_core.dart';

const kCoachTokenKey = ValueKey<String>('coach-token');

Future<ProviderContainer> _createContainer() async {
  final database = await AppDatabase.memory();
  final container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(database),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      initialProgramProvider.overrideWithValue(ProgramSeed.powerbuilding()),
      initialActiveSessionProvider.overrideWithValue(null),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await database.close();
  });
  return container;
}

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.delegates,
    theme: SsTheme.light(),
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saving the coach token persists it', (tester) async {
    final container = await _createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(kCoachTokenKey),
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(kCoachTokenKey), 'abc123');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(container.read(settingsControllerProvider).coachToken, 'abc123');
  });

  testWidgets('toggling visibility switches the obscure mode', (tester) async {
    final container = await _createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(kCoachTokenKey),
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final before = tester
        .widget<TextField>(find.byKey(kCoachTokenKey))
        .obscureText;
    expect(before, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_rounded).first);
    await tester.pumpAndSettle();
    final after = tester
        .widget<TextField>(find.byKey(kCoachTokenKey))
        .obscureText;
    expect(after, isFalse);
  });
}
