import 'dart:math' as math;
import 'dart:ui';

bool conceptSegmentCrosses(Offset a, Offset b, Rect box) {
  if (a.dx == b.dx)
    return a.dx > box.left &&
        a.dx < box.right &&
        math.min(a.dy, b.dy) < box.bottom &&
        math.max(a.dy, b.dy) > box.top;
  if (a.dy == b.dy)
    return a.dy > box.top &&
        a.dy < box.bottom &&
        math.min(a.dx, b.dx) < box.right &&
        math.max(a.dx, b.dx) > box.left;
  return false;
}

/// A long new-to-old link follows empty channels, rather than passing through
/// an intermediate node and appearing to originate at that unrelated concept.
List<Offset> routeConceptConnection(
    String fromId, String toId, Map<String, Rect> boxes, Size size,
    {List<List<Offset>> occupied = const []}) {
  final from = boxes[fromId], to = boxes[toId];
  if (from == null || to == null) return [];
  const margin = 28.0;
  final obstacles = boxes.values.map((b) => b.inflate(7)).toList();
  bool blocked(Offset p) => obstacles.any((b) =>
      p.dx > b.left && p.dx < b.right && p.dy > b.top && p.dy < b.bottom);
  List<(Offset, Offset)> ports(Rect box) => [
        (box.centerRight, box.centerRight + const Offset(margin, 0)),
        (box.bottomCenter, box.bottomCenter + const Offset(0, margin)),
        (box.centerLeft, box.centerLeft - const Offset(margin, 0)),
        (box.topCenter, box.topCenter - const Offset(0, margin)),
      ]
          .where((p) => (Offset.zero & size).contains(p.$2) && !blocked(p.$2))
          .toList();
  final starts = ports(from), goals = ports(to);
  if (starts.isEmpty || goals.isEmpty) return [];
  final xs = <double>{0, size.width}, ys = <double>{0, size.height};
  for (final b in boxes.values) {
    xs.addAll([b.left - margin, b.center.dx, b.right + margin]);
    ys.addAll([b.top - margin, b.center.dy, b.bottom + margin]);
  }
  final x = xs.where((v) => v >= 0 && v <= size.width).toList()..sort();
  final y = ys.where((v) => v >= 0 && v <= size.height).toList()..sort();
  int key(Offset p) => x.indexOf(p.dx) * y.length + y.indexOf(p.dy);
  Offset point(int id) => Offset(x[id ~/ y.length], y[id % y.length]);
  final roots = {for (final p in starts) key(p.$2): p.$1};
  final targets = {for (final p in goals) key(p.$2): p.$1};
  double estimate(int id) {
    final p = point(id);
    return targets.keys.map((goal) {
      final d = point(goal) - p;
      return d.dx.abs() + d.dy.abs();
    }).reduce(math.min);
  }

  double congestion(Offset a, Offset b) {
    var penalty = 0.0;
    for (final route in occupied.reversed.take(12)) {
      for (var i = 1; i < route.length; i++) {
        final c = route[i - 1], d = route[i];
        if (a.dx == b.dx && c.dx == d.dx && a.dx == c.dx) {
          final overlap = math.min(math.max(a.dy, b.dy), math.max(c.dy, d.dy)) -
              math.max(math.min(a.dy, b.dy), math.min(c.dy, d.dy));
          if (overlap > 0) penalty += 40 + overlap * 2;
        } else if (a.dy == b.dy && c.dy == d.dy && a.dy == c.dy) {
          final overlap = math.min(math.max(a.dx, b.dx), math.max(c.dx, d.dx)) -
              math.max(math.min(a.dx, b.dx), math.min(c.dx, d.dx));
          if (overlap > 0) penalty += 40 + overlap * 2;
        }
      }
    }
    return penalty;
  }

  final cost = {
    for (final id in roots.keys) id: margin + congestion(roots[id]!, point(id))
  };
  final previous = <int, int>{}, open = roots.keys.toSet(), closed = <int>{};
  while (open.isNotEmpty) {
    final current = open.reduce(
        (a, b) => cost[a]! + estimate(a) <= cost[b]! + estimate(b) ? a : b);
    open.remove(current);
    if (targets.containsKey(current)) {
      final result = <Offset>[targets[current]!, point(current)];
      var at = current;
      while (previous.containsKey(at)) {
        at = previous[at]!;
        result.add(point(at));
      }
      result.add(roots[at]!);
      final ordered = result.reversed.toList(), simplified = <Offset>[];
      for (final p in ordered) {
        if (simplified.isNotEmpty && simplified.last == p) continue;
        if (simplified.length > 1) {
          final a = simplified[simplified.length - 2], b = simplified.last;
          if ((a.dx == b.dx && b.dx == p.dx) || (a.dy == b.dy && b.dy == p.dy))
            simplified.removeLast();
        }
        simplified.add(p);
      }
      return simplified;
    }
    closed.add(current);
    final ix = current ~/ y.length, iy = current % y.length;
    final neighbours = <int>[
      if (ix > 0) current - y.length,
      if (ix + 1 < x.length) current + y.length,
      if (iy > 0) current - 1,
      if (iy + 1 < y.length) current + 1,
    ];
    for (final next in neighbours) {
      if (closed.contains(next)) continue;
      final a = point(current), b = point(next);
      if (blocked(b) ||
          obstacles.any((box) => conceptSegmentCrosses(a, b, box))) continue;
      final d = b - a;
      var candidate =
          cost[current]! + d.dx.abs() + d.dy.abs() + congestion(a, b);
      if (previous[current] case final before?) {
        final prior = a - point(before);
        if ((prior.dx == 0) != (d.dx == 0)) candidate += 12;
      }
      if (candidate < (cost[next] ?? double.infinity)) {
        cost[next] = candidate;
        previous[next] = current;
        open.add(next);
      }
    }
  }
  return [];
}
