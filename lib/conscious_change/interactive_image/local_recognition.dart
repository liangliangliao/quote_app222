import 'dart:math' as math;

import 'dart:ui' show Offset, Rect;

import 'package:flutter/services.dart' show MethodChannel;

import 'artwork.dart';
import 'region_geometry.dart';

const interactiveImageChannel =
    MethodChannel('com.example.quote_app/interactive_image');

class LocalRecognition {
  const LocalRecognition();

  Future<RecognitionResult> detect(
      String previewPath, String id, double aspectRatio) async {
    final result =
        await interactiveImageChannel.invokeMapMethod<String, dynamic>(
      'recognize',
      {'path': previewPath, 'id': id},
    );
    if (result == null) throw const FormatException();
    return RecognitionResult.fromJson({
      ...result,
      'id': id,
      'completedAt': DateTime.now().toIso8601String(),
      'processing': 'on-device',
    }, aspectRatio);
  }

  Future<void> cancel(String id) => interactiveImageChannel
      .invokeMethod<void>('cancelRecognition', {'id': id});
}

class RecognitionResult {
  RecognitionResult.fromJson(this.raw, double aspectRatio)
      : people = _CandidateBuilder(raw, aspectRatio).build();

  final Map<String, dynamic> raw;
  final List<RecognitionTarget> people;

  String get id => raw['id'] as String;
  String get model => raw['model'] as String;
  bool get partial => (raw['unavailable'] as List?)?.isNotEmpty ?? false;
}

class RecognitionTarget {
  const RecognitionTarget(this.id, this.bounds, this.regions,
      {required this.handOnly});
  final String id;
  final Rect bounds;
  final List<ImageRegion> regions;
  final bool handOnly;
}

class _Landmark {
  _Landmark(List point)
      : point =
            Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
        scores = [
          if (point[3] != null) point[3] as num,
          if (point[4] != null) point[4] as num
        ];
  final Offset point;
  final List<num> scores;

  bool get inImage =>
      point.dx >= 0 && point.dx <= 1 && point.dy >= 0 && point.dy <= 1;
  double? get confidence => scores.isEmpty
      ? null
      : scores.reduce(math.min).toDouble().clamp(0.0, 1.0);
  bool get visible => inImage && (confidence ?? 1) >= 0.35;
}

typedef _Landmarks = List<_Landmark>;

class _Person {
  _Person({this.pose, this.face, this.handOnly}) : hands = {};
  final _Landmarks? pose;
  _Landmarks? face;
  final _Landmarks? handOnly;
  final Map<String, _Landmarks> hands;

  Rect get bounds => _bounds([
        for (final points in [pose, face, handOnly, ...hands.values])
          if (points != null)
            for (final mark in points)
              if (mark.visible) mark.point,
      ]);
}

