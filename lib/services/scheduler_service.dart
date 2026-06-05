import 'package:quote_app/services/native_guard.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import '../utils/debug_logger.dart';
import '../data/dao.dart';
import '../data/db.dart';
import '../platform/native_scheduler.dart';
import '../platform/perm_helper.dart';
import 'task_runner.dart';
import 'native_wm.dart';
import 'dart:convert';

class SchedulerService {
  static Future<void> init() async { /* 初始化已在 main.dart 完成 */ }

  /// 计算下一次运行时间：优先 next_time；否则使用 start_time(HH:mm) 今日/明日
  static DateTime _nextTimeForTask(Map<String, dynamic> t) {
    final now = DateTime.now();
    const grace = Duration(seconds: 10);
    try {
      final raw = (t['next_time'] ?? '').toString();
      if (raw.isNotEmpty) {
        final dt = DateTime.tryParse(raw);
        if (dt != null && dt.isAfter(now.subtract(grace))) return dt;
      }
    } catch (_) {}
    final start = (t['start_time'] ?? '09:00').toString();
    final parts = start.split(':');
    final hh = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
    final mm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    var next = DateTime(now.year, now.month, now.day, hh, mm);
    if (next.isBefore(now.subtract(grace))) next = next.add(const Duration(days: 1));
    return next;
  }

  /// 计算下一次运行时间（新实现）：根据任务配置计算下一次运行时间。
  /// 如果 start_time 为绝对时间且在未来，则直接使用之；否则按 freq_type 计算每日/每周/每月下一次。
  static DateTime _computeNextRun(Map<String, dynamic> t) {
    final now = DateTime.now();
    String start = (t['start_time'] ?? '09:00').toString().trim();
    if (start.isEmpty) start = '09:00';
    // 解析 HH:mm 或 YYYY-MM-DD HH:mm[:ss]
    DateTime? absDt;
    int hh = 9, mm = 0;
    // 如果包含日期
    final reAbs = RegExp(r'^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?\$');
    if (reAbs.hasMatch(start)) {
      try {
        // 标准化为 T 分隔
        final s = start.replaceFirst(' ', 'T');
        absDt = DateTime.parse(s);
      } catch (_) {
        absDt = null;
      }
      if (absDt != null) {
        hh = absDt.hour;
        mm = absDt.minute;
      }
    } else {
      // 尝试从任意字符串中提取 HH:mm 或 H:mm
      final m = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(start);
      if (m != null) {
        hh = int.tryParse(m.group(1) ?? '9') ?? 9;
        mm = int.tryParse(m.group(2) ?? '0') ?? 0;
      }
    }
    // 读取频率。对于手动任务或未设置的情况，默认 daily
    String freqType = (t['freq_type'] ?? 'daily').toString();
    if (freqType.isEmpty || freqType == 'null' || freqType == 'manual') {
      freqType = 'daily';
    }
    final int? weekDay = t['freq_weekday'] is int ? t['freq_weekday'] as int? : null;
    final int? dayOfMonth = t['freq_day_of_month'] is int ? t['freq_day_of_month'] as int? : null;
    // 如果 start_time 为未来的绝对时间，直接使用
    if (absDt != null && absDt.isAfter(now)) {
      return absDt;
    }
    // 周期计算
    if (freqType == 'weekly' && weekDay != null) {
      final wd = weekDay;
      int delta = (wd - now.weekday) % 7;
      var cand = DateTime(now.year, now.month, now.day, hh, mm).add(Duration(days: delta));
      // 如果候选时间尚未过去（含相等），则本周即将触发，否则推迟到下周
      if (!cand.isBefore(now)) return cand;
      return cand.add(const Duration(days: 7));
    }
    if (freqType == 'monthly' && dayOfMonth != null) {
      final d = dayOfMonth.clamp(1,31);
      int y = now.year;
      int mth = now.month;
      int end = DateTime(y, mth + 1, 0).day;
      var cand = DateTime(y, mth, d.clamp(1, end), hh, mm);
      // 若未来仍有本月候选(含同一时刻)，使用之；否则顺延至下月对应日
      if (!cand.isBefore(now)) return cand;
      mth += 1;
      end = DateTime(y, mth + 1, 0).day;
      cand = DateTime(y, mth, d.clamp(1, end), hh, mm);
      return cand;
    }
    // 默认：每日
    final today = DateTime(now.year, now.month, now.day, hh, mm);
    if (!today.isBefore(now)) return today;
    return today.add(const Duration(days: 1));
  }

