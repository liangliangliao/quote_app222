import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import '../domain/json_util.dart';
import 'nav.dart';
import 'widgets.dart';

/// 路径探测与收敛：对几条候选路径各做一次小探测，
/// 再按「想要 × 能力」收敛到一条线，并写下舍弃清单。
class ProbePage extends StatefulWidget {
  const ProbePage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  bool _busy = false;
  String _msg = '';
  List<Map<String, String>> _cands = <Map<String, String>>[];

  ZhaojianController get _c => widget.controller;

  Future<void> _propose() async {
    final List<String> sup = _c.hypotheses
        .where((ZHypothesis h) => h.status == 1)
        .map((ZHypothesis h) => h.text)
        .toList();
    final List<String> pics = _c
        .items('goal')
        .where((ZEntry g) => g.s('pic').isNotEmpty)
        .map((ZEntry g) => g.s('pic'))
        .toList();
    setState(() {
      _busy = true;
      _msg = 'AI 正在想…（约半分钟）';
    });
    final String raw = await _c.oracle.generate(
      prompt: '用户被行为支持的主线：${sup.isEmpty ? '（还没有）' : sup.join('；')}。'
          '目标终点的画面：${pics.isEmpty ? '（还没有）' : pics.take(3).join('；')}。'
          '当前选定的线：${_c.kv('line.pick').isEmpty ? '（还没有）' : _c.kv('line.pick')}。\n'
          '请提出 5 条彼此不同的候选路径（方向），每条配一个本周就能做的、小而可逆的探测动作。'
          '这些只是待检验的猜测，不替用户决定，不说「你适合」。'
          '只输出 JSON 数组 [{"t":"路径(不超过16字)","why":"为什么值得试(不超过30字)","mini":"小探测(不超过30字)"}]。',
      purpose: 'zhaojian.probe_candidates',
    );
    if (!mounted) return;
    final List<Map<String, String>> list = <Map<String, String>>[];
    for (final dynamic e in zParseArray(raw)) {
      if (e is! Map) continue;
      final String t = '${e['t'] ?? ''}'.trim();
      if (t.isEmpty) continue;
      list.add(<String, String>{
        't': t,
        'why': '${e['why'] ?? ''}'.trim(),
        'mini': '${e['mini'] ?? ''}'.trim(),
      });
    }
    setState(() {
      _busy = false;
      _cands = list.take(5).toList();
      _msg = list.isEmpty ? '没有可用的 AI，或没有完成。自己加也可以。' : '';
    });
  }

  Future<void> _addProbe(String t, String why, String mini) async {
    await _c.addItem('probe', <String, dynamic>{
      't': t,
      'why': why,
      'mini': mini,
      'done': false,
      'want': 0,
      'able': 0,
    });
  }

  Future<void> _converge(ZEntry chosen) async {
    final String old = _c.kv('line.drop');
    final List<String> lines = old.isEmpty ? <String>[] : old.split('\n');
    for (final ZEntry e in _c.items('probe')) {
      if (e.id != chosen.id && e.s('t').isNotEmpty && !lines.contains(e.s('t'))) {
        lines.add(e.s('t'));
      }
    }
    await _c.setKv('line.pick', chosen.s('t'));
    await _c.setKv('line.drop', lines.join('\n'));
    if (!mounted) return;
    zSnack(context, '已选定为一条线，其余候选写进了舍弃清单。');
    ZNav.open(context, _c, ZDest.line);
  }

  Widget _card(ZEntry it) {
    final bool done = it.b('done');
    final int want = it.i('want') ?? 0;
    final int able = it.i('able') ?? 0;
    final bool rated = want > 0 && able > 0;
    final int q = probeQuadrant(want, able);
    return ZItem(
      warn: !done,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(it.s('t'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _c.removeItem(it),
              ),
            ],
          ),
          if (it.s('why').isNotEmpty) ZNote('为什么值得试：${it.s('why')}'),
          if (it.s('mini').isNotEmpty) Text('小探测：${it.s('mini')}'),
          if (!done)
            FilledButton(
              onPressed: () {
                it.data['done'] = true;
                _c.saveItem(it);
              },
              child: const Text('做完了这次小探测'),
            )
          else ...<Widget>[
            const ZNote('做完之后，凭实际的感受打分（1 到 5）：'),
            ZNote('想要程度：${want == 0 ? '未评' : want}'),
            zChoice(
              labels: const <String>['1', '2', '3', '4', '5'],
              selected: want == 0 ? null : want - 1,
              onSelect: (int i) {
                it.data['want'] = i + 1;
                _c.saveItem(it);
              },
            ),
            ZNote('能力（做得顺不顺）：${able == 0 ? '未评' : able}'),
            zChoice(
              labels: const <String>['1', '2', '3', '4', '5'],
              selected: able == 0 ? null : able - 1,
              onSelect: (int i) {
                it.data['able'] = i + 1;
                _c.saveItem(it);
              },
            ),
            if (rated) ...<Widget>[
              Text(ZCopy.probeQuadrants[q][0], style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(ZCopy.probeQuadrants[q][1]),
              if (q <= 1)
                TextButton(
                  onPressed: () => _converge(it),
                  child: const Text('选为一条线，其余写进舍弃清单'),
                ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> probes = _c.items('probe').reversed.toList();
    final int undone = _c.activeProbes;
    return ZPage(
      title: '探测',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        const ZNote('不确定走哪条路时，别靠想。对每条候选做一次小探测（小、可逆、一周内能做），再按「想要 × 能力」收敛。'),
        if (undone >= 3)
          ZNote('还有 $undone 个探测没做完：先做完，别再加新的。', warn: true),
        ZSection(
          title: '加一条候选路径',
          children: <Widget>[
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('t', '候选路径'),
                ZFieldSpec('why', '为什么觉得值得试（可选）'),
                ZFieldSpec('mini', '小探测：本周能做的最小动作', lines: 2),
              ],
              mustFill: const <String>['t', 'mini'],
              submitLabel: '加入探测',
              onSubmit: (Map<String, String> v) => _addProbe(v['t'] ?? '', v['why'] ?? '', v['mini'] ?? ''),
            ),
            if (_c.oracle.sendsData) ...<Widget>[
              ZNote('点击后，你的主线与目标画面会发送给：${_c.oracle.generateLabel}。', warn: true),
              OutlinedButton(
                onPressed: _busy ? null : _propose,
                child: const Text('让 AI 提 5 条候选'),
              ),
            ],
            if (_msg.isNotEmpty) ZNote(_msg, warn: true),
            for (final Map<String, String> c in _cands)
              ZItem(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(c['t'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ZNote('${c['why']}　小探测：${c['mini']}'),
                    TextButton(
                      onPressed: () async {
                        await _addProbe(c['t'] ?? '', c['why'] ?? '', c['mini'] ?? '');
                        if (!mounted) return;
                        setState(() => _cands.remove(c));
                      },
                      child: const Text('加入探测'),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ZSection(
          title: '我的探测（${probes.length}）',
          children: probes.isEmpty ? const <Widget>[ZNote('还没有。')] : probes.map(_card).toList(),
        ),
      ],
    );
  }
}
