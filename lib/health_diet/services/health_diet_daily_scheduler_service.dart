import 'dart:convert';
import 'package:workmanager/workmanager.dart';

import '../../data/kv_dao.dart';
import '../../utils/debug_logger.dart';
import '../../services/notification_service.dart';
import '../../platform/native_scheduler.dart';
import '../repositories/health_diet_agent_repository.dart';
import '../repositories/health_profile_repository.dart';
import 'health_diet_autopilot_service.dart';
import 'health_diet_settings_service.dart';

class HealthDietScheduleSlot {
  const HealthDietScheduleSlot({
    required this.id,
    required this.label,
    required this.taskType,
    required this.hour,
    required this.minute,
    required this.reason,
    this.weekday,
    this.requiresReview = false,
  });

  final String id;
  final String label;
  final String taskType;
  final int hour;
  final int minute;
  final int? weekday;
  final String reason;
  final bool requiresReview;

  String get timeText => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class HealthDietScheduleRunResult {
  const HealthDietScheduleRunResult({
    required this.slot,
    required this.ran,
    required this.message,
    this.autopilotResult,
  });

  final HealthDietScheduleSlot slot;
  final bool ran;
  final String message;
  final HealthDietAutopilotResult? autopilotResult;
}

class HealthDietScheduleTickReport {
  const HealthDietScheduleTickReport({
    required this.enabled,
    required this.checkedAt,
    required this.results,
    required this.scheduledCount,
  });

  final bool enabled;
  final DateTime checkedAt;
  final List<HealthDietScheduleRunResult> results;
  final int scheduledCount;

  bool get hasRun => results.any((e) => e.ran);

  String get summary {
    if (!enabled) return '自动定时膳食 Agent 未开启。';
    if (results.isEmpty) return '暂无到点任务，已保持下一轮定时计划。';
    final ran = results.where((e) => e.ran).length;
    return '已检查定时托管任务，执行 $ran 项，已安排 $scheduledCount 个后续任务。';
  }
}

/// 每日定时膳食 Agent。
///
/// 目标：把健康饮食模块从“用户打开页面才生成方案”，升级为“按早餐/午餐/晚餐/晚间复盘等关键时间点自动巡检”。
/// 由于手机系统限制，后台任务是 best-effort：
/// - App 打开健康饮食模块时会立即补跑已经到点但未执行的任务；
/// - Android 后台通过 Workmanager 注册一组一日内任务；
/// - 每次后台任务执行后会自动注册下一天/下一周的对应任务。
class HealthDietDailySchedulerService {
  HealthDietDailySchedulerService({
    KeyValueDao? kvDao,
    HealthDietSettingsService? settingsService,
    HealthDietAutopilotService? autopilotService,
    HealthDietAgentRepository? agentRepository,
  })  : _kv = kvDao ?? KeyValueDao(),
        _settings = settingsService ?? HealthDietSettingsService(),
        _autopilot = autopilotService ?? HealthDietAutopilotService(),
        _agentRepo = agentRepository ?? HealthDietAgentRepository();

  final KeyValueDao _kv;
  final HealthDietSettingsService _settings;
  final HealthDietAutopilotService _autopilot;
  final HealthDietAgentRepository _agentRepo;

  static const workJob = 'health_diet_agent';
  static const workTaskName = 'health_diet_agent_task';
  static const _nativeNotificationBaseId = 940000;

