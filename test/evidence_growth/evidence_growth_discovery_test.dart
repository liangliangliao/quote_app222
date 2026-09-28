import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_cache.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_json.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_form_drafts.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_discovery.dart';
import 'package:quote_app/evidence_growth/evidence_growth_discovery_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_runtime.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_store.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/evidence_growth/evidence_growth_smart_form.dart';

class _TextAi extends UnifiedAiService {
  _TextAi(this.response);
  final Future<String> Function(String, String) response;
  final calls = <String>[];
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: 'test-only',
          model: 'text-model',
          endpoint: 'https://example.test',
          label: 'test',
          displayModel: 'text-model',
          available: true);
  @override
  Future<String> generateText(
      {required String prompt,
      required String purpose,
      String? systemPrompt,
      int maxTokens = 1800,
      bool expectJson = false,
      String? forcedProvider,
      String? forcedModel,
      double? temperature}) async {
    calls.add(purpose);
    return response(purpose, prompt);
  }
}

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EvidenceGrowthDao(database: () async => db);
    await dao.ensureTables();
  });
  tearDown(() => db.close());
  const raw = '作品初稿写好了，迟迟没有发送，希望弄清卡点。';
  final n = EvidenceGrowthKnowledge.source('A02');
  GrowthData candidate(int i) => {
        'need': '需求 $i',
        'problem': '作品交流的候选问题 $i',
        'intention': '可能希望获得反馈',
        'reason': '待确认的解释',
        'fact_quote': '迟迟没有发送',
        'question': '是否符合自己？',
        'score': .5
      };
  List<GrowthData> selected() => [
        {'id': 'need_1', 'need': '获得具体反馈', 'problem': '如何开始发送作品'}
      ];
  List<GrowthData> knowledge() => [
        {'id': n.id, 'snapshot': n.toJson(), 'score': .9, 'score_origin': 'JEV'}
      ];
  GrowthData solution() => {
        'summary': '根据已选需要尝试一次作品交流',
        'relationships': '先减少启动阻力，再获取反馈',
        'steps': [
          {
            'need_ids': ['need_1'],
            'node_ids': [n.id],
            'action': '把一段作品发给愿意阅读的人',
            'why': '小行动用于取得现实反馈',
            'signal': '是否完成发送以及收到什么反馈',
            'boundary': '对方不愿意时不反复联系'
          }
        ],
        'suggested_goal': '获得一条作品反馈',
        'first_step': '先整理一段作品',
        'origin': 'AI'
      };
  EvidenceGrowthJev judge({bool fail = false}) =>
      EvidenceGrowthJev(client: MockClient((request) async {
        if (fail) return http.Response('{}', 503);
        final q = growthMap(growthMap(jsonDecode(request.body))['questions']);
        return http.Response(
            jsonEncode({
              'model': 'jev-test',
              'answers': {
                for (final key in q.keys)
                  key: {
                    'type': 'noul',
                    'noul': key.startsWith('need_')
                        ? int.parse(key.substring(5)) / 40
                        : key.startsWith('contra_')
                            ? 0.05
                            : 0.85
                  }
              }
            }),
            200);
      }));
  test(
      'JSON handles provider prose, fences, quoted braces; incomplete JSON fails',
      () {
    expect(
        GrowthAiJson.decode(
                '说明\n```json\n{"text":"a { value }","nested":{"x":1}}\n```')[
            'text'],
        'a { value }');
    expect(() => GrowthAiJson.decode('{"broken":'), throwsFormatException);
  });
  test(
      'successful cache survives instance recreation, preserves canonical keys and invalidates cycle/model',
      () async {
    var calls = 0;
    Future<GrowthData> generate() async => {'origin': 'AI', 'value': ++calls};
    await GrowthAiCache(dao).run('test', {'cycle': 1, 'model': 'a'}, generate);
    final hit = await GrowthAiCache(dao)
        .run('test', {'model': 'a', 'cycle': 1}, generate);
    expect(calls, 1);
    expect(hit['cache_hit'], true);
    await GrowthAiCache(dao).run('test', {'cycle': 2, 'model': 'a'}, generate);
    await GrowthAiCache(dao).run('test', {'cycle': 2, 'model': 'b'}, generate);
    await GrowthAiCache(dao)
        .run('test', {'cycle': 2, 'model': 'b'}, generate, refresh: true);
    expect(calls, 4);
  });
  test('inflight requests coalesce while service failures remain retryable',
      () async {
    final done = Completer<GrowthData>();
    var calls = 0;
    final cache = GrowthAiCache(dao);
    Future<GrowthData> load() {
      calls++;
      return done.future;
    }

    final a = cache.run('dedupe', raw, load),
        b = cache.run('dedupe', raw, load);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    done.complete({'origin': 'LOCAL_RULE'});
    await Future.wait([a, b]);
    expect(calls, 1);
    await cache.run('dedupe', raw, () async {
      calls++;
      return {'origin': 'AI'};
    });
    expect(calls, 2);
  });
  test(
      'LLM explores distinct needs, JEV sorts the top 20, no selection is made for user',
      () async {
    final ai = _TextAi((_, __) async =>
        jsonEncode({'candidates': List.generate(30, candidate)}));
    final service =
        GrowthDiscovery(dao, ai: ai, jev: judge(), key: () async => 'test');
    final result = await service.discover(raw);
    final rows = growthRows(result['candidates']);
    expect(rows, hasLength(20));
    expect(result['ranking_origin'], 'JEV');
    expect(rows.first['id'], 'need_30');
    expect(rows.first['origin'], 'AI_HYPOTHESIS');
    expect(rows.any((r) => r['selected'] == true), false);
    await GrowthDiscovery(dao, ai: ai, jev: judge(), key: () async => 'test')
        .discover(raw);
    expect(ai.calls, hasLength(1));
  });
  test('JEV failure remains labelled LLM, does not manufacture JEV scores',
      () async {
    final ai = _TextAi((_, __) async =>
        jsonEncode({'candidates': List.generate(22, candidate)}));
    final r = await GrowthDiscovery(dao,
        ai: ai, jev: judge(fail: true), key: () async => 'test').discover(raw);
    expect(r['ranking_origin'], 'LLM');
    expect(growthRows(r['candidates']).every((r) => r['score_origin'] == 'LLM'),
        true);
  });
  test('candidate facts must be literal input excerpts', () {
    expect(
        () => GrowthDiscovery.needs({
              'candidates': [
                {...candidate(1), 'fact_quote': '曾经获得大奖'}
              ]
            }, raw),
        throwsFormatException);
  });
  test(
      'knowledge is ranked across a recalled pool and returns five with JEV provenance',
      () async {
    final r = await GrowthDiscovery(dao, jev: judge(), key: () async => 'test')
        .knowledge(raw, selected());
    final rows = growthRows(r['candidates']);
    expect(rows, hasLength(5));
    expect(r['ranking_origin'], 'JEV');
    expect(
        rows.every((row) =>
            row['score'] is num &&
            growthMap(row['snapshot'])['node_id'] == row['id']),
        true);
  });
  test(
      'solution excludes unselected needs and sources, covers every selected need',
      () {
    expect(
        GrowthDiscovery.checkedSolution(
            solution(), selected(), knowledge())['origin'],
        'AI');
    final bad = solution();
    growthRows(bad['steps']).first['node_ids'] = ['invented'];
    // Rows may be copied by growthRows: construct explicit invalid input.
    expect(
        () => GrowthDiscovery.checkedSolution({
              ...solution(),
              'steps': [
                {
                  ...growthRows(solution()['steps']).first,
                  'node_ids': ['invented']
                }
              ]
            }, selected(), knowledge()),
        throwsFormatException);
    expect(
        () => GrowthDiscovery.checkedSolution(
            solution(),
            [
              ...selected(),
              {'id': 'need_2', 'need': '另一需要'}
            ],
            knowledge()),
        throwsFormatException);
  });
  test(
      'user confirmed choices persist; compiled action uses only chosen knowledge',
      () async {
    var j = await dao.journeys.create(raw);
    j = await dao.journeys.change(j, 'discovery-confirm', {
      'raw_input': raw,
      'needs': selected(),
      'knowledge': knowledge(),
      'solution': solution(),
      'user_confirmed': true
    });
    expect(j.confirmed, false);
    expect(j.node, 'BELIEF');
    j = await dao.journeys.change(j, 'contract',
        {'goal': '获得反馈', 'current': raw, 'criterion': '收到一个具体建议'});
    final route = EvidenceGrowthJourneyRuntime.compile(j);
    expect(route.selectedNodes.map((n) => n.id), [n.id]);
    expect(route.riskChecks['SELECTION'], 'USER_KNOWLEDGE_SELECTION');
    expect(
        (await dao.journeys.find(j.id))!.data['confirmed_needs'], selected());
  });
  test(
      'six module stats count real node runs, successful AI drafts and knowledge usage separately',
      () async {
    final j = await dao.journeys.create(raw);
    for (final node in [
      'BELIEF',
      'GOAL',
      'ACTION',
      'OUTCOME',
      'REVIEW',
      'CHANGE'
    ]) {
      await EvidenceGrowthJourneyStore.nodeRun(db, j, node, {}, {});
      await dao.journeys
          .recordDraft(j, 'node', {'origin': 'AI', 'stage': node}, [n]);
    }
    final stats = await dao.summary();
    for (final m in GrowthModule.values) {
      expect(stats.nodeRunCounts[m], 1);
      expect(stats.aiCounts[m], 1);
    }
    await dao.summary();
    expect((await dao.summary()).aiCounts[GrowthModule.goal], 1);
  });
  test(
      'first journey route needs no previous learning; successful route cache preserves facts and frozen knowledge',
      () async {
    var j = await dao.journeys.create(raw);
    j = await dao.journeys.change(j, 'contract',
        {'goal': '获得作品反馈', 'current': raw, 'criterion': '收到一条建议'});
    final frozen =
        EvidenceKNode.fromJson({...n.toJson(), 'version': n.version + 100});
    final route = EvidenceGrowthJourneyRuntime.compile(j).copyWith(
        selectedNodes: [frozen],
        operator: frozen.operators.first,
        facts: ['作品初稿写好了'],
        riskChecks: {'SELECTION': 'USER_KNOWLEDGE_SELECTION'});
    final ai = _TextAi((_, __) async => jsonEncode({
          'selected_nodes': [
            {'node_id': n.id}
          ],
          'inference': '用小范围可撤回行动获取具体反馈',
          'confidence': .7,
          'operator': route.operator,
          'action_instruction': '先用五分钟整理一段作品',
          'completion_definition': '整理一段',
          'risk_gate': 'PASS',
          'evidence_status': 'E1',
          'review_trigger': '一次尝试之后',
          'alternatives': [],
          'cycle_plan': {
            'goal': j.title,
            'current': raw,
            'gap': '开始获取反馈',
            'belief': '先验证一次',
            'belief_basis': '已有初稿',
            'expected_signal': '记录是否完成整理',
            'why_action': '降低启动阻力',
            'learning_applied': ''
          }
        }));
    final service = EvidenceGrowthAiService(dao: dao, ai: ai);
    final result = await service.enrichRoute(route);
    expect(result.riskChecks['CONTENT_ORIGIN'], 'AI',
        reason: result.riskChecks['CONTENT_REASON']);
    expect(ai.calls, hasLength(1));
    final hit =
        await EvidenceGrowthAiService(dao: dao, ai: ai).enrichRoute(route);
    expect(ai.calls, hasLength(1));
    expect(hit.facts, ['作品初稿写好了']);
    expect(hit.selectedNodes.single.version, n.version + 100);
    expect(hit.riskChecks['CACHE_HIT'], 'true');
    await service.enrichRoute(route, refresh: true);
    expect(ai.calls, hasLength(2));
  });
  test(
      'review accepts exact excerpts but persists complete original facts; cache and manual refresh work',
      () async {
    var trial = await dao.createTrial(
        const EvidenceGrowthRouter().route('作品已经准备好，拖延没开始'),
        prediction: '对方会指出一处改进',
        probability: .6,
        reviewAt: DateTime.now().subtract(const Duration(hours: 1)),
        riskConfirmed: true);
    trial = await dao.startTrial(trial);
    trial = await dao.captureResult(trial,
        didAction: true,
        actualOutcome: '发出作品后，对方指出了两处可修改的地方。',
        unexpected: '实际有两处建议',
        resultStatus: 'DONE',
        resultMeasurements: {
          'outcome_helpful': 'true',
          'signal_final': 'true'
        });
    final ai = _TextAi((_, __) async =>
        '模型回复：\n' +
        jsonEncode({
          'actual_facts': ['对方指出了两处可修改的地方'],
          'prediction_error': '实际反馈比预期更具体',
          'failure_class': 'NO_FAILURE',
          'learning': '本次获得了可用信息，不能概括所有情境',
          'rule_update': '保留小范围具体提问',
          'decision': 'ACT',
          'next_change_one_variable': '保持相同提问方式，再获取一条具体意见',
          'knowledge_nodes_used': trial.nodeIds
        }));
    final service = EvidenceGrowthAiService(dao: dao, ai: ai);
    final result = await service.review(trial);
    expect(result.contentOrigin, 'AI', reason: result.contentDetail);
    expect(result.actualFacts, [trial.actualOutcome, trial.unexpected]);
    expect(result.predictionOriginal, trial.prediction);
    await EvidenceGrowthAiService(dao: dao, ai: ai).review(trial);
    expect(ai.calls, hasLength(1));
    await service.review(trial, refresh: true);
    expect(ai.calls, hasLength(2));
    final saved = await dao.saveReview(trial, result);
    expect(saved.prediction, trial.prediction);
    expect(saved.actualOutcome, trial.actualOutcome);
  });
  test('manual JEV rematch bypasses judge memory cache', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final questions =
          growthMap(growthMap(jsonDecode(request.body))['questions']);
      return http.Response(
          jsonEncode({
            'answers': {
              for (final k in questions.keys) k: {'type': 'noul', 'noul': .5}
            }
          }),
          200);
    });
    final jev = EvidenceGrowthJev(client: client);
    await jev.rank({'raw': raw}, [n], apiKey: 'test');
    await jev.rank({'raw': raw}, [n], apiKey: 'test');
    expect(calls, 1);
    await jev.rank({'raw': raw}, [n], apiKey: 'test', refresh: true);
    expect(calls, 2);
  });
  test(
      'new cycle uses its confirmed changed action instead of the initial discovery proposal',
      () async {
    var j = await dao.journeys.create(raw);
    j = await dao.journeys.change(j, 'discovery-confirm', {
      'user_confirmed': true,
      'needs': selected(),
      'knowledge': knowledge(),
      'solution': solution(),
      'raw_input': raw
    });
    j = await dao.journeys.change(j, 'contract',
        {'goal': '获取具体反馈', 'current': raw, 'criterion': '获得一条建议'});
    j = j.copy({
      'cycle': 2,
      'next_change': {'target': 'MODIFY', 'next_action': '先核对作品中一条具体建议'},
      'previous_plan_version': j.plan['version']
    });
    final route = EvidenceGrowthJourneyRuntime.compile(j);
    expect(route.actionInstruction, '先核对作品中一条具体建议');
    expect(route.actionInstruction, isNot(solution()['first_step']));
  });
  test(
      'knowledge snapshots are canonical and a plan cannot smuggle an unselected source',
      () async {
    var j = await dao.journeys.create(raw);
    final forged = [
      {
        ...knowledge().single,
        'snapshot': {...n.toJson(), 'title': '篡改标题'}
      }
    ];
    j = await dao.journeys.change(j, 'discovery-confirm', {
      'user_confirmed': true,
      'needs': selected(),
      'knowledge': forged,
      'solution': solution()
    });
    expect(
        growthMap(growthRows(j.data['selected_knowledge']).single['snapshot'])[
            'title'],
        n.title);
    await expectLater(
        dao.journeys.change(j, 'discovery-confirm', {
          'user_confirmed': true,
          'needs': selected(),
          'knowledge': knowledge(),
          'solution': {
            ...solution(),
            'steps': [
              {
                ...growthRows(solution()['steps']).first,
                'node_ids': ['not-selected']
              }
            ]
          }
        }),
        throwsArgumentError);
  });
  test(
      'form defaults contain valid numbers and AI fills optional fields with labelled, cached suggestions',
      () async {
    const fields = {
      'goal': '目标',
      'quality': '边界',
      'minutes': '分钟',
      'energy': '精力',
      'attention': '数量'
    };
    final defaults = GrowthFormDrafts.defaults(
        fields, {'title': '整理作品', 'current': '', 'raw_input': raw});
    expect(int.tryParse(defaults['minutes']!), isNotNull);
    expect(int.tryParse(defaults['energy']!), isNotNull);
    final ai = _TextAi((_, __) async => jsonEncode({'fields': defaults}));
    final service = GrowthFormDrafts(dao, ai: ai);
    final result = await service.generate('核对目标', fields, {'title': '整理作品'});
    expect(result['origin'], 'AI');
    expect(growthMap(result['fields']).keys, containsAll(fields.keys));
    await GrowthFormDrafts(dao, ai: ai)
        .generate('核对目标', fields, {'title': '整理作品'});
    expect(ai.calls, hasLength(1));
  });
  testWidgets(
      'all fields are prefilled; late AI cannot overwrite typed or existing user content',
      (tester) async {
    final response = Completer<GrowthData>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GrowthSmartForm(
                title: '目标核对',
                fields: const {
                  'goal': '希望怎样',
                  'current': '当前事实',
                  'quality': '边界'
                },
                initial: const {'current': '已经记录的事实'},
                requiredKeys: const ['goal', 'current'],
                contextData: const {'title': '准备作品'},
                loader: (_) => response.future))));
    await tester.enterText(find.byKey(const ValueKey('form_goal')), '我亲自修改的目标');
    response.complete({
      'origin': 'AI',
      'fields': {'goal': '另一个目标', 'current': '不应覆盖事实', 'quality': '保留休息'}
    });
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('form_goal')))
            .controller!
            .text,
        '我亲自修改的目标');
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('form_current')))
            .controller!
            .text,
        '已经记录的事实');
    await tester.tap(find.text('更多细节（1 项，已预填可修改）'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('form_quality')))
            .controller!
            .text,
        '保留休息');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'new discovery page exposes two explicit choice gates before solution',
      (tester) async {
    await tester.runAsync(() async {
      Future<void> reveal(Finder target, double delta) async {
        await tester.scrollUntilVisible(target, delta,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }

      final j = await dao.journeys.create(raw);
      final ai = _TextAi((purpose, prompt) async {
        if (purpose.endsWith('.needs'))
          return jsonEncode({
            'candidates': [candidate(1), candidate(2)]
          });
        final chosenLine = prompt
            .split('\n')
            .firstWhere((line) => line.startsWith('用户第二轮明确选择的知识（唯一依据）：'));
        final chosen =
            growthRows(jsonDecode(chosenLine.split('：').skip(1).join('：')));
        return jsonEncode({
          ...solution(),
          'steps': [
            {
              ...growthRows(solution()['steps']).first,
              'node_ids': [chosen.first['id']]
            }
          ]
        });
      });
      await tester.pumpWidget(MaterialApp(
          home: GrowthDiscoveryPage(
              dao: dao,
              journey: j,
              service: GrowthDiscovery(dao,
                  ai: ai, jev: judge(), key: () async => 'test'))));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final needsButton = find.byKey(const ValueKey('confirm_needs'));
      await reveal(needsButton, 300);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('confirm_needs')))
              .onPressed,
          isNull);
      expect(ai.calls.where((s) => s.endsWith('.solution')), isEmpty);
      await reveal(find.byKey(const ValueKey('need_need_1')), -300);
      await tester.tap(find.byKey(const ValueKey('need_need_1')));
      await tester.pumpAndSettle();
      await reveal(needsButton, 300);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('confirm_needs')))
              .onPressed,
          isNotNull);
      await tester.tap(needsButton);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final knowledgeButton = find.byKey(const ValueKey('confirm_knowledge'));
      await reveal(knowledgeButton, 300);
      expect(tester.widget<FilledButton>(knowledgeButton).onPressed, isNull);
      expect(ai.calls.where((s) => s.endsWith('.solution')), isEmpty);
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      final knowledgeTile = find
          .byWidgetPredicate(
              (w) => w is CheckboxListTile && '${w.key}'.contains('knowledge_'))
          .first;
      await tester.ensureVisible(knowledgeTile);
      await tester.tap(knowledgeTile);
      await tester.pumpAndSettle();
      await reveal(knowledgeButton, 300);
      await tester.tap(knowledgeButton);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await reveal(find.byKey(const ValueKey('continue_journey')), 300);
      expect(ai.calls.where((s) => s.endsWith('.solution')), hasLength(1));
      expect((await dao.journeys.find(j.id))!.confirmed, false);
      expect(
          (await dao.journeys.find(j.id))!.data['selected_knowledge'], isNull);
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });
}
