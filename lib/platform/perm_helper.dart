import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/debug_logger.dart';

class PermHelper {
  static const MethodChannel _ch = MethodChannel('com.example.quote_app/sys');
  static bool? _lastHasExact;
  static DateTime? _lastExactCheckedAt;

  /// 是否拥有“精确闹钟”权限（带缓存与容错，避免偶发抖动）
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod('hasExactAlarmPermission');
      return ok == true;
    } on MissingPluginException catch (_) {
      // Fallback：如果 /sys 通道未注册，尝试走主用的 native.scheduler
      try {
        const MethodChannel ch2 = MethodChannel('native.scheduler');
        final ok2 = await ch2.invokeMethod('canScheduleExact');
        return ok2 == true;
      } catch (e) {
        DLog.w('platform/perm_helper.dart', 'both /sys and native.scheduler unavailable: ' + e.toString());
        return false;
      }
    } catch (e) {
      DLog.w('platform/perm_helper.dart', 'hasExactAlarmPermission catch: ' + e.toString());
      return false;
    }
  }

  /// 申请“精确闹钟”权限（带兜底通道）
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('requestExactAlarmPermission');
    } on MissingPluginException catch (_) {
      try {
        const MethodChannel ch2 = MethodChannel('native.scheduler');
        await ch2.invokeMethod('requestExactPermission');
      } catch (e) {
        DLog.w('platform/perm_helper.dart', 'fallback requestExactPermission failed: ' + e.toString());
      }
    } catch (e) {
      DLog.e('platform/perm_helper.dart', 'requestExactAlarmPermission catch: ' + e.toString());
    }
  }
}