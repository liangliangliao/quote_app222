import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../domain/controller.dart';
import 'widgets.dart';

/// 行为记录：做了什么，事后反应，是否思虑过，身体信号，表达了哪条主线。
class LogPage extends StatefulWidget {
  const LogPage({super.key, required this.controller});

  final ZhaojianController controller;

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final TextEditingController _what = TextEditingController();
  int? _reaction;
  int? _deliberate;
  int? _typical;
  final List<String> _body = <String>[];
  int? _hypId;
  String _hypKind = 'sup';

  static const List<String> _deliberateLabels = <String>['思虑过', '一时冲动'];
  static const List<String> _typicalLabels = <String>['大多数人也会', '大多数人不会'];

  @override
  void dispose() {
    _what.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_what.text.trim().isEmpty || _reaction == null) {
      zSnack(context, '请写下做了什么，并选一个事后反应');
      return;
    }
    final ZLog l = ZLog(
      what: _what.text.trim(),
      reaction: ZCopy.reactions[_reaction!],
      deliberate: _deliberate == null ? '' : _deliberateLabels[_deliberate!],
      typical: _typical == null ? '' : _typicalLabels[_typical!],
      body: List<String>.from(_body),
      hypId: _hypId,
      hypKind: _hypId == null ? null : _hypKind,
      createdAt: DateTime.now(),
    );
    await widget.controller.addLog(l);
    if (!mounted) return;
    setState(() {
      _what.clear();
      _reaction = null;
      _deliberate = null;
      _typical = null;
      _body.clear();
      _hypId = null;
      _hypKind = 'sup';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<ZHypothesis> hyps = widget.controller.hypotheses;
        final List<ZLog> logs =
            widget.controller.logs.reversed.take(30).toList();
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('行为记录'),
            backgroundColor: Colors.white,
            foregroundColor: zInk,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: <Widget>[
              const ZNote('看行为和事后反应，不只听自己怎么说。'),
              ZSection(
                title: '随手记一次行为',
                children: <Widget>[
                  TextField(controller: _what, decoration: zInput('我实际做了什么？')),
                  const SizedBox(height: 8),
                  const ZNote('事后第一反应：'),
                  zChoice(
                    labels: ZCopy.reactions,
                    selected: _reaction,
                    onSelect: (int i) => setState(() => _reaction = i),
                  ),
                  const ZNote('这次行为是…（可选）'),
                  zChoice(
                    labels: _deliberateLabels,
                    selected: _deliberate,
                    onSelect: (int i) => setState(() => _deliberate = i),
                  ),
                  zChoice(
                    labels: _typicalLabels,
                    selected: _typical,
                    onSelect: (int i) => setState(() => _typical = i),
                  ),
                  const ZNote('身体信号（可多选，只是线索，不是诊断）'),
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
                  if (hyps.isNotEmpty) ...<Widget>[
                    const ZNote('这个行为表达了哪条主线？（可选，会自动计入该假设的支持或反驳）'),
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
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _save, child: const Text('记下')),
                ],
              ),
              ZSection(
                title: '最近的记录',
                children: logs.isEmpty
                    ? const <Widget>[ZNote('还没有记录。')]
                    : logs.map(_logTile).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logTile(ZLog l) {
    final List<String> tags = <String>[
      l.reaction,
      if (l.deliberate.isNotEmpty) l.deliberate,
      if (l.typical.isNotEmpty) l.typical,
      ...l.body,
    ];
    return ZItem(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l.what),
                ZNote(tags.join(' · ')),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              final int? id = l.id;
              if (id != null) widget.controller.deleteLog(id);
            },
          ),
        ],
      ),
    );
  }
}
