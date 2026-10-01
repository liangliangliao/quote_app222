import 'package:workmanager/workmanager.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import 'enemy_ai_talker.dart';
import 'enemy_host_reminder.dart';
import 'enemy_sources.dart';

/// 后台巡查：App 不在前台时，敌人也每隔一段时间自己出门巡一次。
///
/// 这是 Android 允许的最勤的方式，**不是实时**：系统最短 15 分钟一次，省电策略
/// （小米等厂商的后台限制尤其严）可能推迟甚至杀掉它。要做到「App 关着也秒级响应」
/// 需要常驻前台服务（带一条常驻通知），那是另一个量级的改动，这里没有做。
///
/// 巡查时敌人做的事和前台一样：同步案卷、对新事件做反应、必要时主动开口，
/// 然后用通知说出来。它尊重静音、静默时段、每日上限和各个开关。
class EnemyHostPatrol {
  const EnemyHostPatrol._();

  /// wm_dispatcher 里的分发标识。
  static const String workJob = 'beautiful_enemy_patrol';

  static const String uniqueName = 'beautiful_enemy_patrol_periodic_v1';
  static const String taskName = 'beautiful_enemy_patrol_task';
  static const int notificationId = 92002;

  /// 前台心跳在这个时间内，说明前台有人在盯着，后台这一轮让位。
  static const Duration foregroundGrace = Duration(seconds: 30);

  /// 一轮巡查最多开口几次，免得一次积压的事连着说。
  static const int maxPerRun = 2;

  static Future<void> ensureScheduled() async {
    try {
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(minutes: 5),
        inputData: const <String, dynamic>{'job': workJob},
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    } catch (_) {
      // 登记不上就算了：前台照常工作。
    }
  }

  /// 巡查一轮。返回 true 表示任务本身成功（没有开口也算成功）。
  static Future<bool> runScheduled() async {
    try {
      final EnemyPresence presence = await EnemyEntry.buildPresence(
        db: await AppDatabase.instance(),
        talker: EnemyAiTalker(),
        sources: defaultEnemySources(),
      );
      final EnemyDao dao = presence.dao;

      if (!await dao.boolSetting(EnemySettings.interject, fallback: true)) return true;
      if (!await dao.boolSetting(EnemySettings.interjectEverywhere, fallback: true)) return true;

      final int beat = await dao.intSetting(EnemySettings.heartbeatMs, 0);
      if (beat > 0 &&
          DateTime.now().millisecondsSinceEpoch - beat < foregroundGrace.inMilliseconds) {
        return true;
      }

      for (int i = 0; i < maxPerRun; i++) {
        final EnemyMessage? msg = await presence.step();
        if (msg == null) break;
        await NotificationService.show(
          id: notificationId + i,
          title: '美丽的敌人',
          body: msg.text,
          payload: EnemyHostReminder.notificationPayload,
        );
      }
    } catch (_) {
      // 一轮失败不要紧，15 分钟后还有下一轮。
    }
    return true;
  }
}
