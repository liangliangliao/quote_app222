import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'concept_hierarchy_view.dart';
import 'concept_meaning_diagram.dart';
import 'semantic_scope.dart';

class MeaningCircle {
  final List<String> ids;
  Offset center;
  double radius;
  MeaningCircle(this.ids, this.center, this.radius);
}

class MeaningCluster {
  final List<SemanticRelation> relations;
  final List<MeaningCircle> circles;
  final Size size;

  /// Geometry consistency only; never source or philosophical verification.
  final bool verified;
  bool get geometryConsistent => verified;
  const MeaningCluster(this.relations, this.circles, this.size, this.verified);
}

/// Deterministic bounded constraint layout. A failed constraint produces local
/// diagrams, never a plausible-looking but contradictory global Euler diagram.
class ConceptCircleLayout {
  static Set<String> _members(SemanticRelation r) =>
      r.scope!.relation == QuoteRelation.partition
          ? {...r.partIds, r.universeId}
          : {
              ...r.nodeIds,
              ...r.partIds,
              if (r.universeId.isNotEmpty) r.universeId
            };
  static List<MeaningCluster> build(SemanticScope value) {
    final pending = value.relations
        .where((r) => r.scope != null && r.nodeIds.length == 2)
        .toList();
    final result = <MeaningCluster>[];
    while (pending.isNotEmpty) {
      final group = [pending.removeAt(0)];
      final ids = _members(group.first);
      var changed = true;
      while (changed) {
        changed = false;
        for (final r in pending.toList()) {
          final members = _members(r);
          if (r.scope!.universe == group.first.scope!.universe &&
              members.any(ids.contains)) {
            group.add(r);
            pending.remove(r);
            ids.addAll(members);
            changed = true;
          }
        }
      }
      result.add(_solve(group));
    }
    return result;
  }

