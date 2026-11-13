import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../theme/ss_colors.dart';

/// Responsive navigation: bottom bar on phones, rail on wide screens.
class SsShell extends StatelessWidget {
  const SsShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const List<String> _paths = <String>[
    '/',
    '/coach',
    '/history',
    '/settings',
  ];

  int get _selectedIndex {
    if (location.startsWith('/coach')) {
      return 1;
    }
    if (location.startsWith('/history')) {
      return 2;
    }
    if (location.startsWith('/settings')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= SsSpacing.railBreakpoint;

    final destinations = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      (Icons.auto_awesome_outlined, Icons.auto_awesome, l10n.navCoach),
      (Icons.show_chart_outlined, Icons.show_chart_rounded, l10n.navHistory),
      (Icons.settings_outlined, Icons.settings_rounded, l10n.navSettings),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            _Rail(
              selectedIndex: _selectedIndex,
              destinations: destinations,
              onSelected: (index) => context.go(_paths[index]),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: SsSpacing.contentMaxWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => context.go(_paths[index]),
        destinations: <Widget>[
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.$1),
              selectedIcon: Icon(destination.$2),
              label: destination.$3,
            ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<(IconData, IconData, String)> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 16),
        child: _RailBrand(),
      ),
      destinations: <NavigationRailDestination>[
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.$1),
            selectedIcon: Icon(destination.$2),
            label: Text(destination.$3),
          ),
      ],
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: SsColors.slate900,
        borderRadius: BorderRadius.circular(SsSpacing.radiusMd),
      ),
      child: const Icon(
        Icons.fitness_center_rounded,
        color: SsColors.emerald400,
        size: 22,
      ),
    );
  }
}
