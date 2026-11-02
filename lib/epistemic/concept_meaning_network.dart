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
  final bool verified;
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
    final ordered = groups.keys.toList()
      ..sort((a, b) => depths[a]!.compareTo(depths[b]!));
    var top = 0;
    for (final id in ordered) {
      final parents =
          contains.where((e) => e.$2 == id).map((e) => e.$1).toList();
      if (parents.isEmpty) {
        circles[id] = MeaningCircle(groups[id]!, Offset(top * 210.0, 0), 120);
        top++;
      } else {
        final parent = parents.first,
            peers =
                contains.where((e) => e.$1 == parent).map((e) => e.$2).toList();
        final p = circles[parent]!, index = peers.indexOf(id);
        final radius = p.radius /
            (peers.length == 1 ? 1.8 : 1.5 + math.sqrt(peers.length));
        final angle = 2 * math.pi * index / peers.length;
        circles[id] = MeaningCircle(
            groups[id]!,
            p.center +
                Offset(math.cos(angle), math.sin(angle)) *
                    (peers.length == 1 ? p.radius * .22 : p.radius * .48),
            radius);
      }
    }
    bool inside(String parent, String child, Set<String> seen) =>
        contains.contains((parent, child)) ||
        (seen.add(parent) &&
            contains
                .where((e) => e.$1 == parent)
                .any((e) => inside(e.$2, child, seen)));
    bool paired(Set<(String, String)> pairs, String a, String b) =>
        pairs.contains((a, b)) || pairs.contains((b, a));
    // Unspecified pairs have no shaded accidental intersection. Their absence
    // remains explicitly unjudged, rather than being asserted as a sixth type.
    for (var i = 0; i < ordered.length; i++) {
      for (var j = i + 1; j < ordered.length; j++) {
        final a = ordered[i], b = ordered[j];
        if (!inside(a, b, {}) && !inside(b, a, {}) && !paired(overlap, a, b))
          separate.add((a, b));
      }
    }
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final cluster in clusters) ...[
        if (cluster.verified)
          ConceptCanvas(
              title: '多概念含义圈 · ${cluster.relations.first.scope!.universe}',
              size: cluster.size,
              child: GestureDetector(
                  key: ValueKey(
                      cluster.relations.map((r) => r.toJson()).toString()),
                  onTapUp: (tap) {
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
                          Theme.of(context).textTheme.bodyMedium?.fontFamily))))
        else ...[
          const Text('这些关系无法在同一组圆中准确排布，以下局部图保留相同的概念身份。',
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
      const Text('只解释已标注关系；未标注的概念关系尚未判断。圈大小不表示数量，交集不证明因果。',
          style: TextStyle(fontSize: 12, color: Color(0xff70675b))),
      Wrap(spacing: 6, children: [
        for (final n in nodes.values.where((n) => clusters.any((g) =>
            g.relations.any((r) =>
                r.nodeIds.contains(n.id) ||
                r.partIds.contains(n.id) ||
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
  const _NetworkCircles(this.circles, this.nodes, this.selected, this.font);
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
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = const Color(0xfffffcf6).withValues(alpha: .88));
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_NetworkCircles old) =>
      old.circles != circles || old.selected != selected || old.font != font;
}
