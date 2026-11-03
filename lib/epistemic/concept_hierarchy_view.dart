import 'grounding_path_view.dart';
import 'concept_connections.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'semantic_scope.dart';
import 'cognitive_mode.dart';

/// Shared zoom surface for the tree and the meaning-circle canvas.
class ConceptCanvas extends StatefulWidget {
  final Size size;
  final Widget child;
  final String title;
  const ConceptCanvas(
      {super.key,
      required this.size,
      required this.child,
      required this.title});
  @override
  State<ConceptCanvas> createState() => _ConceptCanvasState();
}

class _ConceptCanvasState extends State<ConceptCanvas> {
  final controller = TransformationController();
  Size viewport = Size.zero;
  bool fitted = false;
  void fit() {
    if (viewport.isEmpty) return;
    final scale = math
        .min(viewport.width / widget.size.width,
            viewport.height / widget.size.height)
        .clamp(.08, 1.0);
    controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw((viewport.width - widget.size.width * scale) / 2,
          (viewport.height - widget.size.height * scale) / 2, 0);
  }

  @override
  void didUpdateWidget(ConceptCanvas old) {
    super.didUpdateWidget(old);
    if (old.size != widget.size || old.child.key != widget.child.key)
      fitted = false;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(
              child: Text(widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(
              tooltip: '适合画布',
              onPressed: fit,
              icon: const Icon(Icons.center_focus_strong)),
          IconButton(
              tooltip: '全屏查看',
              icon: const Icon(Icons.fullscreen),
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog.fullscreen(
                      child: Scaffold(
                          backgroundColor: const Color(0xfffaf6ee),
                          appBar: AppBar(title: Text(widget.title)),
                          body: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                      child: SizedBox(
                                          width: constraints.maxWidth,
                                          child: _FullscreenCanvas(
                                              size: widget.size,
                                              child: widget.child,
                                              height:
                                                  constraints.maxHeight))))))))
        ]),
        SizedBox(
            height: 350,
            child: LayoutBuilder(builder: (context, box) {
              viewport = Size(box.maxWidth, 350);
              if (!fitted) {
                fitted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) fit();
                });
              }
              return ClipRect(
                  child: ColoredBox(
                      color: const Color(0xfffffcf6),
                      child: InteractiveViewer(
                          transformationController: controller,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(500),
                          minScale: .08,
                          maxScale: 5,
                          child: SizedBox(
                              width: widget.size.width,
                              height: widget.size.height,
                              child: widget.child))));
            })),
        const Text('双指缩放、拖动平移；点选节点查看含义与原文依据。',
            style: TextStyle(fontSize: 12, color: Color(0xff70675b))),
      ]);
}

class _FullscreenCanvas extends StatefulWidget {
  final Size size;
  final Widget child;
  final double height;
  const _FullscreenCanvas(
      {required this.size, required this.child, required this.height});
  @override
  State<_FullscreenCanvas> createState() => _FullscreenCanvasState();
}

class _FullscreenCanvasState extends State<_FullscreenCanvas> {
  final controller = TransformationController();
  bool fitted = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        if (!fitted) {
          fitted = true;
          final scale = math
              .min(box.maxWidth / widget.size.width,
                  box.maxHeight / widget.size.height)
              .clamp(.08, 1.0);
          controller.value = Matrix4.diagonal3Values(scale, scale, 1)
            ..setTranslationRaw((box.maxWidth - widget.size.width * scale) / 2,
                (box.maxHeight - widget.size.height * scale) / 2, 0);
        }
        return InteractiveViewer(
            constrained: false,
            transformationController: controller,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: .08,
            maxScale: 5,
            child: SizedBox(
                width: widget.size.width,
                height: widget.size.height,
                child: widget.child));
      }));
}

