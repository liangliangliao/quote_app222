import '../platform/native_scheduler.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_operator_registry.dart';

class EvidenceGrowthReminder {
  const EvidenceGrowthReminder(this.kind, this.atMs, this.title, this.body);
  final String kind;
  final int atMs;
  final String title;
  final String body;
}

class EvidenceGrowthNotificationService {
  const EvidenceGrowthNotificationService();
  static const kinds = ['trial_review_due','trial_start','recovery_end','missing_result','repeated_avoidance'];

  /// Pure planning permits deterministic timing/de-duplication tests.
  static List<EvidenceGrowthReminder> plan(RealityTrial trial, int now, {bool repeatedAvoidance = false}) {
    if (trial.isClosed || const {'RESULT_CAPTURED','REVIEWED'}.contains(trial.status)) return [];
    final due = trial.nextReviewAtMs > 0 ? trial.nextReviewAtMs : trial.reviewAtMs;
    final start = int.tryParse(trial.operatorInputs['scheduled_start_ms'] ?? '') ?? 0;
    final minutes = EvidenceGrowthOperatorRegistry.maybeById(trial.operator)?.minimumMinutes ?? 0;
    final list = <EvidenceGrowthReminder>[
      if (trial.status == 'READY' && start > now)
        EvidenceGrowthReminder('trial_start', start, '现实试验 · 开始时间到了', '你不需要完成全部，先进入现实五分钟。'),
      if (trial.operator == 'RECOVER' && trial.startedAtMs > 0)
        EvidenceGrowthReminder('recovery_end', trial.startedAtMs + (minutes > 0 ? minutes : 20) * 60000,
          '恢复窗口结束', '先检查恢复情况，再做最小下一步；仍然耗竭就继续恢复。'),
      EvidenceGrowthReminder('trial_review_due', due, '现实试验 · 观察窗口到了', '记录实际发生的事实，再比较原预测；尚无结果可以继续观察。'),
      EvidenceGrowthReminder('missing_result', due + 86400000, '这轮还缺少现实反馈', '回来记录完成、部分、未做或中止，再决定下一步。'),
      if (repeatedAvoidance)
        EvidenceGrowthReminder('repeated_avoidance', now + 60000, '同类回避出现三次', '先检查情境、暴露强度和恢复；把本轮动作缩小。'),
    ];
    final unique = <int, EvidenceGrowthReminder>{};
    for (final item in list) {
      if (item.atMs > now) unique.putIfAbsent(item.atMs, () => item);
    }
    return unique.values.toList()..sort((a,b)=>a.atMs.compareTo(b.atMs));
  }

  Future<bool> scheduleTrial(RealityTrial trial, {bool repeatedAvoidance = false}) async {
    if (!await NativeScheduler.requestNotificationPermissionSystem()) return false;
    if (!await NativeScheduler.canScheduleExactAlarm()) return false;
    await cancel(trial.id);
    var success = true;
    for (final item in plan(trial, DateTime.now().millisecondsSinceEpoch, repeatedAvoidance: repeatedAvoidance)) {
      final result = await NativeScheduler.scheduleExactAt(
        id: alarmId(trial.id, item.kind), epochMs: item.atMs,
        payload: {'module':'evidence_growth','type':item.kind,'trial_id':trial.id,
          'title':item.title,'body':item.body});
      success = result && success;
    }
    return success;
  }

  Future<bool> scheduleReview(RealityTrial trial) => scheduleTrial(trial);

  Future<void> cancel(String trialId) async {
    for (final kind in kinds) {
      await NativeScheduler.cancel(alarmId(trialId, kind));
    }
    // Remove an alarm created by the first release's ID scheme too.
    var legacyHash = 902100;
    for (final unit in trialId.codeUnits) { legacyHash = (legacyHash * 31 + unit) & 0x3fffffff; }
    await NativeScheduler.cancel(902100 + legacyHash % 800000);
  }

  static int alarmId(String trialId, [String kind = 'trial_review_due']) {
    var hash = 902100;
    for (final unit in '$trialId:$kind'.codeUnits) { hash = (hash * 31 + unit) & 0x3fffffff; }
    return 20000000 + hash;
  }
}
