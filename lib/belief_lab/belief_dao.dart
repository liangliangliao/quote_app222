import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:quote_app/data/db.dart';
import 'belief_models.dart';
import 'belief_seed.dart';

class BeliefDao {
  Future<Database> _db() => AppDatabase.instance();

  Future<void> ensureTables() async {
    final db = await _db();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS belief_segments (
        id INTEGER PRIMARY KEY,
        lecture INTEGER NOT NULL,
        seg_no INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        tags_json TEXT NOT NULL DEFAULT '[]',
        UNIQUE(lecture, seg_no) ON CONFLICT REPLACE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS belief_progress (
        key TEXT PRIMARY KEY,
        status INTEGER NOT NULL DEFAULT 0,
        updated_at_ms INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
  }

  Future<void> seedIfNeeded() async {
    final db = await _db();
    await ensureTables();
    final cnt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(1) FROM belief_segments')) ?? 0;
    if (cnt > 0) return;

    await db.transaction((txn) async {
      for (final m in beliefSeedSegments) {
        await txn.insert('belief_segments', {
          'id': m['id'],
          'lecture': m['lecture'],
          'seg_no': m['seg_no'],
          'title': m['title'],
          'body': m['body'],
          'tags_json': m['tags_json'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<BeliefSegment>> listSegments({int? lecture}) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'belief_segments',
      where: lecture == null ? null : 'lecture=?',
      whereArgs: lecture == null ? null : [lecture],
      orderBy: 'lecture ASC, seg_no ASC',
    );
    return rows.map((r) => BeliefSegment.fromRow(r)).toList();
  }

  Future<BeliefSegment?> getSegmentByKey(String key) async {
    // key like L6#12
    final m = RegExp(r'^L(\d+)#(\d+)$').firstMatch(key);
    if (m == null) return null;
    final lecture = int.tryParse(m.group(1) ?? '');
    final segNo = int.tryParse(m.group(2) ?? '');
    if (lecture == null || segNo == null) return null;

    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'belief_segments',
      where: 'lecture=? AND seg_no=?',
      whereArgs: [lecture, segNo],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return BeliefSegment.fromRow(rows.first);
  }

  Future<Map<String, BeliefSegment>> getSegmentsByKeys(List<String> keys) async {
    final out = <String, BeliefSegment>{};
    for (final k in keys) {
      final s = await getSegmentByKey(k);
      if (s != null) out[k] = s;
    }
    return out;
  }

  Future<BeliefProgress?> getProgress(String key) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query('belief_progress', where: 'key=?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return BeliefProgress.fromRow(rows.first);
  }

  Future<void> upsertProgress(String key, {required int status, Map<String, dynamic>? payload}) async {
    final db = await _db();
    await ensureTables();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'belief_progress',
      {
        'key': key,
        'status': status,
        'updated_at_ms': now,
        'payload_json': jsonEncode(payload ?? {}),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BeliefProgress>> listProgressByPrefix(String prefix) async {
    final db = await _db();
    await ensureTables();
    final rows = await db.query(
      'belief_progress',
      where: 'key LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'updated_at_ms DESC',
    );
    return rows.map((r) => BeliefProgress.fromRow(r)).toList();
  }

  Future<void> deleteProgress(String key) async {
    final db = await _db();
    await ensureTables();
    await db.delete('belief_progress', where: 'key=?', whereArgs: [key]);
  }
}
