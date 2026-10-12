import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 主线与假设：只有被后来的行为反复支持，才算认识了自己的一部分。
class HypothesisPage extends StatefulWidget {
  const HypothesisPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<HypothesisPage> createState() => _HypothesisPageState();
}

class _HypothesisPageState extends State<HypothesisPage> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _test = TextEditingController();

  static const List<String> _statusNames = <String>['待验证', '被行为支持', '被行为反驳'];

  @override
  void dispose() {
    _text.dispose();
    _test.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String t = _text.text.trim();
    if (t.isEmpty) {
      zSnack(context, '先写下一个假设');
      return;
    }
    await widget.controller.addHypothesis(t, _test.text.trim());
    if (!mounted) return;
    setState(() {
      _text.clear();
      _test.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<ZHypothesis> hs = widget.controller.hypotheses.reversed.toList();
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('主线与假设'),
            backgroundColor: Colors.white,
            foregroundColor: zInk,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              const ZNote(ZCopy.hypothesisRule),
              ZSection(
                title: '一个假设',
                children: <Widget>[
                  TextField(
                    controller: _text,
                    decoration: zInput('例：我在人情面前容易心软'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _test,
                    maxLines: 2,
                    decoration: zInput('检验：下次遇到什么情境，我预计会怎么做'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _add, child: const Text('加入检验')),
                ],
              ),
              ZSection(
                title: '我的假设',
                children: hs.isEmpty
                    ? const <Widget>[ZNote('还没有假设。')]
                    : hs.map(_tile).toList(),
              ),
              const ZNote('AI 的分析和你自己的猜测都只是假设。在「行为记录」和「开牌」里标注一个行为表达了哪条主线，会自动给它加一次支持或反驳。'),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(ZHypothesis h) {
    final int? id = h.id;
    return ZItem(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(h.text, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (h.test.isNotEmpty) ZNote('检验：${h.test}'),
          ZNote(
              '${_statusNames[h.status.clamp(0, 2)]} · 支持 ${h.sup.length} 次 / 反驳 ${h.ref.length} 次'),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: id == null
                    ? null
                    : () => widget.controller.bumpHypothesis(id, 'sup'),
                child: const Text('＋支持一次'),
              ),
              TextButton(
                onPressed: id == null
                    ? null
                    : () => widget.controller.bumpHypothesis(id, 'ref'),
                child: const Text('＋反驳一次'),
              ),
              TextButton(
                onPressed:
                    id == null ? null : () => widget.controller.deleteHypothesis(id),
                child: const Text('删'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
