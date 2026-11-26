import 'package:strongsense_core/strongsense_core.dart';

import '../repositories/coach_plan_repository.dart';
import '../repositories/program_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/settings_repository.dart';

/// Outcome of importing a backup, used by the Settings screen.
class BackupImportResult {
  const BackupImportResult({
    required this.mode,
    required this.settings,
    required this.program,
    required this.sessionCount,
    required this.coachPlanCount,
  });

  final BackupImportMode mode;
  final AppSettings settings;
  final TrainingProgram program;
  final int sessionCount;
  final int coachPlanCount;
}

/// Builds, exports and imports the local data snapshot.
///
/// All validation happens in the pure-Dart core before any repository is
/// touched, so a malformed file cannot partially overwrite local data.
class BackupService {
  BackupService({
    required this.settingsRepository,
    required this.programRepository,
    required this.sessionRepository,
    required this.coachPlanRepository,
  });

  final SettingsRepository settingsRepository;
  final ProgramRepository programRepository;
  final SessionRepository sessionRepository;
  final CoachPlanRepository coachPlanRepository;

  Future<BackupDocument> buildDocument() async {
    final settings = await settingsRepository.load();
    final program = await programRepository.loadOrSeed();
    final sessions = await sessionRepository.loadAll();
    final coachPlans = await coachPlanRepository.loadAll();
    return BackupDocument(
      exportedAt: DateTime.now(),
      settings: settings,
      program: program,
      sessions: sessions,
      coachPlans: <BackupCoachPlan>[
        for (final record in coachPlans)
          BackupCoachPlan(
            key: record.key,
            generatedAt: record.generatedAt,
            plan: record.plan,
          ),
      ],
    );
  }

  Future<String> exportJson() async => (await buildDocument()).encode();

  Future<String> exportCsv() async =>
      SessionCsvExporter.toCsv(await sessionRepository.loadAll());

  Future<BackupImportResult> importJson(
    String raw, {
    required BackupImportMode mode,
  }) async {
    final backup = BackupDocument.decode(raw);
    final currentSettings = await settingsRepository.load();
    final currentProgram = await programRepository.loadOrSeed();
    final currentSessions = await sessionRepository.loadAll();
    final currentPlans = await coachPlanRepository.loadAll();

    final merged = BackupMerger.merge(
      backup: backup,
      currentSettings: currentSettings,
      currentProgram: currentProgram,
      currentSessions: currentSessions,
      currentCoachPlans: <BackupCoachPlan>[
        for (final record in currentPlans)
          BackupCoachPlan(
            key: record.key,
            generatedAt: record.generatedAt,
            plan: record.plan,
          ),
      ],
      mode: mode,
    );

    if (mode == BackupImportMode.replace) {
      await sessionRepository.deleteAll();
      await coachPlanRepository.deleteAll();
    }
    await settingsRepository.save(merged.settings);
    await programRepository.save(merged.program);
    for (final session in merged.sessions) {
      await sessionRepository.save(session);
    }
    for (final coachPlan in merged.coachPlans) {
      await coachPlanRepository.saveRecord(
        SavedCoachPlanRecord(
          key: coachPlan.key,
          plan: coachPlan.plan,
          generatedAt: coachPlan.generatedAt,
        ),
      );
    }

    return BackupImportResult(
      mode: mode,
      settings: merged.settings,
      program: merged.program,
      sessionCount: merged.sessionCount,
      coachPlanCount: merged.coachPlanCount,
    );
  }
}
