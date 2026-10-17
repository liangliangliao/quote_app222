import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 自画像：三层性格、核心与展开、获得性格进度。
class SelfPage extends StatefulWidget {
  const SelfPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<SelfPage> createState() => _SelfPageState();
}

class _SelfPageState extends State<SelfPage> {
  late final TextEditingController _strength =
      TextEditingController(text: widget.controller.kv('ab.s'));
  late final TextEditingController _weak =
      TextEditingController(text: widget.controller.kv('ab.w'));
  late final TextEditingController _limit =
      TextEditingController(text: widget.controller.kv('ab.l'));

  @override
  void dispose() {
    _strength.dispose();
    _weak.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _restore(BuildContext context) async {
    final TextEditingController box = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('从备份恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('把之前复制的备份（JSON）粘贴到这里。恢复会替换现在的全部数据，不能撤销。',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(controller: box, minLines: 4, maxLines: 8, decoration: zInput('备份内容')),
            TextButton(
              onPressed: () async {
                final ClipboardData? d = await Clipboard.getData(Clipboard.kTextPlain);
                if (d?.text != null) box.text = d!.text!;
              },
              child: const Text('从剪贴板粘贴'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('恢复')),
        ],
      ),
    );
    final String raw = box.text;
    box.dispose();
    if (go != true || !context.mounted) return;
    final String? err = await widget.controller.restoreJson(raw);
    if (!context.mounted) return;
    zSnack(context, err ?? '已恢复。');
  }

  Widget _tag(String t) => Chip(
        label: Text(t, style: const TextStyle(fontSize: 12)),
        backgroundColor: zCard,
        visualDensity: VisualDensity.compact,
      );

