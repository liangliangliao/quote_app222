import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/domain/motivation_profile.dart';
import 'package:quote_app/beautiful_enemy/src/domain/motivation_stimulus.dart';

void main() {
  group('MotivationProfile', () {
    test('冷启动画像只是一组温和先验，直接挑战最高但不垄断', () {
      expect(MotivationProfile.defaultPrior(StimulusStyle.challenge), 4);
      expect(MotivationProfile.defaultPrior(StimulusStyle.integrity), 3);
      expect(MotivationProfile.defaultPrior(StimulusStyle.mirror), 2);
      expect(MotivationProfile.defaultPrior(StimulusStyle.competition), 2);
      expect(MotivationProfile.defaultPrior(StimulusStyle.provocation), 2);
    });

    test('问卷把 1..5 映射到 -4..4，并覆盖默认先验', () {
      final Map<String, int> priors = MotivationProfile.priorsFromAnswers(
        <String, int>{
          'q_mirror': 5,
          'q_integrity': 1,
          'q_challenge': 4,
          'q_competition': 2,
          'q_provocation': 5,
          'q_pressure_tolerance': 1,
        },
      );

      expect(priors[StimulusStyle.mirror], 4);
      expect(priors[StimulusStyle.integrity], -4);
      // challenge 同时受到 q_challenge(+2) 和压力耐受(-4)影响，平均为 -1。
      expect(priors[StimulusStyle.challenge], -1);
      // provocation 同时受到 +4 和 -4，得到 0，而不是盲目认为挑衅有效。
      expect(priors[StimulusStyle.provocation], 0);
      expect(priors[StimulusStyle.competition], -2);
    });

    test('没有回答的维度保留默认值，不把未知误当成零', () {
      final Map<String, int> priors = MotivationProfile.priorsFromAnswers(
        <String, int>{'q_mirror': 5},
      );
      expect(priors[StimulusStyle.mirror], 4);
      expect(
        priors[StimulusStyle.challenge],
        MotivationProfile.defaultPrior(StimulusStyle.challenge),
      );
    });

    test('真实经验可以反转默认先验', () {
      expect(
        MotivationProfile.effectiveScore(prior: 4, learned: -8),
        -4,
      );
      expect(
        MotivationProfile.effectiveScore(prior: 2, learned: 8),
        10,
      );
    });

    test('情境记忆只做局部修正，不会无限放大单一场景', () {
      expect(
        MotivationProfile.contextAdjustedScore(
          globalScore: 6,
          contextBias: 3,
        ),
        9,
      );
      expect(
        MotivationProfile.contextAdjustedScore(
          globalScore: 6,
          contextBias: 99,
        ),
        10,
      );
      expect(
        MotivationProfile.contextAdjustedScore(
          globalScore: -6,
          contextBias: -99,
        ),
        -10,
      );
    });

    test('置信度明确区分默认、问卷和真实行为样本', () {
      expect(
        MotivationProfile.confidenceLabel(0, questionnaireDone: false),
        contains('冷启动'),
      );
      expect(
        MotivationProfile.confidenceLabel(0, questionnaireDone: true),
        contains('问卷'),
      );
      expect(
        MotivationProfile.confidenceLabel(6, questionnaireDone: true),
        contains('行为校准'),
      );
      expect(
        MotivationProfile.confidenceLabel(15, questionnaireDone: true),
        contains('真实行动'),
      );
    });
  });
}
