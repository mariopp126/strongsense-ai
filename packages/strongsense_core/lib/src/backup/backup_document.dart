import 'dart:convert';

import '../json/json_utils.dart';
import '../models/app_settings.dart';
import '../models/coach_plan.dart';
import '../models/program.dart';
import '../models/session.dart';

/// Raised when a backup file is malformed or from an unsupported schema.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// One persisted coach plan inside a backup.
class BackupCoachPlan {
  const BackupCoachPlan({
    required this.key,
    required this.generatedAt,
    required this.plan,
  });

  factory BackupCoachPlan.fromJson(Map<String, dynamic> json) {
    return BackupCoachPlan(
      key: json.requireString('key'),
      generatedAt: DateTime.parse(json.requireString('generatedAt')).toLocal(),
      plan: CoachPlan.fromJson(json.requireMap('plan')),
    );
  }

  final String key;
  final DateTime generatedAt;
  final CoachPlan plan;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'generatedAt': formatTimestamp(generatedAt),
    'plan': plan.toJson(),
  };
}

/// A complete, versioned snapshot of the local app data.
///
/// The format is intentionally explicit so a future migration can inspect the
/// `schemaVersion` before decoding the rest. Unknown fields are ignored, which
/// keeps forward-compatible backups readable.
class BackupDocument {
  const BackupDocument({
    required this.exportedAt,
    required this.settings,
    required this.program,
    required this.sessions,
    required this.coachPlans,
  });

  factory BackupDocument.fromJson(Map<String, dynamic> json) {
    if (json.optString('format') != format) {
      throw const BackupException(
        'This file is not a StrongSense backup (missing format marker).',
      );
    }
    final version = json.optInt('schemaVersion');
    if (version == null || version < 1) {
      throw const BackupException('The backup schema version is missing.');
    }
    if (version > schemaVersion) {
      throw BackupException(
        'This backup uses schema version $version, but this app supports '
        'up to $schemaVersion. Update the app to import it.',
      );
    }

    final exportedAt = _parseTimestamp(json.optString('exportedAt'));
    try {
      final settings = AppSettings.fromJson(json.requireMap('settings'));
      final program = TrainingProgram.fromJson(json.requireMap('program'));
      final sessions = json
          .optMapList('sessions')
          .map(Session.fromJson)
          .toList(growable: false);
      final coachPlans = json
          .optMapList('coachPlans')
          .map(BackupCoachPlan.fromJson)
          .toList(growable: false);
      _ensureUnique(sessions.map((session) => session.id), 'session ids');
      _ensureUnique(
        coachPlans.map((coachPlan) => coachPlan.key),
        'coach plan keys',
      );
      return BackupDocument(
        exportedAt: exportedAt,
        settings: settings,
        program: program,
        sessions: sessions,
        coachPlans: coachPlans,
      );
    } on FormatException catch (error) {
      throw BackupException('Invalid backup data: ${error.message}');
    } on ArgumentError catch (error) {
      throw BackupException('Invalid backup data: ${error.message}');
    }
  }

  /// Decode a backup from raw JSON text.
  factory BackupDocument.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw BackupException('The file is not valid JSON: ${error.message}');
    }
    if (decoded is! Map) {
      throw const BackupException('The backup root must be a JSON object.');
    }
    return BackupDocument.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  static const String format = 'strongsense.backup';
  static const int schemaVersion = 1;

  final DateTime exportedAt;
  final AppSettings settings;
  final TrainingProgram program;
  final List<Session> sessions;
  final List<BackupCoachPlan> coachPlans;

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': format,
    'schemaVersion': schemaVersion,
    'exportedAt': formatTimestamp(exportedAt),
    'settings': settings.toJson(),
    'program': program.toJson(),
    'sessions': sessions
        .map((session) => session.toJson())
        .toList(growable: false),
    'coachPlans': coachPlans
        .map((coachPlan) => coachPlan.toJson())
        .toList(growable: false),
  };

  BackupDocument copyWith({
    DateTime? exportedAt,
    AppSettings? settings,
    TrainingProgram? program,
    List<Session>? sessions,
    List<BackupCoachPlan>? coachPlans,
  }) {
    return BackupDocument(
      exportedAt: exportedAt ?? this.exportedAt,
      settings: settings ?? this.settings,
      program: program ?? this.program,
      sessions: sessions ?? this.sessions,
      coachPlans: coachPlans ?? this.coachPlans,
    );
  }

  static DateTime _parseTimestamp(String? value) {
    if (value == null) {
      return DateTime.now();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw BackupException('Invalid exportedAt timestamp: $value');
    }
    return parsed.toLocal();
  }

  static void _ensureUnique(Iterable<String> values, String label) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw BackupException('The backup contains duplicate $label: $value');
      }
    }
  }
}
