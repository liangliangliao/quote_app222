import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'evidence_growth_models.dart';

class EvidenceGrowthEvidenceHistory extends StatelessWidget {
  const EvidenceGrowthEvidenceHistory({super.key,required this.trials,required this.onOpen});
  final List<RealityTrial> trials;
  final ValueChanged<RealityTrial> onOpen;
  @override
  Widget build(BuildContext context) {
    final byId={for(final t in trials)t.id:t};
    final recovery=trials.where((t)=>t.resultAtMs>0 &&
      (const {'NOT_DONE','ABORTED'}.contains(t.resultStatus) || const {'BASIC','COMPLEX','INTELLIGENT'}.contains(t.failureClass)))
      .where((t)=>(byId[t.nextTrialId]?.startedAtMs ?? 0)>=t.resultAtMs)
      .toList()..sort((a,b)=>a.resultAtMs.compareTo(b.resultAtMs));
    final points=recovery.length>12?recovery.sublist(recovery.length-12):recovery;
    final hours=points.map((t)=>(byId[t.nextTrialId]!.startedAtMs-t.resultAtMs)/3600000).toList();
    final exposure=trials.where((t)=>t.operator.contains('EXPOSURE') || t.imageExposureSignal).take(20).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('失败／中断后，多久重新行动？',style:TextStyle(fontWeight:FontWeight.bold)),
        const Text('只使用已连接的下一轮真实开始时间。最近记录中最多展示 12 次；未重新开始的轮次不记为 0 小时。'),
        if(hours.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('还没有“结果记录→下一轮开始”的完整时间样本。')),
        if(hours.isNotEmpty) ...[
          const SizedBox(height:12),
          Semantics(label:'重新行动间隔（小时），从早到晚：${hours.map((h)=>h.toStringAsFixed(1)).join('，')}',
            child:SizedBox(height:110,width:double.infinity,child:CustomPaint(painter:_RecoveryPainter(hours)))),
          ...points.asMap().entries.map((e)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,
            title:Text('${_date(e.value.resultAtMs)} · ${hours[e.key].toStringAsFixed(1)} 小时后重新行动'),
            onTap:()=>onOpen(e.value))),
        ],
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('暴露记录',style:TextStyle(fontWeight:FontWeight.bold)),
        const Text('对照原预测、实际反馈和恢复；区分想象暴露与现实行动。'),
        if(exposure.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('还没有暴露试验记录。')),
        ...exposure.map((t)=>ExpansionTile(tilePadding:EdgeInsets.zero,title:Text(t.actionInstruction,maxLines:2,overflow:TextOverflow.ellipsis),
          subtitle:Text('${_date(t.createdAtMs)} · ${t.imageExposureSignal?'含想象暴露 · ':''}${t.startedAtMs>0?'已启动':'尚未启动'}'),
          children:[Align(alignment:Alignment.centerLeft,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('原预测：${t.prediction}（${(t.probability*100).round()}%）'),
            Text('实际：${t.actualOutcome.isEmpty?'尚无结果':t.actualOutcome}'),
            Text('实测焦虑：${t.operatorInputs['actual_anxiety'] ?? '未记录'} / 10'),
            Text('自报恢复时长：${t.operatorInputs['recovery_hours'] ?? '未记录'} 小时'),
            Text('学习：${t.learning.isEmpty?'尚未复盘':t.learning}'),
            TextButton(onPressed:()=>onOpen(t),child:const Text('打开证据档案')),
          ]))])),
      ]))),
    ]);
  }
  static String _date(int ms) { final t=DateTime.fromMillisecondsSinceEpoch(ms);return '${t.month}/${t.day}'; }
}

class _RecoveryPainter extends CustomPainter {
  _RecoveryPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas,Size size) {
    final maxValue=math.max(1.0,values.reduce(math.max));
    final paint=Paint()..color=const Color(0xFF24766C)..strokeWidth=2..style=PaintingStyle.stroke;
    final path=Path();
    for(var i=0;i<values.length;i++) {
      final point=Offset(values.length==1?size.width/2:6+i*(size.width-12)/(values.length-1),size.height-6-values[i]/maxValue*(size.height-12));
      if(i==0) {path.moveTo(point.dx,point.dy);} else {path.lineTo(point.dx,point.dy);}
      canvas.drawCircle(point,3,Paint()..color=paint.color);
    }
    canvas.drawPath(path,paint);
  }
  @override
  bool shouldRepaint(covariant _RecoveryPainter oldDelegate)=>oldDelegate.values!=values;
}
