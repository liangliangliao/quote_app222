import 'package:flutter/material.dart';
import 'cognitive_models.dart';
import 'cognitive_mode.dart';
import 'cognitive_snapshot_view.dart';
import 'cognitive_usage.dart';

class CognitiveEvidenceView extends StatelessWidget {
  final CognitiveNote note;
  final VoidCallback? onOriginal;
  const CognitiveEvidenceView({super.key, required this.note, this.onOriginal});
  @override
  Widget build(BuildContext context) => ExpansionTile(
          key: const ValueKey('cognitive-evidence'),
          tilePadding: EdgeInsets.zero,
          expansionAnimationStyle: cognitiveExpansionStyle(context),
          title: const Text('判断依据'),
          subtitle: const Text('判断凭什么成立；与事件的可能原因分开'),
          onExpansionChanged: (open) {
            if (open)
              CognitiveUsageStore.instance.track(CognitiveEvent.basisOpened);
          },
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note.analysis.basis.isNotEmpty) ...[
              const Text('最初分析的根据 · 未经外部核对',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SelectableText(note.analysis.basis),
            ],
            for (final ref in note.evidenceRefs)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                '本次所选${cognitiveModuleLabel(note.selection.module)}材料',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const Text('原文对应 · 尚未外部核实'),
                            if (note.task != CognitiveTask.review)
                              SelectableText('${ref['excerpt']}')
                            else
                              const Text('仅引用你已确认选中的注释快照，可回到上方材料逐条核对。'),
                            if ('${ref['explanation']}'.isNotEmpty)
                              Text('${ref['explanation']}'),
                          ]))),
            if (note.revisions.isNotEmpty) ...[
              const Text('最新修订引用的材料 · 用户报告'),
              SelectableText(note.revisions.last.evidence),
              if (note.revisions.last.reason.isNotEmpty)
                Text('改判理由：${note.revisions.last.reason}'),
            ],
            const Text('原文中的报告、引用或相邻事件，只是当前判断的材料，不会因此升级为已核实事实或因果证明。'),
            if (onOriginal != null)
              TextButton.icon(
                  onPressed: onOriginal,
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('回到所选原文')),
          ]);
}
