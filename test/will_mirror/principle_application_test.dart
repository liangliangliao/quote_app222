import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';

import 'fixtures.dart';

MirrorNode principle(CaseFile f,
        {NodeStatus status = NodeStatus.accepted,
        String risk = 'clear',
        String maturity = 'tentative',
        String? revisionOf}) =>
    commands.record(
        f,
        NodeKind.principle,
        {
          'summary': '类似情境下先核实资料，仍需实践检验',
          'ifCondition': '需要核实岗位条件且没有新的安全限制',
          'thenAction': '先取得真实答复',
          'exceptionRule': '岗位或健康安全条件变化时先暂停核实',
          'contexts': ['本次岗位比较'],
          'maturity': maturity,
          'falsifier': '核实并未帮助比较，或者情境已经不同',
          'nextTest': '记录是否实际采用及结果，不强断因果',
          'riskGate': risk,
          'insightIds': <String>[],
        },
        evidenceIds: [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis,
        status: status,
        revisionOf: revisionOf);

MirrorNode application(CaseFile f, MirrorNode p,
        {String recall = 'unknown',
        String outcome = 'unknown',
        String detail = '本人选作参考，尚不代表实际采用',
        List<String> observations = const [],
        String? revisionOf,
        String? version,
        TimePhase? phase}) =>
    commands.record(
        f,
        NodeKind.principleApplication,
        {
          'principleId': p.id,
          'principleVersion': version ?? p.id,
          'triggerId': f.latest(NodeKind.trigger)?.id,
          'exposure': 'accepted',
          'recall': recall,
          'application': outcome,
          'attemptIds': <String>[],
          'observationIds': observations,
          'detail': detail,
        },
        evidenceIds: p.evidenceIds,
        links: [p.id],
        revisionOf: revisionOf,
        phase: phase);

void main() {
  test('a draft principle cannot become an adopted cue before user acceptance',
      () {
    var f = prepared();
    final p = principle(f, status: NodeStatus.draft);
    f = commands.append(f, [p]);
    expect(() => commands.append(f, [application(f, p)]),
        throwsA(isA<MirrorProblem>()));
    f = commands.feedback(f, p.id, 'accept');
    f = commands.append(f, [application(f, f.node(p.id)!)]);
    expect(f.latest(NodeKind.principleApplication)!.text('application'),
        'unknown');
  });

  test('risk and review gates block principle adoption and plan sealing', () {
    for (final condition in [
      ('blocked', 'tentative'),
      ('verify_first', 'tentative'),
      ('unknown', 'tentative'),
      ('clear', 'needs_review'),
    ]) {
      var f = prepared();
      final p = principle(f, risk: condition.$1, maturity: condition.$2);
      f = commands.append(f, [p]);
      expect(EvidenceRules.principleCanBePrepared(p, f), isFalse);
      expect(() => commands.append(f, [application(f, p)]),
          throwsA(isA<MirrorProblem>()));
      expect(() => commands.sealPlan(f, {...planBody(f), 'principleId': p.id}),
          throwsA(isA<MirrorProblem>()));
      expect(
          commands.sealPlan(f, planBody(f)).latest(NodeKind.plan), isNotNull);
    }
  });

  test('display and advance declarations cannot fabricate actual principle use',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    expect(
        () => commands
            .append(f, [application(f, p, outcome: 'applied_self_report')]),
        throwsA(isA<MirrorProblem>()));
    expect(
        () => commands
            .append(f, [application(f, p, recall: 'explicitly_recalled')]),
        throwsA(isA<MirrorProblem>()));
  });

  test('real application needs a concrete account and a known observation', () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    final original = application(f, p);
    f = commands.append(f, [original]);
    f = commands.observe(f,
        body: observationBody(f, state: 'unknown'), evidenceText: '还没有核实发生了什么');
    expect(
        () => commands.append(f, [
              application(f, p,
                  outcome: 'applied_self_report',
                  revisionOf: original.id,
                  observations: [f.latest(NodeKind.observation)!.id])
            ]),
        throwsA(isA<MirrorProblem>()));
    f = commands.observe(f,
        body: observationBody(f), evidenceText: '确实发出了核实问题');
    final observed = f.latest(NodeKind.observation)!;
    expect(
        () => commands.append(f, [
              application(f, p,
                  outcome: 'applied_self_report',
                  detail: '',
                  revisionOf: original.id,
                  observations: [observed.id])
            ]),
        throwsA(isA<MirrorProblem>()));
    final updated = application(f, p,
        outcome: 'applied_self_report',
        detail: '先核实职责，随后发出了具体问题，作用仍需检验',
        observations: [observed.id],
        revisionOf: original.id);
    f = commands.append(f, [updated]);
    expect(f.latest(NodeKind.principleApplication)!.phase, TimePhase.t2);
    expect(f.node(original.id)!.text('application'), 'unknown');
    expect(
        () => commands.append(f, [
              application(f, p,
                  outcome: 'applied_verified',
                  observations: [observed.id],
                  revisionOf: updated.id)
            ]),
        throwsA(isA<MirrorProblem>()));
  });

  test(
      'version references must match and an application cannot switch versions',
      () {
    var f = prepared();
    final p = principle(f), other = principle(f);
    f = commands.append(f, [p, other]);
    expect(() => commands.append(f, [application(f, p, version: other.id)]),
        throwsA(isA<MirrorProblem>()));
    final original = application(f, p);
    f = commands.append(f, [original]);
    expect(
        () => commands
            .append(f, [application(f, other, revisionOf: original.id)]),
        throwsA(isA<MirrorProblem>()));
  });

  test('later revisions stop new cues but preserve review of the version used',
      () {
    var f = prepared();
    final old = principle(f);
    f = commands.append(f, [old]);
    final original = application(f, old);
    f = commands.append(f, [original]);
    final revised = principle(f, revisionOf: old.id);
    f = commands.append(f, [revised]);
    expect(EvidenceRules.principleCanBePrepared(old, f), isFalse);
    expect(() => commands.append(f, [application(f, old)]),
        throwsA(isA<MirrorProblem>()));
    f = commands.observe(f,
        body: observationBody(f), evidenceText: '按当时版本先询问了资料');
    f = commands.append(f, [
      application(f, old,
          outcome: 'applied_self_report',
          observations: [f.latest(NodeKind.observation)!.id],
          detail: '当时采用的是旧版核实做法；新原则尚未尝试',
          revisionOf: original.id)
    ]);
    expect(f.latest(NodeKind.principleApplication)!.text('principleVersion'),
        old.id);
    expect(f.node(old.id)!.body, old.body);
    expect(f.node(original.id)!.text('application'), 'unknown');
  });

  test('changed field conditions stop reuse without rewriting past acceptance',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    f = commands.sealPlan(f, {...planBody(f), 'principleId': p.id});
    final original = application(f, p);
    f = commands.append(f, [original]);
    f = commands.verifyTrigger(f, 'confirmed', '收到实际回复', occurredAt: time);
    f = commands.append(f, [
      application(f, p, recall: 'context_changed', revisionOf: original.id)
    ]);
    expect(EvidenceRules.principleCanBePrepared(p, f), isFalse);
    expect(f.node(original.id)!.text('recall'), 'unknown');
  });

  test(
      'cross-case reuse requires authorization and a current safe context match',
      () {
    var source = prepared();
    final p = principle(source);
    source = commands.append(source, [p]);
    var target = prepared();
    final authorized = {for (final n in source.nodes) n.id: n};
    expect(EvidenceRules.principleCanBePrepared(p, target), isFalse);
    expect(
        EvidenceRules.principleCanBePrepared(p, target, authorized: authorized),
        isFalse);
    final match = commands.record(target, NodeKind.principleMatch, {
      'principleId': p.id,
      'routeIds': [target.selectedRouteId],
      'fit': 'applicable',
      'reason': '本次仍需先核实岗位信息，条件和例外已经比较',
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
        isTrue);
    target = commands.append(target, [application(target, p)],
        authorized: authorized);
    expect(target.latest(NodeKind.principleApplication), isNotNull);
    expect(EvidenceRules.principleCanBePrepared(p, target), isFalse);
  });

  test('a new safety restriction suspends even an accepted principle', () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    f = commands.sealPlan(f, {...planBody(f), 'principleId': p.id});
    f = commands.verifyTrigger(f, 'confirmed', '现场已核实', occurredAt: time);
    f = commands.append(f, [
      commands.record(f, NodeKind.reappraisal, {
        'triggerCheckId': f.latest(NodeKind.triggerCheck)!.id,
        'planId': f.latest(NodeKind.plan)!.id,
        'changes': ['出现新的安全限制'],
        'immediateMotive': '先保护自己并核实',
        'rememberedMotiveIds': <String>[],
        'safetyChanged': true,
        'choice': 'verify',
        'routeId': null,
      })
    ]);
    expect(EvidenceRules.principleCanBePrepared(p, f), isFalse);
    expect(f.node(p.id)!.status, NodeStatus.accepted);
  });

  for (final exposure in ['none', 'opened', 'accepted']) {
    testWidgets('field cue requires explicit adoption, exposure=$exposure',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('flutter_tts'), (_) async => 1);
      final c = MirrorController(
          store: MemoryStore(),
          model: OfflineModel(),
          reminders: TestReminders());
      await c.initialize();
      var f = prepared();
      final p = principle(f);
      f = commands.append(f, [p]);
      if (exposure != 'none') {
        final body = {...application(f, p).body, 'exposure': exposure};
        f = commands.append(f, [
          commands.record(f, NodeKind.principleApplication, body,
              evidenceIds: p.evidenceIds, links: [p.id])
        ]);
      }
      f = commands.sealPlan(f, planBody(f));
      f = commands
          .verifyTrigger(f, 'confirmed', '真实条件已出现', occurredAt: time)
          .evolve(step: 5);
      await c.store.save(f, expectedRevision: 0);
      await c.reload();
      await tester.pumpWidget(
          MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
      await tester.pumpAndSettle();
      final recalled = find.text('我现场确实想起了它');
      expect(recalled, exposure == 'accepted' ? findsOneWidget : findsNothing);
      if (exposure == 'accepted') {
        await tester.ensureVisible(find.text('当前条件不适用'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('当前条件不适用'));
        await tester.pumpAndSettle();
        expect(recalled, findsNothing);
        expect(
            c.file(f.id)!.latest(NodeKind.principleApplication)!.text('recall'),
            'context_changed');
        expect(
            c
                .file(f.id)!
                .latest(NodeKind.principleApplication)!
                .text('application'),
            'unknown');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets('unsafe draft explains its gate and cannot be adopted',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (_) async => 1);
    final c = MirrorController(
        store: MemoryStore(),
        model: OfflineModel(),
        reminders: TestReminders());
    await c.initialize();
    var f = prepared();
    f = commands.append(f, [
      principle(f, status: NodeStatus.draft, risk: 'verify_first')
    ]).evolve(step: 4);
    await c.store.save(f, expectedRevision: 0);
    await c.reload();
    await tester.pumpWidget(
        MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
    await tester.pumpAndSettle();
    expect(find.textContaining('适用条件或安全限制需要重新核实'), findsOneWidget);
    final adopt = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '采用为本次参考'));
    expect(adopt.onPressed, isNull);
    expect(c.file(f.id)!.latest(NodeKind.principleApplication), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
