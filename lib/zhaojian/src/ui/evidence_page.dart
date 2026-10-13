import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'nav.dart';
import 'widgets.dart';

/// 证据：行为考古（带人生阶段）、他人观察、自述线索。
/// 强证据是行为，弱证据是自述；画像只看行为，自述只作线索。
class EvidencePage extends StatelessWidget {
  const EvidencePage({super.key, required this.controller});

  final ZhaojianController controller;

  static const List<String> _deliberate = <String>['思虑过', '一时冲动'];
  static const List<String> _typical = <String>['大多数人也会', '大多数人不会'];

  int get _weakCount {
    int n = 0;
    for (int i = 0; i < ZCopy.expQuestions.length; i++) {
      if (controller.kv('exp.$i').isNotEmpty) n += 1;
    }
    for (final String k in <String>['ab.s', 'ab.w', 'ab.l']) {
      if (controller.kv(k).isNotEmpty) n += 1;
    }
    return n;
  }

  Widget _archCard(ZEntry it) {
    final List<String> body = it.list('bs');
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (it.s('ph').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(it.s('ph'), style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: zChipOn,
                  ),
                ),
              Expanded(
                child: Text(it.s('w'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => controller.removeItem(it),
              ),
            ],
          ),
          if (it.s('c').isNotEmpty) ZNote('代价：${it.s('c')}'),
          if (it.s('m').isNotEmpty) ZNote('当时我说的动机：${it.s('m')}'),
          if (it.s('r').isNotEmpty) ZNote('事后的反应：${it.s('r')}'),
          const ZNote('这次是…（可选）'),
          zChoice(
            labels: _deliberate,
            selected: _deliberate.indexOf(it.s('dl')) < 0
                ? null
                : _deliberate.indexOf(it.s('dl')),
            onSelect: (int i) {
              it.data['dl'] = _deliberate[i];
              controller.saveItem(it);
            },
          ),
          zChoice(
            labels: _typical,
            selected: _typical.indexOf(it.s('ty')) < 0
                ? null
                : _typical.indexOf(it.s('ty')),
            onSelect: (int i) {
              it.data['ty'] = _typical[i];
              controller.saveItem(it);
            },
          ),
          const ZNote('当时的身体信号（可多选，只是线索）'),
          zMulti(
            labels: ZCopy.bodySignals,
            selected: body,
            onToggle: (String l) {
              final List<String> next = List<String>.from(body);
              if (next.contains(l)) {
                next.remove(l);
              } else {
                next.add(l);
              }
              it.data['bs'] = next;
              controller.saveItem(it);
            },
          ),
          zHypPicker(
            hyps: controller.hypotheses,
            current: it.i('th'),
            kind: it.s('tk', 'sup'),
            onChange: (int? hid, String kind) => controller.tagItem(it, hid, kind),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> arch = controller.items('arch').reversed.toList();
    final List<ZEntry> obs = controller.items('obs').reversed.toList();
    return ZPage(
      title: '证据',
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('强证据是行为（做了什么、事后什么反应）；弱证据是自述。画像主要看行为，自述只作线索。'),
        Wrap(
          spacing: 6,
          children: <Widget>[
            Chip(
              label: Text('强：行为 ${controller.evidenceCount} 条',
                  style: const TextStyle(fontSize: 12)),
              backgroundColor: zChipOn,
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              label: Text('弱：自述 $_weakCount 条',
                  style: const TextStyle(fontSize: 12)),
              backgroundColor: zCard,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ZSection(
          title: '① 行为考古：过去实际做过的事',
          children: <Widget>[
            const ZNote('回想在不同人生阶段做过的事，写做了什么、付出了什么代价，而不是当时怎么想。同一主线在不同阶段反复出现，才算稳定。'),
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('ph', '人生阶段（如：童年 / 高中 / 刚工作）'),
                ZFieldSpec('w', '我实际做了什么', lines: 3),
                ZFieldSpec('c', '付出的代价或后果（可选）'),
                ZFieldSpec('m', '当时我说自己是因为…（可选）'),
                ZFieldSpec('r', '事后的反应（可选）'),
              ],
              required: const <String>['w'],
              submitLabel: '记下这件事',
              onSubmit: (Map<String, String> v) async {
                await controller.addItem('arch', <String, dynamic>{
                  'ph': v['ph'],
                  'w': v['w'],
                  'c': v['c'],
                  'm': v['m'],
                  'r': v['r'],
                  'bs': <String>[],
                });
              },
            ),
            if (arch.isEmpty) const ZNote('还没有记录。') else ...arch.map(_archCard),
          ],
        ),
        ZSection(
          title: '② 他人观察',
          children: <Widget>[
            const ZNote('别人看到的你，常和你自己想的不一样。记下他看到什么、他猜你当时的动机，再写你自己知道的真实动机，对比两者。'),
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('who', '谁（如：妻子 / 老同事）'),
                ZFieldSpec('saw', '他看到我做了什么', lines: 2),
                ZFieldSpec('guess', '他猜我当时的动机'),
                ZFieldSpec('real', '我自己知道的真实动机'),
              ],
              required: const <String>['saw'],
              submitLabel: '记下他的观察',
              onSubmit: (Map<String, String> v) async {
                await controller.addItem('obs', <String, dynamic>{
                  'who': v['who'],
                  'saw': v['saw'],
                  'guess': v['guess'],
                  'real': v['real'],
                });
              },
            ),
            if (obs.isEmpty)
              const ZNote('还没有记录。')
            else
              for (final ZEntry o in obs)
                ZItem(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${o.s('who').isEmpty ? '有人' : o.s('who')}看到：${o.s('saw')}'),
                            if (o.s('guess').isNotEmpty || o.s('real').isNotEmpty)
                              ZNote('他猜：${o.s('guess').isEmpty ? '（没写）' : o.s('guess')}　我说：${o.s('real').isEmpty ? '（没写）' : o.s('real')}'),
                            if (o.s('guess').isNotEmpty &&
                                o.s('real').isNotEmpty &&
                                o.s('guess') != o.s('real'))
                              const ZNote('两边不一致：这是个线索，说明别人看到的和你自己认为的有差距。', warn: true),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => controller.removeItem(o),
                      ),
                    ],
                  ),
                ),
          ],
        ),
        ZSection(
          title: '③ 行为记录与预测落差',
          children: <Widget>[
            ZNote('已有行为记录 ${controller.logs.length} 条，已开牌 ${controller.revealed.length} 次。这是最强的证据来源。'),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => ZNav.open(context, controller, ZDest.log),
                  child: const Text('去记一次行为'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => ZNav.open(context, controller, ZDest.hypothesis),
                  child: const Text('主线与假设'),
                ),
              ],
            ),
          ],
        ),
        ZSection(
          title: '④ 自述线索（弱证据，只作线索）',
          children: <Widget>[
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('回答几个问题（已答 ${<int>[
                for (int i = 0; i < ZCopy.expQuestions.length; i++)
                  if (controller.kv('exp.$i').isNotEmpty) i,
              ].length} / ${ZCopy.expQuestions.length}）',
                  style: const TextStyle(fontSize: 14)),
              children: <Widget>[
                for (int i = 0; i < ZCopy.expQuestions.length; i++)
                  _ExpQuestion(controller: controller, index: i),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ExpQuestion extends StatefulWidget {
  const _ExpQuestion({required this.controller, required this.index});

  final ZhaojianController controller;
  final int index;

  @override
  State<_ExpQuestion> createState() => _ExpQuestionState();
}

class _ExpQuestionState extends State<_ExpQuestion> {
  late final TextEditingController _c = TextEditingController(
      text: widget.controller.kv('exp.${widget.index}'));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ZNote('${widget.index + 1}. ${ZCopy.expQuestions[widget.index]}'),
          TextField(
            controller: _c,
            minLines: 1,
            maxLines: 3,
            decoration: zInput(''),
            onChanged: (String v) =>
                widget.controller.setKv('exp.${widget.index}', v.trim()),
          ),
        ],
      ),
    );
  }
}
