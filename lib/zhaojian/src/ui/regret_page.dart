import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import '../domain/json_util.dart';
import 'nav.dart';
import 'widgets.dart';

/// 回望：悔恨诊断，以及手段与欲求是否一致的检查。
///
/// 叔本华：悔恨不是欲求变了，而是认识纠正了；多数悔恨其实是手段选错了。
/// 外部的挫折不是悔恨，不要把运气不好算成自己的错。
class RegretPage extends StatefulWidget {
  const RegretPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<RegretPage> createState() => _RegretPageState();
}

class _RegretPageState extends State<RegretPage> {
  final TextEditingController _w = TextEditingController();
  final TextEditingController _n = TextEditingController();
  int? _kind;
  int? _reason;

  final TextEditingController _desire = TextEditingController();
  final TextEditingController _means = TextEditingController();
  int _manual = 50;
  bool _useManual = false;
  bool _busy = false;
  String _msg = '';
  int? _aiSvc;
  String _aiWhy = '';
  List<String> _aiAlts = <String>[];

  ZhaojianController get _c => widget.controller;

  @override
  void dispose() {
    _w.dispose();
    _n.dispose();
    _desire.dispose();
    _means.dispose();
    super.dispose();
  }

  Future<void> _saveRegret() async {
    if (_w.text.trim().isEmpty || _kind == null || _reason == null) {
      zSnack(context, '写下是什么事，并选出指向与原因');
      return;
    }
    await _c.addItem('reg', <String, dynamic>{
      'w': _w.text.trim(),
      'k': _kind,
      'c': _reason,
      'n': _n.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _w.clear();
      _n.clear();
      _kind = null;
      _reason = null;
    });
  }

  Future<void> _aiCheck() async {
    if (_desire.text.trim().isEmpty || _means.text.trim().isEmpty) {
      zSnack(context, '先写下欲求和手段');
      return;
    }
    setState(() {
      _busy = true;
      _msg = 'AI 正在评估…（约半分钟）';
    });
    final String raw = await _c.oracle.generate(
      prompt: '欲求（只是假设）：${_desire.text.trim()}。我现在用的手段：${_means.text.trim()}。'
      '请评估这个手段对这个欲求的服务程度（0 到 100，50 表示无关，低于 50 表示背离），'
      '理由不超过 40 字，并给最多 2 个替代手段（具体、小、可试）。这是待检验的猜测，不是结论，不替用户决定。'
      '只输出 JSON：{"svc":数字,"why":"","alts":["",""]}',
      purpose: 'zhaojian.means_check',
    );
    if (!mounted) return;
    final Map<String, dynamic>? o = zParseObject(raw);
    setState(() {
      _busy = false;
      if (o == null || o['svc'] is! num) {
        _msg = raw.isEmpty ? '没有可用的 AI，或没有完成。可以改用自评。' : 'AI 的回答没法解析。可以改用自评。';
        return;
      }
      _msg = '';
      _aiSvc = (o['svc'] as num).round().clamp(0, 100).toInt();
      _aiWhy = '${o['why'] ?? ''}'.trim();
      _aiAlts = zStrings(o['alts'], max: 2);
    });
  }

  Future<void> _saveMeans() async {
    final int? svc = _useManual ? _manual : _aiSvc;
    if (_desire.text.trim().isEmpty || _means.text.trim().isEmpty || svc == null) {
      zSnack(context, '写下欲求和手段，并先评估（AI 或自评）');
      return;
    }
    await _c.addItem('mc', <String, dynamic>{
      'd': _desire.text.trim(),
      'm': _means.text.trim(),
      'svc': svc,
      'why': _useManual ? '' : _aiWhy,
      'alts': _useManual ? <String>[] : _aiAlts,
      'src': _useManual ? '自评' : 'AI',
    });
    if (!mounted) return;
    setState(() {
      _desire.clear();
      _means.clear();
      _aiSvc = null;
      _aiWhy = '';
      _aiAlts = <String>[];
      _manual = 50;
    });
  }

