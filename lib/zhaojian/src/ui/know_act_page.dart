import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 知行（王阳明）：愿望 → 决意 → 行动，看在哪里掉下去；
/// 抽象动机说该做、行动却跟了直观动机的那些决定，诊断知行落差。
class KnowActPage extends StatelessWidget {
  const KnowActPage({super.key, required this.controller});

  final ZhaojianController controller;

  Widget _gapCard(BuildContext context, ZDecision d) {
    final ZSums s = sumMotives(d.motives);
    final String abs = absLean(s) == 'a' ? d.optionA : d.optionB;
    final String did = d.actual == 'a' ? d.optionA : d.optionB;
    final String key = 'zx.${d.id}';
    final int cur = int.tryParse(controller.kv(key, '-1')) ?? -1;
    return ZItem(
      warn: cur < 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(d.question.isEmpty ? '(未写问题)' : d.question,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          ZNote('抽象动机指向：$abs　行动实际：$did'),
          const ZNote('知而不行，卡在哪儿？'),
          zChoice(
            labels: ZCopy.knowActKinds.map((List<String> g) => g[0]).toList(),
            selected: cur < 0 ? null : cur,
            onSelect: (int i) => controller.setKv(key, '$i'),
          ),
          if (cur >= 0) ...<Widget>[
            ZNote(ZCopy.knowActKinds[cur][1]),
            if (cur == 4)
              const ZNote('外部障碍要写绕开办法，否则容易变成借口：去「计划与复盘」里记。', warn: true),
            TextButton(
              onPressed: () => ZNav.open(context, controller, ZDest.engine),
              child: const Text('把它变成一个改变计划'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ZDecision> gaps = knowActGaps(controller.revealed);
    final ZWinStat win = winStat(controller.revealed);
    final List<ZEntry> nian = controller.items('nian').reversed.toList();
    final ZFunnel f = funnelOf(nian.map((ZEntry e) => e.i('st') ?? 0));
    final List<ZEntry> xc = controller.items('xc').reversed.toList();
    return ZPage(
      title: '知行',
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('王阳明说，知是行的主意，行是知的功夫；知而不行，只是未知。这里不评判，只看你在哪一步掉下去。'),
        ZSection(
          title: '知行合一度',
          children: <Widget>[
            if (win.total == 0)
              const ZNote('还没有「抽象与直观动机指向不同选项」的已开牌决定。')
            else
              Text('抽象与直观冲突的 ${win.total} 次里，行动跟了抽象 ${win.abstractWins} 次（${zPercent(win.abstractWins / win.total)}）。'),
            const ZNote('「抽象」大致对应你事先想清楚的，「直观」对应到现场才出场的。'),
          ],
        ),
        ZSection(
          title: '知行落差诊断（${gaps.length}）',
          children: gaps.isEmpty
              ? const <Widget>[ZNote('没有落差记录：要么都做到了，要么还没开过这类牌。')]
              : gaps.reversed.map((ZDecision d) => _gapCard(context, d)).toList(),
        ),
        ZSection(
          title: '愿望漏斗',
          children: <Widget>[
            const ZNote('愿望只显出人类共有的一面；写下代价、替代，才算决意，才显出你个人的性格。再做出来，才是行动。'),
            if (f.wish > 0)
              Text('愿望 ${f.wish} → 决意 ${f.resolve}（${zPercent(f.wishToResolve)}）→ 行动 ${f.act}（${zPercent(f.resolveToAct)}）'),
            ZForm(
              fields: const <ZFieldSpec>[ZFieldSpec('t', '我想…（一个愿望）', lines: 2)],
              mustFill: const <String>['t'],
              submitLabel: '放进漏斗',
              onSubmit: (Map<String, String> v) async {
                await controller.addItem('nian', <String, dynamic>{
                  't': v['t'],
                  'st': 0,
                  'cost': '',
                  'alt': '',
                  'r': '',
                });
              },
            ),
            if (nian.isEmpty) const ZNote('还没有愿望。') else
              for (final ZEntry e in nian)
                _NianCard(key: ValueKey<int?>(e.id), controller: controller, item: e),
          ],
        ),
        ZSection(
          title: '事上磨练',
          children: <Widget>[
            const ZNote('道理在事上练：今天挑一件小事当练习，别等大事。能系绳子就系绳子，能做实验就做实验。'),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => ZNav.open(context, controller, ZDest.rope),
                  child: const Text('系一根绳子'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => ZNav.open(context, controller, ZDest.wall),
                  child: const Text('做个小实验'),
                ),
              ],
            ),
          ],
        ),
        ZSection(
          title: '念头省察',
          children: <Widget>[
            const ZNote('念头一起，就看一眼：它从哪儿来？该顺它，还是该放下？不评判，只看见。'),
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('t', '刚才起的念头'),
                ZFieldSpec('src', '它从哪儿来（习惯 / 眼前的刺激 / 别人的话 / 我真正想要的）'),
                ZFieldSpec('act', '我怎么处理它'),
              ],
              mustFill: const <String>['t'],
              submitLabel: '记一次省察',
              onSubmit: (Map<String, String> v) async {
                await controller.addItem('xc', <String, dynamic>{
                  't': v['t'],
                  'src': v['src'],
                  'act': v['act'],
                });
              },
            ),
            for (final ZEntry e in xc.take(8))
              ZItem(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.s('t')),
                          if (e.s('src').isNotEmpty || e.s('act').isNotEmpty)
                            ZNote('来自：${e.s('src')}　处理：${e.s('act')}'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => controller.removeItem(e),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NianCard extends StatefulWidget {
  const _NianCard({super.key, required this.controller, required this.item});

  final ZhaojianController controller;
  final ZEntry item;

  @override
  State<_NianCard> createState() => _NianCardState();
}

class _NianCardState extends State<_NianCard> {
  late final TextEditingController _cost =
      TextEditingController(text: widget.item.s('cost'));
  late final TextEditingController _alt =
      TextEditingController(text: widget.item.s('alt'));

  @override
  void dispose() {
    _cost.dispose();
    _alt.dispose();
    super.dispose();
  }

  Future<void> _set(String key, String v) async {
    widget.item.data[key] = v.trim();
    await widget.controller.saveItem(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final ZEntry it = widget.item;
    final int st = it.i('st') ?? 0;
    final bool canResolve = _cost.text.trim().isNotEmpty && _alt.text.trim().isNotEmpty;
    final int rIdx = ZCopy.reactions.indexOf(it.s('r'));
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${ZCopy.nianStages[st.clamp(0, 2)]} · ${it.s('t')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(it),
              ),
            ],
          ),
          if (st == 0) ...<Widget>[
            const ZNote('要成为决意，先写下代价和替代：做这件事我要付出什么，不做的话我用什么顶上。'),
            TextField(
              controller: _cost,
              decoration: zInput('代价'),
              onChanged: (String v) {
                _set('cost', v);
                setState(() {});
              },
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _alt,
              decoration: zInput('替代'),
              onChanged: (String v) {
                _set('alt', v);
                setState(() {});
              },
            ),
            FilledButton(
              onPressed: canResolve
                  ? () {
                      it.data['st'] = 1;
                      widget.controller.saveItem(it);
                    }
                  : null,
              child: const Text('定为决意'),
            ),
          ] else ...<Widget>[
            ZNote('代价：${it.s('cost')}　替代：${it.s('alt')}'),
            if (st == 1) ...<Widget>[
              const ZNote('做了之后，第一反应是什么？选了才能记为行动。'),
              zChoice(
                labels: ZCopy.reactions,
                selected: rIdx < 0 ? null : rIdx,
                onSelect: (int i) {
                  it.data['r'] = ZCopy.reactions[i];
                  widget.controller.saveItem(it);
                },
              ),
              FilledButton(
                onPressed: rIdx < 0
                    ? null
                    : () {
                        it.data['st'] = 2;
                        widget.controller.saveItem(it);
                      },
                child: const Text('已经做了'),
              ),
            ] else
              ZNote('做了。事后：${it.s('r')}'),
          ],
        ],
      ),
    );
  }
}
