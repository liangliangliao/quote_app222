import 'self_os_models.dart';
import 'self_os_v37_rules.dart';

const osPrincipleStatuses = {
  'draft': '候选 · 待你认可',
  'user_accepted': '我认可 · 仍待检验',
  'needs_review': '需要复核',
  'user_rejected': '已拒绝',
  'retired': '已归档',
};
const osPrincipleRecall = {
  'unknown': '还不清楚是否想起',
  'explicitly_recalled': '现场确实想起',
  'rejected': '现场决定不用',
  'context_changed': '条件变了，先重审',
};
const osPrincipleUse = {
  'unknown': '是否采用还不清楚',
  'applied_self_report': '我实际采用了',
  'not_applied': '这次没有采用',
};

/// Uses the existing review IDs and profile document. No parallel personality
/// store, inferred actions, or recommendation scores as evidence.
class SelfOsPrinciples {
  static Map<String, dynamic> normalize(Map<String, dynamic> p) => {
        ...osClone(p),
        'version': p['version'] is int ? p['version'] : 1,
        'status': osPrincipleStatuses.containsKey(p['status'])
            ? p['status']
            : 'needs_review',
        'notApplicable': p['notApplicable'] ?? p['doesNotApply'] ?? '',
        'counterEvidenceIds': osStrings(p['counterEvidenceIds']),
        'maturity': p['maturity'] ?? 'tentative',
      };

  static Map<String, (SelfOsCase, SelfOsReview)> evidence(
          List<SelfOsCase> cases,
          {String? currentCaseId,
          DateTime? knownAt}) =>
      {
        for (final c in cases)
          if (currentCaseId == null ||
              currentCaseId == c.id ||
              c.v37.flag('shareExperience'))
            for (final r in c.reviews)
              if (r.notes['experienceWithdrawn'] != 'yes' &&
                  !r.createdAt.isAfter(knownAt ?? DateTime.now()))
                r.id: (c, r)
      };

  static String? unavailable(Map<String, dynamic> raw, List<SelfOsCase> cases,
      {String? currentCaseId, DateTime? knownAt}) {
    final p = normalize(raw);
    if (p['stale'] == true) return '来源已撤回，需要重新建立原则';
    if (p['status'] != 'user_accepted')
      return osPrincipleStatuses[p['status']] ?? '尚未认可';
    final sources =
        evidence(cases, currentCaseId: currentCaseId, knownAt: knownAt);
    final ids = osStrings(p['evidenceIds']);
    if (ids.isEmpty || ids.any((id) => !sources.containsKey(id)))
      return '来源缺失、已撤回或尚未获准用于这个案例';
    if (osStrings(p['counterEvidenceIds'])
        .any((id) => !sources.containsKey(id))) return '反例来源需要重新核对';
    if (knownAt != null) {
      final created = DateTime.tryParse(osText(p['createdAt']));
      if (created == null || created.isAfter(knownAt)) return '这条原则在当时尚不存在';
      final versionAt = DateTime.tryParse(osText(p['updatedAt']));
      final acceptedAt = DateTime.tryParse(osText(p['statusAt']));
      if ((versionAt != null && versionAt.isAfter(knownAt)) ||
          (acceptedAt != null && acceptedAt.isAfter(knownAt)))
        return '这个版本或这次认可在当时尚不存在';
    }
    for (final key in [
      'condition',
      'rule',
      'notApplicable',
      'exception',
      'riskGate',
      'nextTest'
    ]) {
      if (osText(p[key]).trim().isEmpty) return '请补充适用条件、边界与下次检验';
    }
    return null;
  }

  static List<Map<String, dynamic>> eligible(
          SelfOsProfile profile, List<SelfOsCase> cases, SelfOsCase current) =>
      profile.principles
          .where(
              (p) => unavailable(p, cases, currentCaseId: current.id) == null)
          .map(normalize)
          .toList();

  static List<SelfOsCase> allowedHistory(
          SelfOsCase current, List<SelfOsCase> history) =>
      [
        for (final source in [
          ...history.where((c) => c.id != current.id),
          current
        ])
          if (source.id == current.id || source.v37.flag('shareExperience'))
            source.copy()
              ..reviews.removeWhere((r) =>
                  r.notes['experienceWithdrawn'] == 'yes' ||
                  r.createdAt.isAfter(DateTime.now())),
      ];

