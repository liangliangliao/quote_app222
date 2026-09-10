import 'dart:convert';
import 'package:flutter/material.dart';

import '../data/db.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_kb_store.dart';
import 'evidence_growth_sync_service.dart';
import 'evidence_growth_notification_service.dart';

class EvidenceGrowthSyncPage extends StatefulWidget {
  const EvidenceGrowthSyncPage({super.key,required this.dao});
  final EvidenceGrowthDao dao;
  @override
  State<EvidenceGrowthSyncPage> createState()=>_EvidenceGrowthSyncPageState();
}
class _EvidenceGrowthSyncPageState extends State<EvidenceGrowthSyncPage> {
  final address=TextEditingController(),token=TextEditingController();
  bool enabled=false,busy=false,configured=false;
  String status='个人记录默认只保存在本机。';
  List<String> conflicts=[];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    address.text=await widget.dao.getSetting('sync_endpoint');
    final active=await widget.dao.getSetting('sync_enabled')=='true';
    final last=await widget.dao.getSetting('sync_last_at');
    final conflictIds=jsonDecode(await widget.dao.getSetting('sync_conflicts',fallback:'[]')) as List;
    if(mounted) setState(() { enabled=active; configured=address.text.isNotEmpty; conflicts=conflictIds.map((e)=>e.toString()).toList();
      if(last.isNotEmpty) status='上次同步：$last'; });
  }
  @override
  void dispose() { address.dispose();token.dispose();super.dispose(); }
  Future<void> _run({bool connect=false,bool knowledge=false}) async {
    if(busy) return;
    setState(()=>busy=true);
    EvidenceGrowthSyncClient? client;
    try {
      final settings=EvidenceGrowthSyncSettings(widget.dao);
      if(connect) { await settings.configure(address.text,token.text); token.clear(); configured=true; }
      client=await settings.client();
      if(client==null) throw StateError('请先配置并启用同步。');
      if(knowledge) {
        await client.updateKnowledge(EvidenceGrowthKbStore(AppDatabase.instance));
        if(mounted) setState(()=>status='知识库已校验并更新。原 Trial 的证据版本保留。');
      } else {
        final result=await client.sync();
        if(mounted) setState(() { conflicts=result.conflicts;
          status='已上传 ${result.uploaded} 轮，下载 ${result.downloaded} 轮。${conflicts.isEmpty?'':'有 ${conflicts.length} 轮冲突，两端记录均保留。'}'; });
      }
    } catch(_) {
      if(mounted) setState(()=>status='暂未同步成功。请检查服务地址、访问令牌与网络；本机记录已经保留。');
    } finally { client?.close();if(mounted) setState(()=>busy=false); }
  }
  Future<void> _resolve(String id) async {
    if(busy) return;
    setState(()=>busy=true);
    EvidenceGrowthSyncClient? client;
    try {
      client=await EvidenceGrowthSyncSettings(widget.dao).client();
      if(client==null) throw StateError('请先启用同步。');
      final comparison=await client.conflict(id);
      if(!mounted) return;
      Widget version(String label,Map bundle) {
        final t=bundle['trial'] as Map;
        return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:const TextStyle(fontWeight:FontWeight.bold)),
          Text('状态：${t['status']} · 决策：${t['decision']}'),
          Text('原预测：${t['prediction']}'), Text('实际事实：${t['actual_outcome']}'),
          Text('学习：${t['learning']}'), Text('下一步：${t['next_action']}'),
        ])));
      }
      final choice=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('比较两端记录'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          version('本机',comparison['local'] as Map),version('远程',comparison['remote'] as Map),
          const Text('两份记录会先保存到冲突档案，随 JSON 导出。只选择本轮当前版本；原预测与原知识依据仍不可改写。'),
        ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('暂不处理')),
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('采用远程')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('采用本机'))]));
      if(choice==null) return;
      await client.resolveConflict(id,comparison,keepLocal:choice);
      await const EvidenceGrowthNotificationService().reconcile();
      await _load();
      if(mounted) setState(()=>status='已处理该轮冲突，两份原记录均已保存在冲突档案。');
    } catch(_) {
      if(mounted) setState(()=>status='未覆盖任何未经核对的新版本。可能有新的修改或原预测不一致，请重新比较；两端记录保留。');
    } finally { client?.close(); if(mounted) setState(()=>busy=false); }
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('跨设备同步')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('连接自己的证据成长服务',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),const Text('启用后，将向这个服务发送 Trial、事前预测、结果和复盘。断网时继续在本机记录，恢复连接后重试。'),
      const SizedBox(height:16),TextField(controller:address,keyboardType:TextInputType.url,
        decoration:const InputDecoration(labelText:'HTTPS 服务地址',hintText:'https://growth.example.com',border:OutlineInputBorder())),
      const SizedBox(height:12),TextField(controller:token,obscureText:true,enableSuggestions:false,autocorrect:false,
        decoration:InputDecoration(labelText:configured?'新的访问令牌（更换连接时填写）':'访问令牌',border:const OutlineInputBorder())),
      SwitchListTile(contentPadding:EdgeInsets.zero,value:enabled,title:const Text('允许同步个人 Trial'),
        onChanged:busy?null:(v) async { setState(()=>enabled=v); if(!v) await EvidenceGrowthSyncSettings(widget.dao).disable();
          else if(configured) await widget.dao.setSetting('sync_enabled','true'); }),
      FilledButton(onPressed:busy||!enabled?null:()=>_run(connect:true),child:const Text('保存连接并同步')),
      if(configured) OutlinedButton(onPressed:busy||!enabled?null:()=>_run(),child:const Text('立即同步')),
      if(configured) OutlinedButton(onPressed:busy||!enabled?null:()=>_run(knowledge:true),child:const Text('检查知识库更新')),
      if(busy) const LinearProgressIndicator(),
      const SizedBox(height:14),Text(status),
      if(conflicts.isNotEmpty) ...[
        const SizedBox(height:18),const Text('冲突未自动覆盖',style:TextStyle(fontWeight:FontWeight.bold)),
        const Text('这些试验在两个设备都有修改。逐轮比较事实后选择当前版本，双方原记录都会保留。'),
        ...conflicts.map((id)=>ListTile(title:Text(id),subtitle:const Text('点击比较与处理'),
          trailing:const Icon(Icons.compare_arrows),onTap:busy?null:()=>_resolve(id))),
      ],
    ]));
}
