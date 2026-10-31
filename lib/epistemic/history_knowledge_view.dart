import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/quote_insight_store.dart';
import '../models/quote_insight.dart';
import 'cognitive_preferences.dart';
import 'cognitive_store.dart';
import 'cognitive_models.dart';

class QuoteConceptGroup {
  final String title;
  final List<Map<String, dynamic>> rows;
  final bool fromExplicitConcepts;
  const QuoteConceptGroup(this.title, this.rows, this.fromExplicitConcepts);
}

List<QuoteConceptGroup> groupQuoteConcepts(
    List<Map<String, dynamic>> rows, Map<String, QuoteAnalysisAddon> addons) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  final explicit = <String>{};
  for (final row in rows) {
    final ref = QuoteReference.fromRow(row);
    final concepts = addons[ref.contentKey]?.concepts ?? [];
    final theme = (row['theme'] ?? '').toString().trim();
    final labels = concepts.isNotEmpty
        ? concepts.toSet()
        : <String>{theme.isEmpty ? '未分类' : theme};
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
  const HistoryKnowledgeView(
      {super.key,
      required this.rows,
      required this.mode,
      this.revision = 0,
      required this.onOpen,
      required this.onSelect,
      required this.selectedKeys,
      required this.onLoadMore,
      required this.hasMore,
      required this.loading,
      this.store});
  @override
  State<HistoryKnowledgeView> createState() => _HistoryKnowledgeViewState();
}

