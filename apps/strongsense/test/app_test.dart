import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strongsense/app.dart';
import 'package:strongsense/data/local/app_database.dart';
import 'package:strongsense/state/providers.dart';
import 'package:strongsense_core/strongsense_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new users land on onboarding', (tester) async {
    final database = await AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
          initialProgramProvider.overrideWithValue(ProgramSeed.powerbuilding()),
          initialActiveSessionProvider.overrideWithValue(null),
        ],
        child: const StrongSenseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Train smart,\nnot just hard'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await database.close();
  });
}
