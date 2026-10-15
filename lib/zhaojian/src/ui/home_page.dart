import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 一条「下一步」提示。
class _Hint {
  const _Hint(this.text, this.dest, {this.warn = false});

  final String text;
  final ZDest? dest;
  final bool warn;
}

/// 照见首页：因果链主轴、下一步、按「选择 / 行动 / 改变 / 我 / 方向」分组的入口。
class ZhaojianHomePage extends StatelessWidget {
  const ZhaojianHomePage({super.key, required this.controller});

  final ZhaojianController controller;

  /// 按进度动态生成的下一步提示，最多 3 条，重要的在前。
  List<_Hint> _hints() {
    final List<_Hint> out = <_Hint>[];
    final int pending = controller.pending.length;
    if (pending > 0) {
      out.add(_Hint('有 $pending 张牌还没开：现场发生后，去开牌。', ZDest.pending));
    }
    if (controller.decisions.isEmpty) {
      out.add(const _Hint('拿一个真实、正在纠结的选择，走一遍「决策」。', ZDest.decide));
    }
    if (controller.hypotheses.isEmpty) {
      out.add(const _Hint('写下一条关于自己的假设（主线），之后记录行为时标注它表达了哪条主线。', ZDest.hypothesis));
    }
    final int ev = controller.evidenceCount;
    if (ev < analysisMinEvidence) {
      out.add(_Hint('行为证据只有 $ev 条，不到 $analysisMinEvidence 条：补几条行为考古或行为记录。', ZDest.evidence));
    }
    final int threads = controller.activeThreads;
    if (threads >= 3) {
      out.add(_Hint('手上同时进行着 $threads 件事（计划、假设行动、探测、放弃实验）：先收敛，再开新的。', ZDest.line, warn: true));
    }
    final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final int stale = controller
        .items('plan')
        .where((ZEntry p) => p.s('st') == '进行中' && p.updatedAt.isBefore(weekAgo))
        .length;
    if (stale > 0) {
      out.add(_Hint('有 $stale 个计划超过 7 天没动了：去复盘，没做到是线索，不是失败。', ZDest.plans, warn: true));
    }
    final int supported =
        controller.hypotheses.where((ZHypothesis h) => h.status == 1).length;
    if (controller.kv('line.pick').isEmpty && supported >= 2) {
      out.add(const _Hint('已有两条以上被行为支持的主线：可以选定一条线，写下舍弃清单。', ZDest.line));
    }
    if (ev >= analysisMinEvidence && controller.items('ana').isEmpty) {
      out.add(const _Hint('证据够了：可以让 AI 分析一版（暂定的假设，不是诊断）。', ZDest.analysis));
    }
    if (out.isEmpty) {
      out.add(const _Hint('保持节奏：做新的选择、开牌、记录行为，让对自己的认识再校准一圈。', null));
    }
    return out.take(3).toList();
  }

  Widget _hintCard(BuildContext context, _Hint h) {
    final ZDest? d = h.dest;
    return ZItem(
      warn: h.warn,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(h.text)),
          if (d != null && ZNav.isReady(d))
            TextButton(
              onPressed: () => ZNav.open(context, controller, d),
              child: const Text('去'),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, ZDest d) {
    final ZDestInfo i = ZNav.info[d]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: zCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ZNav.open(context, controller, d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(i.icon, color: zAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        i.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: zInk,
                        ),
                      ),
                      Text(
                        i.subtitle,
                        style: const TextStyle(fontSize: 12, color: zMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: zMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZPage(
      title: ZCopy.title,
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote(ZCopy.chainLine),
        const ZNote(ZCopy.principle),
        const SizedBox(height: 6),
        for (final _Hint h in _hints()) _hintCard(context, h),
        for (final String g in ZNav.groups)
          if (ZNav.inGroup(g).isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                g,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: zMuted,
                ),
              ),
            ),
            for (final ZDest d in ZNav.inGroup(g)) _tile(context, d),
          ],
        const SizedBox(height: 8),
        const ZNote(ZCopy.redLine),
      ],
    );
  }
}
