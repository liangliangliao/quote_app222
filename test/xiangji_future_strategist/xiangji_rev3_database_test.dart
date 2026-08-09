import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quote_app/external_data/todo_dao.dart';
import 'package:quote_app/external_data/todo_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_agent_service.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_repository.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_rev3_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late XiangjiDao dao;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = XiangjiDao(database: database);
    await dao.ensureSchema(database);
    await dao.createProblem(
      id: 'problem-r3',
      rawEventId: 'event-r3',
      rawQuestion: '我想辞职但害怕',
      contextText: '我想辞职但害怕',
    );
  });

  tearDown(() => database.close());

  test('Rev3 creates all AI work-domain entities and SCK-001..018', () async {
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'xf_%'",
    );
    final names = rows.map((row) => row['name']).toSet();

    expect(
      names,
      containsAll(<String>{
        'xf_situation_model',
        'xf_ai_inference',
        'xf_information_need',
        'xf_clarification_question',
        'xf_user_correction',
        'xf_agent_run',
        'xf_reasoning_artifact',
        'xf_judgment',
        'xf_decision_draft',
      }),
    );
    final rules = await dao.enabledRules();
    final sckCodes = rules
        .map((row) => (row['rule_code'] ?? '').toString())
        .where((code) => code.startsWith('SCK-'))
        .toSet();
    expect(sckCodes, hasLength(18));
    expect(sckCodes, containsAll(<String>['SCK-001', 'SCK-018']));

    Future<Set<String>> columns(String table) async =>
        (await database.rawQuery('PRAGMA table_info($table)'))
            .map((row) => (row['name'] ?? '').toString())
            .toSet();
    expect(
      await columns('xf_problem'),
      contains('situation_model_id'),
    );
    expect(
      await columns('xf_information_need'),
      contains('resolution_action_id'),
    );
    expect(await columns('xf_decision_draft'), contains('agent_run_id'));
    expect(await columns('xf_strategy_option'), contains('opportunity_cost'));
    expect(await columns('xf_reality_result'), contains('experience_json'));
  });

  test('SituationModel is versioned and latest version remains explicit',
      () async {
    await dao.saveSituationModel(
      id: 'situation-v1',
      objectType: 'problem',
      objectId: 'problem-r3',
      version: 1,
      state: XiangjiSituationModelState.framed,
      summary: '第一版',
      currentNeed: '判断是否辞职',
      model: const <String, Object?>{'model_is_revisable': true},
      sourceRefs: const <String>['raw_event:event-r3'],
    );
    await dao.saveSituationModel(
      id: 'situation-v2',
      objectType: 'problem',
      objectId: 'problem-r3',
      version: 2,
      state: XiangjiSituationModelState.grounded,
      summary: '第二版',
      currentNeed: '先验证替代路线',
      model: const <String, Object?>{'model_is_revisable': true},
      sourceRefs: const <String>['raw_event:event-r3'],
    );

    expect(
      await dao.nextSituationModelVersion(
        objectType: 'problem',
        objectId: 'problem-r3',
      ),
      3,
    );
    final latest = await dao.latestSituationModel(
      objectType: 'problem',
      objectId: 'problem-r3',
    );
    expect(latest?['id'], 'situation-v2');
    expect(latest?['state'], 'GROUNDED');
  });

  test('user correction marks every downstream AI object STALE', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.saveSituationModel(
      id: 'situation-active',
      objectType: 'problem',
      objectId: 'problem-r3',
      version: 1,
      state: XiangjiSituationModelState.framed,
      summary: 'AI 当前理解',
      currentNeed: '辞职',
      model: const <String, Object?>{},
      sourceRefs: const <String>['raw_event:event-r3'],
    );
    await dao.saveAiInference(<String, Object?>{
      'id': 'inference-1',
      'situation_model_id': 'situation-active',
      'problem_id': 'problem-r3',
      'text': '你不适合当前工作',
      'inference_type': 'judgment',
      'source_refs_json': jsonEncode(const <String>['raw_event:event-r3']),
      'agent_run_id': 'run-a02',
      'epistemic_status': 'PROVISIONAL',
      'user_confirmed': 0,
      'status': 'ACTIVE',
      'created_at_ms': now,
    });
    await dao.addClaim(
      id: 'claim-ai',
      problemId: 'problem-r3',
      text: '你不适合当前工作',
      claimType: 'judgment',
      state: XiangjiClaimState.provisional,
      sourceKind: 'ai_inference',
    );
    await dao.saveReasoningArtifact(<String, Object?>{
      'id': 'artifact-1',
      'problem_id': 'problem-r3',
      'campaign_id': '',
      'situation_model_id': 'situation-active',
      'agent_run_id': 'run-a02',
      'kind': 'judgment_map',
      'json_payload': '{}',
      'status': 'ACTIVE',
      'created_at_ms': now,
    });
    await dao.saveJudgment(<String, Object?>{
      'id': 'judgment-1',
      'problem_id': 'problem-r3',
      'situation_model_id': 'situation-active',
      'purpose_scope': '判断当前路线是否值得继续',
      'compared_cases_json': '[]',
      'relevant_similarities_json': '[]',
      'relevant_differences_json': '[]',
      'counterexamples_json': '[]',
      'conclusion': '先做可逆侏察',
      'agent_run_id': 'run-a02',
      'state': XiangjiJudgmentState.draft.wire,
      'created_at_ms': now,
      'updated_at_ms': now,
    });
    await dao.saveDecisionDraft(<String, Object?>{
      'id': 'decision-1',
      'problem_id': 'problem-r3',
      'campaign_id': '',
      'action_id': '',
      'situation_model_id': 'situation-active',
      'true_problem': '是否值得继续当前路线',
      'recommendation': '先侦察',
      'judgment': '暂时不能形成身份定论',
      'why_text': '根据不足',
      'current_action': '访谈一位从业者',
      'change_signals': '出现独立反证',
      'epistemic_status': 'PROVISIONAL',
      'clarification_question': '',
      'options_json': '[]',
      'uncertainty_json': '{}',
      'weakest_premise': '样本太少',
      'unresolved_items_json': '[]',
      'user_status': 'PROPOSED',
      'created_at_ms': now,
      'updated_at_ms': now,
    });

    await dao.saveUserCorrectionAndInvalidate(
      id: 'correction-1',
      problemId: 'problem-r3',
      targetRef: 'decision_draft:decision-1',
      oldValue: '你不适合当前工作',
      correctedValue: '我并不是不适合，只是当前团队资源不足',
      reason: '用户纠正 AI 归因',
    );

    final situation = await dao.latestSituationModel(
      objectType: 'problem',
      objectId: 'problem-r3',
    );
    final inference = (await dao.aiInferences('problem-r3')).single;
    final decision = await dao.decisionDraft('decision-1');
    final claim = (await dao.claimsForProblem('problem-r3')).single;
    final judgment = (await dao.judgments('problem-r3')).single;

    expect(situation?['state'], 'STALE');
    expect(inference['status'], 'STALE');
    expect(decision?.status, XiangjiDecisionDraftStatus.stale);
    expect(claim['epistemic_status'], 'UNRESOLVED');
    expect(judgment['state'], XiangjiJudgmentState.contested.wire);
    expect(await dao.reasoningArtifacts(problemId: 'problem-r3'), isEmpty);
  });

  test('AskUserGuard persistence selects at most one question per round',
      () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var index = 0; index < 2; index++) {
      await dao.saveInformationNeed(<String, Object?>{
        'id': 'need-$index',
        'problem_id': 'problem-r3',
        'situation_model_id': 'situation-1',
        'question': '问题 $index',
        'missing_field': 'field-$index',
        'missing': 1,
        'decision_impact': 'HIGH',
        'can_infer': 0,
        'infer_source_refs_json': '[]',
        'scouting_possible': 0,
        'scouting_option': '',
        'evsi_rank': 2 - index,
        'expected_value': '${2 - index}',
        'user_burden': 1,
        'selected_for_question': index == 0 ? 1 : 0,
        'status': 'OPEN',
        'created_at_ms': now,
        'updated_at_ms': now,
      });
    }

    final needs = await dao.informationNeeds('problem-r3', openOnly: true);
    expect(
      needs.where((row) => row['selected_for_question'] == 1),
      hasLength(1),
    );
  });

  test('ConceptVersion preserves support, counterexample and supersession',
      () async {
    await dao.saveConceptDefinition(
      conceptId: 'concept-career-fit',
      versionId: 'concept-career-fit-v1',
      name: '职业匹配',
      definition: '第一版可修订定义',
      scope: 'problem-r3',
      observableCriteria: const <String>['连续两周出现可观察的能力增长'],
      supportRefs: const <String>['experience:one'],
      counterexampleRefs: const <String>['experience:counter-one'],
      changeReason: '初始候选',
      origin: 'ai_inference',
    );
    await dao.saveConceptDefinition(
      conceptId: 'concept-career-fit',
      versionId: 'concept-career-fit-v2',
      name: '职业匹配',
      definition: '第二版可修订定义',
      scope: 'problem-r3',
      observableCriteria: const <String>['目标相关能力与现实回馈同时改善'],
      supportRefs: const <String>['experience:two'],
      counterexampleRefs: const <String>['experience:counter-two'],
      changeReason: '新现实修订',
      origin: 'ai_inference',
    );

    final versions = (await dao.conceptVersions())
        .where((row) => row['concept_id'] == 'concept-career-fit')
        .toList();
    final latest = versions.singleWhere((row) => row['version_no'] == 2);
    expect(versions, hasLength(2));
    expect(latest['supersedes_id'], 'concept-career-fit-v1');
    expect(
      jsonDecode(latest['support_refs_json'].toString()),
      <String>['experience:two'],
    );
    expect(
      jsonDecode(latest['counterexample_refs_json'].toString()),
      <String>['experience:counter-two'],
    );
    expect(latest['status'], 'ACTIVE');
  });

  test('SCK-018 always creates AIError even in deterministic local mode',
      () async {
    await dao.createAction(
      id: 'action-refuted',
      title: '发出三封验证邮件',
      whyChain: const <String, Object?>{'key_gap': '缺少回复样本'},
      prediction: '两天内至少收到一次回复',
      problemId: 'problem-r3',
      state: XiangjiActionState.done,
    );
    await dao.recordRealityResult(
      id: 'reality-refuted',
      actionId: 'action-refuted',
      facts: const <String>['两天后仍没人回复'],
      experiences: const <String>['我感到焦虑'],
      unexpected: const <String>['没有收到预期回复'],
      sourceRefs: const <String>['user_report:reality-refuted'],
      userInterpretation: '当前邮件路线可能无效',
    );
    await dao.updateProblemState(
      'problem-r3',
      XiangjiProblemState.verifying,
    );

    final repository = XiangjiRepository(dao: dao);
    await repository.verifyAction(
      actionId: 'action-refuted',
      verdict: 'refutes',
      resolutionCriteriaMet: false,
      correction: '现实与事前预测相反',
    );

    final error = (await dao.aiErrors()).single;
    expect(error['model_run_id'], 'local_sck_reconciliation:action-refuted');
    expect(error['discovered_by'], 'reality_result:reality-refuted');
    expect(
      (await dao.problem('problem-r3'))?.state,
      XiangjiProblemState.backtracking,
    );
  });

  test('TC-AI-011 two failed cycles create one auditable A11 to A00 council',
      () async {
    for (final entry in const <(String, int, int)>[
      ('old', 10, 1000),
      ('new', 20, 2000),
    ]) {
      final suffix = entry.$1;
      await dao.createAction(
        id: 'action-$suffix',
        title: '实验 $suffix',
        whyChain: const <String, Object?>{'key_gap': '验证投入结果链'},
        prediction: '应出现领先指标',
        expectedMinutes: entry.$2,
        state: XiangjiActionState.done,
      );
      await dao.recordRealityResult(
        id: 'reality-$suffix',
        actionId: 'action-$suffix',
        facts: const <String>['结果仍未改变'],
        unexpected: const <String>['领先指标未出现'],
        sourceRefs: const <String>['user_report'],
        userInterpretation: '',
      );
      await database.update(
        'xf_reality_result',
        <String, Object?>{
          'observed_at_ms': entry.$3,
          'verdict': 'refutes',
        },
        where: 'id = ?',
        whereArgs: <Object?>['reality-$suffix'],
      );
    }

    final repository = XiangjiRepository(dao: dao);
    final first = await repository.refreshAutomaticWatch();
    final second = await repository.refreshAutomaticWatch();
    final runs = await dao.agentRuns('');
    final alert = await dao.latestOpenAlert();
    final monitorRun = runs.singleWhere((row) => row['agent_role'] == 'A11');
    final chiefRun = runs.singleWhere((row) => row['agent_role'] == 'A00');

    expect(first.state, XiangjiAlertState.orange);
    expect(second.state, XiangjiAlertState.orange);
    expect(runs.map((row) => row['agent_role']).toSet(), <Object?>{'A11', 'A00'});
    expect(
      chiefRun['input_refs_json'].toString(),
      contains(monitorRun['id'].toString()),
    );
    expect(alert?['default_action'], contains('战略复核'));
  });

  test('G6: three Need -> analysis -> Action -> Reality -> Update loops',
      () async {
    final repository = XiangjiRepository(
      dao: dao,
      todoDao: _EmptyTodoDao(),
      agentService: _UnavailableAgentService(dao),
    );
    const cases = <(String, String)>[
      ('我想恢复晨间写作，本周已经写了两次', '今天完成了15分钟写作并记下了一个可观察结果'),
      ('我想改善睡前整理习惯，昨天做了十分钟', '今天完成了整理，并记录了实际用时'),
      ('我想找到更稳定的学习节奏，已经连续三天练习', '今天完成了最小练习并得到了一条新反馈'),
    ];

    for (final entry in cases) {
      final initial = await repository.consultStrategist(
        utterance: entry.$1,
      );
      expect(initial.actionId, isNotEmpty);
      expect(initial.draft.operatorMechanism, isNotEmpty);
      expect(initial.draft.prediction, isNotEmpty);
      await repository.respondToDecisionDraft(
        decisionDraftId: initial.decisionDraftId,
        status: XiangjiDecisionDraftStatus.adopted,
      );
      await repository.startAction(
        actionId: initial.actionId,
        userConfirmed: true,
      );

      final updated = await repository.reconcileRealityFromNaturalLanguage(
        actionId: initial.actionId,
        feedback: entry.$2,
      );
      final reality = await dao.realityResult(initial.actionId);
      final completedAction = await dao.action(initial.actionId);
      final latestSituation = await dao.latestSituationModel(
        objectType: 'problem',
        objectId: initial.problemId,
      );

      expect(reality?['verdict'], 'supports');
      expect(completedAction?.state, XiangjiActionState.done);
      expect(updated.situationModelId, isNot(initial.situationModelId));
      expect((latestSituation?['version_no'] as num?)?.toInt(), 2);
      expect(updated.actionId, isNotEmpty);
    }
  });

  test('legacy Rev2 tables receive all Rev3 columns without data reset',
      () async {
    final legacyDirectory =
        await Directory.systemTemp.createTemp('xiangji_rev3_legacy_');
    final legacy = await databaseFactoryFfi.openDatabase(
      p.join(legacyDirectory.path, 'legacy.db'),
    );
    try {
      await legacy.execute(
        'CREATE TABLE xf_problem (id TEXT PRIMARY KEY, state TEXT, updated_at_ms INTEGER)',
      );
      await legacy.execute(
        'CREATE TABLE xf_concept_version (id TEXT PRIMARY KEY)',
      );
      await legacy.execute(
        'CREATE TABLE xf_information_need (id TEXT PRIMARY KEY, problem_id TEXT, status TEXT, evsi_rank REAL)',
      );
      await legacy.execute(
        'CREATE TABLE xf_decision_draft (id TEXT PRIMARY KEY, problem_id TEXT, updated_at_ms INTEGER)',
      );
      await legacy.execute(
        'CREATE TABLE xf_strategy_option (id TEXT PRIMARY KEY)',
      );
      await legacy.execute(
        'CREATE TABLE xf_reality_result (id TEXT PRIMARY KEY)',
      );
      final legacyDao = XiangjiDao(database: legacy);
      await legacyDao.ensureSchema(legacy);

      Future<Set<String>> columns(String table) async =>
          (await legacy.rawQuery('PRAGMA table_info($table)'))
              .map((row) => (row['name'] ?? '').toString())
              .toSet();
      expect(await columns('xf_problem'), contains('situation_model_id'));
      expect(
        await columns('xf_concept_version'),
        containsAll(<String>['support_refs_json', 'counterexample_refs_json']),
      );
      expect(
        await columns('xf_information_need'),
        contains('resolution_action_id'),
      );
      expect(await columns('xf_decision_draft'), contains('agent_run_id'));
      expect(
        await columns('xf_strategy_option'),
        contains('opportunity_cost'),
      );
      expect(await columns('xf_reality_result'), contains('experience_json'));
    } finally {
      await legacy.close();
      await legacyDirectory.delete(recursive: true);
    }
  });

  test('module export advertises Rev3 without losing Rev2 tables', () async {
    final snapshot = await dao.exportSnapshot();
    final tables = snapshot['tables'] as Map<String, Object?>;

    expect(snapshot['format'], 'xiangji-future-strategist-v6.1-rev3');
    expect(tables, contains('xf_problem'));
    expect(tables, contains('xf_decision_draft'));
  });
}

class _UnavailableAgentService extends XiangjiAgentService {
  _UnavailableAgentService(XiangjiDao dao) : super(dao: dao);

  @override
  Future<XiangjiAgentResult> run(XiangjiAgentRequest request) async {
    throw StateError('Test provider intentionally unavailable.');
  }
}

class _EmptyTodoDao extends TodoDao {
  @override
  Future<List<TodoTaskRecord>> listTasks(
    String listId, {
    String filter = 'all',
    int limit = 50,
    int offset = 0,
  }) async =>
      <TodoTaskRecord>[];
}
