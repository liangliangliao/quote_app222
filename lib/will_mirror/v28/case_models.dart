import 'dart:convert';

/// The v2.8 aggregate extends wm_goal: caseId is always the existing goal ID.
/// All payloads live in the same encrypted Vault; no parallel personality DB.
typedef WmJson = Map<String, dynamic>;

WmJson wmMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : {};
List<WmJson> wmMaps(Object? v) => v is List ? v.map(wmMap).toList() : [];
List<String> wmStrings(Object? v) =>
    v is List ? v.whereType<String>().toList() : [];
int wmInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String wmText(Object? v, [String fallback = '']) => v is String ? v : fallback;
T wmEnum<T extends Enum>(List<T> values, Object? v, T fallback) =>
    values.firstWhere((e) => e.name == v, orElse: () => fallback);
WmJson wmClone(WmJson v) => wmMap(jsonDecode(jsonEncode(v)));

enum WmPhase { t0, t1, t2, t3 }

enum WmFactKind {
  statement,
  fact,
  belief,
  feeling,
  unknown,
  preparation,
  attempt,
  observation,
  capability
}

enum WmFactStatus { reported, verified, hypothesis, unknown, refuted, revoked }

enum WmGate { clear, verifyFirst, blocked }

enum WmPrincipleStatus {
  draft,
  accepted,
  needsReview,
  rejected,
  retired,
  revoked
}

extension WmPhaseLabel on WmPhase {
  String get label => ['事前准备', '现场核实', '行动与结果', '后续体验'][index];
}

extension WmKindLabel on WmFactKind {
  String get label => [
        '用户原话',
        '事实',
        '信念 / 预测',
        '感受',
        '尚未知',
        '实际准备',
        '真实尝试',
        '观察结果',
        '任务能力证据'
      ][index];
}

extension WmStatusLabel on WmFactStatus {
  String get label => ['本人报告', '本人已核实', '候选解释', '未知', '已有反证', '已撤回'][index];
}

extension WmGateLabel on WmGate {
  String get label => ['已核实可用', '先核实条件', '暂停此路线'][index];
}

extension WmPrincipleStatusLabel on WmPrincipleStatus {
  String get label =>
      ['候选，未认可', '本人认可，仍可检验', '需重新核实', '不适用 / 拒绝', '已归档', '证据已撤回'][index];
}

class WmEvidence {
  const WmEvidence(
      {required this.id,
      required this.text,
      required this.kind,
      required this.phase,
      required this.knownAt,
      required this.recordedAt,
      this.happenedAt,
      this.status = WmFactStatus.reported,
      this.source = 'user_report',
      this.context = '',
      this.supersedesId,
      this.legacyId,
      this.independent = false});
  final String id, text, source, context;
  final WmFactKind kind;
  final WmFactStatus status;
  final WmPhase phase;
  final int knownAt, recordedAt;
  final int? happenedAt;
  final String? supersedesId, legacyId;
  final bool independent;
  bool get usable =>
      status != WmFactStatus.revoked && status != WmFactStatus.refuted;
  bool get factual =>
      usable &&
      (status == WmFactStatus.reported || status == WmFactStatus.verified) &&
      kind != WmFactKind.belief &&
      kind != WmFactKind.unknown;
  WmJson toJson() => {
        'id': id,
        'text': text,
        'kind': kind.name,
        'status': status.name,
        'phase': phase.name,
        'knownAt': knownAt,
        'recordedAt': recordedAt,
        'happenedAt': happenedAt,
        'source': source,
        'context': context,
        'supersedesId': supersedesId,
        'legacyId': legacyId,
        'independent': independent
      };
  factory WmEvidence.fromJson(WmJson j) => WmEvidence(
      id: wmText(j['id']),
      text: wmText(j['text']),
      kind: wmEnum(WmFactKind.values, j['kind'], WmFactKind.unknown),
      status: wmEnum(WmFactStatus.values, j['status'], WmFactStatus.unknown),
      phase: wmEnum(WmPhase.values, j['phase'], WmPhase.t2),
      knownAt: wmInt(j['knownAt']),
      recordedAt: wmInt(j['recordedAt']),
      happenedAt: j['happenedAt'] as int?,
      source: wmText(j['source'], 'user_report'),
      context: wmText(j['context']),
      supersedesId: j['supersedesId'] as String?,
      legacyId: j['legacyId'] as String?,
      independent: j['independent'] == true);
  WmEvidence revoke() => WmEvidence.fromJson(
      {...toJson(), 'text': '', 'context': '', 'status': 'revoked'});
}

