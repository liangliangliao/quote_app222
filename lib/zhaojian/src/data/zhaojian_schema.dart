import 'package:sqflite/sqflite.dart';

/// 照见模块的 DDL 与迁移。
///
/// 所有表前缀 `z_`，不含任何指向宿主表的外键，删除 `lib/zhaojian/` 后宿主
/// 数据库依然自洽。createAll 与 migrate 均为幂等，可在宿主的 onCreate /
/// onUpgrade 中各调一次，也可在每次 openDatabase 之后重复调用。
class ZhaojianSchema {
  const ZhaojianSchema._();

  /// 模块自管的 schema 版本，与宿主 database version 无关。
  static const int schemaVersion = 3;

  static const String _metaKey = 'schema_version';

  static const List<String> _ddl = <String>[
    '''
    CREATE TABLE IF NOT EXISTS z_meta (
      key   TEXT PRIMARY KEY,
      value TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS z_decision (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      question        TEXT    NOT NULL,
      option_a        TEXT    NOT NULL,
      option_b        TEXT    NOT NULL,
      importance      TEXT,
      motives_json    TEXT,
      pred            TEXT    NOT NULL,
      stake           INTEGER NOT NULL,
      felt_freedom    INTEGER,
      condition_text  TEXT,
      jt_pred         INTEGER,
      conflict_type   INTEGER,
      sealed_at       INTEGER NOT NULL,
      actual          TEXT,
      actual_at       INTEGER,
      reaction        TEXT,
      body_json       TEXT,
      jt_actual       INTEGER,
      hyp_id          INTEGER,
      hyp_kind        TEXT,
      miss_logged     INTEGER NOT NULL DEFAULT 0,
      notes_json      TEXT,
      imagery_depth   REAL,
      imagery_sym     REAL,
      align_json      TEXT
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_z_decision_actual
      ON z_decision(actual, sealed_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS z_log (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      what        TEXT    NOT NULL,
      reaction    TEXT,
      deliberate  TEXT,
      typical     TEXT,
      body_json   TEXT,
      hyp_id      INTEGER,
      hyp_kind    TEXT,
      created_at  INTEGER NOT NULL
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_z_log_created
      ON z_log(created_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS z_hyp (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      text        TEXT    NOT NULL,
      test        TEXT,
      sup_json    TEXT,
      ref_json    TEXT,
      status      INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS z_item (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      kind        TEXT    NOT NULL,
      data_json   TEXT    NOT NULL,
      created_at  INTEGER NOT NULL,
      updated_at  INTEGER NOT NULL
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_z_item_kind
      ON z_item(kind, created_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS z_miss (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      cat          INTEGER NOT NULL,
      text         TEXT,
      decision_id  INTEGER,
      created_at   INTEGER NOT NULL
    )
    ''',
  ];

  /// 所有表名，测试和卸载用。
  static const List<String> tables = <String>[
    'z_meta',
    'z_decision',
    'z_log',
    'z_hyp',
    'z_miss',
    'z_item',
  ];

  static Future<void> createAll(Database db) async {
    for (final String sql in _ddl) {
      await db.execute(sql);
    }
    await db.insert(
      'z_meta',
      <String, Object?>{'key': _metaKey, 'value': '$schemaVersion'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 迁移幂等：先补建缺失的表，再按模块自己记录的版本补列。
  /// v2：z_decision 新增 align_json（一致度与难度）。
  /// v3：新增通用条目表 z_item（绳子、小墙、计划等十几类条目共用，按 kind 区分）。
  static Future<void> migrate(Database db, int oldV, int newV) async {
    await createAll(db);
    final int stored = await storedVersion(db);
    if (stored < 2 && !await _hasColumn(db, 'z_decision', 'align_json')) {
      await db.execute('ALTER TABLE z_decision ADD COLUMN align_json TEXT');
    }
    await db.update(
      'z_meta',
      <String, Object?>{'value': '$schemaVersion'},
      where: 'key = ?',
      whereArgs: <Object?>[_metaKey],
    );
  }

  static Future<bool> _hasColumn(Database db, String table, String column) async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((Map<String, Object?> r) => r['name'] == column);
  }

  static Future<int> storedVersion(Database db) async {
    final List<Map<String, Object?>> rows = await db.query(
      'z_meta',
      where: 'key = ?',
      whereArgs: <Object?>[_metaKey],
    );
    if (rows.isEmpty) return 0;
    return int.tryParse((rows.first['value'] ?? '').toString()) ?? 0;
  }
}
