import 'dart:convert';

import '../data/kv_dao.dart';
import 'positive_psych_models.dart';

class PositivePsychDao {
  static const _actionsKey = 'positive_psych_module_actions_v1';
  static const _reviewsKey = 'positive_psych_module_reviews_v1';
  static const _progressKey = 'positive_psych_module_progress_v1';
  static const _personaKey = 'positive_psych_module_persona_v1';
  static const _worldKey = 'positive_psych_module_world_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<List<PositivePsychAction>> loadActions() async {
    final raw = await _kv.getString(_actionsKey);
    final items = List<PositivePsychAction>.from(actionsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveAction(PositivePsychAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
    } else {
      items.add(action);
    }
    await _kv.setString(_actionsKey, actionsToString(items));
  }

  Future<void> updateAction(PositivePsychAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
      await _kv.setString(_actionsKey, actionsToString(items));
    }
  }

  Future<List<PositivePsychReview>> loadReviews() async {
    final raw = await _kv.getString(_reviewsKey);
    final items = List<PositivePsychReview>.from(reviewsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveReview(PositivePsychReview review) async {
    final items = await loadReviews();
    items.add(review);
    await _kv.setString(_reviewsKey, reviewsToString(items));
  }

  Future<Set<String>> loadCompletedSegments() async {
    final raw = await _kv.getString(_progressKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final obj = jsonDecode(raw);
      if (obj is List) return obj.map((e) => '$e').toSet();
    } catch (_) {}
    return <String>{};
  }

  Future<void> markSegmentCompleted(String segmentId) async {
    final set = await loadCompletedSegments();
    set.add(segmentId);
    await _kv.setString(_progressKey, jsonEncode(set.toList()));
  }

  Future<PositivePsychPersonaProfile?> loadPersona() async {
    final raw = await _kv.getString(_personaKey);
    return personaFromString(raw);
  }

  Future<void> savePersona(PositivePsychPersonaProfile persona) async {
    final raw = personaToString(persona);
    if (raw != null) await _kv.setString(_personaKey, raw);
  }

  Future<PositivePsychWorldState> loadWorldState() async {
    final raw = await _kv.getString(_worldKey);
    return worldStateFromString(raw) ?? PositivePsychWorldState(
      unlockedNodes: const <String>['解释风格学院'],
      currentNode: '解释风格学院',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> saveWorldState(PositivePsychWorldState state) async {
    final raw = worldStateToString(state);
    if (raw != null) await _kv.setString(_worldKey, raw);
  }
}
