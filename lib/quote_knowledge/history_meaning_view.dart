import 'dart:async';
import 'package:flutter/material.dart';
import '../epistemic/semantic_analysis_archive.dart';
import '../epistemic/semantic_scope.dart';
import '../epistemic/semantic_scope_service.dart';
import '../epistemic/semantic_scope_view.dart';
import '../epistemic/cognitive_store.dart';
import 'models.dart';
import 'repository.dart';

class HistoryMeaningView extends StatefulWidget {
  final QuoteKnowledgeRepository repository;
  final String? category;
  final String categoryLabel, query;
  final List<Map<String, dynamic>> quotes;
  final SemanticScopeService? service;
  const HistoryMeaningView(
      {super.key,
      required this.repository,
      required this.quotes,
      this.category,
      required this.categoryLabel,
      this.query = '',
      this.service});
  @override
  State<HistoryMeaningView> createState() => _HistoryMeaningViewState();
}

class _HistoryMeaningViewState extends State<HistoryMeaningView> {
  late final service = widget.service ??
      SemanticScopeService(
          store: CognitiveStore(database: () => widget.repository.database));
  List<SavedSemanticAnalysis> saved = [];
  List<String> texts = [];
  final selected = <String>{};
  String? active;
  bool loading = true, selectionOpen = false;
  int generation = 0;
  Timer? timer;
  StreamSubscription<void>? subscription;
  @override
  void initState() {
    super.initState();
    _load();
    subscription = SemanticAnalysisArchive.changes.stream.listen((_) {
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 180), _refresh);
    });
  }

  @override
  void didUpdateWidget(HistoryMeaningView old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category || old.query != widget.query) {
      selected.clear();
      active = null;
      _load();
    } else if (old.quotes.map(knowledgeQuoteKey).toList().toString() !=
        widget.quotes.map(knowledgeQuoteKey).toList().toString())
      _initSelection();
  }

  void _initSelection() {
    selected.removeWhere(
        (id) => !widget.quotes.any((r) => knowledgeQuoteKey(r) == id));
    if (selected.isEmpty)
      selected.addAll(widget.quotes.take(2).map(knowledgeQuoteKey));
  }

  Future<void> _load() async {
    final n = ++generation;
    setState(() => loading = true);
    _initSelection();
    final all = <String>[];
    try {
      var offset = 0;
      while (true) {
        final page = await widget.repository.quotesForCategory(widget.category,
            query: widget.query, offset: offset, limit: 250);
        if (!mounted || n != generation) return;
        all.addAll(page.map((r) => '${r['content'] ?? ''}'));
        if (page.length < 250) break;
        offset += page.length;
      }
      texts = all.toSet().toList();
      await _refresh();
      await service.importReadingCaches(texts);
      if (!mounted || n != generation) return;
      await _refresh();
    } catch (_) {
      if (mounted && n == generation) setState(() => loading = false);
    }
  }

  Future<void> _refresh() async {
    final n = generation;
    try {
      final values = await service.archive.forLibrary(texts);
      if (!mounted || n != generation) return;
      setState(() {
        saved = values;
        if (active == null) active = values.firstOrNull?.session;
        if (active != 'new' && !values.any((v) => v.session == active))
          active = values.firstOrNull?.session;
        loading = false;
      });
    } catch (_) {
      if (mounted && n == generation) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = saved.where((s) => s.session == active).firstOrNull;
    final chosen = widget.quotes
        .where((r) => selected.contains(knowledgeQuoteKey(r)))
        .take(6)
        .toList();
    final sources = current?.sources ??
        [
          for (final row in chosen.indexed)
            ScopeSource(
                String.fromCharCode(65 + row.$1), '${row.$2['content'] ?? ''}',
                title: '${row.$2['author_name'] ?? ''}')
        ];
    final contextInfo = current == null
        ? SemanticContext(
            purpose: '历史名言的概念含义范围',
            requestedViews: const ['circles'],
            inquiry: '围绕${widget.categoryLabel}理解所选名言中的概念，核对共同规定、区别及其具体经验。')
        : SemanticContext(
            purpose: current.purpose,
            conditions: current.conditions,
            inquiry: current.inquiry,
            requestedViews: const ['circles']);
    final light = Theme.of(context).copyWith(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff8d7955)),
        textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xff2f2c27),
            displayColor: const Color(0xff2f2c27)),
        iconTheme: const IconThemeData(color: Color(0xff4b463c)));
    return Theme(
        data: light,
        child: DefaultTextStyle(
            style: const TextStyle(color: Color(0xff2f2c27), fontSize: 14),
            child: Container(
                key: const ValueKey('history-meaning-circles'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xfffaf7ee),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('概念含义圈',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const Text('呈现已保存的定义与范围判断；共同收录或主题相近不自动表示概念相交。',
                          style: TextStyle(fontSize: 12, height: 1.5)),
                      if (loading) const LinearProgressIndicator(),
                      if (saved.isNotEmpty)
                        DropdownButtonFormField<String>(
                            key: ValueKey('saved-meaning-$active'),
                            initialValue: current?.session,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: '已保存的关系分析'),
                            items: [
                              for (final item in saved)
                                DropdownMenuItem(
                                    value: item.session,
                                    child: Text(
                                        '${item.inquiry.isEmpty ? item.purpose : item.inquiry} · ${item.sources.map((s) => s.text).join(' / ')}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis))
                            ],
                            onChanged: (value) =>
                                setState(() => active = value)),
                      TextButton.icon(
                          onPressed: widget.quotes.isEmpty
                              ? null
                              : () => setState(() {
                                    active = 'new';
                                    selectionOpen = true;
                                  }),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('选择名言建立含义关系')),
                      if (current == null && selectionOpen)
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('本次分析 ${chosen.length} 条名言，可选择最多 6 条：'),
                              for (final row in widget.quotes)
                                CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: selected
                                        .contains(knowledgeQuoteKey(row)),
                                    title: Text('${row['content'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    onChanged: (on) => setState(() {
                                          final id = knowledgeQuoteKey(row);
                                          if (on == true && selected.length < 6)
                                            selected.add(id);
                                          else if (on != true)
                                            selected.remove(id);
                                        })),
                            ]),
                      if (current == null && saved.isEmpty && !loading)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                                '当前范围尚未保存概念含义关系。可分析所选名言建立；浏览本页不会自动请求 AI。')),
                      if (sources.isNotEmpty)
                        SemanticScopePanel(
                          key: ValueKey(current?.session ??
                              sources.map((s) => s.text).join('|')),
                          sources: sources,
                          focus: current?.focus ?? '核对所选名言的概念含义及其范围',
                          analysisContext: contextInfo,
                          initial: current?.analysis,
                          service: service,
                          preferredView: EpistemicViewKind.circles,
                          showViewSelector: false,
                        ),
                      if (current != null)
                        ExpansionTile(
                            title: Text('这张图基于 ${sources.length} 条原始名言'),
                            children: [
                              for (final s in sources)
                                ListTile(
                                    title: Text(s.text),
                                    subtitle:
                                        s.title.isEmpty ? null : Text(s.title))
                            ]),
                    ]))));
  }
}
