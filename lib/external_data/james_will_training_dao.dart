import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'james_will_training_models.dart';

class JamesWillTrainingDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_action_ideas (
        idea_id TEXT PRIMARY KEY,
        original_goal TEXT NOT NULL,
        goal_note TEXT,
        core_value TEXT,
        action_idea TEXT,
        first_body_action TEXT,
        minimum_action TEXT,
        five_minute_version TEXT,
        attention_anchor TEXT,
        obstacle_ideas_json TEXT,
        replacement_ideas_json TEXT,
        competition_json TEXT,
        coach_message TEXT,
        ai_provider TEXT,
        ai_model_label TEXT,
        ai_used_fallback INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_decisions (
        decision_id TEXT PRIMARY KEY,
        idea_id TEXT NOT NULL,
        question TEXT NOT NULL,
        positive_idea TEXT,
        negative_idea TEXT,
        hesitation_type TEXT,
        decision_type TEXT,
        strategy TEXT,
        today_first_action TEXT,
        attention_anchor TEXT,
        coach_message TEXT,
        sealed_until_ms INTEGER DEFAULT 0,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_logs (
        log_id TEXT PRIMARY KEY,
        idea_id TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        before_obstacle TEXT,
        dominant_action_idea TEXT,
        attention_recovery_count INTEGER DEFAULT 0,
        start_delay_minutes INTEGER DEFAULT 0,
        effort_attention_score INTEGER DEFAULT 0,
        reflection TEXT,
        ai_summary TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_action_status ON james_will_action_ideas(status, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_decision_idea ON james_will_decisions(idea_id, created_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_log_idea ON james_will_logs(idea_id, created_at_ms)');
  }

  Future<void> upsertActionIdea(JamesWillActionIdea idea) async {
    final db = await _db;
    await db.insert('james_will_action_ideas', idea.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<JamesWillActionIdea>> listActionIdeas({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_action_ideas',
      where: "status <> 'deleted'",
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillActionIdea.fromMap).toList(growable: false);
  }

  Future<JamesWillActionIdea?> getActionIdea(String id) async {
    final db = await _db;
    final rows = await db.query('james_will_action_ideas', where: 'idea_id=?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return JamesWillActionIdea.fromMap(rows.first);
  }

  Future<void> archiveActionIdea(String id) async {
    final db = await _db;
    await db.update(
      'james_will_action_ideas',
      <String, Object?>{'status': 'archived', 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'idea_id=?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> saveDecision(JamesWillDecision decision) async {
    final db = await _db;
    await db.insert('james_will_decisions', decision.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<JamesWillDecision>> listDecisions(String ideaId, {int limit = 20}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_decisions',
      where: 'idea_id=?',
      whereArgs: <Object?>[ideaId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillDecision.fromMap).toList(growable: false);
  }

  Future<void> saveLog(JamesWillLog log) async {
    final db = await _db;
    await db.insert('james_will_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.update(
      'james_will_action_ideas',
      <String, Object?>{'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'idea_id=?',
      whereArgs: <Object?>[log.ideaId],
    );
  }

  Future<List<JamesWillLog>> listLogs({String? ideaId, int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_logs',
      where: ideaId == null ? null : 'idea_id=?',
      whereArgs: ideaId == null ? null : <Object?>[ideaId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillLog.fromMap).toList(growable: false);
  }

  Future<Map<String, int>> stats() async {
    final db = await _db;
    Future<int> count(String table) async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return willIntValue(rows.first['c']);
    }

    final completedRows = await db.rawQuery('SELECT COUNT(*) AS c FROM james_will_logs WHERE completed=1');
    return <String, int>{
      'ideas': await count('james_will_action_ideas'),
      'decisions': await count('james_will_decisions'),
      'logs': await count('james_will_logs'),
      'completed': willIntValue(completedRows.first['c']),
    };
  }
}
