import 'package:flutter/material.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../l10n/app_localizations.dart';
import '../theme/ss_colors.dart';
import '../utils/formatters.dart';
import 'ss_card.dart';
import 'ss_progress.dart';

/// Readiness hero with score, band and (optionally) component bars.
class SsReadinessCard extends StatelessWidget {
  const SsReadinessCard({
    super.key,
    required this.readiness,
    this.showComponents = true,
  });

  final ReadinessReport readiness;
  final bool showComponents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = readinessText(readiness.band);
    final background = readinessBackground(readiness.band);

    return Container(
      padding: const EdgeInsets.all(SsSpacing.xl),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SsSpacing.radiusLg),
        border: Border.all(
          color: readinessColor(readiness.band).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${readiness.score}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: color,
                  fontSize: 44,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/100',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              SsBandChip(band: readiness.band),
            ],
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            l10n.bandAdvice(readiness.band.wire),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (showComponents) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            for (final entry in readiness.components.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 128,
                      child: Text(
                        l10n.componentLabel(entry.key),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          SsSpacing.radiusFull,
                        ),
                        child: LinearProgressIndicator(
                          value: (entry.value / 100).clamp(0, 1),
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.55),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.value >= 60
                                ? SsColors.emerald500
                                : SsColors.amber500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SsSpacing.sm),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${entry.value.round()}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Renders a coach plan (rules or AI) consistently across screens.
class CoachPlanView extends StatelessWidget {
  const CoachPlanView({
    super.key,
    required this.plan,
    required this.readiness,
    this.aiLoading = false,
    this.aiNotice,
    this.aiModel = '',
    this.onRegenerate,
    this.showReadinessCard = false,
  });

  final CoachPlan plan;
  final ReadinessReport? readiness;
  final bool aiLoading;
  final String? aiNotice;
  final String aiModel;
  final VoidCallback? onRegenerate;
  final bool showReadinessCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showReadinessCard && readiness != null) ...<Widget>[
          SsReadinessCard(readiness: readiness!),
          const SizedBox(height: SsSpacing.lg),
        ],
        Row(
          children: <Widget>[
            _SourcePill(plan: plan, model: aiModel),
            if (plan.deload) ...<Widget>[
              const SizedBox(width: SsSpacing.sm),
              SsPill(
                label: l10n.planDeload,
                color: SsColors.orange800,
                background: SsColors.orange100,
                icon: Icons.battery_charging_full_rounded,
              ),
            ],
            const Spacer(),
            if (onRegenerate != null)
              IconButton(
                tooltip: l10n.planRegenerate,
                onPressed: aiLoading ? null : onRegenerate,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        if (aiLoading) ...<Widget>[
          const SizedBox(height: SsSpacing.sm),
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: SsSpacing.sm),
          Text(
            l10n.planAiThinking,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (aiNotice != null) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsBanner(
            message: aiNotice!,
            color: SsColors.amber800,
            background: SsColors.amber100,
            icon: Icons.cloud_off_rounded,
          ),
        ],
        const SizedBox(height: SsSpacing.lg),
        Text(plan.summary, style: theme.textTheme.bodyLarge),
        const SizedBox(height: SsSpacing.sm),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(l10n.readinessWhy, style: theme.textTheme.titleSmall),
              leading: const Icon(
                Icons.psychology_alt_outlined,
                color: SsColors.emerald600,
                size: 20,
              ),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    plan.readinessExplanation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
              ],
            ),
          ),
        ),
        if (plan.adjustments.isNotEmpty) ...<Widget>[
          const SizedBox(height: SsSpacing.sm),
          SsSectionHeader(
            title: l10n.planAdjustments,
            icon: Icons.tune_rounded,
          ),
          for (final adjustment in plan.adjustments)
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: _AdjustmentTile(adjustment: adjustment),
            ),
        ],
        if (plan.tips.isNotEmpty) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsSectionHeader(
            title: l10n.planTips,
            icon: Icons.lightbulb_outline_rounded,
          ),
          for (final tip in plan.tips)
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: _TipTile(tip: tip),
            ),
        ],
        if (plan.flags.isNotEmpty) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          _FlagsCard(flags: plan.flags),
        ],
        const SizedBox(height: SsSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.health_and_safety_outlined,
                size: 14,
                color: SsColors.slate400,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.planDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.plan, required this.model});

  final CoachPlan plan;
  final String model;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (plan.source) {
      case CoachSource.llm:
        return SsPill(
          label: model.isEmpty
              ? l10n.planSourceAi
              : '${l10n.planSourceAi} · $model',
          color: SsColors.blue800,
          background: SsColors.blue100,
          icon: Icons.auto_awesome_rounded,
        );
      case CoachSource.rulesFallback:
        return SsPill(
          label: l10n.planSourceFallback,
          color: SsColors.amber800,
          background: SsColors.amber100,
          icon: Icons.cloud_off_rounded,
        );
      case CoachSource.rules:
        return SsPill(
          label: l10n.planSourceRules,
          color: SsColors.slate700,
          background: SsColors.slate100,
          icon: Icons.offline_bolt_rounded,
        );
    }
  }
}

class _AdjustmentTile extends StatelessWidget {
  const _AdjustmentTile({required this.adjustment});

  final Adjustment adjustment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(SsSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  adjustment.exercise,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (adjustment.loadDeltaPct != 0)
                Padding(
                  padding: const EdgeInsets.only(left: SsSpacing.xs),
                  child: SsPill(
                    label: l10n.signedPercent(adjustment.loadDeltaPct),
                    color: adjustment.loadDeltaPct > 0
                        ? SsColors.emerald800
                        : SsColors.orange800,
                    background: adjustment.loadDeltaPct > 0
                        ? SsColors.emerald100
                        : SsColors.orange100,
                  ),
                ),
              if (adjustment.setsDelta != 0)
                Padding(
                  padding: const EdgeInsets.only(left: SsSpacing.xs),
                  child: SsPill(
                    label: l10n.signedSets(adjustment.setsDelta),
                    color: adjustment.setsDelta > 0
                        ? SsColors.blue800
                        : SsColors.slate700,
                    background: adjustment.setsDelta > 0
                        ? SsColors.blue100
                        : SsColors.slate100,
                  ),
                ),
            ],
          ),
          if (adjustment.substituteWith != null) ...<Widget>[
            const SizedBox(height: SsSpacing.xs),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: SsColors.orange500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    adjustment.substituteWith!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SsColors.orange800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            adjustment.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({required this.tip});

  final CoachTip tip;

  IconData get _icon {
    switch (tip.category) {
      case TipCategory.technique:
        return Icons.sports_gymnastics_rounded;
      case TipCategory.recovery:
        return Icons.bedtime_outlined;
      case TipCategory.nutrition:
        return Icons.restaurant_rounded;
      case TipCategory.programming:
        return Icons.event_repeat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(SsSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: SsColors.emerald50,
              borderRadius: BorderRadius.circular(SsSpacing.radiusSm),
            ),
            child: Icon(_icon, size: 17, color: SsColors.emerald700),
          ),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(tip.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  tip.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagsCard extends StatelessWidget {
  const _FlagsCard({required this.flags});

  final List<String> flags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SsSpacing.md),
      decoration: BoxDecoration(
        color: SsColors.amber100,
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
        border: Border.all(color: SsColors.amber500.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: SsColors.amber800,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).planFlags,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: SsColors.amber800,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.xs),
          for (final flag in flags)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $flag',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: SsColors.amber800,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
