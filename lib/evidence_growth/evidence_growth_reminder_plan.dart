import 'evidence_growth_models.dart';

class EvidenceGrowthReminder {
  const EvidenceGrowthReminder(this.kind, this.atMs, this.title, this.body, this.sourceIds);
  final String kind;
  final int atMs;
  final String title;
  final String body;
  final List<String> sourceIds;
}

/// PRD §40. The grace period is an explicit engineering default, not a KB claim.
class EvidenceGrowthReminderPlan {
  static const kinds = ['trial_start', 'trial_review_due', 'missing_result', 'repeated_avoidance', 'recovery_end'];
  static List<EvidenceGrowthReminder> build(RealityTrial trial, int now, {
    bool repeatedAvoidance = false, bool includeOverdue = false, int missingHours = 24,
  }) {
    final list = <EvidenceGrowthReminder>[];
    final due = trial.nextReviewAtMs > 0 ? trial.nextReviewAtMs : trial.reviewAtMs;
    final start = int.tryParse(trial.operatorInputs['scheduled_start_ms'] ?? '') ?? 0;
    if (!trial.isClosed && !const {'RESULT_CAPTURED', 'REVIEWED'}.contains(trial.status)) {
      if (trial.status == 'READY' && start > 0) {
        list.add(EvidenceGrowthReminder('trial_start', start, '现实试验 · 开始时间到了',
          '你不需要完成，只需要进入现实 5 分钟。点击查看本轮最小动作。', const ['KB35-A02']));
      }
      if (trial.operator == 'RECOVER' && trial.status == 'IN_PROGRESS') {
        list.add(EvidenceGrowthReminder('recovery_end', due, '恢复窗口结束',
          '恢复是为了重新进入行动。先检查恢复情况，再做最小下一步；仍然耗竭就继续恢复。', const ['KB35-A-AUDIT-01', 'KB35-A02']));
      }
      if (due > 0) {
        list.add(EvidenceGrowthReminder('trial_review_due', due, '现实试验 · 观察窗口到了',
          '回来比较预测与实际。还没开始、尚无结果也可以如实记录，不把时间到期当作已经完成。', const ['KB35-R01', 'KB35-R-EXT2-01']));
        list.add(EvidenceGrowthReminder('missing_result', due + missingHours.clamp(1, 168) * 3600000,
          '这条路线还缺少反馈', '继续之前，先补充现实证据。点击记录完成、部分、未做、中止或继续观察。', const ['KB35-R01', 'KB35-G-EXT2-02']));
      }
    }
    if (repeatedAvoidance && trial.isClosed && trial.decision == 'EXIT') {
      list.add(EvidenceGrowthReminder('repeated_avoidance', trial.updatedAtMs + 60000,
        '同一节点连续三次退出', '先检查环境、失败暴露与系统条件，再决定下一步；退出本身不是失败。',
        const ['KB35-F01', 'KB35-A-EXT2-01', 'KB35-C-EXT2-01']));
    }
    // One notification per Trial per minute window, including competing recovery/result triggers.
    final windows = <int, EvidenceGrowthReminder>{};
    for (final item in list) {
      if (includeOverdue || item.atMs > now) windows.putIfAbsent(item.atMs ~/ 60000, () => item);
    }
    return windows.values.toList()..sort((a, b) => a.atMs.compareTo(b.atMs));
  }
}
