import 'package:strongsense_core/strongsense_core.dart';

import '../remote/coach_api_client.dart';

/// Result of asking for today's plan: always contains a safe plan.
class CoachResult {
  const CoachResult({
    required this.plan,
    required this.baselinePlan,
    required this.aiUsed,
    this.aiError,
    this.model = '',
  });

  /// The plan to apply (AI-enriched and clamped, or the offline rules plan).
  final CoachPlan plan;

  /// The deterministic rules plan; never empty.
  final CoachPlan baselinePlan;
  final bool aiUsed;
  final String? aiError;
  final String model;
}

/// Orchestrates: rules baseline -> optional server call -> client clamp.
class CoachService {
  CoachService({required this.settings, required this.client});

  final AppSettings settings;
  final CoachApiClient client;

  Future<CoachResult> generate(CoachContext context) async {
    final rules = AutoregulationEngine.evaluate(context).plan;

    if (!settings.coachEnabled || settings.coachBaseUrl.trim().isEmpty) {
      return CoachResult(plan: rules, baselinePlan: rules, aiUsed: false);
    }

    try {
      final response = await client.requestPlan(
        CoachRequest(
          context: context,
          baselinePlan: rules,
          locale: settings.language,
        ),
      );
      final clamped = SafetyBounds.clamp(response.plan, context);
      return CoachResult(
        plan: clamped,
        baselinePlan: rules,
        aiUsed: response.source == CoachSource.llm,
        model: response.meta.model,
      );
    } on CoachApiException catch (error) {
      return CoachResult(
        plan: rules,
        baselinePlan: rules,
        aiUsed: false,
        aiError: error.message,
      );
    } catch (_) {
      return CoachResult(
        plan: rules,
        baselinePlan: rules,
        aiUsed: false,
        aiError: 'Unexpected coach error',
      );
    }
  }
}
