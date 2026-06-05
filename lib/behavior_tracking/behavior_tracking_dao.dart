import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'behavior_tracking_analytics.dart';
import 'behavior_tracking_models.dart';

class BehaviorTrackingDao {
  static const String tableName = 'behavior_tracking_records';
  static const String templateTableName = 'behavior_tracking_templates';

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
        deleted_at_ms INTEGER,
        record_date_ms INTEGER NOT NULL,
        mode TEXT,
        template_key TEXT,
        entry_mode TEXT,
        primary_layer TEXT,
        category TEXT,
        title TEXT,
        source TEXT,
        sensitivity_level TEXT,
        start_minute INTEGER,
        end_minute INTEGER,
        behavior TEXT,
        planned_value REAL,
        actual_value REAL,
        unit TEXT,
        completion_state TEXT,
        reason TEXT,
        outcome TEXT,
        emotion TEXT,
        emotion_intensity INTEGER,
        valence_score INTEGER,
        arousal_score INTEGER,
        perceived_control INTEGER,
        trigger_text TEXT,
        cognition TEXT,
        reaction TEXT,
        environment TEXT,
        location_type TEXT,
        people_context TEXT,
        cue_tags TEXT,
        body_state TEXT,
        sleep_duration_min INTEGER,
        sleep_quality INTEGER,
        energy_morning INTEGER,
        steps INTEGER,
        exercise_min INTEGER,
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
    await _ensureRecordColumns(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $templateTableName (
        template_key TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        purpose TEXT,
        default_entry_mode TEXT,
        schema_json TEXT,
        is_default INTEGER NOT NULL DEFAULT 1,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await _seedDefaultTemplates(db);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_date ON $tableName(record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_category ON $tableName(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_template_date ON $tableName(template_key, record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_layer_date ON $tableName(primary_layer, record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_updated ON $tableName(updated_at_ms DESC)');
  }

  Future<void> _ensureRecordColumns(Database db) async {
    final existingRows = await db.rawQuery('PRAGMA table_info($tableName)');
    final existing = existingRows.map((row) => row['name']?.toString()).whereType<String>().toSet();
    final additions = <String, String>{
      'deleted_at_ms': 'INTEGER',
      'template_key': 'TEXT',
      'entry_mode': 'TEXT',
      'source': 'TEXT',
      'sensitivity_level': 'TEXT',
      'planned_value': 'REAL',
      'actual_value': 'REAL',
      'unit': 'TEXT',
      'completion_state': 'TEXT',
      'valence_score': 'INTEGER',
      'arousal_score': 'INTEGER',
      'perceived_control': 'INTEGER',
      'location_type': 'TEXT',
      'people_context': 'TEXT',
      'cue_tags': 'TEXT',
      'sleep_duration_min': 'INTEGER',
      'sleep_quality': 'INTEGER',
      'energy_morning': 'INTEGER',
      'steps': 'INTEGER',
      'exercise_min': 'INTEGER',
    };
    for (final entry in additions.entries) {
      if (!existing.contains(entry.key)) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }

  Future<void> _seedDefaultTemplates(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final template in behaviorTrackingTemplates) {
      await db.insert(
        templateTableName,
        {
          'template_key': template.key,
          'name': template.name,
          'purpose': template.purpose,
          'default_entry_mode': template.defaultEntryMode,
          'schema_json': jsonEncode({
            'field_keys': template.fieldKeys,
            'completion_rules': template.completionRules,
            'local_first': true,
          }),
          'is_default': template.isDefault ? 1 : 0,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int> save(BehaviorTrackingRecord record) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalized = record.copyWith(
      updatedAtMs: now,
      createdAtMs: record.id == null ? now : record.createdAtMs,
      templateKey: record.templateKey.isEmpty ? BehaviorTrackingTemplate.templateKeyForMode(record.mode) : record.templateKey,
      entryMode: record.entryMode.isEmpty ? record.mode : record.entryMode,
      source: record.source.isEmpty ? 'manual' : record.source,
      sensitivityLevel: record.sensitivityLevel.isEmpty ? 'normal' : record.sensitivityLevel,
    );
    final data = normalized.toMap();
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
    await db.update(tableName, {'deleted_at_ms': now, 'updated_at_ms': now}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> purgeDeleted({Duration olderThan = const Duration(days: 30)}) async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
    await db.delete(tableName, where: 'deleted_at_ms IS NOT NULL AND deleted_at_ms < ?', whereArgs: [cutoff]);
  }

  Future<List<BehaviorTrackingRecord>> recent({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query(tableName, where: 'deleted_at_ms IS NULL', orderBy: 'record_date_ms DESC, id DESC', limit: limit);
    return rows.map(BehaviorTrackingRecord.fromMap).toList();
  }

  Future<List<BehaviorTrackingRecord>> between(DateTime startInclusive, DateTime endExclusive) async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: 'deleted_at_ms IS NULL AND record_date_ms >= ? AND record_date_ms < ?',
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

  Future<BehaviorStatsOverview> statsOverview({int days = 30}) async {
    final records = await _recordsForExport(days);
    return BehaviorStatsOverview.fromRecords(records, rangeDays: days);
  }

  Future<String> exportJson({int days = 90}) async {
    final records = await _recordsForExport(days);
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'privacy': {'local_first': true, 'cloud_sync': 'optional', 'precise_location_default': 'off', 'delete_mode': 'soft_delete_tombstone'},
      'templates': behaviorTrackingTemplates
          .map((template) => {
                'template_key': template.key,
                'name': template.name,
                'field_keys': template.fieldKeys,
                'completion_rules': template.completionRules,
              })
          .toList(),
      'records': records.map((record) => record.toMap()).toList(),
    });
  }

  Future<String> exportCsv({int days = 90}) async {
    final records = await _recordsForExport(days);
    final header = [
      'record_date',
      'template_key',
      'entry_mode',
      'primary_layer',
      'category',
      'title',
      'start_minute',
      'end_minute',
      'duration_min',
      'behavior',
      'emotion',
      'emotion_intensity',
      'trigger',
      'short_term_result',
      'long_term_impact',
      'alternative',
      'source',
      'sensitivity_level',
      'tags',
    ];
    String esc(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final lines = <String>[header.map(esc).join(',')];
    for (final r in records) {
      lines.add([
        DateFormat('yyyy-MM-dd').format(r.recordDate),
        r.templateKey,
        r.entryMode,
        r.primaryLayer,
        r.category,
        r.title,
        r.startMinute,
        r.endMinute,
        r.durationMinutes,
        r.behavior,
        r.emotion,
        r.emotionIntensity,
        r.trigger,
        r.shortTermResult,
        r.longTermImpact,
        r.alternative,
        r.source,
        r.sensitivityLevel,
        r.tags.join('|'),
      ].map(esc).join(','));
    }
    return lines.join('\n');
  }

  Future<String> exportMarkdown({int days = 90}) async {
    final records = await _recordsForExport(days);
    final buffer = StringBuffer()
      ..writeln('# 行为跟踪导出')
      ..writeln()
      ..writeln('- 导出时间：${DateTime.now().toIso8601String()}')
      ..writeln('- 范围：近 $days 天')
      ..writeln('- 说明：本导出来自本地优先记录，敏感字段请自行妥善保存。')
      ..writeln();
    for (final r in records) {
      buffer
        ..writeln('## ${DateFormat('yyyy-MM-dd').format(r.recordDate)} ${r.title.isEmpty ? r.primaryLayer : r.title}')
        ..writeln()
        ..writeln('- 模板：${r.templateKey} / ${r.entryMode}')
        ..writeln('- 类别：${r.category.isEmpty ? '未分类' : r.category}')
        ..writeln('- 时间：${r.timeRangeLabel.isEmpty ? '未填' : r.timeRangeLabel}（${r.durationMinutes ?? 0} 分钟）')
        ..writeln('- 行为：${r.behavior.isEmpty ? '未填' : r.behavior}')
        ..writeln('- 触发：${r.trigger.isEmpty ? '未填' : r.trigger}')
        ..writeln('- 情绪：${r.emotion.isEmpty ? '未填' : r.emotion}${r.emotionIntensity == null ? '' : ' ${r.emotionIntensity}/10'}')
        ..writeln('- 短期/长期：${r.shortTermResult.isEmpty ? '未填' : r.shortTermResult} / ${r.longTermImpact.isEmpty ? '未填' : r.longTermImpact}')
        ..writeln('- 替代方案：${r.alternative.isEmpty ? '未填' : r.alternative}')
        ..writeln('- 标签：${r.tags.isEmpty ? '无' : r.tags.join('、')}')
        ..writeln();
    }
    return buffer.toString();
  }

  Future<List<BehaviorTrackingRecord>> _recordsForExport(int days) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: days));
    return between(start, end);
  }
}
