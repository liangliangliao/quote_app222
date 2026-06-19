import 'dart:convert';

import '../data/kv_dao.dart';
import 'sustainable_excellence_models.dart';

class SustainableExcellenceDao {
  static const String _casesKey = 'sustainable_excellence_cases_v2';
  static const String _legacyCasesKey = 'sustainable_excellence_cases_v1';
  static const String _reviewsKey = 'sustainable_excellence_reviews_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<List<SustainableExcellenceCase>> loadCases({bool includeArchived = false}) async {
    var raw = await _kv.getString(_casesKey);
    if (raw == null || raw.trim().isEmpty) {
      raw = await _kv.getString(_legacyCasesKey);
    }
    final items = List<SustainableExcellenceCase>.from(sustainableCasesFromString(raw));
    final visible = includeArchived ? items : items.where((e) => !e.isArchived).toList();
    visible.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return visible;
  }

  Future<SustainableExcellenceCase?> findCaseBySourceTodo(String sourceTodoId) async {
    final id = sourceTodoId.trim();
    if (id.isEmpty) return null;
    final items = await loadCases(includeArchived: true);
    for (final item in items) {
      if (item.sourceTodoId == id) return item;
    }
    return null;
  }

  Future<SustainableExcellenceCase?> getCase(String caseId, {bool includeArchived = true}) async {
    final items = await loadCases(includeArchived: includeArchived);
    for (final item in items) {
      if (item.id == caseId) return item;
    }
    return null;
  }

  Future<List<SustainableExcellenceCase>> searchCases(String query, {bool includeArchived = false}) async {
    final q = query.trim().toLowerCase();
    final items = await loadCases(includeArchived: includeArchived);
    if (q.isEmpty) return items;
    return items.where((e) {
      final hay = <String>[
        e.title,
        e.userGoal,
        e.currentStateSummary,
        e.coachMessage,
        e.todoWriteback.nextTodoTitle,
        e.sourceTodoId,
        e.linkedTodoTaskId,
        e.generatedTodoTaskIds.join(' '),
        e.spiralStage,
        e.lastFailureType,
        e.modeDetection.pressureLevel,
        e.modeDetection.perfectionismLevel,
        e.logs.map((l) => '${l.title} ${l.note} ${l.details.join(' ')}').join('\n'),
      ].join('\n').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<List<SustainableDailyReview>> loadReviews() async {
    final items = List<SustainableDailyReview>.from(sustainableReviewsFromString(await _kv.getString(_reviewsKey)));
    items.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return items;
  }

  Future<List<SustainableDailyReview>> loadReviewsByType(String reviewType) async {
    final type = reviewType.trim().isEmpty ? 'daily' : reviewType.trim();
    return (await loadReviews()).where((e) => e.reviewType == type).toList();
  }

  Future<void> deleteReview(String reviewId) async {
    final items = await loadReviews();
    items.removeWhere((e) => e.id == reviewId);
    await _kv.setString(_reviewsKey, sustainableReviewsToString(items));
  }

  Future<void> saveReview(SustainableDailyReview review) async {
    final items = await loadReviews();
    final period = _reviewPeriodKey(review.reviewType, review.createdAtMs);
    items.removeWhere((e) => e.id == review.id || (e.reviewType == review.reviewType && _reviewPeriodKey(e.reviewType, e.createdAtMs) == period));
    items.insert(0, review);
    await _kv.setString(_reviewsKey, sustainableReviewsToString(items.take(80).toList()));
  }

  String _reviewPeriodKey(String type, int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    if (type == 'weekly') {
      final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
      return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveCase(SustainableExcellenceCase item) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == item.id);
    final updated = item.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    if (index >= 0) {
      items[index] = updated;
    } else {
      items.add(updated);
    }
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> deleteCase(String caseId) async {
    final items = await loadCases(includeArchived: true);
    items.removeWhere((e) => e.id == caseId);
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> archiveCase(String caseId) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    items[index] = items[index].copyWith(archivedAtMs: DateTime.now().millisecondsSinceEpoch, updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> restoreCase(String caseId) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    items[index] = items[index].copyWith(archivedAtMs: 0, updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> linkTodo({required String caseId, required String taskId, String sourceTodoId = '', String sourceListId = ''}) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final generated = <String>[...old.generatedTodoTaskIds];
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isNotEmpty) {
      generated.remove(cleanTaskId);
      generated.insert(0, cleanTaskId);
    }
    items[index] = old.copyWith(
      linkedTodoTaskId: cleanTaskId,
      generatedTodoTaskIds: generated.take(20).toList(),
      sourceTodoId: sourceTodoId.trim().isEmpty ? null : sourceTodoId,
      sourceListId: sourceListId.trim().isEmpty ? null : sourceListId,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> applyFailureReview(String caseId, Map<String, dynamic> review) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final failureType = (review['failure_type'] ?? old.failureLearning.possibleFailureType).toString();
    final learningPoint = (review['learning_point'] ?? old.failureLearning.learningQuestion).toString();
    final next = (review['next_smaller_experiment'] ?? old.failureLearning.nextSmallerExperiment).toString();
    final strategy = (review['strategy_change'] ?? old.failureLearning.ifFailedThen).toString();
    final todoTitle = (review['todo_writeback_title'] ?? '').toString().trim();
    final rawSteps = review['todo_writeback_steps'];
    final steps = rawSteps is List ? rawSteps.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : old.todoWriteback.nextTodoSteps;
    final repeated = review['is_repeated_pattern'] == true;
    final obstacle = SustainableObstacleAnalysis(
      obstacle: repeated ? '重复失败模式：$failureType' : '失败反馈：$failureType',
      evidence: learningPoint,
      changeableVariable: strategy.trim().isEmpty ? '下一轮只改变一个变量。' : strategy,
    );
    items[index] = old.copyWith(
      failureLearning: SustainableFailureLearning(
        possibleFailureType: failureType,
        ifFailedThen: strategy.trim().isEmpty ? old.failureLearning.ifFailedThen : strategy,
        learningQuestion: learningPoint.trim().isEmpty ? old.failureLearning.learningQuestion : learningPoint,
        nextSmallerExperiment: next.trim().isEmpty ? old.failureLearning.nextSmallerExperiment : next,
      ),
      todoWriteback: SustainableTodoWriteback(
        nextTodoTitle: todoTitle.isEmpty ? '做一次 5 分钟「${old.userGoal}」重新开始实验' : todoTitle,
        nextTodoSteps: steps.isEmpty ? <String>['打开材料', '只做第一小步', '记录一个反馈', '安排微恢复'] : steps,
        parentGoal: old.userGoal,
        statusLabel: repeated ? 'adjusted' : 'reviewed',
        evidenceTags: <String>['失败学习', repeated ? '重复模式' : '新失败样本', '下一轮更小实验'],
      ),
      obstacleAnalysis: <SustainableObstacleAnalysis>[obstacle, ...old.obstacleAnalysis.take(5)],
      lastFailureType: failureType,
      spiralStage: SustainableSpiralStage.failedOrStuck,
      nextRecommendedStage: SustainableSpiralStage.recovery,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> addLog(String caseId, SustainableEvidenceLog log) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final stage = log.spiralStage.trim().isEmpty ? _stageForLog(log.type) : log.spiralStage.trim();
    final normalizedLog = SustainableEvidenceLog(
      id: log.id,
      caseId: log.caseId,
      experimentType: log.experimentType,
      type: log.type,
      title: log.title,
      note: log.note,
      details: log.details,
      spiralStage: stage,
      aiSummary: log.aiSummary,
      generatedTodoId: log.generatedTodoId,
      createdAtMs: log.createdAtMs,
    );
    final logs = <SustainableEvidenceLog>[normalizedLog, ...old.logs];
    items[index] = _applySpiralAfterLog(old.copyWith(logs: logs), normalizedLog);
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> deleteLog(String caseId, String logId) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final logs = old.logs.where((e) => e.id != logId).toList();
    items[index] = old.copyWith(logs: logs, updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> selectExperiment(String caseId, String experimentType) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    items[index] = items[index].copyWith(
      selectedExperimentType: experimentType,
      spiralStage: SustainableSpiralStage.experiment,
      nextRecommendedStage: SustainableSpiralStage.action,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  SustainableExcellenceCase _applySpiralAfterLog(SustainableExcellenceCase item, SustainableEvidenceLog log) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stage = _stageForLog(log.type);
    var cycleCount = item.spiralCycleCount;
    var nextStage = SustainableSpiralStage.next(stage);
    if (log.type == 'restart') {
      cycleCount += 1;
      nextStage = SustainableSpiralStage.completedCycle;
    }
    if (log.type == 'failure_learning') {
      nextStage = SustainableSpiralStage.recovery;
    }
    if (log.type == 'recovery') {
      nextStage = SustainableSpiralStage.adjustment;
    }
    if (log.type == 'process') {
      nextStage = SustainableSpiralStage.adjustment;
    }
    final recentFailures = item.logs.where((e) => e.type == 'failure_learning').take(3).length;
    final repeatedFailure = log.type == 'failure_learning' && recentFailures >= 2;
    return item.copyWith(
      spiralStage: stage,
      spiralCycleCount: cycleCount,
      lastFailureType: log.type == 'failure_learning' ? (log.details.isNotEmpty ? log.details.first.replaceFirst('失败类型：', '') : log.note) : null,
      lastRecoveryAtMs: log.type == 'recovery' ? log.createdAtMs : null,
      lastActionAtMs: log.type == 'action' ? log.createdAtMs : null,
      nextRecommendedStage: repeatedFailure ? SustainableSpiralStage.adjustment : nextStage,
      updatedAtMs: now,
    );
  }

  String _stageForLog(String type) {
    switch (type) {
      case 'action':
        return SustainableSpiralStage.action;
      case 'failure_learning':
        return SustainableSpiralStage.failedOrStuck;
      case 'recovery':
        return SustainableSpiralStage.recovery;
      case 'process':
        return SustainableSpiralStage.feedback;
      case 'restart':
        return SustainableSpiralStage.restart;
      default:
        return SustainableSpiralStage.experiment;
    }
  }


  Future<void> applyPerfectionismScan(String caseId, Map<String, dynamic> scan) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final mode = (scan['mode'] ?? '').toString().toLowerCase();
    final preserve = _stringListFrom(scan['preserve']);
    final adjust = _stringListFrom(scan['adjust']);
    final explanation = (scan['explanation'] ?? '').toString().trim();
    final practices = scan['practices'] is List
        ? (scan['practices'] as List).map((e) => e.toString()).take(4).toList()
        : <String>[];
    items[index] = old.copyWith(
      modeDetection: SustainableModeDetection(
        pressureLevel: old.modeDetection.pressureLevel,
        recoveryLevel: old.modeDetection.recoveryLevel,
        perfectionismLevel: mode.contains('perfection') || adjust.length >= 2 ? 'high' : old.modeDetection.perfectionismLevel,
        failureFearLevel: old.modeDetection.failureFearLevel,
        processConnectionLevel: old.modeDetection.processConnectionLevel,
      ),
      valueMapping: SustainableValueMapping(
        preserve: preserve.isEmpty ? old.valueMapping.preserve : preserve,
        adjust: adjust.isEmpty ? old.valueMapping.adjust : adjust,
        coreReframe: explanation.isEmpty ? old.valueMapping.coreReframe : explanation,
      ),
      reflectionQuestions: <String>[
        ...old.reflectionQuestions,
        if (practices.isNotEmpty) '下一轮完美主义训练：${practices.first}',
      ].take(12).toList(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> applyPressureRecoveryPlan(String caseId, Map<String, dynamic> plan) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final pressure = (plan['pressure_level'] ?? old.modeDetection.pressureLevel).toString();
    final recoveryGap = (plan['recovery_gap'] ?? '').toString();
    final rhythm = (plan['rhythm'] ?? old.recoveryPlan.recommendedRhythm).toString();
    items[index] = old.copyWith(
      modeDetection: SustainableModeDetection(
        pressureLevel: pressure.trim().isEmpty ? old.modeDetection.pressureLevel : pressure,
        recoveryLevel: recoveryGap.contains('severe') ? 'severely_insufficient' : recoveryGap.contains('insufficient') ? 'insufficient' : old.modeDetection.recoveryLevel,
        perfectionismLevel: old.modeDetection.perfectionismLevel,
        failureFearLevel: old.modeDetection.failureFearLevel,
        processConnectionLevel: old.modeDetection.processConnectionLevel,
      ),
      recoveryPlan: SustainableRecoveryPlan(
        microRecovery: _stringListFrom(plan['micro_recovery']).isEmpty ? old.recoveryPlan.microRecovery : _stringListFrom(plan['micro_recovery']),
        mediumRecovery: _stringListFrom(plan['medium_recovery']).isEmpty ? old.recoveryPlan.mediumRecovery : _stringListFrom(plan['medium_recovery']),
        deepRecovery: _stringListFrom(plan['deep_recovery']).isEmpty ? old.recoveryPlan.deepRecovery : _stringListFrom(plan['deep_recovery']),
        recommendedRhythm: rhythm.trim().isEmpty ? old.recoveryPlan.recommendedRhythm : rhythm,
      ),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  Future<void> applyProcessReframe(String caseId, Map<String, dynamic> reframe) async {
    final items = await loadCases(includeArchived: true);
    final index = items.indexWhere((e) => e.id == caseId);
    if (index < 0) return;
    final old = items[index];
    final experiences = _stringListFrom(reframe['one_percent_experience']);
    final afterQuestions = _stringListFrom(reframe['after_action_questions']);
    final during = (reframe['during_action_sentence'] ?? reframe['process_anchor'] ?? old.processEnjoyment.duringActionReminder).toString();
    final value = (reframe['long_term_value'] ?? old.processEnjoyment.meaningConnection).toString();
    items[index] = old.copyWith(
      modeDetection: SustainableModeDetection(
        pressureLevel: old.modeDetection.pressureLevel,
        recoveryLevel: old.modeDetection.recoveryLevel,
        perfectionismLevel: old.modeDetection.perfectionismLevel,
        failureFearLevel: old.modeDetection.failureFearLevel,
        processConnectionLevel: experiences.isEmpty ? old.modeDetection.processConnectionLevel : 'medium',
      ),
      processEnjoyment: SustainableProcessEnjoyment(
        meaningConnection: value.trim().isEmpty ? old.processEnjoyment.meaningConnection : value,
        onePercentExperience: experiences.isEmpty ? old.processEnjoyment.onePercentExperience : experiences.join('；'),
        duringActionReminder: during.trim().isEmpty ? old.processEnjoyment.duringActionReminder : during,
        afterActionReflection: afterQuestions.isEmpty ? old.processEnjoyment.afterActionReflection : afterQuestions.join('；'),
      ),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(_casesKey, sustainableCasesToString(items));
  }

  List<String> _stringListFrom(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) return <String>[raw.trim()];
    return <String>[];
  }

  Future<Map<String, int>> counts() async {
    final cases = await loadCases(includeArchived: false);
    final allCases = await loadCases(includeArchived: true);
    final logs = cases.expand((e) => e.logs).toList();
    int count(String type) => logs.where((e) => e.type == type).length;
    final highPressure = cases.where((e) => e.modeDetection.pressureLevel == 'high' || e.modeDetection.pressureLevel == 'overload').length;
    final highPerfection = cases.where((e) => e.modeDetection.perfectionismLevel == 'high').length;
    final activeCycles = cases.where((e) => e.spiralCycleCount > 0 || e.logs.isNotEmpty).length;
    return <String, int>{
      'cases': cases.length,
      'archived': allCases.where((e) => e.isArchived).length,
      'active_cycles': activeCycles,
      'action': count('action'),
      'failure_learning': count('failure_learning'),
      'recovery': count('recovery'),
      'process': count('process'),
      'restart': count('restart'),
      'high_pressure': highPressure,
      'high_perfection': highPerfection,
    };
  }

  Future<Map<String, int>> trendSnapshot({int days = 7}) async {
    final cases = await loadCases(includeArchived: false);
    final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final logs = cases.expand((e) => e.logs).where((e) => e.createdAtMs >= since).toList();
    int count(String type) => logs.where((e) => e.type == type).length;
    return <String, int>{
      'action': count('action'),
      'failure_learning': count('failure_learning'),
      'recovery': count('recovery'),
      'process': count('process'),
      'restart': count('restart'),
      'days': days,
    };
  }

  Future<int> importCasesJson(String raw) async {
    final incoming = sustainableCasesFromString(raw);
    if (incoming.isEmpty) return 0;
    final items = await loadCases(includeArchived: true);
    for (final item in incoming) {
      final index = items.indexWhere((e) => e.id == item.id);
      if (index >= 0) {
        final local = items[index];
        final mergedLogs = _mergeLogs(local.logs, item.logs);
        if (item.updatedAtMs >= local.updatedAtMs) {
          items[index] = item.copyWith(logs: mergedLogs, updatedAtMs: item.updatedAtMs);
        } else {
          items[index] = local.copyWith(logs: mergedLogs, updatedAtMs: local.updatedAtMs);
        }
      } else {
        items.add(item);
      }
    }
    await _kv.setString(_casesKey, sustainableCasesToString(items));
    return incoming.length;
  }

  List<SustainableEvidenceLog> _mergeLogs(List<SustainableEvidenceLog> a, List<SustainableEvidenceLog> b) {
    final byId = <String, SustainableEvidenceLog>{};
    for (final log in [...a, ...b]) {
      byId[log.id] = log;
    }
    final logs = byId.values.toList()..sort((x, y) => y.createdAtMs.compareTo(x.createdAtMs));
    return logs;
  }

  Future<String> exportFullArchiveJson() async {
    final cases = await loadCases(includeArchived: true);
    final reviews = await loadReviews();
    return jsonEncode(<String, dynamic>{
      'module': 'sustainable_excellence_lab',
      'schema_version': 4,
      'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
      'cases': cases.map((e) => e.toJson()).toList(),
      'reviews': reviews.map((e) => e.toJson()).toList(),
    });
  }

  Future<Map<String, int>> importFullArchiveJson(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return <String, int>{'cases': 0, 'reviews': 0};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['cases'] is List) {
        final cases = (decoded['cases'] as List).map(SustainableExcellenceCase.fromJson).toList();
        final importedCases = await importCasesJson(sustainableCasesToString(cases));
        var importedReviews = 0;
        if (decoded['reviews'] is List) {
          final incomingReviews = (decoded['reviews'] as List).map(SustainableDailyReview.fromJson).toList();
          final local = await loadReviews();
          for (final review in incomingReviews) {
            final index = local.indexWhere((e) => e.id == review.id);
            if (index >= 0) {
              if (review.createdAtMs >= local[index].createdAtMs) local[index] = review;
            } else {
              local.add(review);
            }
          }
          local.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
          await _kv.setString(_reviewsKey, sustainableReviewsToString(local.take(120).toList()));
          importedReviews = incomingReviews.length;
        }
        return <String, int>{'cases': importedCases, 'reviews': importedReviews};
      }
    } catch (_) {}
    final cases = await importCasesJson(text);
    return <String, int>{'cases': cases, 'reviews': 0};
  }

  Future<void> clearAll() async {
    await _kv.setString(_casesKey, '[]');
    await _kv.setString(_reviewsKey, '[]');
  }
}
