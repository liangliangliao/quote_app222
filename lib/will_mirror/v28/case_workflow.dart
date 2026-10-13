import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'case_analysis.dart';
import 'case_models.dart';

String wmId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${Random.secure().nextInt(1 << 32).toRadixString(36)}';

class WmWorkflow {
  WmWorkflow({int Function()? clock, String Function(String)? ids})
      : clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        ids = ids ?? wmId;
  final int Function() clock;
  final String Function(String) ids;
  static const engine = WmAnalysisEngine();

  WmCase start(String caseId, String issue, {int? createdAt}) {
    _required(issue);
    final now = clock();
    var c = WmCase(
        id: caseId,
        issue: issue.trim(),
        createdAt: createdAt ?? now,
        updatedAt: now,
        evidence: [
          WmEvidence(
              id: ids('e'),
              text: issue.trim(),
              kind: WmFactKind.statement,
              phase: WmPhase.t0,
              knownAt: now,
              recordedAt: now)
        ]);
    c = c.change({'analysis': engine.local(c).toJson()});
    return rank(c);
  }

  WmCase _event(WmCase c, String kind, WmPhase phase, WmJson data,
      {List<String> evidenceIds = const [],
      int? happenedAt,
      String source = 'user_report'}) {
    final now = clock();
    if (happenedAt != null && happenedAt > now)
      throw const FormatException('实际发生时间不能在未来');
    final e = WmEvent(
        id: ids(kind),
        kind: kind,
        phase: phase,
        recordedAt: now,
        cycle: c.cycle,
        data: wmClone(data),
        evidenceIds: evidenceIds,
        happenedAt: happenedAt,
        source: source);
    return c.change({
      'events': [...c.events.map((e) => e.toJson()), e.toJson()],
      'updatedAt': now
    });
  }

  WmCase rank(WmCase c, {Map<String, WmJson>? facets, String? receipt}) =>
      c.change({
        'rankings': [
          ...c.rankings,
          engine.rank(c,
              runId: ids('rank'),
              now: clock(),
              remoteFacets: facets,
              remoteReceipt: receipt)
        ]
      });

  WmCase analyze(WmCase c, WmAnalysis analysis) {
    engine.validate(analysis, c);
    final adjusted = WmAnalysis.fromJson(
        {...analysis.toJson(), 'version': c.analysis.version + 1});
    final next = _event(
        c,
        'analysis',
        c.phase,
        {
          'previousAnalysis': c.analysis.toJson(),
          'analysis': adjusted.toJson()
        },
        source: 'analysis');
    return rank(next.change({'analysis': adjusted.toJson()}));
  }

  WmCase addEvidence(WmCase c,
      {required String text,
      required WmFactKind kind,
      WmFactStatus status = WmFactStatus.reported,
      int? happenedAt,
      String context = '',
      String? legacyId,
      bool independent = false}) {
    _required(text);
    final now = clock();
    if (happenedAt != null && happenedAt > now)
      throw const FormatException('实际发生时间不能在未来');
    if (kind == WmFactKind.unknown) status = WmFactStatus.unknown;
    if (kind == WmFactKind.belief && status == WmFactStatus.verified)
      throw const FormatException('信念不能因确信而成为事实');
    if (legacyId != null && c.evidence.any((e) => e.legacyId == legacyId))
      return c;
    final e = WmEvidence(
        id: ids('e'),
        text: text.trim(),
        kind: kind,
        phase: c.phase,
        status: status,
        knownAt: now,
        recordedAt: now,
        happenedAt: happenedAt,
        context: context,
        legacyId: legacyId,
        independent: independent);
    // New facts invalidate a recommendation, but never rewrite its old values.
    return c.change({
      'evidence': [...c.evidence.map((e) => e.toJson()), e.toJson()],
      if (kind == WmFactKind.fact || kind == WmFactKind.capability)
        'analysis': {
          ...c.analysis.toJson(),
          'version': c.analysis.version + 1,
          'routes': c.analysis.routes
              .map((r) => {
                    ...r.toJson(),
                    'gate': r.gate == WmGate.blocked ? 'blocked' : 'verifyFirst'
                  })
              .toList(),
        },
      'rankings': c.rankings
          .map((r) => {...r, 'status': 'stale_new_evidence'})
          .toList(),
      'updatedAt': now
    });
  }

