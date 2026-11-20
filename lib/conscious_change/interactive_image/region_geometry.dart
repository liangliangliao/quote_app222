import 'package:flutter/material.dart';

import 'artwork.dart';

Rect artworkRect(Size viewport, double aspectRatio) {
  final fitted = applyBoxFit(BoxFit.contain, Size(aspectRatio, 1), viewport);
  return Alignment.center.inscribe(fitted.destination, Offset.zero & viewport);
}

Offset? normalizedPoint(Offset scene, Rect image, {bool clamp = false}) {
  if (image.isEmpty || (!clamp && !image.contains(scene))) return null;
  return Offset(
    ((scene.dx - image.left) / image.width).clamp(0.0, 1.0),
    ((scene.dy - image.top) / image.height).clamp(0.0, 1.0),
  );
}

Offset imagePoint(Offset point, Rect image) => Offset(
    image.left + point.dx * image.width, image.top + point.dy * image.height);

Path regionPath(List<Offset> points, Rect image, {bool close = true}) => Path()
  ..addPolygon([for (final point in points) imagePoint(point, image)], close);

double _cross(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

double polygonArea(List<Offset> points) {
  var area = 0.0;
  for (var i = 0; i < points.length; i++) {
    area += _cross(Offset.zero, points[i], points[(i + 1) % points.length]);
  }
  return area.abs() / 2;
}

bool _onSegment(Offset start, Offset end, Offset point) =>
    _cross(start, end, point).abs() < 1e-10 &&
    (point - start).dx * (point - end).dx +
            (point - start).dy * (point - end).dy <=
        1e-10;

bool validPolygon(List<Offset> points) {
  if (points.length < 3 ||
      points.toSet().length != points.length ||
      polygonArea(points) < 0.000001) return false;
  for (var i = 0; i < points.length; i++) {
    final first = points[i];
    final second = points[(i + 1) % points.length];
    for (var j = i + 2; j < points.length; j++) {
      if (i == 0 && j == points.length - 1) continue;
      final third = points[j];
      final fourth = points[(j + 1) % points.length];
      if (_onSegment(first, second, third) ||
          _onSegment(first, second, fourth) ||
          _onSegment(third, fourth, first) ||
          _onSegment(third, fourth, second) ||
          (_cross(first, second, third) * _cross(first, second, fourth) < 0 &&
              _cross(third, fourth, first) * _cross(third, fourth, second) < 0))
        return false;
    }
  }
  return true;
}

List<Offset> convexHull(Iterable<Offset> points) {
  final sorted = points
      .map(
          (point) => Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0)))
      .toSet()
      .toList()
    ..sort(
        (a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx));
  if (sorted.length <= 2) return sorted;
  List<Offset> half(Iterable<Offset> ordered) {
    final hull = <Offset>[];
    for (final point in ordered) {
      while (hull.length >= 2 &&
          _cross(hull[hull.length - 2], hull.last, point) <= 0) {
        hull.removeLast();
      }
      hull.add(point);
    }
    return hull..removeLast();
  }

  return [...half(sorted), ...half(sorted.reversed)];
}

ImageRegion? hitRegion(Iterable<ImageRegion> regions, Offset point,
    {TouchGesture? gesture, bool editing = false}) {
  final map = {for (final region in regions) region.id: region};
  int depth(ImageRegion region) {
    final visited = {region.id};
    var parentId = region.parentId;
    while (parentId != null &&
        map.containsKey(parentId) &&
        visited.add(parentId)) {
      parentId = map[parentId]?.parentId;
    }
    return visited.length;
  }

  final matches = regions.where((region) {
    if (!editing &&
        (!region.enabled ||
            region.rules.isEmpty ||
            (gesture != null && !region.rules.containsKey(gesture))))
      return false;
    final points = region.polygon;
    return regionPath(points, const Rect.fromLTWH(0, 0, 1, 1))
            .contains(point) ||
        List.generate(points.length, (i) => i).any(
          (i) => _onSegment(points[i], points[(i + 1) % points.length], point),
        );
  }).toList();
  matches.sort((a, b) {
    final priority = b.priority.compareTo(a.priority);
    if (priority != 0) return priority;
    final level = depth(b).compareTo(depth(a));
    if (level != 0) return level;
    final area = polygonArea(a.polygon).compareTo(polygonArea(b.polygon));
    return area == 0 ? a.id.compareTo(b.id) : area;
  });
  return matches.isEmpty ? null : matches.first;
}
