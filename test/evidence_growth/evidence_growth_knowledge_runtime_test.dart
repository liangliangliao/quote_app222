import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_store.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_runtime.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_knowledge_runtime.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';

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
  Future<GrowthJourney> goal() async {
    final j = await store.create('作品准备好了，但是怕不完美而迟迟不敢发送');
    return store.change(j, 'contract', {
      'goal': j.title,
      'current': '完成初稿，未发送',
      'criterion': '收到一个具体建议',
      'quality': '可撤回',
      'belief': '担心别人否定我'
    });
  }

  final n = EvidenceGrowthKnowledge.source('A02');
  GrowthData application(String stage, {EvidenceKNode? node}) => {
        'stage': stage,
        'node_id': (node ?? n).id,
        'node_version': (node ?? n).version,
        'understanding': '开始一小步可以带来新的现实反馈',
        'application': '打开草稿，检查一个段落后发给朋友征求一条意见',
        'expected_signal': '朋友是否给出一条具体意见',
        'transfer_reason': '当前卡点是完美主义阻止开始',
        'conditions_confirmed': true,
      };
  test('unknown text has no fabricated first-card fallback', () {
    for (final s in EvidenceGrowthKnowledgeRuntime.stages) {
      expect(EvidenceGrowthJourneyStore.evidence(s, 'zxqv987654'), isEmpty);
    }
    expect(() => EvidenceGrowthKnowledgeRuntime.stage('INVALID'),
        throwsArgumentError);
  });
  test('context contains latest facts and cross-module candidates', () async {
    var j = await goal();
    j = await store.change(j, 'entry', {'text': '新卡点是恐惧被拒绝，陷入完美主义'});
    final q = EvidenceGrowthKnowledgeRuntime.query(
        EvidenceGrowthKnowledgeRuntime.context(j, 'ACTION'));
    expect(q, contains('新卡点'));
    expect(q, contains('完成初稿'));
    final found =
        EvidenceGrowthKnowledgeRuntime.retrieve('ACTION', q, limit: 80);
    expect(found.any((n) => n.module == GrowthModule.failure), isTrue);
    expect(
        found.every((n) => EvidenceGrowthKnowledge.byId(n.id) != null), isTrue);
  });
  test('selected action changes actual compiled instruction and sources',
      () async {
    var j = await goal();
    final oldFacts = j.data['current'];
    j = await store.change(j, 'knowledge-apply', application('ACTION'));
    final r = EvidenceGrowthJourneyRuntime.compile(j);
    expect(r.actionInstruction, application('ACTION')['application']);
    expect(r.selectedNodes.map((n) => n.id), contains(n.id));
    expect(
        r.inputDrafts['prediction'], application('ACTION')['expected_signal']);
    expect(j.data['current'], oldFacts);
    expect(r.riskChecks['SELECTION'], 'USER_KNOWLEDGE_APPLICATION');
  });
  test('application cannot bypass action safety gate', () async {
    var j = await goal();
    j = await store.change(j, 'knowledge-apply', {
      ...application('ACTION'),
      'application': '自己决定停药并改变药物剂量',
    });
    final r = EvidenceGrowthJourneyRuntime.compile(j);
    expect(r.canAct, isFalse);
    expect(r.status, 'PROFESSIONAL_ESCALATION');
  });
  test(
      'all six stages store versioned sources; do not advance journey or claim mastery',
      () async {
    var j = await store.create('准备作品，想先了解自己担心的是什么');
    for (final stage in EvidenceGrowthKnowledgeRuntime.stages) {
      j = await store.change(j, 'knowledge-apply', application(stage));
      expect(EvidenceGrowthKnowledgeRuntime.appliedNodes(j, stage).single.id,
          n.id);
    }
    expect(j.node, 'BELIEF');
    expect(j.confirmed, isFalse);
    final history = await store.history(j.id);
    expect(
        history.where((e) => e['kind'] == 'KNOWLEDGE_APPLICATION').length, 6);
    for (final r
        in history.where((e) => e['kind'] == 'KNOWLEDGE_APPLICATION')) {
      expect(growthMap(r['snapshot'])['source_locator'], isNotNull);
      expect(r['conditions_confirmed'], isTrue);
    }
    j = await store.change(j, 'knowledge-practice', {
      'stage': 'BELIEF',
      'node_id': n.id,
      'node_version': n.version,
      'reflection': '试着解释原理，还需要现实检验'
    });
    expect(
        (await store.history(j.id)).singleWhere(
            (r) => r['kind'] == 'KNOWLEDGE_PRACTICE')['mastery_verified'],
        isFalse);
    expect((await dao.summary()).learnedNodes, 0);
  });
  test('missing boundaries, source version and transfer reasons are rejected',
      () async {
    final j = await goal();
    await expectLater(
        store.change(j, 'knowledge-apply',
            {...application('ACTION'), 'conditions_confirmed': false}),
        throwsStateError);
    await expectLater(
        store.change(j, 'knowledge-apply',
            {...application('ACTION'), 'node_version': -1}),
        throwsStateError);
    await expectLater(
        store.change(j, 'knowledge-apply',
            {...application('REVIEW'), 'transfer_reason': ''}),
        throwsStateError);
    expect((await store.find(j.id))!.version, j.version);
  });
  test(
      'past step application queues next cycle and stale clients cannot overwrite it',
      () async {
    final original = await goal();
    var j =
        await store.change(original, 'knowledge-apply', application('BELIEF'));
    expect(EvidenceGrowthKnowledgeRuntime.applications(j, 'BELIEF'), isEmpty);
    expect(
        growthRows(j.data['knowledge_applications']).single['effective_cycle'],
        j.cycle + 1);
    await expectLater(
        store.change(original, 'knowledge-apply', application('GOAL')),
        throwsStateError);
    j = await store.change(j, 'knowledge-withdraw', {
      'application_id':
          growthRows(j.data['knowledge_applications']).single['id']
    });
    expect(growthRows(j.data['knowledge_applications']), isEmpty);
    expect(
        (await store.history(j.id))
            .any((r) => r['kind'] == 'KNOWLEDGE_APPLICATION'),
        isTrue);
  });
  test(
      'node runs distinguish retrieved from selected; knowledge gap does not invent facts',
      () async {
    var j = await store.create('zxqv987654');
    await db.transaction(
        (tx) => EvidenceGrowthJourneyStore.nodeRun(tx, j, 'BELIEF', {}, {}));
    expect(
        (await store.history(j.id)).last['knowledge_status'], 'KNOWLEDGE_GAP');
    j = await store.change(j, 'knowledge-apply', application('BELIEF'));
    await db.transaction(
        (tx) => EvidenceGrowthJourneyStore.nodeRun(tx, j, 'BELIEF', {}, {}));
    final last = (await store.history(j.id)).last;
    expect(last['knowledge_status'], 'USER_SELECTED_APPLICATION');
    expect(growthRows(last['knowledge_evidence']).single['node_id'], n.id);
  });
  test('sync bundle preserves knowledge provenance and excludes JEV secret',
      () async {
    var j = await goal();
    j = await store.change(j, 'knowledge-apply', application('ACTION'));
    await dao.setSetting('jev_key_encrypted', 'keystore-v1:private-key');
    final bundle = await store.bundle(j.id);
    final text = jsonEncode(bundle);
    expect(text, contains(n.id));
    expect(text, contains('KNOWLEDGE_APPLICATION'));
    expect(text, isNot(contains('private-key')));
  });
  test(
      'knowledge added during a live action cannot rewrite prediction; review can use new sources',
      () async {
    var j = await goal();
    var trial = await dao.createTrial(EvidenceGrowthJourneyRuntime.compile(j),
        prediction: '朋友会指出一个问题',
        probability: .5,
        reviewAt: DateTime.now().add(const Duration(hours: 1)),
        riskConfirmed: true,
        operatorInputs: {
          'journey_id': j.id,
          'journey_version': '${j.version}'
        });
    final actionRecord = (await store.history(j.id))
        .singleWhere((r) => r['kind'] == 'NODE_RUN' && r['node'] == 'ACTION');
    expect(actionRecord['knowledge_status'], 'ACTION_SOURCE_SNAPSHOT');
    expect(
        growthRows(actionRecord['knowledge_evidence']).map((r) => r['node_id']),
        orderedEquals(trial.nodeIds));
    trial = await dao.startTrial(trial);
    j = (await store.find(j.id))!;
    j = await store.change(j, 'knowledge-apply', application('ACTION'));
    expect(EvidenceGrowthKnowledgeRuntime.applications(j, 'ACTION'), isEmpty);
    expect((await dao.byId(trial.id))!.prediction, '朋友会指出一个问题');
    trial = await dao.captureResult(trial,
        didAction: true,
        actualOutcome: '朋友提出一个排版意见',
        unexpected: '',
        resultStatus: 'DONE');
    j = (await store.find(j.id))!;
    j = await store.change(j, 'outcome', {'facts': trial.actualOutcome});
    j = await store.change(j, 'readiness', {'value': 'READY_NOW'});
    final reviewNode = EvidenceGrowthKnowledge.source('R01');
    j = await store.change(
        j, 'knowledge-apply', application('REVIEW', node: reviewNode));
    final reviewed = await dao.saveReview(
        trial,
        TrialReviewResult(
            predictionOriginal: trial.prediction,
            actualFacts: [trial.actualOutcome],
            predictionError: '实际收到具体意见',
            failureClass: 'NO_FAILURE',
            learning: '可通过一个小样本获得可用反馈',
            ruleUpdate: '先做小样本',
            decision: 'OBSERVE',
            nextChangeOneVariable: '记录下一条具体意见',
            knowledgeNodeIds: [reviewNode.id]));
    expect(reviewed.prediction, trial.prediction);
    expect(reviewed.nodeIds, trial.nodeIds);
    final used = (await store.history(j.id))
        .where((r) => r['kind'] == 'REVIEW_KNOWLEDGE_USED')
        .single;
    expect(growthStrings(used['node_ids']), contains(reviewNode.id));
    expect(growthRows(used['additional_review_sources']).single['node_id'],
        reviewNode.id);
  });
  GrowthData response() => {
        'model': 'jev-latest',
        'answers': {
          'relevant_0': {'type': 'noul', 'noul': .9},
          'contra_0': {'type': 'noul', 'noul': .1},
        },
        'usage': {'input_tokens': 200, 'output_tokens': 8}
      };
  test(
      'JEV native typed request and cache include context; never chat completions',
      () async {
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      expect(r.url, EvidenceGrowthJev.endpoint);
      expect(r.headers['Authorization'], 'Bearer test-key');
      final b = jsonDecode(r.body) as Map;
      expect(b.containsKey('messages'), isFalse);
      expect((b['questions'] as Map).length, 2);
      expect(b['questions']['relevant_0']['instructions'], contains('index 0'));
      return http.Response(jsonEncode(response()), 200);
    });
    final jev = EvidenceGrowthJev(client: client);
    final first = await jev.rank({'question': '拖延'}, [n], apiKey: 'test-key');
    expect(first['status'], 'JEV');
    expect(growthRows(first['scores']).single['eligible'], isTrue);
    await jev.rank({'question': '拖延'}, [n], apiKey: 'test-key');
    expect(calls, 1);
    await jev.rank({'question': '出现新的实际反馈'}, [n], apiKey: 'test-key');
    expect(calls, 2);
    client.close();
  });
  test('JEV malformed, incomplete, out-of-range responses fall back locally',
      () async {
    for (final body in [
      {},
      {'answers': {}},
      {
        'answers': {
          'relevant_0': {'type': 'noul', 'noul': 1.1}
        }
      }
    ]) {
      final client =
          MockClient((_) async => http.Response(jsonEncode(body), 200));
      final result =
          await EvidenceGrowthJev(client: client).rank({}, [n], apiKey: 'key');
      expect(result['status'], 'LOCAL');
      client.close();
    }
  });
  test('JEV overload cools down, empty key never sends request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('overload', 429);
    });
    final jev = EvidenceGrowthJev(client: client);
    await jev.rank({}, [n], apiKey: '');
    expect(calls, 0);
    expect((await jev.rank({}, [n], apiKey: 'key'))['status'], 'LOCAL');
    await jev.rank({'changed': true}, [n], apiKey: 'key');
    expect(calls, 1);
    client.close();
  });
  test('JEV action prediction follows the interpreted contract', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '周五前提交报告',
      'action_profile': {
        'forecast_events': [
          {
            'id': 'submit_report',
            'label': '周五前提交报告',
            'true_criterion':
                'The report is submitted before the Friday deadline.',
            'false_criterion':
                'The report is not submitted before the Friday deadline.',
            'primary': true,
          },
          {
            'id': 'finish_draft',
            'label': '完成可提交版本',
            'true_criterion':
                'A submission-ready draft is completed before the deadline.',
            'false_criterion':
                'No submission-ready draft is completed before the deadline.',
            'primary': false,
          }
        ],
        'relevant_core_factors': [
          'intention',
          'instrumental_attitude',
          'self_efficacy',
          'perceived_control'
        ],
        'dynamic_factors': [
          {
            'id': 'review_dependency',
            'label': '他人审核依赖',
            'ibm_construct': 'environmental_constraints',
            'condition':
                'Any required external review can be completed before the deadline.',
            'evidence': ''
          }
        ],
        'failure_modes': [
          {
            'id': 'review_delay',
            'label': '审核延误',
            'criterion':
                'Required external review is not completed before the deadline.'
          }
        ]
      }
    }, 'jev-latest');
    final questions = request['questions'] as Map;
    expect(questions, contains('event_submit_report'));
    expect(questions, contains('event_finish_draft'));
    expect(questions, contains('factor_intention'));
    expect(questions, contains('factor_environmental_constraints'));
    expect(questions, contains('factor_implementation_intention'));
    expect(questions, contains('factor_dynamic_review_dependency'));
    expect(questions, contains('dominant_failure_mode'));

    final scoreAnswer = {
      'type': 'score',
      'score': 2.4,
      'confidence': .75,
      'legend': {
        '0': 'blocks',
        '1': 'somewhat blocks',
        '2': 'neutral',
        '3': 'supports',
        '4': 'strongly supports'
      },
      'probabilities': {'0': .05, '1': .15, '2': .3, '3': .4, '4': .1}
    };
    final parsed = EvidenceGrowthJev.parseAction({
      'model': 'jev-latest',
      'answers': {
        'event_submit_report': {'type': 'noul', 'noul': .72},
        'event_finish_draft': {'type': 'noul', 'noul': .81},
        'hard_blocker': {'type': 'noul', 'noul': .12},
        'factor_intention': scoreAnswer,
        'factor_instrumental_attitude': scoreAnswer,
        'factor_self_efficacy': scoreAnswer,
        'factor_perceived_control': scoreAnswer,
        'factor_knowledge_skills': scoreAnswer,
        'factor_salience': scoreAnswer,
        'factor_environmental_constraints': scoreAnswer,
        'factor_habit': scoreAnswer,
        'factor_implementation_intention': scoreAnswer,
        'factor_dynamic_review_dependency': scoreAnswer,
        'dominant_failure_mode': {
          'type': 'choice',
          'choice': 'review_delay',
          'confidence': .7,
          'probabilities': {
            'review_delay': .55,
            'insufficient_evidence': .45
          }
        },
      }
    });
    expect(parsed['overall'], .72);
    expect(growthMap(parsed['events'])['finish_draft'], .81);
    expect(
        growthMap(growthMap(parsed['factors'])['dynamic_review_dependency'])[
            'score'],
        .6);
    expect(growthMap(parsed['dominant_failure_mode'])['choice'],
        'review_delay');
  });

  test('action prediction records reality outcome for later personal calibration',
      () async {
    final prediction =
        EvidenceGrowthActionPredictionService(dao: dao);
    await prediction.savePrediction({
      'id': 'prediction-1',
      'plan': '去体检',
      'estimate': .64,
      'outcome': 'PENDING',
      'scheduled_at_ms': 1,
    });
    await prediction.recordOutcome('prediction-1', 'SUCCESS');
    final rows = await prediction.history();
    expect(rows.single['outcome'], 'SUCCESS');
    expect(EvidenceGrowthActionPredictionService.band(.64),
        '有一定把握，但仍可能被打断');
  });
  testWidgets('learning opens all stages and browsing does not mark mastery',
      (tester) async {
    await tester.runAsync(() async {
      final j = await store.create('担心作品不够完美');
      await tester.pumpWidget(MaterialApp(
          home: EvidenceGrowthKnowledgePage(
              dao: dao, journey: j, stage: 'BELIEF')));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      for (final s in EvidenceGrowthKnowledgeRuntime.stages) {
        await tester
            .tap(find.widgetWithText(ChoiceChip, GrowthJourney.labels[s]!));
        await tester.pumpAndSettle();
        expect(find.text(EvidenceGrowthKnowledgeRuntime.lessons[s]![0]),
            findsOneWidget);
      }
      expect((await dao.summary()).learnedNodes, 0);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
