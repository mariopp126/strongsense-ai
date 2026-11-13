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
    this.theme = 'system',
    this.onboardingComplete = false,
    this.userName = '',
    this.bodyWeightKg,
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
    theme: json.optString('theme') ?? 'system',
    onboardingComplete: json.optBool('onboardingComplete') ?? false,
    userName: json.optString('userName') ?? '',
    bodyWeightKg: json.optDouble('bodyWeightKg'),
  );

  final Unit unit;
  final String language;
  final Increments increments;
  final DeloadPolicy deloadPolicy;
  final bool coachEnabled;
  final String coachBaseUrl;
  final String theme;
  final bool onboardingComplete;
  final String userName;
  final double? bodyWeightKg;

  TrainingSettings get training =>
      TrainingSettings(unit: unit, increments: increments);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'unit': unit.wire,
    'language': language,
    'increments': increments.toJson(),
    'deloadPolicy': deloadPolicy.wire,
    'coachEnabled': coachEnabled,
    'coachBaseUrl': coachBaseUrl,
    'theme': theme,
    'onboardingComplete': onboardingComplete,
    'userName': userName,
    'bodyWeightKg': bodyWeightKg,
  };

  AppSettings copyWith({
    Unit? unit,
    String? language,
    Increments? increments,
    DeloadPolicy? deloadPolicy,
    bool? coachEnabled,
    String? coachBaseUrl,
    String? theme,
    bool? onboardingComplete,
    String? userName,
    double? bodyWeightKg,
    bool clearBodyWeight = false,
  }) {
    return AppSettings(
      unit: unit ?? this.unit,
      language: language ?? this.language,
      increments: increments ?? this.increments,
      deloadPolicy: deloadPolicy ?? this.deloadPolicy,
      coachEnabled: coachEnabled ?? this.coachEnabled,
      coachBaseUrl: coachBaseUrl ?? this.coachBaseUrl,
      theme: theme ?? this.theme,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      userName: userName ?? this.userName,
      bodyWeightKg: clearBodyWeight
          ? null
          : (bodyWeightKg ?? this.bodyWeightKg),
    );
  }
}
