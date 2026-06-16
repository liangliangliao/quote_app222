import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'shame_transform_models.dart';

class ShameTransformDao {
  Future<Database> _database() async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    return db;
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shame_events (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        intensity INTEGER NOT NULL DEFAULT 0,
        scene TEXT NOT NULL DEFAULT 'eventRecord',
        event_fact TEXT NOT NULL DEFAULT '',
        emotion TEXT NOT NULL DEFAULT '',
        body_reaction TEXT NOT NULL DEFAULT '',
        toxic_language TEXT NOT NULL DEFAULT '',
        source_voice TEXT NOT NULL DEFAULT '',
        healthy_rewrite TEXT NOT NULL DEFAULT '',
        user_responsibility TEXT NOT NULL DEFAULT '',
        not_user_responsibility TEXT NOT NULL DEFAULT '',
        minimum_action TEXT NOT NULL DEFAULT '',
        fallback_action TEXT NOT NULL DEFAULT '',
        evidence_sentence TEXT NOT NULL DEFAULT '',
        linked_goal_id TEXT NOT NULL DEFAULT '',
        action_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _ensureColumns(db, 'shame_events', {
      'scene': "TEXT NOT NULL DEFAULT 'eventRecord'",
      'source_voice': "TEXT NOT NULL DEFAULT ''",
      'user_responsibility': "TEXT NOT NULL DEFAULT ''",
      'not_user_responsibility': "TEXT NOT NULL DEFAULT ''",
      'fallback_action': "TEXT NOT NULL DEFAULT ''",
      'action_completed': 'INTEGER NOT NULL DEFAULT 0',
      'positive_affect': "TEXT NOT NULL DEFAULT ''",
      'original_desire': "TEXT NOT NULL DEFAULT ''",
      'blocking_point': "TEXT NOT NULL DEFAULT ''",
      'shame_trigger': "TEXT NOT NULL DEFAULT ''",
      'self_contraction': "TEXT NOT NULL DEFAULT ''",
      'compass_primary': "TEXT NOT NULL DEFAULT ''",
      'compass_secondary': "TEXT NOT NULL DEFAULT ''",
      'compass_short_function': "TEXT NOT NULL DEFAULT ''",
      'compass_long_cost': "TEXT NOT NULL DEFAULT ''",
      'true_pride_potential': "TEXT NOT NULL DEFAULT ''",
      'ability_reflected': "TEXT NOT NULL DEFAULT ''",
      'seen_risk_level': "TEXT NOT NULL DEFAULT ''",
    });
    await _copyLegacyResponsibilityColumns(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shame_inner_voices (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        voice_text TEXT NOT NULL,
        source_guess TEXT NOT NULL,
        protection_intent TEXT NOT NULL,
        toxic_method TEXT NOT NULL,
        healthy_rewrite TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shame_goal_profiles (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        goal_text TEXT NOT NULL,
        shame_triggers TEXT NOT NULL,
        non_shame_goal TEXT NOT NULL,
        problem_tree_json TEXT NOT NULL,
        action_tree_json TEXT NOT NULL,
        daily_action TEXT NOT NULL,
        evidence_sentence TEXT NOT NULL
      )
    ''');
    await _ensureColumns(db, 'shame_goal_profiles', {
      'goal_positive_affect': "TEXT NOT NULL DEFAULT ''",
      'goal_shame_risks_json': "TEXT NOT NULL DEFAULT '[]'",
      'compass_risks_json': "TEXT NOT NULL DEFAULT '[]'",
      'exposure_ladder_json': "TEXT NOT NULL DEFAULT '[]'",
      'true_pride_standard': "TEXT NOT NULL DEFAULT ''",
    });

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shame_evidence (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        action TEXT NOT NULL,
        identity_evidence TEXT NOT NULL,
        value_anchor TEXT NOT NULL,
        source_event_id TEXT NOT NULL,
        shame_risk_carried TEXT NOT NULL DEFAULT '',
        compass_turn TEXT NOT NULL DEFAULT '',
        positive_affect_restored TEXT NOT NULL DEFAULT '',
        ability_reflected TEXT NOT NULL DEFAULT '',
        true_pride_sentence TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _ensureColumns(db, 'shame_evidence', {
      'shame_risk_carried': "TEXT NOT NULL DEFAULT ''",
      'compass_turn': "TEXT NOT NULL DEFAULT ''",
      'positive_affect_restored': "TEXT NOT NULL DEFAULT ''",
      'ability_reflected': "TEXT NOT NULL DEFAULT ''",
      'true_pride_sentence': "TEXT NOT NULL DEFAULT ''",
    });
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shame_scripts (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        old_script TEXT NOT NULL,
        trigger_scene TEXT NOT NULL,
        protection_function TEXT NOT NULL,
        long_term_cost TEXT NOT NULL,
        new_script TEXT NOT NULL,
        experiment_action TEXT NOT NULL,
        review_evidence TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS affect_recovery_logs (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        affect_type TEXT NOT NULL,
        blocked_by_shame TEXT NOT NULL,
        recovery_action TEXT NOT NULL,
        micro_joy TEXT NOT NULL,
        shared_or_not INTEGER NOT NULL DEFAULT 0,
        true_pride_after_action TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureColumns(
    Database db,
    String table,
    Map<String, String> definitions,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final names = info.map((item) => '${item['name']}').toSet();
    for (final entry in definitions.entries) {
      if (!names.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  Future<void> _copyLegacyResponsibilityColumns(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(shame_events)');
    final names = info.map((item) => '${item['name']}').toSet();
    if (names.contains('responsibility')) {
      await db.execute('''
        UPDATE shame_events
        SET user_responsibility = responsibility
        WHERE user_responsibility = '' AND responsibility != ''
      ''');
    }
    if (names.contains('not_responsibility')) {
      await db.execute('''
        UPDATE shame_events
        SET not_user_responsibility = not_responsibility
        WHERE not_user_responsibility = '' AND not_responsibility != ''
      ''');
    }
  }

  Future<List<ShameEvent>> listEvents({int? limit}) async {
    final db = await _database();
    final rows = await db.query(
      'shame_events',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ShameEvent.fromMap).toList();
  }

  Future<void> saveEvent(ShameEvent event) async {
    final db = await _database();
    final values = event.toMap();
    final info = await db.rawQuery('PRAGMA table_info(shame_events)');
    final names = info.map((item) => '${item['name']}').toSet();
    if (names.contains('responsibility')) {
      values['responsibility'] = event.userResponsibility;
    }
    if (names.contains('not_responsibility')) {
      values['not_responsibility'] = event.notUserResponsibility;
    }
    await db.insert(
      'shame_events',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setActionCompleted(String eventId, bool completed) async {
    final db = await _database();
    await db.update(
      'shame_events',
      {'action_completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  Future<void> deleteEvent(String id) async {
    final db = await _database();
    await db.delete('shame_events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InnerVoice>> listInnerVoices() async {
    final db = await _database();
    final rows = await db.query(
      'shame_inner_voices',
      orderBy: 'created_at DESC',
    );
    return rows.map(InnerVoice.fromMap).toList();
  }

  Future<void> saveInnerVoice(InnerVoice voice) async {
    final db = await _database();
    await db.insert(
      'shame_inner_voices',
      voice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GoalShameProfile>> listGoalProfiles() async {
    final db = await _database();
    final rows = await db.query(
      'shame_goal_profiles',
      orderBy: 'created_at DESC',
    );
    return rows.map(GoalShameProfile.fromMap).toList();
  }

  Future<void> saveGoalProfile(GoalShameProfile profile) async {
    final db = await _database();
    await db.insert(
      'shame_goal_profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<EvidenceItem>> listEvidence() async {
    final db = await _database();
    final rows = await db.query(
      'shame_evidence',
      orderBy: 'created_at DESC',
    );
    return rows.map(EvidenceItem.fromMap).toList();
  }

  Future<void> saveEvidence(EvidenceItem evidence) async {
    final db = await _database();
    await db.insert(
      'shame_evidence',
      evidence.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ShameScript>> listShameScripts() async {
    final db = await _database();
    final rows = await db.query('shame_scripts', orderBy: 'created_at DESC');
    return rows.map(ShameScript.fromMap).toList();
  }

  Future<void> saveShameScript(ShameScript script) async {
    final db = await _database();
    await db.insert(
      'shame_scripts',
      script.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAffectRecoveryLog(AffectRecoveryLog log) async {
    final db = await _database();
    await db.insert(
      'affect_recovery_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>> compassMetrics({int days = 7}) async {
    final db = await _database();
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT compass_primary AS direction, COUNT(*) AS total
      FROM shame_events
      WHERE created_at >= ? AND compass_primary != ''
      GROUP BY compass_primary
      ''',
      [since],
    );
    final result = <String, int>{
      '退缩': 0,
      '攻击自己': 0,
      '回避': 0,
      '攻击他人': 0,
      '混合型': 0,
      '暂无法判断': 0,
    };
    for (final row in rows) {
      final key = '${row['direction']}';
      result[key] = (row['total'] as num?)?.toInt() ?? 0;
    }
    return result;
  }

  Future<Map<String, int>> weeklyMetrics() async {
    final db = await _database();
    final since = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    Future<int> count(String table, [String extra = '']) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM $table WHERE created_at >= ? $extra',
        [since],
      );
      return (rows.first['total'] as num?)?.toInt() ?? 0;
    }

    return {
      'events': await count('shame_events'),
      'actions': await count(
        'shame_events',
        'AND action_completed = 1',
      ),
      'evidence': await count('shame_evidence'),
      'goals': await count('shame_goal_profiles'),
      'scripts': await count('shame_scripts'),
    };
  }
}
