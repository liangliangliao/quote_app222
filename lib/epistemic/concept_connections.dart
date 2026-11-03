import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/quote_insight.dart';
import 'semantic_scope.dart';
import 'concept_connection_routes.dart';

String conceptConnectionLabel(String kind) => switch (kind) {
      'subtype' => '下位限定',
      'mediation' => '概念依赖',
      'grounding' => '直观依据',
      'instance' => '具体实例',
      'metaphor' => '隐喻映射',
      'contrast' => '对照',
      'predication' => '主谓规定',
      'condition' => '条件',
      'cause' => '因果主张',
      'sequence' => '先后',
      'preference' => '偏好次序',
      'analogy' => '类比',
      'association' => '语境关联',
      'extension_equal' => '外延重合',
      'extension_contains' => '完全包含',
      'extension_overlap' => '外延相交',
      'extension_siblings' => '同属上位范围',
      'extension_partition' => '划分子类',
      _ => '原文关系',
    };

class ConceptConnection {
  final String from, to, kind, explanation, status;
  final List<ScopeReference> references;
  const ConceptConnection(this.from, this.to, this.kind, this.explanation,
      this.status, this.references);
  String get label => conceptConnectionLabel(kind);
  String get identity => '$from:$kind:$to';
  bool get symmetric => const {
        'contrast',
        'analogy',
        'association',
        'extension_equal',
        'extension_overlap',
        'extension_siblings',
      }.contains(kind);
  bool get dashed =>
      status == 'interpretation' ||
      status == 'unknown' ||
      const {'mediation', 'grounding', 'instance'}.contains(kind);
  Color get color => switch (kind) {
        'metaphor' || 'analogy' => const Color(0xff8969a4),
        'contrast' || 'preference' => const Color(0xffad7846),
        'grounding' || 'instance' || 'mediation' => const Color(0xff557d82),
        _ => const Color(0xff7d735c),
      };
}

/// Both canvases use the same validated identities. No relationship is inferred
/// from a name, screen position, category label or a shared keyword.
List<ConceptConnection> conceptConnections(SemanticScope value) {
  final nodes = {for (final n in value.concepts) n.id: n};
  final result = <String, ConceptConnection>{};
  void add(ConceptConnection e) {
    if (nodes.containsKey(e.from) && nodes.containsKey(e.to) && e.from != e.to)
      result[e.identity] = e;
  }

  for (final e in value.hierarchy) {
    add(ConceptConnection(e.parent, e.child, e.kind, e.explanation,
        nodes[e.child]?.status ?? 'interpretation', e.references));
  }
  for (final e in value.meaningLinks) {
    add(ConceptConnection(
        e.from, e.to, e.kind, e.explanation, e.status, e.references));
  }
  for (final r in value.relations) {
    final s = r.scope;
    if (s == null) {
      if (r.nodeIds.length == 2)
        add(ConceptConnection(r.nodeIds[0], r.nodeIds[1], 'context',
            r.statement, r.status, r.references));
      continue;
    }
    if (r.nodeIds.length != 2) continue;
    final a = r.nodeIds[0], b = r.nodeIds[1];
    switch (s.relation) {
      case QuoteRelation.subset:
        add(ConceptConnection(
            b, a, 'extension_contains', r.statement, r.status, r.references));
      case QuoteRelation.superset:
        add(ConceptConnection(
            a, b, 'extension_contains', r.statement, r.status, r.references));
      case QuoteRelation.partition:
      case QuoteRelation.siblings:
        for (final id in r.partIds.isEmpty ? r.nodeIds : r.partIds) {
          add(ConceptConnection(
              r.universeId,
              id,
              s.relation == QuoteRelation.partition
                  ? 'extension_partition'
                  : 'extension_contains',
              r.statement,
              r.status,
              r.references));
        }
        if (s.relation == QuoteRelation.siblings)
          add(ConceptConnection(
              a, b, 'extension_siblings', r.statement, r.status, r.references));
      case QuoteRelation.equal:
      case QuoteRelation.overlap:
        add(ConceptConnection(
            a,
            b,
            s.relation == QuoteRelation.equal
                ? 'extension_equal'
                : 'extension_overlap',
            r.statement,
            r.status,
            r.references));
      default:
        break;
    }
  }
  return result.values.toList();
}

