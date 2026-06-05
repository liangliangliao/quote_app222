import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/sport_dao.dart';

/// 运动计划进度（日历）页面
///
/// 根据计划 repeat 规则与历史记录，在日历上标记：
/// - 已完成（绿色）
/// - 未完成/缺卡（红色）
/// - 当天进行中/已暂停（蓝色）
/// - 未来未开始（灰色）
class SportPlanProgressPage extends StatefulWidget {
  final Map<String, dynamic> plan;

  const SportPlanProgressPage({super.key, required this.plan});

  @override
  State<SportPlanProgressPage> createState() => _SportPlanProgressPageState();
}

class _SportPlanProgressPageState extends State<SportPlanProgressPage> {
  final SportDao _dao = SportDao();

  late DateTime _cursorMonth;
  bool _loading = true;
  List<Map<String, dynamic>> _records = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cursorMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final planId = widget.plan['id'] as int?;
    if (planId == null) {
      setState(() {
        _records = const [];
        _loading = false;
      });
      return;
    }

    final start = DateTime(_cursorMonth.year, _cursorMonth.month, 1);
    final end = DateTime(_cursorMonth.year, _cursorMonth.month + 1, 1);
    try {
      final recs = await _dao.getRecordsByPlanBetween(planId, start, end);
      if (!mounted) return;
      setState(() {
        _records = recs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = const [];
        _loading = false;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _cursorMonth = DateTime(_cursorMonth.year, _cursorMonth.month - 1, 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _cursorMonth = DateTime(_cursorMonth.year, _cursorMonth.month + 1, 1);
    });
    _load();
  }

  String _monthTitle(DateTime m) {
    return '${m.year}-${m.month.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDay(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  Set<DateTime> _expectedDaysInMonth(DateTime monthStart) {
    final plan = widget.plan;
    final repeatType = (plan['repeat_type'] ?? 'daily').toString();
    final detailStr = (plan['repeat_detail'] ?? '').toString();
    Map<String, dynamic> detail = const {};
    try {
      if (detailStr.isNotEmpty) {
        final v = jsonDecode(detailStr);
        if (v is Map<String, dynamic>) detail = v;
      }
    } catch (_) {}

    final start = DateTime(monthStart.year, monthStart.month, 1);
    final end = DateTime(monthStart.year, monthStart.month + 1, 1);
    final set = <DateTime>{};

    if (repeatType == 'daily') {
      for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        set.add(DateTime(d.year, d.month, d.day));
      }
      return set;
    }

    if (repeatType == 'weekly') {
      final weekdays = (detail['weekdays'] is List) ? List<int>.from(detail['weekdays']) : <int>[1,2,3,4,5,6,7];
      for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
        if (weekdays.contains(d.weekday)) {
          set.add(DateTime(d.year, d.month, d.day));
        }
      }
      return set;
    }

    if (repeatType == 'monthly') {
      final days = (detail['monthdays'] is List) ? List<int>.from(detail['monthdays']) : <int>[];
      for (final day in days) {
        final candidate = DateTime(monthStart.year, monthStart.month, day);
        if (candidate.month == monthStart.month) {
          set.add(DateTime(candidate.year, candidate.month, candidate.day));
        }
      }
      return set;
    }

    if (repeatType == 'custom') {
      final dates = (detail['dates'] is List) ? List<String>.from(detail['dates']) : <String>[];
      for (final s in dates) {
        final d = DateTime.tryParse(s);
        if (d != null && d.year == monthStart.year && d.month == monthStart.month) {
          set.add(DateTime(d.year, d.month, d.day));
        }
      }
      return set;
    }

    return set;
  }

  Map<DateTime, Map<String, dynamic>> _recordByDay() {
    final map = <DateTime, Map<String, dynamic>>{};
    for (final r in _records) {
      final day = _parseDay(r['start_time']?.toString());
      if (day == null) continue;
      // 如果同一天多条记录，优先用最新一条（start_time 最大）
      if (!map.containsKey(day)) {
        map[day] = r;
        continue;
      }
      final prev = map[day];
      final prevT = DateTime.tryParse(prev?['start_time']?.toString() ?? '');
      final curT = DateTime.tryParse(r['start_time']?.toString() ?? '');
      if (prevT == null || (curT != null && curT.isAfter(prevT))) {
        map[day] = r;
      }
    }
    return map;
  }

  Color? _bgColorForDay(DateTime day, bool expected, Map<String, dynamic>? record) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    if (!expected && record == null) return null;

    // record 优先
    if (record != null) {
      final status = (record['status'] ?? '').toString();
      if (status == 'completed') return Colors.green.withOpacity(0.85);
      if (status == 'in_progress' || status == 'paused' || status == 'stopped') {
        // 当天进行中 / 已暂停 / 已停止
        if (day == todayDay) return Colors.blue.withOpacity(0.75);
        // 非当天的未完成按红色
        return Colors.red.withOpacity(0.75);
      }
      return Colors.red.withOpacity(0.75);
    }

    // 没有记录但属于计划日
    if (day.isAfter(todayDay)) return Colors.grey.withOpacity(0.35);
    if (day == todayDay) return Colors.grey.withOpacity(0.55);
    // 过去缺卡
    return Colors.red.withOpacity(0.65);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.plan['title']?.toString() ?? '计划进度';
    final monthStart = DateTime(_cursorMonth.year, _cursorMonth.month, 1);
    final monthEnd = DateTime(_cursorMonth.year, _cursorMonth.month + 1, 1);
    final expected = _expectedDaysInMonth(monthStart);
    final recMap = _recordByDay();
    final firstWeekday = monthStart.weekday; // 1..7
    final daysInMonth = monthEnd.subtract(const Duration(days: 1)).day;

    final cells = <Widget>[];
    // leading blanks
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int dayNum = 1; dayNum <= daysInMonth; dayNum++) {
      final day = DateTime(monthStart.year, monthStart.month, dayNum);
      final exp = expected.contains(day);
      final rec = recMap[day];
      final bg = _bgColorForDay(day, exp, rec);
      cells.add(
        GestureDetector(
          onTap: rec == null
              ? null
              : () {
                  // 简单展示状态信息
                  final status = (rec['status'] ?? '').toString();
                  final steps = rec['total_steps']?.toString() ?? '-';
                  final dist = (rec['total_distance'] is num)
                      ? ((rec['total_distance'] as num).toDouble() / 1000.0).toStringAsFixed(2)
                      : '-';
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('${day.month}/${day.day} 记录'),
                      content: Text('状态: $status\n步数: $steps\n距离: $dist km'),
                      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('确定'))],
                    ),
                  );
                },
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            alignment: Alignment.center,
            child: Text(
              dayNum.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: bg == null ? Colors.black87 : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('进度 - $title'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                      Expanded(
                        child: Center(
                          child: Text(
                            _monthTitle(_cursorMonth),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                ),
                _legend(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('一'),
                      Text('二'),
                      Text('三'),
                      Text('四'),
                      Text('五'),
                      Text('六'),
                      Text('日'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    crossAxisCount: 7,
                    children: cells,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String t) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          item(Colors.green.withOpacity(0.85), '已完成'),
          item(Colors.red.withOpacity(0.75), '未完成/缺卡'),
          item(Colors.blue.withOpacity(0.75), '当天进行中/暂停'),
          item(Colors.grey.withOpacity(0.55), '未开始'),
        ],
      ),
    );
  }
}
