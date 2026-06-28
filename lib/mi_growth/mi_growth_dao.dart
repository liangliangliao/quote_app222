import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'mi_growth_models.dart';

class MiGrowthDao {
  static const String profileKey = 'mi_growth_value_profile_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS mi_growth_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        scene TEXT,
        stage TEXT,
        user_input TEXT,
        ai_response TEXT,
        focus TEXT,
        values_json TEXT,
        change_talk_json TEXT,
        sustain_talk_json TEXT,
        discord_json TEXT,
        action_json TEXT,
        risk_level TEXT,
        strategy TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS mi_growth_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        title TEXT,
        focus TEXT,
        value_connection TEXT,
        time_text TEXT,
        place TEXT,
        action TEXT,
        duration TEXT,
        backup_plan TEXT,
        review_questions_json TEXT,
        confidence_score INTEGER,
        status TEXT,
        source_session_id INTEGER
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS mi_growth_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        status TEXT,
        what_happened TEXT,
        done_part TEXT,
        stuck_part TEXT,
        next_adjustment TEXT,
        value_connection TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_mi_growth_sessions_created ON mi_growth_sessions(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_mi_growth_actions_status ON mi_growth_actions(status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_mi_growth_reviews_action ON mi_growth_reviews(action_id, created_at_ms DESC)');
  }

  Future<MiGrowthValueProfile> loadProfile() async {
    final raw = await _kv.getString(profileKey);
    return MiGrowthValueProfile.fromRaw(raw ?? '');
  }

  Future<void> saveProfile(MiGrowthValueProfile profile) async {
    await _kv.setString(profileKey, profile.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).encode());
  }

  Future<int> insertSession(MiGrowthSessionRecord record) async {
    final database = await _db;
    final id = await database.insert('mi_growth_sessions', <String, Object?>{
      'created_at_ms': record.createdAtMs == 0 ? DateTime.now().millisecondsSinceEpoch : record.createdAtMs,
      'scene': record.scene,
      'stage': record.stage,
      'user_input': record.userInput,
      'ai_response': record.aiResponse,
      'focus': record.focus,
      'values_json': jsonEncode(record.valuesDetected),
      'change_talk_json': record.changeTalk.encode(),
      'sustain_talk_json': jsonEncode(record.sustainTalk),
      'discord_json': jsonEncode(record.discordSignals),
      'action_json': record.nextAction.encode(),
      'risk_level': record.riskLevel,
      'strategy': record.strategy,
    });
    if (record.nextAction.hasConcreteStep && record.riskLevel != 'crisis') {
      await insertAction(record.nextAction.copyWith(sourceSessionId: id));
    }
    return id;
  }

