import 'dart:async';

import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 未开的牌：现场速查、开牌、自知分。
class PendingPage extends StatelessWidget {
  const PendingPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final List<ZDecision> pending = controller.pending;
        final List<ZDecision> done =
            controller.revealed.reversed.take(8).toList();
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('未开的牌'),
            backgroundColor: Colors.white,
            foregroundColor: zInk,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              ZSection(
                title: '未开的牌',
                children: pending.isEmpty
                    ? const <Widget>[ZNote('没有未开的牌。去「选择」押一次。')]
                    : pending
                        .map((ZDecision d) => _PendingTile(
                              key: ValueKey<int?>(d.id),
                              controller: controller,
                              decision: d,
                            ))
                        .toList(),
              ),
              ZSection(
                title: '已开的牌 · 自知分 ${totalSelfScore(controller.revealed)}',
                children: done.isEmpty
                    ? const <Widget>[ZNote('还没有开过的牌。')]
                    : done.map(_doneTile).toList(),
              ),
              const ZNote('自知分：命中加筹码，落空扣筹码。目的是看清你对自己有多了解，不是赢，也没有任何随机奖励。'),
            ],
          ),
        );
      },
    );
  }

  Widget _doneTile(ZDecision d) {
    final String pred = d.pred == 'a' ? d.optionA : d.optionB;
    final String actual = d.actual == 'a' ? d.optionA : d.optionB;
    return ZItem(
      warn: !d.hit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(d.question.isEmpty ? '(未写)' : d.question,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          ZNote(
              '你押：$pred　实际：$actual　${d.hit ? '命中 +${d.stake}' : '落空 −${d.stake}'}　事后：${d.reaction ?? ''}'),
        ],
      ),
    );
  }
}

class _PendingTile extends StatefulWidget {
  const _PendingTile({
    super.key,
    required this.controller,
    required this.decision,
  });

  final ZhaojianController controller;
  final ZDecision decision;

  @override
  State<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends State<_PendingTile> {
  bool _quick = false;

  Widget _quickCard(ZDecision d) {
    final List<ZMotive> ms = List<ZMotive>.from(d.motives)
      ..sort((ZMotive x, ZMotive y) => y.weight.compareTo(x.weight));
    List<ZMotive> side(String k) =>
        ms.where((ZMotive m) => m.side == k || m.side == 'both').take(2).toList();
    Widget list(List<ZMotive> a) {
      if (a.isEmpty) return const ZNote('无记录');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ZMotive m in a)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('· ${m.text}（${m.isAbstract ? '抽象' : '直观'}${m.weight}）'),
                  if (m.scene.isNotEmpty) ZNote(m.scene),
                ],
              ),
            ),
        ],
      );
    }

    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('现场速查（30 秒）',
              style: TextStyle(fontWeight: FontWeight.w700)),
          if (d.condition.isNotEmpty) Text('我在等：${d.condition}'),
          const SizedBox(height: 4),
          Text('拉向 A：${d.optionA}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          list(side('a')),
          Text('拉向 B：${d.optionB}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          list(side('b')),
          const SizedBox(height: 4),
          const Text('冷静三问', style: TextStyle(fontWeight: FontWeight.w700)),
          for (int i = 0; i < ZCopy.coolQuestions.length; i++)
            Text('${i + 1}. ${ZCopy.coolQuestions[i]}'),
          const ZNote('你的预测仍然封存，开牌后才揭晓。事先的「理性占优」只因它在场；到现场，另一方可能强烈得多。'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ZDecision d = widget.decision;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: zCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(d.question.isEmpty ? '(未写问题)' : d.question,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: zInk)),
          Text('${d.optionA}  /  ${d.optionB}',
              style: const TextStyle(fontSize: 13, color: zMuted)),
          ZNote(
              '预测已封存，押了 ${d.stake} 个筹码，等现场发生再开牌${d.condition.isEmpty ? '' : '；我在等：${d.condition}'}'),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RevealPage(
                      controller: widget.controller,
                      decision: d,
                    ),
                  ));
                },
                child: const Text('开牌'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => _quick = !_quick),
                child: Text(_quick ? '收起速查' : '现场速查'),
              ),
            ],
          ),
          if (_quick) _quickCard(d),
        ],
      ),
    );
  }
}

/// 开牌页：选实际结果和事后反应，然后翻牌。
class RevealPage extends StatefulWidget {
  const RevealPage({
    super.key,
    required this.controller,
    required this.decision,
  });

  final ZhaojianController controller;
  final ZDecision decision;

  @override
  State<RevealPage> createState() => _RevealPageState();
}

class _RevealPageState extends State<RevealPage> {
  String? _actual;
  int? _reaction;
  int? _jt;
  bool? _sigHit;
  final List<String> _body = <String>[];
  int? _hypId;
  String _hypKind = 'sup';
  bool _busy = false;

