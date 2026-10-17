import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_duration_planner.dart';
import 'package:quote_app/meditation_module/meditation_mentor_guidance.dart';
import 'package:quote_app/meditation_module/meditation_models.dart';

import 'duration_fixtures.dart';
import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, recommendation;
import 'response_recovery_test.dart' show cognitiveChangeScript;

Future<MeditationAiGenerationResult> generateTimed(FakeAi ai, FakeDao dao,
        {int minutes = 8}) async =>
    (await MeditationAiService(ai: ai, settings: FakeSettings(), dao: dao)
        .generateDailyMeditation(
            currentState: '日常练习',
            recommended: recommendation,
            recentRecords: [],
            durationMinutes: minutes,
            userDescription: '认知转变'))!;

String narration(Map<String, dynamic> script) => (script['segments'] as List)
    .map((s) => s['text'])
    .join()
    .replaceAll(RegExp(r'\s'), '');

void expectPlayable(MeditationSessionTemplate session) {
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
  expect(session.steps.last.intent, contains('closing'));
}

void main() {
  test('569 秒对 480 秒的有效引导直接交付完整版本，原文与收束都保留', () async {
    final script = timedCognitiveChangeScript(569);
    final ai = FakeAi([jsonEncode(script)]);
    final dao = FakeDao();
    final result = await generateTimed(ai, dao);
    expect(result.targetDurationSeconds, 480);
    expect(result.session.durationSeconds, 569);
    expect(result.session.durationLabel, '9分29秒');
    expect(result.session.description, contains('目标8分钟，完整引导预计9分29秒'));
    expect(
        result.session.steps
            .map((s) => s.text)
            .join()
            .replaceAll(RegExp(r'\s'), ''),
        narration(script));
    expectPlayable(result.session);
    expect(ai.calls, hasLength(1));
    expect(dao.outputs.single['success'], isTrue);
    final input = dao.outputs.single['input'] as Map;
    expect(input['quality_issues'], isEmpty);
    expect(input['duration_repair_requested'], isFalse);
    expect(input['duration_plan']['original_minimum_seconds'], 569);
    expect(input['duration_plan']['planned_seconds'], 569);
    expect(input['duration_plan']['complete_version_offered'], isTrue);
    expect(ai.calls.single['prompt'], contains('duration_budget'));
  });

  test('569 秒中的可调整停顿能校准到 480 秒，不删正文、不再次请求模型', () async {
    final script = timedCognitiveChangeScript(420);
    final segments = script['segments'] as List;
    var extra = 149;
    while (extra > 0) {
      for (final s in segments) {
        if (extra == 0) break;
        if (s['pause_after_seconds'] >= 30) continue;
        s['pause_after_seconds']++;
        extra--;
      }
    }
    final ai = FakeAi([jsonEncode(script)]);
    final dao = FakeDao();
    final result = await generateTimed(ai, dao);
    expect(result.session.durationSeconds, 480);
    expect(result.pausesAdjusted, isTrue);
    expect(result.session.steps.map((s) => s.text).join(), narration(script));
    for (final s in result.session.steps) {
      final core = RegExp(
              r'body_emotion|allow_experience|embodied_shift|real_life_rehearsal')
          .hasMatch(s.intent!);
      expect(s.pauseAfterSeconds, greaterThanOrEqualTo(core ? 8 : 4));
    }
    expectPlayable(result.session);
    expect(ai.calls, hasLength(1));
    expect(
        (dao.outputs.single['input'] as Map)['duration_plan']
            ['original_minimum_seconds'],
        569);
  });

  test('预算充足时保留原停顿和可行时间轴，核心原有短停顿不被强行加长', () {
    const steps = [
      MeditationStep(
          startSecond: 0,
          text: '感受脚底。',
          pauseAfterSeconds: 4,
          intent: 'body_emotion'),
      MeditationStep(
          startSecond: 60,
          text: '温和睁眼。',
          pauseAfterSeconds: 10,
          intent: 'closing'),
    ];
    final plan = MeditationDurationPlanner.plan(steps, 180);
    expect(plan.durationSeconds, 180);
    expect(plan.pausesAdjusted, isFalse);
    expect(plan.steps[1].startSecond, 60);
    expect(plan.steps.first.pauseAfterSeconds, 4);
  });

  test('无法再压缩时保留身体体验的停顿，不靠加速或截断强行装入预算', () {
    final steps = List.generate(
        18,
        (i) => MeditationStep(
            startSecond: i,
            text: '留意手掌第$i处触感，再看看周围的光影。',
            pauseAfterSeconds: 8,
            intent: 'embodied_shift'));
    final plan = MeditationDurationPlanner.plan(steps, 180);
    expect(plan.durationSeconds, greaterThan(180));
    expect(plan.steps.map((s) => s.text), steps.map((s) => s.text));
    expect(plan.steps.every((s) => s.pauseAfterSeconds == 8), isTrue);
    expect(plan.pausesAdjusted, isFalse);
  });

  test('明显超时也只交付原完整版本，不花费第二次调用精简', () async {
    final script = cognitiveChangeScript();
    final raw = jsonEncode(script);
    final ai = FakeAi([raw]);
    final dao = FakeDao();
    final result = await generateTimed(ai, dao, minutes: 1);
    expect(result.targetDurationSeconds, 60);
    expect(result.session.durationSeconds, greaterThan(60));
    expect(ai.calls, hasLength(1));
    expect(
        result.session.steps
            .map((s) => s.text)
            .join()
            .replaceAll(RegExp(r'\s'), ''),
        narration(script));
    expect(dao.outputs.single['raw'], raw);
    expect(dao.outputs.single['success'], isTrue);
    expect((dao.outputs.single['input'] as Map)['duration_repair_requested'],
        isFalse);
    expectPlayable(result.session);
  });
}
