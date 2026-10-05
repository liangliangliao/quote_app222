import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_knowledge_route_core.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_schopenhauer_core_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late XiangjiDao dao;
  late XiangjiKnowledgeRouter router;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = XiangjiDao(database: database);
    await dao.ensureSchema(database);
    router = XiangjiKnowledgeRouter(dao: dao);
  });

  tearDown(() => database.close());

  test('TC-KB-005 route order starts with reality and offline K0', () async {
    await dao.createProblem(
      id: 'problem-route',
      rawEventId: 'event-route',
      rawQuestion: '怎样做一个重大决定？',
      contextText: '先保留我的真实处境。',
    );
    await dao.addEpistemicDebt(
      id: 'debt-route',
      problemId: 'problem-route',
      description: '关键成本未知',
      decisionImpact: 'high',
      groundingGap: '缺少报价',
    );

    final context = await router.route(const XiangjiKnowledgeRequest(
      requestId: 'request-route',
      query: '是否立即投入？',
      problemId: 'problem-route',
      isMajorDecision: true,
      hasUserConfirmation: false,
    ));

    expect(context.trace.routePlan.take(2), <String>[
      '1.current_reality',
      '2.k0_rule_preflight',
    ]);
    expect(context.trace.ruleIds, contains('K0-RULE-007'));
    expect(context.trace.debtIds, contains('debt-route'));
    expect(context.currentReality.single['content'], '先保留我的真实处境。');
    expect(context.coreConceptNodes, hasLength(24));
    expect(
      context.trace.routePlan,
      contains('4.l0_schopenhauer_core'),
    );
    expect(
      context.trace.sourcesUsed,
      containsAll(XiangjiSchopenhauerCoreCatalog.ids),
    );
    final promptCore = context.toPromptMap()['l0_schopenhauer_core'] as List;
    expect(promptCore, hasLength(24));
    expect(
      (promptCore.first as Map)['operational_rule'],
      isNotEmpty,
    );
    expect(await dao.retrievalTraces(), hasLength(1));
  });

  test('TC-KB-011 original-source request returns traceable locator',
      () async {
    final context = await router.route(const XiangjiKnowledgeRequest(
      requestId: 'request-source',
      query: '系统性',
      askingForOriginalSource: true,
    ));

    expect(context.passages, isNotEmpty);
    expect(
      context.passages.any(
        (row) => (row['locator'] ?? '').toString().contains('§14'),
      ),
      isTrue,
    );
    expect(context.trace.routePlan, contains('8.original_source_retriever'));
  });

  test('TC-KB-016 expired provider file is rejected, never silently reused',
      () async {
    await dao.saveProviderFile(XiangjiProviderFileRecord(
      id: 'expired-file',
      providerId: 'openai',
      sourceId: 'source-1',
      state: XiangjiProviderFileState.ready,
      remoteFileId: 'file-1',
      expiresAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
    ));

    final context = await router.route(const XiangjiKnowledgeRequest(
      requestId: 'request-remote',
      query: '读取大文件',
      needsLargeRemoteFile: true,
      preferredProviderId: 'openai',
    ));

    expect(context.providerFiles, isEmpty);
    expect(
      context.trace.rejectedSources,
      contains('openai:source-1:expired'),
    );
  });

  test('K0 risk gate is executable with no network or provider', () async {
    final context = await router.route(const XiangjiKnowledgeRequest(
      requestId: 'request-offline',
      query: '高风险操作',
      isHighRisk: true,
      isIrreversible: true,
      aiInferencePresentedAsFact: true,
    ));

    expect(context.preflight.executionFrozen, isTrue);
    expect(context.preflight.alertState, XiangjiAlertState.red);
    expect(context.preflight.ruleIds, contains('K0-RULE-002'));
  });
}
