import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

typedef Json = Map<String, dynamic>;

/// Every item belongs to one case and one episode. Inferences never replace facts.
enum NodeKind {
  evidence,
  understanding,
  want,
  belief,
  motive,
  reframe,
  route,
  routeFit,
  graphEdge,
  conflict,
  deliberation,
  graphShift,
  consequence,
  obstacle,
  taskRequirement,
  capability,
  supportVariant,
  resourceConflict,
  tradeoff,
  preflight,
  intervention,
  interventionExecution,
  scene,
  sceneFeedback,
  plan,
  seal,
  trigger,
  triggerCheck,
  reappraisal,
  awareness,
  decision,
  opportunity,
  attempt,
  observation,
  acquisition,
  experience,
  review,
  repair,
  insight,
  manifestation,
  principle,
  principleMatch,
  principleApplication,
  changeability,
  strengthMatch,
  boundaryReview,
  recommendation,
  feedback,
  reminder,
  permission,
  revision,
}

enum EvidenceOrigin {
  selfReport,
  authorizedObservation,
  deviceEvent,
  aiHypothesis,
  productRule
}

enum TimePhase { t0, t1, t2, t3, unknown }

enum NodeStatus { active, draft, accepted, rejected, stale, retracted, retired }

enum CaseStage {
  newCase,
  understood,
  reframed,
  preflight,
  sealed,
  waiting,
  triggered,
  observed,
  revealed,
  revised,
  paused,
  triggerMissed,
  conditionsChanged,
  noObservation
}

