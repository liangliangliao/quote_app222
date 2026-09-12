import 'evidence_growth_models.dart';
import 'evidence_growth_decision_engine.dart';

/// Shared offline/server fallback. Outcome usefulness and prediction accuracy
/// are different observations; neither is inferred from action completion.
class EvidenceGrowthReviewEngine {
  const EvidenceGrowthReviewEngine();
  TrialReviewResult review(RealityTrial trial,{List<RealityTrial> history=const [],DateTime? now}) {
    final did = trial.didAction == true;
    final actual = trial.actualOutcome.trim();
    final pending = actual.isEmpty || trial.resultStatus == 'OBSERVING';
    final failure = pending ? 'TOO_EARLY' : !did ? 'NO_ACTION'
        : trial.operatorInputs['failure_class'] ?? 'NOT_CLASSIFIED';
    final recommendation=EvidenceGrowthDecisionEngine.evaluate(trial,history:history,now:now);
    final decision=recommendation.type;
    final next=recommendation.next;
    return TrialReviewResult(
      predictionOriginal: trial.prediction,
      actualFacts: [if (actual.isNotEmpty) actual, if (trial.unexpected.isNotEmpty) trial.unexpected],
      predictionError: pending ? '仍在观察，不能把尚无结果分类为失败。'
          : '原预测“${trial.prediction}”；实际“$actual”。预测是否发生：${trial.operatorInputs['prediction_occurred'] ?? 'unknown'}。',
      failureClass: failure,
      learning: recommendation.reason,
      ruleUpdate: next,
      decision: decision,
      nextChangeOneVariable: next,
      knowledgeNodeIds: trial.nodeIds,
    );
  }
}
