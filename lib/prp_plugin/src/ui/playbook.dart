import 'package:flutter/material.dart';

import '../core.dart';
import '../models.dart';
import 'seal_stamp.dart';
import 'session_card.dart';

/// 个人战术手册：已盖印的教训（有效 / 无效双栏、成色、验证 / 没挡住次数）和待盖印的草稿。
/// 插件关闭时（[viewAlways] 为 false）什么都不显示；设置页里 [viewAlways] 为 true，关闭后也能看。
class PrpPlaybook extends StatefulWidget {
  const PrpPlaybook({super.key, required this.core, this.viewAlways = false});

  final PrpCore core;
  final bool viewAlways;

  @override
  State<PrpPlaybook> createState() => _PrpPlaybookState();
}

class _PrpPlaybookState extends State<PrpPlaybook> {
  PrpPlaybookData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PrpPlaybookData d = await widget.core.playbookData(
      viewAlways: widget.viewAlways,
    );
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sealDraft(PrpLesson l) async {
    final int? id = l.id;
    if (id == null) return;
    final res = await widget.core.sealExisting(id);
    if (!mounted) return;
    if (res != null && res.ok) {
      _snack('已盖印');
    } else {
      _snack(res == null ? '这次没能保存，稍后再试。' : '还不能盖印：缺有效、具体的没起作用，或“如果—那么”。');
    }
    await _load();
  }

  Future<void> _rewrite(PrpLesson l) async {
    final PrpSurface surface = PrpSurfaceX.parse(l.source) ?? PrpSurface.enemy;
    final PrpOffer? offer = await widget.core.signal(
      PrpSignal(
        surface: surface,
        kind: 'manual',
        subjectKey: l.subjectKey,
        expected: l.subjectText,
        category: l.category.isEmpty ? null : l.category,
        userInitiated: true,
        rewriteOf: l.id,
        tsMs: widget.core.host.nowMs(),
      ),
    );
    if (!mounted) return;
    if (offer == null) {
      _snack('插件已关闭，先在设置里打开它再改写。');
      return;
    }
    await openPrpSessionPage(context, widget.core, offer);
    if (mounted) await _load();
  }

  Widget _col(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (items.isEmpty) const Text('—'),
        ...items.map((String e) => Text('· $e')),
      ],
    );
  }

  Widget _card(PrpLesson l, {required bool draft}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (l.category.isNotEmpty) Chip(label: Text(l.category)),
                const SizedBox(width: 8),
                Text(
                  draft ? '草稿（待盖印）' : '成色 ${l.quality}/5',
                  style: const TextStyle(color: Colors.grey),
                ),
                const Spacer(),
                if (!draft) const PrpSealStamp(size: 34),
              ],
            ),
            if (l.hasIfThen)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  '如果${l.ifCue}，我就${l.thenAction}。',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints c) {
                final Widget worked = _col('有效', l.worked);
                final Widget failed = _col('没起作用', l.failed);
                if (c.maxWidth > 420) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: worked),
                      const SizedBox(width: 8),
                      Expanded(child: failed),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[worked, const SizedBox(height: 6), failed],
                );
              },
            ),
            if (l.earlySignal.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('最早的信号：${l.earlySignal}'),
              ),
            if (!draft)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '验证 ${l.verifiedCnt} · 没挡住 ${l.repeatedCnt}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            if (!draft && l.repeatedCnt >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '没挡住 ${l.repeatedCnt} 次，要改一版吗？',
                  style: const TextStyle(color: kPrpSeal),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: draft
                  ? TextButton(
                      onPressed: () => _sealDraft(l),
                      child: const Text('盖印'),
                    )
                  : TextButton(
                      onPressed: () => _rewrite(l),
                      child: const Text('改一版'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.viewAlways
          ? const Center(child: CircularProgressIndicator())
          : const SizedBox.shrink();
    }
    final PrpPlaybookData d = _data ?? PrpPlaybookData.empty;
    if (d.sealed.isEmpty && d.drafts.isEmpty) {
      return widget.viewAlways
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('还没有盖印的教训。')),
            )
          : const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(
            children: <Widget>[
              Text('我的教训手册', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (d.drafts.isNotEmpty)
                Text(
                  '待盖印 ${d.drafts.length} 条',
                  style: const TextStyle(color: kPrpSeal),
                ),
            ],
          ),
        ),
        ...d.drafts.map((PrpLesson l) => _card(l, draft: true)),
        ...d.sealed.map((PrpLesson l) => _card(l, draft: false)),
      ],
    );
  }
}
