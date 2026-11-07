import 'dart:async';

import 'package:flutter/material.dart';

import '../core.dart';
import '../models.dart';
import '../templates.dart';

enum PrpRepeatChoice { proceed, rewrite }

String _lessonLine(PrpLesson l) =>
    l.hasIfThen ? '如果${l.ifCue}，我就${l.thenAction}。' : l.summaryLine();

/// 复犯提示：又遇到类似的事，把用户上次盖印的话原样摆出来。
Future<PrpRepeatChoice> showPrpRepeatDialog(
  BuildContext context,
  PrpRecallHit hit,
  PrpVoice voice,
) async {
  final PrpCopy copy = PrpCopy(voice);
  final PrpRepeatChoice? res = await showDialog<PrpRepeatChoice>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(copy.recallTitle(hit.nth)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(copy.recallLast),
          const SizedBox(height: 4),
          Text(
            '「${_lessonLine(hit.lesson)}」',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(hit.suggestRewrite ? copy.recallRepeated : copy.recallAsk),
        ],
      ),
      actions: <Widget>[
        if (hit.suggestRewrite)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(PrpRepeatChoice.rewrite),
            child: Text(copy.recallRewrite),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(PrpRepeatChoice.proceed),
          child: Text(copy.recallContinue),
        ),
      ],
    ),
  );
  return res ?? PrpRepeatChoice.proceed;
}

/// 新建字据时，输入框上方的小提示：类似的事你上次盖印过什么。
/// 只提示、不记录；插件关闭或没有相关教训时什么都不显示。
class PrpCommitmentHint extends StatefulWidget {
  const PrpCommitmentHint({
    super.key,
    required this.core,
    required this.controller,
  });

  final PrpCore core;
  final TextEditingController controller;

  @override
  State<PrpCommitmentHint> createState() => _PrpCommitmentHintState();
}

class _PrpCommitmentHintState extends State<PrpCommitmentHint> {
  Timer? _debounce;
  PrpRecallHit? _hit;
  bool _dismissed = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _query);
  }

  Future<void> _query() async {
    final String t = widget.controller.text.trim();
    if (t == _lastQuery) return;
    _lastQuery = t;
    if (t.length < 4 || _dismissed) {
      if (_hit != null && mounted) setState(() => _hit = null);
      return;
    }
    final List<PrpRecallHit> hits = await widget.core.hintFor(
      PrpContext(surface: PrpSurface.enemy, text: t),
    );
    if (!mounted) return;
    setState(() => _hit = hits.isEmpty ? null : hits.first);
  }

  @override
  Widget build(BuildContext context) {
    final PrpRecallHit? hit = _hit;
    if (hit == null || _dismissed) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '类似的事，你上次盖印过：',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _lessonLine(hit.lesson),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _dismissed = true),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
    );
  }
}
