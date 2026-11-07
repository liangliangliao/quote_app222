import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'store.dart';

/// 生产用存储：沿用 App 的数据库，只建 prp_ 前缀的表（CREATE TABLE IF NOT EXISTS，幂等）。
/// 建表在第一次使用时进行，与敌人的 EnemySchema.createAll 做法一致，不走 App 的迁移体系。
class SqflitePrpStore implements PrpStore {
  SqflitePrpStore(this._open);

  final Future<Database> Function() _open;
  Future<Database>? _ready;

  Future<Database> _db() async {
    final Future<Database>? existing = _ready;
    if (existing != null) return existing;
    final Future<Database> f = () async {
      final Database db = await _open();
      for (final String sql in PrpSchema.createStatements) {
        await db.execute(sql);
      }
      return db;
    }();
    _ready = f;
    try {
      return await f;
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

  Map<String, Object?> _withoutId(Map<String, Object?> m) {
    final Map<String, Object?> copy = Map<String, Object?>.from(m);
    copy.remove('id');
    return copy;
  }

  // ───────────────────────── 会话 ─────────────────────────

  @override
  Future<int> insertSession(PrpSession s) async {
    final Database db = await _db();
    return db.insert('prp_session', _withoutId(s.toMap()));
  }

  @override
  Future<void> updateSession(PrpSession s) async {
    final int? id = s.id;
    if (id == null) return;
    final Database db = await _db();
    await db.update(
      'prp_session',
      _withoutId(s.toMap()),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<PrpSession?> session(int id) async {
    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      'prp_session',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : PrpSession.fromMap(rows.first);
  }

  @override
  Future<int> countSessionsSince(int sinceMs) async {
    final Database db = await _db();
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM prp_session WHERE started_ms >= ?',
            <Object?>[sinceMs],
          ),
        ) ??
        0;
  }

  @override
  Future<int> sessionCount() async {
    final Database db = await _db();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM prp_session'),
        ) ??
        0;
  }

  // ───────────────────────── 教训 ─────────────────────────

  @override
  Future<int> insertLesson(PrpLesson l) async {
    final Database db = await _db();
    return db.insert('prp_lesson', _withoutId(l.toMap()));
  }

  @override
  Future<void> updateLesson(PrpLesson l) async {
    final int? id = l.id;
    if (id == null) return;
    final Database db = await _db();
    await db.update(
      'prp_lesson',
      _withoutId(l.toMap()),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<PrpLesson?> lesson(int id) async {
    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      'prp_lesson',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : PrpLesson.fromMap(rows.first);
  }

  @override
  Future<List<PrpLesson>> lessons({
    PrpLessonState? state,
    int limit = 200,
  }) async {
    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      'prp_lesson',
      where: state == null ? null : 'state = ?',
      whereArgs: state == null ? null : <Object?>[state.name],
      orderBy: 'COALESCE(sealed_ms, created_ms) DESC, id DESC',
      limit: limit,
    );
    return rows.map(PrpLesson.fromMap).toList();
  }

  @override
  Future<int> lessonCount(PrpLessonState state) async {
    final Database db = await _db();
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM prp_lesson WHERE state = ?',
            <Object?>[state.name],
          ),
        ) ??
        0;
  }

  @override
  Future<void> bumpLessonCounters(
    int lessonId, {
    int verified = 0,
    int repeated = 0,
  }) async {
    final Database db = await _db();
    await db.rawUpdate(
      'UPDATE prp_lesson SET verified_cnt = verified_cnt + ?, repeated_cnt = repeated_cnt + ? WHERE id = ?',
      <Object?>[verified, repeated, lessonId],
    );
  }

  // ───────────────────────── 回访 ─────────────────────────

  @override
  Future<int> insertRecall(PrpRecall r) async {
    final Database db = await _db();
    return db.insert('prp_recall', _withoutId(r.toMap()));
  }

  @override
  Future<PrpRecall?> recall(int id) async {
    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      'prp_recall',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : PrpRecall.fromMap(rows.first);
  }

  @override
  Future<void> updateRecallOutcome(int id, PrpOutcome outcome) async {
    final Database db = await _db();
    await db.update(
      'prp_recall',
      <String, Object?>{'outcome': outcome.name},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  @override
  Future<List<PrpRecall>> recalls({
    PrpOutcome? outcome,
    int limit = 200,
  }) async {
    final Database db = await _db();
    final List<Map<String, Object?>> rows = await db.query(
      'prp_recall',
      where: outcome == null ? null : 'outcome = ?',
      whereArgs: outcome == null ? null : <Object?>[outcome.name],
      orderBy: 'ts DESC',
      limit: limit,
    );
    return rows.map(PrpRecall.fromMap).toList();
  }

  @override
  Future<int> countRecallsSince(
    int sinceMs, {
    required Set<String> contexts,
  }) async {
    if (contexts.isEmpty) return 0;
    final Database db = await _db();
    final String marks = List<String>.filled(contexts.length, '?').join(',');
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM prp_recall WHERE ts >= ? AND context IN ($marks)',
            <Object?>[sinceMs, ...contexts],
          ),
        ) ??
        0;
  }

  @override
  Future<int> recallCount() async {
    final Database db = await _db();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM prp_recall'),
        ) ??
        0;
  }

  // ───────────────────────── 导出 / 清除 ─────────────────────────

  @override
  Future<String> exportJson() async {
    final Database db = await _db();
    final List<Map<String, Object?>> lessons = await db.query(
      'prp_lesson',
      orderBy: 'id ASC',
    );
    final List<Map<String, Object?>> sessions = await db.query(
      'prp_session',
      orderBy: 'id ASC',
    );
    final List<Map<String, Object?>> recalls = await db.query(
      'prp_recall',
      orderBy: 'id ASC',
    );
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'version': 1,
      'lessons': lessons,
      'sessions': sessions,
      'recalls': recalls,
    });
  }

  @override
  Future<void> clearAll() async {
    final Database db = await _db();
    await db.transaction((Transaction txn) async {
      for (final String t in PrpSchema.tables) {
        await txn.delete(t);
      }
    });
  }
}
