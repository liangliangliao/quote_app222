import '../platform/native_scheduler.dart';
import 'zhixing_dao.dart';
import 'zhixing_extended_models.dart';
import 'zhixing_models.dart';

class ZxAgentScheduleResult {
  const ZxAgentScheduleResult({
    required this.notificationPermission,
    required this.exactAlarmPermission,
    required this.scheduledCount,
  });

  final bool notificationPermission;
  final bool exactAlarmPermission;
  final int scheduledCount;

  bool get ready =>
      notificationPermission && exactAlarmPermission && scheduledCount > 0;
}

/// Action-mentor coordinator. Alarms only remind and route the user; actual
/// reports are generated from submitted feedback so the agent never invents
/// an action result in the background.
class ZxAgentService {
  ZxAgentService({ZxDao? dao}) : _dao = dao ?? ZxDao();

  static const int _alarmBase = 882100;
  static const int _maxScheduledDays = 14;

  final ZxDao _dao;

  ZxAgentScene decide({
    required List<ZxGoal> goals,
    required List<ZxActionPrescription> actions,
    required int selectedThoughtCount,
    required bool hasRecentReport,
    DateTime? now,
  }) {
    final activeGoals = goals.where((goal) => goal.status == 'active');
    if (activeGoals.isEmpty) return ZxAgentScene.setGoal;
    // Thought selection is no longer a prerequisite. With no manual choice,
    // the local matcher recommends a reviewed thought transparently and lets
    // the user accept or change it after seeing a concrete action.
    final active = actions
        .where((action) => action.status == ZxActionStatus.active)
        .toList(growable: false);
    if (active.isEmpty) {
      return hasRecentReport
          ? ZxAgentScene.continueCycle
          : ZxAgentScene.startAction;
    }
    final clock = now ?? DateTime.now();
    final oldest = active.reduce(
      (a, b) => a.updatedAtMs <= b.updatedAtMs ? a : b,
    );
    final age = clock.difference(
      DateTime.fromMillisecondsSinceEpoch(
        oldest.updatedAtMs == 0 ? oldest.createdAtMs : oldest.updatedAtMs,
      ),
    );
    return age >= const Duration(hours: 4)
        ? ZxAgentScene.requestReview
        : ZxAgentScene.trackProgress;
  }

  Future<ZxAgentScene> currentScene({required int selectedThoughtCount}) async {
    final goals = await _dao.goals();
    final actions = await _dao.actions();
    final reports = await _dao.reviewReports(limit: 1);
    return decide(
      goals: goals,
      actions: actions,
      selectedThoughtCount: selectedThoughtCount,
      hasRecentReport: reports.isNotEmpty,
    );
  }

  Future<ZxAgentScheduleResult> enableAndSchedule(
    ZxAgentSettings settings, {
    required int selectedThoughtCount,
  }) async {
    final notificationPermission =
        await NativeScheduler.requestNotificationPermissionSystem();
    final exactPermission = await NativeScheduler.canScheduleExactAlarm();
    final enabled = ZxAgentSettings(
      enabled: true,
      hour: settings.hour,
      minute: settings.minute,
      reviewHour: settings.reviewHour,
      reviewMinute: settings.reviewMinute,
      daysAhead: settings.daysAhead.clamp(1, _maxScheduledDays).toInt(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _dao.saveAgentSettings(enabled);
    if (!notificationPermission || !exactPermission) {
      return ZxAgentScheduleResult(
        notificationPermission: notificationPermission,
        exactAlarmPermission: exactPermission,
        scheduledCount: 0,
      );
    }
    final scene = await currentScene(
      selectedThoughtCount: selectedThoughtCount,
    );
    final count = await _scheduleWindow(enabled, morningScene: scene);
    await _dao.recordAgentEvent(
      scene,
      'schedule_enabled',
      detail: <String, Object?>{'scheduled_count': count},
    );
    return ZxAgentScheduleResult(
      notificationPermission: notificationPermission,
      exactAlarmPermission: exactPermission,
      scheduledCount: count,
    );
  }

  Future<void> disable() async {
    final existing = await _dao.agentSettings();
    for (var day = 0; day < _maxScheduledDays; day++) {
      try {
        await NativeScheduler.cancel(_alarmBase + day * 2);
        await NativeScheduler.cancel(_alarmBase + day * 2 + 1);
      } catch (_) {}
    }
    await _dao.saveAgentSettings(
      ZxAgentSettings(
        enabled: false,
        hour: existing.hour,
        minute: existing.minute,
        reviewHour: existing.reviewHour,
        reviewMinute: existing.reviewMinute,
        daysAhead: existing.daysAhead,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _dao.recordAgentEvent(
      ZxAgentScene.startAction,
      'schedule_disabled',
    );
  }

  Future<int> _scheduleWindow(
    ZxAgentSettings settings, {
    required ZxAgentScene morningScene,
  }) async {
    var count = 0;
    final now = DateTime.now();
    for (var day = 0; day < settings.daysAhead; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final morning = DateTime(
        date.year,
        date.month,
        date.day,
        settings.hour,
        settings.minute,
      );
      final review = DateTime(
        date.year,
        date.month,
        date.day,
        settings.reviewHour,
        settings.reviewMinute,
      );
      if (morning.isAfter(now)) {
        final ok = await _scheduleOne(
          id: _alarmBase + day * 2,
          at: morning,
          scene: morningScene,
          body: _morningBody(morningScene),
        );
        if (ok) count++;
      }
      if (review.isAfter(now)) {
        final ok = await _scheduleOne(
          id: _alarmBase + day * 2 + 1,
          at: review,
          scene: ZxAgentScene.requestReview,
          body: '用3个关键问题反馈结果，导师会自动生成复盘报告并建议下一轮思想。',
        );
        if (ok) count++;
      }
    }
    return count;
  }

  Future<bool> _scheduleOne({
    required int id,
    required DateTime at,
    required ZxAgentScene scene,
    required String body,
  }) async {
    try {
      return await NativeScheduler.scheduleExactAt(
        id: id,
        epochMs: at.millisecondsSinceEpoch,
        payload: <String, Object?>{
          'module': 'zhixing_tree',
          'type': 'zhixing_agent_reminder',
          'scene': scene.key,
          'title': '知行树行动导师',
          'body': body,
        },
      );
    } catch (_) {
      return false;
    }
  }

  String _morningBody(ZxAgentScene scene) {
    switch (scene) {
      case ZxAgentScene.setGoal:
        return '从系统、Todo目标价值系统或 Microsoft To Do 选择一个最近目标。';
      case ZxAgentScene.chooseThought:
        return '查看系统为当前目标推荐的指导思想；你可以接受、替换或融合。';
      case ZxAgentScene.startAction:
        return '把目标转成一个现在可以开始的最小步骤。';
      case ZxAgentScene.trackProgress:
        return '看看行动推进到哪里；需要时把步骤缩小，不等待完美状态。';
      case ZxAgentScene.requestReview:
        return '反馈实际结果，让导师自动复盘并建议继续、切换或融合思想。';
      case ZxAgentScene.continueCycle:
        return '查看上轮报告，把新的认识转成今天的下一步。';
    }
  }
}