  // RunKey now uses a human‑readable timestamp (yyyy-MM-dd HH:mm:ss) to align with the new idCard format.
  static String _runKeyFromTime(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

  static int _alarmId(String uid, String runKey) {
    // Stable cross‑platform 32‑bit FNV‑1a over UTF‑8 of "uid|runKey"
    const int FNV_PRIME = 16777619;
    const int FNV_OFFSET = 2166136261;
    final bytes = utf8.encode('$uid|$runKey');
    int h = FNV_OFFSET;
    for (final b in bytes) {
      h ^= b;
      h = (h * FNV_PRIME) & 0xffffffff;
    }
    return (h & 0x7fffffff);
  }

  // Unique names for WM tasks now embed source(main/fallback), runKey and uid for easier identification.
  static String _wmUniqueNormal(String uid, String runKey) => 'src=main-wm_runkey='+runKey+'_uid='+uid;
  // For fallback unique names, do not embed the attempt number.  
  // Using only src, runKey and uid ensures the native side can cancel and replace fallback work  
  // regardless of retry attempt. The attempt is still passed in inputData.
  static String _wmUniqueFallback(String uid, String runKey, int attempt) => 'src=fallback-wm_runkey='+runKey+'_uid='+uid;

  /// 取消 WM 正常/兜底（按唯一名）
  static Future<void> _cancelWmNormal(String uid, String runKey) async {
    // Always cancel WM tasks even when native takeover is reported. Log takeover but proceed.
    if (await NativeGuard.isNativeWM()) {
      await DLog.i('SCH', '【原生】WM 已接管，但 Dart 继续取消 uid='+uid+' run='+(runKey ?? ''));
    }
    try { await NativeScheduler.cancelWmByUnique(_wmUniqueNormal(uid, runKey)); } catch (_){ }
    try { await Workmanager().cancelByUniqueName(_wmUniqueNormal(uid, runKey)); } catch (_) {}
    await DLog.i('SCH', '【Dart】WM 取消完成 uid='+uid+' run='+(runKey ?? ''));
    try { await NativeWm.cancelByUid(uid); } catch (_){ }
  }
  static Future<void> _cancelWmFallback(String uid, String runKey, int attempt) async {
    // Always cancel fallback WM tasks regardless of native takeover to prevent duplicates
    try { await NativeScheduler.cancelWmByUnique(_wmUniqueFallback(uid, runKey, attempt)); } catch (_){ }
    try { await Workmanager().cancelByUniqueName(_wmUniqueFallback(uid, runKey, attempt)); } catch (_) {}
  await DLog.i('SCH', '【Dart】WM 取消完成 uid='+uid+' run='+(runKey ?? ''));
    try { await NativeWm.cancelByUid(uid); } catch (_){ }
  }

  /// 注册下一次（按权限分支：有精准=仅AM+兜底WM；无精准=仅WM正常+兜底WM）
  static Future<void> scheduleNextForTask(String uid) async {
    // Ensure DB columns exist before using them
    try { await ensureExtraTaskColumns(); } catch (_) {}
    final t = await TaskDao().getByUid(uid);
    if (t == null) return;
    if ((t['status'] ?? 'on').toString() != 'on') return;

    // 计算下一次运行时间
    final nextTime = _computeNextRun(t);
    final runKey = _runKeyFromTime(nextTime);
    final now = DateTime.now();
    final diff = nextTime.difference(now);
    final normalDelay = diff.isNegative ? Duration.zero : diff;

    // 更新 DB：保存 next_time 与 scheduled_run_key。如果缺少列则补充后重试。
    try {
      final db = await AppDatabase.instance();
      await db.update('tasks', {'next_time': nextTime.toIso8601String()}, where: 'task_uid=?', whereArgs: [uid]);
      await DLog.i('SCH','更新下一次时间 uid='+uid+' next='+_runKeyFromTime(nextTime));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such column') && msg.contains('next_time')) {
        try {
          await ensureExtraTaskColumns();
          final db = await AppDatabase.instance();
          await db.update('tasks', {'next_time': nextTime.toIso8601String()}, where: 'task_uid=?', whereArgs: [uid]);
          await DLog.i('SCH','更新下一次时间(重试) uid='+uid+' next='+_runKeyFromTime(nextTime));
        } catch (e2) {
          await DLog.e('SCH','更新下一次时间失败(重试) uid='+uid+' err='+e2.toString());
        }
      } else {
        await DLog.e('SCH','更新下一次时间失败 uid='+uid+' err='+e.toString());
      }
    }
    try {
      await TaskDao().setScheduledRunKey(uid, runKey);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such column') && msg.contains('scheduled_run_key')) {
        try {
          await ensureExtraTaskColumns();
          await TaskDao().setScheduledRunKey(uid, runKey);
        } catch (_) {}
      }
    }

