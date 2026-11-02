import 'package:flutter/material.dart';
import 'semantic_scope.dart';

class GroundingPathView extends StatefulWidget {
  final SemanticScope value;
  final ValueChanged<String> onInspect;
  const GroundingPathView(
      {super.key, required this.value, required this.onInspect});
  @override
  State<GroundingPathView> createState() => _GroundingPathViewState();
}

class _GroundingPathViewState extends State<GroundingPathView> {
  String? _selected;
  List<SemanticConcept> _path(String id, Set<String> visited) {
    if (!visited.add(id)) return [];
    final node = widget.value.concepts.where((c) => c.id == id).firstOrNull;
    if (node == null) return [];
    if (node.kind == 'experience') return [node];
    var best = <SemanticConcept>[];
    for (final e in widget.value.hierarchy.where((e) => e.parent == id)) {
      final child = _path(e.child, {...visited});
      if (child.isNotEmpty &&
          child.last.kind == 'experience' &&
          child.length > best.length) best = child;
    }
    return [node, ...best];
  }

  @override
  Widget build(BuildContext context) {
    final concepts =
        widget.value.concepts.where((c) => c.kind == 'concept').toList();
    if (concepts.isEmpty) return const Text('请先补充可理解的概念与具体材料。');
    final paths = {for (final c in concepts) c.id: _path(c.id, {})};
    final best = concepts
        .reduce((a, b) => paths[a.id]!.length >= paths[b.id]!.length ? a : b);
    final selected =
        concepts.where((c) => c.id == _selected).firstOrNull ?? best;
    final path = paths[selected.id]!;
    return Column(
        key: const ValueKey('grounding-path-view'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('概念如何获得内容 · 沿中介链回到直观',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('概念仍是抽象表象。下位限定、概念依赖与直观依据分别核对；模拟描述是返回经验的线索。',
              style: TextStyle(fontSize: 12, height: 1.6)),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final c in concepts)
              ChoiceChip(
                  label: Text(c.label, style: const TextStyle(fontSize: 12)),
                  selected: c.id == selected.id,
                  onSelected: (_) => setState(() => _selected = c.id))
          ]),
          for (final item in path.indexed) ...[
            if (item.$1 > 0)
              Builder(builder: (context) {
                final e = widget.value.hierarchy.firstWhere((e) =>
                    e.parent == path[item.$1 - 1].id && e.child == item.$2.id);
                final label = switch (e.kind) {
                  'mediation' => '概念依赖 · 通过这一规定理解',
                  'grounding' => '直观依据 · 内容回到可感知场景',
                  'instance' => '具体实例 · 呈现部分规定',
                  _ => '下位限定 · 增加一个条件'
                };
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      const Icon(Icons.south,
                          size: 18, color: Color(0xff8a9a9c)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(label,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xff687e80))))
                    ]));
              }),
            Card(
                color: item.$2.kind == 'experience'
                    ? const Color(0xffe6eff0)
                    : const Color(0xfff7e7c5),
                elevation: 0,
                margin: EdgeInsets.zero,
                child: InkWell(
                    key: ValueKey('grounding-node-${item.$2.id}'),
                    onTap: () => widget.onInspect(item.$2.id),
                    child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(item.$2.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(item.$2.definition,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.6)),
                              if (item.$2.kind == 'experience') ...[
                                const SizedBox(height: 8),
                                Text(
                                    item.$2.status == 'example'
                                        ? '模拟场景 · 可据此观察人物、动作与条件，再与自己的经验对照。'
                                        : '原文提供的具体材料 · 仍需核对其观察来源。',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xff526e73)))
                              ],
                            ])))),
          ],
          if (path.last.kind != 'experience')
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('这条链尚缺直观依据；请补充可观察的具体材料，不能用概念名称代替。')),
        ]);
  }
}
