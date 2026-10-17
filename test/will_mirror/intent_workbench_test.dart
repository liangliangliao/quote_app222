import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/ai/pipeline.dart';
import 'package:quote_app/will_mirror/ai/protocol.dart';
import 'package:quote_app/will_mirror/ai/workbench_pass.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/domain/workbench_projection.dart';
import 'package:quote_app/will_mirror/presentation/design.dart';
import 'package:quote_app/will_mirror/presentation/journey_views.dart';
import 'package:quote_app/will_mirror/presentation/workbench.dart';
import 'ai_contract_test.dart' show FunctionModel, grant, inputOf;
import 'fixtures.dart';
import 'principle_application_test.dart' show principle;

Json fitBody(String routeId) => {
      'routeId': routeId,
      'wantFit': 'unknown',
      'bodySkillFit': 'unverified',
      'externalFeasibility': 'conditional',
      'motivationCognition': '现场是否想起仍未知',
      'hardSafetyGate': 'clear',
      'difficulty': null,
      'difficultyFactors': <Json>[],
      'matrix': <Json>[],
      'exploratoryIndex': null,
      'indexDimensions': <Json>[],
      'uncertainty': '还没有实际体验',
      'lowerDifficultyRouteId': null,
    };

Json responseRow(String id, String kind, Json body, List<String> refs) => {
      'id': id,
      'kind': kind,
      'body': body,
      'evidenceIds': refs,
      'counterIds': <String>[],
      'links': <String>[],
      'revisionOf': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), (_) async => 1));

  test(
      'first pass commits understanding without starting the fifty-motive workflow',
      () async {
    final f = newCase();
    final calls = <AnalysisStage>[];
    final model = FunctionModel((stage, prompt, _) async {
      calls.add(stage);
      final prefix = inputOf(prompt)['idPrefix'] as String;
      return {
        'records': stage == AnalysisStage.understand
            ? [
                responseRow('${prefix}u', 'understanding', {
                  'summary': '想争取机会，也想先弄清楚条件。',
                  'facts': [
                    {
                      'claim': f.issue,
                      'quote': f.issue,
                      'evidenceIds': [f.nodes.first.id]
                    }
                  ],
                  'unknowns': ['实际岗位要求'],
                  'keyQuestion': '岗位具体需要什么？',
                  'domains': ['工作'],
                  'riskFlags': <String>[],
                  'timeContext': 'future',
                }, [
                  f.nodes.first.id
                ])
              ]
            : <Json>[],
        'summary': '先保留未知',
        'unknowns': ['需要更多现实证据']
      };
    });
    final commits = <CaseFile>[];
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        options: {'workbenchPass': WorkbenchPass.understand.name},
        commit: (_, after, __) async => commits.add(after),
        progress: (_, __) {});
    expect(calls, [AnalysisStage.understand, AnalysisStage.wants]);
    expect(commits.first.latest(NodeKind.understanding), isNotNull);
    expect(result.current(NodeKind.motive), isEmpty);
    expect(result.latest(NodeKind.recommendation), isNull);
    expect(result.id, f.id);
  });

  test(
      'route comparison commits one target at a time and never merges matrices',
      () async {
    var f = prepared();
    final other = route(f);
    f = commands.append(f, [other]);
    final targets = <String>[];
    final model = FunctionModel((stage, prompt, _) async {
      final input = inputOf(prompt);
      final target = jsonMap(input['options'])['assessmentRouteId'] as String;
      targets.add(target);
      return {
        'records': [
          responseRow('${input['idPrefix']}fit', 'routeFit', fitBody(target),
              [f.nodes.first.id])
        ],
        'summary': '保留未知',
        'unknowns': ['实际体验']
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        options: {'workbenchPass': 'routes'},
        commit: (_, __, ___) async {},
        progress: (_, __) {});
    expect(targets, f.current(NodeKind.route).map((n) => n.id));
    expect(
        result.current(NodeKind.routeFit).map((n) => n.text('routeId')).toSet(),
        targets.toSet());
    expect(
        result
            .current(NodeKind.routeFit)
            .every((n) => n.number('difficulty') == null),
        isTrue);
  });

  test('scope retry resumes inside its pass without repeating earlier work',
      () {
    expect(requestedPass({'workbenchPass': 'understand', 'resumeAt': 'wants'}),
        [AnalysisStage.wants]);
    expect(
        () => requestedPass({'workbenchPass': 'routes', 'resumeAt': 'wants'}),
        throwsA(isA<MirrorProblem>()));
  });

  test('same motive keeps different directions for different routes', () {
    var f = prepared();
    final other = route(f);
    f = commands.append(f, [other]);
    final m = motive(f, 1);
    final mixed = commands.record(
        f,
        NodeKind.motive,
        {
          ...m.body,
          'directionByRoute': [
            {
              'routeId': f.selectedRouteId,
              'relation': 'supports',
              'reason': '可以核实条件'
            },
            {'routeId': other.id, 'relation': 'opposes', 'reason': '会失去核实的机会'},
          ]
        },
        evidenceIds: m.evidenceIds,
        origin: EvidenceOrigin.aiHypothesis);
    f = commands.append(f, [mixed]);
    expect(
        RouteReasons.forRoute(f, f.node(f.selectedRouteId)!).support.single.id,
        mixed.id);
    expect(RouteReasons.forRoute(f, other).opposition.single.id, mixed.id);
    expect(RouteReasons.forRoute(f, other).support, isEmpty);
  });

  test(
      'new condition cancels reminders and stops stale plans without altering the seal',
      () async {
    final store = MemoryStore(), reminders = TestReminders();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: reminders);
    await c.initialize();
    var f = prepared();
    f = commands.sealPlan(f, planBody(f));
    await store.save(f, expectedRevision: 0);
    await c.reload();
    final seal = f.latest(NodeKind.seal)!;
    await c.addEvidence(f.id, '岗位要求发生变化，尚待重新核实', materialChange: true);
    final revised = c.file(f.id)!;
    expect(revised.latest(NodeKind.plan), isNull);
    expect(revised.selectedRouteId, isNull);
    expect(revised.selectedMotiveIds, isEmpty);
    expect(realityTrace(revised).first.source?.id, f.latest(NodeKind.plan)!.id);
    expect(revised.node(seal.id)!.toJson(), seal.toJson());
    expect(EvidenceRules.verifySeal(revised.node(seal.id)!), isTrue);
    expect(
        EvidenceRules.routeCanBePrepared(
            revised.node(f.selectedRouteId)!, revised),
        isFalse);
    expect(revised.current(NodeKind.observation), isEmpty);
    final reassessed = commands.record(
        revised, NodeKind.routeFit, fitBody(f.selectedRouteId!),
        evidenceIds: [revised.nodes.first.id],
        origin: EvidenceOrigin.aiHypothesis);
    final fresh = commands.append(revised, [reassessed]);
    expect(
        EvidenceRules.routeCanBePrepared(fresh.node(f.selectedRouteId)!, fresh),
        isTrue);
    c.dispose();
  });

  test(
      'completed action does not fill missing decision, attempt, or satisfaction',
      () {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '已发出问题');
    final trace = realityTrace(f);
    expect(trace.firstWhere((r) => r.label == '临场选择').source, isNull);
    expect(trace.firstWhere((r) => r.label == '真实尝试').source, isNull);
    expect(trace.firstWhere((r) => r.label == '后续体验').source, isNull);
    expect(trace.firstWhere((r) => r.label == '实际行动').source, isNotNull);
  });

  test(
      'principle reuse needs a new match after changed conditions or a new episode',
      () {
    var f = prepared();
    final p = principle(f);
    f = commands.append(f, [p]);
    expect(EvidenceRules.principleCanBePrepared(p, f), isTrue);
    final update = commands.record(f, NodeKind.evidence, {
      'text': '实际岗位条件有变',
      'category': 'condition',
      'source': 'self_report',
      'sensitive': false,
      'scope': 'case_only',
      'context': 'requires_route_review',
    });
    f = commands.append(f, [update]);
    expect(EvidenceRules.principleCanBePrepared(p, f), isFalse);
    final match = commands.record(
        f,
        NodeKind.principleMatch,
        {
          'principleId': p.id,
          'routeIds': [f.selectedRouteId],
          'fit': 'conditional',
          'reason': '已经比较这次新条件，仅作为核实方法的参考',
          'changedConditions': ['岗位条件变化'],
          'riskGate': 'clear',
        },
        evidenceIds: [update.id],
        origin: EvidenceOrigin.aiHypothesis);
    f = commands.append(f, [match]);
    expect(EvidenceRules.principleCanBePrepared(p, f), isTrue);
    expect(EvidenceRules.principleCanBePrepared(p, commands.nextEpisode(f)),
        isFalse);
  });

  test('retrospective belief changes keep the after-event phase label', () {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '实际发出询问');
    expect(f.evolve(stage: CaseStage.reframed).phaseLabel, '事后回望');
  });

  test(
      'invalid workbench scope cannot leave an orphan permission or busy state',
      () async {
    final c = MirrorController(
        store: MemoryStore(),
        model: OfflineModel(),
        reminders: TestReminders());
    await c.initialize();
    final f = await c.create('真实课题');
    await expectLater(
        c.analyze(grant(f), options: {'workbenchPass': 'invented'}),
        throwsA(isA<MirrorProblem>()));
    expect(c.busyCaseId, isNull);
    expect(c.file(f.id)!.current(NodeKind.permission), isEmpty);
    c.dispose();
  });

  test(
      'superseded-route motives leave the live pool while historical evidence remains',
      () {
    var f = prepared();
    final oldRoute = f.node(f.selectedRouteId)!;
    final oldMotive = motive(f, 1);
    f = commands.append(f, [oldMotive]);
    final newRoute = commands.record(
        f, NodeKind.route, {...oldRoute.body, 'title': '调整后的走法'},
        revisionOf: oldRoute.id,
        evidenceIds: oldRoute.evidenceIds,
        origin: EvidenceOrigin.aiHypothesis);
    f = commands.append(f, [newRoute]);
    expect(f.current(NodeKind.motive), isEmpty);
    expect(
        f.current(NodeKind.motive, allEpisodes: true).single.id, oldMotive.id);
    expect(f.node(oldMotive.id), isNotNull);
    expect(() => commands.chooseMotive(f, oldMotive.id, true),
        throwsA(isA<MirrorProblem>()));
  });

  test(
      'historical reasons cannot suppress current-route candidates during deduplication',
      () async {
    var f = prepared();
    final oldRoute = f.node(f.selectedRouteId)!;
    final oldMotive = motive(f, 1, semanticKey: 'same_reason');
    f = commands.append(f, [oldMotive]);
    f = commands.chooseMotive(f, oldMotive.id, true);
    final newRoute = commands.record(
        f, NodeKind.route, {...oldRoute.body, 'title': '新的实际走法'},
        revisionOf: oldRoute.id,
        evidenceIds: oldRoute.evidenceIds,
        origin: EvidenceOrigin.aiHypothesis);
    f = commands.append(f, [newRoute]);
    final template = motive(f, 1, semanticKey: 'same_reason');
    final model = FunctionModel((stage, prompt, _) async {
      if (prompt.startsWith('这是独立语义审查')) {
        final pool = jsonDecode(prompt.split('\n').last) as List;
        return {
          'items': [
            for (final n in pool)
              {'id': n['id'], 'duplicateOf': null, 'reason': '当前路线的有效候选'}
          ]
        };
      }
      final input = inputOf(prompt);
      return {
        'records': [
          responseRow('${input['idPrefix']}fresh', 'motive', template.body,
              [f.nodes.first.id])
        ],
        'summary': '只保留有来源的当前候选',
        'unknowns': ['不凑数']
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.motives,
        commit: (_, __, ___) async {},
        progress: (_, __) {});
    expect(result.current(NodeKind.motive).single.id, isNot(oldMotive.id));
    expect(result.selectedRouteId, isNull);
    expect(result.selectedMotiveIds, isEmpty);
    expect(
        result
            .current(NodeKind.motive)
            .single
            .objects('directionByRoute')
            .single['routeId'],
        newRoute.id);
    expect(result.analysisMessage, contains('1 条'));
  });

  testWidgets('feedback is a single sheet and unknown remains unknown',
      (tester) async {
    final store = MemoryStore();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: TestReminders());
    await c.initialize();
    final f = await c.create('要核实一个现实条件');
    await c.advance(f.id, 6);
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.light),
        home: CaseWorkbench(controller: c, caseId: f.id)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('记录实际观察'));
    await tester.tap(find.text('记录实际观察'));
    await tester.pumpAndSettle();
    expect(find.text('行动本身'), findsOneWidget);
    expect(find.text('外部结果'), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('mirror-save-observation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mirror-save-observation')));
    await tester.pumpAndSettle();
    final observed = c.file(f.id)!.latest(NodeKind.observation)!;
    expect(observed.text('actionState'), 'unknown');
    expect(observed.text('outcomeState'), 'unknown');
    expect(EvidenceRules.canReveal(c.file(f.id)!), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('conflict view fits a narrow screen with large type',
      (tester) async {
    var f = prepared();
    f = commands.append(f, [motive(f, 1), motive(f, 2, relation: 'opposes')]);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: mirrorTheme(Brightness.dark),
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(
                    size: Size(320, 700), textScaler: TextScaler.linear(1.8)),
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child:
                            MotiveConflictPanel(file: f, onNode: (_) {})))))));
    await tester.pumpAndSettle();
    expect(find.text('让我想停下或换路'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
