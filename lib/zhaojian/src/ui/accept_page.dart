import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 接受：控制圈。分清哪些该改、哪些只能影响、哪些不可控。
/// 对不可控的事，只有先写过绕开办法、并确认它不会因为你的努力而改变，才给「必然性」的安慰。
class AcceptPage extends StatefulWidget {
  const AcceptPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<AcceptPage> createState() => _AcceptPageState();
}

class _AcceptPageState extends State<AcceptPage> {
  static const List<String> _levels = <String>['控制内', '可影响', '不可控'];

  final TextEditingController _t = TextEditingController();
  int _level = 0;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String t = _t.text.trim();
    if (t.isEmpty) {
      zSnack(context, '先写下这件事');
      return;
    }
    await widget.controller.addItem('acc', <String, dynamic>{
      't': t,
      'c': _level,
      'by': '',
      'fx': false,
    });
    if (!mounted) return;
    setState(() => _t.clear());
  }

  @override
  Widget build(BuildContext context) {
    final ZhaojianController c = widget.controller;
    final List<ZEntry> all = c.items('acc');
    return ZPage(
      title: '接受',
      controller: c,
      content: (BuildContext context) => <Widget>[
        const ZNote('把让你烦恼的事放进三个圈：控制内（我能直接改）、可影响（我能影响但不能保证）、不可控（我改不了）。精力放在前两个圈。'),
        ZSection(
          title: '放进一件事',
          children: <Widget>[
            TextField(controller: _t, decoration: zInput('这件事是…')),
            ZGuard(controllers: <TextEditingController>[_t], app: c),
            zChoice(
              labels: _levels,
              selected: _level,
              onSelect: (int i) => setState(() => _level = i),
            ),
            const SizedBox(height: 6),
            FilledButton(onPressed: _add, child: const Text('放进去')),
          ],
        ),
        for (int lv = 0; lv < 3; lv++)
          ZSection(
            title: '${_levels[lv]}（${all.where((ZEntry e) => e.i('c') == lv).length}）',
            children: <Widget>[
              if (lv == 0)
                const ZNote('能直接改的：去「改变引擎」设计一个最小动作。')
              else if (lv == 1)
                const ZNote('只能影响的：做你能做的那一部分，结果交给别人和时机。'),
              for (final ZEntry e in all.where((ZEntry x) => x.i('c') == lv).toList().reversed)
                _AcceptCard(key: ValueKey<int?>(e.id), controller: c, item: e),
            ],
          ),
      ],
    );
  }
}

class _AcceptCard extends StatefulWidget {
  const _AcceptCard({super.key, required this.controller, required this.item});

  final ZhaojianController controller;
  final ZEntry item;

  @override
  State<_AcceptCard> createState() => _AcceptCardState();
}

class _AcceptCardState extends State<_AcceptCard> {
  late final TextEditingController _by =
      TextEditingController(text: widget.item.s('by'));

  @override
  void dispose() {
    _by.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ZEntry it = widget.item;
    final int level = it.i('c') ?? 0;
    final bool fixed = it.b('fx');
    final bool comfort = acceptComfortAllowed(
      control: level,
      bypass: it.s('by'),
      confirmedFixed: fixed,
    );
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(it.s('t'))),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(it),
              ),
            ],
          ),
          if (level == 2) ...<Widget>[
            const ZNote('先别急着放下：写下你试过、或能想到的绕开办法（换条路、借助他人、改目标）。'),
            TextField(
              controller: _by,
              minLines: 1,
              maxLines: 3,
              decoration: zInput('绕开办法'),
              onChanged: (String v) {
                it.data['by'] = v.trim();
                widget.controller.saveItem(it);
              },
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('我确认：它不会因为我的努力而改变',
                  style: TextStyle(fontSize: 14)),
              value: fixed,
              onChanged: (bool? v) {
                it.data['fx'] = v == true;
                widget.controller.saveItem(it);
              },
            ),
            if (comfort)
              const ZItem(
                child: Text(
                  '你已经想过绕开它的办法，也确认它不会因为你的努力而改变。现在放下的不是责任，而是不属于你的那一部分。必然的事，不必再用愤怒或愧疚去对抗。',
                  style: TextStyle(height: 1.6),
                ),
              )
            else
              const ZNote('写过绕开办法并勾选确认之后，才能放下它。', warn: true),
          ],
        ],
      ),
    );
  }
}
