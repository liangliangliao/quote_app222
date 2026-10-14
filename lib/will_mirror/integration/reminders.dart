import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MirrorLink {
  const MirrorLink(
      {required this.caseId,
      this.triggerId,
      this.planId,
      this.principleId,
      this.runId,
      this.sceneId,
      this.version,
      this.jobId,
      this.step = 5});
  final String caseId;
  final String? triggerId, planId, principleId, runId, sceneId;
  final int? version, jobId;
  final int step;
  String encode() => Uri(
          scheme: 'willmirror',
          host: 'case',
          path: '/$caseId',
          queryParameters: {
            'step': '$step',
            if (triggerId != null) 'trigger': triggerId!,
            if (planId != null) 'plan': planId!,
            if (principleId != null) 'principle': principleId!,
            if (runId != null) 'run': runId!,
            if (sceneId != null) 'scene': sceneId!,
            if (version != null) 'version': '$version',
            if (jobId != null) 'job': '$jobId'
          }).toString();
  static MirrorLink? parse(String? value) {
    if (value == null || value.length > 2000) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'willmirror' ||
        uri.host != 'case' ||
        uri.pathSegments.length != 1 ||
        uri.pathSegments.first.isEmpty) return null;
    final q = uri.queryParameters;
    final step = int.tryParse(q['step'] ?? '5');
    if (step == null || step < 0 || step > 6) return null;
    return MirrorLink(
        caseId: uri.pathSegments.first,
        triggerId: q['trigger'],
        planId: q['plan'],
        principleId: q['principle'],
        runId: q['run'],
        sceneId: q['scene'],
        version: int.tryParse(q['version'] ?? ''),
        jobId: int.tryParse(q['job'] ?? ''),
        step: step);
  }
}

abstract interface class MirrorReminders {
  Future<bool> requestPermission();
  Future<bool> schedule(int id, DateTime at, MirrorLink link);
  Future<void> cancel(int id);
  Future<Set<int>> pending();
}

class AndroidMirrorReminders implements MirrorReminders {
  AndroidMirrorReminders() {
    tzdata.initializeTimeZones();
  }
  final plugin = FlutterLocalNotificationsPlugin();
  @override
  Future<bool> requestPermission() async {
    try {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> schedule(int id, DateTime at, MirrorLink link) async {
    if (!at.isAfter(DateTime.now())) return false;
    try {
      // Host owns plugin initialization and notification-tap routing. Do not
      // replace its callback or request exact-alarm access for this module.
      await plugin.zonedSchedule(
          id,
          '意志之镜',
          '到了你选择的回看时间，打开课题核实当前条件。',
          tz.TZDateTime.from(at.toUtc(), tz.UTC),
          const NotificationDetails(
              android: AndroidNotificationDetails('will_mirror_v28', '意志之镜课题提醒',
                  channelDescription: '自愿设置的课题回看',
                  importance: Importance.defaultImportance,
                  priority: Priority.defaultPriority,
                  visibility: NotificationVisibility.private,
                  playSound: false,
                  enableVibration: false)),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: link.encode());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancel(int id) => plugin.cancel(id);
  @override
  Future<Set<int>> pending() async {
    try {
      return (await plugin.pendingNotificationRequests())
          .map((e) => e.id)
          .toSet();
    } catch (_) {
      return {};
    }
  }
}