class ConceptDetails extends StatelessWidget {
  final SemanticConcept node;
  final List<ConceptHierarchyEdge> hierarchy;
  final List<SemanticConcept> concepts;
  final List<ConceptConnection> connections;
  final ValueChanged<String>? onSelect, onExpand;
  final VoidCallback? onOpen;
  final String? imagePath;
  const ConceptDetails(
      {super.key,
      required this.node,
      this.hierarchy = const [],
      this.concepts = const [],
      this.connections = const [],
      this.onSelect,
      this.onExpand,
      this.onOpen,
      this.imagePath});
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xfffffbf2),
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(node.label,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            Text(
                ['experience', 'formal'].contains(node.kind)
                    ? node.kind == 'formal'
                        ? '形式构造 · 定义下的直观'
                        : node.status == 'example'
                            ? '具体经验 · 模拟示例'
                            : '具体经验 · 原文材料'
                    : node.status == 'text_claim'
                        ? '按原句主张'
                        : node.status == 'definition'
                            ? '依所列定义'
                            : '概念 · 一种理解',
                style: const TextStyle(fontSize: 12, color: Color(0xff8c6b38))),
            const SizedBox(height: 8),
            Text(node.definition, style: const TextStyle(height: 1.6)),
            if (imagePath != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Image.file(File(imagePath!),
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            for (final field in [
              ('具体材料', node.observed),
              ('保留的共同规定', node.retained),
              ('抽象时省略', node.omitted),
              ('反例与边界', node.counterExample)
            ])
              if (field.$2.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${field.$1}：${field.$2}',
                        style: const TextStyle(height: 1.6))),
            for (final edge in hierarchy.where((e) => e.child == node.id)) ...[
              Text(edge.explanation, style: const TextStyle(height: 1.5)),
              if (onSelect != null)
                TextButton.icon(
                    onPressed: () => onSelect!(edge.parent),
                    icon: const Icon(Icons.arrow_upward),
                    label: Text(
                        '${edge.kind == 'subtype' ? '返回上位概念' : conceptConnectionLabel(edge.kind)}：${concepts.where((n) => n.id == edge.parent).firstOrNull?.label ?? ''}')),
            ],
            for (final edge in connections.where((e) =>
                (e.from == node.id || e.to == node.id) &&
                !const {'subtype', 'mediation', 'grounding', 'instance'}
                    .contains(e.kind)))
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${edge.label}${edge.symmetric ? ' ↔ ' : edge.from == node.id ? ' → ' : ' ← '}'
                      '${concepts.where((c) => c.id == (edge.from == node.id ? edge.to : edge.from)).firstOrNull?.label ?? ''}'),
                  subtitle: Text('${edge.explanation}\n'
                      '${edge.references.map((r) => '${r.source}「${r.excerpt}」').join('\n')}'),
                  onTap: onSelect == null
                      ? null
                      : () => onSelect!(
                          edge.from == node.id ? edge.to : edge.from)),
            ExpansionTile(
                expansionAnimationStyle: cognitiveExpansionStyle(context),
                tilePadding: EdgeInsets.zero,
                title: const Text('原文依据与对应'),
                children: [
                  for (final r in node.references)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${r.source}　「${r.excerpt}」',
                            style: const TextStyle(height: 1.6))),
                  const Text('模拟示例用于帮助理解，配画是视觉类比，均不替代原文或证明。',
                      style: TextStyle(fontSize: 12)),
                ]),
            Wrap(spacing: 8, children: [
              if (onOpen != null)
                TextButton(onPressed: onOpen, child: const Text('相关名言与概念详情')),
              if (onExpand != null && node.kind == 'concept')
                OutlinedButton.icon(
                    onPressed: () => onExpand!(node.id),
                    icon: const Icon(Icons.unfold_more),
                    label: const Text('展开相关概念')),
            ]),
          ])));
}

/// The inspector is a route, so node taps work equally in inline and fullscreen canvases.
Future<void> inspectConcept(
        BuildContext context, String id, SemanticScope value,
        {ValueChanged<String>? onExpand,
        ValueChanged<String>? onOpen,
        Map<String, String> imagePaths = const {}}) =>
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          var current = id;
          return SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .78,
              child: StatefulBuilder(builder: (context, update) {
                final node =
                    value.concepts.where((n) => n.id == current).firstOrNull;
                if (node == null) return const SizedBox.shrink();
                return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: ConceptDetails(
                        node: node,
                        hierarchy: value.hierarchy,
                        concepts: value.concepts,
                        connections: conceptConnections(value),
                        imagePath: imagePaths[current],
                        onSelect: (id) => update(() => current = id),
                        onExpand: onExpand == null
                            ? null
                            : (id) {
                                Navigator.pop(sheetContext);
                                onExpand(id);
                              },
                        onOpen: onOpen == null
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                onOpen(current);
                              }));
              }));
        });

class ConceptHierarchyView extends StatefulWidget {
  final SemanticScope value;
  final bool traceGrounding;
  final ValueChanged<String>? onExpand, onOpen;
  final Map<String, String> imagePaths;
  const ConceptHierarchyView(
      {super.key,
      required this.value,
      this.traceGrounding = false,
      this.onExpand,
      this.onOpen,
      this.imagePaths = const {}});
  @override
  State<ConceptHierarchyView> createState() => _ConceptHierarchyViewState();
}

