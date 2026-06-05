import 'dart:convert';
import 'package:flutter/material.dart';

/// 运动历史记录详情页面
///
/// 展示单次运动记录的完整信息，包括开始/结束时间、用时、步数、距离、平均速度、模式、状态以及起止位置等。
class SportHistoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const SportHistoryDetailPage({super.key, required this.record});

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

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'stopped':
        return '已停止';
      case 'paused':
        return '已暂停';
      case 'in_progress':
        return '进行中';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _formatDateTime(record['start_time']?.toString());
    final endTime = _formatDateTime(record['end_time']?.toString());
    final durationSec = record['total_duration'] is num
        ? (record['total_duration'] as num).toInt()
        : null;
    final durationStr = _formatDuration(durationSec);
    final steps = record['total_steps'];
    final distMeters = record['total_distance'] is num
        ? (record['total_distance'] as num).toDouble()
        : null;
    final distKm = distMeters != null ? distMeters / 1000.0 : null;
    final avgSpeed = record['avg_speed'] is num ? (record['avg_speed'] as num).toDouble() : null;
    final mode = record['mode']?.toString() ?? '';
    final status = record['status']?.toString() ?? '';
    Map<String, dynamic>? startLoc;
    Map<String, dynamic>? endLoc;
    try {
      final sl = record['start_location'];
      if (sl != null && sl is String && sl.isNotEmpty) {
        startLoc = jsonDecode(sl) as Map<String, dynamic>?;
      }
    } catch (_) {}
    try {
      final el = record['end_location'];
      if (el != null && el is String && el.isNotEmpty) {
        endLoc = jsonDecode(el) as Map<String, dynamic>?;
      }
    } catch (_) {}
    return Scaffold(
      appBar: AppBar(
        title: const Text('运动记录详情'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('开始时间'),
              subtitle: Text(startTime.isNotEmpty ? startTime : '未知'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('结束时间'),
              subtitle: Text(endTime.isNotEmpty ? endTime : '未知'),
            ),
          ),
          if (durationStr.isNotEmpty)
            Card(
              child: ListTile(
                title: const Text('用时'),
                subtitle: Text(durationStr),
              ),
            ),
          if (steps != null)
            Card(
              child: ListTile(
                title: const Text('步数'),
                subtitle: Text(steps.toString()),
              ),
            ),
          if (distKm != null)
            Card(
              child: ListTile(
                title: const Text('距离'),
                subtitle: Text('${distKm.toStringAsFixed(2)} km'),
              ),
            ),
          if (avgSpeed != null)
            Card(
              child: ListTile(
                title: const Text('平均速度'),
                subtitle: Text('${avgSpeed.toStringAsFixed(2)} km/h'),
              ),
            ),
          Card(
            child: ListTile(
              title: const Text('模式'),
              subtitle: Text(mode == 'plan' ? '计划模式' : '非计划模式'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('状态'),
              subtitle: Text(_statusLabel(status)),
            ),
          ),
          if (startLoc != null)
            Card(
              child: ListTile(
                title: const Text('起点位置'),
                subtitle: Text(() {
                  // Note: `startLoc` is a nullable local variable. Type promotion does not
                  // apply inside closures, so we snapshot it to a non-null local first.
                  final sloc = startLoc;
                  if (sloc == null) return '';
                  final lat = sloc['lat'];
                  final lon = sloc['lon'];
                  final name = sloc['name'];
                  final addr = sloc['address'];
                  final parts = <String>[];
                  if (lat != null && lon != null) {
                    parts.add('(' + lat.toString() + ', ' + lon.toString() + ')');
                  }
                  if (name != null && name.toString().isNotEmpty) {
                    parts.add(name.toString());
                  }
                  if (addr != null && addr.toString().isNotEmpty) {
                    parts.add(addr.toString());
                  }
                  return parts.join('\n');
                }()),
              ),
            ),
          if (endLoc != null)
            Card(
              child: ListTile(
                title: const Text('终点位置'),
                subtitle: Text(() {
                  // Same promotion limitation applies here.
                  final eloc = endLoc;
                  if (eloc == null) return '';
                  final lat = eloc['lat'];
                  final lon = eloc['lon'];
                  final name = eloc['name'];
                  final addr = eloc['address'];
                  final parts = <String>[];
                  if (lat != null && lon != null) {
                    parts.add('(' + lat.toString() + ', ' + lon.toString() + ')');
                  }
                  if (name != null && name.toString().isNotEmpty) {
                    parts.add(name.toString());
                  }
                  if (addr != null && addr.toString().isNotEmpty) {
                    parts.add(addr.toString());
                  }
                  return parts.join('\n');
                }()),
              ),
            ),
        ],
      ),
    );
  }
}