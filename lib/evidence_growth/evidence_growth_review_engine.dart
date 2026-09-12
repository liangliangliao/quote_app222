import 'evidence_growth_models.dart';

/// Shared offline/server fallback. Outcome usefulness and prediction accuracy
/// are different observations; neither is inferred from action completion.
class EvidenceGrowthReviewEngine {
  const EvidenceGrowthReviewEngine();
  TrialReviewResult review(RealityTrial trial) {
    final did = trial.didAction == true;
    final actual = trial.actualOutcome.trim();
    final pending = actual.isEmpty || trial.resultStatus == 'OBSERVING';
    final helpful = trial.operatorInputs['outcome_helpful'];
    final failure = pending ? 'TOO_EARLY' : !did ? 'NO_ACTION'
        : trial.operatorInputs['failure_class'] ?? 'NOT_CLASSIFIED';
    final decision = pending ? 'OBSERVE' : !did || helpful == 'false' ? 'ADJUST'
        : helpful == 'true' ? 'ACT' : 'OBSERVE';
    final next = decision == 'OBSERVE' ? '保留原预测，补一条可判断目标是否推进的事实。'
        : decision == 'ACT' ? '保持本轮条件，再取一个现实样本。'
        : '只把动作尺度缩小一半，其他条件保持不变。';
    return TrialReviewResult(
      predictionOriginal: trial.prediction,
      actualFacts: [if (actual.isNotEmpty) actual, if (trial.unexpected.isNotEmpty) trial.unexpected],
      predictionError: pending ? '仍在观察，不能把尚无结果分类为失败。'
          : '原预测“${trial.prediction}”；实际“$actual”。预测是否发生：${trial.operatorInputs['prediction_occurred'] ?? 'unknown'}。',
      failureClass: failure,
      learning: did ? '行动事实已经保存；先比较预测与实际，再判断结果对目标的帮助。'
          : '未做或中止提供了障碍信息；先检查恢复、任务尺度和情境。',
      ruleUpdate: next,
      decision: decision,
      nextChangeOneVariable: next,
      knowledgeNodeIds: trial.nodeIds,
    );
  }
}
