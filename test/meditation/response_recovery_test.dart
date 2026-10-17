import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';
import 'package:quote_app/meditation_module/meditation_mentor_guidance.dart';
import 'package:quote_app/services/unified_ai_service.dart';

import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, recommendation;
import 'depth_fixtures.dart';

// The visible design fields match the reported shape. The screenshot does not
// include the complete script, so these segments are representative fixtures.
Map<String, dynamic> cognitiveChangeScript() {
  const phases = [
    'arrival',
    'breath',
    'body_emotion',
    'allow_experience',
    'embodied_shift',
    'real_life_rehearsal',
    'integration',
    'closing',
  ];
  const texts = [
    '先选择一个身体有支撑的坐姿，脚底可以落在地面，背部也可以靠住。今天，我们尝试在念头与行动之间，留出一点可感的空间。你可以保持睁眼，或随时换个姿势；不需要坐得很正确。先留意手掌与桌面接触的这一小片地方。',
    '接下来，跟随两轮自然呼吸，不要求更深，也不要求更慢。留意身体自行起伏的感觉。如果这个入口不舒服，也可以听周围的声音，或把注意力放到脚底的支撑。走神时，轻轻回到这个真实触点就可以。',
    '留意手掌下方平实的触感，以及手指有没有正在用力。再邀请自己留意此刻的情绪：可能紧绷、平静，也可能难以命名。一次只停在你愿意观察的一处；暂时没有明显感觉，也可以先知道自己坐在这里。',
    '允许一个轻微的念头暂时存在，不用赶走它，也不需要立刻照着它行动。这里不保证情绪立刻放松，感受仍然可以保持原样。你可以选择只听声音，给这个反应一点地方，然后继续留意身体实际发生了什么。',
    '如果愿意，把一个念头看作放在面前纸上的几行字。留意纸面上柔和的光影，再留意手掌接触桌面的平实触感。字可以留在那里，你的手指可以选择少用一点力。停留之后，留意念头与行动之间这一点空间，身体或情绪有没有反应。',
    '如果稍后收到一条消息，试试先感受脚底，再决定怎样回应。念头可以出现，手掌也可以先停留一小会儿；回应仍由你选择。不需要排练一场很困难的对话，只把这一个小动作放进普通的日常片刻。',
    '现在问问自己：手掌的用力、身体的触点或情绪，有没有一点实际变化？没有变化也可以如实知道。今天如果愿意，可以把这一个停留带进下一步；没有答案时，也可以先休息。不必把练习变成一次考核。',
    '最后，再感受脚底或座面的支撑。眼睛如果闭着，可以温和睁开，看向周围一个普通物体。让目光慢慢辨认它的轮廓，再选择继续休息或做一个很小的动作。你已经完成这次尝试，不需要先产生某种感觉。',
  ];
  const starts = [0, 40, 105, 160, 225, 320, 390, 455];
  final script = <String, dynamic>{
    'experience_design': {
      'input_anchor': '认知转变',
      'theme': '让认知转变成为念头与行动之间可感的一点空间',
      'sensory_cues': ['纸面上的柔和光影', '手掌接触桌面的平实触感'],
      'body_invitation': '选择感受手掌、脚底或座面的支撑，也可以轻轻松开手指',
      'emotional_permission': '可以是紧绷、平静、难以命名，也可以没有明显变化',
      'felt_check': '停留后观察触点、身体用力或情绪有没有细微变化；没有变化也如实知道',
    },
    'understood_need': '在念头出现时多出一点选择，让身体也参与这一步。',
    'cognitive_shift': '从念头出现就照着做，转向知道念头与选择行动之间可以留空间。',
    'embodied_goal': '通过真实触点和手指少用一点力，留意身体与情绪反应。',
    'real_life_scene': '收到一条普通消息，先停留，再决定回应。',
    'title': '让念头与行动之间多一点空间',
    'type': '认知转变体验',
    'duration_minutes': 8,
    'segments': List.generate(
        phases.length,
        (i) => {
              'phase': phases[i],
              'start_seconds': starts[i],
              'text': texts[i],
            }),
    'ending_reflection': '没有变化也能完成这次练习。',
  };
  script['depth_evidence'] = depthEvidence(script['segments'] as List);
  return script;
}

class UnavailableAi extends FakeAi {
  UnavailableAi() : super([]);

  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'existing-app-provider',
          apiKey: '',
          model: '',
          endpoint: 'https://unused.invalid',
          label: 'test',
          displayModel: 'test',
          available: false);
}

class StorageFailureDao extends FakeDao {
  @override
  Future<int> insertAiOutput(
          {required String feature,
          String? inputJson,
          required String outputText,
          String? parsedJson,
          String? provider,
          String? model,
          bool success = true,
          String? errorMessage}) async =>
      throw StateError('diagnostic storage unavailable');
}

