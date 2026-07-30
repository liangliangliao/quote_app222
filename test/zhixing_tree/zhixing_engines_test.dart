import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhixing_tree/zhixing_engines.dart';
import 'package:quote_app/zhixing_tree/zhixing_knowledge_repository.dart';
import 'package:quote_app/zhixing_tree/zhixing_models.dart';
import 'package:quote_app/zhixing_tree/zhixing_thinker_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('knowledge package', () {
    test('loads 22 reviewed sources and 22 mechanism lenses with valid hash',
        () async {
      final repository = ZxKnowledgeRepository();
      await repository.load();

      expect(repository.packageInfo.integrityValid, isTrue);
      expect(repository.packageInfo.sourceCount, 22);
      expect(repository.works, hasLength(22));
      expect(repository.lenses, hasLength(22));
      for (final lens in repository.lenses) {
        expect(lens.evidenceLinks, isNotEmpty);
        for (final locator in lens.evidenceLinks) {
          expect(repository.locatorExists(locator), isTrue,
              reason: '${lens.id} -> $locator');
        }
      }
    });

    test('can retrieve both mechanisms and evidence locators', () async {
      final repository = ZxKnowledgeRepository();
      await repository.load();

      final results = repository.search('如果 那么 行动');
      expect(results, isNotEmpty);
      expect(results.any((item) => item.type == 'lens'), isTrue);
      expect(repository.search('BCW-P0064-B010'), isNotEmpty);
    });

    test('shows every reviewed thought in a complete ordered decision guide',
        () async {
      final repository = ZxKnowledgeRepository();
      await repository.load();

      expect(ZxThinkerCatalog.guides, hasLength(22));
      expect(
        ZxThinkerCatalog.guides.map((item) => item.sequence),
        orderedEquals(List<int>.generate(22, (index) => index + 1)),
      );
      expect(
        ZxThinkerCatalog.validateAgainst(repository.lenses),
        isEmpty,
      );
      for (final guide in ZxThinkerCatalog.guides) {
        expect(guide.coreValues, isNotEmpty);
        expect(guide.coreIdeas, isNotEmpty);
        expect(guide.distinctiveFocus, isNotEmpty);
        expect(guide.decisionCue, isNotEmpty);
        expect(guide.relatedLensIds, isNotEmpty);
      }
    });
  });

  group('safety and COM-B diagnosis', () {
    const safety = ZxSafetyGate();
    const diagnoser = ZxBehaviourDiagnoser();

    test('R4 and R3 block ordinary actions', () {
      final acute = safety.evaluate(_input(acuteDanger: true));
      final professional =
          safety.evaluate(_input(professionalDecision: true));

      expect(acute.risk, ZxRiskLevel.r4);
      expect(acute.actionAllowed, isFalse);
      expect(professional.risk, ZxRiskLevel.r3);
      expect(professional.actionAllowed, isFalse);
    });

    test('low capacity restricts action to L1', () {
      final result = safety.evaluate(
        _input(
          bodyCapacity: 0.2,
          attentionCapacity: 0.2,
          sleepCapacity: 0.25,
        ),
      );

      expect(result.risk, ZxRiskLevel.r1);
      expect(result.maximumDifficulty, ZxDifficulty.l1);
    });

    test('missing time and tools diagnose opportunity, not vague motivation',
        () {
      final result = diagnoser.diagnose(
        _input(
          hasTime: false,
          hasTools: false,
          availableMinutes: 5,
        ),
      );

      expect(result.primary.barrier, ZxBarrier.physicalOpportunity);
      expect(result.hypotheses.length, lessThanOrEqualTo(3));
      expect(result.primary.evidence.join(' '), contains('时间'));
    });
  });

  group('thinker matching and prescription', () {
    const diagnoser = ZxBehaviourDiagnoser();
    const matcher = ZxThinkerMatcher();
    const generator = ZxActionGenerator();

    test('uses the documented weighted fit formula and selects direct lens',
        () {
      final input = _input(
        hasTime: false,
        hasTools: false,
        availableMinutes: 15,
        valueReason: '对我的学习承诺负责',
      );
      final diagnosis = diagnoser.diagnose(input);
      final direct = _lens(
        id: 'DIRECT',
        barriers: const <ZxBarrier>[ZxBarrier.physicalOpportunity],
        methods: const <String>['环境重构', 'COM-B'],
        evidenceDirectness: 1,
      );
      final vague = _lens(
        id: 'VAGUE',
        sourceId: 'B',
        barriers: const <ZxBarrier>[ZxBarrier.reflectiveMotivation],
        stages: const <ZxStage>[ZxStage.s4],
        difficulties: const <ZxDifficulty>[ZxDifficulty.l3],
        methods: const <String>['意志'],
        evidenceDirectness: 0.5,
      );

      final result = matcher.match(
        input: input,
        diagnosis: diagnosis,
        lenses: <ZxThinkerLens>[vague, direct],
      );

      expect(result.primary.id, 'DIRECT');
      expect(result.scoreFor('DIRECT')!.components['障碍匹配'], 1);
      expect(result.scoreFor('DIRECT')!.total, greaterThan(0.8));
      expect(result.scoreFor('VAGUE')!.total,
          lessThan(result.scoreFor('DIRECT')!.total));
    });

    test('prescription contains one observable action, stop rules and evidence',
        () {
      final input = _input(hasTime: false, hasTools: false);
      final diagnosis = diagnoser.diagnose(input);
      final lens = _lens(
        id: 'DIRECT',
        barriers: const <ZxBarrier>[ZxBarrier.physicalOpportunity],
      );
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

      expect(action, isNotNull);
      expect(generator.validate(action!), isEmpty);
      expect(action.stopConditions, isNotEmpty);
      expect(action.proofOptions, isNotEmpty);
      expect(action.evidenceLocators, isNotEmpty);
      expect(action.mainAction, contains('完成一个最小动作'));
      expect(action.mainAction, isNot(contains('一定成功')));
    });

    test('chosen primary thought shapes the action and fusion stays supportive',
        () {
      final input = _input();
      final diagnosis = diagnoser.diagnose(input);
      final primary = _lens(id: 'PRIMARY');
      final complementary = _lens(id: 'COMPLEMENT', sourceId: 'B');
      final match = ZxMatchResult(
        primary: primary,
        complementary: complementary,
        ranking: const <ZxFitScore>[],
        lowMatch: false,
        lowMatchReason: '',
        uncertainty: 0.2,
        conflictNotes: const <String>[],
      );

      final action = generator.generate(
        input: input,
        diagnosis: diagnosis,
        match: match,
      )!;

      expect(action.mainAction, contains('采用PRIMARY'));
      expect(action.mainAction, contains('完成一个最小动作'));
      expect(action.supportChanges.join(' '), contains('互补采用COMPLEMENT'));
      expect(action.complementaryLensId, 'COMPLEMENT');
    });
  });

  group('reward, tree and challenge rules', () {
    const diagnoser = ZxBehaviourDiagnoser();
    const matcher = ZxThinkerMatcher();
    const generator = ZxActionGenerator();
    const rewards = ZxRewardEngine();
    const trees = ZxTreeEngine();

    late ZxActionPrescription action;

    setUp(() {
      final input = _input();
      final diagnosis = diagnoser.diagnose(input);
      final lens = _lens(
        id: 'ACTION',
        barriers: <ZxBarrier>[diagnosis.primary.barrier],
      );
      final match = matcher.match(
        input: input,
        diagnosis: diagnosis,
        lenses: <ZxThinkerLens>[lens],
      );
      action = generator.generate(
        input: input,
        diagnosis: diagnosis,
        match: match,
        selectedDifficulty: ZxDifficulty.l2,
      )!;
    });

    test('completion and learning rewards are separate and daily-capped', () {
      const review = ZxReviewInput(
        completion: ZxCompletionStatus.completed,
        learning: ZxLearningStatus.strong,
        proofType: ZxProofType.processTrace,
        whatHappened: '完成了动作',
        hypothesisUpdate: '机会比动力更关键',
        difficultyFit: '合适',
        consequences: '可以继续',
        nextDecision: '修改',
        nextAction: '预先准备入口',
        reflectionDepth: 5,
      );
      final normal = rewards.calculate(
        action: action,
        review: review,
        sameActionRewardedCount: 0,
        sameDifficultyCountToday: 0,
        coinsEarnedToday: 0,
      );
      final capped = rewards.calculate(
        action: action,
        review: review,
        sameActionRewardedCount: 0,
        sameDifficultyCountToday: 0,
        coinsEarnedToday: 59,
      );

      expect(normal.completionCoins, greaterThan(0));
      expect(normal.learningCoins, greaterThan(0));
      expect(capped.totalCoins, 1);
      expect(capped.dailyCapApplied, isTrue);
    });

    test('repetition reduces novelty but never below 0.7', () {
      const review = ZxReviewInput(
        completion: ZxCompletionStatus.completed,
        learning: ZxLearningStatus.none,
        proofType: ZxProofType.selfReport,
        whatHappened: '',
        hypothesisUpdate: '',
        difficultyFit: '合适',
        consequences: '',
        nextDecision: '',
        nextAction: '',
      );
      final repeated = rewards.calculate(
        action: action,
        review: review,
        sameActionRewardedCount: 20,
        sameDifficultyCountToday: 0,
        coinsEarnedToday: 0,
      );
      expect(repeated.noveltyFactor, 0.7);
    });

    test('tree vitality is geometric and coins cannot purchase XP', () {
      const state = ZxTreeState(
        water: 100,
        sunlight: 25,
        fertilizer: 25,
        coins: 20,
        abilityXp: <String, double>{
          '选择力': 3,
          '启动力': 4,
          '持续力': 5,
          '修正力': 6,
          '贡献力': 7,
        },
      );
      final result = trees.exchange(state, 'sunlight');

      expect(state.vitality, closeTo(39.685, 0.01));
      expect(result.state.abilityXp, state.abilityXp);
      expect(result.state.coins, 15);
    });

    test('dormancy is recoverable and does not delete growth', () {
      final now = DateTime(2026, 7, 29).millisecondsSinceEpoch;
      const growth = 42.0;
      final dormant = trees.refreshTemporalState(
        ZxTreeState(
          growth: growth,
          lastActivityMs:
              now - const Duration(days: 15).inMilliseconds,
        ),
        nowMs: now,
      );
      final revived = trees.revive(dormant, nowMs: now);

      expect(dormant.dormant, isTrue);
      expect(revived.dormant, isFalse);
      expect(revived.growth, growth);
    });

    test('garden contains 10 dimensions x 5 difficulties', () {
      final all = const ZxChallengeFactory().buildAll();
      expect(all, hasLength(50));
      expect(all.map((item) => item.dimension).toSet(), hasLength(10));
      expect(
        all.where((item) => item.difficulty == ZxDifficulty.l4)
            .every((item) => item.risk == ZxRiskLevel.r2),
        isTrue,
      );
    });
  });
}

