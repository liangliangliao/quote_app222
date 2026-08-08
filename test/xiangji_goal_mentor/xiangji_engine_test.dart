import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_engine.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_knowledge_repository.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = XiangjiGoalMentorEngine();

  group('safety gate', () {
    test('blocks self-harm, violence, abuse danger and dangerous self-neglect',
        () {
      for (final text in <String>[
        '我不想活了',
        '我想杀人',
        '我被家暴',
        '为了目标几天不睡觉',
      ]) {
        final assessment = engine.assessSafety(text);
        expect(assessment.highRisk, isTrue, reason: text);
        expect(assessment.message, isNotEmpty, reason: text);
      }
      expect(engine.assessSafety('我想把今天的一步缩小').highRisk, isFalse);
    });
  });

  group('goal and guidance generation', () {
    test('creates one controllable action with traceable local sources', () {
      final draft = engine.buildDraft(
        '父母觉得我应该考证，但我想先弄清这是不是自己的目标',
        _catalog(),
        selectedMentorId: 'self_determination',
      );

      expect(draft.guidance.systemId, 'self_determination');
      expect(draft.guidance.mechanismId, 'mentor_goal_core');
      expect(draft.guidance.sources, hasLength(1));
      expect(draft.guidance.sources.single.locator, 'BOOK-1-P10');
      expect(draft.step.actionText, contains('最小可见版本'));
      expect(draft.step.minimumDone, isNotEmpty);
      expect(draft.step.evidenceRule, isNotEmpty);
      expect(draft.step.controllabilityReason, contains('外在结果'));
    });

    test('shrinking lowers burden while keeping the same goal direction', () {
      final step = engine
          .buildDraft(
            '我想开始写作',
            _catalog(),
            selectedMentorId: 'yangming',
          )
          .step;
      final smaller = engine.shrinkStep(step);

      expect(smaller.actionText, step.smallerVariant);
      expect(smaller.actionText, isNot(step.actionText));
      expect(smaller.sourceSystemId, step.sourceSystemId);
      expect(smaller.controllabilityReason, contains('只要求启动'));
    });

    test('stops when a selected system has no traceable evidence', () {
      final catalog = XiangjiKnowledgeCatalog(
        version: 'test',
        title: 'test',
        systems: <XiangjiKnowledgeSystem>[
          _system('self_determination', evidence: const <XiangjiEvidenceRecord>[]),
          _system('yangming', evidence: const <XiangjiEvidenceRecord>[]),
        ],
        books: const <XiangjiBookInfo>[],
      );

      expect(
        () => engine.buildDraft('父母要求我必须成功', catalog),
        throwsStateError,
      );
    });
  });

  test('selected V2.1 mentors produce distinct judgments and actions',
      () async {
    final catalog = await XiangjiKnowledgeRepository().load();
    final adler = engine.buildDraft(
      '我想重新确定未来一年的工作方向',
      catalog,
      selectedMentorId: 'adler',
    );
    final frankl = engine.buildDraft(
      '我想重新确定未来一年的工作方向',
      catalog,
      selectedMentorId: 'frankl',
    );

    expect(adler.guidance.systemId, 'adler');
    expect(frankl.guidance.systemId, 'frankl');
    expect(adler.guidance.coreJudgment, isNot(frankl.guidance.coreJudgment));
    expect(adler.step.actionText, isNot(frankl.step.actionText));
    expect(adler.guidance.selectionReason, contains('主动选择'));
    expect(frankl.guidance.selectionReason, contains('主动选择'));
  });

  test('four-layer calibration can produce all five specified outcomes', () {
    final goal = _goal();
    final results = <XiangjiCalibrationResult>{
      engine
          .calibrationDecision(
            goal: goal,
            valueAnswer: 'yes',
            goalAnswer: 'yes',
            methodAnswer: 'effective',
            actionAnswer: 'fit',
          )
          .result,
      engine
          .calibrationDecision(
            goal: goal,
            valueAnswer: 'yes',
            goalAnswer: 'yes',
            methodAnswer: 'ineffective',
            actionAnswer: 'fit',
          )
          .result,
      engine
          .calibrationDecision(
            goal: goal,
            valueAnswer: 'yes',
            goalAnswer: 'yes',
            methodAnswer: 'effective',
            actionAnswer: 'too_big',
          )
          .result,
      engine
          .calibrationDecision(
            goal: goal,
            valueAnswer: 'yes',
            goalAnswer: 'yes',
            methodAnswer: 'effective',
            actionAnswer: 'conditions_unavailable',
          )
          .result,
      engine
          .calibrationDecision(
            goal: goal,
            valueAnswer: 'no',
            goalAnswer: 'yes',
            methodAnswer: 'effective',
            actionAnswer: 'fit',
          )
          .result,
    };

    expect(results, unorderedEquals(XiangjiCalibrationResult.values));
  });

  test('records non-start and goal-exit evidence without failure language', () {
    const step = XiangjiDailyStep(
      id: 1,
      goalId: 1,
      goalVersionId: 1,
      actionText: '写下第一句。',
      triggerContext: '打开文档时。',
      minimumDone: '一句。',
      evidenceRule: '保留文字。',
      controllabilityReason: '由自己控制。',
      smallerVariant: '写一个词。',
      sourceSystemId: 'yangming',
      status: 'ready',
      createdAtMs: 0,
    );
    final notStarted = engine.evidenceSummary(
      step: step,
      resultType: 'not_started',
      userText: '今天需要先休息',
    );
    final exited = engine.evidenceSummary(
      step: step,
      resultType: 'no_longer_relevant',
      userText: '目标已经改变',
    );

    expect(notStarted, contains('现实条件'));
    expect(notStarted, isNot(contains('失败')));
    expect(exited, contains('不再适合'));
    expect(exited, contains('目标已经改变'));
  });
}

