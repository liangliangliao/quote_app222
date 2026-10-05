import 'package:flutter/material.dart';

class EvidenceGrowthDecisionFields extends StatefulWidget {
  const EvidenceGrowthDecisionFields({super.key,required this.onChanged,this.budget=''});
  final ValueChanged<Map<String,String>> onChanged;
  final String budget;
  @override
  State<EvidenceGrowthDecisionFields> createState()=>_DecisionFieldsState();
}
class _DecisionFieldsState extends State<EvidenceGrowthDecisionFields> {
  final values=<String,String>{'signal_final':'false','hypothesis_support':'unknown','goal_fit':'unknown',
    'alternative_better':'unknown','next_round_safe':'unknown','method_changed':'false'};
  void change(String key,String value){setState(()=>values[key]=value);widget.onChanged(Map.of(values));}
  Widget choice(String key,String label,Map<String,String> choices)=>DropdownButtonFormField<String>(
    initialValue:values[key],decoration:InputDecoration(labelText:label),
    items:choices.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
    onChanged:(v)=>change(key,v??'unknown'));
  Widget text(String key,String label,{bool numeric=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:6),
    child:TextFormField(decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
      keyboardType:numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.multiline,
      maxLines:numeric?1:3,onChanged:(v)=>change(key,v)));
  @override
  Widget build(BuildContext context)=>Column(children:[
    CheckboxListTile(value:values['signal_final']=='true',title:const Text('约定的结果信号已明确，不必继续等到窗口结束'),
      onChanged:(v)=>change('signal_final','$v')),
    ExpansionTile(title:const Text('继续、调整或退出的依据（按需补充）'),children:[
      choice('hypothesis_support','现实证据如何影响核心假设？',{'unknown':'还不能判断','supports':'支持假设','refuted':'反驳假设'}),
      text('decision_evidence','支持／反对证据、成本或目标变化的具体事实'),
      choice('goal_fit','目标仍符合我的价值和约束吗？',{'unknown':'尚未判断','true':'仍然符合','false':'已经不再符合'}),
      choice('next_round_safe','继续后还保留下一轮资格吗？',{'unknown':'需要检查','true':'可承受且可撤回','false':'会失去生活保障或下一轮资格'}),
      choice('alternative_better','是否已有更合适的替代路线及比较依据？',{'unknown':'尚未判断','true':'有，已在上面记录依据','false':'尚没有'}),
      if(widget.budget.isNotEmpty) Text('行动前预算：${widget.budget}；以下成本请使用相同单位。'),
      if(widget.budget.isNotEmpty) text('cost_spent','本路线累计已用成本',numeric:true),
      CheckboxListTile(value:values['method_changed']=='true',title:const Text('本轮已实际调整策略，而非原样重复'),onChanged:(v)=>change('method_changed','$v')),
      text('proposed_change','若继续测试，建议只改变哪个变量？'),
    ]),
  ]);
}