  static const List<HealthDietScheduleSlot> defaultSlots = [
    HealthDietScheduleSlot(
      id: 'morning_plan',
      label: '早晨今日饮食计划',
      taskType: 'morning_plan',
      hour: 8,
      minute: 0,
      reason: '根据睡眠、步数、健康目标和昨日/近期饮食，自动安排早餐、午餐、晚餐结构。',
    ),
    HealthDietScheduleSlot(
      id: 'breakfast_check',
      label: '早餐记录与能量检查',
      taskType: 'meal_reminder',
      hour: 10,
      minute: 30,
      reason: '检查是否记录早餐；如果没有记录，提醒先补一条最小记录，避免后续方案失真。',
    ),
    HealthDietScheduleSlot(
      id: 'lunch_plan',
      label: '午餐动态安排',
      taskType: 'meal_plan',
      hour: 12,
      minute: 0,
      reason: '根据早餐和上午身体状态，刷新午餐应补什么、少选什么。',
    ),
    HealthDietScheduleSlot(
      id: 'snack_check',
      label: '下午加餐与甜饮风险检查',
      taskType: 'meal_reminder',
      hour: 15,
      minute: 30,
      reason: '检查疲劳、甜饮、加餐冲动和蛋白/纤维缺口，给出低负担加餐建议。',
    ),
    HealthDietScheduleSlot(
      id: 'dinner_plan',
      label: '晚餐恢复型安排',
      taskType: 'meal_plan',
      hour: 18,
      minute: 0,
      reason: '根据全天已吃、步数、运动和高盐/高糖风险，动态调整晚餐。',
    ),
    HealthDietScheduleSlot(
      id: 'evening_review',
      label: '晚间饮食复盘',
      taskType: 'diet_review',
      hour: 21,
      minute: 30,
      reason: '合并今日饮食、营养 API、Health Connect 和 AI 二次审查，形成明日最小改变。',
      requiresReview: true,
    ),
    HealthDietScheduleSlot(
      id: 'weekly_report',
      label: '每周健康饮食趋势报告',
      taskType: 'weekly_report',
      hour: 21,
      minute: 0,
      weekday: DateTime.sunday,
      reason: '每周识别反复出现的高糖、高盐、早餐缺失、低蛋白、低蔬菜等模式。',
      requiresReview: true,
    ),
  ];

