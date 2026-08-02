import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'xiangji_models.dart';

class XiangjiGoalMentorDao {
  static Future<void>? _schemaFuture;

  Future<Database> _database() async {
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
    await batch.commit(noResult: true);
    final goalColumns = await db.rawQuery('PRAGMA table_info(xiangji_goals)');
    if (!goalColumns.any(
      (column) => column['name']?.toString() == 'last_interaction_at_ms',
    )) {
      await db.execute(
        'ALTER TABLE xiangji_goals ADD COLUMN last_interaction_at_ms INTEGER',
      );
    }
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
    final allowed = <String>{
      'completed',
      'partially_completed',
      'not_started',
      'blocked',
      'no_longer_relevant',
    };
    if (!allowed.contains(resultType)) {
      throw ArgumentError.value(resultType, 'resultType');
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
        !_allowedTransition(goal.state, XiangjiGoalState.calibrating)) {
      throw StateError(
        'INVALID_GOAL_TRANSITION:${goal.state.value}->${XiangjiGoalState.calibrating.value}',
      );
    }
    final target = _stateForCalibration(decision.result);
    if (!_allowedTransition(XiangjiGoalState.calibrating, target)) {
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
    if (!_allowedTransition(goal.state, target)) {
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
    return _reminderContentForGoal(goal);
  }

  Future<String?> scheduledReminderContent() async {
    final goal = await activeGoal();
    if (goal == null || goal.state == XiangjiGoalState.archived) return null;
    final lastInteraction = await _lastInteractionAtMs(goal.id);
    final silenceDays = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastInteraction))
        .inDays;
    if (silenceDays >= 21) {
      if ((silenceDays - 21) % 7 != 0) return null;
      return '你曾经说过：“${goal.originalText}”\n'
          '现在是目标变了，还是生活暂时占据了注意力？不必用补作业的方式回来。';
    }
    if (silenceDays >= 7 && (silenceDays - 7) % 3 != 0) return null;
    return _reminderContentForGoal(goal);
  }

  Future<String?> _reminderContentForGoal(XiangjiGoal goal) async {
    if (goal.state == XiangjiGoalState.completed) {
      return '你已经完成“${goal.originalText}”。先不急着制造更高目标，看看这段经历形成了什么能力，以及是否需要巩固、分享或休息。';
    }
    if (goal.state == XiangjiGoalState.paused) {
      return '你暂停的是推进，不是你重视的“${goal.higherValues.join('、')}”。现在不必催促自己。';
    }
    if (goal.state == XiangjiGoalState.reselecting) {
      return '具体路径可以改变，你仍可以保留“${goal.higherValues.join('、')}”这些高层价值。';
    }
    final step = await currentStep(goal.id);
    if (step != null &&
        (step.status == 'ready' || step.status == 'in_progress')) {
      return '你曾说：“${goal.originalText}”\n今日一步：${step.actionText}';
    }
    final evidence = await evidenceForGoal(goal.id);
    if (evidence.isNotEmpty) {
      return '你曾说：“${goal.originalText}”\n最近的成长证据：${evidence.first.summary}';
    }
    return '你曾经说过，这件事对你很重要。现在是目标变了，还是生活暂时占据了注意力？';
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
    final rows = await db.query(
      'xiangji_local_books',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'created_at_ms DESC',
    );
    return rows
        .map(
          (row) => XiangjiBookInfo(
            id: 'local_${row['id']}',
            title: (row['title'] ?? '').toString(),
            author: (row['author'] ?? '').toString(),
            edition: (row['edition'] ?? '').toString(),
            sourceStatus: 'private_local',
            builtIn: false,
            localPath: (row['local_uri'] ?? '').toString(),
            contentHash: (row['content_hash'] ?? '').toString(),
            parseStatus: (row['parse_status'] ?? 'pending').toString(),
          ),
        )
        .toList(growable: false);
  }

  Future<int> saveImportedBook({
    required String title,
    required String localPath,
    required String contentHash,
  }) async {
    final db = await _database();
    return db.insert('xiangji_local_books', <String, Object?>{
      'title': title,
      'author': '',
      'edition': '',
      'local_uri': localPath,
      'content_hash': contentHash,
      'parse_status': 'local_only',
      'permission_scope': 'private',
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> markImportedBookDeleted(String id) async {
    final numericId = int.tryParse(id.replaceFirst('local_', ''));
    if (numericId == null) return;
    final db = await _database();
    await db.update(
      'xiangji_local_books',
      <String, Object?>{
        'deleted_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[numericId],
    );
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
      'xiangji_local_books',
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
      'xiangji_growth_evidence',
      'xiangji_checkins',
      'xiangji_daily_steps',
      'xiangji_mentor_sessions',
      'xiangji_calibrations',
      'xiangji_goal_state_events',
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

  static bool _allowedTransition(
    XiangjiGoalState from,
    XiangjiGoalState to,
  ) {
    const allowed = <XiangjiGoalState, Set<XiangjiGoalState>>{
      XiangjiGoalState.mist: <XiangjiGoalState>{XiangjiGoalState.spark},
      XiangjiGoalState.spark: <XiangjiGoalState>{
        XiangjiGoalState.anchored,
        XiangjiGoalState.mist,
        XiangjiGoalState.archived,
      },
      XiangjiGoalState.anchored: <XiangjiGoalState>{
        XiangjiGoalState.active,
        XiangjiGoalState.paused,
        XiangjiGoalState.reselecting,
      },
      XiangjiGoalState.active: <XiangjiGoalState>{
        XiangjiGoalState.feedback,
        XiangjiGoalState.paused,
        XiangjiGoalState.calibrating,
        XiangjiGoalState.completed,
      },
      XiangjiGoalState.feedback: <XiangjiGoalState>{
        XiangjiGoalState.active,
        XiangjiGoalState.calibrating,
        XiangjiGoalState.completed,
      },
      XiangjiGoalState.calibrating: <XiangjiGoalState>{
        XiangjiGoalState.active,
        XiangjiGoalState.paused,
        XiangjiGoalState.reselecting,
        XiangjiGoalState.completed,
      },
      XiangjiGoalState.paused: <XiangjiGoalState>{
        XiangjiGoalState.active,
        XiangjiGoalState.calibrating,
        XiangjiGoalState.reselecting,
        XiangjiGoalState.archived,
      },
      XiangjiGoalState.reselecting: <XiangjiGoalState>{
        XiangjiGoalState.spark,
        XiangjiGoalState.anchored,
        XiangjiGoalState.archived,
      },
      XiangjiGoalState.completed: <XiangjiGoalState>{
        XiangjiGoalState.archived,
        XiangjiGoalState.spark,
      },
      XiangjiGoalState.archived: <XiangjiGoalState>{},
    };
    return allowed[from]?.contains(to) ?? false;
  }
}
