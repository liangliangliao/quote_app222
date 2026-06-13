import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'james_will_training_practice_models.dart';

class JamesWillTrainingPracticeDao {
  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS james_will_practice_sessions (
        practice_id TEXT PRIMARY KEY,
        idea_id TEXT NOT NULL,
        user_need TEXT,
        user_context TEXT,
        need_understanding TEXT,
        guiding_questions_json TEXT,
        options_json TEXT,
        practice_stages_json TEXT,
        choice_prompt TEXT,
        selected_option_title TEXT,
        user_commitment TEXT,
        practice_feedback TEXT,
        current_stage INTEGER DEFAULT 1,
        status TEXT DEFAULT 'draft',
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_practice_idea ON james_will_practice_sessions(idea_id, updated_at_ms)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_james_will_practice_status ON james_will_practice_sessions(status, updated_at_ms)');
  }

  Future<void> saveSession(JamesWillPracticeSession session) async {
    final db = await _db;
    await db.insert('james_will_practice_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JamesWillPracticeSession?> latestForIdea(String ideaId) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_practice_sessions',
      where: 'idea_id=?',
      whereArgs: <Object?>[ideaId],
      orderBy: 'updated_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JamesWillPracticeSession.fromMap(rows.first);
  }

  Future<List<JamesWillPracticeSession>> listForIdea(String ideaId, {int limit = 20}) async {
    final db = await _db;
    final rows = await db.query(
      'james_will_practice_sessions',
      where: 'idea_id=?',
      whereArgs: <Object?>[ideaId],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(JamesWillPracticeSession.fromMap).toList(growable: false);
  }

  Future<Map<String, int>> stats() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM james_will_practice_sessions');
    final selected = await db.rawQuery("SELECT COUNT(*) AS c FROM james_will_practice_sessions WHERE selected_option_title<>''");
    return <String, int>{
      'practiceSessions': int.tryParse((rows.first['c'] ?? '0').toString()) ?? 0,
      'practiceSelected': int.tryParse((selected.first['c'] ?? '0').toString()) ?? 0,
    };
  }
}
