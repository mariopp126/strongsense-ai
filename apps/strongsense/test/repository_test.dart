import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/data/repositories/coach_plan_repository.dart';
import 'package:strongsense/data/repositories/program_repository.dart';
import 'package:strongsense/data/repositories/session_repository.dart';
import 'package:strongsense/data/repositories/settings_repository.dart';
import 'package:strongsense_core/strongsense_core.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  group('SettingsRepository', () {
    test('returns defaults when empty and persists updates', () async {
      final repository = SettingsRepository(database);

      final initial = await repository.load();
      expect(initial.userName, isEmpty);
      expect(initial.unit, Unit.kg);

      await repository.save(
        const AppSettings(userName: 'Mario', unit: Unit.lb, language: 'es'),
      );

      final loaded = await repository.load();
      expect(loaded.userName, 'Mario');
      expect(loaded.unit, Unit.lb);
      expect(loaded.language, 'es');
    });
  });

  group('ProgramRepository', () {
    test('seeds the default program once', () async {
      final repository = ProgramRepository(database);

      final first = await repository.loadOrSeed();
      final second = await repository.loadOrSeed();

      expect(first.days.length, 3);
      expect(second.days.length, 3);
      expect(second.days.first.title, first.days.first.title);
    });

    test('persists program edits', () async {
      final repository = ProgramRepository(database);
      final program = await repository.loadOrSeed();
      await repository.save(program.copyWith(name: 'Custom'));

      final loaded = await repository.loadOrSeed();
      expect(loaded.name, 'Custom');
    });
  });

  group('SessionRepository', () {
    test('saves, loads and filters sessions', () async {
      final repository = SessionRepository(database);
      final started = DateTime(2026, 11, 14, 10);
      final inProgress = Session(
        id: 'session-draft',
        dayId: 'day-2',
        date: DateTime(2026, 11, 14),
        startedAt: started,
        checkIn: const CheckIn(
          sleepQuality: 4,
          energy: 3,
          motivation: 4,
          soreness: 2,
          stress: 2,
          painSeverity: 0,
          timeAvailableMin: 60,
        ),
        setLogs: const <SetLog>[
          SetLog(
            exerciseId: 'ex-bench',
            setIndex: 0,
            targetReps: 5,
            reps: 5,
            loadKg: 75,
            completed: true,
          ),
        ],
        status: SessionStatus.inProgress,
      );
      final completed = Session(
        id: 'session-done',
        dayId: 'day-2',
        date: DateTime(2026, 11, 14),
        startedAt: started,
        checkIn: inProgress.checkIn,
        setLogs: inProgress.setLogs,
        status: SessionStatus.completed,
        completedAt: started.add(const Duration(minutes: 45)),
      );

      await repository.save(inProgress);
      await repository.save(completed);

      expect((await repository.loadAll()).length, 2);
      expect((await repository.loadCompleted()).length, 1);
      expect((await repository.loadCompleted()).single.id, 'session-done');
      expect((await repository.loadInProgress())?.id, 'session-draft');
      expect(
        (await repository.byId('session-draft'))?.status,
        SessionStatus.inProgress,
      );
      expect(
        (await repository.byId('session-done'))?.status,
        SessionStatus.completed,
      );

      await repository.delete('session-draft');
      await repository.delete('session-done');
      expect(await repository.loadAll(), isEmpty);
    });
  });

  group('CoachPlanRepository', () {
    test('stores and retrieves the latest plan', () async {
      final repository = CoachPlanRepository(database);
      const plan = CoachPlan(
        source: CoachSource.rules,
        summary: 'Test summary',
        readinessExplanation: 'Test explanation',
        rpeCap: 8.5,
        deload: false,
        adjustments: <Adjustment>[],
        tips: <CoachTip>[
          CoachTip(title: 'Tip', body: 'Body', category: TipCategory.technique),
        ],
        flags: <String>[],
        disclaimer: SafetyBounds.disclaimer,
      );

      await repository.save('session-1', plan);

      final stored = await repository.forSession('session-1');
      expect(stored, isNotNull);
      expect(stored!.summary, 'Test summary');
      expect(stored.tips.single.title, 'Tip');

      final latest = await repository.latest();
      expect(latest, isNotNull);
      expect(latest!.plan.summary, 'Test summary');
    });

    test('saveLatest stores a plan without a session id', () async {
      final repository = CoachPlanRepository(database);
      const plan = CoachPlan(
        source: CoachSource.llm,
        summary: 'AI plan from check-in',
        readinessExplanation: 'Explanation',
        rpeCap: 8.5,
        deload: false,
        adjustments: <Adjustment>[],
        tips: <CoachTip>[],
        flags: <String>[],
        disclaimer: SafetyBounds.disclaimer,
      );

      await repository.saveLatest(plan);

      final latest = await repository.latest();
      expect(latest, isNotNull);
      expect(latest!.plan.summary, 'AI plan from check-in');
      expect(latest.plan.source, CoachSource.llm);
    });
  });
}
