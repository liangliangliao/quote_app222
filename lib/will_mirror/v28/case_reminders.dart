import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../platform/native_scheduler.dart';

class WmCaseLink {
  const WmCaseLink(
      {required this.caseId,
      required this.snapshotId,
      required this.triggerId,
      this.principleId});
  final String caseId, snapshotId, triggerId;
  final String? principleId;
  String encode() => Uri(
          scheme: 'willmirror',
          host: 'case',
          path: '/$caseId',
          queryParameters: {
            'snapshot': snapshotId,
            'trigger': triggerId,
            if (principleId != null) 'principle': principleId!
          }).toString();
  static WmCaseLink? parse(String? raw) {
    try {
      final u = Uri.parse(raw ?? '');
      if (u.scheme != 'willmirror' ||
          u.host != 'case' ||
          u.pathSegments.length != 1) return null;
      final id = u.pathSegments.single,
          s = u.queryParameters['snapshot'],
          t = u.queryParameters['trigger'],
          p = u.queryParameters['principle'];
      bool valid(String? v) =>
          v != null && RegExp(r'^[A-Za-z0-9_-]{1,180}$').hasMatch(v);
      if (!valid(id) || !valid(s) || !valid(t) || (p != null && !valid(p)))
        return null;
      return WmCaseLink(
          caseId: id, snapshotId: s!, triggerId: t!, principleId: p);
    } catch (_) {
      return null;
    }
  }
}

class WmReminders {
  WmReminders({FlutterLocalNotificationsPlugin? plugin})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin plugin;
  static const title = '意志之镜 · 现场核实';
  static const body = '有一个你安排的回顾时刻。打开后核实现实条件，也可以暂停。';
  static int notificationId(String caseId) {
    final bytes = sha256.convert(utf8.encode('will_mirror.v28.$caseId')).bytes;
    return 0x50000000 | ((bytes[0] << 16) | (bytes[1] << 8) | bytes[2]);
  }

  Future<String> schedule(WmCaseLink link, DateTime at) async {
    if (!at.isAfter(DateTime.now())) return '时间已过，未安排提醒';
    if (!await NativeScheduler.requestNotificationPermissionSystem())
      return '通知权限未开启；仍可手动进入现场卡';
    try {
      await plugin.zonedSchedule(
          notificationId(link.caseId),
          title,
          body,
          tz.TZDateTime.from(at.toUtc(), tz.UTC),
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  'will_mirror_case_v28', '意志之镜课题提醒',
                  channelDescription: '仅在本人选择时提醒，不展示私密课题',
                  importance: Importance.defaultImportance,
                  priority: Priority.defaultPriority,
                  visibility: NotificationVisibility.private)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: link.encode());
      return '已登记系统提醒；实际送达、看见和影响仍未知。省电或强制停止可能延迟。';
    } catch (_) {
      return '系统未能登记提醒；已保存的现场卡仍可离线打开';
    }
  }

  Future<void> cancel(String caseId) async {
    try {
      await plugin.cancel(notificationId(caseId));
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      for (final r in await plugin.pendingNotificationRequests()) {
        if (WmCaseLink.parse(r.payload) != null) await plugin.cancel(r.id);
      }
      for (final r in await plugin.getActiveNotifications()) {
        if (r.channelId == 'will_mirror_case_v28' && r.id != null)
          await plugin.cancel(r.id!);
      }
    } catch (_) {}
  }
}