ZxSituationInput _input({
  bool acuteDanger = false,
  bool professionalDecision = false,
  bool hasTime = true,
  bool hasTools = true,
  int availableMinutes = 15,
  double bodyCapacity = 0.7,
  double attentionCapacity = 0.7,
  double sleepCapacity = 0.7,
  String valueReason = '这对我的成长很重要',
}) =>
    ZxSituationInput(
      goalTitle: '完成学习任务',
      recentEvent: '昨晚在书桌前打开手机后没有开始',
      targetBehavior: '打开文档并写一个段落',
      valueReason: valueReason,
      thought: '我可能做不好',
      emotion: '焦虑',
      urge: '刷手机',
      actualAction: '回避',
      availableMinutes: availableMinutes,
      bodyCapacity: bodyCapacity,
      attentionCapacity: attentionCapacity,
      sleepCapacity: sleepCapacity,
      hasTime: hasTime,
      hasTools: hasTools,
      acuteDanger: acuteDanger,
      professionalDecision: professionalDecision,
    );

ZxThinkerLens _lens({
  required String id,
  String sourceId = 'A',
  List<ZxBarrier> barriers = const <ZxBarrier>[
    ZxBarrier.automaticMotivation,
  ],
  List<ZxStage> stages = const <ZxStage>[
    ZxStage.s0,
    ZxStage.s1,
    ZxStage.s2,
    ZxStage.s3,
    ZxStage.s4,
    ZxStage.s5,
  ],
  List<ZxDifficulty> difficulties = const <ZxDifficulty>[
    ZxDifficulty.l0,
    ZxDifficulty.l1,
    ZxDifficulty.l2,
    ZxDifficulty.l3,
  ],
  List<String> methods = const <String>['行为', '环境'],
  double evidenceDirectness = 0.9,
}) =>
    ZxThinkerLens(
      id: id,
      sourceId: sourceId,
      thinker: id,
      name: '测试镜头',
      coreQuestion: '当前真正的障碍是什么？',
      mechanism: '用情境机制解释并设计可求证行动。',
      bestFit: '低风险具体情境',
      nonFit: '即时危险',
      prerequisites: '目标行为已定义',
      contraindications: 'R3/R4',
      barriers: barriers,
      stages: stages,
      difficulties: difficulties,
      methods: methods,
      actionTemplates: const <String>['完成一个最小动作'],
      tensionLinks: const <String>['同时检查机会与动机。'],
      evidenceLinks: const <String>['TEST-P0001-B001'],
      evidenceDirectness: evidenceDirectness,
      reviewStatus: 'approved',
    );
