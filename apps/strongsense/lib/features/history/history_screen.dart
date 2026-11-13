import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.historyTitle),
          bottom: TabBar(
            labelColor: SsColors.emerald400,
            unselectedLabelColor: SsColors.slate400,
            indicatorColor: SsColors.emerald400,
            tabs: <Widget>[
              Tab(text: l10n.historySessionsTab),
              Tab(text: l10n.historyProgressTab),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_SessionsTab(), _ProgressTab()],
        ),
      ),
    );
  }
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(historyProvider);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final localeCode = Localizations.localeOf(context).languageCode;

    return history.when(
      loading: () => SsLoading(label: l10n.loading),
      error: (error, stack) => SsEmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n.errorGeneric,
        action: FilledButton(
          onPressed: () => ref.invalidate(historyProvider),
          child: Text(l10n.retry),
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: SsEmptyState(
              icon: Icons.history_rounded,
              title: l10n.historyEmpty,
              body: l10n.historyEmptyBody,
              action: FilledButton(
                onPressed: () => context.push('/checkin'),
                child: Text(l10n.homeStartCheckIn),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(SsSpacing.lg),
          itemCount: sessions.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: SsSpacing.md),
          itemBuilder: (context, index) {
            final session = sessions[index];
            final day = program.dayById(session.dayId);
            return SsCard(
              onTap: () => context.go('/history/${session.id}'),
              padding: const EdgeInsets.all(SsSpacing.lg),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SsColors.emerald50,
                      borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        '${session.date.day}',
                        style: const TextStyle(
                          color: SsColors.emerald700,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.dayTitle(
                            session.dayId,
                            day?.title ?? session.dayId,
                          ),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDateShort(session.date, localeCode)} · '
                          '${l10n.historySets(session.completedSetCount, session.plannedSetCount)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        formatVolume(session.totalVolumeKg, settings.unit),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (session.missedSets.isNotEmpty)
                        Text(
                          '${session.missedSets.length} ${l10n.historyMissedSets}',
                          style: const TextStyle(
                            color: SsColors.orange800,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: SsSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: SsColors.slate400,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProgressTab extends ConsumerStatefulWidget {
  const _ProgressTab();

  @override
  ConsumerState<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<_ProgressTab> {
  String? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final sessions =
        ref.watch(historyProvider).valueOrNull ?? const <Session>[];

    final mainLifts = <ProgramExercise>[
      for (final day in program.days) ...day.mainExercises,
    ];
    if (mainLifts.isEmpty) {
      return Center(
        child: SsEmptyState(
          icon: Icons.show_chart_rounded,
          title: l10n.historyNoData,
        ),
      );
    }

    final selectedId = _exerciseId ?? mainLifts.first.id;
    final points = _e1rmPoints(sessions, selectedId);
    final volumeSessions = sessions.reversed.take(8).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        Wrap(
          spacing: SsSpacing.sm,
          runSpacing: SsSpacing.sm,
          children: <Widget>[
            for (final lift in mainLifts)
              ChoiceChip(
                label: Text(lift.name),
                selected: lift.id == selectedId,
                onSelected: (_) => setState(() => _exerciseId = lift.id),
              ),
          ],
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.historyE1rm,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    settings.unit.wire,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.md),
              SizedBox(
                height: 220,
                child: points.length < 2
                    ? Center(
                        child: Text(
                          l10n.historyNoData,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _E1rmChart(
                        points: points,
                        unit: settings.unit,
                        localeCode: Localizations.localeOf(
                          context,
                        ).languageCode,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.historyVolume, style: theme.textTheme.titleSmall),
              const SizedBox(height: SsSpacing.md),
              SizedBox(
                height: 180,
                child: volumeSessions.isEmpty
                    ? Center(
                        child: Text(
                          l10n.historyNoData,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 26,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 ||
                                      index >= volumeSessions.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      formatDateShort(
                                        volumeSessions[index].date,
                                        Localizations.localeOf(
                                          context,
                                        ).languageCode,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontSize: 9),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barTouchData: const BarTouchData(enabled: false),
                          barGroups: <BarChartGroupData>[
                            for (
                              var index = 0;
                              index < volumeSessions.length;
                              index++
                            )
                              BarChartGroupData(
                                x: index,
                                barRods: <BarChartRodData>[
                                  BarChartRodData(
                                    toY: toDisplayWeight(
                                      volumeSessions[index].totalVolumeKg,
                                      settings.unit,
                                    ),
                                    color: SsColors.emerald500,
                                    width: 18,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<(DateTime, double)> _e1rmPoints(
    List<Session> sessions,
    String exerciseId,
  ) {
    final points = <(DateTime, double)>[];
    for (final session in sessions.reversed) {
      var best = 0.0;
      for (final log in session.setLogs) {
        if (log.exerciseId != exerciseId ||
            !log.completed ||
            log.skipped ||
            (log.loadKg ?? 0) <= 0 ||
            (log.reps ?? 0) <= 0) {
          continue;
        }
        final estimate = E1rm.epley(log.loadKg!, log.reps!);
        if (estimate > best) {
          best = estimate;
        }
      }
      if (best > 0) {
        points.add((session.date, best));
      }
    }
    return points;
  }
}

class _E1rmChart extends StatelessWidget {
  const _E1rmChart({
    required this.points,
    required this.unit,
    required this.localeCode,
  });

  final List<(DateTime, double)> points;
  final Unit unit;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((point) => point.$2).toList(growable: false);
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final padding = math.max((maxValue - minValue) * 0.25, 2.5);
    final interval = points.length <= 4
        ? 1.0
        : (points.length / 4).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: math.max(0, minValue - padding),
        maxY: maxValue + padding,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                formatWeightValue(toCanonicalWeight(value, unit), unit),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    formatDateShort(points[index].$1, localeCode),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${formatWeightValue(toCanonicalWeight(spot.y, unit), unit)} ${unit.wire}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (var index = 0; index < points.length; index++)
                FlSpot(
                  index.toDouble(),
                  toDisplayWeight(points[index].$2, unit),
                ),
            ],
            isCurved: true,
            color: SsColors.emerald500,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: SsColors.emerald500.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