class _HistoryKnowledgeViewState extends State<HistoryKnowledgeView> {
  final _transform =
      TransformationController(Matrix4.diagonal3Values(.43, .43, 1));
  Map<String, QuoteAnalysisAddon> _addons = {};
  String? _selected;
  double _zoom = .43;
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
        oldWidget.rows.toString() != widget.rows.toString()) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final addons = await (widget.store ?? QuoteInsightStore())
          .readAddons(widget.rows.map(QuoteReference.fromRow).toList());
      final refs = widget.rows.map(QuoteReference.fromRow).toList();
      List<CognitiveNote> notes = const [];
      try {
        notes = await CognitiveStore().forRecords('quote',
            refs.map((r) => r.id.isEmpty ? r.contentKey : r.id).toList());
      } catch (_) {
        // A note-store problem must not discard existing quote concept tags.
      }
      for (final ref in refs) {
        final note = notes
            .where((n) =>
                n.task == CognitiveTask.concept &&
                n.selection.recordId ==
                    (ref.id.isEmpty ? ref.contentKey : ref.id) &&
                n.selection.matches(ref.content))
            .firstOrNull;
        if (note != null && note.analysis.concepts.isNotEmpty) {
          addons[ref.contentKey] = QuoteAnalysisAddon.fromStoredJson({
            ...?addons[ref.contentKey]?.toJson(),
            'concepts': note.analysis.concepts
          });
        }
      }
      if (mounted && generation == _generation)
        setState(() => _addons = addons);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _addons = {});
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Widget _quote(Map<String, dynamic> row, {bool dark = false}) {
    final ref = QuoteReference.fromRow(row);
    final selected = widget.selectedKeys.contains(ref.contentKey);
    return Card(
        color: dark ? const Color(0xfff5f0e6) : null,
        child: ListTile(
            onTap: () => widget.onOpen(row),
            title: Text(ref.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: dark ? const TextStyle(color: Color(0xff292a2b)) : null),
            subtitle: Text(ref.author,
                style: dark ? const TextStyle(color: Color(0xff635f54)) : null),
            trailing: IconButton(
                tooltip: selected ? '取消比较选择' : '加入比较',
                onPressed: () => widget.onSelect(row),
                icon: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected
                        ? Colors.teal
                        : dark
                            ? Colors.black54
                            : null))));
  }

  Widget get _more => widget.hasMore
      ? TextButton.icon(
          onPressed: widget.loading ? null : widget.onLoadMore,
          icon: const Icon(Icons.expand_more),
          label: Text(widget.loading ? '正在读取' : '加载更多名言'))
      : const SizedBox.shrink();
  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty)
      return const Center(child: Text('暂无匹配名言，可先导入或保存名言。'));
    if (widget.mode == 2) return _timeline();
    if (widget.mode == 3) return _authors();
    final groups = groupQuoteConcepts(widget.rows, _addons);
    final selected =
        groups.where((g) => g.title == _selected).firstOrNull ?? groups.first;
    return ValueListenableBuilder<CognitivePreferences>(
        valueListenable: CognitivePreferenceStore.instance,
        builder: (context, prefs, _) => ColoredBox(
            color: const Color(0xff081f28),
            child: Theme(
                data: ThemeData.dark(useMaterial3: true).copyWith(
                    textTheme: Theme.of(context).textTheme.apply(
                        bodyColor: Colors.white, displayColor: Colors.white)),
                child: Material(
                    color: Colors.transparent,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      const Text('概念关系 · 从共相到具体名言',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                          '已载入 ${widget.rows.length} 条名言。节点大小表示当前记录数；连线仅表示概念共现，不证明因果或外延交集。',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xffbdcbd0),
                              height: 1.5)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 7, runSpacing: 4, children: [
                        for (final group in groups.take(24))
                          ChoiceChip(
                              label:
                                  Text('${group.title} ${group.rows.length}'),
                              selected: group.title == selected.title,
                              onSelected: (_) =>
                                  setState(() => _selected = group.title))
                      ]),
                      if (prefs.relations) ...[
                        Row(children: [
                          const Expanded(
                              child: Text('缩小看概念 · 放大看名言',
                                  style: TextStyle(fontSize: 12))),
                          IconButton(
                              tooltip: '缩小关系图',
                              onPressed: () => _scale(.8),
                              icon: const Icon(Icons.remove)),
                          IconButton(
                              tooltip: '放大关系图',
                              onPressed: () => _scale(1.25),
                              icon: const Icon(Icons.add)),
                          IconButton(
                              tooltip: '重置视图',
                              onPressed: () => setState(() {
                                    _transform.value =
                                        Matrix4.diagonal3Values(.43, .43, 1);
                                    _zoom = .43;
                                  }),
                              icon: const Icon(Icons.fit_screen))
                        ]),
                        SizedBox(
                            height: 350,
                            child: ClipRect(
                                child: InteractiveViewer(
                                    transformationController: _transform,
                                    constrained: false,
                                    minScale: .3,
                                    maxScale: 2.5,
                                    boundaryMargin: const EdgeInsets.all(200),
                                    onInteractionUpdate: (_) => setState(() =>
                                        _zoom = _transform.value
                                            .getMaxScaleOnAxis()),
                                    child: _graph(
                                        groups.take(24).toList(), selected)))),
                      ] else
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('关系图已关闭，仍可按概念浏览关联名言。')),
                      const SizedBox(height: 12),
                      Text(
                          '${selected.title} · ${selected.fromExplicitConcepts ? '已保存的概念标注' : '原记录主题'}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      for (final row in selected.rows) _quote(row, dark: true),
                      _more,
                    ])))));
  }

  void _scale(double factor) => setState(() {
        final target = (_zoom * factor).clamp(.3, 2.5);
        _transform.value = _transform.value.clone()
          ..multiply(
              Matrix4.diagonal3Values(target / _zoom, target / _zoom, 1));
        _zoom = target;
      });
  Offset _position(int i, int length) {
    if (i == 0) return const Offset(450, 320);
    final ring = (i - 1) ~/ 8;
    final angle = (i - 1) % 8 * math.pi / 4 - math.pi / 2 + ring * .25;
    final radius = 155.0 + ring * 105;
    return Offset(
        450 + math.cos(angle) * radius, 320 + math.sin(angle) * radius * .7);
  }

  Widget _graph(List<QuoteConceptGroup> groups, QuoteConceptGroup selected) {
    double diameter(QuoteConceptGroup g) =>
        84 + 55 * math.sqrt(g.rows.length / groups.first.rows.length);
    final points = [
      for (var i = 0; i < groups.length; i++) _position(i, groups.length)
    ];
    final connections = <(Offset, Offset)>[];
    for (var i = 0; i < groups.length; i++) {
      final ids = groups[i]
          .rows
          .map((r) => QuoteReference.fromRow(r).contentKey)
          .toSet();
      for (var j = i + 1; j < groups.length; j++) {
        if (groups[j]
            .rows
            .any((r) => ids.contains(QuoteReference.fromRow(r).contentKey))) {
          connections.add((points[i], points[j]));
        }
      }
    }
    final selectedIndex = groups.indexWhere((g) => g.title == selected.title);
    final center =
        selectedIndex >= 0 ? points[selectedIndex] : const Offset(450, 320);
    return SizedBox(
        width: 900,
        height: 640,
        child: Stack(children: [
          Positioned.fill(
              child: CustomPaint(painter: _ConstellationPainter(connections))),
          for (final entry in groups.indexed)
            Positioned(
                left: points[entry.$1].dx - diameter(entry.$2) / 2,
                top: points[entry.$1].dy - diameter(entry.$2) / 2,
                child: Semantics(
                    button: true,
                    label: '${entry.$2.title}，${entry.$2.rows.length} 条名言',
                    child: InkWell(
                        onTap: () => setState(() => _selected = entry.$2.title),
                        customBorder: const CircleBorder(),
                        child: Container(
                            width: diameter(entry.$2),
                            height: diameter(entry.$2),
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  [
                                    const Color(0xffb08b45),
                                    const Color(0xff537b8b),
                                    const Color(0xff906b78),
                                    const Color(0xff4b856b)
                                  ][entry.$1 % 4],
                                  const Color(0xff132b34)
                                ]),
                                border: Border.all(
                                    color: entry.$2.title == selected.title
                                        ? const Color(0xffffe3a1)
                                        : Colors.white38,
                                    width: entry.$2.title == selected.title
                                        ? 3
                                        : 1),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.white.withAlpha(30),
                                      blurRadius: 14)
                                ]),
                            child: Text(
                                '${entry.$2.title}\n(${entry.$2.rows.length})',
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: entry.$1 == 0 ? 21 : 17,
                                    height: 1.3)))))),
          if (_zoom >= 1.0)
            for (final entry in selected.rows.take(4).indexed)
              Positioned(
                  left: center.dx + (entry.$1.isEven ? -250 : 80),
                  top: center.dy + (entry.$1 < 2 ? -150 : 80),
                  width: 170,
                  child: Card(
                      color: const Color(0xfffaf5e9),
                      child: InkWell(
                          onTap: () => widget.onOpen(entry.$2),
                          child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text('${entry.$2['content']}',
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xff302c25))))))),
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
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('时间线 · 记录时间不证明思想之间存在因果', style: TextStyle(height: 1.6)),
      for (final group in groups.entries) ...[
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(group.key,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        for (final row in group.value) _quote(row),
      ],
      _more,
    ]);
  }

  Widget _authors() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in widget.rows) {
      final author = (row['author_name'] ?? '').toString().trim();
      groups.putIfAbsent(author.isEmpty ? '作者待考' : author, () => []).add(row);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('按记录署名聚合 · 作者声望不代替根据'),
      for (final entry in groups.entries)
        ExpansionTile(
            title: Text(entry.key),
            subtitle: Text('${entry.value.length} 条'),
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            children: [for (final row in entry.value) _quote(row)]),
      _more,
    ]);
  }
}

class _ConstellationPainter extends CustomPainter {
  final List<(Offset, Offset)> connections;
  _ConstellationPainter(this.connections);
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(17);
    final star = Paint()..color = Colors.white.withAlpha(100);
    for (var i = 0; i < 130; i++) {
      canvas.drawCircle(
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height),
          .6 + random.nextDouble() * 1.2,
          star);
    }
    final edge = Paint()
      ..color = const Color(0xff537380)
      ..strokeWidth = 1.2;
    for (final pair in connections) {
      canvas.drawLine(pair.$1, pair.$2, edge);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.connections.toString() != connections.toString();
}