class WmWant {
  const WmWant(
      {required this.id,
      required this.claim,
      required this.evidenceIds,
      this.counterIds = const [],
      this.context = '',
      this.alternative = '',
      this.nextTest = '',
      this.status = 'tentative',
      this.origin = 'anticipated_outcome'});
  final String id, claim, context, alternative, nextTest, status, origin;
  final List<String> evidenceIds, counterIds;
  WmJson toJson() => {
        'id': id,
        'claim': claim,
        'evidenceIds': evidenceIds,
        'counterIds': counterIds,
        'context': context,
        'alternative': alternative,
        'nextTest': nextTest,
        'status': status,
        'origin': origin
      };
  factory WmWant.fromJson(WmJson j) => WmWant(
      id: wmText(j['id']),
      claim: wmText(j['claim']),
      evidenceIds: wmStrings(j['evidenceIds']),
      counterIds: wmStrings(j['counterIds']),
      context: wmText(j['context']),
      alternative: wmText(j['alternative']),
      nextTest: wmText(j['nextTest']),
      status: wmText(j['status'], 'tentative'),
      origin: wmText(j['origin'], 'unknown'));
}

class WmRoute {
  const WmRoute(
      {required this.id,
      required this.title,
      required this.action,
      this.wantIds = const [],
      this.evidenceIds = const [],
      this.near = '未知',
      this.far = '未知',
      this.wantFit = '未知',
      this.capabilityFit = '未知',
      this.feasibility = 'unknown',
      this.difficulty,
      this.gate = WmGate.verifyFirst,
      this.risk = '',
      this.requirement = '',
      this.support = '',
      this.falsifier = '',
      this.protective = false});
  final String id,
      title,
      action,
      near,
      far,
      wantFit,
      capabilityFit,
      feasibility,
      risk,
      requirement,
      support,
      falsifier;
  final List<String> wantIds, evidenceIds;
  final int? difficulty;
  final WmGate gate;
  final bool protective;
  bool get canCommit => gate == WmGate.clear && feasibility != 'infeasible';
  WmJson toJson() => {
        'id': id,
        'title': title,
        'action': action,
        'wantIds': wantIds,
        'evidenceIds': evidenceIds,
        'near': near,
        'far': far,
        'wantFit': wantFit,
        'capabilityFit': capabilityFit,
        'feasibility': feasibility,
        'difficulty': difficulty,
        'gate': gate.name,
        'risk': risk,
        'requirement': requirement,
        'support': support,
        'falsifier': falsifier,
        'protective': protective
      };
  factory WmRoute.fromJson(WmJson j) => WmRoute(
      id: wmText(j['id']),
      title: wmText(j['title']),
      action: wmText(j['action']),
      wantIds: wmStrings(j['wantIds']),
      evidenceIds: wmStrings(j['evidenceIds']),
      near: wmText(j['near'], '未知'),
      far: wmText(j['far'], '未知'),
      wantFit: wmText(j['wantFit'], '未知'),
      capabilityFit: wmText(j['capabilityFit'], '未知'),
      feasibility: wmText(j['feasibility'], 'unknown'),
      difficulty: j['difficulty'] as int?,
      gate: wmEnum(WmGate.values, j['gate'], WmGate.verifyFirst),
      risk: wmText(j['risk']),
      requirement: wmText(j['requirement']),
      support: wmText(j['support']),
      falsifier: wmText(j['falsifier']),
      protective: j['protective'] == true);
}

