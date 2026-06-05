import 'package:flutter_test/flutter_test.dart';
import 'package:project_fixed_20260307_v10_goal_module_phase39_world_navigation_chain/will_module/will_dashboard_support.dart';
import 'package:project_fixed_20260307_v10_goal_module_phase39_world_navigation_chain/will_module/will_models.dart';

void main() {
  test('trainingTypeForTaskTitle maps known tasks', () {
    expect(trainingTypeForTaskTitle('10 秒起步'), '启动型');
    expect(trainingTypeForTaskTitle('30 秒注意锁定'), '注意锁定型');
    expect(trainingTypeForTaskTitle('90 秒延迟诱惑'), '抗诱惑型');
    expect(trainingTypeForTaskTitle('晚间意志复盘'), '复盘型');
  });

  test('defaultUnitIdsForTask returns non-empty unit ids', () {
    expect(defaultUnitIdsForTask('10 秒起步'), isNotEmpty);
    expect(defaultUnitIdsForTask('30 秒注意锁定'), contains('R-003'));
  });

  test('progress helpers compute expected values', () {
    const checkpoints = [
      StageCheckpoint(label: 'a', done: true),
      StageCheckpoint(label: 'b', done: false),
      StageCheckpoint(label: 'c', done: true),
    ];
    expect(progressSummary(checkpoints), '2 / 3 条已完成');
    expect(progressValue(checkpoints), closeTo(2 / 3, 0.0001));
  });

  test('currentTrainingStreak counts consecutive active days', () {
    final now = DateTime.now();
    int atDaysAgo(int n) => DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: n))
        .millisecondsSinceEpoch;

    final executions = [
      WillTaskExecutionEntry(id: 1, taskTitle: '10 秒起步', note: '', effortLevel: 2, completedAtMs: atDaysAgo(0)),
      WillTaskExecutionEntry(id: 2, taskTitle: '10 秒起步', note: '', effortLevel: 2, completedAtMs: atDaysAgo(1)),
      WillTaskExecutionEntry(id: 3, taskTitle: '10 秒起步', note: '', effortLevel: 2, completedAtMs: atDaysAgo(2)),
    ];

    expect(
      currentTrainingStreak(executions: executions, reviews: const [], zones: const []),
      3,
    );
  });
}
