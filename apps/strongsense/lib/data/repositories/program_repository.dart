import 'package:sembast/sembast.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../local/app_database.dart';

class ProgramRepository {
  ProgramRepository(this._database);

  final AppDatabase _database;

  static const String _recordKey = 'default';

  Future<TrainingProgram> loadOrSeed() async {
    final stored = await _database
        .store(AppDatabase.programsStore)
        .record(_recordKey)
        .get(_database.db);
    if (stored != null) {
      try {
        return TrainingProgram.fromJson(stored);
      } catch (_) {
        // Corrupt program: fall back to the seed and rewrite it.
      }
    }
    final program = ProgramSeed.powerbuilding();
    await save(program);
    return program;
  }

  Future<void> save(TrainingProgram program) => _database
      .store(AppDatabase.programsStore)
      .record(_recordKey)
      .put(_database.db, program.toJson());
}
