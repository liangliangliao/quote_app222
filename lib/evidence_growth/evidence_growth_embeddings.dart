import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common/sqlite_api.dart';
import '../services/unified_ai_service.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_search.dart';

/// Only provider-produced vectors are stored. Queries/credentials are never
/// persisted in this public knowledge index. Failed batches can be resumed.
class EvidenceGrowthEmbeddings {
  EvidenceGrowthEmbeddings(this.database, this.config, {required this.model, http.Client? client})
      : client=client ?? http.Client();
  final Future<Database> Function() database;
  final UnifiedAiResolvedConfig config;
  final String model;
  final http.Client client;
  void close()=>client.close();
  String get identity=>sha256.convert(utf8.encode('${config.provider}|${config.endpoint}|$model')).toString();
  bool get gemini=>config.provider.toLowerCase()=='gemini';
  static String defaultModel(UnifiedAiResolvedConfig c) =>
      c.provider=='openai' ? 'text-embedding-3-small' : c.provider=='gemini' ? 'gemini-embedding-001' : '';

  Uri get endpoint {
    final uri=Uri.parse(config.endpoint);
    if(uri.scheme!='https' || uri.host.isEmpty || model.trim().isEmpty) throw StateError('EMBEDDING_MODEL_REQUIRED');
    if(gemini) return uri.replace(path:'/v1beta/models/$model:batchEmbedContents',query:'');
    var path=uri.path.replaceFirst(RegExp(r'/(chat/completions|responses)/?$'),'/embeddings');
    if(config.provider=='azure') {
      path=path.replaceFirst(RegExp(r'/deployments/[^/]+/'),'/deployments/${Uri.encodeComponent(model)}/');
    }
    if(!path.endsWith('/embeddings')) throw StateError('EMBEDDING_ENDPOINT_UNSUPPORTED');
    return uri.replace(path:path);
  }
  Future<List<List<double>>> embed(List<String> texts, {bool query=false}) async {
    if(texts.isEmpty) return [];
    final body=gemini ? {'requests':texts.map((t)=>{'model':'models/$model',
      'content':{'parts':[{'text':t}]},'taskType':query?'RETRIEVAL_QUERY':'RETRIEVAL_DOCUMENT'}).toList()}
      : {'model':model,'input':texts,'encoding_format':'float'};
    final headers={'Content-Type':'application/json',
      ...(gemini?{'x-goog-api-key':config.apiKey}:config.effectiveAuthHeaders)};
    final response=await client.post(endpoint,headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:25));
    if(response.statusCode!=200) throw StateError('EMBEDDING_HTTP_${response.statusCode}');
    final data=jsonDecode(response.body) as Map;
    final rows=(data[gemini?'embeddings':'data'] as List).toList();
    if(!gemini) {
      if(rows.map((r)=>(r as Map)['index']).toSet().length!=texts.length ||
          rows.any((r)=>r['index'] is! int || r['index']<0 || r['index']>=texts.length)) {
        throw const FormatException('EMBEDDING_INDICES');
      }
      rows.sort((a,b)=>(a['index'] as int).compareTo(b['index'] as int));
    }
    final vectors=rows.map((r)=>(r[gemini?'values':'embedding'] as List).map((v)=>(v as num).toDouble()).toList()).toList();
    if(vectors.length!=texts.length || vectors.any((v)=>v.isEmpty || v.length>16384 ||
      v.any((x)=>!x.isFinite) || v.every((x)=>x==0) || v.length!=vectors.first.length)) {
      throw const FormatException('EMBEDDING_DIMENSIONS');
    }
    return vectors;
  }
  Future<Database> _db() async {
    final db=await database();
    await db.execute('CREATE TABLE IF NOT EXISTS evidence_growth_vectors ('
      'space TEXT NOT NULL,node_id TEXT NOT NULL,digest TEXT NOT NULL,vector TEXT NOT NULL,'
      'PRIMARY KEY(space,node_id))');
    return db;
  }
  static String digest(EvidenceKNode n)=>sha256.convert(utf8.encode('${n.version}|${n.embeddingText}')).toString();
  Future<Map<String,List<double>>> load(List<EvidenceKNode> nodes) async {
    final current={for(final n in nodes)n.id:digest(n)};
    final result=<String,List<double>>{};
    for(final row in await (await _db()).query('evidence_growth_vectors',where:'space = ?',whereArgs:[identity])) {
      if(current[row['node_id']]!=row['digest']) continue;
      try {
        final v=(jsonDecode(row['vector'] as String) as List).map((x)=>(x as num).toDouble()).toList();
        if(v.isNotEmpty && v.every((x)=>x.isFinite) && v.any((x)=>x!=0)) result[row['node_id'] as String]=v;
      } catch(_) { /* Rebuild invalid cached row. */ }
    }
    return result;
  }
  Future<int> build(List<EvidenceKNode> nodes, {void Function(int,int)? progress, bool Function()? cancelled}) async {
    final existing=await load(nodes);
    final missing=nodes.where((n)=>!existing.containsKey(n.id)).toList();
    final db=await _db(); var count=existing.length;
    progress?.call(count,nodes.length);
    for(var i=0;i<missing.length;i+=8) {
      if(cancelled?.call()==true) break;
      final batch=missing.skip(i).take(8).toList();
      final vectors=await embed(batch.map((n)=>n.embeddingText).toList());
      if(existing.isNotEmpty && vectors.first.length!=existing.values.first.length) {
        throw const FormatException('EMBEDDING_MODEL_CHANGED_REBUILD_REQUIRED');
      }
      await db.transaction((tx) async {
        for(var j=0;j<batch.length;j++) {
          await tx.insert('evidence_growth_vectors',{'space':identity,'node_id':batch[j].id,
            'digest':digest(batch[j]),'vector':jsonEncode(vectors[j])},conflictAlgorithm:ConflictAlgorithm.replace);
          existing[batch[j].id]=vectors[j];
        }
      });
      count+=batch.length; progress?.call(count,nodes.length);
    }
    return count;
  }
  Future<void> clear() async { await (await _db()).delete('evidence_growth_vectors',where:'space = ?',whereArgs:[identity]); }
  Future<Map<String,double>> similarities(String query,List<EvidenceKNode> nodes) async {
    final vectors=await load(nodes);
    if(vectors.isEmpty) return {};
    final q=(await embed([query],query:true)).single;
    return {for(final e in vectors.entries) if(e.value.length==q.length)
      e.key:EvidenceGrowthSearch.cosine(q,e.value)};
  }
}
