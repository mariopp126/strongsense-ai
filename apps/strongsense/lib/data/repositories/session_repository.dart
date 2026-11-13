import 'package:sembast/sembast.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../local/app_database.dart';

class SessionRepository {
  SessionRepository(this._database);

  final AppDatabase _database;

  StoreRef<String, Map<String, Object?>> get _store =>
      _database.store(AppDatabase.sessionsStore);

  Future<List<Session>> loadAll() async {
    final records = await _store.find(
      _database.db,
      finder: Finder(sortOrders: <SortOrder>[SortOrder('startedAt', false)]),
    );
    return _decode(records);
  }

  Future<List<Session>> loadCompleted() async {
    final records = await _store.find(
      _database.db,
      finder: Finder(
        filter: Filter.equals('status', SessionStatus.completed.wire),
        sortOrders: <SortOrder>[SortOrder('startedAt', false)],
      ),
    );
    return _decode(records);
  }

  Future<Session?> loadInProgress() async {
    final records = await _store.find(
      _database.db,
      finder: Finder(
        filter: Filter.equals('status', SessionStatus.inProgress.wire),
        sortOrders: <SortOrder>[SortOrder('startedAt', false)],
        limit: 1,
      ),
    );
    if (records.isEmpty) {
      return null;
    }
    return _tryDecode(records.first.value, records.first.key);
  }

  Future<Session?> byId(String id) async {
    final value = await _store.record(id).get(_database.db);
    if (value == null) {
      return null;
    }
    return _tryDecode(value, id);
  }

  Future<void> save(Session session) =>
      _store.record(session.id).put(_database.db, session.toJson());

  Future<void> delete(String id) => _store.record(id).delete(_database.db);

  Future<void> deleteAll() => _store.delete(_database.db);

  List<Session> _decode(
    List<RecordSnapshot<String, Map<String, Object?>>> records,
  ) {
    final sessions = <Session>[];
    for (final record in records) {
      final session = _tryDecode(record.value, record.key);
      if (session != null) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  Session? _tryDecode(Map<String, Object?> value, String key) {
    try {
      return Session.fromJson(value);
    } catch (_) {
      // Ignore corrupt records instead of breaking the whole history.
      return null;
    }
  }
}
