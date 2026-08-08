import 'package:flutter/material.dart';

import 'xiangji_knowledge_repository.dart';

class XiangjiMentorUpgradeCard extends StatelessWidget {
  const XiangjiMentorUpgradeCard({
    super.key,
    required this.fromThinkerId,
    required this.onReselect,
  });

  static const ValueKey<String> cardKey =
      ValueKey<String>('xiangji_mentor_upgrade_reselection');
  static const ValueKey<String> reselectKey =
      ValueKey<String>('xiangji_reselect_mentor_after_upgrade');

  final String fromThinkerId;
  final VoidCallback onReselect;

  @override
  Widget build(BuildContext context) {
    final legacyName = XiangjiKnowledgeRepository.legacySystemDisplayName(
      fromThinkerId,
    );
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x0F20342D)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A20342D),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.system_update_alt,
            color: Color(0xFF3D725D),
            size: 32,
          ),
          const SizedBox(height: 10),
          const Text(
            '知识库已升级，请重新选择目标导师',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '原导师：$legacyName。旧版体系不能被静默等同为新的 10 位目标核心导师，因此由你重新选择。',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            '你的目标原话、版本、行动、证据、私人书籍和历史记录均已保留；选定后只会重算当前行动。',
            style: TextStyle(height: 1.5, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: reselectKey,
              onPressed: onReselect,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('查看 10 位导师并重新选择'),
            ),
          ),
        ],
      ),
    );
  }
}
