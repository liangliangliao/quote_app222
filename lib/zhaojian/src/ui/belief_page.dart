import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/analysis.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 信念检验：把一个信念看成一张「远期汇票」。
/// 期限多久才见分晓？现在有什么证据？我为它付出了什么？谁在为它担保？若永不兑付会怎样？
class BeliefPage extends StatelessWidget {
  const BeliefPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  Widget build(BuildContext context) {
    final List<ZEntry> bills = controller.items('bill').reversed.toList();
    final int high = bills
        .where((ZEntry b) => _riskOf(b) == 2)
        .length;
    return ZPage(
      title: '信念检验',
      controller: controller,
      content: (BuildContext context) => <Widget>[
        const ZNote('一个深信的信念，像一张远期汇票：到期才知道能不能兑付。在到期之前，别拿真金白银押它。风险评级只是提醒，不是结论。'),
        ZSection(
          title: '开一张汇票',
          children: <Widget>[
            ZForm(
              fields: const <ZFieldSpec>[
                ZFieldSpec('t', '我深信的是…', lines: 2),
                ZFieldSpec('term', '期限：要到什么时候才见分晓'),
                ZFieldSpec('ev', '证据：现在有什么事实支持它'),
                ZFieldSpec('cost', '代价：我已经为它付出了什么'),
                ZFieldSpec('end', '背书：谁（或什么）在为它担保'),
                ZFieldSpec('nev', '若永不兑付：我会怎样'),
              ],
              mustFill: const <String>['t'],
              submitLabel: '开出这张汇票',
              onSubmit: (Map<String, String> v) async {
                await controller.addItem('bill', <String, dynamic>{
                  't': v['t'],
                  'term': v['term'],
                  'ev': v['ev'],
                  'cost': v['cost'],
                  'end': v['end'],
                  'nev': v['nev'],
                  'q': '',
                });
              },
            ),
          ],
        ),
        ZSection(
          title: '我的汇票（${bills.length}，高风险 $high）',
          children: bills.isEmpty
              ? const <Widget>[ZNote('还没有。')]
              : <Widget>[
                  for (final ZEntry b in bills)
                    _BillCard(key: ValueKey<int?>(b.id), controller: controller, item: b),
                ],
        ),
      ],
    );
  }
}

int _riskOf(ZEntry b) => billRisk(
      term: b.s('term'),
      evidence: b.s('ev'),
      endorser: b.s('end'),
      neverCashed: b.s('nev'),
    );

class _BillCard extends StatefulWidget {
  const _BillCard({super.key, required this.controller, required this.item});

  final ZhaojianController controller;
  final ZEntry item;

  @override
  State<_BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<_BillCard> {
  bool _busy = false;
  String _msg = '';

  Future<void> _challenge() async {
    final ZEntry b = widget.item;
    setState(() {
      _busy = true;
      _msg = 'AI 正在想…（约半分钟）';
    });
    final String raw = await widget.controller.oracle.generate(
      prompt: '用户深信的信念：「${b.s('t')}」。期限：${b.s('term')}。证据：${b.s('ev')}。'
      '已付代价：${b.s('cost')}。背书：${b.s('end')}。若永不兑付：${b.s('nev')}。'
      '请提出两个最尖锐、但公平的质疑（问事实，不问人格），再给一个最小的检验办法。'
      '不诊断，不说「你就是这样的人」，不替用户下结论。总共不超过 150 字。',
      purpose: 'zhaojian.belief_challenge',
    );
    if (!mounted) return;
    if (raw.trim().isNotEmpty) {
      b.data['q'] = raw.trim();
      await widget.controller.saveItem(b);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = raw.trim().isEmpty ? '没有可用的 AI，或没有完成。' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ZEntry b = widget.item;
    final int risk = _riskOf(b);
    return ZItem(
      warn: risk == 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(b.s('t'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Chip(
                label: Text('风险 ${ZCopy.billRisks[risk]}', style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                backgroundColor: risk == 2 ? const Color(0xFFF6DDCB) : zCard,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => widget.controller.removeItem(b),
              ),
            ],
          ),
          if (b.s('term').isNotEmpty) ZNote('期限：${b.s('term')}'),
          if (b.s('ev').isNotEmpty) ZNote('证据：${b.s('ev')}'),
          if (b.s('cost').isNotEmpty) ZNote('已付代价：${b.s('cost')}'),
          if (b.s('end').isNotEmpty) ZNote('背书：${b.s('end')}'),
          if (b.s('nev').isNotEmpty) ZNote('若永不兑付：${b.s('nev')}'),
          if (risk == 2)
            const ZNote('证据、背书、期限里缺得太多：在见到证据之前，别再往里加码。', warn: true),
          if (b.s('q').isNotEmpty) ZItem(child: Text(b.s('q'))),
          if (widget.controller.oracle.sendsData) ...<Widget>[
            ZNote('点后，这张汇票的内容会发送给：${widget.controller.oracle.generateLabel}。', warn: true),
            OutlinedButton(
              onPressed: _busy ? null : _challenge,
              child: Text(b.s('q').isEmpty ? '让 AI 质疑它' : '再质疑一次'),
            ),
          ],
          if (_msg.isNotEmpty) ZNote(_msg, warn: true),
        ],
      ),
    );
  }
}
