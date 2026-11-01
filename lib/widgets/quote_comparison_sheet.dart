import 'package:flutter/material.dart';

import '../models/quote_insight.dart';
import '../services/quote_comparison_service.dart';
import '../epistemic/cognitive_preferences.dart';
import '../epistemic/cognitive_mode.dart';
import '../epistemic/cognitive_models.dart';
import '../epistemic/cognitive_sheet.dart';
import '../epistemic/cognitive_store.dart';
import '../epistemic/passage_scope_view.dart';
import '../epistemic/reading_scope.dart';
import '../data/quote_insight_store.dart';
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
  bool _left = true, _deferred = false;
  final _readings = <String, CognitiveAnalysis>{};

  Future<void> _start() async {
    CognitivePreferenceStore.instance.load();
    if (CognitivePreferenceStore.active) {
      _loadReadings();
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

  String _subject(QuoteReference ref) {
    final id = ref.id.isEmpty ? ref.contentKey : ref.id;
    return widget.recordLabel == '概念' && id.startsWith('concept:')
        ? id.substring(8)
        : id;
  }

  String get _module => widget.recordLabel == '概念' ? 'concept' : 'quote';

  Future<void> _loadReadings() async {
    for (final ref in [widget.a, widget.b]) {
      final id = _subject(ref);
      try {
        final addon = await QuoteInsightStore().readAddon(ref);
        final base = CognitiveAnalysis.fromJson(addon.cognition, ref.content);
        final notes = await CognitiveStore().forRecord(_module, id);
        final note = notes
            .where((n) =>
                n.task == CognitiveTask.concept &&
                n.selection.matches(ref.content) &&
                (n.analysis.scopes.isNotEmpty ||
                    n.analysis.abstractions.isNotEmpty))
            .firstOrNull;
        if (!mounted) return;
        setState(() => _readings[ref.contentKey] = note?.analysis ?? base);
      } catch (_) {/* Old records may have no locally stored analysis. */}
    }
  }

  Future<void> _analyzeScope(QuoteReference ref) async {
    await showCognitiveAnalysis(context,
        task: CognitiveTask.concept,
        selection: CognitiveSelection.fromText(
            module: _module,
            recordId: _subject(ref),
            title: ref.author,
            fullText: ref.content));
    if (mounted) await _loadReadings();
  }

  Widget _passagePanel() {
    final ref = _left ? widget.a : widget.b;
    final reading = _left ? _result?.readingA : _result?.readingB;
    final fresh = CognitiveAnalysis.fromJson(reading, ref.content);
    final saved = _readings[ref.contentKey];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, bounds) {
        final sideBySide = bounds.maxWidth >= 270 &&
            MediaQuery.textScalerOf(context).scale(14) <= 22;
        return Wrap(spacing: 8, runSpacing: 6, children: [
          for (final isA in [true, false])
            SizedBox(
                width: sideBySide ? (bounds.maxWidth - 8) / 2 : bounds.maxWidth,
                child: Semantics(
                    selected: _left == isA,
                    button: true,
                    child: Material(
                        color: _left == isA
                            ? const Color(0xffefe2c8)
                            : const Color(0xfffffcf6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: _left == isA
                                    ? const Color(0xffa78345)
                                    : const Color(0xffddd2bf))),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            onTap: () => setState(() => _left = isA),
                            child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(isA ? 'A 句中概念' : 'B 句中概念',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                      Text((isA ? widget.a : widget.b).content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ])))))),
        ]);
      }),
      if (reading != null &&
          insightText(reading, 'missing_evidence').isNotEmpty)
        Text(
            '待查条件　${insightText(reading, 'missing_evidence')}\n${insightText(reading, 'clarifying_question')}'),
      PassageScopeView(
          key: ValueKey(ref.contentKey),
          text: ref.content,
          scopes: fresh.scopes.isNotEmpty ? fresh.scopes : saved?.scopes ?? [],
          abstractions: fresh.abstractions.isNotEmpty
              ? fresh.abstractions
              : saved?.abstractions ?? [],
          onAnalyze: () => _analyzeScope(ref)),
    ]);
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

  Future<void> _compare() async {
    setState(() {
      _busy = true;
      _deferred = false;
      _message = null;
      _result = null;
      _appliedConditions = _conditions.text.trim();
    });
    try {
      final result = await _service.compareForPurpose(
        widget.a,
        widget.b,
        _purpose,
        _appliedConditions,
      );
      if (mounted) setState(() => _result = result);
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _message = '暂时无法比较。请检查网络和全局 AI 设置后重试；原句仍可阅读。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
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
                  if (prefs.relations)
                    if (_result?.canDrawSets == true)
                      QuoteRelationView(result: _result!)
                    else
                      _passagePanel(),
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
                  if (!CognitivePreferenceStore.active ||
                      (prefs.relations && !result.canDrawSets))
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
