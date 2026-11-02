import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_experiential_method.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';

import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, example, recommendation;
import 'returned_content_test.dart' show expectPlayable;

void main() {
  Future<Map<String, dynamic>> request({
    String topic = '我担心一次失误说明自己没有能力',
    int minutes = 5,
    MeditationExpertPreferences preferences =
        const MeditationExpertPreferences(),
    String? customPrompt,
  }) async {
    final ai = FakeAi([jsonEncode(example())]);
    final dao = FakeDao();
    final result = await MeditationAiService(
      ai: ai,
      dao: dao,
      settings: FakeSettings(customPrompt),
    ).generateDailyMeditation(
      currentState: '日常',
      recommended: recommendation,
      recentRecords: [],
      durationMinutes: minutes,
      userDescription: topic,
      preferences: preferences,
    );
    expect(result, isNotNull);
    expect(ai.calls, hasLength(1));
    expect(dao.outputs.single['provider'], 'existing-app-provider');
    final input = dao.outputs.single['input'] as Map<String, dynamic>;
    expect(input['primary_practice_input'], topic);
    expect(input['quality_repair_requested'], isFalse);
    final sent =
        jsonDecode(ai.calls.single['prompt']!.split('【结构化输入，必要时请优先参考】\n').last)
            as Map;
    expect(sent['experiential_method'], input['experiential_method']);
    expect(
      ai.calls.single['system'],
      contains(MeditationExperientialMethod.systemRules),
    );
    return input;
  }

  Map timePlan(Map input) =>
      input['experiential_method']['practice_dimensions']['time'] as Map;

  test('默认和已保存自定义提示都带上多维体验设计，复用一次模型请求', () async {
    for (final custom in [null, '请使用我习惯的简短语气。']) {
      final input = await request(customPrompt: custom);
      final method = input['experiential_method'] as Map;
      expect(method['version'], MeditationExperientialMethod.version);
      expect(
        (method['practice_dimensions'] as Map).keys,
        containsAll([
          'cognition',
          'time',
          'space',
          'imagination',
          'body',
          'present_return',
        ]),
      );
      expect(timePlan(input)['anchors'], [
        'present',
        'yesterday',
        'day_before_yesterday',
        'future',
        'present',
      ]);
      expect(timePlan(input)['past_mode'], 'gentle_recollection');
      expect(timePlan(input)['future_mode'], 'possible_scene');
      expect(input['generation_mode'], 'single_request');
    }
  });

  test('1–2分钟仍将时间与空间传给导师，不在本地裁掉正文', () async {
    for (final minutes in [1, 2]) {
      final input = await request(minutes: minutes);
      expect(input['duration_minutes'], minutes);
      expect(
        timePlan(input)['anchors'],
        containsAll(['yesterday', 'day_before_yesterday', 'future']),
      );
      expect(input['experiential_method']['duration_mode'], contains('微练习'));
    }
  });

  test('真实感官偏好以时间区分替代回放与预演', () async {
    final input = await request(
      preferences: const MeditationExpertPreferences(imageryPreference: '真实感官'),
    );
    expect(timePlan(input)['past_mode'], 'time_orientation');
    expect(timePlan(input)['future_mode'], 'time_orientation');
    expect(input['imagery_mode'], '真实感官与环境，不深入想象');
  });

  test('用户原话明确拒绝想象时，优先于默认温和画面偏好', () async {
    for (final topic in [
      '我想练习接纳，不想进行想象练习',
      '允许自己为人，不要让我想象或闭眼',
      '我担心明天，不想闭眼或想象',
      '我想放松，但不想象',
    ]) {
      final input = await request(topic: topic);
      expect(input['imagery_mode'], '真实感官与环境，不深入想象', reason: topic);
      expect(timePlan(input)['past_mode'], 'time_orientation');
      expect(timePlan(input)['future_mode'], 'time_orientation');
    }
  });

  test('拒绝过去或未来情景时省略对应时间，不把局部拒绝扩成禁止全部想象', () async {
    final noPast = await request(topic: '我怕失败，不想回忆过去，只想预演明天');
    expect(timePlan(noPast)['past_mode'], 'omit');
    expect(timePlan(noPast)['anchors'], ['present', 'future', 'present']);
    expect(timePlan(noPast)['future_mode'], 'possible_scene');

    final noFuture = await request(topic: '我怕失败，不要想象未来，愿意看看昨天');
    expect(timePlan(noFuture)['future_mode'], 'omit');
    expect(timePlan(noFuture)['past_mode'], 'gentle_recollection');
    expect(timePlan(noFuture)['anchors'], [
      'present',
      'yesterday',
      'day_before_yesterday',
      'present',
    ]);

    final notRefusing = await request(topic: '我不是不想回忆，也不会拒绝想象，只是需要慢一点');
    expect(timePlan(notRefusing)['past_mode'], 'gentle_recollection');
    expect(timePlan(notRefusing)['future_mode'], 'possible_scene');
  });

  test('强烈不适时只定向当下，不进入过去或未来场景', () async {
    final input = await request(topic: '我此刻很惊恐，想试着稳定一下');
    expect(input['safety_level'], 'medium');
    expect(input['imagery_mode'], '真实感官与环境，不深入想象');
    expect(timePlan(input)['past_mode'], 'omit');
    expect(timePlan(input)['future_mode'], 'omit');
    expect(timePlan(input)['anchors'], everyElement('present'));
  });

  test('睡前的未来片刻聚焦休息，结束后继续休息', () async {
    final input = await request(topic: '睡前想放下对失败的担心');
    expect(timePlan(input)['future_focus'], contains('休息'));
    expect(timePlan(input)['future_focus'], contains('不引出工作、任务'));
    expect(input['experiential_method']['closing_mode'], contains('继续休息'));
  });

  test('多维作者示例的正文、回返顺序及留白在播放转换中完整保留', () async {
    // Authored reference: this checks playback compatibility, not live model
    // quality or an individual listener's response.
    final script = jsonDecode(
      File(
        'test/meditation/fixtures/time_space_failure.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    final ai = FakeAi([jsonEncode(script)]);
    final dao = FakeDao();
    final result = await MeditationAiService(
      ai: ai,
      dao: dao,
      settings: FakeSettings(),
    ).generateDailyMeditation(
      currentState: '日常',
      recommended: recommendation,
      recentRecords: [],
      durationMinutes: 8,
      userDescription: '我担心一次失误说明自己没有能力',
    );
    final segments = script['segments'] as List;
    expect(result, isNotNull);
    expect(
      result!.session.steps.map((s) => s.text),
      segments.map((s) => s['text']),
    );
    expect(
      result.session.steps.map((s) => s.pauseAfterSeconds),
      segments.map((s) => s['pause_after_seconds']),
    );
    expectPlayable(result);
    expect(ai.calls, hasLength(1));
    expect(dao.outputs.single['success'], isTrue);
  });
}
