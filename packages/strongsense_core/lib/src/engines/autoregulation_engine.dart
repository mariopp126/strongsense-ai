import '../models/coach_context.dart';
import '../models/coach_plan.dart';
import '../models/enums.dart';
import '../models/program.dart';
import 'pain_guidance.dart';
import 'safety_bounds.dart';
import 'tips_library.dart';
import 'training_math.dart';

/// Outcome of the deterministic auto-regulation pass.
class AutoregulationResult {
  const AutoregulationResult({required this.plan, required this.isDeload});

  final CoachPlan plan;
  final bool isDeload;
}

/// Rules-first coach: turns readiness + last-session performance into today's
/// adjustments. Runs entirely offline and is the baseline the LLM enriches.
abstract final class AutoregulationEngine {
  static const double deloadLoadDeltaPct = -35;
  static const int deloadMainSetsDelta = -2;
  static const int deloadVariationSetsDelta = -1;
  static const int deloadAccessorySetsDelta = -2;
  static const double deloadRpeCap = 7.0;

  /// Deload expectations shared with [SafetyBounds] and the server clamp.
  static bool shouldDeload(CoachContext context) =>
      SafetyBounds.deloadExpected(context);

  static AutoregulationResult evaluate(CoachContext context) {
    final isDeload = shouldDeload(context);
    final last =
        context.lastSession?.classification ?? SessionClassification.none;
    final matrix = context.readiness.band == ReadinessBand.red
        ? const _Matrix(
            loadDeltaPct: -40,
            mainSetsDelta: -2,
            accessorySetsDelta: -2,
            rpeCap: 7.0,
          )
        : isDeload
        ? const _Matrix(
            loadDeltaPct: deloadLoadDeltaPct,
            mainSetsDelta: deloadMainSetsDelta,
            accessorySetsDelta: deloadAccessorySetsDelta,
            rpeCap: deloadRpeCap,
          )
        : _matrixFor(context.readiness.band, last);

    final adjustments = <Adjustment>[];
    var hasSubstitution = false;
    var painAffected = false;

    for (final exercise in context.programDay.exercises) {
      final double loadDelta;
      final int setsDelta;

      switch (exercise.role) {
        case ExerciseRole.main:
          loadDelta = matrix.loadDeltaPct;
          setsDelta = isDeload ? deloadMainSetsDelta : matrix.mainSetsDelta;
        case ExerciseRole.variation:
          loadDelta = isDeload ? deloadLoadDeltaPct : matrix.loadDeltaPct;
          setsDelta = isDeload ? deloadVariationSetsDelta : 0;
        case ExerciseRole.accessory:
          loadDelta = 0;
          setsDelta = isDeload
              ? deloadAccessorySetsDelta
              : matrix.accessorySetsDelta;
      }

      var effectiveLoadDelta = loadDelta;
      var reason = _reasonFor(context, matrix, isDeload, exercise.role, last);
      String? substitute;

      if (context.checkIn.painSeverity >= SafetyBounds.painLoadLockThreshold &&
          PainGuidance.isAffected(
            exercise.id,
            exercise.name,
            context.checkIn.painAreas,
          )) {
        painAffected = true;
        if (effectiveLoadDelta > 0) {
          effectiveLoadDelta = 0;
        }
        substitute = PainGuidance.substituteFor(
          exerciseId: exercise.id,
          name: exercise.name,
          painAreas: context.checkIn.painAreas,
        );
        hasSubstitution = hasSubstitution || substitute != null;
        reason =
            '$reason Pain reported: load held at or below the current '
            'working weight${substitute == null ? '' : ' and the lift swapped for $substitute'}.';
      }

      final adjusted = effectiveLoadDelta != 0 || setsDelta != 0;
      if (!adjusted && substitute == null) {
        continue;
      }

      adjustments.add(
        Adjustment(
          exerciseId: exercise.id,
          exercise: exercise.name,
          loadDeltaPct: _roundToHalf(effectiveLoadDelta),
          setsDelta: setsDelta,
          repsHint: _repsHint(exercise, matrix.rpeCap, isDeload),
          reason: reason,
          substituteWith: substitute,
        ),
      );
    }

    final plan = CoachPlan(
      source: CoachSource.rules,
      summary: _summaryFor(context, matrix, isDeload, last),
      readinessExplanation: _explanationFor(context, matrix),
      rpeCap: matrix.rpeCap,
      deload: isDeload,
      adjustments: List<Adjustment>.unmodifiable(adjustments),
      tips: List<CoachTip>.unmodifiable(
        TipsLibrary.build(context: context, isDeload: isDeload),
      ),
      flags: _flagsFor(
        context,
        matrix,
        isDeload,
        painAffected,
        hasSubstitution,
      ),
      disclaimer: SafetyBounds.disclaimer,
    );

    return AutoregulationResult(
      plan: SafetyBounds.clamp(plan, context),
      isDeload: isDeload,
    );
  }

