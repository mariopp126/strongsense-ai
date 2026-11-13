import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/ss_theme.dart';
import 'l10n/app_localizations.dart';
import 'state/providers.dart';

class StrongSenseApp extends ConsumerWidget {
  const StrongSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'StrongSense AI',
      debugShowCheckedModeBanner: false,
      theme: SsTheme.light(),
      darkTheme: SsTheme.dark(),
      themeMode: _themeMode(settings.theme),
      locale: Locale(settings.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.delegates,
      routerConfig: router,
    );
  }

  static ThemeMode _themeMode(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