  static SelfOsProfile analysisProfile(
      SelfOsProfile profile, List<SelfOsCase> history, SelfOsCase current) {
    final copy = SelfOsProfile.fromJson(osClone(profile.toJson()));
    copy.principles
      ..clear()
      ..addAll(
          eligible(profile, history, current).map((p) => p..remove('history')));
    final ids = evidence(history, currentCaseId: current.id).keys.toSet();
    for (final s in copy.strengths) {
      s.data['observations'] =
          s.observations.where((o) => ids.contains(o['reviewId'])).toList();
    }
    return copy;
  }

  static void assertRemoteAllowed(SelfOsCase c) {
    if (c.v37.settings['allowRemoteAnalysis'] == false)
      throw const FormatException('这个案例已关闭远程分析，可以继续在本机记录与核对。');
  }

  static Map<String, dynamic> candidate(Map<String, dynamic> fields,
      List<String> supports, List<String> counters, List<SelfOsCase> cases,
      {String? currentCaseId, DateTime? at}) {
    final now = at ?? DateTime.now();
    final sources = evidence(cases, currentCaseId: currentCaseId, knownAt: now);
    if (supports.isEmpty ||
        [...supports, ...counters].any((id) => !sources.containsKey(id)))
      throw const FormatException('原则必须引用真实、未撤回且已获准使用的经历');
    if (supports.toSet().intersection(counters.toSet()).isNotEmpty)
      throw const FormatException('同一事实的支持和反对含义请先分开说明');
    final p = <String, dynamic>{
      for (final k in [
        'condition',
        'rule',
        'notApplicable',
        'exception',
        'riskGate',
        'nextTest'
      ])
        k: osText(fields[k]).trim(),
      'id': selfOsId(),
      'version': 1,
      'status': 'draft',
      // Repetition is not a psychological law; user acceptance is separate.
      'maturity': 'tentative',
      'evidenceIds': supports.toSet().toList(),
      'counterEvidenceIds': counters.toSet().toList(),
      'counterSearch':
          counters.isEmpty ? '已检查允许范围内的经历，尚未确认反例；不代表没有反例' : '有反例，需保留适用情境的差异',
      'sourceCaseIds':
          supports.map((id) => sources[id]!.$1.id).toSet().toList(),
      'consentCaseIds': sources.values
          .where((e) => e.$1.v37.flag('shareExperience'))
          .map((e) => e.$1.id)
          .toSet()
          .toList(),
      'safetyPolicyVersion': 'experience-v28-1',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'history': <Map<String, dynamic>>[],
    };
    if (osText(p['rule']).isEmpty)
      throw const FormatException('请写下一个可以观察的具体做法');
    return p;
  }

  static void revise(Map<String, dynamic> p, Map<String, dynamic> fields,
      {required int expectedVersion, String reason = '用户修订'}) {
    final before = normalize(p);
    if (before['version'] != expectedVersion)
      throw const FormatException('原则已有新版本，请重新读取后修改');
    final history = osMaps(before['history']);
    history.add({...before..remove('history'), 'revisionReason': reason});
    p.addAll({
      ...fields,
      'version': expectedVersion + 1,
      'history': history,
      'status': 'draft',
      'updatedAt': DateTime.now().toIso8601String(),
      'revisionReason': reason,
    });
  }

  static void setStatus(
      Map<String, dynamic> p, String status, List<SelfOsCase> cases) {
    if (!osPrincipleStatuses.containsKey(status))
      throw const FormatException('原则状态无效');
    if (status == 'user_accepted') {
      final check = {...normalize(p), 'status': status};
      final error = unavailable(check, cases);
      if (error != null) throw FormatException(error);
    }
    p['status'] = status;
    p['statusAt'] = DateTime.now().toIso8601String();
  }

  static List<Map<String, dynamic>> applications(SelfOsCase c) =>
      osMaps(c.v37.settings['principleApplications']);

