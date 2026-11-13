import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../../core/theme/ss_colors.dart';
import '../../core/widgets/ss_card.dart';
import '../../core/widgets/ss_plan_view.dart';
import '../../core/widgets/ss_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';

class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final latest = ref.watch(latestCoachPlanProvider);
    final history = ref.watch(historyProvider).valueOrNull ?? const <Session>[];

    final readiness = history.isEmpty
        ? null
        : ReadinessEngine.compute(history.first.checkIn);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.coachTitle)),
      body: latest.when(
        loading: () => SsLoading(label: l10n.loading),
        error: (error, stack) => SsEmptyState(
          icon: Icons.auto_awesome_outlined,
          title: l10n.errorGeneric,
          action: FilledButton(
            onPressed: () => context.push('/checkin'),
            child: Text(l10n.coachGoCheckIn),
          ),
        ),
        data: (saved) {
          if (saved == null) {
            return Center(
              child: SsEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: l10n.coachEmpty,
                body: l10n.coachEmptyBody,
                action: FilledButton.icon(
                  onPressed: () => context.push('/checkin'),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(l10n.coachGoCheckIn),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              SsSpacing.lg,
              SsSpacing.lg,
              SsSpacing.lg,
              SsSpacing.section,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    l10n.coachLatestPlan,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    l10n.coachOfflineHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.md),
              SsCard(
                child: CoachPlanView(
                  plan: saved.plan,
                  readiness: readiness,
                  showReadinessCard: readiness != null,
                ),
              ),
              const SizedBox(height: SsSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.push('/checkin'),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.coachGoCheckIn),
              ),
            ],
          );
        },
      ),
    );
  }
}
