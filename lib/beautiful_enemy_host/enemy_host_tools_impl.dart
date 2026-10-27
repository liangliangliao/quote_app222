import '../beautiful_enemy/beautiful_enemy.dart';
import '../services/notification_service.dart';
import '../data/db.dart';
import 'package:workmanager/workmanager.dart';
import 'enemy_host_patrol.dart';
import 'enemy_host_reminder.dart';

/// 自检页上的按钮：通知和后台任务这两件模块自己做不了的事。
class EnemyHostToolsImpl implements EnemyHostTools, EnemyHostPower {
  const EnemyHostToolsImpl();

  @override
  Future<void> setModuleEnabled(bool enabled) async {
    final dao = EnemyDao(await AppDatabase.instance());
    await dao.ensureSchema();
    if (enabled) {
      await EnemyHostPatrol.ensureScheduled();
      if (await dao.boolSetting(EnemySettings.dailyNotify)) {
        await const EnemyHostReminder().onDailyNotifyChanged(enabled: true,
          hour: await dao.intSetting(EnemySettings.dailyNotifyHour, 21));
      }
    } else {
      try { await Workmanager().cancelByUniqueName(EnemyHostPatrol.uniqueName); } catch (_) {}
      try { await Workmanager().cancelByUniqueName(EnemyHostPatrol.onceName); } catch (_) {}
      await const EnemyHostReminder().onDailyNotifyChanged(enabled: false, hour: 21);
    }
  }

  @override
  Future<String> testNotification(String text) async {
    try {
      final dao = EnemyDao(await AppDatabase.instance());
      await dao.ensureSchema();
      if (!await dao.boolSetting(EnemySettings.enabled, fallback: true)) return '模块已停用';
      await NotificationService.show(
        id: 92003,
        title: '美丽的敌人（测试）',
        body: text,
        payload: EnemyHostReminder.notificationPayload,
      );
      return '';
    } catch (e) {
      return '发不出去：$e';
    }
  }

  @override
  Future<String> scheduleBackgroundPatrol() => EnemyHostPatrol.ensureScheduled();

  @override
  Future<String> runBackgroundPatrolOnce() => EnemyHostPatrol.scheduleOnce();
}
