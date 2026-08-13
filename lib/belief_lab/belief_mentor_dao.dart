import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_policies.dart';
import 'belief_mentor_story_catalog.dart';

class BeliefMentorDao {
  BeliefMentorDao({Database? database}) : _database = database;

  final Database? _database;
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
    for (final statement in _schemaStatements) {
      await db.execute(statement);
    }
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
        testing_started_at_ms INTEGER NOT NULL DEFAULT 0
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
        completed_at_ms INTEGER NOT NULL DEFAULT 0
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS belief_mentor_evidence (
        id TEXT PRIMARY KEY,
        belief_id TEXT NOT NULL,
        experiment_id TEXT NOT NULL DEFAULT '',
        prediction_text TEXT NOT NULL DEFAULT '',
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
  ];

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
    if (rows.isNotEmpty) return BeliefMentorProfile.fromRow(rows.first);
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
      value
          .copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch)
          .toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveBelief(
    BeliefMentorBelief belief, {
    String scoreSource = 'user',
  }) async {
    final db = await _db();
    await db.transaction((txn) async {
      await txn.insert(
        'belief_mentor_beliefs',
        belief.toRow(),
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
      belief.userConfirmed ? 'belief_created' : 'belief_candidate_created',
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
    return rows.map(BeliefMentorBelief.fromRow).toList(growable: false);
  }

  Future<BeliefMentorBelief?> belief(String id) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_beliefs',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : BeliefMentorBelief.fromRow(rows.first);
  }

  Future<void> confirmBelief({
    required String id,
    required String statement,
    required BeliefMentorBeliefType type,
    required int strength,
    required String trigger,
    required String alternative,
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
      ),
      scoreSource: 'confirmation',
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
    await db.insert('belief_mentor_experiments', value.toRow());
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

  Future<List<BeliefMentorExperiment>> experiments({String? beliefId}) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_experiments',
      where: beliefId == null ? null : 'belief_id = ?',
      whereArgs: beliefId == null ? null : <Object?>[beliefId],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(BeliefMentorExperiment.fromRow).toList(growable: false);
  }

  Future<BeliefMentorExperiment?> experiment(String id) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_experiments',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : BeliefMentorExperiment.fromRow(rows.first);
  }

  Future<void> startExperiment(String id, {String source = 'self'}) async {
    final db = await _db();
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = await experiment(id);
    if (value == null ||
        (value.state != BeliefMentorExperimentState.scheduled &&
            value.state != BeliefMentorExperimentState.draft)) {
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
      where: 'experiment_id = ? AND reminder_type IN (?, ?) AND state IN (?, ?, ?)',
      whereArgs: <Object?>[
        id,
        BeliefMentorReminderType.preAction.name,
        BeliefMentorReminderType.antiAvoidance.name,
        BeliefMentorReminderState.scheduled.name,
        BeliefMentorReminderState.sent.name,
        BeliefMentorReminderState.opened.name,
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
        value.state == BeliefMentorExperimentState.evidenceCreated)
      return;
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

  Future<void> abandonExperiment(String id) async {
    final value = await experiment(id);
    if (value == null) return;
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
    final db = await _db();
    await db.transaction((txn) async {
      await txn.insert(
        'belief_mentor_evidence',
        value.toRow(),
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
    return rows.map(BeliefMentorEvidence.fromRow).toList(growable: false);
  }

  Future<void> saveReminder(BeliefMentorReminder value) async {
    final db = await _db();
    await db.insert(
      'belief_mentor_reminders',
      value.toRow(),
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
    return rows.isEmpty ? null : BeliefMentorReminder.fromRow(rows.first);
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
    return rows.map(BeliefMentorReminder.fromRow).toList(growable: false);
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
      'SELECT COUNT(1) FROM belief_mentor_reminders WHERE delivery_key = ? AND state IN (?, ?, ?, ?)',
      <Object?>[
        key,
        BeliefMentorReminderState.sent.name,
        BeliefMentorReminderState.opened.name,
        BeliefMentorReminderState.actionStarted.name,
        BeliefMentorReminderState.evidenceCreated.name,
      ],
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
    final selected = BeliefMentorStoryCatalog.forType(belief.type, seen: seen);
    final rows = await db.query(
      'belief_mentor_stories',
      where: 'id = ?',
      whereArgs: <Object?>[selected.id],
      limit: 1,
    );
    return rows.isEmpty ? selected : BeliefMentorStory.fromRow(rows.first);
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
    required String nextStep,
  }) async {
    final db = await _db();
    final existing = await db.query(
      'belief_mentor_failures',
      where: 'experiment_id = ? AND closed_at_ms = 0',
      whereArgs: <Object?>[experimentId],
      limit: 1,
    );
    if (existing.isNotEmpty) return _failureFromRow(existing.first);
    final now = DateTime.now().millisecondsSinceEpoch;
    final value = BeliefMentorFailure(
      id: _id('failure'),
      beliefId: beliefId,
      experimentId: experimentId,
      facts: facts.trim(),
      interpretation: interpretation.trim(),
      emotion: emotion.trim(),
      nextStep: nextStep.trim(),
      stage: 'T+0',
      createdAtMs: now,
      updatedAtMs: now,
    );
    await db.insert('belief_mentor_failures', value.toRow());
    await track(
      'failure_logged',
      beliefId: beliefId,
      experimentId: experimentId,
    );
    return value;
  }

  Future<List<BeliefMentorFailure>> failures({bool openOnly = false}) async {
    final db = await _db();
    final rows = await db.query(
      'belief_mentor_failures',
      where: openOnly ? 'closed_at_ms = 0' : null,
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(_failureFromRow).toList(growable: false);
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
    final mainBelief = active.first;
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
      columns: <String>['created_at_ms'],
      where: 'belief_id = ?',
      whereArgs: <Object?>[beliefId],
    );
    final distinctDays = evidenceRows
        .map((row) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            _rowInt(row['created_at_ms']),
          );
          return '${date.year}-${date.month}-${date.day}';
        })
        .toSet()
        .length;
    final next = BeliefMentorTransitionPolicy.suggestedState(
      belief: current,
      completedExperiments: completed,
      evidenceCount: evidenceRows.length,
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
    await db.insert('belief_mentor_agent_runs', <String, Object?>{
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
      payload[table] = await db.query(table);
    }
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
