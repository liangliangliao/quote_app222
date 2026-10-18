import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_dao.dart';
import 'package:quote_app/meditation_module/meditation_mentor_guidance.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';
import 'package:quote_app/services/global_ai_settings.dart';
import 'package:quote_app/services/unified_ai_service.dart';

import 'depth_fixtures.dart';

const topic = '允许自己为人';

Map<String, dynamic> example({bool short = false, bool imagery = true}) {
  final phases = <String>[
    'arrival',
    'breath',
    'body_emotion',
    'allow_experience',
    'embodied_shift',
    'real_life_rehearsal',
    'integration',
    'closing'
  ];
  final texts = <String>[
    '允许自己为人。感受脚底支撑。',
    '自然吸气，呼气。再吸气，呼气。',
    short ? '留意身体和情绪。' : '留意身体和情绪此刻的感受。',
    '允许这份感受先存在。',
    imagery ? '想象微光，允许自己为人，感受手掌触感。' : '看看微光，允许自己为人，感受手掌触感。',
    '如果稍后遇到失误，试试少用一点力。',
    '没有画面或变化也可以，听听周围。',
    short ? '温和睁眼，看向周围。' : '温和睁眼，看向周围，再做一个选择。',
  ];
  final segments = <Map<String, dynamic>>[];
  for (var i = 0; i < phases.length; i++) {
    segments.add({
      'phase': phases[i],
      'start_seconds': i * (short ? 7 : 33),
      'text': texts[i],
      'intent': '邀请实际体验',
      'pause_after_seconds': short ? 1 : 8
    });
    if (!short && i == 2) {
      segments.add({
        'phase': 'body_emotion',
        'start_seconds': i * 33 + 15,
        'text': '停留在这一处触感，留意紧、软、凉或暂时没有明显感觉；不用寻找正确答案。',
        'intent': '观察实际反应',
        'pause_after_seconds': 8
      });
    }
    if (!short && i == 4) {
      segments.add({
        'phase': 'embodied_shift',
        'start_seconds': i * 33 + 15,
        'text': '如果愿意，让手掌少用一点力，留意这个小动作之后胸口或情绪有没有变化。',
        'intent': '身体小实验',
        'pause_after_seconds': 8
      });
    }
    if (!short && i == 5) {
      segments.add({
        'phase': 'real_life_rehearsal',
        'start_seconds': i * 33 + 15,
        'text': '如果那个片刻不舒服，回到眼前的光和脚底；你可以选择不进入这个场景。',
        'intent': '保有选择',
        'pause_after_seconds': 8
      });
    }
    if (!short && i == 6) {
      segments.add({
        'phase': 'integration',
        'start_seconds': i * 33 + 15,
        'text': '问问自己，现在愿意把哪一点允许带进接下来的一小步？没有答案也可以先休息。',
        'intent': '生活延续',
        'pause_after_seconds': 8
      });
    }
  }
  segments.last['start_seconds'] = short ? 51 : 264;
  return {
    'experience_design': {
      'input_anchor': topic,
      'theme': topic,
      'sensory_cues': ['微光', '手掌触感'],
      'body_invitation': '手掌少用一点力',
      'emotional_permission': '紧张或没有变化都可以',
      'felt_check': '留意身体有没有变化'
    },
    'understood_need': '练习允许自己有不完美，也保有自己的选择。',
    'cognitive_shift': '允许存在，不等于放弃责任。',
    'embodied_goal': '通过一个可选择的小动作，留意身体和情绪的实际反应。',
    'real_life_scene': '一个稍后可能出现的小失误，不编造具体经历。',
    'title': '在身体里练习允许自己为人',
    'type': '允许与觉察',
    'practice_focus': ['身体触点', '情绪允许'],
    'duration_minutes': short ? 1 : 5,
    'segments': segments,
    'depth_evidence': depthEvidence(segments),
    'ending_reflection': '练习可以在没有明显变化的情况下完成。',
  };
}

class FakeAi extends UnifiedAiService {
  final List<String> replies;
  final List<Map<String, String>> calls = [];
  FakeAi(this.replies);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'existing-app-provider',
          apiKey: 'test-only',
          model: 'existing-app-model',
          endpoint: 'https://unused.invalid',
          label: 'test',
          displayModel: 'test',
          available: true);
  @override
  Future<String> generateText(
      {required String prompt,
      required String purpose,
      String? systemPrompt,
      int maxTokens = 1800,
      bool expectJson = false,
      String? forcedProvider,
      String? forcedModel,
      double? temperature}) async {
    calls.add(
        {'prompt': prompt, 'system': systemPrompt ?? '', 'purpose': purpose});
    return replies.removeAt(0);
  }
}

