import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/provenance.dart';
import 'package:quote_app/will_mirror/domain/ranking.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/presentation/design.dart';
import 'package:quote_app/will_mirror/presentation/me_page.dart';
import 'package:quote_app/will_mirror/presentation/sheets.dart';
import 'package:quote_app/will_mirror/presentation/visuals.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';

import 'fixtures.dart';
import 'intent_visual_test.dart' show visualCase;
import 'principle_application_test.dart' show principle;
import 'regression_v28_test.dart' show insightBody;

CaseFile labeledCase() {
  var f = visualCase();
  final route = f.current(NodeKind.route).first;
  f = commands.chooseRoute(f, route.id);
  f = commands.chooseMotive(f, f.current(NodeKind.motive).first.id, true);
  final scene = commands.record(
      f,
      NodeKind.scene,
      {
        'routeId': route.id,
        'motiveIds': f.selectedMotiveIds,
        'reframeIds': <String>[],
        'mode': 'future',
        'frames': [
          {
            'kind': 'future',
            'text': '可能先收到具体岗位资料，再作选择。',
            'claimType': 'hypothetical',
            'evidenceIds': <String>[]
          }
        ],
        'fieldCue': '先核实条件再选择。',
        'ifThen': '有新资料就先对照',
        'fallback': '条件变化可以暂停',
        'riskGate': 'clear',
        'durationSeconds': 10,
      },
      evidenceIds: [f.nodes.first.id],
      origin: EvidenceOrigin.aiHypothesis,
      status: NodeStatus.accepted);
  final preflight = commands.record(
      f,
      NodeKind.preflight,
      {
        'routeId': route.id,
        'baseline': '岗位要求尚未清楚',
        'possibleWithChanges': '先核实可以增加实际信息',
        'unchangeable': <String>[],
        'unknowns': ['对方是否答复'],
        'forecast': '取得信息后再选择',
        'triggerSignal': '收到答复',
        'verifyFirst': ['确认答复来源'],
        'safetyException': '条件变化可暂停',
        'fallback': '保留其他渠道',
      },
      evidenceIds: [f.nodes.first.id],
      origin: EvidenceOrigin.aiHypothesis,
      status: NodeStatus.draft);
  f = commands.append(f, [scene, preflight, principle(f)]);
  f = commands.append(f, [MotiveRanking.build(f)]);
  f = commands.sealPlan(f, {...planBody(f), 'sceneId': scene.id});
  f = commands.verifyTrigger(f, 'confirmed', '确实收到答复', occurredAt: time);
  f = commands.observe(f,
      body: observationBody(f), evidenceText: '已核实实际资料，外部结果尚不清楚');
  final observation = f.latest(NodeKind.observation)!;
  final review = commands.record(
      f,
      NodeKind.review,
      {
        'observationIds': [observation.id],
        'planId': f.latest(NodeKind.plan)!.id,
        'summary': '核实资料确实发生了，不能仅凭这一次认定长期有效。',
        'earliestDeviation': 'unknown',
        'knownFacts': [
          {
            'claim': '已核实资料',
            'evidenceIds': [observation.id]
          }
        ],
        'hypotheses': <Json>[],
        'regretTypes': ['unknown'],
        'revisedClaims': <Json>[],
        'unknowns': ['外部结果'],
        'nextTest': '下次仍对照实际条件',
        'satisfactionGap': '尚未取得目标',
        'alternativeExplanations': ['对方答复也影响结果'],
      },
      evidenceIds: [observation.id],
      origin: EvidenceOrigin.aiHypothesis,
      status: NodeStatus.draft);
  final insight = commands.record(f, NodeKind.insight, insightBody(),
      evidenceIds: [observation.id],
      origin: EvidenceOrigin.aiHypothesis,
      status: NodeStatus.draft);
  return commands.append(f, [review, insight]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_tts'), (_) async => 1);
  });

  test(
      'every model-authored type carries AI attribution, including after acceptance',
      () {
    final f = labeledCase();
    for (final kind in analyticalKinds) {
      final n = commands.record(f, kind, {},
          origin: EvidenceOrigin.aiHypothesis, status: NodeStatus.draft);
      expect(aiContentOrigin(n), 'AI 生成', reason: kind.name);
      expect(aiContentOrigin(n.withStatus(NodeStatus.accepted)), 'AI 生成',
          reason: kind.name);
    }
  });

  test(
      'an actual observation is authored by the person even when its route came from AI',
      () {
    final f = labeledCase();
    expect(aiContentOrigin(f.latest(NodeKind.observation)!, resolve: f.node),
        isNull);
    expect(aiContentOrigin(f.nodes.first, resolve: f.node), isNull);
    expect(contentSourceLabel(f.latest(NodeKind.observation)!, resolve: f.node),
        '本人记录');
    expect(aiContentOrigin(f.latest(NodeKind.plan)!, resolve: f.node),
        '你确认的预案 · 含 AI 建议');
  });

  test(
      'user-edited AI principles retain the original authorship without labelling every user record as AI',
      () {
    var f = labeledCase();
    final old = f.latest(NodeKind.principle)!;
    final edited = commands.record(
        f,
        NodeKind.principle,
        {
          ...old.body,
          'thenAction': '本人修改后的具体做法',
        },
        evidenceIds: old.evidenceIds,
        revisionOf: old.id);
    f = commands.append(f, [edited]);
    expect(aiContentOrigin(edited, resolve: f.node), 'AI 原稿 · 你已更新');
    final own = commands.record(f, NodeKind.principle, old.body,
        evidenceIds: old.evidenceIds);
    expect(aiContentOrigin(own, resolve: f.node), isNull);
  });

  test('model evaluation and rule sorting have distinct attribution', () {
    final f = labeledCase();
    expect(aiContentOrigin(f.latest(NodeKind.recommendation)!, resolve: f.node),
        'AI 理由 · 规则排序');
    expect(
        aiContentOrigin(MotiveRanking.build(f, method: 'decisions'),
            resolve: f.node),
        'AI 评估 · 规则排序');
  });

  test(
      'sealed mixed records identify AI analysis without turning real observations into AI output',
      () {
    final f = labeledCase();
    expect(aiContentOrigin(f.latest(NodeKind.seal)!, resolve: f.node),
        '系统封存 · 含 AI 分析');
    expect(aiContentOrigin(f.latest(NodeKind.observation)!, resolve: f.node),
        isNull);
  });

  test(
      'AI-filled preparation stays attributable even when the user wrote the route',
      () {
    var f = newCase();
    final ownRoute = commands.record(f, NodeKind.route, route(f).body,
        evidenceIds: [f.nodes.first.id]);
    f = commands.chooseRoute(commands.append(f, [ownRoute]), ownRoute.id);
    final source = commands.record(
        f,
        NodeKind.preflight,
        {
          ...labeledCase().latest(NodeKind.preflight)!.body,
          'routeId': ownRoute.id
        },
        evidenceIds: [f.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis);
    f = commands.append(f, [source]);
    final ownPlan = commands.sealPlan(f, planBody(f)).latest(NodeKind.plan)!;
    expect(aiContentOrigin(ownPlan, resolve: f.node), isNull);
    f = commands.sealPlan(f, {
      ...planBody(f),
      'sourceAnalysisIds': [source.id]
    });
    final plan = f.latest(NodeKind.plan)!;
    expect(plan.dependencies, contains(source.id));
    expect(aiContentOrigin(plan, resolve: f.node), '你确认的预案 · 含 AI 建议');
  });

  for (var step = 0; step < 7; step++) {
    testWidgets(
        'AI content is visibly identified at workbench step ${step + 1}',
        (tester) async {
      final c = MirrorController(
          store: MemoryStore(),
          model: OfflineModel(),
          reminders: TestReminders());
      await c.initialize();
      addTearDown(c.dispose);
      final f = labeledCase().evolve(step: step);
      await c.store.save(f, expectedRevision: 0);
      await c.reload();
      await tester.pumpWidget(
          MaterialApp(home: CaseWorkbench(controller: c, caseId: f.id)));
      await tester.pumpAndSettle();
      expect(find.text('AI 生成'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final view in ['经验认识', '个人原则']) {
    testWidgets(
        '$view shows AI origin separately from maturity and personal approval',
        (tester) async {
      final c = MirrorController(
          store: MemoryStore(),
          model: OfflineModel(),
          reminders: TestReminders());
      await c.initialize();
      addTearDown(c.dispose);
      final f = labeledCase();
      await c.store.save(f, expectedRevision: 0);
      await c.reload();
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: MirrorMePage(controller: c))));
      await tester.tap(find.text(view));
      await tester.pumpAndSettle();
      expect(find.text('AI 生成'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'scene playback and source sheets identify the source of edited AI content',
      (tester) async {
    var f = labeledCase();
    final original = f.latest(NodeKind.scene)!;
    final edited = commands.record(
        f, NodeKind.scene, {...original.body, 'fieldCue': '本人修改后的提醒'},
        evidenceIds: original.evidenceIds, revisionOf: original.id);
    f = commands.append(f, [edited]);
    final c = MirrorController(
        store: MemoryStore(),
        model: OfflineModel(),
        reminders: TestReminders());
    await c.initialize();
    addTearDown(c.dispose);
    await c.store.save(f, expectedRevision: 0);
    await c.reload();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SceneRehearsal(
                scene: edited,
                resolve: f.node,
                duration: 10,
                animate: false,
                onStop: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('AI 原稿 · 你已更新'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showNodeDetails(context, c, edited),
                    child: const Text('查看来源'))))));
    await tester.tap(find.text('查看来源'));
    await tester.pumpAndSettle();
    expect(find.text('AI 原稿 · 你已更新'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
