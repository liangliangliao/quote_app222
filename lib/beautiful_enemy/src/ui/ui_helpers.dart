import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/enemy_engine.dart';

const Color kEnemyBg = Color(0xFF14100F);
const Color kEnemyCard = Color(0xFF221A19);
const Color kEnemyAccent = Color(0xFFE0654F);
const Color kEnemyText = Color(0xFFF3E9E6);
const Color kEnemyMuted = Color(0xFFB9A29D);

String fmtTime(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String fmtRemaining(int dueMs, int nowMs) {
  final int diff = dueMs - nowMs;
  if (diff <= 0) return '已到期';
  final int minutes = (diff / 60000).ceil();
  if (minutes < 60) return '还剩 $minutes 分钟';
  final int hours = (minutes / 60).floor();
  if (hours < 48) return '还剩 $hours 小时';
  return '还剩 ${(hours / 24).floor()} 天';
}

const Map<String, String> _eventLabels = <String, String>{
  'habit_done': '习惯完成',
  'habit_missed': '习惯未完成',
  'habit_skipped': '习惯跳过',
  'kindling_completed': '火种十五分钟完成',
  'kindling_aborted': '火种中途退出',
  'knowledge_converted': '知识卡转换',
  'journal_entry': '行为记录',
  'commitment_created': '立下承诺',
  'commitment_done': '承诺兑现',
  'commitment_missed': '承诺失效',
  'commitment_excused': '承诺豁免',
};

String eventLine(EnemyEvent e) {
  final String base = _eventLabels[e.type] ?? e.type;
  final String label = e.label.trim();
  return label.isEmpty ? base : '$base · $label';
}

const Map<String, String> commitmentStatusLabels = <String, String>{
  CommitmentStatus.open: '进行中',
  CommitmentStatus.done: '已兑现',
  CommitmentStatus.missed: '已失效',
  CommitmentStatus.excused: '已豁免',
};

/// 单行文本输入对话框。取消返回 null。
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  String confirm = '确定',
  int maxLines = 3,
}) {
  final TextEditingController controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: kEnemyCard,
        title: Text(title, style: const TextStyle(color: kEnemyText, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          minLines: 1,
          style: const TextStyle(color: kEnemyText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kEnemyMuted),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(confirm),
          ),
        ],
      );
    },
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirm = '确定',
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: kEnemyCard,
      title: Text(title, style: const TextStyle(color: kEnemyText, fontSize: 16)),
      content: Text(body, style: const TextStyle(color: kEnemyMuted)),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}

/// 点开证据：列出判词引用的每一条原始记录。
Future<void> showEvidenceSheet(
  BuildContext context,
  EnemyEngine engine,
  List<int> ids,
) async {
  final List<EnemyEvent> events = await engine.dao.eventsByIds(ids);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: kEnemyCard,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('证据', style: TextStyle(color: kEnemyText, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (events.isEmpty)
                const Text('这些证据已被清除。', style: TextStyle(color: kEnemyMuted))
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final EnemyEvent e in events)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(eventLine(e), style: const TextStyle(color: kEnemyText)),
                          subtitle: Text(
                            '#${e.id} · ${fmtTime(e.ts)}',
                            style: const TextStyle(color: kEnemyMuted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
