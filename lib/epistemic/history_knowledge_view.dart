import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import 'cognitive_preferences.dart';
import 'cognitive_store.dart';
import 'cognitive_models.dart';
import 'cognitive_mode.dart';
import 'quote_concept_catalog.dart';
import 'reading_scope.dart';
import 'semantic_scope.dart';
import 'semantic_scope_view.dart';
import '../widgets/quote_history_avatar.dart';

class QuoteConceptGroup {
  final String title;
  final List<Map<String, dynamic>> rows;
  final bool fromExplicitConcepts;
  const QuoteConceptGroup(this.title, this.rows, this.fromExplicitConcepts);
}

List<QuoteConceptGroup> groupQuoteConcepts(
  List<Map<String, dynamic>> rows,
  Map<String, QuoteAnalysisAddon> addons,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  final explicit = <String>{};
  for (final row in rows) {
    final ref = QuoteReference.fromRow(row);
    final concepts = addons[ref.contentKey]?.concepts ?? [];
    final theme = (row['theme'] ?? '').toString().trim();
    final labels = indexTerms(theme, concepts, ref.content);
    for (final label in labels) {
      grouped.putIfAbsent(label, () => []).add(row);
      if (concepts.isNotEmpty) explicit.add(label);
    }
  }
  final groups = grouped.entries
      .map((e) => QuoteConceptGroup(e.key, e.value, explicit.contains(e.key)))
      .toList();
  groups.sort((a, b) {
    final n = b.rows.length.compareTo(a.rows.length);
    return n == 0 ? a.title.compareTo(b.title) : n;
  });
  return groups;
}

class HistoryKnowledgeView extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final int mode, revision;
  final void Function(Map<String, dynamic>) onOpen, onSelect;
  final Set<String> selectedKeys;
  final VoidCallback onLoadMore;
  final bool hasMore, loading;
  final QuoteInsightStore? store;
  const HistoryKnowledgeView({
    super.key,
    required this.rows,
    required this.mode,
    this.revision = 0,
    required this.onOpen,
    required this.onSelect,
    required this.selectedKeys,
    required this.onLoadMore,
    required this.hasMore,
    required this.loading,
    this.store,
  });
  @override
  State<HistoryKnowledgeView> createState() => _HistoryKnowledgeViewState();
}

