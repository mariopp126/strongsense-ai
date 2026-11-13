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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final program = ref.watch(programControllerProvider);
    final day = ref.watch(nextDayProvider);
    final history = ref.watch(historyProvider);
    final stats = ref.watch(weeklyStatsProvider);
    final records = ref.watch(personalRecordsProvider);
    final activeSession = ref.watch(sessionControllerProvider);
    final hasActive = ref.watch(hasActiveSessionProvider);
    final latestPlan = ref.watch(latestCoachPlanProvider).valueOrNull;
    final sessions = history.valueOrNull ?? const <Session>[];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const Icon(
              Icons.fitness_center_rounded,
              color: SsColors.emerald400,
              size: 22,
            ),
            const SizedBox(width: SsSpacing.sm),
            Text(l10n.appName),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(historyProvider);
          ref.invalidate(latestCoachPlanProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            SsSpacing.lg,
            SsSpacing.lg,
            SsSpacing.lg,
            SsSpacing.section,
          ),
          children: <Widget>[
            _HeroCard(
              name: settings.userName,
              day: day,
              onStart: () => context.push('/checkin?day=${day.id}'),
            ),
            if (hasActive && activeSession != null) ...<Widget>[
              const SizedBox(height: SsSpacing.md),
              SsCard(
                borderColor: SsColors.amber500,
                color: SsColors.amber100,
                onTap: () => context.go('/workout/${activeSession.id}'),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: SsColors.amber800,
                      size: 28,
                    ),
                    const SizedBox(width: SsSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.homeResume,
                            style: const TextStyle(
                              color: SsColors.amber800,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l10n.homeResumeBody,
                            style: const TextStyle(
                              color: SsColors.amber800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SsColors.amber800,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: SsSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: SsStatTile(
                    value: l10n.sessionsCount(stats.sessions),
                    label: l10n.thisWeek,
                    icon: Icons.event_available_rounded,
                  ),
                ),
                const SizedBox(width: SsSpacing.sm),
                Expanded(
                  child: SsStatTile(
                    value: formatVolume(stats.volumeKg, settings.unit),
                    label: l10n.homeWeeklyVolume,
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
                const SizedBox(width: SsSpacing.sm),
                Expanded(
                  child: SsStatTile(
                    value: '${records.length}',
                    label: l10n.homePRs,
                    icon: Icons.emoji_events_outlined,
                    accent: SsColors.amber500,
                  ),
                ),
              ],
            ),
            if (latestPlan != null) ...<Widget>[
              const SizedBox(height: SsSpacing.xl),
              SsSectionHeader(
                title: l10n.navCoach,
                icon: Icons.auto_awesome_rounded,
                actionLabel: l10n.homeViewAll,
                onAction: () => context.go('/coach'),
              ),
              _CoachTeaser(
                plan: latestPlan.plan,
                onTap: () => context.go('/coach'),
              ),
            ],
            const SizedBox(height: SsSpacing.xl),
            SsSectionHeader(
              title: l10n.homeRecent,
              icon: Icons.history_rounded,
              actionLabel: sessions.isEmpty ? null : l10n.homeViewAll,
              onAction: sessions.isEmpty ? null : () => context.go('/history'),
            ),
            if (history.isLoading && sessions.isEmpty)
              const SsLoading()
            else if (sessions.isEmpty)
              SsCard(
                child: SsEmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: l10n.homeNoSessions,
                  action: FilledButton(
                    onPressed: () => context.push('/checkin?day=${day.id}'),
                    child: Text(l10n.homeStartCheckIn),
                  ),
                ),
              )
            else
              _RecentSessions(
                sessions: sessions.take(3).toList(growable: false),
                program: program,
                unit: settings.unit,
                onTap: (session) => context.go('/history/${session.id}'),
              ),
            if (records.isNotEmpty) ...<Widget>[
              const SizedBox(height: SsSpacing.xl),
              SsSectionHeader(
                title: l10n.homePRs,
                icon: Icons.emoji_events_rounded,
              ),
              _RecordsCard(
                records: records.take(3).toList(growable: false),
                program: program,
                unit: settings.unit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.day,
    required this.onStart,
  });

  final String name;
  final ProgramDay day;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(SsSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[SsColors.slate900, SsColors.slate800],
        ),
        borderRadius: BorderRadius.circular(SsSpacing.radiusXl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: SsColors.slate900.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.greeting(name),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                  ),
                ),
              ),
              const Icon(
                Icons.fitness_center_rounded,
                color: SsColors.emerald400,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(
            l10n.homeSubtitle,
            style: const TextStyle(
              color: SsColors.slate400,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: SsSpacing.xl),
          Container(
            padding: const EdgeInsets.all(SsSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SsColors.emerald500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(SsSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.today_rounded,
                    color: SsColors.emerald400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: SsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.homeToday,
                        style: const TextStyle(
                          color: SsColors.emerald400,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dayTitle(day.id, day.title),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.bolt_rounded),
            label: Text(l10n.homeStartCheckIn),
          ),
        ],
      ),
    );
  }
}

