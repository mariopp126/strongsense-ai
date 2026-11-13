import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_plan_view.dart';
import '../../core/widgets/ss_progress.dart';
import '../../core/widgets/ss_workout.dart';
import '../../data/services/coach_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

enum _Phase { form, preview }

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key, this.initialDayId});

  final String? initialDayId;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  late int _dayIndex;

  int _sleepQuality = 4;
  double _sleepHours = 7;
  int _energy = 3;
  int _motivation = 4;
  int _soreness = 2;
  int _stress = 2;
  final Set<PainArea> _painAreas = <PainArea>{};
  int _painSeverity = 0;
  int _timeAvailable = 60;
  final TextEditingController _notesController = TextEditingController();

  _Phase _phase = _Phase.form;
  CoachContext? _coachContext;
  CoachResult? _result;
  CheckIn? _checkIn;
  bool _aiLoading = false;
  String? _aiNotice;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final program = ref.read(programControllerProvider);
    final index = program.days.indexWhere(
      (day) => day.id == widget.initialDayId,
    );
    _dayIndex = index < 0 ? 0 : index;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final day = ref.read(programControllerProvider).days[_dayIndex];
    final checkIn = CheckIn(
      sleepQuality: _sleepQuality,
      sleepHours: _sleepHours,
      energy: _energy,
      motivation: _motivation,
      soreness: _soreness,
      stress: _stress,
      painAreas: _painAreas.toList(growable: false),
      painSeverity: _painAreas.isEmpty
          ? 0
          : (_painSeverity == 0 ? 3 : _painSeverity),
      timeAvailableMin: _timeAvailable,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _phase = _Phase.preview;
      _checkIn = checkIn;
      _result = null;
      _aiLoading = false;
      _aiNotice = null;
    });

    final coachContext = await ref
        .read(coachContextServiceProvider)
        .build(day: day, checkIn: checkIn);
    if (!mounted) {
      return;
    }

    final rules = AutoregulationEngine.evaluate(coachContext).plan;
    setState(() {
      _coachContext = coachContext;
      _result = CoachResult(plan: rules, baselinePlan: rules, aiUsed: false);
    });

    await _requestAi();
  }

  Future<void> _requestAi() async {
    final settings = ref.read(settingsControllerProvider);
    final coachContext = _coachContext;
    if (coachContext == null ||
        !settings.coachEnabled ||
        settings.coachBaseUrl.trim().isEmpty) {
      return;
    }

    setState(() => _aiLoading = true);
    final result = await ref.read(coachServiceProvider).generate(coachContext);
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _aiLoading = false;
      _aiNotice = result.aiError;
    });
  }

  Future<void> _startWorkout() async {
    final coachContext = _coachContext;
    final result = _result;
    final checkIn = _checkIn;
    if (coachContext == null || result == null || checkIn == null) {
      return;
    }

    setState(() => _starting = true);
    final plan = TargetResolver.resolve(
      context: coachContext,
      plan: result.plan,
    );
    final session = await ref
        .read(sessionControllerProvider.notifier)
        .start(checkIn: checkIn, plan: plan);
    ref.invalidate(historyProvider);
    if (mounted) {
      context.go('/workout/${session.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final program = ref.watch(programControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_phase == _Phase.form ? l10n.checkInTitle : l10n.planTitle),
      ),
      body: _phase == _Phase.form
          ? _buildForm(l10n, program)
          : _buildPreview(l10n),
    );
  }

  Widget _buildForm(AppLocalizations l10n, TrainingProgram program) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SsSpacing.lg,
        SsSpacing.lg,
        SsSpacing.lg,
        SsSpacing.section,
      ),
      children: <Widget>[
        Text(
          l10n.checkInSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsDaySelector(
          days: program.days,
          selectedIndex: _dayIndex,
          onSelected: (index) => setState(() => _dayIndex = index),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _intSlider(
                label: l10n.checkInSleepQuality,
                value: _sleepQuality,
                onChanged: (value) => setState(() => _sleepQuality = value),
              ),
              _doubleSlider(
                label: l10n.checkInSleepHours,
                value: _sleepHours,
                min: 4,
                max: 10,
                divisions: 12,
                onChanged: (value) => setState(() => _sleepHours = value),
              ),
              _intSlider(
                label: l10n.checkInEnergy,
                value: _energy,
                onChanged: (value) => setState(() => _energy = value),
              ),
              _intSlider(
                label: l10n.checkInMotivation,
                value: _motivation,
                onChanged: (value) => setState(() => _motivation = value),
              ),
              _intSlider(
                label: l10n.checkInSoreness,
                value: _soreness,
                onChanged: (value) => setState(() => _soreness = value),
              ),
              _intSlider(
                label: l10n.checkInStress,
                value: _stress,
                onChanged: (value) => setState(() => _stress = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.checkInPain, style: theme.textTheme.titleSmall),
              const SizedBox(height: SsSpacing.sm),
              Wrap(
                spacing: SsSpacing.sm,
                runSpacing: SsSpacing.sm,
                children: <Widget>[
                  for (final area in PainArea.values)
                    FilterChip(
                      label: Text(l10n.painAreaLabel(area.wire)),
                      selected: _painAreas.contains(area),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _painAreas.add(area);
                            if (_painSeverity == 0) {
                              _painSeverity = 3;
                            }
                          } else {
                            _painAreas.remove(area);
                            if (_painAreas.isEmpty) {
                              _painSeverity = 0;
                            }
                          }
                        });
                      },
                    ),
                ],
              ),
              if (_painAreas.isNotEmpty) ...<Widget>[
                const SizedBox(height: SsSpacing.md),
                _intSlider(
                  label: l10n.checkInPainSeverity,
                  value: _painSeverity,
                  min: 1,
                  max: 10,
                  onChanged: (value) => setState(() => _painSeverity = value),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.checkInTime, style: theme.textTheme.titleSmall),
              const SizedBox(height: SsSpacing.sm),
              Wrap(
                spacing: SsSpacing.sm,
                children: <Widget>[
                  for (final minutes in <int>[30, 45, 60, 90])
                    ChoiceChip(
                      label: Text('$minutes ${l10n.min}'),
                      selected: _timeAvailable == minutes,
                      onSelected: (_) =>
                          setState(() => _timeAvailable = minutes),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.checkInNotes, style: theme.textTheme.titleSmall),
              const SizedBox(height: SsSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l10n.checkInNotesHint),
              ),
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.xl),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.insights_rounded),
          label: Text(l10n.checkInGetPlan),
        ),
      ],
    );
  }

  Widget _buildPreview(AppLocalizations l10n) {
    final coachContext = _coachContext;
    final result = _result;

    if (coachContext == null || result == null) {
      return SsLoading(label: l10n.checkInGenerating);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SsSpacing.lg,
        SsSpacing.lg,
        SsSpacing.lg,
        SsSpacing.section,
      ),
      children: <Widget>[
        SsReadinessCard(readiness: coachContext.readiness),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: CoachPlanView(
            plan: result.plan,
            readiness: coachContext.readiness,
            aiLoading: _aiLoading,
            aiNotice: _aiNotice,
            aiModel: result.model,
            onRegenerate: _requestAi,
          ),
        ),
        const SizedBox(height: SsSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _starting
                    ? null
                    : () => setState(() => _phase = _Phase.form),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.edit),
              ),
            ),
            const SizedBox(width: SsSpacing.md),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _starting ? null : _startWorkout,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.planStart),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _intSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 1,
    int max = 5,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              '$value',
              style: theme.textTheme.titleSmall?.copyWith(
                color: SsColors.emerald700,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value',
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }

  Widget _doubleSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} h',
              style: theme.textTheme.titleSmall?.copyWith(
                color: SsColors.emerald700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toStringAsFixed(1)} h',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