  static Map<String, dynamic> choose(
      SelfOsCase c, Map<String, dynamic> p, List<SelfOsCase> cases,
      {required bool contextMatches,
      required bool safe,
      String opposingReason = '',
      DateTime? at}) {
    final now = at ?? DateTime.now();
    if (c.reviewed) throw const FormatException('本轮已复盘，请在下一轮检验原则');
    final selectedRoute = c.text('routeId').isEmpty
        ? osText(c.guide.draft['routeId'])
        : c.text('routeId');
    if (selectedRoute.isNotEmpty &&
        !c.v37.routes.any((r) => r.id == selectedRoute))
      throw const FormatException('关联路线已改变，请先重新选择');
    final limit = SelfOsV37Rules.taskLimit(c.v37, routeId: selectedRoute);
    if (limit != null) throw FormatException(limit);
    final error = unavailable(p, cases, currentCaseId: c.id, knownAt: now);
    if (error != null) throw FormatException(error);
    if (!contextMatches || !safe)
      throw const FormatException('先核对适用条件和安全边界，也可以跳过或改道');
    final list = applications(c);
    if (list.any((a) =>
        a['round'] == c.round &&
        a['atT2'] == null &&
        a['stale'] != true &&
        !['declined', 'cancelled'].contains(a['exposureStatus'])))
      throw const FormatException('这轮先检验一条原则；可暂停原原则后再选择');
    final entry = <String, dynamic>{
      'id': selfOsId(),
      'caseId': c.id,
      'round': c.round,
      'principleId': p['id'],
      'principleVersion': normalize(p)['version'],
      'triggerId': selfOsId(),
      'trigger': c.text('trigger'),
      'principleSnapshot': normalize(p)..remove('history'),
      'exposureStatus': 'accepted',
      'recallStatus': 'unknown',
      'applicationStatus': 'unknown',
      'opposingReason': opposingReason.trim(),
      'contextCheck': 'user_confirmed',
      'riskCheck': 'user_confirmed',
      'atT0': now.toIso8601String(),
      'actionAttemptIds': <String>[],
      'observationIds': <String>[],
    };
    list.add(entry);
    c.v37.settings['principleApplications'] = list;
    return entry;
  }

  static void checkIn(SelfOsCase c, String applicationId, String recall,
      {String newInformation = ''}) {
    if (c.reviewed) throw const FormatException('事后补充请写在复盘，不能倒填现场认识');
    if (!osPrincipleRecall.containsKey(recall))
      throw const FormatException('请选择实际的现场状态');
    final list = applications(c);
    final a = list.firstWhere((a) => a['id'] == applicationId);
    if (a['stale'] == true ||
        a['atT2'] != null ||
        a['round'] != c.round ||
        ['declined', 'cancelled'].contains(a['exposureStatus']))
      throw const FormatException('这条应用已失效或已完成');
    final entry = {
      'exposureStatus': 'opened',
      'recallStatus': recall,
      'newInformation': newInformation.trim(),
      'knownAt': DateTime.now().toIso8601String(),
    };
    a.addAll({
      ...entry,
      'atT1': a['atT1'] ?? entry['knownAt'],
      't1Checkins': [...osMaps(a['t1Checkins']), entry]
    });
    if (recall == 'context_changed' || newInformation.trim().isNotEmpty) {
      c.fields['newInformation'] = newInformation.trim().isEmpty
          ? '原则适用条件变化，待核实'
          : newInformation.trim();
      c.v37.settings['newInformationReviewed'] = false;
      c.v37.settings['requiresReconsideration'] = true;
    }
    c.v37.settings['principleApplications'] = list;
  }

  static void recordExposure(SelfOsCase c, String id, String status) {
    if (!['delivered', 'opened', 'seen_unknown'].contains(status))
      throw const FormatException('曝光状态无效');
    final list = applications(c);
    final a = list.firstWhere((a) => a['id'] == id);
    if (a['stale'] == true ||
        a['atT2'] != null ||
        ['declined', 'cancelled'].contains(a['exposureStatus']))
      throw const FormatException('这条提示已暂停或失效');
    final event = {'status': status, 'at': DateTime.now().toIso8601String()};
    a['exposureEvents'] = [...osMaps(a['exposureEvents']), event];
    a['exposureStatus'] = status;
    // Neither notification delivery nor opening is evidence of recall or use.
    c.v37.settings['principleApplications'] = list;
  }

  static void pause(SelfOsCase c, String id) {
    final list = applications(c);
    list.firstWhere((a) => a['id'] == id)['exposureStatus'] = 'declined';
    c.v37.settings['principleApplications'] = list;
  }

  static Set<String> reconcile(SelfOsProfile profile, SelfOsCase c) {
    final cancel = <String>{};
    final list = applications(c);
    if (list.isEmpty) return cancel;
    final taskBlocked = SelfOsV37Rules.taskLimit(c.v37,
            routeId: c.text('routeId').isEmpty
                ? osText(c.guide.draft['routeId'])
                : c.text('routeId')) !=
        null;
    for (final a in list) {
      final p = profile.principles
          .where((p) => p['id'] == a['principleId'])
          .firstOrNull;
      final invalid = taskBlocked ||
          p == null ||
          p['status'] != 'user_accepted' ||
          p['stale'] == true ||
          normalize(p)['version'] != a['principleVersion'];
      if ((invalid ||
              a['atT2'] != null ||
              a['exposureStatus'] == 'declined' ||
              profile.experienceSettings['remindersEnabled'] != true) &&
          ['requested', 'scheduled'].contains(a['reminderStatus'])) {
        cancel.add(osText(a['id']));
        a['reminderStatus'] = 'cancelled';
      }
      if (invalid && a['atT2'] == null) a['exposureStatus'] = 'cancelled';
    }
    c.v37.settings['principleApplications'] = list;
    return cancel;
  }

