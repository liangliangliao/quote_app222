import 'package:flutter/material.dart';
import 'concept_hierarchy_view.dart';
import 'concept_connections.dart';
import 'semantic_scope.dart';

/// General semantic relations have their own view. This is never a substitute
/// for a class hierarchy or an extensional meaning-circle diagram.
class ConceptCirclePreview extends StatelessWidget {
  final SemanticScope value;
  final ValueChanged<String>? onOpen, onExpand;
  final bool withGrounding;
  const ConceptCirclePreview(
      {super.key,
      required this.value,
      this.onOpen,
      this.onExpand,
      this.withGrounding = false});
  @override
  Widget build(BuildContext context) {
    final connections = conceptConnections(value)
        .where((e) =>
            (withGrounding ||
                !const ['subtype', 'mediation', 'grounding', 'instance']
                    .contains(e.kind)) &&
            !e.kind.startsWith('extension_'))
        .toList();
    final ids = {
      for (final e in connections) e.from,
      for (final e in connections) e.to
    };
    final nodes = value.concepts.where((n) => ids.contains(n.id)).toList();
    if (nodes.isEmpty) return const Text('当前结果尚未建立语义关系。');
    final byId = {for (final n in nodes) n.id: n};
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
    final layout = ConceptConnectionLayout.build(nodes, connections,
        scale: scale, layered: withGrounding);
    return Column(
        key: const ValueKey('concept-circle-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              connections.isEmpty
                  ? '语义关系 · 当前结果尚未返回连线'
                  : '${withGrounding ? '概念关系与直观内容' : '语义关系'} · ${connections.length} 条连线',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          LayoutBuilder(
              builder: (context, constraints) => ConceptCanvas(
                  height: withGrounding
                      ? (layout.size.height /
                              layout.size.width *
                              constraints.maxWidth)
                          .clamp(350.0, 1200.0)
                      : 350,
                  title: withGrounding ? '概念、中介与具体经验' : '隐喻、条件与其他语义关系',
                  size: layout.size,
                  child: Stack(
                      key: ValueKey(value.toJson().toString()),
                      children: [
                        Positioned.fill(
                            child: CustomPaint(
                                painter: ConceptConnectionPainter(
                                    connections, layout.boxes,
                                    font: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.fontFamily))),
                        for (final n in nodes)
                          Positioned(
                              key: ValueKey('meaning-node-${n.id}'),
                              left: layout.boxes[n.id]!.left,
                              top: layout.boxes[n.id]!.top,
                              width: layout.boxes[n.id]!.width,
                              height: layout.boxes[n.id]!.height,
                              child: Semantics(
                                  label: '概念：${n.label}。${n.definition}',
                                  button: true,
                                  child: Material(
                                      color: n.kind == 'concept'
                                          ? const Color(0xfff3e6c8)
                                          : const Color(0xffe6eef0),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          side: const BorderSide(
                                              color: Color(0xff8fa7aa))),
                                      child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          onTap: () => inspectConcept(
                                              context, n.id, value,
                                              onOpen: onOpen,
                                              onExpand: onExpand),
                                          child: Center(
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(15),
                                                  child: Text(n.label,
                                                      maxLines: 4,
                                                      overflow: TextOverflow.ellipsis,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)))))))),
                      ]))),
          Text(
              connections.isEmpty
                  ? '该结果没有给出可连接的概念身份与关系。可点击重新分析；已有原文与节点继续保留。'
                  : withGrounding
                      ? '沿标注核对关系类型与依据；蓝色虚线追到具体经验，组成部分不等于下位类别。范围包含与相交另见含义圈。'
                      : '沿标注连线阅读隐喻、条件与主张。此图表达语义联系，含义范围另见“含义圈”。',
              style: TextStyle(fontSize: 12, height: 1.6)),
          if (connections.isNotEmpty)
            ExpansionTile(
                title: Text('连线含义与原文依据 · ${connections.length}'),
                children: [
                  for (final e in connections)
                    ListTile(
                        key: ValueKey('meaning-link-${e.identity}'),
                        title: Text(
                            '${byId[e.from]!.label}　${e.label}${e.symmetric ? ' ↔ ' : ' → '}${byId[e.to]!.label}'),
                        subtitle: Text(
                            '${e.status == 'interpretation' ? '解释：' : e.status == 'unknown' ? '待核对：' : ''}${e.explanation}\n'
                            '${e.references.map((r) => '${r.source}「${r.excerpt}」').join('\n')}')),
                ]),
        ]);
  }
}