  static _Matrix _matrixFor(ReadinessBand band, SessionClassification last) {
    switch (band) {
      case ReadinessBand.green:
        switch (last) {
          case SessionClassification.easy:
            return const _Matrix(
              loadDeltaPct: 2.5,
              mainSetsDelta: 0,
              accessorySetsDelta: 0,
              rpeCap: 9.0,
            );
          case SessionClassification.normal:
            return const _Matrix(
              loadDeltaPct: 1.5,
              mainSetsDelta: 1,
              accessorySetsDelta: 0,
              rpeCap: 9.0,
            );
          case SessionClassification.hard:
          case SessionClassification.none:
            return const _Matrix(
              loadDeltaPct: 0,
              mainSetsDelta: 0,
              accessorySetsDelta: 0,
              rpeCap: 8.5,
            );
        }
      case ReadinessBand.amber:
        switch (last) {
          case SessionClassification.easy:
            return const _Matrix(
              loadDeltaPct: 1.0,
              mainSetsDelta: 1,
              accessorySetsDelta: 0,
              rpeCap: 8.5,
            );
          case SessionClassification.normal:
          case SessionClassification.none:
            return const _Matrix(
              loadDeltaPct: 0,
              mainSetsDelta: 0,
              accessorySetsDelta: 0,
              rpeCap: 8.5,
            );
          case SessionClassification.hard:
            return const _Matrix(
              loadDeltaPct: -5,
              mainSetsDelta: -1,
              accessorySetsDelta: -1,
              rpeCap: 8.0,
            );
        }
      case ReadinessBand.orange:
        return const _Matrix(
          loadDeltaPct: -5,
          mainSetsDelta: -1,
          accessorySetsDelta: -1,
          rpeCap: 8.0,
        );
      case ReadinessBand.red:
        return const _Matrix(
          loadDeltaPct: -40,
          mainSetsDelta: -2,
          accessorySetsDelta: -2,
          rpeCap: 7.0,
        );
    }
  }

  static String _reasonFor(
    CoachContext context,
    _Matrix matrix,
    bool isDeload,
    ExerciseRole role,
    SessionClassification last,
  ) {
    if (isDeload) {
      return 'Deload week: working load reduced and volume cut to keep fatigue '
          'in check while you recover.';
    }
    final band = context.readiness.band.wire;
    final lastLabel = _lastDescription(last);
    if (role == ExerciseRole.accessory) {
      return matrix.accessorySetsDelta == 0
          ? 'Accessory volume is left unchanged for a $band readiness day.'
          : 'Accessory volume adjusted for $band readiness after $lastLabel.';
    }
    if (matrix.loadDeltaPct > 0) {
      return '$band readiness after $lastLabel: a small load increase '
          'is earned while staying inside the RPE cap.';
    }
    if (matrix.loadDeltaPct < 0) {
      return '$band readiness after $lastLabel: load reduced to keep '
          'technique and recovery intact.';
    }
    return '$band readiness after $lastLabel: hold the current load '
        'and win on execution.';
  }

  static String _lastDescription(SessionClassification last) {
    switch (last) {
      case SessionClassification.easy:
        return 'an easy session';
      case SessionClassification.normal:
        return 'a normal session';
      case SessionClassification.hard:
        return 'a hard session';
      case SessionClassification.none:
        return 'no recent session';
    }
  }

