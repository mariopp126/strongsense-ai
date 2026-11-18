import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import 'set_targets_dialog.dart';

class ProgramScreen extends ConsumerStatefulWidget {
  const ProgramScreen({super.key});

  @override
  ConsumerState<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends ConsumerState<ProgramScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.programTitle),
        actions: <Widget>[
          IconButton(
            tooltip: _editing ? 'Done' : 'Edit',
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.section,
        ),
        children: <Widget>[
          if (!_editing)
            SsBanner(
              message: l10n.programReadOnly,
              color: SsColors.blue800,
              background: SsColors.blue100,
              icon: Icons.info_outline_rounded,
            ),
          if (!_editing) const SizedBox(height: SsSpacing.lg),
          for (final day in program.days) ...<Widget>[
            SsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _editing
                            ? TextFormField(
                                initialValue: day.title,
                                decoration: const InputDecoration(
                                  labelText: 'Day title',
                                ),
                                onFieldSubmitted: (value) =>
                                    _renameDay(day, value),
                              )
                            : Text(
                                l10n.dayTitle(day.id, day.title),
                                style: theme.textTheme.titleLarge,
                              ),
                      ),
                      if (!_editing)
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
                            child: _editing
                                ? TextFormField(
                                    initialValue: exercise.name,
                                    decoration: const InputDecoration(
                                      labelText: 'Exercise',
                                    ),
                                    onFieldSubmitted: (value) =>
                                        _renameExercise(day, exercise, value),
                                  )
                                : Text(
                                    exercise.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: SsSpacing.sm),
                          Text(
                            _setsLabel(exercise, settings.unit),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_editing) ...<Widget>[
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              onPressed: () => _editSets(day, exercise),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              onPressed: () => _removeExercise(day, exercise),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_editing)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _addExercise(day),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add exercise'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SsSpacing.lg),
          ],
          if (_editing)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save program'),
            ),
        ],
      ),
    );
  }

  Future<void> _renameDay(ProgramDay day, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == day.title) return;
    final program = ref.read(programControllerProvider);
    final newDays = program.days
        .map((d) {
          if (d.id != day.id) return d;
          return d.copyWith(title: trimmed);
        })
        .toList(growable: false);
    await ref
        .read(programControllerProvider.notifier)
        .save(program.copyWith(days: newDays));
  }

  Future<void> _renameExercise(
    ProgramDay day,
    ProgramExercise exercise,
    String value,
  ) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == exercise.name) return;
    final program = ref.read(programControllerProvider);
    final newDays = program.days
        .map((d) {
          if (d.id != day.id) return d;
          final newExercises = d.exercises
              .map((e) {
                if (e.id != exercise.id) return e;
                return e.copyWith(name: trimmed);
              })
              .toList(growable: false);
          return d.copyWith(exercises: newExercises);
        })
        .toList(growable: false);
    await ref
        .read(programControllerProvider.notifier)
        .save(program.copyWith(days: newDays));
  }

  Future<void> _removeExercise(ProgramDay day, ProgramExercise exercise) async {
    final program = ref.read(programControllerProvider);
    final newDays = program.days
        .map((d) {
          if (d.id != day.id) return d;
          return d.copyWith(
            exercises: d.exercises
                .where((e) => e.id != exercise.id)
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    await ref
        .read(programControllerProvider.notifier)
        .save(program.copyWith(days: newDays));
  }

  Future<void> _addExercise(ProgramDay day) async {
    final program = ref.read(programControllerProvider);
    final newId = 'ex-${day.id}-${DateTime.now().millisecondsSinceEpoch}';
    final newExercise = ProgramExercise(
      id: newId,
      name: 'New exercise',
      role: ExerciseRole.accessory,
      setTargets: const <SetTarget>[SetTarget(reps: 10, loadKg: null)],
    );
    final newDays = program.days
        .map((d) {
          if (d.id != day.id) return d;
          return d.copyWith(
            exercises: <ProgramExercise>[...d.exercises, newExercise],
          );
        })
        .toList(growable: false);
    await ref
        .read(programControllerProvider.notifier)
        .save(program.copyWith(days: newDays));
  }

  Future<void> _editSets(ProgramDay day, ProgramExercise exercise) async {
    final settings = ref.read(settingsControllerProvider);
    final newTargets = await showSetTargetsDialog(
      context: context,
      exerciseName: exercise.name,
      targets: exercise.setTargets,
      unit: settings.unit,
    );
    if (newTargets == null) return;
    final program = ref.read(programControllerProvider);
    final newDays = program.days
        .map((d) {
          if (d.id != day.id) return d;
          final newExercises = d.exercises
              .map((e) {
                if (e.id != exercise.id) return e;
                return e.copyWith(setTargets: newTargets);
              })
              .toList(growable: false);
          return d.copyWith(exercises: newExercises);
        })
        .toList(growable: false);
    await ref
        .read(programControllerProvider.notifier)
        .save(program.copyWith(days: newDays));
  }

  Future<void> _save() async {
    if (mounted) setState(() => _editing = false);
  }

  static String _setsLabel(ProgramExercise exercise, Unit unit) {
    if (exercise.setTargets.isEmpty) {
      return '—';
    }
    final first = exercise.setTargets.first;
    final uniform = exercise.setTargets.every(
      (target) =>
          target.reps == first.reps &&
          target.repsMax == first.repsMax &&
          target.loadKg == first.loadKg,
    );
    final load = first.loadKg == null
        ? ''
        : ' · ${formatWeight(first.loadKg, unit)}';
    if (!uniform) {
      return '${exercise.setTargets.length} × …';
    }
    return '${exercise.setTargets.length} × ${first.repsLabel}$load';
  }
}
