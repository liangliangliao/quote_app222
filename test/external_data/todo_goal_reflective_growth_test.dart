import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/todo_goal_models.dart';

void main() {
  test('reflection maps structured Reflective Growth evidence', () {
    final reflection = TodoGoalReflection.fromMap(<String, Object?>{
      'reflection_id': 'r1',
      'goal_id': 'g1',
      'step_id': 's1',
      'reflection_date': '2026-06-09',
      'what_done': '在项目会上提出了不同意见',
      'why_done': '练习真实表达',
      'process_experience': '紧张，但说完后更放松',
      'obstacle': '担心被否定',
      'tomorrow_next_step': '再表达一个真实偏好',
      'ai_summary': '一次真实行动',
      'mood_score': 4,
      'meaning_score': 5,
      'process_score': 4,
      'created_at_ms': 1,
      'body_signal': '肩膀紧',
      'emotion_label': '焦虑',
      'cognition': '不同意见会破坏关系',
      'authentic_truth': '我其实不同意当前方案',
      'feedback_source': '同事',
      'feedback_content': '希望观点更具体',
      'feedback_learning': '下次补充一个例子',
      'core_pattern': '回避冲突',
      'core_value': '真实',
      'action_experiment': '说一句不同角度',
      'action_when': '明天项目会',
      'action_evidence': '会议纪要里有我的观点',
      'follow_up_question': '结果真的像担心的那么糟吗？',
      'review_mode': 'feedback',
    });

    expect(reflection.bodySignal, '肩膀紧');
    expect(reflection.emotionLabel, '焦虑');
    expect(reflection.feedbackLearning, '下次补充一个例子');
    expect(reflection.corePattern, '回避冲突');
    expect(reflection.actionExperiment, '说一句不同角度');
    expect(reflection.reviewMode, 'feedback');
  });

  test('AI review serializes action and pattern fields', () {
    const result = TodoGoalReviewResult(
      summary: 'summary',
      processInsight: 'insight',
      meaningConnection: 'meaning',
      tomorrowNextStep: 'next',
      encouragement: 'encouragement',
      provider: 'local',
      modelLabel: 'test',
      growthPattern: '回避冲突',
      actionExperiment: '表达一个真实偏好',
      actionEvidence: '发出一条消息',
    );

    expect(result.toJson()['growthPattern'], '回避冲突');
    expect(result.toJson()['actionExperiment'], '表达一个真实偏好');
    expect(result.toJson()['actionEvidence'], '发出一条消息');
  });
}
