import 'dart:convert';

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
  TrainingProgram? _draft;

  TrainingProgram get _saved => ref.read(programControllerProvider);

  TrainingProgram get _current => _draft ?? _saved;

  bool get _isDirty {
    if (!_editing || _draft == null) {
      return false;
    }
    return jsonEncode(_draft!.toJson()) != jsonEncode(_saved.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saved = ref.watch(programControllerProvider);
    final program = _editing ? (_draft ?? saved) : saved;

    return PopScope<Object?>(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final discard = await _confirmDiscard();
        if (!discard || !context.mounted) {
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.programTitle),
          actions: <Widget>[
            if (!_editing)
              IconButton(
                key: const ValueKey<String>('program-edit'),
                tooltip: l10n.edit,
                icon: const Icon(Icons.edit_rounded),
                onPressed: _startEditing,
              ),
            if (_editing) ...<Widget>[
              IconButton(
                key: const ValueKey<String>('program-cancel'),
                tooltip: l10n.programDiscard,
                icon: const Icon(Icons.close_rounded),
                onPressed: _cancelEditing,
              ),
              IconButton(
                key: const ValueKey<String>('program-save'),
                tooltip: l10n.save,
                icon: const Icon(Icons.check_rounded),
                onPressed: _saveDraft,
              ),
            ],
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
            if (_editing) ...<Widget>[
              TextFormField(
                key: const ValueKey<String>('program-name'),
                initialValue: program.name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.programProgramName,
                  prefixIcon: const Icon(Icons.fitness_center_rounded),
                ),
                onChanged: _renameProgram,
              ),
              const SizedBox(height: SsSpacing.lg),
            ],
            for (
              var index = 0;
              index < program.days.length;
              index++
            ) ...<Widget>[
              _buildDay(
                context,
                l10n,
                theme,
                program,
                program.days[index],
                index,
              ),
              const SizedBox(height: SsSpacing.lg),
            ],
            if (_editing && program.days.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.lg),
                child: Text(l10n.programNoDays, textAlign: TextAlign.center),
              ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('program-add-day'),
                  onPressed: _addDay,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.programAddDay),
                ),
              ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('program-restore-default'),
                  onPressed: _restoreDefault,
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(l10n.programRestoreDefault),
                ),
              ),
            if (_editing)
              FilledButton.icon(
                key: const ValueKey<String>('program-save-bottom'),
                onPressed: _saveDraft,
                icon: const Icon(Icons.save_rounded),
                label: Text(l10n.programSave),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDay(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    TrainingProgram program,
    ProgramDay day,
    int index,
  ) {
    final settings = ref.watch(settingsControllerProvider);
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _editing
                    ? TextFormField(
                        key: ValueKey<String>('day-title-${day.id}'),
                        initialValue: day.title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n.programDayTitle,
                        ),
                        onChanged: (value) => _renameDay(day, value),
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
              if (_editing) ...<Widget>[
                IconButton(
                  key: ValueKey<String>('day-${day.id}-up'),
                  tooltip: l10n.programMoveUp,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed: index == 0 ? null : () => _moveDay(day, -1),
                ),
                IconButton(
                  key: ValueKey<String>('day-${day.id}-down'),
                  tooltip: l10n.programMoveDown,
                  icon: const Icon(Icons.arrow_downward_rounded),
                  onPressed: index == program.days.length - 1
                      ? null
                      : () => _moveDay(day, 1),
                ),
              ],
            ],
          ),
          if (_editing) ...<Widget>[
            const SizedBox(height: SsSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('day-${day.id}-focus'),
                    initialValue: day.focus,
                    decoration: InputDecoration(labelText: l10n.programFocus),
                    items: <DropdownMenuItem<String>>[
                      for (final focus in const <String>[
                        'lower',
                        'upper',
                        'full',
                      ])
                        DropdownMenuItem<String>(
                          value: focus,
                          child: Text(
                            dayFocusLabel(
                              focus,
                              Localizations.localeOf(context).languageCode,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _setDayFocus(day, value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: SsSpacing.sm),
                IconButton(
                  key: ValueKey<String>('day-${day.id}-duplicate'),
                  tooltip: l10n.programDuplicate,
                  icon: const Icon(Icons.copy_all_rounded),
                  onPressed: () => _duplicateDay(day),
                ),
                IconButton(
                  key: ValueKey<String>('day-${day.id}-delete'),
                  tooltip: l10n.programRemoveDay,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _removeDay(day),
                ),
              ],
            ),
            const SizedBox(height: SsSpacing.md),
          ] else
            const SizedBox(height: SsSpacing.md),
          for (final exercise in day.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: _buildExercise(
                context,
                l10n,
                theme,
                settings,
                day,
                exercise,
              ),
            ),
          if (_editing) ...<Widget>[
            if (day.mainExercises.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: SsColors.amber800,
                    ),
                    const SizedBox(width: SsSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.programNoMainLift,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SsColors.amber800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey<String>('day-${day.id}-add-exercise'),
                onPressed: () => _addExercise(day),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.programAddExercise),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExercise(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AppSettings settings,
    ProgramDay day,
    ProgramExercise exercise,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
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
                      key: ValueKey<String>('exercise-name-${exercise.id}'),
                      initialValue: exercise.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.programExerciseName,
                      ),
                      onChanged: (value) =>
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
            if (!_editing)
              Text(
                _setsLabel(exercise, settings.unit),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (_editing)
              IconButton(
                key: ValueKey<String>('exercise-${exercise.id}-sets'),
                tooltip: l10n.programEditSets,
                icon: const Icon(Icons.tune_rounded, size: 18),
                onPressed: () => _editSets(day, exercise),
              ),
          ],
        ),
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: <Widget>[
                DropdownButton<ExerciseRole>(
                  key: ValueKey<String>('exercise-${exercise.id}-role'),
                  value: exercise.role,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<ExerciseRole>>[
                    DropdownMenuItem<ExerciseRole>(
                      value: ExerciseRole.main,
                      child: Text(l10n.programMain),
                    ),
                    DropdownMenuItem<ExerciseRole>(
                      value: ExerciseRole.variation,
                      child: Text(l10n.programVariation),
                    ),
                    DropdownMenuItem<ExerciseRole>(
                      value: ExerciseRole.accessory,
                      child: Text(l10n.programAccessory),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _changeRole(day, exercise, value);
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey<String>('exercise-${exercise.id}-up'),
                  tooltip: l10n.programMoveUp,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  onPressed: () => _moveExercise(day, exercise, -1),
                ),
                IconButton(
                  key: ValueKey<String>('exercise-${exercise.id}-down'),
                  tooltip: l10n.programMoveDown,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  onPressed: () => _moveExercise(day, exercise, 1),
                ),
                IconButton(
                  key: ValueKey<String>('exercise-${exercise.id}-duplicate'),
                  tooltip: l10n.programDuplicate,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () => _duplicateExercise(day, exercise),
                ),
                IconButton(
                  key: ValueKey<String>('exercise-${exercise.id}-delete'),
                  tooltip: l10n.programRemoveExercise,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () => _removeExercise(day, exercise),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Draft lifecycle
  // -------------------------------------------------------------------------

  void _startEditing() {
    setState(() {
      _draft = _saved;
      _editing = true;
    });
  }

  Future<void> _cancelEditing() async {
    if (_isDirty) {
      final discard = await _confirmDiscard();
      if (!discard) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = false;
      _draft = null;
    });
  }

  Future<void> _saveDraft() async {
    final l10n = AppLocalizations.of(context);
    final draft = _draft;
    if (draft == null) {
      setState(() => _editing = false);
      return;
    }
    final error = _validate(draft, l10n);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    try {
      // Manual edits detach the program from its template so the next
      // progression step cannot silently overwrite them. Reselect the template
      // in Settings to reattach.
      await ref
          .read(programControllerProvider.notifier)
          .save(draft.copyWith(clearTemplate: true));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.programSaveFailed)));
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _editing = false;
      _draft = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.programSaved)));
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.programUnsavedTitle),
        content: Text(l10n.programUnsavedBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.programStay),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.programDiscard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String? _validate(TrainingProgram draft, AppLocalizations l10n) {
    if (draft.days.isEmpty) {
      return l10n.programValidationNoDays;
    }
    final dayIds = <String>{};
    final exerciseIds = <String>{};
    for (final day in draft.days) {
      if (day.title.trim().isEmpty) {
        return l10n.programValidationDayTitle;
      }
      if (!dayIds.add(day.id)) {
        return l10n.programValidationDuplicateId;
      }
      for (final exercise in day.exercises) {
        if (exercise.name.trim().isEmpty) {
          return l10n.programValidationExerciseName;
        }
        if (!exerciseIds.add(exercise.id)) {
          return l10n.programValidationDuplicateId;
        }
        for (final target in exercise.setTargets) {
          try {
            target.validate();
          } on ArgumentError {
            return l10n.programValidationExercise(exercise.name);
          }
        }
      }
    }
    return null;
  }

  void _updateDraft(TrainingProgram next) {
    setState(() => _draft = next);
  }

  // -------------------------------------------------------------------------
  // Program metadata
  // -------------------------------------------------------------------------

  void _renameProgram(String value) {
    final draft = _current;
    if (value == draft.name) {
      return;
    }
    _updateDraft(draft.copyWith(name: value));
  }

  // -------------------------------------------------------------------------
  // Days
  // -------------------------------------------------------------------------

  void _renameDay(ProgramDay day, String value) {
    if (value == day.title) {
      return;
    }
    _updateDraft(
      _mapDay(_current, day.id, (current) => current.copyWith(title: value)),
    );
  }

  void _setDayFocus(ProgramDay day, String focus) {
    if (focus == day.focus) {
      return;
    }
    _updateDraft(
      _mapDay(_current, day.id, (current) => current.copyWith(focus: focus)),
    );
  }

  void _addDay() {
    final l10n = AppLocalizations.of(context);
    final program = _current;
    final day = ProgramDay(
      id: _uniqueId('day', program.days.map((day) => day.id)),
      title: l10n.programNewDay,
      focus: 'full',
      exercises: const <ProgramExercise>[],
    );
    _updateDraft(program.copyWith(days: <ProgramDay>[...program.days, day]));
  }

  void _duplicateDay(ProgramDay day) {
    final l10n = AppLocalizations.of(context);
    final program = _current;
    final takenDayIds = program.days.map((current) => current.id).toSet();
    final copy = ProgramDay(
      id: _uniqueId('day', takenDayIds),
      title: l10n.programCopyOf(day.title),
      focus: day.focus,
      exercises: _copyExercises(program, day.exercises),
    );
    final index = program.days.indexWhere((current) => current.id == day.id);
    final days = List<ProgramDay>.of(program.days)..insert(index + 1, copy);
    _updateDraft(program.copyWith(days: days));
  }

  Future<void> _removeDay(ProgramDay day) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.programDeleteDayTitle,
      message: l10n.programDeleteDayConfirm(day.title),
    );
    if (!confirmed) {
      return;
    }
    final program = _current;
    _updateDraft(
      program.copyWith(
        days: program.days
            .where((current) => current.id != day.id)
            .toList(growable: false),
      ),
    );
  }

  void _moveDay(ProgramDay day, int delta) {
    final program = _current;
    final index = program.days.indexWhere((current) => current.id == day.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= program.days.length) {
      return;
    }
    final days = List<ProgramDay>.of(program.days);
    final moved = days.removeAt(index);
    days.insert(target, moved);
    _updateDraft(program.copyWith(days: days));
  }

  Future<void> _restoreDefault() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.programRestoreDefault,
      message: l10n.programRestoreDefaultConfirm,
      confirmLabel: l10n.programRestore,
    );
    if (!confirmed) {
      return;
    }
    _updateDraft(ProgramSeed.powerbuilding());
  }

  // -------------------------------------------------------------------------
  // Exercises
  // -------------------------------------------------------------------------

  void _renameExercise(ProgramDay day, ProgramExercise exercise, String value) {
    if (value == exercise.name) {
      return;
    }
    _updateExercise(day, exercise, (current) => current.copyWith(name: value));
  }

  void _changeRole(
    ProgramDay day,
    ProgramExercise exercise,
    ExerciseRole role,
  ) {
    if (role == exercise.role) {
      return;
    }
    _updateExercise(day, exercise, (current) => current.copyWith(role: role));
  }

  void _addExercise(ProgramDay day) {
    final l10n = AppLocalizations.of(context);
    final program = _current;
    final exercise = ProgramExercise(
      id: _uniqueId('ex', _exerciseIds(program)),
      name: l10n.programNewExercise,
      role: ExerciseRole.accessory,
      setTargets: const <SetTarget>[SetTarget(reps: 10)],
    );
    _updateDraft(
      _mapDay(
        program,
        day.id,
        (current) => current.copyWith(
          exercises: <ProgramExercise>[...current.exercises, exercise],
        ),
      ),
    );
  }

  void _duplicateExercise(ProgramDay day, ProgramExercise exercise) {
    final program = _current;
    final copy = ProgramExercise(
      id: _uniqueId('ex', _exerciseIds(program)),
      name: exercise.name,
      role: exercise.role,
      setTargets: exercise.setTargets,
      notes: exercise.notes,
    );
    _updateDraft(
      _mapDay(program, day.id, (current) {
        final index = current.exercises.indexWhere(
          (item) => item.id == exercise.id,
        );
        final exercises = List<ProgramExercise>.of(current.exercises)
          ..insert(index + 1, copy);
        return current.copyWith(exercises: exercises);
      }),
    );
  }

  Future<void> _removeExercise(ProgramDay day, ProgramExercise exercise) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.programDeleteExerciseTitle,
      message: l10n.programDeleteExerciseConfirm(exercise.name),
    );
    if (!confirmed) {
      return;
    }
    _updateDraft(
      _mapDay(
        _current,
        day.id,
        (current) => current.copyWith(
          exercises: current.exercises
              .where((item) => item.id != exercise.id)
              .toList(growable: false),
        ),
      ),
    );
  }

  void _moveExercise(ProgramDay day, ProgramExercise exercise, int delta) {
    _updateDraft(
      _mapDay(_current, day.id, (current) {
        final index = current.exercises.indexWhere(
          (item) => item.id == exercise.id,
        );
        final target = index + delta;
        if (index < 0 || target < 0 || target >= current.exercises.length) {
          return current;
        }
        final exercises = List<ProgramExercise>.of(current.exercises);
        final moved = exercises.removeAt(index);
        exercises.insert(target, moved);
        return current.copyWith(exercises: exercises);
      }),
    );
  }

  void _updateExercise(
    ProgramDay day,
    ProgramExercise exercise,
    ProgramExercise Function(ProgramExercise exercise) transform,
  ) {
    _updateDraft(
      _mapDay(
        _current,
        day.id,
        (current) => current.copyWith(
          exercises: current.exercises
              .map((item) => item.id == exercise.id ? transform(item) : item)
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _editSets(ProgramDay day, ProgramExercise exercise) async {
    final settings = ref.read(settingsControllerProvider);
    final newTargets = await showSetTargetsDialog(
      context: context,
      exerciseName: exercise.name,
      targets: exercise.setTargets,
      unit: settings.unit,
    );
    if (newTargets == null) {
      return;
    }
    _updateExercise(
      day,
      exercise,
      (current) => current.copyWith(setTargets: newTargets),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  TrainingProgram _mapDay(
    TrainingProgram program,
    String dayId,
    ProgramDay Function(ProgramDay day) transform,
  ) {
    return program.copyWith(
      days: program.days
          .map((day) => day.id == dayId ? transform(day) : day)
          .toList(growable: false),
    );
  }

  List<ProgramExercise> _copyExercises(
    TrainingProgram program,
    List<ProgramExercise> exercises,
  ) {
    final ids = <String>{..._exerciseIds(program)};
    return exercises
        .map((exercise) {
          final id = _uniqueId('ex', ids);
          ids.add(id);
          return ProgramExercise(
            id: id,
            name: exercise.name,
            role: exercise.role,
            setTargets: exercise.setTargets,
            notes: exercise.notes,
          );
        })
        .toList(growable: false);
  }

  Set<String> _exerciseIds(TrainingProgram program) => program.days
      .expand((day) => day.exercises)
      .map((exercise) => exercise.id)
      .toSet();

  static String _uniqueId(String prefix, Iterable<String> taken) {
    final base = '$prefix-${DateTime.now().microsecondsSinceEpoch}';
    final used = taken.toSet();
    var candidate = base;
    var suffix = 1;
    while (used.contains(candidate)) {
      suffix += 1;
      candidate = '$base-$suffix';
    }
    return candidate;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String? confirmLabel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel ?? l10n.delete),
          ),
        ],
      ),
    );
    return result ?? false;
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