  Widget _field(String label, TextEditingController c, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZNote(label),
        TextField(
          controller: c,
          minLines: 1,
          maxLines: 3,
          decoration: zInput(''),
          onChanged: (String v) => widget.controller.setKv(key, v.trim()),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ZhaojianController c = widget.controller;
    return ZPage(
      title: '自画像',
      controller: c,
      content: (BuildContext context) {
        final List<ZHypothesis> supported =
            c.hypotheses.where((ZHypothesis h) => h.status == 1).toList();
        final List<ZHypothesis> all = c.hypotheses.reversed.take(6).toList();
        final Map<String, int> reactions =
            countStrings(c.logs.map((ZLog l) => l.reaction));
        final Map<String, int> body = countStrings(<String>[
          for (final ZLog l in c.logs) ...l.body,
          for (final ZDecision d in c.revealed) ...d.body,
        ]);
        final Map<String, int> styles = countStrings(c.revealed
            .where((ZDecision d) => d.jtActual != null)
            .map((ZDecision d) => ZCopy.jamesTypes[d.jtActual!.clamp(0, 4)][0]));
        final double? hit = hitRateOf(c.revealed);
        final List<List<Object>> checks = <List<Object>>[
          <Object>['至少 2 条被行为支持的主线', supported.length >= 2],
          <Object>['行为证据至少 4 条', c.evidenceCount >= 4],
          <Object>[
            '写了长处与界限',
            c.kv('ab.s').isNotEmpty && c.kv('ab.l').isNotEmpty
          ],
          <Object>['选定了一条线', c.kv('line.pick').isNotEmpty],
          <Object>['写了舍弃清单', c.kv('line.drop').isNotEmpty],
          <Object>['至少 1 条自己的原则', c.items('prin').isNotEmpty],
        ];
        final int done = checks.where((List<Object> x) => x[1] == true).length;
        return <Widget>[
          const ZNote(ZCopy.threeLayers),
          ZSection(
            title: '成长闭环',
            children: <Widget>[
              Wrap(
                spacing: 6,
                children: <Widget>[
                  _tag('行为证据 ${c.evidenceCount} 条'),
                  _tag('假设 ${c.hypotheses.length}（被行为支持 ${supported.length}）'),
                  _tag('已开牌 ${c.revealed.length}'),
                  _tag('预测命中 ${zPercent(hit)}'),
                  _tag('自知分 ${totalSelfScore(c.revealed)}'),
                ],
              ),
            ],
          ),
          ZSection(
            title: '睿智性格 · 根',
            children: <Widget>[
              const ZNote('睿智性格不变，也没法直接看见：只有被后来的行为反复支持的主线，才放在这里。'),
              if (supported.isEmpty)
                const ZNote('还没有被行为支持的主线。到「主线与假设」写下假设，之后在行为记录和开牌时标注它。', warn: true)
              else
                for (final ZHypothesis h in supported)
                  ZItem(
                    child: Text(
                        '${h.text}　支持 ${h.sup.length} 次 / 反驳 ${h.ref.length} 次'),
                  ),
            ],
          ),
          ZSection(
            title: '核心与展开',
            children: <Widget>[
              const ZNote('一条主线（核心）会在不同的人生阶段、不同的情境里展开成许多行为。看它展开了多少次，才知道它是稳定的，还是只是那阵子的状态。'),
              if (all.isEmpty)
                const ZNote('还没有假设。')
              else
                for (final ZHypothesis h in all)
                  ZItem(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(h.text,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        ZNote(
                            '展开成 ${c.actsOfHypothesis(h.id ?? -1)} 个行为 · 跨 ${c.phasesOfHypothesis(h.id ?? -1)} 个人生阶段 · 支持 ${h.sup.length} / 反驳 ${h.ref.length}'),
                      ],
                    ),
                  ),
            ],
          ),
          ZSection(
            title: '经验性格 · 从行为里认识',
            children: <Widget>[
              ZNote(reactions.isEmpty
                  ? '还没有行为记录。'
                  : '事后反应：${topCounts(reactions)}'),
              ZNote(body.isEmpty
                  ? '还没有身体信号记录。'
                  : '身体信号：${topCounts(body)}（只是线索，不是诊断）'),
              ZNote(styles.isEmpty
                  ? '还没有开过牌的决定方式记录。'
                  : '你实际的决定方式：${topCounts(styles)}'),
            ],
          ),
          ZSection(
            title: '获得性格 · 我清楚的自己（$done / ${checks.length}）',
            children: <Widget>[
              const ZNote('获得性格是对自己个体性最充分的认识：长处、短处、界限，以及自己立下的原则。'),
              for (final List<Object> x in checks)
                Text('${x[1] == true ? '✓' : '○'} ${x[0]}',
                    style: TextStyle(
                        fontSize: 13,
                        color: x[1] == true ? zAccent : zMuted)),
              const SizedBox(height: 8),
              _field('我的长处（有行为为证的）', _strength, 'ab.s'),
              _field('我的短处（不回避的）', _weak, 'ab.w'),
              _field('我的界限（不会做、不愿做的）', _limit, 'ab.l'),
              const ZNote('这些是你的自述，只算弱证据；用行为记录和开牌去校准它。'),
            ],
          ),
          ZSection(
            title: '我的原则',
            children: <Widget>[
              const ZNote('把从经历里学到的写成原则。原则是对自己的约定，不是给别人的要求。'),
              ZForm(
                fields: const <ZFieldSpec>[
                  ZFieldSpec('t', '原则，例：借钱前先过一夜'),
                  ZFieldSpec('src', '它从哪次经历来（可选）'),
                ],
                mustFill: const <String>['t'],
                submitLabel: '记下原则',
                onSubmit: (Map<String, String> v) async {
                  await c.addItem('prin', <String, dynamic>{'t': v['t'], 'src': v['src']});
                },
              ),
              for (final ZEntry p in c.items('prin').reversed)
                ZItem(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(p.s('t')),
                            if (p.s('src').isNotEmpty) ZNote('来自：${p.s('src')}'),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => c.removeItem(p),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          ZSection(
            title: '数据',
            children: <Widget>[
              const ZNote('全部数据只存在这台设备上。可以复制成 JSON 备份，或带给别人看。'),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: c.exportJson()));
                  if (!context.mounted) return;
                  zSnack(context, '已复制全部数据（JSON）');
                },
                child: const Text('复制全部数据（JSON）'),
              ),
              OutlinedButton(
                onPressed: () => _restore(context),
                child: const Text('从备份恢复（会替换现有全部数据）'),
              ),
              TextButton(
                onPressed: () => ZNav.open(context, c, ZDest.map),
                child: const Text('看思想地图：每个理论接在哪里'),
              ),
            ],
          ),
        ];
      },
    );
  }
}
