import '../json/json_utils.dart';
import '../models/session.dart';

/// Flattens sessions into a spreadsheet-friendly CSV (one row per set).
///
/// The output starts with a UTF-8 BOM and uses CRLF so Excel opens it with the
/// expected encoding and line endings. Fields containing commas, quotes or
/// newlines are quoted and escaped per RFC 4180.
abstract final class SessionCsvExporter {
  static const List<String> columns = <String>[
    'session_id',
    'date',
    'day_id',
    'status',
    'started_at',
    'completed_at',
    'session_rpe',
    'exercise_id',
    'set_index',
    'target_reps',
    'target_load_kg',
    'reps',
    'load_kg',
    'rpe',
    'completed',
    'skipped',
    'notes',
  ];

  static String toCsv(List<Session> sessions) {
    final sorted = sessions.toList(growable: false)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final buffer = StringBuffer('\uFEFF');
    buffer.write(columns.map(_escape).join(','));
    buffer.write('\r\n');

    for (final session in sorted) {
      if (session.setLogs.isEmpty) {
        buffer.write(_row(session, null));
        buffer.write('\r\n');
        continue;
      }
      for (final set in session.setLogs) {
        buffer.write(_row(session, set));
        buffer.write('\r\n');
      }
    }
    return buffer.toString();
  }

  static String _row(Session session, SetLog? set) {
    final values = <String>[
      session.id,
      formatDateOnly(session.date),
      session.dayId,
      session.status.wire,
      formatTimestamp(session.startedAt),
      session.completedAt == null ? '' : formatTimestamp(session.completedAt!),
      _number(session.sessionRpe),
      set?.exerciseId ?? '',
      set?.setIndex.toString() ?? '',
      set?.targetReps.toString() ?? '',
      _number(set?.targetLoadKg),
      set?.reps?.toString() ?? '',
      _number(set?.loadKg),
      _number(set?.rpe),
      set?.completed.toString() ?? '',
      set?.skipped.toString() ?? '',
      set?.notes ?? '',
    ];
    return values.map(_escape).join(',');
  }

  static String _number(double? value) {
    if (value == null) {
      return '';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  static String _escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\r') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