  WmCase feedback(WmCase c, String motiveId, String feedback) {
    if (!['endorsed', 'rejected', 'verify', 'unknown'].contains(feedback))
      throw const FormatException('未知反馈');
    if (!c.analysis.motives.any((m) => m.id == motiveId))
      throw const FormatException('动机不存在');
    final a = WmAnalysis.fromJson({
      ...c.analysis.toJson(),
      'version': c.analysis.version + 1,
      'motives': c.analysis.motives
          .map((m) => m.id == motiveId
              ? {...m.toJson(), 'feedback': feedback}
              : m.toJson())
          .toList()
    });
    return rank(_event(c.change({'analysis': a.toJson()}), 'motive_feedback',
        c.phase, {'motiveId': motiveId, 'feedback': feedback}));
  }

  WmCase weights(WmCase c, Map<String, double> weights) =>
      rank(c.change({'weights': weights}));

  WmCase addRoute(WmCase c, String title, String action) {
    _required(title);
    _required(action);
    final r = WmRoute(
        id: ids('route'),
        title: title,
        action: action,
        requirement: '执行前核实安全、资格、资源和他人同意');
    return c.change({
      'analysis': {
        ...c.analysis.toJson(),
        'version': c.analysis.version + 1,
        'routes': [...c.analysis.routes.map((e) => e.toJson()), r.toJson()]
      }
    });
  }

  WmCase assessRoute(WmCase c, String routeId,
      {required WmGate gate,
      required String fact,
      String capability = '未知',
      String wantFit = '未知',
      String support = ''}) {
    _required(fact);
    if (!c.analysis.routes.any((r) => r.id == routeId))
      throw const FormatException('路线不存在');
    if (c.analysis.routes.firstWhere((r) => r.id == routeId).gate ==
            WmGate.blocked &&
        gate == WmGate.clear) {
      throw const FormatException('已经阻断的手段不能由分数或一次勾选解除。请建立安全替代路线，并重新核实条件。');
    }
    var next = addEvidence(c,
        text: fact, kind: WmFactKind.fact, status: WmFactStatus.verified);
    final eid = next.evidence.last.id;
    next = next.change({
      'analysis': {
        ...next.analysis.toJson(),
        'version': next.analysis.version + 1,
        'routes': next.analysis.routes
            .map((r) => r.id == routeId
                ? {
                    ...r.toJson(),
                    'gate': gate.name,
                    'evidenceIds': [...r.evidenceIds, eid],
                    'risk': fact,
                    'wantFit': wantFit,
                    'capabilityFit': capability,
                    'support': support,
                    'feasibility': gate == WmGate.clear
                        ? 'verified'
                        : gate == WmGate.blocked
                            ? 'infeasible'
                            : 'unknown'
                  }
                : r.toJson())
            .toList()
      }
    });
    return rank(_event(next, 'route_assessment', c.phase,
        {'routeId': routeId, 'gate': gate.name},
        evidenceIds: [eid]));
  }

  WmCase seal(WmCase c,
      {String? routeId,
      required String trigger,
      required String ifThen,
      required String fallback,
      String prediction = '',
      String expectation = '',
      int? scheduledAt}) {
    if (c.phase != WmPhase.t0)
      throw const FormatException('现场和事后信息不能补写本轮事前快照；请开始下一轮');
    _required(trigger);
    _required(ifThen);
    _required(fallback);
    if (routeId != null && !c.analysis.routes.any((r) => r.id == routeId))
      throw const FormatException('路线不存在');
    final now = clock(), triggerId = ids('trigger');
    final payload = <String, dynamic>{
      'caseId': c.id,
      'cycle': c.cycle,
      'at': now,
      'routeId': routeId,
      'triggerId': triggerId,
      'trigger': trigger,
      'ifThen': ifThen,
      'fallback': fallback,
      'prediction': prediction,
      'expectation': expectation,
      'scheduledAt': scheduledAt,
      'nonce': ids('nonce'),
      'evidence': c.activeEvidence
          .where((e) => e.knownAt <= now)
          .map((e) => e.toJson())
          .toList(),
      'analysis': c.analysis.toJson(),
      'ranking': c.rankings.isEmpty ? null : c.rankings.last,
      'principleRefs': c.principleUses
          .where((u) =>
              u['cycle'] == c.cycle && u['status'] != 'stale_due_to_revocation')
          .toList()
    };
    final s = <String, dynamic>{
      'id': ids('seal'),
      'cycle': c.cycle,
      'status': 'sealed',
      'payload': payload,
      'hash': sha256.convert(utf8.encode(jsonEncode(payload))).toString()
    };
    return c.change({
      'snapshots': [
        ...c.snapshots.map((old) =>
            old['cycle'] == c.cycle && old['status'] == 'sealed'
                ? {...old, 'status': 'superseded'}
                : old),
        s
      ],
      'updatedAt': now
    });
  }