  static void review(
      SelfOsCase c, SelfOsProfile profile, String id, SelfOsReview observation,
      {required String use,
      required String attempt,
      required String preparation,
      required String effect,
      bool counterExample = false}) {
    if (!osPrincipleUse.containsKey(use) ||
        !['unknown', 'completed', 'blocked', 'rerouted', 'not_started']
            .contains(attempt) ||
        !['unknown', 'helped', 'not_helped', 'harmed'].contains(effect))
      throw const FormatException('请选择实际采用、尝试及作用状态');
    if (!c.reviews.any((r) => r.id == observation.id))
      throw const FormatException('先保存这次真实行动的复盘');
    final list = applications(c);
    final a = list.firstWhere((a) => a['id'] == id);
    if (a['atT2'] != null ||
        a['stale'] == true ||
        a['round'] != observation.round)
      throw const FormatException('本轮应用已复盘、已失效或不属于这次行动');
    a.addAll({
      'applicationStatus': use,
      'attemptStatus': attempt,
      'preparation': preparation.trim(),
      'reportedEffect': effect,
      'causalConclusion': 'unknown',
      'observedOutcome': observation.outcome,
      'observationIds': [observation.id],
      'attemptEvidenceIds':
          attempt == 'unknown' ? <String>[] : [observation.id],
      'attemptEvidenceKind': 'user_self_report',
      'counterExample': counterExample,
      'atT2': DateTime.now().toIso8601String(),
    });
    c.v37.settings['principleApplications'] = list;
    if (counterExample) {
      final p = profile.principles
          .where((p) => p['id'] == a['principleId'])
          .firstOrNull;
      if (p != null) {
        final next = {...normalize(p)};
        revise(
            p,
            {
              'counterEvidenceIds': {
                ...osStrings(next['counterEvidenceIds']),
                observation.id
              }.toList(),
            },
            expectedVersion: next['version'],
            reason: '实际应用出现反例，需检查条件');
        p['status'] = 'needs_review';
      }
    }
  }

