import 'package:flutter/services.dart';
import 'package:quote_app/utils/debug_logger.dart';

class NativeWm {
  static const _ch = MethodChannel('com.example.quote_app/sys');

  static Future<bool> cancelByUid(String uid) async {
    try {
      final ret = await _ch.invokeMethod('cancelWmByUid', {'uid': uid});
      return ret == true;
    } catch (_) { return false; }
  }

    static Future<bool> cancelWmByUidBoth(String uid) async {
    try {
      const ch = MethodChannel('native.scheduler');
      final ret = await ch.invokeMethod('cancelWmByUidBoth', {'uid': uid});
      return ret == true;
    } catch (_) { return false; }
  }
}


  