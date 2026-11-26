import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final active = ref.watch(sessionControllerProvider);
    final history = ref.watch(historyProvider).valueOrNull ?? const <Session>[];

    if (active != null && active.id == sessionId) {
      return _SummaryBody(
        session: active,
        program: program,
        settings: settings,
        history: history,
      );
    }

    return FutureBuilder<Session?>(
      future: ref.watch(sessionRepositoryProvider).byId(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.summaryTitle)),
            body: SsLoading(label: l10n.loading),
          );
        }
        final session = snapshot.data;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.summaryTitle)),
            body: SsEmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.errorGeneric,
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.done),
              ),
            ),
          );
        }
        return _SummaryBody(
          session: session,
          program: program,
          settings: settings,
          history: history,
        );
      },
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({
    required this.session,
    required this.program,
    required this.settings,
    required this.history,
  });

  final Session session;
  final TrainingProgram program;
  final AppSettings settings;
  final List<Session> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = _dayForSession(session, program);
    final summary = SessionSummaryCalculator.summarize(
      session: session,
      day: day,
    );
    final prs = _newPrs(session, history);
    final nextLoads = ProgressionEngine.nextTopLoads(
      session: session,
      day: day,
      increments: settings.increments,
    );
    final localeCode = Localizations.localeOf(context).languageCode;

    if (!session.isCompleted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.summaryTitle)),
        body: SsEmptyState(
          icon: Icons.timer_outlined,
          title: l10n.homeResume,
          body: l10n.homeResumeBody,
          action: FilledButton(
            onPressed: () => context.go('/workout/${session.id}'),
            child: Text(l10n.workoutTitle),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.summaryTitle),
        automaticallyImplyLeading: false,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.historyTitle,
            onPressed: () => context.go('/history'),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.xxl,
          SsSpacing.lg,
          SsSpacing.section,
        ),
        children: <Widget>[
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: SsColors.emerald100,
                shape: BoxShape.circle,
                border: Border.all(color: SsColors.emerald200, width: 2),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: SsColors.emerald700,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          Text(
            l10n.summaryTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(
            l10n.summarySubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            '${l10n.dayTitle(day.id, day.title)} · ${formatDateLong(session.date, localeCode)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (prs.isNotEmpty) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            SsBanner(
              message:
                  '${l10n.summaryPR} ${prs.map((record) => _exerciseName(program, record.exerciseId)).join(', ')}',
              color: SsColors.amber800,
              background: SsColors.amber100,
              icon: Icons.emoji_events_rounded,
            ),
          ],
          const SizedBox(height: SsSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: SsStatTile(
                  value: formatVolume(summary.totalVolumeKg, settings.unit),
                  label: l10n.summaryVolume,
                  icon: Icons.bar_chart_rounded,
                ),
              ),
              const SizedBox(width: SsSpacing.sm),
              Expanded(
                child: SsStatTile(
                  value: '${summary.setsCompleted}/${summary.setsPlanned}',
                  label: l10n.summarySets,
                  icon: Icons.checklist_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: SsStatTile(
                  value: '${summary.missedSets}',
                  label: l10n.summaryMissed,
                  icon: Icons.flag_outlined,
                  accent: summary.missedSets > 0
                      ? SsColors.orange500
                      : SsColors.emerald600,
                ),
              ),
              const SizedBox(width: SsSpacing.sm),
              Expanded(
                child: SsStatTile(
                  value: formatDuration(summary.durationMin),
                  label: l10n.summaryDuration,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          if (summary.sessionRpe != null) ...<Widget>[
            const SizedBox(height: SsSpacing.sm),
            SsCard(
              padding: const EdgeInsets.all(SsSpacing.md),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.speed_rounded,
                    size: 18,
                    color: SsColors.emerald600,
                  ),
                  const SizedBox(width: SsSpacing.sm),
                  Text(
                    l10n.summarySessionRpe,
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    formatRpe(summary.sessionRpe),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: SsColors.emerald700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: SsSpacing.xl),
          SsSectionHeader(
            title: l10n.summaryLifts,
            icon: Icons.fitness_center_rounded,
          ),
          for (final lift in summary.perLift)
            if (lift.setsCompleted > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                child: _LiftRow(lift: lift, unit: settings.unit),
              ),
          if (nextLoads.isNotEmpty) ...<Widget>[
            const SizedBox(height: SsSpacing.xl),
            SsSectionHeader(
              title: l10n.summaryNextTime,
              icon: Icons.trending_up_rounded,
            ),
            SsCard(
              child: Column(
                children: <Widget>[
                  for (final entry in nextLoads.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _exerciseName(program, entry.key),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            formatWeight(entry.value, settings.unit),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: SsColors.emerald700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (session.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: SsSpacing.xl),
            SsSectionHeader(
              title: l10n.summaryNotes,
              icon: Icons.notes_rounded,
            ),
            SsCard(
              child: Text(session.notes, style: theme.textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: SsSpacing.section),
          FilledButton.icon(
            onPressed: () {
              ref.read(sessionControllerProvider.notifier).clear();
              context.go('/');
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.summarySave),
          ),
        ],
      ),
    );
  }

  static List<PersonalRecord> _newPrs(Session session, List<Session> history) {
    final previous = RecordsCalculator.personalRecords(
      history.where((other) => other.id != session.id),
    );
    final current = RecordsCalculator.personalRecords(<Session>[session]);
    final result = <PersonalRecord>[];
    for (final record in current) {
      final previousBest = previous
          .where((old) => old.exerciseId == record.exerciseId)
          .toList(growable: false);
      if (previousBest.isEmpty || record.e1rmKg > previousBest.first.e1rmKg) {
        result.add(record);
      }
    }
    return result;
  }

  static String _exerciseName(TrainingProgram program, String exerciseId) {
    for (final day in program.days) {
      final exercise = day.exerciseById(exerciseId);
      if (exercise != null) {
        return exercise.name;
      }
    }
    return exerciseId;
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.lift, required this.unit});

  final LiftSummary lift;
  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SsCard(
      padding: const EdgeInsets.all(SsSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SsColors.emerald50,
              borderRadius: BorderRadius.circular(SsSpacing.radiusSm),
            ),
            child: Center(
              child: Text(
                '${lift.topSetReps}×',
                style: const TextStyle(
                  color: SsColors.emerald700,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(lift.exercise, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  lift.e1rmKg > 0
                      ? '${lift.setsCompleted}/${lift.setsPlanned} ${AppLocalizations.of(context).setsLabel} · '
                            '${AppLocalizations.of(context).historyE1rm} '
                            '${formatWeightValue(lift.e1rmKg, unit)} ${unit.wire}'
                      : '${lift.setsCompleted}/${lift.setsPlanned} ${AppLocalizations.of(context).setsLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (lift.missedSets > 0)
            Padding(
              padding: const EdgeInsets.only(right: SsSpacing.sm),
              child: SsPill(
                label: '${lift.missedSets}',
                color: SsColors.orange800,
                background: SsColors.orange100,
                icon: Icons.flag_outlined,
              ),
            ),
          Text(
            lift.topSetKg > 0 ? formatWeight(lift.topSetKg, unit) : '—',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds a display day for a session whose program day no longer exists
/// (for example after switching templates). The set data stays accurate even
/// when the original exercise names are gone.
ProgramDay _dayForSession(Session session, TrainingProgram program) {
  final day = program.dayById(session.dayId);
  if (day != null) {
    return day;
  }
  final byExercise = <String, List<SetLog>>{};
  for (final log in session.setLogs) {
    byExercise.putIfAbsent(log.exerciseId, () => <SetLog>[]).add(log);
  }
  return ProgramDay(
    id: session.dayId,
    title: session.dayId,
    focus: '',
    exercises: <ProgramExercise>[
      for (final entry in byExercise.entries)
        ProgramExercise(
          id: entry.key,
          name: entry.key,
          role: ExerciseRole.accessory,
          setTargets: <SetTarget>[
            for (final log in entry.value)
              SetTarget(reps: log.targetReps, loadKg: log.targetLoadKg),
          ],
        ),
    ],
  );
}
