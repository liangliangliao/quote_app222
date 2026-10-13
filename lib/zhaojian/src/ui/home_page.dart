import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 照见首页：因果链主轴、下一步、按「选择 / 行动 / 改变 / 我 / 方向」分组的入口。
class ZhaojianHomePage extends StatelessWidget {
  const ZhaojianHomePage({super.key, required this.controller});

  final ZhaojianController controller;

  String _nextStep() {
    final int pending = controller.pending.length;
    if (pending > 0) return '有 $pending 张牌还没开：现场发生后，到「未开的牌」开牌。';
    if (controller.decisions.isEmpty) return '拿一个真实、正在纠结的选择，走一遍「决策」。';
    if (controller.hypotheses.isEmpty) {
      return '写下一条关于自己的假设（主线），之后记录行为时标注它表达了哪条主线。';
    }
    return '保持节奏：做新的选择、开牌、记录行为，让对自己的认识再校准一圈。';
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
        ZItem(child: Text(_nextStep())),
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
