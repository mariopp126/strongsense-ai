import 'package:sembast/sembast.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../local/app_database.dart';

class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  static const String _recordKey = 'app';

  Future<AppSettings> load() async {
    final stored = await _database
        .store(AppDatabase.settingsStore)
        .record(_recordKey)
        .get(_database.db);
    if (stored == null) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(stored);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) => _database
      .store(AppDatabase.settingsStore)
      .record(_recordKey)
      .put(_database.db, settings.toJson());

  Future<void> clear() =>
      _database.store(AppDatabase.settingsStore).delete(_database.db);
}
