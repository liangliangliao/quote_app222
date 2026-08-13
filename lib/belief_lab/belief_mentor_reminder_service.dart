import '../platform/native_scheduler.dart';
import 'belief_mentor_dao.dart';
import 'belief_mentor_models.dart';
import 'belief_mentor_policies.dart';

class BeliefMentorReminderService {
  BeliefMentorReminderService({BeliefMentorDao? dao})
    : _dao = dao ?? BeliefMentorDao();

  final BeliefMentorDao _dao;

  Future<bool> requestPermission() =>
      NativeScheduler.requestNotificationPermissionSystem();

  Future<List<BeliefMentorReminder>> scheduleExperimentPlan(
    BeliefMentorExperiment experiment,
  ) async {
    final safety = BeliefMentorSafetyPolicy.assess(
      '${experiment.action} ${experiment.minimumVersion} '
      '${experiment.fallbackAction}',
    );
    if (safety.blocksNormalFlow) {
      await _dao.recordSafetyEvent(
        category: safety.category,
        action: 'blocked_reminder_plan',
        source: 'experiment',
      );
      return const <BeliefMentorReminder>[];
    }
    final actionAt = DateTime.fromMillisecondsSinceEpoch(
      experiment.scheduledAtMs,
    );
    final now = DateTime.now();
    final plan =
        <
          ({
            BeliefMentorReminderType type,
            DateTime at,
            String title,
            String body,
          })
        >[
          (
            type: BeliefMentorReminderType.preAction,
            at: actionAt.subtract(const Duration(minutes: 10)),
            title: '信念实验即将开始',
            body: '只做最小版本：${experiment.minimumVersion}',
          ),
          (
            type: BeliefMentorReminderType.antiAvoidance,
            at: actionAt.add(const Duration(minutes: 20)),
            title: '不需要等到完全准备好',
            body: '如果还没开始，先做备用动作：${experiment.fallbackAction}',
          ),
          (
            type: BeliefMentorReminderType.evidenceCapture,
            at: actionAt.add(const Duration(minutes: 60)),
            title: '把结果变成证据',
            body: '记录预测、实际行动与结果；一次结果不代表全部。',
          ),
        ];
    final created = <BeliefMentorReminder>[];
    for (final item in plan) {
      final at = item.at.isBefore(now)
          ? now.add(const Duration(minutes: 1))
          : item.at;
      created.add(
        await _create(
          type: item.type,
          at: at,
          beliefId: experiment.beliefId,
          experimentId: experiment.id,
          title: item.title,
          body: item.body,
        ),
      );
    }
    return created;
  }

