import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final localeCode = Localizations.localeOf(context).languageCode;

    return FutureBuilder<Session?>(
      future: ref.watch(sessionRepositoryProvider).byId(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.historyTitle)),
            body: SsLoading(label: l10n.loading),
          );
        }
        final session = snapshot.data;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.historyTitle)),
            body: SsEmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.errorGeneric,
            ),
          );
        }

        final day = program.dayById(session.dayId) ?? program.days.first;
        final summary = SessionSummaryCalculator.summarize(
          session: session,
          day: day,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(formatDateShort(session.date, localeCode)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              SsSpacing.lg,
              SsSpacing.lg,
              SsSpacing.lg,
              SsSpacing.section,
            ),
            children: <Widget>[
              SsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.dayTitle(day.id, day.title),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateLong(session.date, localeCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SsStatTile(
                            value: formatVolume(
                              summary.totalVolumeKg,
                              settings.unit,
                            ),
                            label: l10n.summaryVolume,
                          ),
                        ),
                        const SizedBox(width: SsSpacing.sm),
                        Expanded(
                          child: SsStatTile(
                            value:
                                '${summary.setsCompleted}/${summary.setsPlanned}',
                            label: l10n.summarySets,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SsSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: SsStatTile(
                            value: formatDuration(summary.durationMin),
                            label: l10n.summaryDuration,
                          ),
                        ),
                        const SizedBox(width: SsSpacing.sm),
                        Expanded(
                          child: SsStatTile(
                            value: '${summary.missedSets}',
                            label: l10n.summaryMissed,
                            accent: summary.missedSets > 0
                                ? SsColors.orange500
                                : SsColors.emerald600,
                          ),
                        ),
                      ],
                    ),
                    if (session.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: SsSpacing.md),
                      Text(
                        session.notes,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SsSpacing.xl),
              SsSectionHeader(
                title: l10n.planTitle,
                icon: Icons.fitness_center_rounded,
              ),
              for (final lift in summary.perLift)
                if (lift.setsCompleted > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                    child: SsCard(
                      padding: const EdgeInsets.all(SsSpacing.md),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  lift.exercise,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lift.e1rmKg > 0
                                      ? '${lift.setsCompleted}/${lift.setsPlanned} ${l10n.setsLabel} · '
                                            '${formatWeightValue(lift.e1rmKg, settings.unit)} ${settings.unit.wire} ${l10n.historyE1rm}'
                                      : '${lift.setsCompleted}/${lift.setsPlanned} ${l10n.setsLabel}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (lift.missedSets > 0)
                            SsPill(
                              label: '${lift.missedSets}',
                              color: SsColors.orange800,
                              background: SsColors.orange100,
                              icon: Icons.flag_outlined,
                            ),
                          const SizedBox(width: SsSpacing.sm),
                          Text(
                            lift.topSetKg > 0
                                ? formatWeight(lift.topSetKg, settings.unit)
                                : '—',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
