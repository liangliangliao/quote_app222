import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:quote_app/utils/debug_logger.dart';

class NativeScheduler {
  static const MethodChannel _ch = MethodChannel('native.scheduler');

  /// 打开系统通知权限弹框（原生侧实现），返回是否已授权
  static Future<bool> requestNotificationPermissionSystem() async {
    try {
      final r = await _ch.invokeMethod('request_notification_permission');
      return r == true;
    } catch (_) {
      return false;
    }
  }


  /// 是否具备精确闹钟权限；Android 12+ 若未授权，预设时间提醒可能不会触发。
  static Future<bool> canScheduleExactAlarm() async {
    try {
      final ok = await _ch.invokeMethod('canScheduleExact');
      return ok == true;
    } catch (_) {
      return true;
    }
  }

  /// 打开精确闹钟授权页。授权后需要用户返回 App 再注册提醒。
  static Future<bool> requestExactAlarmPermission() async {
    try {
      final ok = await _ch.invokeMethod('requestExactPermission');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// 注册精准闹钟（原生侧实现）
  static Future<bool> scheduleExactAt({
    required int id,
    required int epochMs,
    Map<String, dynamic>? payload,
  }) async {
    await DLog.i('SCH', '【Dart→原生】AM 注册请求(id='+id.toString()+', epochMs='+epochMs.toString()+')');
    final ok = await _ch.invokeMethod<bool>('scheduleExactAt', {
      'id': id,
      'epochMs': epochMs,
      'payload': jsonEncode(payload ?? {}),
    });
    return ok ?? false;
  }

  /// 注册系统闹钟级别提醒（Android AlarmManager.setAlarmClock）。
  /// 用于行为预设闹钟：即使 App 后台进程不在，也尽量像系统闹钟一样准时拉起。
  static Future<bool> scheduleAlarmClockAt({
    required int id,
    required int epochMs,
    Map<String, dynamic>? payload,
  }) async {
    await DLog.i('SCH', '【Dart→原生】AlarmClock 注册请求(id=' + id.toString() + ', epochMs=' + epochMs.toString() + ')');
    final ok = await _ch.invokeMethod<bool>('scheduleAlarmClockAt', {
      'id': id,
      'epochMs': epochMs,
      'payload': jsonEncode(payload ?? {}),
    });
    return ok ?? false;
  }

/// 取消精准闹钟
  static Future<void> cancel(int id) async {
    await _ch.invokeMethod('cancel', {'id': id});
    await DLog.i('SCH', '【Dart】AM 调用原生取消完成 id='+id.toString());
  }


  /// 原生：一次性注册 WM 正常(main-wm) + 兜底(fallback-wm)；兜底延迟 +2 分钟，但 runKey 不变
  static Future<bool> scheduleWmPair({
    required String uid,
    required String runKey,
    required DateTime triggerAt,
  }) async {
    try {
      final ok = await _ch.invokeMethod('scheduleWmPair', {
        'uid': uid,
        'runKey': runKey,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      });
      try { await _ch.invokeMethod('scheduleKickAt', {
        'uid': uid,
        'runKey': runKey,
        'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      }); } catch (_){ };

      return ok == true;
    } catch (_) {
      return false; // 原生不可用→回退到 Dart WM
    }
  }

  /// 取消 Kick 闹钟（与 AM 统一 alarmId 计算，native 侧按 uid+runKey 生成）
  static Future<void> cancelKick(String uid, String runKey) async {
    try { await _ch.invokeMethod('cancelKick', {'uid': uid, 'runKey': runKey}); } catch (_){ }
  }

  /// 原生：按唯一名取消 WM
  static Future<void> cancelWmByUnique(String unique) async {
    try { await _ch.invokeMethod('cancelWmByUnique', {'unique': unique}); } catch (_) {}
  }
}