import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import '../services/quote_comparison_service.dart';
import '../epistemic/cognitive_mode.dart';
import '../epistemic/cognitive_preferences.dart';
import '../epistemic/semantic_scope.dart';
import '../epistemic/concept_meaning_diagram.dart';
import '../epistemic/concept_analysis.dart';
import 'quote_portrait.dart';

/// The comparison's existing controller owns requests and context invalidation.
/// This view only arranges the validated result and its reading controls.
class QuoteComparisonPrototype extends StatelessWidget {
  final QuoteReference a, b;
  final QuoteComparison? result;
  final CognitivePreferences preferences;
  final String title;
  final String? message;
  final bool busy, deferred;
  final int tab;
  final ComparisonPurpose purpose;
  final ValueChanged<int> onTab;
  final ValueChanged<ComparisonPurpose> onPurpose;
  final VoidCallback onCompare, onClear;
  final TextEditingController conditions;
  final Widget semanticPanel;
  final SemanticScope? semanticOverride;
  final Widget Function(String, QuoteReference) quoteCard;
  const QuoteComparisonPrototype(
      {super.key,
      required this.a,
      required this.b,
      required this.result,
      required this.preferences,
      required this.title,
      required this.message,
      required this.busy,
      required this.deferred,
      required this.tab,
      required this.purpose,
      required this.onTab,
      required this.onPurpose,
      required this.onCompare,
      required this.onClear,
      required this.conditions,
      required this.semanticPanel,
      required this.quoteCard,
      this.semanticOverride});

  SemanticScope? get semantic {
    if (semanticOverride != null) return semanticOverride;
    try {
      if (result?.semanticMap.isNotEmpty != true) return null;
      return SemanticScope.parse(result!.semanticMap,
          [ScopeSource('A', a.content), ScopeSource('B', b.content)],
          model: result!.modelDisplayName);
    } catch (_) {
      return null;
    }
  }

