import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_operator_registry.dart';

class EvidenceGrowthDao {
  EvidenceGrowthDao({Future<Database> Function()? database})
      : _databaseProvider = database ?? AppDatabase.instance;
  final Future<Database> Function() _databaseProvider;
  Future<void>? _ready;
  Future<Database> _database() => _databaseProvider();
  Future<void> ensureTables() => _ready ??= _createTables();

  Future<void> _createTables() async {
    final db = await _database();
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_trials (
      trial_id TEXT PRIMARY KEY, status TEXT NOT NULL, raw_input TEXT,
      facts_json TEXT NOT NULL DEFAULT '[]', primary_module TEXT NOT NULL,
      secondary_modules_json TEXT NOT NULL DEFAULT '[]', node_ids_json TEXT NOT NULL DEFAULT '[]',
      evidence_level TEXT, ai_inference TEXT, operator TEXT, action_instruction TEXT,
      completion_definition TEXT, prediction TEXT, probability REAL, review_at_ms INTEGER,
      risk_gate TEXT, stretch_level TEXT, reversible INTEGER NOT NULL DEFAULT 1,
      next_round_preserved INTEGER NOT NULL DEFAULT 1, did_action INTEGER,
      actual_outcome TEXT, unexpected TEXT, failure_class TEXT, learning TEXT,
      rule_update TEXT, decision TEXT, next_action TEXT, kb_version TEXT NOT NULL,
      prompt_version TEXT NOT NULL, created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_eg_trials_status ON evidence_growth_trials(status, updated_at_ms DESC)');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_trial_evidence (
      id INTEGER PRIMARY KEY AUTOINCREMENT, trial_id TEXT NOT NULL, node_id TEXT NOT NULL,
      node_version INTEGER NOT NULL, source_class TEXT NOT NULL, evidence_level TEXT NOT NULL,
      rank_no INTEGER NOT NULL, applicability_reason TEXT, source_locator_json TEXT NOT NULL,
      UNIQUE(trial_id, node_id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_predictions (
      trial_id TEXT PRIMARY KEY, statement TEXT NOT NULL, probability REAL NOT NULL,
      window_end_ms INTEGER NOT NULL, created_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_results (
      trial_id TEXT PRIMARY KEY, did_action INTEGER NOT NULL, actual_outcome TEXT NOT NULL,
      unexpected TEXT, captured_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_reviews (
      trial_id TEXT PRIMARY KEY, prediction_original TEXT NOT NULL, prediction_error TEXT,
      failure_class TEXT, learning TEXT, rule_update TEXT, recommendation TEXT,
      next_change_one_variable TEXT, created_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_decisions (
      trial_id TEXT PRIMARY KEY, decision TEXT NOT NULL, reason TEXT, next_action TEXT,
      next_trial_id TEXT, created_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_personal_node_stats (
      node_id TEXT PRIMARY KEY, used_count INTEGER NOT NULL DEFAULT 0,
      completed_count INTEGER NOT NULL DEFAULT 0, positive_outcome_count INTEGER NOT NULL DEFAULT 0,
      strategy_change_count INTEGER NOT NULL DEFAULT 0, last_used_ms INTEGER NOT NULL DEFAULT 0,
      fit_score REAL NOT NULL DEFAULT 0.5)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_router_logs (
      request_id TEXT PRIMARY KEY, raw_input_hash TEXT, candidates_json TEXT NOT NULL,
      selected_json TEXT NOT NULL, required_checks_json TEXT NOT NULL, status TEXT NOT NULL,
      kb_version TEXT NOT NULL, created_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_prompt_runs (
      request_id TEXT PRIMARY KEY, purpose TEXT NOT NULL, prompt_version TEXT NOT NULL,
      provider TEXT, model TEXT, valid_structure INTEGER NOT NULL, error_code TEXT,
      latency_ms INTEGER, created_at_ms INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_settings (
      setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)''');
    await db.transaction((txn) async {
      final columns = (await txn.rawQuery('PRAGMA table_info(evidence_growth_trials)'))
          .map((r) => r['name']).toSet();
      const additions = <String, String>{
        'context_tags_json': "TEXT NOT NULL DEFAULT '[]'",
        'goal_state': "TEXT NOT NULL DEFAULT ''", 'current_state': "TEXT NOT NULL DEFAULT ''",
        'top_gap': "TEXT NOT NULL DEFAULT ''", 'operator_inputs_json': "TEXT NOT NULL DEFAULT '{}'",
        'commitment_level': "TEXT NOT NULL DEFAULT ''", 'worst_case': "TEXT NOT NULL DEFAULT ''",
        'risk_checks_json': "TEXT NOT NULL DEFAULT '{}'", 'result_status': "TEXT NOT NULL DEFAULT ''",
        'stable_context': "TEXT NOT NULL DEFAULT ''", 'shame_signal': 'INTEGER NOT NULL DEFAULT 0',
        'image_exposure_signal': 'INTEGER NOT NULL DEFAULT 0', 'started_at_ms': 'INTEGER NOT NULL DEFAULT 0',
        'result_at_ms': 'INTEGER NOT NULL DEFAULT 0', 'next_review_at_ms': 'INTEGER NOT NULL DEFAULT 0',
        'next_trial_id': "TEXT NOT NULL DEFAULT ''", 'decision_reason': "TEXT NOT NULL DEFAULT ''",
      };
      for (final entry in additions.entries) {
        if (!columns.contains(entry.key)) {
          await txn.execute('ALTER TABLE evidence_growth_trials ADD COLUMN ${entry.key} ${entry.value}');
        }
      }
      final evidenceColumns = (await txn.rawQuery('PRAGMA table_info(evidence_growth_trial_evidence)'))
          .map((r) => r['name']).toSet();
      if (!evidenceColumns.contains('snapshot_json')) {
        await txn.execute("ALTER TABLE evidence_growth_trial_evidence ADD COLUMN snapshot_json TEXT NOT NULL DEFAULT '{}'");
      }
      await txn.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_events (
        event_id INTEGER PRIMARY KEY AUTOINCREMENT, trial_id TEXT NOT NULL,
        event_type TEXT NOT NULL, payload_json TEXT NOT NULL, created_at_ms INTEGER NOT NULL)''');
      await txn.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_learned_nodes (
        node_id TEXT PRIMARY KEY, learned_at_ms INTEGER NOT NULL)''');
      await txn.execute('''CREATE TRIGGER IF NOT EXISTS eg_prediction_immutable
        BEFORE UPDATE ON evidence_growth_predictions BEGIN
        SELECT RAISE(ABORT, 'Original prediction is immutable'); END''');
      await txn.execute('''CREATE TRIGGER IF NOT EXISTS eg_trial_prediction_immutable
        BEFORE UPDATE ON evidence_growth_trials
        WHEN NEW.prediction != OLD.prediction OR NEW.probability != OLD.probability
        BEGIN SELECT RAISE(ABORT, 'Original prediction is immutable'); END''');
      await txn.insert('evidence_growth_settings', {'setting_key': 'schema_version', 'setting_value': '2'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<RealityTrial> createTrial(EvidenceRouteResult route,
      {required String prediction, required double probability, required DateTime reviewAt,
      bool riskConfirmed = false, String goalState = '', String currentState = '',
      String topGap = '', Map<String, String> operatorInputs = const {},
      String commitmentLevel = '', String stretchLevel = 'STRETCH',
      String worstCase = '', String stableContext = '', String previousTrialId = ''}) async {
    if (!route.canAct || route.evidenceLevel == 'E0' || !riskConfirmed ||
        !route.reversible || !route.nextRoundPreserved || stretchLevel == 'PANIC') {
      throw StateError('行动前必须通过证据、前提、Panic、可逆性和下一轮资格检查。');
    }
    if (prediction.trim().isEmpty || !probability.isFinite || probability < 0 || probability > 1) {
      throw ArgumentError('请填写有效预测和 0–100% 概率。');
    }
    final spec = EvidenceGrowthOperatorRegistry.byId(route.operator);
    if (spec.needsCommitment && commitmentLevel.isEmpty) throw ArgumentError('请选择最低有效承诺等级。');
    if (route.selectedNodes.isEmpty || !route.selectedNodes.first.isTal ||
        !route.selectedNodes.any((n) => n.operators.contains(route.operator))) {
      throw StateError('行动缺少已路由的知识依据。');
    }
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'eg_${now}_${DateTime.now().microsecond}';
    final keepRaw = await getSetting('keep_raw_input', fallback: 'true') == 'true';
    final facts = keepRaw
        ? route.facts
        : route.facts.where((fact) => !fact.startsWith('用户原话：')).toList();
    final trial = RealityTrial(
      id: id,
      status: 'READY',
      rawInput: keepRaw ? route.rawInput : '',
      facts: facts,
      primaryModule: route.primaryModule,
      secondaryModules: route.secondaryModules,
      nodeIds: route.selectedNodes.map((e) => e.id).toList(),
      evidenceLevel: route.evidenceLevel,
      inference: route.inference,
      operator: route.operator,
      actionInstruction: route.actionInstruction,
      completionDefinition: route.completionDefinition,
      prediction: prediction.trim(),
      probability: probability.clamp(0, 1).toDouble(),
      reviewAtMs: reviewAt.millisecondsSinceEpoch,
      riskGate: route.riskGate,
      stretchLevel: route.operator == 'RECOVER' ? 'RECOVERY' : stretchLevel,
      reversible: route.reversible,
      nextRoundPreserved: route.nextRoundPreserved,
      createdAtMs: now,
      updatedAtMs: now,
      kbVersion: EvidenceGrowthKnowledge.kbVersion,
      promptVersion: EvidenceGrowthKnowledge.promptVersion,
      contextTags: route.contextTags,
      goalState: goalState.isEmpty ? route.goalState : goalState,
      currentState: currentState.isEmpty ? route.currentState : currentState,
      topGap: topGap.isEmpty ? route.topGap : topGap,
      operatorInputs: operatorInputs,
      commitmentLevel: commitmentLevel,
      worstCase: worstCase,
      stableContext: stableContext,
      riskChecks: {...route.riskChecks, 'USER_PREFLIGHT': 'CONFIRMED',
        'REVERSIBLE': 'YES', 'NEXT_ROUND_PRESERVED': 'YES', 'STRETCH_ZONE': stretchLevel},
    );
    await db.transaction((txn) async {
      await txn.insert('evidence_growth_trials', trial.toRow());
      await txn.insert('evidence_growth_predictions', {
        'trial_id': id,
        'statement': trial.prediction,
        'probability': trial.probability,
        'window_end_ms': trial.reviewAtMs,
        'created_at_ms': now,
      });
      for (var i = 0; i < route.selectedNodes.length; i++) {
        final node = route.selectedNodes[i];
        var reason = '';
        for (final item in route.candidates) {
          if (item.node.id == node.id) reason = item.reason;
        }
        await txn.insert('evidence_growth_trial_evidence', {
          'trial_id': id,
          'node_id': node.id,
          'node_version': node.version,
          'source_class': node.sourceClass,
          'evidence_level': route.evidenceLevel,
          'rank_no': i + 1,
          'applicability_reason': reason,
          'source_locator_json': jsonEncode(node.locator.toJson()),
          'snapshot_json': jsonEncode(node.toJson()),
        });
      }
      await txn.insert('evidence_growth_router_logs', {
        'request_id': id,
        'raw_input_hash': _smallHash(route.rawInput),
        'candidates_json': jsonEncode(route.candidates.map((e) => {'node_id': e.node.id, 'score': e.score, 'reason': e.reason}).toList()),
        'selected_json': jsonEncode(route.selectedNodes.map((e) => e.id).toList()),
        'required_checks_json': jsonEncode(route.requiredChecks),
        'status': route.status,
        'kb_version': EvidenceGrowthKnowledge.kbVersion,
        'created_at_ms': now,
      });
      await _event(txn, id, 'CREATED', {'risk_checks': trial.riskChecks}, now);
      if (previousTrialId.isNotEmpty) {
        final parent = await _current(txn, previousTrialId);
        if (!parent.isClosed || parent.nextTrialId.isNotEmpty) throw StateError('上一轮尚未决策或已连接下一轮。');
        await txn.update('evidence_growth_trials', {'next_trial_id': id},
            where: 'trial_id = ?', whereArgs: [previousTrialId]);
        await txn.update('evidence_growth_decisions', {'next_trial_id': id},
            where: 'trial_id = ?', whereArgs: [previousTrialId]);
        await _event(txn, previousTrialId, 'NEXT_TRIAL_LINKED', {'next_trial_id': id}, now);
      }
    });
    return trial;
  }

  Future<RealityTrial> startTrial(RealityTrial trial) async {
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      final current = await _current(txn, trial.id);
      if (current.status == 'IN_PROGRESS') return current;
      if (current.status != 'READY') throw StateError('只有待开始试验可以启动。');
      final updated = current.copyWith(status: 'IN_PROGRESS', startedAtMs: now, updatedAtMs: now);
      await txn.update('evidence_growth_trials', updated.toRow(), where: 'trial_id = ?', whereArgs: [trial.id]);
      for (final node in trial.nodeIds) {
        await _incrementNode(txn, node, used: 1, now: now);
      }
      await _event(txn, trial.id, 'STARTED', {}, now);
      return updated;
    });
  }

  Future<RealityTrial> captureResult(RealityTrial trial,
      {required bool didAction, required String actualOutcome, required String unexpected,
      String resultStatus = '', Map<String, String> resultMeasurements = const {},
      bool shameSignal = false, bool imageExposureSignal = false}) async {
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = resultStatus.isEmpty ? (didAction ? 'DONE' : 'NOT_DONE') : resultStatus;
    if (!const {'DONE','PARTIAL','NOT_DONE','ABORTED','OBSERVING'}.contains(result) || actualOutcome.trim().isEmpty) {
      throw ArgumentError('结果状态或事实不能为空。');
    }
    return db.transaction((txn) async {
    final current = await _current(txn, trial.id);
    if (!const {'IN_PROGRESS','OBSERVING'}.contains(current.status)) throw StateError('本轮结果已经保存或尚未开始。');
    final updated = current.copyWith(
      status: 'RESULT_CAPTURED',
      didAction: result == 'DONE' || result == 'PARTIAL',
      actualOutcome: actualOutcome.trim(),
      unexpected: unexpected.trim(),
      updatedAtMs: now,
      resultStatus: result, resultAtMs: now,
      operatorInputs: {...current.operatorInputs, ...resultMeasurements},
      shameSignal: shameSignal, imageExposureSignal: imageExposureSignal,
    );
      await txn.update('evidence_growth_trials', updated.toRow(), where: 'trial_id = ?', whereArgs: [trial.id]);
      await txn.insert('evidence_growth_results', {
        'trial_id': trial.id,
        'did_action': didAction ? 1 : 0,
        'actual_outcome': actualOutcome.trim(),
        'unexpected': unexpected.trim(),
        'captured_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (result == 'DONE' && current.resultStatus != 'DONE') {
        for (final node in trial.nodeIds) {
          await _incrementNode(txn, node, completed: 1, now: now);
        }
      }
      await _event(txn, trial.id, 'RESULT_CAPTURED', {'result_status': result,
        'actual_outcome': actualOutcome.trim(), 'measurements': resultMeasurements}, now);
      return updated;
    });
  }

  Future<RealityTrial> saveReview(RealityTrial trial, TrialReviewResult review) async {
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
    final current = await _current(txn, trial.id);
    if (current.status != 'RESULT_CAPTURED') throw StateError('先保存现实结果再复盘。');
    if (review.predictionOriginal != current.prediction ||
        review.knowledgeNodeIds.any((id) => !current.nodeIds.contains(id))) {
      throw StateError('复盘不得改写原预测或引入未引用知识。');
    }
    final updated = current.copyWith(
      status: 'REVIEWED',
      failureClass: review.failureClass,
      learning: review.learning,
      ruleUpdate: review.ruleUpdate,
      nextAction: review.nextChangeOneVariable,
      updatedAtMs: now,
    );
      await txn.update('evidence_growth_trials', updated.toRow(), where: 'trial_id = ?', whereArgs: [trial.id]);
      await txn.insert('evidence_growth_reviews', {
        'trial_id': trial.id,
        'prediction_original': review.predictionOriginal,
        'prediction_error': review.predictionError,
        'failure_class': review.failureClass,
        'learning': review.learning,
        'rule_update': review.ruleUpdate,
        'recommendation': review.decision,
        'next_change_one_variable': review.nextChangeOneVariable,
        'created_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _event(txn, trial.id, 'REVIEWED', {'rule_update': review.ruleUpdate}, now);
      return updated;
    });
  }

  Future<RealityTrial> decide(RealityTrial trial,
      {required String decision, required String reason, required String nextAction, DateTime? nextReviewAt}) async {
    final normalized = decision.toUpperCase();
    if (!const {'ACT', 'ADJUST', 'EXIT', 'OBSERVE'}.contains(normalized)) {
      throw ArgumentError.value(decision, 'decision');
    }
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (reason.trim().isEmpty || nextAction.trim().isEmpty) throw ArgumentError('请保留决定依据与下一动作。');
    return db.transaction((txn) async {
      final current = await _current(txn, trial.id);
      if (current.status != 'REVIEWED') throw StateError('本轮尚未复盘或已决策。');
      final nextAt = (nextReviewAt ?? DateTime.now().add(const Duration(days: 1))).millisecondsSinceEpoch;
      if (normalized == 'OBSERVE' && nextAt <= now) throw ArgumentError('继续观察必须设置未来复盘时间。');
      final updated = current.copyWith(status: normalized == 'OBSERVE' ? 'OBSERVING' : 'DECIDED',
          decision: normalized, decisionReason: reason.trim(), nextAction: nextAction.trim(),
          nextReviewAtMs: normalized == 'OBSERVE' ? nextAt : 0, updatedAtMs: now);
      await txn.update('evidence_growth_trials', updated.toRow(), where: 'trial_id = ?', whereArgs: [trial.id]);
      await txn.insert('evidence_growth_decisions', {
        'trial_id': trial.id,
        'decision': normalized,
        'reason': reason.trim(),
        'next_action': nextAction.trim(),
        'created_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final node in trial.nodeIds) {
        await _incrementNode(txn, node,
            positive: current.operatorInputs['prediction_occurred'] == 'true' ? 1 : 0,
            strategyChanges: normalized == 'ADJUST' ? 1 : 0,
            now: now);
      }
      await _event(txn, trial.id, 'DECIDED', {'decision': normalized, 'reason': reason.trim()}, now);
      return updated;
    });
  }

  Future<void> recordPromptRun({
    required String requestId,
    required String purpose,
    required String provider,
    required String model,
    required bool valid,
    required int latencyMs,
    String errorCode = '',
  }) async {
    await ensureTables();
    final db = await _database();
    await db.insert('evidence_growth_prompt_runs', {
      'request_id': requestId,
      'purpose': purpose,
      'prompt_version': EvidenceGrowthKnowledge.promptVersion,
      'provider': provider,
      'model': model,
      'valid_structure': valid ? 1 : 0,
      'error_code': errorCode,
      'latency_ms': latencyMs,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<RealityTrial?> byId(String id) async {
    await ensureTables();
    final rows = await (await _database()).query('evidence_growth_trials', where: 'trial_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : RealityTrial.fromRow(rows.first);
  }

  Future<List<RealityTrial>> activeTrials({int limit = 5}) async {
    await ensureTables();
    final rows = await (await _database()).query('evidence_growth_trials',
        where: "status IN ('READY','IN_PROGRESS','OBSERVING','RESULT_CAPTURED','REVIEWED')", orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(RealityTrial.fromRow).toList();
  }

  Future<List<RealityTrial>> recentTrials({int limit = 80}) async {
    await ensureTables();
    final rows = await (await _database()).query('evidence_growth_trials', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(RealityTrial.fromRow).toList();
  }

  Future<EvidenceSummary> summary() async {
    await ensureTables();
    final trials = await recentTrials(limit: 1000);
    final stats = await (await _database()).query('evidence_growth_personal_node_stats', orderBy: 'used_count DESC');
    final counts = {for (final module in GrowthModule.values) module: 0};
    for (final trial in trials) {
      counts[trial.primaryModule] = counts[trial.primaryModule]! + 1;
    }
    return EvidenceSummary(
      learnedNodes: (await (await _database()).query('evidence_growth_learned_nodes')).length,
      activatedNodes: stats.where((e) => ((e['used_count'] as num?)?.toInt() ?? 0) > 0).length,
      startedTrials: trials.where((e) => e.startedAtMs > 0 || e.status != 'READY').length,
      completedActions: trials.where((e) => e.resultStatus == 'DONE' || (e.resultStatus.isEmpty && e.didAction == true)).length,
      failureSamples: trials.where((e) => e.failureClass.isNotEmpty && e.failureClass != 'NO_FAILURE').length,
      strategyChanges: trials.where((e) => e.decision == 'ADJUST').length,
      exits: trials.where((e) => e.decision == 'EXIT').length,
      moduleCounts: counts,
      topNodeIds: stats.take(5).map((e) => (e['node_id'] ?? '').toString()).toList(),
      partialActions: trials.where((e) => e.resultStatus == 'PARTIAL').length,
      notDoneActions: trials.where((e) => e.resultStatus == 'NOT_DONE').length,
      abortedActions: trials.where((e) => e.resultStatus == 'ABORTED').length,
      exposureCount: trials.where((e) => e.startedAtMs > 0 && e.operator.contains('EXPOSURE')).length,
      averageRecoveryHours: _mean(trials.map((e) => double.tryParse(e.operatorInputs['recovery_hours'] ?? '')).whereType<double>()),
      calibrationError: _mean(trials.where((e) => const {'true','false'}.contains(e.operatorInputs['prediction_occurred']))
          .map((e) { final delta = e.probability - (e.operatorInputs['prediction_occurred'] == 'true' ? 1 : 0); return delta * delta; })),
      ruleChanges: trials.where((e) => e.ruleUpdate.isNotEmpty).map((e) => e.ruleUpdate).take(10).toList(),
    );
  }

  Future<void> setSetting(String key, String value) async {
    await ensureTables();
    await (await _database()).insert('evidence_growth_settings', {'setting_key': key, 'setting_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> getSetting(String key, {String fallback = ''}) async {
    await ensureTables();
    final rows = await (await _database()).query('evidence_growth_settings', where: 'setting_key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? fallback : (rows.first['setting_value'] ?? fallback).toString();
  }

  Future<void> deletePersonalEvidence() async {
    await ensureTables();
    final db = await _database();
    await db.transaction((txn) async {
      for (final table in const [
        'evidence_growth_trial_evidence', 'evidence_growth_predictions', 'evidence_growth_results',
        'evidence_growth_reviews', 'evidence_growth_decisions', 'evidence_growth_personal_node_stats',
        'evidence_growth_router_logs', 'evidence_growth_prompt_runs', 'evidence_growth_trials',
        'evidence_growth_events', 'evidence_growth_learned_nodes'
      ]) {
        await txn.delete(table);
      }
    });
  }

  Future<String> exportJson() async {
    await ensureTables();
    final db = await _database();
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'evidence_growth_export_v2',
      'kb_version': EvidenceGrowthKnowledge.kbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'trials': await db.query('evidence_growth_trials', orderBy: 'created_at_ms ASC'),
      'trial_evidence': await db.query('evidence_growth_trial_evidence'),
      'predictions': await db.query('evidence_growth_predictions'),
      'results': await db.query('evidence_growth_results'),
      'reviews': await db.query('evidence_growth_reviews'),
      'decisions': await db.query('evidence_growth_decisions'),
      'personal_node_stats': await db.query('evidence_growth_personal_node_stats'),
      'events': await db.query('evidence_growth_events'),
      'learned_nodes': await db.query('evidence_growth_learned_nodes'),
    });
  }

  Future<void> markLearned(String nodeId) async {
    await ensureTables();
    if (EvidenceGrowthKnowledge.byId(nodeId) == null) return;
    await (await _database()).insert('evidence_growth_learned_nodes',
      {'node_id': nodeId, 'learned_at_ms': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, double>> nodeFitScores() async {
    await ensureTables();
    final rows = await (await _database()).query('evidence_growth_personal_node_stats');
    return {for (final row in rows) row['node_id'] as String: (row['fit_score'] as num).toDouble()};
  }

  Future<List<Map<String, Object?>>> timeline(String trialId) async {
    await ensureTables();
    return (await _database()).query('evidence_growth_events', where: 'trial_id = ?',
        whereArgs: [trialId], orderBy: 'event_id ASC');
  }

  Future<List<Map<String, Object?>>> evidenceSnapshots(String trialId) async {
    await ensureTables();
    return (await _database()).query('evidence_growth_trial_evidence', where: 'trial_id = ?', whereArgs: [trialId]);
  }

  Future<RealityTrial> _current(DatabaseExecutor db, String id) async {
    final rows = await db.query('evidence_growth_trials', where: 'trial_id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Trial 不存在');
    return RealityTrial.fromRow(rows.first);
  }

  Future<void> _event(DatabaseExecutor db, String id, String type, Map<String, Object?> payload, int now) async {
    await db.insert('evidence_growth_events', {'trial_id': id, 'event_type': type,
      'payload_json': jsonEncode(payload), 'created_at_ms': now});
  }

  double? _mean(Iterable<double> values) {
    final list = values.where((v) => v.isFinite && v >= 0).toList();
    return list.isEmpty ? null : list.reduce((a,b) => a+b) / list.length;
  }

  Future<void> _incrementNode(DatabaseExecutor db, String nodeId,
      {int used = 0, int completed = 0, int positive = 0, int strategyChanges = 0, required int now}) async {
    final rows = await db.query('evidence_growth_personal_node_stats', where: 'node_id = ?', whereArgs: [nodeId], limit: 1);
    final current = rows.isEmpty ? <String, Object?>{} : rows.first;
    final u = ((current['used_count'] as num?)?.toInt() ?? 0) + used;
    final c = ((current['completed_count'] as num?)?.toInt() ?? 0) + completed;
    final p = ((current['positive_outcome_count'] as num?)?.toInt() ?? 0) + positive;
    final s = ((current['strategy_change_count'] as num?)?.toInt() ?? 0) + strategyChanges;
    final last = (current['last_used_ms'] as num?)?.toInt() ?? 0;
    final completionRate = u == 0 ? 0.0 : c / u;
    final positiveRate = u == 0 ? 0.0 : p / u;
    final repeatability = (c / 3).clamp(0, 1).toDouble();
    final contextFit = u <= 1 ? .5 : (1 - s / u).clamp(0, 1).toDouble();
    final recency = last == 0 ? .5 : (1 - ((now - last) / 86400000) / 30).clamp(0, 1).toDouble();
    final fit = u == 0 ? .5 : (completionRate * .30 + positiveRate * .25 + repeatability * .20 + contextFit * .15 + recency * .10).clamp(0, 1);
    await db.insert('evidence_growth_personal_node_stats', {
      'node_id': nodeId,
      'used_count': u,
      'completed_count': c,
      'positive_outcome_count': p,
      'strategy_change_count': s,
      'last_used_ms': now,
      'fit_score': fit,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _smallHash(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) hash = (hash * 31 + unit) & 0x7fffffff;
    return hash.toRadixString(16);
  }
}
