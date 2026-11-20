import 'dart:math';

import 'package:flutter/material.dart';

String newArtworkId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

List<double> pointJson(Offset point) => [point.dx, point.dy];

List<Offset> pointsFromJson(List<dynamic> points) => [
      for (final point in points)
        Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
    ];

class Artwork {
  const Artwork({
    required this.id,
    required this.title,
    required this.format,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  factory Artwork.fromJson(Map<String, dynamic> json) => Artwork(
        id: json['id'] as String,
        title: json['title'] as String,
        format: json['format'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String title;
  final String format;
  final int width;
  final int height;
  final DateTime createdAt;

  double get aspectRatio => width / height;

  Artwork renamed(String name) => Artwork(
        id: id,
        title: name,
        format: format,
        width: width,
        height: height,
        createdAt: createdAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'format': format,
        'width': width,
        'height': height,
        'createdAt': createdAt.toIso8601String(),
        'privacy': 'private',
      };
}

enum RegionGroup {
  head('头面部'),
  torso('躯干'),
  arms('上肢'),
  legs('下肢'),
  object('普通物体');

  const RegionGroup(this.label);
  final String label;
}

enum RegionSource {
  detected('AI 候选'),
  proposed('待确认'),
  manual('手动标注'),
  confirmed('已确认');

  const RegionSource(this.label);
  final String label;
  bool get isAutomatic => this == detected || this == proposed;
}

enum TouchGesture {
  tap('点击'),
  hold('长按'),
  swipe('滑动');

  const TouchGesture(this.label);
  final String label;
}

enum TouchAction {
  highlight('高亮区域'),
  pulse('区域脉冲动画'),
  sound('短提示音'),
  vibration('轻震动'),
  learning('打开学习模块'),
  books('打开书籍下载');

  const TouchAction(this.label);
  final String label;
}

class ImageRegion {
  const ImageRegion({
    required this.id,
    required this.label,
    required this.group,
    required this.polygon,
    this.source = RegionSource.manual,
    this.confidence,
    this.parentId,
    this.targetId,
    this.priority = 0,
    this.enabled = true,
    this.edited = false,
    this.rules = const {},
  });

  factory ImageRegion.fromJson(Map<String, dynamic> json) => ImageRegion(
        id: json['id'] as String,
        label: json['label'] as String,
        group: RegionGroup.values.byName(json['group'] as String),
        polygon: pointsFromJson(json['polygon'] as List),
        source: RegionSource.values.byName(json['source'] as String),
        confidence: (json['confidence'] as num?)?.toDouble(),
        parentId: json['parentId'] as String?,
        targetId: json['targetId'] as String?,
        priority: json['priority'] as int? ?? 0,
        enabled: json['enabled'] as bool? ?? true,
        edited: json['edited'] as bool? ?? false,
        rules: {
          for (final gesture in TouchGesture.values)
            for (final action in TouchAction.values)
              if ((json['rules'] as Map?)?[gesture.name] == action.name)
                gesture: action,
        },
      );

  final String id;
  final String label;
  final RegionGroup group;
  final List<Offset> polygon;
  final RegionSource source;
  final double? confidence;
  final String? parentId;
  final String? targetId;
  final int priority;
  final bool enabled;
  final bool edited;
  final Map<TouchGesture, TouchAction> rules;

  ImageRegion copyWith({
    String? label,
    RegionGroup? group,
    List<Offset>? polygon,
    RegionSource? source,
    int? priority,
    bool? enabled,
    bool? edited,
    Map<TouchGesture, TouchAction>? rules,
  }) =>
      ImageRegion(
        id: id,
        label: label ?? this.label,
        group: group ?? this.group,
        polygon: polygon ?? this.polygon,
        source: source ?? this.source,
        confidence: confidence,
        parentId: parentId,
        targetId: targetId,
        priority: priority ?? this.priority,
        enabled: enabled ?? this.enabled,
        edited: edited ?? this.edited,
        rules: rules ?? this.rules,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'group': group.name,
        'polygon': polygon.map(pointJson).toList(),
        'source': source.name,
        'confidence': confidence,
        'parentId': parentId,
        'targetId': targetId,
        'priority': priority,
        'enabled': enabled,
        'edited': edited,
        'rules':
            rules.map((gesture, action) => MapEntry(gesture.name, action.name)),
      };
}

class PolygonDraft {
  const PolygonDraft(this.regionId, this.points);

  factory PolygonDraft.fromJson(Map<String, dynamic> json) => PolygonDraft(
      json['regionId'] as String?, pointsFromJson(json['points'] as List));

  final String? regionId;
  final List<Offset> points;

  Map<String, Object?> toJson() => {
        'regionId': regionId,
        'points': points.map(pointJson).toList(),
      };
}

class ArtworkEdits {
  const ArtworkEdits({
    this.regions = const [],
    this.targetId,
    this.lastAnalysisId,
    this.dismissed = const {},
    this.draft,
  });

  factory ArtworkEdits.fromJson(Map<String, dynamic> json) => ArtworkEdits(
        regions: [
          for (final region in json['regions'] as List)
            ImageRegion.fromJson(region)
        ],
        targetId: json['targetId'] as String?,
        lastAnalysisId: json['lastAnalysisId'] as String?,
        dismissed: Set<String>.from(json['dismissed'] as List? ?? const []),
        draft:
            json['draft'] == null ? null : PolygonDraft.fromJson(json['draft']),
      );

  final List<ImageRegion> regions;
  final String? targetId;
  final String? lastAnalysisId;
  final Set<String> dismissed;
  final PolygonDraft? draft;

  List<ImageRegion> get visibleRegions => [
        for (final region in regions)
          if (region.targetId == null || region.targetId == targetId) region,
      ];

  ArtworkEdits withDraft(PolygonDraft? value) => ArtworkEdits(
        regions: regions,
        targetId: targetId,
        lastAnalysisId: lastAnalysisId,
        dismissed: dismissed,
        draft: value,
      );

  ArtworkEdits withRegions(List<ImageRegion> value, {Set<String>? dismissed}) =>
      ArtworkEdits(
        regions: value,
        targetId: targetId,
        lastAnalysisId: lastAnalysisId,
        dismissed: dismissed ?? this.dismissed,
        draft: draft,
      );

  ArtworkEdits withTarget(
      String target, String runId, List<ImageRegion> detected) {
    final retained = regions
        .where((region) =>
            region.targetId != target ||
            !region.source.isAutomatic ||
            region.edited)
        .toList();
    final existing = retained.map((region) => region.id).toSet();
    return ArtworkEdits(
      targetId: target,
      lastAnalysisId: runId,
      dismissed: dismissed,
      regions: [
        ...retained,
        ...detected.where((region) =>
            !existing.contains(region.id) && !dismissed.contains(region.id)),
      ],
    );
  }

  ArtworkEdits resetRecognition() => ArtworkEdits(
        regions: regions
            .where((region) => !region.source.isAutomatic || region.edited)
            .toList(),
        targetId: targetId,
      );

  Map<String, Object?> toJson() => {
        'version': 1,
        'regions': regions.map((region) => region.toJson()).toList(),
        'targetId': targetId,
        'lastAnalysisId': lastAnalysisId,
        'dismissed': dismissed.toList(),
        'draft': draft?.toJson(),
      };
}

class FeedbackSettings {
  const FeedbackSettings({
    this.visual = true,
    this.sound = true,
    this.vibration = true,
  });

  factory FeedbackSettings.fromJson(Map<String, dynamic> json) =>
      FeedbackSettings(
        visual: json['visual'] as bool? ?? true,
        sound: json['sound'] as bool? ?? true,
        vibration: json['vibration'] as bool? ?? true,
      );

  final bool visual;
  final bool sound;
  final bool vibration;

  FeedbackSettings copyWith({bool? visual, bool? sound, bool? vibration}) =>
      FeedbackSettings(
        visual: visual ?? this.visual,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
      );

  Map<String, bool> toJson() =>
      {'visual': visual, 'sound': sound, 'vibration': vibration};
}
