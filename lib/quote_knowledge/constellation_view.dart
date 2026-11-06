import 'history_meaning_view.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import '../services/quote_insight_settings.dart';
import '../widgets/quote_portrait.dart';
import 'management_sheet.dart';
import 'models.dart';
import 'repository.dart';
import 'schema.dart';

const knowledgeNight = Color(0xff081c26);
const _starColors = [
  Color(0xff73b9cf),
  Color(0xffb67c79),
  Color(0xff7bb398),
  Color(0xff82acbb),
  Color(0xffb5bfa1),
  Color(0xff6e9ab1)
];

class QuoteKnowledgeConstellation extends StatefulWidget {
  final QuoteKnowledgeRepository? repository;
  final String query;
  final Set<String> selectedKeys;
  final ValueChanged<Map<String, dynamic>> onOpen, onSelect;
  final VoidCallback? onCompare;
  const QuoteKnowledgeConstellation(
      {super.key,
      this.repository,
      this.query = '',
      required this.selectedKeys,
      required this.onOpen,
      required this.onSelect,
      this.onCompare});
  @override
  State<QuoteKnowledgeConstellation> createState() =>
      _QuoteKnowledgeConstellationState();
}

class _QuoteKnowledgeConstellationState
    extends State<QuoteKnowledgeConstellation> {
  late final _repository = widget.repository ?? QuoteKnowledgeRepository();
  QuoteKnowledgeGraph? _graph;
  List<Map<String, dynamic>> _quotes = [];
  String? _selected, _focus, _error;
  bool _meaning = true;
  bool _tree = false, _more = false, _loadingMore = false;
  int _generation = 0, _quoteGeneration = 0;
  StreamSubscription<void>? _changes;
  Timer? _refresh;
  final _camera = TransformationController();
  @override
  void initState() {
    super.initState();
    _load();
    _changes = QuoteKnowledgeEvents.changes.listen((_) {
      _refresh?.cancel();
      _refresh = Timer(const Duration(milliseconds: 180), _load);
    });
  }

  @override
  void didUpdateWidget(QuoteKnowledgeConstellation old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _load();
  }

  @override
  void dispose() {
    _generation++;
    _quoteGeneration++;
    _changes?.cancel();
    _refresh?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final n = ++_generation;
    try {
      await _repository.bootstrapLegacy();
      final g = await _repository.snapshot(query: widget.query);
      if (!mounted || n != _generation) return;
      final active = g.categories.where((c) => c.quoteCount > 0).toList();
      setState(() {
        _graph = g;
        _error = null;
        if (_selected!=null && !active.any((c) => c.id == _selected))
          _selected = null;
        if (g.category(_focus ?? '') == null) _focus = null;
      });
      await _loadQuotes();
    } catch (_) {
      if (mounted && n == _generation) setState(() => _error = '关系图暂未读取，请重试。');
    }
  }

  Future<void> _loadQuotes({bool more = false}) async {
    final n = ++_quoteGeneration;
    final rows = await _repository.quotesForCategory(_selected,
        query: widget.query, offset: more ? _quotes.length : 0, limit: 20);
    if (mounted && n == _quoteGeneration)
      setState(() {
        _quotes = more ? [..._quotes, ...rows] : rows;
        _more = rows.length == 20;
        _loadingMore = false;
      });
  }

  void _select(String? id, {bool drill = false}) {
    setState(() {
      _selected = id;
      if (drill) {
        _focus = id;
        _camera.value = Matrix4.identity();
      }
    });
    unawaited(_loadQuotes().catchError((_) {
      if (mounted) setState(() => _error = '关联名言暂未读取，请重试。');
    }));
  }

  void _allCategories() {
    var search = '';
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => DraggableScrollableSheet(
                expand: false,
                initialChildSize: .7,
                builder: (context, scroll) =>
                    ListView(controller: scroll, children: [
                      const ListTile(
                          title: Text('全部主题类别'),
                          subtitle: Text('数字为全库收录数，包含下位类别并去重')),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                              key: const ValueKey('history-concept-search'),
                              decoration: const InputDecoration(
                                  labelText: '查找概念',
                                  prefixIcon: Icon(Icons.search)),
                              onChanged: (value) =>
                                  update(() => search = value))),
                      if (!_graph!.categories.any((c) =>
                          c.quoteCount > 0 &&
                          '${c.name} ${c.definition}'.contains(search)))
                        const ListTile(title: Text('暂无匹配概念。')),
                      for (final c in _graph!.categories.where((c) =>
                          c.quoteCount > 0 &&
                          '${c.name} ${c.definition}'.contains(search)))
                        ListTile(
                            title: Text(c.name),
                            subtitle: Text(c.definition),
                            trailing: Text('${c.quoteCount}'),
                            onTap: () {
                              Navigator.pop(context);
                              _select(c.id);
                            }),
                    ]))));
  }

  Widget _treeNode(QuoteCategory c, Set<String> visited) {
    if (!visited.add(c.id)) return const SizedBox.shrink();
    final children =
        _graph!.children(c.id).where((c) => c.quoteCount > 0).toList();
    if (children.isEmpty)
      return ListTile(
          textColor: Colors.white70,
          title: Text(c.name),
          trailing: Text('${c.quoteCount}'),
          onTap: () => _select(c.id));
    return ExpansionTile(
        textColor: Colors.white,
        collapsedTextColor: Colors.white70,
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white70,
        title: Text('${c.name}  ${c.quoteCount}'),
        children: [
          TextButton(
              onPressed: () => _select(c.id), child: const Text('查看此类全部名言')),
          for (final child in children)
            Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _treeNode(child, {...visited})),
        ]);
  }

  Future<void> _showEdges() async {
    final g = _graph!;
    final edges =
        g.edges.where((e) => e.from == _selected || e.to == _selected).toList();
    await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) =>
            ListView(padding: const EdgeInsets.all(16), children: [
              const Text('概念关系与依据',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const Text('收录数量与共同收录表示名言索引；主题层级表示分类范围。概念的外延关系需结合具体材料另行分析。'),
              if (edges.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16), child: Text('此类别还没有保存的概念关系。')),
              for (final e in edges)
                ListTile(
                    title: Text(
                        '${g.category(e.from)?.name ?? ''} → ${g.category(e.to)?.name ?? ''}'),
                    subtitle: Text('${e.label} · ${e.explanation}'),
                    onTap: () async {
                      final rows =
                          await _repository.relationEvidence(e.from, e.to);
                      if (!context.mounted) return;
                      showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: Text(e.label),
                                  content: SingleChildScrollView(
                                      child: Text(rows.isEmpty
                                          ? e.explanation
                                          : rows
                                              .map((r) =>
                                                  '“${r['excerpt']}”\n${r['reason']}')
                                              .join('\n\n'))),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('关闭'))
                                  ]));
                    }),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final g = _graph;
    return LayoutBuilder(builder: (context, viewport) {
      return ColoredBox(
          color: knowledgeNight,
          child: Theme(
              data: Theme.of(context).copyWith(
                  brightness: Brightness.dark,
                  colorScheme: ColorScheme.fromSeed(
                      seedColor: const Color(0xffc5b984),
                      brightness: Brightness.dark),
                  iconTheme: const IconThemeData(color: Colors.white70),
                  textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: const Color(0xffe3e9e8),
                      displayColor: Colors.white)),
              child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Color(0xffe3e9e8)),
                  child: IconTheme.merge(
                      data: const IconThemeData(color: Colors.white70),
                      child: g == null
                          ? Center(
                              child: TextButton(
                                  onPressed: _load,
                                  child: Text(_error ?? '正在读取已保存的概念关系…')))
                          : ListView(
                              key: const ValueKey(
                                  'history-constellation-scroll'),
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                              children: [
                                  SizedBox(
                                      height: MediaQuery.textScalerOf(context)
                                                  .scale(12) >
                                              18
                                          ? 60
                                          : 42,
                                      child: Row(children: [
                                        Expanded(
                                            child: ListView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                children: [
                                              _filter('全部', _selected == null,
                                                  () => _select(null)),
                                              for (final c in g.roots.where(
                                                  (c) => c.quoteCount > 0))
                                                _filter(
                                                    c.name,
                                                    _selected == c.id,
                                                    () => _select(c.id)),
                                            ])),
                                        IconButton(
                                            onPressed: _allCategories,
                                            tooltip: '全部类别',
                                            icon: const Icon(Icons.more_horiz,
                                                color: Colors.white70))
                                      ])),
                                  Wrap(spacing:8,children:[
                                    ChoiceChip(label:const Text('含义圈'),selected:_meaning,onSelected:(_)=>setState(()=>_meaning=true)),
                                    ChoiceChip(label:const Text('分类索引'),selected:!_meaning,onSelected:(_)=>setState(()=>_meaning=false)),
                                  ]),
                                  if(_meaning)HistoryMeaningView(repository:_repository,quotes:_quotes,
                                    category:_selected,categoryLabel:g.category(_selected??'')?.name??'全部名言',query:widget.query)
                                  else ...[
                                  Row(children: [
                                    Expanded(
                                        child: Text(
                                            _focus == null
                                                ? '主题索引 · 归类导航'
                                                : '${g.category(_focus!)?.name ?? ''} · 下位主题',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white60))),
                                    if (_focus != null)
                                      IconButton(
                                          tooltip: '返回上位主题',
                                          onPressed: () => setState(() =>
                                              _focus = g
                                                          .category(_focus!)
                                                          ?.parentId
                                                          .isEmpty ==
                                                      true
                                                  ? null
                                                  : g
                                                      .category(_focus!)
                                                      ?.parentId),
                                          icon: const Icon(Icons.arrow_upward,
                                              size: 18)),
                                    IconButton(
                                        tooltip: _tree ? '切换星图' : '查看分类树',
                                        onPressed: () =>
                                            setState(() => _tree = !_tree),
                                        icon: Icon(
                                            _tree
                                                ? Icons.bubble_chart_outlined
                                                : Icons.account_tree_outlined,
                                            size: 19)),
                                    IconButton(
                                        tooltip: '归类依据',
                                        onPressed: _showEdges,
                                        icon: const Icon(Icons.info_outline,
                                            size: 19)),
                                    IconButton(
                                        tooltip: '分类管理',
                                        onPressed: () =>
                                            showQuoteKnowledgeManagement(
                                                context, _repository),
                                        icon: const Icon(Icons.tune, size: 19)),
                                  ]),
                                  if (_error != null)
                                    TextButton(
                                        onPressed: _load, child: Text(_error!)),
                                  if (_tree) ...[
                                    for (final c in g.roots
                                        .where((c) => c.quoteCount > 0))
                                      _treeNode(c, {}),
                                  ] else
                                    _canvas(g),
                                  if (g.categories
                                      .every((c) => c.quoteCount == 0))
                                    Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(children: [
                                          const Text(
                                              '保存名言后，这里会长出你的概念星图。已有记录可一键分批整理。',
                                              textAlign: TextAlign.center),
                                          TextButton(
                                              onPressed: () =>
                                                  showQuoteKnowledgeManagement(
                                                      context, _repository),
                                              child: const Text('整理名言分类')),
                                        ])),
                                  ],
                                  Row(children: [
                                    Expanded(
                                        child: Text(
                                            '${g.category(_selected ?? '')?.name ?? '全部'} · 相关名言',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600))),
                                    if (_quotes.isNotEmpty)
                                      TextButton(
                                          onPressed: () =>
                                              showQuoteKnowledgeManagement(
                                                  context, _repository,
                                                  quote: _quotes.first),
                                          child: const Text('调整分类',
                                              style: TextStyle(fontSize: 11)))
                                  ]),
                                  if (_quotes.isEmpty) const Text('此主题尚无匹配名言。'),
                                  if (_quotes.isNotEmpty)
                                    SizedBox(
                                        height: MediaQuery.textScalerOf(context)
                                                    .scale(13) >
                                                19
                                            ? 175
                                            : 126,
                                        child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _quotes.length +
                                                (_more ? 1 : 0),
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 8),
                                            itemBuilder: (context, i) {
                                              if (i == _quotes.length)
                                                return TextButton(
                                                    onPressed: _loadingMore
                                                        ? null
                                                        : () {
                                                            setState(() =>
                                                                _loadingMore =
                                                                    true);
                                                            unawaited(
                                                                _loadQuotes(
                                                                    more:
                                                                        true));
                                                          },
                                                    child: const Text('更多名言'));
                                              final row = _quotes[i],
                                                  ref = QuoteReference.fromRow(
                                                      row),
                                                  selected = widget.selectedKeys
                                                      .contains(ref.contentKey);
                                              return SizedBox(
                                                  width: MediaQuery.textScalerOf(context).scale(13) > 19
                                                      ? 244
                                                      : (viewport.maxWidth - 32) /
                                                          2,
                                                  child: Card(
                                                      margin: EdgeInsets.zero,
                                                      color: const Color(
                                                          0xfff8f3e8),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  12),
                                                          side: BorderSide(
                                                              color: selected
                                                                  ? const Color(
                                                                      0xffcbb277)
                                                                  : Colors
                                                                      .transparent,
                                                              width: 2)),
                                                      child: InkWell(
                                                          onTap: () => widget
                                                              .onOpen(row),
                                                          onLongPress: () =>
                                                              showQuoteKnowledgeManagement(
                                                                  context, _repository,
                                                                  quote: row),
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Padding(
                                                              padding: const EdgeInsets.all(10),
                                                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                                QuotePortrait(
                                                                    quote: ref,
                                                                    diameter:
                                                                        34),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Expanded(
                                                                    child: Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                      Expanded(
                                                                          child: Text(
                                                                              ref.content,
                                                                              maxLines: 3,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              style: const TextStyle(color: Color(0xff343a37), fontSize: 12, height: 1.4))),
                                                                      Text(
                                                                          ref.author.isEmpty
                                                                              ? '作者待考'
                                                                              : '— ${ref.author}',
                                                                          maxLines:
                                                                              1,
                                                                          overflow: TextOverflow
                                                                              .ellipsis,
                                                                          style: const TextStyle(
                                                                              color: Color(0xff756e60),
                                                                              fontSize: 10)),
                                                                    ])),
                                                                if (QuoteInsightSettings
                                                                    .comparisonEnabled)
                                                                  SizedBox(
                                                                      width: 24,
                                                                      child: IconButton(
                                                                          padding: EdgeInsets
                                                                              .zero,
                                                                          tooltip: selected
                                                                              ? '取消比较选择'
                                                                              : '加入比较',
                                                                          onPressed: () => widget.onSelect(
                                                                              row),
                                                                          icon: Icon(
                                                                              selected ? Icons.check_circle : Icons.add_circle_outline,
                                                                              size: 20,
                                                                              color: const Color(0xff8a794f)))),
                                                              ])))));
                                            })),
                                  const SizedBox(height: 12),
                                  Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        Text('全库 ${g.quoteCount} 条 · 数字为分类收录数',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 10)),
                                        if (QuoteInsightSettings
                                            .comparisonEnabled)
                                          OutlinedButton.icon(
                                              key: const ValueKey(
                                                  'constellation-compare'),
                                              onPressed:
                                                  widget.selectedKeys
                                                              .length ==
                                                          2
                                                      ? widget.onCompare
                                                      : null,
                                              style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      const Color(0xffe4d6af),
                                                  disabledForegroundColor:
                                                      const Color(0xff829693),
                                                  side: const BorderSide(
                                                      color:
                                                          Color(0xff6e8183))),
                                              icon: const Icon(
                                                  Icons.compare_arrows,
                                                  size: 17),
                                              label: Text(
                                                  '加入比较 ${widget.selectedKeys.length}/2')),
                                      ]),
                                  if (g.pending +
                                          g.needsReview +
                                          g.legacyRemaining >
                                      0)
                                    TextButton(
                                        onPressed: () =>
                                            showQuoteKnowledgeManagement(
                                                context, _repository),
                                        child: Text(
                                            '整理进度 · ${g.pending} 条处理中 · ${g.needsReview} 条待复核 · ${g.legacyRemaining} 条旧记录待整理',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white54))),
                                ])))));
    });
  }

  Widget _filter(String label, bool selected, VoidCallback tap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  color: selected ? const Color(0xfff4e9c9) : Colors.white70,
                  fontSize: 12)),
          selected: selected,
          onSelected: (_) => tap(),
          showCheckmark: false,
          selectedColor: const Color(0xff3c4a49),
          backgroundColor: const Color(0xff142b35),
          side: BorderSide(
              color:
                  selected ? const Color(0xff9b936e) : const Color(0xff2c4049)),
          padding: const EdgeInsets.symmetric(horizontal: 6)));
  Widget _canvas(QuoteKnowledgeGraph g) =>
      LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth, height = (width * 1.12).clamp(340.0, 460.0);
        final large = MediaQuery.textScalerOf(context).scale(14) > 21;
        final selected = g.category(_selected ?? '');
        var active = (_focus == null ? g.categories : g.children(_focus!))
            .where((c) => c.quoteCount > 0 && c.id != selected?.id)
            .toList();
        active = active.take(large ? 5 : 12).toList();
        final visible = [if (selected != null) selected, ...active];
        final positions = <String, Offset>{};
        final sizes = <String, double>{};
        for (final c in visible.indexed) {
          if (c.$1 == 0 && selected != null) {
            positions[c.$2.id] = Offset(width * .49, height * .46);
            sizes[c.$2.id] = large ? 116 : 106;
            continue;
          }
          final i = c.$1 - (selected == null ? 0 : 1),
              inner = i < 6,
              angle = (-105 + i * 60) * math.pi / 180;
          final radiusX = width * (inner ? .33 : .43),
              radiusY = height * (inner ? .31 : .44);
          positions[c.$2.id] = Offset(width * .49 + math.cos(angle) * radiusX,
              height * .46 + math.sin(angle) * radiusY);
          sizes[c.$2.id] = large
              ? 82
              : inner
                  ? (68 + math.min(18, c.$2.quoteCount * .8))
                  : 38;
        }
        return SizedBox(
            height: height,
            child: ClipRect(
                child: InteractiveViewer(
                    transformationController: _camera,
                    minScale: .65,
                    maxScale: 3,
                    boundaryMargin: const EdgeInsets.all(140),
                    child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(children: [
                          Positioned.fill(
                              child: CustomPaint(
                                  painter: _ConstellationPainter(
                                      positions, g.edges.where((e) => e.kind == 'subtopic').toList(), _selected))),
                          for (final c in visible)
                            Positioned(
                                left: positions[c.id]!.dx - sizes[c.id]! / 2,
                                top: positions[c.id]!.dy - sizes[c.id]! / 2,
                                child: _bubble(
                                    c, sizes[c.id]!, c.id == _selected)),
                          const Positioned(
                              left: 0,
                              right: 0,
                              bottom: 3,
                              child: Text('双指缩放 · 双击主题展开下位类别；连线仅表示分类归属',
                                  maxLines: 2,
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.white38))),
                        ])))));
      });
  Widget _bubble(QuoteCategory c, double size, bool selected) {
    final color = selected
        ? const Color(0xffe1bc65)
        : switch (c.name) {
            '痛苦' => const Color(0xffbd827b),
            '成长' => const Color(0xff83b38a),
            '自由' => const Color(0xff83bec7),
            '自然' => const Color(0xff9abbaa),
            '责任' => const Color(0xff7da4bb),
            '意义' => const Color(0xffa7b995),
            _ => _starColors[
                c.id.codeUnits.fold(0, (a, b) => a + b) % _starColors.length],
          };
    final tiny = size < 55;
    return Semantics(
        label: '${c.name}，${c.quoteCount}条名言。双击展开下位类别。',
        button: true,
        child: Tooltip(
            message: '${c.name} · ${c.definition}',
            child: GestureDetector(
                onTap: () => _select(c.id),
                onDoubleTap: () => _select(c.id, drill: true),
                child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                            center: const Alignment(-.35, -.5),
                            radius: 1,
                            colors: [
                              Color.lerp(color, Colors.white, .2)!,
                              color.withValues(alpha: .44),
                              const Color(0xff122c37)
                            ]),
                        border: Border.all(
                            color: color.withValues(alpha: .7),
                            width: selected ? 1.8 : .8),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  color.withValues(alpha: selected ? .35 : .16),
                              blurRadius: selected ? 26 : 13,
                              spreadRadius: selected ? 3 : 1),
                          BoxShadow(
                              color: color.withValues(alpha: .22),
                              blurRadius: 3,
                              spreadRadius: 1)
                        ]),
                    child: Padding(
                        padding: const EdgeInsets.all(6),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                              child: Text(c.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: tiny
                                          ? 8
                                          : selected
                                              ? 18
                                              : 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      shadows: const [
                                        Shadow(
                                            blurRadius: 4,
                                            color: Colors.black87)
                                      ]))),
                          Text('(${c.quoteCount})',
                              style: TextStyle(
                                  fontSize: tiny ? 8 : 12,
                                  color: Colors.white70))
                        ]))))));
  }
}

