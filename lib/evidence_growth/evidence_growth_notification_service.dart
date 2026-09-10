import 'package:flutter/services.dart';
import '../platform/native_scheduler.dart';
import 'evidence_growth_models.dart';
import 'evidence_growth_reminder_plan.dart';
export 'evidence_growth_reminder_plan.dart' show EvidenceGrowthReminder;

/// SQLite is the durable outbox. Native AlarmManager and WorkManager share it.
class EvidenceGrowthNotificationService {
  const EvidenceGrowthNotificationService();
  static const _channel = MethodChannel('native.scheduler');
  static const kinds = EvidenceGrowthReminderPlan.kinds;

  static List<EvidenceGrowthReminder> plan(RealityTrial trial, int now, {bool repeatedAvoidance = false}) =>
    EvidenceGrowthReminderPlan.build(trial, now, repeatedAvoidance: repeatedAvoidance);

  Future<bool> reconcile() async {
    try { return await _channel.invokeMethod<bool>('eg_reconcile_reminders') ?? false; }
    catch (_) { return false; }
  }

  Future<Map<String, dynamic>> status() async {
    try { return Map<String, dynamic>.from(await _channel.invokeMapMethod<String, dynamic>('eg_notification_status') ?? {}); }
    catch (_) { return {'notifications': false, 'exact': false, 'available': false}; }
  }

  Future<void> openSystemSettings() async {
    await _channel.invokeMethod('eg_notification_settings');
  }

  // DAO mutations commit reminder intents in the same transaction as the Trial.
  // These methods only reconcile the OS, never prompt from background work.
  Future<bool> scheduleTrial(RealityTrial trial, {bool repeatedAvoidance = false}) async {
    await _cancelLegacy(trial.id);
    return reconcile();
  }
  Future<bool> scheduleReview(RealityTrial trial) => scheduleTrial(trial);
  Future<void> cancel(String trialId) async {
    await _cancelLegacy(trialId);
    await reconcile();
  }
  Future<void> _cancelLegacy(String trialId) async {
    for (final kind in kinds) {
      try { await NativeScheduler.cancel(alarmId(trialId, kind)); } catch (_) {}
    }
    var hash = 902100;
    for (final unit in trialId.codeUnits) { hash = (hash * 31 + unit) & 0x3fffffff; }
    try { await NativeScheduler.cancel(902100 + hash % 800000); } catch (_) {}
  }
  static int alarmId(String trialId, [String kind = 'trial_review_due']) {
    var hash = 902100;
    for (final unit in '$trialId:$kind'.codeUnits) { hash = (hash * 31 + unit) & 0x3fffffff; }
    return 20000000 + hash;
  }
}
