import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/meditation_module/meditation_ai_service.dart';
import 'package:quote_app/meditation_module/meditation_experiential_method.dart';
import 'package:quote_app/meditation_module/meditation_narration_guide.dart';

import 'experiential_mentor_test.dart'
    show FakeAi, FakeDao, FakeSettings, recommendation;

Map<String, dynamic> reference() => jsonDecode(
    File('test/meditation/fixtures/multidimensional_allow_human.json')
        .readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> brief(
        {int minutes = 8,
        bool imagery = true,
        bool grounding = false,
        String input = '允许自己为人'}) =>
    MeditationExperientialMethod.buildBrief(
        userInput: input,
        durationMinutes: minutes,
        useImagery: imagery,
        isSleep: false,
        prioritizeGrounding: grounding);

void main() {
  test('1到30分钟行程总预算一致，长练习给三个时间片刻实际展开空间', () {
    for (final minutes in [1, 2, 3, 5, 8, 15, 30]) {
      final plan = brief(minutes: minutes)['narration_blueprint'] as List;
      final total = plan.fold<int>(
          0, (n, u) => n + (u['budget_seconds_including_silence'] as int));
      expect(total, minutes * 60);
      expect(
          plan.every((u) => u['budget_seconds_including_silence'] > 0), isTrue);
      final episodes = plan
          .where((u) =>
              ['yesterday', 'day_before_yesterday', 'future'].contains(u['id']))
          .toList();
      expect(episodes, hasLength(3));
      if (minutes >= 5) {
        expect(episodes.every((u) => u['suggested_segments'] >= 3), isTrue);
        expect(
            episodes.fold<int>(0,
                (n, u) => n + (u['budget_seconds_including_silence'] as int)),
            greaterThan(minutes * 60 ~/ 3));
      }
    }
  });

  test('低刺激和用户边界删除不允许的行程，预算重新分配', () {
    for (final b in [brief(grounding: true), brief(input: '不想回忆过去，也不要预演未来')]) {
      final plan = b['narration_blueprint'] as List;
      expect(plan.map((u) => u['id']), isNot(contains('yesterday')));
      expect(plan.map((u) => u['id']), isNot(contains('future')));
      expect(
          plan.fold<int>(
              0, (n, u) => n + (u['budget_seconds_including_silence'] as int)),
          480);
    }
    final real = brief(imagery: false)['narration_blueprint'] as List;
    expect(real.singleWhere((u) => u['id'] == 'yesterday')['invitation'],
        contains('不要求回放'));
  });

  test('所有维度都写在附注，只有一句时间词的正文仍暴露缺少的邀请', () {
    final hollow = reference();
    hollow['experience_design'] = {
      'time_exploration': '昨天、前天、未来都充分展开',
      'space_exploration': '练习了距离与位置',
      'imagery_participation': '主动想象并参与',
      'body_invitation': '放松了全身',
    };
    hollow['segments'] = [
      {'text': '允许自己为人，回想昨天，想想前天，想象明天。'},
      {'text': '你已经很好了，一切都会变好。'},
      {'text': '现在回到呼吸。'},
    ];
    final gaps = MeditationNarrationGuide.missingInvitations(hollow,
        brief: brief(), minutes: 8);
    expect(
        gaps,
        containsAll([
          '昨天片刻的进入、参与与观察',
          '前天片刻的进入、参与与观察',
          '未来情景中的具体回应预演',
          '近远与位置的空间觉察',
          '真实身体感受与放松尝试',
        ]));
  });

  test('人工完整示例有可见邀请，删除时间段或放松段会留下对应缺口', () {
    final full = reference();
    expect(
        MeditationNarrationGuide.missingInvitations(full,
            brief: brief(), minutes: 8),
        isEmpty);
    final removed = reference();
    (removed['segments'] as List).removeWhere((s) =>
        s['unit'] == 'day_before_yesterday' || s['unit'] == 'body_release');
    final gaps = MeditationNarrationGuide.missingInvitations(removed,
        brief: brief(), minutes: 8);
    expect(gaps, contains('前天片刻的进入、参与与观察'));
    // Merely mentioning 前天 in the return/closing is not a complete episode.
    expect(gaps, contains('真实身体感受与放松尝试'));
  });

  test('真实感官和低刺激不因没有想象场景产生错误提醒', () {
    final script = {
      'segments': [
        {'text': '情绪可以存在，你仍可选择回应。'},
        {'text': '先听近处的声音，再听稍远处，感觉身体在这里的位置。'},
        {'text': '感受手指，愿意的话少用一点力。'},
        {'text': '现在回到真实身体与周围的声音。'},
      ]
    };
    for (final b in [brief(imagery: false), brief(grounding: true)]) {
      expect(
          MeditationNarrationGuide.missingInvitations(script,
              brief: b, minutes: 8),
          isEmpty);
    }
  });

  test('生成只发一套主规则，行程进入请求，正文保留且缺口如实返回', () async {
    for (final script in [
      reference(),
      {
        'segments': [
          {'text': '允许自己为人。先自然呼吸，再回到当下。'}
        ]
      }
    ]) {
      final ai = FakeAi([jsonEncode(script)]);
      final dao = FakeDao();
      final result = await MeditationAiService(
              ai: ai, dao: dao, settings: FakeSettings('使用温暖语气。'))
          .generateDailyMeditation(
              currentState: '日常',
              recommended: recommendation,
              recentRecords: [],
              durationMinutes: 10,
              userDescription: '允许自己为人');
      expect(ai.calls, hasLength(1));
      expect(ai.calls.single['system'], MeditationNarrationGuide.systemPrompt);
      expect(ai.calls.single['prompt'], contains('narration_blueprint'));
      expect(result, isNotNull);
      final logged =
          (dao.outputs.single['input'] as Map)['narration_review'] as Map;
      expect(logged['missing_invitations'], result!.practiceGaps);
      if (script['title'] != null) {
        expect(result.practiceGaps, isEmpty);
      } else {
        expect(result.practiceGaps, contains('前天片刻的进入、参与与观察'));
        expect(result.session.steps.single.text, '允许自己为人。先自然呼吸，再回到当下。');
      }
    }
  });
}
