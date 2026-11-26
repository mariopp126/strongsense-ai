import 'package:strongsense_core/strongsense_core.dart';
import 'package:test/test.dart';

Session _session(
  String id, {
  DateTime? startedAt,
  DateTime? completedAt,
  String setNotes = '',
}) {
  final started = startedAt ?? DateTime.utc(2026, 11, 20, 10);
  final completed = completedAt ?? started.add(const Duration(hours: 1));
  return Session(
    id: id,
    dayId: 'day-1',
    date: DateTime(2026, 11, 20),
    startedAt: started,
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
      notes: 'felt good',
    ),
    setLogs: <SetLog>[
      SetLog(
        exerciseId: 'ex-squat',
        setIndex: 0,
        targetReps: 5,
        targetLoadKg: 75,
        reps: 5,
        loadKg: 75,
        rpe: 8,
        completed: true,
        notes: setNotes,
      ),
    ],
    notes: 'Session notes, "quoted"',
    completedAt: completed,
    sessionRpe: 8,
  );
}

CoachPlan _plan(String summary) => CoachPlan(
  source: CoachSource.llm,
  summary: summary,
  readinessExplanation: 'Explanation',
  rpeCap: 8.5,
  deload: false,
  adjustments: const <Adjustment>[
    Adjustment(
      exerciseId: 'ex-squat',
      exercise: 'Squat',
      loadDeltaPct: 2.5,
      setsDelta: 0,
      reason: 'Good readiness',
    ),
  ],
  tips: const <CoachTip>[
    CoachTip(title: 'Tip', body: 'Body', category: TipCategory.technique),
  ],
  flags: const <String>['Flag'],
  disclaimer: SafetyBounds.disclaimer,
);

AppSettings _settings({String name = 'Mario'}) => AppSettings(
  userName: name,
  unit: Unit.lb,
  coachEnabled: true,
  coachBaseUrl: 'http://127.0.0.1:8080',
  coachToken: 'secret-token',
  onboardingComplete: true,
  bodyWeightKg: 82.5,
);

BackupDocument _document({String summary = 'Round trip'}) => BackupDocument(
  exportedAt: DateTime.utc(2026, 11, 26, 12),
  settings: _settings(),
  program: ProgramSeed.powerbuilding(),
  sessions: <Session>[_session('session-1')],
  coachPlans: <BackupCoachPlan>[
    BackupCoachPlan(
      key: 'latest',
      generatedAt: DateTime.utc(2026, 11, 26, 12),
      plan: _plan(summary),
    ),
  ],
);

