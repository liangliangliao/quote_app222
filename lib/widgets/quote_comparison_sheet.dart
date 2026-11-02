import 'package:flutter/material.dart';

import '../models/quote_insight.dart';
import '../data/quote_insight_store.dart';
import '../services/quote_comparison_service.dart';
import '../epistemic/cognitive_preferences.dart';
import '../epistemic/cognitive_mode.dart';
import '../epistemic/semantic_scope.dart';
import '../epistemic/semantic_scope_view.dart';
import '../epistemic/reading_scope.dart';
import '../epistemic/concept_meaning_diagram.dart';

Future<void> showQuoteComparison(
  BuildContext context,
  QuoteReference a,
  QuoteReference b, {
  QuoteComparisonService? service,
  String title = '两句名言比较',
  String recordLabel = '原句',
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .96,
        child: SafeArea(
          top: false,
          child: QuoteComparisonSheet(
            a: a,
            b: b,
            service: service,
            title: title,
            recordLabel: recordLabel,
          ),
        ),
      ),
    );

class QuoteComparisonSheet extends StatefulWidget {
  final QuoteReference a, b;
  final QuoteComparisonService? service;
  final String title, recordLabel;
  const QuoteComparisonSheet({
    super.key,
    required this.a,
    required this.b,
    this.service,
    this.title = '两句名言比较',
    this.recordLabel = '原句',
  });
  @override
  State<QuoteComparisonSheet> createState() => _QuoteComparisonSheetState();
}

class _QuoteComparisonSheetState extends State<QuoteComparisonSheet> {
  late final _service = widget.service ?? QuoteComparisonService();
  QuoteComparison? _result;
  bool _busy = true;
  String? _message;
  ComparisonPurpose _purpose = ComparisonPurpose.distinction;
  final _conditions = TextEditingController();
  String _appliedConditions = '';
  int _tab = 0;
  bool _deferred = false;
  int _generation = 0;
  String _completedContext = '';
  String get _contextKey => [
        widget.a.contentKey,
        widget.b.contentKey,
        _purpose.name,
        _conditions.text.trim()
      ].join('|');

  Future<void> _start() async {
    CognitivePreferenceStore.instance.load();
    if (!mounted) return;
    if (CognitivePreferenceStore.active) {
      if (similarRecordWording(widget.a, widget.b)) {
        setState(() {
          _deferred = true;
          _busy = false;
        });
        return;
      }
    }
    await _compare();
  }

  Future<void> _indexConcepts(SemanticScope value) async {
    try {
      final store = QuoteInsightStore();
      for (final entry in [('A', widget.a), ('B', widget.b)]) {
        await store.saveSemanticConcepts(
            entry.$2,
            value.concepts
                .where((n) =>
                    n.kind == 'concept' &&
                    n.references.any((r) => r.source == entry.$1))
                .map((n) => n.label));
      }
    } catch (_) {}
  }

  Widget _semanticPanel() {
    final sources = [
      ScopeSource('A', widget.a.content),
      ScopeSource('B', widget.b.content)
    ];
    SemanticScope? initial;
    if (_result?.semanticMap.isNotEmpty == true) {
      try {
        initial = SemanticScope.parse(_result!.semanticMap, sources,
            model: _result!.modelDisplayName);
      } catch (_) {}
    }
    return SemanticScopePanel(
        key: ValueKey([
          widget.a.contentKey,
          widget.b.contentKey,
          _purpose.name,
          _appliedConditions
        ].join('|')),
        sources: sources,
        focus: widget.recordLabel == '概念' ? '主题概念比较' : '分别分析 A、B 句内概念及跨句关系',
        initial: initial,
        onResult: _indexConcepts,
        analysisContext: SemanticContext(
            purpose: _purpose.question, conditions: _appliedConditions));
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _conditions.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuoteComparisonSheet old) {
    super.didUpdateWidget(old);
    if (old.a.contentKey != widget.a.contentKey ||
        old.b.contentKey != widget.b.contentKey) {
      _generation++;
      _result = null;
      _message = null;
      _completedContext = '';
      _start();
    }
  }

