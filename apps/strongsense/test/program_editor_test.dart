import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/core/theme/ss_theme.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/features/program/program_screen.dart';
import 'package:strongsense/features/program/set_targets_dialog.dart';
import 'package:strongsense/l10n/app_localizations.dart';
import 'package:strongsense/state/providers.dart';
import 'package:strongsense_core/strongsense_core.dart';

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

  testWidgets('editing one set keeps the rest of the prescribed sets', (
    tester,
  ) async {
    final container = await _createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(const ProgramScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('set-0-load')), '80');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    final program = container.read(programControllerProvider);
    final squat = program.dayById('day-1')!.exerciseById('ex-squat')!;
    expect(squat.setTargets, hasLength(4));
    expect(squat.setTargets.first.loadKg, 80);
    expect(squat.setTargets[1].loadKg, 75);
  });

  testWidgets('the set dialog preserves ranges and back-off loads', (
    tester,
  ) async {
    List<SetTarget>? result;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showSetTargetsDialog(
                  context: context,
                  exerciseName: 'Deadlift',
                  targets: const <SetTarget>[
                    SetTarget(reps: 5, loadKg: 80),
                    SetTarget(reps: 5, loadKg: 70),
                    SetTarget(reps: 15, repsMax: 20),
                  ],
                  unit: Unit.kg,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('set-0-load')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-2-repsMax')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, hasLength(3));
    expect(result![0].loadKg, 80);
    expect(result![1].loadKg, 70);
    expect(result![2].reps, 15);
    expect(result![2].repsMax, 20);
  });
}