    bool hasExact = false;
    try { hasExact = await PermHelper.hasExactAlarmPermission(); } catch (_) {}

    if (hasExact) {
      // ✅ 精准闹钟权限存在：先注册 AM，再注册 fallback-wm (+2 分钟) 兜底
      try {
        await DLog.i('SCH', '【Dart→原生】AM 注册请求 uid='+uid+' run='+(runKey ?? '')+' when='+nextTime.millisecondsSinceEpoch.toString());
        await NativeScheduler.scheduleExactAt(
          id: _alarmId(uid, runKey),
          epochMs: nextTime.millisecondsSinceEpoch,
          payload: {'uid': uid, 'runKey': runKey, 'chan': 'am', 'attempt': 1},
        );
        await DLog.i('SCH', '【Dart】AM 调用原生注册完成 uid='+uid+' run='+(runKey ?? ''));
        await DLog.i('SCH', '【原生】AM 注册完成 uid='+uid+' am_id='+_alarmId(uid, runKey).toString()+' run='+(runKey ?? ''));
      } catch (e) {
        await DLog.w('SCH', 'AM 注册失败，忽略: '+e.toString());
      }
      try {
        final u = _wmUniqueFallback(uid, runKey, 1);
        // Always register fallback WM task even when native WM takeover is reported. This ensures
        // a fallback notification will fire when precise alarm is not delivered. Log takeover but
        // proceed with registration to avoid skipping tasks entirely.
        if (await NativeGuard.isNativeWM()) {
          await DLog.i('SCH', '【原生】WM 已接管，但 Dart 继续注册兜底 uid='+uid+' run='+(runKey ?? ''));
        }
        // Register the fallback WM task (+2 minutes) with both legacy and new keys
        try {
          await Workmanager().registerOneOffTask(
            u, 'wm_task',
            initialDelay: normalDelay + const Duration(minutes: 2),
            inputData: {
              'job': 'wm_run',
              'task_uid': uid,
              'run_key': runKey,
              'uid': uid,
              'runKey': runKey,
              'chan': 'fallback-wm',
              'attempt': 1
            },
            existingWorkPolicy: ExistingWorkPolicy.replace,
            tag: uid,
          );
          await DLog.i('SCH', '【Dart】AM兜底 注册完成 uid='+uid+' run='+(runKey ?? ''));
        } catch (_) {}
        await DLog.i('SCH', 'WM 兜底注册完成 uid='+uid+' wm_unique='+u+' run='+(runKey ?? ''));
      } catch (e) {
        await DLog.e('SCH', 'WM 兜底注册失败: '+e.toString());
      }
    } else {
      // ❌ 无精准：优先走原生 WM（main+fallback）；成功则直接返回；失败再回退到 Dart WM
      try {
        if (await NativeGuard.isNativeWM()) {
          final ok = await NativeScheduler.scheduleWmPair(uid: uid, runKey: runKey, triggerAt: nextTime);
          await DLog.i('SCH', ok
            ? '【原生】WM 成对注册完成 uid='+uid+' run='+runKey
            : '【原生】WM 注册失败，回退到 Dart WM');
          if (ok) return;
        }
      } catch (_) {}

      // ❌ 无精准：使用 WM 路径，包含 main-wm 正常通道和 fallback-wm 兜底通道
      try {
        final u = _wmUniqueNormal(uid, runKey);
        // Even if native WM takeover is reported, proceed with Workmanager registration.
        if (await NativeGuard.isNativeWM()) {
          await DLog.i('SCH', '【原生】WM 已接管，但 Dart 继续注册正常 uid='+uid+' run='+(runKey ?? ''));
        }
        try {
          await Workmanager().registerOneOffTask(
            u, 'wm_task',
            initialDelay: normalDelay,
            inputData: {
              'job': 'wm_run',
              'task_uid': uid,
              'run_key': runKey,
              'uid': uid,
              'runKey': runKey,
              'chan': 'main-wm',
              'attempt': 1
            },
            existingWorkPolicy: ExistingWorkPolicy.replace,
            tag: uid,
          );
          await DLog.i('SCH', '【Dart】WM正常 注册完成 uid='+uid+' run='+(runKey ?? ''));
        } catch (_) {}
        await DLog.i('SCH','【Dart】WM 正常注册完成 uid='+uid+' wm_unique='+u+' run='+(runKey ?? '')+' delay='+normalDelay.inSeconds.toString()+'s');
      } catch (e) {
        await DLog.e('SCH','WM 正常注册失败: '+e.toString());
      }
      try {
        final u = _wmUniqueFallback(uid, runKey, 1);
        // Even if native WM takeover is reported, proceed with fallback registration.
        if (await NativeGuard.isNativeWM()) {
          await DLog.i('SCH', '【原生】WM 已接管，但 Dart 继续注册兜底 uid='+uid+' run='+(runKey ?? ''));
        }
        try {
          await Workmanager().registerOneOffTask(
            u, 'wm_task',
            initialDelay: normalDelay + const Duration(minutes: 2),
            inputData: {
              'job': 'wm_run',
              'task_uid': uid,
              'run_key': runKey,
              'uid': uid,
              'runKey': runKey,
              'chan': 'fallback-wm',
              'attempt': 1
            },
            existingWorkPolicy: ExistingWorkPolicy.replace,
            tag: uid,
          );
          await DLog.i('SCH', '【Dart】WM兜底 注册完成 uid='+uid+' run='+(runKey ?? ''));
        } catch (_) {}
        await DLog.i('SCH','【Dart】WM 兜底注册完成 uid='+uid+' wm_unique='+u+' run='+(runKey ?? ''));
      } catch (e) {
        await DLog.e('SCH','WM 兜底注册失败: '+e.toString());
      }
    }
  }

  /// 精准取消（根据保存的 scheduled_run_key）
  static Future<void> cancelNextForTask(String uid) async {
    final t = await TaskDao().getByUid(uid);
    if (t == null) return;
    final runKey = (t['scheduled_run_key'] ?? '').toString();
    if (runKey.isEmpty) {
      await DLog.w('SCH','取消下一次：没有保存的 runKey，uid='+uid);
      return;
    }
    try { await DLog.i('SCH', '【原生】AM 取消 uid='+uid+' run='+(runKey ?? '')); } catch (_) {}
    try { await NativeScheduler.cancel(_alarmId(uid, runKey)); } catch (_) {}
    try { await NativeScheduler.cancelKick(uid, runKey); } catch (_){ }
    await _cancelWmNormal(uid, runKey);
    await _cancelWmFallback(uid, runKey, 1);
    await _cancelWmFallback(uid, runKey, 2);
    await DLog.i('SCH','已取消下一次计划 uid='+uid+' run='+(runKey ?? ''));
  }

  /// 为全部任务安排下一次
  static Future<void> scheduleNextForAll() async {
    // Ensure DB contains required auxiliary columns before scheduling
    try { await ensureExtraTaskColumns(); } catch (_) {}
    final list = await TaskDao().all();
    for (final t in list) {
      final uid = (t['task_uid'] ?? '').toString();
      if (uid.isEmpty) continue;
      await scheduleNextForTask(uid);
    }
  }

  /// 保存 next_time 并重新安排
  static Future<void> _updateNextAndReschedule(String uid) async {
    final t = await TaskDao().getByUid(uid);
    if (t == null) return;
    // 计算并保存下一次运行时间
    final next = _computeNextRun(t);
    // Ensure auxiliary columns exist before writing
    try { await ensureExtraTaskColumns(); } catch (_) {}
    final db = await AppDatabase.instance();
    try {
      await db.update('tasks', {'next_time': next.toIso8601String()}, where: 'task_uid=?', whereArgs: [uid]);
      await DLog.i('SCH','更新下一次时间 uid='+uid+' next='+_runKeyFromTime(next));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such column') && msg.contains('next_time')) {
        // As a last resort, ensure columns again then retry once
        try {
          await ensureExtraTaskColumns();
          await db.update('tasks', {'next_time': next.toIso8601String()}, where: 'task_uid=?', whereArgs: [uid]);
          await DLog.i('SCH','更新下一次时间(重试) uid='+uid+' next='+_runKeyFromTime(next));
        } catch (e2) {
          await DLog.e('SCH','更新下一次时间失败(重试) uid='+uid+' err='+e2.toString());
        }
      } else {
        await DLog.e('SCH','更新下一次时间失败 uid='+uid+' err='+e.toString());
      }
    }
    // 安排下一次
    await scheduleNextForTask(uid);
  }

  /// 后台 WM 回调执行：统一走 TaskRunner
  
