import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_method_catalog.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_practical_product.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_repository.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_rev3_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_schopenhauer_core_catalog.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_signature_method_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late XiangjiDao dao;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = XiangjiDao(database: database);
    await dao.ensureSchema(database);
  });

  tearDown(() => database.close());

  test('TC-KB-001/002 seeds protected offline K0 with source locators',
      () async {
    final rules = await dao.enabledRules();
    final passages = await dao.sourcePassages('XF-K0-SCHOPENHAUER');

    expect(rules, isNotEmpty);
    expect(rules.any((row) => row['rule_code'] == 'K0-RULE-025'), isTrue);
    expect(passages, isNotEmpty);
    expect(
      passages.every((row) => (row['locator'] ?? '').toString().isNotEmpty),
      isTrue,
    );
  });

  test('TC-KB-REV52 seeds the complete method and rule inventory', () async {
    final coreNodes = await dao.knowledgeNodes(
      sourceId: XiangjiSchopenhauerCoreCatalog.sourceId,
      limit: 100,
    );
    final nodes = await dao.knowledgeNodes(
      sourceId: XiangjiMethodCatalog.sourceId,
      limit: 100,
    );
    final rules = await dao.knowledgeRules(sourceId: 'XF-K0-SCHOPENHAUER');
    final methodCoreEdges = await database.query(
      'xf_knowledge_edge',
      where: 'relation_type = ?',
      whereArgs: const <Object?>['L0_CONSTRAINS_METHOD'],
    );

    expect(coreNodes, hasLength(24));
    expect(
      coreNodes.map((row) => row['id']),
      containsAll(XiangjiSchopenhauerCoreCatalog.ids),
    );
    expect(
      coreNodes.every(
        (row) => (row['provenance_json'] ?? '')
            .toString()
            .contains('feature_bindings'),
      ),
      isTrue,
    );

    expect(nodes, hasLength(14));
    expect(
      nodes.map((row) => row['id']),
      containsAll(XiangjiMethodCatalog.ids),
    );
    expect(
      nodes.every(
        (row) => (row['provenance_json'] ?? '')
            .toString()
            .contains('source_concept'),
      ),
      isTrue,
    );
    expect(methodCoreEdges, isNotEmpty);
    expect(
      methodCoreEdges.map((row) => row['from_id']).toSet(),
      containsAll(XiangjiSchopenhauerCoreCatalog.ids),
    );
    expect(
      rules.where(
        (row) => (row['rule_code'] ?? '').toString().startsWith('SCK-'),
      ),
      hasLength(18),
    );
    expect(
      rules.where(
        (row) => (row['rule_code'] ?? '').toString().startsWith('CEL-'),
      ),
      hasLength(18),
    );
    expect(
      rules.where(
        (row) => (row['rule_code'] ?? '').toString().startsWith('PS-'),
      ),
      hasLength(10),
    );
    expect(
      rules.where((row) {
        final code = (row['rule_code'] ?? '').toString();
        return !code.startsWith('SCK-') &&
            !code.startsWith('CEL-') &&
            !code.startsWith('PS-');
      }),
      hasLength(17),
    );
  });

  test('TC-V62-GUIDE seeds cases, feature grounding and user preferences',
      () async {
    final cases = await dao.guidedCases();
    final guideNodes = await database.query(
      'xf_knowledge_node',
      where: 'source_id = ? AND node_type = ?',
      whereArgs: const <Object?>[
        'XF-PRODUCT-GUIDE-V6.2',
        'product_feature_guide',
      ],
    );
    final caseNodes = await database.query(
      'xf_knowledge_node',
      where: 'source_id = ? AND node_type = ?',
      whereArgs: const <Object?>[
        'XF-PRODUCT-GUIDE-V6.2',
        'guided_complete_case',
      ],
    );
    final featureEdges = await database.query(
      'xf_knowledge_edge',
      where: 'relation_type = ?',
      whereArgs: const <Object?>['L0_GROUNDS_FEATURE'],
    );

    expect(cases, hasLength(XiangjiPracticalProductContract.guidedCases.length));
    expect(
      guideNodes,
      hasLength(XiangjiPracticalProductContract.featureGuides.length),
    );
    expect(
      caseNodes,
      hasLength(XiangjiPracticalProductContract.guidedCases.length),
    );
    expect(
      featureEdges.map((row) => row['from_id']).toSet(),
      containsAll(XiangjiSchopenhauerCoreCatalog.ids),
    );

    const profile = XiangjiUserPreferenceProfile(
      interestTags: <String>['探索挑战'],
      valueTags: <String>['自由'],
      strengthTags: <String>['好奇'],
      energyLevel: 'high',
      supportStyle: 'challenge',
      preferredMinutes: 20,
      updatedAtMs: 123,
    );
    await dao.saveUserPreferenceProfile(profile);
    final restored = await dao.userPreferenceProfile();
    expect(restored.interestTags, profile.interestTags);
    expect(restored.valueTags, profile.valueTags);
    expect(restored.strengthTags, profile.strengthTags);
    expect(restored.energyLevel, 'high');
    expect(restored.supportStyle, 'challenge');
    expect(restored.preferredMinutes, 20);
  });

  test('TC-V62-ACTION user-selected burden becomes the authoritative action',
      () async {
    await dao.createProblem(
      id: 'problem-practical',
      rawEventId: 'event-practical',
      rawQuestion: '我想求职但一直只浏览',
      contextText: '今天浏览了岗位但没有投递。',
    );
    await dao.saveSituationModel(
      id: 'situation-practical',
      objectType: 'problem',
      objectId: 'problem-practical',
      version: 1,
      state: XiangjiSituationModelState.framed,
      summary: '需要用真实投递取得反馈',
      currentNeed: '找到工作',
      model: const <String, Object?>{},
      sourceRefs: const <String>['user:event-practical'],
    );
    await dao.createAction(
      id: 'action-practical',
      title: '发出一份定向申请',
      whyChain: const <String, Object?>{'key_gap': '缺少真实投递样本'},
      prediction: '会获得一个可比较结果',
      problemId: 'problem-practical',
      expectedMinutes: 15,
    );
    await dao.saveDecisionDraft(<String, Object?>{
      'id': 'draft-practical',
      'problem_id': 'problem-practical',
      'campaign_id': '',
      'action_id': 'action-practical',
      'situation_model_id': 'situation-practical',
      'true_problem': '浏览替代了现实投递',
      'recommendation': '获得一个现实样本',
      'judgment': '先投递再判断',
      'why_text': '缺少现实反馈',
      'current_action': '发出一份定向申请',
      'change_signals': '收到回复或发现材料差异',
      'epistemic_status': 'PROVISIONAL',
      'clarification_question': '',
      'options_json': '[]',
      'uncertainty_json': '{}',
      'weakest_premise': '尚不清楚材料是否匹配',
      'unresolved_items_json': '[]',
      'agent_run_id': '',
      'user_status': XiangjiDecisionDraftStatus.proposed.wire,
      'created_at_ms': 1,
      'updated_at_ms': 1,
    });
    const choice = XiangjiActionChoice(
      id: 'tiny_start',
      label: '轻松起步',
      action: '只用 3 分钟打开目标岗位并写出第一条匹配点',
      minutes: 3,
      stopCondition: '写出第一条匹配点或达到 3 分钟就停止',
      fitReason: '当前能量低，先启动',
      mechanism: '降低启动负担并取得第一个现实材料',
      prediction: '3 分钟后应至少得到一条岗位匹配信息',
      coreConceptIds: <String>['SC-K0-004', 'SC-K0-022'],
      preferred: true,
    );
    final repository = XiangjiRepository(dao: dao);

    await repository.adoptPracticalChoice(
      decisionDraftId: 'draft-practical',
      actionId: 'action-practical',
      choice: choice,
    );

    final action = await dao.action('action-practical');
    final draft = await dao.decisionDraft('draft-practical');
    expect(action?.title, choice.action);
    expect(action?.expectedMinutes, 3);
    expect(action?.prediction, choice.prediction);
    expect(action?.whyChain['stop_condition'], choice.stopCondition);
    expect(action?.whyChain['selected_experience_mode'], 'tiny_start');
    expect(action?.whyChain['user_selected'], isTrue);
    expect(draft?.status, XiangjiDecisionDraftStatus.adopted);
    expect(draft?.currentAction, choice.action);
  });

  test('TC-PS-001 preserves user raw material and derived layers separately',
      () async {
    await dao.createProblem(
      id: 'problem-1',
      rawEventId: 'event-1',
      rawQuestion: '我是否应该换工作？',
      contextText: '经理在周一会议上取消了我的项目。',
    );
    await dao.addClaim(
      id: 'claim-1',
      problemId: 'problem-1',
      text: '经理可能不再信任我',
      claimType: 'interpretation',
      state: XiangjiClaimState.draft,
      sourceKind: 'user',
      isUserWording: true,
    );

    final problem = await dao.problem('problem-1');
    final experiences = await dao.experiencesForProblem('problem-1');
    final claims = await dao.claimsForProblem('problem-1');

    expect(problem?.rawQuestion, '我是否应该换工作？');
    expect(experiences.single['content'], '经理在周一会议上取消了我的项目。');
    expect(claims.single['epistemic_status'], 'DRAFT');
    expect(claims.single['text'], isNot(equals(experiences.single['content'])));
  });

  test('TC-EP-008 deleting sole evidence downgrades high impact claim',
      () async {
    await dao.addClaim(
      id: 'claim-high',
      text: '关键资源一定会按期到位',
      claimType: 'prediction',
      state: XiangjiClaimState.grounded,
      importance: 'critical',
      sourceKind: 'document',
    );
    await database.insert('xf_evidence', <String, Object?>{
      'id': 'evidence-1',
      'problem_id': '',
      'campaign_id': '',
      'evidence_type': 'document',
      'source_ref': 'contract-1',
      'content': '供应合同',
      'content_hash': 'hash',
      'provenance_json': '{}',
      'sensitivity': 'normal',
      'collected_at_ms': 1,
      'deleted_at_ms': null,
    });
    await dao.addGrounding(
      id: 'ground-1',
      claimId: 'claim-high',
      groundType: 'evidence',
      groundRefId: 'evidence-1',
    );

    final affected = await dao.deleteEvidenceAndDowngradeClaims('evidence-1');
    final row = (await dao.allClaims()).single;

    expect(affected, contains('claim-high'));
    expect(row['epistemic_status'], 'EPISTEMIC_DEBT');
  });

  test('TC-KB-025 database rejects embedding as formal grounding', () async {
    expect(
      () => dao.addGrounding(
        id: 'bad-ground',
        claimId: 'claim',
        groundType: 'embedding',
        groundRefId: 'vector-hit',
      ),
      throwsArgumentError,
    );
  });

  test('TC-LG-005 action DONE never fabricates RealityResult', () async {
    await dao.createProblem(
      id: 'problem-2',
      rawEventId: 'event-2',
      rawQuestion: '怎样验证假设？',
      contextText: '需要一次测试。',
    );
    await dao.updateProblemState(
      'problem-2',
      XiangjiProblemState.actionReady,
    );
    await dao.createAction(
      id: 'action-1',
      title: '做一次小测试',
      whyChain: const <String, Object?>{'key_gap': '缺少现实反馈'},
      prediction: '会获得一个可观察结果',
      problemId: 'problem-2',
    );
    await dao.updateAction(
      'action-1',
      <String, Object?>{'state': XiangjiActionState.done.wire},
      eventType: 'done',
    );

    expect(await dao.realityResult('action-1'), isNull);
    expect(
      (await dao.problem('problem-2'))?.state,
      XiangjiProblemState.actionReady,
    );
    expect(
      (await dao.actions(currentOnly: true)).single.id,
      'action-1',
      reason:
          'Todo/Action 打勾后仍必须留在当前闭环，直到用户回填现实结果。',
    );
    expect(
      (await dao.dashboard()).currentAction?.id,
      'action-1',
      reason: '首页必须把“完成但未回填现实”作为最高优先级待办。',
    );

    await dao.recordRealityResult(
      id: 'reality-1',
      actionId: 'action-1',
      facts: const <String>['获得一个可观察结果'],
      unexpected: const <String>[],
      sourceRefs: const <String>['user:reality-1'],
      userInterpretation: '',
    );
    expect(await dao.actions(currentOnly: true), isEmpty);
  });

  test('TC-KB-013 one local source can map to multiple providers', () async {
    await dao.saveProviderFile(const XiangjiProviderFileRecord(
      id: 'provider-file-openai',
      providerId: 'openai',
      sourceId: 'same-source',
      state: XiangjiProviderFileState.ready,
      remoteFileId: 'file-openai',
      remoteStoreId: 'store-openai',
    ));
    await dao.saveProviderFile(const XiangjiProviderFileRecord(
      id: 'provider-file-gemini',
      providerId: 'gemini',
      sourceId: 'same-source',
      state: XiangjiProviderFileState.ready,
      remoteFileId: 'document-gemini',
      remoteStoreId: 'store-gemini',
    ));

    final rows = await dao.providerFiles(sourceId: 'same-source');
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.providerId), containsAll(<String>['openai', 'gemini']));
  });

  test('TC-KB-018 candidate knowledge starts outside stable personal rules',
      () async {
    await dao.saveCandidateKnowledge(
      id: 'candidate-1',
      statement: '我在上午更适合做深度工作',
      originRunId: 'run-1',
      supportingRefs: const <String>[],
      counterRefs: const <String>[],
      validationPlan: '跨两周记录至少四次',
      scope: '工作日',
    );

    final candidate = (await dao.candidateKnowledge()).single;
    expect(candidate['status'], XiangjiKnowledgeItemState.candidate.wire);
    expect(await dao.personalRules(), isEmpty);
  });

  test('data reset stays inside module and restores protected K0', () async {
    await dao.createProblem(
      id: 'problem-reset',
      rawEventId: 'event-reset',
      rawQuestion: '删除前的问题',
      contextText: '仅测试模块删除。',
    );
    final snapshot = await dao.exportSnapshot();

    await dao.resetUserData();

    expect((snapshot['tables'] as Map<String, Object?>)['xf_problem'], isNotEmpty);
    expect(await dao.problems(), isEmpty);
    expect(await dao.enabledRules(), isNotEmpty);
    expect(await dao.providerCapabilities(), isNotEmpty);
    expect(
      await dao.guidedCases(),
      hasLength(XiangjiPracticalProductContract.guidedCases.length),
      reason: '操作示例属于受保护产品说明，重置个人数据后仍应可用。',
    );
  });

  test('T-MEC-DB atomically persists SolverSnapshot and MethodEvent', () async {
    await dao.createProblem(
      id: 'problem-method',
      rawEventId: 'event-method',
      rawQuestion: '我不想去，所以我一定不适合工作吗？',
      contextText: '我不想去，所以我一定不适合工作。',
    );
    const router = XiangjiSignatureCapabilityRouter();
    final result = router.route(
      state: const XiangjiSolverSnapshot(
        problemId: 'problem-method',
        need: '判断是否不适合工作',
      ),
      context: const XiangjiSignatureMethodContext(
        problemId: 'problem-method',
        problemState: XiangjiProblemState.formalizing,
        requestedMethodIds: <String>['MEC-001'],
        experiences: <String>['我不想去'],
        interpretations: <String>['我一定不适合工作'],
        createdAtMs: 100,
        eventIdPrefix: 'db-method',
      ),
    );

    await dao.saveSolverStateAndMethodEvents(
      snapshot: result.after,
      events: result.events,
    );

    final snapshot = await dao.solverSnapshot('problem-method');
    final snapshots = await dao.solverSnapshots();
    final events = await dao.methodEvents(problemId: 'problem-method');
    expect(snapshot?.currentState['interpretations_may_drive_goal'], isFalse);
    expect(snapshots.single.problemId, 'problem-method');
    expect(events.single.methodId, 'MEC-001');
    expect(events.single.dataMutations, isNotEmpty);
    expect(events.single.stateVersion, snapshot?.stateVersion);

    final actionTurn = router.route(
      state: result.after,
      context: const XiangjiSignatureMethodContext(
        problemId: 'problem-method',
        problemState: XiangjiProblemState.executing,
        requestedMethodIds: <String>['MEC-013'],
        prediction: '完成后得到一条可观察事实',
        actionMode: true,
        visibleLimit: 0,
        createdAtMs: 200,
        eventIdPrefix: 'db-action-turn',
      ),
    );
    await dao.saveSolverStateAndMethodEvents(
      snapshot: actionTurn.after,
      events: actionTurn.events,
    );

    expect(
      await dao.latestMethodTurnEvents(problemId: 'problem-method'),
      isEmpty,
      reason: 'Action Mode 的零提示轮次不能回显上一轮方法卡',
    );
  });

  test('Method Effect gate rejects explanation-only MethodEvent', () async {
    const event = XiangjiMethodEvent(
      id: 'bad-method',
      methodId: 'MEC-011',
      problemId: 'problem-x',
      stateVersion: 1,
      trigger: 'S0/G known',
      operationSummary: '只解释，没有变更',
      dataMutations: <Map<String, Object?>>[],
      decisionEffect: '没有效果',
      userVisibleSummary: '说明卡',
      realityTest: '无',
    );

    expect(() => dao.saveMethodEvent(event), throwsArgumentError);
  });
}
