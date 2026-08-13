import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_policies.dart';
import 'belief_mentor_privacy.dart';
import 'belief_mentor_story_catalog.dart';

class BeliefMentorDao {
  BeliefMentorDao({
    Database? database,
    BeliefMentorSensitiveCodec codec = const BeliefMentorSensitiveCodec(),
  }) : _database = database,
       _codec = codec;

  final Database? _database;
  final BeliefMentorSensitiveCodec _codec;
  bool _schemaReady = false;
  Future<void>? _schemaInitialization;

  Future<Database> _db() async {
    final db = _database ?? await AppDatabase.instance();
    if (!_schemaReady) {
      _schemaInitialization ??= _initializeSchema(db);
      await _schemaInitialization;
      _schemaReady = true;
    }
    return db;
  }

  Future<void> ensureSchema([Database? target]) async {
    final db = target ?? _database ?? await AppDatabase.instance();
    await _initializeSchema(db);
    _schemaReady = true;
  }

  Future<void> _initializeSchema(Database db) async {
    await db.rawQuery('PRAGMA secure_delete = ON');
    for (final statement in _schemaStatements) {
      await db.execute(statement);
    }
    await _ensureSchemaColumns(db);
    await _migrateSensitiveText(db);
    await _seedStories(db);
  }

  static const List<String> _schemaStatements = <String>[
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        domains_json TEXT NOT NULL DEFAULT '[]',
        reminders_enabled INTEGER NOT NULL DEFAULT 0,
        quiet_start TEXT NOT NULL DEFAULT '22:00',
        quiet_end TEXT NOT NULL DEFAULT '08:00',
        morning_time TEXT NOT NULL DEFAULT '08:30',
        tone TEXT NOT NULL DEFAULT 'coach',
        notifications_paused INTEGER NOT NULL DEFAULT 0,
        needs_space_until_ms INTEGER NOT NULL DEFAULT 0,
        timezone TEXT NOT NULL DEFAULT '',
        active_belief_id TEXT NOT NULL DEFAULT '',
        show_sensitive_notification_content INTEGER NOT NULL DEFAULT 0,
        model_improvement_opt_in INTEGER NOT NULL DEFAULT 0,
        updated_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_beliefs (
        id TEXT PRIMARY KEY,
        statement TEXT NOT NULL,
        belief_type TEXT NOT NULL,
        strength INTEGER NOT NULL DEFAULT 50,
        initial_strength INTEGER NOT NULL DEFAULT 50,
        trigger_text TEXT NOT NULL DEFAULT '',
        alternative_statement TEXT NOT NULL DEFAULT '',
        state TEXT NOT NULL,
        user_confirmed INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        testing_started_at_ms INTEGER NOT NULL DEFAULT 0,
        patterns_json TEXT NOT NULL DEFAULT '[]'
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_belief_scores (
        id TEXT PRIMARY KEY,
        belief_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        source TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_experiments (
        id TEXT PRIMARY KEY,
        belief_id TEXT NOT NULL,
        action_text TEXT NOT NULL,
        minimum_version TEXT NOT NULL,
        fallback_action TEXT NOT NULL,
        scheduled_at_ms INTEGER NOT NULL,
        timezone TEXT NOT NULL DEFAULT '',
        difficulty INTEGER NOT NULL,
        completion_probability INTEGER NOT NULL,
        state TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        started_at_ms INTEGER NOT NULL DEFAULT 0,
        completed_at_ms INTEGER NOT NULL DEFAULT 0,
        revision_of_id TEXT NOT NULL DEFAULT '',
        revision_reason TEXT NOT NULL DEFAULT ''
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_evidence (
        id TEXT PRIMARY KEY,
        belief_id TEXT NOT NULL,
        experiment_id TEXT NOT NULL DEFAULT '',
        prediction_text TEXT NOT NULL DEFAULT '',
        predicted_failure_probability INTEGER NOT NULL DEFAULT 50,
        prediction_occurred INTEGER NOT NULL DEFAULT 0,
        action_text TEXT NOT NULL,
        outcome_text TEXT NOT NULL,
        emotion_before INTEGER NOT NULL DEFAULT 0,
        emotion_after INTEGER NOT NULL DEFAULT 0,
        learning_text TEXT NOT NULL DEFAULT '',
        evidence_statement TEXT NOT NULL,
        strength TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_reminders (
        id TEXT PRIMARY KEY,
        experiment_id TEXT NOT NULL DEFAULT '',
        belief_id TEXT NOT NULL DEFAULT '',
        reminder_type TEXT NOT NULL,
        scheduled_at_ms INTEGER NOT NULL,
        state TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        alarm_id INTEGER NOT NULL,
        delivery_key TEXT NOT NULL UNIQUE,
        suppress_reason TEXT NOT NULL DEFAULT '',
        ignored_count INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_stories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_type TEXT NOT NULL,
        hook TEXT NOT NULL,
        story_text TEXT NOT NULL,
        mechanism TEXT NOT NULL,
        boundary_text TEXT NOT NULL,
        reflection_question TEXT NOT NULL,
        proposed_experiment TEXT NOT NULL,
        evidence_grade TEXT NOT NULL,
        source_label TEXT NOT NULL,
        review_status TEXT NOT NULL,
        content_version TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_story_views (
        id TEXT PRIMARY KEY,
        story_id TEXT NOT NULL,
        belief_id TEXT NOT NULL DEFAULT '',
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_failures (
        id TEXT PRIMARY KEY,
        belief_id TEXT NOT NULL,
        experiment_id TEXT NOT NULL DEFAULT '',
        facts TEXT NOT NULL DEFAULT '',
        interpretation_text TEXT NOT NULL DEFAULT '',
        emotion_text TEXT NOT NULL DEFAULT '',
        learning_text TEXT NOT NULL DEFAULT '',
        next_step TEXT NOT NULL DEFAULT '',
        stage TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        closed_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''',
    '''
      CREATE UNIQUE INDEX IF NOT EXISTS belief_mentor_open_recovery_unique
      ON belief_mentor_failures(experiment_id)
      WHERE closed_at_ms = 0 AND experiment_id <> ''
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_agent_runs (
        id TEXT PRIMARY KEY,
        agent TEXT NOT NULL,
        input_hash TEXT NOT NULL DEFAULT '',
        output_json TEXT NOT NULL DEFAULT '{}',
        provider TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL DEFAULT '',
        run_status TEXT NOT NULL,
        redacted_count INTEGER NOT NULL DEFAULT 0,
        failure_message TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_events (
        id TEXT PRIMARY KEY,
        event_name TEXT NOT NULL,
        belief_id TEXT NOT NULL DEFAULT '',
        experiment_id TEXT NOT NULL DEFAULT '',
        properties_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE INDEX IF NOT EXISTS belief_mentor_events_time_idx
      ON belief_mentor_events(created_at_ms)
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_safety_events (
        id TEXT PRIMARY KEY,
        risk_category TEXT NOT NULL,
        policy_action TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_privacy_audit (
        id TEXT PRIMARY KEY,
        event_name TEXT NOT NULL,
        details_json TEXT NOT NULL DEFAULT '{}',
        created_at_ms INTEGER NOT NULL
      )
    ''',
  ];

  Future<void> _ensureSchemaColumns(Database db) async {
    await _ensureColumn(
      db,
      'belief_mentor_profile',
      'active_belief_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'belief_mentor_profile',
      'show_sensitive_notification_content',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'belief_mentor_profile',
      'model_improvement_opt_in',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'belief_mentor_beliefs',
      'patterns_json',
      "TEXT NOT NULL DEFAULT '[]'",
    );
    await _ensureColumn(
      db,
      'belief_mentor_experiments',
      'revision_of_id',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'belief_mentor_failures',
      'learning_text',
      "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      'belief_mentor_evidence',
      'predicted_failure_probability',
      'INTEGER NOT NULL DEFAULT 50',
    );
    await _ensureColumn(
      db,
      'belief_mentor_evidence',
      'prediction_occurred',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      'belief_mentor_experiments',
      'revision_reason',
      "TEXT NOT NULL DEFAULT ''",
    );
  }

  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    if (rows.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  static const Map<String, List<String>> _sensitiveColumns =
      <String, List<String>>{
        'belief_mentor_profile': <String>['domains_json'],
        'belief_mentor_beliefs': <String>[
          'statement',
          'trigger_text',
          'alternative_statement',
        ],
        'belief_mentor_experiments': <String>[
          'action_text',
          'minimum_version',
          'fallback_action',
          'revision_reason',
        ],
        'belief_mentor_evidence': <String>[
          'prediction_text',
          'action_text',
          'outcome_text',
          'learning_text',
          'evidence_statement',
        ],
        'belief_mentor_reminders': <String>['title', 'body'],
        'belief_mentor_failures': <String>[
          'facts',
          'interpretation_text',
          'emotion_text',
          'learning_text',
          'next_step',
        ],
        'belief_mentor_agent_runs': <String>['output_json', 'failure_message'],
      };

  Future<void> _migrateSensitiveText(Database db) async {
    for (final entry in _sensitiveColumns.entries) {
      final rows = await db.query(entry.key);
      for (final row in rows) {
        final id = row['id'];
        final updates = <String, Object?>{};
        for (final column in entry.value) {
          final value = (row[column] ?? '').toString();
          if (value.isEmpty || _codec.isEncrypted(value)) continue;
          updates[column] = await _codec.encrypt(value);
        }
        if (updates.isNotEmpty) {
          await db.update(
            entry.key,
            updates,
            where: 'id = ?',
            whereArgs: <Object?>[id],
          );
        }
      }
    }
  }

  Future<Map<String, Object?>> _encryptRow(
    String table,
    Map<String, Object?> row,
  ) async {
    final result = Map<String, Object?>.from(row);
    for (final column in _sensitiveColumns[table] ?? const <String>[]) {
      if (!result.containsKey(column)) continue;
      result[column] = await _codec.encrypt((result[column] ?? '').toString());
    }
    return result;
  }

  Future<Map<String, Object?>> _decryptRow(
    String table,
    Map<String, Object?> row,
  ) async {
    final result = Map<String, Object?>.from(row);
    for (final column in _sensitiveColumns[table] ?? const <String>[]) {
      if (!result.containsKey(column)) continue;
      result[column] = await _codec.decrypt((result[column] ?? '').toString());
    }
    return result;
  }

  Future<List<Map<String, Object?>>> _decryptRows(
    String table,
    List<Map<String, Object?>> rows,
  ) => Future.wait(rows.map((row) => _decryptRow(table, row)));

  Future<void> _seedStories(Database db) async {
    await db.transaction((txn) async {
      for (final story in BeliefMentorStoryCatalog.all) {
        await txn.insert('belief_mentor_stories', <String, Object?>{
          ...story.toRow(),
          'content_version': BeliefMentorStoryCatalog.version,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<BeliefMentorProfile> profile() async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_profile',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return BeliefMentorProfile.fromRow(
        await _decryptRow('belief_mentor_profile', rows.first),
      );
    }
    final value = BeliefMentorProfile(
      timezone: DateTime.now().timeZoneName,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await saveProfile(value);
    return value;
  }

  Future<void> saveProfile(BeliefMentorProfile value) async {
    final db = await _db();
    await db.insert(
      'belief_mentor_profile',
      await _encryptRow(
        'belief_mentor_profile',
        value
            .copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch)
            .toRow(),
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveBelief(
    BeliefMentorBelief belief, {
    String scoreSource = 'user',
  }) async {
    if (belief.statement.trim().isEmpty) {
      throw StateError('信念陈述不能为空。');
    }
    if (belief.userConfirmed) {
      final safety = BeliefMentorSafetyPolicy.assess(
        '${belief.statement} ${belief.trigger} ${belief.alternativeStatement}',
      );
      if (safety.blocksNormalFlow) {
        await recordSafetyEvent(
          category: safety.category,
          action: 'blocked_belief_write',
          source: scoreSource,
        );
        throw StateError(safety.message);
      }
    }
    final db = await _db();
    await db.transaction((txn) async {
      await txn.insert(
        'belief_mentor_beliefs',
        await _encryptRow('belief_mentor_beliefs', belief.toRow()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('belief_mentor_belief_scores', <String, Object?>{
        'id': _id('score'),
        'belief_id': belief.id,
        'score': belief.strength,
        'source': scoreSource,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    });
    await track(
      scoreSource == 'user_edit'
          ? 'belief_updated'
          : belief.userConfirmed
          ? 'belief_created'
          : 'belief_candidate_created',
      beliefId: belief.id,
      properties: <String, Object?>{
        'type': belief.type.name,
        'strength': belief.strength,
        'state': belief.state.name,
      },
    );
  }

  Future<List<BeliefMentorBelief>> beliefs({
    bool includeArchived = false,
  }) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_beliefs',
      where: includeArchived ? null : 'state <> ?',
      whereArgs: includeArchived
          ? null
          : <Object?>[BeliefMentorBeliefState.archived.name],
      orderBy: 'user_confirmed DESC, updated_at_ms DESC',
    );
    final decrypted = await _decryptRows('belief_mentor_beliefs', rows);
    return decrypted.map(BeliefMentorBelief.fromRow).toList(growable: false);
  }

  Future<BeliefMentorBelief?> belief(String id) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_beliefs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : BeliefMentorBelief.fromRow(
            await _decryptRow('belief_mentor_beliefs', rows.first),
          );
  }

  Future<void> confirmBelief({
    required String id,
    required String statement,
    required BeliefMentorBeliefType type,
    required int strength,
    required String trigger,
    required String alternative,
    List<BeliefMentorCognitivePattern>? patterns,
  }) async {
    final existing = await belief(id);
    if (existing == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextState = alternative.trim().isEmpty
        ? BeliefMentorBeliefState.activeLimiting
        : BeliefMentorBeliefState.alternativeFormed;
    await saveBelief(
      BeliefMentorBelief(
        id: id,
        statement: statement.trim(),
        type: type,
        strength: strength.clamp(0, 100),
        initialStrength: existing.initialStrength == 0
            ? strength.clamp(0, 100)
            : existing.initialStrength,
        trigger: trigger.trim(),
        alternativeStatement: alternative.trim(),
        state: nextState,
        userConfirmed: true,
        createdAtMs: existing.createdAtMs,
        updatedAtMs: now,
        testingStartedAtMs: existing.testingStartedAtMs,
        patterns: patterns ?? existing.patterns,
      ),
      scoreSource: 'confirmation',
    );
    final currentProfile = await profile();
    if (currentProfile.activeBeliefId.isEmpty) {
      await saveProfile(currentProfile.copyWith(activeBeliefId: id));
    }
  }

  Future<void> updateBelief({
    required String id,
    required String statement,
    required BeliefMentorBeliefType type,
    required int strength,
    required String trigger,
    required String alternative,
    required List<BeliefMentorCognitivePattern> patterns,
  }) async {
    final current = await belief(id);
    if (current == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    var nextState = current.state;
    if (current.userConfirmed &&
        current.state != BeliefMentorBeliefState.archived) {
      final candidate = alternative.trim().isEmpty
          ? BeliefMentorBeliefState.activeLimiting
          : current.state == BeliefMentorBeliefState.activeLimiting
          ? BeliefMentorBeliefState.alternativeFormed
          : current.state;
      if (candidate != current.state &&
          BeliefMentorTransitionPolicy.canTransition(
            current.state,
            candidate,
          )) {
        nextState = candidate;
      }
    }
    await saveBelief(
      BeliefMentorBelief(
        id: current.id,
        statement: statement.trim(),
        type: type,
        strength: strength.clamp(0, 100),
        initialStrength: current.initialStrength,
        trigger: trigger.trim(),
        alternativeStatement: alternative.trim(),
        state: nextState,
        userConfirmed: current.userConfirmed,
        createdAtMs: current.createdAtMs,
        updatedAtMs: now,
        testingStartedAtMs: current.testingStartedAtMs,
        patterns: patterns,
      ),
      scoreSource: 'user_edit',
    );
    await track(
      'belief_edited',
      beliefId: id,
      properties: <String, Object?>{
        'type': type.name,
        'pattern_count': patterns.length,
      },
    );
  }

  Future<void> setActiveBelief(String id) async {
    final value = await belief(id);
    if (value == null ||
        !value.userConfirmed ||
        value.state == BeliefMentorBeliefState.archived) {
      throw StateError('只能把已确认且未归档的信念设为当前信念。');
    }
    final current = await profile();
    await saveProfile(current.copyWith(activeBeliefId: id));
    await track('active_belief_changed', beliefId: id);
  }

  /// Archives a belief and closes its still-active reminders.
  ///
  /// The returned alarm IDs must be cancelled by the platform reminder layer.
  Future<List<int>> archiveBelief(String id) async {
    final current = await belief(id);
    if (current == null) return const <int>[];
    final db = await _db();
    final reminderRows = await db.query(
      'belief_mentor_reminders',
      columns: <String>['alarm_id'],
      where: 'belief_id = ? AND state NOT IN (?, ?, ?)',
      whereArgs: <Object?>[
        id,
        BeliefMentorReminderState.closed.name,
        BeliefMentorReminderState.suppressed.name,
        BeliefMentorReminderState.evidenceCreated.name,
      ],
    );
    final alarmIds = reminderRows
        .map((row) => _rowInt(row['alarm_id']))
        .where((value) => value > 0)
        .toList(growable: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'belief_mentor_beliefs',
        <String, Object?>{
          'state': BeliefMentorBeliefState.archived.name,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.update(
        'belief_mentor_reminders',
        <String, Object?>{
          'state': BeliefMentorReminderState.closed.name,
          'suppress_reason': '信念已归档',
          'updated_at_ms': now,
        },
        where: 'belief_id = ? AND state NOT IN (?, ?, ?)',
        whereArgs: <Object?>[
          id,
          BeliefMentorReminderState.closed.name,
          BeliefMentorReminderState.suppressed.name,
          BeliefMentorReminderState.evidenceCreated.name,
        ],
      );
    });
    final currentProfile = await profile();
    if (currentProfile.activeBeliefId == id) {
      final alternatives = await beliefs();
      final next = alternatives.where(
        (item) => item.id != id && item.userConfirmed,
      );
      await saveProfile(
        currentProfile.copyWith(
          activeBeliefId: next.isEmpty ? '' : next.first.id,
        ),
      );
    }
    await track('belief_archived', beliefId: id);
    return alarmIds;
  }

  /// Permanently removes one belief and all of its dependent user records.
  /// Reviewed catalog stories and the deletion audit are intentionally retained.
  Future<List<int>> deleteBelief(String id) async {
    final db = await _db();
    final reminderRows = await db.query(
      'belief_mentor_reminders',
      columns: <String>['alarm_id'],
      where: 'belief_id = ?',
      whereArgs: <Object?>[id],
    );
    final alarmIds = reminderRows
        .map((row) => _rowInt(row['alarm_id']))
        .where((value) => value > 0)
        .toList(growable: false);
    await db.transaction((txn) async {
      for (final table in const <String>[
        'belief_mentor_reminders',
        'belief_mentor_evidence',
        'belief_mentor_failures',
        'belief_mentor_experiments',
        'belief_mentor_story_views',
        'belief_mentor_belief_scores',
        'belief_mentor_events',
      ]) {
        await txn.delete(
          table,
          where: 'belief_id = ?',
          whereArgs: <Object?>[id],
        );
      }
      await txn.delete(
        'belief_mentor_beliefs',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.insert('belief_mentor_privacy_audit', <String, Object?>{
        'id': _id('privacy_audit'),
        'event_name': 'belief_deleted',
        'details_json': jsonEncode(<String, Object?>{
          'belief_id_hash': id.hashCode.toUnsigned(32).toRadixString(16),
          'alarm_count': alarmIds.length,
        }),
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    });
    final currentProfile = await profile();
    if (currentProfile.activeBeliefId == id) {
      final remaining = await beliefs();
      final confirmed = remaining.where((item) => item.userConfirmed);
      await saveProfile(
        currentProfile.copyWith(
          activeBeliefId: confirmed.isEmpty ? '' : confirmed.first.id,
        ),
      );
    }
    return alarmIds;
  }

  Future<void> markBeliefNeedsRealityCheck(String id) async {
    final current = await belief(id);
    if (current == null ||
        !BeliefMentorTransitionPolicy.canTransition(
          current.state,
          BeliefMentorBeliefState.needsRealityCheck,
        )) {
      return;
    }
    await _updateBeliefState(id, BeliefMentorBeliefState.needsRealityCheck);
    await track('belief_reality_check_requested', beliefId: id);
  }

  Future<void> restoreBeliefFromRealityCheck(
    String id, {
    required bool continueTesting,
  }) async {
    final current = await belief(id);
    if (current == null ||
        current.state != BeliefMentorBeliefState.needsRealityCheck) {
      return;
    }
    final next = continueTesting
        ? BeliefMentorBeliefState.testing
        : BeliefMentorBeliefState.activeLimiting;
    await _updateBeliefState(id, next);
    await track(
      'belief_reality_check_completed',
      beliefId: id,
      properties: <String, Object?>{'next_state': next.name},
    );
  }

  Future<List<Map<String, Object?>>> beliefScoreHistory(String beliefId) async {
    final db = await _db();
    return db.query(
      'belief_mentor_belief_scores',
      where: 'belief_id = ?',
      whereArgs: <Object?>[beliefId],
      orderBy: 'created_at_ms ASC',
    );
  }

  Future<void> rejectBelief(String id) async {
    final current = await belief(id);
    if (current == null ||
        !BeliefMentorTransitionPolicy.canTransition(
          current.state,
          BeliefMentorBeliefState.userRejected,
        )) {
      return;
    }
    await _updateBeliefState(id, BeliefMentorBeliefState.userRejected);
  }

  Future<void> rescoreBelief(String id, int score) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await belief(id);
    if (current == null) return;
    await db.transaction((txn) async {
      await txn.update(
        'belief_mentor_beliefs',
        <String, Object?>{
          'strength': score.clamp(0, 100),
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.insert('belief_mentor_belief_scores', <String, Object?>{
        'id': _id('score'),
        'belief_id': id,
        'score': score.clamp(0, 100),
        'source': 'user_rescore',
        'created_at_ms': now,
      });
    });
    await track(
      'belief_rescored',
      beliefId: id,
      properties: <String, Object?>{
        'old': current.strength,
        'new': score.clamp(0, 100),
      },
    );
    await reconcileBeliefState(id);
  }

  Future<void> _updateBeliefState(
    String id,
    BeliefMentorBeliefState state,
  ) async {
    final db = await _db();
    await db.update(
      'belief_mentor_beliefs',
      <String, Object?>{
        'state': state.name,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<BeliefMentorExperiment> createExperiment({
    required String beliefId,
    required BeliefMentorExperimentDraft draft,
    required DateTime scheduledAt,
  }) async {
    final errors = BeliefMentorExperimentPolicy.validate(draft);
    if (errors.isNotEmpty) throw StateError(errors.join('；'));
    final safety = BeliefMentorSafetyPolicy.assess(
      '${draft.action} ${draft.minimumVersion} ${draft.fallbackAction}',
    );
    if (safety.blocksNormalFlow) {
      await recordSafetyEvent(
        category: safety.category,
        action: 'blocked_experiment_write',
        source: 'user_confirmation',
      );
      throw StateError(safety.message);
    }
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = BeliefMentorExperiment(
      id: _id('experiment'),
      beliefId: beliefId,
      action: draft.action.trim(),
      minimumVersion: draft.minimumVersion.trim(),
      fallbackAction: draft.fallbackAction.trim(),
      scheduledAtMs: scheduledAt.millisecondsSinceEpoch,
      timezone: DateTime.now().timeZoneName,
      difficulty: draft.difficulty,
      completionProbability: draft.completionProbability,
      state: BeliefMentorExperimentState.scheduled,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await db.insert(
      'belief_mentor_experiments',
      await _encryptRow('belief_mentor_experiments', value.toRow()),
    );
    final current = await belief(beliefId);
    if (current != null &&
        BeliefMentorTransitionPolicy.canTransition(
          current.state,
          BeliefMentorBeliefState.testing,
        )) {
      await db.update(
        'belief_mentor_beliefs',
        <String, Object?>{
          'state': BeliefMentorBeliefState.testing.name,
          'testing_started_at_ms': current.testingStartedAtMs == 0
              ? now
              : current.testingStartedAtMs,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[beliefId],
      );
    }
    await track(
      'experiment_created',
      beliefId: beliefId,
      experimentId: value.id,
      properties: <String, Object?>{
        'difficulty': value.difficulty,
        'probability': value.completionProbability,
      },
    );
    return value;
  }

  Future<BeliefMentorExperiment> reviseExperiment({
    required String experimentId,
    required BeliefMentorExperimentDraft draft,
    required DateTime scheduledAt,
    required bool resize,
    required String reason,
  }) async {
    final original = await experiment(experimentId);
    if (original == null) throw StateError('找不到要调整的实验。');
    final errors = BeliefMentorExperimentPolicy.validate(draft);
    if (errors.isNotEmpty) throw StateError(errors.join('；'));
    final targetState = resize
        ? BeliefMentorExperimentState.resized
        : BeliefMentorExperimentState.rescheduled;
    if (!BeliefMentorExperimentTransitionPolicy.canTransition(
      original.state,
      targetState,
    )) {
      throw StateError('当前实验状态不能执行这项调整。');
    }
    final safety = BeliefMentorSafetyPolicy.assess(
      '${draft.action} ${draft.minimumVersion} ${draft.fallbackAction}',
    );
    if (safety.blocksNormalFlow) {
      await recordSafetyEvent(
        category: safety.category,
        action: 'blocked_experiment_revision',
        source: 'user_edit',
      );
      throw StateError(safety.message);
    }
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = BeliefMentorExperiment(
      id: _id('experiment'),
      beliefId: original.beliefId,
      action: draft.action.trim(),
      minimumVersion: draft.minimumVersion.trim(),
      fallbackAction: draft.fallbackAction.trim(),
      scheduledAtMs: scheduledAt.millisecondsSinceEpoch,
      timezone: DateTime.now().timeZoneName,
      difficulty: draft.difficulty,
      completionProbability: draft.completionProbability,
      state: targetState,
      createdAtMs: now,
      updatedAtMs: now,
      revisionOfId: original.id,
      revisionReason: reason.trim(),
    );
    await db.transaction((txn) async {
      await txn.update(
        'belief_mentor_experiments',
        <String, Object?>{
          'state': BeliefMentorExperimentState.abandoned.name,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[original.id],
      );
      await txn.insert(
        'belief_mentor_experiments',
        await _encryptRow('belief_mentor_experiments', value.toRow()),
      );
      await txn.update(
        'belief_mentor_reminders',
        <String, Object?>{
          'state': BeliefMentorReminderState.closed.name,
          'suppress_reason': resize ? '实验已缩小' : '实验已改期',
          'updated_at_ms': now,
        },
        where: 'experiment_id = ? AND state NOT IN (?, ?)',
        whereArgs: <Object?>[
          original.id,
          BeliefMentorReminderState.closed.name,
          BeliefMentorReminderState.evidenceCreated.name,
        ],
      );
    });
    await track(
      resize ? 'experiment_resized' : 'experiment_rescheduled',
      beliefId: original.beliefId,
      experimentId: value.id,
      properties: <String, Object?>{
        'revision_of_id': original.id,
        'difficulty': value.difficulty,
        'probability': value.completionProbability,
      },
    );
    return value;
  }

  Future<List<BeliefMentorExperiment>> experiments({String? beliefId}) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_experiments',
      where: beliefId == null ? null : 'belief_id = ?',
      whereArgs: beliefId == null ? null : <Object?>[beliefId],
      orderBy: 'created_at_ms DESC',
    );
    final decrypted = await _decryptRows('belief_mentor_experiments', rows);
    return decrypted
        .map(BeliefMentorExperiment.fromRow)
        .toList(growable: false);
  }

  Future<BeliefMentorExperiment?> experiment(String id) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_experiments',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : BeliefMentorExperiment.fromRow(
            await _decryptRow('belief_mentor_experiments', rows.first),
          );
  }

  Future<void> startExperiment(String id, {String source = 'self'}) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = await experiment(id);
    if (value == null ||
        (value.state != BeliefMentorExperimentState.scheduled &&
            value.state != BeliefMentorExperimentState.draft &&
            value.state != BeliefMentorExperimentState.resized &&
            value.state != BeliefMentorExperimentState.rescheduled)) {
      return;
    }
    await db.update(
      'belief_mentor_experiments',
      <String, Object?>{
        'state': BeliefMentorExperimentState.started.name,
        'started_at_ms': now,
        'updated_at_ms': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    await db.update(
      'belief_mentor_reminders',
      <String, Object?>{
        'state': BeliefMentorReminderState.actionStarted.name,
        'updated_at_ms': now,
      },
      where: 'experiment_id = ? AND reminder_type IN (?, ?) AND state IN (?, ?, ?, ?)',
      whereArgs: <Object?>[
        id,
        BeliefMentorReminderType.preAction.name,
        BeliefMentorReminderType.antiAvoidance.name,
        BeliefMentorReminderState.scheduled.name,
        BeliefMentorReminderState.sent.name,
        BeliefMentorReminderState.opened.name,
        BeliefMentorReminderState.followUp.name,
      ],
    );
    await track(
      'experiment_started',
      beliefId: value.beliefId,
      experimentId: id,
      properties: <String, Object?>{'source': source},
    );
  }

  Future<void> completeExperiment(String id) async {
    final db = await _db();
    final value = await experiment(id);
    if (value == null ||
        !BeliefMentorExperimentTransitionPolicy.canTransition(
          value.state,
          BeliefMentorExperimentState.completed,
        )) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'belief_mentor_experiments',
        <String, Object?>{
          'state': BeliefMentorExperimentState.completed.name,
          'completed_at_ms': now,
          'updated_at_ms': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.update(
        'belief_mentor_reminders',
        <String, Object?>{
          'state': BeliefMentorReminderState.closed.name,
          'suppress_reason': '实验已完成',
          'updated_at_ms': now,
        },
        where: 'experiment_id = ? AND reminder_type = ? AND state = ?',
        whereArgs: <Object?>[
          id,
          BeliefMentorReminderType.antiAvoidance.name,
          BeliefMentorReminderState.scheduled.name,
        ],
      );
    });
    await track(
      'experiment_completed',
      beliefId: value.beliefId,
      experimentId: id,
    );
  }

  Future<void> startExperimentReflection(String id) async {
    final value = await experiment(id);
    if (value == null || value.state != BeliefMentorExperimentState.completed) {
      return;
    }
    final db = await _db();
    await db.update(
      'belief_mentor_experiments',
      <String, Object?>{
        'state': BeliefMentorExperimentState.reflection.name,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    await track(
      'reflection_started',
      beliefId: value.beliefId,
      experimentId: id,
    );
    await saveAgentRun(
      agent: 'ReflectionAgent',
      output: <String, Object?>{
        'questions': <String>[
          '你原本预测会发生什么？',
          '实际可观察结果是什么？',
          '你愿意把哪条更准确的解释保留下来？',
        ],
        'user_owned_belief': '',
      },
      provider: 'local',
      model: 'reflection-contract-v1',
      runStatus: 'awaiting_user_response',
      redactedCount: 0,
    );
  }

  Future<void> abandonExperiment(String id) async {
    final value = await experiment(id);
    if (value == null ||
        !BeliefMentorExperimentTransitionPolicy.canTransition(
          value.state,
          BeliefMentorExperimentState.abandoned,
        )) {
      return;
    }
    final db = await _db();
    await db.update(
      'belief_mentor_experiments',
      <String, Object?>{
        'state': BeliefMentorExperimentState.abandoned.name,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    await track(
      'experiment_abandoned',
      beliefId: value.beliefId,
      experimentId: id,
    );
  }

  Future<void> saveEvidence(BeliefMentorEvidence value) async {
    if (value.action.trim().isEmpty ||
        value.outcome.trim().isEmpty ||
        value.statement.trim().isEmpty) {
      throw StateError('证据必须包含实际行动、可观察结果和证据句。');
    }
    final safety = BeliefMentorSafetyPolicy.assess(
      '${value.prediction} ${value.action} ${value.outcome} '
      '${value.learning} ${value.statement}',
    );
    if (safety.blocksNormalFlow) {
      await recordSafetyEvent(
        category: safety.category,
        action: 'blocked_evidence_write',
        source: 'user_edit',
      );
      throw StateError(safety.message);
    }
    if (value.experimentId.isNotEmpty) {
      final sourceExperiment = await experiment(value.experimentId);
      if (sourceExperiment == null ||
          !BeliefMentorExperimentTransitionPolicy.canTransition(
            sourceExperiment.state,
            BeliefMentorExperimentState.evidenceCreated,
          )) {
        throw StateError('当前实验尚未进入可复盘状态。');
      }
    }
    final db = await _db();
    await db.transaction((txn) async {
      await txn.insert(
        'belief_mentor_evidence',
        await _encryptRow('belief_mentor_evidence', value.toRow()),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (value.experimentId.isNotEmpty) {
        await txn.update(
          'belief_mentor_experiments',
          <String, Object?>{
            'state': BeliefMentorExperimentState.evidenceCreated.name,
            'updated_at_ms': value.createdAtMs,
          },
          where: 'id = ?',
          whereArgs: <Object?>[value.experimentId],
        );
        await txn.update(
          'belief_mentor_reminders',
          <String, Object?>{
            'state': BeliefMentorReminderState.evidenceCreated.name,
            'updated_at_ms': value.createdAtMs,
          },
          where: 'experiment_id = ? AND state <> ?',
          whereArgs: <Object?>[
            value.experimentId,
            BeliefMentorReminderState.closed.name,
          ],
        );
      }
    });
    await track(
      'evidence_created',
      beliefId: value.beliefId,
      experimentId: value.experimentId,
      properties: <String, Object?>{'evidence_strength': value.strength.name},
    );
    await saveAgentRun(
      agent: 'EvidenceAgent',
      output: <String, Object?>{
        'prediction': value.prediction,
        'predicted_failure_probability': value.predictedFailureProbability,
        'prediction_occurred': value.predictionOccurred,
        'outcome': value.outcome,
        'evidence_statement': value.statement,
        'strength': value.strength.name,
      },
      provider: 'local',
      model: 'evidence-contract-v1',
      runStatus: 'user_confirmed',
      redactedCount: 0,
    );
    await reconcileBeliefState(value.beliefId);
  }

  Future<List<BeliefMentorEvidence>> evidence({String? beliefId}) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_evidence',
      where: beliefId == null ? null : 'belief_id = ?',
      whereArgs: beliefId == null ? null : <Object?>[beliefId],
      orderBy: 'created_at_ms DESC',
    );
    final decrypted = await _decryptRows('belief_mentor_evidence', rows);
    return decrypted.map(BeliefMentorEvidence.fromRow).toList(growable: false);
  }

  Future<void> saveReminder(BeliefMentorReminder value) async {
    final db = await _db();
    await db.insert(
      'belief_mentor_reminders',
      await _encryptRow('belief_mentor_reminders', value.toRow()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BeliefMentorReminder?> reminder(String id) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_reminders',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : BeliefMentorReminder.fromRow(
            await _decryptRow('belief_mentor_reminders', rows.first),
          );
  }

  Future<BeliefMentorReminder?> reminderForDeliveryKey(String key) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_reminders',
      where: 'delivery_key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : BeliefMentorReminder.fromRow(
            await _decryptRow('belief_mentor_reminders', rows.first),
          );
  }

  Future<List<BeliefMentorReminder>> reminders({String? experimentId}) async {
    final db = await _db();
    final staleBefore = DateTime.now()
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    await db.rawUpdate(
      '''UPDATE belief_mentor_reminders
         SET state = ?, ignored_count = ignored_count + 1, updated_at_ms = ?
         WHERE scheduled_at_ms < ? AND state IN (?, ?, ?, ?, ?, ?)''',
      <Object?>[
        BeliefMentorReminderState.ignored.name,
        DateTime.now().millisecondsSinceEpoch,
        staleBefore,
        BeliefMentorReminderState.created.name,
        BeliefMentorReminderState.scheduled.name,
        BeliefMentorReminderState.sent.name,
        BeliefMentorReminderState.snoozed.name,
        BeliefMentorReminderState.rescheduled.name,
        BeliefMentorReminderState.followUp.name,
      ],
    );
    final rows = await db.query(
      'belief_mentor_reminders',
      where: experimentId == null ? null : 'experiment_id = ?',
      whereArgs: experimentId == null ? null : <Object?>[experimentId],
      orderBy: 'scheduled_at_ms ASC',
    );
    final decrypted = await _decryptRows('belief_mentor_reminders', rows);
    return decrypted.map(BeliefMentorReminder.fromRow).toList(growable: false);
  }

  Future<void> updateReminderState(
    String id,
    BeliefMentorReminderState state, {
    String suppressReason = '',
    int? scheduledAtMs,
  }) async {
    final db = await _db();
    await db.update(
      'belief_mentor_reminders',
      <String, Object?>{
        'state': state.name,
        if (suppressReason.isNotEmpty) 'suppress_reason': suppressReason,
        if (scheduledAtMs != null) 'scheduled_at_ms': scheduledAtMs,
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markReminderIgnored(String id) async {
    final db = await _db();
    await db.rawUpdate(
      '''UPDATE belief_mentor_reminders
         SET state = ?, ignored_count = ignored_count + 1, updated_at_ms = ?
         WHERE id = ?''',
      <Object?>[
        BeliefMentorReminderState.ignored.name,
        DateTime.now().millisecondsSinceEpoch,
        id,
      ],
    );
  }

  Future<int> reminderCountForDay(DateTime day, {bool critical = false}) async {
    final db = await _db();
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(
      day.year,
      day.month,
      day.day + 1,
    ).millisecondsSinceEpoch;
    final comparison = critical ? '= ?' : '<> ?';
    return Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(1) FROM belief_mentor_reminders
             WHERE state IN (?, ?, ?) AND scheduled_at_ms >= ? AND scheduled_at_ms < ?
             AND reminder_type $comparison''',
            <Object?>[
              BeliefMentorReminderState.sent.name,
              BeliefMentorReminderState.opened.name,
              BeliefMentorReminderState.actionStarted.name,
              start,
              end,
              BeliefMentorReminderType.preAction.name,
            ],
          ),
        ) ??
        0;
  }

  Future<bool> hasInterventionWithin(DateTime time, Duration window) async {
    final db = await _db();
    final rows = await db.rawQuery(
      '''SELECT COUNT(1) AS c FROM belief_mentor_reminders
         WHERE state IN (?, ?, ?) AND scheduled_at_ms BETWEEN ? AND ?''',
      <Object?>[
        BeliefMentorReminderState.sent.name,
        BeliefMentorReminderState.opened.name,
        BeliefMentorReminderState.actionStarted.name,
        time.subtract(window).millisecondsSinceEpoch,
        time.add(window).millisecondsSinceEpoch,
      ],
    );
    return (Sqflite.firstIntValue(rows) ?? 0) > 0;
  }

  Future<bool> deliveryKeyExists(String key) async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT COUNT(1) FROM belief_mentor_reminders WHERE delivery_key = ?',
      <Object?>[key],
    );
    return (Sqflite.firstIntValue(rows) ?? 0) > 0;
  }

  Future<BeliefMentorStory> storyForBelief(BeliefMentorBelief belief) async {
    final db = await _db();
    final seenRows = await db.query(
      'belief_mentor_story_views',
      columns: <String>['story_id'],
      where: 'belief_id = ?',
      whereArgs: <Object?>[belief.id],
    );
    final seen = seenRows
        .map((row) => (row['story_id'] ?? '').toString())
        .toSet();
    final selected = BeliefMentorStoryCatalog.forBelief(belief, seen: seen);
    final rows = await db.query(
      'belief_mentor_stories',
      where: 'id = ?',
      whereArgs: <Object?>[selected.id],
      limit: 1,
    );
    final result = rows.isEmpty
        ? selected
        : BeliefMentorStory.fromRow(rows.first);
    await saveAgentRun(
      agent: 'StoryAgent',
      output: <String, Object?>{
        'story_id': result.id,
        'framing': result.hook,
        'boundary': result.boundary,
        'reflection': result.reflection,
      },
      provider: 'local',
      model: 'reviewed-story-matcher-v1',
      runStatus: 'matched',
      redactedCount: 0,
    );
    return result;
  }

  Future<List<BeliefMentorStory>> stories() async {
    final db = await _db();
    final rows = await db.query('belief_mentor_stories', orderBy: 'id ASC');
    return rows.map(BeliefMentorStory.fromRow).toList(growable: false);
  }

  Future<void> recordStoryView(
    String storyId,
    String beliefId, {
    int durationSeconds = 0,
  }) async {
    final db = await _db();
    await db.insert('belief_mentor_story_views', <String, Object?>{
      'id': _id('story_view'),
      'story_id': storyId,
      'belief_id': beliefId,
      'duration_seconds': durationSeconds,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
    await track(
      'story_viewed',
      beliefId: beliefId,
      properties: <String, Object?>{
        'story_id': storyId,
        'duration': durationSeconds,
      },
    );
  }

  Future<BeliefMentorFailure> createFailure({
    required String beliefId,
    required String experimentId,
    required String facts,
    required String interpretation,
    required String emotion,
    String learning = '',
    required String nextStep,
  }) async {
    if (facts.trim().isEmpty || nextStep.trim().isEmpty) {
      throw StateError('恢复协议必须保留事实和一个最小下一步。');
    }
    final safety = BeliefMentorSafetyPolicy.assess(
      '$facts $interpretation $emotion $learning $nextStep',
    );
    if (safety.blocksNormalFlow) {
      await recordSafetyEvent(
        category: safety.category,
        action: 'blocked_recovery_write',
        source: 'user_edit',
      );
      throw StateError(safety.message);
    }
    final db = await _db();
    final existing = await db.query(
      'belief_mentor_failures',
      where: 'experiment_id = ? AND closed_at_ms = 0',
      whereArgs: <Object?>[experimentId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _failureFromRow(
        await _decryptRow('belief_mentor_failures', existing.first),
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = BeliefMentorFailure(
      id: _id('failure'),
      beliefId: beliefId,
      experimentId: experimentId,
      facts: facts.trim(),
      interpretation: interpretation.trim(),
      emotion: emotion.trim(),
      learning: learning.trim(),
      nextStep: nextStep.trim(),
      stage: 'T+0',
      createdAtMs: now,
      updatedAtMs: now,
    );
    await db.insert(
      'belief_mentor_failures',
      await _encryptRow('belief_mentor_failures', value.toRow()),
    );
    await track(
      'failure_logged',
      beliefId: beliefId,
      experimentId: experimentId,
    );
    await saveAgentRun(
      agent: 'RecoveryAgent',
      output: <String, Object?>{
        'recovery_stage': value.stage,
        'next_step': value.nextStep,
        'reminder_plan': <String>['T+6', 'T+24', 'T+72'],
      },
      provider: 'local',
      model: 'recovery-contract-v1',
      runStatus: 'user_confirmed',
      redactedCount: 0,
    );
    return value;
  }

  Future<void> updateFailureReflection({
    required String id,
    required String facts,
    required String interpretation,
    required String emotion,
    required String learning,
    required String nextStep,
  }) async {
    final safety = BeliefMentorSafetyPolicy.assess(
      '$facts $interpretation $emotion $learning $nextStep',
    );
    if (safety.blocksNormalFlow) {
      await recordSafetyEvent(
        category: safety.category,
        action: 'blocked_recovery_update',
        source: 'user_edit',
      );
      throw StateError(safety.message);
    }
    final db = await _db();
    final values = await _encryptRow(
      'belief_mentor_failures',
      <String, Object?>{
        'facts': facts.trim(),
        'interpretation_text': interpretation.trim(),
        'emotion_text': emotion.trim(),
        'learning_text': learning.trim(),
        'next_step': nextStep.trim(),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
    );
    await db.update(
      'belief_mentor_failures',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    await track(
      'recovery_reflection_updated',
      properties: <String, Object?>{'failure_id': id},
    );
  }

  Future<List<BeliefMentorFailure>> failures({bool openOnly = false}) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_failures',
      where: openOnly ? 'closed_at_ms = 0' : null,
      orderBy: 'created_at_ms DESC',
    );
    final decrypted = await _decryptRows('belief_mentor_failures', rows);
    return decrypted.map(_failureFromRow).toList(growable: false);
  }

  Future<void> closeFailure(String id) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'belief_mentor_failures',
      <String, Object?>{
        'stage': 'CLOSED',
        'closed_at_ms': now,
        'updated_at_ms': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    await track(
      'recovery_action_started',
      properties: <String, Object?>{'failure_id': id},
    );
  }

  BeliefMentorFailure _failureFromRow(Map<String, Object?> row) {
    final createdAtMs = _rowInt(row['created_at_ms']);
    final closedAtMs = _rowInt(row['closed_at_ms']);
    var stage = (row['stage'] ?? 'T+0').toString();
    if (closedAtMs == 0 && createdAtMs > 0) {
      final hours = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(createdAtMs))
          .inHours;
      stage = hours >= 72
          ? 'T+72'
          : hours >= 24
          ? 'T+24'
          : hours >= 6
          ? 'T+6'
          : 'T+0';
    }
    return BeliefMentorFailure(
      id: (row['id'] ?? '').toString(),
      beliefId: (row['belief_id'] ?? '').toString(),
      experimentId: (row['experiment_id'] ?? '').toString(),
      facts: (row['facts'] ?? '').toString(),
      interpretation: (row['interpretation_text'] ?? '').toString(),
      emotion: (row['emotion_text'] ?? '').toString(),
      learning: (row['learning_text'] ?? '').toString(),
      nextStep: (row['next_step'] ?? '').toString(),
      stage: stage,
      createdAtMs: createdAtMs,
      updatedAtMs: _rowInt(row['updated_at_ms']),
      closedAtMs: closedAtMs,
    );
  }

  Future<BeliefMentorTodaySnapshot> today() async {
    final allBeliefs = await beliefs();
    final active = allBeliefs.where((item) => item.userConfirmed).toList();
    if (active.isEmpty) return const BeliefMentorTodaySnapshot();
    final currentProfile = await profile();
    final selected = active.where(
      (item) => item.id == currentProfile.activeBeliefId,
    );
    final mainBelief = selected.isEmpty ? active.first : selected.first;
    final allExperiments = await experiments(beliefId: mainBelief.id);
    BeliefMentorExperiment? currentExperiment;
    for (final item in allExperiments) {
      if (item.state != BeliefMentorExperimentState.evidenceCreated &&
          item.state != BeliefMentorExperimentState.abandoned) {
        currentExperiment = item;
        break;
      }
    }
    final allReminders = currentExperiment == null
        ? const <BeliefMentorReminder>[]
        : await reminders(experimentId: currentExperiment.id);
    BeliefMentorReminder? nextReminder;
    for (final item in allReminders) {
      if (item.state == BeliefMentorReminderState.scheduled ||
          item.state == BeliefMentorReminderState.snoozed ||
          item.state == BeliefMentorReminderState.rescheduled) {
        nextReminder = item;
        break;
      }
    }
    final items = await evidence(beliefId: mainBelief.id);
    final story = await storyForBelief(mainBelief);
    final openFailures = (await failures(openOnly: true))
        .where((item) => item.beliefId == mainBelief.id)
        .toList(growable: false);
    return BeliefMentorTodaySnapshot(
      belief: mainBelief,
      experiment: currentExperiment,
      nextReminder: nextReminder,
      latestEvidence: items.isEmpty ? null : items.first,
      story: story,
      openFailure: openFailures.isEmpty ? null : openFailures.first,
    );
  }

  Future<void> reconcileBeliefState(String beliefId) async {
    final current = await belief(beliefId);
    if (current == null) return;
    final db = await _db();
    final completed =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(1) FROM belief_mentor_experiments WHERE belief_id = ? AND state IN (?, ?)',
            <Object?>[
              beliefId,
              BeliefMentorExperimentState.completed.name,
              BeliefMentorExperimentState.evidenceCreated.name,
            ],
          ),
        ) ??
        0;
    final evidenceRows = await db.query(
      'belief_mentor_evidence',
      where: 'belief_id = ?',
      whereArgs: <Object?>[beliefId],
    );
    final decryptedEvidenceRows = await _decryptRows(
      'belief_mentor_evidence',
      evidenceRows,
    );
    final distinctDays = decryptedEvidenceRows
        .map((row) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            _rowInt(row['created_at_ms']),
          );
          return '${date.year}-${date.month}-${date.day}';
        })
        .toSet()
        .length;
    final effectiveEvidenceCount = BeliefMentorEvidencePolicy.effectiveCount(
      decryptedEvidenceRows.map(BeliefMentorEvidence.fromRow).toList(),
    );
    final next = BeliefMentorTransitionPolicy.suggestedState(
      belief: current,
      completedExperiments: completed,
      evidenceCount: effectiveEvidenceCount,
      distinctEvidenceDays: distinctDays,
      now: DateTime.now(),
    );
    if (next != current.state &&
        BeliefMentorTransitionPolicy.canTransition(current.state, next)) {
      await _updateBeliefState(beliefId, next);
    }
  }

  Future<BeliefMentorWeeklyReport> weeklyReport({DateTime? now}) async {
    final db = await _db();
    final end = now ?? DateTime.now();
    final start = end.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    Future<int> count(String event) async =>
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(1) FROM belief_mentor_events WHERE event_name = ? AND created_at_ms >= ?',
            <Object?>[event, start],
          ),
        ) ??
        0;

    final created = await count('experiment_created');
    final started = await count('experiment_started');
    final completed = await count('experiment_completed');
    final evidenceCreated = await count('evidence_created');
    final failuresLogged = await count('failure_logged');
    final recovery = await count('recovery_action_started');
    final remindersSent = await count('reminder_sent');
    final autonomous =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(1) FROM belief_mentor_events
             WHERE event_name = 'experiment_started' AND created_at_ms >= ?
             AND json_extract(properties_json, '\$.source') = 'self' ''',
            <Object?>[start],
          ),
        ) ??
        0;

    final scoreRows = await db.query(
      'belief_mentor_belief_scores',
      where: 'created_at_ms >= ?',
      whereArgs: <Object?>[start],
      orderBy: 'belief_id ASC, created_at_ms ASC',
    );
    final scoresByBelief = <String, List<int>>{};
    for (final row in scoreRows) {
      scoresByBelief
          .putIfAbsent((row['belief_id'] ?? '').toString(), () => <int>[])
          .add(_rowInt(row['score']));
    }
    final scoreChanges = scoresByBelief.values
        .where((scores) => scores.length >= 2)
        .map((scores) => (scores.first - scores.last).toDouble())
        .toList(growable: false);
    final beliefScoreChange = scoreChanges.isEmpty
        ? 0.0
        : scoreChanges.reduce((a, b) => a + b) / scoreChanges.length;

    final recoveryRows = await db.rawQuery(
      '''SELECT created_at_ms, closed_at_ms FROM belief_mentor_failures
         WHERE closed_at_ms > 0 AND closed_at_ms >= ?''',
      <Object?>[start],
    );
    final recoveryDurations =
        recoveryRows
            .map(
              (row) =>
                  (_rowInt(row['closed_at_ms']) -
                      _rowInt(row['created_at_ms'])) /
                  Duration.millisecondsPerHour,
            )
            .where((hours) => hours >= 0)
            .toList(growable: false)
          ..sort();
    final recoveryHalfLifeHours = _median(recoveryDurations);

    final calibrationRows = await db.query(
      'belief_mentor_evidence',
      columns: <String>['predicted_failure_probability', 'prediction_occurred'],
      where: 'created_at_ms >= ?',
      whereArgs: <Object?>[start],
    );
    final calibrationErrors = calibrationRows
        .map((row) {
          final probability =
              _rowInt(row['predicted_failure_probability']) / 100;
          final outcome = _rowInt(row['prediction_occurred']) == 1 ? 1.0 : 0.0;
          return (probability - outcome).abs();
        })
        .toList(growable: false);
    final predictionCalibrationError = calibrationErrors.isEmpty
        ? 0.0
        : calibrationErrors.reduce((a, b) => a + b) / calibrationErrors.length;

    final reminderRows = await db.query(
      'belief_mentor_reminders',
      columns: <String>['state'],
      where: 'scheduled_at_ms >= ?',
      whereArgs: <Object?>[start],
    );
    final ignoredReminders = reminderRows
        .where(
          (row) =>
              (row['state'] ?? '').toString() ==
              BeliefMentorReminderState.ignored.name,
        )
        .length;
    final reminderFatigueRate = reminderRows.isEmpty
        ? 0.0
        : ignoredReminders / reminderRows.length;

    final terminalExperiments =
        completed +
        (Sqflite.firstIntValue(
              await db.rawQuery(
                '''SELECT COUNT(1) FROM belief_mentor_experiments
                   WHERE state = ? AND updated_at_ms >= ?''',
                <Object?>[BeliefMentorExperimentState.abandoned.name, start],
              ),
            ) ??
            0);
    return BeliefMentorWeeklyReport(
      experimentsCreated: created,
      experimentsStarted: started,
      experimentsCompleted: completed,
      evidenceCreated: evidenceCreated,
      failuresLogged: failuresLogged,
      recoveryActions: recovery,
      remindersSent: remindersSent,
      autonomousStarts: autonomous,
      averageReminderCount: started == 0 ? 0 : remindersSent / started,
      beliefScoreChange: beliefScoreChange,
      recoveryHalfLifeHours: recoveryHalfLifeHours,
      predictionCalibrationError: predictionCalibrationError,
      reminderFatigueRate: reminderFatigueRate,
      promiseReliability: terminalExperiments == 0
          ? 0
          : completed / terminalExperiments,
    );
  }

  Future<void> saveAgentRun({
    required String agent,
    required Map<String, Object?> output,
    required String provider,
    required String model,
    required String runStatus,
    required int redactedCount,
    String failureMessage = '',
  }) async {
    final db = await _db();
    await db.insert(
      'belief_mentor_agent_runs',
      await _encryptRow('belief_mentor_agent_runs', <String, Object?>{
        'id': _id('agent_run'),
        'agent': agent,
        'input_hash': '',
        'output_json': jsonEncode(output),
        'provider': provider,
        'model': model,
        'run_status': runStatus,
        'redacted_count': redactedCount,
        'failure_message': failureMessage,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> recordSafetyEvent({
    required String category,
    required String action,
    required String source,
  }) async {
    final db = await _db();
    await db.insert('belief_mentor_safety_events', <String, Object?>{
      'id': _id('safety'),
      'risk_category': category,
      'policy_action': action,
      'source': source,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> track(
    String eventName, {
    String beliefId = '',
    String experimentId = '',
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    final db = await _db();
    await db.insert('belief_mentor_events', <String, Object?>{
      'id': _id('event'),
      'event_name': eventName,
      'belief_id': beliefId,
      'experiment_id': experimentId,
      'properties_json': jsonEncode(properties),
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<String> exportData() async {
    final db = await _db();
    final payload = <String, Object?>{
      'schema': 'belief-mentor-export-v1',
      'exported_at': DateTime.now().toIso8601String(),
    };
    for (final table in _userDataTables) {
      final rows = await db.query(table);
      payload[table] = await _decryptRows(table, rows);
    }
    payload['belief_mentor_privacy_audit'] = await db.query(
      'belief_mentor_privacy_audit',
      orderBy: 'created_at_ms ASC',
    );
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<List<int>> deleteAllUserData() async {
    final db = await _db();
    final alarmRows = await db.query(
      'belief_mentor_reminders',
      columns: <String>['alarm_id'],
    );
    final alarmIds = alarmRows
        .map((row) => _rowInt(row['alarm_id']))
        .where((id) => id > 0)
        .toList();
    await db.transaction((txn) async {
      for (final table in _userDataTables.reversed) {
        await txn.delete(table);
      }
      await txn.insert('belief_mentor_privacy_audit', <String, Object?>{
        'id': _id('privacy_audit'),
        'event_name': 'user_data_deleted',
        'details_json': jsonEncode(<String, Object?>{
          'scope': 'belief_mentor_all_user_data',
          'alarm_count': alarmIds.length,
        }),
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
    });
    return alarmIds;
  }

  static const List<String> _userDataTables = <String>[
    'belief_mentor_profile',
    'belief_mentor_beliefs',
    'belief_mentor_belief_scores',
    'belief_mentor_experiments',
    'belief_mentor_evidence',
    'belief_mentor_reminders',
    'belief_mentor_story_views',
    'belief_mentor_failures',
    'belief_mentor_agent_runs',
    'belief_mentor_events',
    'belief_mentor_safety_events',
  ];

  static String newId(String prefix) => _id(prefix);

  static String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  static int _counter = 0;
}

int _rowInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final middle = values.length ~/ 2;
  if (values.length.isOdd) return values[middle];
  return (values[middle - 1] + values[middle]) / 2;
}
