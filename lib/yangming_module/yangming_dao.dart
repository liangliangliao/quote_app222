import 'dart:convert';
import 'dart:math';

import '../data/kv_dao.dart';
import 'yangming_models.dart';
import 'yangming_builtin_contents.dart';

class YangmingDao {
  final KeyValueDao _kv = KeyValueDao();

  static const String _actionsKey = 'yangming_actions_v1';
  static const String _reviewsKey = 'yangming_reviews_v1';
  static const String _doneLessonsKey = 'yangming_done_lessons_v1';
  static const String _lessonContentsKey = 'yangming_lesson_contents_v2_overrides';
  static const String _personaProfileKey = 'yangming_persona_profile_v1';
  static const String _trainingPlansKey = 'yangming_training_plans_v1';
  static const String _trainingTracesKey = 'yangming_training_traces_v1';
  static const String _latestGrowthNavigatorKey = 'yangming_latest_growth_navigator_v1';
  static const String _latestNextCycleKey = 'yangming_latest_next_cycle_v1';
  static const String _latestDailyCockpitKey = 'yangming_latest_daily_cockpit_v1';

  String _id(String prefix) {
    final Random random = Random();
    return '\${prefix}_\${DateTime.now().millisecondsSinceEpoch}_\${random.nextInt(1 << 20)}';
  }

