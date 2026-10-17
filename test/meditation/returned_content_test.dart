import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';
import 'package:quote_app/meditation_module/meditation_mentor_guidance.dart';

import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, recommendation;
import 'response_recovery_test.dart' show cognitiveChangeScript;

Future<MeditationAiGenerationResult?> generate(FakeAi ai, FakeDao dao,
        {String topic = '恐惧'}) =>
    MeditationAiService(ai: ai, dao: dao, settings: FakeSettings())
        .generateDailyMeditation(
            currentState: '日常',
            recommended: recommendation,
            recentRecords: [],
            durationMinutes: 8,
            userDescription: topic);

void expectPlayable(MeditationAiGenerationResult result) {
  final session = result.session;
  expect(session.steps, isNotEmpty);
  expect(session.steps.first.startSecond, 0);
  for (var i = 0; i < session.steps.length; i++) {
    final step = session.steps[i];
    final end = i + 1 < session.steps.length
        ? session.steps[i + 1].startSecond
        : session.durationSeconds;
    expect(
        end - step.startSecond,
        greaterThanOrEqualTo(MeditationMentorGuidance.speechSeconds(step.text) +
            step.pauseAfterSeconds));
  }
}

void main() {
  test('恐惧主题的自然收束不含旧关键词时仍交付原文，只有一次模型调用', () async {
    final script = cognitiveChangeScript();
    const closing = '感受脚底的支撑，轻轻活动手指，让视线慢慢清晰。';
    (script['segments'] as List).last['text'] = closing;
    final raw = jsonEncode(script);
    final ai = FakeAi([raw]);
    final dao = FakeDao();
    final result = (await generate(ai, dao))!;
    expect(result.session.steps.last.text, closing);
    expectPlayable(result);
    expect(ai.calls, hasLength(1));
    expect(ai.calls.single['purpose'], 'meditation.daily_script');
    expect(dao.outputs.single['raw'], raw);
    expect(dao.outputs.single['success'], isTrue);
    expect(dao.outputs.single['error'], isNull);
    expect((dao.outputs.single['input'] as Map)['content_advisories'].join(),
        contains('closing 缺少对应的可体验引导'));
  });

  test('阶段数量、标签、设计附注都缺失时仍按原顺序播放有效段落', () async {
    final texts = ['先感觉鞋底与地面的接触。', '担忧可以暂时留在那里。', '轻轻活动指尖。'];
    final raw = jsonEncode({'segments': texts});
    final ai = FakeAi([raw]);
    final dao = FakeDao();
    final result = (await generate(ai, dao))!;
    expect(result.session.steps.map((s) => s.text).toList(), texts);
    expect(result.session.title, '本次冥想引导');
    expectPlayable(result);
    expect(ai.calls, hasLength(1));
    expect(dao.outputs.single['success'], isTrue);
  });

  test('混合格式保留全部可读正文，跳过空项，时间轴与停顿在本地补齐', () async {
    final raw = jsonEncode({
      'steps': [
        null,
        '',
        7,
        {'text': ''},
        {'text': null, 'content': '感觉椅子承托着你。', 'start': '-1', 'pause': '8秒'},
        {'guide': '留意此刻的声音。', 'start_seconds': 0, 'pause_after_seconds': -3},
        '让视线自然变得清晰。',
      ]
    });
    final ai = FakeAi([raw]);
    final result = (await generate(ai, FakeDao()))!;
    expect(result.session.steps.map((s) => s.text).toList(),
        ['感觉椅子承托着你。', '留意此刻的声音。', '让视线自然变得清晰。']);
    expectPlayable(result);
    expect(ai.calls, hasLength(1));
  });

  test('普通文字、文字围栏和 JSON 正文字段均能本地转成可播放引导', () async {
    const text = '恐惧可能还在。先感受双脚触地的重量。\n\n轻轻活动手指，让视线慢慢清晰。';
    for (final raw in [
      text,
      '```text\n$text\n```',
      jsonEncode(text),
      jsonEncode({'content': text})
    ]) {
      final ai = FakeAi([raw]);
      final dao = FakeDao();
      final result = (await generate(ai, dao))!;
      expect(
          result.session.steps
              .map((s) => s.text)
              .join()
              .replaceAll(RegExp(r'\s'), ''),
          text.replaceAll(RegExp(r'\s'), ''));
      expectPlayable(result);
      expect(ai.calls, hasLength(1));
      expect(dao.outputs.single['raw'], raw);
    }
  });

  test('很长的普通正文不会按推荐段数截断，也不会自动请求精简', () async {
    final text =
        List.generate(100, (i) => '第${i + 1}个片刻，留意双脚触地，允许情绪存在。').join('\n');
    final ai = FakeAi([text]);
    final result = (await generate(ai, FakeDao()))!;
    expect(
        result.session.steps
            .map((s) => s.text)
            .join()
            .replaceAll(RegExp(r'\s'), ''),
        text.replaceAll(RegExp(r'\s'), ''));
    expect(result.session.durationSeconds, greaterThan(480));
    expectPlayable(result);
    expect(ai.calls, hasLength(1));
  });

  test('真正没有可读正文或收到损坏结构时保留原响应，不自动修复', () async {
    for (final raw in [
      '{"segments":[',
      '{"segments":[null,17,{"text":false}]}',
      '{"title":"只有标题"}',
      '<html><body>Bad Gateway</body></html>'
    ]) {
      final ai = FakeAi([raw]);
      final dao = FakeDao();
      await expectLater(
          generate(ai, dao),
          throwsA(isA<MeditationGenerationException>().having(
              (e) => e.kind, 'kind', MeditationGenerationFailureKind.format)));
      expect(ai.calls, hasLength(1));
      expect(dao.outputs.single['success'], isFalse);
      expect(dao.outputs.single['raw'], raw);
    }
  });

  test('明确的立即危险输入仍先分流，不调用普通冥想生成', () async {
    final ai = FakeAi([]);
    final result = await generate(ai, FakeDao(), topic: '我现在想自杀');
    expect(result, isNull);
    expect(ai.calls, isEmpty);
  });
}