void main() {
  group('BackupDocument', () {
    test('round-trips settings, program, sessions and coach plans', () {
      final document = _document();
      final decoded = BackupDocument.decode(document.encode());

      expect(decoded.exportedAt.isAtSameMomentAs(document.exportedAt), isTrue);
      expect(decoded.settings.userName, 'Mario');
      expect(decoded.settings.coachToken, 'secret-token');
      expect(decoded.program.days.length, 3);
      expect(decoded.sessions.single.id, 'session-1');
      expect(decoded.sessions.single.setLogs.single.reps, 5);
      expect(decoded.sessions.single.completedAt, isNotNull);
      expect(decoded.coachPlans.single.key, 'latest');
      expect(decoded.coachPlans.single.plan.summary, 'Round trip');
      expect(
        decoded.coachPlans.single.plan.adjustments.single.reason,
        'Good readiness',
      );
    });

    test('rejects a file without the format marker', () {
      expect(
        () => BackupDocument.decode('{"schemaVersion": 1}'),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects an unsupported schema version', () {
      final json = _document().toJson()..['schemaVersion'] = 99;
      expect(
        () => BackupDocument.fromJson(json),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects duplicate session ids', () {
      final json = _document().toJson();
      final sessions = List<dynamic>.from(json['sessions'] as List);
      sessions.add(sessions.first);
      json['sessions'] = sessions;
      expect(
        () => BackupDocument.fromJson(json),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects malformed session data', () {
      final json = _document().toJson();
      final sessions = List<dynamic>.from(json['sessions'] as List);
      sessions.add(<String, dynamic>{'id': 'broken'});
      json['sessions'] = sessions;
      expect(
        () => BackupDocument.fromJson(json),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('BackupMerger', () {
    test('merge keeps current settings/program and the newest conflicts', () {
      final current = _session(
        'session-1',
        startedAt: DateTime.utc(2026, 11, 25, 10),
        completedAt: DateTime.utc(2026, 11, 25, 11),
      );
      final importedOld = _session(
        'session-1',
        startedAt: DateTime.utc(2026, 11, 20, 10),
        completedAt: DateTime.utc(2026, 11, 20, 11),
      );
      final importedNew = _session(
        'session-2',
        startedAt: DateTime.utc(2026, 11, 26, 10),
        completedAt: DateTime.utc(2026, 11, 26, 11),
      );

      final result = BackupMerger.merge(
        backup: BackupDocument(
          exportedAt: DateTime.utc(2026, 11, 26, 12),
          settings: _settings(name: 'Backup'),
          program: ProgramSeed.powerbuilding().copyWith(name: 'Backup program'),
          sessions: <Session>[importedOld, importedNew],
          coachPlans: <BackupCoachPlan>[
            BackupCoachPlan(
              key: 'latest',
              generatedAt: DateTime.utc(2026, 11, 26, 12),
              plan: _plan('Newer plan'),
            ),
          ],
        ),
        currentSettings: _settings(name: 'Current'),
        currentProgram: ProgramSeed.powerbuilding(),
        currentSessions: <Session>[current],
        currentCoachPlans: <BackupCoachPlan>[
          BackupCoachPlan(
            key: 'latest',
            generatedAt: DateTime.utc(2026, 11, 20, 12),
            plan: _plan('Older plan'),
          ),
        ],
        mode: BackupImportMode.merge,
      );

      expect(result.settings.userName, 'Current');
      expect(result.program.name, 'Powerbuilding 3-Day');
      expect(
        result.sessions.map((s) => s.id),
        containsAll(<String>['session-1', 'session-2']),
      );
      final session1 = result.sessions.firstWhere((s) => s.id == 'session-1');
      expect(session1.startedAt.isAtSameMomentAs(current.startedAt), isTrue);
      expect(result.coachPlans.single.plan.summary, 'Newer plan');
    });

    test('replace uses the backup settings, program and records', () {
      final result = BackupMerger.merge(
        backup: BackupDocument(
          exportedAt: DateTime.utc(2026, 11, 26, 12),
          settings: _settings(name: 'Backup'),
          program: ProgramSeed.powerbuilding().copyWith(name: 'Backup program'),
          sessions: <Session>[_session('imported')],
          coachPlans: <BackupCoachPlan>[
            BackupCoachPlan(
              key: 'latest',
              generatedAt: DateTime.utc(2026, 11, 26, 12),
              plan: _plan('Backup plan'),
            ),
          ],
        ),
        currentSettings: _settings(name: 'Current'),
        currentProgram: ProgramSeed.powerbuilding(),
        currentSessions: <Session>[_session('current')],
        currentCoachPlans: const <BackupCoachPlan>[],
        mode: BackupImportMode.replace,
      );

      expect(result.settings.userName, 'Backup');
      expect(result.program.name, 'Backup program');
      expect(result.sessions.single.id, 'imported');
      expect(result.coachPlans.single.plan.summary, 'Backup plan');
    });
  });

  group('SessionCsvExporter', () {
    test('writes a header, one row per set and escapes CSV fields', () {
      final csv = SessionCsvExporter.toCsv(<Session>[
        _session('session-1', setNotes: 'note, with "quotes"\nand a newline'),
        _session('session-2', startedAt: DateTime.utc(2026, 11, 21, 10)),
      ]);

      expect(csv.startsWith('\uFEFFsession_id,date,day_id'), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(lines.first, startsWith('session_id,date,day_id'));
      expect(lines.length, 4); // header + 1 set + 1 set + trailing empty
      expect(lines[1], contains('session-1'));
      expect(lines[1], contains('"note, with ""quotes""\nand a newline"'));
      expect(lines[2], contains('session-2'));
    });
  });

  test('large history encodes and decodes within a reasonable budget', () {
    final sessions = <Session>[
      for (var index = 0; index < 2000; index++)
        _session(
          'session-$index',
          startedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: index)),
        ),
    ];
    final document = BackupDocument(
      exportedAt: DateTime.utc(2026, 11, 26, 12),
      settings: _settings(),
      program: ProgramSeed.powerbuilding(),
      sessions: sessions,
      coachPlans: const <BackupCoachPlan>[],
    );

    final stopwatch = Stopwatch()..start();
    final encoded = document.encode();
    final decoded = BackupDocument.decode(encoded);
    stopwatch.stop();

    expect(decoded.sessions.length, 2000);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    print(
      'Backup 2000 sessions: ${stopwatch.elapsedMilliseconds} ms '
      '(${encoded.length} chars)',
    );
  });
}
