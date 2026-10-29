import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'self_os_principle_link.dart';

/// Shares the app's initialized notification channel without replacing its tap
/// callback. Scheduling never records delivery, recall, or application.
class SelfOsExperienceReminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static int idFor(String applicationId) {
    final bytes = sha256.convert(utf8.encode(applicationId)).bytes;
    return 0x3a000000 | bytes[0] << 16 | bytes[1] << 8 | bytes[2];
  }

  static Future<bool> schedule(
      String applicationId, OsPrincipleLink link, DateTime at) async {
    if (!Platform.isAndroid || !at.isAfter(DateTime.now())) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (await android?.areNotificationsEnabled() != true) return false;
    await _plugin.zonedSchedule(
        idFor(applicationId),
        '回来核对这次情境',
        '你为自己留了一条经验提示。可查看，也可以跳过。',
        tz.TZDateTime.from(at, tz.UTC),
        const NotificationDetails(
            android: AndroidNotificationDetails('self_os_experience', '经验提示',
                channelDescription: '仅在你主动设置时提醒核对，不显示个人心理或能力内容',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
                visibility: NotificationVisibility.private)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: link.encode());
    return true;
  }

  static Future<void> cancel(String applicationId) async {
    try {
      await _plugin.cancel(idFor(applicationId));
    } catch (_) {
      // A generic system notification may remain if the platform is unavailable;
      // opening it still revalidates consent, evidence, status and exact IDs.
    }
  }
}
