import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

Session _session(
  String dayId,
  String exerciseId, {
  int reps = 5,
  double rpe = 8,
}) {
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
        reps: reps,
        loadKg: 75,
        rpe: rpe,
        completed: true,
      ),
    ],
    completedAt: DateTime.utc(2026, 11, 26, 11),
  );
}

void main() {
  const increments = Increments();

  group('registry', () {
    test('exposes the three templates and looks them up by id', () {
      expect(ProgramTemplates.all.length, 3);
      expect(
        ProgramTemplates.byId(ProgramTemplates.fiveThreeOneId)?.name,
        '5/3/1',
      );
      expect(ProgramTemplates.byId(ProgramTemplates.gzclpId)?.name, 'GZCLP');
      expect(
        ProgramTemplates.byId(ProgramTemplates.blockPeriodizationId)?.name,
        'Block Periodization',
      );
      expect(ProgramTemplates.byId('missing'), isNull);
    });

    test('derives training maxes from the current program', () {
      final template = ProgramTemplates.byId(ProgramTemplates.fiveThreeOneId)!;
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      expect(state.templateId, ProgramTemplates.fiveThreeOneId);
      expect(state.week, 1);
      expect(state.trainingMaxKg['ex-squat'], 75);
      expect(state.trainingMaxKg['ex-bench'], 75);
      expect(state.trainingMaxKg['ex-deadlift'], 80);
      expect(state.trainingMaxKg['ex-ohp'], 40);
    });
  });

  group('5/3/1', () {
    final template = ProgramTemplates.byId(ProgramTemplates.fiveThreeOneId)!;

    test('week 1 uses 65/75/85 percent sets', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final program = template.build(state, increments);
      final squat = program.days.first.exerciseById('ex-squat')!;

      expect(program.days.length, 4);
      expect(program.template, isNotNull);
      expect(squat.role, ExerciseRole.main);
      expect(squat.setTargets.map((set) => set.reps), <int>[5, 5, 5]);
      expect(squat.setTargets.map((set) => set.loadKg), <double?>[50, 55, 65]);
    });

    test('week 4 is a deload', () {
      final state = template
          .initialState(ProgramSeed.powerbuilding(), increments)
          .copyWith(week: 4);
      final program = template.build(state, increments);
      final squat = program.days.first.exerciseById('ex-squat')!;

      expect(squat.setTargets.map((set) => set.reps), <int>[5, 5, 5]);
      expect(squat.setTargets.map((set) => set.loadKg), <double?>[30, 40, 45]);
    });

    test('advances the week and increases maxes after a full cycle', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final week2 = template.advance(
        state,
        _session('531-day-1', 'ex-squat'),
        4,
        increments,
      );
      expect(week2.week, 2);
      expect(week2.trainingMaxKg['ex-squat'], 75);

      final nextCycle = template.advance(
        state,
        _session('531-day-4', 'ex-ohp'),
        16,
        increments,
      );
      expect(nextCycle.week, 1);
      expect(nextCycle.trainingMaxKg['ex-squat'], 80);
      expect(nextCycle.trainingMaxKg['ex-bench'], 77.5);
      expect(nextCycle.trainingMaxKg['ex-deadlift'], 85);
      expect(nextCycle.trainingMaxKg['ex-ohp'], 42.5);
    });
  });

  group('GZCLP', () {
    final template = ProgramTemplates.byId(ProgramTemplates.gzclpId)!;

    test('builds T1 5x3, T2 3x10 and T3 3x15', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final program = template.build(state, increments);
      final squat = program.days.first.exerciseById('ex-squat')!;
      final benchT2 = program.days.first.exerciseById('ex-bench')!;
      final pulldown = program.days.first.exerciseById('ex-lat-pulldown')!;

      expect(squat.setTargets.length, 5);
      expect(squat.setTargets.first.reps, 3);
      expect(squat.setTargets.first.loadKg, 75);

      expect(benchT2.setTargets.length, 3);
      expect(benchT2.setTargets.first.reps, 10);
      expect(benchT2.setTargets.first.loadKg, 50);

      expect(pulldown.setTargets.length, 3);
      expect(pulldown.setTargets.first.reps, 15);
      expect(pulldown.setTargets.first.loadKg, 37.5);
    });

    test('increases the trained lift after a successful session', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final next = template.advance(
        state,
        _session('gzclp-day-1', 'ex-squat'),
        1,
        increments,
      );
      expect(next.trainingMaxKg['ex-squat'], 80);
      expect(next.trainingMaxKg['ex-bench'], 75);
    });

    test('does not increase after missed reps', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final next = template.advance(
        state,
        _session('gzclp-day-1', 'ex-squat', reps: 2),
        1,
        increments,
      );
      expect(next.trainingMaxKg['ex-squat'], 75);
    });
  });

  group('block periodization', () {
    final template = ProgramTemplates.byId(
      ProgramTemplates.blockPeriodizationId,
    )!;

    test('builds volume, intensity and deload weeks', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final volume = template.build(state, increments);
      final squatVolume = volume.days.first.exerciseById('ex-squat')!;
      expect(squatVolume.setTargets.length, 4);
      expect(squatVolume.setTargets.first.reps, 8);
      expect(squatVolume.setTargets.first.loadKg, 55);

      final intensity = template.build(state.copyWith(week: 3), increments);
      final squatIntensity = intensity.days.first.exerciseById('ex-squat')!;
      expect(squatIntensity.setTargets.length, 5);
      expect(squatIntensity.setTargets.first.reps, 5);
      expect(squatIntensity.setTargets.first.loadKg, 60);

      final deload = template.build(state.copyWith(week: 4), increments);
      final squatDeload = deload.days.first.exerciseById('ex-squat')!;
      expect(squatDeload.setTargets.length, 3);
      expect(squatDeload.setTargets.first.reps, 5);
      expect(squatDeload.setTargets.first.loadKg, 45);
    });

    test('advances the week and increases maxes after the block', () {
      final state = template.initialState(
        ProgramSeed.powerbuilding(),
        increments,
      );
      final week2 = template.advance(
        state,
        _session('block-day-1', 'ex-squat'),
        4,
        increments,
      );
      expect(week2.week, 2);

      final nextBlock = template.advance(
        state,
        _session('block-day-4', 'ex-ohp'),
        16,
        increments,
      );
      expect(nextBlock.week, 1);
      expect(nextBlock.trainingMaxKg['ex-squat'], 80);
      expect(nextBlock.trainingMaxKg['ex-ohp'], 42.5);
    });
  });

  test('program template state round-trips through JSON', () {
    final template = ProgramTemplates.byId(ProgramTemplates.fiveThreeOneId)!;
    final state = template.initialState(
      ProgramSeed.powerbuilding(),
      increments,
    );
    final program = template.build(state, increments);

    final decoded = TrainingProgram.fromJson(program.toJson());

    expect(decoded.name, '5/3/1');
    expect(decoded.template, isNotNull);
    expect(decoded.template!.templateId, ProgramTemplates.fiveThreeOneId);
    expect(decoded.template!.week, 1);
    expect(decoded.template!.trainingMaxKg['ex-squat'], 75);
    expect(decoded.days.length, 4);
  });
}
