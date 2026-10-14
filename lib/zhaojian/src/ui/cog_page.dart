import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import '../domain/json_util.dart';
import 'widgets.dart';

/// 认知重构：揪出 → 查证 → 体验 → 重设。只是自助练习，不替代治疗；
/// 出现绝望或自伤的迹象就停下，转向求助。
class CogPage extends StatefulWidget {
  const CogPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<CogPage> createState() => _CogPageState();
}

class _CogPageState extends State<CogPage> {
  int _step = 0;
  final TextEditingController _sit = TextEditingController();
  final TextEditingController _bel = TextEditingController();
  final TextEditingController _evf = TextEditingController();
  final TextEditingController _eva = TextEditingController();
  final TextEditingController _exp = TextEditingController();
  final TextEditingController _how = TextEditingController();
  final TextEditingController _alt = TextEditingController();
  final TextEditingController _res = TextEditingController();
  int _pre = 70;
  int _post = 50;
  final Set<String> _dis = <String>{};

  List<String> _hint0 = <String>[];
  String _hint1 = '';
  String _hint2 = '';
  String _hint3 = '';
  bool _busy = false;
  String _msg = '';

  ZhaojianController get _c => widget.controller;

  List<TextEditingController> get _all => <TextEditingController>[
        _sit, _bel, _evf, _eva, _exp, _how, _alt, _res,
      ];

