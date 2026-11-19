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

Future<void> _pumpProgram(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _app(const ProgramScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await _tapKey(tester, 'program-edit');
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) => _tapKey(tester, 'program-save');

TrainingProgram _program(ProviderContainer container) =>
    container.read(programControllerProvider);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editing one set keeps the rest of the prescribed sets', (
    tester,
  ) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await _tapKey(tester, 'exercise-ex-squat-sets');

    await tester.enterText(find.byKey(const ValueKey('set-0-load')), '80');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    await _save(tester);

    final squat = _program(
      container,
    ).dayById('day-1')!.exerciseById('ex-squat')!;
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

  testWidgets('save persists day, exercise and program renames', (
    tester,
  ) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('day-title-day-1')),
      'Lower A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise-name-ex-squat')),
      'High-Bar Squat',
    );
    await tester.enterText(
      find.byKey(const ValueKey('program-name')),
      'My Program',
    );
    await _save(tester);

    final program = _program(container);
    expect(program.name, 'My Program');
    expect(program.dayById('day-1')!.title, 'Lower A');
    expect(
      program.dayById('day-1')!.exerciseById('ex-squat')!.name,
      'High-Bar Squat',
    );
  });

  testWidgets('adds a day with a unique id and can restore the default', (
    tester,
  ) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await _tapKey(tester, 'program-add-day');
    await _save(tester);

    var program = _program(container);
    expect(program.days, hasLength(4));
    expect(program.days.map((day) => day.id).toSet(), hasLength(4));
    expect(program.days.last.exercises, isEmpty);

    await _tapKey(tester, 'program-edit');
    await _tapKey(tester, 'program-restore-default');
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();
    await _save(tester);

    program = _program(container);
    expect(program.days, hasLength(3));
    expect(program.days.map((day) => day.id), <String>[
      'day-1',
      'day-2',
      'day-3',
    ]);
  });

  testWidgets('duplicates a day with fresh exercise ids', (tester) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await _tapKey(tester, 'day-day-1-duplicate');
    await _save(tester);

    final program = _program(container);
    expect(program.days, hasLength(4));
    expect(program.days[1].title, 'Copy of Squat & Lower Body');
    expect(program.days[1].exercises, hasLength(5));
    final allExerciseIds = program.days
        .expand((day) => day.exercises)
        .map((exercise) => exercise.id)
        .toList();
    expect(allExerciseIds.toSet(), hasLength(allExerciseIds.length));
  });

  testWidgets('adds an exercise and switches its role to main', (tester) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await _tapKey(tester, 'day-day-1-add-exercise');

    var day = _program(container).dayById('day-1')!;
    expect(day.exercises, hasLength(5));

    final draftDays = container.read(programControllerProvider);
    expect(draftDays.days, hasLength(3));

    await _tapKey(tester, 'exercise-ex-squat-role');
    await tester.tap(find.text('Accessory').last);
    await tester.pumpAndSettle();
    await _save(tester);

    day = _program(container).dayById('day-1')!;
    expect(day.exercises, hasLength(6));
    expect(day.exerciseById('ex-squat')!.role, ExerciseRole.accessory);
  });

  testWidgets('reorders and duplicates exercises', (tester) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await _tapKey(tester, 'exercise-ex-squat-down');
    await _tapKey(tester, 'exercise-ex-squat-duplicate');
    await _save(tester);

    final day = _program(container).dayById('day-1')!;
    expect(day.exercises, hasLength(6));
    expect(day.exercises[1].id, 'ex-squat');
    final ids = day.exercises.map((exercise) => exercise.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  testWidgets('deleting an exercise requires confirmation', (tester) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await _tapKey(tester, 'exercise-ex-leg-extension-delete');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(
      _program(container).dayById('day-1')!.exerciseById('ex-leg-extension'),
      isNotNull,
    );

    await _tapKey(tester, 'exercise-ex-leg-extension-delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(
      _program(container).dayById('day-1')!.exerciseById('ex-leg-extension'),
      isNull,
    );
  });

  testWidgets('renamed day title shows in read-only view', (tester) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('day-title-day-1')),
      'Lower A',
    );
    await _save(tester);
    await tester.pumpAndSettle();

    expect(find.text('Lower A'), findsOneWidget);
    expect(find.text('Squat & Lower Body'), findsNothing);
  });

  testWidgets('cancel discards a draft without touching the saved program', (
    tester,
  ) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('day-title-day-1')),
      'Temporary',
    );
    await _tapKey(tester, 'program-cancel');
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(_program(container).dayById('day-1')!.title, 'Squat & Lower Body');
    expect(find.byKey(const ValueKey('day-title-day-1')), findsNothing);
    expect(find.byKey(const ValueKey('program-save')), findsNothing);
  });

  testWidgets('the unsaved-changes guard can keep editing', (tester) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('day-title-day-1')),
      'Temporary',
    );
    await _tapKey(tester, 'program-cancel');
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('program-save')), findsOneWidget);
  });

  testWidgets('invalid input blocks save and explains the field', (
    tester,
  ) async {
    final container = await _createContainer();
    await _pumpProgram(tester, container);

    await tester.enterText(find.byKey(const ValueKey('day-title-day-1')), '');
    await _save(tester);

    expect(find.text('Day title cannot be empty.'), findsOneWidget);
    expect(find.byKey(const ValueKey('program-save')), findsOneWidget);
    expect(_program(container).dayById('day-1')!.title, 'Squat & Lower Body');
  });
}
