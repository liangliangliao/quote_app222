import 'package:flutter/material.dart';
import 'self_os_action_facts.dart';
import 'self_os_codec.dart';

class SelfOsActionFactsPanel extends StatelessWidget {
  const SelfOsActionFactsPanel(
      {super.key, required this.values, required this.onChanged});
  final Map<String, dynamic> values;
  final void Function(String, String) onChanged;

  Widget _choice(String key, String label, Map<String, String> options) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              key: ValueKey('action_fact_$key'),
              isExpanded: true,
              initialValue: options.containsKey(values[key])
                  ? osText(values[key])
                  : 'unknown',
              decoration: InputDecoration(labelText: label),
              items: [
                for (final e in options.entries)
                  DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis))
              ],
              onChanged: (v) {
                onChanged(key, v ?? 'unknown');
                if (key == 'targetStatus' &&
                    !['acquired', 'practiced'].contains(v)) {
                  onChanged('realizedExperience', '');
                  onChanged('ongoingBurden', '');
                }
              }));
  Widget _text(String key, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
          key: ValueKey('action_fact_$key'),
          initialValue: osText(values[key]),
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => onChanged(key, v)));

  @override
  Widget build(BuildContext context) => ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('补充实际过程与限制（可选）'),
          children: [
            const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text('尝试、外部结果和真实体验分开记录。受阻、改道、被迫行为与未知都不定义你的性格。')),
            _choice('attemptStatus', '实际尝试到了哪一步？', osAttemptStates),
            _text('preparation', '已经真正做过的准备'),
            _choice('opportunity', '当时有没有实际选择机会？', osOpportunityStates),
            _choice('autonomy', '当时的自主条件', osAutonomyStates),
            _text('alternativeExplanations', '还有哪些其他解释或限制未排除？'),
            _choice('targetStatus', '行动之后，目标是否真正获得？', osTargetStates),
            if (['acquired', 'practiced'].contains(values['targetStatus'])) ...[
              _text('realizedExperience', '真正得到或实践后，实际体验怎样？'),
              _text('ongoingBurden', '持续负担、适应期与仍待观察的变化'),
            ],
          ]);
}
