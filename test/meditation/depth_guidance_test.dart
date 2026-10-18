import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';

import 'depth_fixtures.dart';
import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, example, recommendation, topic;

// An authored reference, not output from a live provider or evidence of an
// individual listener's emotional response.
Map<String, dynamic> humanExperience() {
  final script = example();
  const beats = [
    ('arrival', '先选一个有支撑的坐姿，留意座面托住身体。这次，把“允许自己为人”放在一个很小的片刻里，不急着成为更好的自己。'),
    ('breath', '跟随两轮自然呼吸，不要求变深。也可以听周围的声音，让注意力有一处可以回来。'),
    ('body_emotion', '如果贴近你，轻轻听一听这句话：“只有先把事情做好，我才可以停一下。”它也许熟悉，也可能与你无关。'),
    ('body_emotion', '先不改变什么。留意听到它时，手指有没有用力，身体是否想赶快行动；情绪可能不安，也可能没有明显感觉。'),
    ('allow_experience', '那份想做好的心，也许在保护认真或被认可的需要。你不必赶走它；可以先承认，这个需要对自己很重要。'),
    ('allow_experience', '如果连停一下都有些不安，给这份不安一点位置。允许感受存在，并不要求你同意每一个催促自己的判断。'),
    (
      'embodied_shift',
      '如果愿意，把一个轻微的未完成放在纸面的一处空白里，留意纸上的光影。没有画面时，就看看眼前的明暗，感受座面的触感。',
    ),
    (
      'embodied_shift',
      '只在这一轮呼气里，试着暂不补齐那一处。手指可以少用一点力，座面仍在这里；“允许自己为人”，能否先成为这一刻的小尝试？',
    ),
    (
      'embodied_shift',
      '等一等，再留意手指和身体用力。情绪有没有不同，或还是原样？如果更紧，就放下场景，睁眼看周围一个物体，也可以暂停。',
    ),
    (
      'real_life_rehearsal',
      '如果稍后又遇到一个小小未完成，想立刻纠正的冲动也许还会回来。先感受脚底，再试一句：“我可以认真，也可以承认此刻有限。”',
    ),
    (
      'integration',
      '回看开头那条规则：这一小刻的支撑，是否非得等事情全做对才有？你注意到了什么，就先保留什么；没有变化或答案，也不用替自己下结论。',
    ),
    ('closing', '感受座面和脚底，温和睁眼，看看周围的轮廓。今天愿意时，可以带走这一点停留；也可以到这里结束，继续休息。'),
  ];
  final segments = <Map<String, dynamic>>[
    for (var i = 0; i < beats.length; i++)
      {
        'phase': beats[i].$1,
        'text': beats[i].$2,
        'start_seconds': i * 35,
        'intent': '把同一主题交给身体和情绪体验',
        'pause_after_seconds': 8,
      },
  ];
  script['segments'] = segments;
  script['understood_need'] = '也许在想：能否认真生活，同时为有限的自己留一点位置。是否贴近你，可以在体验里辨认。';
  script['cognitive_shift'] = '从必须先做对才可停留，试探责任与有限是否可以并存。';
  script['depth_evidence'] = {
    ...depthEvidence(segments),
    'experiment': '只在这一轮呼气里，试着暂不补齐那一处。',
    'emotional_contact': '如果连停一下都有些不安，给这份不安一点位置。',
  };
  return script;
}

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
      contains('可感锚点 → 开放觉察 → 主题许可 → 安静停留 → 回到锚点'),
    );
    expect(ai.calls.single['system'], contains('无需输出 depth_evidence'));
    expect(progress, ['正在生成冥想引导……']);
    expect(
      (dao.outputs.single['input'] as Map)['generation_mode'],
      'single_request',
    );
    expect(
      (dao.outputs.single['input'] as Map)['mentor_template_version'],
      'permission_flow_v1',
    );
    expect(dao.outputs.single['provider'], 'existing-app-provider');
    final text = result!.session.steps.map((s) => s.text).join();
    expect(text, contains('先不改变什么'));
    expect(text, contains('试着暂不补齐那一处'));
    expect(text, contains('如果连停一下都有些不安'));
    expect(text, contains('是否非得等事情全做对才有'));
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

  test('深度附注缺失或引用不匹配不触发校对、不覆盖原正文', () async {
    for (final evidence in [
      null,
      {'meaning': '没有出现在正文的引用'},
    ]) {
      final script = humanExperience()..['depth_evidence'] = evidence;
      final raw = jsonEncode(script);
      final ai = FakeAi([raw]);
      final dao = FakeDao();
      final result = await writePractice(ai, dao);
      expect(result, isNotNull);
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
    final script = example(short: true)..remove('depth_evidence');
    final ai = FakeAi([jsonEncode(script)]);
    final result = await writePractice(ai, FakeDao(), minutes: 1);
    expect(result!.session.durationSeconds, 60);
    expect(result.session.steps.every((s) => s.pauseAfterSeconds >= 1), isTrue);
    expect(ai.calls, hasLength(1));
  });
}
