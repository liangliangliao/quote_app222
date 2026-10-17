import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/will_mirror/ai/pipeline.dart';
import 'package:quote_app/will_mirror/ai/protocol.dart';
import 'package:quote_app/will_mirror/application/controller.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/rules.dart';
import 'package:quote_app/will_mirror/domain/ranking.dart';
import 'package:quote_app/will_mirror/integration/private_model.dart';
import 'ai_contract_test.dart'
    show ConfigHost, FunctionModel, grant, inputOf, row;
import 'fixtures.dart';

Json insightBody({String maturity = 'tentative'}) => {
      'claim': '在这次条件下，先核实信息可能有帮助，仍需检验',
      'category': 'want',
      'contexts': ['本次岗位核实'],
      'alternativeExplanations': ['时间与对方回复也可能影响结果'],
      'confounders': ['不同情境尚未比较'],
      'maturity': maturity,
      'falsifier': '其他相似机会中取舍不同',
      'nextTest': '下次机会记录实际条件',
      'unknowns': ['是否适用于其他情境']
    };

void main() {
  test(
      'a superseded route cannot activate an old plan or rank its old support as current',
      () {
    var f = prepared();
    final old = f.node(f.selectedRouteId)!;
    final supporting = motive(f, 1);
    f = commands.append(f, [supporting]);
    final revised = commands.record(
        f, NodeKind.route, {...old.body, 'title': '补充事实后重新核实的走法'},
        revisionOf: old.id,
        evidenceIds: old.evidenceIds,
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft);
    f = commands.append(f, [revised]);
    expect(f.current(NodeKind.route).single.id, revised.id);
    expect(EvidenceRules.routeCanBePrepared(old, f), false);
    expect(MotiveRanking.eligible(supporting, f), false);
    expect(f.node(old.id)!.body, old.body);
  });
  test(
      'repeated route analysis must revise prior IDs instead of exceeding six active alternatives',
      () async {
    var f = prepared();
    f = commands.append(f, [for (var i = 0; i < 5; i++) route(f)]);
    final model = FunctionModel((stage, prompt, schema) async {
      final data = inputOf(prompt);
      return {
        'records': [
          for (var i = 0; i < 3; i++) row(route(f), '${data['idPrefix']}$i')
        ],
        'summary': '不合格的重复追加',
        'unknowns': []
      };
    });
    var commits = 0;
    await expectLater(
        CaseAnalysisPipeline(model).run(
            file: f,
            consent: grant(f),
            cancel: CancelToken(),
            onlyStage: AnalysisStage.options,
            commit: (a, b, s) async {
              commits++;
            },
            progress: (s, d) {}),
        throwsA(isA<MirrorProblem>()));
    expect(model.calls, 2);
    expect(commits, 0);
  });
  test('weight adjustment retains the original online scoring and expiry times',
      () async {
    final store = MemoryStore();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: TestReminders());
    await c.initialize();
    var f = prepared();
    final candidate = motive(f, 1);
    f = commands.append(f, [candidate]);
    final ranking = MotiveRanking.build(f,
        method: 'decisions',
        model: 'gpt-6-luna',
        scoredAt: time,
        facets: {
          candidate.id: [
            for (final dimension in rankingDimensions)
              {
                'dimension': dimension,
                'score': 2.5,
                'confidence': .8,
                'status': 'scored',
                'answerName': 'fixture_$dimension'
              }
          ]
        });
    f = commands.append(f, [ranking]);
    await store.save(f, expectedRevision: 0);
    await c.reload();
    await c.updateWeights([.1, .2, .3, .4], f.id);
    final next = c.file(f.id)!.latest(NodeKind.recommendation)!;
    expect(next.text('scoredAt'), time.toIso8601String());
    expect(next.text('expiresAt'),
        time.add(const Duration(hours: 24)).toIso8601String());
    expect(c.file(f.id)!.node(ranking.id)!.body, ranking.body);
    c.dispose();
  });
  test('latest hard safety assessment blocks high-scored supporting motives',
      () {
    var f = prepared();
    final supporting = motive(f, 1);
    f = commands.append(f, [supporting]);
    final fit = commands.record(f, NodeKind.routeFit,
        {'routeId': f.selectedRouteId, 'hardSafetyGate': 'blocked'});
    f = f.evolve(nodes: [...f.nodes, fit]);
    expect(MotiveRanking.eligible(supporting, f), false);
    expect(MotiveRanking.build(f).objects('ranked'), isEmpty);
  });
  test('unreferenced AI guesses cannot use verified fact status', () {
    final f = prepared();
    final original = motive(f, 1, refs: []);
    final guessed = commands.record(
        f, NodeKind.motive, {...original.body, 'factStatus': 'verified'},
        origin: EvidenceOrigin.aiHypothesis, status: NodeStatus.draft);
    expect(() => EvidenceRules.validateBatch(f, [guessed], modelOutput: true),
        throwsA(isA<MirrorProblem>()));
  });
  test('later user records cannot acquire an earlier knowledge phase', () {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '已询问');
    final late = commands.record(f, NodeKind.decision, {}, phase: TimePhase.t0);
    expect(late.phase, TimePhase.t2);
    expect(f.nodes.first.phase, TimePhase.t0);
  });
  test(
      'known exclusive resources prohibit a parallel tradeoff but allow sequencing',
      () {
    var f = prepared();
    final second = route(f);
    f = commands.append(f, [second]);
    final conflict = commands.record(f, NodeKind.resourceConflict, {
      'routeAId': f.selectedRouteId,
      'routeBId': second.id,
      'resource': '同一时间窗口',
      'window': '明天下午',
      'relation': 'strictly_exclusive',
      'capacityBasis': '本人核实时间重叠',
      'irreversibility': '尚可调整安排',
      'alternatives': ['分期'],
      'status': 'reported'
    }, evidenceIds: [
      f.nodes.first.id
    ]);
    f = commands.append(f, [conflict]);
    final body = {
      'selectedRouteIds': [f.selectedRouteId, second.id],
      'deferredRouteIds': <String>[],
      'abandonedRouteIds': <String>[],
      'mode': 'parallel',
      'cost': '时间冲突',
      'restoreCondition': '协调另一时间',
      'userConfirmed': true
    };
    expect(
        () => commands.append(f, [commands.record(f, NodeKind.tradeoff, body)]),
        throwsA(isA<MirrorProblem>()));
    expect(
        commands
            .append(f, [
              commands
                  .record(f, NodeKind.tradeoff, {...body, 'mode': 'sequence'})
            ])
            .latest(NodeKind.tradeoff)!
            .text('mode'),
        'sequence');
  });
  test(
      'two actual events without free informed alternatives cannot prove a stable want',
      () {
    var f = prepared();
    f = commands.observe(f, body: observationBody(f), evidenceText: '被要求发出问题');
    final first = f.latest(NodeKind.observation)!;
    f = commands.nextEpisode(f);
    f = commands.observe(f, body: observationBody(f), evidenceText: '再次被要求询问');
    final second = f.latest(NodeKind.observation)!;
    final claim = commands.record(
        f, NodeKind.insight, insightBody(maturity: 'multiple_contexts'),
        origin: EvidenceOrigin.aiHypothesis,
        status: NodeStatus.draft,
        evidenceIds: [first.id, second.id]);
    expect(() => EvidenceRules.validateBatch(f, [claim], modelOutput: true),
        throwsA(isA<MirrorProblem>()));
  });
  test(
      'safety reappraisal immediately retires preparation and cancels the OS job',
      () async {
    final store = MemoryStore(), reminders = TestReminders();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: reminders);
    await c.initialize();
    final initial = prepared();
    await store.save(initial, expectedRevision: 0);
    await c.reload();
    await c.seal(
        initial.id,
        {
          ...planBody(initial),
          'remindAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String()
        },
        reminderPermission: true);
    var f = c.file(initial.id)!;
    final plan = f.latest(NodeKind.plan)!;
    final seal = f.latest(NodeKind.seal)!;
    final sealJson = canonicalJson(seal.body);
    await c.verifyTrigger(f.id, 'confirmed', '到达现场发现资格条件变化',
        occurredAt: DateTime.now());
    f = c.file(f.id)!;
    await c.recordNode(f.id, NodeKind.reappraisal, {
      'triggerCheckId': f.latest(NodeKind.triggerCheck)!.id,
      'planId': plan.id,
      'changes': ['原安全条件已变化'],
      'immediateMotive': '先核实',
      'rememberedMotiveIds': <String>[],
      'safetyChanged': true,
      'choice': 'verify',
      'routeId': null
    });
    f = c.file(f.id)!;
    expect(f.node(plan.id)!.status, NodeStatus.stale);
    expect(reminders.jobs, isEmpty);
    expect(
        EvidenceRules.routeCanBePrepared(f.node(f.selectedRouteId)!, f), false);
    expect(canonicalJson(f.node(seal.id)!.body), sealJson);
    expect(EvidenceRules.verifySeal(f.node(seal.id)!), true);
    c.dispose();
  });
  test(
      'identical completed analysis reuses its result and new facts invalidate reuse',
      () async {
    final store = MemoryStore();
    final c = MirrorController(
        store: store, model: OfflineModel(), reminders: TestReminders());
    await c.initialize();
    var f = prepared();
    f = commands.append(f, [for (var i = 0; i < 50; i++) motive(f, i)]);
    // Only presence is relevant to cache eligibility; route assessment validation
    // is independently covered by the domain suite.
    f = f
        .evolve(nodes: [...f.nodes, commands.record(f, NodeKind.routeFit, {})]);
    final consent = grant(f);
    final fingerprint = digest({
      'sources': (consent.evidenceIds.toList()..sort())
          .map((id) => f.node(id)?.toJson())
          .toList(),
      'scope': <String>[],
      'sensitive': false,
      'selectedRouteId': f.selectedRouteId,
      'selectedMotiveIds': f.selectedMotiveIds,
      'phase': f.phase.name,
      'provider': c.providerLabel
    });
    f = commands.append(f, [
      commands.record(
          f,
          NodeKind.permission,
          {
            'purpose': 'analysis',
            'allowedIds': consent.evidenceIds.toList(),
            'sourceCaseIds': <String>[],
            'sensitiveAllowed': false,
            'granted': true,
            'runId': consent.runId,
            'analysisFingerprint': fingerprint,
            'stage': 'full',
            'completed': true
          },
          origin: EvidenceOrigin.deviceEvent)
    ]);
    await store.save(f, expectedRevision: 0);
    await c.reload();
    await c.analyze(grant(f));
    expect(c.notice, contains('资料未发生变化'));
    expect(c.file(f.id)!.revision, f.revision);
    await c.addEvidence(f.id, '刚收到不同的新条件');
    await c.analyze(grant(c.file(f.id)!));
    expect(c.notice, isNull);
    expect(c.error, contains('尚未配置'));
    c.dispose();
  });
  for (final rejectAlways in [false, true]) {
    test(
        'independent learning review ${rejectAlways ? 'rejects persistent violations' : 'repairs once before commit'}',
        () async {
      var f = prepared();
      f = commands.observe(f,
          body: observationBody(f), evidenceText: '实际已发出询问');
      var audits = 0, commits = 0;
      final model = FunctionModel((stage, prompt, schema) async {
        if ((schema['properties'] as Map).containsKey('violations')) {
          audits++;
          return {
            'violations': rejectAlways || audits == 1 ? ['permanent_label'] : []
          };
        }
        final data = inputOf(prompt);
        final node = commands.record(f, NodeKind.insight, insightBody(),
            evidenceIds: [f.latest(NodeKind.observation)!.id]);
        return {
          'records': [row(node, '${data['idPrefix']}insight')],
          'summary': '候选需本人核实',
          'unknowns': ['其他情境未知']
        };
      });
      final run = CaseAnalysisPipeline(model).run(
          file: f,
          consent: grant(f),
          cancel: CancelToken(),
          onlyStage: AnalysisStage.learning,
          commit: (before, after, stage) async {
            commits++;
          },
          progress: (s, d) {});
      if (rejectAlways) {
        await expectLater(run, throwsA(isA<MirrorProblem>()));
        expect(commits, 0);
      } else {
        final result = await run;
        expect(result.current(NodeKind.insight), hasLength(1));
        expect(commits, 1);
      }
      expect(audits, 2);
      expect(model.calls, 4);
    });
  }
  test('Azure tries an alternate path only after an unsupported endpoint',
      () async {
    var calls = 0;
    final model = HostPrivateModel(
        host: ConfigHost(const UnifiedAiResolvedConfig(
            provider: 'azure',
            apiKey: 'fixture',
            model: 'resource/gpt-6-luna',
            deployment: 'gpt-6-luna',
            endpoint: 'https://example.test/old',
            endpointCandidates: [
              'https://example.test/old',
              'https://example.test/openai/v1/chat/completions'
            ],
            authHeaders: {'api-key': 'fixture'},
            label: 'fixture',
            displayModel: 'fixture',
            available: true)),
        clientFactory: () => MockClient((request) async {
              calls++;
              expect(request.headers['api-key'], 'fixture');
              final body = jsonMap(jsonDecode(request.body));
              expect(body['model'], 'gpt-6-luna');
              expect(body['max_completion_tokens'], 16000);
              if (calls == 1) return http.Response('private ignored', 404);
              return http.Response(
                  jsonEncode({
                    'choices': [
                      {
                        'message': {'content': '{"summary":"ok"}'},
                        'finish_reason': 'stop'
                      }
                    ]
                  }),
                  200);
            }));
    final result = await model.complete(
        stage: AnalysisStage.understand,
        system: '',
        prompt: '',
        schema: {},
        cancel: CancelToken());
    expect(result['summary'], 'ok');
    expect(calls, 2);
  });
  test('Azure Claude uses Messages body and parses text blocks', () async {
    final model = HostPrivateModel(
        host: ConfigHost(const UnifiedAiResolvedConfig(
            provider: 'azure',
            apiKey: 'fixture',
            model: 'claude',
            endpoint: 'https://example.test/anthropic/v1/messages',
            label: 'fixture',
            displayModel: 'fixture',
            available: true)),
        clientFactory: () => MockClient((request) async {
              expect(request.headers['x-api-key'], 'fixture');
              final body = jsonMap(jsonDecode(request.body));
              expect(body['system'], 'system');
              expect(body.containsKey('response_format'), false);
              return http.Response(
                  jsonEncode({
                    'stop_reason': 'end_turn',
                    'content': [
                      {'type': 'text', 'text': '{"summary":"ok"}'}
                    ]
                  }),
                  200);
            }));
    expect(
        (await model.complete(
            stage: AnalysisStage.understand,
            system: 'system',
            prompt: '',
            schema: {},
            cancel: CancelToken()))['summary'],
        'ok');
  });
}
