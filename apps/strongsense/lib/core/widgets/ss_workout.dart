import 'package:flutter/material.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../l10n/app_localizations.dart';
import '../theme/ss_colors.dart';
import '../utils/formatters.dart';
import 'ss_card.dart';

/// Segmented day selector from the reference design.
class SsDaySelector extends StatelessWidget {
  const SsDaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ProgramDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: index == selectedIndex
                        ? scheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(SsSpacing.radiusSm),
                    boxShadow: index == selectedIndex
                        ? <BoxShadow>[
                            BoxShadow(
                              color: SsColors.slate900.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    l10n.dayShort(days[index].id),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: index == selectedIndex
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tappable set row. Tap toggles completion, long press opens the editor.
class SsSetRow extends StatelessWidget {
  const SsSetRow({
    super.key,
    required this.log,
    required this.unit,
    required this.onToggle,
    required this.onEdit,
  });

  final SetLog log;
  final Unit unit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final checked = log.completed && !log.skipped;
    final skipped = log.skipped;

    final borderColor = checked
        ? SsColors.emerald500
        : skipped
        ? SsColors.amber500
        : scheme.outlineVariant;
    final background = checked
        ? SsColors.emerald50
        : skipped
        ? SsColors.amber100
        : scheme.surfaceContainerLow;
    final labelColor = checked ? SsColors.emerald700 : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
          onTap: onToggle,
          onLongPress: onEdit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: checked || skipped ? borderColor : scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: checked || skipped ? borderColor : scheme.outline,
                      width: 2,
                    ),
                  ),
                  child: checked || skipped
                      ? Icon(
                          skipped
                              ? Icons.fast_forward_rounded
                              : Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: SsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.setNumber(log.setIndex + 1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${log.reps ?? log.targetReps} ${l10n.workoutReps}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: checked
                              ? SsColors.emerald800
                              : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (log.rpe != null)
                        Text(
                          'RPE ${formatRpe(log.rpe)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (log.loadKg != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SsSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: checked ? SsColors.emerald200 : scheme.surface,
                      borderRadius: BorderRadius.circular(SsSpacing.radiusSm),
                      border: Border.all(
                        color: checked
                            ? SsColors.emerald300
                            : scheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      formatWeight(log.loadKg, unit),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: checked ? SsColors.emerald800 : scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: l10n.workoutEditSet,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: SsColors.slate400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Exercise card holding its set rows.
class SsExerciseCard extends StatelessWidget {
  const SsExerciseCard({
    super.key,
    required this.exercise,
    required this.logs,
    required this.unit,
    required this.onToggle,
    required this.onEdit,
    this.rpeCap,
    this.substitutedFor,
  });

  final ProgramExercise exercise;
  final List<SetLog> logs;
  final Unit unit;
  final void Function(SetLog log) onToggle;
  final void Function(SetLog log) onEdit;
  final double? rpeCap;
  final String? substitutedFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final first = logs.isEmpty ? null : logs.first;
    final repsLabel = first == null
        ? ''
        : '${logs.length} × ${_repsRange(exercise.setTargets)}';
    final loadLabel = first == null ? null : formatWeight(first.loadKg, unit);

    return SsCard(
      padding: const EdgeInsets.all(SsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(exercise.name, style: theme.textTheme.titleLarge),
                    if (substitutedFor != null)
                      Text(
                        '${l10n.programVariation}: $substitutedFor',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SsColors.orange800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (repsLabel.isNotEmpty) repsLabel,
                        ?loadLabel,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  SsPill(
                    label: _roleLabel(l10n, exercise.role),
                    color: exercise.role == ExerciseRole.main
                        ? SsColors.emerald800
                        : SsColors.slate700,
                    background: exercise.role == ExerciseRole.main
                        ? SsColors.emerald100
                        : SsColors.slate100,
                  ),
                  if (rpeCap != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'RPE ≤ ${rpeCap!.toStringAsFixed(1)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          for (final log in logs)
            SsSetRow(
              log: log,
              unit: unit,
              onToggle: () => onToggle(log),
              onEdit: () => onEdit(log),
            ),
        ],
      ),
    );
  }

  static String _repsRange(List<SetTarget> targets) {
    if (targets.isEmpty) {
      return '—';
    }
    final first = targets.first;
    return first.repsLabel;
  }

  static String _roleLabel(AppLocalizations l10n, ExerciseRole role) {
    switch (role) {
      case ExerciseRole.main:
        return l10n.programMain;
      case ExerciseRole.variation:
        return l10n.programVariation;
      case ExerciseRole.accessory:
        return l10n.programAccessory;
    }
  }
}
