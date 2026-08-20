import 'dart:async';

import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/controller.dart';

/// 十五分钟。
///
/// 界面只有一个圆和剩余时间。无音效、无鼓励、无暂停统计。
/// 中途退出 = aborted=1，不做任何提示，不记为失败。
/// 结束后只问一句「还想接着做吗」，答完直接返回清单，不显示任何总结。
class KindlingBurnPage extends StatefulWidget {
  const KindlingBurnPage({
    super.key,
    required this.controller,
    required this.itemId,
    required this.title,
  });

  static const Duration span = Duration(minutes: 15);

  static const Key startKey = ValueKey<String>('kindling_burn_start');
  static const Key clockKey = ValueKey<String>('kindling_burn_clock');
  static const Key wantYesKey = ValueKey<String>('kindling_burn_want_yes');
  static const Key wantNoKey = ValueKey<String>('kindling_burn_want_no');

  final KindlingController controller;
  final int itemId;
  final String title;

  @override
  State<KindlingBurnPage> createState() => _KindlingBurnPageState();
}

class _KindlingBurnPageState extends State<KindlingBurnPage> {
  Timer? _ticker;
  DateTime? _startedAt;
  int _remaining = KindlingBurnPage.span.inSeconds;
  bool _running = false;
  bool _finished = false;
  bool _recorded = false;
  int? _burnId;

  @override
  void dispose() {
    _ticker?.cancel();
    // 中途退出：静默记为 aborted，不提示、不评价。
    if (_running && !_recorded) {
      _recorded = true;
      final DateTime started = _startedAt ?? DateTime.now();
      unawaited(
        widget.controller
            .recordBurn(
              itemId: widget.itemId,
              startedAt: started,
              seconds: KindlingBurnPage.span.inSeconds - _remaining,
              aborted: true,
            )
            .catchError((Object _) => 0),
      );
    }
    super.dispose();
  }

  void _start() {
    if (_running || _finished) return;
    setState(() {
      _running = true;
      _startedAt = DateTime.now();
      _remaining = KindlingBurnPage.span.inSeconds;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
        unawaited(_complete());
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  Future<void> _complete() async {
    if (_recorded) return;
    _recorded = true;
    final int id = await widget.controller.recordBurn(
      itemId: widget.itemId,
      startedAt: _startedAt ?? DateTime.now(),
      seconds: KindlingBurnPage.span.inSeconds,
      aborted: false,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _finished = true;
      _burnId = id;
    });
  }

  Future<void> _answer(bool wantMore) async {
    final int? id = _burnId;
    if (id != null) {
      await widget.controller.answerWantMore(id, wantMore);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String get _clock {
    final int m = _remaining ~/ 60;
    final int s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2B2B2B),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _finished ? _buildAsk() : _buildClock(),
        ),
      ),
    );
  }

  Widget _buildClock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          key: KindlingBurnPage.clockKey,
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E2E2), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            _clock,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w300,
              color: Color(0xFF2B2B2B),
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (!_running)
          TextButton(
            key: KindlingBurnPage.startKey,
            onPressed: _start,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2B2B2B),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            ),
            child: const Text(KCopy.start, style: TextStyle(fontSize: 16)),
          ),
      ],
    );
  }

  Widget _buildAsk() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            KCopy.burnAsk,
            style: TextStyle(fontSize: 19, color: Color(0xFF2B2B2B)),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlinedButton(
                key: KindlingBurnPage.wantYesKey,
                onPressed: () => _answer(true),
                style: _askStyle,
                child: const Text(KCopy.burnYes, style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 14),
              OutlinedButton(
                key: KindlingBurnPage.wantNoKey,
                onPressed: () => _answer(false),
                style: _askStyle,
                child: const Text(KCopy.burnNo, style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle get _askStyle => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2B2B2B),
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}
