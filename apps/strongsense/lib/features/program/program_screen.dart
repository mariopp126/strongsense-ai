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

  TrainingProgram get _program => ref.read(programControllerProvider);

  Future<void> _persist(TrainingProgram program) =>
      ref.read(programControllerProvider.notifier).save(program);

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.programTitle),
        actions: <Widget>[
          IconButton(
            tooltip: _editing ? l10n.done : l10n.edit,
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
          if (_editing) ...<Widget>[
            TextFormField(
              key: const ValueKey<String>('program-name'),
              initialValue: program.name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.programProgramName,
                prefixIcon: const Icon(Icons.fitness_center_rounded),
              ),
              onFieldSubmitted: _renameProgram,
            ),
            const SizedBox(height: SsSpacing.lg),
          ],
          for (var index = 0; index < program.days.length; index++) ...<Widget>[
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
            OutlinedButton.icon(
              key: const ValueKey<String>('program-restore-default'),
              onPressed: _restoreDefault,
              icon: const Icon(Icons.restore_rounded),
              label: Text(l10n.programRestoreDefault),
            ),
        ],
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
                        onFieldSubmitted: (value) => _renameDay(day, value),
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
  // Program metadata
  // -------------------------------------------------------------------------

  Future<void> _renameProgram(String value) async {
    final trimmed = value.trim();
    final program = _program;
    if (trimmed.isEmpty || trimmed == program.name) {
      return;
    }
    await _persist(program.copyWith(name: trimmed));
  }

  // -------------------------------------------------------------------------
  // Days
  // -------------------------------------------------------------------------

  Future<void> _renameDay(ProgramDay day, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == day.title) {
      return;
    }
    await _persist(
      _mapDay(_program, day.id, (current) => current.copyWith(title: trimmed)),
    );
  }

  Future<void> _setDayFocus(ProgramDay day, String focus) async {
    if (focus == day.focus) {
      return;
    }
    await _persist(
      _mapDay(_program, day.id, (current) => current.copyWith(focus: focus)),
    );
  }

  Future<void> _addDay() async {
    final l10n = AppLocalizations.of(context);
    final program = _program;
    final day = ProgramDay(
      id: _uniqueId('day', program.days.map((day) => day.id)),
      title: l10n.programNewDay,
      focus: 'full',
      exercises: const <ProgramExercise>[],
    );
    await _persist(program.copyWith(days: <ProgramDay>[...program.days, day]));
  }

  Future<void> _duplicateDay(ProgramDay day) async {
    final l10n = AppLocalizations.of(context);
    final program = _program;
    final takenDayIds = program.days.map((current) => current.id).toSet();
    final copy = ProgramDay(
      id: _uniqueId('day', takenDayIds),
      title: l10n.programCopyOf(day.title),
      focus: day.focus,
      exercises: _copyExercises(program, day.exercises),
    );
    final index = program.days.indexWhere((current) => current.id == day.id);
    final days = List<ProgramDay>.of(program.days)..insert(index + 1, copy);
    await _persist(program.copyWith(days: days));
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
    final program = _program;
    await _persist(
      program.copyWith(
        days: program.days
            .where((current) => current.id != day.id)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _moveDay(ProgramDay day, int delta) async {
    final program = _program;
    final index = program.days.indexWhere((current) => current.id == day.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= program.days.length) {
      return;
    }
    final days = List<ProgramDay>.of(program.days);
    final moved = days.removeAt(index);
    days.insert(target, moved);
    await _persist(program.copyWith(days: days));
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
    await _persist(ProgramSeed.powerbuilding());
  }

  // -------------------------------------------------------------------------
  // Exercises
  // -------------------------------------------------------------------------

  Future<void> _renameExercise(
    ProgramDay day,
    ProgramExercise exercise,
    String value,
  ) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == exercise.name) {
      return;
    }
    await _updateExercise(
      day,
      exercise,
      (current) => current.copyWith(name: trimmed),
    );
  }

  Future<void> _changeRole(
    ProgramDay day,
    ProgramExercise exercise,
    ExerciseRole role,
  ) async {
    if (role == exercise.role) {
      return;
    }
    await _updateExercise(
      day,
      exercise,
      (current) => current.copyWith(role: role),
    );
  }

  Future<void> _addExercise(ProgramDay day) async {
    final l10n = AppLocalizations.of(context);
    final program = _program;
    final exercise = ProgramExercise(
      id: _uniqueId('ex', _exerciseIds(program)),
      name: l10n.programNewExercise,
      role: ExerciseRole.accessory,
      setTargets: const <SetTarget>[SetTarget(reps: 10)],
    );
    await _persist(
      _mapDay(
        program,
        day.id,
        (current) => current.copyWith(
          exercises: <ProgramExercise>[...current.exercises, exercise],
        ),
      ),
    );
  }

  Future<void> _duplicateExercise(
    ProgramDay day,
    ProgramExercise exercise,
  ) async {
    final program = _program;
    final copy = ProgramExercise(
      id: _uniqueId('ex', _exerciseIds(program)),
      name: exercise.name,
      role: exercise.role,
      setTargets: exercise.setTargets,
      notes: exercise.notes,
    );
    await _persist(
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
    await _persist(
      _mapDay(
        _program,
        day.id,
        (current) => current.copyWith(
          exercises: current.exercises
              .where((item) => item.id != exercise.id)
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _moveExercise(
    ProgramDay day,
    ProgramExercise exercise,
    int delta,
  ) async {
    final program = _program;
    await _persist(
      _mapDay(program, day.id, (current) {
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

  Future<void> _updateExercise(
    ProgramDay day,
    ProgramExercise exercise,
    ProgramExercise Function(ProgramExercise exercise) transform,
  ) {
    return _persist(
      _mapDay(
        _program,
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
    await _updateExercise(
      day,
      exercise,
      (current) => current.copyWith(setTargets: newTargets),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  List<ProgramExercise> _copyExercises(
    TrainingProgram program,
    List<ProgramExercise> exercises,
  ) {
    final taken = _exerciseIds(program);
    final ids = <String>{...taken};
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
