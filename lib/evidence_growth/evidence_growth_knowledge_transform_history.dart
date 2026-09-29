import 'package:flutter/material.dart';

import 'evidence_growth_knowledge_transform_store.dart';

/// 某张卡片的转换历史列表。点一条会带着它返回，由上层切换显示。
class EvidenceGrowthKnowledgeTransformHistorySheet extends StatelessWidget {
  const EvidenceGrowthKnowledgeTransformHistorySheet({
    super.key,
    required this.entries,
    required this.currentId,
  });
  final List<KnowledgeTransformEntry> entries;
  final int? currentId;

  static Future<KnowledgeTransformEntry?> show(
    BuildContext context, {
    required List<KnowledgeTransformEntry> entries,
    required int? currentId,
  }) =>
      showModalBottomSheet<KnowledgeTransformEntry>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => EvidenceGrowthKnowledgeTransformHistorySheet(
            entries: entries, currentId: currentId),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('转换历史 · ${entries.length} 条',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('只增不改：每次“重新转换”都会新增一条，不会覆盖之前已成功的内容。',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      for (var i = 0; i < entries.length; i++) ...[
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          selected: entries[i].id == currentId,
          title: Text(
              '${entries[i].timeLabel}${i == 0 ? ' · 最新' : ''}${entries[i].id == currentId ? ' · 正在查看' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${entries[i].transform.core}${entries[i].model.isEmpty ? '' : '\n${entries[i].model}'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context, entries[i]),
        ),
      ],
    ]);
  }
}
