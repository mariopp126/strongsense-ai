import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/theme/ss_colors.dart';
import 'core/theme/ss_theme.dart';
import 'data/local/app_database.dart';
import 'data/repositories/program_repository.dart';
import 'data/repositories/session_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting();

    final database = await AppDatabase.open();
    final settings = await SettingsRepository(database).load();
    final program = await ProgramRepository(database).loadOrSeed();
    final activeSession = await SessionRepository(database).loadInProgress();

    runApp(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(settings),
          initialProgramProvider.overrideWithValue(program),
          initialActiveSessionProvider.overrideWithValue(activeSession),
        ],
        child: const StrongSenseApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('StrongSense failed to start: $error\n$stackTrace');
    runApp(BootFailureApp(error: error));
  }
}

/// Last-resort screen so a storage/init failure is never a blank page.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrongSense AI',
      debugShowCheckedModeBanner: false,
      theme: SsTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: SsColors.slate900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: SsColors.emerald400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'StrongSense AI could not start',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your local training data was not touched. '
                    'Close and reopen the app; if the problem persists, '
                    'clear the app storage or check the browser console.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SsColors.slate100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      '$error',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: SsColors.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