class _CoachTeaser extends StatelessWidget {
  const _CoachTeaser({required this.plan, required this.onTap});

  final CoachPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tip = plan.tips.isEmpty ? null : plan.tips.first;

    return SsCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SsPill(
                label: plan.source == CoachSource.llm
                    ? AppLocalizations.of(context).planSourceAi
                    : AppLocalizations.of(context).planSourceRules,
                color: plan.source == CoachSource.llm
                    ? SsColors.blue800
                    : SsColors.slate700,
                background: plan.source == CoachSource.llm
                    ? SsColors.blue100
                    : SsColors.slate100,
                icon: plan.source == CoachSource.llm
                    ? Icons.auto_awesome_rounded
                    : Icons.offline_bolt_rounded,
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: SsColors.slate400),
            ],
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(tip?.title ?? plan.summary, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            tip?.body ?? plan.readinessExplanation,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSessions extends StatelessWidget {
  const _RecentSessions({
    required this.sessions,
    required this.program,
    required this.unit,
    required this.onTap,
  });

  final List<Session> sessions;
  final TrainingProgram program;
  final Unit unit;
  final ValueChanged<Session> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var index = 0; index < sessions.length; index++) ...<Widget>[
            InkWell(
              onTap: () => onTap(sessions[index]),
              child: Padding(
                padding: const EdgeInsets.all(SsSpacing.lg),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: SsColors.emerald50,
                        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: SsColors.emerald700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: SsSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.dayTitle(
                              sessions[index].dayId,
                              program.dayById(sessions[index].dayId)?.title ??
                                  sessions[index].dayId,
                            ),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDateShort(sessions[index].date, Localizations.localeOf(context).languageCode)} · '
                            '${l10n.historySets(sessions[index].completedSetCount, sessions[index].plannedSetCount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          formatVolume(sessions[index].totalVolumeKg, unit),
                          style: theme.textTheme.labelLarge,
                        ),
                        if (sessions[index].missedSets.isNotEmpty)
                          Text(
                            '${sessions[index].missedSets.length} ${l10n.historyMissedSets}',
                            style: const TextStyle(
                              color: SsColors.orange800,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SsColors.slate400,
                    ),
                  ],
                ),
              ),
            ),
            if (index != sessions.length - 1)
              const Divider(
                height: 1,
                indent: SsSpacing.lg,
                endIndent: SsSpacing.lg,
              ),
          ],
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({
    required this.records,
    required this.program,
    required this.unit,
  });

  final List<PersonalRecord> records;
  final TrainingProgram program;
  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var index = 0; index < records.length; index++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.all(SsSpacing.lg),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: SsColors.amber500,
                    size: 20,
                  ),
                  const SizedBox(width: SsSpacing.md),
                  Expanded(
                    child: Text(
                      _exerciseName(program, records[index].exerciseId),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${formatWeightValue(records[index].e1rmKg, unit)} ${unit.wire}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: SsColors.emerald700,
                        ),
                      ),
                      Text(
                        l10n.historyE1rm,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (index != records.length - 1)
              const Divider(
                height: 1,
                indent: SsSpacing.lg,
                endIndent: SsSpacing.lg,
              ),
          ],
        ],
      ),
    );
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