class _ConceptHierarchyViewState extends State<ConceptHierarchyView> {
  String? selected;
  bool _fullTree = true;
  @override
  Widget build(BuildContext context) {
    if (widget.traceGrounding && !_fullTree)
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GroundingPathView(
            value: widget.value,
            onInspect: (id) => inspectConcept(context, id, widget.value,
                onExpand: widget.onExpand,
                onOpen: widget.onOpen,
                imagePaths: widget.imagePaths)),
        TextButton.icon(
            onPressed: () => setState(() => _fullTree = true),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('查看完整概念树与分支')),
      ]);
    final nodes = widget.value.concepts, edges = widget.value.hierarchy;
    final connections = conceptConnections(widget.value);
    if (nodes.isEmpty) return const Text('尚无概念层级。可主动分析当前原文，已有解读仍可阅读。');
    final depths = {for (final n in nodes) n.id: 0};
    for (var i = 0; i < nodes.length; i++) {
      var changed = false;
      for (final e in edges) {
        final next = depths[e.parent]! + 1;
        if (next > depths[e.child]!) {
          depths[e.child] = next;
          changed = true;
        }
      }
      if (!changed) break;
    }
    final levels = <int, List<SemanticConcept>>{};
    for (final n in nodes) {
      levels.putIfAbsent(depths[n.id]!, () => []).add(n);
    }
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
    final cardHeight = 112 * scale;
    final levelHeight = cardHeight + 70;
    final positions = <String, Offset>{};
    final maxCount = levels.values.map((l) => l.length).reduce(math.max);
    final columns = math.min(maxCount, nodes.length > 8 ? 3 : 2);
    var width = math.max(340.0, columns * 272.0 + 32), top = 20.0;
    for (final level in levels.entries) {
      final count = math.min(columns, level.value.length);
      for (final entry in level.value.indexed) {
        positions[entry.$2.id] = Offset(
            (width - count * 272) / 2 + (entry.$1 % columns) * 272 + 46,
            top + (entry.$1 ~/ columns) * levelHeight);
      }
      top += ((level.value.length + columns - 1) ~/ columns) * levelHeight;
    }
    if (edges.isEmpty) {
      final layout =
          ConceptConnectionLayout.build(nodes, connections, scale: scale);
      width = layout.size.width;
      top = layout.size.height;
      for (final entry in layout.boxes.entries) {
        positions[entry.key] = entry.value.topLeft;
      }
    }
    final boxes = {
      for (final n in nodes)
        n.id: Rect.fromLTWH(
            positions[n.id]!.dx, positions[n.id]!.dy, 180, cardHeight)
    };
    final picked =
        nodes.where((n) => n.id == selected).firstOrNull ?? nodes.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('概念树与关系 · 区分类属、含义依赖和直观',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ConceptCanvas(
          title: '概念树',
          size: Size(width + 32, top + 40),
          child:
              Stack(key: ValueKey(widget.value.toJson().toString()), children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: ConceptConnectionPainter(connections, boxes,
                        font: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.fontFamily))),
            for (final n in nodes)
              Positioned(
                left: positions[n.id]!.dx,
                top: positions[n.id]!.dy,
                width: 180,
                height: cardHeight,
                child: Semantics(
                    button: true,
                    selected: picked.id == n.id,
                    label: '${n.label}。${n.definition}',
                    child: Material(
                        color: n.kind == 'experience'
                            ? const Color(0xffe6eef0)
                            : depths[n.id] == 0
                                ? const Color(0xfff6dfac)
                                : const Color(0xfff6ebd4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                                color: picked.id == n.id
                                    ? const Color(0xffa46c26)
                                    : const Color(0xffded3bd),
                                width: picked.id == n.id ? 2 : 1)),
                        child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setState(() => selected = n.id);
                              inspectConcept(context, n.id, widget.value,
                                  onExpand: widget.onExpand,
                                  onOpen: widget.onOpen,
                                  imagePaths: widget.imagePaths);
                            },
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(n.label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 5),
                                      Text(
                                          n.kind == 'formal'
                                              ? '形式构造 · 定义下的直观'
                                              : n.kind == 'experience'
                                                  ? n.status == 'example'
                                                      ? '具体经验 · 模拟'
                                                      : '具体经验'
                                                  : edges.any((e) =>
                                                          e.child == n.id &&
                                                          e.kind == 'subtype')
                                                      ? '下位概念 · 新增限定'
                                                      : edges.any((e) =>
                                                              e.child == n.id &&
                                                              e.kind ==
                                                                  'mediation')
                                                          ? '中介概念'
                                                          : edges.any((e) =>
                                                                  e.parent ==
                                                                      n.id &&
                                                                  e.kind ==
                                                                      'subtype')
                                                              ? '上位概念 · 共同规定'
                                                              : n.status ==
                                                                      'interpretation'
                                                                  ? '解释概念'
                                                                  : '原文概念',
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center),
                                    ]))))),
              ),
          ])),
      if (widget.traceGrounding)
        TextButton(
            onPressed: () => setState(() => _fullTree = false),
            child: const Text('追踪概念的直观链路')),
      const Text('按连线标注区分类属、依赖、隐喻和对照；排在上方不自动表示上位概念。点选节点查看相连概念与依据。',
          style: TextStyle(fontSize: 12)),
      Wrap(spacing: 6, children: [
        for (final n in nodes)
          ActionChip(
              label: Text(n.label),
              onPressed: () => setState(() => selected = n.id))
      ]),
      ConceptDetails(
          node: picked,
          hierarchy: edges,
          concepts: nodes,
          connections: connections,
          imagePath: widget.imagePaths[picked.id],
          onSelect: (id) => setState(() => selected = id),
          onExpand: widget.onExpand,
          onOpen:
              widget.onOpen == null ? null : () => widget.onOpen!(picked.id)),
    ]);
  }
}
