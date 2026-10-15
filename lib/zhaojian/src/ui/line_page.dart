import 'package:flutter/material.dart';

import '../data/models.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 一条线：选定一条主线，写下舍弃清单；换线时归档旧的并记下原因（接力）；
/// 羡慕日志——羡慕只是线索，先问自己愿不愿意付他的代价。
class LinePage extends StatefulWidget {
  const LinePage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<LinePage> createState() => _LinePageState();
}

class _LinePageState extends State<LinePage> {
  late final TextEditingController _pick =
      TextEditingController(text: widget.controller.kv('line.pick'));
  late final TextEditingController _drop =
      TextEditingController(text: widget.controller.kv('line.drop'));
  final TextEditingController _next = TextEditingController();
  final TextEditingController _why = TextEditingController();

  ZhaojianController get _c => widget.controller;

  @override
  void dispose() {
    _pick.dispose();
    _drop.dispose();
    _next.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _relay() async {
    final String old = _c.kv('line.pick');
    if (old.isEmpty) {
      zSnack(context, '还没有选定的线，直接在上面写就行');
      return;
    }
    if (_next.text.trim().isEmpty || _why.text.trim().isEmpty) {
      zSnack(context, '写下新的线，和换线的原因');
      return;
    }
    await _c.addItem('linehist', <String, dynamic>{
      't': old,
      'to': _next.text.trim(),
      'why': _why.text.trim(),
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    await _c.setKv('line.pick', _next.text.trim());
    if (!mounted) return;
    setState(() {
      _pick.text = _next.text.trim();
      _next.clear();
      _why.clear();
    });
  }

  String _date(ZEntry e) {
    final int? ms = e.i('at');
    if (ms == null) return '';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> hist = _c.items('linehist').reversed.toList();
    final List<ZEntry> envy = _c.items('envy').reversed.toList();
    final int threads = _c.activeThreads;
    return ZPage(
      title: '一条线',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        const ZNote('同时追很多条线，每条都只得到零头。选定一条，其余的明说「这一阵不做」。选定不是永远：换线时，记下原因就行。'),
        if (threads >= 3)
          ZNote('手上同时进行着 $threads 件事（计划、假设行动、探测、放弃实验）：先收敛，再开新的。', warn: true),
        ZSection(
          title: '选定的线',
          children: <Widget>[
            TextField(
              controller: _pick,
              minLines: 1,
              maxLines: 3,
              decoration: zInput('这一阵，我主要走的一条线是…'),
              onChanged: (String v) => _c.setKv('line.pick', v.trim()),
            ),
            const SizedBox(height: 8),
            const ZNote('舍弃清单：这一阵明确不做的（每行一条）'),
            TextField(
              controller: _drop,
              minLines: 2,
              maxLines: 6,
              decoration: zInput('不做…'),
              onChanged: (String v) => _c.setKv('line.drop', v.trim()),
            ),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => ZNav.open(context, _c, ZDest.probe),
                  child: const Text('不确定？先做小探测'),
                ),
                TextButton(
                  onPressed: () => ZNav.open(context, _c, ZDest.goal),
                  child: const Text('看目标链'),
                ),
              ],
            ),
          ],
        ),
        ZSection(
          title: '换线（接力）',
          children: <Widget>[
            const ZNote('换线不是失败：旧线归档，记下为什么换，以后回看才知道是成长，还是在逃。'),
            TextField(controller: _next, decoration: zInput('新的线')),
            const SizedBox(height: 8),
            TextField(controller: _why, minLines: 1, maxLines: 3, decoration: zInput('换线的原因')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _relay, child: const Text('归档旧线，换成新线')),
            for (final ZEntry h in hist)
              ZItem(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${h.s('t')}  →  ${h.s('to')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ZNote('${_date(h)}　原因：${h.s('why')}'),
                  ],
                ),
              ),
          ],
        ),
        ZSection(
          title: '羡慕日志',
          children: <Widget>[
            const ZNote('羡慕是线索，不是指令：它可能指向你被压住的欲求，也可能只是别人的评价在起作用。先问：我愿意付他付过的代价吗？'),
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('what', '我羡慕什么 / 谁'),
                ZFieldSpec('guess', '我猜，我羡慕的其实是…'),
                ZFieldSpec('cost', '他付出的代价，我愿意付吗'),
              ],
              mustFill: const <String>['what'],
              submitLabel: '记一笔',
              onSubmit: (Map<String, String> v) async {
                await _c.addItem('envy', <String, dynamic>{
                  'what': v['what'],
                  'guess': v['guess'],
                  'cost': v['cost'],
                });
              },
            ),
            for (final ZEntry e in envy.take(8))
              ZItem(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(e.s('what')),
                          if (e.s('guess').isNotEmpty || e.s('cost').isNotEmpty)
                            ZNote('其实羡慕：${e.s('guess')}　代价：${e.s('cost')}'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _c.removeItem(e),
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
