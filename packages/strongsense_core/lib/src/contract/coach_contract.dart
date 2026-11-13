import '../json/json_utils.dart';
import '../models/coach_context.dart';
import '../models/coach_plan.dart';
import '../models/enums.dart';

/// Versioned HTTP surface shared with the Python service.
abstract final class CoachContract {
  static const int version = 1;
  static const int maxBodyBytes = 256 * 1024;
  static const String planPath = '/v1/coach/plan';
  static const String healthPath = '/health';
}

/// Request body for `POST /v1/coach/plan`.
class CoachRequest {
  const CoachRequest({
    required this.context,
    this.baselinePlan,
    this.locale = 'en',
    this.forceRules = false,
  });

  factory CoachRequest.fromJson(Map<String, dynamic> json) {
    final version = json.requireInt('contractVersion');
    if (version != CoachContract.version) {
      throw FormatException(
        'Unsupported contractVersion $version (expected ${CoachContract.version})',
      );
    }
    return CoachRequest(
      context: CoachContext.fromJson(json.requireMap('context')),
      baselinePlan: json.optMap('baselinePlan') == null
          ? null
          : CoachPlan.fromJson(json.requireMap('baselinePlan')),
      locale: json.optString('locale') ?? 'en',
      forceRules: json.optBool('forceRules') ?? false,
    );
  }

  final CoachContext context;
  final CoachPlan? baselinePlan;
  final String locale;
  final bool forceRules;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'contractVersion': CoachContract.version,
    'locale': locale,
    'context': context.toJson(),
    if (baselinePlan != null) 'baselinePlan': baselinePlan!.toJson(),
    if (forceRules) 'forceRules': true,
  };
}

/// Provider/model diagnostics returned alongside a generated plan.
class CoachMeta {
  const CoachMeta({
    this.provider = '',
    this.model = '',
    this.latencyMs = 0,
    this.clamped = false,
    this.droppedAdjustments = 0,
  });

  factory CoachMeta.fromJson(Map<String, dynamic> json) => CoachMeta(
    provider: json.optString('provider') ?? '',
    model: json.optString('model') ?? '',
    latencyMs: json.optInt('latencyMs') ?? 0,
    clamped: json.optBool('clamped') ?? false,
    droppedAdjustments: json.optInt('droppedAdjustments') ?? 0,
  );

  final String provider;
  final String model;
  final int latencyMs;
  final bool clamped;
  final int droppedAdjustments;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'provider': provider,
    'model': model,
    'latencyMs': latencyMs,
    'clamped': clamped,
    'droppedAdjustments': droppedAdjustments,
  };
}

/// Response body for `POST /v1/coach/plan`.
class CoachResponse {
  const CoachResponse({
    required this.source,
    required this.plan,
    required this.meta,
  });

  factory CoachResponse.fromJson(Map<String, dynamic> json) {
    final version = json.requireInt('contractVersion');
    if (version != CoachContract.version) {
      throw FormatException(
        'Unsupported contractVersion $version (expected ${CoachContract.version})',
      );
    }
    final source = CoachSource.fromWire(json.requireString('source'));
    final plan = CoachPlan.fromJson(json.requireMap('plan'));
    if (plan.source != source) {
      throw FormatException(
        'Inconsistent response: source "${source.wire}" but '
        'plan.source "${plan.source.wire}"',
      );
    }
    return CoachResponse(
      source: source,
      plan: plan,
      meta: json.optMap('meta') == null
          ? const CoachMeta()
          : CoachMeta.fromJson(json.requireMap('meta')),
    );
  }

  final CoachSource source;
  final CoachPlan plan;
  final CoachMeta meta;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'contractVersion': CoachContract.version,
    'source': source.wire,
    'plan': plan.toJson(),
    'meta': meta.toJson(),
  };
}

/// One configured LLM provider (reported by `/health`).
class CoachProviderInfo {
  const CoachProviderInfo({required this.name, required this.model});

  factory CoachProviderInfo.fromJson(Map<String, dynamic> json) =>
      CoachProviderInfo(
        name: json.requireString('name'),
        model: json.requireString('model'),
      );

  final String name;
  final String model;
}

/// Result of `GET /health`.
class CoachHealth {
  const CoachHealth({
    required this.status,
    required this.version,
    required this.contractVersion,
    required this.llmConfigured,
    this.providers = const <CoachProviderInfo>[],
  });

  factory CoachHealth.fromJson(Map<String, dynamic> json) => CoachHealth(
    status: json.requireString('status'),
    version: json.optString('version') ?? '',
    contractVersion: json.optInt('contractVersion') ?? 0,
    llmConfigured: json.optBool('llmConfigured') ?? false,
    providers: json
        .optMapList('providers')
        .map(CoachProviderInfo.fromJson)
        .toList(growable: false),
  );

  final String status;
  final String version;
  final int contractVersion;
  final bool llmConfigured;
  final List<CoachProviderInfo> providers;

  bool get isOk => status == 'ok';

  String get primaryModel => providers.isEmpty ? '' : providers.first.model;
}
