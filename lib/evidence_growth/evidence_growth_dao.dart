import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';

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
  }

  Future<RealityTrial> createTrial(EvidenceRouteResult route,
      {required String prediction, required double probability, required DateTime reviewAt}) async {
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
      stretchLevel: route.operator == 'RECOVER' ? 'RECOVERY' : 'STRETCH',
      reversible: true,
      nextRoundPreserved: true,
      createdAtMs: now,
      updatedAtMs: now,
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
    });
    return trial;
  }

  Future<RealityTrial> startTrial(RealityTrial trial) async {
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = trial.copyWith(status: 'IN_PROGRESS', updatedAtMs: now);
    await db.transaction((txn) async {
      await txn.update('evidence_growth_trials', updated.toRow(), where: 'trial_id = ?', whereArgs: [trial.id]);
      for (final node in trial.nodeIds) {
        await _incrementNode(txn, node, used: 1, now: now);
      }
    });
    return updated;
  }

  Future<RealityTrial> captureResult(RealityTrial trial,
      {required bool didAction, required String actualOutcome, required String unexpected}) async {
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = trial.copyWith(
      status: 'RESULT_CAPTURED',
      didAction: didAction,
      actualOutcome: actualOutcome.trim(),
      unexpected: unexpected.trim(),
      updatedAtMs: now,
    );
    await db.transaction((txn) async {
      await txn.update('evidence_growth_trials', updated.toRow(), where: 'trial_id = ?', whereArgs: [trial.id]);
      await txn.insert('evidence_growth_results', {
        'trial_id': trial.id,
        'did_action': didAction ? 1 : 0,
        'actual_outcome': actualOutcome.trim(),
        'unexpected': unexpected.trim(),
        'captured_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (didAction) {
        for (final node in trial.nodeIds) {
          await _incrementNode(txn, node, completed: 1, now: now);
        }
      }
    });
    return updated;
  }

  Future<RealityTrial> saveReview(RealityTrial trial, TrialReviewResult review) async {
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = trial.copyWith(
      status: 'REVIEWED',
      failureClass: review.failureClass,
      learning: review.learning,
      ruleUpdate: review.ruleUpdate,
      nextAction: review.nextChangeOneVariable,
      updatedAtMs: now,
    );
    await db.transaction((txn) async {
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
    });
    return updated;
  }

  Future<RealityTrial> decide(RealityTrial trial,
      {required String decision, required String reason, required String nextAction}) async {
    final normalized = decision.toUpperCase();
    if (!const {'ACT', 'ADJUST', 'EXIT', 'OBSERVE'}.contains(normalized)) {
      throw ArgumentError.value(decision, 'decision');
    }
    await ensureTables();
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = trial.copyWith(status: 'DECIDED', decision: normalized, nextAction: nextAction.trim(), updatedAtMs: now);
    await db.transaction((txn) async {
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
            positive: normalized == 'ACT' ? 1 : 0,
            strategyChanges: normalized == 'ADJUST' ? 1 : 0,
            now: now);
      }
    });
    return updated;
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
        where: "status IN ('READY','IN_PROGRESS','RESULT_CAPTURED','REVIEWED')", orderBy: 'updated_at_ms DESC', limit: limit);
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
      learnedNodes: EvidenceGrowthKnowledge.nodes.length,
      activatedNodes: stats.where((e) => ((e['used_count'] as num?)?.toInt() ?? 0) > 0).length,
      startedTrials: trials.length,
      completedActions: trials.where((e) => e.didAction == true).length,
      failureSamples: trials.where((e) => e.failureClass.isNotEmpty && e.failureClass != 'NO_FAILURE').length,
      strategyChanges: trials.where((e) => e.decision == 'ADJUST').length,
      exits: trials.where((e) => e.decision == 'EXIT').length,
      moduleCounts: counts,
      topNodeIds: stats.take(5).map((e) => (e['node_id'] ?? '').toString()).toList(),
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
        'evidence_growth_router_logs', 'evidence_growth_prompt_runs', 'evidence_growth_trials'
      ]) {
        await txn.delete(table);
      }
    });
  }

  Future<String> exportJson() async {
    await ensureTables();
    final db = await _database();
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'evidence_growth_export_v1',
      'kb_version': EvidenceGrowthKnowledge.kbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'trials': await db.query('evidence_growth_trials', orderBy: 'created_at_ms ASC'),
      'trial_evidence': await db.query('evidence_growth_trial_evidence'),
      'predictions': await db.query('evidence_growth_predictions'),
      'results': await db.query('evidence_growth_results'),
      'reviews': await db.query('evidence_growth_reviews'),
      'decisions': await db.query('evidence_growth_decisions'),
      'personal_node_stats': await db.query('evidence_growth_personal_node_stats'),
    });
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
