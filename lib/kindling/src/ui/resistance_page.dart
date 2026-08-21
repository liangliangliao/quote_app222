import 'package:flutter/material.dart';

import '../copy.dart';
import '../domain/controller.dart';
import '../kindling_oracle.dart';

/// 阻抗追问。只追问，不给建议，不打气。
///
/// 每步一个输入框，可跳过。最后一屏固定一句结束语。
/// 无总结、无建议列表、无「推荐行动」。
class KindlingResistancePage extends StatefulWidget {
  const KindlingResistancePage({
    super.key,
    required this.controller,
    this.itemId,
    this.title,
  });

  static const Key inputKey = ValueKey<String>('kindling_resistance_input');
  static const Key nextKey = ValueKey<String>('kindling_resistance_next');
  static const Key skipKey = ValueKey<String>('kindling_resistance_skip');
  static const Key endKey = ValueKey<String>('kindling_resistance_end');

  final KindlingController controller;
  final int? itemId;
  final String? title;

  @override
  State<KindlingResistancePage> createState() => _KindlingResistancePageState();
}

class _KindlingResistancePageState extends State<KindlingResistancePage> {
  final TextEditingController _input = TextEditingController();
  final List<({String q, String? a})> _history = <({String q, String? a})>[];

  /// 首问不等任何人：本地问题梯同步可得，进场就有内容，不留白屏。
  String? _question = LocalOracle.questionAt(0);
  bool _busy = false;
  bool _ended = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// 取下一问。
  ///
  /// 等待期间**不清空当前这一问**——留在原地比闪一段白屏好；追问器那边也有
  /// 时限兜底，等不到就用本地问题梯。
  Future<void> _advance() async {
    setState(() => _busy = true);
    final String? next =
        await widget.controller.oracle.nextResistanceQuestion(_history);
    if (!mounted) return;
    setState(() {
      _question = next;
      _ended = next == null;
      _busy = false;
      _input.clear();
    });
  }

  Future<void> _submit({required bool skipped}) async {
    final String? question = _question;
    if (question == null || _busy) return;
    final String text = _input.text.trim();
    final String? answer = skipped || text.isEmpty ? null : text;

    await widget.controller.dao.insertResistanceStep(
      itemId: widget.itemId,
      step: _history.length + 1,
      question: question,
      answer: answer,
    );
    _history.add((q: question, a: answer));
    await _advance();
  }

  @override
  Widget build(BuildContext context) {
    final String? subtitle = widget.title;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF2B2B2B),
        title: Text(
          subtitle ?? KCopy.menuResistance,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: _ended ? _buildEnd() : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Text(
            _question ?? '',
            style: const TextStyle(
              fontSize: 19,
              height: 1.6,
              color: Color(0xFF2B2B2B),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: KindlingResistancePage.inputKey,
              controller: _input,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 16, height: 1.6),
              decoration: const InputDecoration(
                hintText: KCopy.writeHint,
                hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: <Widget>[
              TextButton(
                key: KindlingResistancePage.skipKey,
                onPressed: _busy ? null : () => _submit(skipped: true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8A8A8A),
                ),
                child: const Text(KCopy.skip, style: TextStyle(fontSize: 15)),
              ),
              const Spacer(),
              OutlinedButton(
                key: KindlingResistancePage.nextKey,
                onPressed: _busy ? null : () => _submit(skipped: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B2B2B),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(KCopy.next, style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnd() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            KCopy.resistanceEnd,
            key: KindlingResistancePage.endKey,
            style: TextStyle(
              fontSize: 18,
              height: 1.7,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 26),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8A8A8A),
              padding: EdgeInsets.zero,
            ),
            child: const Text(KCopy.done, style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
