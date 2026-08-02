import '../data/dao.dart';
import '../data/db.dart';
import '../services/notification_service.dart';
import '../services/scheduler_service.dart';
import 'xiangji_dao.dart';
import 'xiangji_models.dart';

class XiangjiReminderService {
  XiangjiReminderService({XiangjiGoalMentorDao? dao})
      : _dao = dao ?? XiangjiGoalMentorDao();

  final XiangjiGoalMentorDao _dao;

  Future<XiangjiReminderSettings> update({
    required bool enabled,
    required String timeOfDay,
    String quietStart = '22:00',
    String quietEnd = '08:00',
  }) async {
    var current = await _dao.reminderSettings();
    var taskUid = current.taskUid;
    final normalizedTime = _outsideQuietHours(
      timeOfDay,
      quietStart: quietStart,
      quietEnd: quietEnd,
    );

    if (taskUid.isEmpty || await TaskDao().getByUid(taskUid) == null) {
      taskUid = await TaskDao().create(
        name: '向己 · 目标守护',
        type: 'xiangji_goal',
        status: enabled ? 'on' : 'off',
        prompt: '只提醒用户自己的目标原话、为什么、今日一步或成长证据；不比较、不羞辱。',
        startTime: normalizedTime,
        freqType: 'daily',
      );
    } else {
      try {
        await SchedulerService.cancelNextForTask(taskUid);
      } catch (_) {}
      await TaskDao().update(taskUid, <String, dynamic>{
        'status': enabled ? 'on' : 'off',
        'start_time': normalizedTime,
        'freq_type': 'daily',
        'name': '向己 · 目标守护',
      });
    }

    current = XiangjiReminderSettings(
      enabled: enabled,
      timeOfDay: normalizedTime,
      quietStart: quietStart,
      quietEnd: quietEnd,
      taskUid: taskUid,
    );
    await _dao.saveReminderSettings(current);
    if (enabled) {
      await NotificationService.request();
      await SchedulerService.scheduleNextForTask(taskUid);
    }
    return current;
  }

  Future<void> sendPreview() async {
    final content = await _dao.reminderContent();
    if (content == null || content.trim().isEmpty) return;
    await NotificationService.show(
      title: '向己 · 记得你重视的方向',
      body: content,
      payload: 'xiangji_goal',
    );
  }

  Future<void> cancelAndRemoveTask() async {
    final settings = await _dao.reminderSettings();
    if (settings.taskUid.isEmpty) return;
    try {
      await TaskDao().update(settings.taskUid, <String, dynamic>{
        'status': 'off',
      });
    } catch (_) {}
    try {
      await SchedulerService.cancelNextForTask(settings.taskUid);
    } catch (_) {}
    try {
      final db = await AppDatabase.instance();
      for (final table in <String>[
        'logs',
        'quotes',
        'notify_guard',
        'notify_failures',
      ]) {
        try {
          await db.delete(
            table,
            where: 'task_uid = ?',
            whereArgs: <Object?>[settings.taskUid],
          );
        } catch (_) {}
      }
    } catch (_) {}
    try {
      await TaskDao().delete(settings.taskUid);
    } catch (_) {}
  }

  String _outsideQuietHours(
    String selected, {
    required String quietStart,
    required String quietEnd,
  }) {
    final minute = _minutes(selected);
    final start = _minutes(quietStart);
    final end = _minutes(quietEnd);
    final inQuiet = start <= end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
    return inQuiet ? quietEnd : selected;
  }

  int _minutes(String value) {
    final parts = value.split(':');
    final hour = parts.isEmpty ? 9 : int.tryParse(parts.first) ?? 9;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    final safeHour = hour.clamp(0, 23).toInt();
    final safeMinute = minute.clamp(0, 59).toInt();
    return safeHour * 60 + safeMinute;
  }
}
