import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_ai_service.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_guidance.dart';
import 'package:quote_app/evidence_growth/evidence_growth_guidance_card.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_runtime.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_store.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge_runtime.dart';

class _Ai extends UnifiedAiService {
  _Ai(this.respond, {this.available = true});
  final Future<String> Function(String, String) respond;
  final bool available;
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
          available: available);
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
    return respond(purpose, prompt);
  }
}

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  late EvidenceGrowthJourneyStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EvidenceGrowthDao(database: () async => db);
    await dao.ensureTables();
    store = dao.journeys;
  });
  tearDown(() => db.close());
  final n = EvidenceGrowthKnowledge.source('A02');
  Future<GrowthJourney> at(String stage) async {
    var j = await store.create('作品已经准备好，但是拖延没开始');
    j = j.copy({
      'node': stage,
      'current': '完成初稿，尚未发送',
      'readiness': 'READY_NOW',
      'knowledge_applications': [
        {
          'stage': stage,
          'effective_cycle': j.cycle,
          'snapshot': n.toJson(),
          'application': '先做一个小步骤'
        }
      ]
    });
    await EvidenceGrowthJourneyStore.put(db, j);
    return j;
  }

  GrowthData planning(GrowthJourney j) => {
        'journey_id': j.id,
        'current_node': j.node,
        'fact_quotes': ['完成初稿'],
        'knowledge_query': '拖延 开始 行动',
        'missing_question': ''
      };
  GrowthData decision(GrowthJourney j, String stage) => {
        'journey_id': j.id,
        'current_node': j.node,
        'stage': stage,
        'next_node': GrowthGuidance.next[stage],
        'summary': '当前需要从一个小步骤获取反馈',
        'interpretation': '启动练习可能减少等待完美状态的依赖，这只是待检验解释。',
        'question': '',
        'next_step': '核对草案后继续当前步骤',
        'fact_quotes': ['完成初稿'],
        'node_ids': [n.id],
        'node_output': {GrowthGuidance.fields[stage]!.first: '具体草案：先核对一个可观察信号'}
      };
  for (final stage in EvidenceGrowthKnowledgeRuntime.stages) {
    test(
        '$stage plans evidence then guides without mutating journey and caches identical context',
        () async {
      final j = await at(stage);
      final ai = _Ai((purpose, _) async => jsonEncode(
          purpose.endsWith('.plan') ? planning(j) : decision(j, stage)));
      final service = EvidenceGrowthAiService(ai: ai, dao: dao);
      final result = await service.guideJourney(j);
      expect(ai.calls,
          ['evidence_growth.guidance.plan', 'evidence_growth.guidance.decide']);
      expect(result['origin'], 'AI');
      expect(result['model'], 'text-model');
      expect(growthRows(result['evidence']).map((e) => e['node_id']),
          contains(n.id));
      expect((await store.find(j.id))!.data, j.data);
      expect((await store.history(j.id)).last['kind'], 'AI_DRAFT');
      await service.guideJourney(j);
      expect(ai.calls.length, 2);
    });
  }
  test(
      'missing configuration and deferred readiness are explicitly local with zero AI calls',
      () async {
    var j = await at('REVIEW');
    final ai = _Ai((_, __) async => throw StateError('must not call'),
        available: false);
    var result =
        await EvidenceGrowthAiService(ai: ai, dao: dao).guideJourney(j);
    expect(result['origin'], 'LOCAL_RULE');
    expect(result['reason'], contains('尚未配置'));
    j = j.copy({'readiness': 'DEFERRED'});
    final active = _Ai((_, __) async => throw StateError('must not call'));
    result = await EvidenceGrowthAiService(ai: active, dao: dao)
        .guideJourney(j, refresh: true);
    expect(result['origin'], 'LOCAL_RULE');
    expect(result['reason'], contains('准备度'));
    expect(active.calls, isEmpty);
    expect(ai.calls, isEmpty);
  });
  test('fabricated source, fact, and workflow jump are rejected', () async {
    final j = await at('BELIEF');
    for (final patch in [
      {
        'node_ids': ['fabricated-id']
      },
      {
        'fact_quotes': ['已发出作品并得到称赞']
      },
      {'next_node': 'ACHIEVED'}
    ]) {
      final ai = _Ai((purpose, _) async => jsonEncode(purpose.endsWith('.plan')
          ? planning(j)
          : {...decision(j, 'BELIEF'), ...patch}));
      final result =
          await EvidenceGrowthAiService(ai: ai, dao: dao).guideJourney(j);
      expect(result['origin'], 'LOCAL_RULE');
      expect(result['reason'], contains('未通过'));
      expect(result['node_output'], isEmpty);
    }
    expect((await store.history(j.id)).where((r) => r['kind'] == 'AI_DRAFT'),
        isEmpty);
  });
  test(
      'missing prerequisite yields a clarification with no formal intervention',
      () async {
    final j = await at('ACTION');
    final ai = _Ai((purpose, _) async => jsonEncode(purpose.endsWith('.plan')
        ? {...planning(j), 'missing_question': '这个动作是否可撤回？'}
        : decision(j, 'ACTION')));
    final result =
        await EvidenceGrowthAiService(ai: ai, dao: dao).guideJourney(j);
    expect(result['needs_user_input'], isTrue);
    expect(result['question'], '这个动作是否可撤回？');
    expect(result['node_output'], isEmpty);
  });
  test('new reality invalidates in-flight old guidance', () async {
    final j = await at('BELIEF');
    final ai = _Ai((purpose, _) async {
      if (purpose.endsWith('.plan')) return jsonEncode(planning(j));
      await store.change(j, 'entry', {'text': '现在有新的现实反馈'});
      return jsonEncode(decision(j, 'BELIEF'));
    });
    final result =
        await EvidenceGrowthAiService(ai: ai, dao: dao).guideJourney(j);
    expect(result['origin'], 'LOCAL_RULE');
    expect(result['reason'], contains('情境已变化'));
  });
  test('AI goal proposal enters the contract only after user confirmation',
      () async {
    final j = await at('BELIEF');
    final ai = _Ai((purpose, _) async => jsonEncode(purpose.endsWith('.plan')
        ? planning(j)
        : {
            ...decision(j, 'GOAL'),
            'node_output': {
              'criterion': '收到一条具体反馈',
              'belief': '不完美的初稿也可能得到有用反馈'
            }
          }));
    final draft = await EvidenceGrowthAiService(ai: ai, dao: dao)
        .journeyDraft(j, 'contract');
    expect(draft['_origin'], 'AI');
    final confirmed = await store.change(j, 'contract', {
      'goal': j.title,
      'current': j.data['current'],
      'criterion': draft['criterion'],
      'belief': draft['belief']
    });
    expect(confirmed.node, 'ACTION');
    expect(confirmed.contract['source'], 'USER_CONFIRMED');
  });
  Future<GrowthJourney> completed(
      {String criteria = '收到一个具体建议', String planField = ''}) async {
    var j = await store.create('准备作品，担心不完美，想获得反馈');
    j = await store.change(j, 'contract',
        {'goal': j.title, 'current': '已有草稿', 'criterion': criteria});
    j = await store.change(j, 'outcome', {'facts': '发出后收到一个建议'});
    j = await store.change(j, 'readiness', {'value': 'READY_NOW'});
    j = await store.change(j, 'review', {'learning': '反馈帮助修改具体内容'});
    return store.change(j, 'change', {
      'target': 'MODIFY',
      'reason': '调整下一次练习',
      'next_action': '修改一个段落',
      'plan_field': planField
    });
  }

  test('multiple success criteria each need their own evidence', () async {
    var j = await completed(criteria: '收到一个具体建议\n按建议完成修改');
    await expectLater(
        store.change(j, 'criterion-evidence',
            {'facts': '收到建议', 'met': true, 'quality_met': true}),
        throwsStateError);
    j = await store.change(j, 'criterion-evidence', {
      'facts': '收到建议但未修改',
      'quality_met': true,
      'items': [
        {'statement': '收到一个具体建议', 'facts': '收到一条排版建议', 'met': true},
        {'statement': '按建议完成修改', 'facts': '尚未修改', 'met': false}
      ]
    });
    await expectLater(
        store.change(j, 'gate', {'choice': 'ACHIEVED'}), throwsStateError);
    j = await store.change(j, 'criterion-evidence', {
      'facts': '建议已采用',
      'quality_met': true,
      'items': [
        {'statement': '收到一个具体建议', 'facts': '收到一条排版建议', 'met': true},
        {'statement': '按建议完成修改', 'facts': '完成排版修改', 'met': true}
      ]
    });
    expect((await store.change(j, 'gate', {'choice': 'ACHIEVED'})).status,
        'ACHIEVED');
  });
  test(
      'structure change requires a new evidence-backed plan before next action',
      () async {
    var j = await completed(planField: 'cadence');
    final version = j.plan['version'];
    await expectLater(
        store.change(j, 'gate', {'choice': 'CONTINUE'}), throwsStateError);
    j = await store.change(j, 'plan', {
      'field': 'cadence',
      'operation': 'MODIFY',
      'reason': '反馈需要处理时间',
      'evidence': '上次未完成修改',
      'change': '每两天一个样本',
      'expected_signal': '每个样本反馈都得到处理'
    });
    expect(j.plan['version'], growthInt(version) + 1);
    expect(j.data['plan_revision_required'], isFalse);
    expect(
        (await store.change(j, 'gate', {'choice': 'CONTINUE'})).node, 'ACTION');
  });
  test(
      'self-label cannot start an intervention until concrete pattern is checked',
      () async {
    var j = await store.create('我很懒，想完成写作草稿');
    j = await store.change(j, 'contract',
        {'goal': j.title, 'current': '尚未开始整理草稿', 'criterion': '完成一篇草稿'});
    Future<void> create(GrowthJourney value) async {
      await dao.createTrial(EvidenceGrowthJourneyRuntime.compile(value),
          prediction: '整理出一段草稿',
          probability: .5,
          reviewAt: DateTime.now().add(const Duration(hours: 1)),
          riskConfirmed: true,
          operatorInputs: {
            'journey_id': value.id,
            'journey_version': '${value.version}'
          });
    }

    await expectLater(create(j), throwsStateError);
    await expectLater(
        store.change(j, 'pattern', {
          'observed_pattern': '我很懒',
          'context': '在家',
          'impact': '拖延',
          'decision': 'CHANGE'
        }),
        throwsArgumentError);
    j = await store.change(j, 'pattern', {
      'observed_pattern': '坐到书桌前后打开了短视频，没有整理草稿',
      'context': '昨晚饭后',
      'impact': '草稿没完成',
      'decision': 'ENVIRONMENT_CHANGE'
    });
    await create(j);
    expect((await store.find(j.id))!.trialId, isNotEmpty);
  });
  test(
      'confirmed details persist and constrain action instead of disappearing after guidance',
      () async {
    var j = await store.create('准备写作练习，希望获得具体反馈');
    j = await store.change(j, 'contract', {
      'goal': j.title,
      'current': '已有草稿',
      'criterion': '收到一个具体建议',
      'belief': '初稿也能得到有用反馈',
      'belief_basis': '上一份草稿收到过建议',
      'testable_belief': '发送一个段落观察反馈',
      'belief_update_rule': '三次无具体反馈时重查提问方式',
      'measurement': '记录反馈是否指出具体段落',
      'review_gate': '收集两次反馈后核验',
      'stop_condition': '对方表示不方便就停止',
      'self_concordance': '练习清楚表达'
    });
    j = (await store.find(j.id))!;
    expect(j.contract['measurement'], '记录反馈是否指出具体段落');
    final action = EvidenceGrowthJourneyRuntime.compile(j);
    expect(action.requiredChecks, contains('stop_condition: 对方表示不方便就停止'));
    expect(action.cyclePlan['belief_basis'], '上一份草稿收到过建议');
    j = await store.change(j, 'outcome', {'facts': '对方指出第二段不够清楚'});
    j = await store.change(j, 'readiness', {'value': 'READY_NOW'});
    j = await store.change(j, 'review', {
      'learning': '具体反馈有助于改写',
      'prediction_error': '本次没有事前预测记录',
      'cause_hypothesis': '段落主题不明确可能影响理解',
      'keep': '继续只问一个具体问题',
      'change_candidate': '改写第二段主题句'
    });
    j = (await store.find(j.id))!;
    expect(growthMap(j.data['review'])['keep'], '继续只问一个具体问题');
    expect(growthMap(j.data['review'])['prediction_state'],
        'NOT_RECORDED_BEFORE_EVENT');
    final runs = (await store.history(j.id))
        .where((r) => r['kind'] == 'NODE_RUN' && r['node'] == 'REVIEW');
    expect(growthMap(runs.last['output'])['cause_hypothesis'], '段落主题不明确可能影响理解');
  });
  testWidgets(
      'guidance distinguishes AI analysis, user records and local fallback',
      (tester) async {
    final c = TextEditingController();
    Future<void> render(GrowthData value) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: EvidenceGrowthGuidanceCard(
                    value: value,
                    loading: false,
                    onRefresh: () {},
                    question: c,
                    onContinue: () {})))));
    await render({
      'origin': 'AI',
      'summary': 'AI 的判断草案',
      'interpretation': '待检验的原因解释',
      'fact_quotes': ['用户原始事实'],
      'node_output': {},
      'evidence': []
    });
    expect(find.text('AI 生成 · 待核对'), findsOneWidget);
    expect(find.text('AI 分析／待检验解释\n待检验的原因解释'), findsOneWidget);
    await render({
      'origin': 'LOCAL_RULE',
      'reason': '未配置可用 AI',
      'summary': '本地步骤说明',
      'node_output': {},
      'evidence': []
    });
    expect(find.text('本地规则'), findsOneWidget);
    expect(find.text('AI 生成 · 待核对'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
