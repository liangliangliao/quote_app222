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