  static bool verifySeal(WmJson s) =>
      s['status'] != 'redacted_due_to_revocation' &&
      s['hash'] ==
          sha256.convert(utf8.encode(jsonEncode(s['payload']))).toString();
  WmJson? activeSeal(WmCase c) {
    if (c.latest('observation') != null) return null;
    for (final s in c.snapshots.reversed) {
      if (s['cycle'] == c.cycle && s['status'] == 'sealed') return s;
    }
    return null;
  }

  WmCase cancelPlan(WmCase c) => _event(
      c.change({
        'snapshots': c.snapshots
            .map((s) => s['cycle'] == c.cycle && s['status'] == 'sealed'
                ? {...s, 'status': 'withdrawn'}
                : s)
            .toList()
      }),
      'pause',
      c.phase,
      {'reason': '用户撤回计划；结果未知'});
  WmCase trigger(WmCase c, String status, String fact, {int? happenedAt}) {
    if (!['confirmed', 'unconfirmed', 'changed', 'expired', 'cancelled']
        .contains(status)) throw const FormatException('触发状态不合法');
    if (c.phase == WmPhase.t2 || c.phase == WmPhase.t3)
      throw const FormatException('本轮已经进入行动阶段；可记录结果，或在下一轮核实新触发');
    if (status == 'confirmed') _required(fact);
    var next = _event(
        c,
        'trigger',
        WmPhase.t1,
        {
          'status': status,
          'fact': fact,
          'triggerId':
              wmMap(activeSeal(c)?['payload'])['triggerId'] ?? ids('trigger'),
          'motiveAwareness': 'unknown',
          'seen': 'unknown'
        },
        happenedAt: happenedAt);
    if (fact.trim().isNotEmpty)
      next = addEvidence(next,
          text: fact, kind: WmFactKind.fact, happenedAt: happenedAt);
    if (status == 'changed') {
      next = next.change({
        'analysis': {
          ...next.analysis.toJson(),
          'version': next.analysis.version + 1,
          'routes': next.analysis.routes
              .map((r) => {
                    ...r.toJson(),
                    'gate': r.gate == WmGate.blocked ? 'blocked' : 'verifyFirst'
                  })
              .toList()
        }
      });
    }
    return rank(next);
  }

  WmCase decide(WmCase c, String routeId,
      {String autonomy = 'unknown', String opportunity = 'unknown'}) {
    if (c.latest('trigger')?.data['status'] != 'confirmed')
      throw const FormatException('先确认条件真的出现；提醒时间不代表真实触发');
    final route = c.analysis.routes.where((r) => r.id == routeId).firstOrNull;
    if (route == null || !route.canCommit)
      throw const FormatException('此路线尚未通过安全与现实条件核实，请先核实或改道');
    if (c.latest('observation') != null || c.latest('attempt') != null)
      throw const FormatException('请在下一轮记录新的决意');
    return _event(
        c,
        'decision',
        WmPhase.t2,
        {
          'routeId': routeId,
          'autonomy': autonomy,
          'opportunity': opportunity,
          'triggerId': c.latest('trigger')!.data['triggerId'],
          'actionStatus': 'unknown'
        },
        happenedAt: clock());
  }

  WmCase recordAction(WmCase c,
      {required String kind,
      required String text,
      String status = 'unknown',
      int? happenedAt,
      String? routeId}) {
    if (!['preparation', 'attempt'].contains(kind))
      throw const FormatException('行动类型不合法');
    _required(text);
    if (routeId != null && !c.analysis.routes.any((r) => r.id == routeId))
      throw const FormatException('路线不存在');
    var next = _event(
        c,
        kind,
        kind == 'preparation' ? c.phase : WmPhase.t2,
        {
          'status': status,
          'routeId': routeId,
          'decisionId': c.latest('decision')?.id,
          'completion': 'unknown'
        },
        happenedAt: happenedAt);
    next = addEvidence(next,
        text: text,
        kind:
            kind == 'preparation' ? WmFactKind.preparation : WmFactKind.attempt,
        happenedAt: happenedAt);
    final list = next.events
        .map((e) => e.id == next.events.last.id
            ? {
                ...e.toJson(),
                'evidenceIds': [next.evidence.last.id]
              }
            : e.toJson())
        .toList();
    return next.change({'events': list});
  }

