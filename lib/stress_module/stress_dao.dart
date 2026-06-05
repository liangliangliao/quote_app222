import 'dart:convert';

import '../data/kv_dao.dart';
import 'stress_models.dart';

class StressDao {
  static const String _actionsKey = 'stress_module_actions_v1';
  static const String _reviewsKey = 'stress_module_reviews_v1';
  static const String _progressKey = 'stress_module_progress_v1';
  static const String _latestInsightKey = 'stress_module_latest_insight_v1';
  static const String _personaKey = 'stress_module_persona_v1';
  static const String _sceneSessionsKey = 'stress_module_scene_sessions_v1';
  static const String _growthReportKey = 'stress_module_growth_report_v1';
  static const String _weeklyReportKey = 'stress_module_weekly_report_v1';
  static const String _monthlyReportKey = 'stress_module_monthly_report_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<List<StressAction>> loadActions() async {
    final raw = await _kv.getString(_actionsKey);
    final items = List<StressAction>.from(stressActionsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveAction(StressAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
    } else {
      items.add(action);
    }
    await _kv.setString(_actionsKey, stressActionsToString(items));
  }

  Future<void> updateAction(StressAction action) async => saveAction(action);

  Future<void> markActionStatus(String id, String status) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(status: status);
    await _kv.setString(_actionsKey, stressActionsToString(items));
  }

  Future<List<StressReviewEntry>> loadReviews() async {
    final raw = await _kv.getString(_reviewsKey);
    final items = List<StressReviewEntry>.from(stressReviewsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveReview(StressReviewEntry review) async {
    final items = await loadReviews();
    final idx = items.indexWhere((e) => e.id == review.id);
    if (idx >= 0) {
      items[idx] = review;
    } else {
      items.add(review);
    }
    await _kv.setString(_reviewsKey, stressReviewsToString(items));
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

  Future<StressInsightResult?> loadLatestInsight() async {
    final raw = await _kv.getString(_latestInsightKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) return StressInsightResult.fromJsonMap(Map<String, dynamic>.from(obj));
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestInsight(StressInsightResult insight) async {
    await _kv.setString(_latestInsightKey, jsonEncode(insight.toJson()));
  }

  Future<StressGrowthReport?> loadLatestGrowthReport() async {
    final raw = await _kv.getString(_growthReportKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) return StressGrowthReport.fromJsonMap(Map<String, dynamic>.from(obj));
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestGrowthReport(StressGrowthReport report) async {
    await _kv.setString(_growthReportKey, jsonEncode(report.toJson()));
  }

  Future<StressWeeklyReport?> loadLatestWeeklyReport() async {
    final raw = await _kv.getString(_weeklyReportKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) return StressWeeklyReport.fromJsonMap(Map<String, dynamic>.from(obj));
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestWeeklyReport(StressWeeklyReport report) async {
    await _kv.setString(_weeklyReportKey, jsonEncode(report.toJson()));
  }

  Future<StressMonthlyReport?> loadLatestMonthlyReport() async {
    final raw = await _kv.getString(_monthlyReportKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) return StressMonthlyReport.fromJsonMap(Map<String, dynamic>.from(obj));
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestMonthlyReport(StressMonthlyReport report) async {
    await _kv.setString(_monthlyReportKey, jsonEncode(report.toJson()));
  }

  Future<StressPersonaProfile?> loadPersona() async {
    final raw = await _kv.getString(_personaKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map) return StressPersonaProfile.fromJson(Map<String, dynamic>.from(obj));
    } catch (_) {}
    return null;
  }

  Future<void> savePersona(StressPersonaProfile profile) async {
    await _kv.setString(_personaKey, jsonEncode(profile.toJson()));
  }

  Future<List<StressSceneSession>> loadSceneSessions() async {
    final raw = await _kv.getString(_sceneSessionsKey);
    final items = List<StressSceneSession>.from(stressSceneSessionsFromString(raw));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> saveSceneSession(StressSceneSession session) async {
    final items = await loadSceneSessions();
    final idx = items.indexWhere((e) => e.id == session.id);
    if (idx >= 0) {
      items[idx] = session;
    } else {
      items.add(session);
    }
    await _kv.setString(_sceneSessionsKey, stressSceneSessionsToString(items));
  }

}
