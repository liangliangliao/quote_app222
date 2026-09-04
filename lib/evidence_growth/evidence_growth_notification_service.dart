import '../platform/native_scheduler.dart';
import 'evidence_growth_models.dart';

class EvidenceGrowthNotificationService {
  const EvidenceGrowthNotificationService();
  Future<bool> scheduleReview(RealityTrial trial) async {
    if (trial.reviewAtMs <= DateTime.now().millisecondsSinceEpoch) return false;
    if (!await NativeScheduler.requestNotificationPermissionSystem()) return false;
    if (!await NativeScheduler.canScheduleExactAlarm()) return false;
    return NativeScheduler.scheduleExactAt(
      id: alarmId(trial.id),
      epochMs: trial.reviewAtMs,
      payload: {
        'module': 'evidence_growth',
        'type': 'trial_review_due',
        'trial_id': trial.id,
        'title': '现实试验 · 结果窗口到了',
        'body': '回来比较原预测与实际，再决定继续、调整或退出。',
      },
    );
  }

  Future<void> cancel(String trialId) async {
    try {
      await NativeScheduler.cancel(alarmId(trialId));
    } catch (_) {}
  }

  static int alarmId(String trialId) {
    var hash = 902100;
    for (final unit in trialId.codeUnits) hash = (hash * 31 + unit) & 0x3fffffff;
    return 902100 + hash % 800000;
  }
}
