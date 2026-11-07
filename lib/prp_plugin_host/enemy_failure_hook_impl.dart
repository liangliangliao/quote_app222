import 'package:flutter/material.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../prp_plugin/prp_plugin.dart';

/// 把美丽的敌人的“失败之后”钩子接到 PRP 插件上。
/// 插件关闭或没接上时，所有方法都等同于 Noop，敌人走自己原有的流程。
class PrpEnemyFailureHook extends EnemyFailureHook {
  const PrpEnemyFailureHook();

  static String _fmt(int ms) {
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Future<bool> onMissed(
    BuildContext context,
    EnemyEngine engine,
    EnemyCommitmentInfo info,
  ) async {
    final PrpMissedResult r = await PrpPlugin.instance.handleMissed(
      context,
      PrpSignal(
        surface: PrpSurface.enemy,
        kind: 'commitment_missed',
        subjectKey: 'commitment:${info.id}',
        expected: info.text,
        facts: <String>[
          '立下时间：${_fmt(info.createdMs)}',
          if (info.dueMs != null) '到期时间：${_fmt(info.dueMs!)}',
          '状态：没做到',
        ],
        userInitiated: true,
        tsMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    // 会话里出现危机内容：敌人沿用自己的安全阀，静音一段时间。
    if (r.crisis) {
      try {
        await engine.muteFor24h(crisis: true);
      } catch (_) {}
    }
    return r.handled;
  }

  @override
  Future<void> onCommitmentCreated(EnemyCommitmentInfo info) =>
      PrpPlugin.instance.linkNewCommitment('commitment:${info.id}', info.text);

  @override
  Widget commitmentHint(BuildContext context, TextEditingController text) =>
      PrpPlugin.instance.commitmentHint(text);

  @override
  Widget lessonsHeader(BuildContext context) => PrpPlugin.instance.playbook();
}
