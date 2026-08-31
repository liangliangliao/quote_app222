import 'package:flutter/material.dart';

import 'xiangji_practical_product.dart';
import 'xiangji_schopenhauer_core_catalog.dart';
import 'xiangji_ui_support.dart';

class XiangjiPracticalDecisionCard extends StatelessWidget {
  const XiangjiPracticalDecisionCard({
    super.key,
    required this.problem,
    required this.goal,
    required this.keyGap,
    required this.judgment,
    required this.choices,
    required this.selectedChoiceId,
    required this.onChoiceSelected,
    required this.onStart,
    required this.onModify,
    required this.onOppose,
    required this.onShowDetails,
    this.detailsExpanded = false,
  });

  final String problem;
  final String goal;
  final String keyGap;
  final String judgment;
  final List<XiangjiActionChoice> choices;
  final String selectedChoiceId;
  final ValueChanged<String> onChoiceSelected;
  final VoidCallback? onStart;
  final VoidCallback onModify;
  final VoidCallback onOppose;
  final VoidCallback onShowDetails;
  final bool detailsExpanded;

  XiangjiActionChoice? get _selected {
    if (choices.isEmpty) return null;
    return choices.firstWhere(
      (choice) => choice.id == selectedChoiceId,
      orElse: () => choices.firstWhere(
        (choice) => choice.preferred,
        orElse: () => choices.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return XiangjiSectionCard(
      title: '现在只需要决定一件事',
      subtitle: '军师已经完成后台分析；选一条你现在真的愿意尝试的办法。',
      icon: Icons.touch_app_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          XiangjiLabeledValue(
            label: '我理解你要解决的是',
            value: problem,
          ),
          if (goal.trim().isNotEmpty)
            XiangjiLabeledValue(
              label: '希望现实变成',
              value: goal,
            ),
          if (judgment.trim().isNotEmpty)
            XiangjiLabeledValue(
              label: '军师一句判断',
              value: judgment,
            ),
          if (choices.isEmpty)
            const Text(
              '当前还没有可安全执行的行动。请补充军师提出的关键事实，或修改对问题的理解。',
              style: TextStyle(color: XiangjiPalette.muted, height: 1.5),
            )
          else ...[
            const SizedBox(height: 4),
            const Text(
              '同一个方向，选择适合当前状态的负担',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final choice in choices) _choiceTile(choice),
            if (selected != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBED8CB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('你选择后，今天只做这一步',
                        style: TextStyle(
                          color: XiangjiPalette.pine,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 6),
                    Text(selected.action,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        )),
                    const SizedBox(height: 8),
                    Text('预计 ${selected.minutes} 分钟 · ${selected.fitReason}',
                        style: const TextStyle(
                          color: XiangjiPalette.muted,
                          height: 1.4,
                        )),
                    const SizedBox(height: 5),
                    Text('做到这里就停：${selected.stopCondition}',
                        style: const TextStyle(
                          color: XiangjiPalette.muted,
                          height: 1.4,
                        )),
                    const SizedBox(height: 7),
                    Text('你会得到：${selected.visibleOutput}',
                        style: const TextStyle(
                          color: XiangjiPalette.pine,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        )),
                    const SizedBox(height: 5),
                    Text('完成信号：${selected.completionSignal}',
                        style: const TextStyle(
                          color: XiangjiPalette.muted,
                          height: 1.4,
                        )),
                    const SizedBox(height: 5),
                    Text('如果卡住：${selected.recoveryAction}',
                        style: const TextStyle(
                          color: XiangjiPalette.muted,
                          height: 1.4,
                        )),
                    const SizedBox(height: 7),
                    Text(selected.motivationCue,
                        style: const TextStyle(
                          color: XiangjiPalette.pine,
                          height: 1.4,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('为什么可能有效 / 怎样验算'),
                childrenPadding: EdgeInsets.zero,
                children: [
                  XiangjiLabeledValue(
                    label: '它先减少什么差距',
                    value: keyGap,
                  ),
                  XiangjiLabeledValue(
                    label: '作用机制',
                    value: selected.mechanism,
                  ),
                  XiangjiLabeledValue(
                    label: '如果有效，现实中应该看到',
                    value: selected.prediction,
                  ),
                  XiangjiLabeledValue(
                    label: '停止条件',
                    value: selected.stopCondition,
                  ),
                  XiangjiLabeledValue(
                    label: '这一步在练会什么',
                    value: selected.principlePractice,
                  ),
                  XiangjiLabeledValue(
                    label: '下次怎样迁移到新情境',
                    value: selected.transferQuestion,
                  ),
                  XiangjiLabeledValue(
                    label: '核心思想家',
                    value: selected.thinkerNames.join('、'),
                  ),
                  if (selected.activeMethodLabels.isNotEmpty)
                    XiangjiLabeledValue(
                      label: '本轮实际调用的方法',
                      value: selected.activeMethodLabels.join('、'),
                    ),
                  XiangjiLabeledValue(
                    label: '本轮知识来源',
                    value: selected.knowledgeSource,
                  ),
                  XiangjiLabeledValue(
                    label: '本轮实际使用的叔本华 L0 概念',
                    value: _conceptNames(selected.coreConceptIds),
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('xiangji_start_selected_action'),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('选择这条并开始'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TextButton(onPressed: onModify, child: const Text('我想改一下')),
              TextButton(onPressed: onOppose, child: const Text('这不是我的问题')),
              TextButton.icon(
                onPressed: onShowDetails,
                icon: Icon(
                  detailsExpanded ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(detailsExpanded ? '收起完整推演' : '展开完整推演'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceTile(XiangjiActionChoice choice) {
    final selected = choice.id == selectedChoiceId ||
        (selectedChoiceId.isEmpty && choice.preferred);
    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.label}，预计 ${choice.minutes} 分钟，${choice.fitReason}',
      child: Card(
        elevation: 0,
        color: selected ? const Color(0xFFFFF3DD) : XiangjiPalette.mist,
        margin: const EdgeInsets.only(bottom: 7),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChoiceSelected(choice.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? XiangjiPalette.pine
                      : XiangjiPalette.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              choice.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${choice.minutes} 分钟',
                            style: const TextStyle(
                              color: XiangjiPalette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        choice.fitReason,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _conceptNames(List<String> ids) => ids
    .map((id) {
      try {
        return XiangjiSchopenhauerCoreCatalog.forId(id).displayName;
      } catch (_) {
        return id;
      }
    })
    .join('；');
