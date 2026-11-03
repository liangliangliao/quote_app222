import '../quote_knowledge/constellation_view.dart';
import '../quote_knowledge/repository.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import 'cognitive_mode.dart';
import 'reading_scope.dart';
import 'history_timeline.dart';
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
  final QuoteKnowledgeRepository? repository;
  final String query;
  final VoidCallback? onCompare;
  final Widget? timelineControls;
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
    this.repository,
    this.query = '',
    this.onCompare,
    this.timelineControls,
  });
  @override
  State<HistoryKnowledgeView> createState() => _HistoryKnowledgeViewState();
}

class _HistoryKnowledgeViewState extends State<HistoryKnowledgeView> {
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
    if (widget.mode == 1)
      return QuoteKnowledgeConstellation(
          repository: widget.repository,
          query: widget.query,
          selectedKeys: widget.selectedKeys,
          onOpen: widget.onOpen,
          onSelect: widget.onSelect,
          onCompare: widget.onCompare);
    if (widget.mode == 2) return _timeline();
    if (widget.rows.isEmpty)
      return const Center(child: Text('暂无匹配名言，可先导入或保存名言。'));
    if (widget.mode == 3) return _authors();
    return _timeline();
  }

  Widget _timeline() => QuoteHistoryTimeline(
      rows: widget.rows, selectedKeys: widget.selectedKeys,
      onOpen: widget.onOpen, onSelect: widget.onSelect,
      controls: widget.timelineControls, hasMore: widget.hasMore,
      loading: widget.loading, onLoadMore: widget.onLoadMore);

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