  String _svcNote(int svc) {
    if (svc < 40) return '这个手段不太服务你的欲求，甚至在背离它：换一个试试，别只是更用力。';
    if (svc < 60) return '这个手段和你的欲求关系不大：想一想它是不是习惯，而不是选择。';
    return '这个手段大体服务你的欲求。';
  }

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> regs = _c.items('reg').reversed.toList();
    final List<ZEntry> mcs = _c.items('mc').reversed.toList();
    final List<ZHypothesis> supported =
        _c.hypotheses.where((ZHypothesis h) => h.status == 1).toList();
    final int? svc = _useManual ? _manual : _aiSvc;
    return ZPage(
      title: '回望',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        const ZNote('叔本华认为，悔恨不是欲求变了，而是认识被纠正了：才发现当时的手段不通向自己要的。外部的挫折则不是悔恨。'),
        ZSection(
          title: '悔恨诊断',
          children: <Widget>[
            TextField(controller: _w, minLines: 1, maxLines: 3, decoration: zInput('我后悔的是…')),
            const SizedBox(height: 8),
            const ZNote('我后悔的是：'),
            zChoice(
              labels: ZCopy.regretKinds,
              selected: _kind,
              onSelect: (int i) => setState(() => _kind = i),
            ),
            if (_kind == 0)
              const ZNote('欲求本身不会因为后悔而改变。想一想：是这个东西不值得要，还是我以为它能给我的，它给不了（认识的问题）？'),
            const ZNote('主要原因：'),
            zChoice(
              labels: ZCopy.regretReasons.map((List<String> r) => r[0]).toList(),
              selected: _reason,
              onSelect: (int i) => setState(() => _reason = i),
            ),
            if (_reason != null)
              ZItem(
                warn: _reason == 4,
                child: Text(ZCopy.regretReasons[_reason!][1]),
              ),
            const SizedBox(height: 8),
            TextField(controller: _n, minLines: 1, maxLines: 3, decoration: zInput('补充（可选）')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _saveRegret, child: const Text('记下这次回望')),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => ZNav.open(context, _c, ZDest.rope),
                  child: const Text('去系绳子'),
                ),
                TextButton(
                  onPressed: () => ZNav.open(context, _c, ZDest.accept),
                  child: const Text('去「接受」'),
                ),
              ],
            ),
          ],
        ),
        ZSection(
          title: '回望记录（${regs.length}）',
          children: regs.isEmpty
              ? const <Widget>[ZNote('还没有记录。回望也是行为证据。')]
              : <Widget>[
                  for (final ZEntry r in regs)
                    ZItem(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(r.s('w')),
                                ZNote(
                                    '${ZCopy.regretKinds[(r.i('k') ?? 0).clamp(0, 1)]} · ${ZCopy.regretReasons[(r.i('c') ?? 0).clamp(0, 5)][0]}'),
                                if (r.s('n').isNotEmpty) ZNote(r.s('n')),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _c.removeItem(r),
                          ),
                        ],
                      ),
                    ),
                ],
        ),
        ZSection(
          title: '手段与欲求是否一致',
          children: <Widget>[
            const ZNote('常见的悔恨来自「用的手段不服务想要的」。把欲求（只是假设）和你现在的手段并排看一眼。'),
            if (supported.isNotEmpty)
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final ZHypothesis h in supported)
                    ActionChip(
                      label: Text('＋ ${h.text}', style: const TextStyle(fontSize: 13)),
                      onPressed: () => setState(() => _desire.text = h.text),
                    ),
                ],
              ),
            TextField(controller: _desire, decoration: zInput('我想要的（欲求）')),
            const SizedBox(height: 8),
            TextField(controller: _means, decoration: zInput('我现在用的手段')),
            const SizedBox(height: 8),
            if (_c.oracle.sendsData) ...<Widget>[
              ZNote('点 AI 按钮后，你写的内容会发送给：${_c.oracle.generateLabel}。', warn: true),
              OutlinedButton(
                onPressed: _busy ? null : _aiCheck,
                child: const Text('让 AI 评估这个手段'),
              ),
            ],
            if (_msg.isNotEmpty) ZNote(_msg, warn: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自己评（自述）', style: TextStyle(fontSize: 14)),
              value: _useManual,
              onChanged: (bool v) => setState(() => _useManual = v),
            ),
            if (_useManual) ...<Widget>[
              ZNote('这个手段对我想要的帮助：$_manual（50 表示无关）'),
              Slider(
                value: _manual.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_manual',
                onChanged: (double v) => setState(() => _manual = v.round()),
              ),
            ],
            if (svc != null) ...<Widget>[
              ZBar(label: '服务程度 $svc', value: svc / 100),
              ZNote(_svcNote(svc)),
              if (!_useManual && _aiWhy.isNotEmpty) ZNote('理由：$_aiWhy'),
              if (!_useManual && _aiAlts.isNotEmpty) ZNote('可以试：${_aiAlts.join('；')}'),
            ],
            FilledButton(onPressed: _saveMeans, child: const Text('记下这次检查')),
            for (final ZEntry m in mcs.take(6))
              ZItem(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${m.s('m')} → ${m.s('d')}'),
                          ZNote('服务程度 ${m.i('svc') ?? '-'}（${m.s('src')}）'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _c.removeItem(m),
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
