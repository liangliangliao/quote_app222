import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import '../zhaojian_oracle.dart';
import 'widgets.dart';

/// 选择：写下处境与选项 → 补全动机 → 体验卡 → 天平 → 封存预测。
class DecidePage extends StatefulWidget {
  const DecidePage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<DecidePage> createState() => _DecidePageState();
}

class _DecidePageState extends State<DecidePage> {
  static const List<String> _noteLabels = <String>[
    '后果的尽头：选 A 一年后会怎样？选 B 一年后呢？',
    '我深信但没验证的信念是什么？它是真的吗？',
    '过去类似的场合，我实际是怎么做的？（看行为，不看决心）',
  ];

  int _step = 0;

  final TextEditingController _q = TextEditingController();
  final TextEditingController _a = TextEditingController();
  final TextEditingController _b = TextEditingController();
  final TextEditingController _ownText = TextEditingController();
  final TextEditingController _cond = TextEditingController();
  final List<TextEditingController> _notes =
      List<TextEditingController>.generate(3, (int _) => TextEditingController());

  String _importance = '';

  final List<ZMotive> _ownMotives = <ZMotive>[];
  String _ownSide = 'a';
  String _ownKind = 'int';
  String _ownValence = 'ap';

  List<ZMotive> _cards = <ZMotive>[];
  int _ci = 0;
  int? _limit;
  List<ZRank>? _top;
  String _topSource = '';

  bool _busy = false;
  String _msg = '';

  String _pred = '';
  int _stake = 3;
  bool _recordFreedom = false;
  int _freedom = 5;
  int? _jtPred;

