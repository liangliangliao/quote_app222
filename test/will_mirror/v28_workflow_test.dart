import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/v28/case_analysis.dart';
import 'package:quote_app/will_mirror/v28/case_models.dart';
import 'package:quote_app/will_mirror/v28/case_workflow.dart';
import 'package:quote_app/will_mirror/v28/case_reminders.dart';

void main() {
  late WmWorkflow flow;
  late WmCase c;
  var now = 1000, serial = 0;
  const engine = WmAnalysisEngine();
  setUp(() {
    now = 1000;
    serial = 0;
    flow = WmWorkflow(clock: () => now++, ids: (p) => '${p}_${serial++}');
    c = flow.start('case_a', '我想尝试一项新任务，但条件还没有核实');
  });
  WmCase principleCase() {
    var value = flow.recordAction(c,
        kind: 'preparation', text: '预留了十分钟并列出所需资料', happenedAt: 900);
    value = flow.principle(value,
        summary: '先准备材料可能有帮助',
        condition: '任务依赖已有资料且时间允许',
        action: '先列出资料再做小试验',
        exception: '紧急风险时先保护自己',
        evidenceIds: [value.evidence.last.id],
        nextTest: '下次比较准备是否减少阻碍');
    return flow.principleStatus(
        value, value.latestPrinciples.single, WmPrincipleStatus.accepted);
  }

  test(
      'T0 stays sealed; decision, attempt, result, later experience are separate',
      () {
    c = flow.seal(c, trigger: '收到资料且时间允许', ifThen: '先看一页', fallback: '条件不够就暂停');
    final sealed = jsonEncode(c.snapshots.single);
    expect(() => flow.decide(c, c.analysis.routes.first.id),
        throwsFormatException);
    c = flow.recordAction(c, kind: 'preparation', text: '已经列出资料清单');
    expect(c.latest('attempt'), isNull);
    expect(c.phase, WmPhase.t0);
    c = flow.assessRoute(c, c.analysis.routes.first.id,
        gate: WmGate.clear, fact: '资料可合法读取，时间与权限均已确认');
    c = flow.trigger(c, 'confirmed', '资料收到，本人有十分钟空闲');
    expect(c.analysis.routes.first.gate, WmGate.verifyFirst);
    c = flow.assessRoute(c, c.analysis.routes.first.id,
        gate: WmGate.clear, fact: '现场重新核对了权限、时间和安全条件');
    c = flow.decide(c, c.analysis.routes.first.id);
    expect(c.latest('attempt'), isNull);
    expect(c.latest('decision')!.data['actionStatus'], 'unknown');
    c = flow.recordAction(c, kind: 'attempt', text: '打开资料阅读了一页');
    c = flow.observe(c,
        status: 'blocked',
        fact: '资料不完整，未能继续',
        externalOutcome: '尚未完成',
        acquired: 'no');
    expect(c.latest('preparation'), isNotNull);
    expect(c.latest('attempt'), isNotNull);
    expect(c.latest('observation')!.data['causalStatus'], 'unknown');
    expect(c.latest('observation')!.data['satisfaction'], 'unknown');
    expect(jsonEncode(c.snapshots.single), sealed);
    expect(WmWorkflow.verifySeal(c.snapshots.single), isTrue);
    expect(() => flow.seal(c, trigger: '重写', ifThen: '按已知结果', fallback: '无'),
        throwsFormatException);
    c = flow.followUp(c, '虽然没完成，但准备仍有价值，也感到失望', window: 'routine');
    expect(c.latest('experience')!.data['longTermFit'], 'unknown');
    c = flow.nextCycle(c);
    expect(c.cycle, 2);
    expect(c.phase, WmPhase.t0);
    expect(c.events.where((e) => e.kind == 'preparation'), hasLength(1));
    expect(c.analysis.routes.first.gate, WmGate.verifyFirst);
    expect(c.snapshots, hasLength(1));
  });

  test('changed conditions re-gate routes; blocked means cannot win by score',
      () {
    final first = c.analysis.routes.first.id, second = c.analysis.routes[1].id;
    c = flow.assessRoute(c, first, gate: WmGate.clear, fact: '当时条件已经核实');
    c = flow.assessRoute(c, second,
        gate: WmGate.blocked, fact: '资格尚未满足，不能采用此手段');
    c = flow.trigger(c, 'changed', '环境条件变化了');
    expect(c.analysis.routes.first.gate, WmGate.verifyFirst);
    expect(c.analysis.routes[1].gate, WmGate.blocked);
    expect(
        () => flow.assessRoute(c, second, gate: WmGate.clear, fact: '我认为分数高'),
        throwsFormatException);
    expect(() => flow.decide(c, first), throwsFormatException);
  });

  test(
      'ranking has <=5 reasons, unknown dimensions remain unscored, risk survives rejection',
      () {
    c = flow.feedback(c, c.analysis.motives[1].id, 'rejected');
    final rank = c.rankings.last;
    expect(wmStrings(rank['topIds']).length, lessThanOrEqualTo(5));
    expect(wmStrings(rank['topIds']), contains(c.analysis.motives[1].id));
    expect(
        wmMap(rank['scores']).containsKey(c.analysis.motives[1].id), isFalse);
    final allHigh = {
      for (final m in c.analysis.motives)
        m.id: {for (final d in WmAnalysisEngine.dimensions) d: 4.0}
    };
    final remote =
        engine.rank(c, runId: 'rank', now: now, remoteFacets: allHigh);
    expect(
        wmMap(remote['scores']).containsKey(c.analysis.motives[1].id), isFalse);
    expect(
        wmMap(wmMap(wmMap(remote['facets'])[c.analysis.motives[1].id])[
            'values'])['evidence_quality'],
        isNull);
    expect(() => flow.weights(c, {'personal_fit': 1}), throwsFormatException);
    allHigh[c.analysis.motives.first.id]!['personal_fit'] = 400;
    expect(() => engine.rank(c, runId: 'bad', now: now, remoteFacets: allHigh),
        throwsFormatException);
  });

  test(
      'semantic duplicates collapse without dropping an independent safety flag',
      () {
    final original = c.analysis.motives.first;
    final duplicate = WmMotive.fromJson(
        {...original.toJson(), 'id': 'copy', 'safetyConcern': true});
    final result = engine.deduplicate([original, duplicate]);
    expect(result, hasLength(1));
    expect(result.single.safetyConcern, isTrue);
    final opposite = WmMotive.fromJson({
      ...original.toJson(),
      'id': 'counter',
      'directionByRoute': {c.analysis.routes[1].id: 'oppose'}
    });
    expect(engine.deduplicate([original, opposite]), hasLength(2));
  });

  test(
      'principles require actual evidence, remain tentative, preserve versions and exceptions',
      () {
    expect(
        () => flow.principle(c,
            summary: '原则',
            condition: '一直',
            action: '努力',
            exception: '没有',
            evidenceIds: [c.evidence.first.id]),
        throwsFormatException);
    c = principleCase();
    expect(c.principles, hasLength(2));
    expect(c.principles.first.status, WmPrincipleStatus.draft);
    expect(c.latestPrinciples.single.maturity, 'tentative');
    c = flow.principleStatus(
        c, c.latestPrinciples.single, WmPrincipleStatus.needsReview,
        counterIds: [c.evidence.last.id]);
    expect(c.latestPrinciples.single.version, 3);
    expect(c.latestPrinciples.single.maturity, 'counterevidence_present');
    expect(c.principles.first.exception, '紧急风险时先保护自己');
  });

  test(
      'cross-case principle use needs consent and matching context, never creates behavior',
      () {
    final source = principleCase(), p = principleCase().latestPrinciples.single;
    final actual = source.latestPrinciples.single;
    var target = flow.start('case_b', '另一个相关任务');
    expect(
        () => flow.applyPrinciple(target, source, actual, contextMatches: true),
        throwsFormatException);
    target = target.change({
      'allowedSourceCaseIds': [source.id]
    });
    expect(
        () =>
            flow.applyPrinciple(target, source, actual, contextMatches: false),
        throwsFormatException);
    expect(() => flow.applyPrinciple(target, source, p, contextMatches: true),
        throwsFormatException);
    target = flow.applyPrinciple(target, source, actual, contextMatches: true);
    final id = wmText(target.principleUses.single['id']);
    expect(target.latest('attempt'), isNull);
    expect(target.principleUses.single['application'], 'unknown');
    expect(
        () => flow.checkPrinciple(target, id, application: 'applied_verified'),
        throwsFormatException);
    expect(
        () =>
            flow.checkPrinciple(target, id, application: 'applied_self_report'),
        throwsFormatException);
    target = flow.checkPrinciple(target, id, recall: 'explicitly_recalled');
    expect(target.principleUses.single['atT1'], isNull);
    expect(target.principleUses.single['recall'], 'unknown');
    target = flow.trigger(target, 'confirmed', '真实条件出现');
    target = flow.checkPrinciple(target, id, recall: 'not_recalled');
    final t1 = target.principleUses.single['atT1'];
    target = flow.recordAction(target, kind: 'attempt', text: '后来采取一个小步骤');
    target = flow.observe(target, status: 'completed', fact: '该步骤已完成');
    target = flow.checkPrinciple(target, id,
        recall: 'explicitly_recalled', application: 'applied_self_report');
    expect(target.principleUses.single['recall'], 'not_recalled');
    expect(target.principleUses.single['atT1'], t1);
    expect(target.principleUses.single['retrospectiveRecall'],
        'explicitly_recalled');
    expect(target.principleUses.single['causalEffect'], 'unknown');
  });

  test(
      'source withdrawal clears sensitive derivatives and cannot be revived by local refresh',
      () {
    c = principleCase();
    c = flow.seal(c, trigger: '材料齐备', ifThen: '列清单', fallback: '暂停');
    final sensitive = c.evidence.last;
    c = flow.revokeEvidence(c, sensitive.id);
    expect(c.analysis.motives, isEmpty);
    expect(c.latestPrinciples.single.status, WmPrincipleStatus.revoked);
    expect(c.snapshots.single['status'], 'redacted_due_to_revocation');
    expect(jsonEncode(c.toJson()), isNot(contains(sensitive.text)));
    c = flow.revokeEvidence(c, c.evidence.first.id);
    c = flow.analyze(c, engine.local(c));
    expect(c.analysis.wants.single.status, 'unknown');
    expect(c.activeEvidence, isEmpty);
  });

  test(
      'changeability uses occurrence and verified sources; beliefs are never verified facts',
      () {
    expect(
        () => flow.addEvidence(c,
            text: '一定会失败',
            kind: WmFactKind.belief,
            status: WmFactStatus.verified),
        throwsFormatException);
    expect(
        () => flow.changeability(c,
            evidenceId: c.evidence.first.id,
            classification: 'irreversible_past',
            nextStep: '未来可准备',
            timeReference: '昨天'),
        throwsFormatException);
    c = flow.addEvidence(c,
        text: '申请截止时间已过', kind: WmFactKind.fact, happenedAt: 800);
    c = flow.changeability(c,
        evidenceId: c.evidence.last.id,
        classification: 'irreversible_past',
        nextStep: '核实未来批次并准备资料',
        timeReference: '仅针对这一批次');
    expect(c.latest('changeability')!.data['scope'], contains('未来条件可变'));
    expect(
        () => flow.changeability(c,
            evidenceId: c.evidence.last.id,
            classification: 'hard_limit_for_task',
            nextStep: '换路线',
            timeReference: '当前任务'),
        throwsFormatException);
    expect(
        () => flow.recordAction(c,
            kind: 'attempt', text: '未来要做', happenedAt: 999999),
        throwsFormatException);
  });

  test('analysis rejects hallucinated evidence and personality claims', () {
    final a = c.analysis.toJson();
    a['wants'] = [
      {
        ...c.analysis.wants.first.toJson(),
        'evidenceIds': ['invented']
      }
    ];
    expect(() => engine.validate(WmAnalysis.fromJson(a), c),
        throwsFormatException);
    a['wants'] = [
      {...c.analysis.wants.first.toJson(), 'claim': '你注定无法胜任'}
    ];
    expect(() => engine.validate(WmAnalysis.fromJson(a), c),
        throwsFormatException);
    expect(() => WmCase.fromJson({...c.toJson(), 'schemaVersion': 999}),
        throwsFormatException);
  });

  test(
      'notification payload is a strict reference, contains no private narrative',
      () {
    const link = WmCaseLink(
        caseId: 'goal_a',
        snapshotId: 'seal_1',
        triggerId: 'trigger_2',
        principleId: 'principle_3');
    final parsed = WmCaseLink.parse(link.encode())!;
    expect(parsed.caseId, 'goal_a');
    expect(parsed.principleId, 'principle_3');
    expect(link.encode(), isNot(contains(c.issue)));
    expect(WmCaseLink.parse('willmirror://case/goal_a?trigger=t'), isNull);
    expect(WmCaseLink.parse('willmirror://case/%2e%2e?trigger=t&snapshot=s'),
        isNull);
    expect(
        WmCaseLink.parse('https://case/goal_a?trigger=t&snapshot=s'), isNull);
    expect(WmReminders.notificationId('a'), WmReminders.notificationId('a'));
    expect(WmReminders.notificationId('a'),
        isNot(WmReminders.notificationId('b')));
    expect(WmReminders.body, isNot(contains(c.issue)));
  });
}
