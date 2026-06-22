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
        created_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_controlled_challenges (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        challenge_name TEXT,
        safety_boundary TEXT,
        five_minute_action TEXT,
        predicted_pain REAL,
        actual_pain REAL,
        actual_result TEXT,
        recovery_time TEXT,
        lesson TEXT,
        psychological_antibody TEXT,
        completed_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'actual_pain REAL');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'actual_result TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'recovery_time TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'lesson TEXT');
    await _tryAddColumn(db, 'realistic_optimism_training_controlled_challenges', 'completed_at_ms INTEGER');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_training_savoring_entries (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        moment_title TEXT,
        sensory_detail TEXT,
        meaning TEXT,
        appreciation_action TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');

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
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_rot_actions_record ON realistic_optimism_training_actions(record_id, created_at_ms DESC)');

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
      if (record.faultFinderStory.isNotEmpty || record.balancedInterpretation.isNotEmpty) {
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
      if (record.psychologicalAntibody.isNotEmpty || record.predictedRecovery.isNotEmpty || record.actualRecovery.isNotEmpty || record.predictedPain != null || record.actualPain != null) {
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
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (record.scene == 'controlled_failure_challenge') {
        await txn.insert(
          'realistic_optimism_training_controlled_challenges',
          <String, Object?>{
            'id': 'rot_cfc_${record.id}',
            'record_id': record.id,
            'challenge_name': record.eventSummary.isEmpty ? record.rawInput : record.eventSummary,
            'safety_boundary': record.finalUserMessage,
            'five_minute_action': record.fiveMinuteAction,
            'predicted_pain': record.predictedPain,
            'psychological_antibody': record.psychologicalAntibody,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (record.savoringPrompt.isNotEmpty || record.smallAppreciationAction.isNotEmpty) {
        await txn.insert(
          'realistic_optimism_training_savoring_entries',
          <String, Object?>{
            'id': 'rot_sv_${record.id}',
            'record_id': record.id,
            'moment_title': record.whatStillMatters.isEmpty ? '一个值得停留的时刻' : record.whatStillMatters.first,
            'sensory_detail': record.savoringPrompt,
            'meaning': record.possibleMeaning.join('；'),
            'appreciation_action': record.smallAppreciationAction,
            'created_at_ms': record.createdAtMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (record.antiPrimeCleanupAction.isNotEmpty) {
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
      if (record.whatStillMatters.isNotEmpty || record.smallAppreciationAction.isNotEmpty) {
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
      if (record.scene == 'gratitude_savoring' && record.smallAppreciationAction.isNotEmpty) {
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
      if (record.dailyValueWord.isNotEmpty || record.lockScreenSentence.isNotEmpty || record.antiPrimeCleanupAction.isNotEmpty) {
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
      if (record.identitySentence.isNotEmpty || record.provedCapacity.isNotEmpty) {
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
      await txn.delete('realistic_optimism_training_identity_evidence', where: 'record_id=?', whereArgs: <Object?>[id]);
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
      await txn.delete('realistic_optimism_training_identity_evidence');
      await txn.delete('realistic_optimism_training_records');
    });
  }

  Future<void> addActionEvidence(RealisticOptimismTrainingActionEvidence evidence) async {
    final db = await _db();
    await ensureTables();
    await db.insert('realistic_optimism_training_actions', evidence.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    );
  }
}
