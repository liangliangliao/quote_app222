import 'package:sqflite/sqflite.dart';

/// 火种模块的 DDL 与迁移。
///
/// 所有表前缀 `k_`，不含任何指向宿主表的外键，删除 `lib/kindling/` 后宿主
/// 数据库依然自洽。createAll 与 migrate 均为幂等，可在宿主的 onCreate /
/// onUpgrade 中各调一次，也可在每次 openDatabase 之后重复调用。
class KindlingSchema {
  const KindlingSchema._();

  /// 模块自管的 schema 版本，与宿主 database version 无关。
  static const int schemaVersion = 1;

  static const String _metaSchemaVersionKey = 'schema_version';

  static const List<String> _ddl = <String>[
    '''
    CREATE TABLE IF NOT EXISTS k_item (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      title        TEXT    NOT NULL,
      kind         TEXT    NOT NULL,
      note         TEXT,
      created_at   INTEGER NOT NULL,
      updated_at   INTEGER NOT NULL,
      released_at  INTEGER,
      release_note TEXT
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_k_item_live
      ON k_item(released_at, updated_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS k_probe (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id     INTEGER NOT NULL REFERENCES k_item(id) ON DELETE CASCADE,
      score       INTEGER NOT NULL CHECK(score BETWEEN 0 AND 4),
      recorded_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_k_probe_item
      ON k_probe(item_id, recorded_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS k_verdict (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id    INTEGER NOT NULL REFERENCES k_item(id) ON DELETE CASCADE,
      answer     TEXT    NOT NULL,
      decided_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_k_verdict_item
      ON k_verdict(item_id, decided_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS k_burn (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id     INTEGER NOT NULL REFERENCES k_item(id) ON DELETE CASCADE,
      started_at  INTEGER NOT NULL,
      seconds     INTEGER NOT NULL,
      want_more   INTEGER,
      aborted     INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_k_burn_item
      ON k_burn(item_id, started_at)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS k_recall (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      question_key TEXT    NOT NULL,
      raw_text     TEXT    NOT NULL,
      created_at   INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS k_resistance (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id    INTEGER REFERENCES k_item(id) ON DELETE SET NULL,
      step       INTEGER NOT NULL,
      question   TEXT    NOT NULL,
      answer     TEXT,
      created_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS k_meta (
      k TEXT PRIMARY KEY,
      v TEXT NOT NULL
    )
    ''',
  ];

  /// 建全部表与索引。幂等：重复调用不报错。
  ///
  /// 版本已经对得上时直接返回，不再写库——这个方法可能被反复调用，不该每次都
  /// 落一次写操作。
  static Future<void> createAll(DatabaseExecutor db) async {
    if (await _isCurrent(db)) return;

    for (final String statement in _ddl) {
      await db.execute(statement);
    }
    await db.insert(
      'k_meta',
      <String, Object?>{
        'k': _metaSchemaVersionKey,
        'v': schemaVersion.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 宿主升级时调用。模块按自己的 schemaVersion 自管，宿主版本号只作为
  /// 触发时机，不参与判断。幂等。
  static Future<void> migrate(
    DatabaseExecutor db,
    int hostOldVersion,
    int hostNewVersion,
  ) async {
    await createAll(db);

    final int installed = await readSchemaVersion(db);
    if (installed >= schemaVersion) return;

    // v1 是首个版本，createAll 已经到位。后续版本在这里按 installed 递进。
    await db.insert(
      'k_meta',
      <String, Object?>{
        'k': _metaSchemaVersionKey,
        'v': schemaVersion.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 表齐了而且版本对得上，才算不用再建。
  ///
  /// 这里先查 sqlite_master 而不是直接查 k_meta：onCreate 是在事务里跑的，
  /// 让一条语句报「no such table」再去接住它，不如干脆别报。
  static Future<bool> _isCurrent(DatabaseExecutor db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='k_meta'",
    );
    if (rows.isEmpty) return false;
    return await readSchemaVersion(db) == schemaVersion;
  }

  /// 已安装的模块 schema 版本；未安装返回 0。
  static Future<int> readSchemaVersion(DatabaseExecutor db) async {
    try {
      final List<Map<String, Object?>> rows = await db.query(
        'k_meta',
        columns: <String>['v'],
        where: 'k = ?',
        whereArgs: <Object?>[_metaSchemaVersionKey],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse('${rows.first['v']}') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
