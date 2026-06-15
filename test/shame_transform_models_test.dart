import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/shame_transform/shame_transform_models.dart';

void main() {
  test('parses affect, compass, pride and exposure fields from V2 JSON', () {
    final result = ShameAiResult.fromJson(
      {
        'scene_key': 'visibilityTraining',
        'affect_analysis': {
          'original_positive_affect': ['表达', '被看见'],
          'original_desire': '表达一个真实需要',
          'blocking_point': '担心被拒绝',
          'shame_trigger': '把拒绝理解为自己不值得',
          'self_contraction': '沉默并撤回消息',
        },
        'shame_compass': {
          'primary_direction': '退缩',
          'secondary_direction': '攻击自己',
          'evidence': ['不回复', '责怪自己'],
          'short_term_function': '避免继续暴露',
          'long_term_cost': '需要无法被看见',
          'turning_action': '向安全的人表达一句',
        },
        'true_pride_record': {
          'completed_or_possible_action': '说出一个低风险需要',
          'shame_risk_endured': '被拒绝',
          'ability_reflected': '表达与承受不确定',
          'positive_affect_restored': '连接',
          'healthy_pride_sentence': '我带着紧张表达了需要',
          'false_pride_warning': '不靠比较获得价值',
        },
        'action_options': [
          {
            'name': '三级训练',
            'purpose': '向安全的人表达',
            'steps': ['说出一句真实需要'],
            'difficulty': '中',
            'shame_exposure_level': '中',
            'time_required': '5分钟',
            'evidence_after_done': '我没有完全隐藏',
          },
        ],
      },
      ShameScene.eventRecord,
    );

    expect(result.scene, ShameScene.visibilityTraining);
    expect(result.originalPositiveAffects, ['表达', '被看见']);
    expect(result.compassPrimary, '退缩');
    expect(result.healthyPrideSentence, '我带着紧张表达了需要');
    expect(result.actionOptions.single.shameExposureLevel, '中');
  });

  test('new persistence models retain V2 fields', () {
    const goal = GoalShameProfile(
      id: 'goal',
      createdAt: 1,
      goalText: '投递岗位',
      shameTriggers: '怕被拒绝',
      nonShameGoal: '投递一个匹配岗位',
      problemTreeJson: '[]',
      actionTreeJson: '[]',
      dailyAction: '修改简历10分钟',
      evidenceSentence: '我允许自己被看见',
      positiveAffect: '能力、被看见',
      shameRisks: '失败、评价',
      compassRisks: '退缩 + 攻击自己',
    );
    final restored = GoalShameProfile.fromMap(goal.toMap());
    expect(restored.positiveAffect, '能力、被看见');
    expect(restored.shameRisks, '失败、评价');
    expect(restored.compassRisks, '退缩 + 攻击自己');

    const joy = MicroJoyRecord(
      id: 'joy',
      createdAt: 2,
      moment: '晒到太阳',
      source: '散步',
      repeatAction: '午后走5分钟',
      affectBefore: 0,
      affectAfter: 2,
      shareable: true,
    );
    final restoredJoy = MicroJoyRecord.fromMap(joy.toMap());
    expect(restoredJoy.affectAfter, 2);
    expect(restoredJoy.shareable, isTrue);
  });
}
