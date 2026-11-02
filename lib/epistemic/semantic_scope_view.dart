import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'concept_meaning_diagram.dart';
import 'semantic_scope.dart';
import 'semantic_scope_service.dart';

String scopeStatus(String value) => switch (value) {
      'text_claim' => '按原句主张',
      'definition' => '依所列定义',
      'interpretation' => 'AI 暂定解释',
      _ => '关系尚待确定'
    };

class SemanticScopePanel extends StatefulWidget {
  final List<ScopeSource> sources;
  final String focus;
  final SemanticScope? initial;
  final SemanticScopeService? service;
  final bool stars;
  const SemanticScopePanel(
      {super.key,
      required this.sources,
      this.focus = '句中概念',
      this.initial,
      this.service,
      this.stars = false});
  @override
  State<SemanticScopePanel> createState() => _SemanticScopePanelState();
}

class _SemanticScopePanelState extends State<SemanticScopePanel> {
  late final service = widget.service ?? SemanticScopeService();
  SemanticScope? result;
  bool busy = false, readingCache = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    result = widget.initial;
    if (result == null) _load();
  }

  @override
  void didUpdateWidget(SemanticScopePanel old) {
    super.didUpdateWidget(old);
    if (widget.initial?.toJson().toString() !=
            old.initial?.toJson().toString() ||
        widget.sources.map((s) => s.toJson()).toString() !=
            old.sources.map((s) => s.toJson()).toString() ||
        widget.focus != old.focus) {
      generation++;
      result = widget.initial;
      busy = false;
      readingCache = false;
      error = null;
      if (result == null) _load();
    }
  }

  Future<void> _load() async {
    final n = ++generation;
    readingCache = true;
    try {
      final v = await service.cached(widget.sources, widget.focus);
      if (mounted && n == generation) setState(() => result = v);
    } catch (_) {
    } finally {
      if (mounted && n == generation) setState(() => readingCache = false);
    }
  }

  Future<void> _analyze() async {
    final n = ++generation;
    setState(() {
      busy = true;
      readingCache = false;
      error = null;
    });
    try {
      final v = await service.analyze(widget.sources, widget.focus,
          force: result != null);
      if (mounted && n == generation) setState(() => result = v);
    } catch (e) {
      if (mounted && n == generation)
        setState(() => error = e is FormatException
            ? e.message
            : e is StateError
                ? e.message
                : '分析暂未完成，请检查文字 AI 设置后重试');
    } finally {
      if (mounted && n == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('semantic-scope-panel'),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xfffcf7eb),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffdeceb0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('概念关系与根据图',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(widget.focus, style: const TextStyle(fontSize: 12)),
        if (result case final v?)
          SemanticScopeView(
              value: v, sources: widget.sources, stars: widget.stars)
        else
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('由 AI 分析所选材料中的概念、判准和关系，再按第九节的五种图式绘制。')),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (busy || readingCache) const LinearProgressIndicator(),
        OutlinedButton.icon(
            onPressed: busy ? null : _analyze,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(busy
                ? '正在分析概念关系…'
                : result == null
                    ? '分析概念关系并绘图'
                    : '重新判断关系并绘图')),
      ]));
}

class SemanticScopeView extends StatefulWidget {
  final SemanticScope value;
  final List<ScopeSource> sources;
  final bool stars;
  const SemanticScopeView(
      {super.key,
      required this.value,
      required this.sources,
      this.stars = false});
  @override
  State<SemanticScopeView> createState() => _SemanticScopeViewState();
}

