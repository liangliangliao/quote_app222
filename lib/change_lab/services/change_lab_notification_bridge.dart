import '../../services/notification_service.dart';
import '../models/change_models.dart';

class ChangeLabNotificationBridge {
  static Future<int> syncDueReminders({
    required List<ReminderSchedule> schedules,
    required bool Function(String reminderId) hasDelivered,
    required void Function(String reminderId) onDelivered,
    required ChangeConcept Function(String conceptId) conceptById,
    required ChangeTask Function(String conceptId, String taskId) taskById,
  }) async {
    var delivered = 0;
    for (final schedule in schedules) {
      if (hasDelivered(schedule.id)) continue;
      final concept = conceptById(schedule.conceptId);
      final task = taskById(schedule.conceptId, schedule.taskId);
      final title = '改变实验室｜${concept.title}';
      final body = '${_label(schedule.type)}：${task.title} · ${schedule.message}';
      try {
        await NotificationService.show(
          id: _stableId(schedule.id),
          title: title,
          body: body,
          payload: 'change_lab:${schedule.id}',
        );
        onDelivered(schedule.id);
        delivered += 1;
      } catch (_) {
        // Ignore notification errors; the in-app reminder center remains the source of truth.
      }
    }
    return delivered;
  }

  static int _stableId(String value) {
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = 0x1fffffff & (hash + code);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash & 0x7fffffff;
  }

  static String _label(ReminderType type) {
    switch (type) {
      case ReminderType.pre:
        return '预提醒';
      case ReminderType.moment:
        return '临场提醒';
      case ReminderType.interrupt:
        return '中断提醒';
      case ReminderType.nextDay:
        return '次日追问';
    }
  }
}
