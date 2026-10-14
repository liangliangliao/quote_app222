import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 绳子：预先承诺。现场的你会被「歌声」带走，所以在听到之前就把自己绑好（绳子），
/// 再把耳朵堵上（蜡）。
class RopePage extends StatefulWidget {
  const RopePage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<RopePage> createState() => _RopePageState();
}

class _RopePageState extends State<RopePage> {
  final TextEditingController _s = TextEditingController();
  final TextEditingController _r = TextEditingController();
  final TextEditingController _w = TextEditingController();
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _s.dispose();
    _r.dispose();
    _w.dispose();
    _c.dispose();
    super.dispose();
  }

  void _useTemplate(List<String> t) {
    setState(() {
      _s.text = t[1];
      _r.text = t[2];
      _w.text = t[3];
      _c.text = t[4];
    });
  }

  Future<void> _add() async {
    if (_s.text.trim().isEmpty || _r.text.trim().isEmpty) {
      zSnack(context, '至少写下「歌声」和「绳子」');
      return;
    }
    await widget.controller.addItem('rope', <String, dynamic>{
      's': _s.text.trim(),
      'r': _r.text.trim(),
      'w': _w.text.trim(),
      'c': _c.text.trim(),
      'seq': <String>[],
      'ok': '',
    });
    if (!mounted) return;
    setState(() {
      _s.clear();
      _r.clear();
      _w.clear();
      _c.clear();
    });
  }

  Future<void> _mark(ZEntry it, String v) async {
    final List<String> seq = it.list('seq')..add(v);
    it.data['seq'] = seq;
    it.data['ok'] = v;
    await widget.controller.saveItem(it);
  }

  Widget _card(ZEntry it) {
    final List<String> seq = it.list('seq');
    final ({int kept, int broken}) st = ropeStats(seq);
    final String dots = seq.map((String x) => x == 'y' ? '●' : '○').join(' ');
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('歌声：${it.s('s')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(it),
              ),
            ],
          ),
          Text('绳子：${it.s('r')}'),
          if (it.s('w').isNotEmpty) Text('蜡：${it.s('w')}'),
          if (it.s('c').isNotEmpty) ZNote('检查：${it.s('c')}'),
          if (seq.isNotEmpty) ...<Widget>[
            Text(dots, style: const TextStyle(fontSize: 18, letterSpacing: 2)),
            ZNote('● 守住 ${st.kept} 次　○ 被破 ${st.broken} 次'),
          ],
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: () => _mark(it, 'y'),
                child: const Text('这次守住了'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _mark(it, 'n'),
                child: const Text('这次被破了'),
              ),
            ],
          ),
          if (st.broken > st.kept && st.broken >= 2)
            const ZNote('被破的次数多于守住：多半不是意志不够，是绳子太松或歌声太近。把绳子系得更早、更紧，或加一层蜡。', warn: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> ropes = widget.controller.items('rope').reversed.toList();
    final ({int kept, int broken}) total = ropeStats(<String>[
      for (final ZEntry r in ropes) ...r.list('seq'),
    ]);
    return ZPage(
      title: '绳子',
      controller: widget.controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('奥德修斯知道自己听到歌声会失控，所以在听到之前，先把自己绑在桅杆上，再让船员用蜡堵上耳朵。绳子是事先的约束，不是现场的意志力。'),
        ZSection(
          title: '用模板起步',
          children: <Widget>[
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final List<String> t in ZCopy.ropeTemplates)
                  ActionChip(label: Text(t[0]), onPressed: () => _useTemplate(t)),
              ],
            ),
          ],
        ),
        ZSection(
          title: '系一根绳子',
          children: <Widget>[
            TextField(controller: _s, decoration: zInput('歌声：什么情境会把我带走')),
            const SizedBox(height: 8),
            TextField(controller: _r, decoration: zInput('绳子：在那之前我先怎么约束自己')),
            const SizedBox(height: 8),
            TextField(controller: _w, decoration: zInput('蜡：怎样让自己听不见（可选）')),
            const SizedBox(height: 8),
            TextField(controller: _c, decoration: zInput('什么时候检查一次（可选）')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _add, child: const Text('系上')),
          ],
        ),
        ZSection(
          title: '我的绳子 · 守住 ${total.kept} / 被破 ${total.broken}',
          children: ropes.isEmpty
              ? const <Widget>[ZNote('还没有绳子。')]
              : ropes.map(_card).toList(),
        ),
        const ZNote('绳子的结果是行为证据：记下守住或被破，比自己说「我有决心」更能说明问题。'),
      ],
    );
  }
}