  @override
  void dispose() {
    for (final TextEditingController c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(int s) => setState(() {
        _step = s;
        _msg = '';
      });

  Future<String> _generate(String prompt, String purpose) async {
    setState(() {
      _busy = true;
      _msg = 'AI 正在想…（约半分钟）';
    });
    final String r = await _c.oracle.generate(prompt: prompt, purpose: purpose);
    if (!mounted) return '';
    setState(() {
      _busy = false;
      _msg = r.isEmpty ? '没有可用的 AI，或没有完成。自己写也可以。' : '';
    });
    return r.trim();
  }

  String get _ctx => '情境：${_sit.text.trim()}。当时脑子里的想法：${_bel.text.trim()}。';

  static const String _guard = '这只是自助练习：不诊断，不贴标签，不替代治疗；只给待检验的猜测，不下结论。';

  Future<void> _aiBeliefs() async {
    final String raw = await _generate(
      '$_ctx\n请指出这个想法背后可能隐含的 1 到 3 个信念（例如「我必须让所有人满意」）。$_guard'
      '只输出 JSON 字符串数组，每条不超过 25 字。',
      'zhaojian.cog_beliefs',
    );
    if (raw.isEmpty) return;
    setState(() => _hint0 = zStrings(zParseArray(raw), max: 3));
  }

  Future<void> _aiQuestions() async {
    final String raw = await _generate(
      '$_ctx\n请提 3 个帮助查证这个想法的问题（问事实，不问感受；包括「有没有反例」「别人会怎么看同样的事」）。$_guard'
      '总共不超过 150 字，分行写。',
      'zhaojian.cog_questions',
    );
    if (raw.isNotEmpty) setState(() => _hint1 = raw);
  }

  Future<void> _aiExperiment() async {
    final String raw = await _generate(
      '$_ctx 支持的事实：${_evf.text.trim()}。不支持的事实：${_eva.text.trim()}。'
      '请设计一个小而可逆、不欺骗他人的行为实验，用来检验这个想法。$_guard 不超过 80 字。',
      'zhaojian.cog_experiment',
    );
    if (raw.isNotEmpty) setState(() => _hint2 = raw);
  }

  Future<void> _aiAlt() async {
    final String raw = await _generate(
      '$_ctx 支持的事实：${_evf.text.trim()}。不支持的事实：${_eva.text.trim()}。实验：${_exp.text.trim()}。'
      '请写一个更贴近事实的替代说法（不是更乐观，而是更准确）。$_guard 不超过 60 字。',
      'zhaojian.cog_alt',
    );
    if (raw.isNotEmpty) setState(() => _hint3 = raw);
  }

  Future<void> _save() async {
    if (_alt.text.trim().isEmpty) {
      zSnack(context, '先写一个更贴近事实的说法');
      return;
    }
    await _c.addItem('cog', <String, dynamic>{
      'sit': _sit.text.trim(),
      'bel': _bel.text.trim(),
      'pre': _pre,
      'dis': _dis.toList(),
      'evf': _evf.text.trim(),
      'eva': _eva.text.trim(),
      'exp': _exp.text.trim(),
      'how': _how.text.trim(),
      'alt': _alt.text.trim(),
      'post': _post,
      'res': _res.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      for (final TextEditingController c in _all) {
        c.clear();
      }
      _dis.clear();
      _pre = 70;
      _post = 50;
      _hint0 = <String>[];
      _hint1 = '';
      _hint2 = '';
      _hint3 = '';
      _step = 0;
    });
    zSnack(context, '已记下这一轮。');
  }

  Widget _disclosure() {
    if (!_c.oracle.sendsData) return const ZNote('没有 AI 引擎：自己写也可以。');
    return ZNote('点 AI 按钮后，你写的内容会发送给：${_c.oracle.generateLabel}。', warn: true);
  }

  Widget _aiButton(String label, Future<void> Function() onTap, bool crisis) {
    if (!_c.oracle.sendsData) return const SizedBox.shrink();
    return OutlinedButton(
      onPressed: (_busy || crisis) ? null : onTap,
      child: Text(label),
    );
  }

  Widget _slider(String label, int v, void Function(int) on) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZNote('$label：$v / 100'),
        Slider(
          value: v.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$v',
          onChanged: (double x) => setState(() => on(x.round())),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String hint, {int lines = 3}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(controller: c, minLines: 1, maxLines: lines, decoration: zInput(hint)),
    );
  }

  Widget _stepBody(bool crisis) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ZNote('第一步：揪出那个想法。写下情境，和当时脑子里蹦出的那句话。'),
            _field(_sit, '情境：发生了什么'),
            _field(_bel, '当时脑子里的那句话'),
            _slider('我有多相信它', _pre, (int x) => _pre = x),
            const ZNote('像哪种想法陷阱？（可多选，只是线索）'),
            zMulti(
              labels: ZCopy.distortions,
              selected: _dis,
              onToggle: (String l) => setState(() {
                if (_dis.contains(l)) {
                  _dis.remove(l);
                } else {
                  _dis.add(l);
                }
              }),
            ),
            const SizedBox(height: 6),
            _disclosure(),
            _aiButton('让 AI 找出它背后的信念', _aiBeliefs, crisis),
            if (_hint0.isNotEmpty)
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final String h in _hint0)
                    ActionChip(
                      label: Text('＋ $h', style: const TextStyle(fontSize: 13)),
                      onPressed: () => setState(() {
                        _bel.text = _bel.text.trim().isEmpty ? h : '${_bel.text.trim()}；$h';
                      }),
                    ),
                ],
              ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ZNote('第二步：查证。只写事实，不写感受。'),
            _field(_evf, '支持这个想法的事实'),
            _field(_eva, '不支持、或相反的事实（有没有反例？）'),
            _disclosure(),
            _aiButton('让 AI 提三个查证的问题', _aiQuestions, crisis),
            if (_hint1.isNotEmpty) ZItem(child: Text(_hint1)),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ZNote('第三步：体验。想法要靠行为来检验，不是靠想。'),
            _field(_exp, '我可以做的一个小实验（小、可逆、不欺骗他人）'),
            _field(_how, '怎么做、做多久、怎么记录'),
            _disclosure(),
            _aiButton('让 AI 设计一个小实验', _aiExperiment, crisis),
            if (_hint2.isNotEmpty) ...<Widget>[
              ZItem(child: Text(_hint2)),
              TextButton(
                onPressed: () => setState(() => _exp.text = _hint2),
                child: const Text('采用这个'),
              ),
            ],
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ZNote('第四步：重设。写一个更贴近事实的说法，不是更乐观，而是更准确。'),
            _field(_alt, '更贴近事实的说法'),
            _slider('现在我有多相信原来那句话', _post, (int x) => _post = x),
            _field(_res, '这一轮我学到了什么（可选）'),
            _disclosure(),
            _aiButton('让 AI 写一个更贴近事实的说法', _aiAlt, crisis),
            if (_hint3.isNotEmpty) ...<Widget>[
              ZItem(child: Text(_hint3)),
              TextButton(
                onPressed: () => setState(() => _alt.text = _hint3),
                child: const Text('采用这个'),
              ),
            ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const List<String> names = <String>['揪出', '查证', '体验', '重设'];
    final List<ZEntry> history = _c.items('cog').reversed.toList();
    return ZPage(
      title: '认知重构',
      controller: _c,
      content: (BuildContext context) {
        final bool crisis = zAnyCrisis(_all);
        return <Widget>[
          const ZNote('一个想法把你带向了不想去的地方时，可以走这四步。这是自助练习，不诊断，不替代治疗。'),
          ZNote('第 ${_step + 1} / 4 步：${names[_step]}'),
          ZCrisisCard(controllers: _all),
          _stepBody(crisis),
          ZGuard(controllers: _all, app: _c),
          if (_msg.isNotEmpty) ZNote(_msg, warn: true),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              if (_step > 0)
                OutlinedButton(onPressed: () => _go(_step - 1), child: const Text('上一步')),
              if (_step > 0) const SizedBox(width: 8),
              if (_step < 3)
                FilledButton(
                  onPressed: crisis ? null : () => _go(_step + 1),
                  child: const Text('下一步'),
                )
              else
                FilledButton(
                  onPressed: crisis ? null : _save,
                  child: const Text('记下这一轮'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ZSection(
            title: '做过的几轮（${history.length}）',
            children: history.isEmpty
                ? const <Widget>[ZNote('还没有。')]
                : <Widget>[
                    for (final ZEntry h in history)
                      ZItem(
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('原来：${h.s('bel')}（${h.i('pre') ?? '-'}）'),
                                  Text('现在：${h.s('alt')}（原想法 ${h.i('post') ?? '-'}）',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (h.s('res').isNotEmpty) ZNote(h.s('res')),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _c.removeItem(h),
                            ),
                          ],
                        ),
                      ),
                  ],
          ),
        ];
      },
    );
  }
}
