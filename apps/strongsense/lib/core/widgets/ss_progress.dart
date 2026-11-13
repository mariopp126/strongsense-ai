import 'package:flutter/material.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../theme/ss_colors.dart';
import '../utils/formatters.dart';
import '../../l10n/app_localizations.dart';

class SsProgressBar extends StatelessWidget {
  const SsProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color = SsColors.emerald500,
  });

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(SsSpacing.radiusFull),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animated, child) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

class SsBandChip extends StatelessWidget {
  const SsBandChip({super.key, required this.band, this.showAdvice = false});

  final ReadinessBand band;
  final bool showAdvice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.bandLabel(band.wire);
    final color = readinessText(band);
    final background = readinessBackground(band);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SsSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SsSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: readinessColor(band),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            showAdvice ? '$label · ${l10n.bandAdvice(band.wire)}' : label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SsLoading extends StatelessWidget {
  const SsLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SsSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (label != null) ...<Widget>[
              const SizedBox(height: SsSpacing.md),
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class SsBanner extends StatelessWidget {
  const SsBanner({
    super.key,
    required this.message,
    this.color = SsColors.emerald600,
    this.background = SsColors.emerald50,
    this.icon = Icons.check_circle_rounded,
  });

  final String message;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SsSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: SsSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