  static String? _repsHint(
    ProgramExercise exercise,
    double rpeCap,
    bool isDeload,
  ) {
    if (exercise.role == ExerciseRole.accessory) {
      return isDeload ? '1-2 sets, stop 3 reps short' : null;
    }
    return 'Keep every set at or below RPE ${rpeCap.toStringAsFixed(1)}';
  }

  static String _summaryFor(
    CoachContext context,
    _Matrix matrix,
    bool isDeload,
    SessionClassification last,
  ) {
    if (isDeload) {
      return 'Deload week: keep the main lifts around 65 percent of your '
          'working weights, two sets each, and no personal-record attempts. '
          'The goal is to leave the gym fresher than you arrived.';
    }

    final band = context.readiness.band.wire;
    final lastLabel = _lastDescription(last);
    final load = matrix.loadDeltaPct;
    final sets = matrix.mainSetsDelta;

    final loadText = load > 0
        ? 'Add ${_fmtPct(load)} to the main lifts'
        : load < 0
        ? 'Reduce the main lifts by ${_fmtPct(-load)}'
        : 'Hold the current main-lift loads';
    final setsText = sets > 0
        ? ' and add $sets working set${sets == 1 ? '' : 's'}.'
        : sets < 0
        ? ' and remove ${-sets} working set${sets == -1 ? '' : 's'}.'
        : '.';

    return 'Readiness is $band with $lastLabel. $loadText$setsText '
        'Keep every set at or below RPE ${matrix.rpeCap.toStringAsFixed(1)}.';
  }

  static String _explanationFor(CoachContext context, _Matrix matrix) {
    final components = context.readiness.components;
    String score(String key) => (components[key] ?? 0).round().toString();
    final buffer = StringBuffer()
      ..write(
        'Readiness ${context.readiness.score}/100 '
        '(${context.readiness.band.wire}). ',
      )
      ..write(
        'Sleep ${score('sleep')}, energy ${score('energy')}, '
        'stress tolerance ${score('stress')}, freshness ${score('soreness')}, '
        'motivation ${score('motivation')}. ',
      );

    if (context.readiness.appliedCaps.isNotEmpty) {
      buffer.write('${context.readiness.appliedCaps.join('. ')}. ');
    }

    buffer.write(
      'The plan keeps the session at or below '
      'RPE ${matrix.rpeCap.toStringAsFixed(1)}.',
    );
    if (context.checkIn.timeAvailableMin < 45) {
      buffer.write(' Accessories are trimmed to fit the time available.');
    }
    return buffer.toString();
  }

  static List<String> _flagsFor(
    CoachContext context,
    _Matrix matrix,
    bool isDeload,
    bool painAffected,
    bool hasSubstitution,
  ) {
    final flags = <String>[];
    if (context.readiness.band != ReadinessBand.green) {
      flags.add(
        '${_capitalize(context.readiness.band.wire)} readiness: keep RPE at or '
        'below ${matrix.rpeCap.toStringAsFixed(1)}.',
      );
    }
    if (isDeload) {
      flags.add('Deload week: no personal-record attempts.');
    }
    if (context.checkIn.painSeverity >= SafetyBounds.severePainThreshold) {
      flags.add(
        'Severe pain reported: stop the affected lift and seek professional '
        'advice.',
      );
    } else if (painAffected) {
      flags.add(
        'Pain reported: affected lifts are held at or below the current load'
        '${hasSubstitution ? ' and substituted' : ''}.',
      );
    }
    if (context.checkIn.timeAvailableMin < 30) {
      flags.add(
        'Short session: accessories removed to fit the time available.',
      );
    } else if (context.checkIn.timeAvailableMin < 45) {
      flags.add('Under 45 minutes: one accessory removed.');
    }
    return flags;
  }

  static String _fmtPct(double value) {
    final rounded = value.roundToDouble();
    return rounded == value
        ? '${value.toStringAsFixed(0)}%'
        : '${value.toStringAsFixed(1)}%';
  }

  static double _roundToHalf(double value) =>
      TrainingMath.roundToIncrement(value, 0.5);

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _Matrix {
  const _Matrix({
    required this.loadDeltaPct,
    required this.mainSetsDelta,
    required this.accessorySetsDelta,
    required this.rpeCap,
  });

  final double loadDeltaPct;
  final int mainSetsDelta;
  final int accessorySetsDelta;
  final double rpeCap;
}
