import 'dart:convert';

import '../data/kv_dao.dart';
import 'goal_setting_models.dart';
import 'goal_setting_remote_sync.dart';

class GoalSettingDao {
  static const _actionsKey = 'goal_setting_module_actions_v1';
  static const _reviewsKey = 'goal_setting_module_reviews_v1';
  static const _progressKey = 'goal_setting_module_progress_v1';
  static const _personaKey = 'goal_setting_module_persona_v1';
  static const _worldKey = 'goal_setting_module_world_v1';
  static const _understandingKey = 'goal_setting_module_understanding_v1';
  static const _actionDraftsKey = 'goal_setting_module_action_drafts_v1';
  static const _factRecordsKey = 'goal_setting_module_fact_records_v1';
  static const _loopInsightsKey = 'goal_setting_module_loop_insights_v1';
  final KeyValueDao _kv = KeyValueDao();
  final GoalSettingRemoteSync _remote = GoalSettingRemoteSync();

  Future<List<GoalSettingAction>> loadActions() async {
    final raw = await _kv.getString(_actionsKey);
    final items = List<GoalSettingAction>.from(actionsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveAction(GoalSettingAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
    } else {
      items.add(action);
    }
    await _kv.setString(_actionsKey, actionsToString(items));
    await _remote.upsertAction(action);
  }

  Future<void> updateAction(GoalSettingAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
      await _kv.setString(_actionsKey, actionsToString(items));
      await _remote.upsertAction(action);
    }
  }