class _SemanticScopeViewState extends State<SemanticScopeView> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final all = widget.value.relations;
    final i = selected.clamp(0, all.length - 1),
        relation = all[i],
        scope = relation.scope;
    String label(SemanticRelation r) {
      final named = widget.sources.where((s) => s.id == r.placement && s.title.isNotEmpty).firstOrNull;
      final where = r.placement == 'cross'
          ? '跨材料'
          : named != null ? '主题 ${named.title}' : widget.sources.length == 1
              ? '句内概念'
              : '${r.placement} 句内';
      return '$where　${r.scope == null ? '待确定' : '${r.scope!.setA} / ${r.scope!.setB}'}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.value.model.isNotEmpty)
        Text('AI 分析 · ${widget.value.model}',
            style: const TextStyle(fontSize: 12)),
      if (widget.stars)
        _RelationAtlas(
            relations: all,
            selected: i,
            onSelect: (n) => setState(() => selected = n)),
      if (all.length > 1)
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final entry in all.indexed)
            ChoiceChip(
                label: Text(label(entry.$2)),
                selected: i == entry.$1,
                onSelected: (_) => setState(() => selected = entry.$1))
        ]),
      Text(scopeStatus(relation.status), style: const TextStyle(fontSize: 12)),
      if (scope != null) ...[
        ConceptMeaningDiagram(
            key: ValueKey(scope.toJson().toString()),
            relation: scope.relation,
            setA: scope.setA,
            setB: scope.setB,
            universe: scope.universe,
            onlyA: scope.onlyA,
            onlyB: scope.onlyB,
            intersection: scope.intersection,
            otherMember: scope.otherMember,
            parts: scope.parts),
        Text(scope.justification),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('概念判准与原文依据'),
            children: [
              Text(
                  'A　${scope.setA}\n${scope.criterionA}\nB　${scope.setB}\n${scope.criterionB}'),
              for (final p in scope.parts)
                Text('${p.term}　${p.criterion}\n${p.example}'),
              for (final ref in relation.references)
                Text('${ref.source}　「${ref.excerpt}」'),
            ])
      ],
      Text(relation.statement, style: const TextStyle(height: 1.6)),
      if (scope == null)
        for (final ref in relation.references)
          Text('${ref.source}　「${ref.excerpt}」'),
      if (widget.value.grounds.isNotEmpty) ...[
        const Divider(height: 28),
        const Text('根据律视角', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final g in widget.value.grounds) GroundRelationView(g),
      ],
    ]);
  }
}

/// Each mini-map uses its semantic geometry. No link is inferred from counts.
class _RelationAtlas extends StatelessWidget {
  final List<SemanticRelation> relations;
  final int selected;
  final ValueChanged<int> onSelect;
  const _RelationAtlas(
      {required this.relations,
      required this.selected,
      required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final names = <String>{};
    for (final r in relations) {
      if (r.scope case final s?) {
        names.addAll([s.setA, s.setB]);
        if (s.parts.isNotEmpty)
          names.addAll([s.universe, ...s.parts.map((p) => p.term)]);
        if (s.relation.name == 'siblings') names.add(s.universe);
      }
    }
    final nodes = names.toList();
    final positions = <String, Offset>{
      for (final n in nodes.indexed)
        n.$2: Offset(
            325 +
                245 * math.cos(2 * math.pi * n.$1 / math.max(1, nodes.length)),
            325 +
                245 * math.sin(2 * math.pi * n.$1 / math.max(1, nodes.length)))
    };
    return Column(children: [
      const Text('概念星图 · 连线按语义分析标注关系图式',
          style: TextStyle(fontWeight: FontWeight.bold)),
      if (nodes.isNotEmpty)
        SizedBox(
            height: 300,
            child: ClipRect(
                child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: FittedBox(
                        child: GestureDetector(
                            onTapUp: (tap) {
                              var best = 50.0;
                              int? found;
                              for (final r in relations.indexed) {
                                final s = r.$2.scope;
                                if (s == null) continue;
                                final midpoint =
                                    (positions[s.setA]! + positions[s.setB]!) /
                                        2;
                                final d =
                                    (midpoint - tap.localPosition).distance;
                                if (d < best) {
                                  best = d;
                                  found = r.$1;
                                }
                              }
                              if (found != null) onSelect(found);
                            },
                            child: CustomPaint(
                                size: const Size(650, 650),
                                painter: _SemanticNetwork(
                                    relations,
                                    positions,
                                    Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.fontFamily))))))),
      const Text('① 重合　② 包含　③ 穷尽划分　④ 相交　⑤ 同属上位范围',
          style: TextStyle(fontSize: 12)),
    ]);
  }
}

class _SemanticNetwork extends CustomPainter {
  final List<SemanticRelation> relations;
  final Map<String, Offset> positions;
  final String? font;
  const _SemanticNetwork(this.relations, this.positions, this.font);
  void label(Canvas c, String text, Offset at, double width, double size) {
    final t = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: const Color(0xff313b3e),
                fontFamily: font,
                fontSize: size)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 3,
        ellipsis: '…')
      ..layout(maxWidth: width);
    c.drawRect(
        Rect.fromCenter(center: at, width: t.width + 6, height: t.height + 4),
        Paint()..color = const Color(0xfffcf7eb));
    t.paint(c, at - Offset(t.width / 2, t.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    for (final entry in relations.indexed) {
      final s = entry.$2.scope;
      if (s == null) continue;
      final a = positions[s.setA]!, b = positions[s.setB]!;
      if (s.parts.isNotEmpty || s.relation.name == 'siblings') {
        final parent = positions[s.universe]!;
        for (final term in s.parts.isNotEmpty
            ? s.parts.map((p) => p.term)
            : [s.setA, s.setB]) {
          c.drawLine(
              parent,
              positions[term]!,
              Paint()
                ..color = const Color(0xffb0a68d)
                ..strokeWidth = 2);
          label(c, '②', (parent + positions[term]!) / 2, 38, 16);
        }
      }
      c.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0xff8b8474)
            ..strokeWidth = 2);
      label(
          c,
          '${entry.$1 + 1} · ${scopePattern(s.relation.name).substring(0, 1)}',
          (a + b) / 2,
          90,
          18);
    }
    for (final node in positions.entries) {
      c.drawCircle(node.value, 53, Paint()..color = const Color(0xffece3d3));
      c.drawCircle(
          node.value,
          53,
          Paint()
            ..color = const Color(0xffa78b54)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      label(c, node.key, node.value, 92, 20);
    }
  }

  @override
  bool shouldRepaint(_SemanticNetwork old) =>
      old.relations != relations ||
      old.positions.toString() != positions.toString() ||
      old.font != font;
}