  Future<void> _compare() async {
    final n = ++_generation, contextKey = _contextKey;
    final purpose = _purpose, conditions = _conditions.text.trim();
    setState(() {
      _busy = true;
      _deferred = false;
      _message = null;
      if (_completedContext != contextKey) _result = null;
      _appliedConditions = conditions;
    });
    try {
      final result = await _service.compareForPurpose(
          widget.a, widget.b, purpose, conditions);
      if (mounted && n == _generation)
        setState(() {
          _result = result;
          _completedContext = contextKey;
        });
    } on FormatException catch (error) {
      if (mounted && n == _generation) setState(() => _message = error.message);
    } catch (_) {
      if (mounted && n == _generation)
        setState(() => _message = '暂时无法比较。请检查网络和全局 AI 设置后重试；原句与已有分析仍可阅读。');
    } finally {
      if (mounted && n == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    _generation++;
    setState(() => _busy = true);
    try {
      await _service.clearPurposeCache(
        widget.a,
        widget.b,
        _purpose,
        _appliedConditions,
      );
      if (mounted)
        setState(() {
          _result = null;
          _message = '已清除此比较的缓存。';
        });
    } catch (_) {
      if (mounted) setState(() => _message = '缓存暂未清除，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _quoteCard(String label, QuoteReference quote) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$label · ${widget.recordLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(quote.content, style: const TextStyle(height: 1.6)),
              if (quote.author.isNotEmpty)
                Text('—— ${quote.author}', textAlign: TextAlign.right),
              if (widget.recordLabel != '概念')
                Text(
                  quote.source.trim().isEmpty || quote.source.trim() == '出处待考'
                      ? '出处待考'
                      : '${EpistemicSource(locator: quote.source).label}：${quote.source}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
            ],
          ),
        ),
      );

  Widget _section(String title, String text) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(height: 1.65)),
          ],
        ),
      );

  @override
  Widget build(
    BuildContext context,
  ) =>
      ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, prefs, _) => SingleChildScrollView(
          key: const ValueKey('quote-comparison-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭比较',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (!CognitivePreferenceStore.active) ...[
                  _quoteCard('A', widget.a),
                  _quoteCard('B', widget.b),
                ] else ...[
                  if (similarRecordWording(widget.a, widget.b))
                    const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.library_books_outlined),
                        title: Text('疑似同段引文'),
                        subtitle: Text('两条收录有较长的相同措辞，可展开核对节选和译文差异。')),
                  Text('A　${widget.a.content}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('B　${widget.b.content}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (prefs.relations) _semanticPanel(),
                  if (_deferred)
                    OutlinedButton(
                        onPressed: _compare, child: const Text('继续比较两种表述')),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      expansionAnimationStyle: cognitiveExpansionStyle(context),
                      title: const Text('核对 A、B 原文与出处'),
                      subtitle: Text(
                          'A　${widget.a.content}\nB　${widget.b.content}'
                              .replaceAll(RegExp(r'\s+'), ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      children: [
                        _quoteCard('A', widget.a),
                        _quoteCard('B', widget.b)
                      ]),
                  const Text('判断目的',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 6,
                    children: ComparisonPurpose.values
                        .map(
                          (purpose) => ChoiceChip(
                            selectedColor: const Color(0xffe9d8b9),
                            backgroundColor: const Color(0xfffffcf6),
                            side: const BorderSide(color: Color(0xffded4c5)),
                            label: Text(purpose.label),
                            selected: _purpose == purpose,
                            onSelected: _busy
                                ? null
                                : (_) {
                                    setState(() => _purpose = purpose);
                                    _compare();
                                  },
                          ),
                        )
                        .toList(),
                  ),
                  ExpansionTile(
                    expansionAnimationStyle: cognitiveExpansionStyle(context),
                    title: const Text('改变情境或条件'),
                    subtitle: const Text('目标、资源、风险变化时，重新检验判断'),
                    children: [
                      TextField(
                        controller: _conditions,
                        enabled: !_busy,
                        maxLength: 1500,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '只填写愿意用于本次比较的情境',
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _compare,
                        child: const Text('按此情境重新比较'),
                      ),
                    ],
                  ),
                ],
                if (_busy) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  const Text('正在比较所选两条名言…', textAlign: TextAlign.center),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_message!),
                  ),
                if (!_busy && !_deferred && _result == null)
                  OutlinedButton.icon(
                    onPressed: _compare,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新比较'),
                  ),
                if (_result case final result?) ...[
                  if (!CognitivePreferenceStore.active)
                    QuoteRelationView(result: result),
                  const SizedBox(height: 14),
                  const Text(
                    'AI 解读 · 一种理解，尚待检验',
                    style: TextStyle(color: Colors.black54),
                  ),
                  if (!CognitivePreferenceStore.active) ...[
                    _section('共同点', result.common),
                    _section('决定性差异', result.difference),
                    _section('不能直接等同的部分', result.notEquivalent),
                    _section('适用条件与未知', result.limitation),
                  ] else ...[
                    Wrap(
                      spacing: 6,
                      children: ['共同点', '差异点', '决定性差异', '适用条件与未知']
                          .asMap()
                          .entries
                          .map(
                            (e) => ChoiceChip(
                              selectedColor: const Color(0xffe9d8b9),
                              backgroundColor: const Color(0xfffffcf6),
                              side: const BorderSide(color: Color(0xffded4c5)),
                              label: Text(e.value),
                              selected: _tab == e.key,
                              onSelected: (_) => setState(() => _tab = e.key),
                            ),
                          )
                          .toList(),
                    ),
                    _section(
                      ['共同点', '不能直接等同的部分', '决定性差异', '适用条件与未知'][_tab],
                      [
                        result.common,
                        result.notEquivalent,
                        result.difference,
                        result.limitation,
                      ][_tab],
                    ),
                    if (_tab != 3)
                      ExpansionTile(
                        expansionAnimationStyle:
                            cognitiveExpansionStyle(context),
                        title: const Text('适用条件与未知'),
                        children: [
                          Text(
                            result.limitation,
                            style: const TextStyle(height: 1.65),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 20),
                  if ((!CognitivePreferenceStore.active || prefs.grounds) &&
                      result.justification.isNotEmpty)
                    _section('判断依据（对原句的解释）', result.justification),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _busy ? null : _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清除此比较缓存'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Select the representation from a validated relation, rather than turning
/// every semantic similarity into an overlapping-set claim.
class QuoteRelationView extends StatelessWidget {
  final QuoteComparison result;
  const QuoteRelationView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final relation = result.relation;
    String text;
    if (result.canDrawSets) {
      return Semantics(
        label:
            '概念外延关系示意：${result.relationLabel}。A：${result.setA}。B：${result.setB}。不证明因果。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '对象范围示意 · ${result.relationLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ConceptMeaningDiagram(
              relation: relation,
              setA: result.setA,
              setB: result.setB,
              intersection: result.common,
              universe: result.universe,
            ),
            Text(
              'A：${result.setA}\nB：${result.setB}',
              style: const TextStyle(height: 1.6),
            ),
            const Text(
              '圆圈仅表示对象范围，不证明因果或名言普遍正确。',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }
    final forward = result.relationDirection == 'A_to_B';
    final directed = forward || result.relationDirection == 'B_to_A';
    if ((relation == QuoteRelation.cause ||
            relation == QuoteRelation.condition) &&
        directed) {
      text =
          '${forward ? 'A → B' : 'B → A'}\n${relation == QuoteRelation.cause ? '待验证的因果假设' : '条件成立时的关系'}；须结合上面的条件与反例，先后并不证明因果。';
    } else if (relation == QuoteRelation.evidence && directed) {
      text =
          '${forward ? 'B（判断）← A（所引依据）' : 'A（判断）← B（所引依据）'}\n这是对论证的理解；作者声望不能代替证据。';
    } else {
      text =
          '${relation == QuoteRelation.contrast ? '并列对照' : '并列对照 · ${result.relationLabel}'}\n${result.common}\n\n关键差异　${result.difference}';
    }
    return Card(
      key: const ValueKey('quote-relation-cards'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(height: 1.6)),
      ),
    );
  }
}