XiangjiKnowledgeCatalog _catalog() {
  const evidence = <XiangjiEvidenceRecord>[
    XiangjiEvidenceRecord(
      id: 'EV-1',
      sourceId: 'BOOK-1',
      locator: 'BOOK-1-P10',
      claim: '自主选择支持目标内化。',
      summary: '区分外部控制与自主选择。',
      boundary: '不代表忽视现实责任。',
    ),
  ];
  return XiangjiKnowledgeCatalog(
    version: 'test-1',
    title: '测试知识库',
    systems: <XiangjiKnowledgeSystem>[
      _system('self_determination', evidence: evidence),
      _system('yangming', evidence: evidence),
    ],
    books: const <XiangjiBookInfo>[
      XiangjiBookInfo(
        id: 'BOOK-1',
        title: '测试书籍',
        author: '测试作者',
        edition: '第一版',
        sourceStatus: 'licensed',
        builtIn: true,
      ),
    ],
  );
}

XiangjiKnowledgeSystem _system(
  String id, {
  required List<XiangjiEvidenceRecord> evidence,
}) {
  return XiangjiKnowledgeSystem(
    id: id,
    displayName: id == 'yangming' ? '王阳明' : '自我决定理论',
    thinker: id,
    coreValues: const <String>['自主'],
    coreIdeas: const <String>['先区分自己的选择与外部控制。'],
    knowledgeView: '通过可回定位依据理解目标。',
    actionView: '形成一个由自己控制的行动。',
    splitDiagnosis: '区分价值、目标、方法与行动。',
    transformationPath: '澄清选择，再做低成本实验。',
    decisionCue: '先检查这是否仍是你的选择。',
    tensions: const <String>['这一视角不替代专业支持。'],
    sourceIds: const <String>['BOOK-1'],
    evidence: evidence,
  );
}

XiangjiGoal _goal() {
  return const XiangjiGoal(
    id: 1,
    versionId: 1,
    state: XiangjiGoalState.active,
    isActive: true,
    originalText: '开始写作',
    whyText: '表达与成长',
    higherValues: <String>['自主', '成长'],
    successDefinition: '完成可控行动',
    scopeText: '未来七天',
    primaryThinkerId: 'yangming',
    currentNodeId: 'knowledge_action_gap',
    createdAtMs: 0,
    updatedAtMs: 0,
  );
}
