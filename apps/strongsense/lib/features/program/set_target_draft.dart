import 'package:strongsense_core/strongsense_core.dart';

import '../../core/utils/formatters.dart';

/// A single set as typed by the user, before validation and conversion to a
/// [SetTarget].
///
/// Load is entered in the user's display [unit] and stored back in kilograms.
/// Blank optional fields mean `null`: a blank load is bodyweight/machine, a
/// blank max reps is a fixed rep count and a blank RPE is "no cap".
class SetTargetDraft {
  SetTargetDraft({
    required this.unit,
    this.reps = '',
    this.repsMax = '',
    this.load = '',
    this.rpe = '',
  });

  factory SetTargetDraft.fromTarget(SetTarget target, Unit unit) {
    return SetTargetDraft(
      unit: unit,
      reps: target.reps.toString(),
      repsMax: target.repsMax?.toString() ?? '',
      load: target.loadKg == null ? '' : formatWeightValue(target.loadKg, unit),
      rpe: _formatDecimal(target.rpeCap),
    );
  }

  /// New-set defaults when the user adds a set.
  factory SetTargetDraft.blank(Unit unit) =>
      SetTargetDraft(unit: unit, reps: '8');

  final Unit unit;

  String reps;
  String repsMax;
  String load;
  String rpe;

  /// Field name to stable error code.
  ///
  /// Codes: `required`, `integer`, `decimal`, `range`, `repsMax`, `loadRange`,
  /// `rpeRange`.
  Map<String, String> validate() {
    final errors = <String, String>{};

    final repsValue = int.tryParse(reps.trim());
    if (reps.trim().isEmpty) {
      errors['reps'] = 'required';
    } else if (repsValue == null) {
      errors['reps'] = 'integer';
    } else if (repsValue < 1 || repsValue > 100) {
      errors['reps'] = 'range';
    }

    final repsMaxText = repsMax.trim();
    if (repsMaxText.isNotEmpty) {
      final repsMaxValue = int.tryParse(repsMaxText);
      if (repsMaxValue == null) {
        errors['repsMax'] = 'integer';
      } else if (repsMaxValue > 100) {
        errors['repsMax'] = 'range';
      } else if (repsValue != null && repsMaxValue < repsValue) {
        errors['repsMax'] = 'repsMax';
      }
    }

    final loadText = load.trim();
    if (loadText.isNotEmpty) {
      final loadValue = _parseDecimal(loadText);
      final loadKg = loadValue == null
          ? null
          : toCanonicalWeight(loadValue, unit);
      if (loadValue == null) {
        errors['load'] = 'decimal';
      } else if (loadKg! < 0 || loadKg > 1000) {
        errors['load'] = 'loadRange';
      }
    }

    final rpeText = rpe.trim();
    if (rpeText.isNotEmpty) {
      final rpeValue = _parseDecimal(rpeText);
      if (rpeValue == null) {
        errors['rpe'] = 'decimal';
      } else if (rpeValue < 1 || rpeValue > 10) {
        errors['rpe'] = 'rpeRange';
      }
    }

    return errors;
  }

  bool get isValid => validate().isEmpty;

  /// Converts a validated draft into a [SetTarget] stored in kilograms.
  SetTarget toTarget() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid set draft: $errors');
    }
    final loadText = load.trim();
    final rpeText = rpe.trim();
    return SetTarget(
      reps: int.parse(reps.trim()),
      repsMax: repsMax.trim().isEmpty ? null : int.parse(repsMax.trim()),
      loadKg: loadText.isEmpty
          ? null
          : toCanonicalWeight(_parseDecimal(loadText)!, unit),
      rpeCap: rpeText.isEmpty ? null : _parseDecimal(rpeText),
    );
  }

  static String _formatDecimal(double? value) {
    if (value == null) {
      return '';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  static double? _parseDecimal(String text) =>
      double.tryParse(text.replaceAll(',', '.'));
}
