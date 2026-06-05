import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'behavior_tracking_models.dart';

class BehaviorTrackingDao {
  static const String tableName = 'behavior_tracking_records';

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        record_date_ms INTEGER NOT NULL,
        mode TEXT,
        primary_layer TEXT,
        category TEXT,
        title TEXT,
        start_minute INTEGER,
        end_minute INTEGER,
        behavior TEXT,
        reason TEXT,
        outcome TEXT,
        emotion TEXT,
        emotion_intensity INTEGER,
        trigger_text TEXT,
        cognition TEXT,
        reaction TEXT,
        environment TEXT,
        body_state TEXT,
        short_term_result TEXT,
        long_term_impact TEXT,
        alternative TEXT,
        sleep TEXT,
        important_behaviors TEXT,
        time_waste TEXT,
        mood TEXT,
        tomorrow_adjustment TEXT,
        notes TEXT,
        tags_json TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_date ON $tableName(record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_category ON $tableName(category)');
  }

  Future<int> save(BehaviorTrackingRecord record) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = record.copyWith(updatedAtMs: now, createdAtMs: record.id == null ? now : record.createdAtMs).toMap();
    if (record.id == null) {
      data.remove('id');
      return db.insert(tableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update(tableName, data, where: 'id = ?', whereArgs: [record.id]);
    return record.id!;
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BehaviorTrackingRecord>> recent({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query(tableName, orderBy: 'record_date_ms DESC, id DESC', limit: limit);
    return rows.map(BehaviorTrackingRecord.fromMap).toList();
  }

  Future<List<BehaviorTrackingRecord>> between(DateTime startInclusive, DateTime endExclusive) async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: 'record_date_ms >= ? AND record_date_ms < ?',
      whereArgs: [
        DateTime(startInclusive.year, startInclusive.month, startInclusive.day).millisecondsSinceEpoch,
        DateTime(endExclusive.year, endExclusive.month, endExclusive.day).millisecondsSinceEpoch,
      ],
      orderBy: 'record_date_ms DESC, start_minute ASC, id DESC',
    );
    return rows.map(BehaviorTrackingRecord.fromMap).toList();
  }

  Future<List<BehaviorTrackingRecord>> today() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return between(start, start.add(const Duration(days: 1)));
  }
}