  Future<BeliefMentorReminder> scheduleMorningPrime({
    required BeliefMentorBelief belief,
    DateTime? day,
  }) async {
    final profile = await _dao.profile();
    final composed = _compose(
      type: type,
      title: title,
      body: body,
      tone: profile.tone,
    );
    final parts = profile.morningTime.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;
    final now = DateTime.now();
    final target = day ?? now;
    var at = DateTime(target.year, target.month, target.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return _create(
      type: BeliefMentorReminderType.morningPrime,
      at: at,
      beliefId: belief.id,
      title: '今天只验证一小步',
      body: '当前工作假设：“${belief.statement}”。选择一件可记录结果的小行动。',
    );
  }

  /// Keeps a rolling seven-day morning plan without creating duplicates.
  Future<List<BeliefMentorReminder>> ensureMorningPrimeSeries({
    required BeliefMentorBelief belief,
    int days = 7,
  }) async {
    final created = <BeliefMentorReminder>[];
    final now = DateTime.now();
    for (var offset = 0; offset < days; offset++) {
      created.add(
        await scheduleMorningPrime(
          belief: belief,
          day: DateTime(now.year, now.month, now.day + offset),
        ),
      );
    }
    return created;
  }

  Future<List<BeliefMentorReminder>> scheduleRecoveryPlan(
    BeliefMentorFailure failure,
  ) async {
    final origin = DateTime.fromMillisecondsSinceEpoch(failure.createdAtMs);
    final stages = <({Duration delay, String stage, String body})>[
      (
        delay: const Duration(hours: 6),
        stage: 'T+6',
        body: '把事实与解释分开：发生了什么？你又对它下了什么结论？',
      ),
      (
        delay: const Duration(hours: 24),
        stage: 'T+24',
        body: '用一个更小版本恢复行动，不需要补偿性冲刺。',
      ),
      (
        delay: const Duration(hours: 72),
        stage: 'T+72',
        body: '回看这次恢复：哪些条件有帮助？把它留下作为下一次依据。',
      ),
    ];
    final created = <BeliefMentorReminder>[];
    for (final item in stages) {
      created.add(
        await _create(
          type: BeliefMentorReminderType.failureRecovery,
          at: origin.add(item.delay),
          beliefId: failure.beliefId,
          experimentId: failure.experimentId,
          title: '失败恢复 · ${item.stage}',
          body: item.body,
        ),
      );
    }
    return created;
  }

  Future<void> completeExperiment(String experimentId) async {
    await _dao.completeExperiment(experimentId);
    final reminders = await _dao.reminders(experimentId: experimentId);
    for (final reminder in reminders) {
      if (reminder.type == BeliefMentorReminderType.antiAvoidance &&
          reminder.state == BeliefMentorReminderState.scheduled) {
        await NativeScheduler.cancel(reminder.alarmId);
        await _dao.updateReminderState(
          reminder.id,
          BeliefMentorReminderState.closed,
          suppressReason: '实验已完成',
        );
      }
    }
  }

  Future<void> closeRecovery(BeliefMentorFailure failure) async {
    final reminders = await _dao.reminders(experimentId: failure.experimentId);
    for (final reminder in reminders) {
      if (reminder.type != BeliefMentorReminderType.failureRecovery ||
          !_active(reminder.state)) {
        continue;
      }
      if (reminder.alarmId > 0) await NativeScheduler.cancel(reminder.alarmId);
      await _dao.updateReminderState(
        reminder.id,
        BeliefMentorReminderState.closed,
        suppressReason: '恢复动作已完成',
      );
    }
    await _dao.closeFailure(failure.id);
  }

  Future<void> snooze(
    String reminderId, {
    Duration duration = const Duration(minutes: 10),
  }) async {
    final current = await _dao.reminder(reminderId);
    if (current == null) return;
    final profile = await _dao.profile();
    final requestedAt = DateTime.now().add(duration);
    final at = BeliefMentorReminderPolicy.moveOutsideQuietHours(
      requestedAt,
      quietStart: profile.quietStart,
      quietEnd: profile.quietEnd,
    );
    await NativeScheduler.cancel(current.alarmId);
    final ok = await NativeScheduler.scheduleExactAt(
      id: current.alarmId,
      epochMs: at.millisecondsSinceEpoch,
      payload: _payload(current, profile: profile, scheduledAt: at),
    );
    await _dao.updateReminderState(
      current.id,
      ok
          ? BeliefMentorReminderState.snoozed
          : BeliefMentorReminderState.suppressed,
      suppressReason: ok ? '' : '系统未接受延期闹钟',
      scheduledAtMs: at.millisecondsSinceEpoch,
    );
    await _dao.track(
      'reminder_snoozed',
      beliefId: current.beliefId,
      experimentId: current.experimentId,
      properties: <String, Object?>{
        'type': current.type.name,
        'minutes': at.difference(DateTime.now()).inMinutes,
        'moved_for_quiet_hours': at != requestedAt,
      },
    );
  }

  Future<void> cancelReminder(
    String reminderId, {
    String reason = '用户取消',
  }) async {
    final current = await _dao.reminder(reminderId);
    if (current == null) return;
    if (current.alarmId > 0) await NativeScheduler.cancel(current.alarmId);
    await _dao.updateReminderState(
      current.id,
      BeliefMentorReminderState.closed,
      suppressReason: reason,
    );
    await _dao.track(
      'reminder_cancelled',
      beliefId: current.beliefId,
      experimentId: current.experimentId,
      properties: <String, Object?>{'type': current.type.name},
    );
  }

  Future<void> rescheduleReminder(
    String reminderId,
    DateTime requestedAt,
  ) async {
    final current = await _dao.reminder(reminderId);
    if (current == null) return;
    final profile = await _dao.profile();
    final at = BeliefMentorReminderPolicy.moveOutsideQuietHours(
      requestedAt,
      quietStart: profile.quietStart,
      quietEnd: profile.quietEnd,
    );
    if (current.alarmId > 0) await NativeScheduler.cancel(current.alarmId);
    final ok = await NativeScheduler.scheduleExactAt(
      id: current.alarmId,
      epochMs: at.millisecondsSinceEpoch,
      payload: _payload(current, profile: profile, scheduledAt: at),
    );
    await _dao.updateReminderState(
      current.id,
      ok
          ? BeliefMentorReminderState.rescheduled
          : BeliefMentorReminderState.suppressed,
      suppressReason: ok ? '' : '系统未接受重新安排的闹钟',
      scheduledAtMs: at.millisecondsSinceEpoch,
    );
    await _dao.track(
      'reminder_rescheduled',
      beliefId: current.beliefId,
      experimentId: current.experimentId,
      properties: <String, Object?>{
        'type': current.type.name,
        'moved_for_quiet_hours': at != requestedAt,
      },
    );
  }

  Future<void> cancelAll() async {
    for (final reminder in await _dao.reminders()) {
      if (reminder.alarmId > 0) await NativeScheduler.cancel(reminder.alarmId);
      await _dao.updateReminderState(
        reminder.id,
        BeliefMentorReminderState.closed,
        suppressReason: '用户关闭了 Belief Mentor 提醒',
      );
    }
  }

  Future<void> cancelAlarmIds(Iterable<int> alarmIds) async {
    for (final id in alarmIds.where((value) => value > 0).toSet()) {
      await NativeScheduler.cancel(id);
    }
  }

  Future<void> cancelExperimentReminders(
    String experimentId, {
    String reason = '实验已调整',
  }) async {
    for (final reminder in await _dao.reminders(experimentId: experimentId)) {
      if (reminder.alarmId > 0) await NativeScheduler.cancel(reminder.alarmId);
      if (_active(reminder.state)) {
        await _dao.updateReminderState(
          reminder.id,
          BeliefMentorReminderState.closed,
          suppressReason: reason,
        );
      }
    }
  }

  Future<void> pauseNonRecovery() async {
    for (final reminder in await _dao.reminders()) {
      if (reminder.type == BeliefMentorReminderType.failureRecovery ||
          !_active(reminder.state)) {
        continue;
      }
      if (reminder.alarmId > 0) await NativeScheduler.cancel(reminder.alarmId);
      await _dao.updateReminderState(
        reminder.id,
        BeliefMentorReminderState.closed,
        suppressReason: '用户当前需要空间',
      );
    }
  }

  Future<void> rescheduleActiveForCurrentProfile() async {
    final active = (await _dao.reminders())
        .where((item) => _active(item.state))
        .toList(growable: false);
    for (final reminder in active) {
      if (reminder.alarmId > 0) await NativeScheduler.cancel(reminder.alarmId);
      await rescheduleReminder(
        reminder.id,
        DateTime.fromMillisecondsSinceEpoch(reminder.scheduledAtMs),
      );
    }
  }

  Future<BeliefMentorReminder> _create({
    required BeliefMentorReminderType type,
    required DateTime at,
    required String beliefId,
    String experimentId = '',
    required String title,
    required String body,
  }) async {
    final profile = await _dao.profile();
    final now = DateTime.now();
    final futureAt = at.isAfter(now) ? at : now.add(const Duration(minutes: 1));
    final adjusted = BeliefMentorReminderPolicy.moveOutsideQuietHours(
      futureAt,
      quietStart: profile.quietStart,
      quietEnd: profile.quietEnd,
    );
    final existing = await _dao.reminders();
    final start = DateTime(adjusted.year, adjusted.month, adjusted.day);
    final end = start.add(const Duration(days: 1));
    final sameDay = existing
        .where((item) {
          final value = DateTime.fromMillisecondsSinceEpoch(item.scheduledAtMs);
          return !value.isBefore(start) &&
              value.isBefore(end) &&
              _active(item.state);
        })
        .toList(growable: false);
    final sameTypeIgnored = _consecutiveIgnored(existing, type);
    final within60 =
        !type.isCritical &&
        existing.any((item) {
          if (!_active(item.state) || item.type.isCritical) return false;
          return (item.scheduledAtMs - adjusted.millisecondsSinceEpoch).abs() <
              const Duration(minutes: 60).inMilliseconds;
        });
    final deliveryKey =
        '$experimentId:${type.name}:${adjusted.millisecondsSinceEpoch}';
    final duplicate = await _dao.reminderForDeliveryKey(deliveryKey);
    if (duplicate != null) return duplicate;
    final eligibility = BeliefMentorReminderPolicy.evaluate(
      type: type,
      scheduledAt: adjusted,
      quietStart: profile.quietStart,
      quietEnd: profile.quietEnd,
      remindersEnabled: profile.remindersEnabled,
      paused: profile.notificationsPaused,
      needsSpace: profile.needsSpaceAt(DateTime.now()),
      experimentCompleted: false,
      sameTypeIgnoredCount: sameTypeIgnored,
      psychologicalCountToday: sameDay
          .where((item) => !item.type.isCritical)
          .length,
      criticalCountToday: sameDay.where((item) => item.type.isCritical).length,
      alreadyDelivered: await _dao.deliveryKeyExists(deliveryKey),
      anotherInterventionWithin60Minutes: within60,
    );
    final id =
        'reminder_${DateTime.now().microsecondsSinceEpoch}_${type.index}';
    final alarmId = _alarmId('$id:$deliveryKey');
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var reminder = BeliefMentorReminder(
      id: id,
      experimentId: experimentId,
      beliefId: beliefId,
      type: type,
      scheduledAtMs: adjusted.millisecondsSinceEpoch,
      state: eligibility.allowed
          ? BeliefMentorReminderState.created
          : BeliefMentorReminderState.suppressed,
      title: composed.title,
      body: composed.body,
      alarmId: alarmId,
      deliveryKey: deliveryKey,
      suppressReason: eligibility.allowed ? '' : eligibility.reason,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    await _dao.saveReminder(reminder);
    if (!eligibility.allowed) {
      await _saveReminderAgentRun(
        reminder: reminder,
        tone: profile.tone,
        suppressReason: eligibility.reason,
      );
      return reminder;
    }

    var scheduled = false;
    try {
      scheduled = await NativeScheduler.scheduleExactAt(
        id: alarmId,
        epochMs: adjusted.millisecondsSinceEpoch,
        payload: _payload(reminder, profile: profile),
      );
    } catch (_) {
      scheduled = false;
    }
    final state = scheduled
        ? BeliefMentorReminderState.scheduled
        : BeliefMentorReminderState.suppressed;
    final reason = scheduled ? '' : '系统未接受精确提醒，请检查通知与精确闹钟权限';
    await _dao.updateReminderState(reminder.id, state, suppressReason: reason);
    reminder = BeliefMentorReminder(
      id: reminder.id,
      experimentId: reminder.experimentId,
      beliefId: reminder.beliefId,
      type: reminder.type,
      scheduledAtMs: reminder.scheduledAtMs,
      state: state,
      title: reminder.title,
      body: reminder.body,
      alarmId: reminder.alarmId,
      deliveryKey: reminder.deliveryKey,
      suppressReason: reason,
      createdAtMs: reminder.createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _saveReminderAgentRun(
      reminder: reminder,
      tone: profile.tone,
      suppressReason: reason,
    );
    return reminder;
  }

  Future<void> _saveReminderAgentRun({
    required BeliefMentorReminder reminder,
    required String tone,
    required String suppressReason,
  }) => _dao.saveAgentRun(
    agent: 'ReminderAgent',
    output: <String, Object?>{
      'type': reminder.type.name,
      'schedule': reminder.scheduledAtMs,
      'tone': tone,
      'suppress_reason': suppressReason,
    },
    provider: 'local',
    model: 'reminder-policy-v1',
    runStatus: suppressReason.isEmpty ? 'scheduled' : 'suppressed',
    redactedCount: 0,
  );

  static ({String title, String body}) _compose({
    required BeliefMentorReminderType type,
    required String title,
    required String body,
    required String tone,
  }) => switch (tone) {
    'gentle' => (title: title, body: '不用一次做完。$body'),
    'challenger' || 'direct' => (title: title, body: '先停止等待完美条件。$body'),
    'minimal' => (title: type.label, body: body),
    _ => (title: title, body: body),
  };

  Map<String, dynamic> _payload(
    BeliefMentorReminder reminder, {
    required BeliefMentorProfile profile,
    DateTime? scheduledAt,
  }) {
    final sensitive = profile.showSensitiveNotificationContent;
    return <String, dynamic>{
      'module': 'belief_mentor',
      'type': reminder.type.name,
      'title': sensitive ? reminder.title : 'Belief Mentor',
      'body': sensitive ? reminder.body : '你有一项已安排的信念实验步骤，点击后在应用内查看。',
      'reminderId': reminder.id,
      'beliefId': reminder.beliefId,
      'experimentId': reminder.experimentId,
      'scheduledAtMs':
          (scheduledAt?.millisecondsSinceEpoch ?? reminder.scheduledAtMs),
    };
  }

  static bool _active(BeliefMentorReminderState state) =>
      state == BeliefMentorReminderState.created ||
      state == BeliefMentorReminderState.scheduled ||
      state == BeliefMentorReminderState.sent ||
      state == BeliefMentorReminderState.opened ||
      state == BeliefMentorReminderState.snoozed ||
      state == BeliefMentorReminderState.rescheduled ||
      state == BeliefMentorReminderState.followUp;

  static int _consecutiveIgnored(
    List<BeliefMentorReminder> reminders,
    BeliefMentorReminderType type,
  ) {
    final recent = reminders.where((item) => item.type == type).toList()
      ..sort((a, b) => b.scheduledAtMs.compareTo(a.scheduledAtMs));
    var count = 0;
    for (final item in recent) {
      if (item.state == BeliefMentorReminderState.ignored) {
        count += item.ignoredCount.clamp(1, 100);
        continue;
      }
      if (item.state == BeliefMentorReminderState.opened ||
          item.state == BeliefMentorReminderState.actionStarted ||
          item.state == BeliefMentorReminderState.evidenceCreated) {
        break;
      }
    }
    return count;
  }

  static int _alarmId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
