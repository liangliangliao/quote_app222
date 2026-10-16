import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/beautiful_enemy/src/domain/guard.dart';
import 'package:quote_app/beautiful_enemy/src/domain/motivation_stimulus.dart';

void main() {
  group('MotivationStimulus', () {
    test('轻度挑衅必须同时满足明确授权和强度至少 2', () {
      final Map<String, int> scores = <String, int>{
        for (final String s in StimulusStyle.all) s: 0,
        StimulusStyle.provocation: 8,
      };

      expect(
        MotivationStimulus.choose(
          intensity: 3,
          allowProvocation: false,
          scores: scores,
          seed: 0,
        ),
        isNot(StimulusStyle.provocation),
      );
      expect(
        MotivationStimulus.choose(
          intensity: 1,
          allowProvocation: true,
          scores: scores,
          seed: 0,
        ),
        isNot(StimulusStyle.provocation),
      );
      expect(
        MotivationStimulus.choose(
          intensity: 2,
          allowProvocation: true,
          scores: scores,
          seed: 0,
        ),
        StimulusStyle.provocation,
      );
    });

    test('用户反馈会学习，但分数有上下界', () {
      expect(MotivationStimulus.updatedScore(0, StimulusFeedback.fired), 2);
      expect(MotivationStimulus.updatedScore(0, StimulusFeedback.flat), -1);
      expect(MotivationStimulus.updatedScore(0, StimulusFeedback.tooMuch), -4);
      expect(MotivationStimulus.updatedScore(8, StimulusFeedback.fired), 8);
      expect(MotivationStimulus.updatedScore(-7, StimulusFeedback.tooMuch), -8);
    });

    test('历史反馈让真正点着过的方式获得优先级', () {
      final String style = MotivationStimulus.choose(
        intensity: 2,
        allowProvocation: false,
        scores: <String, int>{
          StimulusStyle.mirror: -1,
          StimulusStyle.integrity: 4,
          StimulusStyle.challenge: 1,
          StimulusStyle.competition: 2,
        },
        seed: 99,
      );
      expect(style, StimulusStyle.integrity);
    });

    test('本地刺激台词仍通过统一安全校验', () {
      const DraftValidator validator = DraftValidator();
      for (final String style in StimulusStyle.all) {
        final String line = MotivationStimulus.decorateLocal(
          base: '对手，账上过去 24 小时没有一次行动。请解释。',
          style: style,
          address: '对手',
        );
        expect(
          validator.validateLine(line, maxTone: 2),
          isEmpty,
          reason: '$style -> $line',
        );
        expect(line.length, lessThanOrEqualTo(DraftValidator.maxLineChars));
      }
    });

    test('言行一致和挑衅策略都明确把刺激收束到行动', () {
      expect(MotivationStimulus.instruction(StimulusStyle.integrity), contains('动作'));
      expect(MotivationStimulus.instruction(StimulusStyle.provocation), contains('可执行动作'));
      expect(MotivationStimulus.instruction(StimulusStyle.provocation), contains('不能持续拱火'));
    });
  });
}
