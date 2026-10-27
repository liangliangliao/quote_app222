import 'dart:async';

import 'package:flutter/material.dart';

import '../services/quote_ai_service.dart';

DateTime? parseTaskScheduleTime(Object? raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty || value.toLowerCase() == 'null') return null;
  return DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

String formatTaskScheduleTime(DateTime? value) {
  if (value == null) return '尚无记录';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String taskScheduleCountdown(DateTime next, DateTime now) {
  final difference = next.difference(now);
  if (difference <= Duration.zero) {
    final overdue = now.difference(next);
    if (overdue < const Duration(minutes: 1)) return '已到计划时间，等待系统触发';
    return '等待系统触发（已到点 ${_compactDuration(overdue)}）';
  }
  return '还有 ${_compactDuration(difference)}';
}

String taskScheduleFrequencyLabel(Map<String, dynamic> task) {
  final type = (task['freq_type'] ?? 'daily').toString().trim().toLowerCase();
  final time = _timeOfDay(task['start_time']);
  if (type == 'interval') {
    final minutes = QuoteAiTaskConfig.fromTask(task).intervalMinutes;
    if (minutes % (24 * 60) == 0) return '每 ${minutes ~/ (24 * 60)} 天';
    if (minutes % 60 == 0) return '每 ${minutes ~/ 60} 小时';
    return '每 $minutes 分钟';
  }
  if (type == 'weekly') {
    const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
    final raw = task['freq_weekday'];
    final weekday = raw is int ? raw : int.tryParse((raw ?? '').toString());
    final label = weekday != null && weekday >= 1 && weekday <= 7
        ? weekdays[weekday - 1]
        : '一';
    return '每周$label $time';
  }
  if (type == 'monthly') {
    final raw = task['freq_day_of_month'];
    final day = raw is int ? raw : int.tryParse((raw ?? '').toString());
    return '每月${(day ?? 1).clamp(1, 31)}日 $time';
  }
  return '每天 $time';
}

String _timeOfDay(Object? raw) {
  final match = RegExp(
    r'\b(\d{1,2}):(\d{2})\b',
  ).firstMatch((raw ?? '').toString());
  if (match == null) return '09:00';
  final hour = int.tryParse(match.group(1) ?? '') ?? 9;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _compactDuration(Duration value) {
  final seconds = value.inSeconds.abs();
  final days = seconds ~/ Duration.secondsPerDay;
  final hours = (seconds % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
  final minutes =
      (seconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final remainder = seconds % Duration.secondsPerMinute;
  if (days > 0) {
    return '$days天 ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
  if (hours > 0) {
    return '$hours小时 ${minutes.toString().padLeft(2, '0')}分${remainder.toString().padLeft(2, '0')}秒';
  }
  if (minutes > 0) return '$minutes分${remainder.toString().padLeft(2, '0')}秒';
  return '$remainder秒';
}

class TaskScheduleStatusView extends StatefulWidget {
  const TaskScheduleStatusView({super.key, required this.task});

  final Map<String, dynamic> task;

  @override
  State<TaskScheduleStatusView> createState() => _TaskScheduleStatusViewState();
}

class _TaskScheduleStatusViewState extends State<TaskScheduleStatusView> {
  @override
  void initState() {
    super.initState();
    _TaskScheduleClock.acquire();
  }

  @override
  void dispose() {
    _TaskScheduleClock.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
        valueListenable: _TaskScheduleClock.now,
        builder: (context, now, _) => _buildStatus(now),
      );

  Widget _buildStatus(DateTime now) {
    final task = widget.task;
    final lastRun = parseTaskScheduleTime(task['last_run_at']);
    final nextRun = parseTaskScheduleTime(task['next_time']);
    final enabled = (task['status'] ?? 'on').toString() == 'on';
    final isAuto = (task['type'] ?? '').toString() == 'auto';
    final autoEnabled = !isAuto || QuoteAiTaskConfig.fromTask(task).autoEnabled;
    final active = enabled && autoEnabled;
    final status = !enabled
        ? '已关闭'
        : !autoEnabled
            ? 'AI 自动获取已暂停'
            : '已开启';
    final nextText = !active
        ? '已暂停'
        : nextRun == null
            ? '正在等待系统安排'
            : formatTaskScheduleTime(nextRun);
    final liveText = !active
        ? '暂停中，不会触发通知'
        : nextRun == null
            ? '正在恢复后台计划'
            : taskScheduleCountdown(nextRun, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近成功执行：${lastRun == null ? '尚未执行' : formatTaskScheduleTime(lastRun)}',
          key: const ValueKey('task-last-run'),
        ),
        const SizedBox(height: 2),
        Text('下次计划执行：$nextText', key: const ValueKey('task-next-run')),
        const SizedBox(height: 2),
        Text(
          '实时状态：$liveText',
          key: const ValueKey('task-countdown'),
          style: TextStyle(
            color: active ? const Color(0xff4f46e5) : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text('计划规则：${taskScheduleFrequencyLabel(task)}  ·  任务状态：$status'),
      ],
    );
  }
}

class _TaskScheduleClock {
  static final ValueNotifier<DateTime> now = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  static Timer? _timer;
  static int _listeners = 0;

  static void acquire() {
    _listeners += 1;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
    });
  }

  static void release() {
    if (_listeners > 0) _listeners -= 1;
    if (_listeners != 0) return;
    _timer?.cancel();
    _timer = null;
  }
}
