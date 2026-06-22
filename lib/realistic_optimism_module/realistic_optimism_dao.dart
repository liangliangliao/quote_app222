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

    // Product-spec schema for the standalone "现实主义乐观训练系统".
    // The current UI keeps rich AI payloads in realistic_optimism_cases, while
    // these tables provide stable persistence targets for the full P0/P1 loop.
    await db.execute('CREATE TABLE IF NOT EXISTS optimism_event (id TEXT PRIMARY KEY, user_id TEXT NOT NULL DEFAULT "", raw_event TEXT NOT NULL DEFAULT "", emotion TEXT NOT NULL DEFAULT "", emotion_intensity INTEGER NOT NULL DEFAULT 0, intensity_level TEXT NOT NULL DEFAULT "", automatic_interpretation TEXT NOT NULL DEFAULT "", created_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS explanation_style_score (id TEXT PRIMARY KEY, event_id TEXT NOT NULL, permanence_score INTEGER NOT NULL DEFAULT 0, pervasiveness_score INTEGER NOT NULL DEFAULT 0, personalization_score INTEGER NOT NULL DEFAULT 0, catastrophizing_score INTEGER NOT NULL DEFAULT 0, helplessness_score INTEGER NOT NULL DEFAULT 0, filtering_score INTEGER NOT NULL DEFAULT 0, balanced_reframe TEXT NOT NULL DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS benefit_reframe (id TEXT PRIMARY KEY, event_id TEXT NOT NULL, fault_finder_story TEXT NOT NULL DEFAULT "", benefit_finder_story TEXT NOT NULL DEFAULT "", uncontrollable_parts TEXT NOT NULL DEFAULT "[]", controllable_parts TEXT NOT NULL DEFAULT "[]", micro_action TEXT NOT NULL DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS action_evidence (id TEXT PRIMARY KEY, event_id TEXT NOT NULL, action TEXT NOT NULL DEFAULT "", completed INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, evidence_text TEXT NOT NULL DEFAULT "", self_efficacy_score REAL NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS failure_immunity (id TEXT PRIMARY KEY, event_id TEXT NOT NULL, predicted_pain REAL, actual_pain REAL, predicted_recovery TEXT NOT NULL DEFAULT "", actual_recovery TEXT NOT NULL DEFAULT "", worst_case_prediction TEXT NOT NULL DEFAULT "", actual_result TEXT NOT NULL DEFAULT "", antibody TEXT NOT NULL DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS controlled_failure_challenge (id TEXT PRIMARY KEY, challenge_name TEXT NOT NULL DEFAULT "", risk_level TEXT NOT NULL DEFAULT "", safety_boundary TEXT NOT NULL DEFAULT "", predicted_pain REAL, actual_pain REAL, recovery_time TEXT NOT NULL DEFAULT "", lesson TEXT NOT NULL DEFAULT "", antibody TEXT NOT NULL DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS gratitude_entry (id TEXT PRIMARY KEY, concrete_gratitude TEXT NOT NULL DEFAULT "", why_matters TEXT NOT NULL DEFAULT "", appreciation_action TEXT NOT NULL DEFAULT "", created_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS savoring_entry (id TEXT PRIMARY KEY, moment_title TEXT NOT NULL DEFAULT "", sensory_detail TEXT NOT NULL DEFAULT "", body_feeling TEXT NOT NULL DEFAULT "", meaning TEXT NOT NULL DEFAULT "", created_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS attention_prime (id TEXT PRIMARY KEY, value_word TEXT NOT NULL DEFAULT "", reminder TEXT NOT NULL DEFAULT "", widget_text TEXT NOT NULL DEFAULT "", benefit_question TEXT NOT NULL DEFAULT "", active INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE IF NOT EXISTS anti_prime (id TEXT PRIMARY KEY, trigger_type TEXT NOT NULL DEFAULT "", trigger_name TEXT NOT NULL DEFAULT "", effect TEXT NOT NULL DEFAULT "", cleanup_action TEXT NOT NULL DEFAULT "", replacement_prime TEXT NOT NULL DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS identity_evidence (id TEXT PRIMARY KEY, source_type TEXT NOT NULL DEFAULT "", source_id TEXT NOT NULL DEFAULT "", identity_type TEXT NOT NULL DEFAULT "", evidence_text TEXT NOT NULL DEFAULT "", identity_sentence TEXT NOT NULL DEFAULT "")');
    await db.execute('CREATE TABLE IF NOT EXISTS happiness_baseline (id TEXT PRIMARY KEY, week_start TEXT NOT NULL DEFAULT "", happiness_score REAL NOT NULL DEFAULT 0, recovery_score REAL NOT NULL DEFAULT 0, agency_score REAL NOT NULL DEFAULT 0, permanence_frequency REAL NOT NULL DEFAULT 0, gratitude_sensitivity REAL NOT NULL DEFAULT 0, action_stability REAL NOT NULL DEFAULT 0)');
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
