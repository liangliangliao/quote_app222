import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhixing_tree/zhixing_engines.dart';
import 'package:quote_app/zhixing_tree/zhixing_models.dart';
import 'package:quote_app/zhixing_tree/zhixing_productization.dart';
import 'package:quote_app/zhixing_tree/zhixing_review_engine.dart';

void main() {
  group('one-input productization', () {
    const product = ZxProductizationEngine();
    const diagnoser = ZxBehaviourDiagnoser();
    const matcher = ZxThinkerMatcher();
    const generator = ZxActionGenerator();
    final lens = _allPurposeLens();

    test('four experience modes change load without changing safety flags', () {
      final gentle = product.buildInput(
        goal: '开始找工作',
        availableMinutes: 15,
        preference: const ZxActionPreference(
          mode: ZxExperienceMode.gentle,
        ),
      );
      final challenge = product.buildInput(
        goal: '开始找工作',
        availableMinutes: 2,
        preference: const ZxActionPreference(
          mode: ZxExperienceMode.challenge,
        ),
      );

      expect(gentle.availableMinutes, 5);
      expect(challenge.availableMinutes, 10);
      expect(gentle.acuteDanger, isFalse);
      expect(challenge.acuteDanger, isFalse);
    });

    test('five one-tap blocks create distinct, testable hypotheses', () {
      final expected = <ZxStarterBlock, ZxBarrier>{
        ZxStarterBlock.unclear: ZxBarrier.psychologicalCapability,
        ZxStarterBlock.inertia: ZxBarrier.automaticMotivation,
        ZxStarterBlock.fear: ZxBarrier.selfEfficacy,
        ZxStarterBlock.lowEnergy: ZxBarrier.capacity,
        ZxStarterBlock.environment: ZxBarrier.physicalOpportunity,
      };

      for (final entry in expected.entries) {
        final input = product.buildInput(
          goal: '完成第一份求职投递',
          block: entry.key,
        );
        final diagnosis = diagnoser.diagnose(input);
        expect(
          diagnosis.hypotheses.map((item) => item.barrier),
          contains(entry.value),
          reason: entry.key.label,
        );
      }
    });

    test('all saved examples run through to an observable action', () {
      for (final example in zxStarterCases) {
        final input = product.buildInput(
          goal: example.goal,
          nextStep: example.nextStep,
          valueReason: example.valueReason,
          availableMinutes: example.minutes,
          block: example.block,
          preference: ZxActionPreference(mode: example.mode),
        );
        final diagnosis = diagnoser.diagnose(input);
        final match = matcher.match(
          input: input,
          diagnosis: diagnosis,
          lenses: <ZxThinkerLens>[lens],
        );
        final action = generator.generate(
          input: input,
          diagnosis: diagnosis,
          match: match,
        );

        expect(action, isNotNull, reason: example.title);
        expect(generator.validate(action!), isEmpty, reason: example.title);
        if (example.block != ZxStarterBlock.lowEnergy) {
          expect(action.mainAction, contains(example.nextStep));
        }
        expect(action.mainAction, isNotEmpty);
        expect(action.mainAction, isNot(contains('测试思想')));
        expect(action.completionDefinition, isNotEmpty);
        expect(action.lowerLoadAlternative, isNotEmpty);
      }
    });

    test('preference round-trip preserves all four personalization choices', () {
      const profile = ZxActionPreference(
        mode: ZxExperienceMode.experiment,
        anchor: ZxMotivationAnchor.curiosity,
        tone: ZxMentorTone.warm,
        strength: ZxStrengthPreference.creativity,
        completed: true,
        updatedAtMs: 42,
      );
      final restored = ZxActionPreference.fromJson(profile.toJson());

      expect(restored.mode, profile.mode);
      expect(restored.anchor, profile.anchor);
      expect(restored.tone, profile.tone);
      expect(restored.strength, profile.strength);
      expect(restored.completed, isTrue);
    });
  });

  group('assistant and embedded manual', () {
    const assistant = ZxModuleAssistantEngine();

    test('assistant routes practical questions to the right product area', () {
      expect(
        assistant.answer('这一步太难怎么办').area,
        ZxProductArea.action,
      );
      expect(
        assistant.answer('如何更换王阳明思想').area,
        ZxProductArea.thought,
      );
      expect(
        assistant.answer('OpenAI书籍上传和文件ID').area,
        ZxProductArea.mentor,
      );
      expect(
        assistant.answer('如何删除和导出数据').area,
        ZxProductArea.more,
      );
    });

    test('every visible feature explains input, output, reason and theory', () {
      expect(zxFeatureGuides.length, greaterThanOrEqualTo(10));
      for (final guide in zxFeatureGuides) {
        expect(guide.summary, isNotEmpty, reason: guide.id);
        expect(guide.input, isNotEmpty, reason: guide.id);
        expect(guide.output, isNotEmpty, reason: guide.id);
        expect(guide.why, isNotEmpty, reason: guide.id);
        expect(guide.theory, isNotEmpty, reason: guide.id);
        expect(guide.example, isNotEmpty, reason: guide.id);
      }
    });
  });

  group('feedback-specific review routing', () {
    const reviewEngine = ZxLocalReviewEngine();

    test('environment feedback changes both finding and thought route', () {
      final report = reviewEngine.generate(
        action: _activeAction(),
        review: _review('时间/工具/环境卡住'),
      );

      expect(report.barrierFinding, contains('环境'));
      expect(report.recommendedDecision, ZxReviewDecision.blendThoughts);
      expect(report.recommendedSystemIds, isNotEmpty);
    });

    test('fear feedback becomes a reversible experiment, not blame', () {
      final report = reviewEngine.generate(
        action: _activeAction(),
        review: _review('害怕失败/追求完美'),
      );

      expect(report.barrierFinding, contains('失败预测'));
      expect(report.rationale, isNot(contains('毅力不足')));
      expect(report.recommendedSystemIds, isNotEmpty);
    });
  });
}

