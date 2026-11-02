import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'repository.dart';
import 'runtime.dart';
import 'schema.dart';

Future<void> showQuoteKnowledgeManagement(
        BuildContext context, QuoteKnowledgeRepository repository,
        {Map<String, dynamic>? quote}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
            heightFactor: .88,
            child: QuoteKnowledgeManagement(
                repository: repository, quote: quote)));

class QuoteKnowledgeManagement extends StatefulWidget {
  final QuoteKnowledgeRepository repository;
  final Map<String, dynamic>? quote;
  const QuoteKnowledgeManagement(
      {super.key, required this.repository, this.quote});
  @override
  State<QuoteKnowledgeManagement> createState() =>
      _QuoteKnowledgeManagementState();
}

class _QuoteKnowledgeManagementState extends State<QuoteKnowledgeManagement> {
  QuoteKnowledgeGraph? _graph;
  List<Map<String, dynamic>> _proof = [], _review = [];
  int _reviewLimit = 20;
  StreamSubscription<void>? _changes;
  final _selected = <String>{};
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
    _changes = QuoteKnowledgeEvents.changes.listen((_) => _load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await widget.repository.bootstrapLegacy();
      final graph = await widget.repository.snapshot();
      final review = await widget.repository.reviewQueue(limit: _reviewLimit);
      var proof = <Map<String, dynamic>>[];
      if (widget.quote != null) {
        final rows = await widget.repository
            .assignments(knowledgeQuoteKey(widget.quote!));
        proof = rows;
        if (_graph == null) _selected.addAll(rows.map((r) => '${r['id']}'));
      }
      if (mounted)
        setState(() {
          _graph = graph;
          _proof = proof;
          _review = review;
        });
    } catch (_) {
      if (mounted) setState(() => _message = '分类暂未读取，可重试。');
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      QuoteKnowledgeRuntime.instance.kick();
      if (mounted) setState(() => _message = message);
    } catch (_) {
      if (mounted) setState(() => _message = '未能完成操作，请检查类别层级后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create({String parent = ''}) async {
    final name = TextEditingController(), definition = TextEditingController();
    final value = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('新增类别'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      maxLength: 24,
                      decoration: const InputDecoration(labelText: '类别名称')),
                  TextField(
                      controller: definition,
                      maxLength: 200,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '类别含义与范围')),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () {
                        if (name.text.trim().isNotEmpty &&
                            definition.text.trim().isNotEmpty)
                          Navigator.pop(context, true);
                      },
                      child: const Text('创建'))
                ]));
    if (value == true && mounted)
      await _run(() async {
        await widget.repository
            .createCategory(name.text, definition.text, parentId: parent);
      }, '类别已创建');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    definition.dispose();
  }

  Future<void> _move(QuoteCategory category) async {
    final parent = await showDialog<String>(
        context: context,
        builder: (context) =>
            SimpleDialog(title: Text('调整“${category.name}”的上位类别'), children: [
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('设为根类别')),
              for (final c
                  in _graph!.categories.where((c) => c.id != category.id))
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, c.id),
                    child: Text(c.name)),
            ]));
    if (parent != null && mounted)
      await _run(
          () => widget.repository.moveCategory(category.id, parent), '类别层级已调整');
  }

  Widget _category(QuoteCategory c, Set<String> visited) {
    if (!visited.add(c.id)) return const SizedBox.shrink();
    final children = _graph!.children(c.id);
    final title = widget.quote == null
        ? Text('${c.name} · ${c.quoteCount}')
        : CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(c.name),
            value: _selected.contains(c.id),
            onChanged: (v) => setState(() {
                  if (v == true)
                    _selected.add(c.id);
                  else
                    _selected.remove(c.id);
                }));
    return ExpansionTile(
        key: ValueKey('knowledge-category-${c.id}'),
        title: title,
        subtitle: Text(c.definition),
        children: [
          Wrap(spacing: 8, children: [
            TextButton.icon(
                onPressed: _busy ? null : () => _create(parent: c.id),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加下位类别')),
            TextButton(
                onPressed: _busy ? null : () => _move(c),
                child: const Text('调整层级'))
          ]),
          for (final child in children)
            Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _category(child, {...visited})),
        ]);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
            Row(children: [
              const Expanded(
                  child: Text('名言分类管理',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭分类管理',
                  icon: const Icon(Icons.close))
            ]),
            const Text('新增名言自动归类；优先复用已有类别，必要时建立下位类别。自动归类保留原句依据，可人工调整。',
                style: TextStyle(height: 1.6)),
            if (_graph case final g?) ...[
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      '全库 ${g.quoteCount} 条 · 队列 ${g.pending} 条 · 待复核 ${g.needsReview} 条 · 旧记录待整理 ${g.legacyRemaining} 条')),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                    key: const ValueKey('knowledge-backfill'),
                    onPressed: _busy
                        ? null
                        : () => _run(widget.repository.enqueueBackfill,
                            '已加入整理队列，可暂停后继续。'),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('一键分批整理旧记录')),
                TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(widget.repository.pauseBackfill,
                            '已暂停旧记录队列；正在处理的一条会完成。'),
                    child: const Text('暂停旧记录整理')),
                TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(widget.repository.retryPending, '已重新加入队列'),
                    child: const Text('重试未完成')),
                TextButton.icon(
                    onPressed: _busy ? null : () => _create(),
                    icon: const Icon(Icons.add),
                    label: const Text('新增根类别')),
              ]),
              if (widget.quote != null) ...[
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('${widget.quote!['content']}')),
                if (_proof.isNotEmpty)
                  ExpansionTile(title: const Text('当前归类与原句依据'), children: [
                    for (final p in _proof)
                      ListTile(
                          title: Text('${p['name']}'),
                          subtitle: Text(
                              '${p['reason']}\n${'${p['evidence']}'.isEmpty ? '原主题初分或用户调整' : '“${p['evidence']}”'}')),
                  ]),
                FilledButton(
                    onPressed: _busy || _selected.isEmpty
                        ? null
                        : () => _run(
                            () => widget.repository.assignManually(
                                knowledgeQuoteKey(widget.quote!),
                                _selected.toList()),
                            '分类已保存，自动整理会保留你的调整。'),
                    child: const Text('保存名言分类')),
              ],
              if (_message != null)
                Text(_message!, style: const TextStyle(height: 1.6)),
              if (_busy) const LinearProgressIndicator(),
              if (_review.isNotEmpty)
                ExpansionTile(
                    title: Text(
                        '待复核与未完成的名言 · ${_review.length}${_review.length == _reviewLimit ? '+' : ''}'),
                    children: [
                      for (final row in _review)
                        ListTile(
                            title: Text('${row['content']}',
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${row['review_reason'] ?? ''} ${row['last_error'] ?? ''}'),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => showQuoteKnowledgeManagement(
                                context, widget.repository,
                                quote: row)),
                      if (_review.length == _reviewLimit)
                        TextButton(
                            onPressed: () {
                              _reviewLimit += 20;
                              _load();
                            },
                            child: const Text('加载更多待整理名言')),
                    ]),
              for (final c in g.roots) _category(c, {}),
            ] else
              TextButton(onPressed: _load, child: Text(_message ?? '正在读取分类…')),
          ]));
}
