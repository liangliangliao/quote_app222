import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import '../domain/json_util.dart';
import 'nav.dart';
import 'widgets.dart';

/// 改变引擎：目标与现状 → 分诊 → 三处设计 → 最小动作。
///
/// 只改认识、动机局面、行为与环境，不去改根本欲求。
class EnginePage extends StatefulWidget {
  const EnginePage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<EnginePage> createState() => _EnginePageState();
}

class _EnginePageState extends State<EnginePage> {
  int _step = 0;
  final TextEditingController _goal = TextEditingController();
  final TextEditingController _cur0 = TextEditingController();
  final TextEditingController _cur1 = TextEditingController();
  final TextEditingController _cur2 = TextEditingController();
  int? _layer;
  String _triage = '';

  final TextEditingController _lv0 = TextEditingController();
  final TextEditingController _lv1 = TextEditingController();
  final TextEditingController _lv2 = TextEditingController();
  final Set<String> _env = <String>{};

  final TextEditingController _act = TextEditingController();
  final TextEditingController _chk = TextEditingController();

  bool _busy = false;
  String _msg = '';

  ZhaojianController get _c => widget.controller;

  List<TextEditingController> get _all => <TextEditingController>[
        _goal, _cur0, _cur1, _cur2, _lv0, _lv1, _lv2, _act, _chk,
      ];

