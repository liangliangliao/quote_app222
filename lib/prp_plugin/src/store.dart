import 'package:sqflite/sqflite.dart';

import 'models.dart';

class PrpSchema {
  const PrpSchema._();
  static const statements = <String>[
    '''CREATE TABLE IF NOT EXISTS prp_lesson (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_key TEXT NOT NULL, category TEXT NOT NULL DEFAULT '其他',
      source TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'draft',
      worked TEXT NOT NULL DEFAULT '[]', failed TEXT NOT NULL DEFAULT '[]',
      trigger_text TEXT, early_signal TEXT, if_cue TEXT, then_action TEXT,
      evidence_refs TEXT NOT NULL DEFAULT '[]', sentences_json TEXT NOT NULL DEFAULT '[]',
      quality INTEGER NOT NULL DEFAULT 0, created_ms INTEGER NOT NULL,
      sealed_ms INTEGER, parent_id INTEGER,
      verified_cnt INTEGER NOT NULL DEFAULT 0, repeated_cnt INTEGER NOT NULL DEFAULT 0,
      quote_allowed INTEGER NOT NULL DEFAULT 0, voice_path TEXT NOT NULL DEFAULT ''
    )''',
    '''CREATE TABLE IF NOT EXISTS prp_session (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      surface TEXT NOT NULL, trigger_kind TEXT NOT NULL, trigger_ref TEXT NOT NULL,
      subject_key TEXT NOT NULL, expected TEXT NOT NULL, started_ms INTEGER NOT NULL,
      pause_sec INTEGER NOT NULL DEFAULT 0, pause_skipped INTEGER NOT NULL DEFAULT 0,
      emotion_before INTEGER, emotion_after INTEGER,
      step TEXT NOT NULL DEFAULT 'pause', lesson_id INTEGER, ended_ms INTEGER,
      outcome TEXT NOT NULL DEFAULT 'open',
      counts_offer INTEGER NOT NULL DEFAULT 1,
      UNIQUE(surface, trigger_kind, trigger_ref)
    )''',
    '''CREATE TABLE IF NOT EXISTS prp_recall (
      id INTEGER PRIMARY KEY AUTOINCREMENT, lesson_id INTEGER NOT NULL,
      ts INTEGER NOT NULL, surface TEXT NOT NULL, subject_key TEXT,
      context TEXT NOT NULL, ref TEXT,
      outcome TEXT NOT NULL DEFAULT 'pending', outcome_ms INTEGER,
      FOREIGN KEY(lesson_id) REFERENCES prp_lesson(id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE IF NOT EXISTS prp_forecast (
      id INTEGER PRIMARY KEY AUTOINCREMENT, subject_key TEXT NOT NULL,
      label TEXT NOT NULL, created_ms INTEGER NOT NULL,
      pred_intensity INTEGER NOT NULL CHECK(pred_intensity BETWEEN 0 AND 10),
      pred_days REAL NOT NULL CHECK(pred_days >= 0 AND pred_days <= 365),
      actual_intensity INTEGER CHECK(actual_intensity BETWEEN 0 AND 10),
      actual_days REAL CHECK(actual_days >= 0 AND actual_days <= 365),
      closed_ms INTEGER
    )''',
    '''CREATE TABLE IF NOT EXISTS prp_event (
      id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
      recall_id INTEGER NOT NULL, created_ms INTEGER NOT NULL,
      UNIQUE(kind, recall_id),
      FOREIGN KEY(recall_id) REFERENCES prp_recall(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_prp_lesson_state ON prp_lesson(state, sealed_ms)',
    'CREATE INDEX IF NOT EXISTS idx_prp_lesson_subj ON prp_lesson(subject_key, state)',
    'CREATE INDEX IF NOT EXISTS idx_prp_recall_lesson ON prp_recall(lesson_id, ts)',
    'CREATE INDEX IF NOT EXISTS idx_prp_recall_ts ON prp_recall(ts)',
  ];

  static Future<void> createAll(DatabaseExecutor db) async {
    for (final sql in statements) {
      await db.execute(sql);
    }
  }
}

/// Lazy, additive schema. Read-only management while off does not create tables.
class PrpStore {
  PrpStore(this.openDatabase);
  final Future<Database> Function() openDatabase;
  static const ownedTables = [
    'prp_event',
    'prp_forecast',
    'prp_recall',
    'prp_session',
    'prp_lesson',
  ];
  Future<bool> tableExists(DatabaseExecutor db, String name) async =>
      (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
              [name]))
          .isNotEmpty;
  Future<bool> exists(DatabaseExecutor db) async => (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='prp_lesson'",
      ))
          .isNotEmpty;

  Future<List<PrpLesson>> lessons({bool sealedOnly = false}) async {
    final db = await openDatabase();
    if (!await exists(db)) return const [];
    final rows = await db.query(
      'prp_lesson',
      where: sealedOnly ? "state = 'sealed'" : null,
      orderBy:
          "CASE state WHEN 'draft' THEN 0 WHEN 'sealed' THEN 1 ELSE 2 END, created_ms DESC, id DESC",
    );
    return rows.map(PrpLesson.fromMap).toList();
  }

  Future<PrpLesson?> lesson(int id) async {
    final db = await openDatabase();
    if (!await exists(db)) return null;
    final rows = await db.query('prp_lesson', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : PrpLesson.fromMap(rows.first);
  }
}