class WmMotive {
  const WmMotive(
      {required this.id,
      required this.text,
      required this.directionByRoute,
      this.wantIds = const [],
      this.evidenceIds = const [],
      this.counterIds = const [],
      this.representation = 'unknown',
      this.horizon = 'unknown',
      this.approachAvoid = 'unknown',
      this.status = 'hypothesis',
      this.source = 'ai_hypothesis',
      this.feedback = 'unknown',
      this.semanticKey = '',
      this.falsifier = '',
      this.safetyConcern = false});
  final String id,
      text,
      representation,
      horizon,
      approachAvoid,
      status,
      source,
      feedback,
      semanticKey,
      falsifier;
  final Map<String, String> directionByRoute;
  final List<String> wantIds, evidenceIds, counterIds;
  final bool safetyConcern;
  bool get opposing =>
      directionByRoute.values.any((v) => v == 'oppose' || v == 'conditional');
  WmJson toJson() => {
        'id': id,
        'text': text,
        'directionByRoute': directionByRoute,
        'wantIds': wantIds,
        'evidenceIds': evidenceIds,
        'counterIds': counterIds,
        'representation': representation,
        'horizon': horizon,
        'approachAvoid': approachAvoid,
        'status': status,
        'source': source,
        'feedback': feedback,
        'semanticKey': semanticKey,
        'falsifier': falsifier,
        'safetyConcern': safetyConcern
      };
  factory WmMotive.fromJson(WmJson j) => WmMotive(
      id: wmText(j['id']),
      text: wmText(j['text']),
      directionByRoute: wmMap(j['directionByRoute'])
          .map((k, v) => MapEntry(k, wmText(v, 'unknown'))),
      wantIds: wmStrings(j['wantIds']),
      evidenceIds: wmStrings(j['evidenceIds']),
      counterIds: wmStrings(j['counterIds']),
      representation: wmText(j['representation'], 'unknown'),
      horizon: wmText(j['horizon'], 'unknown'),
      approachAvoid: wmText(j['approachAvoid'], 'unknown'),
      status: wmText(j['status'], 'hypothesis'),
      source: wmText(j['source'], 'ai_hypothesis'),
      feedback: wmText(j['feedback'], 'unknown'),
      semanticKey: wmText(j['semanticKey']),
      falsifier: wmText(j['falsifier']),
      safetyConcern: j['safetyConcern'] == true);
}

class WmAnalysis {
  const WmAnalysis(
      {this.wants = const [],
      this.routes = const [],
      this.motives = const [],
      this.reframes = const [],
      this.unknowns = const [],
      this.receipt = '本地整理，尚未调用 AI',
      this.version = 1});
  final List<WmWant> wants;
  final List<WmRoute> routes;
  final List<WmMotive> motives;
  final List<WmJson> reframes;
  final List<String> unknowns;
  final String receipt;
  final int version;
  WmJson toJson() => {
        'wants': wants.map((e) => e.toJson()).toList(),
        'routes': routes.map((e) => e.toJson()).toList(),
        'motives': motives.map((e) => e.toJson()).toList(),
        'reframes': reframes,
        'unknowns': unknowns,
        'receipt': receipt,
        'version': version
      };
  factory WmAnalysis.fromJson(WmJson j) => WmAnalysis(
      wants: wmMaps(j['wants']).map(WmWant.fromJson).toList(),
      routes: wmMaps(j['routes']).map(WmRoute.fromJson).toList(),
      motives: wmMaps(j['motives']).map(WmMotive.fromJson).toList(),
      reframes: wmMaps(j['reframes']),
      unknowns: wmStrings(j['unknowns']),
      receipt: wmText(j['receipt']),
      version: wmInt(j['version'], 1));
}

