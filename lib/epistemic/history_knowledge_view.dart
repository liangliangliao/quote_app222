import 'dart:math' as math;
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
import 'concept_meaning_diagram.dart';
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
  final _transform = TransformationController(
    Matrix4.diagonal3Values(.60, .60, 1),
  );
  Map<String, QuoteAnalysisAddon> _addons = {};
  List<QuoteConceptGroup>? _groups;
  String? _selected;
  String _conceptSearch = '';
  int _conceptPage = 0;
  bool _stars = false;
  String? _addonError;
  double _zoom = .60;
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
          (g) => g.title.toLowerCase().contains(
                _conceptSearch.trim().toLowerCase(),
              ),
        )
        .toList();
    final pageCount = math.max(1, (filtered.length + 23) ~/ 24);
    final page = _conceptPage.clamp(0, pageCount - 1).toInt();
    final visible = filtered.skip(page * 24).take(24).toList();
    final selected = visible.where((g) => g.title == _selected).firstOrNull ??
        visible.firstOrNull;
    return ValueListenableBuilder<CognitivePreferences>(
      valueListenable: CognitivePreferenceStore.instance,
      builder: (context, prefs, _) => ColoredBox(
        color: const Color(0xff081f28),
        child: Theme(
          data: ThemeData.dark(useMaterial3: true).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (prefs.relations)
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
                Text('已载入 ${widget.rows.length} 条名言。',
                    style: const TextStyle(fontSize: 12)),
                if (prefs.relations && !_stars)
                  _RecordScopeView(
                      groups: groups.where((g) => g.title != '未分类').toList(),
                      onOpen: widget.onOpen),
                if (_stars) const Text('连线表示同一条收录中的概念共现。'),
                const SizedBox(height: 8),
                if (_addonError != null)
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_addonError!),
                  ),
                TextField(
                  key: const ValueKey('history-concept-search'),
                  decoration: const InputDecoration(
                    labelText: '查找概念',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _conceptSearch = value;
                    _conceptPage = 0;
                    _selected = null;
                  }),
                ),
                if (pageCount > 1)
                  Row(
                    children: [
                      IconButton(
                        tooltip: '上一组概念',
                        onPressed: page == 0
                            ? null
                            : () => setState(() {
                                  _conceptPage = page - 1;
                                  _selected = null;
                                }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '共 ${filtered.length} 个概念 · 第 ${page + 1}/$pageCount 组',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        tooltip: '下一组概念',
                        onPressed: page + 1 >= pageCount
                            ? null
                            : () => setState(() {
                                  _conceptPage = page + 1;
                                  _selected = null;
                                }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无匹配概念。可修改搜索词，或加载更多名言。'),
                  ),
                ExpansionTile(
                  title: const Text('浏览全部概念'),
                  expansionAnimationStyle: cognitiveExpansionStyle(context),
                  initiallyExpanded: true,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      children: [
                        for (final group in visible)
                          ChoiceChip(
                            label: Text('${group.title} ${group.rows.length}'),
                            selected: group.title == selected?.title,
                            onSelected: (_) =>
                                setState(() => _selected = group.title),
                          ),
                      ],
                    ),
                  ],
                ),
                if (prefs.relations && _stars && selected != null) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '聚焦概念 · 放大看名言',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: '缩小关系图',
                        onPressed: () => _scale(.8),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: '放大关系图',
                        onPressed: () => _scale(1.25),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton(
                        tooltip: '重置视图',
                        onPressed: () => setState(() {
                          _transform.value = Matrix4.diagonal3Values(
                            .60,
                            .60,
                            1,
                          );
                          _zoom = .60;
                        }),
                        icon: const Icon(Icons.fit_screen),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 350,
                    child: ClipRect(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: .3,
                        maxScale: 2.5,
                        boundaryMargin: const EdgeInsets.all(200),
                        onInteractionUpdate: (_) {
                          final zoom = _transform.value.getMaxScaleOnAxis();
                          final detailsChanged = (zoom >= 1) != (_zoom >= 1);
                          _zoom = zoom;
                          if (detailsChanged) setState(() {});
                        },
                        child: _graph(visible, selected),
                      ),
                    ),
                  ),
                ] else if (!prefs.relations)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('关系图已关闭，仍可按概念浏览关联名言。'),
                  ),
                const SizedBox(height: 12),
                if (selected != null) ...[
                  Text(
                    '${selected.title} · ${selected.fromExplicitConcepts ? '已保存的概念标注' : '原记录主题'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final row in selected.rows) _quote(row, dark: true),
                ],
                _more,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scale(double factor) => setState(() {
        final target = (_zoom * factor).clamp(.3, 2.5);
        _transform.value = _transform.value.clone()
          ..multiply(
              Matrix4.diagonal3Values(target / _zoom, target / _zoom, 1));
        _zoom = target;
      });
  Offset _position(int i, int length) {
    if (i == 0) return const Offset(300, 260);
    final angle = (i - 1) * 2 * math.pi / math.max(1, length - 1) - math.pi / 2;
    return Offset(300 + math.cos(angle) * 178, 260 + math.sin(angle) * 178);
  }

  Widget _graph(List<QuoteConceptGroup> available, QuoteConceptGroup selected) {
    // Focus one concept and at most six neighbours; all loaded concepts remain
    // reachable through the chips/search above. Do not shrink 24 labels to dots.
    final members = selected.rows.toSet();
    final neighbours = available
        .where((g) => g.title != selected.title)
        .map((g) => (g, g.rows.where(members.contains).length))
        .toList()
      ..sort((a, b) {
        final order = b.$2.compareTo(a.$2);
        return order == 0 ? a.$1.title.compareTo(b.$1.title) : order;
      });
    final groups = [selected, ...neighbours.take(6).map((pair) => pair.$1)];
    double diameter(QuoteConceptGroup g) =>
        100 + 35 * math.sqrt(g.rows.length / widget.rows.length);
    final points = [
      for (var i = 0; i < groups.length; i++) _position(i, groups.length),
    ];
    final connections = <(Offset, Offset)>[];
    for (var i = 0; i < groups.length; i++) {
      final ids = groups[i]
          .rows
          .map((r) => QuoteReference.fromRow(r).contentKey)
          .toSet();
      for (var j = i + 1; j < groups.length; j++) {
        if (groups[j].rows.any(
              (r) => ids.contains(QuoteReference.fromRow(r).contentKey),
            )) {
          connections.add((points[i], points[j]));
        }
      }
    }
    final selectedIndex = groups.indexWhere((g) => g.title == selected.title);
    final center =
        selectedIndex >= 0 ? points[selectedIndex] : const Offset(300, 260);
    return SizedBox(
      width: 600,
      height: 520,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ConstellationPainter(connections)),
          ),
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
                      gradient: RadialGradient(
                        colors: [
                          [
                            const Color(0xffb08b45),
                            const Color(0xff537b8b),
                            const Color(0xff906b78),
                            const Color(0xff4b856b),
                          ][entry.$1 % 4],
                          const Color(0xff132b34),
                        ],
                      ),
                      border: Border.all(
                        color: entry.$2.title == selected.title
                            ? const Color(0xffffe3a1)
                            : Colors.white38,
                        width: entry.$2.title == selected.title ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(30),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Text(
                      '${entry.$2.title}\n(${entry.$2.rows.length})',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: entry.$1 == 0 ? 23 : 21,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
                      child: Text(
                        '${entry.$2['content']}',
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xff302c25),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
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

class _ConstellationPainter extends CustomPainter {
  final List<(Offset, Offset)> connections;
  _ConstellationPainter(this.connections);
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(17);
    final star = Paint()..color = Colors.white.withAlpha(100);
    for (var i = 0; i < 130; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .6 + random.nextDouble() * 1.2,
        star,
      );
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

/// A finite domain makes membership inspectable, including disjoint sets.
/// Never infer a universal philosophical relation from a local collection.
class _RecordScopeView extends StatefulWidget {
  final List<QuoteConceptGroup> groups;
  final ValueChanged<Map<String, dynamic>> onOpen;
  const _RecordScopeView({required this.groups, required this.onOpen});
  @override
  State<_RecordScopeView> createState() => _RecordScopeViewState();
}

class _RecordScopeViewState extends State<_RecordScopeView> {
  String? left, right, region;
  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    if (groups.isEmpty) return const Text('载入的名言还没有主题或概念标注。');
    final a = groups.where((g) => g.title == left).firstOrNull ?? groups.first;
    Widget members(List<Map<String, dynamic>> rows) => Column(children: [
          for (final row in rows.take(3))
            ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(QuoteReference.fromRow(row).content,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpen(row)),
          if (rows.length > 3)
            ExpansionTile(title: Text('其余 ${rows.length - 3} 条收录'), children: [
              for (final row in rows.skip(3))
                ListTile(
                    title: Text(QuoteReference.fromRow(row).content,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => widget.onOpen(row))
            ])
        ]);
    if (groups.length == 1)
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('已载入收录中的单一范围'),
                CircleAvatar(
                    radius: 56,
                    child: Text(a.title, textAlign: TextAlign.center)),
                Text('属于此分类的收录 · ${a.rows.length} 条'),
                members(a.rows)
              ])));
    final aIds = a.rows.toSet();
    final candidates = groups.where((g) => g != a).toList();
    final b = candidates.where((g) => g.title == right).firstOrNull ??
        candidates
            .where((g) => g.rows.any((r) => aIds.contains(r)))
            .firstOrNull ??
        candidates.first;
    final bIds = b.rows.toSet();
    final shared = a.rows.where((r) => bIds.contains(r)).toList();
    final onlyA = a.rows.where((r) => !bIds.contains(r)).toList();
    final onlyB = b.rows.where((r) => !aIds.contains(r)).toList();
    final relation = shared.isEmpty
        ? QuoteRelation.disjoint
        : onlyA.isEmpty && onlyB.isEmpty
            ? QuoteRelation.equal
            : onlyA.isEmpty
                ? QuoteRelation.subset
                : onlyB.isEmpty
                    ? QuoteRelation.superset
                    : QuoteRelation.overlap;
    final regions = {'共同': shared, 'A': onlyA, 'B': onlyB};
    final active = regions[region]?.isNotEmpty == true
        ? region!
        : shared.isNotEmpty
            ? '共同'
            : 'A';
    Widget selector(String label, String value,
            Iterable<QuoteConceptGroup> choices, ValueChanged<String> select) =>
        Expanded(
            child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                items: [
                  for (final choice in choices)
                    DropdownMenuItem(
                        value: choice.title,
                        child: Text('$label  ${choice.title}',
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      select(v);
                      region = null;
                    });
                }));
    return Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
            textTheme: ThemeData.light().textTheme.apply(
                fontFamily:
                    Theme.of(context).textTheme.bodyMedium?.fontFamily)),
        child: Card(
            color: const Color(0xfffcf7eb),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('收录范围',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('按本次载入记录的主题和概念标注归类。点图中的区域可以查阅成员名言。',
                          style: TextStyle(fontSize: 12)),
                      Row(children: [
                        selector('A', a.title, groups, (v) => left = v),
                        const SizedBox(width: 8),
                        selector('B', b.title, candidates, (v) => right = v)
                      ]),
                      ConceptMeaningDiagram(
                          key: ValueKey(
                              [a.title, b.title, relation.name].join('|')),
                          relation: relation,
                          setA: a.title,
                          setB: b.title,
                          universe: '当前已载入的名言收录',
                          onlyA: '仅归入「${a.title}」的 ${onlyA.length} 条收录',
                          onlyB: '仅归入「${b.title}」的 ${onlyB.length} 条收录',
                          intersection: '同时归入两个分类的 ${shared.length} 条收录',
                          onRegion: (v) => setState(() => region = v)),
                      const Divider(),
                      Text('$active 区域的成员 · ${regions[active]!.length} 条'),
                      members(regions[active]!),
                    ]))));
  }
}
