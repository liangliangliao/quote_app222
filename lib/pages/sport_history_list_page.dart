import 'dart:async';
import 'package:flutter/material.dart';
import '../data/sport_dao.dart';
import 'sport_history_detail_page.dart';
import 'sport_history_summary_page.dart';

/// 运动历史记录列表页面
///
/// 显示所有运动记录或特定计划的历史记录，并允许查看详情或删除记录。
class SportHistoryListPage extends StatefulWidget {
  /// 可选的计划 id，用于过滤特定计划的历史记录。
  final int? planId;

  /// 可选的计划标题，用于显示页面标题。
  final String? planTitle;

  const SportHistoryListPage({super.key, this.planId, this.planTitle});

  @override
  State<SportHistoryListPage> createState() => _SportHistoryListPageState();
}

class _SportHistoryListPageState extends State<SportHistoryListPage> {
  final SportDao _dao = SportDao();
  bool _loading = true;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> recs;
    try {
      if (widget.planId != null) {
        recs = await _dao.getRecordsByPlan(widget.planId!);
      } else {
        recs = await _dao.getRecords();
      }
    } catch (_) {
      recs = [];
    }
    if (!mounted) return;
    setState(() {
      _records = recs;
      _loading = false;
    });
  }

  Future<void> _deleteRecord(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定删除此条运动记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteRecord(id);
      _load();
    }
  }

  void _openDetail(Map<String, dynamic> record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SportHistoryDetailPage(record: record),
      ),
    );
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.planTitle != null && widget.planTitle!.isNotEmpty
        ? '${widget.planTitle} 历史'
        : '运动历史';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '汇总',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SportHistorySummaryPage(
                    planId: widget.planId,
                    planTitle: widget.planTitle,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_records.isEmpty
              ? const Center(child: Text('暂无历史记录'))
              : ListView.builder(
                  itemCount: _records.length,
                  itemBuilder: (ctx, index) {
                    final rec = _records[index];
                    final startTime = _formatDateTime(rec['start_time']?.toString());
                    final durationSec = rec['total_duration'] is num
                        ? (rec['total_duration'] as num).toInt()
                        : null;
                    final durationStr = _formatDuration(durationSec);
                    final steps = rec['total_steps'];
                    final distMeters = rec['total_distance'] is num
                        ? (rec['total_distance'] as num).toDouble()
                        : null;
                    final distKm = distMeters != null ? distMeters / 1000.0 : null;
                    // Build title and subtitle lines.  Prefer the record's custom
                    // title, falling back to the start time when no title is
                    // provided.  Include the start time, duration, steps and
                    // distance in the subtitle for better context.
                    final recTitle = (rec['title'] ?? '').toString().trim();
                    final List<String> lines = [];
                    if (startTime.isNotEmpty) lines.add('开始: $startTime');
                    if (durationStr.isNotEmpty) lines.add('用时: $durationStr');
                    if (steps != null) lines.add('步数: $steps');
                    if (distKm != null) lines.add('距离: ${distKm.toStringAsFixed(2)} km');
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        onTap: () => _openDetail(rec),
                        title: Text(
                          recTitle.isNotEmpty
                              ? recTitle
                              : (startTime.isNotEmpty ? startTime : '未知运动'),
                        ),
                        subtitle: Text(lines.join('\n')),
                        isThreeLine: lines.length > 2,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteRecord(rec['id'] as int);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}