import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'second_thought_models.dart';

/// 第二念模块的独立 DAO。
///
/// 只创建 second_thought_* 数据表，不改写、不复用其他模块表结构。
class SecondThoughtDao {
  static const String profileKey = 'second_thought_value_profile_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS second_thought_cases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        title TEXT,
        scene TEXT,
        user_input TEXT,
        ai_response TEXT,
        ambivalence_type TEXT,
        confidence REAL,
        core_conflict TEXT,
        go_forces_json TEXT,
        no_forces_json TEXT,
        inner_committee_json TEXT,
        possible_values_json TEXT,
        core_values_json TEXT,
        value_conflicts_json TEXT,
        evidence_questions_json TEXT,
        options_json TEXT,
        third_way_json TEXT,
        change_talk_json TEXT,
        action_experiment_json TEXT,
        status TEXT,
        risk_level TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS second_thought_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        case_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        status TEXT,
        what_happened TEXT,
        values_lived TEXT,
        remaining_voices TEXT,
        adjustment TEXT,
        next_micro_action TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_second_thought_cases_created ON second_thought_cases(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_second_thought_cases_status ON second_thought_cases(status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_second_thought_reviews_case ON second_thought_reviews(case_id, created_at_ms DESC)');
  }

  Future<SecondThoughtProfile> loadProfile() async {
    final raw = await _kv.getString(profileKey);
    return SecondThoughtProfile.fromRaw(raw ?? '');
  }

  Future<void> saveProfile(SecondThoughtProfile profile) async {
    await _kv.setString(profileKey, profile.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).encode());
  }

  Future<int> insertCase(SecondThoughtCaseRecord record) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('second_thought_cases', <String, Object?>{
      'created_at_ms': record.createdAtMs == 0 ? now : record.createdAtMs,
      'updated_at_ms': record.updatedAtMs == 0 ? now : record.updatedAtMs,
      'title': record.title,
      'scene': record.scene,
      'user_input': record.userInput,
      'ai_response': record.aiResponse,
      'ambivalence_type': record.ambivalenceType,
      'confidence': record.confidence,
      'core_conflict': record.coreConflict,
      'go_forces_json': jsonEncode(record.goForces.map((e) => e.toJson()).toList(growable: false)),
      'no_forces_json': jsonEncode(record.noForces.map((e) => e.toJson()).toList(growable: false)),
      'inner_committee_json': jsonEncode(record.innerCommittee.map((e) => e.toJson()).toList(growable: false)),
      'possible_values_json': jsonEncode(record.possibleValues),
      'core_values_json': jsonEncode(record.coreValuesToConfirm),
      'value_conflicts_json': jsonEncode(record.valueConflicts.map((e) => e.toJson()).toList(growable: false)),
      'evidence_questions_json': jsonEncode(record.evidenceQuestions),
      'options_json': jsonEncode(record.options.map((e) => e.toJson()).toList(growable: false)),
      'third_way_json': jsonEncode(record.thirdWayPossibilities),
      'change_talk_json': record.changeTalk.encode(),
      'action_experiment_json': record.actionExperiment.encode(),
      'status': record.status,
      'risk_level': record.riskLevel,
    });
  }

  Future<List<SecondThoughtCaseRecord>> listCases({int limit = 40}) async {
    final database = await _db;
    final rows = await database.query('second_thought_cases', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(SecondThoughtCaseRecord.fromMap).toList(growable: false);
  }

  Future<List<SecondThoughtCaseRecord>> listActionCases({int limit = 40}) async {
    final cases = await listCases(limit: limit);
    return cases.where((c) => c.actionExperiment.hasAction).toList(growable: false);
  }

  Future<void> updateCaseStatus(int id, String status) async {
    final database = await _db;
    await database.update(
      'second_thought_cases',
      <String, Object?>{'status': status, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteCase(int id) async {
    final database = await _db;
    await database.delete('second_thought_reviews', where: 'case_id = ?', whereArgs: <Object?>[id]);
    await database.delete('second_thought_cases', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<int> insertReview(SecondThoughtReviewRecord review) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('second_thought_reviews', <String, Object?>{
      'case_id': review.caseId,
      'created_at_ms': review.createdAtMs == 0 ? now : review.createdAtMs,
      'status': review.status,
      'what_happened': review.whatHappened,
      'values_lived': review.valuesLived,
      'remaining_voices': review.remainingVoices,
      'adjustment': review.adjustment,
      'next_micro_action': review.nextMicroAction,
    });
  }

  Future<List<SecondThoughtReviewRecord>> listReviews({int? caseId, int limit = 50}) async {
    final database = await _db;
    final rows = await database.query(
      'second_thought_reviews',
      where: caseId == null ? null : 'case_id = ?',
      whereArgs: caseId == null ? null : <Object?>[caseId],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(SecondThoughtReviewRecord.fromMap).toList(growable: false);
  }

  Future<SecondThoughtStats> stats() async {
    final database = await _db;
    Future<int> count(String sql, [List<Object?> args = const <Object?>[]]) async {
      final rows = await database.rawQuery(sql, args);
      if (rows.isEmpty) return 0;
      final v = rows.first.values.first;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final cases = await count('SELECT COUNT(*) FROM second_thought_cases');
    final openCases = await count("SELECT COUNT(*) FROM second_thought_cases WHERE status IN ('exploring','acting','integrating')");
    final reviews = await count('SELECT COUNT(*) FROM second_thought_reviews');
    final recent = await listCases(limit: 80);
    final actionExperiments = recent.where((c) => c.actionExperiment.hasAction).length;
    final changeTalkCount = recent.fold<int>(0, (sum, c) => sum + c.changeTalk.all.length);
    final profile = await loadProfile();
    return SecondThoughtStats(
      cases: cases,
      actionExperiments: actionExperiments,
      openCases: openCases,
      reviews: reviews,
      valueCount: profile.coreValues.length,
      changeTalkCount: changeTalkCount,
    );
  }

  Future<String> recentContextJson() async {
    final cases = await listCases(limit: 8);
    final reviews = await listReviews(limit: 8);
    return jsonEncode(<String, dynamic>{
      'recent_cases': cases.map((c) => <String, dynamic>{
        'title': c.title,
        'ambivalence_type': c.ambivalenceType,
        'core_conflict': c.coreConflict,
        'values': c.coreValuesToConfirm,
        'status': c.status,
        'change_talk': c.changeTalk.all.take(8).toList(growable: false),
        'action': c.actionExperiment.microAction,
      }).toList(growable: false),
      'recent_reviews': reviews.map((r) => <String, dynamic>{
        'status': r.status,
        'what_happened': r.whatHappened,
        'values_lived': r.valuesLived,
        'remaining_voices': r.remainingVoices,
        'adjustment': r.adjustment,
      }).toList(growable: false),
    });
  }
}
