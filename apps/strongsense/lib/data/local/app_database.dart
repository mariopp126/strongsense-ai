import 'package:sembast/sembast_memory.dart';

import 'database_opener.dart';

/// Thin wrapper around the sembast database with named stores.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const int schemaVersion = 1;

  static const String settingsStore = 'settings';
  static const String programsStore = 'programs';
  static const String sessionsStore = 'sessions';
  static const String coachPlansStore = 'coach_plans';

  static Future<AppDatabase> open() async =>
      AppDatabase(await openPlatformDatabase());

  /// In-memory database used by repository tests.
  static Future<AppDatabase> memory() async => AppDatabase(
    await databaseFactoryMemory.openDatabase('strongsense_test.db'),
  );

  StoreRef<String, Map<String, Object?>> store(String name) =>
      stringMapStoreFactory.store(name);

  Future<void> close() => db.close();
}
