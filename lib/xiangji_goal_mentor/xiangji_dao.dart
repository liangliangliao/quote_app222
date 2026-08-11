import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'xiangji_models.dart';
import 'xiangji_policies.dart';

class XiangjiGoalMentorDao {
  XiangjiGoalMentorDao({Database? database}) : _providedDatabase = database;

  static Future<void>? _schemaFuture;
  final Database? _providedDatabase;
  Future<void>? _providedSchemaFuture;

  Future<Database> _database() async {
    final provided = _providedDatabase;
    if (provided != null) {
      _providedSchemaFuture ??= _ensureSchema(provided);
      try {
        await _providedSchemaFuture;
      } catch (_) {
        _providedSchemaFuture = null;
        rethrow;
      }
      return provided;
    }
    final db = await AppDatabase.instance();
    _schemaFuture ??= _ensureSchema(db);
    try {
      await _schemaFuture;
    } catch (_) {
      _schemaFuture = null;
      rethrow;
    }
    return db;
  }

  static Future<void> _ensureSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        status TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        current_version_id INTEGER,
        primary_thinker_id TEXT,
        current_node_id TEXT,
        current_pathway_id TEXT,
        last_interaction_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_xiangji_active_goal
      ON xiangji_goals(is_active) WHERE is_active = 1
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_goal_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        original_text TEXT NOT NULL,
        ai_summary TEXT,
        why_text TEXT NOT NULL,
        higher_values_json TEXT NOT NULL,
        success_definition TEXT,
        scope_text TEXT,
        created_by TEXT NOT NULL DEFAULT 'user_confirmed',
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_goal_state_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        from_state TEXT,
        to_state TEXT NOT NULL,
        trigger TEXT NOT NULL,
        reason TEXT,
        actor TEXT NOT NULL DEFAULT 'user',
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_daily_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        goal_version_id INTEGER NOT NULL,
        action_text TEXT NOT NULL,
        trigger_context TEXT NOT NULL,
        minimum_done TEXT NOT NULL,
        evidence_rule TEXT NOT NULL,
        controllability_reason TEXT NOT NULL,
        smaller_variant TEXT NOT NULL,
        source_system_id TEXT,
        status TEXT NOT NULL DEFAULT 'ready',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE,
        FOREIGN KEY(goal_version_id) REFERENCES xiangji_goal_versions(id)
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_checkins (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        step_id INTEGER NOT NULL,
        result_type TEXT NOT NULL,
        user_text TEXT,
        blocker_type TEXT,
        mood_signal TEXT,
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(step_id) REFERENCES xiangji_daily_steps(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_growth_evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        checkin_id INTEGER,
        evidence_type TEXT NOT NULL,
        user_original_text TEXT,
        ai_summary TEXT NOT NULL,
        confirmed_at_ms INTEGER,
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE,
        FOREIGN KEY(checkin_id) REFERENCES xiangji_checkins(id) ON DELETE SET NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_mentor_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        user_input TEXT,
        surface_problem TEXT,
        mechanism_id TEXT,
        mechanism_label TEXT,
        primary_thinker_id TEXT NOT NULL,
        zoom_mode TEXT NOT NULL,
        confidence REAL NOT NULL,
        structured_output_json TEXT,
        kb_version TEXT,
        validation_status TEXT NOT NULL DEFAULT 'validated',
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_calibrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        value_assessment TEXT NOT NULL,
        goal_assessment TEXT NOT NULL,
        method_assessment TEXT NOT NULL,
        action_assessment TEXT NOT NULL,
        recommendation TEXT NOT NULL,
        retained_values_json TEXT NOT NULL,
        confirmed_at_ms INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_reminder_settings (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        enabled INTEGER NOT NULL DEFAULT 0,
        time_of_day TEXT NOT NULL DEFAULT '09:00',
        quiet_start TEXT NOT NULL DEFAULT '22:00',
        quiet_end TEXT NOT NULL DEFAULT '08:00',
        task_uid TEXT,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_reminder_deliveries (
        delivery_key TEXT PRIMARY KEY,
        goal_id INTEGER NOT NULL,
        local_day TEXT NOT NULL,
        content_type TEXT NOT NULL,
        status TEXT NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 1,
        claimed_at_ms INTEGER NOT NULL,
        delivered_at_ms INTEGER,
        last_error TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_local_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        edition TEXT,
        local_uri TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        parse_status TEXT NOT NULL,
        permission_scope TEXT NOT NULL DEFAULT 'private',
        created_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_book_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        chunk_uid TEXT NOT NULL UNIQUE,
        chunk_index INTEGER NOT NULL,
        section_title TEXT NOT NULL DEFAULT '',
        source_locator TEXT NOT NULL,
        text_content TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        UNIQUE(book_id, chunk_index),
        FOREIGN KEY(book_id) REFERENCES xiangji_local_books(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE INDEX IF NOT EXISTS idx_xiangji_book_chunks_book
      ON xiangji_book_chunks(book_id, chunk_index)
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_provider_mirrors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        provider TEXT NOT NULL,
        provider_file_id TEXT NOT NULL DEFAULT '',
        provider_index_id TEXT NOT NULL DEFAULT '',
        synced_hash TEXT NOT NULL DEFAULT '',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        indexed_status TEXT NOT NULL DEFAULT 'pending',
        consented_at_ms INTEGER NOT NULL DEFAULT 0,
        last_error TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        UNIQUE(book_id, provider),
        FOREIGN KEY(book_id) REFERENCES xiangji_local_books(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_provider_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        provider TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        content_hash TEXT NOT NULL DEFAULT '',
        provider_file_id TEXT NOT NULL DEFAULT '',
        provider_index_id TEXT NOT NULL DEFAULT '',
        error_summary TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(book_id) REFERENCES xiangji_local_books(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS xiangji_generation_audits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        query_hash TEXT NOT NULL,
        output_hash TEXT NOT NULL DEFAULT '',
        provider TEXT NOT NULL,
        model_label TEXT NOT NULL DEFAULT '',
        source_mode TEXT NOT NULL,
        allowed_book_ids_json TEXT NOT NULL,
        source_chunk_ids_json TEXT NOT NULL,
        validation_status TEXT NOT NULL,
        validation_errors_json TEXT NOT NULL,
        prompt_version TEXT NOT NULL,
        schema_version TEXT NOT NULL,
        kb_version TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY(goal_id) REFERENCES xiangji_goals(id) ON DELETE SET NULL
      )
    ''');
    await batch.commit(noResult: true);
    final goalColumns = await db.rawQuery('PRAGMA table_info(xiangji_goals)');
    if (!goalColumns.any(
      (column) => column['name']?.toString() == 'last_interaction_at_ms',
    )) {
      await db.execute(
        'ALTER TABLE xiangji_goals ADD COLUMN last_interaction_at_ms INTEGER',
      );
    }
    await _addColumnIfMissing(
      db,
      'xiangji_local_books',
      'mime_type',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'xiangji_local_books',
      'size_bytes',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'xiangji_local_books',
      'parsed_characters',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'xiangji_local_books',
      'chunk_count',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'xiangji_local_books',
      'parse_error',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'xiangji_local_books',
      'updated_at_ms',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((row) => row['name']?.toString() == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<XiangjiGoal?> activeGoal() async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT g.*, v.id AS version_id, v.original_text, v.why_text,
             v.higher_values_json, v.success_definition, v.scope_text
      FROM xiangji_goals g
      JOIN xiangji_goal_versions v ON v.id = g.current_version_id
      WHERE g.is_active = 1
      LIMIT 1
    ''');
    return rows.isEmpty ? null : XiangjiGoal.fromJoinedRow(rows.first);
  }

  Future<XiangjiGoal?> goalById(int goalId) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT g.*, v.id AS version_id, v.original_text, v.why_text,
             v.higher_values_json, v.success_definition, v.scope_text
      FROM xiangji_goals g
      JOIN xiangji_goal_versions v ON v.id = g.current_version_id
      WHERE g.id = ?
      LIMIT 1
    ''', <Object?>[goalId]);
    return rows.isEmpty ? null : XiangjiGoal.fromJoinedRow(rows.first);
  }

  Future<void> markGoalSeen(int goalId) async {
    final db = await _database();
    await db.update(
      'xiangji_goals',
      <String, Object?>{
        'last_interaction_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[goalId],
    );
  }

  Future<List<XiangjiGoal>> allGoals() async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT g.*, v.id AS version_id, v.original_text, v.why_text,
             v.higher_values_json, v.success_definition, v.scope_text
      FROM xiangji_goals g
      JOIN xiangji_goal_versions v ON v.id = g.current_version_id
      ORDER BY g.updated_at_ms DESC
    ''');
    return rows.map(XiangjiGoal.fromJoinedRow).toList(growable: false);
  }

  Future<List<Map<String, Object?>>> goalVersions(int goalId) async {
    final db = await _database();
    return db.query(
      'xiangji_goal_versions',
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'created_at_ms DESC, id DESC',
    );
  }

  Future<XiangjiGoal> createAndActivateGoal(
    XiangjiGoalDraft draft, {
    String kbVersion = '2.0.0',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final goalId = await db.transaction<int>((txn) async {
      final existing = Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM xiangji_goals WHERE is_active = 1',
            ),
          ) ??
          0;
      if (existing > 0) {
        throw StateError('GOAL_ACTIVE_CONFLICT');
      }
      final id = await txn.insert('xiangji_goals', <String, Object?>{
        'status': XiangjiGoalState.spark.value,
        'is_active': 0,
        'primary_thinker_id': draft.guidance.systemId,
        'current_node_id': draft.guidance.mechanismId,
        'last_interaction_at_ms': now,
        'created_at_ms': now,
        'updated_at_ms': now,
      });
      final versionId = await txn.insert(
        'xiangji_goal_versions',
        <String, Object?>{
          'goal_id': id,
          'original_text': draft.originalText,
          'ai_summary': draft.originalText,
          'why_text': draft.whyText,
          'higher_values_json': jsonEncode(draft.higherValues),
          'success_definition': draft.successDefinition,
          'scope_text': draft.scopeText,
          'created_by': 'user_confirmed',
          'created_at_ms': now,
        },
      );
      await txn.update(
        'xiangji_goals',
        <String, Object?>{'current_version_id': versionId},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await _insertStateEvent(
        txn,
        goalId: id,
        from: XiangjiGoalState.mist,
        to: XiangjiGoalState.spark,
        trigger: 'spark_confirmed',
        reason: '用户确认目标火种草案',
      );
      await _insertStateEvent(
        txn,
        goalId: id,
        from: XiangjiGoalState.spark,
        to: XiangjiGoalState.anchored,
        trigger: 'goal_anchored',
        reason: '用户确认目标原话、为什么和高层价值',
      );
      await _insertStateEvent(
        txn,
        goalId: id,
        from: XiangjiGoalState.anchored,
        to: XiangjiGoalState.active,
        trigger: 'first_step_created',
        reason: '已生成第一个可控行动',
      );
      await txn.update(
        'xiangji_goals',
        <String, Object?>{
          'status': XiangjiGoalState.active.value,
          'is_active': 1,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await _insertStep(
        txn,
        goalId: id,
        goalVersionId: versionId,
        step: draft.step,
        now: now,
      );
      await _insertMentorSession(
        txn,
        goalId: id,
        userInput: draft.originalText,
        guidance: draft.guidance,
        zoomMode: XiangjiZoomMode.panorama,
        kbVersion: kbVersion,
        now: now,
      );
      return id;
    });
    final created = await goalById(goalId);
    if (created == null) throw StateError('目标创建后读取失败');
    return created;
  }

  Future<XiangjiGoal> updateGoalVersion({
    required XiangjiGoal goal,
    required String originalText,
    required String whyText,
    required List<String> higherValues,
    required String successDefinition,
    required String scopeText,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction<void>((txn) async {
      final versionId = await txn.insert(
        'xiangji_goal_versions',
        <String, Object?>{
          'goal_id': goal.id,
          'original_text': originalText.trim(),
          'ai_summary': originalText.trim(),
          'why_text': whyText.trim(),
          'higher_values_json': jsonEncode(higherValues),
          'success_definition': successDefinition.trim(),
          'scope_text': scopeText.trim(),
          'created_by': 'user_edited',
          'created_at_ms': now,
        },
      );
      await txn.update(
        'xiangji_goals',
        <String, Object?>{
          'current_version_id': versionId,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
    });
    final updated = await goalById(goal.id);
    if (updated == null) throw StateError('目标更新后读取失败');
    return updated;
  }

  Future<XiangjiDailyStep?> currentStep(int goalId) async {
    final db = await _database();
    var rows = await db.query(
      'xiangji_daily_steps',
      where: "goal_id = ? AND status IN ('ready', 'in_progress')",
      whereArgs: <Object?>[goalId],
      orderBy: 'created_at_ms DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      rows = await db.query(
        'xiangji_daily_steps',
        where: 'goal_id = ?',
        whereArgs: <Object?>[goalId],
        orderBy: 'created_at_ms DESC, id DESC',
        limit: 1,
      );
    }
    return rows.isEmpty ? null : XiangjiDailyStep.fromRow(rows.first);
  }

  Future<XiangjiDailyStep> replaceCurrentStep(
    XiangjiGoal goal,
    XiangjiDailyStep step, {
    String trigger = 'step_replaced',
  }) async {
    const replaceableStates = <XiangjiGoalState>{
      XiangjiGoalState.active,
      XiangjiGoalState.feedback,
      XiangjiGoalState.calibrating,
      XiangjiGoalState.paused,
    };
    if (!replaceableStates.contains(goal.state)) {
      throw StateError('STEP_NOT_ALLOWED_IN_STATE:${goal.state.value}');
    }
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final stepId = await db.transaction<int>((txn) async {
      await txn.update(
        'xiangji_daily_steps',
        <String, Object?>{'status': 'replaced', 'updated_at_ms': now},
        where: "goal_id = ? AND status IN ('ready', 'in_progress')",
        whereArgs: <Object?>[goal.id],
      );
      final id = await _insertStep(
        txn,
        goalId: goal.id,
        goalVersionId: goal.versionId,
        step: step,
        now: now,
      );
      if (goal.state == XiangjiGoalState.feedback ||
          goal.state == XiangjiGoalState.calibrating) {
        await _insertStateEvent(
          txn,
          goalId: goal.id,
          from: goal.state,
          to: XiangjiGoalState.active,
          trigger: trigger,
          reason: '已根据反馈生成新的可控行动',
        );
        await txn.update(
          'xiangji_goals',
          <String, Object?>{
            'status': XiangjiGoalState.active.value,
            'updated_at_ms': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[goal.id],
        );
      }
      return id;
    });
    final rows = await db.query(
      'xiangji_daily_steps',
      where: 'id = ?',
      whereArgs: <Object?>[stepId],
      limit: 1,
    );
    return XiangjiDailyStep.fromRow(rows.first);
  }

  Future<void> markStepStarted(int stepId) async {
    final db = await _database();
    await db.update(
      'xiangji_daily_steps',
      <String, Object?>{
        'status': 'in_progress',
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[stepId],
    );
  }

  Future<int> addCheckinAndEvidenceDraft({
    required XiangjiGoal goal,
    required XiangjiDailyStep step,
    required String resultType,
    required String userText,
    required String evidenceType,
    required String evidenceSummary,
  }) async {
    if (goal.state != XiangjiGoalState.active ||
        (step.status != 'ready' && step.status != 'in_progress')) {
      throw StateError(
        'CHECKIN_NOT_ALLOWED:${goal.state.value}/${step.status}',
      );
    }
    if (tryParseXiangjiCheckinResult(resultType) == null) {
      throw ArgumentError.value(resultType, 'resultType');
    }
    if (tryParseXiangjiEvidenceType(evidenceType) == null) {
      throw ArgumentError.value(evidenceType, 'evidenceType');
    }
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction<int>((txn) async {
      final checkinId = await txn.insert(
        'xiangji_checkins',
        <String, Object?>{
          'step_id': step.id,
          'result_type': resultType,
          'user_text': userText.trim(),
          'blocker_type': resultType == 'blocked' ? 'user_reported' : null,
          'created_at_ms': now,
        },
      );
      await txn.update(
        'xiangji_daily_steps',
        <String, Object?>{'status': resultType, 'updated_at_ms': now},
        where: 'id = ?',
        whereArgs: <Object?>[step.id],
      );
      final evidenceId = await txn.insert(
        'xiangji_growth_evidence',
        <String, Object?>{
          'goal_id': goal.id,
          'checkin_id': checkinId,
          'evidence_type': evidenceType,
          'user_original_text': userText.trim(),
          'ai_summary': evidenceSummary,
          'confirmed_at_ms': null,
          'created_at_ms': now,
        },
      );
      if (goal.state == XiangjiGoalState.active) {
        await _insertStateEvent(
          txn,
          goalId: goal.id,
          from: XiangjiGoalState.active,
          to: XiangjiGoalState.feedback,
          trigger: 'checkin_submitted',
          reason: '用户提交了行动反馈',
        );
        await txn.update(
          'xiangji_goals',
          <String, Object?>{
            'status': XiangjiGoalState.feedback.value,
            'updated_at_ms': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[goal.id],
        );
      }
      return evidenceId;
    });
  }

  Future<void> confirmEvidence(int evidenceId) async {
    final db = await _database();
    await db.update(
      'xiangji_growth_evidence',
      <String, Object?>{
        'confirmed_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[evidenceId],
    );
  }

  Future<void> discardEvidenceDraft(int evidenceId) async {
    final db = await _database();
    await db.delete(
      'xiangji_growth_evidence',
      where: 'id = ? AND confirmed_at_ms IS NULL',
      whereArgs: <Object?>[evidenceId],
    );
  }

  Future<List<XiangjiGrowthEvidence>> evidenceForGoal(int goalId) async {
    final db = await _database();
    final rows = await db.query(
      'xiangji_growth_evidence',
      where: 'goal_id = ? AND confirmed_at_ms IS NOT NULL',
      whereArgs: <Object?>[goalId],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(XiangjiGrowthEvidence.fromRow).toList(growable: false);
  }

  Future<void> saveGuidance({
    required XiangjiGoal goal,
    required String userInput,
    required XiangjiGuidance guidance,
    required XiangjiZoomMode zoomMode,
    required String kbVersion,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction<void>((txn) async {
      await txn.update(
        'xiangji_goals',
        <String, Object?>{
          'primary_thinker_id': guidance.systemId,
          'current_node_id': guidance.mechanismId,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
      await _insertMentorSession(
        txn,
        goalId: goal.id,
        userInput: userInput,
        guidance: guidance,
        zoomMode: zoomMode,
        kbVersion: kbVersion,
        now: now,
      );
    });
  }

  Future<void> applyCalibration(
    XiangjiGoal goal,
    XiangjiCalibrationDecision decision,
  ) async {
    if (goal.state != XiangjiGoalState.calibrating &&
        !XiangjiGoalTransitionPolicy.canTransition(
          goal.state,
          XiangjiGoalState.calibrating,
        )) {
      throw StateError(
        'INVALID_GOAL_TRANSITION:${goal.state.value}->${XiangjiGoalState.calibrating.value}',
      );
    }
    final target = _stateForCalibration(decision.result);
    if (!XiangjiGoalTransitionPolicy.canTransition(
      XiangjiGoalState.calibrating,
      target,
    )) {
      throw StateError(
        'INVALID_GOAL_TRANSITION:${XiangjiGoalState.calibrating.value}->${target.value}',
      );
    }
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction<void>((txn) async {
      await txn.insert('xiangji_calibrations', <String, Object?>{
        'goal_id': goal.id,
        'value_assessment': decision.valueAssessment,
        'goal_assessment': decision.goalAssessment,
        'method_assessment': decision.methodAssessment,
        'action_assessment': decision.actionAssessment,
        'recommendation': decision.result.value,
        'retained_values_json': jsonEncode(decision.retainedValues),
        'confirmed_at_ms': now,
        'created_at_ms': now,
      });
      var from = goal.state;
      if (from != XiangjiGoalState.calibrating) {
        await _insertStateEvent(
          txn,
          goalId: goal.id,
          from: from,
          to: XiangjiGoalState.calibrating,
          trigger: 'calibration_confirmed',
          reason: '用户完成四层校准',
        );
        from = XiangjiGoalState.calibrating;
      }
      await _insertStateEvent(
        txn,
        goalId: goal.id,
        from: from,
        to: target,
        trigger: decision.result.value,
        reason: decision.result.description,
      );
      await txn.update(
        'xiangji_goals',
        <String, Object?>{
          'status': target.value,
          'is_active': decision.result == XiangjiCalibrationResult.reselect ? 0 : 1,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
    });
  }

  Future<void> transitionGoal(
    XiangjiGoal goal,
    XiangjiGoalState target, {
    required String trigger,
    required String reason,
  }) async {
    if (!XiangjiGoalTransitionPolicy.canTransition(goal.state, target)) {
      throw StateError(
        'INVALID_GOAL_TRANSITION:${goal.state.value}->${target.value}',
      );
    }
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction<void>((txn) async {
      await _insertStateEvent(
        txn,
        goalId: goal.id,
        from: goal.state,
        to: target,
        trigger: trigger,
        reason: reason,
      );
      await txn.update(
        'xiangji_goals',
        <String, Object?>{
          'status': target.value,
          'is_active': target == XiangjiGoalState.archived ? 0 : 1,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[goal.id],
      );
    });
  }

  Future<List<Map<String, Object?>>> stateEvents(int goalId) async {
    final db = await _database();
    return db.query(
      'xiangji_goal_state_events',
      where: 'goal_id = ?',
      whereArgs: <Object?>[goalId],
      orderBy: 'created_at_ms DESC',
    );
  }

  Future<XiangjiReminderSettings> reminderSettings() async {
    final db = await _database();
    final rows = await db.query(
      'xiangji_reminder_settings',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return XiangjiReminderSettings.defaults();
    final row = rows.first;
    return XiangjiReminderSettings(
      enabled: (row['enabled'] as int? ?? 0) == 1,
      timeOfDay: (row['time_of_day'] ?? '09:00').toString(),
      quietStart: (row['quiet_start'] ?? '22:00').toString(),
      quietEnd: (row['quiet_end'] ?? '08:00').toString(),
      taskUid: (row['task_uid'] ?? '').toString(),
    );
  }

  Future<void> saveReminderSettings(XiangjiReminderSettings settings) async {
    final db = await _database();
    await db.insert(
      'xiangji_reminder_settings',
      <String, Object?>{
        'id': 1,
        'enabled': settings.enabled ? 1 : 0,
        'time_of_day': settings.timeOfDay,
        'quiet_start': settings.quietStart,
        'quiet_end': settings.quietEnd,
        'task_uid': settings.taskUid,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> reminderContent() async {
    final goal = await activeGoal();
    if (goal == null || goal.state == XiangjiGoalState.archived) return null;
    return (await _reminderForGoal(goal)).body;
  }

  Future<String?> scheduledReminderContent({DateTime? now}) async {
    return (await _scheduledReminderCandidate(now: now))?.body;
  }

  /// Atomically claims today's proactive reminder. A second worker receives
  /// null, so duplicate scheduler wakeups cannot notify twice on the same day.
  Future<XiangjiScheduledReminder?> claimScheduledReminder({
    DateTime? now,
  }) async {
    final candidate = await _scheduledReminderCandidate(now: now);
    if (candidate == null) return null;
    final claimedAt = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final db = await _database();
    return db.transaction<XiangjiScheduledReminder?>((txn) async {
      final existing = await txn.query(
        'xiangji_reminder_deliveries',
        where: 'delivery_key = ?',
        whereArgs: <Object?>[candidate.deliveryKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final row = existing.first;
        if ((row['status'] ?? '').toString() != 'failed') return null;
        final rawAttempts = row['attempt_count'];
        final attempts = rawAttempts is int
            ? rawAttempts
            : int.tryParse((rawAttempts ?? '1').toString()) ?? 1;
        await txn.update(
          'xiangji_reminder_deliveries',
          <String, Object?>{
            'status': 'claimed',
            'attempt_count': attempts + 1,
            'claimed_at_ms': claimedAt,
            'last_error': null,
            'updated_at_ms': claimedAt,
          },
          where: 'delivery_key = ? AND status = ?',
          whereArgs: <Object?>[candidate.deliveryKey, 'failed'],
        );
        return candidate;
      }
      await txn.insert(
        'xiangji_reminder_deliveries',
        <String, Object?>{
          'delivery_key': candidate.deliveryKey,
          'goal_id': candidate.goalId,
          'local_day': candidate.deliveryKey.split(':').last,
          'content_type': candidate.contentType,
          'status': 'claimed',
          'attempt_count': 1,
          'claimed_at_ms': claimedAt,
          'created_at_ms': claimedAt,
          'updated_at_ms': claimedAt,
        },
      );
      return candidate;
    });
  }

  Future<void> markScheduledReminderDelivered(String deliveryKey) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'xiangji_reminder_deliveries',
      <String, Object?>{
        'status': 'delivered',
        'delivered_at_ms': now,
        'last_error': null,
        'updated_at_ms': now,
      },
      where: 'delivery_key = ? AND status = ?',
      whereArgs: <Object?>[deliveryKey, 'claimed'],
    );
  }

  Future<void> markScheduledReminderFailed(
    String deliveryKey,
    Object error,
  ) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final errorText = error.toString();
    await db.update(
      'xiangji_reminder_deliveries',
      <String, Object?>{
        'status': 'failed',
        'last_error': errorText.length <= 300
            ? errorText
            : errorText.substring(0, 300),
        'updated_at_ms': now,
      },
      where: 'delivery_key = ? AND status = ?',
      whereArgs: <Object?>[deliveryKey, 'claimed'],
    );
  }

  Future<XiangjiScheduledReminder?> _scheduledReminderCandidate({
    DateTime? now,
  }) async {
    final settings = await reminderSettings();
    if (!settings.enabled) return null;
    final goal = await activeGoal();
    if (goal == null || goal.state == XiangjiGoalState.archived) return null;
    final localNow = now ?? DateTime.now();
    final lastInteraction = await _lastInteractionAtMs(goal.id);
    final silenceDays = localNow
        .difference(DateTime.fromMillisecondsSinceEpoch(lastInteraction))
        .inDays;
    if (!XiangjiReminderPolicy.shouldSendForSilence(silenceDays)) {
      return null;
    }
    final content = XiangjiReminderPolicy.isLongSilence(silenceDays)
        ? _XiangjiReminderContent(
            type: 'reconnect',
            body: '你曾经说过：“${goal.originalText}”\n'
                '现在是目标变了，还是生活暂时占据了注意力？不必用补作业的方式回来。',
          )
        : await _reminderForGoal(goal);
    return XiangjiScheduledReminder(
      deliveryKey: XiangjiReminderPolicy.deliveryKey(
        goalId: goal.id,
        localDate: localNow,
      ),
      goalId: goal.id,
      contentType: content.type,
      body: content.body,
    );
  }

  Future<_XiangjiReminderContent> _reminderForGoal(XiangjiGoal goal) async {
    if (goal.state == XiangjiGoalState.completed) {
      return _XiangjiReminderContent(
        type: 'evidence',
        body: '你已经完成“${goal.originalText}”。先不急着制造更高目标，看看这段经历形成了什么能力，以及是否需要巩固、分享或休息。',
      );
    }
    if (goal.state == XiangjiGoalState.paused) {
      return _XiangjiReminderContent(
        type: 'value',
        body: '你暂停的是推进，不是你重视的“${goal.higherValues.join('、')}”。现在不必催促自己。',
      );
    }
    if (goal.state == XiangjiGoalState.reselecting) {
      return _XiangjiReminderContent(
        type: 'value',
        body: '具体路径可以改变，你仍可以保留“${goal.higherValues.join('、')}”这些高层价值。',
      );
    }
    final step = await currentStep(goal.id);
    if (step != null &&
        (step.status == 'ready' || step.status == 'in_progress')) {
      return _XiangjiReminderContent(
        type: 'action',
        body: '你曾说：“${goal.originalText}”\n今日一步：${step.actionText}',
      );
    }
    final evidence = await evidenceForGoal(goal.id);
    if (evidence.isNotEmpty) {
      return _XiangjiReminderContent(
        type: 'evidence',
        body: '你曾说：“${goal.originalText}”\n最近的成长证据：${evidence.first.summary}',
      );
    }
    return const _XiangjiReminderContent(
      type: 'reconnect',
      body: '你曾经说过，这件事对你很重要。现在是目标变了，还是生活暂时占据了注意力？',
    );
  }

  Future<int> _lastInteractionAtMs(int goalId) async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT MAX(event_at_ms) AS last_at_ms FROM (
        SELECT COALESCE(last_interaction_at_ms, updated_at_ms) AS event_at_ms
        FROM xiangji_goals WHERE id = ?
        UNION ALL
        SELECT updated_at_ms AS event_at_ms
        FROM xiangji_daily_steps WHERE goal_id = ?
        UNION ALL
        SELECT c.created_at_ms AS event_at_ms
        FROM xiangji_checkins c
        JOIN xiangji_daily_steps s ON s.id = c.step_id
        WHERE s.goal_id = ?
        UNION ALL
        SELECT created_at_ms AS event_at_ms
        FROM xiangji_mentor_sessions WHERE goal_id = ?
        UNION ALL
        SELECT created_at_ms AS event_at_ms
        FROM xiangji_calibrations WHERE goal_id = ?
      )
    ''', <Object?>[goalId, goalId, goalId, goalId, goalId]);
    final raw = rows.isEmpty ? null : rows.first['last_at_ms'];
    if (raw is int && raw > 0) return raw;
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<List<XiangjiBookInfo>> importedBooks() async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT b.*,
             m.provider AS mirror_provider,
             m.provider_file_id AS mirror_file_id,
             m.provider_index_id AS mirror_index_id,
             m.synced_hash AS mirror_synced_hash,
             m.sync_status AS mirror_sync_status,
             m.indexed_status AS mirror_indexed_status,
             m.consented_at_ms AS mirror_consented_at_ms,
             m.last_error AS mirror_last_error,
             m.created_at_ms AS mirror_created_at_ms,
             m.updated_at_ms AS mirror_updated_at_ms
      FROM xiangji_local_books b
      LEFT JOIN xiangji_provider_mirrors m
        ON m.id = (
          SELECT newest.id
          FROM xiangji_provider_mirrors newest
          WHERE newest.book_id = b.id
          ORDER BY newest.updated_at_ms DESC
          LIMIT 1
        )
      WHERE b.deleted_at_ms IS NULL
      ORDER BY b.created_at_ms DESC
    ''');
    return rows.map(_bookFromRow).toList(growable: false);
  }

  Future<XiangjiBookInfo?> importedBookById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final numericId = _localBookId(id);
    if (numericId == null) return null;
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT b.*,
             m.provider AS mirror_provider,
             m.provider_file_id AS mirror_file_id,
             m.provider_index_id AS mirror_index_id,
             m.synced_hash AS mirror_synced_hash,
             m.sync_status AS mirror_sync_status,
             m.indexed_status AS mirror_indexed_status,
             m.consented_at_ms AS mirror_consented_at_ms,
             m.last_error AS mirror_last_error,
             m.created_at_ms AS mirror_created_at_ms,
             m.updated_at_ms AS mirror_updated_at_ms
      FROM xiangji_local_books b
      LEFT JOIN xiangji_provider_mirrors m
        ON m.id = (
          SELECT newest.id
          FROM xiangji_provider_mirrors newest
          WHERE newest.book_id = b.id
          ORDER BY newest.updated_at_ms DESC
          LIMIT 1
        )
      WHERE b.id = ? ${includeDeleted ? '' : 'AND b.deleted_at_ms IS NULL'}
      LIMIT 1
    ''', <Object?>[numericId]);
    return rows.isEmpty ? null : _bookFromRow(rows.first);
  }

  Future<XiangjiBookInfo?> activeBookByHash(String contentHash) async {
    final db = await _database();
    final rows = await db.query(
      'xiangji_local_books',
      where: 'content_hash = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[contentHash],
      limit: 1,
    );
    return rows.isEmpty ? null : _bookFromRow(rows.first);
  }

  Future<int> saveImportedBook({
    required String title,
    required String localPath,
    required String contentHash,
    String mimeType = '',
    int sizeBytes = 0,
    String parseStatus = 'pending',
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('xiangji_local_books', <String, Object?>{
      'title': title,
      'author': '',
      'edition': '',
      'local_uri': localPath,
      'content_hash': contentHash,
      'parse_status': parseStatus,
      'permission_scope': 'private',
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'parsed_characters': 0,
      'chunk_count': 0,
      'parse_error': '',
      'created_at_ms': now,
      'updated_at_ms': now,
    });
  }

  Future<void> replaceBookChunks({
    required int bookId,
    required List<XiangjiBookChunk> chunks,
    required int parsedCharacters,
    required bool partial,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction<void>((txn) async {
      await txn.delete(
        'xiangji_book_chunks',
        where: 'book_id = ?',
        whereArgs: <Object?>[bookId],
      );
      for (final chunk in chunks) {
        await txn.insert('xiangji_book_chunks', <String, Object?>{
          'book_id': bookId,
          'chunk_uid': chunk.id,
          'chunk_index': chunk.chunkIndex,
          'section_title': chunk.sectionTitle,
          'source_locator': chunk.locator,
          'text_content': chunk.text,
          'content_hash': chunk.contentHash,
          'created_at_ms': now,
        });
      }
      await txn.update(
        'xiangji_local_books',
        <String, Object?>{
          'parse_status': partial ? 'partial' : 'ready',
          'parsed_characters': parsedCharacters,
          'chunk_count': chunks.length,
          'parse_error': '',
          'updated_at_ms': now,
        },
        where: 'id = ? AND deleted_at_ms IS NULL',
        whereArgs: <Object?>[bookId],
      );
    });
  }

  Future<void> markBookParseFailed(int bookId, String error) async {
    final db = await _database();
    await db.update(
      'xiangji_local_books',
      <String, Object?>{
        'parse_status': 'failed',
        'parsed_characters': 0,
        'chunk_count': 0,
        'parse_error': _safeAuditText(error),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at_ms IS NULL',
      whereArgs: <Object?>[bookId],
    );
  }

  Future<List<XiangjiBookChunk>> chunksForBooks(
    List<String> bookIds,
  ) async {
    final ids = bookIds.map(_localBookId).whereType<int>().toSet().toList();
    if (ids.isEmpty) return const <XiangjiBookChunk>[];
    final db = await _database();
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT c.*, b.title AS book_title
      FROM xiangji_book_chunks c
      JOIN xiangji_local_books b ON b.id = c.book_id
      WHERE c.book_id IN ($placeholders)
        AND b.deleted_at_ms IS NULL
        AND b.permission_scope = 'private'
        AND b.parse_status IN ('ready', 'partial')
      ORDER BY c.book_id, c.chunk_index
    ''', ids.cast<Object?>());
    return rows.map(_chunkFromRow).toList(growable: false);
  }

  Future<List<XiangjiBookChunk>> chunksByIds(
    List<String> chunkIds, {
    List<String>? allowedBookIds,
  }) async {
    final unique = chunkIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const <XiangjiBookChunk>[];
    final allowed = (allowedBookIds ?? const <String>[])
        .map(_localBookId)
        .whereType<int>()
        .toSet()
        .toList();
    if (allowedBookIds != null && allowed.isEmpty) {
      return const <XiangjiBookChunk>[];
    }
    final db = await _database();
    final chunkPlaceholders = List<String>.filled(unique.length, '?').join(',');
    final bookClause = allowedBookIds == null
        ? ''
        : 'AND c.book_id IN (${List<String>.filled(allowed.length, '?').join(',')})';
    final rows = await db.rawQuery('''
      SELECT c.*, b.title AS book_title
      FROM xiangji_book_chunks c
      JOIN xiangji_local_books b ON b.id = c.book_id
      WHERE c.chunk_uid IN ($chunkPlaceholders)
        $bookClause
        AND b.deleted_at_ms IS NULL
        AND b.permission_scope = 'private'
        AND b.parse_status IN ('ready', 'partial')
    ''', <Object?>[...unique, ...allowed]);
    final byId = <String, XiangjiBookChunk>{
      for (final row in rows) (row['chunk_uid'] ?? '').toString(): _chunkFromRow(row),
    };
    return unique.map((id) => byId[id]).whereType<XiangjiBookChunk>().toList();
  }

  Future<XiangjiProviderMirror?> providerMirror(
    String bookId, {
    String provider = 'openai',
  }) async {
    final numericId = _localBookId(bookId);
    if (numericId == null) return null;
    final db = await _database();
    final rows = await db.query(
      'xiangji_provider_mirrors',
      where: 'book_id = ? AND provider = ?',
      whereArgs: <Object?>[numericId, provider],
      limit: 1,
    );
    return rows.isEmpty ? null : _mirrorFromRow(rows.first);
  }

  Future<XiangjiProviderMirror> saveProviderMirror(
    XiangjiProviderMirror mirror,
  ) async {
    final numericId = _localBookId(mirror.bookId);
    if (numericId == null) throw ArgumentError('无效的本地书籍ID。');
    final db = await _database();
    final existing = await providerMirror(
      mirror.bookId,
      provider: mirror.provider,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = <String, Object?>{
      'book_id': numericId,
      'provider': mirror.provider,
      'provider_file_id': mirror.providerFileId,
      'provider_index_id': mirror.providerIndexId,
      'synced_hash': mirror.syncedHash,
      'sync_status': mirror.syncStatus,
      'indexed_status': mirror.indexedStatus,
      'consented_at_ms': mirror.consentedAtMs,
      'last_error': _safeAuditText(mirror.lastError),
      'created_at_ms': existing?.createdAtMs ??
          (mirror.createdAtMs > 0 ? mirror.createdAtMs : now),
      'updated_at_ms': now,
    };
    if (existing == null) {
      await db.insert('xiangji_provider_mirrors', row);
    } else {
      await db.update(
        'xiangji_provider_mirrors',
        row,
        where: 'book_id = ? AND provider = ?',
        whereArgs: <Object?>[numericId, mirror.provider],
      );
    }
    return (await providerMirror(mirror.bookId, provider: mirror.provider))!;
  }

  Future<List<XiangjiProviderMirror>> pendingProviderDeletions() async {
    final db = await _database();
    final rows = await db.query(
      'xiangji_provider_mirrors',
      where: "sync_status = 'delete_pending'",
      orderBy: 'updated_at_ms',
    );
    return rows.map(_mirrorFromRow).toList(growable: false);
  }

  Future<void> recordProviderEvent({
    required String bookId,
    required String provider,
    required String action,
    required String status,
    required String contentHash,
    String providerFileId = '',
    String providerIndexId = '',
    String errorSummary = '',
  }) async {
    final numericId = _localBookId(bookId);
    if (numericId == null) return;
    final db = await _database();
    await db.insert('xiangji_provider_events', <String, Object?>{
      'book_id': numericId,
      'provider': provider,
      'action': action,
      'status': status,
      'content_hash': contentHash,
      'provider_file_id': providerFileId,
      'provider_index_id': providerIndexId,
      'error_summary': _safeAuditText(errorSummary),
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordGenerationAudit({
    int? goalId,
    required String queryHash,
    required String outputHash,
    required String provider,
    required String modelLabel,
    required String sourceMode,
    required List<String> allowedBookIds,
    required List<String> sourceChunkIds,
    required String validationStatus,
    required List<String> validationErrors,
    String kbVersion = '',
  }) async {
    final db = await _database();
    await db.insert('xiangji_generation_audits', <String, Object?>{
      'goal_id': goalId,
      'query_hash': queryHash,
      'output_hash': outputHash,
      'provider': provider,
      'model_label': modelLabel,
      'source_mode': sourceMode,
      'allowed_book_ids_json': jsonEncode(allowedBookIds),
      'source_chunk_ids_json': jsonEncode(sourceChunkIds),
      'validation_status': validationStatus,
      'validation_errors_json': jsonEncode(validationErrors),
      'prompt_version': 'xiangji_grounded_guidance_v1',
      'schema_version': 'xiangji_grounded_answer_v1',
      'kb_version': kbVersion,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> markImportedBookDeleted(String id) async {
    final numericId = _localBookId(id);
    if (numericId == null) return;
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction<void>((txn) async {
      await txn.delete(
        'xiangji_book_chunks',
        where: 'book_id = ?',
        whereArgs: <Object?>[numericId],
      );
      await txn.update(
        'xiangji_local_books',
        <String, Object?>{
          'local_uri': '',
          'parse_status': 'deleted',
          'parsed_characters': 0,
          'chunk_count': 0,
          'parse_error': '',
          'updated_at_ms': now,
          'deleted_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[numericId],
      );
    });
  }

  Future<String> exportJson() async {
    final db = await _database();
    const tables = <String>[
      'xiangji_goals',
      'xiangji_goal_versions',
      'xiangji_goal_state_events',
      'xiangji_daily_steps',
      'xiangji_checkins',
      'xiangji_growth_evidence',
      'xiangji_mentor_sessions',
      'xiangji_calibrations',
      'xiangji_reminder_settings',
      'xiangji_reminder_deliveries',
      'xiangji_local_books',
      'xiangji_provider_mirrors',
      'xiangji_provider_events',
      'xiangji_generation_audits',
    ];
    final payload = <String, Object?>{
      'product': '向己智能目标导师',
      'schema_version': '1.1.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final table in tables) {
      payload[table] = await db.query(table);
    }
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> deleteAllData() async {
    final db = await _database();
    const tables = <String>[
      'xiangji_generation_audits',
      'xiangji_provider_events',
      'xiangji_provider_mirrors',
      'xiangji_book_chunks',
      'xiangji_growth_evidence',
      'xiangji_checkins',
      'xiangji_daily_steps',
      'xiangji_mentor_sessions',
      'xiangji_calibrations',
      'xiangji_goal_state_events',
      'xiangji_reminder_deliveries',
      'xiangji_goal_versions',
      'xiangji_goals',
      'xiangji_reminder_settings',
      'xiangji_local_books',
    ];
    var secureDeleteEnabled = false;
    try {
      await db.execute('PRAGMA secure_delete = ON');
      secureDeleteEnabled = true;
    } catch (_) {}
    try {
      await db.transaction<void>((txn) async {
        for (final table in tables) {
          await txn.delete(table);
        }
      });
    } finally {
      if (secureDeleteEnabled) {
        try {
          await db.execute('PRAGMA secure_delete = OFF');
        } catch (_) {}
      }
    }
  }

  static Future<int> _insertStep(
    DatabaseExecutor db, {
    required int goalId,
    required int goalVersionId,
    required XiangjiDailyStep step,
    required int now,
  }) {
    return db.insert('xiangji_daily_steps', <String, Object?>{
      'goal_id': goalId,
      'goal_version_id': goalVersionId,
      'action_text': step.actionText,
      'trigger_context': step.triggerContext,
      'minimum_done': step.minimumDone,
      'evidence_rule': step.evidenceRule,
      'controllability_reason': step.controllabilityReason,
      'smaller_variant': step.smallerVariant,
      'source_system_id': step.sourceSystemId,
      'status': 'ready',
      'created_at_ms': now,
      'updated_at_ms': now,
    });
  }

  static Future<void> _insertMentorSession(
    DatabaseExecutor db, {
    required int goalId,
    required String userInput,
    required XiangjiGuidance guidance,
    required XiangjiZoomMode zoomMode,
    required String kbVersion,
    required int now,
  }) async {
    final structured = <String, Object?>{
      'mentor': guidance.mentorName,
      'mechanism': guidance.mechanismLabel,
      'core_judgment': guidance.coreJudgment,
      'selection_reason': guidance.selectionReason,
      'boundary_note': guidance.boundaryNote,
      'source_ids': guidance.sources.map((item) => item.sourceId).toList(),
      'evidence_ids': guidance.sources.map((item) => item.evidenceId).toList(),
      'content_type': 'kb_application',
    };
    await db.insert('xiangji_mentor_sessions', <String, Object?>{
      'goal_id': goalId,
      'user_input': userInput,
      'surface_problem': userInput,
      'mechanism_id': guidance.mechanismId,
      'mechanism_label': guidance.mechanismLabel,
      'primary_thinker_id': guidance.systemId,
      'zoom_mode': zoomMode.name,
      'confidence': guidance.confidence,
      'structured_output_json': jsonEncode(structured),
      'kb_version': kbVersion,
      'validation_status': guidance.sources.isEmpty ? 'coverage_insufficient' : 'validated',
      'created_at_ms': now,
    });
  }

  static Future<void> _insertStateEvent(
    DatabaseExecutor db, {
    required int goalId,
    required XiangjiGoalState from,
    required XiangjiGoalState to,
    required String trigger,
    required String reason,
  }) async {
    await db.insert('xiangji_goal_state_events', <String, Object?>{
      'goal_id': goalId,
      'from_state': from.value,
      'to_state': to.value,
      'trigger': trigger,
      'reason': reason,
      'actor': 'user',
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static XiangjiBookInfo _bookFromRow(Map<String, Object?> row) {
    final numericId = _int(row['id']);
    final provider = (row['mirror_provider'] ?? '').toString();
    final mirror = provider.isEmpty
        ? null
        : XiangjiProviderMirror(
            bookId: 'local_$numericId',
            provider: provider,
            providerFileId: (row['mirror_file_id'] ?? '').toString(),
            providerIndexId: (row['mirror_index_id'] ?? '').toString(),
            syncedHash: (row['mirror_synced_hash'] ?? '').toString(),
            syncStatus:
                (row['mirror_sync_status'] ?? 'pending').toString(),
            indexedStatus:
                (row['mirror_indexed_status'] ?? 'pending').toString(),
            consentedAtMs: _int(row['mirror_consented_at_ms']),
            lastError: (row['mirror_last_error'] ?? '').toString(),
            createdAtMs: _int(row['mirror_created_at_ms']),
            updatedAtMs: _int(row['mirror_updated_at_ms']),
          );
    return XiangjiBookInfo(
      id: 'local_$numericId',
      title: (row['title'] ?? '').toString(),
      author: (row['author'] ?? '').toString(),
      edition: (row['edition'] ?? '').toString(),
      sourceStatus: 'private_local',
      builtIn: false,
      localPath: (row['local_uri'] ?? '').toString(),
      contentHash: (row['content_hash'] ?? '').toString(),
      parseStatus: (row['parse_status'] ?? 'pending').toString(),
      mimeType: (row['mime_type'] ?? '').toString(),
      sizeBytes: _int(row['size_bytes']),
      parsedCharacters: _int(row['parsed_characters']),
      chunkCount: _int(row['chunk_count']),
      parseError: (row['parse_error'] ?? '').toString(),
      providerMirror: mirror,
    );
  }

  static XiangjiBookChunk _chunkFromRow(Map<String, Object?> row) =>
      XiangjiBookChunk(
        id: (row['chunk_uid'] ?? '').toString(),
        bookId: 'local_${_int(row['book_id'])}',
        bookTitle: (row['book_title'] ?? '').toString(),
        chunkIndex: _int(row['chunk_index']),
        sectionTitle: (row['section_title'] ?? '').toString(),
        locator: (row['source_locator'] ?? '').toString(),
        text: (row['text_content'] ?? '').toString(),
        contentHash: (row['content_hash'] ?? '').toString(),
      );

  static XiangjiProviderMirror _mirrorFromRow(Map<String, Object?> row) =>
      XiangjiProviderMirror(
        bookId: 'local_${_int(row['book_id'])}',
        provider: (row['provider'] ?? 'openai').toString(),
        providerFileId: (row['provider_file_id'] ?? '').toString(),
        providerIndexId: (row['provider_index_id'] ?? '').toString(),
        syncedHash: (row['synced_hash'] ?? '').toString(),
        syncStatus: (row['sync_status'] ?? 'pending').toString(),
        indexedStatus: (row['indexed_status'] ?? 'pending').toString(),
        consentedAtMs: _int(row['consented_at_ms']),
        lastError: (row['last_error'] ?? '').toString(),
        createdAtMs: _int(row['created_at_ms']),
        updatedAtMs: _int(row['updated_at_ms']),
      );

  static int? _localBookId(String id) {
    final normalized = id.trim();
    if (!normalized.startsWith('local_')) return null;
    return int.tryParse(normalized.substring('local_'.length));
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  static String _safeAuditText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 237)}...';
  }

  static XiangjiGoalState _stateForCalibration(
    XiangjiCalibrationResult result,
  ) {
    switch (result) {
      case XiangjiCalibrationResult.continueGoal:
      case XiangjiCalibrationResult.changeMethod:
      case XiangjiCalibrationResult.reduceScope:
        return XiangjiGoalState.active;
      case XiangjiCalibrationResult.pause:
        return XiangjiGoalState.paused;
      case XiangjiCalibrationResult.reselect:
        return XiangjiGoalState.reselecting;
    }
  }

}

class _XiangjiReminderContent {
  const _XiangjiReminderContent({required this.type, required this.body});

  final String type;
  final String body;
}