  @override
  void dispose() {
    _q.dispose();
    _a.dispose();
    _b.dispose();
    _ownText.dispose();
    _cond.dispose();
    for (final TextEditingController c in _notes) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- 公共

  List<ZMotive> _allMotives() {
    return <ZMotive>[
      ..._ownMotives,
      ..._cards.where((ZMotive m) => m.weight > 0),
    ];
  }

  String _situation() {
    final String profile =
        widget.controller.profileText(ZCopy.categories);
    return '用户的选择：「${_q.text.trim()}」。选项A：${_a.text.trim()}；'
        '选项B：${_b.text.trim()}。$profile';
  }

  void _go(int step) {
    setState(() {
      _step = step;
      _msg = '';
    });
  }

  String _sideName(String side) {
    if (side == 'a') return 'A：${_a.text.trim()}';
    if (side == 'b') return 'B：${_b.text.trim()}';
    return '两边';
  }

  // ---------------------------------------------------------------- 第 0 步

  Widget _stepQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZSection(
          title: '摆在面前的选择',
          children: <Widget>[
            TextField(
              controller: _q,
              maxLines: 2,
              decoration: zInput('你的处境或问题，如：他开口借钱，我怎么办？'),
            ),
            const SizedBox(height: 8),
            TextField(controller: _a, decoration: zInput('选项 A，如：借')),
            const SizedBox(height: 8),
            TextField(controller: _b, decoration: zInput('选项 B，如：不借')),
          ],
        ),
        ZSection(
          title: '这件事对我多重要？',
          children: <Widget>[
            zChoice(
              labels: ZCopy.importanceLevels
                  .map((String e) => '$e事')
                  .toList(),
              selected: ZCopy.importanceLevels.indexOf(_importance) < 0
                  ? null
                  : ZCopy.importanceLevels.indexOf(_importance),
              onSelect: (int i) =>
                  setState(() => _importance = ZCopy.importanceLevels[i]),
            ),
            const ZNote('叔本华说，除了无关紧要的小事，决定我们的多是抽象动机。标上重要度，之后可以检验这句话在你身上成不成立。'),
          ],
        ),
        FilledButton(
          onPressed: () {
            if (_a.text.trim().isEmpty || _b.text.trim().isEmpty) {
              zSnack(context, '请先写下 A、B 两个选项');
              return;
            }
            _go(1);
          },
          child: const Text('下一步：补全动机'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 第 1 步

  void _addOwn() {
    final String t = _ownText.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _ownMotives.add(ZMotive(
        text: t,
        cat: -1,
        kind: _ownKind,
        side: _ownSide,
        valence: _ownValence,
        weight: 3,
        rated: true,
        own: true,
      ));
      _ownText.clear();
    });
  }

  void _useLibrary({String message = ''}) {
    setState(() {
      _cards = buildMotiveLibrary();
      _ci = 0;
      _limit = null;
      _top = null;
      _msg = message;
      _step = 2;
    });
  }

  Future<void> _useAi() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = 'AI 正在补全动机…（约半分钟，请稍候）';
    });
    List<ZMotive> got = <ZMotive>[];
    try {
      got = await widget.controller.oracle
          .completeMotives(
            question: _q.text.trim(),
            optionA: _a.text.trim(),
            optionB: _b.text.trim(),
            profile: widget.controller.profileText(ZCopy.categories),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      got = <ZMotive>[];
    }
    if (!mounted) return;
    if (got.length < 20) {
      setState(() => _busy = false);
      _useLibrary(message: 'AI 暂不可用，已改用内置动机库（61 条）');
      return;
    }
    final List<ZMotive> merged = List<ZMotive>.from(got);
    if (merged.length < 50) {
      final Set<String> have = merged.map((ZMotive m) => m.text).toSet();
      for (final ZMotive m in buildMotiveLibrary()) {
        if (merged.length >= 50) break;
        if (!have.contains(m.text)) merged.add(m);
      }
    }
    setState(() {
      _busy = false;
      _cards = merged;
      _ci = 0;
      _limit = null;
      _top = null;
      _msg = '';
      _step = 2;
    });
  }

  Widget _stepComplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZSection(
          title: '我自己已想到的动机（可跳过）',
          children: <Widget>[
            TextField(controller: _ownText, decoration: zInput('一个动机')),
            const SizedBox(height: 6),
            zChoice(
              labels: <String>['拉向 A', '拉向 B', '两边'],
              selected: _ownSide == 'a' ? 0 : (_ownSide == 'b' ? 1 : 2),
              onSelect: (int i) => setState(
                  () => _ownSide = i == 0 ? 'a' : (i == 1 ? 'b' : 'both')),
            ),
            zChoice(
              labels: <String>['抽象', '直观'],
              selected: _ownKind == 'abs' ? 0 : 1,
              onSelect: (int i) =>
                  setState(() => _ownKind = i == 0 ? 'abs' : 'int'),
            ),
            zChoice(
              labels: <String>['想要', '害怕'],
              selected: _ownValence == 'ap' ? 0 : 1,
              onSelect: (int i) =>
                  setState(() => _ownValence = i == 0 ? 'ap' : 'av'),
            ),
            OutlinedButton(onPressed: _addOwn, child: const Text('添加')),
            for (int i = 0; i < _ownMotives.length; i++)
              ZItem(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_ownMotives[i].text}（${_sideName(_ownMotives[i].side)}）',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _ownMotives.removeAt(i)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ZSection(
          title: '动机补全',
          children: <Widget>[
            const ZNote('AI 会针对这个选择，补出你可能没意识到的约 60 条动机，每条配一个能让你「感到」它的画面。点击后，你填写的内容会发送给所配置的 AI 服务。没配置或不可用时，会用内置的 61 条动机库。'),
            FilledButton(
              onPressed: _busy ? null : _useAi,
              child: const Text('让 AI 补全（约 60 条）'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _busy ? null : () => _useLibrary(),
              child: const Text('用内置动机库（61 条，离线可用）'),
            ),
            if (_msg.isNotEmpty) ZNote(_msg, warn: true),
          ],
        ),
        OutlinedButton(onPressed: () => _go(0), child: const Text('上一步')),
      ],
    );
  }

  // ---------------------------------------------------------------- 第 2 步

  Future<void> _runTop() async {
    if (_busy || _cards.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = '正在为 ${_cards.length} 个动机打分…';
    });
    ZScoreResult res = const ZScoreResult();
    try {
      res = await widget.controller.oracle
          .scoreMotives(situation: _situation(), motives: _cards)
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      res = const ZScoreResult();
    }
    if (!mounted) return;
    final List<ZRank> ranks = rankTop5(
      _cards,
      res.pulls,
      confidences: res.confidences,
      missCats: widget.controller.missCats,
    );
    setState(() {
      _top = ranks;
      _topSource = res.isEmpty
          ? '规则推荐（按类别，不是个性化；接入 AI 后会逐个打分）'
          : res.source;
      _busy = false;
      _msg = '';
    });
  }

  void _onlyTop() {
    final List<ZRank>? top = _top;
    if (top == null || top.isEmpty) return;
    final List<ZMotive> first = top.map((ZRank r) => r.motive).toList();
    setState(() {
      _cards = <ZMotive>[
        ...first,
        ..._cards.where(
            (ZMotive m) => !first.any((ZMotive f) => identical(f, m))),
      ];
      _limit = first.length;
      _ci = 0;
    });
  }

  Widget _topBox() {
    final List<ZRank>? top = _top;
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '推荐：最该先感受的 5 个动机',
            style: TextStyle(fontWeight: FontWeight.w700, color: zInk),
          ),
          ZNote(
              '对全部 ${_cards.length} 个动机逐个打分（拉力 0 到 4），再按拉力、置信度和你常漏的类别排序，每类最多 2 个。'),
          if (widget.controller.oracle.sendsData)
            ZNote('点击后，题面和动机文字会发送给：${widget.controller.oracle.label}。', warn: true),
          FilledButton(
            onPressed: _busy ? null : _runTop,
            child: Text(top == null ? '为全部动机打分，推荐前 5' : '重新打分'),
          ),
          if (_msg.isNotEmpty) ZNote(_msg, warn: true),
          if (top != null) ...<Widget>[
            const SizedBox(height: 6),
            for (int k = 0; k < top.length; k++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${k + 1}. ${top[k].motive.text}'
                        '（${top[k].motive.cat >= 0 ? ZCopy.categories[top[k].motive.cat] : '自己写的'}'
                        '${top[k].scored ? '，拉力 ${top[k].pull.toStringAsFixed(1)}/4' : ''}'
                        '${top[k].confidence != null ? '，置信 ${zPercent(top[k].confidence)}' : ''}'
                        '${top[k].badge.isNotEmpty ? '，${top[k].badge}' : ''}）',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final int i = _cards.indexOf(top[k].motive);
                        if (i >= 0) setState(() => _ci = i);
                      },
                      child: const Text('先评这个'),
                    ),
                  ],
                ),
              ),
            OutlinedButton(
              onPressed: _onlyTop,
              child: const Text('只评这 5 个，然后看天平'),
            ),
            ZNote('打分来源：$_topSource。分数只是排序的依据，不是结论；你自己的感受才是最后的权重。'),
          ],
        ],
      ),
    );
  }

  Widget _stepCards() {
    if (_cards.isEmpty) {
      return Column(
        children: <Widget>[
          const Text('还没有动机卡片'),
          OutlinedButton(onPressed: () => _go(1), child: const Text('回上一步')),
        ],
      );
    }
    final int total = _limit ?? _cards.length;
    final ZMotive c = _cards[_ci];
    final ZImagery im = imageryOf(_cards);
    final int rated = _cards.where((ZMotive m) => m.weight > 0).length;
    final String catName = c.cat >= 0 ? ZCopy.categories[c.cat] : '自己写的';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _topBox(),
        ZNote('第 ${_ci + 1} / $total 张 · $catName${c.ai ? ' · AI' : ''}　已评分 $rated'),
        Text(
          c.text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: zInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(c.scene, style: const TextStyle(fontSize: 14, height: 1.6)),
        if (c.cat == ZCopy.hiddenCategory)
          const ZNote('这类动机最容易被遗漏，到时却很有力量。', warn: true),
        const SizedBox(height: 10),
        const ZNote('先把画面补全：点你真的在脑子里想象到的（两边都要想，别漏了最坏的一刻）'),
        zMulti(
          labels: ZCopy.imageryTags,
          selected: c.imagery,
          onToggle: (String l) => setState(() {
            final List<String> next = List<String>.from(c.imagery);
            if (next.contains(l)) {
              next.remove(l);
            } else {
              next.add(l);
            }
            c.imagery = next;
          }),
        ),
        ZNote(
            '想象进度：已补全画面 ${im.count} 张，平均每张 ${im.average.toStringAsFixed(1)}/5；A 侧 ${im.a}、B 侧 ${im.b}；最坏的一刻：${im.worst ? '已想' : '还没想'}。'
            '${im.lopsided ? '两边想象得不对称，天平可能偏向想得更生动的一边。' : ''}',
            warn: im.lopsided),
        const SizedBox(height: 8),
        const ZNote('闭上眼感受一下：它此刻在你身上有多重？'),
        zChoice(
          labels: ZCopy.weightLabels,
          selected: c.rated ? c.weight : null,
          onSelect: (int i) => setState(() {
            c.weight = i;
            c.rated = true;
          }),
        ),
        const ZNote('它把人拉向哪边？'),
        zChoice(
          labels: <String>[
            'A：${_a.text.trim()}',
            'B：${_b.text.trim()}',
            '两边'
          ],
          selected: c.side == 'a' ? 0 : (c.side == 'b' ? 1 : 2),
          onSelect: (int i) => setState(
              () => c.side = i == 0 ? 'a' : (i == 1 ? 'b' : 'both')),
        ),
        const ZNote('对你来说，它是「想要」还是「害怕」？'),
        zChoice(
          labels: <String>['想要/靠近', '害怕/回避'],
          selected: c.valence == 'ap' ? 0 : 1,
          onSelect: (int i) =>
              setState(() => c.valence = i == 0 ? 'ap' : 'av'),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            OutlinedButton(
              onPressed: _ci > 0 ? () => setState(() => _ci -= 1) : null,
              child: const Text('上一张'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (_ci + 1 >= total) {
                  _go(3);
                } else {
                  setState(() => _ci += 1);
                }
              },
              child: const Text('下一张'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _go(3),
              child: const Text('够了，看天平'),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 第 3 步

  Widget _stepBalance() {
    final List<ZMotive> all = _allMotives();
    final ZSums s = sumMotives(all);
    final ZConflict cf = conflictOf(all);
    final ZImagery im = imageryOf(_cards);
    final double mx = s.maxValue;
    final List<ZMotive> top = List<ZMotive>.from(all)
      ..sort((ZMotive x, ZMotive y) => y.weight.compareTo(x.weight));
    String letter(String? side) => side == 'a' ? 'A' : 'B';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZSection(
          title: '动机的天平',
          children: <Widget>[
            Text('A：${_a.text.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ZBar(
                label: '抽象（现在在场） ${s.aAbs.toStringAsFixed(1)}',
                value: s.aAbs / mx),
            ZBar(
                label: '直观（到现场才出场） ${s.aInt.toStringAsFixed(1)}',
                value: s.aInt / mx),
            const SizedBox(height: 4),
            Text('B：${_b.text.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ZBar(
                label: '抽象（现在在场） ${s.bAbs.toStringAsFixed(1)}',
                value: s.bAbs / mx),
            ZBar(
                label: '直观（到现场才出场） ${s.bInt.toStringAsFixed(1)}',
                value: s.bInt / mx),
            if (all.isEmpty)
              const ZNote('还没有评分的动机，回上一步感受几张。', warn: true)
            else
              ZNote(lanesDisagree(s)
                  ? '理性动机偏向 ${letter(absLean(s))}，直观动机偏向 ${letter(intLean(s))}。'
                      '事先理性占上风，只因它在场；到现场，直观动机可能骤然反转。'
                  : '两类动机方向大体一致，到时的决定相对稳定。'),
            if (im.lopsided)
              const ZItem(
                warn: true,
                child: Text('你对一边想象得明显更多：天平可能偏向想得更生动的一边，先把另一边也补全。'),
              ),
          ],
        ),
        if (all.isNotEmpty)
          ZSection(
            title: '动机冲突诊断：${ZCopy.conflictTypes[cf.type][0]}',
            children: <Widget>[
              ZNote(
                  'A：想要 ${cf.aAp.toStringAsFixed(1)} / 害怕 ${cf.aAv.toStringAsFixed(1)}　B：想要 ${cf.bAp.toStringAsFixed(1)} / 害怕 ${cf.bAv.toStringAsFixed(1)}'),
              Text(ZCopy.conflictTypes[cf.type][1]),
            ],
          ),
        if (top.isNotEmpty)
          ZSection(
            title: '最重的几个',
            children: <Widget>[
              for (final ZMotive m in top.take(6))
                ZItem(
                  child: Text(
                    '${m.text}　${m.weight} 分 · ${m.isAbstract ? '抽象' : '直观'} · ${_sideName(m.side)}',
                  ),
                ),
            ],
          ),
        ZSection(
          title: '再想三件事（可跳过）',
          children: <Widget>[
            for (int i = 0; i < 3; i++) ...<Widget>[
              ZNote(_noteLabels[i]),
              TextField(controller: _notes[i], maxLines: 2, decoration: zInput('')),
              const SizedBox(height: 6),
            ],
          ],
        ),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(2), child: const Text('回卡片')),
            const SizedBox(width: 8),
            FilledButton(
                onPressed: () => _go(4), child: const Text('下一步：下注')),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 第 4 步

  Future<void> _seal() async {
    if (_pred.isEmpty) {
      zSnack(context, '请选择 A 或 B');
      return;
    }
    final List<ZMotive> all = _allMotives()
      ..sort((ZMotive x, ZMotive y) => y.weight.compareTo(x.weight));
    final ZImagery im = imageryOf(_cards);
    final ZDecision d = ZDecision(
      question: _q.text.trim(),
      optionA: _a.text.trim(),
      optionB: _b.text.trim(),
      importance: _importance,
      motives: all,
      pred: _pred,
      stake: _stake,
      feltFreedom: _recordFreedom ? _freedom : null,
      condition: _cond.text.trim(),
      jtPred: _jtPred,
      conflictType: conflictOf(all).type,
      sealedAt: DateTime.now(),
      notes: _notes.map((TextEditingController c) => c.text.trim()).toList(),
      imageryDepth: im.count == 0 ? null : im.average,
      imagerySymmetry: im.symmetry,
    );
    await widget.controller.seal(d);
    if (!mounted) return;
    zSnack(context, '已封存。现场发生后，到「未开的牌」开牌。');
    Navigator.of(context).pop(true);
  }

  Widget _stepBet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZSection(
          title: '下注：封存你的预测',
          children: <Widget>[
            const ZNote('牌其实已经发好：决定由你的性格与到时在场的动机决定，只是还没进入你的知性。押一个，封存起来，等现场发生再开牌。筹码是虚拟的：押得越满，对了赚得越多，错了亏得越多。'),
            zChoice(
              labels: <String>[
                '我会选 A：${_a.text.trim()}',
                '我会选 B：${_b.text.trim()}',
              ],
              selected: _pred == 'a' ? 0 : (_pred == 'b' ? 1 : null),
              onSelect: (int i) => setState(() => _pred = i == 0 ? 'a' : 'b'),
            ),
            ZNote('下注筹码：$_stake / 5'),
            Slider(
              value: _stake.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_stake',
              onChanged: (double v) => setState(() => _stake = v.round()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('记录「此刻我觉得两边都有可能的程度」',
                  style: TextStyle(fontSize: 14)),
              value: _recordFreedom,
              onChanged: (bool v) => setState(() => _recordFreedom = v),
            ),
            if (_recordFreedom) ...<Widget>[
              ZNote('两边都有可能的程度：$_freedom / 10'),
              Slider(
                value: _freedom.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$_freedom',
                onChanged: (double v) => setState(() => _freedom = v.round()),
              ),
            ],
            TextField(
              controller: _cond,
              decoration: zInput('我在等什么条件出现？（到时可打开「现场速查」）'),
            ),
            const SizedBox(height: 8),
            const ZNote('我预计到时会以哪种方式做决定？（詹姆斯五种决策，可跳过）'),
            zChoice(
              labels: ZCopy.jamesTypes.map((List<String> t) => t[0]).toList(),
              selected: _jtPred,
              onSelect: (int i) => setState(() => _jtPred = i),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(3), child: const Text('回天平')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _seal, child: const Text('封存预测')),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 外壳

  Widget _body() {
    switch (_step) {
      case 0:
        return _stepQuestion();
      case 1:
        return _stepComplete();
      case 2:
        return _stepCards();
      case 3:
        return _stepBalance();
      default:
        return _stepBet();
    }
  }

  @override
  Widget build(BuildContext context) {
    const List<String> names = <String>[
      '写下选择',
      '补全动机',
      '体验卡',
      '天平',
      '下注',
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('选择'),
        backgroundColor: Colors.white,
        foregroundColor: zInk,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: <Widget>[
          ZNote('第 ${_step + 1} / 5 步：${names[_step]}'),
          _body(),
        ],
      ),
    );
  }
}
