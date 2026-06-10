import 'todo_failure_growth_models.dart';
import 'todo_goal_models.dart';
import 'todo_raisebase_models.dart';

class TodoRaiseBaseEngine {
  const TodoRaiseBaseEngine();

  TodoRaiseBaseBeliefMap buildBeliefMap({
    required TodoGoalProfile goal,
    required String limitingBelief,
    String realityEvidence = '',
  }) {
    final belief = limitingBelief.trim().isEmpty ? '我还没有足够把握，所以很难开始。' : limitingBelief.trim();
    final evidence = realityEvidence.trim().isEmpty ? goal.obstacleSummary.trim() : realityEvidence.trim();
    final absolute = RegExp(r'永远|一定|完全|根本|注定|都不|不可能|没资格|就是不行').hasMatch(belief);
    final exaggerated = absolute
        ? '这个解释把当前困难扩大成了永久、普遍或人格结论；事实只支持“现在有困难”，不支持“永远不可能”。'
        : '这个判断可能把不确定性当成了结论。需要区分已知事实、尚未验证的预测和可以通过行动获得的新证据。';
    final action = goal.processGoal.trim().isNotEmpty
        ? '先做 5–15 分钟版本：${goal.processGoal.trim()}'
        : '先做 5–15 分钟版本：围绕“${goal.goalTitle}”产出一个可见的小结果。';
    return TodoRaiseBaseBeliefMap(
      mapId: '',
      goalId: goal.goalId,
      goalTitle: goal.goalTitle,
      limitingBelief: belief,
      realityEvidence: evidence.isEmpty ? '目前信息不足，先把事实与预测分开记录。' : evidence,
      exaggeratedPart: exaggerated,
      alternativeBelief: '我不需要假装它容易；我可以通过一个小实验增加信息、能力和成功概率。',
      minimumAction: action,
      controllableFactor: '今天可控的是投入一小段时间、完成一个具体输出，并观察反馈。',
      environmentCue: '清空一个工作平面，把手机移远，只保留完成这一步所需的工具。',
      obstaclePlan: '如果开始时想逃避，就只做 5 分钟；5 分钟后允许停止，但必须留下一个可见痕迹。',
      createdAtMs: 0,
    );
  }

  TodoRaiseBaseSnapshot buildSnapshot({
    required List<TodoGoalActionStep> steps,
    required List<TodoGoalReflection> reflections,
    required List<TodoFailureGrowthLoop> failures,
    required List<TodoRaiseBaseCheckIn> checkIns,
  }) {
    final completed = steps.where((step) => step.isCompleted).length;
    final reviewedFailures = failures.where((loop) => loop.isCompleted).length;
    final mood = checkIns.isEmpty ? _average(reflections.map((e) => e.moodScore)) : _average(checkIns.map((e) => e.moodScore));
    final copingRecorded = checkIns.isEmpty ? 0 : _average(checkIns.map((e) => e.copingScore));
    final efficacyRecorded = checkIns.isEmpty ? 0 : _average(checkIns.map((e) => e.selfEfficacyScore));
    final coping = (copingRecorded + completed * 8 + reviewedFailures * 12).clamp(0, 100).toInt();
    final efficacy = (efficacyRecorded + completed * 7 + reflections.length * 4 + reviewedFailures * 8).clamp(0, 100).toInt();
    final evidence = <String>[
      ...steps.where((e) => e.isCompleted).take(4).map((e) => '即使不确定，你仍完成了：${e.title}'),
      ...failures.where((e) => e.isCompleted).take(3).map((e) => '你把“${e.eventText}”转成了下一版行动'),
      ...checkIns.where((e) => e.evidenceText.trim().isNotEmpty).take(3).map((e) => e.evidenceText.trim()),
    ];
    return TodoRaiseBaseSnapshot(
      moodBaseline: mood,
      copingIndex: coping,
      selfEfficacy: efficacy,
      completedActions: completed,
      failureReflections: reviewedFailures,
      evidence: evidence,
    );
  }

  int _average(Iterable<int> values) {
    final valid = values.where((value) => value > 0).toList();
    if (valid.isEmpty) return 0;
    return (valid.reduce((a, b) => a + b) / valid.length * (valid.any((e) => e <= 5) ? 20 : 1)).round().clamp(0, 100).toInt();
  }
}
