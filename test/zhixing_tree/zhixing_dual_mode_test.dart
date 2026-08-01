import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhixing_tree/zhixing_agent_service.dart';
import 'package:quote_app/zhixing_tree/zhixing_extended_models.dart';
import 'package:quote_app/zhixing_tree/zhixing_models.dart';
import 'package:quote_app/zhixing_tree/zhixing_remote_knowledge_models.dart';
import 'package:quote_app/zhixing_tree/zhixing_review_engine.dart';

void main() {
  group('local and AI-derived knowledge isolation', () {
    test('AI draft validates detail and keeps ai-derived origin', () {
      final draft = ZxAiKnowledgeDraft.fromAiJson(
        <String, dynamic>{
          'title': '融合思想体系',
          'core_values': <String>['真实', '行动', '责任', '反馈'],
          'core_ideas': List<String>.generate(
            8,
            (index) => '核心思想' + (index + 1).toString(),
          ),
          'knowledge_view': '知要进入可检验的判断。',
          'action_view': '行是具体实行与承担反馈。',
          'transformation_path': '认识→行动→反馈→修正',
          'decision_cue': '理解很多但尚未开始时使用。',
          'yangming_connection': '把知行合一转成可反馈的实践路径。',
          'common_ground': <String>['反对空谈'],
          'differences': <String>['更强调实验反馈'],
          'boundaries': <String>['不是疾病诊断'],
        },
        thinker: '测试思想家',
        bookIds: const <int>[1, 2],
        provider: 'openai',
        modelLabel: 'OpenAI · test',
      );

      expect(draft.origin, ZxKnowledgeOrigin.aiDerived);
      expect(draft.toMap()['origin'], 'ai_derived');
      expect(
        ZxAiKnowledgeDraft.fromMap(draft.toMap()).coreIdeas,
        hasLength(8),
      );
    });

    test('remote-derived draft remains explicitly distinct from local upload',
        () {
      final draft = ZxAiKnowledgeDraft.fromAiJson(
        <String, dynamic>{
          'title': '远端融合体系',
          'core_values': <String>['真实', '行动', '责任', '反馈'],
          'core_ideas': List<String>.generate(
            8,
            (index) => '核心思想' + (index + 1).toString(),
          ),
          'knowledge_view': '知要进入可检验的判断。',
          'action_view': '行是具体实行与承担反馈。',
          'transformation_path': '认识→行动→反馈→修正',
          'decision_cue': '理解很多但尚未开始时使用。',
          'yangming_connection': '把知行合一转成可反馈的实践路径。',
          'common_ground': <String>['反对空谈'],
          'differences': <String>['更强调实验反馈'],
          'boundaries': <String>['不是疾病诊断'],
        },
        thinker: '测试思想家',
        bookIds: const <int>[1],
        provider: 'openai',
        modelLabel: 'OpenAI · test',
        sourceMode: 'remote_knowledge',
      );

      expect(draft.usesRemoteKnowledge, isTrue);
      expect(
        ZxAiKnowledgeDraft.fromMap(draft.toMap()).usesRemoteKnowledge,
        isTrue,
      );
    });

    test('action serialization preserves guidance source and draft reference',
        () {
      final action = _action().copyWith(
        guidanceOrigin: 'ai_derived',
        guidanceKnowledgeRefId: 42,
        aiProvider: 'openai',
        aiModelLabel: 'OpenAI · test',
      );
      final restored = ZxActionPrescription.fromJson(action.toJson());

      expect(restored.guidanceOrigin, 'ai_derived');
      expect(restored.guidanceKnowledgeRefId, 42);
      expect(restored.aiProvider, 'openai');
      expect(restored.aiModelLabel, 'OpenAI · test');
    });
  });

  group('persistent remote knowledge identifiers', () {
    test('provider-specific ready state requires durable identifiers', () {
      const openAi = ZxRemoteKnowledgeItem(
        bookId: 1,
        provider: ZxRemoteKnowledgeProvider.openai,
        remoteFileId: 'file_123',
        remoteStoreId: 'vs_123',
      );
      const geminiPending = ZxRemoteKnowledgeItem(
        bookId: 2,
        provider: ZxRemoteKnowledgeProvider.gemini,
        remoteStoreId: 'fileSearchStores/store_123',
        remoteDocumentId: 'operations/pending_123',
        status: ZxRemoteKnowledgeStatus.processing,
      );
      const geminiReady = ZxRemoteKnowledgeItem(
        bookId: 2,
        provider: ZxRemoteKnowledgeProvider.gemini,
        remoteStoreId: 'fileSearchStores/store_123',
        remoteDocumentId: 'fileSearchStores/store_123/documents/doc_123',
      );

      expect(openAi.isReady, isTrue);
      expect(geminiPending.isReady, isFalse);
      expect(geminiReady.isReady, isTrue);
    });

    test('Gemini retention wording does not claim permanent raw file storage',
        () {
      expect(
        ZxRemoteKnowledgeProvider.gemini.retentionLabel,
        contains('检索索引'),
      );
      expect(
        ZxRemoteKnowledgeProvider.gemini.retentionLabel,
        contains('原始文件'),
      );
    });
  });

  group('automatic local review report', () {
    const engine = ZxLocalReviewEngine();

    test('successful fitting action recommends continuing current thought', () {
      final report = engine.generate(
        action: _action(),
        review: _review(),
      );

      expect(report.origin, ZxKnowledgeOrigin.localReviewed);
      expect(
        report.recommendedDecision,
        ZxReviewDecision.continueCurrent,
      );
      expect(report.nextAction, isNotEmpty);
    });

    test('unfinished high-load action recommends a knowledge-based blend', () {
      final report = engine.generate(
        action: _action(),
        review: _review(
          completion: ZxCompletionStatus.notCompleted,
          difficultyFit: '过高',
        ),
      );

      expect(report.recommendedDecision, ZxReviewDecision.blendThoughts);
      expect(report.recommendedSystemIds, isNotEmpty);
      expect(report.barrierFinding, contains('负荷'));
    });
  });

  group('action mentor state machine', () {
    final agent = ZxAgentService();
    const goal = ZxGoal(title: '写论文');

    test('asks for goal before all other scenes', () {
      expect(
        agent.decide(
          goals: const <ZxGoal>[],
          actions: const <ZxActionPrescription>[],
          selectedThoughtCount: 0,
          hasRecentReport: false,
        ),
        ZxAgentScene.setGoal,
      );
    });

    test('asks for thought, action and review in sequence', () {
      expect(
        agent.decide(
          goals: const <ZxGoal>[goal],
          actions: const <ZxActionPrescription>[],
          selectedThoughtCount: 0,
          hasRecentReport: false,
        ),
        ZxAgentScene.chooseThought,
      );
      expect(
        agent.decide(
          goals: const <ZxGoal>[goal],
          actions: const <ZxActionPrescription>[],
          selectedThoughtCount: 1,
          hasRecentReport: false,
        ),
        ZxAgentScene.startAction,
      );
      expect(
        agent.decide(
          goals: const <ZxGoal>[goal],
          actions: <ZxActionPrescription>[
            _action(
              updatedAtMs: DateTime(2026, 1, 1, 8).millisecondsSinceEpoch,
            ),
          ],
          selectedThoughtCount: 1,
          hasRecentReport: false,
          now: DateTime(2026, 1, 1, 13),
        ),
        ZxAgentScene.requestReview,
      );
    });
  });
}

