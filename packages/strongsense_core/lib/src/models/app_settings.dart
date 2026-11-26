import '../json/json_utils.dart';
import 'coach_context.dart';
import 'enums.dart';

/// Persisted user preferences and coach configuration.
class AppSettings {
  const AppSettings({
    this.unit = Unit.kg,
    this.language = 'en',
    this.increments = const Increments(),
    this.deloadPolicy = DeloadPolicy.everyFourthWeek,
    this.coachEnabled = false,
    this.coachBaseUrl = 'http://127.0.0.1:8080',
    this.coachToken = '',
    this.theme = 'system',
    this.onboardingComplete = false,
    this.userName = '',
    this.bodyWeightKg,
    this.remindersEnabled = false,
    this.reminderHour = 18,
    this.reminderMinute = 0,
    this.reminderWeekdays = const <int>[1, 3, 5],
    this.restNotificationsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    unit: Unit.fromWire(json.optString('unit') ?? 'kg'),
    language: json.optString('language') ?? 'en',
    increments: json.optMap('increments') == null
        ? const Increments()
        : Increments.fromJson(json.requireMap('increments')),
    deloadPolicy: DeloadPolicy.fromWire(
      json.optString('deloadPolicy') ?? 'every_fourth_week',
    ),
    coachEnabled: json.optBool('coachEnabled') ?? false,
    coachBaseUrl: json.optString('coachBaseUrl') ?? 'http://127.0.0.1:8080',
    coachToken: json.optString('coachToken') ?? '',
    theme: json.optString('theme') ?? 'system',
    onboardingComplete: json.optBool('onboardingComplete') ?? false,
    userName: json.optString('userName') ?? '',
    bodyWeightKg: json.optDouble('bodyWeightKg'),
    remindersEnabled: json.optBool('remindersEnabled') ?? false,
    reminderHour: _clampInt(json.optInt('reminderHour') ?? 18, 0, 23),
    reminderMinute: _clampInt(json.optInt('reminderMinute') ?? 0, 0, 59),
    reminderWeekdays: _normalizeWeekdays(json.optIntList('reminderWeekdays')),
    restNotificationsEnabled: json.optBool('restNotificationsEnabled') ?? true,
    quietHoursEnabled: json.optBool('quietHoursEnabled') ?? false,
    quietStartHour: _clampInt(json.optInt('quietStartHour') ?? 22, 0, 23),
    quietEndHour: _clampInt(json.optInt('quietEndHour') ?? 7, 0, 23),
  );

  final Unit unit;
  final String language;
  final Increments increments;
  final DeloadPolicy deloadPolicy;
  final bool coachEnabled;
  final String coachBaseUrl;
  final String coachToken;
  final String theme;
  final bool onboardingComplete;
  final String userName;
  final double? bodyWeightKg;

  /// Training reminder preferences (local notifications only).
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;

  /// Weekdays to remind, using `DateTime.monday`..`DateTime.sunday` (1..7).
  final List<int> reminderWeekdays;
  final bool restNotificationsEnabled;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;

  TrainingSettings get training =>
      TrainingSettings(unit: unit, increments: increments);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'unit': unit.wire,
    'language': language,
    'increments': increments.toJson(),
    'deloadPolicy': deloadPolicy.wire,
    'coachEnabled': coachEnabled,
    'coachBaseUrl': coachBaseUrl,
    'coachToken': coachToken,
    'theme': theme,
    'onboardingComplete': onboardingComplete,
    'userName': userName,
    'bodyWeightKg': bodyWeightKg,
    'remindersEnabled': remindersEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'reminderWeekdays': reminderWeekdays,
    'restNotificationsEnabled': restNotificationsEnabled,
    'quietHoursEnabled': quietHoursEnabled,
    'quietStartHour': quietStartHour,
    'quietEndHour': quietEndHour,
  };

  AppSettings copyWith({
    Unit? unit,
    String? language,
    Increments? increments,
    DeloadPolicy? deloadPolicy,
    bool? coachEnabled,
    String? coachBaseUrl,
    String? coachToken,
    String? theme,
    bool? onboardingComplete,
    String? userName,
    double? bodyWeightKg,
    bool clearBodyWeight = false,
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    List<int>? reminderWeekdays,
    bool? restNotificationsEnabled,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    return AppSettings(
      unit: unit ?? this.unit,
      language: language ?? this.language,
      increments: increments ?? this.increments,
      deloadPolicy: deloadPolicy ?? this.deloadPolicy,
      coachEnabled: coachEnabled ?? this.coachEnabled,
      coachBaseUrl: coachBaseUrl ?? this.coachBaseUrl,
      coachToken: coachToken ?? this.coachToken,
      theme: theme ?? this.theme,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      userName: userName ?? this.userName,
      bodyWeightKg: clearBodyWeight
          ? null
          : (bodyWeightKg ?? this.bodyWeightKg),
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderWeekdays: reminderWeekdays ?? this.reminderWeekdays,
      restNotificationsEnabled:
          restNotificationsEnabled ?? this.restNotificationsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
    );
  }
}

int _clampInt(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

List<int> _normalizeWeekdays(List<int> values) {
  final normalized =
      values
          .where(
            (value) => value >= DateTime.monday && value <= DateTime.sunday,
          )
          .toSet()
          .toList(growable: false)
        ..sort();
  if (normalized.isEmpty) {
    return const <int>[DateTime.monday, DateTime.wednesday, DateTime.friday];
  }
  return List<int>.unmodifiable(normalized);
}
