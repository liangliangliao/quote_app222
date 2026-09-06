import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'evidence_growth_knowledge.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_operator_registry.dart';
import 'evidence_growth_search.dart';

/// Public, versioned knowledge cache. Installs are atomic; personal Trial source
/// snapshots live in separate tables and are never rewritten by a KB upgrade.
class EvidenceGrowthKbStore {
  EvidenceGrowthKbStore(this.database);
  final Future<Database> Function() database;
  Future<void> initialize() async {
    final db = await database();
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_kb_manifests (
      version TEXT PRIMARY KEY, digest TEXT NOT NULL, payload TEXT NOT NULL,
      installed_at_ms INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS evidence_growth_kb_nodes (
      node_id TEXT PRIMARY KEY, version INTEGER NOT NULL, module TEXT NOT NULL,
      source_class TEXT NOT NULL, payload TEXT NOT NULL)''');
    await db.execute('''CREATE VIRTUAL TABLE IF NOT EXISTS evidence_growth_kb_fts
      USING fts4(node_id, terms)''');
    final current = await db.query('evidence_growth_kb_manifests',where:'active = 1',limit:1);
    if (current.isEmpty) {
      await install(manifest(EvidenceGrowthKnowledge.bundledVersion,EvidenceGrowthKnowledge.bundledNodes));
    } else {
      final payload = Map<String,dynamic>.from(jsonDecode(current.first['payload'] as String) as Map);
      final nodes = validate(payload);
      EvidenceGrowthKnowledge.activate(payload['version'] as String,nodes);
    }
  }

  static Map<String,Object?> manifest(String version,List<EvidenceKNode> nodes) {
    final data = nodes.map((n)=>n.toJson()).toList();
    return {'schema':1,'version':version,'nodes':data,
      'sha256':sha256.convert(utf8.encode(jsonEncode(data))).toString()};
  }

  static List<EvidenceKNode> validate(Map<String,dynamic> manifest) {
    final version = manifest['version'];
    if (manifest['schema'] != 1 || version is! String || !RegExp(r'^[a-zA-Z0-9.-]{1,50}$').hasMatch(version)) {
      throw const FormatException('无效知识库 manifest');
    }
    final records = manifest['nodes'];
    if (records is! List || records.length < 60 || records.length > 10000 ||
        sha256.convert(utf8.encode(jsonEncode(records))).toString() != manifest['sha256']) {
      throw const FormatException('知识库内容摘要不匹配');
    }
    final nodes = records.map((e)=>EvidenceKNode.fromJson(Map<String,dynamic>.from(e as Map))).toList();
    final ids = nodes.map((n)=>n.id).toSet();
    if (ids.length != nodes.length || !EvidenceGrowthKnowledge.bundledNodes.every((n)=>ids.contains(n.id))) {
      throw const FormatException('知识库缺少运行时所需稳定节点或存在重复 ID');
    }
    for (final node in nodes) {
      if (node.version < 1 || node.claim.trim().isEmpty || node.title.trim().isEmpty ||
          !const {'K_TAL','K_EXT1','K_EXT2'}.contains(node.sourceClass) ||
          node.locator.document != 'KB35' || node.locator.pages.isEmpty ||
          node.locator.pages.any((p)=>p<1 || p>195) || node.locator.originalNodeIds.isEmpty ||
          node.howTo.isEmpty || node.boundaries.isEmpty || node.triggers.isEmpty ||
          node.operators.isEmpty || node.operators.any((op)=>EvidenceGrowthOperatorRegistry.maybeById(op)==null) ||
          node.nextNodes.any((id)=>!ids.contains(id))) {
        throw FormatException('节点证据或运行规则不完整：${node.id}');
      }
    }
    return nodes;
  }

  Future<void> install(Map<String,dynamic> manifest) async {
    final nodes = validate(manifest);
    final db = await database();
    final version = manifest['version'] as String;
    await db.transaction((txn) async {
      final existing = await txn.query('evidence_growth_kb_manifests',where:'version = ?',whereArgs:[version]);
      if (existing.isNotEmpty && existing.first['digest'] != manifest['sha256']) {
        throw const FormatException('不能以同一版本替换不同知识内容');
      }
      final oldNodes = {for (final row in await txn.query('evidence_growth_kb_nodes')) row['node_id'] as String:row};
      for (final node in nodes) {
        final old = oldNodes[node.id];
        if (old != null && (node.version < (old['version'] as num) ||
            (node.version == old['version'] && jsonEncode(node.toJson()) != old['payload']))) {
          throw FormatException('修改知识必须递增节点版本：${node.id}');
        }
      }
      await txn.update('evidence_growth_kb_manifests',{'active':0});
      await txn.insert('evidence_growth_kb_manifests',{'version':version,'digest':manifest['sha256'],
        'payload':jsonEncode(manifest),'installed_at_ms':DateTime.now().millisecondsSinceEpoch,'active':1},
        conflictAlgorithm:ConflictAlgorithm.replace);
      await _replaceIndex(txn,nodes);
    });
    EvidenceGrowthKnowledge.activate(version,nodes);
  }

  Future<void> installDelta(Map<String,dynamic> delta) async {
    if (delta['base_version'] != EvidenceGrowthKnowledge.kbVersion) throw StateError('增量基线不匹配');
    final nodes = {for(final node in EvidenceGrowthKnowledge.nodes) node.id:node};
    for (final id in delta['removed_ids'] as List? ?? []) { nodes.remove(id); }
    for (final record in delta['upserts'] as List? ?? []) {
      final node=EvidenceKNode.fromJson(Map<String,dynamic>.from(record as Map)); nodes[node.id]=node;
    }
    final candidate=manifest(delta['version'] as String,nodes.values.toList());
    if (candidate['sha256'] != delta['sha256']) throw const FormatException('增量摘要不匹配');
    await install(candidate);
  }

  Future<bool> rollback() async {
    final db=await database();
    final rows=await db.query('evidence_growth_kb_manifests',where:'active = 0',orderBy:'installed_at_ms DESC',limit:1);
    if(rows.isEmpty) return false;
    final payload=Map<String,dynamic>.from(jsonDecode(rows.first['payload'] as String) as Map);
    final nodes=validate(payload);
    await db.transaction((txn) async {
      await txn.update('evidence_growth_kb_manifests',{'active':0});
      await txn.update('evidence_growth_kb_manifests',{'active':1},where:'version = ?',whereArgs:[payload['version']]);
      await _replaceIndex(txn,nodes);
    });
    EvidenceGrowthKnowledge.activate(payload['version'] as String,nodes);
    return true;
  }

  Future<void> _replaceIndex(DatabaseExecutor db,List<EvidenceKNode> nodes) async {
    await db.delete('evidence_growth_kb_nodes'); await db.delete('evidence_growth_kb_fts');
    for(final node in nodes) {
      await db.insert('evidence_growth_kb_nodes',{'node_id':node.id,'version':node.version,
        'module':node.module.key,'source_class':node.sourceClass,'payload':jsonEncode(node.toJson())});
      await db.insert('evidence_growth_kb_fts',{'node_id':node.id,'terms':EvidenceGrowthSearch.tokenize('${node.id} ${node.embeddingText}').join(' ')});
    }
  }

  Future<List<String>> exactSearch(String query) async {
    final terms=EvidenceGrowthSearch.tokenize(query).toSet().take(20).toList();
    if(terms.isEmpty) return [];
    final rows=await (await database()).rawQuery(
      'SELECT node_id FROM evidence_growth_kb_fts WHERE terms MATCH ? LIMIT 30',
      [terms.map((t)=>'"$t"').join(' OR ')]);
    return rows.map((r)=>r['node_id'] as String).toList();
  }
}
