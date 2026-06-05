import 'dart:convert';

import '../data/kv_dao.dart';
import 'happiness_models.dart';

class HappinessDao {
  static const _actionsKey = 'happiness_module_actions_v1';
  static const _reviewsKey = 'happiness_module_reviews_v1';
  static const _progressKey = 'happiness_module_progress_v1';
  static const _promptKey = 'happiness_module_prompts_v1';
  final _kv = KeyValueDao();

  Future<List<HappinessAction>> loadActions() async {
    final raw = await _kv.getString(_actionsKey);
    final items = List<HappinessAction>.from(actionsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveAction(HappinessAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
    } else {
      items.add(action);
    }
    await _kv.setString(_actionsKey, actionsToString(items));
  }

  Future<void> markActionDone(String id, bool done) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(status: done ? 'done' : 'todo');
      await _kv.setString(_actionsKey, actionsToString(items));
    }
  }

  Future<List<HappinessReviewEntry>> loadReviews() async {
    final raw = await _kv.getString(_reviewsKey);
    final items = List<HappinessReviewEntry>.from(reviewsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }


  Future<void> updateAction(HappinessAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
      await _kv.setString(_actionsKey, actionsToString(items));
    }
  }

  Future<void> saveReview(HappinessReviewEntry review) async {
    final items = await loadReviews();
    items.add(review);
    await _kv.setString(_reviewsKey, reviewsToString(items));
  }

  Future<Set<String>> loadCompletedUnits() async {
    final raw = await _kv.getString(_progressKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final list = jsonDecode(raw);
      if (list is List) return list.map((e) => '$e').toSet();
    } catch (_) {}
    return <String>{};
  }

  Future<void> markUnitCompleted(String unitId) async {
    final set = await loadCompletedUnits();
    set.add(unitId);
    await _kv.setString(_progressKey, jsonEncode(set.toList()));
  }

  Future<Map<String, String>> loadPrompts() async {
    final raw = await _kv.getString(_promptKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) return obj.map((key, value) => MapEntry('$key', '${value ?? ''}'));
    } catch (_) {}
    return {};
  }

  Future<void> savePrompts(Map<String, String> prompts) async {
    await _kv.setString(_promptKey, jsonEncode(prompts));
  }
}
