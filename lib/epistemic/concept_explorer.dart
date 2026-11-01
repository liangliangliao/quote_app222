import 'package:flutter/material.dart';
import '../data/dao.dart';
import '../models/quote_insight.dart';
import '../widgets/quote_comparison_sheet.dart';
import 'cognitive_models.dart';
import 'concept_meaning_diagram.dart';
import 'cognitive_sheet.dart';
import 'cognitive_store.dart';
import 'cognitive_mode.dart';
import 'cognitive_preferences.dart';
import 'quote_concept_catalog.dart';
import 'quote_cognitive_reader.dart';

class ConceptExplorer extends StatefulWidget {
  final String title;
  final String? nodeUid, parentUid;
  final QuoteConceptCatalog? catalog;
  const ConceptExplorer({
    super.key,
    required this.title,
    this.nodeUid,
    this.parentUid,
    this.catalog,
  });
  @override
  State<ConceptExplorer> createState() => _ConceptExplorerState();
}

class _ConceptExplorerState extends State<ConceptExplorer> {
  int _tab = 0;
  List<Map<String, dynamic>> _children = [], _parents = [], _alternatives = [];
  final List<ConceptQuoteMatch> _quotes = [];
  late final _catalog = widget.catalog ?? QuoteConceptCatalog();
  String? _resolvedUid;
  int _quoteOffset = 0;
  bool _quotesLoading = false, _quotesLoaded = false, _moreQuotes = false;
  String? _quoteError;
  CognitiveNote? _note;
  bool _loading = true;
  String? _error;
  String get _id => widget.nodeUid ?? _resolvedUid ?? widget.title;
  CognitiveSelection get _selection => CognitiveSelection.fromText(
        module: 'concept',
        recordId: _id,
        title: widget.title,
        fullText: widget.title,
      );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dao = VisionDao();
      final candidates = widget.nodeUid == null
          ? await dao.findThoughtNodesByTitle(widget.title)
          : await dao.listThoughtNodesByUids({widget.nodeUid!});
      final node = candidates.length == 1 ? candidates.single : null;
      final uid = widget.nodeUid ?? node?['uid']?.toString();
      final parentUid = widget.parentUid ?? node?['parent_uid']?.toString();
      final children = uid == null
          ? <Map<String, dynamic>>[]
          : await dao.listThoughtChildNodes(uid);
      final parents = parentUid == null
          ? <Map<String, dynamic>>[]
          : await dao.listThoughtNodesByUids({parentUid});
      final alternatives = await _withClassificationPaths(dao, candidates);
      final id = uid ?? widget.title;
      final store = CognitiveStore();
      final notes = await store.forRecord('concept', id);
      if (widget.nodeUid == null && id != widget.title) {
        notes.addAll(await store.forRecord('concept', widget.title));
      }
      if (mounted)
        setState(() {
          _resolvedUid = uid;
          _alternatives = alternatives;
          _children = children;
          _parents = parents;
          _note =
              notes.where((e) => e.selection.matches(widget.title)).firstOrNull;
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = '本地关联暂未读取，可以稍后重试。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _withClassificationPaths(
    VisionDao dao,
    List<Map<String, dynamic>> candidates,
  ) async {
    if (candidates.length < 2) return [];
    String? parentOf(Map<String, dynamic> row) {
      final parent = '${row['parent_uid'] ?? ''}'.trim();
      return parent.isEmpty ? null : parent;
    }

    final nodes = {for (final row in candidates) '${row['uid']}': row};
    var frontier = candidates.map(parentOf).whereType<String>().toSet();
    final requested = <String>{};
    for (var depth = 0; depth < 32 && frontier.isNotEmpty; depth++) {
      final missing =
          frontier.difference(nodes.keys.toSet()).difference(requested);
      if (missing.isEmpty) break;
      requested.addAll(missing);
      final ancestors = await dao.listThoughtNodesByUids(missing);
      for (final row in ancestors) {
        nodes['${row['uid']}'] = row;
      }
      frontier = ancestors.map(parentOf).whereType<String>().toSet();
    }
    return candidates.map((row) {
      final path = <String>[];
      final visited = <String>{'${row['uid']}'};
      var parent = parentOf(row);
      while (parent != null && path.length < 32 && visited.add(parent)) {
        final ancestor = nodes[parent];
        if (ancestor == null) break;
        path.add('${ancestor['title']}');
        parent = parentOf(ancestor);
      }
      final label = path.isEmpty && parentOf(row) == null
          ? '根分类'
          : '上位分类：${path.isEmpty ? '待确认' : path.reversed.join(' → ')}${parent == null ? '' : ' · 路径待核对'}';
      return {...row, 'classification_path': label};
    }).toList();
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (tab == 2 && !_quotesLoaded) _loadQuotes();
  }

  Future<void> _loadQuotes({bool reset = false}) async {
    if (_quotesLoading) return;
    setState(() {
      _quotesLoading = true;
      _quoteError = null;
      if (reset) {
        _quotes.clear();
        _quoteOffset = 0;
      }
    });
    try {
      final page = await _catalog.find(widget.title, offset: _quoteOffset);
      if (mounted)
        setState(() {
          final ids =
              _quotes.map((e) => QuoteReference.fromRow(e.row).id).toSet();
          _quotes.addAll(
            page.matches.where((e) {
              final ref = QuoteReference.fromRow(e.row);
              return ref.id.isEmpty || ids.add(ref.id);
            }),
          );
          _quoteOffset = page.nextOffset;
          _moreQuotes = page.hasMore;
          _quotesLoaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _quoteError = '相关名言暂未读取，请重试。');
    } finally {
      if (mounted) setState(() => _quotesLoading = false);
    }
  }

  Future<void> _openQuote(Map<String, dynamic> row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .88,
        child: SelectionArea(
          child: QuoteCognitiveReader(
            quote: QuoteReference.fromRow(row),
            topic: '${row['theme'] ?? ''}',
            authorLabel: '${row['author_name'] ?? ''}',
            note: '${row['explanation'] ?? ''}',
          ),
        ),
      ),
    );
    if (mounted && CognitivePreferenceStore.active) _loadQuotes(reset: true);
  }