/// An append-only event. Data does not inherit facts from a preceding event.
/// E.g. declaring a decision never creates an attempt or an outcome.
class WmEvent {
  const WmEvent(
      {required this.id,
      required this.kind,
      required this.phase,
      required this.recordedAt,
      required this.cycle,
      this.happenedAt,
      this.data = const {},
      this.evidenceIds = const [],
      this.source = 'user_report'});
  final String id, kind, source;
  final WmPhase phase;
  final int recordedAt, cycle;
  final int? happenedAt;
  final WmJson data;
  final List<String> evidenceIds;
  WmJson toJson() => {
        'id': id,
        'kind': kind,
        'phase': phase.name,
        'recordedAt': recordedAt,
        'happenedAt': happenedAt,
        'cycle': cycle,
        'data': data,
        'evidenceIds': evidenceIds,
        'source': source
      };
  factory WmEvent.fromJson(WmJson j) => WmEvent(
      id: wmText(j['id']),
      kind: wmText(j['kind']),
      phase: wmEnum(WmPhase.values, j['phase'], WmPhase.t2),
      recordedAt: wmInt(j['recordedAt']),
      happenedAt: j['happenedAt'] as int?,
      cycle: wmInt(j['cycle'], 1),
      data: wmMap(j['data']),
      evidenceIds: wmStrings(j['evidenceIds']),
      source: wmText(j['source'], 'user_report'));
}

class WmPrinciple {
  const WmPrinciple(
      {required this.id,
      required this.caseId,
      required this.version,
      required this.createdAt,
      required this.summary,
      required this.ifCondition,
      required this.thenAction,
      required this.exception,
      required this.evidenceIds,
      this.counterIds = const [],
      this.context = '',
      this.nextTest = '',
      this.status = WmPrincipleStatus.draft,
      this.maturity = 'tentative',
      this.revisionReason = '',
      this.sourceRevisionIds = const []});
  final String id,
      caseId,
      summary,
      ifCondition,
      thenAction,
      exception,
      context,
      nextTest,
      maturity,
      revisionReason;
  final int version, createdAt;
  final WmPrincipleStatus status;
  final List<String> evidenceIds, counterIds, sourceRevisionIds;
  WmJson toJson() => {
        'id': id,
        'caseId': caseId,
        'version': version,
        'createdAt': createdAt,
        'summary': summary,
        'ifCondition': ifCondition,
        'thenAction': thenAction,
        'exception': exception,
        'evidenceIds': evidenceIds,
        'counterIds': counterIds,
        'context': context,
        'nextTest': nextTest,
        'status': status.name,
        'maturity': maturity,
        'revisionReason': revisionReason,
        'sourceRevisionIds': sourceRevisionIds,
        'safetyPolicyVersion': '2.8.1'
      };
  factory WmPrinciple.fromJson(WmJson j) => WmPrinciple(
      id: wmText(j['id']),
      caseId: wmText(j['caseId']),
      version: wmInt(j['version'], 1),
      createdAt: wmInt(j['createdAt']),
      summary: wmText(j['summary']),
      ifCondition: wmText(j['ifCondition']),
      thenAction: wmText(j['thenAction']),
      exception: wmText(j['exception']),
      evidenceIds: wmStrings(j['evidenceIds']),
      counterIds: wmStrings(j['counterIds']),
      context: wmText(j['context']),
      nextTest: wmText(j['nextTest']),
      status: wmEnum(
          WmPrincipleStatus.values, j['status'], WmPrincipleStatus.draft),
      maturity: wmText(j['maturity'], 'tentative'),
      revisionReason: wmText(j['revisionReason']),
      sourceRevisionIds: wmStrings(j['sourceRevisionIds']));
}

