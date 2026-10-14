import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 计划与复盘：每个计划有状态；没做到要问原因；外部原因必须写绕开办法；
/// 带着修正再来一轮。
class PlansPage extends StatelessWidget {
  const PlansPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> plans = controller.items('plan').reversed.toList();
    final int done = plans.where((ZEntry p) => p.s('st') == '做到了').length;
    final int active = plans.where((ZEntry p) => p.s('st') == '进行中').length;
    return ZPage(
      title: '计划与复盘',
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('没做到不是失败，是线索：问清是认识、动机、手段、环境，还是外部的原因，再带着修正来一轮。'),
        ZNote('进行中 $active　做到了 $done　共 ${plans.length} 个'),
        if (active >= 3)
          const ZNote('进行中的计划有点多：先做完一个，别同时铺太多。', warn: true),
        OutlinedButton(
          onPressed: () => ZNav.open(context, controller, ZDest.engine),
          child: const Text('新建一个计划（改变引擎）'),
        ),
        const SizedBox(height: 8),
        if (plans.isEmpty)
          const ZNote('还没有计划。')
        else
          for (final ZEntry p in plans)
            _PlanCard(key: ValueKey<int?>(p.id), controller: controller, item: p),
      ],
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({super.key, required this.controller, required this.item});

  final ZhaojianController controller;
  final ZEntry item;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late final TextEditingController _fzw =
      TextEditingController(text: widget.item.s('fzw'));
  final TextEditingController _rev = TextEditingController();

  @override
  void dispose() {
    _fzw.dispose();
    _rev.dispose();
    super.dispose();
  }

  Future<void> _redo() async {
    final ZEntry it = widget.item;
    final int rd = (it.i('rd') ?? 1) + 1;
    await widget.controller.addItem('plan', <String, dynamic>{
      'goal': it.s('goal'),
      'cur': it.list('cur'),
      'layer': it.s('layer'),
      'lv': it.list('lv'),
      'env': it.list('env'),
      'act': it.s('act'),
      'chk': it.s('chk'),
      'st': '进行中',
      'fz': '',
      'fzw': '',
      'rd': rd,
      'rev': _rev.text.trim(),
    });
    if (!mounted) return;
    zSnack(context, '第 $rd 轮开始了。');
  }

  @override
  Widget build(BuildContext context) {
    final ZEntry it = widget.item;
    final String st = it.s('st');
    final String fz = it.s('fz');
    final int fzIdx = ZCopy.failReasons.indexOf(fz);
    final bool external = ZCopy.externalFailReasons.contains(fzIdx);
    final List<String> cur = it.list('cur');
    return ZItem(
      warn: st == '没做到',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('第 ${it.i('rd') ?? 1} 轮 · ${it.s('goal')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(it),
              ),
            ],
          ),
          if (it.s('layer').isNotEmpty) ZNote('分诊：${it.s('layer')}'),
          if (cur.length > 1 && cur[1].isNotEmpty) ZNote('想变成：${cur[1]}'),
          Text('最小动作：${it.s('act')}'),
          if (it.s('chk').isNotEmpty) ZNote('检查：${it.s('chk')}'),
          if (it.s('rev').isNotEmpty) ZNote('这一轮的修正：${it.s('rev')}'),
          const ZNote('状态：'),
          zChoice(
            labels: ZCopy.planStates,
            selected: ZCopy.planStates.indexOf(st) < 0 ? null : ZCopy.planStates.indexOf(st),
            onSelect: (int i) {
              it.data['st'] = ZCopy.planStates[i];
              widget.controller.saveItem(it);
            },
          ),
          if (st == '没做到') ...<Widget>[
            const ZNote('主要卡在哪儿？'),
            zChoice(
              labels: ZCopy.failReasons,
              selected: fzIdx < 0 ? null : fzIdx,
              onSelect: (int i) {
                it.data['fz'] = ZCopy.failReasons[i];
                widget.controller.saveItem(it);
              },
            ),
            if (external) ...<Widget>[
              const ZNote('外部原因容易变成借口：先写一个绕开它的办法。这是待验证的猜测，不是结论。', warn: true),
              TextField(
                controller: _fzw,
                minLines: 1,
                maxLines: 3,
                decoration: zInput('绕开办法'),
                onChanged: (String v) {
                  it.data['fzw'] = v.trim();
                  widget.controller.saveItem(it);
                },
              ),
              if (it.s('fzw').isEmpty)
                const ZNote('写了绕开办法，再带着修正来一轮。', warn: true),
            ],
          ],
          if ((st == '没做到' || st == '放弃') && (!external || it.s('fzw').isNotEmpty)) ...<Widget>[
            const SizedBox(height: 6),
            TextField(
              controller: _rev,
              minLines: 1,
              maxLines: 3,
              decoration: zInput('下一轮我要改的是…'),
            ),
            OutlinedButton(onPressed: _redo, child: const Text('带着修正再来一轮')),
          ],
        ],
      ),
    );
  }
}
