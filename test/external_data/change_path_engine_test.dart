import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/change_path_engine.dart';
import 'package:quote_app/external_data/change_path_models.dart';

void main() {
  const engine = ChangePathEngine();

  test('difficulty is classified into comfort stretch and panic zones', () {
    expect(engine.classifyZone(2), 'comfort');
    expect(engine.classifyZone(4), 'stretch');
    expect(engine.classifyZone(6), 'stretch');
    expect(engine.classifyZone(9), 'panic');
  });

  test('panic-zone action is diagnosed and downgraded', () {
    final diagnosis = engine.diagnoseResistance(
      action: '今晚连续学习四小时并完成全部课程',
      difficulty: 9,
      obstacle: '担心做不好，所以一直没有开始',
      hasTime: true,
    );
    expect(diagnosis.type, '行动太大');
    expect(diagnosis.adjustment, contains('4-6'));

    const card = ChangePathActionCard(
      cardId: 'card',
      goalId: 'goal',
      stepId: 'step',
      sourceTaskId: 'task',
      sourceListId: 'list',
      changeGoal: '更稳定地学习',
      oldPattern: '任务一大就回避',
      preservedValue: '成长',
      resistanceType: '行动太大',
      action: '连续学习四小时',
      difficulty: 9,
      zone: 'panic',
      completionStandard: '学习四小时',
      failurePlan: '记录阻力',
      actionMeaning: '练习开始',
      reviewQuestion: '证明了什么',
      status: 'ready',
      createdAtMs: 1,
    );
    expect(engine.downgradedAction(card), contains('5 分钟'));
  });

  test('missing trigger is treated as design data instead of weak willpower', () {
    final diagnosis = engine.diagnoseResistance(
      action: '打开文档写三个标题',
      difficulty: 5,
      obstacle: '',
      hasTime: false,
    );
    expect(diagnosis.type, '时间不明确');
    expect(diagnosis.adjustment, contains('触发器'));
  });
}
