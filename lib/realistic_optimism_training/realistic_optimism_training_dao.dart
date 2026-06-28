import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'realistic_optimism_training_models.dart';

class RealisticOptimismTrainingDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> _tryAddColumn(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {
      // Column already exists or migration is not needed.
    }
  }

  String _payloadString(Map<String, dynamic> payload, List<String> path, {String fallback = ''}) {
    dynamic current = payload;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return fallback;
      }
    }
    final text = current?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> ensureTables() async {
    final db = await _db();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_records (
        id TEXT PRIMARY KEY,
        scene TEXT,
        raw_input TEXT,
        intensity_level TEXT,
        primary_emotion TEXT,
        automatic_interpretation TEXT,
        main_pattern TEXT,
        five_minute_action TEXT,
        identity_sentence TEXT,
        provider TEXT,
        model_label TEXT,
        payload_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_records_updated ON realistic_optimism_training_records(updated_at_ms DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_event_intensity (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        level TEXT,
        reason TEXT,
        allowed_interventions_json TEXT,
        blocked_interventions_json TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_process_plans (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        five_minute_action TEXT,
        next_three_steps_json TEXT,
        if_then_plan_json TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_explanation_scores (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        permanence_score INTEGER,
        pervasiveness_score INTEGER,
        personalization_score INTEGER,
        catastrophizing_score INTEGER,
        helplessness_score INTEGER,
        filtering_score INTEGER,
        main_pattern TEXT,
        automatic_interpretation TEXT,
        balanced_reframe TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_benefit_reframes (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        fault_finder_story TEXT,
        benefit_finder_story TEXT,
        not_denied_pain TEXT,
        controllable_actions_json TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_failure_immunity (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        predicted_pain REAL,
        actual_pain REAL,
        predicted_recovery TEXT,
        actual_recovery TEXT,
        psychological_antibody TEXT,
        worst_case_prediction TEXT,
        actual_result TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_controlled_challenges (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        challenge_name TEXT,
        risk_level TEXT,
        safety_boundary TEXT,
        five_minute_action TEXT,
        predicted_pain REAL,
        actual_pain REAL,
        actual_result TEXT,
        recovery_time TEXT,
        lesson TEXT,
        psychological_antibody TEXT,
        challenge_status TEXT,
        planned_at_ms INTEGER,
        user_reflection TEXT,
        next_attempt TEXT,
        completed_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _tryAddColumn(db, 'realistic_optimism_training_failure_immunity', 'worst_case_prediction TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_failure_immunity', 'actual_result TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'risk_level TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'actual_pain REAL');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'actual_result TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'recovery_time TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'lesson TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'completed_at_ms INTEGER');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'challenge_status TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'planned_at_ms INTEGER');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'user_reflection TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'next_attempt TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_savoring_entries (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        moment_title TEXT,
        sensory_detail TEXT,
        body_feeling TEXT,
        meaning TEXT,
        appreciation_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _tryAddColumn(db, 'realistic_optimism_training_savoring_entries', 'body_feeling TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_anti_primes (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        trigger_type TEXT,
        trigger_name TEXT,
        effect TEXT,
        cleanup_action TEXT,
        replacement_prime TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_actions (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        action TEXT,
        evidence_text TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        completed_at_ms INTEGER,
        self_efficacy_score REAL,
        source_type TEXT,
        source_id TEXT,
        todo_task_id TEXT,
        daily_artifact_id TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _tryAddColumn(db, 'realistic_optimism_training_actions', 'completed_at_ms INTEGER');
    await _tryAddColumn(db, 'realistic_optimism_training_actions', 'self_efficacy_score REAL');
    await _tryAddColumn(db, 'realistic_optimism_training_actions', 'source_type TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_actions', 'source_id TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_actions', 'todo_task_id TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_actions', 'daily_artifact_id TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_actions_record ON realistic_optimism_training_actions(record_id, created_at_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_actions_source ON realistic_optimism_training_actions(source_type, source_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_baselines (
        id TEXT PRIMARY KEY,
        ts_ms INTEGER NOT NULL,
        happiness_score REAL,
        recovery_score REAL,
        agency_score REAL,
        permanence_frequency REAL,
        gratitude_sensitivity REAL,
        action_stability REAL,
        note TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_baselines_time ON realistic_optimism_training_baselines(ts_ms DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_gratitude_entries (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        concrete_gratitude TEXT,
        why_matters TEXT,
        appreciation_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_relationship_gratitude (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        person TEXT,
        context TEXT,
        light_text TEXT,
        concrete_text TEXT,
        deep_text TEXT,
        chosen_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_primes (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        value_word TEXT,
        reminder TEXT,
        widget_text TEXT,
        benefit_question TEXT,
        anti_prime_cleanup_action TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL
      )
    ''');



    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_p2_artifacts (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        artifact_type TEXT,
        title TEXT,
        trigger_text TEXT,
        trigger_condition TEXT,
        summary TEXT,
        reuse_surface TEXT,
        content_json TEXT,
        next_action TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'trigger_condition TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'summary TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'reuse_surface TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'source_type TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'source_id TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'target_type TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'target_id TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'status TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'scheduled_at_ms INTEGER');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'completed_at_ms INTEGER');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'dismissed_count INTEGER DEFAULT 0');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'last_triggered_at_ms INTEGER');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'linked_session_id TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'linked_record_id TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'safety_level TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_p2_artifacts', 'timezone TEXT');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_p2_source ON realistic_optimism_training_p2_artifacts(source_type, source_id, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_p2_target ON realistic_optimism_training_p2_artifacts(target_type, target_id, status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_sessions (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        current_step INTEGER NOT NULL DEFAULT 0,
        initial_scene TEXT,
        entry_scene TEXT,
        level TEXT,
        intensity REAL,
        emotion TEXT,
        body_signal TEXT,
        event_text TEXT,
        fact_text TEXT,
        unknown_text TEXT,
        interpretation_text TEXT,
        controllable_text TEXT,
        action_text TEXT,
        obstacle_text TEXT,
        if_then_text TEXT,
        action_completed INTEGER NOT NULL DEFAULT 1,
        evidence_text TEXT,
        gratitude_text TEXT,
        prime_text TEXT,
        identity_text TEXT,
        linked_record_id TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_sessions_status ON realistic_optimism_training_sessions(status, updated_at_ms DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_value_source_anchors (
        id TEXT PRIMARY KEY,
        source_name TEXT,
        chapter_or_lecture TEXT,
        original_excerpt TEXT,
        summary TEXT,
        core_value TEXT,
        used_in_scenes TEXT,
        prompt_instruction TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_identity_evidence (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        source_type TEXT,
        identity_type TEXT,
        evidence_text TEXT,
        identity_sentence TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
  }

  Future<void> upsertRecord(RealisticOptimismTrainingRecord record) async {
    final db = await _db();
    await ensureTables();
    await db.transaction((txn) async {
      final isSafetyRouted = record.intensityLevel == 'L3' || record.intensityLevel == 'L4';
      final isFailureScene = record.scene == 'failure_immunity' || record.scene == 'controlled_failure_challenge' || record.scene == 'psychological_immunity_experiment';
      final isGratitudeScene = <String>{'gratitude_savoring', 'complete_reality', 'appreciation_scan', 'gratitude_time_in'}.contains(record.scene);
      final isDailyReviewScene = record.scene == 'daily_review';
      final writesGratitudeAndSavoring = isGratitudeScene || isDailyReviewScene;
      final isPrimeScene = <String>{'prime_design', 'anti_prime_cleanup', 'priming_diagnostic', 'identity_script_activation'}.contains(record.scene);
      final isP2Scene = <String>{'todo_goal_bridge', 'daily_review', 'course_card', 'role_model_case', 'proactive_reminder', 'monthly_report', 'complete_reality', 'appreciation_scan', 'same_reality_interpretations', 'loss_resource_retention', 'priming_diagnostic', 'identity_script_activation', 'gratitude_time_in', 'process_simulation_check', 'psychological_immunity_experiment'}.contains(record.scene);
      await txn.insert(
        'realistic_optimism_training_records',
        record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'realistic_optimism_training_event_intensity',
        <String, Object?>{
          'id': 'rot_ei_${record.id}',
          'record_id': record.id,
          'level': record.intensityLevel,
          'reason': record.intensityReason,
          'allowed_interventions_json': jsonEncode(record.allowedInterventions),
          'blocked_interventions_json': jsonEncode(record.blockedInterventions),
          'created_at_ms': record.createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (record.fiveMinuteAction.isNotEmpty || record.nextThreeSteps.isNotEmpty || record.ifThenPlan.isNotEmpty) {
        await txn.insert(
          'realistic_optimism_training_process_plans',
          <String, Object?>{
            'id': 'rot_pp_${record.id}',
            'record_id': record.id,
            'five_minute_action': record.fiveMinuteAction,
            'next_three_steps_json': jsonEncode(record.nextThreeSteps),
            'if_then_plan_json': jsonEncode(record.ifThenPlan),
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'realistic_optimism_training_explanation_scores',
        <String, Object?>{
          'id': 'rot_x_${record.id}',
          'record_id': record.id,
          'permanence_score': record.permanenceScore,
          'pervasiveness_score': record.pervasivenessScore,
          'personalization_score': record.personalizationScore,
          'catastrophizing_score': record.catastrophizingScore,
          'helplessness_score': record.helplessnessScore,
          'filtering_score': record.filteringScore,
          'main_pattern': record.mainPattern,
          'automatic_interpretation': record.automaticInterpretation,
          'balanced_reframe': record.balancedInterpretation,
          'created_at_ms': record.createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (!isSafetyRouted && (record.faultFinderStory.isNotEmpty || record.balancedInterpretation.isNotEmpty)) {
        await txn.insert(
          'realistic_optimism_training_benefit_reframes',
          <String, Object?>{
            'id': 'rot_br_${record.id}',
            'record_id': record.id,
            'fault_finder_story': record.faultFinderStory,
            'benefit_finder_story': record.balancedInterpretation,
            'not_denied_pain': record.notDeniedPain,
            'controllable_actions_json': jsonEncode(record.controllableActions),
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && isFailureScene && (record.psychologicalAntibody.isNotEmpty || record.predictedRecovery.isNotEmpty || record.actualRecovery.isNotEmpty || record.predictedPain != null || record.actualPain != null)) {
        await txn.insert(
          'realistic_optimism_training_failure_immunity',
          <String, Object?>{
            'id': 'rot_fi_${record.id}',
            'record_id': record.id,
            'predicted_pain': record.predictedPain,
            'actual_pain': record.actualPain,
            'predicted_recovery': record.predictedRecovery,
            'actual_recovery': record.actualRecovery,
            'psychological_antibody': record.psychologicalAntibody,
            'worst_case_prediction': _payloadString(record.payload, <String>['failure_immunity', 'worst_case_prediction']),
            'actual_result': _payloadString(record.payload, <String>['failure_immunity', 'actual_result']),
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && record.scene == 'controlled_failure_challenge') {
        await txn.insert(
          'realistic_optimism_training_controlled_challenges',
          <String, Object?>{
            'id': 'rot_cfc_${record.id}',
            'record_id': record.id,
            'challenge_name': record.eventSummary.isEmpty ? record.rawInput : record.eventSummary,
            'risk_level': _payloadString(record.payload, <String>['controlled_failure_challenge', 'risk_level'], fallback: 'low'),
            'safety_boundary': record.finalUserMessage,
            'five_minute_action': record.fiveMinuteAction,
            'predicted_pain': record.predictedPain,
            'psychological_antibody': record.psychologicalAntibody,
            'challenge_status': 'planned',
            'planned_at_ms': record.createdAtMs,
            'user_reflection': '',
            'next_attempt': record.fiveMinuteAction,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && writesGratitudeAndSavoring && (record.savoringPrompt.isNotEmpty || record.smallAppreciationAction.isNotEmpty || record.whatStillMatters.isNotEmpty)) {
        await txn.insert(
          'realistic_optimism_training_savoring_entries',
          <String, Object?>{
            'id': 'rot_sv_${record.id}',
            'record_id': record.id,
            'moment_title': record.whatStillMatters.isEmpty ? '一个值得停留的时刻' : record.whatStillMatters.first,
            'sensory_detail': record.savoringPrompt,
            'body_feeling': _payloadString(record.payload, <String>['gratitude_or_savoring', 'body_feeling'], fallback: record.primaryEmotion),
            'meaning': record.possibleMeaning.join('；'),
            'appreciation_action': record.smallAppreciationAction,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && <String>{'anti_prime_cleanup', 'priming_diagnostic'}.contains(record.scene) && record.antiPrimeCleanupAction.isNotEmpty) {
        await txn.insert(
          'realistic_optimism_training_anti_primes',
          <String, Object?>{
            'id': 'rot_ap_${record.id}',
            'record_id': record.id,
            'trigger_type': record.scene == 'anti_prime_cleanup' ? '用户描述的环境启动源' : '未分类',
            'trigger_name': record.rawInput,
            'effect': record.behavioralEffect,
            'cleanup_action': record.antiPrimeCleanupAction,
            'replacement_prime': record.lockScreenSentence,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && writesGratitudeAndSavoring && (record.whatStillMatters.isNotEmpty || record.smallAppreciationAction.isNotEmpty || record.savoringPrompt.isNotEmpty)) {
        await txn.insert(
          'realistic_optimism_training_gratitude_entries',
          <String, Object?>{
            'id': 'rot_g_${record.id}',
            'record_id': record.id,
            'concrete_gratitude': jsonEncode(record.whatStillMatters),
            'why_matters': record.savoringPrompt,
            'appreciation_action': record.smallAppreciationAction,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && writesGratitudeAndSavoring && record.smallAppreciationAction.isNotEmpty) {
        final rawRelationship = record.payload['relationship_gratitude'];
        final relationship = rawRelationship is Map ? Map<String, dynamic>.from(rawRelationship) : <String, dynamic>{};
        final person = (relationship['person'] ?? '').toString().trim().isNotEmpty
            ? relationship['person'].toString().trim()
            : (record.rawInput.contains('人') ? '一个值得感谢的人' : '未指定对象');
        final context = (relationship['context'] ?? '').toString().trim().isNotEmpty ? relationship['context'].toString().trim() : record.rawInput;
        await txn.insert(
          'realistic_optimism_training_relationship_gratitude',
          <String, Object?>{
            'id': 'rot_rg_${record.id}',
            'record_id': record.id,
            'person': person,
            'context': context,
            'light_text': (relationship['light_text'] ?? '').toString().trim().isNotEmpty ? relationship['light_text'].toString().trim() : '今天想到你之前的支持，还是想说谢谢。',
            'concrete_text': (relationship['concrete_text'] ?? '').toString().trim().isNotEmpty ? relationship['concrete_text'].toString().trim() : '你做的那件事对我很重要，我没有把它当成理所当然。谢谢你。',
            'deep_text': (relationship['deep_text'] ?? '').toString().trim().isNotEmpty ? relationship['deep_text'].toString().trim() : '我以前可能没有认真表达过，但你的支持让我感到被看见。我想让你知道，我记得，也很珍惜。',
            'chosen_action': (relationship['chosen_action'] ?? '').toString().trim().isNotEmpty ? relationship['chosen_action'].toString().trim() : record.smallAppreciationAction,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && isPrimeScene && (record.dailyValueWord.isNotEmpty || record.lockScreenSentence.isNotEmpty || record.antiPrimeCleanupAction.isNotEmpty)) {
        await txn.insert(
          'realistic_optimism_training_primes',
          <String, Object?>{
            'id': 'rot_p_${record.id}',
            'record_id': record.id,
            'value_word': record.dailyValueWord,
            'reminder': record.lockScreenSentence,
            'widget_text': record.lockScreenSentence,
            'benefit_question': record.benefitFinderQuestion,
            'anti_prime_cleanup_action': record.antiPrimeCleanupAction,
            'active': 1,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && isP2Scene) {
        final p2 = record.payload['p2_delivery'];
        final p2Map = p2 is Map ? Map<String, dynamic>.from(p2) : <String, dynamic>{};
        await txn.insert(
          'realistic_optimism_training_p2_artifacts',
          <String, Object?>{
            'id': 'rot_p2_${record.id}',
            'record_id': record.id,
            'artifact_type': record.scene,
            'title': (p2Map['title'] ?? '').toString().trim().isNotEmpty ? p2Map['title'].toString().trim() : (record.eventSummary.isEmpty ? record.scene : record.eventSummary),
            'trigger_text': record.rawInput,
            'trigger_condition': (p2Map['trigger_condition'] ?? '').toString().trim(),
            'summary': (p2Map['summary'] ?? '').toString().trim(),
            'reuse_surface': (p2Map['reuse_surface'] ?? '').toString().trim(),
            'content_json': jsonEncode(p2Map.isEmpty ? record.payload : p2Map),
            'next_action': record.fiveMinuteAction.isEmpty ? record.finalUserMessage : record.fiveMinuteAction,
            'active': 1,
            'created_at_ms': record.createdAtMs,
            'source_type': 'ai_scene',
            'source_id': record.id,
            'target_type': 'artifact',
            'target_id': 'rot_p2_${record.id}',
            'status': 'active',
            'scheduled_at_ms': null,
            'completed_at_ms': null,
            'dismissed_count': 0,
            'last_triggered_at_ms': null,
            'linked_session_id': '',
            'linked_record_id': record.id,
            'safety_level': record.intensityLevel,
            'timezone': '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (!isSafetyRouted && (record.identitySentence.isNotEmpty || record.provedCapacity.isNotEmpty)) {
        await txn.insert(
          'realistic_optimism_training_identity_evidence',
          <String, Object?>{
            'id': 'rot_i_${record.id}',
            'record_id': record.id,
            'source_type': record.scene,
            'identity_type': record.identityType,
            'evidence_text': record.provedCapacity,
            'identity_sentence': record.identitySentence,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<RealisticOptimismTrainingRecord>> listRecords({int limit = 80}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_training_records', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map(RealisticOptimismTrainingRecord.fromRow).toList();
  }

  Future<RealisticOptimismTrainingRecord?> getRecord(String id) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_training_records', where: 'id=?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return RealisticOptimismTrainingRecord.fromRow(rows.first);
  }

  Future<void> deleteRecord(String id) async {
    final db = await _db();
    await ensureTables();
    await db.transaction((txn) async {
      await txn.delete('realistic_optimism_training_actions', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_event_intensity', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_process_plans', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_explanation_scores', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_benefit_reframes', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_failure_immunity', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_controlled_challenges', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_savoring_entries', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_anti_primes', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_gratitude_entries', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_relationship_gratitude', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_primes', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_p2_artifacts', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_identity_evidence', where: 'record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_sessions', where: 'linked_record_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_training_records', where: 'id=?', whereArgs: <Object?>[id]);
    });
  }

  Future<void> clearAll() async {
    final db = await _db();
    await ensureTables();
    await db.transaction((txn) async {
      await txn.delete('realistic_optimism_training_actions');
      await txn.delete('realistic_optimism_training_event_intensity');
      await txn.delete('realistic_optimism_training_process_plans');
      await txn.delete('realistic_optimism_training_explanation_scores');
      await txn.delete('realistic_optimism_training_benefit_reframes');
      await txn.delete('realistic_optimism_training_failure_immunity');
      await txn.delete('realistic_optimism_training_controlled_challenges');
      await txn.delete('realistic_optimism_training_savoring_entries');
      await txn.delete('realistic_optimism_training_anti_primes');
      await txn.delete('realistic_optimism_training_baselines');
      await txn.delete('realistic_optimism_training_gratitude_entries');
      await txn.delete('realistic_optimism_training_relationship_gratitude');
      await txn.delete('realistic_optimism_training_primes');
      await txn.delete('realistic_optimism_training_p2_artifacts');
      await txn.delete('realistic_optimism_training_identity_evidence');
      await txn.delete('realistic_optimism_training_sessions');
      await txn.delete('realistic_optimism_training_records');
    });
  }

  Future<void> addActionEvidence(RealisticOptimismTrainingActionEvidence evidence) async {
    final db = await _db();
    await ensureTables();
    await db.insert('realistic_optimism_training_actions', evidence.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }


  Future<void> addIdentityEvidence({
    required String sourceType,
    required String identityType,
    required String evidenceText,
    required String identitySentence,
    String recordId = '',
    String? id,
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeId = (id == null || id.trim().isEmpty) ? 'rot_identity_${sourceType.hashCode.abs()}_${evidenceText.hashCode.abs()}' : id.trim();
    await db.insert(
      'realistic_optimism_training_identity_evidence',
      <String, Object?>{
        'id': safeId,
        'record_id': recordId,
        'source_type': sourceType,
        'identity_type': identityType,
        'evidence_text': evidenceText,
        'identity_sentence': identitySentence,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addAttentionPrime({
    required String valueWord,
    required String reminder,
    required String widgetText,
    required String benefitQuestion,
    String antiPrimeCleanupAction = '',
    String recordId = '',
    String? id,
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeId = (id == null || id.trim().isEmpty) ? 'rot_prime_manual_${reminder.hashCode.abs()}' : id.trim();
    await db.insert(
      'realistic_optimism_training_primes',
      <String, Object?>{
        'id': safeId,
        'record_id': recordId,
        'value_word': valueWord,
        'reminder': reminder,
        'widget_text': widgetText,
        'benefit_question': benefitQuestion,
        'anti_prime_cleanup_action': antiPrimeCleanupAction,
        'active': 1,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addAntiPrimeCleanup({
    required String triggerType,
    required String triggerName,
    required String effect,
    required String cleanupAction,
    required String replacementPrime,
    String recordId = '',
    String? id,
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeId = (id == null || id.trim().isEmpty) ? 'rot_antiprime_manual_${triggerName.hashCode.abs()}_${cleanupAction.hashCode.abs()}' : id.trim();
    await db.insert(
      'realistic_optimism_training_anti_primes',
      <String, Object?>{
        'id': safeId,
        'record_id': recordId,
        'trigger_type': triggerType,
        'trigger_name': triggerName,
        'effect': effect,
        'cleanup_action': cleanupAction,
        'replacement_prime': replacementPrime,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RealisticOptimismTrainingActionEvidence>> listActionEvidence(String recordId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'realistic_optimism_training_actions',
      where: 'record_id=?',
      whereArgs: <Object?>[recordId],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(RealisticOptimismTrainingActionEvidence.fromRow).toList();
  }



  Future<List<RealisticOptimismTrainingActionEvidence>> listAllActionEvidence({int limit = 80}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'realistic_optimism_training_actions',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(RealisticOptimismTrainingActionEvidence.fromRow).toList();
  }
  Future<void> addBaseline(RealisticOptimismTrainingBaseline baseline) async {
    final db = await _db();
    await ensureTables();
    await db.insert('realistic_optimism_training_baselines', baseline.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RealisticOptimismTrainingBaseline>> listBaselines({int limit = 24}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_training_baselines', orderBy: 'ts_ms DESC', limit: limit);
    return rows.map(RealisticOptimismTrainingBaseline.fromRow).toList();
  }


  Future<List<Map<String, Object?>>> listEventIntensity({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_event_intensity', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<List<Map<String, Object?>>> listProcessPlans({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_process_plans', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<List<Map<String, Object?>>> listFailureImmunity({String? recordId, int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query(
      'realistic_optimism_training_failure_immunity',
      where: recordId == null ? null : 'record_id=?',
      whereArgs: recordId == null ? null : <Object?>[recordId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> listControlledChallenges({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_controlled_challenges', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<List<Map<String, Object?>>> listRelationshipGratitude({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_relationship_gratitude', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<List<Map<String, Object?>>> listPrimes({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_primes', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<List<Map<String, Object?>>> listAntiPrimes({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_anti_primes', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<void> addFailureRecoveryReview({
    required String recordId,
    required double actualPain,
    required String actualRecovery,
    required String psychologicalAntibody,
    String actualResult = '',
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'realistic_optimism_training_failure_immunity',
      <String, Object?>{
        'id': 'rot_fi_review_${recordId}_$now',
        'record_id': recordId,
        'predicted_pain': null,
        'actual_pain': actualPain,
        'predicted_recovery': '',
        'actual_recovery': actualRecovery,
        'psychological_antibody': psychologicalAntibody.isEmpty ? actualResult : psychologicalAntibody,
        'actual_result': actualResult,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateControlledChallengeReview({
    required String recordId,
    required double actualPain,
    required String actualResult,
    required String recoveryTime,
    required String lesson,
    required String psychologicalAntibody,
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query('realistic_optimism_training_controlled_challenges', where: 'record_id=?', whereArgs: <Object?>[recordId], limit: 1);
    final row = <String, Object?>{
      'actual_pain': actualPain,
      'actual_result': actualResult,
      'recovery_time': recoveryTime,
      'lesson': lesson,
      'psychological_antibody': psychologicalAntibody,
      'challenge_status': 'completed',
      'user_reflection': lesson,
      'next_attempt': '下次继续选择低风险、可恢复的小挑战。',
      'completed_at_ms': now,
    };
    if (existing.isEmpty) {
      await db.insert(
        'realistic_optimism_training_controlled_challenges',
        <String, Object?>{
          'id': 'rot_cfc_manual_${recordId}_$now',
          'record_id': recordId,
          'challenge_name': '手动复盘的可控失败挑战',
          'safety_boundary': '低风险、可恢复、不伤害自己或他人。',
          'five_minute_action': '',
          'predicted_pain': null,
          ...row,
          'created_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update('realistic_optimism_training_controlled_challenges', row, where: 'record_id=?', whereArgs: <Object?>[recordId]);
    }
  }

  Future<void> addRelationshipGratitude({
    required String person,
    required String context,
    required String lightText,
    required String concreteText,
    required String deepText,
    required String chosenAction,
    String recordId = '',
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'realistic_optimism_training_relationship_gratitude',
      <String, Object?>{
        'id': 'rot_rg_manual_$now',
        'record_id': recordId,
        'person': person,
        'context': context,
        'light_text': lightText,
        'concrete_text': concreteText,
        'deep_text': deepText,
        'chosen_action': chosenAction,
        'created_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listP2Artifacts({int limit = 40}) async {
    final db = await _db();
    await ensureTables();
    return db.query('realistic_optimism_training_p2_artifacts', orderBy: 'created_at_ms DESC', limit: limit);
  }

  Future<List<Map<String, Object?>>> listDailyArtifactsLinkedToRecord(String recordId, {int limit = 10}) async {
    final db = await _db();
    await ensureTables();
    if (recordId.trim().isEmpty) return <Map<String, Object?>>[];
    return db.query(
      'realistic_optimism_training_p2_artifacts',
      where: 'record_id=? OR linked_record_id=? OR source_id=?',
      whereArgs: <Object?>[recordId, recordId, recordId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getDailyArtifact(String id) async {
    final db = await _db();
    await ensureTables();
    if (id.trim().isEmpty) return null;
    final rows = await db.query('realistic_optimism_training_p2_artifacts', where: 'id=?', whereArgs: <Object?>[id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertDailyExtensionArtifact({
    required String artifactType,
    required String title,
    required String triggerText,
    required String triggerCondition,
    required String summary,
    required String reuseSurface,
    required String nextAction,
    Map<String, Object?> content = const <String, Object?>{},
    String recordId = '',
    String sourceType = '',
    String sourceId = '',
    String targetType = '',
    String targetId = '',
    String status = 'active',
    int? scheduledAtMs,
    int? completedAtMs,
    int dismissedCount = 0,
    int? lastTriggeredAtMs,
    String linkedSessionId = '',
    String linkedRecordId = '',
    String safetyLevel = 'L1',
    String timezone = '',
    String? artifactId,
  }) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeType = artifactType.trim().isEmpty ? 'daily_extension' : artifactType.trim();
    final safeId = artifactId?.trim().isNotEmpty == true
        ? artifactId!.trim()
        : 'rot_de_${safeType}_${sourceId.trim().isEmpty ? now.toString() : sourceId.trim().hashCode.abs().toString()}_${now}';
    await db.insert(
      'realistic_optimism_training_p2_artifacts',
      <String, Object?>{
        'id': safeId,
        'record_id': recordId,
        'artifact_type': safeType,
        'title': title.trim().isEmpty ? '日常实践产物' : title.trim(),
        'trigger_text': triggerText,
        'trigger_condition': triggerCondition,
        'summary': summary,
        'reuse_surface': reuseSurface,
        'content_json': jsonEncode(content),
        'next_action': nextAction,
        'active': <String>{'archived', 'abandoned', 'paused_for_safety', 'superseded', 'completed', 'failed'}.contains(status) ? 0 : 1,
        'created_at_ms': now,
        'source_type': sourceType,
        'source_id': sourceId,
        'target_type': targetType,
        'target_id': targetId,
        'status': status,
        'scheduled_at_ms': scheduledAtMs,
        'completed_at_ms': completedAtMs,
        'dismissed_count': dismissedCount,
        'last_triggered_at_ms': lastTriggeredAtMs,
        'linked_session_id': linkedSessionId,
        'linked_record_id': linkedRecordId.isNotEmpty ? linkedRecordId : recordId,
        'safety_level': safetyLevel,
        'timezone': timezone,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> findOpenDailyExtensionBySource({
    required String artifactType,
    required String sourceType,
    required String sourceId,
  }) async {
    final db = await _db();
    await ensureTables();
    if (sourceId.trim().isEmpty) return null;
    final rows = await db.query(
      'realistic_optimism_training_p2_artifacts',
      where: "artifact_type=? AND source_type=? AND source_id=? AND COALESCE(status,'active') IN ('draft','active','scheduled') AND COALESCE(active,1)=1",
      whereArgs: <Object?>[artifactType, sourceType, sourceId],
      orderBy: 'created_at_ms DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }


  Future<void> supersedeOpenDailyArtifactsByType({
    required String artifactType,
    String sourceType = '',
    String sourceId = '',
  }) async {
    final db = await _db();
    await ensureTables();
    final args = <Object?>[artifactType];
    var where = "artifact_type=? AND COALESCE(status,'active') IN ('draft','active','scheduled') AND COALESCE(active,1)=1";
    if (sourceType.trim().isNotEmpty) {
      where += ' AND source_type=?';
      args.add(sourceType.trim());
    }
    if (sourceId.trim().isNotEmpty) {
      where += ' AND source_id=?';
      args.add(sourceId.trim());
    }
    await db.update(
      'realistic_optimism_training_p2_artifacts',
      <String, Object?>{'status': 'superseded', 'active': 0},
      where: where,
      whereArgs: args,
    );
  }

  Future<List<String>> pauseOrdinaryDailyArtifactsForSafety(String level) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'realistic_optimism_training_p2_artifacts',
      columns: <String>['target_type', 'target_id'],
      where: "artifact_type IN ('todo_goal_bridge','daily_review','proactive_reminder','anti_prime_cleanup') AND COALESCE(status,'active') IN ('draft','active','scheduled','needs_review') AND COALESCE(active,1)=1",
    );
    await db.update(
      'realistic_optimism_training_p2_artifacts',
      <String, Object?>{
        'status': 'paused_for_safety',
        'active': 0,
        'last_triggered_at_ms': now,
        'safety_level': level,
      },
      where: "artifact_type IN ('todo_goal_bridge','daily_review','proactive_reminder','anti_prime_cleanup') AND COALESCE(status,'active') IN ('draft','active','scheduled','needs_review') AND COALESCE(active,1)=1",
    );
    return rows
        .where((row) => (row['target_type'] ?? '').toString() == 'todo_task')
        .map((row) => (row['target_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> updateDailyExtensionArtifactStatus({
    required String id,
    required String status,
    int? completedAtMs,
    int? lastTriggeredAtMs,
    int? dismissedCount,
    String nextAction = '',
    Map<String, Object?>? mergeContent,
  }) async {
    final db = await _db();
    await ensureTables();
    final row = <String, Object?>{
      'status': status,
      'active': <String>{'archived', 'abandoned', 'paused_for_safety', 'superseded', 'completed', 'failed'}.contains(status) ? 0 : 1,
    };
    if (completedAtMs != null) row['completed_at_ms'] = completedAtMs;
    if (lastTriggeredAtMs != null) row['last_triggered_at_ms'] = lastTriggeredAtMs;
    if (dismissedCount != null) row['dismissed_count'] = dismissedCount;
    if (nextAction.trim().isNotEmpty) row['next_action'] = nextAction.trim();
    if (mergeContent != null) {
      final old = await db.query('realistic_optimism_training_p2_artifacts', columns: <String>['content_json'], where: 'id=?', whereArgs: <Object?>[id], limit: 1);
      final content = <String, Object?>{};
      if (old.isNotEmpty) {
        try {
          final decoded = jsonDecode((old.first['content_json'] ?? '{}').toString());
          if (decoded is Map) content.addAll(Map<String, Object?>.from(decoded));
        } catch (_) {}
      }
      content.addAll(mergeContent);
      row['content_json'] = jsonEncode(content);
    }
    await db.update('realistic_optimism_training_p2_artifacts', row, where: 'id=?', whereArgs: <Object?>[id]);
  }


  Future<void> upsertSession(RealisticOptimismTrainingSession session) async {
    final db = await _db();
    await ensureTables();
    await db.insert('realistic_optimism_training_sessions', session.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<RealisticOptimismTrainingSession?> getSession(String id) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_training_sessions', where: 'id=?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return RealisticOptimismTrainingSession.fromRow(rows.first);
  }

  Future<List<RealisticOptimismTrainingSession>> listOpenSessions({int limit = 8}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'realistic_optimism_training_sessions',
      where: "status IN ('draft','active','safety_routed')",
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(RealisticOptimismTrainingSession.fromRow).toList();
  }

  Future<void> abandonSession(String id) async {
    final db = await _db();
    await ensureTables();
    await db.update(
      'realistic_optimism_training_sessions',
      <String, Object?>{'status': 'abandoned', 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id=?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> completeSession({required String sessionId, required String recordId}) async {
    final db = await _db();
    await ensureTables();
    await db.update(
      'realistic_optimism_training_sessions',
      <String, Object?>{'status': 'completed', 'linked_record_id': recordId, 'current_step': 3, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id=?',
      whereArgs: <Object?>[sessionId],
    );
  }

  Future<void> seedValueSourceAnchors() async {
    final db = await _db();
    await ensureTables();
    for (final obsoleteId in <String>[
      'ROT_EXPLAIN_SELIGMAN_BIONDI',
      'ROT_FAILURE_IMMUNITY',
      'ROT_PRIME_ENVIRONMENT',
      'ROT_GRATITUDE_IDENTITY',
    ]) {
      await db.delete(
        'realistic_optimism_training_value_source_anchors',
        where: 'id=?',
        whereArgs: <Object?>[obsoleteId],
      );
    }
    const anchors = <RotValueSourceAnchor>[
      RotValueSourceAnchor(
        id: 'ROT_EXPLAIN_SAME_REALITY',
        sourceName: 'Lecture 7 same reality, different interpretations',
        chapterOrLecture: '解释风格与 Tal 失败故事',
        originalExcerpt: 'Lecture 7 强调 optimism 是 interpretation style。Tal 的项目失败、博士项目被淘汰、资格考试失败，都展示同一现实可以被解释为羞辱，也可以成为训练、谦卑和未来能力来源。',
        summary: '把一次挫折从“这定义了我”拉回“这是一个具体现实，我仍能选择下一步解释和行动”。',
        coreValue: '乐观是解释风格；不让痛苦垄断全部解释权。',
        usedInScenes: 'reality_record,event_reframe,explanation_radar,dual_lens,failure_immunity,same_reality_interpretations,loss_resource_retention',
        promptInstruction: '必须帮助用户区分现实事件与自动解释，并给出更完整、更现实、更有行动可能的替代表达。',
      ),
      RotValueSourceAnchor(
        id: 'ROT_ACTION_EFFICACY_IMMUNITY',
        sourceName: 'Lecture 7 Bandura self-efficacy / psychological immune system',
        chapterOrLecture: '行动证据、自我效能与心理免疫',
        originalExcerpt: 'Lecture 7 强调自信不是口号，而是来自努力、应对、失败、恢复和小成功。失败像心理疫苗，经历失败并恢复会形成心理抗体。',
        summary: '行动产生证据，证据塑造信念；失败通过预测、实际、恢复和下次行动进入心理免疫训练。',
        coreValue: '行动优先于口号；失败是心理免疫训练。',
        usedInScenes: 'reality_record,failure_immunity,controlled_failure_challenge,process_action,event_reframe,todo_goal_bridge,psychological_immunity_experiment,process_simulation_check',
        promptInstruction: '未完成时不要判定人格失败，必须转成可恢复、可缩小、可复盘的下一步；不要给空泛肯定。',
      ),
      RotValueSourceAnchor(
        id: 'ROT_ATTENTION_PRIMING',
        sourceName: 'Lecture 8 Bargh / professor-hooligan priming',
        chapterOrLecture: '注意力创造现实 / 环境启动',
        originalExcerpt: 'Lecture 8 通过 Bargh 词语启动和 professor / hooligan 角色启动说明：词语、图像、角色原型和环境会改变行为表现。',
        summary: '注意力启动线索不是口号，而是放在真实环境中的词语、照片、桌面、待办、锁屏或空间线索；消极启动源会启动逃避、比较和无力。',
        coreValue: '注意力创造现实；用环境支持解释和行动。',
        usedInScenes: 'reality_record,prime_design,anti_prime_cleanup,process_action,identity_evidence,proactive_reminder,priming_diagnostic,identity_script_activation',
        promptInstruction: '注意力启动线索必须具体到锁屏句、桌面、待办事项、提醒、空间线索或社交环境。',
      ),
      RotValueSourceAnchor(
        id: 'ROT_GRATITUDE_FULL_REALITY',
        sourceName: 'Lecture 9 祖母故事 / 感恩静心分享',
        chapterOrLecture: '感恩是完整现实感',
        originalExcerpt: 'Lecture 9 前半段通过祖母故事和 感恩静心分享 说明：真正的资源发现不是 脱离现实的快乐主义，而是在极端苦难中仍不遗漏生命中的好；不被珍惜的东西，会在心理上贬值。',
        summary: '感恩不是否认痛苦，而是不让痛苦遮蔽生命中的善；必须具体到人、物、画面、关系、身体感受和珍惜行动。',
        coreValue: '感恩是高级现实感；不遗漏好的部分。',
        usedInScenes: 'gratitude_savoring,identity_evidence,weekly_baseline,event_reframe,daily_review,complete_reality,appreciation_scan,gratitude_time_in',
        promptInstruction: '感恩必须具体到人、物、画面、关系或行动；高强度痛苦时先稳定，不强行感恩。',
      ),
    ];
    for (final anchor in anchors) {
      await db.insert('realistic_optimism_training_value_source_anchors', anchor.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<RotValueSourceAnchor>> listValueSourceAnchors() async {
    final db = await _db();
    await ensureTables();
    await seedValueSourceAnchors();
    final rows = await db.query('realistic_optimism_training_value_source_anchors', orderBy: 'id ASC');
    return rows.map(RotValueSourceAnchor.fromRow).toList();
  }

  Future<void> upsertDeterministicArtifactsFromSession({required RealisticOptimismTrainingSession session, required String recordId}) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    final isSafetyRouted = session.level == 'L3' || session.level == 'L4';
    await db.transaction((txn) async {
      await txn.insert('realistic_optimism_training_event_intensity', <String, Object?>{
        'id': 'rot_session_ei_${session.id}',
        'record_id': recordId,
        'level': session.level,
        'reason': '来自核心训练会话的用户自评强度：${session.intensity.round()}/10，情绪：${session.emotion}。',
        'allowed_interventions_json': jsonEncode(isSafetyRouted ? <String>['情绪稳定', '现实支持', '安全行动'] : <String>['情绪允许', '事实解释分离', '行动预演', '复盘沉淀']),
        'blocked_interventions_json': jsonEncode(isSafetyRouted ? <String>['强行积极', '强行感恩', '失败挑战'] : <String>['空泛鸡汤', '否认痛苦']),
        'created_at_ms': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (!isSafetyRouted) {
        await txn.insert('realistic_optimism_training_explanation_scores', <String, Object?>{
          'id': 'rot_session_x_${session.id}',
          'record_id': recordId,
          'permanence_score': session.interpretationText.contains('永远') || session.interpretationText.contains('一直') ? 8 : 4,
          'pervasiveness_score': session.interpretationText.contains('都') || session.interpretationText.contains('什么') ? 7 : 4,
          'personalization_score': session.interpretationText.contains('我不行') || session.interpretationText.contains('我很差') || session.interpretationText.contains('废') ? 8 : 5,
          'catastrophizing_score': session.interpretationText.contains('完了') || session.interpretationText.contains('肯定') ? 8 : 4,
          'helplessness_score': session.interpretationText.contains('没办法') || session.interpretationText.contains('无法') ? 8 : 4,
          'filtering_score': 6,
          'main_pattern': '来自会话的自动解释：检查永久化、普遍化、人格化、灾难化、无力化、过滤化。',
          'automatic_interpretation': session.interpretationText,
          'balanced_reframe': '承认痛苦，但把解释拉回事实、可控点和下一步行动。',
          'created_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('realistic_optimism_training_benefit_reframes', <String, Object?>{
          'id': 'rot_session_br_${session.id}',
          'record_id': recordId,
          'fault_finder_story': session.interpretationText,
          'benefit_finder_story': '这件事确实不舒服，但它不是全部现实；现在仍可控制：${session.controllableText}',
          'not_denied_pain': '情绪被承认：${session.emotion}，身体感受：${session.bodySignal}。',
          'controllable_actions_json': jsonEncode(<String>[session.actionText, session.controllableText]),
          'created_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('realistic_optimism_training_process_plans', <String, Object?>{
          'id': 'rot_session_pp_${session.id}',
          'record_id': recordId,
          'five_minute_action': session.actionText,
          'next_three_steps_json': jsonEncode(<String>[session.actionText, '完成后记录证据', '明天用注意力启动线索 继续启动']),
          'if_then_plan_json': jsonEncode(<String>[session.ifThenText, '如果仍卡住，就把行动缩小到 2 分钟。']),
          'created_at_ms': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        if (!session.actionCompleted) {
          await txn.insert('realistic_optimism_training_failure_immunity', <String, Object?>{
            'id': 'rot_session_fi_${session.id}',
            'record_id': recordId,
            'predicted_pain': session.intensity,
            'actual_pain': session.intensity,
            'predicted_recovery': '行动前担心会继续卡住。',
            'actual_recovery': '通过复盘把行动缩小，保留重新开始的入口。',
            'psychological_antibody': session.evidenceText.isEmpty ? '没完成不是人格失败，而是流程需要继续缩小。' : session.evidenceText,
            'worst_case_prediction': session.obstacleText,
            'actual_result': '本次会话选择未完成分支，记录卡点并进入失败免疫。',
            'created_at_ms': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (session.gratitudeText.isNotEmpty) {
          await txn.insert('realistic_optimism_training_gratitude_entries', <String, Object?>{
            'id': 'rot_session_g_${session.id}',
            'record_id': recordId,
            'concrete_gratitude': jsonEncode(<String>[session.gratitudeText]),
            'why_matters': '不让痛苦遮蔽全部现实。',
            'appreciation_action': '停留 30 秒品味这个具体事实。',
            'created_at_ms': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          await txn.insert('realistic_optimism_training_savoring_entries', <String, Object?>{
            'id': 'rot_session_sv_${session.id}',
            'record_id': recordId,
            'moment_title': session.gratitudeText,
            'sensory_detail': '具体回看这个仍值得珍惜的事实：${session.gratitudeText}',
            'meaning': '完整现实感',
            'appreciation_action': '停留 30 秒。',
            'created_at_ms': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (session.primeText.isNotEmpty) {
          await txn.insert('realistic_optimism_training_primes', <String, Object?>{
            'id': 'rot_session_p_${session.id}',
            'record_id': recordId,
            'value_word': '行动证据',
            'reminder': session.primeText,
            'widget_text': session.primeText,
            'benefit_question': '这件事里，我还剩下哪个可控点？',
            'anti_prime_cleanup_action': session.obstacleText.isEmpty ? '移除一个最强干扰入口。' : session.obstacleText,
            'active': 1,
            'created_at_ms': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (session.identityText.isNotEmpty || session.evidenceText.isNotEmpty) {
          await txn.insert('realistic_optimism_training_identity_evidence', <String, Object?>{
            'id': 'rot_session_i_${session.id}',
            'record_id': recordId,
            'source_type': 'core_business_session',
            'identity_type': session.actionCompleted ? '行动证据积累者' : '失败后恢复者',
            'evidence_text': session.evidenceText.isEmpty ? session.actionText : session.evidenceText,
            'identity_sentence': session.identityText,
            'created_at_ms': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<RealisticOptimismTrainingStats> stats() async {
    final db = await _db();
    await ensureTables();
    Future<int> count(String table) async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM $table')) ?? 0;
    return RealisticOptimismTrainingStats(
      records: await count('realistic_optimism_training_records'),
      actions: await count('realistic_optimism_training_actions'),
      baselines: await count('realistic_optimism_training_baselines'),
      gratitude: await count('realistic_optimism_training_gratitude_entries'),
      primes: await count('realistic_optimism_training_primes'),
      identity: await count('realistic_optimism_training_identity_evidence'),
      explanationScores: await count('realistic_optimism_training_explanation_scores'),
      benefitReframes: await count('realistic_optimism_training_benefit_reframes'),
      failureImmunity: await count('realistic_optimism_training_failure_immunity'),
      controlledChallenges: await count('realistic_optimism_training_controlled_challenges'),
      savoring: await count('realistic_optimism_training_savoring_entries'),
      antiPrimes: await count('realistic_optimism_training_anti_primes'),
      relationshipGratitude: await count('realistic_optimism_training_relationship_gratitude'),
      eventIntensity: await count('realistic_optimism_training_event_intensity'),
      processPlans: await count('realistic_optimism_training_process_plans'),
      p2Artifacts: await count('realistic_optimism_training_p2_artifacts'),
      sessions: await count('realistic_optimism_training_sessions'),
      openSessions: Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(1) FROM realistic_optimism_training_sessions WHERE status IN ('draft','active','safety_routed')")) ?? 0,
    );
  }
}
