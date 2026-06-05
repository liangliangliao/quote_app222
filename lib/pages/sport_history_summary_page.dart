import 'package:flutter/material.dart';

import '../data/sport_dao.dart';

/// 运动历史记录汇总页面
///
/// 支持查看全量或某个计划在指定时间范围内的汇总数据。
class SportHistorySummaryPage extends StatefulWidget {
  final int? planId;
  final String? planTitle;

  const SportHistorySummaryPage({super.key, this.planId, this.planTitle});

  @override
  State<SportHistorySummaryPage> createState() => _SportHistorySummaryPageState();
}

class _SportHistorySummaryPageState extends State<SportHistorySummaryPage> {
  final SportDao _dao = SportDao();

  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now().add(const Duration(days: 1));
  bool _loading = true;
  Map<String, dynamic> _summaryAll = const {};
  Map<String, dynamic> _summaryPlan = const {};
  Map<String, dynamic> _summaryInstant = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = DateTime(_start.year, _start.month, _start.day);
      final end = DateTime(_end.year, _end.month, _end.day);

      Map<String, dynamic> resAll = const {};
      Map<String, dynamic> resPlan = const {};
      Map<String, dynamic> resInstant = const {};

      if (widget.planId != null) {
        resAll = await _dao.getHistorySummary(start, end, planId: widget.planId);
      } else {
        // Global summary: separate plan vs instant per requirement.
        resAll = await _dao.getHistorySummary(start, end);
        resPlan = await _dao.getHistorySummary(start, end, mode: 'plan');
        resInstant = await _dao.getHistorySummary(start, end, mode: 'instant');
      }
      if (!mounted) return;
      setState(() {
        _summaryAll = resAll;
        _summaryPlan = resPlan;
        _summaryInstant = resInstant;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summaryAll = const {};
        _summaryPlan = const {};
        _summaryInstant = const {};
        _loading = false;
      });
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _start = picked);
      _load();
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.subtract(const Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      // end 采用“次日 00:00”作为 exclusive 上界
      setState(() => _end = picked.add(const Duration(days: 1)));
      _load();
    }
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _fmtDurationSeconds(num seconds) {
    final s = seconds.toInt();
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.planTitle != null && widget.planTitle!.isNotEmpty
        ? '${widget.planTitle} 汇总'
        : '历史记录汇总';
    Widget buildSummaryCard(String header, Map<String, dynamic> sum) {
      final totalCount = (sum['total_count'] ?? 0) as num? ?? 0;
      final completedCount = (sum['completed_count'] ?? 0) as num? ?? 0;
      final durationSum = (sum['total_duration_sum'] ?? 0) as num? ?? 0;
      final stepsSum = (sum['total_steps_sum'] ?? 0) as num? ?? 0;
      final distSum = (sum['total_distance_sum'] ?? 0) as num? ?? 0;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(header, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _kv('总次数', totalCount.toString()),
              _kv('完成次数', completedCount.toString()),
              _kv('总时长', _fmtDurationSeconds(durationSum)),
              _kv('总步数', stepsSum.toString()),
              _kv('总距离', '${(distSum / 1000.0).toStringAsFixed(2)} km'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('时间范围', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickStart,
                                child: Text('开始：${_fmtDate(_start)}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickEnd,
                                child: Text('结束：${_fmtDate(_end.subtract(const Duration(days: 1)))}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('说明：结束日期为包含当天（内部以次日 00:00 作为上界）', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.planId != null)
                  buildSummaryCard('汇总数据', _summaryAll)
                else ...[
                  buildSummaryCard('全部模式汇总', _summaryAll),
                  const SizedBox(height: 12),
                  buildSummaryCard('计划模式汇总', _summaryPlan),
                  const SizedBox(height: 12),
                  buildSummaryCard('非计划模式汇总', _summaryInstant),
                ],
              ],
            ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 14, color: Colors.black87))),
          Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
