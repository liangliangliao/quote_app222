import '../beautiful_enemy/beautiful_enemy.dart';
import '../services/notification_service.dart';
import 'enemy_host_patrol.dart';
import 'enemy_host_reminder.dart';

/// 自检页上的按钮：通知和后台任务这两件模块自己做不了的事。
class EnemyHostToolsImpl implements EnemyHostTools {
  const EnemyHostToolsImpl();

  @override
  Future<String> testNotification(String text) async {
    try {
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
