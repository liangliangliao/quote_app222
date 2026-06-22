import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import 'realistic_optimism_models.dart';

class RealisticOptimismDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> ensureTables() async {
    final db = await _db();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_cases (
        id TEXT PRIMARY KEY,
        source TEXT NOT NULL DEFAULT 'manual',
        title TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ro_cases_updated ON realistic_optimism_cases(updated_at_ms DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_action_logs (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        status TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ro_action_case ON realistic_optimism_action_logs(case_id, created_at_ms DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_failure_reviews (
        id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        event TEXT NOT NULL DEFAULT '',
        original_explanation TEXT NOT NULL DEFAULT '',
        permanent_flag INTEGER NOT NULL DEFAULT 0,
        global_flag INTEGER NOT NULL DEFAULT 0,
        personalization_flag INTEGER NOT NULL DEFAULT 0,
        catastrophe_flag INTEGER NOT NULL DEFAULT 0,
        realistic_explanation TEXT NOT NULL DEFAULT '',
        feedback TEXT NOT NULL DEFAULT '',
        next_adjustment TEXT NOT NULL DEFAULT '',
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ro_review_case ON realistic_optimism_failure_reviews(case_id, created_at_ms DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS realistic_optimism_baselines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_ms INTEGER NOT NULL,
        mood_score REAL NOT NULL DEFAULT 0,
        self_esteem_score REAL NOT NULL DEFAULT 0,
        self_efficacy_score REAL NOT NULL DEFAULT 0,
        cope_count INTEGER NOT NULL DEFAULT 0,
        avoid_count INTEGER NOT NULL DEFAULT 0,
        minimum_action_done INTEGER NOT NULL DEFAULT 0,
        failure_review_done INTEGER NOT NULL DEFAULT 0,
        realistic_optimism_used INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ro_baseline_time ON realistic_optimism_baselines(ts_ms DESC)');
  }

  Future<void> upsertCase(RealisticOptimismCase item) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'realistic_optimism_cases',
      <String, Object?>{
        'id': item.id,
        'source': item.source,
        'title': item.title,
        'created_at_ms': item.createdAtMs,
        'updated_at_ms': item.updatedAtMs,
        'payload_json': jsonEncode(item.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RealisticOptimismCase>> listCases({int limit = 50}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_cases', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map((e) => RealisticOptimismCase.fromRow(e)).toList();
  }

  Future<RealisticOptimismCase?> getCase(String id) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_cases', where: 'id=?', whereArgs: <Object?>[id], limit: 1);
    if (rows.isEmpty) return null;
    return RealisticOptimismCase.fromRow(rows.first);
  }

  Future<void> deleteCase(String id) async {
    final db = await _db();
    await ensureTables();
    await db.transaction((txn) async {
      await txn.delete('realistic_optimism_action_logs', where: 'case_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_failure_reviews', where: 'case_id=?', whereArgs: <Object?>[id]);
      await txn.delete('realistic_optimism_cases', where: 'id=?', whereArgs: <Object?>[id]);
    });
  }

  Future<void> clearAll() async {
    final db = await _db();
    await ensureTables();
    await db.transaction((txn) async {
      await txn.delete('realistic_optimism_action_logs');
      await txn.delete('realistic_optimism_failure_reviews');
      await txn.delete('realistic_optimism_baselines');
      await txn.delete('realistic_optimism_cases');
    });
  }

  Future<void> addActionLog(RealisticOptimismActionLog log) async {
    final db = await _db();
    await ensureTables();
    await db.insert(
      'realistic_optimism_action_logs',
      <String, Object?>{
        'id': log.id,
        'case_id': log.caseId,
        'status': log.status,
        'note': log.note,
        'created_at_ms': log.createdAtMs,
        'payload_json': jsonEncode(log.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RealisticOptimismActionLog>> listActionLogs(String caseId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'realistic_optimism_action_logs',
      where: 'case_id=?',
      whereArgs: <Object?>[caseId],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map((e) => RealisticOptimismActionLog.fromRow(e)).toList();
  }

  Future<void> addFailureReview(RealisticOptimismFailureReview review) async {
    final db = await _db();
    await ensureTables();
    await db.insert('realistic_optimism_failure_reviews', review.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RealisticOptimismFailureReview>> listFailureReviews(String caseId) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'realistic_optimism_failure_reviews',
      where: 'case_id=?',
      whereArgs: <Object?>[caseId],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map((e) => RealisticOptimismFailureReview.fromRow(e)).toList();
  }

  Future<int> addBaseline(RealisticOptimismBaselineEntry entry) async {
    final db = await _db();
    await ensureTables();
    return db.insert('realistic_optimism_baselines', entry.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RealisticOptimismBaselineEntry>> listBaselines({int limit = 30}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('realistic_optimism_baselines', orderBy: 'ts_ms DESC', limit: limit);
    return rows.map((e) => RealisticOptimismBaselineEntry.fromRow(e)).toList();
  }

  Future<Map<String, int>> counts() async {
    final db = await _db();
    await ensureTables();
    final cases = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM realistic_optimism_cases')) ?? 0;
    final actions = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM realistic_optimism_action_logs')) ?? 0;
    final reviews = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM realistic_optimism_failure_reviews')) ?? 0;
    final baselines = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM realistic_optimism_baselines')) ?? 0;
    return <String, int>{'cases': cases, 'actions': actions, 'reviews': reviews, 'baselines': baselines};
  }
}