  static MeaningCluster _solve(List<SemanticRelation> relations) {
    if (relations.any((r) => r.scope!.relation == QuoteRelation.partition)) {
      // Exhaustive parts must fill the parent; separated circles leave a false remainder.
      return MeaningCluster(relations, const [], const Size(500, 350), false);
    }
    final ids = <String>{for (final r in relations) ..._members(r)};
    final aliases = {for (final id in ids) id: id};
    String root(String id) {
      while (aliases[id] != id) {
        id = aliases[id]!;
      }
      return id;
    }

    for (final r
        in relations.where((r) => r.scope!.relation == QuoteRelation.equal)) {
      aliases[root(r.nodeIds[1])] = root(r.nodeIds[0]);
    }
    final groups = <String, List<String>>{};
    for (final id in ids) {
      groups.putIfAbsent(root(id), () => []).add(id);
    }
    final contains = <(String, String)>{};
    final overlap = <(String, String)>{};
    final separate = <(String, String)>{};
    for (final r in relations) {
      final a = r.scope!.relation == QuoteRelation.partition
          ? ''
          : root(r.nodeIds[0]);
      final b = r.scope!.relation == QuoteRelation.partition
          ? ''
          : root(r.nodeIds[1]);
      switch (r.scope!.relation) {
        case QuoteRelation.subset:
          contains.add((b, a));
          break;
        case QuoteRelation.superset:
          contains.add((a, b));
          break;
        case QuoteRelation.overlap:
          overlap.add((a, b));
          break;
        case QuoteRelation.partition:
        case QuoteRelation.siblings:
          final children =
              (r.partIds.isEmpty ? r.nodeIds : r.partIds).map(root).toList();
          for (final id in children) {
            contains.add((root(r.universeId), id));
          }
          for (var i = 0; i < children.length; i++) {
            for (var j = i + 1; j < children.length; j++) {
              separate.add((children[i], children[j]));
            }
          }
          break;
        default:
          break;
      }
    }
    final depths = {for (final id in groups.keys) id: 0};
    for (var i = 0; i < groups.length; i++) {
      for (final e in contains) {
        depths[e.$2] = math.max(depths[e.$2]!, depths[e.$1]! + 1);
      }
    }
    if (contains.any((e) => e.$1 == e.$2) ||
        depths.values.any((d) => d >= groups.length)) {
      return MeaningCluster(relations, const [], const Size(500, 300), false);
    }
    final circles = <String, MeaningCircle>{};
    bool paired(Set<(String, String)> pairs, String a, String b) => pairs.contains((a, b)) || pairs.contains((b, a));
    final ordered = groups.keys.toList()
      ..sort((a, b) => depths[a]!.compareTo(depths[b]!));
    var top = 0;
    for (final id in ordered) {
      final parents =
          contains.where((e) => e.$2 == id).map((e) => e.$1).toList()..sort((a, b) => depths[b]!.compareTo(depths[a]!));
      if (parents.isEmpty) {
        final radius = contains.isEmpty ? 120.0 : 360.0;
        circles[id] = MeaningCircle(groups[id]!, Offset(top * radius * 1.75, 0), radius);
        top++;
      } else {
        final parent = parents.first,
            peers =
                contains.where((e) => e.$1 == parent).map((e) => e.$2).toList();
        final p = circles[parent]!, index = peers.indexOf(id);
        final hasDisjointPeer = peers.any((other) => paired(separate, id, other));
        final radius = p.radius * (hasDisjointPeer ? 1 / (1.8 + math.sqrt(peers.length)) : .64);
        final angle = 2 * math.pi * index / peers.length;
        circles[id] = MeaningCircle(
            groups[id]!,
            p.center +
                Offset(math.cos(angle), math.sin(angle)) *
                    (peers.length == 1 ? p.radius * .18 : p.radius * .36),
            radius);
      }
    }
    // A long overlap path gets a compact hexagonal snake. Adjacent circles
    // intersect and non-neighbours remain separate in the bounded exercise.
    if (contains.isEmpty &&
        relations.every((r) => r.scope!.relation == QuoteRelation.overlap)) {
      final graph = <String, Set<String>>{};
      for (final e in overlap) {
        graph.putIfAbsent(e.$1, () => {}).add(e.$2);
        graph.putIfAbsent(e.$2, () => {}).add(e.$1);
      }
      final ends = graph.keys.where((id) => graph[id]!.length == 1).toList();
      if (ends.length == 2 &&
          graph.length == groups.length &&
          graph.values.every((n) => n.length <= 2)) {
        final path = <String>[], seen = <String>{};
        var at = ends.first;
        while (seen.add(at)) {
          path.add(at);
          final next = graph[at]!.where((n) => !seen.contains(n)).firstOrNull;
          if (next == null) break;
          at = next;
        }
        if (path.length == groups.length)
          for (final e in path.indexed) {
            final i = e.$1, row = i ~/ 4, step = i % 4;
            final x = row.isEven
                ? (step < 3 ? step * 160.0 : 400.0)
                : (step < 3 ? (2 - step) * 160.0 : -80.0);
            final y = row * 277.2 + (step == 3 ? 138.6 : 0);
            circles[e.$2]!.center = Offset(x, y);
          }
      }
    }
    // An unspecified pair is unknown, not a disjointness constraint.
    void distance(String a, String b, double target, {bool oneSided = false}) {
      final x = circles[a]!, y = circles[b]!;
      final delta = y.center - x.center, d = delta.distance;
      final direction = d < .001 ? const Offset(1, .35) / 1.059481 : delta / d;
      final correction = direction * (target - d) * .7;
      if (oneSided) {
        y.center += correction;
      } else {
        x.center -= correction / 2;
        y.center += correction / 2;
      }
    }

    for (var iteration = 0; iteration < 500; iteration++) {
      for (final e in overlap) {
        final a = circles[e.$1]!, b = circles[e.$2]!;
        final low =
            (a.radius - b.radius).abs() + math.min(a.radius, b.radius) * .3;
        final high = a.radius + b.radius - math.min(a.radius, b.radius) * .4;
        final d = (a.center - b.center).distance;
        if (d < low || d > high) distance(e.$1, e.$2, (low + high) / 2);
      }
      for (final e in separate) {
        final a = circles[e.$1]!,
            b = circles[e.$2]!,
            d = (a.center - b.center).distance;
        if (d < a.radius + b.radius + 6)
          distance(e.$1, e.$2, a.radius + b.radius + 8);
      }
      for (final e in contains) {
        final p = circles[e.$1]!,
            c = circles[e.$2]!,
            d = (p.center - c.center).distance;
        final maxD = p.radius - c.radius - 8;
        if (d > maxD) distance(e.$1, e.$2, math.max(0, maxD), oneSided: true);
      }
    }
    final verified = contains.every((e) {
          final p = circles[e.$1]!, c = circles[e.$2]!;
          return (p.center - c.center).distance + c.radius <= p.radius - 5;
        }) &&
        separate.every((e) {
          final a = circles[e.$1]!, b = circles[e.$2]!;
          return (a.center - b.center).distance >= a.radius + b.radius + 3;
        }) &&
        overlap.every((e) {
          final a = circles[e.$1]!,
              b = circles[e.$2]!,
              d = (a.center - b.center).distance;
          return d > (a.radius - b.radius).abs() + 3 &&
              d < a.radius + b.radius - 3;
        });
    final list = circles.values.toList();
    final left = list.map((c) => c.center.dx - c.radius).reduce(math.min) - 24;
    final topY = list.map((c) => c.center.dy - c.radius).reduce(math.min) - 24;
    final right = list.map((c) => c.center.dx + c.radius).reduce(math.max) + 24;
    final bottom =
        list.map((c) => c.center.dy + c.radius).reduce(math.max) + 24;
    for (final c in list) {
      c.center -= Offset(left, topY);
    }
    return MeaningCluster(
        relations, list, Size(right - left, bottom - topY), verified);
  }
}