  WmCase observe(WmCase c,
      {required String status,
      required String fact,
      String externalOutcome = '未知',
      String acquired = 'unknown',
      String barrier = '',
      String earliestDeviation = 'unknown',
      int? happenedAt}) {
    if (![
      'completed',
      'partial',
      'not_started',
      'blocked',
      'redirected',
      'pressured',
      'unknown'
    ].contains(status)) throw const FormatException('观察状态不合法');
    _required(fact);
    var next = _event(
        c,
        'observation',
        WmPhase.t2,
        {
          'status': status,
          'externalOutcome': externalOutcome,
          'acquired': acquired,
          'barrier': barrier,
          'earliestDeviation': earliestDeviation,
          'attemptIds': c.currentEvents
              .where((e) => e.kind == 'attempt')
              .map((e) => e.id)
              .toList(),
          'decisionId': c.latest('decision')?.id,
          'causalStatus': 'unknown',
          'satisfaction': 'unknown'
        },
        happenedAt: happenedAt);
    // The observation is T2 knowledge, even though the next screen is T3.
    final now = clock();
    final e = WmEvidence(
        id: ids('e'),
        text: fact,
        kind: WmFactKind.observation,
        phase: WmPhase.t2,
        knownAt: now,
        recordedAt: now,
        happenedAt: happenedAt,
        status:
            status == 'unknown' ? WmFactStatus.unknown : WmFactStatus.reported);
    next = next.change({
      'evidence': [...next.evidence.map((e) => e.toJson()), e.toJson()],
      'rankings': next.rankings
          .map((r) => {...r, 'status': 'stale_new_observation'})
          .toList(),
      'events': next.events
          .map((v) => v.id == next.events.last.id
              ? {
                  ...v.toJson(),
                  'evidenceIds': [e.id]
                }
              : v.toJson())
          .toList()
    });
    return next;
  }

  WmCase followUp(WmCase c, String experience,
      {required String window, int? happenedAt}) {
    _required(experience);
    final o = c.latest('observation');
    if (o == null) throw const FormatException('先记录实际结果，再记录后续体验');
    final next = _event(
        c,
        'experience',
        WmPhase.t3,
        {
          'observationId': o.id,
          'window': window,
          'experience': experience,
          'acquired': o.data['acquired'],
          'longTermFit': 'unknown'
        },
        happenedAt: happenedAt);
    return addEvidence(next,
        text: experience, kind: WmFactKind.feeling, happenedAt: happenedAt);
  }

  WmCase nextCycle(WmCase c) => c.change({
        'cycle': c.cycle + 1,
        'updatedAt': clock(),
        'remoteAllowed': false,
        'analysis': {
          ...c.analysis.toJson(),
          'version': c.analysis.version + 1,
          'routes': c.analysis.routes
              .map((r) => {
                    ...r.toJson(),
                    'gate': r.gate == WmGate.blocked ? 'blocked' : 'verifyFirst'
                  })
              .toList()
        },
        'rankings':
            c.rankings.map((r) => {...r, 'status': 'stale_new_cycle'}).toList(),
      });

  WmCase principle(WmCase c,
      {required String summary,
      required String condition,
      required String action,
      required String exception,
      required List<String> evidenceIds,
      List<String> counterIds = const [],
      String context = '',
      String nextTest = '',
      String? principleId,
      WmPrincipleStatus status = WmPrincipleStatus.draft,
      String revisionReason = ''}) {
    for (final s in [summary, condition, action, exception]) {
      _required(s);
    }
    final factual = c.activeEvidence
        .where((e) => e.factual && e.kind != WmFactKind.statement)
        .map((e) => e.id)
        .toSet();
    if (evidenceIds.isEmpty ||
        evidenceIds.any((e) => !factual.contains(e)) ||
        counterIds.any((e) => !factual.contains(e))) {
      throw const FormatException('原则必须引用仍有效的真实经历；榜单得分与想象不能作证据');
    }
    final old = principleId == null
        ? null
        : c.latestPrinciples.where((p) => p.id == principleId).firstOrNull;
    if (principleId != null && old == null)
      throw const FormatException('原则不存在');
    final p = WmPrinciple(
        id: old?.id ?? ids('principle'),
        caseId: c.id,
        version: (old?.version ?? 0) + 1,
        createdAt: clock(),
        summary: summary,
        ifCondition: condition,
        thenAction: action,
        exception: exception,
        evidenceIds: evidenceIds,
        counterIds: counterIds,
        context: context,
        nextTest: nextTest,
        status: status,
        maturity:
            counterIds.isNotEmpty ? 'counterevidence_present' : 'tentative',
        revisionReason: revisionReason);
    return c.change({
      'principles': [...c.principles.map((p) => p.toJson()), p.toJson()],
      'updatedAt': clock()
    });
  }

