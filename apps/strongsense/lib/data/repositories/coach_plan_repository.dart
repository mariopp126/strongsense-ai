import 'package:sembast/sembast.dart';
import 'package:strongsense_core/strongsense_core.dart';

import '../local/app_database.dart';

/// A coach plan as persisted for a session.
class SavedCoachPlan {
  const SavedCoachPlan({required this.plan, required this.generatedAt});

  final CoachPlan plan;
  final DateTime generatedAt;
}

class CoachPlanRepository {
  CoachPlanRepository(this._database);

  final AppDatabase _database;

  StoreRef<String, Map<String, Object?>> get _store =>
      _database.store(AppDatabase.coachPlansStore);

  /// Stable key for the most recent plan, including a plan generated at
  /// check-in before the athlete starts a workout.
  static const String latestKey = 'latest';

  Future<void> save(String sessionId, CoachPlan plan) => _put(sessionId, plan);

  /// Persist [plan] as the latest plan shown in the Coach tab and Home teaser.
  Future<void> saveLatest(CoachPlan plan) => _put(latestKey, plan);

  Future<void> _put(String key, CoachPlan plan) =>
      _store.record(key).put(_database.db, <String, Object?>{
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'plan': plan.toJson(),
      });

  Future<CoachPlan?> forSession(String sessionId) async {
    final value = await _store.record(sessionId).get(_database.db);
    return _decode(value);
  }

  Future<SavedCoachPlan?> latest() async {
    final records = await _store.find(
      _database.db,
      finder: Finder(
        sortOrders: <SortOrder>[SortOrder('generatedAt', false)],
        limit: 1,
      ),
    );
    if (records.isEmpty) {
      return null;
    }
    final value = records.first.value;
    final plan = _decode(value);
    if (plan == null) {
      return null;
    }
    return SavedCoachPlan(
      plan: plan,
      generatedAt:
          DateTime.tryParse('${value['generatedAt']}')?.toLocal() ??
          DateTime.now(),
    );
  }

  Future<void> deleteAll() => _store.delete(_database.db);

  CoachPlan? _decode(Map<String, Object?>? value) {
    if (value == null) {
      return null;
    }
    try {
      final planJson = value['plan'];
      if (planJson is! Map) {
        return null;
      }
      return CoachPlan.fromJson(
        planJson.map((key, entry) => MapEntry(key.toString(), entry)),
      );
    } catch (_) {
      return null;
    }
  }
}
