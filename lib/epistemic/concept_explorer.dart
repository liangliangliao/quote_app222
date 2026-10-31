import 'package:flutter/material.dart';
import '../data/dao.dart';
import '../models/quote_insight.dart';
import '../widgets/quote_comparison_sheet.dart';
import 'cognitive_models.dart';
import 'cognitive_sheet.dart';
import 'cognitive_store.dart';

class ConceptExplorer extends StatefulWidget {
  final String title;
  final String? nodeUid, parentUid;
  const ConceptExplorer(
      {super.key, required this.title, this.nodeUid, this.parentUid});
  @override
  State<ConceptExplorer> createState() => _ConceptExplorerState();
}

class _ConceptExplorerState extends State<ConceptExplorer> {
  int _tab = 0;
  List<Map<String, dynamic>> _children = [], _quotes = [], _parents = [];
  CognitiveNote? _note;
  bool _loading = true;
  String? _error;
  String get _id => widget.nodeUid ?? widget.title;
  CognitiveSelection get _selection => CognitiveSelection.fromText(
      module: 'concept',
      recordId: _id,
      title: widget.title,
      fullText: widget.title);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dao = VisionDao();
      final children = widget.nodeUid == null
          ? <Map<String, dynamic>>[]
          : await dao.listThoughtChildNodes(widget.nodeUid!);
      final parents = widget.parentUid == null
          ? <Map<String, dynamic>>[]
          : await dao.listThoughtNodesByUids({widget.parentUid!});
      final quotes = await QuoteDao().latest(limit: 30, q: widget.title);
      final notes = await CognitiveStore().forRecord('concept', _id);
      if (mounted)
        setState(() {
          _children = children;
          _parents = parents;
          _quotes = quotes;
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

  Future<void> _analyze() async {
    await showCognitiveAnalysis(context,
        selection: _selection, task: CognitiveTask.concept);
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
                                    onChanged: !chosen.contains(entry.$1) &&
                                            chosen.length == 2
                                        ? null
                                        : (v) => update(() {
                                              if (v == true) {
                                                chosen.add(entry.$1);
                                              } else {
                                                chosen.remove(entry.$1);
                                              }
                                            })),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: chosen.length != 2
                              ? null
                              : () => Navigator.pop(ctx, chosen.toList()),
                          child: const Text('比较所选概念'))
                    ])));
    if (pair == null || !mounted) return;
    QuoteReference ref(int i) => QuoteReference(
        id: 'concept:${nodes[i]['uid']}', content: '${nodes[i]['title']}');
    await showQuoteComparison(context, ref(pair[0]), ref(pair[1]),
        title: '概念比较', recordLabel: '概念');
  }

  void _openNode(Map<String, dynamic> row) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ConceptExplorer(
              title: (row['title'] ?? '').toString(),
              nodeUid: row['uid']?.toString(),
              parentUid: row['parent_uid']?.toString())));
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xfffaf6ee),
      appBar: AppBar(
          title: Text(widget.title), backgroundColor: const Color(0xfffaf6ee)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final entry in ['概念树', '含义关系', '相关名言'].indexed)
            ChoiceChip(
                label: Text(entry.$2),
                selected: _tab == entry.$1,
                onSelected: (_) => setState(() => _tab = entry.$1))
        ]),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) TextButton(onPressed: _load, child: Text(_error!)),
        Card(
            color: const Color(0xfff5e8cb),
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_note?.analysis.summary ?? '从具体经验中辨认共同规定，同时保留差异。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.6))
                ]))),
        if (_tab == 0) ...[
          for (final parent in _parents)
            TextButton.icon(
                onPressed: () => _openNode(parent),
                icon: const Icon(Icons.arrow_upward),
                label: Text('返回上位概念：${parent['title']}')),
          const Padding(
              padding: EdgeInsets.only(top: 12), child: Text('分类层级 · 不表示因果关系')),
          for (final child in _children)
            Card(
                child: ListTile(
                    title: Text('${child['title']}'),
                    leading: const Icon(Icons.account_tree_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openNode(child))),
          if (_children.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('没有已保存的下位分类。可从具体实例继续理解这个概念。')),
          for (final example
              in _note?.analysis.examples ?? <CognitiveExample>[])
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('具体表现 · 模拟示例',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(example.situation,
                              style: const TextStyle(height: 1.7)),
                          Text('抽象出的规定：${example.connection}'),
                          Text('局限与例外：${example.boundary}'),
                          TextButton(
                              onPressed: () => setState(() => _tab = 1),
                              child: Text('返回“${widget.title}”的概念边界')),
                        ]))),
          FilledButton.tonal(
              onPressed: _analyze, child: const Text('展开实例、反例与边界')),
        ],
        if (_tab == 1) ...[
          Text(_note?.analysis.boundary ?? '没有充分材料时，不把词语相似或同属一个分类画成外延交集。',
              style: const TextStyle(height: 1.7)),
          if (_note?.analysis.counterExample.isNotEmpty == true)
            Text('可能反例：${_note!.analysis.counterExample}'),
          const SizedBox(height: 12),
          const Text('选择一个分类节点，比较共同规定与决定性差异：'),
          if (_parents.isNotEmpty || _children.isNotEmpty)
            OutlinedButton.icon(
                onPressed: _choosePair,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('从当前分支选择两个概念')),
          for (final row in [..._parents, ..._children])
            ListTile(
                title: Text('${row['title']}'),
                trailing: const Icon(Icons.compare_arrows),
                onTap: () => showQuoteComparison(
                    context,
                    QuoteReference(id: 'concept:$_id', content: widget.title),
                    QuoteReference(
                        id: 'concept:${row['uid']}',
                        content: '${row['title']}'),
                    title: '概念比较',
                    recordLabel: '概念')),
          TextButton(onPressed: _analyze, child: const Text('查看当前概念的根据与未知')),
        ],
        if (_tab == 2) ...[
          const Text('按当前概念文字检索本地名言；检索匹配不代表概念等同。'),
          if (_quotes.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16), child: Text('暂无匹配的本地名言。')),
          for (final row in _quotes)
            Card(
                child: ListTile(
                    title: Text('${row['content']}'),
                    subtitle: Text('${row['author_name'] ?? ''} · 待核对出处'),
                    onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                                title: const Text('相关名言 · 原句'),
                                content: SingleChildScrollView(
                                    child: SelectableText(
                                        '${row['content']}\n\n${row['explanation'] ?? ''}')),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('关闭'))
                                ])))),
        ],
      ]));
}
