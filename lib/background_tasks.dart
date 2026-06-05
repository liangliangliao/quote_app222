
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'utils/debug_logger.dart';
import 'services/notification_service.dart';
import 'services/scheduler_service.dart';

class BackgroundTasks {
  static Future<void> registerSelfCheck() async {
    // 自检已禁用：仅清理历史的自检任务，不再注册
    const uniq = 'bg_selfcheck_next';
    try { await Workmanager().cancelByUniqueName(uniq); } catch (_) {}
    await DLog.i('BG', '自检已禁用（仅执行清理，不再注册）');
  }
}