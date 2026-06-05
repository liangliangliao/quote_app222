import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';

class DLog {
  static bool _checkedSchema = false;

  static Future<void> _ensureLogsSchema(Database db) async {
    if (_checkedSchema) return;
    try {
      // 1) Ensure table exists (idempotent)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          log_uid TEXT UNIQUE,
          task_uid TEXT,
          detail TEXT,
          created_at INTEGER,
          task_name_snapshot TEXT,
          task_start_time_snapshot TEXT
        )
      ''');

      // 2) Backwards-compat: add missing columns when upgrading from old schemas.
      final cols = await db.rawQuery('PRAGMA table_info(logs)');
      final names = <String>{
        for (final r in cols)
          if (r['name'] != null) (r['name'] as String),
      };

      Future<void> addCol(String name, String typeSql) async {
        if (names.contains(name)) return;
        await db.execute('ALTER TABLE logs ADD COLUMN $name $typeSql');
        names.add(name);
      }

      // Common columns across versions
      await addCol('detail', 'TEXT');
      await addCol('created_at', 'INTEGER');
      await addCol('task_uid', 'TEXT');
      await addCol('log_uid', 'TEXT');
      await addCol('task_name_snapshot', 'TEXT');
      await addCol('task_start_time_snapshot', 'TEXT');

      // If legacy columns exist, migrate snapshots for better UI.
      if (names.contains('task_name') && names.contains('task_name_snapshot')) {
        try {
          await db.execute(
            'UPDATE logs SET task_name_snapshot = task_name WHERE task_name_snapshot IS NULL AND task_name IS NOT NULL',
          );
        } catch (_) {}
      }
      if (names.contains('task_start_time') && names.contains('task_start_time_snapshot')) {
        try {
          await db.execute(
            'UPDATE logs SET task_start_time_snapshot = task_start_time WHERE task_start_time_snapshot IS NULL AND task_start_time IS NOT NULL',
          );
        } catch (_) {}
      }

      _checkedSchema = true;
    } catch (_) {
      // Don't block app flow due to logging schema issues.
    }
  }

  static Future<void> _insertLine(String tag, String line) async {
    try {
      final db = await AppDatabase.instance();
      await _ensureLogsSchema(db);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final nowStr = DateTime.now().toString();
      // Prefer new schema (snapshots) so LogsPage shows a left title/time.
      try {
        await db.insert(
          'logs',
          {
            'created_at': nowMs,
            'task_uid': '_SYS_',
            'detail': line,
            'task_name_snapshot': tag,
            'task_start_time_snapshot': nowStr,
            'log_uid': '$nowMs:$tag',
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        return;
      } catch (_) {}

      // Fallback for very old schema
      await db.insert(
        'logs',
        {
          'task_name': tag,
          'task_start_time': nowStr,
          'detail': line,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {}
  }

  static Future<void> i(String tag, String msg) async {
    final now = DateTime.now().toIso8601String();
    final line = "【信息】[$now][$tag] $msg";
    // ignore: avoid_print
    print(line);
    await _insertLine(tag, line);
  }

  static Future<void> w(String tag, String msg) async {
    final now = DateTime.now().toIso8601String();
    final line = "【警告】[$now][$tag] $msg";
    // ignore: avoid_print
    print(line);
    await _insertLine(tag, line);
  }

  static Future<void> e(String tag, String msg) async {
    final now = DateTime.now().toIso8601String();
    final line = "【错误】[$now][$tag] $msg";
    // ignore: avoid_print
    print(line);
    await _insertLine(tag, line);
  }
}