ZxThinkerLens _allPurposeLens() => ZxThinkerLens(
      id: 'PRODUCT_TEST',
      sourceId: 'TEST',
      thinker: '测试思想',
      name: '只用于测试的镜头',
      coreQuestion: '怎样把目标变成一个动作？',
      mechanism: '依据现实障碍选择可求证动作。',
      bestFit: '普通低风险行动',
      nonFit: 'R3/R4',
      prerequisites: '目标已定义',
      contraindications: '即时危险',
      barriers: ZxBarrier.values,
      stages: ZxStage.values,
      difficulties: ZxDifficulty.values,
      methods: const <String>['行为', '环境', '价值', '子技能', '分级'],
      actionTemplates: const <String>['完成一个最小动作'],
      tensionLinks: const <String>['不把抽象理论写进主动作。'],
      evidenceLinks: const <String>['TEST-P0001-B001'],
      evidenceDirectness: 0.9,
      reviewStatus: 'approved',
    );

ZxActionPrescription _activeAction() => const ZxActionPrescription(
      id: 'review-route-action',
      goalTitle: '完成第一份求职投递',
      targetBehavior: '打开岗位并投递',
      primaryLensId: 'WY_KNOW_ACT',
      primaryBarrier: ZxBarrier.automaticMotivation,
      stage: ZxStage.s1,
      difficulty: ZxDifficulty.l1,
      risk: ZxRiskLevel.r0,
      thoughtLens: '在真实行动中检验判断',
      mainAction: '打开一条岗位并投递',
      lowerLoadAlternative: '只打开岗位页面并停留30秒',
      challengeAlternative: '投递三份匹配岗位',
      cue: '打开招聘软件时',
      response: '打开一条岗位并投递',
      supportChanges: <String>['关闭一个干扰入口'],
      stopConditions: <String>['出现明显过载时停止'],
      proofOptions: <ZxProofType>[ZxProofType.selfReport],
      completionDefinition: '出现一条提交记录',
      reviewQuestion: '事实发生了什么？',
      evidenceLocators: <String>['WY-S003-P0108'],
      uncertainty: 0.2,
      status: ZxActionStatus.active,
    );

ZxReviewInput _review(String reason) => ZxReviewInput(
      completion: ZxCompletionStatus.notCompleted,
      learning: ZxLearningStatus.updated,
      proofType: ZxProofType.selfReport,
      whatHappened: '实际没有开始；现实原因：' + reason,
      hypothesisUpdate: reason,
      difficultyFit: '合适',
      consequences: '',
      nextDecision: 'auto|',
      nextAction: '',
      reflectionDepth: 2,
    );
