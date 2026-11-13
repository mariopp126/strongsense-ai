import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../theme/ss_colors.dart';

/// Converts a canonical kg value into the user's display unit.
double toDisplayWeight(double kg, Unit unit) =>
    unit == Unit.lb ? kg * 2.2046226218 : kg;

/// Converts a displayed value back to canonical kg.
double toCanonicalWeight(double value, Unit unit) =>
    unit == Unit.lb ? value / 2.2046226218 : value;

/// Formats a load value without the unit, e.g. `75` or `165.5`.
String formatWeightValue(double? kg, Unit unit) {
  if (kg == null) {
    return '—';
  }
  final value = toDisplayWeight(kg, unit);
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

/// Formats a load with its unit, e.g. `75 kg` or `—`.
String formatWeight(double? kg, Unit unit) =>
    kg == null ? '—' : '${formatWeightValue(kg, unit)} ${unit.wire}';

/// Formats a total volume with thousands separators.
String formatVolume(double volumeKg, Unit unit) {
  final value = toDisplayWeight(volumeKg, unit);
  final formatter = NumberFormat('#,##0', unit == Unit.lb ? 'en' : null);
  return '${formatter.format(value)} ${unit.wire}';
}

/// `1h 05m`, `45 min`, `—`.
String formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) {
    return '—';
  }
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return '${hours}h ${rest.toString().padLeft(2, '0')}m';
}

String formatDateShort(DateTime date, String localeCode) =>
    DateFormat.MMMd(localeCode).format(date);

String formatDateLong(DateTime date, String localeCode) =>
    DateFormat.yMMMMd(localeCode).format(date);

String formatDateTime(DateTime date, String localeCode) =>
    DateFormat.MMMd(localeCode).add_Hm().format(date);

/// Color for a readiness band, matching the design tokens.
Color readinessColor(ReadinessBand band) {
  switch (band) {
    case ReadinessBand.green:
      return SsColors.emerald500;
    case ReadinessBand.amber:
      return SsColors.amber500;
    case ReadinessBand.orange:
      return SsColors.orange500;
    case ReadinessBand.red:
      return SsColors.red500;
  }
}

Color readinessBackground(ReadinessBand band) {
  switch (band) {
    case ReadinessBand.green:
      return SsColors.emerald100;
    case ReadinessBand.amber:
      return SsColors.amber100;
    case ReadinessBand.orange:
      return SsColors.orange100;
    case ReadinessBand.red:
      return SsColors.red100;
  }
}

Color readinessText(ReadinessBand band) {
  switch (band) {
    case ReadinessBand.green:
      return SsColors.emerald800;
    case ReadinessBand.amber:
      return SsColors.amber800;
    case ReadinessBand.orange:
      return SsColors.orange800;
    case ReadinessBand.red:
      return SsColors.red800;
  }
}

String formatRpe(double? rpe) {
  if (rpe == null) {
    return '—';
  }
  return rpe == rpe.roundToDouble()
      ? rpe.toStringAsFixed(1)
      : rpe.toStringAsFixed(1);
}

String dayFocusLabel(String focus, String localeCode) {
  final es = localeCode == 'es';
  switch (focus) {
    case 'lower':
      return es ? 'Tren inferior' : 'Lower body';
    case 'upper':
      return es ? 'Tren superior' : 'Upper body';
    case 'full':
      return es ? 'Cuerpo completo' : 'Full body';
    default:
      return focus;
  }
}