class ConceptMeaningNetwork extends StatefulWidget {
  final SemanticScope value;
  final ValueChanged<int>? onRelation;
  final ValueChanged<String>? onExpand, onOpen;
  const ConceptMeaningNetwork(
      {super.key,
      required this.value,
      this.onRelation,
      this.onExpand,
      this.onOpen});
  @override
  State<ConceptMeaningNetwork> createState() => _ConceptMeaningNetworkState();
}

class _ConceptMeaningNetworkState extends State<ConceptMeaningNetwork> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final clusters = ConceptCircleLayout.build(widget.value);
    final nodes = {for (final n in widget.value.concepts) n.id: n};
    final picked = nodes[selected];
    if (clusters.isEmpty) return const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('尚未建立含义范围图', style: TextStyle(fontWeight: FontWeight.w700)),
      Text('当前结果没有同一论域中的包含、重合、划分或交叉判断。语义关系可以单独查看；它不能替代含义圈。请重新生成概念定义与范围。'),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (clusters.isNotEmpty)
        const Text('外延圈图 · 按所列论域与成员判准绘制',
            style: TextStyle(fontWeight: FontWeight.w600)),
      if (clusters.any((g) => g.relations.any((r) => r.scope!.basisKind == 'analytic_definition')))
        const Text('分析性重构 · 依本次明示的定义；可能情形用于解释范围，不表示原文记述过这些事实。', style: TextStyle(fontSize: 12)),
      for (final cluster in clusters) ...[
        if (cluster.geometryConsistent)
          ConceptCanvas(
              title:
                  '${cluster.relations.any((r) => r.scope!.illustration) ? '模拟练习 · ' : ''}多概念含义圈 · ${cluster.relations.first.scope!.universe}',
              size: cluster.size,
              child: GestureDetector(
                  key: ValueKey(
                      cluster.relations.map((r) => r.toJson()).toString()),
                  onTapUp: (tap) {
                    for (final r in cluster.relations.where((r) => r.intersectionId.isNotEmpty)) {
                      final sets = r.nodeIds.map((id) => cluster.circles.where((c) => c.ids.contains(id)).firstOrNull).toList();
                      if (sets.every((c) => c != null && (tap.localPosition-c.center).distance <= c.radius)) {
                        inspectConcept(context, r.intersectionId, widget.value, onExpand: widget.onExpand, onOpen: widget.onOpen);
                        return;
                      }
                    }
                    final found = cluster.circles
                        .where((c) =>
                            (tap.localPosition - c.center).distance <= c.radius)
                        .toList()
                      ..sort((a, b) => a.radius.compareTo(b.radius));
                    if (found.isNotEmpty) {
                      final id = found.first.ids.first;
                      setState(() => selected = id);
                      inspectConcept(context, id, widget.value,
                          onExpand: widget.onExpand, onOpen: widget.onOpen);
                    }
                  },
                  child: CustomPaint(
                      size: cluster.size,
                      painter: _NetworkCircles(cluster.circles, nodes, selected,
                          Theme.of(context).textTheme.bodyMedium?.fontFamily, cluster.relations))))
        else ...[
          const Text('按局部范围图呈现相应图式；穷尽划分用完整扇区覆盖上位范围，概念身份保持一致。',
              style: TextStyle(fontSize: 12)),
          for (final relation in cluster.relations) _local(relation),
        ],
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final entry in cluster.relations.indexed)
            ActionChip(
                label: Text(
                    '${entry.$1 + 1}　${entry.$2.scope!.setA} · ${entry.$2.scope!.setB}'),
                onPressed: () => widget.onRelation
                    ?.call(widget.value.relations.indexOf(entry.$2)))
        ]),
      ],
      const Text('本图呈现已列范围判断的一种排布，未列关系不据位置补推。圈大小不表示数量，交集不证明因果。',
          style: TextStyle(fontSize: 12, color: Color(0xff70675b))),
      Wrap(spacing: 6, children: [
        for (final n in nodes.values.where((n) => clusters.any((g) =>
            g.relations.any((r) =>
                r.nodeIds.contains(n.id) ||
                r.partIds.contains(n.id) ||
                r.intersectionId == n.id ||
                r.universeId == n.id))))
          ActionChip(
              label: Text(n.label),
              onPressed: () => setState(() => selected = n.id))
      ]),
      if (picked != null)
        ConceptDetails(
            node: picked,
            onExpand: widget.onExpand,
            onOpen:
                widget.onOpen == null ? null : () => widget.onOpen!(picked.id)),
    ]);
  }

  Widget _local(SemanticRelation r) {
    final s = r.scope!;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ConceptMeaningDiagram(
            relation: s.relation,
            setA: s.setA,
            setB: s.setB,
            universe: s.universe,
            intersection: s.intersection,
            onlyA: s.onlyA,
            onlyB: s.onlyB,
            otherMember: s.otherMember,
            parts: s.parts));
  }
}

