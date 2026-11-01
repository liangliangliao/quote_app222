import 'dart:io';
import 'package:flutter/material.dart';
import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import '../pages/history_page.dart';
import '../services/quote_frame_ai_service.dart';
import '../services/quote_visual_script_service.dart';
import '../services/quote_insight_settings.dart';
import '../widgets/quote_calligraphy_text.dart';
import '../widgets/quote_reading_insights.dart';
import 'cognitive_models.dart';
import 'cognitive_preferences.dart';
import 'cognitive_sheet.dart';
import 'cognitive_store.dart';
import 'cognitive_input_dialog.dart';
import 'concept_explorer.dart';
import 'cognitive_usage.dart';

class QuoteCognitiveReader extends StatefulWidget {
  final QuoteReference quote;
  final String topic, authorLabel, note;
  final String? imagePath;
  const QuoteCognitiveReader(
      {super.key,
      required this.quote,
      required this.topic,
      required this.authorLabel,
      required this.note,
      this.imagePath});
  @override
  State<QuoteCognitiveReader> createState() => _QuoteCognitiveReaderState();
}

class _QuoteCognitiveReaderState extends State<QuoteCognitiveReader> {
  QuoteAnalysisAddon _addon = const QuoteAnalysisAddon();
  CognitiveNote? _conceptNote;
  int _tab = 0;
  bool _choseTab = false;
  String get _recordId =>
      widget.quote.id.isEmpty ? widget.quote.contentKey : widget.quote.id;
  CognitiveSelection get _selection => CognitiveSelection.fromText(
      module: 'quote',
      recordId: _recordId,
      title: widget.topic,
      fullText: widget.quote.content);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await CognitivePreferenceStore.instance.load();
    try {
      final addon = await QuoteInsightStore().readAddon(widget.quote);
      final notes = await CognitiveStore().forRecord('quote', _recordId);
      if (!mounted) return;
      setState(() {
        _addon = addon;
        _conceptNote = notes
            .where((n) =>
                n.task == CognitiveTask.concept &&
                n.selection.matches(widget.quote.content))
            .firstOrNull;
        if (!_choseTab)
          _tab = CognitivePreferenceStore.instance.value.style.index;
      });
    } catch (_) {}
  }

  Future<void> _expandConcept() async {
    await showCognitiveAnalysis(context,
        selection: _selection, task: CognitiveTask.concept);
    if (mounted) await _load();
  }

  Future<void> _observe() async {
    final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const CognitiveInputDialog(
            title: '把理解带回经验',
            description: '记录一次具体情境：发生了什么？哪里符合或不符合这句话？',
            submitLabel: '分析这次观察',
            fields: [CognitiveInputField('observation', '我的观察')]));
    if (values == null || !mounted) return;
    final observation = values['observation']!;
    final text = '所选名言：${widget.quote.content}\n我的观察（用户报告）：$observation';
    await showCognitiveAnalysis(context,
        selection: CognitiveSelection.fromText(
            module: 'quote_observation',
            recordId: _recordId,
            title: widget.topic,
            fullText: text),
        task: CognitiveTask.reflection);
  }

  Widget _block(String title, String text,
          {IconData icon = Icons.lightbulb_outline}) =>
      Card(
          margin: const EdgeInsets.only(top: 12),
          elevation: 0,
          color: const Color(0xfff7f0e4),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(icon, size: 21, color: const Color(0xff946a29)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)))
                    ]),
                    const SizedBox(height: 10),
                    Text(text, style: const TextStyle(height: 1.7)),
                  ])));
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          CognitivePreferences>(
      valueListenable: CognitivePreferenceStore.instance,
      builder: (context, prefs, _) {
        final concepts = _conceptNote?.analysis.concepts.isNotEmpty == true
            ? _conceptNote!.analysis.concepts
            : _addon.concepts;
        final quoteStyle = quotePrefersLiteraryEnglish(widget.quote.content)
            ? quoteLiteraryTextStyle(
                const TextStyle(fontSize: 21, height: 1.65))
            : const TextStyle(
                fontSize: 21, height: 1.65, fontWeight: FontWeight.w600);
        final enabled = prefs.enabled &&
            CognitivePreferenceStore.enabledInBuild &&
            QuoteInsightSettings.readingEnabled;
        return SingleChildScrollView(
            key: const ValueKey('quote-full-reading'),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.topic.trim().isNotEmpty) ...[
                    Text(widget.topic,
                        style: const TextStyle(fontSize: 20, height: 1.5)),
                    const SizedBox(height: 16)
                  ],
                  Text(widget.quote.content, style: quoteStyle),
                  if (widget.authorLabel.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    QuoteAuthorSignature(widget.authorLabel,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 15, height: 1.5))
                  ],
                  if (enabled) ...[
                    const SizedBox(height: 20),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final tab in ['直观', '概念', '比较', '判断', '应用'].indexed)
                        ChoiceChip(
                            label: Text(tab.$2),
                            selected: _tab == tab.$1,
                            onSelected: (_) => setState(() {
                                  _tab = tab.$1;
                                  _choseTab = true;
                                  final event = switch (tab.$1) {
                                    0 => CognitiveEvent.exampleOpened,
                                    2 => CognitiveEvent.differenceOpened,
                                    3 => CognitiveEvent.basisOpened,
                                    _ => null,
                                  };
                                  if (event != null)
                                    CognitiveUsageStore.instance.track(event);
                                })),
                    ]),
                    if (_tab == 0) ...[
                      if (widget.imagePath?.isNotEmpty == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(widget.imagePath!),
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink()))),
                      if (_addon.concreteExample.isNotEmpty)
                        _block('具体是什么样子 · 示例', _addon.concreteExample,
                            icon: Icons.landscape_outlined),
                      if (_conceptNote != null)
                        for (final example in _conceptNote!.analysis.examples)
                          _block('具体经验 · 模拟情境',
                              '${example.situation}\n对应：${example.connection}\n局限：${example.boundary}'),
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('示例与配画只呈现部分含义，不是史实、原意或证据。',
                              style: TextStyle(fontSize: 12))),
                      TextButton.icon(
                          onPressed: _expandConcept,
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(_addon.concreteExample.isEmpty
                              ? '看个具体例子'
                              : '展开概念与反例')),
                      QuoteVisualExplanation(
                          topic: widget.topic, quote: widget.quote.content),
                    ],
                    if (_tab == 1) ...[
                      _block(
                          '从经验到概念',
                          _conceptNote?.analysis.summary ??
                              '概念提取共同规定，也会省略具体经验的细节。可以查看一个实例、反例和适用边界。',
                          icon: Icons.hub_outlined),
                      if (concepts.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(spacing: 8, runSpacing: 4, children: [
                              for (final concept in concepts)
                                ActionChip(
                                    label: Text(concept),
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ConceptExplorer(
                                                title: concept)))),
                            ])),
                      TextButton(
                          onPressed: _expandConcept,
                          child: const Text('概念、实例与边界')),
                      if (_addon.boundary.isNotEmpty)
                        _block('概念遗漏了什么', _addon.boundary),
                    ],
                    if (_tab == 2) ...[
                      if (_addon.commonality.isNotEmpty)
                        _block('哪里相同', _addon.commonality),
                      if (_addon.criticalDifference.isNotEmpty)
                        _block('关键区别', _addon.criticalDifference),
                      _block('比较需要两个明确对象', '从历史中选择另一句名言，比较共同点、决定性差异和不能直接等同的部分。',
                          icon: Icons.compare_arrows),
                      FilledButton.tonal(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => HistoryPage(
                                      initialComparison: widget.quote))),
                          child: const Text('选择另一句比较')),
                    ],
                    if (_tab == 3) ...[
                      _block(
                          '哪些条件下不成立',
                          _addon.boundary.isEmpty
                              ? '适用条件尚未明确。一条名言不能直接证明普遍结论，需要回到具体处境检验。'
                              : _addon.boundary),
                      if (prefs.grounds && _addon.analysisBasis.isNotEmpty)
                        _block('判断依据 · 一种解释', _addon.analysisBasis,
                            icon: Icons.fact_check_outlined),
                      CognitiveAction(
                          label: '核查范围、反例与未知',
                          task: CognitiveTask.calibration,
                          selection: _selection),
                    ],
                    if (_tab == 4) ...[
                      _block('观察 → 理解 → 检验 → 修订',
                          '选择一个低风险的小情境，观察实际发生了什么。记录支持和不支持原判断的材料；有新材料时保留旧判断并修订。',
                          icon: Icons.autorenew),
                      FilledButton.tonal(
                          onPressed: _observe, child: const Text('记录一次具体观察')),
                      TextButton(
                          onPressed: () => showCognitiveNotes(context,
                              module: 'quote_observation', recordId: _recordId),
                          child: const Text('回顾我的观察与修订')),
                    ],
                  ],
                  if (widget.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const Text('解读 · 一种理解',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(widget.note,
                        style: const TextStyle(fontSize: 17, height: 1.7)),
                  ],
                  QuoteReadingInsights(
                      quote: widget.quote, showReadingSections: !enabled),
                ]));
      });
}