static Future<void> wmRunTask(String uid, String? runKey, {String? chan, int attempt = 1}) async {
    // 记录即将发送的来源、尝试次数与关键信息
    // Default to main-wm channel if no chan provided. Old value 'normal' is deprecated.
    final String source = (chan ?? 'main-wm');
    try {
      await DLog.i('SCH', '开始发送通知 chan='+source+' attempt='+attempt.toString()+' uid='+uid+' run='+(runKey ?? ''));
    } catch (_) {}

    // 幂等：同一任务同一 runKey 只能发送一次
    if (runKey != null && runKey.isNotEmpty) {
      try {
        final sent = await NotifyGuardDao().alreadySent(uid, runKey, chan: source, attempt: attempt);
        if (sent) {
          await DLog.w('SCH','幂等拦截：uid='+uid+' run='+(runKey ?? '')+' 已发送过，忽略');
          return;
        } else {
          await NotifyGuardDao().markSent(uid, runKey, chan: source, attempt: attempt);
        }
      } catch (_) {}
    }

    // ★ 在 WM 任务执行期间，不再取消当前正在运行的主/兜底/self-check 任务。取消同名任务会导致正在运行的 WorkManager
    // worker 被打断，从而无法正常发送通知。当前 AM 通道可提前取消，以避免双重调度。
    try {
      if (runKey != null && runKey.isNotEmpty) {
        final ch = source.toLowerCase();
        if (ch == 'am') {
          // Cancel AM by alarmId to prevent duplicate alarms. 其他渠道的取消逻辑在发送成功或失败后执行。
          try { await NativeScheduler.cancel(_alarmId(uid, runKey)); } catch (_) {}
    try { await NativeScheduler.cancelKick(uid, runKey); } catch (_){ }
          try { await LogDao().add(taskUid: uid, detail: '精准取消当前任务(am)：uid='+uid+' run='+(runKey ?? '')); } catch (_) {}
        }
        // For main-wm, fallback-wm and selfck-wm we intentionally avoid cancelling here.  Cancelling the unique
        // work while it is executing would interrupt the worker before notifications are sent.
      }
    } catch (_) {}

    try {
      await TaskRunner.run(uid);
      // 成功：标记成功日志
      try {
        await DLog.i('SCH', '发送成功 chan='+source+' attempt='+attempt.toString()+' uid='+uid+' run='+(runKey ?? ''));
      } catch (_) {}
      try { await FailureStatDao().markLatestSuccess(uid); } catch (_) {}

      // 根据来源处理后续逻辑和取消
      final String lower = source.toLowerCase();
      if (runKey != null && runKey.isNotEmpty) {
        if (lower == 'fallback-wm' || lower == 'selfck-wm') {
          // 兜底或自检成功：取消当前任务即结束，不安排下一次
          try {
            // Cancel the running fallback/selfck task using its unique id
            await _cancelWmFallback(uid, runKey, attempt);
          } catch (_) {}
          // Best-effort cancel AM as well in case of leftover alarm
          try { await NativeScheduler.cancel(_alarmId(uid, runKey)); } catch (_) {}
    try { await NativeScheduler.cancelKick(uid, runKey); } catch (_){ }
          return;
        } else {
          // 来源为 am 或 main-wm：先取消兜底，再取消当前任务，然后续排下一次
          // Cancel fallback WM tasks (any attempts)
          try {
            await _cancelWmFallback(uid, runKey, 1);
            await _cancelWmFallback(uid, runKey, 2);
          } catch (_) {}
          // Cancel current channel
          if (lower == 'am') {
            try { await NativeScheduler.cancel(_alarmId(uid, runKey)); } catch (_) {}
    try { await NativeScheduler.cancelKick(uid, runKey); } catch (_){ }
          } else if (lower == 'main-wm') {
            try { await _cancelWmNormal(uid, runKey); } catch (_) {}
          }
          // 安排下一次
          try { await _updateNextAndReschedule(uid); } catch (_) {}
          return;
        }
      } else {
        // 没有 runKey 时仅安排下一次（仅适用于 am/main-wm）
        if (lower != 'fallback-wm' && lower != 'selfck-wm') {
          try { await _updateNextAndReschedule(uid); } catch (_) {}
        }
        return;
      }
    } catch (e) {
      // 捕获失败：记录来源与尝试次数
      try {
        await DLog.e('SCH','发送失败 chan='+source+' attempt='+attempt.toString()+' uid='+uid+' run='+(runKey ?? '')+' err='+e.toString());
      } catch (_) {}
      final dateStr = DateTime.now().toIso8601String().substring(0,10);
      try {
        await FailureStatDao().insertFail(taskUid: uid, channel: source, uniqueId: (runKey ?? ''), dateStr: dateStr);
      } catch (_) {}

      // 根据来源处理失败逻辑
      final String lowerChan = source.toLowerCase();
      if (lowerChan == 'fallback-wm') {
        // 兜底任务失败：取消当前兜底任务
        if (runKey != null && runKey.isNotEmpty) {
          try { await _cancelWmFallback(uid, runKey, attempt); } catch (_) {}
        }
        // 若重试次数不超过 2，则立即注册一次兜底重试；否则安排下一次任务
        if (attempt <= 1) {
          try {
            final String nextRunKey = runKey ?? _runKeyFromTime(DateTime.now());
            final u = _wmUniqueFallback(uid, nextRunKey, attempt + 1);
            await DLog.i('SCH', '【Dart】WM 注册完成 uid='+uid+' run='+(runKey ?? ''));
            // Even if native WM takeover is reported, proceed with immediate fallback registration.
            try {
              await Workmanager().registerOneOffTask(
                u, 'wm_task',
                initialDelay: Duration.zero,
                inputData: {
                  'job':'wm_run',
                  'task_uid': uid,
                  'run_key': runKey,
                  'uid': uid,
                  'runKey': runKey,
                  'chan': 'fallback-wm',
                  'attempt': attempt + 1
                },
                existingWorkPolicy: ExistingWorkPolicy.replace,
                tag: uid,
              );
            } catch (_) {}
            await DLog.w('SCH','兜底失败，已注册第'+(attempt+1).toString()+'次兜底 uid='+uid+' run='+(runKey ?? ''));
          } catch (e2) {
            await DLog.e('SCH','兜底再次注册失败 uid='+uid+' err='+e2.toString());
          }
          return;
        } else {
          try { await _updateNextAndReschedule(uid); } catch (_) {}
          return;
        }
      } else if (lowerChan == 'selfck-wm') {
        // 自检任务失败：取消当前自检任务后结束
        if (runKey != null && runKey.isNotEmpty) {
          try { await _cancelWmFallback(uid, runKey, attempt); } catch (_) {}
        }
        return;
      } else if (lowerChan == 'am' || lowerChan == 'main-wm') {
        // AM 或 主 WM 失败：取消当前任务，并安排下一次
        if (runKey != null && runKey.isNotEmpty) {
          if (lowerChan == 'am') {
            try { await NativeScheduler.cancel(_alarmId(uid, runKey)); } catch (_) {}
    try { await NativeScheduler.cancelKick(uid, runKey); } catch (_){ }
          } else {
            try { await _cancelWmNormal(uid, runKey); } catch (_) {}
          }
        }
        try { await _updateNextAndReschedule(uid); } catch (_) {}
        return;
      } else {
        // 其他渠道失败：直接安排下一次
        try { await _updateNextAndReschedule(uid); } catch (_) {}
        return;
      }
    }
  }
