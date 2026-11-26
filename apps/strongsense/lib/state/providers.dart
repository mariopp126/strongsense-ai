import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../data/local/app_database.dart';
import '../data/remote/coach_api_client.dart';
import '../data/repositories/coach_plan_repository.dart';
import '../data/repositories/program_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/backup_file_service.dart';
import '../data/services/backup_service.dart';
import '../data/services/coach_context_service.dart';
import '../data/services/coach_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/program_template_service.dart';
import 'program_controller.dart';
import 'session_controller.dart';
import 'settings_controller.dart';

// ---------------------------------------------------------------------------
// Bootstrapping (overridden in main.dart)
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final initialProgramProvider = Provider<TrainingProgram>(
  (ref) =>
      throw UnimplementedError('initialProgramProvider must be overridden'),
);

final initialActiveSessionProvider = Provider<Session?>((ref) => null);

// ---------------------------------------------------------------------------
// Repositories & services
// ---------------------------------------------------------------------------

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => ProgramRepository(ref.watch(appDatabaseProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(appDatabaseProvider)),
);

final coachPlanRepositoryProvider = Provider<CoachPlanRepository>(
  (ref) => CoachPlanRepository(ref.watch(appDatabaseProvider)),
);

final coachApiClientProvider = Provider<CoachApiClient>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return CoachApiClient(
    baseUrl: settings.coachBaseUrl,
    coachToken: settings.coachToken,
  );
});

final coachServiceProvider = Provider<CoachService>(
  (ref) => CoachService(
    settings: ref.watch(settingsControllerProvider),
    client: ref.watch(coachApiClientProvider),
  ),
);

final coachContextServiceProvider = Provider<CoachContextService>(
  (ref) => CoachContextService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    program: ref.watch(programControllerProvider),
    settings: ref.watch(settingsControllerProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    settingsRepository: ref.watch(settingsRepositoryProvider),
    programRepository: ref.watch(programRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    coachPlanRepository: ref.watch(coachPlanRepositoryProvider),
  ),
);

final backupFileServiceProvider = Provider<BackupFileService>(
  (ref) => const BackupFileService(),
);

final programTemplateServiceProvider = Provider<ProgramTemplateService>(
  (ref) => const ProgramTemplateService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => createNotificationService(),
);

// ---------------------------------------------------------------------------
// Controllers
// ---------------------------------------------------------------------------

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
      (ref) => SettingsController(
        repository: ref.watch(settingsRepositoryProvider),
        initial: ref.read(initialSettingsProvider),
      ),
    );

final programControllerProvider =
    StateNotifierProvider<ProgramController, TrainingProgram>(
      (ref) => ProgramController(
        repository: ref.watch(programRepositoryProvider),
        initial: ref.read(initialProgramProvider),
      ),
    );

final sessionControllerProvider =
    StateNotifierProvider<SessionController, Session?>(
      (ref) => SessionController(
        repository: ref.watch(sessionRepositoryProvider),
        coachPlanRepository: ref.watch(coachPlanRepositoryProvider),
        initial: ref.read(initialActiveSessionProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Derived state
// ---------------------------------------------------------------------------

final historyProvider = FutureProvider<List<Session>>(
  (ref) => ref.watch(sessionRepositoryProvider).loadCompleted(),
);

final personalRecordsProvider = Provider<List<PersonalRecord>>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull;
  if (sessions == null) {
    return const <PersonalRecord>[];
  }
  return RecordsCalculator.personalRecords(sessions);
});

final latestCoachPlanProvider = FutureProvider<SavedCoachPlan?>(
  (ref) => ref.watch(coachPlanRepositoryProvider).latest(),
);

final nextDayProvider = Provider<ProgramDay>((ref) {
  final program = ref.watch(programControllerProvider);
  final sessions = ref.watch(historyProvider).valueOrNull;
  if (sessions == null || sessions.isEmpty) {
    return program.days.first;
  }
  final index = program.days.indexWhere(
    (day) => day.id == sessions.first.dayId,
  );
  if (index < 0) {
    return program.days.first;
  }
  return program.days[(index + 1) % program.days.length];
});

final activeSessionProvider = Provider<Session?>(
  (ref) => ref.watch(sessionControllerProvider),
);

final hasActiveSessionProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session != null && session.status == SessionStatus.inProgress;
});

class WeeklyStats {
  const WeeklyStats({required this.sessions, required this.volumeKg});

  final int sessions;
  final double volumeKg;
}

final weeklyStatsProvider = Provider<WeeklyStats>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull;
  if (sessions == null || sessions.isEmpty) {
    return const WeeklyStats(sessions: 0, volumeKg: 0);
  }
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  final week = sessions
      .where((session) => session.date.isAfter(cutoff))
      .toList(growable: false);
  return WeeklyStats(
    sessions: week.length,
    volumeKg: week.fold<double>(
      0,
      (sum, session) => sum + session.totalVolumeKg,
    ),
  );
});
