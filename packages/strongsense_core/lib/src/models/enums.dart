/// Shared enums and their stable wire representation.
///
/// Every enum that crosses the HTTP boundary exposes [wire] (snake_case) and
/// [fromWire]. Never persist enum `.name` values; use `wire`.
library;

enum ExerciseRole {
  main('main'),
  variation('variation'),
  accessory('accessory');

  const ExerciseRole(this.wire);
  final String wire;

  static ExerciseRole fromWire(String value) => values.firstWhere(
    (role) => role.wire == value,
    orElse: () => throw FormatException('Unknown ExerciseRole: $value'),
  );
}

enum ReadinessBand {
  green('green'),
  amber('amber'),
  orange('orange'),
  red('red');

  const ReadinessBand(this.wire);
  final String wire;

  static ReadinessBand fromWire(String value) => values.firstWhere(
    (band) => band.wire == value,
    orElse: () => throw FormatException('Unknown ReadinessBand: $value'),
  );
}

enum ReadinessAdvice {
  push('push'),
  maintain('maintain'),
  reduce('reduce'),
  recover('recover');

  const ReadinessAdvice(this.wire);
  final String wire;

  static ReadinessAdvice fromWire(String value) => values.firstWhere(
    (advice) => advice.wire == value,
    orElse: () => throw FormatException('Unknown ReadinessAdvice: $value'),
  );
}

enum SessionClassification {
  easy('easy'),
  normal('normal'),
  hard('hard'),
  none('none');

  const SessionClassification(this.wire);
  final String wire;

  static SessionClassification fromWire(String value) => values.firstWhere(
    (classification) => classification.wire == value,
    orElse: () =>
        throw FormatException('Unknown SessionClassification: $value'),
  );
}

enum CoachSource {
  rules('rules'),
  llm('llm'),
  rulesFallback('rules_fallback');

  const CoachSource(this.wire);
  final String wire;

  static CoachSource fromWire(String value) => values.firstWhere(
    (source) => source.wire == value,
    orElse: () => throw FormatException('Unknown CoachSource: $value'),
  );
}

enum TipCategory {
  technique('technique'),
  recovery('recovery'),
  nutrition('nutrition'),
  programming('programming');

  const TipCategory(this.wire);
  final String wire;

  static TipCategory fromWire(String value) => values.firstWhere(
    (category) => category.wire == value,
    orElse: () => throw FormatException('Unknown TipCategory: $value'),
  );
}

enum Unit {
  kg('kg'),
  lb('lb');

  const Unit(this.wire);
  final String wire;

  static Unit fromWire(String value) => values.firstWhere(
    (unit) => unit.wire == value,
    orElse: () => throw FormatException('Unknown Unit: $value'),
  );
}

enum SessionStatus {
  planned('planned'),
  inProgress('in_progress'),
  completed('completed');

  const SessionStatus(this.wire);
  final String wire;

  static SessionStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw FormatException('Unknown SessionStatus: $value'),
  );
}

enum DeloadPolicy {
  everyFourthWeek('every_fourth_week'),
  readinessDriven('readiness_driven'),
  manual('manual');

  const DeloadPolicy(this.wire);
  final String wire;

  static DeloadPolicy fromWire(String value) => values.firstWhere(
    (policy) => policy.wire == value,
    orElse: () => throw FormatException('Unknown DeloadPolicy: $value'),
  );
}

enum PainArea {
  lowerBack('lower_back'),
  knee('knee'),
  shoulder('shoulder'),
  elbow('elbow'),
  wrist('wrist'),
  hip('hip'),
  other('other');

  const PainArea(this.wire);
  final String wire;

  static PainArea fromWire(String value) => values.firstWhere(
    (area) => area.wire == value,
    orElse: () => throw FormatException('Unknown PainArea: $value'),
  );
}