Rect _bounds(List<Offset> points) {
  if (points.isEmpty) return Rect.zero;
  var left = points.first.dx;
  var right = left;
  var top = points.first.dy;
  var bottom = top;
  for (final point in points.skip(1)) {
    left = math.min(left, point.dx);
    right = math.max(right, point.dx);
    top = math.min(top, point.dy);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

class _CandidateBuilder {
  _CandidateBuilder(this.raw, double aspectRatio)
      : xFactor = math.min(1, aspectRatio),
        yFactor = math.min(1, 1 / aspectRatio);
  final Map<String, dynamic> raw;
  final double xFactor;
  final double yFactor;

  List<_Landmarks> _points(String key, int minimum) => [
        for (final entry in raw[key] as List? ?? const [])
          if ((entry as List).length >= minimum)
            [for (final point in entry) _Landmark(point as List)],
      ];

  double _distance(Offset first, Offset second) =>
      Offset((first.dx - second.dx) * xFactor, (first.dy - second.dy) * yFactor)
          .distance;

  List<RecognitionTarget> build() {
    final people = [
      for (final pose in _points('pose', 33)) _Person(pose: pose)
    ];
    for (final face in _points('face', 468)) {
      if (!face[1].visible) continue;
      final faceBounds = _bounds([
        for (final point in face)
          if (point.visible) point.point
      ]);
      final tolerance = math.max(
          0.025, _distance(faceBounds.topLeft, faceBounds.bottomRight) * 0.65);
      final person = _closest<_Person>(
          people.where((person) => person.pose != null), (person) {
        final nose = person.pose![0];
        if (!nose.visible) return double.infinity;
        return _distance(nose.point, face[1].point);
      }, tolerance);
      if (person == null || person.face != null) {
        // An overlapping face can belong to a pose with hidden landmarks. Keep it separate.
        people.add(_Person(face: face));
      } else {
        person.face = face;
      }
    }
    final wrists = [
      for (final person in people)
        if (person.pose != null)
          for (final (side, index) in [('left', 15), ('right', 16)])
            if (person.pose![index].visible)
              (person, side, person.pose![index].point),
    ];
    final isolatedHands = <_Person>[];
    for (final hand in _points('hand', 21)) {
      if (!hand.first.visible) continue;
      final size = _distance(hand.first.point, hand[9].point);
      final owner = _closest(
          wrists,
          (wrist) => _distance(wrist.$3, hand.first.point),
          math.max(0.025, size));
      if (owner != null) {
        owner.$1.hands.putIfAbsent(owner.$2, () => hand);
      } else {
        isolatedHands.add(_Person(handOnly: hand));
      }
    }
    if (people.isEmpty) people.addAll(isolatedHands);
    people.removeWhere((person) => person.bounds.isEmpty);
    people.sort((a, b) {
      final x = a.bounds.center.dx.compareTo(b.bounds.center.dx);
      return x == 0 ? a.bounds.center.dy.compareTo(b.bounds.center.dy) : x;
    });
    return [
      for (var i = 0; i < people.length; i++)
        if (_target(people[i], 'target-$i') case final target?) target,
    ];
  }

  T? _closest<T>(
      Iterable<T> choices, double Function(T) distance, double limit) {
    T? nearest;
    var first = limit;
    var second = double.infinity;
    for (final choice in choices) {
      final length = distance(choice);
      if (length < first) {
        if (nearest != null) second = first;
        first = length;
        nearest = choice;
      } else {
        second = math.min(second, length);
      }
    }
    return second < first * 1.3 ? null : nearest;
  }

  RecognitionTarget? _target(_Person person, String id) {
    final regions = <ImageRegion>[];
    void add(String key, String name, RegionGroup group, List<Offset> samples,
        {String? parent, double? confidence}) {
      final polygon = convexHull(samples);
      if (polygon.length < 3 || polygonArea(polygon) < 0.000001) return;
      final parentId = parent == null ? null : '$id-$parent';
      regions.add(ImageRegion(
        id: '$id-$key',
        label: name,
        group: group,
        polygon: polygon,
        source: confidence != null && confidence >= 0.72
            ? RegionSource.detected
            : RegionSource.proposed,
        confidence: confidence,
        targetId: id,
        parentId:
            regions.any((region) => region.id == parentId) ? parentId : null,
      ));
    }

    final pose = person.pose;
    final face = person.face;
    const head = RegionGroup.head;
    if (face != null) {
      List<Offset> facePoints(List<int> indices) => [
            for (final i in indices)
              if (face[i].visible) face[i].point
          ];
      add(
          'head',
          '头面部',
          head,
          facePoints([
            10,
            338,
            297,
            332,
            454,
            323,
            361,
            379,
            152,
            150,
            132,
            93,
            234,
            103,
            67,
            109
          ]));
      add('left-eye', '左眼', head, facePoints([362, 385, 387, 263, 373, 380]),
          parent: 'head');
      add('right-eye', '右眼', head, facePoints([33, 160, 158, 133, 153, 144]),
          parent: 'head');
      add('nose', '鼻部', head, facePoints([168, 98, 2, 327, 4]), parent: 'head');
      add('mouth', '嘴部', head, facePoints([61, 40, 0, 270, 291, 321, 17, 91]),
          parent: 'head');
    } else if (pose != null && pose[0].visible) {
      final marks = [
        for (final i in [0, 2, 5, 7, 8, 9, 10])
          if (pose[i].visible) pose[i]
      ];
      final frame = _bounds(marks.map((mark) => mark.point).toList());
      if (marks.length >= 3 && !frame.isEmpty) {
        final padded = Rect.fromLTRB(
            frame.left - frame.width * 0.22,
            frame.top - frame.height * 0.65,
            frame.right + frame.width * 0.22,
            frame.bottom + frame.height * 0.35);
        add(
            'head',
            '头面部',
            head,
            [
              padded.topLeft,
              padded.topRight,
              padded.bottomRight,
              padded.bottomLeft
            ],
            confidence: _confidence(marks));
      }
    }

    if (pose != null) {
      final torso = [pose[11], pose[12], pose[24], pose[23]];
      if (torso.every((mark) => mark.visible)) {
        add('torso', '躯干', RegionGroup.torso,
            [for (final mark in torso) mark.point],
            confidence: _confidence(torso));
      }
      void limb(String key, String name, RegionGroup group, int from, int to,
          double thickness) {
        final points = [pose[from], pose[to]];
        if (points.every((point) => point.visible)) {
          add(key, name, group,
              _limb(points.first.point, points.last.point, thickness),
              confidence: _confidence(points));
        }
      }

      for (final (side, label, offset) in [
        ('left', '左', 0),
        ('right', '右', 1)
      ]) {
        limb('$side-arm', '$label上臂', RegionGroup.arms, 11 + offset,
            13 + offset, 0.18);
        limb('$side-forearm', '$label前臂', RegionGroup.arms, 13 + offset,
            15 + offset, 0.15);
        limb('$side-thigh', '$label大腿', RegionGroup.legs, 23 + offset,
            25 + offset, 0.23);
        limb('$side-shin', '$label小腿', RegionGroup.legs, 25 + offset,
            27 + offset, 0.16);
        limb('$side-foot', '$label足部', RegionGroup.legs, 29 + offset,
            31 + offset, 0.23);
        final hand = person.hands[side];
        if (hand != null) {
          add(
              '$side-hand',
              '$label手部',
              RegionGroup.arms,
              [
                for (final point in hand)
                  if (point.visible) point.point
              ],
              parent: '$side-forearm');
        } else {
          final marks = [
            pose[15 + offset],
            pose[17 + offset],
            pose[19 + offset],
            pose[21 + offset]
          ];
          if (marks.first.visible &&
              marks.where((mark) => mark.visible).length >= 3) {
            add(
                '$side-hand',
                '$label手部',
                RegionGroup.arms,
                [
                  for (final mark in marks)
                    if (mark.visible) mark.point
                ],
                parent: '$side-forearm',
                confidence: _confidence(marks.where((mark) => mark.visible)));
          }
        }
      }
    }
    final handOnly = person.handOnly;
    if (handOnly != null) {
      add('hand', '手部', RegionGroup.arms, [
        for (final point in handOnly)
          if (point.visible) point.point
      ]);
    }
    if (regions.isEmpty) return null;
    return RecognitionTarget(id, person.bounds, regions,
        handOnly: handOnly != null);
  }

  double? _confidence(Iterable<_Landmark> marks) {
    final values = [for (final mark in marks) mark.confidence];
    if (values.any((value) => value == null)) return null;
    return values.cast<double>().reduce(math.min);
  }

  List<Offset> _limb(Offset start, Offset end, double thickness) {
    final delta =
        Offset((end.dx - start.dx) * xFactor, (end.dy - start.dy) * yFactor);
    if (delta.distance < 0.006) return const [];
    final along = (end - start) * 0.12;
    final across = Offset(-delta.dy / xFactor, delta.dx / yFactor) * thickness;
    return [
      start - along,
      start + across,
      end + across,
      end + along,
      end - across,
      start - across
    ];
  }
}