  Future<Map<String, YangmingLessonContent>> _loadStoredOverrides() async {
    final raw = (await _kv.getString(_lessonContentsKey)) ?? '{}';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), YangmingLessonContent.fromJson(Map<String, dynamic>.from(value as Map))));
      }
      if (decoded is List) {
        final items = decoded.whereType<Map>().map((e) => YangmingLessonContent.fromJson(Map<String, dynamic>.from(e))).toList();
        return <String, YangmingLessonContent>{for (final item in items) item.lessonId: item};
      }
    } catch (_) {}
    return <String, YangmingLessonContent>{};
  }

  Future<void> _saveStoredOverrides(Map<String, YangmingLessonContent> overrides) async {
    await _kv.setString(_lessonContentsKey, jsonEncode(overrides.map((key, value) => MapEntry(key, value.toJson()))));
  }


  Future<YangmingPersonaProfile> loadPersonaProfile() async {
    final raw = (await _kv.getString(_personaProfileKey)) ?? '{}';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return YangmingPersonaProfile.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return YangmingPersonaProfile.empty;
  }

  Future<void> savePersonaProfile(YangmingPersonaProfile profile) async {
    await _kv.setString(_personaProfileKey, jsonEncode(profile.toJson()));
  }


  Future<YangmingGrowthNavigatorResult?> loadLatestGrowthNavigator() async {
    final raw = (await _kv.getString(_latestGrowthNavigatorKey)) ?? '{}';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map && decoded.isNotEmpty) {
        return YangmingGrowthNavigatorResult.fromMap(Map<String, dynamic>.from(decoded), raw: raw, source: (decoded['source'] ?? 'persisted').toString());
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestGrowthNavigator(YangmingGrowthNavigatorResult result) async {
    await _kv.setString(_latestGrowthNavigatorKey, jsonEncode(result.toJson()));
  }

  Future<void> clearLatestGrowthNavigator() async {
    await _kv.setString(_latestGrowthNavigatorKey, '{}');
  }


  Future<YangmingDailyCockpitResult?> loadLatestDailyCockpit() async {
    final raw = (await _kv.getString(_latestDailyCockpitKey)) ?? '{}';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map && decoded.isNotEmpty) {
        return YangmingDailyCockpitResult.fromMap(Map<String, dynamic>.from(decoded), raw: raw, source: (decoded['source'] ?? 'persisted').toString());
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestDailyCockpit(YangmingDailyCockpitResult result) async {
    await _kv.setString(_latestDailyCockpitKey, jsonEncode(result.toJson()));
  }

  Future<void> clearLatestDailyCockpit() async {
    await _kv.setString(_latestDailyCockpitKey, '{}');
  }

  Future<YangmingNextCycleRecommendationResult?> loadLatestNextCycleRecommendation() async {
    final raw = (await _kv.getString(_latestNextCycleKey)) ?? '{}';
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map && decoded.isNotEmpty) {
        return YangmingNextCycleRecommendationResult.fromMap(Map<String, dynamic>.from(decoded), raw: raw);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveLatestNextCycleRecommendation(YangmingNextCycleRecommendationResult result) async {
    await _kv.setString(_latestNextCycleKey, jsonEncode(result.toJson()));
  }

  Future<void> clearLatestNextCycleRecommendation() async {
    await _kv.setString(_latestNextCycleKey, '{}');
  }

  Future<List<YangmingTrainingTrace>> loadTrainingTraces() async {
    final raw = (await _kv.getString(_trainingTracesKey)) ?? '[]';
    return decodeJsonList(raw).map(YangmingTrainingTrace.fromJson).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<YangmingTrainingTrace> loadTrainingTrace(YangmingTrainingPlan plan) async {
    final items = await loadTrainingTraces();
    final found = items.where((e) => e.planId == plan.id).cast<YangmingTrainingTrace?>().firstWhere((e) => e != null, orElse: () => null);
    if (found == null) return YangmingTrainingTrace.emptyForPlan(plan);
    if (found.days.length == plan.dailyTasks.length) return found;
    final normalized = <YangmingTrainingDayCheckin>[];
    for (int i = 0; i < plan.dailyTasks.length; i++) {
      final existing = found.days.where((d) => d.dayIndex == i + 1).cast<YangmingTrainingDayCheckin?>().firstWhere((e) => e != null, orElse: () => null);
      normalized.add(existing?.copyWith(task: plan.dailyTasks[i]) ?? YangmingTrainingDayCheckin(dayIndex: i + 1, task: plan.dailyTasks[i], done: false, fact: '', reflection: '', checkedAt: ''));
    }
    return found.copyWith(days: normalized);
  }

  Future<void> saveTrainingTrace(YangmingTrainingTrace trace) async {
    final items = await loadTrainingTraces();
    final idx = items.indexWhere((e) => e.planId == trace.planId);
    if (idx >= 0) {
      items[idx] = trace;
    } else {
      items.insert(0, trace);
    }
    await _kv.setString(_trainingTracesKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<YangmingTrainingPlan>> loadTrainingPlans() async {
    final raw = (await _kv.getString(_trainingPlansKey)) ?? '[]';
    return decodeJsonList(raw).map(YangmingTrainingPlan.fromJson).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveTrainingPlan(YangmingTrainingPlan plan) async {
    final items = await loadTrainingPlans();
    final idx = items.indexWhere((e) => e.id == plan.id);
    if (idx >= 0) {
      items[idx] = plan;
    } else {
      items.insert(0, plan);
    }
    await _kv.setString(_trainingPlansKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> markTrainingPlanDone(String id, bool done) async {
    final items = await loadTrainingPlans();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(status: done ? 'done' : 'active', updatedAt: DateTime.now().toIso8601String());
    await _kv.setString(_trainingPlansKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<Map<String, YangmingLessonContent>> loadLessonContents() async {
    final builtIn = await loadBuiltInYangmingLessonContents();
    final overrides = await _loadStoredOverrides();
    return <String, YangmingLessonContent>{...builtIn, ...overrides};
  }

  Future<YangmingLessonContent?> loadLessonContent(String lessonId) async {
    final map = await loadLessonContents();
    return map[lessonId];
  }

  Future<void> saveLessonContent(YangmingLessonContent content) async {
    final overrides = await _loadStoredOverrides();
    if (content.hasAnyContent) {
      overrides[content.lessonId] = content;
    } else {
      overrides.remove(content.lessonId);
    }
    await _saveStoredOverrides(overrides);
  }

  Future<void> saveLessonContentsBulk(List<YangmingLessonContent> contents) async {
    final overrides = await _loadStoredOverrides();
    for (final item in contents) {
      if (item.hasAnyContent) {
        overrides[item.lessonId] = item;
      }
    }
    await _saveStoredOverrides(overrides);
  }

  Future<void> deleteLessonContent(String lessonId) async {
    final overrides = await _loadStoredOverrides();
    overrides.remove(lessonId);
    await _saveStoredOverrides(overrides);
  }

  Future<List<YangmingAction>> loadActions() async {
    final raw = (await _kv.getString(_actionsKey)) ?? '[]';
    return decodeJsonList(raw).map(YangmingAction.fromJson).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveAction(YangmingAction action) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == action.id);
    if (idx >= 0) {
      items[idx] = action;
    } else {
      items.insert(0, action);
    }
    await _kv.setString(_actionsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> markActionDone(String id, bool done) async {
    final items = await loadActions();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final updated = items[idx].copyWith(status: done ? 'done' : 'doing', updatedAt: DateTime.now().toIso8601String());
    items[idx] = updated;
    await _kv.setString(_actionsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<List<YangmingReviewEntry>> loadReviews() async {
    final raw = (await _kv.getString(_reviewsKey)) ?? '[]';
    return decodeJsonList(raw).map(YangmingReviewEntry.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveReview(YangmingReviewEntry review) async {
    final items = await loadReviews();
    items.insert(0, review);
    await _kv.setString(_reviewsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<Set<String>> loadCompletedLessons() async {
    final raw = (await _kv.getString(_doneLessonsKey)) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> markLessonCompleted(String lessonId) async {
    final set = await loadCompletedLessons();
    set.add(lessonId);
    await _kv.setString(_doneLessonsKey, jsonEncode(set.toList()));
  }

  YangmingAction createAction({
    required String lessonId,
    required String lessonTitle,
    required String taskTitle,
    required String instruction,
    required String source,
    String fact = '',
    String diagnosisSummary = '',
    String nextStepSuggestion = '',
    String reviewQuestion = '',
    String lessonRecommendationId = '',
    String lessonRecommendationTitle = '',
    String lastAiDiagnosisAt = '',
  }) {
    final now = DateTime.now().toIso8601String();
    return YangmingAction(
      id: _id('ya'),
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      taskTitle: taskTitle,
      instruction: instruction,
      status: 'todo',
      createdAt: now,
      updatedAt: now,
      source: source,
      fact: fact,
      diagnosisSummary: diagnosisSummary,
      nextStepSuggestion: nextStepSuggestion,
      reviewQuestion: reviewQuestion,
      lessonRecommendationId: lessonRecommendationId,
      lessonRecommendationTitle: lessonRecommendationTitle,
      lastAiDiagnosisAt: lastAiDiagnosisAt,
    );
  }

  YangmingTrainingPlan createTrainingPlan({
    required String lessonId,
    required String lessonTitle,
    required int durationDays,
    required String planTheme,
    required String planSummary,
    required List<String> dailyTasks,
    required List<String> guardrails,
    required List<String> checkpoints,
    required List<String> reviewPrompts,
    String source = 'ai_training_plan',
  }) {
    final now = DateTime.now().toIso8601String();
    return YangmingTrainingPlan(
      id: _id('ytp'),
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      durationDays: durationDays,
      planTheme: planTheme,
      planSummary: planSummary,
      dailyTasks: dailyTasks,
      guardrails: guardrails,
      checkpoints: checkpoints,
      reviewPrompts: reviewPrompts,
      status: 'active',
      source: source,
      createdAt: now,
      updatedAt: now,
    );
  }

  YangmingReviewEntry createReview({
    required String lessonId,
    required String lessonTitle,
    required String fact,
    required String reflection,
    required String aiSummary,
  }) {
    return YangmingReviewEntry(
      id: _id('yr'),
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      fact: fact,
      reflection: reflection,
      aiSummary: aiSummary,
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}