String scopePattern(String name) => switch (name) {
      'equal' => '① 外延重合',
      'subset' || 'superset' => '② 完全包含',
      'partition' => '③ 互斥且穷尽上位范围',
      'overlap' => '④ 部分相交',
      'siblings' => '⑤ 同属上位范围且未穷尽',
      _ => '尚待确定'
    };

class GroundRelationView extends StatelessWidget {
  final GroundDiagram graph;
  const GroundRelationView(this.graph, {super.key});
  @override
  Widget build(BuildContext context) {
    final title = switch (graph.kind) {
      'evidence' => '认识根据 → 判断',
      'cause' => '生成根据 · 因果条件',
      'time' => '时间 · 先后关系',
      'space' => '空间 · 相对位置',
      _ => '动机 → 行动'
    };
    return Card(
        elevation: 0,
        color: const Color(0xfff0f3f4),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(scopeStatus(graph.status),
                      style: const TextStyle(fontSize: 12)),
                  if (graph.kind == 'space')
                    _space()
                  else
                    Column(children: [
                      _node(graph.from),
                      SizedBox(
                          height: 42,
                          child: CustomPaint(
                              painter: _GroundArrow(
                                  dashed: graph.kind == 'cause' ||
                                      graph.status == 'unknown'),
                              child: const SizedBox(width: 50))),
                      _node(graph.to),
                    ]),
                  Text(graph.link, style: const TextStyle(height: 1.5)),
                  for (final r in graph.references)
                    Text('${r.source}　「${r.excerpt}」',
                        style: const TextStyle(fontSize: 12)),
                ])));
  }

  Widget _space() {
    if (graph.position == 'inside')
      return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xff9aa9ae)),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(graph.to),
            const SizedBox(height: 12),
            _node(graph.from)
          ]));
    final reversed = ['right', 'below'].contains(graph.position);
    final items = <Widget>[
      _node(reversed ? graph.to : graph.from),
      const SizedBox(width: 24, height: 24),
      _node(reversed ? graph.from : graph.to)
    ];
    final vertical = ['above', 'below', 'unspecified'].contains(graph.position);
    return CustomPaint(
        painter: const _SpaceGrid(),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: vertical
                ? Column(children: items)
                : Row(children: [
                    Expanded(child: items[0]),
                    items[1],
                    Expanded(child: items[2])
                  ])));
  }

  Widget _node(String s) => Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xff9aa9ae)),
          borderRadius: BorderRadius.circular(10)),
      child: Text(s, textAlign: TextAlign.center));
}

class _GroundArrow extends CustomPainter {
  final bool dashed;
  const _GroundArrow({this.dashed = false});
  @override
  void paint(Canvas c, Size s) {
    final pen = Paint()
      ..color = const Color(0xff687b81)
      ..strokeWidth = 2;
    if (dashed) {
      for (double y = 3; y < s.height - 8; y += 9)
        c.drawLine(Offset(s.width / 2, y), Offset(s.width / 2, y + 5), pen);
    } else
      c.drawLine(
          Offset(s.width / 2, 3), Offset(s.width / 2, s.height - 6), pen);
    c.drawLine(Offset(s.width / 2, s.height - 6),
        Offset(s.width / 2 - 5, s.height - 13), pen);
    c.drawLine(Offset(s.width / 2, s.height - 6),
        Offset(s.width / 2 + 5, s.height - 13), pen);
  }

  @override
  bool shouldRepaint(_GroundArrow old) => old.dashed != dashed;
}

class _SpaceGrid extends CustomPainter {
  const _SpaceGrid();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xffc6d1d4)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 24)
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    for (double y = 0; y < s.height; y += 24)
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }

  @override
  bool shouldRepaint(_SpaceGrid old) => false;
}
