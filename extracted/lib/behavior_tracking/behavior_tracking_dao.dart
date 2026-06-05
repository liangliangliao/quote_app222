import 'dart:convert';

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
        template_key TEXT,
        entry_mode TEXT,
        source TEXT,
        timezone TEXT,
        privacy_level TEXT,
        sync_state TEXT,
        deleted_at_ms INTEGER,
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
    await _ensureColumn(db, 'template_key', 'TEXT');
    await _ensureColumn(db, 'entry_mode', 'TEXT');
    await _ensureColumn(db, 'source', 'TEXT');
    await _ensureColumn(db, 'timezone', 'TEXT');
    await _ensureColumn(db, 'privacy_level', 'TEXT');
    await _ensureColumn(db, 'sync_state', 'TEXT');
    await _ensureColumn(db, 'deleted_at_ms', 'INTEGER');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_date ON $tableName(record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_category ON $tableName(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_mode_date ON $tableName(mode, record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_updated ON $tableName(updated_at_ms DESC)');
  }

  Future<void> _ensureColumn(Database db, String name, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((row) => row['name'] == name);
    if (!exists) await db.execute('ALTER TABLE $tableName ADD COLUMN $name $type');
  }

  Future<int> save(BehaviorTrackingRecord record) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = record
        .copyWith(
          updatedAtMs: now,
          createdAtMs: record.id == null ? now : record.createdAtMs,
          templateKey: record.templateKey.isEmpty ? BehaviorTrackingTemplate.keyForMode(record.mode) : record.templateKey,
          entryMode: record.entryMode.isEmpty ? record.mode : record.entryMode,
          source: record.source.isEmpty ? 'manual' : record.source,
          timezone: record.timezone.isEmpty ? DateTime.now().timeZoneName : record.timezone,
          privacyLevel: record.privacyLevel.isEmpty ? 'local_first' : record.privacyLevel,
          syncState: 'local_pending',
        )
        .toMap();
    if (record.id == null) {
      data.remove('id');
      return db.insert(tableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update(tableName, data, where: 'id = ?', whereArgs: [record.id]);
    return record.id!;
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(tableName, {'deleted_at_ms': now, 'updated_at_ms': now, 'sync_state': 'local_pending'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> purgeDeleted({Duration olderThan = const Duration(days: 30)}) async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
    await db.delete(tableName, where: 'deleted_at_ms IS NOT NULL AND deleted_at_ms < ?', whereArgs: [cutoff]);
  }

  Future<List<BehaviorTrackingRecord>> recent({int limit = 200, bool includeDeleted = false}) async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: includeDeleted ? null : 'deleted_at_ms IS NULL',
      orderBy: 'record_date_ms DESC, id DESC',
      limit: limit,
    );
    return rows.map(BehaviorTrackingRecord.fromMap).toList();
  }

  Future<List<BehaviorTrackingRecord>> between(DateTime startInclusive, DateTime endExclusive, {bool includeDeleted = false}) async {
    final db = await _db;
    final where = StringBuffer('record_date_ms >= ? AND record_date_ms < ?');
    if (!includeDeleted) where.write(' AND deleted_at_ms IS NULL');
    final rows = await db.query(
      tableName,
      where: where.toString(),
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

  Future<BehaviorTrackingStats> statsForLastDays(int days) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: days));
    return BehaviorTrackingStats.fromRecords(await between(start, end));
  }

  Future<String> exportJson({int days = 90}) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: days));
    final records = await between(start, end);
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'range_days': days,
      'privacy_note': '本导出由本地数据库生成；健康、情绪、认知与位置线索可能包含敏感个人信息。',
      'templates': behaviorTrackingTemplates.map((t) => {
            'key': t.key,
            'name': t.name,
            'entry_mode': t.entryMode,
            'required_fields': t.requiredFields,
            'optional_layers': t.optionalLayers,
          }).toList(),
      'records': records.map((r) => r.toMap()).toList(),
    });
  }

  Future<String> exportCsv({int days = 90}) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: days));
    final records = await between(start, end);
    String esc(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      ['record_date', 'template_key', 'entry_mode', 'primary_layer', 'category', 'title', 'start_minute', 'end_minute', 'duration_min', 'behavior', 'emotion', 'emotion_intensity', 'trigger', 'short_term_result', 'long_term_impact', 'alternative', 'source', 'privacy_level', 'tags'],
      for (final r in records)
        [DateTime.fromMillisecondsSinceEpoch(r.recordDateMs).toIso8601String(), r.templateKey, r.entryMode, r.primaryLayer, r.category, r.title, r.startMinute, r.endMinute, r.durationMinutes, r.behavior, r.emotion, r.emotionIntensity, r.trigger, r.shortTermResult, r.longTermImpact, r.alternative, r.source, r.privacyLevel, r.tags.join('|')],
    ];
    return rows.map((row) => row.map(esc).join(',')).join('\n');
  }

  Future<String> exportMarkdown({int days = 30}) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: days));
    final records = await between(start, end);
    final stats = BehaviorTrackingStats.fromRecords(records);
    final buffer = StringBuffer()
      ..writeln('# 行为跟踪复盘导出')
      ..writeln()
      ..writeln('- 导出时间：${DateTime.now().toIso8601String()}')
      ..writeln('- 覆盖周期：近 $days 天')
      ..writeln('- 记录数：${stats.recordCount}')
      ..writeln('- 已标记时间：${stats.totalMinutes} 分钟')
      ..writeln()
      ..writeln('> 提醒：统计仅用于自我观察；相关性不代表因果，也不构成医疗判断。')
      ..writeln();
    for (final record in records) {
      buffer
        ..writeln('## ${DateTime.fromMillisecondsSinceEpoch(record.recordDateMs).toIso8601String().split('T').first} · ${record.title.isEmpty ? record.primaryLayer : record.title}')
        ..writeln()
        ..writeln('- 模板：${record.templateKey} / ${record.entryMode}')
        ..writeln('- 层面：${record.primaryLayer}')
        ..writeln('- 时间：${record.timeRangeLabel.isEmpty ? '未填' : record.timeRangeLabel}')
        ..writeln('- 行为：${record.behavior.isEmpty ? '未填' : record.behavior}')
        ..writeln('- 触发：${record.trigger.isEmpty ? '未填' : record.trigger}')
        ..writeln('- 情绪：${record.emotion.isEmpty ? '未填' : record.emotion}${record.emotionIntensity == null ? '' : ' ${record.emotionIntensity}/10'}')
        ..writeln('- 结果：短期 ${record.shortTermResult.isEmpty ? '未填' : record.shortTermResult}；长期 ${record.longTermImpact.isEmpty ? '未填' : record.longTermImpact}')
        ..writeln('- 替代方案：${record.alternative.isEmpty ? '未填' : record.alternative}')
        ..writeln();
    }
    return buffer.toString();
  }
}
