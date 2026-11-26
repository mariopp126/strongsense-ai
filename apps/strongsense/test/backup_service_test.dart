import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/data/repositories/coach_plan_repository.dart';
import 'package:strongsense/data/repositories/program_repository.dart';
import 'package:strongsense/data/repositories/session_repository.dart';
import 'package:strongsense/data/repositories/settings_repository.dart';
import 'package:strongsense/data/services/backup_service.dart';
import 'package:strongsense_core/strongsense_core.dart';

Session _session(String id, {required DateTime startedAt, String notes = ''}) {
  return Session(
    id: id,
    dayId: 'day-1',
    date: DateTime(startedAt.year, startedAt.month, startedAt.day),
    startedAt: startedAt,
    status: SessionStatus.completed,
    checkIn: const CheckIn(
      sleepQuality: 4,
      sleepHours: 7.5,
      energy: 3,
      motivation: 4,
      soreness: 2,
      stress: 2,
      painSeverity: 0,
      timeAvailableMin: 60,
    ),
    setLogs: <SetLog>[
      const SetLog(
        exerciseId: 'ex-squat',
        setIndex: 0,
        targetReps: 5,
        targetLoadKg: 75,
        reps: 5,
        loadKg: 75,
        rpe: 8,
        completed: true,
      ),
    ],
    notes: notes,
    completedAt: startedAt.add(const Duration(hours: 1)),
    sessionRpe: 8,
  );
}

CoachPlan _plan(String summary) => CoachPlan(
  source: CoachSource.llm,
  summary: summary,
  readinessExplanation: 'Explanation',
  rpeCap: 8.5,
  deload: false,
  adjustments: const <Adjustment>[],
  tips: const <CoachTip>[],
  flags: const <String>[],
  disclaimer: SafetyBounds.disclaimer,
);

BackupDocument _backup({
  String settingsName = 'Backup',
  String programName = 'Backup program',
  required List<Session> sessions,
  required DateTime planGeneratedAt,
  String planSummary = 'Backup plan',
}) {
  return BackupDocument(
    exportedAt: DateTime.utc(2026, 11, 26, 12),
    settings: AppSettings(
      userName: settingsName,
      onboardingComplete: true,
      coachEnabled: true,
    ),
    program: ProgramSeed.powerbuilding().copyWith(name: programName),
    sessions: sessions,
    coachPlans: <BackupCoachPlan>[
      BackupCoachPlan(
        key: CoachPlanRepository.latestKey,
        generatedAt: planGeneratedAt,
        plan: _plan(planSummary),
      ),
    ],
  );
}

void main() {
  late AppDatabase database;
  late SettingsRepository settingsRepository;
  late ProgramRepository programRepository;
  late SessionRepository sessionRepository;
  late CoachPlanRepository coachPlanRepository;
  late BackupService service;

  setUp(() async {
    database = await AppDatabase.memory();
    for (final store in <String>[
      AppDatabase.settingsStore,
      AppDatabase.programsStore,
      AppDatabase.sessionsStore,
      AppDatabase.coachPlansStore,
    ]) {
      await database.store(store).delete(database.db);
    }
    settingsRepository = SettingsRepository(database);
    programRepository = ProgramRepository(database);
    sessionRepository = SessionRepository(database);
    coachPlanRepository = CoachPlanRepository(database);
    service = BackupService(
      settingsRepository: settingsRepository,
      programRepository: programRepository,
      sessionRepository: sessionRepository,
      coachPlanRepository: coachPlanRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedCurrent() async {
    await settingsRepository.save(
      const AppSettings(
        userName: 'Current',
        unit: Unit.lb,
        coachEnabled: true,
        onboardingComplete: true,
      ),
    );
    await programRepository.save(ProgramSeed.powerbuilding());
    await sessionRepository.save(
      _session('session-current', startedAt: DateTime.utc(2026, 11, 25, 10)),
    );
    await coachPlanRepository.saveRecord(
      SavedCoachPlanRecord(
        key: CoachPlanRepository.latestKey,
        generatedAt: DateTime.utc(2026, 11, 20, 12),
        plan: _plan('Current plan'),
      ),
    );
  }

  test('exports settings, program, sessions and coach plans', () async {
    await seedCurrent();

    final raw = await service.exportJson();
    final decoded = BackupDocument.decode(raw);

    expect(decoded.settings.userName, 'Current');
    expect(decoded.program.days.length, 3);
    expect(decoded.sessions.single.id, 'session-current');
    expect(decoded.coachPlans.single.key, 'latest');
    expect(decoded.coachPlans.single.plan.summary, 'Current plan');
  });

  test('replace imports the backup and removes current records', () async {
    await seedCurrent();
    final raw = _backup(
      sessions: <Session>[
        _session('session-imported', startedAt: DateTime.utc(2026, 11, 20, 10)),
      ],
      planGeneratedAt: DateTime.utc(2026, 11, 20, 12),
      planSummary: 'Replacement plan',
    ).encode();

    final result = await service.importJson(
      raw,
      mode: BackupImportMode.replace,
    );

    expect(result.mode, BackupImportMode.replace);
    expect(result.sessionCount, 1);
    expect((await settingsRepository.load()).userName, 'Backup');
    expect((await programRepository.loadOrSeed()).name, 'Backup program');
    final sessions = await sessionRepository.loadAll();
    expect(sessions.single.id, 'session-imported');
    final plans = await coachPlanRepository.loadAll();
    expect(plans.single.plan.summary, 'Replacement plan');
  });

  test('merge keeps current settings and the newest records', () async {
    await seedCurrent();
    final current = _session(
      'session-current',
      startedAt: DateTime.utc(2026, 11, 25, 10),
    );
    final importedOlder = _session(
      'session-current',
      startedAt: DateTime.utc(2026, 11, 20, 10),
    );
    final importedNew = _session(
      'session-imported',
      startedAt: DateTime.utc(2026, 11, 26, 10),
    );
    final raw = _backup(
      sessions: <Session>[importedOlder, importedNew],
      planGeneratedAt: DateTime.utc(2026, 11, 26, 12),
      planSummary: 'Newest plan',
    ).encode();

    final result = await service.importJson(raw, mode: BackupImportMode.merge);

    expect(result.mode, BackupImportMode.merge);
    expect((await settingsRepository.load()).userName, 'Current');
    expect((await programRepository.loadOrSeed()).name, 'Powerbuilding 3-Day');
    final sessions = await sessionRepository.loadAll();
    expect(
      sessions.map((session) => session.id),
      containsAll(<String>['session-current', 'session-imported']),
    );
    final currentAfter = sessions.firstWhere(
      (session) => session.id == 'session-current',
    );
    expect(currentAfter.startedAt.isAtSameMomentAs(current.startedAt), isTrue);
    final plans = await coachPlanRepository.loadAll();
    expect(plans.single.plan.summary, 'Newest plan');
  });

  test('rejects a malformed backup without touching local data', () async {
    await seedCurrent();

    await expectLater(
      service.importJson('not json', mode: BackupImportMode.replace),
      throwsA(isA<BackupException>()),
    );
    expect((await settingsRepository.load()).userName, 'Current');
    expect((await sessionRepository.loadAll()).single.id, 'session-current');
  });

  test('exports a CSV with one row per set', () async {
    await seedCurrent();

    final csv = await service.exportCsv();

    expect(csv, startsWith('\uFEFFsession_id,date,day_id'));
    expect(csv, contains('session-current'));
    expect(csv, contains('ex-squat'));
  });
}
