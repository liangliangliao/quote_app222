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
/// 登记**必须发生在 Workmanager 初始化之后**（见 main.dart 的启动流程）；登记结果和每次运行
/// 的结论都写进设置，自检页读它们——后台任务看不见摸不着，不留痕迹就没法验证它是否真的在跑。
class EnemyHostPatrol {
  const EnemyHostPatrol._();

  /// wm_dispatcher 里的分发标识。
  static const String workJob = 'beautiful_enemy_patrol';

  static const String uniqueName = 'beautiful_enemy_patrol_periodic_v1';
  static const String onceName = 'beautiful_enemy_patrol_once_v1';
  static const String taskName = 'beautiful_enemy_patrol_task';
  static const int notificationId = 92002;

  /// 前台心跳在这个时间内，说明前台有人在盯着，后台这一轮让位。
  static const Duration foregroundGrace = Duration(seconds: 30);

  /// 一轮巡查最多开口几次，免得一次积压的事连着说。
  static const int maxPerRun = 2;

  static Future<EnemyDao> _dao() async {
    final EnemyDao dao = EnemyDao(await AppDatabase.instance());
    await dao.ensureSchema();
    return dao;
  }

  /// 登记周期任务（幂等）。成功返回空串，失败返回原因；两种结果都会记下来供自检页显示。
  static Future<String> ensureScheduled() async {
    String error = '';
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
    } catch (e) {
      error = '$e';
    }
    try {
      final EnemyDao dao = await _dao();
      if (error.isEmpty) {
        await dao.setSetting(EnemySettings.bgScheduledMs, '${DateTime.now().millisecondsSinceEpoch}');
      }
      await dao.setSetting(EnemySettings.bgScheduleError, error);
    } catch (_) {
      // 记不下来也不影响任务本身。
    }
    return error;
  }

  /// 10 秒后在真正的后台跑一次（带演练标记），用来验证「登记 → 系统调起 → 分发 → 运行」整条通路。
  static Future<String> scheduleOnce() async {
    try {
      await Workmanager().registerOneOffTask(
        onceName,
        taskName,
        initialDelay: const Duration(seconds: 10),
        inputData: const <String, dynamic>{'job': workJob, 'drill': '1'},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      return '';
    } catch (e) {
      return '$e';
    }
  }

  /// 巡查一轮。返回 true 表示任务本身成功（没有开口也算成功）。
  /// [inputData] 里 `drill == '1'` 表示这是验证通路的演练：不让位给前台，并且一定发一条通知。
  static Future<bool> runScheduled([Map<String, dynamic>? inputData]) async {
    final bool drill = '${inputData?['drill'] ?? ''}' == '1';
    EnemyDao? dao;
    String note;
    try {
      final EnemyPresence presence = await EnemyEntry.buildPresence(
        db: await AppDatabase.instance(),
        talker: EnemyAiTalker(),
        sources: defaultEnemySources(),
      );
      dao = presence.dao;
      await dao.setSetting(EnemySettings.bgLastRunMs, '${DateTime.now().millisecondsSinceEpoch}');

      if (drill) {
        await NotificationService.show(
          id: notificationId + 9,
          title: '美丽的敌人（后台演练）',
          body: '后台通路是通的：这条通知是在后台任务里发出的。',
          payload: EnemyHostReminder.notificationPayload,
        );
      }

      if (!await dao.boolSetting(EnemySettings.interject, fallback: true)) {
        note = '跳过：实时插话是关的';
      } else if (!await dao.boolSetting(EnemySettings.interjectEverywhere, fallback: true)) {
        note = '跳过：「在其它页面也插话」是关的';
      } else {
        final int beat = await dao.intSetting(EnemySettings.heartbeatMs, 0);
        final bool foreground = beat > 0 &&
            DateTime.now().millisecondsSinceEpoch - beat < foregroundGrace.inMilliseconds;
        if (foreground && !drill) {
          note = '让位：前台正在跑';
        } else {
          int spoke = 0;
          for (int i = 0; i < maxPerRun; i++) {
            final EnemyMessage? msg = await presence.step();
            if (msg == null) break;
            spoke++;
            await NotificationService.show(
              id: notificationId + i,
              title: '美丽的敌人',
              body: msg.text,
              payload: EnemyHostReminder.notificationPayload,
            );
          }
          final EnemyStatus s = await presence.status();
          note = spoke > 0
              ? '开口 $spoke 次'
              : '巡查完成，没有要说的（${EnemyStatus.whyText(s.lastWhy)}）';
        }
      }
    } catch (e) {
      note = '出错：$e';
    }
    try {
      await dao?.setSetting(EnemySettings.bgLastNote, drill ? '演练 · $note' : note);
    } catch (_) {
      // 记不下来也不影响任务本身。
    }
    return true;
  }
}
