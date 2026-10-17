import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 小墙：行为实验。假设行动（as-if）：先「像」那样做，观察反应。
/// 都只做小而可逆、不欺骗他人的实验。
class WallPage extends StatefulWidget {
  const WallPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<WallPage> createState() => _WallPageState();
}

class _WallPageState extends State<WallPage> {
  static const List<String> _wallResults = <String>['符合预期', '不符合', '没做'];

  final Set<int> _lines = <int>{};

  ZhaojianController get _c => widget.controller;

  String _wallVerdict(String r) {
    switch (r) {
      case '符合预期':
        return '假设得到一次支持。只是一次：换个情境再试，才算数。';
      case '不符合':
        return '假设被一次反驳：这是好事，说明你对自己的认识更准了一点。';
      case '没做':
        return '没做本身就是数据：是太大？太难？还是其实并不想要？';
      default:
        return '';
    }
  }

  Widget _wallCard(ZEntry it) {
    final String r = it.s('r');
    final int idx = _wallResults.indexOf(r);
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('假设：${it.s('h')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _c.removeItem(it),
              ),
            ],
          ),
          Text('小实验：${it.s('t')}'),
          if (it.s('e').isNotEmpty) ZNote('我预计会看到：${it.s('e')}'),
          const ZNote('结果：'),
          zChoice(
            labels: _wallResults,
            selected: idx < 0 ? null : idx,
            onSelect: (int i) {
              it.data['r'] = _wallResults[i];
              _c.saveItem(it);
            },
          ),
          if (r.isNotEmpty) ZNote(_wallVerdict(r)),
        ],
      ),
    );
  }

  Widget _asifCard(ZEntry it) {
    final String r = it.s('r');
    final String nb = it.s('nb');
    final String al = it.s('al');
    final bool open = r.isEmpty || nb.isEmpty || al.isEmpty;
    int? sel(List<String> labels, String v) {
      final int i = labels.indexOf(v);
      return i < 0 ? null : i;
    }

    return ZItem(
      warn: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('像一个「${it.s('role')}」那样做',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _c.removeItem(it),
              ),
            ],
          ),
          Text('具体做：${it.s('acts')}'),
          if (it.s('pred').isNotEmpty) ZNote('我预计：${it.s('pred')}'),
          const ZNote('检验一：做的时候，反应怎样？'),
          zChoice(
            labels: ZCopy.asifReactions,
            selected: sel(ZCopy.asifReactions, r),
            onSelect: (int i) {
              it.data['r'] = ZCopy.asifReactions[i];
              _c.saveItem(it);
            },
          ),
          const ZNote('检验二（去信念测试）：做之前担心的事，成真了吗？'),
          zChoice(
            labels: ZCopy.asifBeliefs,
            selected: sel(ZCopy.asifBeliefs, nb),
            onSelect: (int i) {
              it.data['nb'] = ZCopy.asifBeliefs[i];
              _c.saveItem(it);
            },
          ),
          const ZNote('检验三：这样做，让我更靠近我真正要的吗？'),
          zChoice(
            labels: ZCopy.asifAligned,
            selected: sel(ZCopy.asifAligned, al),
            onSelect: (int i) {
              it.data['al'] = ZCopy.asifAligned[i];
              _c.saveItem(it);
            },
          ),
          const SizedBox(height: 4),
          Text(asifVerdict(r, nb, al),
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> walls = _c.items('wall').reversed.toList();
    final List<ZEntry> asifs = _c.items('asif').reversed.toList();
    final bool allLines = _lines.length == ZCopy.asifRedLines.length;
    final int openAsif = asifs
        .where((ZEntry e) =>
            e.s('r').isEmpty || e.s('nb').isEmpty || e.s('al').isEmpty)
        .length;
    return ZPage(
      title: '小墙与假设行动',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        const ZNote('先用小而可逆的实验检验一个假设，而不是靠想。实验的结果是行为证据。'),
        ZSection(
          title: '小墙：行为实验',
          children: <Widget>[
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('h', '假设：如果我…，那么…', lines: 2),
                ZFieldSpec('t', '小实验：我具体做什么（小、可逆）', lines: 2),
                ZFieldSpec('e', '我预计会看到什么（可选）'),
              ],
              mustFill: const <String>['h', 't'],
              submitLabel: '砌一块砖',
              onSubmit: (Map<String, String> v) async {
                await _c.addItem('wall', <String, dynamic>{
                  'h': v['h'],
                  't': v['t'],
                  'e': v['e'],
                  'r': '',
                });
              },
            ),
            if (walls.isEmpty) const ZNote('还没有实验。') else ...walls.map(_wallCard),
          ],
        ),
        ZSection(
          title: '假设行动：先「像」那样做',
          children: <Widget>[
            const ZNote('「弄假成真」只在小处用：先像一个更接近你想要的人那样做一件小事，观察反应，再决定留不留。它不是假装成另一个人，也不替代心理治疗。'),
            const ZNote('开始前，确认四条红线：'),
            for (int i = 0; i < ZCopy.asifRedLines.length; i++)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(ZCopy.asifRedLines[i], style: const TextStyle(fontSize: 14)),
                value: _lines.contains(i),
                onChanged: (bool? v) => setState(() {
                  if (v == true) {
                    _lines.add(i);
                  } else {
                    _lines.remove(i);
                  }
                }),
              ),
            if (openAsif >= 3)
              ZNote('已有 $openAsif 个假设行动没有出结论：先把手上的做完，别同时铺太多。', warn: true),
            if (!allLines)
              const ZNote('四条都确认后才能新建。', warn: true)
            else
              ZForm(
                fields: const <ZFieldSpec>[
                  ZFieldSpec('role', '像一个什么样的人那样做（例：从容拒绝的人）'),
                  ZFieldSpec('acts', '具体做什么（小、可逆、不欺骗任何人）', lines: 2),
                  ZFieldSpec('pred', '我预计做的时候会…（可选）'),
                ],
                mustFill: const <String>['role', 'acts'],
                submitLabel: '开始这个假设行动',
                onSubmit: (Map<String, String> v) async {
                  await _c.addItem('asif', <String, dynamic>{
                    'role': v['role'],
                    'acts': v['acts'],
                    'pred': v['pred'],
                    'r': '',
                    'nb': '',
                    'al': '',
                  });
                },
              ),
            if (asifs.isEmpty) const ZNote('还没有假设行动。') else ...asifs.map(_asifCard),
          ],
        ),
      ],
    );
  }
}