  /// 文字一变就重建：第一步的「下一步」是否可点取决于有没有绝望迹象。
  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in _all) {
      c.addListener(_onText);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _all) {
      c.removeListener(_onText);
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
    return r;
  }

  String get _situation => '用户想改变：「${_goal.text.trim()}」。'
      '现在实际怎么做：${_cur0.text.trim()}。想变成：${_cur1.text.trim()}。'
      '已经试过：${_cur2.text.trim()}。';

  Future<void> _aiTriage() async {
    final String raw = await _generate(
      '$_situation\n请判断这件事卡在下面哪几层（最多 3 个，按可能性从高到低），每个给一句不超过 30 字的理由。'
      '层只能从这些里选：${ZCopy.layers.map((List<String> l) => l[0]).join('、')}。'
      '这只是待检验的猜测，不是诊断。只输出 JSON 数组 [{"l":"层名","why":"理由"}]。',
      'zhaojian.engine_triage',
    );
    if (raw.isEmpty) return;
    final List<String> lines = <String>[];
    for (final dynamic e in zParseArray(raw)) {
      if (e is! Map) continue;
      final String l = '${e['l'] ?? ''}'.trim();
      if (ZCopy.layers.any((List<String> x) => x[0] == l)) {
        lines.add('$l：${e['why'] ?? ''}');
      }
    }
    setState(() => _triage = lines.isEmpty ? '' : 'AI 的猜测（待你检验）：\n${lines.join('\n')}');
  }

  Future<void> _aiDesign() async {
    final String layer = _layer == null ? '未选' : ZCopy.layers[_layer!][0];
    final String raw = await _generate(
      '$_situation 分诊：$layer。请按「认识 / 动机局面 / 行为与环境」三处，设计一个小而可逆的改变方案。'
      '只输出 JSON 对象：{"k":"认识上要补什么(不超过40字)","m":"动机局面上要加什么(不超过40字，写成有画面的动机)",'
      '"a":"行为与环境上做什么(不超过40字)","env":["…"]}，env 只能从 [${ZCopy.envChecks.join(',')}] 里选。'
      '不改变用户的根本欲求，不诊断，不使用宿命式措辞。',
      'zhaojian.engine_design',
    );
    if (raw.isEmpty) return;
    final Map<String, dynamic>? o = zParseObject(raw);
    if (o == null) {
      setState(() => _msg = 'AI 的回答没法解析，自己写也可以。');
      return;
    }
    setState(() {
      _lv0.text = '${o['k'] ?? ''}'.trim();
      _lv1.text = '${o['m'] ?? ''}'.trim();
      _lv2.text = '${o['a'] ?? ''}'.trim();
      _env
        ..clear()
        ..addAll(zStrings(o['env']).where(ZCopy.envChecks.contains));
    });
  }

  Future<void> _save() async {
    if (_act.text.trim().isEmpty) {
      zSnack(context, '先写一个最小动作');
      return;
    }
    await _c.addItem('plan', <String, dynamic>{
      'goal': _goal.text.trim(),
      'cur': <String>[_cur0.text.trim(), _cur1.text.trim(), _cur2.text.trim()],
      'layer': _layer == null ? '' : ZCopy.layers[_layer!][0],
      'lv': <String>[_lv0.text.trim(), _lv1.text.trim(), _lv2.text.trim()],
      'env': _env.toList(),
      'act': _act.text.trim(),
      'chk': _chk.text.trim(),
      'st': '进行中',
      'fz': '',
      'fzw': '',
      'rd': 1,
      'rev': '',
    });
    if (!mounted) return;
    zSnack(context, '计划已存下，到「计划与复盘」里跟进。');
    Navigator.of(context).pop();
  }

  Widget _disclosure() {
    if (!_c.oracle.sendsData) {
      return const ZNote('没有 AI 引擎：自己写也可以。');
    }
    return ZNote('点 AI 按钮后，你写的内容会发送给：${_c.oracle.generateLabel}。', warn: true);
  }

  Widget _stepGoal() {
    final bool crisis = zAnyCrisis(<TextEditingController>[_goal, _cur0, _cur1, _cur2]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZNote('先说清楚想改变什么，和现在实际是怎么做的。看行为，不看决心。'),
        TextField(controller: _goal, minLines: 1, maxLines: 3, decoration: zInput('我想改变的是…')),
        const SizedBox(height: 8),
        TextField(controller: _cur0, minLines: 1, maxLines: 3, decoration: zInput('现在我实际上是怎么做的')),
        const SizedBox(height: 8),
        TextField(controller: _cur1, minLines: 1, maxLines: 3, decoration: zInput('我想变成怎样')),
        const SizedBox(height: 8),
        TextField(controller: _cur2, minLines: 1, maxLines: 3, decoration: zInput('已经试过什么、结果如何')),
        ZGuard(controllers: _all, app: _c),
        ZCrisisCard(controllers: <TextEditingController>[_goal, _cur0, _cur1, _cur2]),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: crisis
              ? null
              : () {
                  if (_goal.text.trim().isEmpty) {
                    zSnack(context, '先写下想改变什么');
                    return;
                  }
                  _go(1);
                },
          child: const Text('下一步：分诊'),
        ),
      ],
    );
  }

  Widget _stepTriage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZNote('卡在哪一层？分清了才知道该动哪里：多数时候要改的是认识、动机局面或环境，而不是「更努力」。'),
        zChoice(
          labels: ZCopy.layers.map((List<String> l) => l[0]).toList(),
          selected: _layer,
          onSelect: (int i) => setState(() => _layer = i),
        ),
        if (_layer != null)
          ZItem(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(ZCopy.layers[_layer!][1]),
                Text('方向：${ZCopy.layers[_layer!][2]}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        if (_layer == 4)
          const ZNote('这个目标和你根本的欲求相悖：不要去改根本欲求。换一个目标，或到「接受」里放下。', warn: true),
        if (_layer == 8)
          const ZNote('身体撑不住：先照顾身体。有持续的不适请咨询医生，这里不做诊断。', warn: true),
        const SizedBox(height: 8),
        _disclosure(),
        if (_c.oracle.sendsData)
          OutlinedButton(
            onPressed: _busy ? null : _aiTriage,
            child: const Text('让 AI 猜猜卡在哪几层'),
          ),
        if (_msg.isNotEmpty) ZNote(_msg, warn: true),
        if (_triage.isNotEmpty) ZItem(child: Text(_triage)),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(0), child: const Text('上一步')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (_layer == null) {
                  zSnack(context, '先选一层（拿不准就选最像的）');
                  return;
                }
                _go(2);
              },
              child: const Text('下一步：三处设计'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepDesign() {
    final int active = _c
        .items('plan')
        .where((ZEntry e) => e.s('st') == '进行中')
        .length;
    final List<ZEntry> shifts = _c.items('shift');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZNote('只动三处：认识、动机局面、行为与环境。根本欲求不动。'),
        TextField(controller: _lv0, minLines: 1, maxLines: 3, decoration: zInput('认识：我要补上或纠正什么认识')),
        const SizedBox(height: 8),
        TextField(controller: _lv1, minLines: 1, maxLines: 3, decoration: zInput('动机局面：加上什么、让它有画面')),
        const SizedBox(height: 8),
        TextField(controller: _lv2, minLines: 1, maxLines: 3, decoration: zInput('行为与环境：我做什么、环境怎么改')),
        const ZNote('环境清单（可多选）'),
        zMulti(
          labels: ZCopy.envChecks,
          selected: _env,
          onToggle: (String l) => setState(() {
            if (_env.contains(l)) {
              _env.remove(l);
            } else {
              _env.add(l);
            }
          }),
        ),
        ZGuard(controllers: _all, app: _c),
        if (shifts.isNotEmpty)
          ZNote('你曾被「${shifts.last.s('mot').isEmpty ? shifts.last.s('bf') : shifts.last.s('mot')}」真正改变过：优先试同类的方式。'),
        if (active >= 3)
          ZNote('手上已有 $active 个进行中的计划：别同时铺太多，先做完一个。', warn: true),
        const SizedBox(height: 6),
        _disclosure(),
        if (_c.oracle.sendsData)
          OutlinedButton(
            onPressed: _busy ? null : _aiDesign,
            child: const Text('让 AI 起草三处设计'),
          ),
        if (_msg.isNotEmpty) ZNote(_msg, warn: true),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(1), child: const Text('上一步')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _go(3), child: const Text('下一步：最小动作')),
          ],
        ),
      ],
    );
  }

  Widget _stepAct() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ZNote('把它缩小到两分钟内能开始的一个动作。小到不需要意志力。'),
        TextField(controller: _act, minLines: 1, maxLines: 3, decoration: zInput('最小动作：我现在就能做的一件小事')),
        const SizedBox(height: 8),
        TextField(controller: _chk, minLines: 1, maxLines: 2, decoration: zInput('什么时候、怎么检查它做没做（可选）')),
        ZGuard(controllers: _all, app: _c),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(2), child: const Text('上一步')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _save, child: const Text('存成计划')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () => ZNav.open(context, _c, ZDest.rope),
              child: const Text('去系一根绳子'),
            ),
            TextButton(
              onPressed: () => ZNav.open(context, _c, ZDest.wall),
              child: const Text('去做个小实验'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const List<String> names = <String>['目标与现状', '分诊', '三处设计', '最小动作'];
    return ZPage(
      title: '改变引擎',
      controller: _c,
      content: (BuildContext context) => <Widget>[
        ZNote('第 ${_step + 1} / 4 步：${names[_step]}'),
        if (_step == 0)
          _stepGoal()
        else if (_step == 1)
          _stepTriage()
        else if (_step == 2)
          _stepDesign()
        else
          _stepAct(),
      ],
    );
  }
}