String newId([String prefix = 'wm']) {
  final random = Random.secure();
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${List.generate(10, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

dynamic _freeze(dynamic value) {
  if (value is Map)
    return UnmodifiableMapView<String, dynamic>(
        value.map((key, dynamic v) => MapEntry(key.toString(), _freeze(v))));
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

Json jsonMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<String> stringList(dynamic value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
DateTime? parseTime(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

String canonicalJson(dynamic value) {
  dynamic sort(dynamic item) {
    if (item is Map) {
      final keys = item.keys.map((e) => e.toString()).toList()..sort();
      return <String, dynamic>{for (final key in keys) key: sort(item[key])};
    }
    if (item is List) return item.map(sort).toList();
    return item;
  }

  return jsonEncode(sort(value));
}

String digest(dynamic value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();

/// Body is validated by the per-kind schema (schema.dart), never an arbitrary
/// model blob. A ledger format keeps the numerous PRD views on one fact source.
class MirrorNode {
  MirrorNode({
    required this.id,
    required this.caseId,
    required this.episodeId,
    required this.kind,
    required this.origin,
    required this.phase,
    required this.recordedAt,
    this.knownAt,
    this.happenedAt,
    required Json body,
    List<String> evidenceIds = const [],
    List<String> counterIds = const [],
    List<String> links = const [],
    this.status = NodeStatus.active,
    this.revisionOf,
  })  : body = _freeze(body) as Json,
        evidenceIds = List.unmodifiable(evidenceIds),
        counterIds = List.unmodifiable(counterIds),
        links = List.unmodifiable(links);

  final String id, caseId, episodeId;
  final NodeKind kind;
  final EvidenceOrigin origin;
  final TimePhase phase;
  final DateTime recordedAt;
  final DateTime? knownAt, happenedAt;
  final Json body;
  final List<String> evidenceIds, counterIds, links;
  final NodeStatus status;
  final String? revisionOf;

  String text(String key, [String fallback = '']) =>
      body[key] is String ? body[key] as String : fallback;
  List<String> strings(String key) => stringList(body[key]);
  List<Json> objects(String key) => body[key] is List
      ? (body[key] as List).whereType<Map>().map(jsonMap).toList()
      : const [];
  Json object(String key) => jsonMap(body[key]);
  bool flag(String key) => body[key] == true;
  num? number(String key) => body[key] is num ? body[key] as num : null;
  bool get usable => !{
        NodeStatus.rejected,
        NodeStatus.retracted,
        NodeStatus.stale,
        NodeStatus.retired
      }.contains(status);
  bool get isFact =>
      origin == EvidenceOrigin.selfReport ||
      origin == EvidenceOrigin.authorizedObservation;

  Set<String> get dependencies {
    final result = <String>{...evidenceIds, ...counterIds, ...links};
    void walk(dynamic value) {
      if (value is Map) {
        value.forEach((key, dynamic v) {
          if (key.toString().endsWith('Id') &&
              !(kind == NodeKind.permission && key == 'runId') &&
              v is String &&
              v.isNotEmpty) result.add(v);
          if (key.toString().endsWith('Ids') &&
              v is List &&
              !(kind == NodeKind.permission && key == 'sourceCaseIds'))
            result.addAll(v.whereType<String>());
          if (v is Map || v is List) walk(v);
        });
      } else if (value is List) {
        for (final v in value) {
          walk(v);
        }
      }
    }

    // Snapshots contain original foreign keys and are linked explicitly. They
    // must not make later records look like current claims.
    if (kind != NodeKind.seal && kind != NodeKind.deliberation) walk(body);
    result.remove(id);
    return result;
  }

  MirrorNode withStatus(NodeStatus value, {bool redact = false}) => MirrorNode(
      id: id,
      caseId: caseId,
      episodeId: episodeId,
      kind: kind,
      origin: origin,
      phase: phase,
      recordedAt: recordedAt,
      knownAt: knownAt,
      happenedAt: happenedAt,
      body: redact ? {'redacted': true} : body,
      evidenceIds: evidenceIds,
      counterIds: counterIds,
      links: links,
      status: value,
      revisionOf: revisionOf);

  Json toJson() => {
        'id': id,
        'caseId': caseId,
        'episodeId': episodeId,
        'kind': kind.name,
        'origin': origin.name,
        'phase': phase.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'knownAt': knownAt?.toUtc().toIso8601String(),
        'happenedAt': happenedAt?.toUtc().toIso8601String(),
        'body': body,
        'evidenceIds': evidenceIds,
        'counterIds': counterIds,
        'links': links,
        'status': status.name,
        'revisionOf': revisionOf
      };

  factory MirrorNode.fromJson(Json json) => MirrorNode(
      id: json['id'] as String,
      caseId: json['caseId'] as String,
      episodeId: json['episodeId'] as String,
      kind: NodeKind.values.byName(json['kind'] as String),
      origin: EvidenceOrigin.values.byName(json['origin'] as String),
      phase: TimePhase.values.byName(json['phase'] as String),
      recordedAt: parseTime(json['recordedAt'])!,
      knownAt: parseTime(json['knownAt']),
      happenedAt: parseTime(json['happenedAt']),
      body: jsonMap(json['body']),
      evidenceIds: stringList(json['evidenceIds']),
      counterIds: stringList(json['counterIds']),
      links: stringList(json['links']),
      status: NodeStatus.values.byName(json['status'] as String),
      revisionOf: json['revisionOf'] as String?);
}

class CaseFile {
  CaseFile({
    required this.id,
    required this.issue,
    required this.createdAt,
    required this.updatedAt,
    required this.episodeId,
    this.revision = 0,
    this.stage = CaseStage.newCase,
    this.step = 0,
    this.cycle = 1,
    List<MirrorNode> nodes = const [],
    this.selectedRouteId,
    List<String> selectedMotiveIds = const [],
    this.retrospective = false,
    this.analysisMessage = '',
    this.schemaVersion = 1,
  })  : nodes = List.unmodifiable(nodes),
        selectedMotiveIds = List.unmodifiable(selectedMotiveIds);

  final String id, issue, episodeId, analysisMessage;
  final int revision, step, cycle, schemaVersion;
  final DateTime createdAt, updatedAt;
  final CaseStage stage;
  final List<MirrorNode> nodes;
  final String? selectedRouteId;
  final List<String> selectedMotiveIds;
  final bool retrospective;

  MirrorNode? node(String? id) {
    if (id == null) return null;
    for (final n in nodes.reversed) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<MirrorNode> current(NodeKind kind,
      {bool allEpisodes = false, bool usableOnly = true}) {
    final superseded =
        nodes.map((n) => n.revisionOf).whereType<String>().toSet();
    return nodes
        .where((n) =>
            n.kind == kind &&
            !superseded.contains(n.id) &&
            (allEpisodes || n.episodeId == episodeId) &&
            (!usableOnly || n.usable))
        .toList(growable: false);
  }

  MirrorNode? latest(NodeKind kind, {bool allEpisodes = false}) {
    final items = current(kind, allEpisodes: allEpisodes);
    return items.isEmpty ? null : items.last;
  }

  List<MirrorNode> get facts => nodes
      .where((n) => n.isFact && n.usable && n.kind != NodeKind.permission)
      .toList();
  TimePhase get phase {
    if (current(NodeKind.experience).isNotEmpty) return TimePhase.t3;
    if (retrospective || current(NodeKind.observation).isNotEmpty)
      return TimePhase.t2;
    if (current(NodeKind.triggerCheck)
        .any((n) => {'confirmed', 'changed'}.contains(n.text('state'))))
      return TimePhase.t1;
    return TimePhase.t0;
  }

  String get phaseLabel => switch (stage) {
        CaseStage.waiting ||
        CaseStage.sealed ||
        CaseStage.triggerMissed =>
          '等待条件',
        CaseStage.triggered || CaseStage.conditionsChanged => '已到现场',
        CaseStage.observed ||
        CaseStage.revealed ||
        CaseStage.revised ||
        CaseStage.noObservation =>
          '事后回望',
        CaseStage.paused => '已暂缓',
        _ => retrospective ? '事后回望' : '事前准备',
      };

  CaseFile evolve(
          {List<MirrorNode>? nodes,
          CaseStage? stage,
          int? step,
          String? selectedRouteId,
          List<String>? selectedMotiveIds,
          String? episodeId,
          int? cycle,
          String? analysisMessage,
          bool clearRoute = false,
          String? issue,
          bool? retrospective,
          DateTime? now,
          int? revision}) =>
      CaseFile(
          id: id,
          issue: issue ?? this.issue,
          createdAt: createdAt,
          updatedAt: (now ?? DateTime.now()).toUtc(),
          revision: revision ?? this.revision + 1,
          episodeId: episodeId ?? this.episodeId,
          stage: stage ?? this.stage,
          step: step ?? this.step,
          cycle: cycle ?? this.cycle,
          nodes: nodes ?? this.nodes,
          selectedRouteId:
              clearRoute ? null : selectedRouteId ?? this.selectedRouteId,
          selectedMotiveIds: selectedMotiveIds ?? this.selectedMotiveIds,
          retrospective: retrospective ?? this.retrospective,
          analysisMessage: analysisMessage ?? this.analysisMessage,
          schemaVersion: schemaVersion);

  Json toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'issue': issue,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'revision': revision,
        'episodeId': episodeId,
        'stage': stage.name,
        'step': step,
        'cycle': cycle,
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'selectedRouteId': selectedRouteId,
        'selectedMotiveIds': selectedMotiveIds,
        'retrospective': retrospective,
        'analysisMessage': analysisMessage
      };

  factory CaseFile.fromJson(Json json) {
    if (json['schemaVersion'] != 1)
      throw const FormatException('不支持的数据版本；未覆盖原数据');
    return CaseFile(
        id: json['id'] as String,
        issue: json['issue'] as String,
        createdAt: parseTime(json['createdAt'])!,
        updatedAt: parseTime(json['updatedAt'])!,
        revision: json['revision'] as int,
        episodeId: json['episodeId'] as String,
        stage: CaseStage.values.byName(json['stage'] as String),
        step: json['step'] as int,
        cycle: json['cycle'] as int,
        nodes: (json['nodes'] as List)
            .map((e) => MirrorNode.fromJson(jsonMap(e)))
            .toList(),
        selectedRouteId: json['selectedRouteId'] as String?,
        selectedMotiveIds: stringList(json['selectedMotiveIds']),
        retrospective: json['retrospective'] == true,
        analysisMessage: (json['analysisMessage'] ?? '') as String);
  }
}

class MirrorSettings {
  const MirrorSettings(
      {this.animations = true,
      this.sound = false,
      this.haptics = false,
      this.remoteScoring = false,
      this.gatewayUrl = '',
      this.gatewayAccessToken = '',
      this.weights = const [0.35, 0.25, 0.25, 0.15],
      this.crossCaseIds = const [],
      this.darkMode = 'system'});
  final bool animations, sound, haptics, remoteScoring;
  final String gatewayUrl, gatewayAccessToken, darkMode;
  final List<double> weights;
  final List<String> crossCaseIds;
  Json toJson() => {
        'animations': animations,
        'sound': sound,
        'haptics': haptics,
        'remoteScoring': remoteScoring,
        'gatewayUrl': gatewayUrl,
        'gatewayAccessToken': gatewayAccessToken,
        'weights': weights,
        'crossCaseIds': crossCaseIds,
        'darkMode': darkMode
      };
  factory MirrorSettings.fromJson(Json j) => MirrorSettings(
      animations: j['animations'] != false,
      sound: j['sound'] == true,
      haptics: j['haptics'] == true,
      remoteScoring: j['remoteScoring'] == true,
      gatewayUrl: (j['gatewayUrl'] ?? '') as String,
      gatewayAccessToken: (j['gatewayAccessToken'] ?? '') as String,
      weights: j['weights'] is List
          ? (j['weights'] as List).map((v) => (v as num).toDouble()).toList()
          : const [0.35, 0.25, 0.25, 0.15],
      crossCaseIds: stringList(j['crossCaseIds']),
      darkMode: (j['darkMode'] ?? 'system') as String);
  MirrorSettings change(Json changes) =>
      MirrorSettings.fromJson({...toJson(), ...changes});
}

class MirrorProblem implements Exception {
  const MirrorProblem(this.message, {this.code = 'invalid_operation'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

class VersionConflict extends MirrorProblem {
  const VersionConflict() : super('这份课题已有新记录，已保留新版本。请重新查看后继续。');
}