  Future<void> _reveal() async {
    final int? id = widget.decision.id;
    if (_actual == null || _reaction == null || id == null) {
      zSnack(context, '请选择实际选择和事后感觉');
      return;
    }
    setState(() => _busy = true);
    final ZDecision? d = await widget.controller.reveal(
      decisionId: id,
      actual: _actual!,
      reaction: ZCopy.reactions[_reaction!],
      jtActual: _jt,
      body: _body,
      hypId: _hypId,
      hypKind: _hypKind,
    );
    if (!mounted) return;
    final ZEntry? sig = widget.controller.signatureOf(widget.decision.id);
    if (sig != null && _sigHit != null) {
      final List<Map<String, dynamic>> log = sig.maps('log')
        ..add(<String, dynamic>{'ctx': widget.decision.question, 'hit': _sigHit});
      sig.data['log'] = log;
      await widget.controller.saveItem(sig);
    }
    if (!mounted) return;
    if (d != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) =>
            RevealDialog(controller: widget.controller, decision: d),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ZDecision d = widget.decision;
    final List<ZHypothesis> hyps = widget.controller.hypotheses;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('开牌'),
        backgroundColor: Colors.white,
        foregroundColor: zInk,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: <Widget>[
          Text(d.question.isEmpty ? '(未写问题)' : d.question,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: zInk)),
          const ZNote('预测已封存。先选现场实际发生的，再翻牌。'),
          ZSection(
            title: '实际选了：',
            children: <Widget>[
              zChoice(
                labels: <String>[d.optionA, d.optionB],
                selected: _actual == null ? null : (_actual == 'a' ? 0 : 1),
                onSelect: (int i) =>
                    setState(() => _actual = i == 0 ? 'a' : 'b'),
              ),
            ],
          ),
          ZSection(
            title: '事后第一反应：',
            children: <Widget>[
              zChoice(
                labels: ZCopy.reactions,
                selected: _reaction,
                onSelect: (int i) => setState(() => _reaction = i),
              ),
            ],
          ),
          ZSection(
            title: '这次决定是怎么发生的（可跳过）：',
            children: <Widget>[
              zChoice(
                labels:
                    ZCopy.jamesTypes.map((List<String> t) => t[0]).toList(),
                selected: _jt,
                onSelect: (int i) => setState(() => _jt = i),
              ),
            ],
          ),
          if (widget.controller.signatureOf(d.id) != null)
            ZSection(
              title: '封存时你挑了一个签名：',
              children: <Widget>[
                Text(
                    '如果${widget.controller.signatureOf(d.id)!.s('ifc')}，那么${widget.controller.signatureOf(d.id)!.s('then')}'),
                const ZNote('这次，它应验了吗？（如实选，落空也是证据）'),
                zChoice(
                  labels: const <String>['应验了', '落空了'],
                  selected: _sigHit == null ? null : (_sigHit! ? 0 : 1),
                  onSelect: (int i) => setState(() => _sigHit = i == 0),
                ),
              ],
            ),
          ZSection(
            title: '当时的身体信号（可多选，只是线索，不是诊断）：',
            children: <Widget>[
              zMulti(
                labels: ZCopy.bodySignals,
                selected: _body,
                onToggle: (String l) => setState(() {
                  if (_body.contains(l)) {
                    _body.remove(l);
                  } else {
                    _body.add(l);
                  }
                }),
              ),
            ],
          ),
          if (hyps.isNotEmpty)
            ZSection(
              title: '这次表达了哪条主线？（可选，会自动计入该假设）',
              children: <Widget>[
                zChoice(
                  labels: hyps.map((ZHypothesis h) => h.text).toList(),
                  selected: _hypId == null
                      ? null
                      : hyps.indexWhere((ZHypothesis h) => h.id == _hypId),
                  onSelect: (int i) => setState(() {
                    final int? hid = hyps[i].id;
                    _hypId = _hypId == hid ? null : hid;
                  }),
                ),
                if (_hypId != null)
                  zChoice(
                    labels: <String>['表达了它', '背离了它'],
                    selected: _hypKind == 'sup' ? 0 : 1,
                    onSelect: (int i) =>
                        setState(() => _hypKind = i == 0 ? 'sup' : 'ref'),
                  ),
              ],
            ),
          FilledButton(
            onPressed: _busy ? null : _reveal,
            child: const Text('翻牌'),
          ),
        ],
      ),
    );
  }
}

/// 翻牌仪式：你押的 → 实际 → 结果与回放。
class RevealDialog extends StatefulWidget {
  const RevealDialog({
    super.key,
    required this.controller,
    required this.decision,
  });

  final ZhaojianController controller;
  final ZDecision decision;

  @override
  State<RevealDialog> createState() => _RevealDialogState();
}

