import 'package:workmanager/workmanager.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import 'enemy_voice_out.dart';

/// 每日报到通知（默认关，开关在模块的设置页里）。
///
/// 模块本身不碰通知，只把开关和时间交出来；这里用宿主已有的 Workmanager
/// 一次性任务排期，到点由 [handleWork] 弹一条只报数字的通知，然后排下一天。
/// 后台任务不调模型、不开庭，只读本地承诺表。
class EnemyHostReminder implements EnemyReminder {
  const EnemyHostReminder();

  /// wm_dispatcher 里的分发标识。
  static const String workJob = 'beautiful_enemy_daily';

  static const String _taskName = 'beautiful_enemy_daily_task';
  static const String notificationPayload = 'beautiful_enemy';

  /// 通知 id，避开宿主其它模块用的区间。
  static const int _notificationId = 92000;

  @override
  Future<void> onDailyNotifyChanged({required bool enabled, required int hour}) async {
    await _cancel();
    if (!enabled) return;
    final engine = await EnemyEntry.buildEngine(db: await AppDatabase.instance());
    if (!await engine.isEnabled()) return;
    await _schedule(hour);
  }

  static Future<void> _schedule(int hour) async {
    final engine = await EnemyEntry.buildEngine(db: await AppDatabase.instance());
    if (!await engine.isEnabled()) return;
    final DateTime now = DateTime.now();
    DateTime next = DateTime(now.year, now.month, now.day, hour);
    if (!next.isAfter(now.add(const Duration(minutes: 1)))) {
      next = next.add(const Duration(days: 1));
    }
    try {
      await Workmanager().registerOneOffTask(
        _taskName,
        'wm_task',
        initialDelay: next.difference(now),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        inputData: <String, dynamic>{'job': workJob, 'hour': hour},
      );
    } catch (_) {
      // 排不上就算了：应用内一切照常，只是没有系统通知。
    }
  }

  static Future<void> _cancel() async {
    try {
      await Workmanager().cancelByUniqueName(_taskName);
    } catch (_) {
      // 没排过就没什么好取消的。
    }
  }

  /// 到点执行：读本地承诺，弹一条通知，再排明天的。
  static Future<void> handleWork(Map<String, dynamic>? inputData) async {
    final Object? rawHour = inputData?['hour'];
    final int hour = rawHour is int ? rawHour : int.tryParse('${rawHour ?? ''}') ?? 21;

    String body = '今天的账该算了。';
    try {
      final EnemyEngine engine = await EnemyEntry.buildEngine(db: await AppDatabase.instance());
      if (!await engine.isEnabled()) return;
      final bool enabled = await engine.dao.boolSetting(EnemySettings.dailyNotify);
      if (!enabled) return;
      if (await engine.isMuted()) {
        await _schedule(hour);
        return;
      }
      body = await engine.briefLine();
    } catch (_) {
      // 无法确认总开关时不发通知。
      return;
    }

    final beforeNotify = await EnemyEntry.buildEngine(db: await AppDatabase.instance());
    if (!await beforeNotify.isEnabled()) return;
    await NotificationService.show(
      id: _notificationId,
      title: '美丽的敌人',
      body: body,
      payload: notificationPayload,
    );
    final engine = await EnemyEntry.buildEngine(db: await AppDatabase.instance());
    if (!await engine.isEnabled()) return;
    if (await engine.dao.boolSetting(EnemySettings.voiceOut)) {
      final voice = EnemyHostVoiceOut();
      await voice.speakWhileEnabled(engine.dao, body);
    }
    if (await engine.isEnabled()) await _schedule(hour);
  }
}