Future<MeditationAiGenerationResult?> generate(FakeAi ai, FakeDao dao,
        {int minutes = 8}) =>
    MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao)
        .generateDailyMeditation(
            currentState: '日常练习',
            recommended: recommendation,
            recentRecords: [],
            durationMinutes: minutes,
            userDescription: '认知转变');

void main() {
  test('八分钟八阶段正文被保留并排成可播放短段，不因格式建议整份丢弃', () async {
    final script = cognitiveChangeScript();
    final raw = jsonEncode(script);
    final ai = FakeAi([raw, raw]);
    final dao = FakeDao();
    final result =
        await MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao)
            .generateDailyMeditation(
                currentState: '日常练习',
                recommended: recommendation,
                recentRecords: [],
                durationMinutes: 8,
                userDescription: '认知转变');
    expect(result, isNotNull,
        reason: '${dao.outputs.map((output) => output['error']).toList()}');
    expect(result!.session.durationSeconds, 480);
    final sourceText =
        (script['segments'] as List).map((s) => s['text']).join();
    expect(
        result.session.steps
            .map((s) => s.text)
            .join()
            .replaceAll(RegExp(r'\s'), ''),
        sourceText.replaceAll(RegExp(r'\s'), ''));
    expect(result.session.steps.every((s) => s.pauseAfterSeconds >= 4), isTrue);
    expect(ai.calls, hasLength(1));
  });

  test('日志响应中的 JSON 字符串解码后可被识别', () async {
    final content = jsonEncode(jsonEncode(cognitiveChangeScript()));
    final response = jsonEncode({
      'choices': [
        {
          'message': {'content': content}
        }
      ]
    });
    final returned = UnifiedAiService.extractText(response);
    final ai = FakeAi([returned, returned]);
    final dao = FakeDao();
    final result =
        await MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao)
            .generateDailyMeditation(
                currentState: '日常练习',
                recommended: recommendation,
                recentRecords: [],
                durationMinutes: 8,
                userDescription: '认知转变');
    expect(result, isNotNull,
        reason: '${dao.outputs.map((output) => output['error']).toList()}');
    expect(ai.calls, hasLength(1));
  });

  test('带围栏的 JSON、字符串秒数和缺失时间轴能归一，缺少分析附注也可播放', () async {
    final script = cognitiveChangeScript()
      ..remove('cognitive_shift')
      ..remove('real_life_scene')
      ..remove('duration_minutes');
    for (final s in script['segments'] as List) {
      s.remove('start_seconds');
      s['pause_after_seconds'] = '8秒';
    }
    final ai = FakeAi(['这里是引导：\n```json\n${jsonEncode(script)}\n```']);
    final result = await generate(ai, FakeDao());
    expect(result, isNotNull);
    expect(result!.session.steps.first.startSecond, 0);
    for (var i = 0; i < result.session.steps.length; i++) {
      final s = result.session.steps[i];
      final end = i + 1 < result.session.steps.length
          ? result.session.steps[i + 1].startSecond
          : 480;
      expect(
          end - s.startSecond,
          greaterThanOrEqualTo(MeditationMentorGuidance.speechSeconds(s.text) +
              s.pauseAfterSeconds));
    }
    expect(ai.calls, hasLength(1));
  });

  test('完整结构的八阶段短句不会为了凑推荐段数而重写', () async {
    final script = cognitiveChangeScript();
    const shortTexts = [
      '先选择身体有支撑的坐姿，留意脚底。今天尝试在念头与行动之间，留出一点可感的空间。你可以随时睁眼或换姿势。',
      '跟随两轮自然呼吸，不要求更深或更慢。走神时，轻轻回来；也可以听周围声音，留意脚底的支撑，停留在这个真实触点。',
      '留意手掌与桌面的触感，以及手指有没有用力。再留意情绪此刻的反应，可能紧绷、平静，也可能暂时没有明显感觉。',
      '允许一个念头暂时存在，不用赶走它。认知转变也可以是先不照着念头行动，给身体和情绪一点空间，再选择怎样回应。',
      '把念头看作纸上的字，留意光影和手掌触感。手指可以少用一点力；停留后，观察念头与行动之间的空间和身体反应。',
      '如果稍后收到一条消息，可以先感受脚底，再决定怎样回应。手掌可以先停留一会儿，不需要排练困难的对话，只尝试这一个动作。',
      '现在问问自己，身体用力或情绪有没有一点变化。没有变化也可以如实知道；如果愿意，把这一点停留带进今天下一步，也可以休息。',
      '最后，感受脚底或座面的支撑。眼睛如果闭着，可以温和睁开，看向周围一个普通物体，辨认它的轮廓，再选择继续休息。',
    ];
    final segments = script['segments'] as List;
    for (var i = 0; i < segments.length; i++) {
      segments[i]['text'] = shortTexts[i];
      segments[i]['pause_after_seconds'] = 8;
    }
    script['depth_evidence'] = depthEvidence(segments);
    final ai = FakeAi([jsonEncode(script)]);
    final result = await generate(ai, FakeDao());
    expect(result, isNotNull);
    expect(result!.session.steps, hasLength(8));
    expect(ai.calls, hasLength(1));
  });

  test('无法读取的截断 JSON 保留原响应，仅请求一次且如实说明未自动重写', () async {
    final full = jsonEncode(cognitiveChangeScript());
    final raw = full.substring(0, full.length - 40);
    final ai = FakeAi([raw]);
    final dao = FakeDao();
    await expectLater(
        generate(ai, dao),
        throwsA(isA<MeditationGenerationException>()
            .having(
                (e) => e.kind, 'kind', MeditationGenerationFailureKind.format)
            .having((e) => e.userMessage, 'message', contains('未自动重写'))));
    expect(ai.calls, hasLength(1));
    expect(dao.outputs.single['raw'], raw);
    expect(dao.outputs.single['success'], isFalse);
  });

  test('缺少体验设计附注时，保留正文并记录非阻断建议', () async {
    final script = cognitiveChangeScript()..remove('experience_design');
    final raw = jsonEncode(script);
    final ai = FakeAi([raw]);
    final dao = FakeDao();
    final result = await generate(ai, dao);
    expect(result, isNotNull);
    expect(ai.calls, hasLength(1));
    expect(dao.outputs.single['raw'], raw);
    expect(dao.outputs.single['success'], isTrue);
    expect((dao.outputs.single['input'] as Map)['quality_repair_requested'],
        isFalse);
    expect((dao.outputs.single['input'] as Map)['content_advisories'].join(),
        contains('experience_design'));
  });

  test('只有元数据而没有正文时呈现可读的失败，不自动再请求', () async {
    final ai = FakeAi(['{"title":"主题设计","experience_design":{}}']);
    final dao = FakeDao();
    await expectLater(
        generate(ai, dao),
        throwsA(isA<MeditationGenerationException>().having(
            (e) => e.kind, 'kind', MeditationGenerationFailureKind.format)));
    expect(ai.calls, hasLength(1));
    expect(
        dao.outputs.single['raw'], '{"title":"主题设计","experience_design":{}}');
  });

  test('空响应与没有可用模型分别说明，不混入质量失败', () async {
    await expectLater(
        generate(FakeAi(['']), FakeDao()),
        throwsA(isA<MeditationGenerationException>().having((e) => e.kind,
            'kind', MeditationGenerationFailureKind.emptyResponse)));
    final unavailable = UnavailableAi();
    await expectLater(
        generate(unavailable, FakeDao()),
        throwsA(isA<MeditationGenerationException>().having((e) => e.kind,
            'kind', MeditationGenerationFailureKind.configuration)));
    expect(unavailable.calls, isEmpty);
  });

  test('诊断保存失败不吞掉已经可用的 AI 引导', () async {
    final result = await generate(
        FakeAi([jsonEncode(cognitiveChangeScript())]), StorageFailureDao());
    expect(result, isNotNull);
    expect(result!.session.title, cognitiveChangeScript()['title']);
  });

  test('用户原话中的两字主题锚点可用，不强求四字或反复逐字复述', () async {
    final script = cognitiveChangeScript();
    (script['experience_design'] as Map)['input_anchor'] = '转变';
    final ai = FakeAi([jsonEncode(script)]);
    final result = await generate(ai, FakeDao());
    expect(result, isNotNull);
    expect(ai.calls, hasLength(1));
  });

  test('正文超过一分钟预算时直接保留完整版本，不额外请求精简', () async {
    final raw = jsonEncode(cognitiveChangeScript());
    final dao = FakeDao();
    final ai = FakeAi([raw, raw]);
    final result = await generate(ai, dao, minutes: 1);
    expect(result!.targetDurationSeconds, 60);
    expect(result.session.durationSeconds, greaterThan(60));
    expect(ai.calls, hasLength(1));
    final input = dao.outputs.single['input'] as Map;
    expect(input['duration_repair_requested'], isFalse);
    expect(input['duration_plan']['complete_version_offered'], isTrue);
    expect(input['quality_issues'], isEmpty);
    expect(dao.outputs.single['raw'], raw);
  });

  test('真实感官模式中的“不需要想象”不会被当作想象任务', () async {
    final script = cognitiveChangeScript();
    (script['segments'] as List)[4]['text'] =
        '不需要想象。看向真实纸面的光影，留意手掌的触感。认知转变可以是留意念头与行动之间的空间；再观察身体反应。';
    script['depth_evidence'] = depthEvidence(script['segments'] as List);
    final ai = FakeAi([jsonEncode(script)]);
    final result = await MeditationAiService(
            ai: ai, settings: FakeSettings(), dao: FakeDao())
        .generateDailyMeditation(
            currentState: '日常练习',
            recommended: recommendation,
            recentRecords: [],
            durationMinutes: 8,
            userDescription: '认知转变',
            preferences:
                const MeditationExpertPreferences(imageryPreference: '真实感官'));
    expect(result, isNotNull);
    expect(ai.calls, hasLength(1));
  });
}
