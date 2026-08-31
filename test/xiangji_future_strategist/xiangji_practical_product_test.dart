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
        energyLevel: 'low',
        preferredMinutes: 3,
      ),
    );
    final challenge = engine.build(
      baseAction: baseAction,
      mechanism: '用真实投递获得岗位反馈',
      prediction: '会获得一个外部可观察结果',
      expectedMinutes: 15,
      profile: const XiangjiUserPreferenceProfile(
        interestTags: <String>['探索挑战'],
        energyLevel: 'high',
        supportStyle: 'challenge',
      ),
    );

    expect(low, hasLength(3));
    expect(low.singleWhere((item) => item.preferred).id, 'tiny_start');
    expect(challenge.singleWhere((item) => item.preferred).id,
        'reality_challenge');
    expect(low.every((item) => item.action.contains('申请')), isTrue);
    expect(challenge.every((item) => item.action.contains('申请')), isTrue);
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

  test('motivation boundary supports autonomy and rejects coercive dependency',
      () {
    final boundary = XiangjiPracticalProductContract.ethicalBoundary;

    expect(boundary, contains('自主选择'));
    expect(boundary, contains('可见产出'));
    expect(boundary, contains('禁止羞耻'));
    expect(boundary, contains('制造依赖'));
  });
}
