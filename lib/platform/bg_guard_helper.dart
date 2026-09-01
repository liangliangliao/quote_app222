import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/debug_logger.dart';

/// Background stability helper.
///
/// Reality check: without a persistent notification / foreground service,
/// many OEMs (especially Samsung) will delay AlarmManager and implicit
/// unlock broadcasts under battery optimization / sleeping-app policies.
///
/// This helper provides:
/// 1) status introspection (battery optimization, standby bucket, exact alarm)
/// 2) one-click jumps to the relevant system settings
class BgGuardHelper {
  static const MethodChannel _ch = MethodChannel('com.example.quote_app/sys');

  static Future<Map<String, dynamic>> getStatus() async {
    if (!Platform.isAndroid) return <String, dynamic>{};
    try {
      final ret = await _ch.invokeMethod('getBgGuardStatus');
      if (ret is Map) {
        return ret.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    } catch (e) {
      DLog.w('BgGuard', 'getStatus failed: $e');
      return <String, dynamic>{'error': e.toString()};
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      DLog.w('BgGuard', 'requestIgnoreBatteryOptimizations failed: $e');
    }
  }

  static Future<void> openAppDetailsSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('openAppDetailsSettings');
    } catch (e) {
      DLog.w('BgGuard', 'openAppDetailsSettings failed: $e');
    }
  }

  static Future<void> openIgnoreBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('openIgnoreBatteryOptimizationSettings');
    } catch (e) {
      DLog.w('BgGuard', 'openIgnoreBatteryOptimizationSettings failed: $e');
    }
  }

  static Future<void> ensureUnlockPulseScheduled() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('ensureUnlockPulseScheduled');
    } catch (e) {
      DLog.w('BgGuard', 'ensureUnlockPulseScheduled failed: $e');
    }
  }

  /// Show a lightweight, non-blocking guide if the current device state is
  /// very likely to delay background unlock/location reminders.
  static Future<void> maybeShowGuide(BuildContext context, {required String feature}) async {
    if (!Platform.isAndroid) return;
    final st = await getStatus();
    final bool ignoreBattOpt = st['ignoreBattOpt'] == true;
    final String bucket = (st['bucket']?.toString() ?? '');
    // If we are not whitelisted OR bucket is restricted, background alarms may be delayed for minutes.
    final bool risky = (!ignoreBattOpt) || bucket.contains('RESTRICTED');
    if (!risky) return;

    // Avoid spamming: only show once per app run.
    if (_shownThisRun) return;
    _shownThisRun = true;

    // UI guide.
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('后台触发可能被系统延迟'),
          content: Text(
            '你开启了「$feature」。\n\n'
            '当前系统状态显示：电池优化未忽略（ignoreBattOpt=false）或应用处于受限档位（$bucket）。'
            '在锁屏/后台时，系统可能会把闹钟/广播延迟到 10 分钟甚至更久。\n\n'
            '解决办法（不需要常驻通知）：\n'
            '1) 将本 App 的电池使用设为「不受限制/无限制」\n'
            '2) 在系统的「睡眠应用/深度睡眠应用」里移除本 App（三星等机型）\n'
            '3) 允许「闹钟和提醒」(精确闹钟)（Android 12+）',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // First try the official whitelist prompt; fallback to app details.
                await requestIgnoreBatteryOptimizations();
                await openAppDetailsSettings();
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  }

  static bool _shownThisRun = false;
}