class QuoteVisualExplanation extends StatefulWidget {
  final String topic, quote;
  final QuoteVisualScript? script;
  const QuoteVisualExplanation(
      {super.key, required this.topic, required this.quote, this.script});
  @override
  State<QuoteVisualExplanation> createState() => _QuoteVisualExplanationState();
}

class _QuoteVisualExplanationState extends State<QuoteVisualExplanation> {
  int? _highlighted;
  late final Future<QuoteVisualScript?> _script = widget.script != null
      ? Future.value(widget.script)
      : QuoteFrameAiService()
          .readCachedScript(widget.topic, widget.quote)
          .catchError((_) => null);
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<CognitivePreferences>(
          valueListenable: CognitivePreferenceStore.instance,
          builder: (context, prefs, _) => FutureBuilder<QuoteVisualScript?>(
              future: _script,
              builder: (context, snapshot) {
                final script = snapshot.data;
                if (script == null) return const SizedBox.shrink();
                return ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('画面如何对应原句'),
                    onExpansionChanged: (open) {
                      if (open)
                        CognitiveUsageStore.instance
                            .track(CognitiveEvent.visualOpened);
                    },
                    expansionAnimationStyle: prefs.reduceMotion ||
                            MediaQuery.disableAnimationsOf(context)
                        ? AnimationStyle.noAnimation
                        : const AnimationStyle(
                            duration: Duration(milliseconds: 250)),
                    children: [
                      for (final entry in script.clauseMappings.indexed)
                        Semantics(
                            button: true,
                            selected: _highlighted == entry.$1,
                            child: InkWell(
                                onTap: () => setState(() => _highlighted =
                                    _highlighted == entry.$1 ? null : entry.$1),
                                child: AnimatedContainer(
                                    duration:
                                        prefs.reduceMotion || MediaQuery.disableAnimationsOf(context)
                                            ? Duration.zero
                                            : const Duration(milliseconds: 250),
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: _highlighted == entry.$1
                                            ? const Color(0xfff5e8cb)
                                            : Colors.transparent),
                                    child: Text(
                                        '“${entry.$2['quote_segment']}”\n↓ 视觉类比\n${entry.$2['visible_relation']}',
                                        style: const TextStyle(height: 1.6))))),
                      Text(
                          '视觉类比：${script.metaphor}\n\n对应关系：${script.relationship}\n\n'
                          '画面没有表达的部分：${script.limitations}\n\n'
                          '画面不等于概念的全部含义，也不证明因果。${script.fromAi ? '这是一种 AI 解释。' : '这是有限本地规则生成的意象。'}',
                          style: const TextStyle(height: 1.65))
                    ]);
              }));
}