ZxActionPrescription _action({int updatedAtMs = 0}) => ZxActionPrescription(
      id: 'action-1',
      goalTitle: '写论文',
      targetBehavior: '打开文档写第一段',
      primaryLensId: 'WY_KNOW_ACT',
      primaryBarrier: ZxBarrier.automaticMotivation,
      stage: ZxStage.s1,
      difficulty: ZxDifficulty.l1,
      risk: ZxRiskLevel.r0,
      thoughtLens: '在事上磨中检验所知',
      mainAction: '打开文档写一句主题句',
      lowerLoadAlternative: '只打开文档并停留30秒',
      challengeAlternative: '完成第一段',
      cue: '坐到书桌前',
      response: '打开文档写一句主题句',
      supportChanges: const <String>['关闭一个干扰入口'],
      stopConditions: const <String>['出现明显过载时停止'],
      proofOptions: const <ZxProofType>[ZxProofType.selfReport],
      completionDefinition: '文档中出现一句主题句',
      reviewQuestion: '行动怎样改变了原先判断？',
      evidenceLocators: const <String>['WY-S003-P0108'],
      uncertainty: 0.2,
      status: ZxActionStatus.active,
      createdAtMs: updatedAtMs,
      updatedAtMs: updatedAtMs,
    );

ZxReviewInput _review({
  ZxCompletionStatus completion = ZxCompletionStatus.completed,
  String difficultyFit = '合适',
}) =>
    ZxReviewInput(
      completion: completion,
      learning: ZxLearningStatus.none,
      proofType: ZxProofType.selfReport,
      whatHappened: completion == ZxCompletionStatus.completed
          ? '实际完成'
          : '实际没有开始',
      hypothesisUpdate: '',
      difficultyFit: difficultyFit,
      consequences: '',
      nextDecision: 'auto|',
      nextAction: '',
      reflectionDepth: 1,
    );
