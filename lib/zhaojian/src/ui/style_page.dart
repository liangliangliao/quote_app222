import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 决策方式：你实际是怎样做决定的（詹姆斯五种），以及预测与实际的差距。
class StylePage extends StatelessWidget {
  const StylePage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  Widget build(BuildContext context) {
    return ZPage(
      title: '决策方式',
      controller: controller,
      content: (BuildContext context) {
        final List<ZDecision> rev = controller.revealed
            .where((ZDecision d) => d.jtActual != null)
            .toList();
        final List<int> counts = List<int>.filled(5, 0);
        for (final ZDecision d in rev) {
          counts[d.jtActual!.clamp(0, 4)] += 1;
        }
        final int total = rev.length;
        int top = 0;
        for (int i = 1; i < 5; i++) {
          if (counts[i] > counts[top]) top = i;
        }
        final List<ZDecision> both = rev
            .where((ZDecision d) => d.jtPred != null)
            .toList();
        final int agree = both
            .where((ZDecision d) => d.jtPred == d.jtActual)
            .length;
        final ZWinStat win = winStat(controller.revealed);
        final Set<int> miss = topMissCategories(controller.misses);
        return <Widget>[
          const ZNote('分类依据詹姆斯《心理学原理》，据二手资料整理，措辞请核对原文。这里记录的是你实际怎样做决定，不是评价好坏。'),
          ZSection(
            title: '你实际的决定方式',
            children: <Widget>[
              if (total == 0)
                const ZNote('还没有数据。开牌时选「这次决定是怎么发生的」，积累后这里显示分布。', warn: true)
              else ...<Widget>[
                for (int i = 0; i < 5; i++)
                  ZBar(
                    label:
                        '${ZCopy.jamesTypes[i][0]} ${counts[i]} 次（${zPercent(counts[i] / total)}）· ${ZCopy.jamesTypes[i][1]}',
                    value: counts[i] / total,
                  ),
                ZItem(
                  child: Text(
                      '最常见：${ZCopy.jamesTypes[top][0]}。${ZCopy.jamesTypes[top][2]}'),
                ),
                const ZNote('样本小时别下结论；决定方式会随事情大小和状态变化。'),
              ],
            ],
          ),
          ZSection(
            title: '预测的方式 vs 实际的方式',
            children: <Widget>[
              if (both.length < 3)
                ZNote('封存和开牌时都选了决定方式的决定还不到 3 个（现在 ${both.length} 个）。')
              else
                Text('预计的决定方式与实际一致：$agree / ${both.length}（${zPercent(agree / both.length)}）'),
            ],
          ),
          ZSection(
            title: '抽象与直观冲突时',
            children: <Widget>[
              ZNote(win.total == 0
                  ? '还没有「抽象与直观动机指向不同选项」的已开牌决定。'
                  : '跟了直观 ${win.intuitive} 次，跟了抽象 ${win.abstractWins} 次。详见「成长回顾」。'),
            ],
          ),
          ZSection(
            title: '常漏掉的动机类别',
            children: <Widget>[
              ZNote(miss.isEmpty
                  ? '开牌时登记「天平漏了什么动机」，积累后这里显示。'
                  : miss.map((int c) => ZCopy.categories[c]).join('、')),
            ],
          ),
        ];
      },
    );
  }
}
