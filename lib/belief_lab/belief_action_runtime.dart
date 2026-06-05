import 'belief_action_consistency.dart';
import 'belief_action_models.dart';
import 'belief_models.dart';

/// 将“行动模板”转换为可执行的 Flow steps。
///
/// 目标：让“概念 → 行动”在 App 内变成可勾选、可记录、可评分、可复盘的结构。
List<BeliefStep> buildBeliefActionStepsFromTemplate({
  required BeliefActionTemplate template,
  required String conceptTitle,
}) {
  final ref = template.refSegmentKeys.isEmpty ? '（无）' : template.refSegmentKeys.join('、');

  final choices = <BeliefChoice>[];
  for (int i = 0; i < template.actionChecklist.length; i++) {
    final text = template.actionChecklist[i].trim();
    if (text.isEmpty) continue;
    choices.add(BeliefChoice(id: 'c$i', text: text));
  }

  final base = <BeliefStep>[
    BeliefStep(
      id: 'tpl_info',
      title: '概念 → 行动（操作性定义）',
      body: '概念：$conceptTitle\n模板：${template.title}（${template.version}）\n\n操作性定义：\n${template.operationalDefinition}\n\n成功判据：\n${template.successCriteria}\n\n参考段落：$ref',
      type: BeliefStepType.info,
      required: false,
    ),
    if (choices.isNotEmpty)
      BeliefStep(
        id: 'tpl_check',
        title: '行动清单（勾选你实际做了哪些）',
        body: '这是行动的“直观表达”。\n你不需要全做，但建议至少做 1–2 条并写下证据。',
        type: BeliefStepType.multiChoice,
        required: false,
        choices: choices,
      ),
    const BeliefStep(
      id: 'tpl_do',
      title: '行动记录',
      body: '请写下你具体怎么做的：\n- 何时何地\n- 做了哪些步骤\n- 用了多久\n- 结果/反馈是什么',
      type: BeliefStepType.input,
      required: true,
    ),
  ];

  return BeliefActionConsistency.enhanceMissionSteps(base);
}
