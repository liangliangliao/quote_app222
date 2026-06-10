import 'change_path_models.dart';
import 'todo_goal_models.dart';

class ChangePathEngine {
  const ChangePathEngine();

  ChangePathActionCard buildActionCard({required TodoGoalProfile goal, required TodoGoalActionStep step, String cardId = ''}) {
    final rawDifficulty = step.difficultyScore.clamp(1, 10).toInt();
    final difficulty = rawDifficulty >= 8 ? 6 : rawDifficulty;
    final zone = classifyZone(difficulty);
    final resistance = diagnoseResistance(
      action: step.title,
      difficulty: rawDifficulty,
      obstacle: goal.obstacleSummary,
      hasTime: step.plannedTime.trim().isNotEmpty || step.startTrigger.trim().isNotEmpty,
    );
    final value = _first(goal.coreValueList, fallback: goal.valueGoal.trim().isEmpty ? '对重要生活负责' : goal.valueGoal);
    final oldPattern = goal.obstacleSummary.trim().isEmpty ? '面对重要事情时，容易停留在想法、等待状态或回避开始。' : goal.obstacleSummary.trim();
    final standard = step.minimumStandard.trim().isEmpty ? '完成一个可观察动作即可，不要求一次做完。' : step.minimumStandard.trim();
    return ChangePathActionCard(
      cardId: cardId,
      goalId: goal.goalId,
      stepId: step.stepId,
      sourceTaskId: step.sourceTaskId,
      sourceListId: step.sourceListId,
      changeGoal: goal.goalTitle,
      oldPattern: oldPattern,
      preservedValue: value,
      resistanceType: resistance.type,
      action: rawDifficulty >= 8
          ? '先做“${step.title}”的最低版本，持续 5 分钟后即可停止。'
          : step.title,
      difficulty: difficulty,
      zone: zone,
      completionStandard: standard,
      failurePlan: '如果没有完成，不把它定义为失败；记录卡住的具体时刻，再把行动缩小一档或补上明确触发时间。',
      actionMeaning: '保留“$value”，同时练习不再由旧模式自动决定下一步。',
      reviewQuestion: step.completionQuestion.trim().isEmpty ? '这次行动证明了什么？它让哪个旧信念松动了一点？' : step.completionQuestion.trim(),
      status: 'ready',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String classifyZone(int difficulty) {
    if (difficulty <= 3) return 'comfort';
    if (difficulty >= 8) return 'panic';
    return 'stretch';
  }

  ChangePathResistanceDiagnosis diagnoseResistance({required String action, required int difficulty, required String obstacle, required bool hasTime}) {
    final text = '$action $obstacle'.toLowerCase();
    if (difficulty >= 8) {
      return const ChangePathResistanceDiagnosis(type: '行动太大', explanation: '当前行动已接近恐慌区，失败概率和恢复成本都偏高。', adjustment: '把范围或时长至少减半，降到 4-6 分。');
    }
    if (!hasTime) {
      return const ChangePathResistanceDiagnosis(type: '时间不明确', explanation: '行动缺少清晰触发点，容易被“稍后再做”吞没。', adjustment: '补上具体时间，或使用“当……之后，我立刻……”的环境触发器。');
    }
    if (text.contains('完美') || text.contains('做不好') || text.contains('失败')) {
      return const ChangePathResistanceDiagnosis(type: '完美主义', explanation: '行动可能被“必须做好”绑住，启动成本因此升高。', adjustment: '把完成标准改成最低可交付版本，只训练开始与反馈。');
    }
    if (text.contains('评价') || text.contains('拒绝') || text.contains('表达') || text.contains('冲突')) {
      return const ChangePathResistanceDiagnosis(type: '害怕评价', explanation: '你可能在保护关系、专业感或安全感，而不是缺少意志力。', adjustment: '先做一次低风险暴露，保留尊重，但降低沉默或讨好的程度。');
    }
    if (action.trim().length < 4 || text.contains('变得') || text.contains('提升自己')) {
      return const ChangePathResistanceDiagnosis(type: '行动不具体', explanation: '目标仍停留在身份愿望，现实中难以判断何时开始、何时完成。', adjustment: '改写成一个有对象、有动作、有完成标准的行为。');
    }
    return const ChangePathResistanceDiagnosis(type: '过度依赖状态', explanation: '行动设计本身可执行，但可能仍在等待动力、情绪或完整时间。', adjustment: '先执行最低标准，再根据真实反馈决定是否继续。');
  }

  String downgradedAction(ChangePathActionCard card) {
    if (card.difficulty >= 8) return '把“${card.action}”缩小到 5 分钟，只完成第一个可观察动作。';
    if (card.difficulty >= 6) return '先做“${card.action}”的最低版本，持续 8 分钟即可。';
    return '给“${card.action}”补上明确时间，并只要求完成最低标准。';
  }

  ChangePathMapSnapshot buildMap({
    required TodoGoalProfile goal,
    required List<ChangePathActionCard> cards,
    required List<ChangePathEvidence> evidence,
    required int reviewCount,
  }) {
    final goalCards = cards.where((card) => card.goalId == goal.goalId).toList();
    final goalEvidence = evidence.where((item) => item.goalId == goal.goalId).toList();
    final resistanceCounts = <String, int>{};
    for (final card in goalCards) {
      resistanceCounts[card.resistanceType] = (resistanceCounts[card.resistanceType] ?? 0) + 1;
    }
    final strongest = resistanceCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final latestBelief = goalEvidence.isEmpty ? '' : goalEvidence.first.newBelief;
    return ChangePathMapSnapshot(
      theme: goal.goalTitle,
      oldPattern: goalCards.isEmpty ? goal.obstacleSummary : goalCards.first.oldPattern,
      preservedValue: goalCards.isEmpty ? _first(goal.coreValueList, fallback: goal.valueGoal) : goalCards.first.preservedValue,
      strongestResistance: strongest.isEmpty ? '尚待通过行动观察' : strongest.first.key,
      newBehavior: goalCards.isEmpty ? goal.processGoal : goalCards.first.action,
      evidenceCount: goalEvidence.length,
      completedActions: goalCards.where((card) => card.isCompleted).length,
      reviewCount: reviewCount,
      newIdentity: latestBelief.isNotEmpty ? latestBelief : (goal.desiredIdentity.trim().isEmpty ? '我正在成为能带着不适采取小行动的人。' : goal.desiredIdentity),
    );
  }

  String _first(List<String> values, {required String fallback}) => values.isEmpty || values.first.trim().isEmpty ? fallback : values.first.trim();
}
