import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';

import 'fixtures.dart';
import 'principle_application_test.dart' show principle, application;

MirrorNode taskRequirement(CaseFile f,
        {String status = 'verified', String? routeId}) =>
    commands.record(
        f,
        NodeKind.taskRequirement,
        {
          'routeId': routeId ?? f.selectedRouteId,
          'taskStep': '核对实际要求',
          'requirement': '能整理和核实书面资料',
          'precision': '以招聘方书面说明为准',
          'riskIfUnmet': '先核实再决定',
          'status': status,
          'validUntil': null,
        },
        evidenceIds: [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);

MirrorNode capability(CaseFile f, {List<String>? evidenceIds}) =>
    commands.record(
        f,
        NodeKind.capability,
        {
          'description': '本人报告曾整理过类似任务资料',
          'functionalDomain': '资料核实',
          'stability': 'context_dependent',
          'state': 'demonstrated_strength',
          'taskRequirementIds': <String>[],
          'status': 'reported',
          'sensitive': false,
        },
        evidenceIds: evidenceIds ?? [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);

MirrorNode strengthMatch(CaseFile f,
        {List<String> capabilities = const [],
        List<String> requirements = const [],
        String state = 'demonstrated_strength',
        String gate = 'clear'}) =>
    commands.record(
        f,
        NodeKind.strengthMatch,
        {
          'routeId': f.selectedRouteId,
          'capabilityIds': capabilities,
          'requirementIds': requirements,
          'supportVariantIds': <String>[],
          'claim': '在这项资料核实任务里小试已有经验',
          'state': state,
          'nextTest': '核对一项真实要求，记录是否帮上忙',
          'riskGate': gate,
        },
        evidenceIds: [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);

MirrorNode changeabilityAssessment(CaseFile f, String classification,
        {String? factId, List<String>? evidenceIds, String? routeId}) =>
    commands.record(
        f,
        NodeKind.changeability,
        {
          'factId': factId ?? f.nodes.first.id,
          'routeId': routeId,
          'classification': classification,
          'timeReference': '本次任务当前条件',
          'contextRequirements': ['仍需核实实际要求'],
          'reason': '对具体事实作有条件判断，不推断人的本性',
          'safeAlternatives': ['取得书面答复或选择安全的替代任务'],
          'reviewCondition': '对方答复、制度或资源有变化时',
        },
        evidenceIds: evidenceIds ?? [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);

void main() {
  test(
      'T353: an uncertain assessment must still offer a concrete verification step',
      () {
    final f = prepared();
    final empty = commands.record(f, NodeKind.changeability, {
      ...changeabilityAssessment(f, 'uncertain').body,
      'safeAlternatives': <String>[],
    }, evidenceIds: [
      f.nodes.first.id
    ]);
    expect(() => commands.append(f, [empty]), throwsA(isA<MirrorProblem>()));
  });

  test(
      'T350: recording a belief after the event does not make its prediction irreversible',
      () {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '已经询问资料');
    final belief = commands.record(f, NodeKind.evidence, {
      ...f.nodes.first.body,
      'text': '我相信以后总是无法改变',
      'category': 'belief',
    });
    f = commands.append(f, [belief]);
    expect(
        () => commands.append(f, [
              changeabilityAssessment(f, 'irreversible_past',
                  factId: belief.id, evidenceIds: [belief.id])
            ]),
        throwsA(isA<MirrorProblem>()));
  });

  test(
      'T347: an expired task requirement cannot establish a current hard limit',
      () {
    var f = prepared();
    final expired = commands.record(f, NodeKind.taskRequirement, {
      ...taskRequirement(f).body,
      'validUntil': time.subtract(const Duration(days: 1)).toIso8601String(),
    }, evidenceIds: [
      f.nodes.first.id
    ]);
    f = commands.append(f, [expired]);
    expect(
        () => commands.append(f, [
              changeabilityAssessment(f, 'hard_limit_for_task',
                  routeId: f.selectedRouteId, evidenceIds: [expired.id])
            ]),
        throwsA(isA<MirrorProblem>()));
  });
  test(
      'T344: an asserted strength needs task requirements and capability evidence',
      () {
    var f = prepared();
    expect(() => commands.append(f, [strengthMatch(f)]),
        throwsA(isA<MirrorProblem>()));
    final requirement = taskRequirement(f), cap = capability(f);
    f = commands.append(f, [requirement, cap]);
    final match = strengthMatch(f,
        requirements: [requirement.id], capabilities: [cap.id]);
    expect(commands.append(f, [match]).latest(NodeKind.strengthMatch), match);
  });

  test(
      'T344: a model capability without real sources does not prove an advantage',
      () {
    var f = prepared();
    final requirement = taskRequirement(f),
        cap = capability(f, evidenceIds: []);
    f = commands.append(f, [requirement, cap]);
    expect(
        () => commands.append(f, [
              strengthMatch(f,
                  requirements: [requirement.id], capabilities: [cap.id])
            ]),
        throwsA(isA<MirrorProblem>()));
  });

  test(
      'T345 T346 T348: gaps, temporary state and new interests retain separate states',
      () {
    var f = prepared();
    final requirement = taskRequirement(f), cap = capability(f);
    f = commands.append(f, [requirement, cap]);
    for (final state in [
      'trainable_gap',
      'variable_state',
      'fit_with_support'
    ]) {
      expect(
          commands
              .append(f, [
                strengthMatch(f,
                    state: state,
                    requirements: [requirement.id],
                    capabilities: [cap.id])
              ])
              .latest(NodeKind.strengthMatch)!
              .text('state'),
          state);
    }
    expect(
        commands
            .append(f, [strengthMatch(f, state: 'unknown')])
            .latest(NodeKind.strengthMatch)!
            .text('state'),
        'unknown');
  });

  test('T344: task evidence cannot silently be borrowed from another route',
      () {
    var f = prepared();
    final other = route(f);
    f = commands.append(f, [other]);
    final requirement = taskRequirement(f, routeId: other.id),
        cap = capability(f);
    f = commands.append(f, [requirement, cap]);
    expect(
        () => commands.append(f, [
              strengthMatch(f,
                  requirements: [requirement.id], capabilities: [cap.id])
            ]),
        throwsA(isA<MirrorProblem>()));
  });

  test('T347: a capability match cannot lower the route safety gate', () {
    var f = newCase();
    final blocked = route(f, safety: 'blocked');
    f = commands.append(f, [blocked]).evolve(selectedRouteId: blocked.id);
    final requirement = taskRequirement(f), cap = capability(f);
    f = commands.append(f, [requirement, cap]);
    expect(
        () => commands.append(f, [
              strengthMatch(f,
                  requirements: [requirement.id], capabilities: [cap.id])
            ]),
        throwsA(isA<MirrorProblem>()));
    expect(
        commands
            .append(f, [
              strengthMatch(f,
                  gate: 'blocked',
                  requirements: [requirement.id],
                  capabilities: [cap.id])
            ])
            .latest(NodeKind.strengthMatch)!
            .text('riskGate'),
        'blocked');
  });

  test('T350: an imagined future is not an irreversible past fact', () {
    var f = prepared();
    expect(
        () => commands
            .append(f, [changeabilityAssessment(f, 'irreversible_past')]),
        throwsA(isA<MirrorProblem>()));
    f = commands.observe(f,
        body: observationBody(f), evidenceText: '已经发出询问，不能撤销已发生事实');
    final observed = f.latest(NodeKind.observation)!;
    expect(
        commands
            .append(f, [
              changeabilityAssessment(f, 'irreversible_past',
                  factId: observed.id, evidenceIds: [observed.id])
            ])
            .latest(NodeKind.changeability)!
            .text('classification'),
        'irreversible_past');
  });

  test(
      'T351 T352 T353: no source means unknown, while support and intervention remain possible',
      () {
    final f = prepared();
    expect(
        () => commands.append(
            f, [changeabilityAssessment(f, 'modifiable_now', evidenceIds: [])]),
        throwsA(isA<MirrorProblem>()));
    for (final state in [
      'modifiable_now',
      'modifiable_with_support',
      'externally_dependent'
    ]) {
      expect(
          commands
              .append(f, [changeabilityAssessment(f, state)])
              .latest(NodeKind.changeability)!
              .text('classification'),
          state);
    }
    expect(
        commands
            .append(
                f, [changeabilityAssessment(f, 'uncertain', evidenceIds: [])])
            .latest(NodeKind.changeability)!
            .strings('safeAlternatives'),
        isNotEmpty);
  });

  test(
      'T347 T353: a hard limit needs verified requirements for this exact task',
      () {
    var f = prepared();
    expect(
        () => commands.append(f, [
              changeabilityAssessment(f, 'hard_limit_for_task',
                  routeId: f.selectedRouteId)
            ]),
        throwsA(isA<MirrorProblem>()));
    final unknown = taskRequirement(f, status: 'unknown');
    f = commands.append(f, [unknown]);
    expect(
        () => commands.append(f, [
              changeabilityAssessment(f, 'hard_limit_for_task',
                  routeId: f.selectedRouteId, evidenceIds: [unknown.id])
            ]),
        throwsA(isA<MirrorProblem>()));
    final verified = taskRequirement(f);
    f = commands.append(f, [verified]);
    expect(
        commands
            .append(f, [
              changeabilityAssessment(f, 'hard_limit_for_task',
                  routeId: f.selectedRouteId, evidenceIds: [verified.id])
            ])
            .latest(NodeKind.changeability)!
            .text('classification'),
        'hard_limit_for_task');
  });

  test(
      'T353: principle and ranking are not the subject of a changeability verdict',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    expect(
        () => commands
            .append(f, [changeabilityAssessment(f, 'uncertain', factId: p.id)]),
        throwsA(isA<MirrorProblem>()));
  });

  test('T357: an unverified expectation is not a verified duty of someone else',
      () {
    var f = prepared();
    final body = {
      'ownActions': ['提出一次清楚的请求'],
      'otherAutonomy': ['对方可以自主回应'],
      'verifiedObligations': ['应提供约定资料'],
      'unknownObligations': <String>[],
      'safeOptions': ['核对约定或寻求适当帮助'],
      'riskGate': 'clear',
      'nextVerification': '核对约定的实际文字',
    };
    MirrorNode review(List<String> ids, Json data) =>
        commands.record(f, NodeKind.boundaryReview, data,
            evidenceIds: ids,
            origin: EvidenceOrigin.aiHypothesis,
            status: NodeStatus.draft);
    expect(
        () => commands.append(f, [
              review([f.nodes.first.id], body)
            ]),
        throwsA(isA<MirrorProblem>()));
    expect(
        commands.append(f, [
          review([
            f.nodes.first.id
          ], {
            ...body,
            'verifiedObligations': <String>[],
            'unknownObligations': ['是否有资料提供义务'],
          })
        ]).latest(NodeKind.boundaryReview),
        isNotNull);
    final requirement = taskRequirement(f);
    f = commands.append(f, [requirement]);
    expect(
        commands
            .append(f, [
              review([requirement.id], body)
            ])
            .latest(NodeKind.boundaryReview)!
            .strings('verifiedObligations'),
        isNotEmpty);
  });

  test('T335: reporting no action alone cannot establish actual principle use',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    final original = application(f, p);
    f = commands.append(f, [original]);
    f = commands.observe(f,
        body: observationBody(f, state: 'not_performed'),
        evidenceText: '确实没有行动');
    expect(
        () => commands.append(f, [
              application(f, p,
                  outcome: 'applied_self_report',
                  detail: '只看了这条原则',
                  revisionOf: original.id,
                  observations: [f.latest(NodeKind.observation)!.id])
            ]),
        throwsA(isA<MirrorProblem>()));
  });

  test(
      'T336: actual preparation remains evidence when the later action did not occur',
      () {
    var f = prepared();
    final p = principle(f);
    final intervention = commands.record(f, NodeKind.intervention, {
      'routeId': f.selectedRouteId,
      'obstacleId': null,
      'action': '核实资料',
      'mechanism': '先取得信息',
      'control': 'direct',
      'cost': '少量时间',
      'conditions': ['资料可查'],
      'risk': '不作承诺',
      'implementationEvidence': '实际整理的资料',
      'fallback': '等待核实',
      'reversible': true,
    }, evidenceIds: [
      f.nodes.first.id
    ]);
    f = commands.append(f, [p, intervention]);
    final original = application(f, p);
    f = commands.append(f, [original]);
    final executed = commands.record(f, NodeKind.interventionExecution, {
      'interventionId': intervention.id,
      'state': 'executed',
      'detail': '确实整理了资料',
    });
    f = commands.append(f, [executed]);
    f = commands.observe(f,
        body: observationBody(f, state: 'not_performed'),
        evidenceText: '资料准备完成，岗位取消，所以没有出发');
    final used = commands.record(
        f,
        NodeKind.principleApplication,
        {
          ...application(f, p).body,
          'application': 'applied_self_report',
          'preparationIds': [executed.id],
          'detail': '先整理了核实资料，之后合理停止',
        },
        evidenceIds: p.evidenceIds,
        links: [p.id],
        revisionOf: original.id);
    expect(
        commands
            .append(f, [used])
            .latest(NodeKind.principleApplication)!
            .strings('preparationIds'),
        [executed.id]);
  });

  test(
      'T329 T338 T365: counterexamples create review versions without rewriting old applications',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    final original = application(f, p);
    f = commands.append(f, [original]);
    final before = canonicalJson(f.toJson());
    final revised =
        commands.addCounterEvidence(f, p.id, '在另一个环境中，不先整理也完成了资料核实');
    final current = revised.latest(NodeKind.principle)!;
    expect(current.revisionOf, p.id);
    expect(current.text('maturity'), 'needs_review');
    expect(current.counterIds, contains(revised.latest(NodeKind.evidence)!.id));
    expect(current.text('reviewReason'), isNotEmpty);
    expect(EvidenceRules.principleCanBePrepared(p, revised), isFalse);
    expect(EvidenceRules.principleCanBePrepared(current, revised), isFalse);
    expect(revised.node(original.id)!.text('principleVersion'), p.id);
    expect(canonicalJson(f.toJson()), before);
    final again =
        commands.addCounterEvidence(revised, current.id, '又出现了不同的实际经历');
    expect(again.latest(NodeKind.principle)!.counterIds, hasLength(2));
    expect(() => commands.addCounterEvidence(again, p.id, '旧版本不能继续收取新反例'),
        throwsA(isA<MirrorProblem>()));
  });

  test(
      'T333: a prior principle match for one route does not approve another route',
      () {
    var source = prepared();
    final p = principle(source);
    source = commands.append(source, [p]);
    var target = prepared();
    final other = route(target);
    target = commands.append(target, [other]);
    final authorized = {for (final n in source.nodes) n.id: n};
    final match = commands.record(target, NodeKind.principleMatch, {
      'principleId': p.id,
      'routeIds': [other.id],
      'fit': 'applicable',
      'reason': '只比较了另一走法',
      'changedConditions': <String>[],
      'riskGate': 'clear',
    }, evidenceIds: [
      target.nodes.first.id
    ], links: [
      p.id
    ]);
    target = commands.append(target, [match], authorized: authorized);
    expect(
        EvidenceRules.principleCanBePrepared(p, target, authorized: authorized),
        isFalse);
  });

  test(
      'T362: an overlong field cue is rejected without replacing the principle',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    final tooLong = commands.record(
        f,
        NodeKind.principle,
        {
          ...p.body,
          'fieldCue': List.filled(76, '字').join(),
        },
        evidenceIds: p.evidenceIds,
        revisionOf: p.id);
    expect(() => commands.append(f, [tooLong]), throwsA(isA<MirrorProblem>()));
    expect(f.latest(NodeKind.principle)!.id, p.id);
  });
}
