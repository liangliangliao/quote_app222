import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 放弃拆分器：把「要不要彻底放弃」拆成一次暂时放弃的小实验：
/// 先预测放弃后会有多难受，真的放弃几天，再对比预测和实际。
class ForgoPage extends StatefulWidget {
  const ForgoPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<ForgoPage> createState() => _ForgoPageState();
}

class _ForgoPageState extends State<ForgoPage> {
  final Set<int> _lines = <int>{};
  final TextEditingController _t = TextEditingController();
  int _pred = 5;
  int _days = 3;

  ZhaojianController get _c => widget.controller;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_t.text.trim().isEmpty) {
      zSnack(context, '先写下想暂时放弃的是什么');
      return;
    }
    await _c.addItem('forgo', <String, dynamic>{
      't': _t.text.trim(),
      'pred': _pred,
      'days': _days,
      'log': <Map<String, dynamic>>[],
    });
    if (!mounted) return;
    setState(() {
      _t.clear();
      _pred = 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> items = _c.items('forgo').reversed.toList();
    final bool ok = _lines.length == ZCopy.forgoRedLines.length;
    return ZPage(
      title: '放弃拆分器',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        const ZNote('「要不要彻底放弃」太大，也太容易冲动。拆成一个小实验：暂时放弃几天，先预测会有多难受，再对比真实的感受。放弃本身不是目的，看清才是。'),
        ZSection(
          title: '开一个实验',
          children: <Widget>[
            const ZNote('开始前，确认两条红线：'),
            for (int i = 0; i < ZCopy.forgoRedLines.length; i++)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(ZCopy.forgoRedLines[i], style: const TextStyle(fontSize: 14)),
                value: _lines.contains(i),
                onChanged: (bool? v) => setState(() {
                  if (v == true) {
                    _lines.add(i);
                  } else {
                    _lines.remove(i);
                  }
                }),
              ),
            if (!ok)
              const ZNote('两条都确认后才能新建。', warn: true)
            else ...<Widget>[
              TextField(controller: _t, decoration: zInput('我想暂时放弃…')),
              ZNote('我预测，放弃之后会有多难受（0 不难受，10 很难受）：$_pred'),
              Slider(
                value: _pred.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$_pred',
                onChanged: (double v) => setState(() => _pred = v.round()),
              ),
              ZNote('放弃几天：$_days'),
              Slider(
                value: _days.toDouble(),
                min: 1,
                max: 14,
                divisions: 13,
                label: '$_days',
                onChanged: (double v) => setState(() => _days = v.round()),
              ),
              FilledButton(onPressed: _add, child: const Text('开始实验')),
            ],
          ],
        ),
        ZSection(
          title: '我的实验（${items.length}）',
          children: items.isEmpty
              ? const <Widget>[ZNote('还没有。')]
              : <Widget>[
                  for (final ZEntry e in items)
                    _ForgoCard(key: ValueKey<int?>(e.id), controller: _c, item: e),
                ],
        ),
      ],
    );
  }
}

class _ForgoCard extends StatefulWidget {
  const _ForgoCard({super.key, required this.controller, required this.item});

  final ZhaojianController controller;
  final ZEntry item;

  @override
  State<_ForgoCard> createState() => _ForgoCardState();
}

class _ForgoCardState extends State<_ForgoCard> {
  final TextEditingController _n = TextEditingController();
  int _v = 5;

  @override
  void dispose() {
    _n.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    final List<Map<String, dynamic>> log = widget.item.maps('log')
      ..add(<String, dynamic>{'v': _v, 'n': _n.text.trim()});
    widget.item.data['log'] = log;
    await widget.controller.saveItem(widget.item);
    if (!mounted) return;
    setState(_n.clear);
  }

  @override
  Widget build(BuildContext context) {
    final ZEntry it = widget.item;
    final int pred = it.i('pred') ?? 5;
    final int days = it.i('days') ?? 3;
    final List<Map<String, dynamic>> log = it.maps('log');
    double? avg;
    if (log.isNotEmpty) {
      double sum = 0;
      for (final Map<String, dynamic> x in log) {
        sum += (x['v'] is num ? (x['v'] as num).toDouble() : 0);
      }
      avg = sum / log.length;
    }
    String verdict = '';
    if (avg != null && log.length >= 2) {
      verdict = avg < pred - 1
          ? '实际比预测轻松：你可能高估了放弃的代价，可以考虑把实验延长。'
          : (avg > pred + 1
              ? '实际比预测更难受：别硬撑，换一个更小的版本再试。'
              : '实际和预测差不多：你对自己判断得挺准。');
    }
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('暂时放弃：${it.s('t')}（$days 天）',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(it),
              ),
            ],
          ),
          ZNote('预测难受程度：$pred　已记录 ${log.length} / $days 天'
              '${avg == null ? '' : '　实际平均：${avg.toStringAsFixed(1)}'}'),
          if (log.length < days) ...<Widget>[
            ZNote('今天实际有多难受：$_v'),
            Slider(
              value: _v.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$_v',
              onChanged: (double x) => setState(() => _v = x.round()),
            ),
            TextField(controller: _n, decoration: zInput('今天的感受（可选）')),
            OutlinedButton(onPressed: _record, child: const Text('记下今天')),
          ],
          if (verdict.isNotEmpty) ZItem(child: Text(verdict)),
        ],
      ),
    );
  }
}