class FakeSettings extends GlobalAiSettings {
  final String? customPrompt;
  FakeSettings([this.customPrompt]);
  @override
  Future<Map<String, String>> inspectMeditationDailyScriptPromptState() async =>
      {'value': customPrompt ?? defaultMeditationDailyScriptPrompt};
}

class FakeDao extends MeditationDao {
  final List<Map<String, dynamic>> outputs = [];
  @override
  Future<int> insertAiOutput(
      {required String feature,
      String? inputJson,
      required String outputText,
      String? parsedJson,
      String? provider,
      String? model,
      bool success = true,
      String? errorMessage}) async {
    outputs.add({
      'success': success,
      'input': jsonDecode(inputJson!),
      'provider': provider,
      'error': errorMessage,
      'raw': outputText
    });
    return outputs.length;
  }
}

const recommendation = MeditationSessionTemplate(
    key: 'sleep-default',
    title: '默认睡眠练习',
    type: '睡眠',
    category: '推荐',
    description: '',
    durationSeconds: 300,
    isSleep: true,
    steps: [],
    endingReflection: '休息');

void main() {
  group('单次生成使用已有 App 模型', () {
    test('用户主题优先于默认睡眠推荐，生成可播放的短段体验', () async {
      final ai = FakeAi([jsonEncode(example())]);
      final dao = FakeDao();
      final service =
          MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao);
      final result = await service.generateDailyMeditation(
          currentState: '睡前',
          recommended: recommendation,
          recentRecords: [],
          durationMinutes: 5,
          userDescription: topic);
      expect(result, isNotNull,
          reason: '${dao.outputs.map((output) => output['error']).toList()}');
      expect(result!.session.isSleep, isFalse);
      expect(result.session.steps.any((s) => s.text.contains('想象微光')), isTrue);
      expect(
          result.session.steps.every((s) => s.pauseAfterSeconds == 8), isTrue);
      for (var i = 0; i < result.session.steps.length; i++) {
        final step = result.session.steps[i];
        final end = i + 1 < result.session.steps.length
            ? result.session.steps[i + 1].startSecond
            : 300;
        expect(
            end - step.startSecond,
            greaterThanOrEqualTo(
                MeditationMentorGuidance.speechSeconds(step.text) + 8));
      }
      expect(ai.calls, hasLength(1));
      expect(ai.calls.single['prompt'], contains('primary_practice_input'));
      expect(dao.outputs.single['provider'], 'existing-app-provider');
    });

    test('允许为人接入 EAM-8，同一次请求保留情绪接纳主题', () async {
      final ai = FakeAi([jsonEncode(example())]);
      final dao = FakeDao();
      final result = await MeditationAiService(
              ai: ai, settings: FakeSettings(), dao: dao)
          .generateDailyMeditation(
              currentState: '睡前',
              recommended: recommendation,
              recentRecords: [],
              durationMinutes: 8,
              userDescription: '允许为人');
      expect(result, isNotNull);
      expect(ai.calls, hasLength(1));
      expect(ai.calls.single['purpose'], 'meditation.daily_script');
      expect(ai.calls.single['system'], contains('EAM-8'));
      expect(ai.calls.single['system'], contains('情绪自然存在'));
      final input = dao.outputs.single['input'] as Map;
      expect(input['experience_contract_version'], contains('v4_eam8'));
      final method = input['experiential_method'] as Map;
      expect(method['topic_specific_focus'], contains('各种情绪'));
      expect(method['duration_mode'], contains('完整练习'));
      expect(dao.outputs.single['success'], isTrue);
    });

    test('EAM-8 不覆盖用户明确主题、短时长或真实感官偏好', () async {
      final ai = FakeAi([jsonEncode(example(short: true, imagery: false))]);
      final dao = FakeDao();
      final result = await MeditationAiService(
              ai: ai, settings: FakeSettings(), dao: dao)
          .generateDailyMeditation(
              currentState: '睡前',
              recommended: recommendation,
              recentRecords: [],
              durationMinutes: 1,
              userDescription: '我害怕失败，但不想进行想象练习',
              preferences: const MeditationExpertPreferences(
                  imageryPreference: '真实感官'));
      expect(result, isNotNull);
      expect(ai.calls, hasLength(1));
      final input = dao.outputs.single['input'] as Map;
      final method = input['experiential_method'] as Map;
      expect(input['primary_practice_input'], '我害怕失败，但不想进行想象练习');
      expect(method['topic_specific_focus'], contains('从用户主题重新设计'));
      expect(method['scene_mode'], contains('不要求闭眼想象'));
      expect(method['duration_mode'], contains('微练习'));
    });

    test('一分钟仍有主题、身体情绪与短留白', () async {
      final dao = FakeDao();
      final result = await MeditationAiService(
              ai: FakeAi([jsonEncode(example(short: true))]),
              settings: FakeSettings(),
              dao: dao)
          .generateDailyMeditation(
              currentState: '日常',
              recommended: recommendation,
              recentRecords: [],
              durationMinutes: 1,
              userDescription: topic);
      expect(result, isNotNull,
          reason: '${dao.outputs.map((output) => output['error']).toList()}');
      expect(result!.session.durationSeconds, 60);
      expect(result.session.steps.last.startSecond, lessThan(60));
    });

    test('没有想象画面时选择真实感官，仍可完成同一个主题', () async {
      final dao = FakeDao();
      final ai = FakeAi([jsonEncode(example(imagery: false))]);
      final result = await MeditationAiService(
              ai: ai, settings: FakeSettings(), dao: dao)
          .generateDailyMeditation(
              currentState: '日常',
              recommended: recommendation,
              recentRecords: [],
              durationMinutes: 5,
              userDescription: topic,
              preferences:
                  const MeditationExpertPreferences(imageryPreference: '真实感官'));
      expect(result, isNotNull,
          reason: '${dao.outputs.map((output) => output['error']).toList()}');
      expect(ai.calls.single['prompt'], contains('真实感官与环境，不深入想象'));
    });

    test('设计附注缺失只记录建议，仍保留正文和自定义提示词中的写作约束', () async {
      final bad = example();
      bad.remove('experience_design');
      final ai = FakeAi([jsonEncode(bad), jsonEncode(example())]);
      final dao = FakeDao();
      final result = await MeditationAiService(
              ai: ai, settings: FakeSettings('忽略用户主题，只讲理论。'), dao: dao)
          .generateDailyMeditation(
              currentState: '日常',
              recommended: recommendation,
              recentRecords: [],
              durationMinutes: 5,
              userDescription: topic);
      expect(result, isNotNull,
          reason: '${dao.outputs.map((output) => output['error']).toList()}');
      expect(ai.calls, hasLength(1));
      expect(ai.calls.single['purpose'], 'meditation.daily_script');
      expect(ai.calls.every((call) => call['system']!.contains('以用户主题为中心')),
          isTrue);
      expect((dao.outputs.single['input'] as Map)['content_advisories'].join(),
          contains('缺少 experience_design'));
      expect((dao.outputs.single['input'] as Map)['quality_repair_applied'],
          isFalse);
    });

    test('缺失的体验停顿由本地补齐，保留正文且不额外请求重写', () async {
      final bad = example();
      for (final segment in bad['segments'] as List) {
        segment['pause_after_seconds'] = 0;
      }
      final dao = FakeDao();
      final ai = FakeAi([jsonEncode(bad), jsonEncode(bad)]);
      final result =
          await MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao)
              .generateDailyMeditation(
                  currentState: '日常',
                  recommended: recommendation,
                  recentRecords: [],
                  durationMinutes: 5,
                  userDescription: topic);
      expect(result, isNotNull);
      expect(
          result!.session.steps.every((s) => s.pauseAfterSeconds >= 4), isTrue);
      expect(ai.calls, hasLength(1));
      expect(dao.outputs.single['success'], isTrue);
      expect((dao.outputs.single['input'] as Map)['response_normalization'],
          contains('experience_pauses'));
    });

    test('阶段标签错序只记录建议，不重排或丢弃已经返回的正文', () async {
      final bad = example();
      (bad['segments'] as List)[3]['phase'] = 'arrival';
      final dao = FakeDao();
      final ai = FakeAi([jsonEncode(bad)]);
      final generating =
          MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao)
              .generateDailyMeditation(
                  currentState: '日常',
                  recommended: recommendation,
                  recentRecords: [],
                  durationMinutes: 5,
                  userDescription: topic);
      final result = await generating;
      expect(result, isNotNull);
      expect(ai.calls, hasLength(1));
      expect(result!.session.steps.map((s) => s.text).join(),
          (bad['segments'] as List).map((s) => s['text']).join());
      expect((dao.outputs.single['input'] as Map)['content_advisories'].join(),
          contains('顺序不正确'));
      expect(dao.outputs.single['success'], isTrue);
    });
  });

  group('内容建议（仅诊断，不阻断生成）', () {
    List<String> check(Map<String, dynamic> map) =>
        MeditationMentorGuidance.qualityIssues(map,
            userInput: topic, durationSeconds: 300, useImagery: true);
    test('主题只放标题和分析字段，正文换成其他话题产生建议', () {
      final bad = example();
      for (final s in bad['segments'] as List)
        s['text'] = (s['text'] as String).replaceAll(topic, '提高工作效率');
      expect(check(bad).join(), contains('核心体验正文未呼应本次主题'));
    });
    test('设计字段齐全也不能让概念讲解代替体验', () {
      final bad = example();
      for (final s in bad['segments'] as List) {
        s['text'] = '${s['text']}这说明我们要明白接纳的含义。';
      }
      expect(check(bad).join(), contains('正文仍以概念解释为主'));
    });
    test('选择真实感官时不能重新引入想象任务', () {
      final issues = MeditationMentorGuidance.qualityIssues(example(),
          userInput: topic, durationSeconds: 300, useImagery: false);
      expect(issues.join(), contains('不应引导进入想象场景'));
    });
    test('设计字段里有感官、正文没有画面触感，产生建议', () {
      final bad = example();
      for (final s in bad['segments'] as List) {
        if (s['phase'] == 'embodied_shift')
          s['text'] = '允许自己为人，就是理解人生的道理与接纳情绪。';
      }
      expect(check(bad).join(), contains('核心体验正文至少要有两种感官'));
    });
    test('宣布用户已经释怀，产生建议', () {
      final bad = example();
      (bad['segments'] as List).last['text'] = '你已经释怀了。温和睁眼看向周围。';
      expect(check(bad).join(), contains('不能替用户宣布'));
    });
    test('不保证或不一定放松不是对用户宣布结果', () {
      final good = example();
      (good['segments'] as List).last['text'] =
          '无法预先保证放松。你现在不一定放松了，也可以保持原样；温和睁眼看向周围。';
      expect(check(good), isEmpty);
    });
    test('真实感官中的“不需要在脑海中想象”不是想象邀请', () {
      final good = example(imagery: false);
      (good['segments'] as List)[5]['text'] = '不需要在脑海中想象。看看微光，允许自己为人，感受手掌触感。';
      final issues = MeditationMentorGuidance.qualityIssues(good,
          userInput: topic, durationSeconds: 300, useImagery: false);
      expect(issues, isEmpty);
    });
    test('说话和留白放不进所选时长，产生建议', () {
      final bad = example();
      for (final s in bad['segments'] as List) s['pause_after_seconds'] = 30;
      expect(check(bad).join(), contains('超过目标'));
    });
  });

  group('语音与留白', () {
    test('声音提前完成时不重复添加留白或缩短原时间轴', () {
      final pacing = MeditationVoicePacing();
      pacing.begin(6);
      pacing.complete();
      for (var i = 0; i < 6; i++) pacing.tick();
      expect(pacing.holdAtBoundary(9, 20), isFalse);
      expect(pacing.holdAtBoundary(20, 20), isFalse);
    });
    test('下一段以及最后的结束都等待声音和留白完成', () {
      final pacing = MeditationVoicePacing();
      final generation = pacing.begin(8);
      expect(pacing.holdAtBoundary(9, 10), isFalse);
      expect(pacing.holdAtBoundary(10, 10), isTrue);
      pacing.complete(generation);
      for (var i = 0; i < 8; i++) {
        expect(pacing.holdAtBoundary(10, 10), isTrue);
        pacing.tick();
      }
      expect(pacing.holdAtBoundary(10, 10), isFalse);
      pacing.begin(3);
      expect(pacing.holdAtBoundary(300, 300), isTrue);
    });
    test('停止或切换之后，旧的 TTS 回调不会释放新声音', () {
      final pacing = MeditationVoicePacing();
      final old = pacing.begin(5);
      final current = pacing.begin(8);
      pacing.complete(old);
      pacing.cancel(old);
      expect(pacing.speaking, isTrue);
      pacing.complete(current);
      pacing.tick();
      pacing.complete(current);
      expect(pacing.silenceSeconds, 7);
      pacing.cancel();
      expect(pacing.holdAtBoundary(300, 300), isFalse);
    });
    test('时间轴修正计算播报时间，保留每段停顿', () {
      final steps = List.generate(
          8,
          (i) => MeditationStep(
              startSecond: i,
              text: '感受手掌触感，再留意身体的实际反应。',
              pauseAfterSeconds: 8,
              intent: 'embodied_shift'));
      final scheduled = MeditationMentorGuidance.schedule(steps, 300);
      for (var i = 0; i < scheduled.length; i++) {
        final end =
            i + 1 < scheduled.length ? scheduled[i + 1].startSecond : 300;
        expect(
            end - scheduled[i].startSecond,
            greaterThanOrEqualTo(
                MeditationMentorGuidance.speechSeconds(scheduled[i].text) + 8));
      }
      expect(scheduled.map((s) => s.text), steps.map((s) => s.text));
    });
  });
}