class _RevealDialogState extends State<RevealDialog> {
  int _stage = 0;
  Timer? _timer;
  int _missCat = -1;
  final TextEditingController _missText = TextEditingController();
  bool _missDone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), _next);
  }

  void _next() {
    if (!mounted) return;
    setState(() => _stage += 1);
    if (_stage < 3) {
      _timer = Timer(const Duration(milliseconds: 900), _next);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _missText.dispose();
    super.dispose();
  }

  String _name(ZDecision d, String? side) => side == 'a' ? d.optionA : d.optionB;

  Widget _replay(ZDecision d) {
    final List<ZMotive> ms = List<ZMotive>.from(d.motives)
      ..sort((ZMotive x, ZMotive y) => y.weight.compareTo(x.weight));
    if (ms.isEmpty) return const SizedBox.shrink();
    final List<ZMotive> mine = ms
        .where((ZMotive m) => m.side == d.actual || m.side == 'both')
        .take(2)
        .toList();
    final List<ZMotive> other = ms
        .where((ZMotive m) => m.side != d.actual && m.side != 'both')
        .take(2)
        .toList();
    String t(List<ZMotive> a) => a.isEmpty
        ? '无'
        : a
            .map((ZMotive m) =>
                '${m.text}（${m.isAbstract ? '抽象' : '直观'}${m.weight}）')
            .join('、');
    final String? f = followedKind(d);
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('旁观者视角：动机与行动并排',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Text('拉向你选的一边：${t(mine)}'),
          Text('拉向另一边：${t(other)}'),
          if (f != null) Text('当时抽象与直观指向不同，你的行动跟了「$f」动机。'),
        ],
      ),
    );
  }

  Widget _alignLine(ZDecision d) {
    final ZAlignSummary? al = d.align;
    final String? actual = d.actual;
    if (al == null || actual == null) return const SizedBox.shrink();
    final int mine = al.yearOf(actual);
    final int other = al.yearOf(actual == 'a' ? 'b' : 'a');
    final bool lower = mine < other;
    return ZNote(
      '你选的这一项一年一致度 $mine，另一项 $other${al.manual ? '（自评）' : ''}。'
      '${lower ? '你选了更不通向欲求的那一边：回头看看，是诱惑，还是手段错位。' : ''}',
      warn: lower,
    );
  }

  Widget _engLine(ZDecision d) {
    final double? pa = widget.controller.engineProbA(d.id);
    final String? actual = d.actual;
    if (pa == null || actual == null) return const SizedBox.shrink();
    final bool? hit = engineHit(pa, actual);
    return ZNote(
      'AI 引擎事先估计你选 A 的概率 ${zPercent(pa)}：${hit == null ? '没有倾向' : (hit ? '估对了' : '估错了')}。'
      '你自己${d.hit ? '对了' : '错了'}。引擎只是一个对照，不是标准答案。',
    );
  }

  Widget _missPrompt(ZDecision d) {
    if (d.missLogged || _missDone) return const SizedBox.shrink();
    if (!(opposesBalance(d) || !d.hit)) return const SizedBox.shrink();
    return ZItem(
      warn: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('天平可能漏了动机',
              style: TextStyle(fontWeight: FontWeight.w700)),
          ZNote(
              '${opposesBalance(d) ? '你的行动和天平上更重的一边相反。' : '你的预测落空了。'}什么动机没被列出，或被你低估了？'),
          zChoice(
            labels: ZCopy.categories,
            selected: _missCat < 0 ? null : _missCat,
            onSelect: (int i) => setState(() => _missCat = i),
          ),
          const SizedBox(height: 6),
          TextField(controller: _missText, decoration: zInput('一句话：那个动机是…')),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () async {
                  final int? id = d.id;
                  if (_missCat < 0 && _missText.text.trim().isEmpty) {
                    zSnack(context, '选一个类别或写一句话');
                    return;
                  }
                  await widget.controller.addMiss(
                    cat: _missCat,
                    text: _missText.text.trim(),
                    decisionId: id,
                  );
                  if (!mounted) return;
                  setState(() => _missDone = true);
                },
                child: const Text('登记'),
              ),
              TextButton(
                onPressed: () async {
                  final int? id = d.id;
                  if (id != null) await widget.controller.markMissLogged(id);
                  if (!mounted) return;
                  setState(() => _missDone = true);
                },
                child: const Text('跳过'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ZDecision d = widget.decision;
    final List<Widget> body = <Widget>[
      Text(d.question.isEmpty ? '' : d.question,
          style: const TextStyle(fontSize: 13, color: zMuted)),
      const SizedBox(height: 8),
    ];
    if (_stage < 1) {
      body.add(const Text('牌在翻……', style: TextStyle(fontSize: 22)));
    } else {
      body.add(Text('你押：${_name(d, d.pred)}（${d.stake} 个筹码）',
          style: const TextStyle(fontSize: 15)));
    }
    if (_stage >= 2) {
      body.add(const SizedBox(height: 6));
      body.add(Text('实际：${_name(d, d.actual)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)));
    }
    if (_stage >= 3) {
      body.add(const SizedBox(height: 6));
      body.add(Text(d.hit ? '命中，+${d.stake} 自知分。' : '落空，−${d.stake} 自知分。'));
      body.add(ZNote(d.hit
          ? '你对这次的自己判断得准。对了不等于认识了全部，下次换个情境再押。'
          : '落差就是线索：你以为的自己和实际的自己不一样。'));
      body.add(_replay(d));
      body.add(_alignLine(d));
      body.add(_engLine(d));
      body.add(_missPrompt(d));
    }
    return AlertDialog(
      title: const Text('开牌'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: body,
        ),
      ),
      actions: <Widget>[
        if (_stage >= 3)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
