import 'dart:io';
import 'package:flutter/services.dart';

/// Native background tracking for Sport.
///
/// Android:
/// - Uses a Foreground Service so distance/steps/time/speeds continue even if user
///   leaves SportRunningPage or removes the app from recent tasks.
///
/// iOS:
/// - Uses native CLLocation background updates. Note that iOS will stop background
///   execution if the user force-quits the app from the app switcher.
class NativeSportFg {
  static const MethodChannel _ch = MethodChannel('com.example.quote_app/sys');

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  static Future<void> ensureStarted({
    required int recordId,
    String title = '运动进行中',
    String? targetType,
    double? targetValue,
    String? targetUnit,
  }) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('startSportForeground', <String, dynamic>{
        'recordId': recordId,
        'title': title,
        if (targetType != null) 'targetType': targetType,
        if (targetValue != null) 'targetValue': targetValue,
        if (targetUnit != null) 'targetUnit': targetUnit,
      });
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> pause({int? recordId, String? title}) async {
    if (!_supported) return;
    try {
      final args = <String, dynamic>{};
      if (recordId != null) args['recordId'] = recordId;
      if (title != null) args['title'] = title;
      await _ch.invokeMethod('pauseSportForeground', args.isEmpty ? null : args);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> resume({int? recordId, String? title}) async {
    if (!_supported) return;
    try {
      final args = <String, dynamic>{};
      if (recordId != null) args['recordId'] = recordId;
      if (title != null) args['title'] = title;
      await _ch.invokeMethod('resumeSportForeground', args.isEmpty ? null : args);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> stop({int? recordId, String? title, String? finalStatus}) async {
    if (!_supported) return;
    try {
      final args = <String, dynamic>{};
      if (recordId != null) args['recordId'] = recordId;
      if (title != null) args['title'] = title;
      if (finalStatus != null) args['finalStatus'] = finalStatus;
      await _ch.invokeMethod('stopSportForeground', args.isEmpty ? null : args);
    } catch (_) {
      // best-effort
    }
  }

  static Future<bool> isRunning() async {
    if (!_supported) return false;
    try {
      final v = await _ch.invokeMethod('isSportForegroundRunning');
      return v == true;
    } catch (_) {
      return false;
    }
  }

  /// iOS-only: get the latest computed sport metrics from native side.
  ///
  /// Android returns null (native metrics are persisted into DB directly).
  static Future<Map<String, dynamic>?> getSnapshot(int recordId) async {
    if (!Platform.isIOS) return null;
    try {
      final v = await _ch.invokeMethod('getSportSnapshot', <String, dynamic>{'recordId': recordId});
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    } catch (_) {
      return null;
    }
  }
}
