import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_practical_product.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_schopenhauer_core_catalog.dart';

void main() {
  test('V6.2 default experience is one closed reality-producing loop', () {
    final steps = XiangjiPracticalProductContract.coreLoop;

    expect(steps, hasLength(4));
    expect(steps.map((step) => step.id), <String>[
      'say_need',
      'choose_route',
      'do_one_action',
      'reality_review',
    ]);
    expect(steps.every((step) => step.userAction.isNotEmpty), isTrue);
    expect(steps.every((step) => step.systemWork.isNotEmpty), isTrue);
    expect(steps.every((step) => step.output.isNotEmpty), isTrue);
    expect(steps.last.output, contains('下一步'));
  });

  test('every visible feature explains use, output and knowledge grounding', () {
    final guides = XiangjiPracticalProductContract.featureGuides;
    final linkedCore = <String>{};

    expect(guides.map((guide) => guide.id).toSet(), hasLength(guides.length));
    for (final guide in guides) {
      expect(guide.what, isNotEmpty, reason: guide.id);
      expect(guide.whenToUse, isNotEmpty, reason: guide.id);
      expect(guide.whatToProvide, isNotEmpty, reason: guide.id);
      expect(guide.steps, isNotEmpty, reason: guide.id);
      expect(guide.output, isNotEmpty, reason: guide.id);
      expect(guide.why, isNotEmpty, reason: guide.id);
      expect(guide.problemSolved, isNotEmpty, reason: guide.id);
      expect(guide.knowledgeSource, isNotEmpty, reason: guide.id);
      expect(guide.coreConceptIds, isNotEmpty, reason: guide.id);
      expect(
        guide.coreConceptIds,
        everyElement(isIn(XiangjiSchopenhauerCoreCatalog.ids)),
        reason: guide.id,
      );
      linkedCore.addAll(guide.coreConceptIds);
    }

    expect(
      linkedCore,
      containsAll(XiangjiSchopenhauerCoreCatalog.ids),
      reason: '24 项叔本华 L0 核心都必须至少约束一个可操作功能。',
    );
  });

  test('three default cases preserve the complete action-reality-revision trace',
      () {
    final cases = XiangjiPracticalProductContract.guidedCases;

    expect(cases, hasLength(3));
    expect(cases.map((item) => item.id).toSet(), hasLength(3));
    for (final item in cases) {
      expect(item.need, isNotEmpty, reason: item.id);
      expect(item.realityFacts, isNotEmpty, reason: item.id);
      expect(item.userInterpretations, isNotEmpty, reason: item.id);
      expect(item.competingCauses.length, greaterThanOrEqualTo(2),
          reason: item.id);
      expect(item.goal, isNotEmpty, reason: item.id);
      expect(item.keyGap, isNotEmpty, reason: item.id);
      expect(item.routeChoices, hasLength(3), reason: item.id);
      expect(item.selectedAction, isNotEmpty, reason: item.id);
      expect(item.prediction, isNotEmpty, reason: item.id);
      expect(item.realityResult, isNotEmpty, reason: item.id);
      expect(item.revision, isNotEmpty, reason: item.id);
      expect(item.nextStep, isNotEmpty, reason: item.id);
      expect(item.sourceLabel, isNotEmpty, reason: item.id);
    }
  });

  test('action burden follows current energy without changing the real problem',
      () {
    const engine = XiangjiPersonalizedActionChoiceEngine();
    const baseAction = '向一个真实岗位发出一份定向申请';
    final low = engine.build(
      baseAction: baseAction,
      mechanism: '用真实投递获得岗位反馈',
      prediction: '会获得一个外部可观察结果',
      expectedMinutes: 15,
      profile: const XiangjiUserPreferenceProfile(
        interestTags: <String>['创作', '轻松开始'],
        valueTags: <String>['自由'],
        strengthTags: <String>['创造'],
        obstacleTags: <String>['担心被评价'],
        energyLevel: 'low',
        preferredMinutes: 3,
      ),
      goal: '一周内取得可比较的求职反馈',
      keyGap: '缺少真实投递样本',
      activeCoreConceptIds: const <String>['SC-K0-011'],
      activeMethodLabels: const <String>['竞争原因与区分实验'],
      activeKnowledgeSources: const <String>['叔本华《充足根据律的四重根》'],
    );
    final challenge = engine.build(
      baseAction: baseAction,
      mechanism: '用真实投递获得岗位反馈',
      prediction: '会获得一个外部可观察结果',
      expectedMinutes: 15,
      profile: const XiangjiUserPreferenceProfile(
        interestTags: <String>['探索', '探索挑战'],
        valueTags: <String>['成就'],
        strengthTags: <String>['好奇'],
        energyLevel: 'high',
        supportStyle: 'challenge',
      ),
      goal: '一周内取得可比较的求职反馈',
      keyGap: '缺少真实投递样本',
      activeCoreConceptIds: const <String>['SC-K0-011'],
      activeMethodLabels: const <String>['竞争原因与区分实验'],
      activeKnowledgeSources: const <String>['叔本华《充足根据律的四重根》'],
    );

    expect(low, hasLength(3));
    expect(low.singleWhere((item) => item.preferred).id, 'tiny_start');
    expect(challenge.singleWhere((item) => item.preferred).id,
        'reality_challenge');
    expect(low.every((item) => item.action.contains('申请')), isTrue);
    expect(challenge.every((item) => item.action.contains('申请')), isTrue);
    for (final choice in <XiangjiActionChoice>[...low, ...challenge]) {
      expect(choice.visibleOutput, isNotEmpty, reason: choice.id);
      expect(choice.completionSignal, isNotEmpty, reason: choice.id);
      expect(choice.recoveryAction, isNotEmpty, reason: choice.id);
      expect(choice.principlePractice, contains('竞争原因'), reason: choice.id);
      expect(choice.transferQuestion, isNotEmpty, reason: choice.id);
      expect(choice.motivationCue, isNotEmpty, reason: choice.id);
      expect(choice.knowledgeSource, contains('叔本华'), reason: choice.id);
      expect(choice.coreConceptIds, contains('SC-K0-011'), reason: choice.id);
      expect(choice.activeMethodLabels, contains('竞争原因与区分实验'));
    }
    expect(
      low.first.fitReason,
      allOf(contains('创造'), contains('小作品')),
    );
    expect(low.first.recoveryAction, contains('只给自己看'));
    expect(low.first.recoveryAction, isNot(contains('人格')));
    expect(challenge.last.fitReason, allOf(contains('探索'), contains('好奇')));
  });

  test('offline usage assistant routes real questions to existing functions', () {
    expect(
      XiangjiPracticalProductContract.answerLocally('这个判断没有证据，凭什么成立？')
          .guideId,
      'grounding_and_debt',
    );
    expect(
      XiangjiPracticalProductContract.answerLocally('我说不清，但总觉得哪里不对')
          .guideId,
      'intuition_and_cause',
    );
    expect(
      XiangjiPracticalProductContract.answerLocally('怎样导出或删除数据？')
          .guideId,
      'settings_ai_data',
    );
  });

  test('usage assistant answers the current action instead of reciting a guide',
      () {
    const context = XiangjiUsageAssistantContext(
      problemId: 'problem-1',
      problem: '想找到一份可以接受的工作',
      goal: '一周内取得三份真实回复',
      keyGap: '缺少真实投递样本',
      currentActionId: 'action-1',
      currentAction: '向一个真实岗位发出定向申请',
      actionState: 'BLOCKED',
      actionStateLabel: '遇到阻碍',
      prediction: '会得到回复或一个可修改差异',
      stopCondition: '发出一份申请就停',
      recoveryAction: '只打开一个岗位并写第一条匹配点',
      principlePractice: '用现实投递区分候选原因',
      knowledgeSource: '叔本华 L0 认识根据',
      coreConceptIds: <String>['SC-K0-005', 'SC-K0-016'],
      activeMethodLabels: <String>['竞争原因与区分实验'],
    );

    final blocked = XiangjiPracticalProductContract.answerLocally(
      '我现在卡住了，该做什么？',
      context: context,
    );
    final why = XiangjiPracticalProductContract.answerLocally(
      '为什么是这一步，哪个思想和概念？',
      context: context,
    );

    expect(blocked.destination, 'current_action');
    expect(blocked.answer, contains('只打开一个岗位'));
    expect(blocked.answer, contains('向一个真实岗位'));
    expect(why.answer, contains('缺少真实投递样本'));
    expect(why.answer, contains('竞争原因与区分实验'));
    expect(why.knowledgeSource, contains('叔本华'));
  });

  test('motivation boundary supports autonomy and rejects coercive dependency',
      () {
    final boundary = XiangjiPracticalProductContract.ethicalBoundary;

    expect(boundary, contains('自主选择'));
    expect(boundary, contains('可见产出'));
    expect(boundary, contains('禁止羞耻'));
    expect(boundary, contains('制造依赖'));
  });
}