  WmCase principleStatus(WmCase c, WmPrinciple p, WmPrincipleStatus status,
          {List<String>? counterIds}) =>
      principle(c,
          summary: p.summary,
          condition: p.ifCondition,
          action: p.thenAction,
          exception: p.exception,
          evidenceIds: p.evidenceIds,
          counterIds: counterIds ?? p.counterIds,
          context: p.context,
          nextTest: p.nextTest,
          principleId: p.id,
          status: status,
          revisionReason: counterIds != null ? '新增反例；适用条件需要复核' : '用户更新自主状态');

  WmCase applyPrinciple(WmCase target, WmCase source, WmPrinciple p,
      {required bool contextMatches}) {
    final current =
        source.latestPrinciples.where((v) => v.id == p.id).firstOrNull;
    if (current == null ||
        current.version != p.version ||
        p.status != WmPrincipleStatus.accepted)
      throw const FormatException('仅可采用当前有效且本人认可的原则');
    if (target.id != source.id &&
        !target.allowedSourceCaseIds.contains(source.id))
      throw const FormatException('尚未授权跨课题引用');
    if (!contextMatches) throw const FormatException('当前情境不适用；可跳过或重新核实');
    if (p.evidenceIds.any(
        (id) => !source.activeEvidence.any((e) => e.id == id && e.factual)))
      throw const FormatException('原则证据已失效');
    final use = {
      'id': ids('application'),
      'caseId': target.id,
      'sourceCaseId': source.id,
      'principleId': p.id,
      'principleVersion': p.version,
      'cycle': target.cycle,
      'atT0': target.phase == WmPhase.t0 ? clock() : null,
      'atT1': null,
      'atT2': null,
      'triggerId': wmMap(activeSeal(target)?['payload'])['triggerId'],
      'status': 'active',
      'exposure': 'accepted',
      'recall': 'unknown',
      'application': 'unknown',
      'actionAttemptIds': <String>[],
      'observationIds': <String>[]
    };
    return target.change({
      'principleUses': [...target.principleUses, use],
      'updatedAt': clock()
    });
  }

  WmCase checkPrinciple(WmCase c, String useId,
      {String? exposure, String? recall, String? application}) {
    final use = c.principleUses.where((u) => u['id'] == useId).firstOrNull;
    if (use == null || use['status'] != 'active')
      throw const FormatException('原则应用已失效');
    if (recall != null &&
        ![
          'explicitly_recalled',
          'not_recalled',
          'unknown',
          'rejected',
          'context_changed',
          'recalled_after'
        ].contains(recall)) throw const FormatException('未知回忆状态');
    if (application != null &&
        ![
          'applied_self_report',
          'not_applied',
          'unknown'
        ].contains(application)) throw const FormatException('没有外部证据不能标为已验证应用');
    if (application == 'applied_self_report' &&
        c.latest('attempt') == null &&
        c.latest('preparation') == null &&
        c.latest('observation') == null) {
      throw const FormatException('请先记录具体采用了什么；打开卡片不是实际应用');
    }
    final isOnsite = c.phase == WmPhase.t1;
    final isBefore = c.phase == WmPhase.t0;
    return c.change({
      'principleUses': c.principleUses
          .map((u) => u['id'] != useId
              ? u
              : {
                  ...u,
                  if (exposure != null) 'exposure': exposure,
                  if (recall != null && isOnsite) 'recall': recall,
                  if (recall != null && isBefore) 'preparationRecall': recall,
                  if (recall != null && !isOnsite && !isBefore)
                    'retrospectiveRecall': recall,
                  if (recall != null && isOnsite) 'atT1': clock(),
                  if (application != null) 'application': application,
                  if (application != null) 'atT2': clock(),
                  if (application != null)
                    'actionAttemptIds': c.currentEvents
                        .where((e) =>
                            e.kind == 'attempt' || e.kind == 'preparation')
                        .map((e) => e.id)
                        .toList(),
                  if (application != null)
                    'observationIds': c.currentEvents
                        .where((e) => e.kind == 'observation')
                        .map((e) => e.id)
                        .toList(),
                  'causalEffect': 'unknown'
                })
          .toList()
    });
  }