  Future<HealthDietScheduleTickReport> tick({
    String userId = HealthProfileRepository.defaultUserId,
    bool forceDue = false,
    bool runDue = false,
    int maxCatchUpRuns = 1,
  }) async {
    final checkedAt = DateTime.now();
    final settings = await _settings.load();
    final enabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentDailyScheduleEnabled]);
    if (!enabled) {
      await _cancelAllSchedules(cancelWorker: true);
      await DLog.i('health_diet.scheduler', '每日定时膳食 Agent 未开启，跳过 tick。');
      return HealthDietScheduleTickReport(enabled: false, checkedAt: checkedAt, results: const [], scheduledCount: 0);
    }
    await _agentRepo.ensureDefaultTasks(userId: userId, goalId: (await _agentRepo.activeGoal(userId: userId))?.id);
    final results = <HealthDietScheduleRunResult>[];
    if (runDue) {
      // 只补跑最近到点的少量任务，避免用户打开页面时把 08:00、10:30、12:00...
      // 多个 slot 全部串行执行，从而触发大量 API/AI 调用、日志刷新和页面长时间转圈。
      final due = <HealthDietScheduleSlot>[];
      for (final slot in defaultSlots) {
        if (!_isSlotDue(slot, checkedAt)) continue;
        final key = _lastRunKey(userId, slot, checkedAt);
        final last = await _kv.getString(key);
        if (last != null && !forceDue) continue;
        due.add(slot);
      }
      due.sort((a, b) => _slotTimeToday(b, checkedAt).compareTo(_slotTimeToday(a, checkedAt)));
      final limit = maxCatchUpRuns.clamp(0, defaultSlots.length).toInt();
      for (final slot in due.take(limit)) {
        results.add(await runSlot(slot.id, userId: userId, force: true, from: 'app_tick'));
      }
    }
    final scheduled = await ensureScheduled(userId: userId);
    return HealthDietScheduleTickReport(enabled: true, checkedAt: checkedAt, results: results, scheduledCount: scheduled);
  }

  Future<int> ensureScheduled({String userId = HealthProfileRepository.defaultUserId}) async {
    final settings = await _settings.load();
    final enabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentDailyScheduleEnabled]);
    if (!enabled) {
      await _cancelAllSchedules(cancelWorker: true);
      return 0;
    }
    var count = 0;
    for (final slot in defaultSlots) {
      try {
        await _scheduleNext(slot, userId: userId);
        count++;
      } catch (e, st) {
        await DLog.e('health_diet.scheduler.schedule', 'slot=${slot.id} $e\n$st');
      }
    }
    return count;
  }

  /// 设置页保存后立即同步任务，避免“开关已保存但要等下次启动才生效”。
  Future<int> syncSchedules({String userId = HealthProfileRepository.defaultUserId}) async {
    final settings = await _settings.load();
    final scheduleEnabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentDailyScheduleEnabled]);
    if (!scheduleEnabled) {
      await _cancelAllSchedules(cancelWorker: true);
      return 0;
    }
    if (!_settings.isEnabledValue(settings[HealthDietSettingsService.agentScheduleNotifyEnabled])) {
      await _cancelNativeReminders();
    }
    return ensureScheduled(userId: userId);
  }

  Future<HealthDietScheduleRunResult> runScheduledSlot(
    String slotId, {
    String userId = HealthProfileRepository.defaultUserId,
  }) async {
    final result = await runSlot(slotId, userId: userId, force: true, from: 'workmanager');
    final slot = _slotById(slotId);
    if (slot != null) {
      try {
        await _scheduleNext(slot, userId: userId, after: DateTime.now().add(const Duration(minutes: 1)));
      } catch (_) {}
    }
    return result;
  }

  Future<HealthDietScheduleRunResult> runSlot(
    String slotId, {
    String userId = HealthProfileRepository.defaultUserId,
    bool force = false,
    String from = 'manual',
  }) async {
    final slot = _slotById(slotId) ?? defaultSlots.first;
    final now = DateTime.now();
    final settings = await _settings.load();
    final enabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentDailyScheduleEnabled]);
    if (!enabled && !force) {
      return HealthDietScheduleRunResult(slot: slot, ran: false, message: '自动定时膳食 Agent 未开启。');
    }
    final runKey = _lastRunKey(userId, slot, now);
    final already = await _kv.getString(runKey);
    if (already != null && !force) {
      return HealthDietScheduleRunResult(slot: slot, ran: false, message: '${slot.label} 今日已执行。');
    }

    await _kv.setString(runKey, now.toIso8601String());
    await DLog.i('health_diet.scheduler.run', 'slot=${slot.id} from=$from reason=${slot.reason}');

    final autopilot = await _autopilot.run(userId: userId, force: true);
    await _agentRepo.upsertMemory(
      userId: userId,
      memoryType: 'schedule',
      memoryKey: 'last_${slot.id}',
      memoryValue: '${slot.label} 已执行；焦点：${autopilot.plan.focusTitle}；策略：${autopilot.plan.next24hStrategy}',
      confidence: 0.88,
      evidence: {
        'slot': slot.id,
        'label': slot.label,
        'reason': slot.reason,
        'from': from,
        'autopilot': autopilot.toJson(),
      },
    );
    await _notifyIfNeeded(slot, autopilot, settings);
    return HealthDietScheduleRunResult(
      slot: slot,
      ran: true,
      message: '${slot.label} 已执行：${autopilot.plan.focusTitle}',
      autopilotResult: autopilot,
    );
  }

  HealthDietScheduleSlot? _slotById(String id) {
    for (final slot in defaultSlots) {
      if (slot.id == id) return slot;
    }
    return null;
  }

  bool _isSlotDue(HealthDietScheduleSlot slot, DateTime now) {
    if (slot.weekday != null && now.weekday != slot.weekday) return false;
    final at = DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
    return !now.isBefore(at) && now.difference(at) < const Duration(hours: 8);
  }

  DateTime _slotTimeToday(HealthDietScheduleSlot slot, DateTime now) => DateTime(now.year, now.month, now.day, slot.hour, slot.minute);

  Future<void> _scheduleNext(HealthDietScheduleSlot slot, {required String userId, DateTime? after}) async {
    final now = after ?? DateTime.now();
    var next = DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
    if (slot.weekday != null) {
      while (next.weekday != slot.weekday || !next.isAfter(now.add(const Duration(minutes: 1)))) {
        next = next.add(const Duration(days: 1));
      }
    } else if (!next.isAfter(now.add(const Duration(minutes: 1)))) {
      next = next.add(const Duration(days: 1));
    }
    final delay = next.difference(now);
    final unique = 'health_diet_agent_${slot.id}_$userId';
    try {
      await Workmanager().registerOneOffTask(
        unique,
        workTaskName,
        initialDelay: delay < const Duration(minutes: 15) ? const Duration(minutes: 15) : delay,
        inputData: {
          'job': workJob,
          'slot': slot.id,
          'user_id': userId,
          'scheduled_for': next.toIso8601String(),
        },
        existingWorkPolicy: ExistingWorkPolicy.replace,
        tag: 'health_diet_agent',
      );
      await _kv.setString('health_diet_agent_next_${slot.id}_$userId', next.toIso8601String());
      // 定时注册是正常维护动作，不写成功日志，避免日志页清空后又被 7 个 slot 的注册记录刷满。
    } catch (e, st) {
      await DLog.e('health_diet.scheduler.schedule', 'Workmanager 注册失败 slot=${slot.id}: $e\n$st');
    }

    // WorkManager 在部分定制 ROM 上可能被推迟或不执行。通知开关打开时，再注册一个
    // 不依赖 Flutter 进程的原生 AlarmManager 提醒；完整 AI 巡检仍由 WorkManager 执行。
    final settings = await _settings.load();
    final notifyEnabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentScheduleNotifyEnabled]);
    final nativeId = _nativeIdFor(slot);
    if (!notifyEnabled) {
      try { await NativeScheduler.cancel(nativeId); } catch (_) {}
      return;
    }
    try {
      await NativeScheduler.scheduleExactAt(
        id: nativeId,
        epochMs: next.millisecondsSinceEpoch,
        payload: {
          'module': 'health_diet',
          'type': 'health_diet_agent',
          'slot': slot.id,
          'target': _targetForSlot(slot),
          'title': '健康饮食 Agent：${slot.label}',
          'body': '到时间了，点击查看本次饮食安排或完成记录。',
          'hour': slot.hour,
          'minute': slot.minute,
          if (slot.weekday != null) 'weekday': slot.weekday,
          'user_id': userId,
          'scheduled_for': next.toIso8601String(),
        },
      );
    } catch (e) {
      await DLog.w('health_diet.scheduler.native', '原生提醒注册失败 slot=${slot.id}: $e');
    }
  }

  Future<void> _notifyIfNeeded(HealthDietScheduleSlot slot, HealthDietAutopilotResult result, Map<String, String> settings) async {
    final enabled = _settings.isEnabledValue(settings[HealthDietSettingsService.agentScheduleNotifyEnabled]);
    if (!enabled) return;
    try {
      final title = '健康饮食 Agent：${slot.label}';
      final body = _notificationBody(slot, result);
      final index = defaultSlots.indexWhere((e) => e.id == slot.id);
      final id = _nativeNotificationBaseId + (index < 0 ? 0 : index);
      await NotificationService.show(
        id: id,
        title: title,
        body: body,
        payload: _notificationPayload(slot, result),
      );
    } catch (e) {
      await DLog.w('health_diet.scheduler.notify', '通知发送失败：$e');
    }
  }


  String _notificationPayload(HealthDietScheduleSlot slot, HealthDietAutopilotResult result) {
    final target = _targetForSlot(slot);
    return jsonEncode({
      'type': 'health_diet_agent',
      'slot': slot.id,
      'target': target,
      'label': slot.label,
      'generated_at': DateTime.now().toIso8601String(),
      'focus': result.plan.focusTitle,
    });
  }

  String _targetForSlot(HealthDietScheduleSlot slot) {
    switch (slot.id) {
      case 'breakfast_check':
        return 'share';
      case 'evening_review':
        return 'review';
      case 'weekly_report':
        return 'weekly';
      case 'morning_plan':
      case 'lunch_plan':
      case 'snack_check':
      case 'dinner_plan':
        return 'today_plan';
      default:
        return 'expert';
    }
  }

  int _nativeIdFor(HealthDietScheduleSlot slot) {
    final index = defaultSlots.indexWhere((e) => e.id == slot.id);
    return _nativeNotificationBaseId + (index < 0 ? 0 : index);
  }

  Future<void> _cancelNativeReminders() async {
    for (final slot in defaultSlots) {
      try { await NativeScheduler.cancel(_nativeIdFor(slot)); } catch (_) {}
    }
  }

  Future<void> _cancelAllSchedules({required bool cancelWorker}) async {
    if (cancelWorker) {
      try { await Workmanager().cancelByTag('health_diet_agent'); } catch (_) {}
    }
    await _cancelNativeReminders();
  }

  String _notificationBody(HealthDietScheduleSlot slot, HealthDietAutopilotResult result) {
    final plan = result.plan;
    switch (slot.id) {
      case 'breakfast_check':
        return 'Agent 定时巡检结果：${plan.microActionTitle}';
      case 'lunch_plan':
        return 'Agent 定时巡检结果：${plan.recipeGoal}';
      case 'snack_check':
        return 'Agent 定时巡检结果：${plan.microActionTitle}';
      case 'dinner_plan':
        return 'Agent 定时巡检结果：${plan.recipeGoal}';
      case 'evening_review':
        return 'Agent 定时巡检结果：${plan.next24hStrategy}';
      case 'weekly_report':
        return 'Agent 定时巡检结果：${plan.focusTitle}';
      default:
        return 'Agent 定时巡检结果：${plan.focusTitle}';
    }
  }

  String _lastRunKey(String userId, HealthDietScheduleSlot slot, DateTime dateTime) {
    final d = _dateKey(dateTime);
    return 'health_diet_agent_run_${slot.id}_${userId}_$d';
  }

  String _dateKey(DateTime v) => '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
}
