import 'package:flutter/material.dart';
import 'concept_hierarchy_view.dart';
import 'semantic_scope.dart';

/// Unresolved relations retain visible concept circles without pretending that
/// an arbitrary intersection is a proved extensional relationship.
class ConceptCirclePreview extends StatelessWidget {
  final SemanticScope value;
  final ValueChanged<String>? onOpen, onExpand;
  const ConceptCirclePreview(
      {super.key, required this.value, this.onOpen, this.onExpand});
  @override
  Widget build(BuildContext context) {
    final nodes = value.concepts.where((n) => n.kind == 'concept').toList();
    if (nodes.isEmpty) return const Text('请先补充原句中可界定的概念，再展开含义圈。');
    final positions = <String, Offset>{};
    for (final n in nodes.indexed) {
      positions[n.$2.id] =
          Offset((n.$1 % 3) * 190.0 + 12, (n.$1 ~/ 3) * 180.0 + 12);
    }
    return Column(
        key: const ValueKey('concept-circle-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('独立概念预览 · 尚未建立外延关系',
              style: TextStyle(fontWeight: FontWeight.w600)),
          ConceptCanvas(
              title: '点选圆圈核对含义',
              size: Size(590, ((nodes.length + 2) ~/ 3) * 180.0 + 20),
              child: Stack(children: [
                for (final n in nodes)
                  Positioned(
                      left: positions[n.id]!.dx,
                      top: positions[n.id]!.dy,
                      width: 155,
                      height: 155,
                      child: Semantics(
                          label: '概念：${n.label}。${n.definition}',
                          button: true,
                          child: Material(
                              color: const Color(0xfff3e6c8),
                              shape: const CircleBorder(
                                  side: BorderSide(color: Color(0xffb49a63))),
                              child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => inspectConcept(
                                      context, n.id, value,
                                      onOpen: onOpen, onExpand: onExpand),
                                  child: Center(
                                      child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Text(n.label,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight:
                                                      FontWeight.w600)))))))),
              ])),
          const Text('各概念分别展示，位置和大小不表示相互排斥、包含或重合。尚缺论域、成员或区域依据时，可改看概念树或判断视图。',
              style: TextStyle(fontSize: 12, height: 1.6)),
        ]);
  }
}
