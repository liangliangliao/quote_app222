import 'package:flutter/material.dart';
import 'evidence_growth_cycle.dart';
import 'evidence_growth_models.dart';

/// A view of one evolving reality, not six completion checkboxes.
class EvidenceGrowthCycleCard extends StatelessWidget {
  const EvidenceGrowthCycleCard({super.key,required this.trial});
  final RealityTrial trial;
  @override
  Widget build(BuildContext context) {
    final p=EvidenceGrowthCycle.plan(trial), confirmed=EvidenceGrowthCycle.confirmed(trial);
    final u=confirmed.isEmpty?EvidenceGrowthCycle.update(trial):confirmed;
    final rows=<String,String>{
      '信念 · 本轮检验':(p['belief']??'').isEmpty?'尚未明确，不替你猜测。':p['belief']!,
      '目标 · 现实差距':'${trial.goalState.isEmpty?"待明确目标":trial.goalState}\n${trial.topGap}',
      '行动 · 进入现实':trial.actionInstruction,
      '失败／成功 · 现实反馈':trial.actualOutcome.isEmpty?'等待现实记录，未开始也可以如实反馈。':
        '${trial.actualOutcome}${trial.didAction==false?"\n未做是障碍信息，不是能力被证伪。":""}',
      '复盘 · 学到了什么':trial.learning.isEmpty?'收到事实后，对照原预测再判断。':trial.learning,
      '改变 · 返回下一轮':trial.decision.isEmpty?'${u['change_reason']??"等待复盘后确认下一步。"}':
        '${trial.nextAction}\n${trial.nextTrialId.isEmpty?(trial.decision=="EXIT"?"当前路线已结束，学习保留。":trial.decision=="OBSERVE"?"本轮仍在等待观察。":"下一轮尚未建立，等待进入现实。") : "已连接下一轮现实行动。"}',
    };
    return Card(elevation:0,child:ExpansionTile(
      key:ValueKey('cycle-${trial.id}'),
      title:Text('第 ${EvidenceGrowthCycle.round(trial)} 轮 · 同一个现实问题'),
      subtitle:Text(trial.goalState.isEmpty?'信念 → 目标 → 行动 → 反馈 → 复盘 → 改变 → 新信念':trial.goalState),
      children:[
        for(final e in rows.entries) ListTile(dense:true,title:Text(e.key),subtitle:Text(e.value)),
        if((u['belief_after']??'').isNotEmpty) ListTile(title:Text(confirmed.isEmpty?'待确认的新判断':'本轮确认的新判断'),
          subtitle:Text('${u['belief_after']}\n依据与范围：${u['belief_reason']}')),
        if((p['learning_applied']??'').isNotEmpty) ListTile(title:const Text('上一轮如何改变了这一轮'),subtitle:Text(p['learning_applied']!)),
      ],
    ));
  }
}
