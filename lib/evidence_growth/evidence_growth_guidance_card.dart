import 'package:flutter/material.dart';
import 'evidence_growth_guidance.dart';
import 'evidence_growth_journey_models.dart';

class EvidenceGrowthGuidanceCard extends StatelessWidget {
  const EvidenceGrowthGuidanceCard(
      {super.key,
      required this.value,
      required this.loading,
      required this.onRefresh,
      required this.question,
      required this.onContinue});
  final GrowthData value;
  final bool loading;
  final VoidCallback? onRefresh, onContinue;
  final TextEditingController question;
  static const labels = {
    'belief': '待检验信念',
    'belief_basis': '判断依据',
    'testable_belief': '如何检验信念',
    'belief_update_rule': '何时修正判断',
    'criterion': '建议标准',
    'quality': '质量边界',
    'measurement': '怎样观察',
    'review_gate': '何时核验',
    'stop_condition': '停止条件',
    'self_concordance': '为什么值得',
    'statement': '候选方向',
    'next_action': '下一动作建议',
    'expected_signal': '检验信号',
    'prerequisite': '前置条件',
    'classification': '结果分类候选',
    'object_question': '需核对的结果对象',
    'readiness_question': '何时适合复盘',
    'prediction_error': '预测与实际的差异',
    'cause_hypothesis': '原因假设',
    'learning': '学习草案',
    'keep': '可保留条件',
    'change_candidate': '改变候选',
    'reason': '改变理由',
    'belief_after': '信念校准候选',
    'change_object': '改变对象',
    'plan_change': '计划差异草案'
  };
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('当前节点指导', style: Theme.of(context).textTheme.titleMedium),
            if (loading) const LinearProgressIndicator(),
            if (value.isNotEmpty)
              Text(GrowthGuidance.label(value['origin'] as String?),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            if ('${value['model'] ?? ''}'.isNotEmpty)
              Text('模型：${value['model']}'),
            if ('${value['reason'] ?? ''}'.isNotEmpty)
              Text('${value['reason']}'),
            if ('${value['summary'] ?? ''}'.isNotEmpty)
              Text('${value['summary']}'),
            if (growthStrings(value['fact_quotes']).isNotEmpty)
              ExpansionTile(title: const Text('用户原始记录'), children: [
                for (final f in growthStrings(value['fact_quotes']))
                  ListTile(title: Text(f))
              ]),
            if ('${value['interpretation'] ?? ''}'.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('AI 分析／待检验解释\n${value['interpretation']}')),
            for (final e in growthMap(value['node_output']).entries)
              if ('${e.value}'.trim().isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('${labels[e.key] ?? e.key}\n${e.value}')),
            if ('${value['question'] ?? ''}'.isNotEmpty)
              Text('需要你核对\n${value['question']}'),
            if ('${value['next_step'] ?? ''}'.isNotEmpty)
              Text('接下来\n${value['next_step']}'),
            if (growthRows(value['evidence']).isNotEmpty)
              ExpansionTile(title: const Text('依据 · 知识库内容（本地原文快照）'), children: [
                for (final n in growthRows(value['evidence']))
                  ListTile(
                      title: Text('${n['title']}'),
                      subtitle: Text(
                          '${n['claim']}\n${growthMap(n['source_locator'])['document'] ?? ''} ${growthMap(n['source_locator'])['physical_pages'] ?? ''}\n${n['node_id']}'))
              ]),
            const SizedBox(height: 8),
            TextField(
                controller: question,
                minLines: 1,
                maxLines: 3,
                enabled: !loading,
                decoration: const InputDecoration(
                    labelText: '想进一步理解什么？（问题不自动记为事实）',
                    border: OutlineInputBorder())),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 深入指导／重试')),
              if (onContinue != null)
                TextButton(
                    onPressed: loading ? null : onContinue,
                    child: const Text('核对后继续当前步骤'))
            ]),
            if (value['origin'] == 'AI')
              const Text('AI 草案经你确认后才进入业务流程；不会自动改写事实、预测或目标状态。')
          ])));
}