class WmCase {
  const WmCase(
      {required this.id,
      required this.issue,
      required this.createdAt,
      required this.updatedAt,
      this.revision = 0,
      this.cycle = 1,
      this.evidence = const [],
      this.analysis = const WmAnalysis(),
      this.events = const [],
      this.snapshots = const [],
      this.rankings = const [],
      this.principles = const [],
      this.principleUses = const [],
      this.allowedSourceCaseIds = const [],
      this.remoteAllowed = false,
      this.weights = const {
        'personal_fit': .35,
        'evidence_quality': .25,
        'decision_materiality': .25,
        'context_relevance': .15
      }});
  static const int schemaVersion = 1;
  final String id, issue;
  final int createdAt, updatedAt, revision, cycle;
  final List<WmEvidence> evidence;
  final WmAnalysis analysis;
  final List<WmEvent> events;
  final List<WmJson> snapshots, rankings, principleUses;
  final List<WmPrinciple> principles;
  final List<String> allowedSourceCaseIds;
  final bool remoteAllowed;
  final Map<String, double> weights;
  List<WmEvidence> get activeEvidence =>
      evidence.where((e) => e.usable).toList();
  List<WmEvent> get currentEvents =>
      events.where((e) => e.cycle == cycle).toList();
  WmEvent? latest(String kind) {
    for (final e in currentEvents.reversed) {
      if (e.kind == kind) return e;
    }
    return null;
  }

  WmPhase get phase {
    if (latest('observation') != null) return WmPhase.t3;
    if (latest('decision') != null || latest('attempt') != null)
      return WmPhase.t2;
    if (latest('trigger') != null) return WmPhase.t1;
    return WmPhase.t0;
  }

  String get stateLabel {
    if (currentEvents.isNotEmpty && currentEvents.last.kind == 'pause')
      return '已暂停，可随时继续';
    if (latest('observation') != null) return '已记录结果 · 后续体验仍可更新';
    if (latest('attempt') != null) return '已报告尝试 · 完成与结果待记录';
    if (latest('decision') != null) return '已声明决意 · 行动仍未知';
    final t = latest('trigger');
    if (t != null)
      return t.data['status'] == 'confirmed'
          ? '已核实触发 · 现场可重新选择'
          : '条件待核实 / 已变化';
    if (snapshots.any((s) => s['cycle'] == cycle && s['status'] == 'sealed'))
      return '等待真实条件';
    return '整理事实与选择';
  }

  List<WmPrinciple> get latestPrinciples {
    final result = <String, WmPrinciple>{};
    for (final p in principles) {
      if (!result.containsKey(p.id) || result[p.id]!.version < p.version)
        result[p.id] = p;
    }
    return result.values.toList();
  }

  WmJson toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'issue': issue,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'revision': revision,
        'cycle': cycle,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'analysis': analysis.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
        'snapshots': snapshots,
        'rankings': rankings,
        'principles': principles.map((e) => e.toJson()).toList(),
        'principleUses': principleUses,
        'allowedSourceCaseIds': allowedSourceCaseIds,
        'remoteAllowed': remoteAllowed,
        'weights': weights
      };
  factory WmCase.fromJson(WmJson j) {
    if (wmInt(j['schemaVersion'], 1) > schemaVersion)
      throw const FormatException('课题版本较新，请先升级应用');
    return WmCase(
        id: wmText(j['id']),
        issue: wmText(j['issue']),
        createdAt: wmInt(j['createdAt']),
        updatedAt: wmInt(j['updatedAt']),
        revision: wmInt(j['revision']),
        cycle: wmInt(j['cycle'], 1),
        evidence: wmMaps(j['evidence']).map(WmEvidence.fromJson).toList(),
        analysis: WmAnalysis.fromJson(wmMap(j['analysis'])),
        events: wmMaps(j['events']).map(WmEvent.fromJson).toList(),
        snapshots: wmMaps(j['snapshots']),
        rankings: wmMaps(j['rankings']),
        principles: wmMaps(j['principles']).map(WmPrinciple.fromJson).toList(),
        principleUses: wmMaps(j['principleUses']),
        allowedSourceCaseIds: wmStrings(j['allowedSourceCaseIds']),
        remoteAllowed: j['remoteAllowed'] == true,
        weights: wmMap(j['weights']).isEmpty
            ? const {
                'personal_fit': .35,
                'evidence_quality': .25,
                'decision_materiality': .25,
                'context_relevance': .15
              }
            : wmMap(j['weights'])
                .map((k, v) => MapEntry(k, (v as num).toDouble())));
  }
  WmCase change(WmJson changes) =>
      WmCase.fromJson(wmClone({...toJson(), ...changes}));
}
