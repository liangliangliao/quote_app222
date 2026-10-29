import 'package:flutter/material.dart';

import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import '../services/quote_insight_settings.dart';

class QuoteReadingInsights extends StatefulWidget {
  final QuoteReference quote;
  final Future<QuoteAnalysisAddon> Function(QuoteReference)? loadAddon;
  const QuoteReadingInsights({super.key, required this.quote, this.loadAddon});

  @override
  State<QuoteReadingInsights> createState() => _QuoteReadingInsightsState();
}

class _QuoteReadingInsightsState extends State<QuoteReadingInsights> {
  QuoteAnalysisAddon _addon = const QuoteAnalysisAddon();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(QuoteReadingInsights oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quote.contentKey != widget.quote.contentKey) {
      _addon = const QuoteAnalysisAddon();
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final addon = await (widget.loadAddon ??
          QuoteInsightStore().readAddon)(widget.quote);
      if (mounted && generation == _generation) setState(() => _addon = addon);
    } catch (_) {
      // Legacy/offline reading always remains available without annotations.
    }
  }

  Widget _fold(String title, List<Widget> children) => ExpansionTile(
        key: ValueKey('quote-insight-$title'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 240)),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        children: children,
      );

  Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: const TextStyle(height: 1.65)),
      );

  @override
  Widget build(BuildContext context) {
    final source = _addon.source.locator.isEmpty
        ? EpistemicSource(
            status: _addon.source.status, locator: widget.quote.source)
        : _addon.source;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Text(source.label,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      if (QuoteInsightSettings.readingEnabled) ...[
        if (_addon.concreteExample.isNotEmpty)
          _fold('具体是什么样子', [
            _paragraph('示例 / 模拟情境，不作为史实或作者原意'),
            _paragraph(_addon.concreteExample),
          ]),
        if (_addon.commonality.isNotEmpty ||
            _addon.criticalDifference.isNotEmpty)
          _fold('相似与不同', [
            if (_addon.commonality.isNotEmpty)
              _paragraph('共同点：${_addon.commonality}'),
            if (_addon.criticalDifference.isNotEmpty)
              _paragraph('决定性差异：${_addon.criticalDifference}'),
          ]),
        if (_addon.boundary.isNotEmpty)
          _fold('哪些条件下不成立', [_paragraph(_addon.boundary)]),
      ],
      _fold('这个解释依据什么', [
        _paragraph('原句按记录保留；解读是一种理解，示例不等于证据。'),
        _paragraph('出处记录：${source.locator.isEmpty ? '出处待考' : source.locator}'),
        if (source.status == SourceStatus.verified)
          _paragraph('审核者：${source.verifiedBy}\n审核时间：${source.verifiedAt}')
        else
          _paragraph('尚无已核对的原典定位。模型自评为“高可信”或被反复引用，都不等于出处已核实。'),
        if (_addon.analysisBasis.isNotEmpty)
          _paragraph('分析依据（AI 解读）：${_addon.analysisBasis}'),
        if (_addon.sourceRefs.isNotEmpty)
          _paragraph('待核对的资料线索：\n${_addon.sourceRefs.join('\n')}'),
        if (_addon.modelSourceAssessment.isNotEmpty)
          _paragraph('模型自评（未经外部核对）：${_addon.modelSourceAssessment}'),
        _paragraph('仍需核对原文、译法与适用语境；现有解释可能需要随新证据修订。'),
      ]),
    ]);
  }
}
