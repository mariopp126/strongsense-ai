import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.programTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.section,
        ),
        children: <Widget>[
          SsBanner(
            message: l10n.programReadOnly,
            color: SsColors.blue800,
            background: SsColors.blue100,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: SsSpacing.lg),
          for (final day in program.days) ...<Widget>[
            SsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.dayTitle(day.id, day.title),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      SsPill(
                        label: dayFocusLabel(
                          day.focus,
                          Localizations.localeOf(context).languageCode,
                        ),
                        color: SsColors.slate700,
                        background: SsColors.slate100,
                      ),
                    ],
                  ),
                  const SizedBox(height: SsSpacing.md),
                  for (final exercise in day.exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: exercise.role == ExerciseRole.main
                                  ? SsColors.emerald500
                                  : SsColors.slate300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: SsSpacing.sm),
                          Expanded(
                            child: Text(
                              exercise.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _setsLabel(exercise, settings.unit),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SsSpacing.lg),
          ],
        ],
      ),
    );
  }

  static String _setsLabel(ProgramExercise exercise, Unit unit) {
    if (exercise.setTargets.isEmpty) {
      return '—';
    }
    final first = exercise.setTargets.first;
    final load = first.loadKg == null
        ? ''
        : ' · ${formatWeight(first.loadKg, unit)}';
    return '${exercise.setTargets.length} × ${first.repsLabel}$load';
  }
}
