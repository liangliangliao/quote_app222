import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_experiential_method.dart';

void main() {
  group('EAM-8 体验设计单次生成契约', () {
    test('允许为人优先情绪流动，不擅自推定完美主义或未完成任务', () {
      final brief = MeditationExperientialMethod.buildBrief(
        userInput: '允许为人',
        durationMinutes: 8,
        useImagery: true,
        isSleep: false,
      );
      expect(brief['method'], contains('EAM-8'));
      expect(brief['topic_specific_focus'], contains('情绪'));
      expect(brief['topic_specific_focus'], contains('没做完任务'));
      expect(brief['topic_specific_focus'], contains('擅自'));
      expect(brief['duration_mode'], contains('完整练习'));
      expect(brief['scene_mode'], contains('真实感官替代'));
      expect(brief['narration_rhythm'], contains('pause_after_seconds'));
    });

    test('具体主题不预判为允许为人，保留独有体验', () {
      final brief = MeditationExperientialMethod.buildBrief(
        userInput: '我害怕失败，因为失败说明我没有能力',
        durationMinutes: 5,
        useImagery: true,
        isSleep: false,
      );
      expect(brief['topic_specific_focus'], contains('从用户主题重新设计'));
      expect(brief['design_questions'], isA<List<String>>());
      expect((brief['experience_path'] as List).length, 8);
    });

    test('短时长、真实感官和睡前练习有独立选择', () {
      final brief = MeditationExperientialMethod.buildBrief(
        userInput: '夜晚焦虑，但不想回忆过去',
        durationMinutes: 1,
        useImagery: false,
        isSleep: true,
      );
      expect(brief['duration_mode'], contains('微练习'));
      expect(brief['scene_mode'], contains('不要求闭眼想象'));
      expect(brief['closing_mode'], contains('继续休息'));
      expect(brief['theme_source'], contains('不想/不要'));
    });

    test('导师文本要求真实观察、先体验后提问、不加付费调用', () {
      expect(MeditationExperientialMethod.systemRules, contains('EAM-8'));
      expect(MeditationExperientialMethod.systemRules, contains('一至两个'));
      expect(MeditationExperientialMethod.systemRules, contains('不评判'));
      expect(MeditationExperientialMethod.systemRules, contains('不得额外触发模型请求或阻断'));
    });
  });
}
