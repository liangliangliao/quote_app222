import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'evidence_growth_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_workflows.dart';

/// Draft is saved independently of Trial creation, including the absolute
/// analysis deadline. Leaving the page or restarting does not reset seven minutes.
class EvidenceGrowthWorkflowPage extends StatefulWidget {
  const EvidenceGrowthWorkflowPage({super.key,required this.route,required this.dao,required this.ai});
  final EvidenceRouteResult route;
  final EvidenceGrowthDao dao;
  final EvidenceGrowthAiService ai;
  @override
  State<EvidenceGrowthWorkflowPage> createState()=>_WorkflowState();
}
class _WorkflowState extends State<EvidenceGrowthWorkflowPage> {
  Map<String,dynamic> data={};
  bool loading=true, generating=false;
  Timer? tick;
  Future<void> writes=Future.value();
  bool get premortem=>widget.route.operator=='PREMORTEM';
  String get key=>'workflow_draft_${sha256.convert(utf8.encode('${widget.route.operator}|${widget.route.rawInput}'))}';
  int get remaining=>(((data['analysis_deadline_ms'] as num? ?? 0)-DateTime.now().millisecondsSinceEpoch)/1000).ceil().clamp(0,420);
  bool get finished=>(data['analysis_finished_ms'] as num? ?? 0)>0 || (!loading && remaining==0);
  @override
  void initState(){super.initState(); unawaited(load());}
  Future<void> load() async {
    final saved=await widget.dao.getSetting(key);
    try { data=EvidenceGrowthWorkflows.decode(saved); } catch(_){data={};}
    if(data.isEmpty) data=premortem?{
      'horizon_days':30,'analysis_deadline_ms':DateTime.now().add(const Duration(minutes:7)).millisecondsSinceEpoch,
      'selected_count':1,'risks':List.generate(5,(i)=>{'id':i,'reason':'','probability':50,'loss':3,
        'prevention':'','signal':'','backup':''}),
    }:{'scans':{for(final k in EvidenceGrowthWorkflows.layers.keys)k:''},'layer':'friction',
      'controllable':false,'window_days':7};
    await persist();
    if(!mounted)return;
    setState(()=>loading=false);
    if(premortem) tick=Timer.periodic(const Duration(seconds:1),(_){
      if(!mounted)return;
      if((data['analysis_finished_ms'] as num? ?? 0)==0 && remaining==0){data['analysis_finished_ms']=DateTime.now().millisecondsSinceEpoch;unawaited(persist());}
      setState((){});
    });
  }
  Future<void> persist(){
    final value=jsonEncode(data);
    writes=writes.catchError((Object _){}).then((_)=>widget.dao.setSetting(key,value));
    return writes;
  }
  void change(void Function() fn){setState(fn);unawaited(persist());}
  @override
  void dispose(){tick?.cancel();super.dispose();}
  Widget field(String label,String id,{Map<String,dynamic>? target,bool enabled=true}) {
    final map=target??data;
    return Padding(padding:const EdgeInsets.symmetric(vertical:6),child:TextFormField(
      key:ValueKey('$id:${map['id']??"root"}:${data['draft_revision']??0}'),
      initialValue:(map[id]??'').toString(),enabled:enabled,minLines:1,maxLines:4,
      decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
      onChanged:(v)=>change(()=>map[id]=v)));
  }
  Future<void> draft() async {
    setState(()=>generating=true);
    final suggested=await widget.ai.workflowDraft(widget.route,premortem:premortem);
    if(!mounted)return;
    if(suggested.isNotEmpty) change((){
      // Preserve user edits, ratings, selected levels, and the original deadline.
      if(premortem && !finished) {
        final rows=suggested['risks'] as List? ?? [];
        for(var i=0;i<5 && i<rows.length;i++) {
          final current=(data['risks'] as List)[i] as Map;
          for(final k in ['reason','prevention','signal','backup']) {
            if((current[k]??'').toString().isEmpty) current[k]=(rows[i] as Map)[k]??'';
          }
        }
      } else if(!premortem) {
        final scans=data['scans'] as Map;
        for(final k in EvidenceGrowthWorkflows.layers.keys) {
          if((scans[k]??'').toString().isEmpty) scans[k]=(suggested['scans'] as Map? ?? {})[k]??'';
        }
      }
      data['draft_revision']=(data['draft_revision'] as num? ?? 0)+1;
      data['ai_draft']=true;
    });
    setState(()=>generating=false);
    if(suggested.isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('暂未获得可用草案，可直接填写并保存。')));
  }
  Future<void> save() async {
    try {
      final inputs={'advanced_json':jsonEncode(data),'workflow_version':'2'};
      EvidenceGrowthWorkflows.validate(widget.route.operator,inputs);
      await persist();
      if(mounted)Navigator.pop(context,inputs);
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(premortem?'事前失败分析':'系统杠杆扫描')),
    body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      Text(premortem?'先限时找风险，再把风险转成预防行动。':'检查八个层面，只改变一个可控变量。',style:Theme.of(context).textTheme.titleLarge),
      Text(premortem?'依据 KB35 物理页 191–192 · Gary Klein':'依据 KB35 物理页 193 · Meadows'),
      const SizedBox(height:12),
      TextButton.icon(onPressed:generating || (premortem && finished)?null:draft,
        icon:generating?const SizedBox(width:18,height:18,child:CircularProgressIndicator()):const Icon(Icons.auto_awesome),
        label:const Text('结合当前问题生成待核对草案')),
      if(data['ai_draft']==true) const Text('AI 草案是待核对假设，不是已经发生的事实；已有填写内容会保留。'),
      if(premortem)...premortemFields() else ...systemFields(),
      const SizedBox(height:16),FilledButton(onPressed:save,child:const Text('保存方案，进入现实行动')),
      const Text('草稿自动保存；返回后可继续。'),
    ]));
  List<Widget> premortemFields() {
    final rows=(data['risks'] as List).cast<Map<String,dynamic>>();
    final ranked=EvidenceGrowthWorkflows.rankedRisks(data);
    final top=ranked.take((data['selected_count'] as num).toInt()).map((r)=>r['id']).toSet();
    return [
      DropdownButtonFormField<int>(initialValue:data['horizon_days'] as int,
        decoration:const InputDecoration(labelText:'假设已经失败的时间'),
        items:const [DropdownMenuItem(value:30,child:Text('30 天后')),DropdownMenuItem(value:90,child:Text('90 天后'))],
        onChanged:finished?null:(v)=>change(()=>data['horizon_days']=v)),
      Text(finished?'原因分析已结束；现在安排护栏，然后进入行动。':'分析剩余 ${remaining~/60}:${(remaining%60).toString().padLeft(2,"0")}'),
      for(final row in rows) Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        field('失败原因 ${(row['id'] as int)+1}','reason',target:row,enabled:!finished),
        Text('估计概率 ${row['probability']}% · 损失 ${row['loss']}/5（主观排序，不是统计结论）'),
        Slider(value:(row['probability'] as num).toDouble(),max:100,divisions:20,
          onChanged:finished?null:(v)=>change(()=>row['probability']=v.round())),
        Slider(value:(row['loss'] as num).toDouble(),min:1,max:5,divisions:4,
          onChanged:finished?null:(v)=>change(()=>row['loss']=v.round())),
      ]))),
      if(!finished) TextButton(onPressed:()=>change(()=>data['analysis_finished_ms']=DateTime.now().millisecondsSinceEpoch),child:const Text('已找到关键风险，提前结束分析')),
      if(finished && rows.any((r)=>(r['reason'] as String).trim().isEmpty))
        const Text('时间到了；空项可记为“暂未识别”，不继续扩展灾难想象。'),
      if(finished) for(final row in rows.where((r)=>(r['reason'] as String).trim().isEmpty))
        TextButton(onPressed:()=>change((){row['reason']='暂未识别，不据此采取行动';row['probability']=0;row['loss']=1;}),child:Text('原因 ${(row['id'] as int)+1} 标为暂未识别')),
      DropdownButtonFormField<int>(initialValue:(data['selected_count'] as num).toInt(),
        decoration:const InputDecoration(labelText:'按概率 × 损失选择前几项'),
        items:[for(var n=1;n<=3;n++)DropdownMenuItem(value:n,child:Text('前 $n 项'))],
        onChanged:(v)=>change(()=>data['selected_count']=v)),
      for(final sorted in ranked) if(top.contains(sorted['id']))
        Builder(builder:(_){final row=rows.firstWhere((r)=>r['id']==sorted['id']);return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          Text('优先风险：${row['reason']}'),
          field('今天的预防动作','prevention',target:row),field('可观察的早期信号','signal',target:row),field('信号出现时的备用方案','backup',target:row),
        ])));}),
    ];
  }
  List<Widget> systemFields()=>[
    for(final layer in EvidenceGrowthWorkflows.layers.entries)
      ExpansionTile(title:Text(layer.value),subtitle:Text((data['scans'] as Map)[layer.key].toString().isEmpty?'尚未核查':'已记录'),children:[
        field('当前事实／待验证假设；不适用时说明原因',layer.key,target:data['scans'] as Map<String,dynamic>),
      ]),
    DropdownButtonFormField<String>(initialValue:data['layer'] as String,
      decoration:const InputDecoration(labelText:'本轮只选择一个层面'),
      items:EvidenceGrowthWorkflows.layers.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value.split('：').first))).toList(),
      onChanged:(v)=>change(()=>data['layer']=v)),
    field('谁能改变这一层？需要谁配合？','owner'),
    CheckboxListTile(value:data['controllable']==true,title:const Text('本次改变在我的控制或已确认的协作范围内'),onChanged:(v)=>change(()=>data['controllable']=v)),
    field('当前基线：现在发生什么？','baseline'),field('只改变哪个变量？其余保持什么？','change'),
    field('怎样观察是否改善？','metric'),field('今天在现实中执行什么？','next_action'),
    DropdownButtonFormField<int>(initialValue:(data['window_days'] as num).toInt(),
      decoration:const InputDecoration(labelText:'PDSA 观察窗口'),
      items:[for(final n in [1,3,7,14,30])DropdownMenuItem(value:n,child:Text('$n 天'))],
      onChanged:(v)=>change(()=>data['window_days']=v)),
  ];
}
