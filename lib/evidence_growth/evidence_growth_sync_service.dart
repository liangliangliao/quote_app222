import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'evidence_growth_dao.dart';
import 'evidence_growth_kb_store.dart';

class EvidenceGrowthSyncResult {
  const EvidenceGrowthSyncResult(this.uploaded,this.downloaded,this.conflicts);
  final int uploaded,downloaded;
  final List<String> conflicts;
}

/// Network errors leave the last acknowledged digest unchanged, so the next
/// attempt retries the same local data. Local writes never await this service.
class EvidenceGrowthSyncClient {
  EvidenceGrowthSyncClient({required this.dao,required this.endpoint,required this.token,http.Client? client})
      : client=client??http.Client();
  final EvidenceGrowthDao dao;
  final Uri endpoint;
  final String token;
  final http.Client client;
  Future<Map<String,dynamic>> request(String method,String path,{Map<String,dynamic>? body,String? key}) async {
    if(endpoint.scheme!='https') throw StateError('同步服务必须使用 HTTPS');
    final uri=endpoint.replace(path:'${endpoint.path.replaceFirst(RegExp(r'/$'), '')}$path',query:null,fragment:null);
    final request=http.Request(method,uri)..headers.addAll({'Authorization':'Bearer $token',
      'Content-Type':'application/json',if(key!=null)'Idempotency-Key':key});
    if(body!=null) request.body=jsonEncode(body);
    final response=await http.Response.fromStream(await client.send(request).timeout(const Duration(seconds:20)))
        .timeout(const Duration(seconds:20));
    if(response.statusCode!=200) throw StateError('同步未完成（HTTP ${response.statusCode}）；本机数据保留。');
    final decoded=jsonDecode(utf8.decode(response.bodyBytes));
    if(decoded is! Map) throw const FormatException('无效同步响应');
    return Map<String,dynamic>.from(decoded);
  }

  Future<EvidenceGrowthSyncResult> sync() async {
    final deletion=await dao.getSetting('sync_delete_pending');
    if(deletion.isNotEmpty) {
      await request('DELETE','/v1/evidence',key:'delete-$deletion');
      await dao.setSetting('sync_delete_pending','');
    }
    if(await dao.getSetting('sync_enabled')!='true') return const EvidenceGrowthSyncResult(0,0,[]);
    final state=await dao.syncState(), sent=<String,String>{};
    final changes=<Map<String,dynamic>>[];
    for(final trial in await dao.recentTrials(limit:10000)) {
      final bundle=await dao.trialBundle(trial.id), digest=EvidenceGrowthDao.bundleDigest(await dao.trialBundle(trial.id));
      if(state[trial.id]?['local_digest']==digest) continue;
      sent[trial.id]=digest;
      changes.add({'base_digest':state[trial.id]?['remote_digest']??'','bundle':bundle});
      if(changes.length>=20) break;
    }
    final response=await request('POST','/v1/sync',body:{'changes':changes,
      'known':{for(final e in state.entries)e.key:e.value['remote_digest']}});
    final ack=Map<String,dynamic>.from(response['acknowledged'] as Map? ?? {});
    for(final entry in ack.entries) {
      if(sent[entry.key]!=null) await dao.acknowledgeSync(entry.key,entry.value as String,sent[entry.key]!);
    }
    final conflicts=(response['conflicts'] as List? ?? []).map((e)=>e.toString()).toList();
    var downloaded=0;
    for(final change in response['changes'] as List? ?? []) {
      final bundle=Map<String,dynamic>.from(change['bundle'] as Map);
      final id=(bundle['trial'] as Map)['trial_id'] as String;
      final local=await dao.byId(id);
      final localDigest=local==null ? '' : EvidenceGrowthDao.bundleDigest(await dao.trialBundle(id));
      if(local!=null && localDigest!=(state[id]?['local_digest']??'')) { conflicts.add(id); continue; }
      try {
        final applied=await dao.importTrialBundle(bundle,baseDigest:localDigest);
        await dao.acknowledgeSync(id,change['digest'] as String,applied); downloaded++;
      } on StateError { conflicts.add(id); }
    }
    await dao.setSetting('sync_conflicts',jsonEncode(conflicts.toSet().toList()));
    var device=await dao.getSetting('sync_device_id');
    if(device.isEmpty) {
      final random=Random.secure(); device=List.generate(16,(_)=>random.nextInt(256).toRadixString(16).padLeft(2,'0')).join();
      await dao.setSetting('sync_device_id',device);
    }
    for(final feedback in await dao.pendingFeedback()) {
      final trialId=feedback['trial_id'] as String;
      if(trialId.isNotEmpty && !(await dao.syncState()).containsKey(trialId)) continue;
      await request('POST','/v1/feedback/evidence',key:'feedback-$device-${feedback['feedback_id']}',body:{
        'trial_id':trialId,'node_id':feedback['node_id'],'category':feedback['category'],'detail':feedback['detail']});
      await dao.acknowledgeFeedback((feedback['feedback_id'] as num).toInt());
    }
    await dao.setSetting('sync_last_at',DateTime.now().toIso8601String());
    return EvidenceGrowthSyncResult(ack.length,downloaded,conflicts.toSet().toList());
  }
  Future<void> updateKnowledge(EvidenceGrowthKbStore store) async {
    await store.install(await request('GET','/v1/kb/manifest'));
  }
  void close()=>client.close();
}

class EvidenceGrowthSyncSettings {
  const EvidenceGrowthSyncSettings(this.dao);
  final EvidenceGrowthDao dao;
  static const _channel=MethodChannel('com.example.quote_app/mental_health_checkup');
  Future<void> configure(String address,String token) async {
    final uri=Uri.tryParse(address.trim());
    if(uri==null || uri.scheme!='https' || uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment || token.trim().isEmpty) {
      throw ArgumentError('请填写 HTTPS 服务地址和访问令牌。');
    }
    if(!Platform.isAndroid) throw StateError('访问令牌仅在 Android Keystore 可用时保存。');
    final encrypted=await _channel.invokeMethod<String>('encryptText',{'value':token.trim()});
    if(encrypted==null || !encrypted.startsWith('keystore-v1:')) throw StateError('访问令牌未安全保存。');
    await dao.setSetting('sync_endpoint',uri.toString());
    await dao.setSetting('sync_token_encrypted',encrypted);
    await dao.setSetting('sync_enabled','true');
  }
  Future<EvidenceGrowthSyncClient?> client() async {
    if(await dao.getSetting('sync_enabled')!='true' && (await dao.getSetting('sync_delete_pending')).isEmpty) return null;
    final address=await dao.getSetting('sync_endpoint'), encrypted=await dao.getSetting('sync_token_encrypted');
    if(!encrypted.startsWith('keystore-v1:')) return null;
    final token=await _channel.invokeMethod<String>('decryptText',{'value':encrypted});
    if(token==null || token.isEmpty) throw StateError('无法解密同步访问令牌。');
    return EvidenceGrowthSyncClient(dao:dao,endpoint:Uri.parse(address),token:token);
  }
  Future<void> disable() async { await dao.setSetting('sync_enabled','false'); }
}
