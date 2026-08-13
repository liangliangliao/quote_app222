import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/belief_lab/belief_mentor_models.dart';
import 'package:quote_app/belief_lab/belief_mentor_policies.dart';

void main() {
  BeliefMentorBelief belief({
    BeliefMentorBeliefState state =
        BeliefMentorBeliefState.evidenceAccumulating,
    int strength = 35,
    int initialStrength = 70,
    int testingStartedAtMs = 0,
  }) => BeliefMentorBelief(
    id: 'belief-1',
    statement: '一次失败说明我不行',
    type: BeliefMentorBeliefType.failure,
    strength: strength,
    initialStrength: initialStrength,
    trigger: '提交作品',
    alternativeStatement: '一次结果只说明本次方法与条件',
    state: state,
    userConfirmed: true,
    createdAtMs: 1,
    updatedAtMs: 1,
    testingStartedAtMs: testingStartedAtMs,
  );

  test('internalized remains reachable before the shifting superset check', () {
    final now = DateTime(2026, 8, 13);
    final value = belief(
      state: BeliefMentorBeliefState.shifting,
      testingStartedAtMs: now
          .subtract(const Duration(days: 22))
          .millisecondsSinceEpoch,
    );

    expect(
      BeliefMentorTransitionPolicy.suggestedState(
        belief: value,
        completedExperiments: 10,
        evidenceCount: 10,
        distinctEvidenceDays: 8,
        now: now,
      ),
      BeliefMentorBeliefState.internalized,
    );
  });

  test('LLM output cannot skip user confirmation or behavior gates', () {
    final now = DateTime(2026, 8, 13);
    final unconfirmed = BeliefMentorBelief(
      id: 'candidate',
      statement: '候选',
      type: BeliefMentorBeliefType.action,
      strength: 80,
      initialStrength: 80,
      trigger: '',
      alternativeStatement: '替代',
      state: BeliefMentorBeliefState.discovered,
      userConfirmed: false,
      createdAtMs: 1,
      updatedAtMs: 1,
    );

    expect(
      BeliefMentorTransitionPolicy.suggestedState(
        belief: unconfirmed,
        completedExperiments: 99,
        evidenceCount: 99,
        distinctEvidenceDays: 99,
        now: now,
      ),
      BeliefMentorBeliefState.discovered,
    );
    expect(
      BeliefMentorTransitionPolicy.suggestedState(
        belief: belief(),
        completedExperiments: 0,
        evidenceCount: 99,
        distinctEvidenceDays: 99,
        now: now,
      ),
      BeliefMentorBeliefState.alternativeFormed,
    );
  });

  test('reminder policy enforces quiet hours, attention budget and dedupe', () {
    final quiet = BeliefMentorReminderPolicy.evaluate(
      type: BeliefMentorReminderType.morningPrime,
      scheduledAt: DateTime(2026, 8, 13, 23),
      quietStart: '22:00',
      quietEnd: '08:00',
      remindersEnabled: true,
      paused: false,
      needsSpace: false,
      experimentCompleted: false,
      sameTypeIgnoredCount: 0,
      psychologicalCountToday: 0,
      criticalCountToday: 0,
      alreadyDelivered: false,
      anotherInterventionWithin60Minutes: false,
    );
    expect(quiet.allowed, isFalse);
    expect(quiet.reason, '安静时段');

    final budget = BeliefMentorReminderPolicy.evaluate(
      type: BeliefMentorReminderType.evidenceCapture,
      scheduledAt: DateTime(2026, 8, 13, 12),
      quietStart: '22:00',
      quietEnd: '08:00',
      remindersEnabled: true,
      paused: false,
      needsSpace: false,
      experimentCompleted: false,
      sameTypeIgnoredCount: 0,
      psychologicalCountToday: 2,
      criticalCountToday: 0,
      alreadyDelivered: false,
      anotherInterventionWithin60Minutes: false,
    );
    expect(budget.allowed, isFalse);
    expect(budget.reason, contains('预算'));
  });

  test('high-risk language hard-overrides the normal coaching flow', () {
    final decision = BeliefMentorSafetyPolicy.assess('我不想活了，想结束生命');
    expect(decision.riskLevel, 'high');
    expect(decision.blocksNormalFlow, isTrue);
    expect(decision.message, contains('紧急'));
  });

  test(
    '3M radar detects magnification, minimization and unsupported inference',
    () {
      final patterns = BeliefMentorCognitivePatternPolicy.detect(
        '这次汇报一定会彻底失败；之前的进展不算什么，他们都肯定觉得我不行。',
      );
      expect(
        patterns,
        containsAll(<BeliefMentorCognitivePattern>[
          BeliefMentorCognitivePattern.magnification,
          BeliefMentorCognitivePattern.minimization,
          BeliefMentorCognitivePattern.unsupportedInference,
        ]),
      );
    },
  );

  test('duplicate evidence has diminishing state-transition weight', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    BeliefMentorEvidence evidence(String id, String outcome) =>
        BeliefMentorEvidence(
          id: id,
          beliefId: 'belief-1',
          experimentId: '',
          prediction: '会失败',
          action: '提交最小草稿',
          outcome: outcome,
          emotionBefore: 7,
          emotionAfter: 4,
          learning: '行动能换来信息',
          statement: '不完美仍能获得反馈',
          strength: BeliefMentorEvidenceStrength.medium,
          createdAtMs: now,
        );

    expect(
      BeliefMentorEvidencePolicy.effectiveCount(<BeliefMentorEvidence>[
        evidence('1', '得到一个修改建议'),
        evidence('2', '得到一个修改建议'),
        evidence('3', '得到一个修改建议'),
        evidence('4', '得到了完全不同的合作邀请'),
      ]),
      1,
    );
  });

  test('experiment transitions reject impossible shortcuts', () {
    expect(
      BeliefMentorExperimentTransitionPolicy.canTransition(
        BeliefMentorExperimentState.scheduled,
        BeliefMentorExperimentState.evidenceCreated,
      ),
      isFalse,
    );
    expect(
      BeliefMentorExperimentTransitionPolicy.canTransition(
        BeliefMentorExperimentState.completed,
        BeliefMentorExperimentState.reflection,
      ),
      isTrue,
    );
  });
}
