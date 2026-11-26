import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/data/repositories/program_repository.dart';
import 'package:strongsense/data/repositories/session_repository.dart';
import 'package:strongsense/data/services/program_template_service.dart';
import 'package:strongsense_core/strongsense_core.dart';

Session _session(String dayId, String exerciseId) {
  return Session(
    id: 'session-$dayId',
    dayId: dayId,
    date: DateTime(2026, 11, 26),
    startedAt: DateTime.utc(2026, 11, 26, 10),
    status: SessionStatus.completed,
    checkIn: const CheckIn(
      sleepQuality: 4,
      sleepHours: 7.5,
      energy: 4,
      motivation: 4,
      soreness: 2,
      stress: 2,
      painSeverity: 0,
      timeAvailableMin: 60,
    ),
    setLogs: <SetLog>[
      SetLog(
        exerciseId: exerciseId,
        setIndex: 0,
        targetReps: 5,
        reps: 5,
        loadKg: 75,
        rpe: 8,
        completed: true,
      ),
    ],
    completedAt: DateTime.utc(2026, 11, 26, 11),
  );
}

void main() {
  const service = ProgramTemplateService();
  const increments = Increments();

  test('select builds a template program with persistent state', () {
    final definition = ProgramTemplates.byId(ProgramTemplates.fiveThreeOneId)!;

    final program = service.select(
      template: definition,
      current: ProgramSeed.powerbuilding(),
      increments: increments,
    );

    expect(program.template, isNotNull);
    expect(program.template!.templateId, ProgramTemplates.fiveThreeOneId);
    expect(program.template!.week, 1);
    expect(program.days.length, 4);
    expect(program.days.first.exerciseById('ex-squat'), isNotNull);
  });

  test('advanceAfterSession moves a 5/3/1 program to week 2', () {
    final definition = ProgramTemplates.byId(ProgramTemplates.fiveThreeOneId)!;
    final program = service.select(
      template: definition,
      current: ProgramSeed.powerbuilding(),
      increments: increments,
    );

    final next = service.advanceAfterSession(
      session: _session('531-day-1', 'ex-squat'),
      program: program,
      completedSessions: 4,
      increments: increments,
    );

    expect(next, isNotNull);
    expect(next!.template!.week, 2);
    expect(next.days.length, 4);
  });

  test('a custom program is never advanced by the template service', () {
    final next = service.advanceAfterSession(
      session: _session('day-1', 'ex-squat'),
      program: ProgramSeed.powerbuilding(),
      completedSessions: 4,
      increments: increments,
    );
    expect(next, isNull);
  });

  test('switching templates keeps existing session history', () async {
    final database = await AppDatabase.memory();
    for (final store in <String>[
      AppDatabase.programsStore,
      AppDatabase.sessionsStore,
    ]) {
      await database.store(store).delete(database.db);
    }
    final sessions = SessionRepository(database);
    final programs = ProgramRepository(database);
    addTearDown(() async {
      await database.close();
    });

    await sessions.save(_session('day-1', 'ex-squat'));
    await programs.save(ProgramSeed.powerbuilding());

    final definition = ProgramTemplates.byId(ProgramTemplates.gzclpId)!;
    final next = service.select(
      template: definition,
      current: await programs.loadOrSeed(),
      increments: increments,
    );
    await programs.save(next);

    final history = await sessions.loadAll();
    final program = await programs.loadOrSeed();

    expect(history.single.id, 'session-day-1');
    expect(program.template!.templateId, ProgramTemplates.gzclpId);
  });
}
