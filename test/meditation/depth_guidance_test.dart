import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';

import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, example, recommendation, topic;

// An authored reference, not output from a live provider or evidence of an
// individual listener's emotional response.
Map<String, dynamic> humanExperience() =>
    jsonDecode(File('test/meditation/fixtures/topic_bridge_allow_human.json')
        .readAsStringSync()) as Map<String, dynamic>;

Future<MeditationAiGenerationResult?> writePractice(
  FakeAi ai,
  FakeDao dao, {
  int minutes = 8,
  String userInput = topic,
  MeditationExpertPreferences preferences = const MeditationExpertPreferences(),
  void Function(String)? onProgress,
  String? customPrompt,
}) =>
    MeditationAiService(
      ai: ai,
      dao: dao,
      settings: FakeSettings(customPrompt),
    ).generateDailyMeditation(
      currentState: '睡前',
      recommended: recommendation,
      recentRecords: [],
      durationMinutes: minutes,
      userDescription: userInput,
      preferences: preferences,
      onProgress: onProgress,
    );

void main() {
  test('同一次请求完成主题理解与深度写作，复用现有配置和自定义提示', () async {
    final ai = FakeAi([jsonEncode(humanExperience())]);
    final dao = FakeDao();
    final progress = <String>[];
    final result = await writePractice(
      ai,
      dao,
      onProgress: progress.add,
      customPrompt: '请沿用我偏好的温柔表达。',
    );
    expect(result, isNotNull);
    expect(ai.calls, hasLength(1));
    expect(ai.calls.single['purpose'], 'meditation.daily_script');
    expect(ai.calls.single['prompt'], contains(topic));
    expect(ai.calls.single['prompt'], contains('请沿用我偏好的温柔表达'));
    expect(ai.calls.single['system'], contains('在本次生成中完成主题理解与正文写作'));
    expect(
      ai.calls.single['system'],
      contains('主题是什么 → 为什么重要或让人卡住 → 可以怎样尝试'),
    );
    expect(ai.calls.single['system'], contains('无需输出 depth_evidence'));
    expect(progress, ['正在生成冥想引导……']);
    expect(
      (dao.outputs.single['input'] as Map)['generation_mode'],
      'single_request',
    );
    expect(
      (dao.outputs.single['input'] as Map)['mentor_template_version'],
      'topic_to_experience_v2',
    );
    expect(dao.outputs.single['provider'], 'existing-app-provider');
    final text = result!.session.steps.map((s) => s.text).join();
    final authored = humanExperience()['segments'] as List;
    expect(text, authored.map((s) => s['text']).join());
    expect(result.session.durationSeconds, 480);
    expect(result.session.steps.map((s) => s.pauseAfterSeconds),
        authored.map((s) => s['pause_after_seconds']));
    expect(dao.outputs.single['success'], isTrue);
  });

  test('不同主题及否定边界进入同一次写作请求，不被默认推荐替换', () async {
    for (final input in [
      '允许自己为人，但不要让我想象或闭眼',
      '害怕被拒绝，但不要劝我积极点',
      '悲伤，我不想马上释怀',
      '认知转变',
    ]) {
      final ai = FakeAi([jsonEncode(example(imagery: false))]);
      final result = await writePractice(
        ai,
        FakeDao(),
        userInput: input,
        preferences: const MeditationExpertPreferences(
          imageryPreference: '真实感官',
        ),
      );
      expect(result, isNotNull);
      expect(result!.session.isSleep, isFalse);
      expect(ai.calls, hasLength(1));
      expect(ai.calls.single['prompt'], contains(input));
      expect(ai.calls.single['prompt'], contains('真实感官与环境，不深入想象'));
      expect(ai.calls.single['system'], contains('用户明确的愿望、边界和否定表达优先'));
    }
  });

  test('认知和画面摘要缺失或类型异常也不触发校对、不覆盖原正文', () async {
    for (final evidence in [
      null,
      {'meaning': '没有出现在正文的引用'},
    ]) {
      final script = humanExperience()..['depth_evidence'] = evidence;
      final design = script['experience_design'] as Map;
      if (evidence == null) {
        design.remove('conceptual_understanding');
        design.remove('imagery_bridge');
      } else {
        design['conceptual_understanding'] = 42;
        design['imagery_bridge'] = <String>[];
      }
      final raw = jsonEncode(script);
      final ai = FakeAi([raw]);
      final dao = FakeDao();
      final result = await writePractice(ai, dao);
      expect(result, isNotNull);
      expect(result!.session.steps.map((s) => s.text).join(),
          (script['segments'] as List).map((s) => s['text']).join());
      expect(ai.calls, hasLength(1));
      expect(dao.outputs.single['raw'], raw);
      expect(
        (dao.outputs.single['input'] as Map)['depth_repair_requested'],
        isFalse,
      );
      expect(dao.outputs.single['success'], isTrue);
    }
  });

  test('一分钟仍保留体验与留白，无额外设计或校对请求', () async {
    final script = {
      'segments': [
        {
          'phase': 'arrival',
          'text': '念头出现，不等于它已经是事实；熟悉的声音，有时让人急着照做。',
          'pause_after_seconds': 2
        },
        {
          'phase': 'embodied_shift',
          'text': '如果愿意，把一个普通念头放在路牌上。先读到它，再感受脚底，暂不迈步。',
          'pause_after_seconds': 3
        },
        {
          'phase': 'body_emotion',
          'text': '留意身体想动的冲动，和此刻的情绪。它们可以仍在。',
          'pause_after_seconds': 3
        },
        {
          'phase': 'integration',
          'text': '念头仍在时，你能否先停一刻，再选择下一步？看向眼前。',
          'pause_after_seconds': 2
        },
      ],
    };
    final ai = FakeAi([jsonEncode(script)]);
    final result =
        await writePractice(ai, FakeDao(), minutes: 1, userInput: '认知转变');
    expect(result!.session.durationSeconds, 60);
    expect(result.session.steps.every((s) => s.pauseAfterSeconds >= 1), isTrue);
    expect(result.session.steps.map((s) => s.text).join(),
        (script['segments'] as List).map((s) => s['text']).join());
    expect(ai.calls, hasLength(1));
  });
}
