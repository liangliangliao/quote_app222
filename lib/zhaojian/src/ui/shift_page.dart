import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 变化：什么真正改变过我。记下改变前后，和是什么让它发生，
/// 积累后就知道「对我有效的改变方式」，改变引擎会优先用它。
class ShiftPage extends StatefulWidget {
  const ShiftPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends State<ShiftPage> {
  int? _kind;

  ZhaojianController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> shifts = _c.items('shift').reversed.toList();
    final Map<String, int> counts = countStrings(
      shifts
          .map((ZEntry e) => e.i('ch'))
          .where((int? i) => i != null && i >= 0 && i < ZCopy.shiftKinds.length)
          .map((int? i) => ZCopy.shiftKinds[i!][0]),
    );
    int top = -1;
    int best = 0;
    for (int i = 0; i < ZCopy.shiftKinds.length; i++) {
      final int n = counts[ZCopy.shiftKinds[i][0]] ?? 0;
      if (n > best) {
        best = n;
        top = i;
      }
    }
    return ZPage(
      title: '变化',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        const ZNote('回想你真正改变过的一件事：不是决心，是行为变了。是什么让它发生的？积累几条，就知道哪种方式对你有效。'),
        ZSection(
          title: '记一次真正的改变',
          children: <Widget>[
            const ZNote('是什么让它发生的？'),
            zChoice(
              labels: ZCopy.shiftKinds.map((List<String> k) => k[0]).toList(),
              selected: _kind,
              onSelect: (int i) => setState(() => _kind = i),
            ),
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('bf', '改变之前，我是怎么做的', lines: 2),
                ZFieldSpec('af', '改变之后，我怎么做', lines: 2),
                ZFieldSpec('mot', '具体是什么让它发生的（一件事、一个人、一次经历）', lines: 2),
              ],
              mustFill: const <String>['bf', 'af'],
              submitLabel: '记下',
              onSubmit: (Map<String, String> v) async {
                await _c.addItem('shift', <String, dynamic>{
                  'bf': v['bf'],
                  'af': v['af'],
                  'mot': v['mot'],
                  'ch': _kind ?? -1,
                });
                if (!mounted) return;
                setState(() => _kind = null);
              },
            ),
          ],
        ),
        ZSection(
          title: '对我有效的方式',
          children: <Widget>[
            if (top < 0)
              const ZNote('还没有归因。记几条，这里就会显示你最常被什么改变。')
            else ...<Widget>[
              Text('最常见：${ZCopy.shiftKinds[top][0]}（$best 次）',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              ZNote(ZCopy.shiftKinds[top][1]),
              ZNote(topCounts(counts)),
            ],
            const ZNote('样本很小，只是线索；改变引擎设计方案时会优先参考。'),
          ],
        ),
        ZSection(
          title: '我的改变（${shifts.length}）',
          children: shifts.isEmpty
              ? const <Widget>[ZNote('还没有。')]
              : <Widget>[
                  for (final ZEntry e in shifts)
                    ZItem(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('${e.s('bf')}  →  ${e.s('af')}'),
                                ZNote(
                                    '${(e.i('ch') ?? -1) >= 0 && (e.i('ch') ?? -1) < ZCopy.shiftKinds.length ? ZCopy.shiftKinds[e.i('ch')!][0] : '未归因'}'
                                    '${e.s('mot').isEmpty ? '' : ' · ${e.s('mot')}'}'),
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
