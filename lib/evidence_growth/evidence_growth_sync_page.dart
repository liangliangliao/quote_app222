import 'dart:convert';
import 'package:flutter/material.dart';

import '../data/db.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_kb_store.dart';
import 'evidence_growth_sync_service.dart';

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
        const Text('这些试验在两个设备都有修改。请先导出证据并核对两端事实，确认保留哪个版本。'),
        ...conflicts.map((id)=>ListTile(title:Text(id),subtitle:const Text('本机记录与远程记录均保留'))),
      ],
    ]));
}