  WmCase changeability(WmCase c,
      {required String evidenceId,
      required String classification,
      required String nextStep,
      required String timeReference}) {
    final fact = c.activeEvidence.where((e) => e.id == evidenceId).firstOrNull;
    if (fact == null) throw const FormatException('事实不存在');
    if (![
      'irreversible_past',
      'modifiable_now',
      'modifiable_with_support',
      'hard_limit_for_task',
      'externally_dependent',
      'uncertain'
    ].contains(classification)) throw const FormatException('未知可改变性类别');
    if (classification == 'irreversible_past' &&
        (fact.happenedAt == null ||
            fact.happenedAt! > clock() ||
            !fact.factual)) throw const FormatException('只有已发生且有依据的事实可标为不可逆过去');
    if (classification == 'hard_limit_for_task' &&
        fact.status != WmFactStatus.verified)
      throw const FormatException('特定任务硬限制需要核实来源');
    _required(nextStep);
    _required(timeReference);
    return _event(c, 'changeability', c.phase, {
      'classification': classification,
      'timeReference': timeReference,
      'nextStep': nextStep,
      'scope': '仅这项事实和当前任务；未来条件可变',
      'reviewAt': null
    }, evidenceIds: [
      evidenceId
    ]);
  }

  /// Privacy withdrawal takes precedence over historical display. Hash metadata
  /// remains, but affected sealed plaintext is removed and visibly redacted.
  WmCase revokeEvidence(WmCase c, String evidenceId) {
    if (!c.evidence.any((e) => e.id == evidenceId))
      throw const FormatException('证据不存在');
    var next = c.change({
      'evidence': c.evidence
          .map((e) => e.id == evidenceId ? e.revoke().toJson() : e.toJson())
          .toList(),
      'analysis': const WmAnalysis(receipt: '来源已撤回，分析待重建').toJson(),
      'rankings': c.rankings
          .map((r) => {
                'id': r['id'],
                'at': r['at'],
                'status': 'stale_due_to_revocation',
                'topIds': <String>[]
              })
          .toList(),
      'snapshots': c.snapshots
          .map((s) => {
                'id': s['id'],
                'cycle': s['cycle'],
                'hash': s['hash'],
                'status': 'redacted_due_to_revocation',
                'payload': <String, dynamic>{}
              })
          .toList(),
      'events': c.events
          .map((e) => (e.evidenceIds.contains(evidenceId) ||
                  ['analysis', 'trigger', 'experience'].contains(e.kind))
              ? {
                  ...e.toJson(),
                  'data': {'status': 'redacted_due_to_revocation'},
                  'evidenceIds':
                      e.evidenceIds.where((id) => id != evidenceId).toList()
                }
              : e.toJson())
          .toList(),
      'principles': c.principles
          .map((p) => p.evidenceIds.contains(evidenceId) ||
                  p.counterIds.contains(evidenceId)
              ? {
                  ...p.toJson(),
                  'summary': '来源已撤回',
                  'ifCondition': '',
                  'thenAction': '',
                  'exception': '',
                  'context': '',
                  'nextTest': '',
                  'status': 'revoked'
                }
              : p.toJson())
          .toList(),
      'principleUses': c.principleUses
          .map((u) => {...u, 'status': 'stale_due_to_revocation'})
          .toList(),
      'remoteAllowed': false,
      'updatedAt': clock()
    });
    if (c.evidence
        .where((e) => e.id == evidenceId)
        .any((e) => e.kind == WmFactKind.statement))
      next = next.change({'issue': '已撤回原始描述'});
    return next;
  }

  WmCase revokeSource(WmCase c, String sourceId) => c.change({
        'allowedSourceCaseIds':
            c.allowedSourceCaseIds.where((id) => id != sourceId).toList(),
        'principleUses': c.principleUses
            .map((u) => u['sourceCaseId'] == sourceId
                ? {...u, 'status': 'stale_due_to_revocation'}
                : u)
            .toList(),
        'rankings': c.rankings
            .map((r) => {...r, 'status': 'stale_due_to_revocation'})
            .toList(),
        'updatedAt': clock()
      });
  static void _required(String text) {
    if (text.trim().isEmpty || text.length > 8000)
      throw const FormatException('请填写具体内容（最多 8000 字）');
  }
}
