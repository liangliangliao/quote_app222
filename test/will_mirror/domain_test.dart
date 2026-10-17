import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/domain/schema.dart';
import 'package:quote_app/will_mirror/domain/ranking.dart';
import 'fixtures.dart';

void main() {
  test(
      'one case preserves raw input and separates UI step from real time phase',
      () {
    final f = newCase();
    expect(f.nodes.single.text('text'), f.issue);
    expect(f.evolve(step: 6).phase, TimePhase.t0);
    expect(f.nodes.single.happenedAt, isNull);
    expect(f.nodes.single.knownAt, time);
  });
  test('nested ledger bodies and support references are immutable', () {
    final f = newCase();
    expect(
        () => f.nodes.single.body['text'] = 'tampered', throwsUnsupportedError);
    expect(
        () => f.nodes.single.evidenceIds.add('forged'), throwsUnsupportedError);
  });
  test('schema rejects invented keys, invalid score and unknown enum', () {
    expect(() => validateShape({'a': 5}, {'a': 'score'}),
        throwsA(isA<MirrorProblem>()));
    expect(() => validateShape({'a': 'x', 'b': 1}, {'a': 'text'}),
        throwsA(isA<MirrorProblem>()));
    expect(() => validateShape('certain', 'enum:unknown,reported'),
        throwsA(isA<MirrorProblem>()));
  });
  test(
      'sealed T0 is canonical, unchanged by T1 and T2, and cannot be backfilled',
      () {
    var f = prepared();
    f = commands.sealPlan(f, planBody(f));
    final seal = f.latest(NodeKind.seal)!;
    final snapshot = canonicalJson(seal.body);
    expect(EvidenceRules.verifySeal(seal), isTrue);
    expect(f.phase, TimePhase.t0);
    expect(() => commands.verifyTrigger(f, 'confirmed', '', occurredAt: time),
        throwsA(isA<MirrorProblem>()));
    f = commands.verifyTrigger(f, 'confirmed', '收到了职责回复',
        occurredAt: time.add(const Duration(hours: 4)));
    expect(f.phase, TimePhase.t1);
    expect(
        () => commands.sealPlan(f, planBody(f)), throwsA(isA<MirrorProblem>()));
    f = commands.observe(f, body: observationBody(f), evidenceText: '确实发出了问题');
    expect(f.phase, TimePhase.t2);
    expect(canonicalJson(f.node(seal.id)!.body), snapshot);
    expect(EvidenceRules.verifySeal(f.node(seal.id)!), isTrue);
  });
  test('changed T1 conditions also prohibit inventing a T0 forecast', () {
    var f = prepared();
    f = commands.sealPlan(f, planBody(f));
    f = commands.verifyTrigger(f, 'changed', '对方取消了原岗位');
    expect(
        () => commands.sealPlan(f, planBody(f)), throwsA(isA<MirrorProblem>()));
  });
  test('retrospective case has no manufactured prediction', () {
    var f = newCase();
    f = f.evolve(retrospective: true);
    final r = route(f);
    f = commands.append(f, [r]);
    f = commands.chooseRoute(f, r.id);
    expect(
        () => commands.sealPlan(f, planBody(f)), throwsA(isA<MirrorProblem>()));
  });
  test('unknown actual action does not become failure or reveal', () {
    var f = prepared();
    expect(EvidenceRules.canReveal(f), isFalse);
    f = commands.observe(f,
        body: observationBody(f, state: 'unknown'), evidenceText: '尚未核实');
    expect(f.latest(NodeKind.observation)!.text('actionState'), 'unknown');
    expect(() => commands.reveal(f), throwsA(isA<MirrorProblem>()));
  });
  test('actual action and outside result remain independent', () {
    var f = prepared();
    f = commands.observe(f,
        body: observationBody(f, outcome: 'pending'), evidenceText: '已经发出询问');
    f = commands.reveal(f);
    expect(f.stage, CaseStage.revealed);
    expect(f.latest(NodeKind.observation)!.text('outcomeState'), 'pending');
    expect(f.latest(NodeKind.acquisition), isNull);
  });
  test('next episode retains original observations once on the same CaseID',
      () {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '已询问');
    final old = f;
    f = commands.nextEpisode(f);
    expect(f.id, old.id);
    expect(f.episodeId, isNot(old.episodeId));
    expect(f.current(NodeKind.observation), isEmpty);
    expect(f.current(NodeKind.observation, allEpisodes: true), hasLength(1));
    expect(f.phase, TimePhase.t0);
  });
  test('unsafe route and later unsafe assessment prevent preparation', () {
    var f = prepared();
    final blocked = route(f, safety: 'blocked');
    expect(
        () => commands.chooseRoute(commands.append(f, [blocked]), blocked.id),
        throwsA(isA<MirrorProblem>()));
    final fit = commands.record(f, NodeKind.routeFit,
        {'routeId': f.selectedRouteId, 'hardSafetyGate': 'blocked'});
    f = f.evolve(nodes: [...f.nodes, fit]);
    expect(EvidenceRules.routeCanBePrepared(f.node(f.selectedRouteId)!, f),
        isFalse);
    expect(
        () => commands.sealPlan(f, planBody(f)), throwsA(isA<MirrorProblem>()));
  });
  test('AI cannot author action facts or user acceptance', () {
    final f = newCase();
    final fake = commands.record(
        f,
        NodeKind.evidence,
        {
          'text': '已经完成',
          'category': 'action',
          'source': 'self_report',
          'sensitive': false,
          'scope': 'case_only'
        },
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);
    expect(() => EvidenceRules.validateBatch(f, [fake], modelOutput: true),
        throwsA(isA<MirrorProblem>()));
  });
  test('missing, stale, or foreign evidence blocks model records', () {
    var f = newCase();
    final m = motive(f, 1, refs: ['foreign']);
    expect(() => EvidenceRules.validateBatch(f, [m], modelOutput: true),
        throwsA(isA<MirrorProblem>()));
    final root = f.nodes.first.id;
    f = commands.retract(f, {root});
    expect(
        () => EvidenceRules.validateBatch(f, [motive(f, 2)], modelOutput: true),
        throwsA(isA<MirrorProblem>()));
  });
  test('plans, scenes, scores and device events do not self-prove personality',
      () {
    var f = prepared();
    f = commands.sealPlan(f, planBody(f));
    final plan = f.latest(NodeKind.plan)!;
    final conclusion =
        commands.record(f, NodeKind.insight, {}, evidenceIds: [plan.id]);
    expect(
        EvidenceRules.actualRoots(
            conclusion, {for (final n in f.nodes) n.id: n}),
        isEmpty);
  });
  test('transitive withdrawal reaches saved forecasts and ranking', () {
    var f = prepared();
    final m = motive(f, 3);
    f = commands.append(f, [m]);
    f = commands.chooseMotive(f, m.id, true);
    f = commands.append(f, [MotiveRanking.build(f)]);
    f = commands.sealPlan(f, planBody(f));
    final root = f.nodes.first.id;
    final affected = EvidenceRules.invalidationClosure(f.nodes, {root});
    expect(affected, contains(f.latest(NodeKind.seal)!.id));
    final wiped = commands.retract(f, {root});
    expect(wiped.selectedRouteId, isNull);
    expect(wiped.selectedMotiveIds, isEmpty);
    expect(wiped.issue, '已撤回原始描述');
    expect(wiped.nodes.every((n) => !n.usable), isTrue);
    expect(canonicalJson(wiped.toJson()), isNot(contains('先向招聘方核实条件')));
  });
  test(
      'Top5 preserves counterarguments and long horizon and never fills false scores',
      () {
    var f = prepared();
    final pool = [
      for (var i = 0; i < 12; i++)
        motive(f, i,
            relation: i == 10 ? 'opposes' : 'supports',
            horizon: i == 11 ? 'long' : 'now',
            critical: i == 9)
    ];
    f = commands.append(f, pool);
    final rank = MotiveRanking.build(f);
    final ids = rank.objects('ranked').map((r) => r['motiveId']);
    expect(ids, hasLength(5));
    expect(ids, containsAll([pool[9].id, pool[10].id, pool[11].id]));
    expect(rank.objects('ranked').every((r) => r['priority'] == null), isTrue);
  });
  test('generic assumptions remain verify-first rather than personal facts',
      () {
    var f = prepared();
    final a = motive(f, 1, basis: 'generic'), b = motive(f, 2);
    f = commands.append(f, [a, b]);
    final rank = MotiveRanking.build(f);
    expect(rank.objects('ranked'), hasLength(1));
    expect(rank.strings('verifyFirstIds'), contains(a.id));
  });
  test('duplicate semantic key collapses paraphrases, bounded distinct pool',
      () {
    final f = prepared();
    expect(
        MotiveRanking.distinct([
          motive(f, 1, semanticKey: 'source-A'),
          motive(f, 9, semanticKey: 'source-A'),
          motive(f, 2)
        ]),
        hasLength(2));
  });
  test('all scored candidates survive weight adjustment, refusal stays unknown',
      () {
    var f = prepared();
    final pool = [for (var i = 0; i < 8; i++) motive(f, i)];
    f = commands.append(f, pool);
    final facets = {
      for (var i = 0; i < 8; i++)
        pool[i].id: [
          for (var d = 0; d < 4; d++)
            {
              'dimension': rankingDimensions[d],
              'score': d == 0 ? 4 - i * .4 : i * .4,
              'confidence': .8,
              'status': 'scored',
              'answerName': 'm${i}_$d'
            }
        ]
    };
    final first = MotiveRanking.build(f,
        facets: facets, method: 'decisions', weights: [1, 0, 0, 0]);
    expect(first.objects('allFacets'), hasLength(8));
    final second = MotiveRanking.build(f,
        facets: facets, method: 'decisions', weights: [0, 1, 0, 0]);
    expect(first.objects('ranked').first['motiveId'], pool.first.id);
    expect(second.objects('ranked').first['motiveId'], pool.last.id);
  });
}
