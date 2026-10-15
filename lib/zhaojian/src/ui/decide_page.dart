import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import '../domain/json_util.dart';
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

  // AI 列选项（10 选 5）与研判
  List<Map<String, dynamic>> _aiOpts = <Map<String, dynamic>>[];
  String _verdict = '';
  bool _verdictBusy = false;

  // 签名挑选与引擎预测
  int? _sigId;
  double? _engA;
  bool _engBusy = false;
  String _engMsg = '';

  // 一致度与难度
  final TextEditingController _desireText = TextEditingController();
  final List<ZDesire> _selDesires = <ZDesire>[];
  ZAlignResult _alignRes = const ZAlignResult();
  bool _useManual = false;
  int _manA = 50;
  int _manB = 50;
  String _manDiffA = '';
  String _manDiffB = '';

  @override
  void dispose() {
    _q.dispose();
    _a.dispose();
    _b.dispose();
    _ownText.dispose();
    _cond.dispose();
    _desireText.dispose();
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

  // ---------------------------------------------------------------- AI 辅助

  Future<void> _aiOptions() async {
    if (_busy) return;
    if (_q.text.trim().isEmpty) {
      zSnack(context, '先写下处境或问题');
      return;
    }
    setState(() {
      _busy = true;
      _msg = 'AI 正在列选项并打分…（约半分钟）';
    });
    final String raw = await widget.controller.oracle.generate(
      prompt: '用户的处境或问题：「${_q.text.trim()}」。${widget.controller.profileText(ZCopy.categories)}\n'
          '请列出 10 个与此高度相关、彼此真正不同的行动选项（包括看起来不体面但现实中常见的，包括「先不决定、拖一拖」，也包括折中和第三条路）。'
          '每个给出：t(选项，不超过14字)、gain(它保护或满足什么，不超过20字)、cost(它要付出或放弃什么，不超过20字)、'
          'fit(它在多大程度上通向用户真正想要的，0到100，50表示无关)、feas(现实中做到它的可行性，0到100)。'
          'fit 与 feas 是你的估计，信息不足就取接近 50，不要夸大。'
          '只输出 JSON 数组 [{"t":"","gain":"","cost":"","fit":0,"feas":0}]。',
      purpose: 'zhaojian.options',
      maxTokens: 3000,
    );
    if (!mounted) return;
    final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    for (final dynamic e in zParseArray(raw)) {
      if (e is! Map) continue;
      final String t = '${e['t'] ?? ''}'.trim();
      if (t.isEmpty) continue;
      int n100(dynamic v) {
        final num? x = v is num ? v : num.tryParse('$v');
        return x == null || x.isNaN ? 50 : x.round().clamp(0, 100).toInt();
      }

      final int fit = n100(e['fit']);
      final int feas = n100(e['feas']);
      list.add(<String, dynamic>{
        't': t,
        'gain': '${e['gain'] ?? ''}'.trim(),
        'cost': '${e['cost'] ?? ''}'.trim(),
        'fit': fit,
        'feas': feas,
        'sc': (0.65 * fit + 0.35 * feas).round(),
      });
    }
    list.sort((Map<String, dynamic> x, Map<String, dynamic> y) =>
        (y['sc'] as int).compareTo(x['sc'] as int));
    setState(() {
      _busy = false;
      _aiOpts = list.take(5).toList();
      _msg = list.isEmpty ? '没有可用的 AI，或没有完成。请自己写选项。' : '';
    });
  }

  Future<void> _aiVerdict() async {
    final List<ZMotive> all = _allMotives()
      ..sort((ZMotive x, ZMotive y) => y.weight.compareTo(x.weight));
    final ZSums s = sumMotives(all);
    final ZConflict cf = conflictOf(all);
    final StringBuffer lines = StringBuffer();
    for (final ZMotive m in all.take(12)) {
      lines.writeln('${m.text}｜${m.weight}分｜${m.isAbstract ? '抽象' : '直观'}｜'
          '${m.side == 'a' ? '拉向A' : (m.side == 'b' ? '拉向B' : '两边')}｜${m.valence == 'av' ? '害怕' : '想要'}');
    }
    setState(() => _verdictBusy = true);
    final String raw = await widget.controller.oracle.generate(
      prompt: '${_situation()}\n用户评过分的动机（动机｜分量｜类型｜拉向｜想要或害怕）：\n$lines'
          '天平：A 抽象 ${s.aAbs.toStringAsFixed(1)} 直观 ${s.aInt.toStringAsFixed(1)}；'
          'B 抽象 ${s.bAbs.toStringAsFixed(1)} 直观 ${s.bInt.toStringAsFixed(1)}；冲突类型：${ZCopy.conflictTypes[cf.type][0]}。\n'
          '请用不超过 200 字读一遍这架天平：哪边总体更强、抽象与直观是否分歧、到现场最可能的变数。'
          '不替用户决定，不说「你应该」，不诊断，结论是待检验的猜测。',
      purpose: 'zhaojian.verdict',
    );
    if (!mounted) return;
    setState(() {
      _verdictBusy = false;
      _verdict = raw.trim().isEmpty ? '没有可用的 AI，或没有完成。' : raw.trim();
    });
  }

  // ---------------------------------------------------------------- 签名与引擎预测

  /// 已确认的签名里，挑一个适用于这件事的；开牌时会问它应验了吗。
  Widget _sigPicker() {
    final List<ZEntry> sigs =
        widget.controller.items('sig').where((ZEntry e) => e.b('conf')).toList();
    if (sigs.isEmpty) return const SizedBox.shrink();
    final int idx = _sigId == null ? -1 : sigs.indexWhere((ZEntry e) => e.id == _sigId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        const ZNote('这件事适用你已确认的哪个签名？（可选；开牌时会问你它应验了吗）'),
        zChoice(
          labels: sigs.map((ZEntry e) => '如果${e.s('ifc')}，那么${e.s('then')}').toList(),
          selected: idx < 0 ? null : idx,
          onSelect: (int i) => setState(() {
            final int? sid = sigs[i].id;
            _sigId = _sigId == sid ? null : sid;
          }),
        ),
      ],
    );
  }

  /// 让 AI 引擎也预测一次「你会选 A 的概率」。结果存起来，开牌前不给你看，
  /// 免得影响你自己的判断；开牌时三方对照：你、引擎、实际。
  Widget _enginePicker() {
    if (!widget.controller.oracle.sendsData) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        const ZNote('让 AI 引擎也预测一次（可选）：开牌前不给你看，开牌时和你的预测、实际三方对照。它只是对照，不是标准答案。'),
        ZNote('点击后，题面和你评过分的动机会发送给：${widget.controller.oracle.generateLabel}。', warn: true),
        OutlinedButton(
          onPressed: _engBusy ? null : _enginePredict,
          child: Text(_engA == null ? '让引擎预测一次' : '重新预测（已记录）'),
        ),
        if (_engMsg.isNotEmpty) ZNote(_engMsg, warn: _engA == null),
      ],
    );
  }

  Future<void> _enginePredict() async {
    final List<ZMotive> all = _allMotives()
      ..sort((ZMotive x, ZMotive y) => y.weight.compareTo(x.weight));
    final StringBuffer lines = StringBuffer();
    for (final ZMotive m in all.take(12)) {
      lines.writeln('${m.text}｜${m.weight}分｜${m.isAbstract ? '抽象' : '直观'}｜'
          '${m.side == 'a' ? '拉向A' : (m.side == 'b' ? '拉向B' : '两边')}｜${m.valence == 'av' ? '害怕' : '想要'}');
    }
    setState(() {
      _engBusy = true;
      _engMsg = '';
    });
    final String raw = await widget.controller.oracle.generate(
      prompt: '${_situation()}\n评过分的动机（动机｜分量｜类型｜拉向｜想要或害怕）：\n$lines'
          '请估计：到了现场，这个人最终选 A 的概率（0 到 1 的小数）。这是对「现场会发生什么」的估计，不是建议。'
          '只输出 JSON {"a":0.0}。',
      purpose: 'zhaojian.engine_predict',
    );
    if (!mounted) return;
    final Map<String, dynamic>? o = zParseObject(raw);
    final dynamic a = o == null ? null : o['a'];
    setState(() {
      _engBusy = false;
      if (a is num) {
        _engA = a.toDouble().clamp(0.0, 1.0).toDouble();
        _engMsg = '已记录。引擎的预测要开牌时才揭晓。';
      } else {
        _engMsg = raw.trim().isEmpty ? '没有可用的 AI，或没有完成。' : 'AI 的回答没法解析。';
      }
    });
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
          title: '让 AI 帮我想选项（可选）',
          children: <Widget>[
            const ZNote('不确定有哪些选项时：AI 先列 10 个彼此不同的行动选项（包括不体面但常见的、拖一拖、折中和第三条路），自评一致度和可行性，取综合最高的 5 个。分数是 AI 的自评，不是决策引擎的打分。'),
            if (widget.controller.oracle.sendsData) ...<Widget>[
              ZNote('点击后，你写的处境会发送给：${widget.controller.oracle.generateLabel}。', warn: true),
              OutlinedButton(
                onPressed: _busy ? null : _aiOptions,
                child: const Text('让 AI 列出候选选项'),
              ),
            ] else
              const ZNote('没有 AI 引擎：请自己写 A、B 两个选项。'),
            if (_msg.isNotEmpty) ZNote(_msg, warn: true),
            for (final Map<String, dynamic> o in _aiOpts)
              ZItem(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${o['t']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ZNote('保护：${o['gain']}　付出：${o['cost']}'),
                    Text('综合 ${o['sc']}　一致度 ${o['fit']}　可行 ${o['feas']}', style: const TextStyle(fontSize: 13)),
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => setState(() => _a.text = '${o['t']}'),
                          child: const Text('设为 A'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _b.text = '${o['t']}'),
                          child: const Text('设为 B'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
          title: 'AI 研判（可选）',
          children: <Widget>[
            const ZNote('让 AI 用几句话把这架天平读一遍：哪边更强、抽象与直观是否分歧、到现场最可能的变数。它不替你决定，也不说「你应该」。'),
            if (widget.controller.oracle.sendsData) ...<Widget>[
              ZNote('点击后，题面和你评过分的动机会发送给：${widget.controller.oracle.generateLabel}。', warn: true),
              OutlinedButton(
                onPressed: _verdictBusy || all.isEmpty ? null : _aiVerdict,
                child: Text(_verdictBusy ? '研判中…' : '让 AI 研判这架天平'),
              ),
            ] else
              const ZNote('没有 AI 引擎：看上面的天平和冲突诊断就够了。'),
            if (_verdict.isNotEmpty) ZItem(child: Text(_verdict)),
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

  // ---------------------------------------------------------------- 一致度与难度

  List<ZDesire> _availableDesires() {
    final List<ZDesire> out = <ZDesire>[];
    for (final ZHypothesis h in widget.controller.hypotheses) {
      out.add(ZDesire(h.text, strong: h.status == 1));
    }
    out.sort((ZDesire x, ZDesire y) =>
        (y.strong ? 1 : 0).compareTo(x.strong ? 1 : 0));
    return out;
  }

  void _addDesire(ZDesire d) {
    if (_selDesires.contains(d)) return;
    if (_selDesires.length >= 3) {
      zSnack(context, '最多对照 3 条欲求');
      return;
    }
    setState(() {
      _selDesires.add(d);
      _alignRes = const ZAlignResult();
    });
  }

  void _removeDesire(int i) {
    setState(() {
      _selDesires.removeAt(i);
      _alignRes = const ZAlignResult();
    });
  }

  void _addManualDesire() {
    final String t = _desireText.text.trim();
    if (t.isEmpty) return;
    _addDesire(ZDesire(t));
    _desireText.clear();
  }

  Future<void> _runAlign() async {
    if (_busy) return;
    if (_selDesires.isEmpty) {
      zSnack(context, '先选一条要对照的欲求（可手写）');
      return;
    }
    setState(() {
      _busy = true;
      _msg = '正在评估一致度与难度…（约半分钟）';
    });
    ZAlignResult res = const ZAlignResult();
    try {
      res = await widget.controller.oracle
          .scoreAlignment(
            situation: _situation(),
            optionA: _a.text.trim(),
            optionB: _b.text.trim(),
            desires: List<ZDesire>.from(_selDesires),
          )
          .timeout(const Duration(seconds: 120));
    } catch (_) {
      res = const ZAlignResult();
    }
    if (!mounted) return;
    setState(() {
      _alignRes = res;
      _busy = false;
      _msg = res.isEmpty ? '没有可用的引擎，或评估没有完成。可以在下面自己评。' : '';
    });
  }

  ZAlignCalc? _alignCalc() {
    if (!_alignRes.isEmpty) return calcAlignment(_alignRes, _selDesires);
    if (_useManual) return manualAlignment(_manA, _manB);
    return null;
  }

  ZDifficulty _difficultyOf(String side) {
    if (!_alignRes.isEmpty) return side == 'a' ? _alignRes.diffA : _alignRes.diffB;
    return ZDifficulty(tier: side == 'a' ? _manDiffA : _manDiffB);
  }

  ZAlignSummary? _alignSummary() {
    final ZAlignCalc? c = _alignCalc();
    if (c == null) return null;
    return ZAlignSummary(
      yearA: c.yearA,
      yearB: c.yearB,
      diffA: _difficultyOf('a').tier,
      diffB: _difficultyOf('b').tier,
      manual: c.manual,
      weakOnly: c.weakOnly,
    );
  }

  String _reasonOf(String side) {
    if (_alignRes.isEmpty) return '';
    final List<String> parts = <String>[];
    for (final ZAlignRow r in _alignRes.rows) {
      final String t = side == 'a' ? r.reasonA : r.reasonB;
      if (t.trim().isNotEmpty) parts.add(t.trim());
    }
    return parts.join('；');
  }

  Widget _alignCard(String side, ZAlignCalc c, ZSums s) {
    final bool a = side == 'a';
    final int year = c.yearOf(side);
    final double share = pullShare(s, side);
    final int q = quadrantOf(year, share);
    final ZDifficulty d = _difficultyOf(side);
    final String reason = _reasonOf(side);
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${a ? 'A' : 'B'}：${(a ? _a : _b).text.trim()}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
              '一致度：本周 ${a ? c.weekA : c.weekB} · 一年 $year · 十年 ${a ? c.decadeA : c.decadeB}'
              '${c.manual ? '' : '（一年的范围 ${a ? c.loA : c.loB}–${a ? c.hiA : c.hiB}）'}'),
          const ZNote('50 表示无关，低于 50 是在背离。'),
          ZBar(label: '一年的一致度', value: year / 100),
          Text('拉力：${zPercent(share)}（来自天平）'),
          Text(ZCopy.quadrants[q][0],
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(ZCopy.quadrants[q][1]),
          const SizedBox(height: 4),
          Text(
              '难度：${d.tier.isEmpty ? '未评' : d.tier}'
              '${d.ring.isEmpty ? '' : ' · 要动「${d.ring}」'}'
              '${d.reason.isEmpty ? '' : ' · ${d.reason}'}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (d.ladder.isNotEmpty)
            ZNote('阶梯：${<String>[
              for (int i = 0; i < d.ladder.length; i++)
                '${<String>['小', '中', '大'][i]}：${d.ladder[i]}',
            ].join('　')}'),
          if (d.externals.isNotEmpty)
            ZNote('外部条件：${d.externals.map((ZExternal e) => '[${e.control}]${e.text}').join('；')}'),
          if (d.externals.any((ZExternal e) => e.uncontrollable))
            const ZNote('有不可控的外部条件：这个选项的难度不只取决于你。', warn: true),
          if (reason.isNotEmpty) ZNote('依据：$reason'),
        ],
      ),
    );
  }

  Widget _stepAlign() {
    final ZAlignCalc? c = _alignCalc();
    final ZSums s = sumMotives(_allMotives());
    final List<ZDesire> avail = _availableDesires()
        .where((ZDesire d) => !_selDesires.contains(d))
        .toList();
    final bool engine = widget.controller.oracle.sendsData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZSection(
          title: '一致度与难度：哪个选择更通向你要的？',
          children: <Widget>[
            const ZNote(ZCopy.alignmentNote),
            const ZNote('已选对照的欲求（点叉移除）'),
            if (_selDesires.isEmpty)
              const ZNote('还没选。可以从下面的假设里选，也可以手写一条。', warn: true)
            else
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (int i = 0; i < _selDesires.length; i++)
                    InputChip(
                      label: Text(
                        '${_selDesires[i].text} · ${_selDesires[i].strong ? '被行为支持' : '自述'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onDeleted: () => _removeDesire(i),
                    ),
                ],
              ),
            if (_selDesires.isNotEmpty && _selDesires.every((ZDesire d) => !d.strong))
              const ZNote('目前只有自述类欲求：结果只作参考。', warn: true),
            if (avail.isNotEmpty)
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final ZDesire d in avail)
                    ActionChip(
                      label: Text(
                        '＋ ${d.text} · ${d.strong ? '被行为支持' : '自述'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () => _addDesire(d),
                    ),
                ],
              ),
            const SizedBox(height: 6),
            TextField(
              controller: _desireText,
              decoration: zInput('手写一条我认为自己真正想要的（算自述）'),
            ),
            OutlinedButton(
              onPressed: _addManualDesire,
              child: const Text('加入对照'),
            ),
          ],
        ),
        ZSection(
          children: <Widget>[
            if (engine) ...<Widget>[
              ZNote('点击后，题面和所选欲求会发送给：${widget.controller.oracle.label}。', warn: true),
              FilledButton(
                onPressed: _busy ? null : _runAlign,
                child: const Text('评估一致度与难度'),
              ),
            ] else
              const ZNote('没有 AI 引擎：请在下面自己评。'),
            if (_msg.isNotEmpty) ZNote(_msg, warn: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自己评（自述，弱证据）', style: TextStyle(fontSize: 14)),
              value: _useManual,
              onChanged: (bool v) => setState(() => _useManual = v),
            ),
            if (_useManual) ...<Widget>[
              ZNote('A 对我真正要的帮助：$_manA'),
              Slider(
                value: _manA.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_manA',
                onChanged: (double v) => setState(() => _manA = v.round()),
              ),
              ZNote('B 对我真正要的帮助：$_manB'),
              Slider(
                value: _manB.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$_manB',
                onChanged: (double v) => setState(() => _manB = v.round()),
              ),
              const ZNote('A 的难度：'),
              zChoice(
                labels: ZCopy.difficultyTiers,
                selected: ZCopy.difficultyTiers.indexOf(_manDiffA) < 0
                    ? null
                    : ZCopy.difficultyTiers.indexOf(_manDiffA),
                onSelect: (int i) =>
                    setState(() => _manDiffA = ZCopy.difficultyTiers[i]),
              ),
              const ZNote('B 的难度：'),
              zChoice(
                labels: ZCopy.difficultyTiers,
                selected: ZCopy.difficultyTiers.indexOf(_manDiffB) < 0
                    ? null
                    : ZCopy.difficultyTiers.indexOf(_manDiffB),
                onSelect: (int i) =>
                    setState(() => _manDiffB = ZCopy.difficultyTiers[i]),
              ),
              const ZNote('自评是自述，不是证据；也可以不评，直接下一步。'),
            ],
          ],
        ),
        if (c != null) ...<Widget>[
          _alignCard('a', c, s),
          _alignCard('b', c, s),
          if (c.confidence != null)
            ZNote(
                '模型置信 ${zPercent(_alignRes.confidence)}，按欲求的证据等级封顶后为 ${zPercent(c.confidence)}。'
                '${c.confidence! < 0.6 ? '置信偏低，只作参考。' : ''}',
                warn: c.confidence! < 0.6),
          if (c.flip)
            const ZNote('排序随欲求而变：结论取决于你到底要什么，先去验证欲求（在「主线与假设」里用行为检验）。', warn: true),
        ],
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(3), child: const Text('上一步')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _go(5), child: const Text('下一步：下注')),
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
      align: _alignSummary(),
    );
    final int id = await widget.controller.seal(d);
    if (_sigId != null) await widget.controller.setKv('sig.$id', '$_sigId');
    if (_engA != null) await widget.controller.setKv('eng.$id', '$_engA');
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
            _sigPicker(),
            _enginePicker(),
          ],
        ),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => _go(4), child: const Text('回一致度')),
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
      case 4:
        return _stepAlign();
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
      '一致度与难度',
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
          ZNote('第 ${_step + 1} / 6 步：${names[_step]}'),
          _body(),
        ],
      ),
    );
  }
}
