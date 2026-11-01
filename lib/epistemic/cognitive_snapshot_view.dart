import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'cognitive_mode.dart';

String cognitiveModuleLabel(String module) =>
    const {
      'diary': '日记',
      'quote': '名言',
      'thought': '念头',
      'concept': '概念',
      'xiangji_problem': '向己',
      'zhixing_action': '知行',
      'quote_observation': '名言实践',
      'enemy_message': '美丽的敌人',
      'discover_belief': '发现之旅信念',
    }[module] ??
    '认识注释';

class CognitiveSnapshotView extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  const CognitiveSnapshotView({super.key, required this.snapshot});
  @override
  Widget build(BuildContext context) {
    final record = insightObject(snapshot['record']);
    final revisions = snapshot['revisions'] is List
        ? snapshot['revisions'] as List
        : const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${cognitiveModuleLabel(insightText(record, 'module'))} · 注释快照',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      if (insightText(record, 'created_at').isNotEmpty)
        Text('保存时间：${record['created_at']}',
            style: const TextStyle(fontSize: 12)),
      for (final field in const {
        'selected_text': '所选原文',
        'original_judgment': '原判断',
        'current_judgment': '当前判断',
        'basis': '依据',
        'unknown': '未知'
      }.entries)
        if (insightText(snapshot, field.key).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SelectableText('${field.value}：${snapshot[field.key]}',
                  style: const TextStyle(height: 1.6))),
      for (final value in revisions)
        Builder(builder: (_) {
          final revision = insightObject(value);
          return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                  '修订：${revision['previous']} → ${revision['judgment']}\n'
                  '新材料：${revision['evidence']}\n理由：${revision['reason']}\n${revision['created_at']}',
                  style: const TextStyle(height: 1.6)));
        }),
      ExpansionTile(
          expansionAnimationStyle: cognitiveExpansionStyle(context),
          tilePadding: EdgeInsets.zero,
          title: const Text('将发送的定位与依据'),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText('记录定位：${record['module']} / ${record['id']}\n'
                '注释定位：${record['note_id']}\n内容指纹：${record['original_hash']}'),
            for (final value in snapshot['evidence_refs'] is List
                ? snapshot['evidence_refs'] as List
                : const [])
              Builder(builder: (_) {
                final ref = insightObject(value);
                return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SelectableText('依据定位：${ref['locator']}\n'
                        '${ref['uses_selected_text'] == true ? '引用上方完整所选原文' : ref['excerpt'] ?? ''}\n'
                        '依据说明：${ref['explanation'] ?? ''}\n状态：尚未外部核对'));
              }),
          ]),
    ]);
  }
}
