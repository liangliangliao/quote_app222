import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_agent_service.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_persistent_solver.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_rev3_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_sck_runtime.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_state_machine.dart';

void main() {
  const sck = XiangjiSckRuntime();

  group('TC-SCK / AskUserGuard', () {
    test('only Missing + HighImpact + CannotInfer may ask', () {
      const inferable = XiangjiInformationNeed(
        id: 'known-income',
        question: '收入是多少？',
        missingField: 'income',
        decisionImpact: XiangjiDecisionImpact.critical,
        canInfer: true,
        inferSourceRefs: <String>['goal:income'],
        expectedValueOfInformation: 10,
      );
      const lowImpact = XiangjiInformationNeed(
        id: 'color',
        question: '你喜欢什么颜色？',
        missingField: 'color',
        decisionImpact: XiangjiDecisionImpact.low,
        expectedValueOfInformation: 1,
      );

      expect(sck.shouldAskUser(inferable), isFalse);
      expect(sck.shouldAskUser(lowImpact), isFalse);
      expect(
        sck.evaluateAskUserGuard(const <XiangjiInformationNeed>[
          inferable,
          lowImpact,
        ]).outcome,
        XiangjiAskUserOutcome.continueAutonomous,
      );
    });

    test('reversible information gap becomes a scout, not a form', () {
      const need = XiangjiInformationNeed(
        id: 'industry-threshold',
        question: '行业真实门槛是什么？',
        missingField: 'industry_threshold',
        decisionImpact: XiangjiDecisionImpact.high,
        scoutingPossible: true,
        scoutingOption: '访谈一位从业者并做一个小项目',
        expectedValueOfInformation: 8,
        userBurden: 4,
      );
      final decision = sck.evaluateAskUserGuard(
        const <XiangjiInformationNeed>[need],
      );

      expect(decision.outcome, XiangjiAskUserOutcome.scoutInReality);
      expect(decision.scoutingNeeds.single.id, 'industry-threshold');
      expect(
        XiangjiAskUserOutcome.values.map((value) => value.wire),
        isNot(contains('ASK_FORM')),
      );
    });

    test('TC-AI-004/006 asks only the EVSI-highest single question', () {
      const first = XiangjiInformationNeed(
        id: 'deadline',
        question: '最迟何时必须决定？',
        missingField: 'deadline',
        decisionImpact: XiangjiDecisionImpact.critical,
        expectedValueOfInformation: 9,
        userBurden: 1,
      );
      const second = XiangjiInformationNeed(
        id: 'preference',
        question: '你更喜欢哪个选项？',
        missingField: 'preference',
        decisionImpact: XiangjiDecisionImpact.high,
        expectedValueOfInformation: 4,
        userBurden: 2,
      );
      final decision = sck.evaluateAskUserGuard(
        const <XiangjiInformationNeed>[second, first],
      );

      expect(decision.outcome, XiangjiAskUserOutcome.askOne);
      expect(decision.selectedNeed?.id, 'deadline');
      expect(decision.selectedNeed?.selectedForQuestion, isTrue);
    });
  });

  group('TC-AI / automatic delegation', () {
    test('an explicit new need outranks facts embedded in the same sentence', () {
      const classifier = XiangjiInputClassifier();
      final classification = classifier.classify(
        input: '我想恢复晨间写作，本周已经写了两次',
        activeProblem: const XiangjiProblemRecord(
          id: 'old-problem',
          rawQuestion: '我想辞职但害怕',
          state: XiangjiProblemState.solving,
        ),
      );

      expect(classification.type, XiangjiInputType.newProblem);
      expect(classification.updateExistingProblem, isFalse);
    });

    test('A03 judgment precedes Solver and major routes include red team', () {
      final plan = sck.orchestrationPlan(majorDecision: true);

      expect(
        plan.indexOf(XiangjiAgentId.judgmentEngine),
        lessThan(plan.indexOf(XiangjiAgentId.solver)),
      );
      expect(plan, contains(XiangjiAgentId.strategist));
      expect(plan, contains(XiangjiAgentId.redTeam));
      expect(
        plan.indexOf(XiangjiAgentId.redTeam),
        lessThan(plan.indexOf(XiangjiAgentId.chiefStrategist)),
      );
      expect(plan, contains(XiangjiAgentId.actionOfficer));
      expect(plan.last, XiangjiAgentId.antiTemplateValidator);
    });

    test('TC-AI-001/002 natural language yields a full prefilled draft', () {
      final draft = sck.buildLocalDraft('我想辞职但很害怕');
      final guard = sck.evaluateAskUserGuard(draft.informationNeeds);

      expect(draft.majorDecision, isTrue);
      expect(draft.trueProblem, isNotEmpty);
      expect(draft.targetGap, isNotEmpty);
      expect(draft.subGoals, isNotEmpty);
      expect(draft.operators.length, greaterThanOrEqualTo(2));
      expect(draft.strategyOptions.length, greaterThanOrEqualTo(2));
      expect(draft.redTeam, isNotEmpty);
      expect(draft.currentAction, isNotEmpty);
      expect(sck.operatorHasMechanism(draft), isTrue);
      expect(guard.outcome, XiangjiAskUserOutcome.scoutInReality);
    });

    test('irreversible urgent decision with no boundary asks one question', () {
      final draft = sck.buildLocalDraft('我现在必须签这个不可逆合同');
      final guard = sck.evaluateAskUserGuard(draft.informationNeeds);

      expect(guard.outcome, XiangjiAskUserOutcome.askOne);
      expect(guard.selectedNeed?.question, contains('撤回'));
    });

    test('TC-SCK-018 reality contradiction is not rewritten as support', () {
      expect(
        sck.reconcilePrediction(
          prediction: '两天内会收到回复',
          realityFeedback: '我做了，但两天后仍然没人回复',
        ),
        'contradicts',
      );
    });

    test('all eighteen SCK rules are executable kernel entries', () {
      expect(XiangjiSckRuntime.rules, hasLength(18));
      expect(XiangjiSckRuntime.rules.keys.first, 'SCK-001');
      expect(XiangjiSckRuntime.rules.keys.last, 'SCK-018');
    });

    test('TC-SCK-002 keeps observation separate from intention attribution', () {
      final draft = sck.buildLocalDraft('他看我一眼就是针对我');

      expect(draft.observedFacts, contains('他看我一眼'));
      expect(draft.userInterpretations, contains('他看我一眼就是针对我'));
      expect(draft.observedFacts, isNot(contains('他针对我')));
    });

    test('TC-SCK-003/005 compares concrete causes before abstraction', () {
      final draft = sck.buildLocalDraft(
        '我已经投了20份简历但没有收到offer。'
        '一次失败让技能增长，另一次失败却一直停滞没有进展。',
      );

      expect(draft.observedFacts.any((item) => item.contains('20份简历')), isTrue);
      expect(draft.causalHypotheses.length, greaterThanOrEqualTo(2));
      expect(
        draft.relevantDifferences.any(
          (item) => item.contains('目标相关能力') && item.contains('可复用进展'),
        ),
        isTrue,
      );
    });

    test('TC-PS-R3-01 audits the hidden premise before perseverance training', () {
      final draft = sck.buildLocalDraft('怎样更有毅力继续这份工作？');

      expect(draft.trueProblem, contains('当前工作或路线是否值得继续'));
      expect(draft.assumptions.single, contains('隐藏前提'));
    });

    test('TC-ST-R3-01 can recommend ending a low-value fight', () {
      final draft = sck.buildLocalDraft('我要继续争论，证明他错了');

      expect(draft.judgment, contains('不值得'));
      expect(draft.recommendation, contains('停止'));
      expect(
        draft.strategyOptions
            .any((option) => option['type'] == 'case_retreat'),
        isTrue,
      );
    });

    test('AI context cannot promote itself into a major user decision', () {
      final draft = sck.buildLocalDraft(
        '今天完成了15分钟写作',
        attachmentText: '上一版 AI 模型：这是长期战略，需要战略复核。',
        userSignalText: '今天完成了15分钟写作',
      );

      expect(draft.majorDecision, isFalse);
      expect(draft.informationNeeds, isEmpty);
      expect(draft.observedFacts, contains('今天完成了15分钟写作'));
    });

    test('TC-AI-010 extracts reality facts, experience and interpretation', () {
      final extraction = sck.extractRealityFeedback(
        '我发了3封邮件，但两天后仍没人回复。我胸口很紧。我觉得对方故意无视我。',
      );

      expect(extraction.facts.any((item) => item.contains('3封邮件')), isTrue);
      expect(extraction.experiences, contains('我胸口很紧'));
      expect(extraction.unexpected.any((item) => item.contains('没人回复')), isTrue);
      expect(extraction.interpretations.single, contains('故意无视'));
    });

    test('A02 causal work and A12 action compression survive merge', () {
      final merged = sck.buildLocalDraft('我不知道怎么办').mergeAgentOutputs(
        <String, Map<String, Object?>>{
          'A02': <String, Object?>{
            'causal_hypotheses': <String>['因果候选 A | 区分证据 A'],
          },
          'A12': <String, Object?>{
            'current_action': '执行唯一当前一步',
            'expected_minutes': 12,
          },
        },
      );

      expect(merged.causalHypotheses, <String>['因果候选 A | 区分证据 A']);
      expect(merged.currentAction, '执行唯一当前一步');
      expect(merged.expectedMinutes, 12);
    });

    test('TC-AI-011 high-value background route is A14 then A00', () {
      expect(
        sck.orchestrationPlan(
          majorDecision: true,
          backgroundWatch: true,
        ),
        <XiangjiAgentId>[
          XiangjiAgentId.monitor,
          XiangjiAgentId.chiefStrategist,
        ],
      );
      const monitor = XiangjiMonitorEngine();
      final alert = monitor.evaluate(
        const XiangjiMonitorInput(
          consecutivePredictionMisses: 2,
          investmentRisingWithoutResultCycles: 2,
        ),
      );
      expect(alert.state, XiangjiAlertState.orange);
      expect(alert.defaultAction, contains('战略复核'));
    });
  });

  group('SituationModel state machine', () {
    test('judgment and grounding are explicit gates', () {
      const machine = XiangjiSituationModelStateMachine();
      final blocked = machine.evaluate(
        XiangjiSituationModelState.parsed,
        XiangjiSituationModelState.judged,
        const XiangjiSituationModelTransitionContext(),
      );
      final allowed = machine.evaluate(
        XiangjiSituationModelState.parsed,
        XiangjiSituationModelState.judged,
        const XiangjiSituationModelTransitionContext(
          judgmentCompleted: true,
        ),
      );

      expect(blocked.allowed, isFalse);
      expect(allowed.allowed, isTrue);
    });

    test('new contradictory reality forces STALE first', () {
      const machine = XiangjiSituationModelStateMachine();
      final decision = machine.evaluate(
        XiangjiSituationModelState.grounded,
        XiangjiSituationModelState.framed,
        const XiangjiSituationModelTransitionContext(
          askUserGuardAllowsProgress: true,
          problemFramed: true,
          newRealityContradictsModel: true,
        ),
      );

      expect(decision.allowed, isFalse);
      expect(decision.reason, contains('STALE'));
    });
  });
}