/// 兼容旧入口
  static Future<void> callback() async {}

  /// 注册/刷新自检周期任务（最小 15 分钟）
  static Future<void> scheduleSelfCheck() async {
    // 自检功能已全局禁用：这里只做清理，不再注册任何周期任务
    try { await NativeScheduler.cancelWmByUnique('wm_selfcheck_unique'); } catch (_) {}
    try { await Workmanager().cancelByUniqueName('wm_selfcheck_unique'); } catch (_) {}
    await DLog.i('SCH','自检已禁用：仅执行清理，不再注册周期任务');
}

  /// 每日自检：扫描当天失败记录并立刻补发
  static Future<void> selfCheckTodayFailures() async {
    try {
      final fails = await FailureStatDao().failsOfToday();
      if (fails.isEmpty) {
        await DLog.i('SCH','自检：今日无失败记录');
        return;
      }
      for (final row in fails) {
        final uid = (row['task_uid'] ?? '').toString();
        if (uid.isEmpty) continue;
        final runKey = _runKeyFromTime(DateTime.now());
        await DLog.i('SCH', '【Dart】WM 注册完成 uid='+uid+' run='+(runKey ?? ''));
        try {
          final u = _wmUniqueNormal(uid, runKey);
          // Even if native WM takeover is reported, proceed with Workmanager registration for self‑check resends.
          if (await NativeGuard.isNativeWM()) {
            await DLog.i('SCH','【原生】WM 已接管，但 Dart 继续注册自检补发 uid='+uid+' run='+(runKey ?? ''));
          }
          try {
            await Workmanager().registerOneOffTask(
              u, 'wm_task',
              initialDelay: Duration.zero,
              // use main-wm channel for self-check resends
              inputData: {
                'job':'wm_run',
                'task_uid': uid,
                'run_key': runKey,
                'uid': uid,
                'runKey': runKey,
                'chan':'main-wm',
                'attempt': 1
              },
              existingWorkPolicy: ExistingWorkPolicy.replace,
              tag: uid,
            );
          } catch (_) {}
          await DLog.i('SCH','自检补发：已注册 WM 正常 uid='+uid+' run='+(runKey ?? ''));
        } catch (e) {
          await DLog.e('SCH','自检补发注册失败 uid='+uid+' err='+e.toString());
        }
      }
    } catch (e) {
      await DLog.e('SCH','自检执行失败: '+e.toString());
    }
  }
}