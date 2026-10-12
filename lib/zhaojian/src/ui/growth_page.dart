import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 成长回顾：命中率、谁胜出、自由感、想象深度、反应与身体信号、常漏的动机。
class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key, required this.controller});

  final ZhaojianController controller;

  Map<String, int> _count(Iterable<String> items) {
    final Map<String, int> c = <String, int>{};
    for (final String s in items) {
      if (s.isEmpty) continue;
      c[s] = (c[s] ?? 0) + 1;
    }
    return c;
  }

  String _top(Map<String, int> c, {int n = 7}) {
    final List<MapEntry<String, int>> es = c.entries.toList()
      ..sort((MapEntry<String, int> x, MapEntry<String, int> y) =>
          y.value.compareTo(x.value));
    return es
        .take(n)
        .map((MapEntry<String, int> e) => '${e.key} ${e.value}')
        .join('　');
  }

  Widget _hitSection(List<ZDecision> rev) {
    final int hits = rev.where((ZDecision d) => d.hit).length;
    final List<Widget> kids = <Widget>[
      if (rev.isEmpty)
        const ZNote('还没有开过的牌。')
      else
        Text('自知分 ${totalSelfScore(rev)}；预测命中 $hits / ${rev.length}'),
    ];
    if (rev.length >= 2) {
      final ({List<ZDecision> early, List<ZDecision> recent}) h =
          splitHalves(rev);
      kids.add(ZNote(
          '命中率：早期 ${zPercent(hitRateOf(h.early))} → 近期 ${zPercent(hitRateOf(h.recent))}。记录越多，对比越有意义。'));
    }
    return ZSection(title: '自知分与命中率', children: kids);
  }

  Widget _winSection(List<ZDecision> rev) {
    final ZWinStat w = winStat(rev);
    if (w.total < 3) {
      return ZSection(
        title: '当抽象与直观动机冲突时，谁胜出？',
        children: <Widget>[
          ZNote('需要至少 3 个「抽象与直观动机指向不同选项」的已开牌决定（现在 ${w.total} 个）。'
              '叔本华说大事多由抽象动机决定、小事多由眼前印象决定：这是可以用你的数据检验的。'),
        ],
      );
    }
    final List<String> byLevel = <String>[];
    int bigAbs = 0, bigInt = 0;
    for (final String lv in ZCopy.importanceLevels) {
      int i = 0, a = 0;
      for (final ZDecision d in rev) {
        if (d.importance != lv) continue;
        final String? f = followedKind(d);
        if (f == '直观') i += 1;
        if (f == '抽象') a += 1;
      }
      if (i + a > 0) byLevel.add('$lv事：直观 $i，抽象 $a');
      if (lv == '大') {
        bigAbs = a;
        bigInt = i;
      }
    }
    final String support = bigAbs + bigInt >= 2
        ? (bigAbs > bigInt ? '支持' : '不支持')
        : '样本不足';
    final String advice = w.intuitive > w.abstractWins
        ? '你多半被现场的直观动机带走：优先用绳子、蜡和环境设计，不要靠现场硬撑。'
        : (w.abstractWins > w.intuitive
            ? '你多半能让抽象动机做主：重点是补全认识、检查目标，别想错、想太多。'
            : '直观和抽象各占一半。');
    return ZSection(
      title: '当抽象与直观动机冲突时，谁胜出？',
      children: <Widget>[
        Text('冲突时你的行动：跟了直观 ${w.intuitive} 次，跟了抽象 ${w.abstractWins} 次（共 ${w.total} 次）。'),
        if (byLevel.isNotEmpty) ZNote('${byLevel.join('；')}。'),
        ZNote('$advice 对「大事多由抽象动机决定」这一说法，你的数据：$support。'
            '动机权重是你事先自己填的，可能带着倾向，样本小时别下结论。'),
      ],
    );
  }

  Widget _freedomSection(List<ZDecision> rev) {
    final ZFreedomStat? f = freedomStat(rev);
    if (f == null) {
      return const ZSection(
        title: '自由感与可预测性',
        children: <Widget>[
          ZNote('需要至少 6 个已开牌、并记录了「自由感」的决定，且高低有差异。'
              '叔本华说，从知性看两边似乎同样可能，这是「经验意志自由」的错觉。'
              '这里看：你觉得两边都有可能时，你的行为其实有多可预测。'),
        ],
      );
    }
    return ZSection(
      title: '自由感与可预测性',
      children: <Widget>[
        Text('觉得两边都很有可能（${f.highCount} 个）：预测命中 ${zPercent(f.highHit)}'),
        Text('觉得相对明确（${f.lowCount} 个）：预测命中 ${zPercent(f.lowHit)}'),
        const ZNote('如果前一组命中率仍然不低，说明「觉得两边都可能」并不等于「你的行为不可预测」。'
            '但这只说明你的行为对你自己可预测，不能证明决定论；知道行为可预测，不等于可以不努力：努力本身就是因果链上的一环。样本小时别下结论。'),
      ],
    );
  }

  Widget _imagerySection(List<ZDecision> rev) {
    final ZImageryStat? s = imageryStat(rev);
    if (s == null) {
      return const ZSection(
        title: '想象深度有用吗？',
        children: <Widget>[
          ZNote('需要至少 6 个已开牌、并做过想象记录的决定才能比较。'
              '想象越深的决定，是否预测更准？这是个可以被数据否定的说法。'),
        ],
      );
    }
    return ZSection(
      title: '想象深度有用吗？',
      children: <Widget>[
        Text('想象较深（${s.deepCount} 个）：预测命中 ${zPercent(s.deepHit)}'),
        Text('想象较浅（${s.shallowCount} 个）：预测命中 ${zPercent(s.shallowHit)}'),
        const ZNote('这只是相关，不是因果；样本小时别下结论。如果想象深的决定并没有更准，说明想象对你没那么管用，可以少花精力。'),
      ],
    );
  }

  Widget _alignSection(List<ZDecision> rev) {
    final ({double? early, double? recent})? t = alignTrend(rev);
    String f(double? v) => v == null ? '-' : v.round().toString();
    return ZSection(
      title: '选择贴近欲求吗？',
      children: <Widget>[
        ZNote(t == null
            ? '做过「一致度与难度」并且开过牌的决定还不到 2 个。看的是：你实际选的那一项，对你所选欲求的一年一致度，是不是越来越高。'
            : '所选项的一年一致度：早期 ${f(t.early)} → 近期 ${f(t.recent)}（50 表示无关）。'
                '一致度来自你对照的欲求假设，欲求若变了，这里的数也会变；样本小时别下结论。'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<ZDecision> rev = controller.revealed;
        final Map<String, int> reactions =
            _count(controller.logs.map((ZLog l) => l.reaction));
        final Map<String, int> body = _count(<String>[
          for (final ZLog l in controller.logs) ...l.body,
          for (final ZDecision d in rev) ...d.body,
        ]);
        final Map<String, int> miss = _count(controller.misses
            .where((ZMiss m) => m.cat >= 0 && m.cat < ZCopy.categories.length)
            .map((ZMiss m) => ZCopy.categories[m.cat]));
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('成长回顾'),
            backgroundColor: Colors.white,
            foregroundColor: zInk,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              const ZNote('按叔本华，根本欲求不变，所以「成长」看三件事：认识更准（预测更接近行为）、行为更像自己、手段更有效。'),
              _hitSection(rev),
              _winSection(rev),
              _freedomSection(rev),
              _imagerySection(rev),
              _alignSection(rev),
              ZSection(
                title: '反应与身体信号',
                children: <Widget>[
                  ZNote(reactions.isEmpty ? '还没有行为记录。' : '事后反应：${_top(reactions)}'),
                  ZNote(body.isEmpty
                      ? '还没有身体信号记录。'
                      : '身体信号：${_top(body)}。身体信号只是线索，不是诊断；系统不做相貌或体型分析。'),
                ],
              ),
              ZSection(
                title: '我常漏掉的动机',
                children: <Widget>[
                  ZNote(miss.isEmpty
                      ? '开牌时如果行动和天平相悖、或预测落空，会问你「什么动机没被列出」。积累后这里显示你常漏掉的类别。'
                      : '常漏的类别：${_top(miss, n: 3)}。AI 补全动机和前 5 推荐时会多留意它们。'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
