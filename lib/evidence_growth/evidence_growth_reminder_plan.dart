import 'evidence_growth_models.dart';

class EvidenceGrowthReminder {
  const EvidenceGrowthReminder(
      this.kind, this.atMs, this.title, this.body, this.sourceIds);
  final String kind;
  final int atMs;
  final String title;
  final String body;
  final List<String> sourceIds;
}

/// PRD §40. The grace period is an explicit engineering default, not a KB claim.
class EvidenceGrowthReminderPlan {
  static const kinds = [
    'trial_start',
    'trial_review_due',
    'missing_result',
    'repeated_avoidance',
    'recovery_end'
  ];

  /// Fixed slots anchored to the first reminder; skip slots already covered by a
  /// late delivery so an outage never produces a burst of catch-up notifications.
  static int nextMissingAt(int first, int interval, int lastCovered) =>
      lastCovered < first
          ? first
          : first + ((lastCovered - first) ~/ interval + 1) * interval;
  static List<EvidenceGrowthReminder> build(
    RealityTrial trial,
    int now, {
    bool repeatedAvoidance = false,
    bool includeOverdue = false,
    int missingHours = 24,
    int? missingAtMs,
  }) {
    final list = <EvidenceGrowthReminder>[];
    final due =
        trial.nextReviewAtMs > 0 ? trial.nextReviewAtMs : trial.reviewAtMs;
    final start =
        int.tryParse(trial.operatorInputs['scheduled_start_ms'] ?? '') ?? 0;
    if (!trial.isClosed &&
        !const {'RESULT_CAPTURED', 'REVIEWED'}.contains(trial.status)) {
      if (trial.status == 'READY' && start > 0) {
        list.add(EvidenceGrowthReminder(
            'trial_start',
            start,
            '证据成长｜行动节点',
            '开始时间已到。目标：${trial.goalState}；动作：${trial.actionInstruction}。点击查看并开始。',
            const ['KB35-A02']));
      }
      if (trial.operator == 'RECOVER' && trial.status == 'IN_PROGRESS') {
        list.add(EvidenceGrowthReminder(
            'recovery_end',
            due,
            '证据成长｜行动节点 · 恢复检查',
            '恢复是为了重新进入行动。先检查恢复情况，再做最小下一步；仍然耗竭就继续恢复。',
            const ['KB35-A-AUDIT-01', 'KB35-A02']));
      }
      if (due > 0) {
        list.add(EvidenceGrowthReminder(
            'trial_review_due',
            due,
            '证据成长｜结果节点',
            '观察窗口已到。目标：${trial.goalState}；原预测：${trial.prediction}。点击记录实际结果；到期不代表完成。',
            const ['KB35-R01', 'KB35-R-EXT2-01']));
        list.add(EvidenceGrowthReminder(
            'missing_result',
            missingAtMs ?? due + missingHours.clamp(1, 168) * 3600000,
            '证据成长｜结果节点 · 待反馈',
            '目标：${trial.goalState}；尚未收到现实反馈。原预测：${trial.prediction}。点击补充实际情况。',
            const ['KB35-R01', 'KB35-G-EXT2-01']));
      }
    }
    if (repeatedAvoidance && trial.isClosed && trial.decision == 'EXIT') {
      list.add(EvidenceGrowthReminder(
          'repeated_avoidance',
          trial.updatedAtMs + 60000,
          '证据成长｜改变节点 · 回看路线',
          '先检查环境、失败暴露与系统条件，再决定下一步；退出本身不是失败。',
          const ['KB35-F01', 'KB35-A-EXT2-01', 'KB35-C-EXT2-01']));
    }
    // One notification per Trial per minute window, including competing recovery/result triggers.
    final windows = <int, EvidenceGrowthReminder>{};
    for (final item in list) {
      if (includeOverdue || item.atMs > now)
        windows.putIfAbsent(item.atMs ~/ 60000, () => item);
    }
    return windows.values.toList()..sort((a, b) => a.atMs.compareTo(b.atMs));
  }
}
