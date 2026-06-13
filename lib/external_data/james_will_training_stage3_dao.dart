import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'james_will_training_models.dart';
import 'james_will_training_stage3_models.dart';

class JamesWillTrainingStage3Dao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_experiments (
        experiment_id TEXT PRIMARY KEY,
        idea_id TEXT NOT NULL,
        title TEXT,
        core_value TEXT,
        trigger_text TEXT,
        place_text TEXT,
        first_body_action TEXT,
        minimum_version TEXT,
        standard_version TEXT,
        fallback_version TEXT,
        daily_plan_json TEXT,
        recovery_plan TEXT,
        current_day INTEGER DEFAULT 1,
        status TEXT DEFAULT 'active',
        sealed_until_ms INTEGER NOT NULL,
        ai_summary TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_cooldowns (
        cooldown_id TEXT PRIMARY KEY,
        idea_id TEXT NOT NULL,
        trigger_text TEXT,
        decision_text TEXT,
        risk_level TEXT,
        reason TEXT,
        cool_until_ms INTEGER NOT NULL,
        check_questions_json TEXT,
        fallback_action TEXT,
        status TEXT DEFAULT 'cooling',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_value_maps (
        snapshot_id TEXT PRIMARY KEY,
        summary TEXT,
        value_nodes_json TEXT,
        action_nodes_json TEXT,
        links_json TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_experiments_idea ON james_will_experiments(idea_id, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_experiments_status ON james_will_experiments(status, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_cooldowns_idea ON james_will_cooldowns(idea_id, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_cooldowns_status ON james_will_cooldowns(status, cool_until_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_value_maps_created ON james_will_value_maps(created_at_ms)');
  }

  Future<void> saveExperiment(JamesWillSevenDayExperiment experiment) async {
    final db = await _db;
    await db.insert('james_will_experiments', experiment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JamesWillSevenDayExperiment?> activeExperimentForIdea(String ideaId) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_experiments',
      where: "idea_id=? AND status='active'",
      whereArgs: <Object?>[ideaId],
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JamesWillSevenDayExperiment.fromMap(rows.first);
  }

  Future<List<JamesWillSevenDayExperiment>> listExperiments({String? ideaId, int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_experiments',
      where: ideaId == null ? null : 'idea_id=?',
      whereArgs: ideaId == null ? null : <Object?>[ideaId],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillSevenDayExperiment.fromMap).toList(growable: false);
  }

  Future<void> saveCooldown(JamesWillCooldownPlan plan) async {
    final db = await _db;
    await db.insert('james_will_cooldowns', plan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<JamesWillCooldownPlan>> listCooldowns({String? ideaId, int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_cooldowns',
      where: ideaId == null ? null : 'idea_id=?',
      whereArgs: ideaId == null ? null : <Object?>[ideaId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillCooldownPlan.fromMap).toList(growable: false);
  }

  Future<void> saveValueMap(JamesWillValueMapSnapshot snapshot) async {
    final db = await _db;
    await db.insert('james_will_value_maps', snapshot.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JamesWillValueMapSnapshot?> latestValueMap() async {
    final db = await _db;
    final rows = await db.query('james_will_value_maps', orderBy: 'created_at_ms DESC', limit: 1);
    if (rows.isEmpty) return null;
    return JamesWillValueMapSnapshot.fromMap(rows.first);
  }

  Future<Map<String, int>> stage3Stats() async {
    final db = await _db;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return willIntValue(rows.first['c']);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final activeCooldownRows = await db.rawQuery("SELECT COUNT(*) AS c FROM james_will_cooldowns WHERE status='cooling' AND cool_until_ms>?", <Object?>[now]);
    return <String, int>{
      'experiments': await count('james_will_experiments'),
      'cooldowns': await count('james_will_cooldowns'),
      'valueMaps': await count('james_will_value_maps'),
      'activeCooldowns': willIntValue(activeCooldownRows.first['c']),
    };
  }
}
