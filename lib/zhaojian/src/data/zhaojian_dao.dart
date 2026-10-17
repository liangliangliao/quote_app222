import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// 照见模块的读写。只碰 `z_` 前缀的表。
class ZhaojianDao {
  ZhaojianDao(this.db);

  final Database db;

  // ---- 决策 ----

  Future<int> insertDecision(ZDecision d) async {
    final Map<String, Object?> row = d.toRow()..remove('id');
    return db.insert('z_decision', row);
  }

  Future<void> updateDecision(ZDecision d) async {
    if (d.id == null) return;
    final Map<String, Object?> row = d.toRow()..remove('id');
    await db.update('z_decision', row,
        where: 'id = ?', whereArgs: <Object?>[d.id]);
  }

  Future<List<ZDecision>> allDecisions() async {
    final List<Map<String, Object?>> rows =
        await db.query('z_decision', orderBy: 'sealed_at ASC, id ASC');
    return rows.map(ZDecision.fromRow).toList();
  }

  Future<List<ZDecision>> pendingDecisions() async {
    final List<Map<String, Object?>> rows = await db.query(
      'z_decision',
      where: 'actual IS NULL',
      orderBy: 'sealed_at DESC, id DESC',
    );
    return rows.map(ZDecision.fromRow).toList();
  }

  Future<List<ZDecision>> revealedDecisions() async {
    final List<Map<String, Object?>> rows = await db.query(
      'z_decision',
      where: 'actual IS NOT NULL',
      orderBy: 'actual_at ASC, id ASC',
    );
    return rows.map(ZDecision.fromRow).toList();
  }

  Future<ZDecision?> findDecision(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'z_decision',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ZDecision.fromRow(rows.first);
  }

  Future<void> deleteDecision(int id) async {
    await db.delete('z_decision', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ---- 随手记 ----

  Future<int> insertLog(ZLog l) async {
    final Map<String, Object?> row = l.toRow()..remove('id');
    return db.insert('z_log', row);
  }

  Future<List<ZLog>> allLogs() async {
    final List<Map<String, Object?>> rows =
        await db.query('z_log', orderBy: 'created_at ASC, id ASC');
    return rows.map(ZLog.fromRow).toList();
  }

  Future<void> deleteLog(int id) async {
    await db.delete('z_log', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ---- 主线假设 ----

  Future<int> insertHypothesis(ZHypothesis h) async {
    final Map<String, Object?> row = h.toRow()..remove('id');
    return db.insert('z_hyp', row);
  }

  Future<void> updateHypothesis(ZHypothesis h) async {
    if (h.id == null) return;
    final Map<String, Object?> row = h.toRow()..remove('id');
    await db.update('z_hyp', row, where: 'id = ?', whereArgs: <Object?>[h.id]);
  }

  Future<List<ZHypothesis>> allHypotheses() async {
    final List<Map<String, Object?>> rows =
        await db.query('z_hyp', orderBy: 'created_at ASC, id ASC');
    return rows.map(ZHypothesis.fromRow).toList();
  }

  Future<ZHypothesis?> findHypothesis(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'z_hyp',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ZHypothesis.fromRow(rows.first);
  }

  Future<void> deleteHypothesis(int id) async {
    await db.delete('z_hyp', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ---- 通用条目 ----

  Future<int> insertItem(ZEntry it) async {
    final Map<String, Object?> row = it.toRow()..remove('id');
    return db.insert('z_item', row);
  }

  Future<void> updateItem(ZEntry it) async {
    if (it.id == null) return;
    final Map<String, Object?> row = it.toRow()..remove('id');
    await db.update('z_item', row, where: 'id = ?', whereArgs: <Object?>[it.id]);
  }

  Future<void> deleteItem(int id) async {
    await db.delete('z_item', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<ZEntry>> allItems() async {
    final List<Map<String, Object?>> rows =
        await db.query('z_item', orderBy: 'created_at ASC, id ASC');
    return rows.map(ZEntry.fromRow).toList();
  }

  // ---- 键值（放在 z_meta，键名加 kv: 前缀） ----

  Future<Map<String, String>> allKv() async {
    final List<Map<String, Object?>> rows = await db.query(
      'z_meta',
      where: 'key LIKE ?',
      whereArgs: <Object?>['kv:%'],
    );
    return <String, String>{
      for (final Map<String, Object?> r in rows)
        (r['key'] ?? '').toString().substring(3): (r['value'] ?? '').toString(),
    };
  }

  Future<void> setKv(String key, String value) async {
    await db.insert(
      'z_meta',
      <String, Object?>{'key': 'kv:$key', 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- 备份恢复 ----

  /// 用备份整体替换全部数据，一个事务：中途出错则全部回滚，原数据不变。
  /// 行里不属于当前表结构的列会被丢掉，所以旧版本的备份也能导入。
  Future<void> replaceAll({
    required List<Map<String, Object?>> decisions,
    required List<Map<String, Object?>> logs,
    required List<Map<String, Object?>> hyps,
    required List<Map<String, Object?>> misses,
    required List<Map<String, Object?>> items,
    required Map<String, String> kv,
  }) async {
    await db.transaction((Transaction txn) async {
      for (final String t in const <String>['z_decision', 'z_log', 'z_hyp', 'z_miss', 'z_item']) {
        await txn.delete(t);
      }
      await txn.delete('z_meta', where: 'key LIKE ?', whereArgs: <Object?>['kv:%']);
      Future<void> put(String table, List<Map<String, Object?>> rows) async {
        final List<Map<String, Object?>> info = await txn.rawQuery('PRAGMA table_info($table)');
        final Set<String> cols = info.map((Map<String, Object?> r) => '${r['name']}').toSet();
        for (final Map<String, Object?> r in rows) {
          await txn.insert(table, <String, Object?>{
            for (final MapEntry<String, Object?> e in r.entries)
              if (cols.contains(e.key)) e.key: e.value,
          });
        }
      }

      await put('z_decision', decisions);
      await put('z_log', logs);
      await put('z_hyp', hyps);
      await put('z_miss', misses);
      await put('z_item', items);
      for (final MapEntry<String, String> e in kv.entries) {
        await txn.insert(
          'z_meta',
          <String, Object?>{'key': 'kv:${e.key}', 'value': e.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ---- 漏掉的动机 ----

  Future<int> insertMiss(ZMiss m) async {
    final Map<String, Object?> row = m.toRow()..remove('id');
    return db.insert('z_miss', row);
  }

  Future<List<ZMiss>> allMisses() async {
    final List<Map<String, Object?>> rows =
        await db.query('z_miss', orderBy: 'created_at ASC, id ASC');
    return rows.map(ZMiss.fromRow).toList();
  }
}