  /// Revocation takes precedence over displaying historical sensitive text.
  /// IDs/times survive, explanations and derived cues do not.
  static void invalidate(
      SelfOsProfile profile, List<SelfOsCase> cases, Set<String> withdrawnIds) {
    final referenceIds = {...withdrawnIds};
    final staleMotiveIds = <String>{};
    for (final c in cases) {
      for (final e in c.v37.evidence) {
        if (!withdrawnIds.contains(e.text('reviewId'))) continue;
        referenceIds.add(e.id);
        final id = e.id, reviewId = e.text('reviewId');
        e.data
          ..clear()
          ..addAll({
            'id': id,
            'reviewId': reviewId,
            'claim': '来源已撤回，待重新核实',
            'label': 'unknown',
            'verified': false,
            'stale': true
          });
      }
    }
    for (final c in cases) {
      for (final m
          in c.motives.where((m) => m.evidenceIds.any(referenceIds.contains))) {
        staleMotiveIds.add(m.id);
        m
          ..title = '来源已撤回的候选'
          ..reason = ''
          ..selected = false
          ..userStatus = 'needs_review'
          ..routeEffects = [];
      }
      for (final n in c.v37.nodes) {
        if (n.evidenceIds.any(referenceIds.contains) ||
            osMaps(n.data['observations'])
                .any((o) => withdrawnIds.contains(o['reviewId']))) {
          n.data['calibrationNeedsReview'] = true;
          n.data['observations'] = osMaps(n.data['observations'])
              .where((o) => !withdrawnIds.contains(o['reviewId']))
              .toList();
        }
      }
    }
    final staleIds = <String>{};
    for (final p in profile.principles) {
      if (![
        ...osStrings(p['evidenceIds']),
        ...osStrings(p['counterEvidenceIds'])
      ].any(referenceIds.contains)) continue;
      staleIds.add(osText(p['id']));
      p.addAll({
        'status': 'needs_review',
        'stale': true,
        'staleReason': 'stale_due_to_revocation',
        'history': <Map<String, dynamic>>[],
        'rule': '来源已撤回，请重新建立原则',
        for (final key in [
          'condition',
          'notApplicable',
          'exception',
          'riskGate',
          'nextTest',
          'comparability',
          'counterSearch'
        ])
          key: '',
      });
      p['unknowns'] = <String>[];
    }
    for (final s in profile.strengths) {
      s.data['observations'] = s.observations
          .where((o) => !withdrawnIds.contains(o['reviewId']))
          .toList();
    }
    for (final c in cases) {
      final list = applications(c);
      for (final a in list) {
        if (!staleIds.contains(a['principleId'])) continue;
        a.addAll({
          'stale': true,
          'principleSnapshot': <String, dynamic>{},
          'exposureStatus': 'cancelled',
          'newInformation': '',
          'preparation': '',
          'opposingReason': '',
          't1Checkins': <Map<String, dynamic>>[],
        });
      }
      c.v37.settings['principleApplications'] = list;
      final assessments = osMaps(c.v37.settings['changeabilityAssessments']);
      for (final a in assessments) {
        if (!osStrings(a['sourceEvidenceIds']).any(referenceIds.contains))
          continue;
        a.addAll({
          'stale': true,
          'safetyReviewRequired': a['classification'] == 'hard_limit_for_task',
          'classification': 'uncertain',
          'fact': '来源已撤回，待重新核实',
          'reason': '',
          'safeAlternatives': ['重新核实后再作判断']
        });
      }
      c.v37.settings['changeabilityAssessments'] = assessments;
      if (staleIds.contains(c.v37.text('principleId'))) {
        c.v37.settings.remove('principleId');
        c.v37.settings.remove('holdCue');
        c.v37.settings.remove('cueSource');
      }
      dynamic redact(dynamic value) {
        if (value is List) return value.map(redact).toList();
        if (value is! Map) return value;
        final map = value.map((k, v) => MapEntry('$k', redact(v)));
        if (staleMotiveIds.contains(map['id']) &&
            map.containsKey('title') &&
            map.containsKey('side')) {
          map.addAll({
            'title': '来源已撤回的候选',
            'reason': '',
            'selected': false,
            'userStatus': 'needs_review',
            'routeEffects': <Map<String, dynamic>>[]
          });
        }
        if (staleMotiveIds.contains(map['motiveId'])) {
          map.addAll({'title': '来源已撤回', 'why': '', 'stale': true});
        }
        if (osMaps(map['ranked']).any((r) => r['stale'] == true))
          map['stale'] = true;
        if (referenceIds.contains(map['id']) &&
            map.containsKey('claim') &&
            map.containsKey('label')) {
          return {
            'id': map['id'],
            'claim': '来源已撤回，待核实',
            'label': 'unknown',
            'verified': false,
            'stale': true
          };
        }
        if (staleIds.contains(map['principleId'])) {
          if (map.containsKey('principleSnapshot')) {
            map.addAll({
              'principleSnapshot': <String, dynamic>{},
              'stale': true,
              'newInformation': '',
              'preparation': '',
              'opposingReason': '',
              't1Checkins': <Map<String, dynamic>>[]
            });
          }
          map.remove('holdCue');
          map.remove('cueSource');
        }
        return map;
      }

      final settings = osMap(redact(c.v37.settings));
      c.v37.settings
        ..clear()
        ..addAll(settings);

      c.commitment = c.commitment == null ? null : osMap(redact(c.commitment));
      for (var i = 0; i < c.v37.priorCommitments.length; i++) {
        c.v37.priorCommitments[i] = osMap(redact(c.v37.priorCommitments[i]));
      }
      for (final r in c.reviews) {
        final clean = osMap(redact(r.snapshot));
        r.snapshot
          ..clear()
          ..addAll(clean);
      }
      if (withdrawnIds.isNotEmpty) {
        c.suggestions.clear();
        c.v37.pendingProposal = null;
      }
      // Derived assistant memory is rebuilt after permission changes; original
      // user turns and raw reviews remain available in their own case.
      if (withdrawnIds.isNotEmpty) {
        c.guide.turns.removeWhere((t) => t['role'] == 'assistant');
        c.guide.frame = null;
        c.guide.confirmedRevision = null;
        c.guide.revision++;
        if (!c.reviewed) {
          c.guide.phase = c.retrospective ? 'review' : 'explore';
          c.v37.settings['requiresReconsideration'] = c.committedAt != null;
        }
      }
    }
  }
}
