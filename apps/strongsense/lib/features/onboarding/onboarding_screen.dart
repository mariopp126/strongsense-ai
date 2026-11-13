import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/widgets/ss_card.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  Unit _unit = Unit.kg;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    await ref
        .read(settingsControllerProvider.notifier)
        .completeOnboarding(
          name: _nameController.text,
          unit: _unit,
          bodyWeightKg: weight,
        );
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final program = ref.watch(programControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SsSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SsColors.slate900,
                      borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: SsColors.emerald400,
                    ),
                  ),
                  const SizedBox(width: SsSpacing.md),
                  Text(
                    l10n.appName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.section),
              Text(
                l10n.onboardingTitle,
                style: theme.textTheme.displaySmall?.copyWith(height: 1.1),
              ),
              const SizedBox(height: SsSpacing.md),
              Text(
                l10n.onboardingBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: SsSpacing.section),
              Text(l10n.onboardingName, style: theme.textTheme.titleSmall),
              const SizedBox(height: SsSpacing.sm),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: l10n.onboardingNameHint,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: SsSpacing.lg),
              Text(l10n.onboardingUnits, style: theme.textTheme.titleSmall),
              const SizedBox(height: SsSpacing.sm),
              SegmentedButton<Unit>(
                segments: const <ButtonSegment<Unit>>[
                  ButtonSegment<Unit>(
                    value: Unit.kg,
                    label: Text('kg'),
                    icon: Icon(Icons.scale_outlined, size: 16),
                  ),
                  ButtonSegment<Unit>(
                    value: Unit.lb,
                    label: Text('lb'),
                    icon: Icon(Icons.fitness_center, size: 16),
                  ),
                ],
                selected: <Unit>{_unit},
                onSelectionChanged: (selection) =>
                    setState(() => _unit = selection.first),
              ),
              const SizedBox(height: SsSpacing.lg),
              Text(
                l10n.onboardingBodyweight,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: SsSpacing.sm),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: l10n.onboardingBodyweightHint,
                  suffixText: _unit.wire,
                  prefixIcon: const Icon(Icons.monitor_weight_outlined),
                ),
              ),
              const SizedBox(height: SsSpacing.section),
              SsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.onboardingProgramTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      l10n.onboardingProgramBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SsSpacing.md),
                    for (final day in program.days)
                      Padding(
                        padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: SsColors.emerald500,
                            ),
                            const SizedBox(width: SsSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.dayTitle(day.id, day.title),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${day.exercises.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SsSpacing.section),
              FilledButton.icon(
                onPressed: _saving ? null : _finish,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(l10n.onboardingStart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
