import 'package:sqflite/sqflite.dart';

/// 美丽的敌人的表结构。全部 `be_` 前缀，不引用宿主任何表。
///
/// 宿主只需调用 [createAll]（幂等）；模块自己进场时也会再调一次。
class EnemySchema {
  const EnemySchema._();

  static const int schemaVersion = 1;

  static const List<String> _statements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS be_event (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      ts         INTEGER NOT NULL,
      source     TEXT    NOT NULL,
      type       TEXT    NOT NULL,
      payload    TEXT    NOT NULL DEFAULT '{}',
      dedupe_key TEXT    NOT NULL UNIQUE
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_be_event_ts ON be_event(ts)',
    'CREATE INDEX IF NOT EXISTS idx_be_event_src ON be_event(source, type, ts)',
    '''
    CREATE TABLE IF NOT EXISTS be_commitment (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      text       TEXT    NOT NULL,
      created_ms INTEGER NOT NULL,
      due_ms     INTEGER,
      status     TEXT    NOT NULL DEFAULT 'open',
      origin     TEXT    NOT NULL DEFAULT 'manual',
      verdict_id INTEGER
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_be_commitment_status ON be_commitment(status, due_ms)',
    '''
    CREATE TABLE IF NOT EXISTS be_verdict (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      ts            INTEGER NOT NULL,
      trigger       TEXT    NOT NULL,
      intensity     INTEGER NOT NULL,
      charge        TEXT    NOT NULL,
      evidence_ids  TEXT    NOT NULL DEFAULT '[]',
      lesson_hint   TEXT,
      action        TEXT    NOT NULL,
      action_due_ms INTEGER NOT NULL,
      appeal_prompt TEXT,
      user_response TEXT    NOT NULL DEFAULT 'pending',
      appeal_text   TEXT,
      outcome       TEXT    NOT NULL DEFAULT 'pending',
      outcome_ms    INTEGER,
      commitment_id INTEGER,
      fact_only     INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_be_verdict_ts ON be_verdict(ts)',
    '''
    CREATE TABLE IF NOT EXISTS be_lesson (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      verdict_id     INTEGER,
      category       TEXT    NOT NULL,
      reason_text    TEXT,
      lesson         TEXT    NOT NULL,
      created_ms     INTEGER NOT NULL,
      times_repeated INTEGER NOT NULL DEFAULT 1
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_be_lesson_cat ON be_lesson(category, created_ms)',
    '''
    CREATE TABLE IF NOT EXISTS be_setting (
      key   TEXT PRIMARY KEY,
      value TEXT
    )
    ''',
  ];

  static Future<void> createAll(Database db) async {
    for (final String sql in _statements) {
      await db.execute(sql);
    }
  }

  /// 目前只有 v1，留给以后加列用。
  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    await createAll(db);
  }
}
