
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../utils/debug_logger.dart';
import '../services/notification_service.dart';
import '../services/scheduler_service.dart';
import '../health_diet/services/health_diet_daily_scheduler_service.dart';
import '../xiangji_future_strategist/xiangji_strategist_monitor_service.dart';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 初始化后台 isolate 的插件注册
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();

    // 日志：任务名与主要参数，便于定位源头
    try {
      final job = (inputData?['job'] ?? '').toString();
      final uid = (inputData?['task_uid'] ?? '').toString();
      final run = (inputData?['run_key'] ?? '').toString();
      final chan = (inputData?['chan'] ?? '').toString();
      await DLog.i('WM', '调度任务='+task+' job='+job+' chan='+chan+' uid='+uid+' run='+run);
    } catch (_) {}

    // 取参数
    final job = (inputData?['job'] ?? '').toString();
    final uid = (inputData?['task_uid'] ?? '').toString();
    final runKey = (inputData?['run_key'] ?? '').toString();
    final chan = (inputData?['chan'] ?? '').toString();
    int attempt = 1;
    try {
      final a = inputData?['attempt'];
      if (a is int) {
        attempt = a;
      } else if (a is String) {
        attempt = int.tryParse(a) ?? 1;
      }
    } catch (_) {
      attempt = 1;
    }

    // 确保通知插件在后台 isolate 可用
    try { await NotificationService.init(); } catch (_) {}

    // 分发
    if (job == 'wm_selfcheck') {
      await SchedulerService.selfCheckTodayFailures();
      return Future.value(true);
    } else if (job == 'wm_boot') {
      // 开机或应用恢复后重新安排所有任务并注册自检
      await SchedulerService.scheduleNextForAll();
      await SchedulerService.scheduleSelfCheck();
      await HealthDietDailySchedulerService().ensureScheduled();
      return Future.value(true);
    } else if (job == HealthDietDailySchedulerService.workJob) {
      final slot = (inputData?['slot'] ?? '').toString();
      final userId = (inputData?['user_id'] ?? '').toString();
      if (slot.isNotEmpty) {
        await HealthDietDailySchedulerService().runScheduledSlot(
          slot,
          userId: userId.isEmpty ? 'default_user' : userId,
        );
      }
      return Future.value(true);
    } else if (job == XiangjiStrategistMonitorService.job) {
      return XiangjiStrategistMonitorService.runScheduled();
    } else if (job == 'wm_run' && uid.isNotEmpty) {
      await SchedulerService.wmRunTask(uid, runKey.isEmpty ? null : runKey, chan: chan.isEmpty ? null : chan, attempt: attempt);
      return Future.value(true);
    }

    // 兼容旧逻辑：无 job/uid 时不执行业务，但返回成功避免重试风暴
    try { await SchedulerService.callback(); } catch (_) {}
    return Future.value(true);
  });
}