class _NetworkCircles extends CustomPainter {
  final List<MeaningCircle> circles;
  final Map<String, SemanticConcept> nodes;
  final String? selected, font;
  final List<SemanticRelation> relations;
  const _NetworkCircles(this.circles, this.nodes, this.selected, this.font, this.relations);
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xffc9a153),
      Color(0xff7299aa),
      Color(0xff9e88ae),
      Color(0xff79a18e),
      Color(0xffc88e77)
    ];
    final ordered = circles.toList()
      ..sort((a, b) => b.radius.compareTo(a.radius));
    for (final entry in ordered.indexed) {
      final c = entry.$2, color = colors[entry.$1 % colors.length];
      canvas.drawCircle(
          c.center, c.radius, Paint()..color = color.withValues(alpha: .13));
      canvas.drawCircle(
          c.center,
          c.radius,
          Paint()
            ..color = c.ids.contains(selected) ? const Color(0xff8c5b22) : color
            ..strokeWidth = c.ids.contains(selected) ? 3 : 1.8
            ..style = PaintingStyle.stroke);
    }
    for (final r in relations.where((r) => r.intersectionId.isNotEmpty)) {
      final a = circles.where((c) => c.ids.contains(r.nodeIds[0])).firstOrNull;
      final b = circles.where((c) => c.ids.contains(r.nodeIds[1])).firstOrNull;
      if (a == null || b == null) continue;
      final lens = Path.combine(PathOperation.intersect,
          Path()..addOval(Rect.fromCircle(center: a.center, radius: a.radius)),
          Path()..addOval(Rect.fromCircle(center: b.center, radius: b.radius)));
      canvas.drawPath(lens, Paint()..color = const Color(0xff8d79ac).withValues(alpha: .13));
    }
    final labelRects = <Rect>[];
    for (final c in ordered) {
      final text = c.ids.map((id) => nodes[id]?.label ?? '').join(' ≡ ');
      final nested = ordered.any((o) =>
          o != c && (o.center - c.center).distance + o.radius < c.radius);
      final at = nested ? c.center - Offset(0, c.radius * .75) : c.center;
      final label = TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(
                  fontFamily: font,
                  fontSize: math.max(12, math.min(20, c.radius * .26)),
                  color: const Color(0xff3d352a),
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 3,
          ellipsis: '…')
        ..layout(maxWidth: c.radius * 1.5);
      final rect = Rect.fromCenter(
          center: at, width: label.width + 6, height: label.height + 4);
      labelRects.add(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = const Color(0xfffffcf6).withValues(alpha: .88));
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
    for (final r in relations.where((r) => r.intersectionId.isNotEmpty)) {
      final a = circles.where((c) => c.ids.contains(r.nodeIds[0])).firstOrNull;
      final b = circles.where((c) => c.ids.contains(r.nodeIds[1])).firstOrNull;
      if (a == null || b == null) continue;
      final delta = b.center-a.center, d = delta.distance;
      if (d == 0) continue;
      final low = math.max(-a.radius, d-b.radius), high = math.min(a.radius, d+b.radius);
      final anchor = a.center+delta/d*((low+high)/2);
      final label = TextPainter(text: TextSpan(text: '${nodes[r.intersectionId]?.label ?? '共同范围'}\n（交集）',
          style: TextStyle(fontFamily: font, fontSize: 15, color: const Color(0xff503c69), fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr, textAlign: TextAlign.center, maxLines: 3)
        ..layout(maxWidth: math.min(145, math.max(80, high-low)));
      final bounds = Rect.fromCircle(center:a.center,radius:a.radius).intersect(Rect.fromCircle(center:b.center,radius:b.radius));
      Offset at = anchor;
      var best = double.infinity;
      for (var y=0; y<=16; y++) {
        for (var x=0; x<=16; x++) {
          final point = Offset(bounds.left+bounds.width*x/16, bounds.top+bounds.height*y/16);
          final box = Rect.fromCenter(center:point,width:label.width+8,height:label.height+6);
          final corners = [box.topLeft,box.topRight,box.bottomLeft,box.bottomRight];
          if (corners.any((p)=>(p-a.center).distance>a.radius || (p-b.center).distance>b.radius)) continue;
          final collisions = labelRects.where((r)=>r.inflate(5).overlaps(box)).length;
          final score = collisions*100000+(point-anchor).distance;
          if (score<best) {best=score;at=point;}
        }
      }
      final rect = Rect.fromCenter(center:at,width:label.width+8,height:label.height+6);
      labelRects.add(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)),Paint()..color=const Color(0xfff4effa));
      label.paint(canvas,at-Offset(label.width/2,label.height/2));
    }
  }

  @override
  bool shouldRepaint(_NetworkCircles old) =>
      old.circles != circles || old.selected != selected || old.font != font;
}
