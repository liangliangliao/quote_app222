import 'package:flutter/services.dart';
import 'package:quote_app/utils/debug_logger.dart';

class NativeNotify {
  static const _ch = MethodChannel('com.example.quote_app/notify');

  static Future<bool> show({
    required int id,
    required String title,
    required String body,
    String? largeIconPath,
  }) async {
    try {
      await DLog.i('SCH', '【Dart→原生】通知请求 id='+id.toString()+' title='+title);
      final ok = await _ch.invokeMethod<bool>('notify', {
        'id': id,
        'title': title,
        'body': body,
        'largeIconPath': largeIconPath,
      });
      await DLog.i('SCH', '【Dart】原生通知调用完成 id='+id.toString()+' ok='+(ok==true).toString());
      return ok ?? true;
    } on PlatformException {
      await DLog.i('SCH', '【Dart】原生通知调用失败(PlatformException) id='+id.toString());
      return false;
    } on MissingPluginException {
      await DLog.i('SCH', '【Dart】原生通知调用失败(MissingPlugin) id='+id.toString());
      // Fallback: let caller handle or keep old Dart path
      return false;
    }
  }
}