  Future<List<GoalSettingReview>> loadReviews() async {
    final raw = await _kv.getString(_reviewsKey);
    final items = List<GoalSettingReview>.from(reviewsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }


  Future<List<GoalSettingReview>> loadHistoricalClosedLoops({
    required String segmentId,
    required String actionTitle,
  }) async {
    final items = await loadReviews();
    final filtered = items.where((e) {
      if (e.segmentId != segmentId) return false;
      if (e.sourceActionTitle.trim() != actionTitle.trim()) return false;
      final hasAiSummary = e.resultJudgement.trim().isNotEmpty ||
          e.resultReasonAnalysis.trim().isNotEmpty ||
          e.retrospectiveGuidance.trim().isNotEmpty ||
          e.relatedKnowledgeConcepts.isNotEmpty ||
          e.summary.trim().isNotEmpty ||
          e.extraSections.isNotEmpty;
      return hasAiSummary;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> saveReview(GoalSettingReview review) async {
    final items = await loadReviews();
    final fingerprint = _reviewFingerprint(review);
    final idx = items.indexWhere((e) => _reviewFingerprint(e) == fingerprint);
    if (idx >= 0) {
      items[idx] = review;
    } else {
      items.add(review);
    }
    await _kv.setString(_reviewsKey, reviewsToString(items));
  }

  String _reviewFingerprint(GoalSettingReview review) {
    final extra = jsonEncode(review.extraSections);
    return [
      review.segmentId.trim(),
      review.sourceActionTitle.trim(),
      review.fact.trim(),
      review.feeling.trim(),
      review.result.trim(),
      review.summary.trim(),
      review.resultJudgement.trim(),
      review.resultReasonAnalysis.trim(),
      review.strengthsFound.trim(),
      review.weaknessesOrBlindspots.trim(),
      review.patternInduction.trim(),
      review.theoryElevation.trim(),
      review.courseConnection.trim(),
      review.retryPlanTitle.trim(),
      review.retryVisualPlan.trim(),
      review.retryPlan.join('||').trim(),
      extra.trim(),
    ].join('##');
  }



  Future<void> deleteReview(String reviewId) async {
    final items = await loadReviews();
    items.removeWhere((e) => e.id == reviewId);
    await _kv.setString(_reviewsKey, reviewsToString(items));
  }

  Future<void> clearReviews() async {
    await _kv.setString(_reviewsKey, reviewsToString(const <GoalSettingReview>[]));
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

  Future<GoalSettingPersonaProfile?> loadPersona() async {
    final raw = await _kv.getString(_personaKey);
    return personaFromString(raw);
  }

  Future<void> savePersona(GoalSettingPersonaProfile persona) async {
    final raw = personaToString(persona);
    if (raw != null) await _kv.setString(_personaKey, raw);
  }

  Future<GoalSettingWorldState> loadWorldState() async {
    final raw = await _kv.getString(_worldKey);
    return worldStateFromString(raw) ?? GoalSettingWorldState(
      unlockedZones: const <String>['聚焦之塔'],
      currentZone: '聚焦之塔',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> saveWorldState(GoalSettingWorldState state) async {
    final raw = worldStateToString(state);
    if (raw != null) await _kv.setString(_worldKey, raw);
  }



  Future<List<GoalSettingFactRecord>> loadFactRecords({String? actionId}) async {
    final raw = await _kv.getString(_factRecordsKey);
    var items = List<GoalSettingFactRecord>.from(factRecordsFromString(raw));
    if (actionId != null && actionId.trim().isNotEmpty) {
      items = items.where((e) => e.actionId == actionId).toList();
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveFactRecord(GoalSettingFactRecord record) async {
    final items = await loadFactRecords();
    final idx = items.indexWhere((e) => e.id == record.id);
    if (idx >= 0) {
      items[idx] = record;
    } else {
      items.add(record);
    }
    await _kv.setString(_factRecordsKey, factRecordsToString(items));
    await _remote.appendFactRecord(record);
  }



  Future<void> deleteFactRecord(String recordId) async {
    final items = await loadFactRecords();
    items.removeWhere((e) => e.id == recordId);
    await _kv.setString(_factRecordsKey, factRecordsToString(items));
  }

  Future<void> clearFactRecords({String? actionId}) async {
    final items = await loadFactRecords();
    final next = (actionId == null || actionId.trim().isEmpty)
        ? <GoalSettingFactRecord>[]
        : items.where((e) => e.actionId != actionId).toList();
    await _kv.setString(_factRecordsKey, factRecordsToString(next));
  }

  Future<GoalSettingActionLoopInsight?> loadLoopInsight(String actionId) async {
    final map = await _loadObjectMap(_loopInsightsKey);
    final raw = map[actionId];
    if (raw is Map) {
      return GoalSettingActionLoopInsight.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return loopInsightFromString(raw);
    }
    return null;
  }

  Future<void> saveLoopInsight(GoalSettingActionLoopInsight insight) async {
    final map = await _loadObjectMap(_loopInsightsKey);
    map[insight.actionId] = insight.toJson();
    await _kv.setString(_loopInsightsKey, jsonEncode(map));
    await _remote.saveLoopInsight(insight);
  }

  Future<Map<String, dynamic>?> fetchRemoteLoopContext(String actionId) async {
    return _remote.fetchLoopContext(actionId);
  }

  Future<GoalSettingUnderstandingResult?> loadUnderstanding(String segmentId) async {
    final map = await _loadObjectMap(_understandingKey);
    final raw = map[segmentId];
    if (raw is Map) {
      return GoalSettingUnderstandingResult.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return GoalSettingUnderstandingResult.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveUnderstanding(String segmentId, GoalSettingUnderstandingResult result) async {
    final map = await _loadObjectMap(_understandingKey);
    map[segmentId] = result.toJson();
    await _kv.setString(_understandingKey, jsonEncode(map));
  }

  Future<GoalSettingActionDraftBundle?> loadActionDraftBundle(String segmentId) async {
    final map = await _loadObjectMap(_actionDraftsKey);
    final raw = map[segmentId];
    if (raw is Map) {
      return GoalSettingActionDraftBundle.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return GoalSettingActionDraftBundle.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveActionDraftBundle(GoalSettingActionDraftBundle bundle) async {
    final map = await _loadObjectMap(_actionDraftsKey);
    map[bundle.segmentId] = bundle.toJson();
    await _kv.setString(_actionDraftsKey, jsonEncode(map));
  }

  Future<Map<String, dynamic>> _loadObjectMap(String key) async {
    final raw = await _kv.getString(key);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

}