class _ConstellationPainter extends CustomPainter {
  final Map<String, Offset> positions;
  final List<QuoteKnowledgeEdge> edges;
  final String? selected;
  _ConstellationPainter(this.positions, this.edges, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(2718);
    for (var i = 0; i < 115; i++) {
      final p = Offset(
          random.nextDouble() * size.width, random.nextDouble() * size.height);
      canvas.drawCircle(
          p,
          random.nextDouble() * 1.3 + .3,
          Paint()
            ..color = const Color(0xff9ec5ce)
                .withValues(alpha: random.nextDouble() * .4 + .06));
    }
    for (final e in edges) {
      final a = positions[e.from], b = positions[e.to];
      if (a == null || b == null) continue;
      final active = e.from == selected || e.to == selected;
      final paint = Paint()
        ..color = (active ? const Color(0xffd5be7f) : const Color(0xff6f9aa5))
            .withValues(alpha: active ? .45 : .18)
        ..strokeWidth = e.kind == 'subtopic' ? 1.2 : .7;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
            (a.dx + b.dx) / 2 + 12, (a.dy + b.dy) / 2 - 18, b.dx, b.dy);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
      if (e.kind == 'condition' ||
          e.kind == 'cause_claim' ||
          e.kind == 'subtopic') {
        final p = Offset.lerp(a, b, .68)!, d = (b - a) / ((b - a).distance);
        canvas.drawLine(p, p - d * 6 + Offset(-d.dy, d.dx) * 3, paint);
        canvas.drawLine(p, p - d * 6 - Offset(-d.dy, d.dx) * 3, paint);
      }
    }
    for (var i = 0; i < 14; i++) {
      final p = Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height),
          r = random.nextDouble() * 5 + 2;
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xffc8d5b0).withValues(alpha: .6),
              const Color(0xff4b8d9e).withValues(alpha: .1)
            ]).createShader(Rect.fromCircle(center: p, radius: r)));
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => true;
}
