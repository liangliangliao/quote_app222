import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';
import 'evidence_growth_knowledge_transform_model.dart';

/// 一条已保存的「6 步转换」记录。
class KnowledgeTransformEntry {
  const KnowledgeTransformEntry({
    this.id,
    required this.nodeId,
    required this.nodeTitle,
    required this.transform,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.sourceHash,
    required this.createdAtMs,
  });

  /// null 表示 AI 已生成成功，但写入本地失败（只在内存里）。
  final int? id;
  final String nodeId;
  final String nodeTitle;
  final KnowledgeTransform transform;
  final String provider;
  final String model;
  final String promptVersion;

  /// 生成时「大标题 + 原案例」的指纹，用来提示原卡片之后是否有更新。
  final String sourceHash;
  final int createdAtMs;

  bool get saved => id != null;

  String get timeLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// 6 步转换的本地历史。只增不改：
/// - 每次转换成功就新增一行；重新转换不会改动任何已保存的行；
/// - 数据库触发器拒绝改写已保存的内容（与预测不可改的做法一致）；
/// - 失败的转换不入库；读不出来的旧行只跳过，不删除。
class EvidenceGrowthKnowledgeTransformStore {
  EvidenceGrowthKnowledgeTransformStore(this.dao);
  final EvidenceGrowthDao dao;

  static const String table = 'evidence_growth_knowledge_transforms';

  Future<void>? _ready;

  Future<Database> _db() async {
    await dao.ensureTables();
    final db = await dao.knowledgeDatabase();
    try {
      await (_ready ??= _createTable(db));
    } catch (_) {
      _ready = null;
      rethrow;
    }
    return db;
  }

  static Future<void> _createTable(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS $table (
      transform_id INTEGER PRIMARY KEY AUTOINCREMENT,
      node_id TEXT NOT NULL, node_title TEXT NOT NULL DEFAULT '',
      body_json TEXT NOT NULL, provider TEXT NOT NULL DEFAULT '',
      model TEXT NOT NULL DEFAULT '', prompt_version TEXT NOT NULL DEFAULT '',
      source_hash TEXT NOT NULL DEFAULT '', created_at_ms INTEGER NOT NULL)''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_eg_transforms_node ON $table(node_id, created_at_ms DESC)');
    await db.execute('''CREATE TRIGGER IF NOT EXISTS eg_transform_history_immutable
      BEFORE UPDATE OF node_id, body_json, created_at_ms ON $table
      BEGIN SELECT RAISE(ABORT, 'Saved transform history is immutable'); END''');
  }

  /// 追加一条新记录并返回带 id 的条目。
  Future<KnowledgeTransformEntry> save({
    required String nodeId,
    required String nodeTitle,
    required KnowledgeTransform transform,
    required String provider,
    required String model,
    required String promptVersion,
    required String sourceHash,
  }) async {
    final db = await _db();
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(table, {
      'node_id': nodeId,
      'node_title': nodeTitle,
      'body_json': jsonEncode(transform.toJson()),
      'provider': provider,
      'model': model,
      'prompt_version': promptVersion,
      'source_hash': sourceHash,
      'created_at_ms': createdAtMs,
    });
    return KnowledgeTransformEntry(
      id: id,
      nodeId: nodeId,
      nodeTitle: nodeTitle,
      transform: transform,
      provider: provider,
      model: model,
      promptVersion: promptVersion,
      sourceHash: sourceHash,
      createdAtMs: createdAtMs,
    );
  }

  /// 某张卡片的全部历史，最新的在前。
  Future<List<KnowledgeTransformEntry>> list(String nodeId) async {
    final db = await _db();
    final rows = await db.query(table,
        where: 'node_id=?',
        whereArgs: [nodeId],
        orderBy: 'created_at_ms DESC, transform_id DESC');
    final entries = <KnowledgeTransformEntry>[];
    for (final row in rows) {
      final entry = _fromRow(row);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  static KnowledgeTransformEntry? _fromRow(Map<String, Object?> row) {
    try {
      return KnowledgeTransformEntry(
        id: row['transform_id'] as int,
        nodeId: '${row['node_id']}',
        nodeTitle: '${row['node_title'] ?? ''}',
        transform: KnowledgeTransform.fromJson(
            growthMap(jsonDecode(row['body_json'] as String))),
        provider: '${row['provider'] ?? ''}',
        model: '${row['model'] ?? ''}',
        promptVersion: '${row['prompt_version'] ?? ''}',
        sourceHash: '${row['source_hash'] ?? ''}',
        createdAtMs: row['created_at_ms'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
