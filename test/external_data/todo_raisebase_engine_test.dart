import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/todo_goal_models.dart';
import 'package:quote_app/external_data/todo_raisebase_engine.dart';

void main() {
  const engine = TodoRaiseBaseEngine();

  TodoGoalProfile goal() => const TodoGoalProfile(
        goalId: 'g1',
        sourceType: 'todo',
        sourceTaskId: 't1',
        sourceListId: 'l1',
        goalTitle: '准备下一次面试',
        deepMeaning: '获得职业选择权',
        desiredIdentity: '能从反馈中学习的人',
        goalCategory: '职业',
        goalOriginType: 'internal',
        selfConcordanceScore: 80,
        processValue: '练习表达',
        obstacleSummary: '项目案例准备不足',
        status: 'active',
        createdAtMs: 1,
        updatedAtMs: 1,
        processGoal: '改写一个 STAR 回答',
      );

  test('belief map separates facts from permanent identity judgment', () {
    final map = engine.buildBeliefMap(
      goal: goal(),
      limitingBelief: '我就是不行，永远不适合这个行业',
      realityEvidence: '这次面试没有通过',
    );

    expect(map.exaggeratedPart, contains('永久'));
    expect(map.alternativeBelief, contains('小实验'));
    expect(map.minimumAction, contains('改写一个 STAR 回答'));
    expect(map.obstaclePlan, contains('5 分钟'));
  });

  test('completed action becomes self efficacy evidence', () {
    const step = TodoGoalActionStep(
      stepId: 's1',
      goalId: 'g1',
      sourceTaskId: 't1',
      title: '录制一次模拟回答',
      minimumStandard: '录 1 分钟',
      recommendedStandard: '录 3 分钟',
      stretchStandard: '请人反馈',
      difficultyScore: 3,
      zoneType: 'stretch',
      plannedDate: '2026-06-10',
      plannedTime: '',
      status: 'completed',
      completedAtMs: 1,
      writeBackToTodo: false,
      remoteTaskId: '',
      createdAtMs: 1,
      updatedAtMs: 1,
    );
    final snapshot = engine.buildSnapshot(steps: const [step], reflections: const [], failures: const [], checkIns: const []);

    expect(snapshot.completedActions, 1);
    expect(snapshot.selfEfficacy, greaterThan(0));
    expect(snapshot.evidence.single, contains('录制一次模拟回答'));
  });
}