  Future<void> _analyze() async {
    await showCognitiveAnalysis(
      context,
      selection: _selection,
      task: CognitiveTask.concept,
    );
    if (mounted) await _load();
  }

  Future<void> _choosePair() async {
    final nodes = <String, Map<String, dynamic>>{
      _id: {'uid': _id, 'title': widget.title},
      for (final row in [..._parents, ..._children]) '${row['uid']}': row,
    }.values.toList();
    final chosen = <int>{};
    final pair = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('选择两个概念'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in nodes.indexed)
                    CheckboxListTile(
                      title: Text('${entry.$2['title']}'),
                      value: chosen.contains(entry.$1),
                      onChanged:
                          !chosen.contains(entry.$1) && chosen.length == 2
                              ? null
                              : (v) => update(() {
                                    if (v == true) {
                                      chosen.add(entry.$1);
                                    } else {
                                      chosen.remove(entry.$1);
                                    }
                                  }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: chosen.length != 2
                  ? null
                  : () => Navigator.pop(ctx, chosen.toList()),
              child: const Text('比较所选概念'),
            ),
          ],
        ),
      ),
    );
    if (pair == null || !mounted) return;
    QuoteReference ref(int i) => QuoteReference(
          id: 'concept:${nodes[i]['uid']}',
          content: '${nodes[i]['title']}',
        );
    await showQuoteComparison(
      context,
      ref(pair[0]),
      ref(pair[1]),
      title: '概念比较',
      recordLabel: '概念',
    );
  }

  void _openNode(Map<String, dynamic> row) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConceptExplorer(
            title: (row['title'] ?? '').toString(),
            nodeUid: row['uid']?.toString(),
            parentUid: row['parent_uid']?.toString(),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => CognitiveModePage(
        title: widget.title,
        child: Scaffold(
          backgroundColor: const Color(0xfffaf6ee),
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: const Color(0xfffaf6ee),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in ['概念树', '含义关系', '相关名言'].indexed)
                    ChoiceChip(
                      selectedColor: const Color(0xffe9d8b9),
                      backgroundColor: const Color(0xfffffcf6),
                      side: const BorderSide(color: Color(0xffded4c5)),
                      label: Text(entry.$2),
                      selected: _tab == entry.$1,
                      onSelected: (_) => _selectTab(entry.$1),
                    ),
                ],
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                TextButton(onPressed: _load, child: Text(_error!)),
              Card(
                color: const Color(0xfff5e8cb),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _note?.analysis.summary ?? '从具体经验中辨认共同规定，同时保留差异。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
              if (_tab == 0) ...[
                if (_alternatives.isNotEmpty) ...[
                  const Text('发现多个同名分类，请选择具体含义；它们不会被自动合并。'),
                  for (final node in _alternatives)
                    ListTile(
                      title: Text('${node['title']}'),
                      subtitle: Text('${node['classification_path']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openNode(node),
                    ),
                ],
                for (final parent in _parents)
                  TextButton.icon(
                    onPressed: () => _openNode(parent),
                    icon: const Icon(Icons.arrow_upward),
                    label: Text('返回上位概念：${parent['title']}'),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('分类层级 · 不表示因果关系'),
                ),
                for (final child in _children)
                  Card(
                    child: ListTile(
                      title: Text('${child['title']}'),
                      leading: const Icon(Icons.account_tree_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openNode(child),
                    ),
                  ),
                if (_children.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('没有已保存的下位分类。可从具体实例继续理解这个概念。'),
                  ),
                for (final example
                    in _note?.analysis.examples ?? <CognitiveExample>[])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '具体表现 · 模拟示例',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            example.situation,
                            style: const TextStyle(height: 1.7),
                          ),
                          Text('抽象出的规定：${example.connection}'),
                          Text('局限与例外：${example.boundary}'),
                          TextButton(
                            onPressed: () => setState(() => _tab = 1),
                            child: Text('返回“${widget.title}”的概念边界'),
                          ),
                        ],
                      ),
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: _analyze,
                  child: const Text('展开实例、反例与边界'),
                ),
              ],
              if (_tab == 1) ...[
                if (_note != null)
                  ConceptAnalysisView(
                    abstractions: _note!.analysis.abstractions,
                    scopes: _note!.analysis.scopes,
                  ),
                Text(
                  _note?.analysis.boundary ?? '没有充分材料时，不把词语相似或同属一个分类画成外延交集。',
                  style: const TextStyle(height: 1.7),
                ),
                if (_note?.analysis.counterExample.isNotEmpty == true)
                  Text('可能反例：${_note!.analysis.counterExample}'),
                const SizedBox(height: 12),
                const Text('选择一个分类节点，比较共同规定与决定性差异：'),
                if (_parents.isNotEmpty || _children.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _choosePair,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('从当前分支选择两个概念'),
                  ),
                for (final row in [..._parents, ..._children])
                  ListTile(
                    title: Text('${row['title']}'),
                    trailing: const Icon(Icons.compare_arrows),
                    onTap: () => showQuoteComparison(
                      context,
                      QuoteReference(id: 'concept:$_id', content: widget.title),
                      QuoteReference(
                        id: 'concept:${row['uid']}',
                        content: '${row['title']}',
                      ),
                      title: '概念比较',
                      recordLabel: '概念',
                    ),
                  ),
                TextButton(
                    onPressed: _analyze, child: const Text('查看当前概念的根据与未知')),
              ],
              if (_tab == 2) ...[
                const Text('同时查找本地概念标注和文字匹配。概念建议与文字匹配都不表示已经核实。'),
                if (_quotesLoading) const LinearProgressIndicator(),
                if (_quoteError != null)
                  TextButton(onPressed: _loadQuotes, child: Text(_quoteError!)),
                if (!_quotesLoading && _quoteError == null && _quotes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无匹配的本地名言。'),
                  ),
                for (final match in _quotes)
                  Card(
                    child: ListTile(
                      title: Text('${match.row['content']}'),
                      subtitle: Text(
                        '${match.row['author_name'] ?? ''}\n${match.explanation}',
                      ),
                      isThreeLine: true,
                      onTap: () => _openQuote(match.row),
                    ),
                  ),
                if (_moreQuotes)
                  TextButton.icon(
                    onPressed: _quotesLoading ? null : _loadQuotes,
                    icon: const Icon(Icons.expand_more),
                    label: const Text('继续加载相关名言'),
                  ),
              ],
            ],
          ),
        ),
      );
}
