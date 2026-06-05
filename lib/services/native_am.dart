import 'package:flutter/services.dart';
import 'package:quote_app/utils/debug_logger.dart';

class NativeAm {
  static const _ch = MethodChannel('com.example.quote_app/sys');
  static Future<bool> cancelExactById(String uid, String? runKey) async {
    try {
      await DLog.i('SCH', '【Dart→原生】AM 取消请求 uid='+uid+' run='+(runKey ?? ''));
      final ret = await _ch.invokeMethod('cancelExactById', {'uid': uid, 'runKey': runKey});
      return ret == true;
    } catch (_) { return false; }
  }

    static Future<bool> cancelExactByNext(String uid, int triggerAtMillis) async {
    try {
      const ch = MethodChannel('native.scheduler');
      final ret = await ch.invokeMethod('cancelExactByNext', {
        'uid': uid, 'triggerAtMillis': triggerAtMillis
      });
      return ret == true;
    } catch (_) { return false; }
  }
}


  