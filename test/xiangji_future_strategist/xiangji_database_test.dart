import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
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
  });
}
