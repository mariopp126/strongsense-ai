import '../models/app_settings.dart';
import '../models/program.dart';
import '../models/session.dart';
import 'backup_document.dart';

/// How an imported backup interacts with the current local data.
enum BackupImportMode {
  /// Keep the current settings/program and union sessions/plans by id/key,
  /// keeping the newest record when both sides contain the same id/key.
  merge,

  /// Replace settings, program, sessions and coach plans with the backup.
  replace,
}

/// The data that should be persisted after an import.
class BackupMergeResult {
  const BackupMergeResult({
    required this.mode,
    required this.settings,
    required this.program,
    required this.sessions,
    required this.coachPlans,
  });

  final BackupImportMode mode;
  final AppSettings settings;
  final TrainingProgram program;
  final List<Session> sessions;
  final List<BackupCoachPlan> coachPlans;

  int get sessionCount => sessions.length;

  int get coachPlanCount => coachPlans.length;
}

/// Pure conflict resolution for backups.
abstract final class BackupMerger {
  static BackupMergeResult merge({
    required BackupDocument backup,
    required AppSettings currentSettings,
    required TrainingProgram currentProgram,
    required List<Session> currentSessions,
    required List<BackupCoachPlan> currentCoachPlans,
    required BackupImportMode mode,
  }) {
    if (mode == BackupImportMode.replace) {
      return BackupMergeResult(
        mode: mode,
        settings: backup.settings,
        program: backup.program,
        sessions: _sortSessions(backup.sessions),
        coachPlans: _sortPlans(backup.coachPlans),
      );
    }

    final sessions = <String, Session>{
      for (final session in currentSessions) session.id: session,
    };
    for (final imported in backup.sessions) {
      final existing = sessions[imported.id];
      if (existing == null ||
          _sessionTimestamp(imported).isAfter(_sessionTimestamp(existing))) {
        sessions[imported.id] = imported;
      }
    }

    final plans = <String, BackupCoachPlan>{
      for (final coachPlan in currentCoachPlans) coachPlan.key: coachPlan,
    };
    for (final imported in backup.coachPlans) {
      final existing = plans[imported.key];
      if (existing == null ||
          imported.generatedAt.isAfter(existing.generatedAt)) {
        plans[imported.key] = imported;
      }
    }

    return BackupMergeResult(
      mode: mode,
      settings: currentSettings,
      program: currentProgram,
      sessions: _sortSessions(sessions.values),
      coachPlans: _sortPlans(plans.values),
    );
  }

  static DateTime _sessionTimestamp(Session session) =>
      session.completedAt ?? session.startedAt;

  static List<Session> _sortSessions(Iterable<Session> sessions) {
    final sorted = sessions.toList(growable: false);
    sorted.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sorted;
  }

  static List<BackupCoachPlan> _sortPlans(Iterable<BackupCoachPlan> plans) {
    final sorted = plans.toList(growable: false);
    sorted.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return sorted;
  }
}
