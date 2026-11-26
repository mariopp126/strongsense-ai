import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_progress.dart';
import '../../core/widgets/ss_workout.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  Timer? _restTimer;
  int _restRemaining = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    await ref.read(sessionControllerProvider.notifier).load(widget.sessionId);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest([int seconds = 90]) {
    _restTimer?.cancel();
    setState(() => _restRemaining = seconds);
    final settings = ref.read(settingsControllerProvider);
    if (settings.restNotificationsEnabled) {
      final l10n = AppLocalizations.of(context);
      unawaited(
        ref
            .read(notificationServiceProvider)
            .scheduleRestDone(
              rest: Duration(seconds: seconds),
              title: l10n.restDoneTitle,
              body: l10n.restDoneBody,
            ),
      );
    }
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restRemaining -= 1;
        if (_restRemaining <= 0) {
          timer.cancel();
          _restRemaining = 0;
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    unawaited(ref.read(notificationServiceProvider).cancelRestDone());
    setState(() => _restRemaining = 0);
  }

  Future<void> _toggleSet(SetLog log) async {
    final wasCompleted = log.completed && !log.skipped;
    await HapticFeedback.selectionClick();
    await ref
        .read(sessionControllerProvider.notifier)
        .toggleSet(log.exerciseId, log.setIndex);
    if (!wasCompleted) {
      _startRest();
    }
  }

  Future<void> _editSet(SetLog log) async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(settingsControllerProvider);
    final repsController = TextEditingController(
      text: '${log.reps ?? log.targetReps}',
    );
    final loadController = TextEditingController(
      text: log.loadKg == null
          ? ''
          : formatWeightValue(log.loadKg, settings.unit),
    );
    final rpeController = TextEditingController(
      text: log.rpe == null ? '' : log.rpe!.toStringAsFixed(1),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.workoutEditSet),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.workoutReps),
              ),
              const SizedBox(height: SsSpacing.md),
              TextField(
                controller: loadController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.workoutWeight,
                  suffixText: settings.unit.wire,
                ),
              ),
              const SizedBox(height: SsSpacing.md),
              TextField(
                controller: rpeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'RPE',
                  hintText: '6 - 10',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved == true) {
      final repsText = repsController.text.trim();
      final loadText = loadController.text.trim().replaceAll(',', '.');
      final rpeText = rpeController.text.trim().replaceAll(',', '.');
      final reps = int.tryParse(repsText);
      final displayLoad = double.tryParse(loadText);
      final rpe = double.tryParse(rpeText);

      await ref
          .read(sessionControllerProvider.notifier)
          .updateSet(
            log.exerciseId,
            log.setIndex,
            reps: reps,
            loadKg: displayLoad == null
                ? null
                : toCanonicalWeight(displayLoad, settings.unit),
            rpe: rpe,
          );
    }

    repsController.dispose();
    loadController.dispose();
    rpeController.dispose();
  }

  Future<void> _finish(ProgramDay day) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    double sessionRpe = 8;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.workoutFinishConfirm),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.workoutFinishBody, style: theme.textTheme.bodySmall),
                const SizedBox(height: SsSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.workoutSessionRpe,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      sessionRpe.toStringAsFixed(1),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: SsColors.emerald700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: sessionRpe,
                  min: 5,
                  max: 10,
                  divisions: 10,
                  label: sessionRpe.toStringAsFixed(1),
                  onChanged: (value) =>
                      setDialogState(() => sessionRpe = value),
                ),
                const SizedBox(height: SsSpacing.sm),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.workoutNotes,
                    hintText: l10n.workoutNotesHint,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.workoutFinish),
            ),
          ],
        ),
      ),
    );

    notesController.dispose();
    if (confirmed != true) {
      return;
    }

    await ref
        .read(sessionControllerProvider.notifier)
        .finish(
          day: day,
          sessionRpe: sessionRpe,
          notes: notesController.text.trim(),
        );
    unawaited(ref.read(notificationServiceProvider).cancelRestDone());
    final completedSession = ref.read(sessionControllerProvider);
    final currentProgram = ref.read(programControllerProvider);
    final settings = ref.read(settingsControllerProvider);
    final completedSessions =
        (await ref.read(sessionRepositoryProvider).loadCompleted()).length;
    if (completedSession != null) {
      final nextProgram = ref
          .read(programTemplateServiceProvider)
          .advanceAfterSession(
            session: completedSession,
            program: currentProgram,
            completedSessions: completedSessions,
            increments: settings.increments,
          );
      if (nextProgram != null) {
        await ref.read(programControllerProvider.notifier).save(nextProgram);
      }
    }
    ref.invalidate(historyProvider);
    ref.invalidate(latestCoachPlanProvider);
    if (mounted) {
      context.go('/summary/${widget.sessionId}');
    }
  }

  Future<void> _discard() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsReset),
        content: Text(l10n.workoutFinishBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      unawaited(ref.read(notificationServiceProvider).cancelRestDone());
      await ref.read(sessionControllerProvider.notifier).discard();
      ref.invalidate(historyProvider);
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final program = ref.watch(programControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final session = ref.watch(sessionControllerProvider);

    if (_loading || session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workoutTitle)),
        body: SsLoading(label: l10n.loading),
      );
    }

    final day = program.dayById(session.dayId) ?? program.days.first;
    final logsByExercise = <String, List<SetLog>>{};
    for (final log in session.setLogs) {
      logsByExercise.putIfAbsent(log.exerciseId, () => <SetLog>[]).add(log);
    }
    for (final logs in logsByExercise.values) {
      logs.sort((a, b) => a.setIndex.compareTo(b.setIndex));
    }

    final totalSets = session.plannedSetCount;
    final doneSets = session.completedSetCount;
    final progress = totalSets == 0 ? 0.0 : doneSets / totalSets;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.dayTitle(day.id, day.title)),
            Text(
              l10n.setsProgress(doneSets, totalSets),
              style: const TextStyle(
                fontSize: 12,
                color: SsColors.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.delete,
            onPressed: _discard,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.lg,
          SsSpacing.xl,
        ),
        children: <Widget>[
          SsCard(
            padding: const EdgeInsets.all(SsSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.workoutTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SsColors.emerald600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SsSpacing.sm),
                SsProgressBar(value: progress),
                if (session.isCompleted) ...<Widget>[
                  const SizedBox(height: SsSpacing.md),
                  SsBanner(message: l10n.summarySubtitle),
                  const SizedBox(height: SsSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.go('/summary/${session.id}'),
                    child: Text(l10n.summaryTitle),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          for (final exercise in day.exercises)
            if (logsByExercise[exercise.id] != null) ...<Widget>[
              SsExerciseCard(
                exercise: exercise,
                logs: logsByExercise[exercise.id]!,
                unit: settings.unit,
                onToggle: _toggleSet,
                onEdit: _editSet,
              ),
              const SizedBox(height: SsSpacing.lg),
            ],
          const SizedBox(height: SsSpacing.sm),
          FilledButton.icon(
            onPressed: session.isCompleted ? null : () => _finish(day),
            icon: const Icon(Icons.flag_rounded),
            label: Text(l10n.workoutFinish),
          ),
        ],
      ),
      bottomNavigationBar: _restRemaining > 0
          ? _RestBar(
              remaining: _restRemaining,
              label: l10n.workoutRest,
              skipLabel: l10n.skip,
              onSkip: _skipRest,
            )
          : null,
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.remaining,
    required this.label,
    required this.skipLabel,
    required this.onSkip,
  });

  final int remaining;
  final String label;
  final String skipLabel;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(SsSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: SsSpacing.lg,
          vertical: SsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: SsColors.slate900,
          borderRadius: BorderRadius.circular(SsSpacing.radiusLg),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: SsColors.slate900.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.timer_outlined,
              color: SsColors.emerald400,
              size: 20,
            ),
            const SizedBox(width: SsSpacing.sm),
            Text(
              '$label  $minutes:$seconds',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSkip,
              child: Text(
                skipLabel,
                style: const TextStyle(color: SsColors.emerald400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
