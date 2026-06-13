import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/todo_goal_models.dart';
import 'package:quote_app/external_data/todo_goal_will_bridge.dart';

void main() {
  const goal = TodoGoalProfile(
    goalId: 'goal-1',
    sourceType: 'microsoft_todo',
    sourceTaskId: 'task-1',
    sourceListId: 'list-1',
    goalTitle: '学习心理学',
    deepMeaning: '理解自己并建立行动方法论',
    desiredIdentity: '持续学习的人',
    goalCategory: '成长',
    goalOriginType: 'self',
    selfConcordanceScore: 88,
    processValue: '理解与探索',
    obstacleSummary: '太累了；想刷手机；担心学了没用',
    status: 'active',
    createdAtMs: 1,
    updatedAtMs: 1,
    coreValues: '长期成长、自我理解',
    valueGoal: '建立行动方法论',
  );

  const step = TodoGoalActionStep(
    stepId: 'step-1',
    goalId: 'goal-1',
    sourceTaskId: 'task-1',
    title: '阅读威廉·詹姆斯意志章节',
    minimumStandard: '打开书并读第一段',
    simplifiedStandard: '只读 5 分钟',
    recommendedStandard: '阅读 20 分钟',
    stretchStandard: '整理一页笔记',
    difficultyScore: 5,
    zoneType: 'stretch',
    plannedDate: '2026-06-13',
    plannedTime: '20:00',
    status: 'not_started',
    completedAtMs: 0,
    writeBackToTodo: false,
    remoteTaskId: '',
    createdAtMs: 1,
    updatedAtMs: 1,
    actionPlace: '书桌前',
    startTrigger: '晚饭后',
  );

  test('uses a stable Todo goal/action identity', () {
    expect(TodoGoalWillBridge.ideaIdFor('goal-1', 'step-1'), 'todo_goal_will_goal-1_step-1');
    expect(TodoGoalWillBridge.ideaIdFor('goal-1', null), 'todo_goal_will_goal-1_goal');
  });

  test('projects goal value and action tree into a concrete will card', () {
    final idea = TodoGoalWillBridge().project(goal: goal, step: step);

    expect(idea.coreValue, '长期成长、自我理解');
    expect(idea.actionIdea, step.title);
    expect(idea.minimumAction, step.minimumStandard);
    expect(idea.fiveMinuteVersion, step.simplifiedStandard);
    expect(idea.firstBodyAction, contains('书桌前'));
    expect(idea.firstBodyAction, contains('晚饭后'));
    expect(idea.obstacleIdeas, contains('想刷手机'));
    expect(idea.competitionItems.map((item) => item.type), containsAll(<String>['行动观念', '阻碍观念', '价值观念']));
    expect(idea.attentionAnchor, contains('不重新审判整个目标'));
  });
}