class _HistoryKnowledgeViewState extends State<HistoryKnowledgeView> {
  Map<String, QuoteAnalysisAddon> _addons = {};
  List<QuoteConceptGroup>? _groups;
  String? _selected;
  String _conceptSearch = '';
  bool _stars = false;
  String? _addonError;
  final Set<String> _chosen = {};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    CognitivePreferenceStore.instance.load();
    _load();
  }

  @override
  void didUpdateWidget(HistoryKnowledgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.rows.length != widget.rows.length ||
        oldWidget.rows.toString() != widget.rows.toString()) {
      _groups = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final addons = await (widget.store ?? QuoteInsightStore()).readAddons(
        widget.rows.map(QuoteReference.fromRow).toList(),
      );
      final refs = widget.rows.map(QuoteReference.fromRow).toList();
      List<CognitiveNote> notes = const [];
      String? warning;
      try {
        notes = await CognitiveStore().forRecords(
          'quote',
          refs.map((r) => r.id.isEmpty ? r.contentKey : r.id).toList(),
        );
      } catch (_) {
        // A note-store problem must not discard existing quote concept tags.
        warning = '认识注释暂未读取；当前显示已有概念标注与原主题。';
      }
      for (final ref in refs) {
        final note = QuoteConceptCatalog.currentConceptNote(ref, notes);
        if (note != null && note.analysis.concepts.isNotEmpty) {
          addons[ref.contentKey] = QuoteAnalysisAddon.fromStoredJson({
            ...?addons[ref.contentKey]?.toJson(),
            'concepts': note.analysis.concepts,
          });
        }
      }
      if (mounted && generation == _generation)
        setState(() {
          _addons = addons;
          _groups = null;
          _addonError = warning;
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _addons = {};
          _groups = null;
          _addonError = '概念标注暂未读取，当前按原记录主题展示。';
        });
    }
  }

  Widget _quote(Map<String, dynamic> row, {bool dark = false}) {
    final ref = QuoteReference.fromRow(row);
    final selected = widget.selectedKeys.contains(ref.contentKey);
    return Card(
      color: dark ? const Color(0xfff5f0e6) : null,
      child: ListTile(
        onTap: () => widget.onOpen(row),
        title: Text(
          ref.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: dark ? const TextStyle(color: Color(0xff292a2b)) : null,
        ),
        subtitle: Text(
          ref.author,
          style: dark ? const TextStyle(color: Color(0xff635f54)) : null,
        ),
        trailing: IconButton(
          tooltip: selected ? '取消比较选择' : '加入比较',
          onPressed: () => widget.onSelect(row),
          icon: Icon(
            selected ? Icons.check_circle : Icons.add_circle_outline,
            color: selected
                ? Colors.teal
                : dark
                    ? Colors.black54
                    : null,
          ),
        ),
      ),
    );
  }

  Widget get _more => widget.hasMore
      ? TextButton.icon(
          onPressed: widget.loading ? null : widget.onLoadMore,
          icon: const Icon(Icons.expand_more),
          label: Text(widget.loading ? '正在读取' : '加载更多名言'),
        )
      : const SizedBox.shrink();
  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty)
      return const Center(child: Text('暂无匹配名言，可先导入或保存名言。'));
    if (widget.mode == 2) return _timeline();
    if (widget.mode == 3) return _authors();
    final groups = _groups ??= groupQuoteConcepts(widget.rows, _addons);
    final filtered = groups
        .where(
            (g) => g.title.toLowerCase().contains(_conceptSearch.toLowerCase()))
        .toList();
    final selected = groups.where((g) => g.title == _selected).firstOrNull ??
        groups.firstOrNull;
    final chosen =
        groups.where((g) => _chosen.contains(g.title)).take(6).toList();
    final sources = [
      for (final entry in chosen.indexed)
        ScopeSource(String.fromCharCode(65 + entry.$1),
            '主题概念　${entry.$2.title}\n${entry.$2.rows.take(3).map((r) => QuoteReference.fromRow(r).content).join('\n')}',
            title: entry.$2.title)
    ];
    return ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, prefs, _) =>
            ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('概念含义圈'),
                    selected: !_stars,
                    onSelected: (_) => setState(() => _stars = false)),
                ChoiceChip(
                    label: const Text('概念星图'),
                    selected: _stars,
                    onSelected: (_) => setState(() => _stars = true)),
              ]),
              const Text('选择主题概念，分析它们的含义和外延关系。', style: TextStyle(height: 1.5)),
              Text('已载入 ${widget.rows.length} 条名言。最多选择六个主题概念。',
                  style: const TextStyle(fontSize: 12)),
              if (_addonError != null)
                TextButton(onPressed: _load, child: Text(_addonError!)),
              TextField(
                  key: const ValueKey('history-concept-search'),
                  decoration: const InputDecoration(
                      labelText: '查找概念', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _conceptSearch = v)),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (filtered.isEmpty) const Text('暂无匹配概念。'),
                for (final group in filtered)
                  FilterChip(
                      label: Text('${group.title} ${group.rows.length}'),
                      selected: _chosen.contains(group.title),
                      onSelected: (v) => setState(() {
                            _selected = group.title;
                            if (v && _chosen.length < 6)
                              _chosen.add(group.title);
                            else if (!v) _chosen.remove(group.title);
                          }))
              ]),
              if (prefs.relations && sources.isNotEmpty)
                SemanticScopePanel(
                    sources: sources, focus: '所选主题概念的语义与外延关系', stars: _stars)
              else if (!prefs.relations)
                const Text('关系图已关闭，可继续查阅主题收录。'),
              if (selected != null) ...[
                Text('${selected.title} · 关联收录',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final row in selected.rows) _quote(row),
              ],
              _more,
            ]));
  }

  Widget _timeline() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in widget.rows) {
      final raw = row['created_at'];
      final date = DateTime.tryParse('${row['inserted_at'] ?? ''}') ??
          (raw is num && raw > 0
              ? DateTime.fromMillisecondsSinceEpoch(raw.toInt())
              : null);
      final label =
          date == null ? '记录时间未知' : '${date.year}年${date.month}月${date.day}日';
      groups.putIfAbsent(label, () => []).add(row);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('时间线 · 记录时间不证明思想之间存在因果', style: TextStyle(height: 1.6)),
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              group.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final row in group.value) _quote(row),
        ],
        _more,
      ],
    );
  }

  ImageProvider? _authorImage(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final path = '${row['avatar'] ?? row['avatar_path'] ?? ''}'.trim();
      if (path.startsWith('data:')) {
        try {
          return MemoryImage(
              base64Decode(path.substring(path.indexOf(',') + 1)));
        } catch (_) {}
      }
      if (path.startsWith('assets/')) return AssetImage(path);
      if (path.startsWith('https://')) return NetworkImage(path);
      if (path.isNotEmpty && File(path).existsSync())
        return FileImage(File(path));
    }
    return null;
  }

  Widget _authors() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in widget.rows) {
      final author = (row['author_name'] ?? '').toString().trim();
      groups.putIfAbsent(author.isEmpty ? '作者待考' : author, () => []).add(row);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('按记录署名聚合 · 作者声望不代替根据'),
        for (final entry in groups.entries)
          ExpansionTile(
            expansionAnimationStyle: cognitiveExpansionStyle(context),
            title: Text(entry.key),
            subtitle: Text('${entry.value.length} 条'),
            leading: QuoteHistoryAvatar(
              image: _authorImage(entry.value),
              diameter: 52,
            ),
            children: [for (final row in entry.value) _quote(row)],
          ),
        _more,
      ],
    );
  }
}