/// Compact, deterministic snake layout. The order follows connected neighbours;
/// rows are for readability and never claim logical rank or class inclusion.
class ConceptConnectionLayout {
  final Map<String, Rect> boxes;
  final Size size;
  const ConceptConnectionLayout(this.boxes, this.size);
  static ConceptConnectionLayout build(
      List<SemanticConcept> nodes, List<ConceptConnection> connections,
      {double scale = 1}) {
    if (nodes.isEmpty) return const ConceptConnectionLayout({}, Size(320, 240));
    final graph = {for (final n in nodes) n.id: <String>{}};
    for (final e in connections) {
      graph[e.from]?.add(e.to);
      graph[e.to]?.add(e.from);
    }
    final groups = <List<String>>[], seen = <String>{}, isolated = <String>[];
    for (final n in nodes) {
      if (graph[n.id]!.isEmpty) {
        isolated.add(n.id);
        continue;
      }
      if (!seen.add(n.id)) continue;
      final queue = [n.id];
      for (var i = 0; i < queue.length; i++) {
        for (final next in graph[queue[i]]!) {
          if (seen.add(next)) queue.add(next);
        }
      }
      groups.add(queue);
    }
    if (isolated.isNotEmpty) groups.add(isolated);
    final extent = 160.0 * scale, step = 232.0 * scale, pad = 52.0 * scale;
    var top = pad, width = 0.0;
    final boxes = <String, Rect>{};
    for (final group in groups) {
      final columns = math.sqrt(group.length).ceil().clamp(1, 4);
      width = math.max(width, (columns - 1) * step + extent + pad * 2);
      for (final entry in group.indexed) {
        final row = entry.$1 ~/ columns, index = entry.$1 % columns;
        final column = row.isEven ? index : columns - 1 - index;
        boxes[entry.$2] = Rect.fromLTWH(
            pad + column * step, top + row * step, extent, extent);
      }
      top += ((group.length + columns - 1) ~/ columns) * step + pad;
    }
    return ConceptConnectionLayout(boxes, Size(width, top - step + extent));
  }
}

/// Edge labels and arrows are part of the canvas, rather than information that
/// only appears after selecting a node. Endpoints stop at the node boundary.
class ConceptConnectionPainter extends CustomPainter {
  final List<ConceptConnection> connections;
  final Map<String, Rect> boxes;
  final String? font;
  const ConceptConnectionPainter(this.connections, this.boxes, {this.font});

  @override
  void paint(Canvas canvas, Size size) {
    final labels = <Rect>[];
    final routes = <List<Offset>>[];
    for (final e in connections) {
      final a = boxes[e.from], b = boxes[e.to];
      if (a == null || b == null) continue;
      final route =
          routeConceptConnection(e.from, e.to, boxes, size, occupied: routes);
      if (route.length < 2) continue;
      routes.add(route);
      final from = route.first, to = route.last;
      final path = Path()..moveTo(from.dx, from.dy);
      for (final p in route.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final pen = Paint()
        ..color = e.color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      final metric = path.computeMetrics().first;
      if (e.dashed) {
        for (double d = 0; d < metric.length; d += 11) {
          canvas.drawPath(
              metric.extractPath(d, math.min(d + 7, metric.length)), pen);
        }
      } else {
        canvas.drawPath(path, pen);
      }
      if (!e.symmetric) {
        final tangent =
            metric.getTangentForOffset(math.max(0, metric.length - .1));
        if (tangent != null) {
          final vector = tangent.vector;
          final side = Offset(-vector.dy, vector.dx);
          canvas.drawLine(to, to - vector * 9 + side * 4, pen);
          canvas.drawLine(to, to - vector * 9 - side * 4, pen);
        }
      }
      final label = TextPainter(
          text: TextSpan(
              text: e.label,
              style: TextStyle(
                  fontFamily: font,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: e.color)),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 2)
        ..layout(maxWidth: 66);
      final segments = [
        for (var i = 1; i < route.length; i++) (route[i - 1], route[i])
      ]..sort(
          (a, b) => (b.$2 - b.$1).distance.compareTo((a.$2 - a.$1).distance));
      Offset? chosen;
      for (final segment in segments) {
        for (final t in [.5, .3, .7, .15, .85]) {
          final at = Offset.lerp(segment.$1, segment.$2, t)!;
          final rect = Rect.fromCenter(
              center: at, width: label.width + 12, height: label.height + 8);
          if ((Offset.zero & size).contains(rect.topLeft) &&
              (Offset.zero & size).contains(rect.bottomRight) &&
              !boxes.values.any((b) => b.inflate(2).overlaps(rect)) &&
              !labels.any((b) => b.inflate(3).overlaps(rect))) {
            chosen = at;
            break;
          }
        }
        if (chosen != null) break;
      }
      final at =
          chosen ?? metric.getTangentForOffset(metric.length / 2)!.position;
      final rect = Rect.fromCenter(
          center: at, width: label.width + 12, height: label.height + 8);
      labels.add(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = const Color(0xfffffcf6));
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(ConceptConnectionPainter old) =>
      old.connections != connections ||
      old.boxes.toString() != boxes.toString() ||
      old.font != font;
}
