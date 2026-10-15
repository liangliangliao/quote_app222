import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 目标链（尼采：有了「为什么」，几乎任何「怎么做」都能忍受）：
/// 把一个目标追问到底，终点配一个具体的画面，并问一句：这是我自己要的吗？
class GoalPage extends StatelessWidget {
  const GoalPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> goals = controller.items('goal').reversed.toList();
    return ZPage(
      title: '目标链',
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('一个目标往下追问「为什么」，追到不能再追的地方，那里才是你真正要的。终点要配一个具体的画面，不然只是口号。'),
        ZSection(
          title: '一个目标',
          children: <Widget>[
            ZForm(
              fields: const <ZFieldSpec>[ZFieldSpec('top', '我想要…', lines: 2)],
              mustFill: const <String>['top'],
              submitLabel: '开始追问',
              onSubmit: (Map<String, String> v) async {
                await controller.addItem('goal', <String, dynamic>{
                  'top': v['top'],
                  'chain': <String>[],
                  'pic': '',
                  'own': '',
                  'done': false,
                });
              },
            ),
          ],
        ),
        if (goals.isEmpty)
          const ZNote('还没有目标。')
        else
          for (final ZEntry g in goals)
            _GoalCard(key: ValueKey<int?>(g.id), controller: controller, item: g),
      ],
    );
  }
}

class _GoalCard extends StatefulWidget {
  const _GoalCard({super.key, required this.controller, required this.item});

  final ZhaojianController controller;
  final ZEntry item;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  final TextEditingController _why = TextEditingController();
  late final TextEditingController _pic =
      TextEditingController(text: widget.item.s('pic'));

  @override
  void dispose() {
    _why.dispose();
    _pic.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final String t = _why.text.trim();
    if (t.isEmpty) {
      zSnack(context, '先回答这一层的「为什么」');
      return;
    }
    final List<String> chain = widget.item.list('chain')..add(t);
    widget.item.data['chain'] = chain;
    await widget.controller.saveItem(widget.item);
    if (!mounted) return;
    setState(_why.clear);
  }

  @override
  Widget build(BuildContext context) {
    final ZEntry it = widget.item;
    final List<String> chain = it.list('chain');
    final bool done = it.b('done');
    final int ownIdx = ZCopy.goalOwn.indexOf(it.s('own'));
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('想要：${it.s('top')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(it),
              ),
            ],
          ),
          for (int i = 0; i < chain.length; i++)
            Text('${'　' * i}↳ 为什么 ${i + 1}：${chain[i]}'),
          if (!done) ...<Widget>[
            const SizedBox(height: 6),
            TextField(
              controller: _why,
              minLines: 1,
              maxLines: 3,
              decoration: zInput('为什么想要「${chain.isEmpty ? it.s('top') : chain.last}」？'),
            ),
            Row(
              children: <Widget>[
                FilledButton(onPressed: _ask, child: const Text('再问一层')),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: chain.length >= 2
                      ? () {
                          it.data['done'] = true;
                          widget.controller.saveItem(it);
                        }
                      : null,
                  child: const Text('追到底了'),
                ),
              ],
            ),
            if (chain.length < 2) const ZNote('至少追问两层，才算追到了根。'),
          ] else ...<Widget>[
            const ZNote('终点配一个具体的画面：那时你在哪儿、在做什么、身边有谁？'),
            TextField(
              controller: _pic,
              minLines: 1,
              maxLines: 3,
              decoration: zInput('终点的画面'),
              onChanged: (String v) {
                it.data['pic'] = v.trim();
                widget.controller.saveItem(it);
              },
            ),
            const ZNote('这个终点，是我自己要的吗？'),
            zChoice(
              labels: ZCopy.goalOwn,
              selected: ownIdx < 0 ? null : ownIdx,
              onSelect: (int i) {
                it.data['own'] = ZCopy.goalOwn[i];
                widget.controller.saveItem(it);
              },
            ),
            if (it.s('own') == '主要来自别人')
              const ZNote('终点主要来自别人的期待：先到「一致度」或「接受」里分清，哪些是你自己要的。', warn: true),
            if (it.s('pic').isEmpty) const ZNote('没有画面的终点只是口号。', warn: true),
            TextButton(
              onPressed: () => ZNav.open(context, widget.controller, ZDest.line),
              child: const Text('去「一条线」选定与舍弃'),
            ),
          ],
        ],
      ),
    );
  }
}