  String _short(String text, [int count = 20]) => text.runes.length <= count
      ? text
      : '${String.fromCharCodes(text.runes.take(count))}…';
  void _original(BuildContext context,
          {String? label, QuoteReference? quote}) =>
      showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('原文与出处'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: quote == null
                              ? [quoteCard('A', a), quoteCard('B', b)]
                              : [quoteCard(label!, quote)])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'))
                  ]));
  Widget _portraitCard(
          BuildContext context, String label, QuoteReference quote) =>
      Expanded(
          child: Material(
              color: const Color(0xfffffcf5),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _original(context, label: label, quote: quote),
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xffeae2d2))),
                      child: Column(children: [
                        QuotePortrait(quote: quote, diameter: 56),
                        const SizedBox(height: 12),
                        Text(quote.content,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.55)),
                        const SizedBox(height: 8),
                        Text(
                            quote.author.isEmpty ? '作者待考' : '— ${quote.author}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xff827666))),
                      ])))));
  String _focus(String label, QuoteReference quote, SemanticScope? value) {
    final concepts = value?.concepts
            .where((c) => c.references.any((r) => r.source == label))
            .toList() ??
        [];
    return concepts.isEmpty
        ? _short(quote.content, 36)
        : concepts.map((c) => c.label).take(3).join(' · ');
  }

  Widget _judgment(QuoteComparison r, SemanticScope? value) {
    final j = value?.judgments.where((j) => j.placement == 'cross').firstOrNull;
    return Container(
        key: const ValueKey('comparison-judgment-map'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xfffbefd5), Color(0xfff1f4ef)])),
        child: Column(children: [
          const Text('判断力 · 围绕当前目的辨清同异',
              style: TextStyle(fontSize: 12, color: Color(0xff78674b))),
          const SizedBox(height: 12),
          Text(j?.common.isNotEmpty == true ? j!.common : r.common,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, height: 1.5, fontWeight: FontWeight.w600)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.call_split, color: Color(0xffa5977b))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in [
              ('A', a, const Color(0xfff1dcb8)),
              ('B', b, const Color(0xffd6e7ef))
            ])
              Expanded(
                  child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: entry.$3,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Text(entry.$1,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                        Text(_focus(entry.$1, entry.$2, value),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.5)),
                      ]))),
          ]),
          const SizedBox(height: 12),
          Text(
              _short(
                  j?.decisive.isNotEmpty == true ? j!.decisive : r.difference,
                  100),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, height: 1.6)),
        ]));
  }

  Widget _diagram(QuoteComparison r, SemanticScope? value) {
    final scope = value?.relations
        .where((r) => r.placement == 'cross' && r.scope != null)
        .firstOrNull
        ?.scope;
    if (scope == null && !r.canDrawSets) return _judgment(r, value);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ConceptMeaningDiagram(
          key: ValueKey('comparison-diagram-$tab'),
          compact: true,
          relation: scope?.relation ?? r.relation,
          setA: scope?.setA ?? r.setA,
          setB: scope?.setB ?? r.setB,
          universe: scope?.universe ?? r.universe,
          intersection: scope?.intersection ?? r.common,
          onlyA: scope?.onlyA ?? r.basisA,
          onlyB: scope?.onlyB ?? r.basisB,
          otherMember: scope?.otherMember ?? '',
          parts: scope?.parts ?? const [],
          centerLabel: _short(scope?.intersection ?? r.common, 18),
          highlightedRegion: tab == 0 &&
                  [
                    QuoteRelation.overlap,
                    QuoteRelation.equal,
                    QuoteRelation.subset,
                    QuoteRelation.superset
                  ].contains(scope?.relation ?? r.relation)
              ? '共同'
              : tab == 1 &&
                      (scope?.relation ?? r.relation) != QuoteRelation.partition
                  ? '差异'
                  : null),
      Text('论域：${scope?.universe ?? r.universe}',
          style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const Text('圈表示对象范围；点按区域查看含义与例子。',
          style: TextStyle(fontSize: 10, color: Colors.black54)),
    ]);
  }

  Widget _section(String title, String text) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        Text(text, style: const TextStyle(fontSize: 14, height: 1.65))
      ]));
  Widget _own(QuoteComparison r, SemanticScope? value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final entry in [('A', a, r.readingA), ('B', b, r.readingB)]) ...[
          _section(
              '${entry.$1} · ${entry.$2.author.isEmpty ? '各自的分析' : entry.$2.author}',
              value?.judgments
                      .where((j) => j.placement == entry.$1)
                      .map((j) => [j.question, j.difference, j.basis]
                          .where((s) => s.isNotEmpty)
                          .join('\n'))
                      .join('\n\n') ??
                  ''),
          for (final c in value?.concepts.where(
                  (c) => c.references.any((ref) => ref.source == entry.$1)) ??
              <SemanticConcept>[]) ...[
            Text('${c.label}：${c.definition}',
                style: const TextStyle(height: 1.6)),
            if (c.observed.isNotEmpty)
              Text('直观：${c.observed}', style: const TextStyle(height: 1.6)),
            if (c.retained.isNotEmpty)
              Text('保留：${c.retained}', style: const TextStyle(height: 1.6)),
            if (c.omitted.isNotEmpty)
              Text('省略：${c.omitted}', style: const TextStyle(height: 1.6)),
          ],
          for (final term in ConceptAbstraction.parse(entry.$3['abstractions']))
            _section(
                term.term,
                [
                  term.definition,
                  '直观：${term.observed}',
                  '保留：${term.retained}',
                  '省略：${term.omitted}',
                  '例子：${term.memberExample}',
                  '反例：${term.nonMember}'
                ].join('\n')),
          if ('${entry.$3['missing_evidence'] ?? ''}'.isNotEmpty)
            Text(
                '${entry.$3['missing_evidence']}\n${entry.$3['clarifying_question'] ?? ''}'),
          if (entry.$3.isEmpty &&
              !(value?.concepts.any(
                      (c) => c.references.any((r) => r.source == entry.$1)) ??
                  false) &&
              !(value?.judgments.any((j) => j.placement == entry.$1) ?? false))
            const Text('本次结果尚未返回这句的独立概念解释，可展开“概念与依据”补充分析。',
                style: TextStyle(height: 1.6)),
        ],
      ]);
  @override
  Widget build(BuildContext context) {
    final r = result, value = semantic;
    return ColoredBox(
        color: const Color(0xfffaf6ed),
        child: SingleChildScrollView(
            key: const ValueKey('quote-comparison-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    IconButton(
                        tooltip: '关闭比较',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18)),
                    Expanded(
                        child: Text(title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600))),
                    IconButton(
                        tooltip: '核对原句',
                        onPressed: () => _original(context),
                        icon: const Icon(Icons.search, size: 20))
                  ]),
                  const SizedBox(height: 8),
                  IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        _portraitCard(context, 'A', a),
                        const Padding(
                            padding:
                                EdgeInsets.only(top: 84, left: 6, right: 6),
                            child: Icon(Icons.compare_arrows,
                                size: 20, color: Color(0xff8c7b5f))),
                        _portraitCard(context, 'B', b)
                      ])),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (final e in ['共同点', '差异点', '决定性差异', '各自的分析'].indexed)
                      Expanded(
                          child: InkWell(
                              key: ValueKey('comparison-tab-${e.$1}'),
                              onTap: () => onTab(e.$1),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2, vertical: 11),
                                  decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              width: 2,
                                              color: tab == e.$1
                                                  ? const Color(0xff8c7855)
                                                  : const Color(0xffe8e0d2)))),
                                  child: Text(e.$2,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: tab == e.$1
                                              ? const Color(0xff463d2e)
                                              : const Color(0xff8b8173),
                                          fontWeight: tab == e.$1
                                              ? FontWeight.w600
                                              : FontWeight.normal)))))
                  ]),
                  const SizedBox(height: 12),
                  if (busy)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('正在比较所选两条名言…')
                        ])),
                  if (deferred) ...[
                    const Text('疑似同段引文'),
                    const Text('可核对节选和译文差异。'),
                    OutlinedButton(
                        onPressed: onCompare, child: const Text('继续比较两种表述'))
                  ],
                  if (message != null)
                    Text(message!, style: const TextStyle(height: 1.6)),
                  if (!busy && !deferred && r == null)
                    OutlinedButton.icon(
                        onPressed: onCompare,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新比较')),
                  if (r != null && preferences.relations) _diagram(r, value),
                  const Padding(
                      padding: EdgeInsets.only(top: 18, bottom: 4),
                      child: Text('判断目的',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600))),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final e in ComparisonPurpose.values.indexed)
                      ChoiceChip(
                          selectedColor: [
                            const Color(0xffd7e7ed),
                            const Color(0xfff1dcb8),
                            const Color(0xffdce9df)
                          ][e.$1],
                          backgroundColor: const Color(0xfffffcf5),
                          side: const BorderSide(color: Color(0xffe6ddcd)),
                          label: Text(e.$2.label,
                              style: const TextStyle(fontSize: 11)),
                          selected: purpose == e.$2,
                          onSelected: busy ? null : (_) => onPurpose(e.$2))
                  ]),
                  if (r != null) ...[
                    if (tab == 3)
                      _own(r, value)
                    else
                      _section(['共同点', '差异点', '决定性差异'][tab],
                          [r.common, r.notEquivalent, r.difference][tab]),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        expansionAnimationStyle:
                            cognitiveExpansionStyle(context),
                        title: const Text('适用条件与未知',
                            style: TextStyle(fontSize: 14)),
                        children: [
                          Text(r.limitation,
                              style: const TextStyle(height: 1.6))
                        ]),
                    if (preferences.grounds && r.justification.isNotEmpty)
                      _section('判断依据（对原句的解释）', r.justification),
                    if (preferences.relations)
                      ExpansionTile(
                          key: const ValueKey('comparison-semantic-details'),
                          tilePadding: EdgeInsets.zero,
                          expansionAnimationStyle:
                              cognitiveExpansionStyle(context),
                          title: const Text('概念与依据',
                              style: TextStyle(fontSize: 14)),
                          children: [semanticPanel]),
                  ],
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      expansionAnimationStyle: cognitiveExpansionStyle(context),
                      title:
                          const Text('改变情境或条件', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('目标、资源、风险变化时，重新检验判断',
                          style: TextStyle(fontSize: 11)),
                      children: [
                        TextField(
                            controller: conditions,
                            enabled: !busy,
                            maxLength: 1500,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                                hintText: '只填写愿意用于本次比较的情境')),
                        TextButton(
                            onPressed: busy ? null : onCompare,
                            child: const Text('按此情境重新比较'))
                      ]),
                  const SizedBox(height: 12),
                  const Text('AI 解读 · 一种理解，尚待检验',
                      style: TextStyle(fontSize: 11, color: Colors.black45)),
                  if (r != null)
                    TextButton.icon(
                        onPressed: busy ? null : onClear,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清除此比较缓存')),
                ])));
  }
}