  Future<List<MiGrowthSessionRecord>> listSessions({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('mi_growth_sessions', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(MiGrowthSessionRecord.fromMap).toList(growable: false);
  }

  Future<int> insertAction(MiGrowthActionPlan action) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('mi_growth_actions', <String, Object?>{
      'created_at_ms': action.createdAtMs == 0 ? now : action.createdAtMs,
      'updated_at_ms': action.updatedAtMs == 0 ? now : action.updatedAtMs,
      'title': action.title,
      'focus': action.focus,
      'value_connection': action.valueConnection,
      'time_text': action.timeText,
      'place': action.place,
      'action': action.action,
      'duration': action.duration,
      'backup_plan': action.backupPlan,
      'review_questions_json': jsonEncode(action.reviewQuestions),
      'confidence_score': action.confidenceScore,
      'status': action.status,
      'source_session_id': action.sourceSessionId,
    });
  }

  Future<List<MiGrowthActionPlan>> listActions({String? status, int limit = 50}) async {
    final database = await _db;
    final rows = await database.query(
      'mi_growth_actions',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'updated_at_ms DESC, created_at_ms DESC',
      limit: limit,
    );
    return rows.map((row) => MiGrowthActionPlan(
      id: row['id'] as int?,
      createdAtMs: _int(row['created_at_ms']),
      updatedAtMs: _int(row['updated_at_ms']),
      title: (row['title'] ?? '').toString(),
      focus: (row['focus'] ?? '').toString(),
      valueConnection: (row['value_connection'] ?? '').toString(),
      timeText: (row['time_text'] ?? '').toString(),
      place: (row['place'] ?? '').toString(),
      action: (row['action'] ?? '').toString(),
      duration: (row['duration'] ?? '').toString(),
      backupPlan: (row['backup_plan'] ?? '').toString(),
      reviewQuestions: _listFromRaw((row['review_questions_json'] ?? '').toString()),
      confidenceScore: row['confidence_score'] is int ? row['confidence_score'] as int : int.tryParse((row['confidence_score'] ?? '').toString()),
      status: (row['status'] ?? 'open').toString(),
      sourceSessionId: row['source_session_id'] is int ? row['source_session_id'] as int : int.tryParse((row['source_session_id'] ?? '').toString()),
    )).toList(growable: false);
  }

  Future<void> updateActionStatus(int id, String status) async {
    final database = await _db;
    await database.update(
      'mi_growth_actions',
      <String, Object?>{'status': status, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> insertReview(MiGrowthReviewRecord review) async {
    final database = await _db;
    final id = await database.insert('mi_growth_reviews', <String, Object?>{
      'action_id': review.actionId,
      'created_at_ms': review.createdAtMs == 0 ? DateTime.now().millisecondsSinceEpoch : review.createdAtMs,
      'status': review.status,
      'what_happened': review.whatHappened,
      'done_part': review.donePart,
      'stuck_part': review.stuckPart,
      'next_adjustment': review.nextAdjustment,
      'value_connection': review.valueConnection,
    });
    if (review.actionId > 0) {
      await updateActionStatus(review.actionId, review.status == 'completed' ? 'completed' : 'reviewed');
    }
    return id;
  }

  Future<List<MiGrowthReviewRecord>> listReviews({int limit = 50}) async {
    final database = await _db;
    final rows = await database.query('mi_growth_reviews', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(MiGrowthReviewRecord.fromMap).toList(growable: false);
  }

  Future<MiGrowthStats> stats() async {
    final database = await _db;
    Future<int> count(String sql, [List<Object?> args = const <Object?>[]]) async {
      final rows = await database.rawQuery(sql, args);
      if (rows.isEmpty) return 0;
      final v = rows.first.values.first;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final sessions = await count('SELECT COUNT(*) FROM mi_growth_sessions');
    final actions = await count('SELECT COUNT(*) FROM mi_growth_actions');
    final openActions = await count("SELECT COUNT(*) FROM mi_growth_actions WHERE status = 'open'");
    final reviews = await count('SELECT COUNT(*) FROM mi_growth_reviews');
    final profile = await loadProfile();
    final recent = await listSessions(limit: 40);
    final changeTalkCount = recent.fold<int>(0, (sum, s) => sum + s.changeTalk.all.length);
    return MiGrowthStats(
      sessions: sessions,
      actions: actions,
      openActions: openActions,
      reviews: reviews,
      changeTalkCount: changeTalkCount,
      valueCount: profile.values.length,
    );
  }

  Future<String> recentContextJson() async {
    final sessions = await listSessions(limit: 8);
    final actions = await listActions(limit: 8);
    final reviews = await listReviews(limit: 8);
    return jsonEncode(<String, dynamic>{
      'recent_sessions': sessions.map((s) => <String, dynamic>{
        'stage': s.stage,
        'focus': s.focus,
        'values': s.valuesDetected,
        'change_talk': s.changeTalk.all.take(6).toList(),
        'risk_level': s.riskLevel,
      }).toList(),
      'recent_actions': actions.map((a) => <String, dynamic>{
        'title': a.title,
        'focus': a.focus,
        'value_connection': a.valueConnection,
        'action': a.action,
        'status': a.status,
      }).toList(),
      'recent_reviews': reviews.map((r) => <String, dynamic>{
        'status': r.status,
        'done_part': r.donePart,
        'stuck_part': r.stuckPart,
        'next_adjustment': r.nextAdjustment,
      }).toList(),
    });
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

List<String> _listFromRaw(String raw) {
  if (raw.trim().isEmpty) return <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
  } catch (_) {}
  return raw.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}
