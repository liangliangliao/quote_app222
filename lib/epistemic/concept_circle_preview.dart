import 'package:flutter/material.dart';
import 'concept_hierarchy_view.dart';
import 'concept_connections.dart';
import 'semantic_scope.dart';

/// Meaning links remain visible when a passage uses metaphor or predication
/// rather than an extensional class relation. Euler geometry is shown separately.
class ConceptCirclePreview extends StatelessWidget {
  final SemanticScope value;
  final ValueChanged<String>? onOpen, onExpand;
  const ConceptCirclePreview(
      {super.key, required this.value, this.onOpen, this.onExpand});
  @override
  Widget build(BuildContext context) {
    final nodes = value.concepts;
    if (nodes.isEmpty) return const Text('请先补充原句中可界定的概念，再展开含义圈。');
    final connections = conceptConnections(value);
    final byId = {for (final n in nodes) n.id: n};
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
    final layout =
        ConceptConnectionLayout.build(nodes, connections, scale: scale);
    return Column(
        key: const ValueKey('concept-circle-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              connections.isEmpty
                  ? '概念含义 · 当前结果尚未返回连线'
                  : '概念含义与关系 · ${connections.length} 条连线',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          ConceptCanvas(
              title: '多概念关系图',
              size: layout.size,
              child: Stack(key: ValueKey(value.toJson().toString()), children: [
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
                              shape: n.kind == 'concept'
                                  ? const CircleBorder(
                                      side:
                                          BorderSide(color: Color(0xffb49a63)))
                                  : RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: const BorderSide(
                                          color: Color(0xff8fa7aa))),
                              child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => inspectConcept(context, n.id, value,
                                      onOpen: onOpen, onExpand: onExpand),
                                  child: Center(
                                      child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Text(n.label,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight:
                                                      FontWeight.w600)))))))),
              ])),
          Text(
              connections.isEmpty
                  ? '该结果没有给出可连接的概念身份与关系。可点击重新分析；已有原文与节点继续保留。'
                  : '沿标注连线阅读关系；虚线为解释或依赖，箭头表示方向。圆的大小、位置不表示外延包含；有成员判准的五种圈图另行展示。',
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
