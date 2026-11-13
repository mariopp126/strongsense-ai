import '../models/coach_context.dart';
import '../models/coach_plan.dart';
import '../models/enums.dart';
import 'pain_guidance.dart';
import 'training_math.dart';

/// Hard limits applied to every plan, whether it came from the rules engine or
/// from the LLM. The server applies the same bounds; the client always clamps
/// again before applying a plan.
abstract final class SafetyBounds {
  static const double normalMinLoadDeltaPct = -10;
  static const double normalMaxLoadDeltaPct = 5;
  static const double deloadMinLoadDeltaPct = -40;
  static const double deloadMaxLoadDeltaPct = 0;

  static const double minRpeCap = 6.5;
  static const double maxRpeCap = 9.0;
  static const double deloadMaxRpeCap = 7.0;

  static const int minSetsDelta = -2;
  static const int maxSetsDelta = 2;

  static const int maxAdjustments = 12;
  static const int maxTips = 12;
  static const int maxFlags = 8;

  static const int maxSummaryChars = 600;
  static const int maxReadinessChars = 600;
  static const int maxTipTitleChars = 80;
  static const int maxTipBodyChars = 480;
  static const int maxFlagChars = 160;
  static const int maxRepsHintChars = 80;
  static const int maxReasonChars = 240;
  static const int maxSubstituteChars = 60;

  static const int painLoadLockThreshold = 4;
  static const int severePainThreshold = 7;

  static const String disclaimer =
      'StrongSense AI provides general training guidance, not medical advice. '
      'Stop and seek professional care if you feel sharp pain, numbness or a '
      'joint gives way.';

  /// Whether the context itself requires a deload, independent of any model.
  static bool deloadExpected(CoachContext context) {
    if (context.checkIn.painSeverity >= severePainThreshold) {
      return true;
    }
    if (context.readiness.band == ReadinessBand.red) {
      return true;
    }
    if (context.blockWeek > 0 && context.blockWeek % 4 == 0) {
      return true;
    }
    return false;
  }

  /// Returns a repaired copy of [plan] that respects every bound.
  static CoachPlan clamp(CoachPlan plan, CoachContext context) {
    final deload = plan.deload || deloadExpected(context);
    final minLoad = deload ? deloadMinLoadDeltaPct : normalMinLoadDeltaPct;
    final maxLoad = deload ? deloadMaxLoadDeltaPct : normalMaxLoadDeltaPct;
    final maxRpe = deload ? deloadMaxRpeCap : context.constraints.rpeCapMax;

    final exerciseNames = <String, String>{
      for (final exercise in context.programDay.exercises)
        exercise.id: exercise.name,
    };

    final adjustments = <Adjustment>[];
    for (final adjustment in plan.adjustments) {
      if (!exerciseNames.containsKey(adjustment.exerciseId)) {
        continue;
      }
      if (adjustments.length >= maxAdjustments) {
        break;
      }

      final name = exerciseNames[adjustment.exerciseId]!;
      var delta = _roundToHalf(
        TrainingMath.clamp(adjustment.loadDeltaPct, minLoad, maxLoad),
      );

      if (context.checkIn.painSeverity >= painLoadLockThreshold &&
          PainGuidance.isAffected(
            adjustment.exerciseId,
            name,
            context.checkIn.painAreas,
          ) &&
          delta > 0) {
        delta = 0;
      }

      final substitute = adjustment.substituteWith?.trim();
      adjustments.add(
        adjustment.copyWith(
          exercise: name,
          loadDeltaPct: delta,
          setsDelta: TrainingMath.clampInt(
            adjustment.setsDelta,
            minSetsDelta,
            maxSetsDelta,
          ),
          repsHint: adjustment.repsHint == null
              ? null
              : _truncate(adjustment.repsHint!, maxRepsHintChars),
          reason: _truncate(adjustment.reason, maxReasonChars),
          substituteWith: substitute == null || substitute.isEmpty
              ? null
              : _truncate(substitute, maxSubstituteChars),
          clearSubstitute: substitute == null || substitute.isEmpty,
        ),
      );
    }

    final tips = <CoachTip>[];
    for (final tip in plan.tips) {
      if (tips.length >= context.constraints.maxTips) {
        break;
      }
      final title = _truncate(tip.title.trim(), maxTipTitleChars);
      final body = _truncate(tip.body.trim(), maxTipBodyChars);
      if (title.isEmpty || body.isEmpty) {
        continue;
      }
      tips.add(tip.copyWith(title: title, body: body));
    }

    final flags = <String>[];
    for (final flag in plan.flags) {
      if (flags.length >= maxFlags) {
        break;
      }
      final trimmed = _truncate(flag.trim(), maxFlagChars);
      if (trimmed.isNotEmpty) {
        flags.add(trimmed);
      }
    }

    final rpeCap = TrainingMath.clamp(plan.rpeCap, minRpeCap, maxRpe);

    return plan.copyWith(
      source: plan.source,
      deload: deload,
      rpeCap: rpeCap,
      adjustments: adjustments,
      tips: tips,
      flags: flags,
      summary: _truncate(plan.summary.trim(), maxSummaryChars),
      readinessExplanation: _truncate(
        plan.readinessExplanation.trim(),
        maxReadinessChars,
      ),
      disclaimer: disclaimer,
    );
  }

  static double _roundToHalf(double value) => (value * 2).round() / 2;

  static String _truncate(String value, int maxChars) {
    if (maxChars <= 0) {
      return '';
    }
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars - 1)}…';
  }
}
