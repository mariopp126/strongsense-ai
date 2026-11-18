import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../l10n/app_localizations.dart';
import 'set_target_draft.dart';

/// Opens the per-set editor and returns the new set list, or `null` when the
/// user cancels.
Future<List<SetTarget>?> showSetTargetsDialog({
  required BuildContext context,
  required String exerciseName,
  required List<SetTarget> targets,
  required Unit unit,
}) {
  return showDialog<List<SetTarget>>(
    context: context,
    builder: (_) => SetTargetsDialog(
      exerciseName: exerciseName,
      targets: targets,
      unit: unit,
    ),
  );
}

class SetTargetsDialog extends StatefulWidget {
  const SetTargetsDialog({
    super.key,
    required this.exerciseName,
    required this.targets,
    required this.unit,
  });

  final String exerciseName;
  final List<SetTarget> targets;
  final Unit unit;

  @override
  State<SetTargetsDialog> createState() => _SetTargetsDialogState();
}

class _SetTargetsDialogState extends State<SetTargetsDialog> {
  final List<_SetEntry> _entries = <_SetEntry>[];
  final Map<int, Map<String, String>> _errors = <int, Map<String, String>>{};
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    final source = widget.targets.isEmpty
        ? const <SetTarget>[SetTarget(reps: 8)]
        : widget.targets;
    for (final target in source) {
      _entries.add(_SetEntry.fromTarget(_nextId++, target, widget.unit));
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addSet() {
    setState(() {
      final last = _entries.isEmpty ? null : _entries.last;
      _entries.add(
        _SetEntry(
          _nextId++,
          widget.unit,
          reps: last?._reps.text ?? '8',
          repsMax: last?._repsMax.text ?? '',
          load: last?._load.text ?? '',
          rpe: last?._rpe.text ?? '',
        ),
      );
    });
  }

  void _duplicate(int index) {
    setState(() {
      final source = _entries[index];
      _entries.insert(
        index + 1,
        _SetEntry(
          _nextId++,
          widget.unit,
          reps: source._reps.text,
          repsMax: source._repsMax.text,
          load: source._load.text,
          rpe: source._rpe.text,
        ),
      );
    });
  }

  void _remove(int index) {
    if (_entries.length <= 1) {
      return;
    }
    setState(() {
      final removed = _entries.removeAt(index);
      _errors.remove(removed.id);
      removed.dispose();
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _entries.length) {
      return;
    }
    setState(() {
      final entry = _entries.removeAt(index);
      _entries.insert(target, entry);
    });
  }

  void _apply() {
    final errors = <int, Map<String, String>>{};
    final result = <SetTarget>[];
    for (final entry in _entries) {
      final draftErrors = entry.draft.validate();
      if (draftErrors.isEmpty) {
        result.add(entry.draft.toTarget());
      } else {
        errors[entry.id] = draftErrors;
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.programEditSetsTitle(widget.exerciseName)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < _entries.length; index++)
                _buildSetCard(context, l10n, theme, index),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSet,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.programAddSet),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _apply, child: Text(l10n.programApply)),
      ],
    );
  }

  Widget _buildSetCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    int index,
  ) {
    final entry = _entries[index];
    final errors = _errors[entry.id] ?? const <String, String>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${l10n.programSet} ${index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.programMoveUp,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  onPressed: index == 0 ? null : () => _move(index, -1),
                ),
                IconButton(
                  tooltip: l10n.programMoveDown,
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  onPressed: index == _entries.length - 1
                      ? null
                      : () => _move(index, 1),
                ),
                IconButton(
                  tooltip: l10n.programDuplicateSet,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () => _duplicate(index),
                ),
                IconButton(
                  tooltip: l10n.programRemoveSet,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: _entries.length <= 1 ? null : () => _remove(index),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _numberField(
                    controller: entry._reps,
                    label: l10n.programReps,
                    error: _errorText(l10n, errors['reps']),
                    integer: true,
                    fieldKey: ValueKey<String>('set-${entry.id}-reps'),
                    onChanged: () => _clearError(entry.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    controller: entry._repsMax,
                    label: l10n.programRepsMax,
                    error: _errorText(l10n, errors['repsMax']),
                    integer: true,
                    fieldKey: ValueKey<String>('set-${entry.id}-repsMax'),
                    onChanged: () => _clearError(entry.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _numberField(
                    controller: entry._load,
                    label: l10n.programLoad,
                    error: _errorText(l10n, errors['load']),
                    suffix: widget.unit.wire,
                    fieldKey: ValueKey<String>('set-${entry.id}-load'),
                    onChanged: () => _clearError(entry.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                    controller: entry._rpe,
                    label: l10n.programRpe,
                    error: _errorText(l10n, errors['rpe']),
                    fieldKey: ValueKey<String>('set-${entry.id}-rpe'),
                    onChanged: () => _clearError(entry.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearError(int entryId) {
    if (_errors.containsKey(entryId)) {
      setState(() => _errors.remove(entryId));
    }
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String? error,
    required VoidCallback onChanged,
    Key? fieldKey,
    bool integer = false,
    String? suffix,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: error,
        isDense: true,
      ),
      onChanged: (_) => onChanged(),
    );
  }

  String? _errorText(AppLocalizations l10n, String? code) {
    switch (code) {
      case null:
        return null;
      case 'required':
        return l10n.programValidationRequired;
      case 'integer':
        return l10n.programValidationInteger;
      case 'decimal':
        return l10n.programValidationDecimal;
      case 'range':
        return l10n.programValidationRange;
      case 'repsMax':
        return l10n.programValidationRepsMax;
      case 'loadRange':
        return l10n.programValidationLoadRange;
      case 'rpeRange':
        return l10n.programValidationRpeRange;
      default:
        return l10n.errorGeneric;
    }
  }
}

class _SetEntry {
  _SetEntry(
    this.id,
    this.unit, {
    required String reps,
    required String repsMax,
    required String load,
    required String rpe,
  }) : _reps = TextEditingController(text: reps),
       _repsMax = TextEditingController(text: repsMax),
       _load = TextEditingController(text: load),
       _rpe = TextEditingController(text: rpe);

  factory _SetEntry.fromTarget(int id, SetTarget target, Unit unit) {
    final draft = SetTargetDraft.fromTarget(target, unit);
    return _SetEntry(
      id,
      unit,
      reps: draft.reps,
      repsMax: draft.repsMax,
      load: draft.load,
      rpe: draft.rpe,
    );
  }

  final int id;
  final Unit unit;
  final TextEditingController _reps;
  final TextEditingController _repsMax;
  final TextEditingController _load;
  final TextEditingController _rpe;

  SetTargetDraft get draft => SetTargetDraft(
    unit: unit,
    reps: _reps.text,
    repsMax: _repsMax.text,
    load: _load.text,
    rpe: _rpe.text,
  );

  void dispose() {
    _reps.dispose();
    _repsMax.dispose();
    _load.dispose();
    _rpe.dispose();
  }
}
