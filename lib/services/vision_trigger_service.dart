import 'dart:convert';

import '../data/dao.dart';
import 'scheduler_service.dart';
// Db import is unused but retained for potential future extension

/// A helper service to synchronise vision triggers with scheduled tasks.
///
/// Each enabled time-based trigger (type = 'time_daily') is mapped onto a
/// dedicated task of type `vision_focus`. Tasks are scheduled using
/// SchedulerService to fire daily at the configured time. When triggers
/// are disabled or removed, the corresponding tasks are cancelled and
/// deleted. This keeps the notification/worker layer consistent with
/// the user's configured execution intentions.
class VisionTriggerService {
  /// Synchronise all vision triggers in the database to the tasks table.
  ///
  /// - For each active `time_daily` trigger (enabled both at row and config level
  ///   with a valid HH:mm time), a task of type `vision_focus` will be
  ///   created or updated. The task's `start_time` is set to the HH:mm
  ///   extracted from the trigger config and its `freq_type` to 'daily'.
  ///   The `freq_custom` JSON field stores the originating trigger id
  ///   under the key `vision_trigger_id` to allow reverse lookup.
  /// - For triggers that are disabled (either via the row `enabled` column
  ///   or a config `enabled` flag), any existing tasks originating from
  ///   that trigger will be deleted and their scheduled runs cancelled.
  /// - For tasks of type `vision_focus` that no longer correspond to any
  ///   existing trigger, the tasks will likewise be cancelled and deleted.
  static Future<void> syncTriggersToTasks() async {
    final visionDao = VisionDao();
    final taskDao = TaskDao();

    // Load all triggers from DB
    final triggerRows = await visionDao.listTriggers();
    // Load all tasks to identify existing vision_focus entries
    final allTasks = await taskDao.all();

    // Build a map of existing vision_focus tasks keyed by vision_trigger_id
    final Map<String, Map<String, dynamic>> existingTasksByTrigger = {};
    for (final t in allTasks) {
      final type = (t['type'] ?? '').toString();
      if (type != 'vision_focus') continue;
      final freqCustom = (t['freq_custom'] ?? '').toString();
      String trigId = '';
      if (freqCustom.isNotEmpty) {
        try {
          final obj = jsonDecode(freqCustom);
          if (obj is Map<String, dynamic>) {
            trigId = (obj['vision_trigger_id'] ?? '').toString();
          }
        } catch (_) {
          // ignore parse errors
        }
      }
      if (trigId.isNotEmpty) {
        existingTasksByTrigger[trigId] = t;
      }
    }

    // We'll collect all trigger ids that are considered valid/enabled. After
    // processing we remove tasks not in this set.
    final Set<String> validTriggerIds = {};

    // Iterate through triggers and process time_daily types
    for (final row in triggerRows) {
      final id = (row['id'] ?? '').toString();
      final type = (row['type'] ?? '').toString();
      final cfgStr = (row['config'] ?? '').toString();
      final rowEnabled = (row['enabled'] ?? 1) != 0;
      if (id.isEmpty || type != 'time_daily') continue;
      // Parse config
      Map<String, dynamic> cfg = const {};
      if (cfgStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(cfgStr);
          if (decoded is Map<String, dynamic>) {
            cfg = decoded;
          }
        } catch (_) {}
      }
      final time = (cfg['time'] ?? '').toString().trim();
      // Determine if the trigger is enabled based on both row and cfg flags
      bool cfgEnabled;
      final e = cfg['enabled'];
      if (e is bool) {
        cfgEnabled = e;
      } else if (e is num) {
        cfgEnabled = e != 0;
      } else {
        // If not specified, default to true
        cfgEnabled = true;
      }
      final isEnabled = rowEnabled && cfgEnabled && time.isNotEmpty;
      if (isEnabled) {
        validTriggerIds.add(id);
        // Determine the task name; use the then_text as a descriptive label
        final thenText = (row['then_text'] ?? '愿景提醒').toString().trim();
        final name = thenText.isNotEmpty ? thenText : '愿景提醒';
        final freqCustomJson = jsonEncode({'vision_trigger_id': id});
        final existing = existingTasksByTrigger[id];
        if (existing != null) {
          final uid = existing['task_uid'].toString();
          // Update the existing task's schedule and ensure it's enabled
          final patch = <String, dynamic>{
            'name': name,
            'type': 'vision_focus',
            'status': 'on',
            'start_time': time,
            'freq_type': 'daily',
            'freq_weekday': null,
            'freq_day_of_month': null,
            'freq_custom': freqCustomJson,
          };
          await taskDao.update(uid, patch);
          // Reschedule this task
          try {
            await SchedulerService.cancelNextForTask(uid);
          } catch (_) {}
          try {
            await SchedulerService.scheduleNextForTask(uid);
          } catch (_) {}
        } else {
          // Create a new task for this trigger
          final newUid = await taskDao.create(
            name: name,
            type: 'vision_focus',
            status: 'on',
            prompt: '',
            avatarPath: '',
            startTime: time,
            freqType: 'daily',
            freqWeekday: null,
            freqDayOfMonth: null,
            freqCustom: freqCustomJson,
          );
          // Schedule it immediately
          try {
            await SchedulerService.scheduleNextForTask(newUid);
          } catch (_) {}
        }
      } else {
        // Disabled trigger: cancel and remove any corresponding task
        final existing = existingTasksByTrigger[id];
        if (existing != null) {
          final uid = existing['task_uid'].toString();
          try {
            await SchedulerService.cancelNextForTask(uid);
          } catch (_) {}
          await taskDao.delete(uid);
        }
      }
    }

    // Clean up any vision_focus tasks whose trigger id is not in validTriggerIds
    for (final t in allTasks) {
      final tType = (t['type'] ?? '').toString();
      if (tType != 'vision_focus') continue;
      String trigId = '';
      final freqCustomStr = (t['freq_custom'] ?? '').toString();
      if (freqCustomStr.isNotEmpty) {
        try {
          final obj = jsonDecode(freqCustomStr);
          if (obj is Map<String, dynamic>) {
            trigId = (obj['vision_trigger_id'] ?? '').toString();
          }
        } catch (_) {}
      }
      if (trigId.isEmpty || !validTriggerIds.contains(trigId)) {
        final uid = t['task_uid'].toString();
        try {
          await SchedulerService.cancelNextForTask(uid);
        } catch (_) {}
        await taskDao.delete(uid);
      }
    }
  }
}