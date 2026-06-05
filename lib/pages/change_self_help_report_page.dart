import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/self_help_dao.dart';

/// Trend report for the "Change · Self-help" measurement system.
///
/// Displays recent composite arousal (0..10) and zone distribution.
class ChangeSelfHelpReportPage extends StatefulWidget {
  const ChangeSelfHelpReportPage({super.key});

  @override
  State<ChangeSelfHelpReportPage> createState() => _ChangeSelfHelpReportPageState();
}

class _ChangeSelfHelpReportPageState extends State<ChangeSelfHelpReportPage> {
  final _dao = SelfHelpDao();
  int _days = 7;
  bool _loading = true;
  List<Map<String, dynamic>> _records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _dao.recordsInLastDays(_days);
    final validRows = rows.where(_isValidRecord).toList(growable: false);
    if (mounted) {
      setState(() {
        _records = validRows;
        _loading = false;
      });
    }
  }


  bool _isValidRecord(Map<String, dynamic> r) {
    final zone = (r['zone'] ?? '').toString().trim();
    if (zone.isNotEmpty) return true;

    // Any meaningful numeric signal (subjective/objective/wearable snapshot)
    const keys = <String>[
      'arousal_0_10',
      'arousal_0_100',
      'distress_0_100',
      'demand_0_100',
      'resources_0_100',
      'bpm',
      'rmssd_ms',
      'signal_quality',
      'subjective_index_0_1',
      'physiological_index_0_1',
      'fitbit_resting_bpm',
      'fitbit_current_bpm',
      'fitbit_hrv_rmssd_ms',
      'fitbit_breathing_rate',
      'fitbit_sleep_minutes',
      'fitbit_sleep_efficiency',
      'fitbit_steps',
      'fitbit_spo2_avg',
      'fitbit_skin_temp_dev',
      'fitbit_active_zone_minutes',
      'fitbit_cardio_score',
    ];
    for (final k in keys) {
      final v = r[k];
      if (v is num) return true;
      if (v is String && v.trim().isNotEmpty) return true;
    }
    return false;
  }


double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _zoneFromRow(Map<String, dynamic> r) {
  final z = (r['zone'] ?? '').toString();
  if (z.contains('舒适')) return '舒适区';
  if (z.contains('学习')) return '学习区';
  if (z.contains('恐慌')) return '恐慌区';

  // Backward compat: infer zone if legacy records didn't save it.
  final ar = _fallbackArousal0To10(r);
  final distress = (_toDouble(r['distress_0_100']) ?? 50.0).clamp(0.0, 100.0);
  final demand = (_toDouble(r['demand_0_100']) ?? 50.0).clamp(0.0, 100.0);
  final res = (_toDouble(r['resources_0_100']) ?? 50.0).clamp(0.0, 100.0);
  final gap = (demand - res) / 100.0;

  if (ar >= 7.0 || distress >= 75.0 || gap >= 0.25) return '恐慌区';
  if (ar <= 3.0 && distress <= 35.0 && gap <= -0.05) return '舒适区';
  return '学习区';
}
  
double _fallbackArousal0To10(Map<String, dynamic> r) {
  // Prefer the stored composite score.
  final a = _toDouble(r['arousal_0_10']);
  if (a != null) return a.clamp(0.0, 10.0);

  // If legacy records stored model indices but not the composite, rebuild it.
  final subj = _toDouble(r['subjective_index_0_1']);
  final phys = _toDouble(r['physiological_index_0_1']);
  if (subj != null && phys != null) {
    final c01 = (0.55 * subj + 0.45 * phys).clamp(0.0, 1.0);
    return (c01 * 10.0).clamp(0.0, 10.0);
  }

  // Otherwise compute a conservative approximation from available inputs.
  final arousal100 = _toDouble(r['arousal_0_100']) ?? 50.0;
  final distress100 = _toDouble(r['distress_0_100']) ?? 50.0;
  final stai = _toDouble(r['stai6_prorated']) ?? 50.0;
  final bpm = _toDouble(r['bpm']);
  final rmssd = _toDouble(r['rmssd_ms']);

  final stai01 = ((stai - 20.0) / 60.0).clamp(0.0, 1.0);
  final a01 = (arousal100 / 100.0).clamp(0.0, 1.0);
  final d01 = (distress100 / 100.0).clamp(0.0, 1.0);

  double o = 0.5;
  if (bpm != null) o = 0.6 * ((bpm - 60.0) / 60.0).clamp(0.0, 1.0) + 0.4 * o;
  if (rmssd != null) o = 0.6 * (1.0 - ((rmssd - 20.0) / 60.0).clamp(0.0, 1.0)) + 0.4 * o;

  final c01 = (0.45 * a01 + 0.25 * d01 + 0.20 * stai01 + 0.10 * o).clamp(0.0, 1.0);
  return (c01 * 10.0).clamp(0.0, 10.0);
}

  @override
  Widget build(BuildContext context) {
    // Aggregate into daily points so the trend chart is meaningful even if the
    // user measures multiple times on the same day (otherwise labels repeat and
    // the line looks misleadingly flat).
    final spots = <FlSpot>[];
    final labels = <String>[];
    final sums = <double>[];
    final counts = <int>[];
    final dayKeys = <String>[];

    int comfort = 0, learning = 0, panic = 0;

    for (final r in _records) {
      final tsRaw = r['timestamp_ms'];
      final ts = (tsRaw is int)
          ? tsRaw
          : (tsRaw is num)
              ? tsRaw.toInt()
              : 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final dayKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final y = _fallbackArousal0To10(r);

      if (dayKeys.isEmpty || dayKeys.last != dayKey) {
        dayKeys.add(dayKey);
        labels.add('${dt.month}/${dt.day}');
        sums.add(y);
        counts.add(1);
      } else {
        final last = sums.length - 1;
        sums[last] += y;
        counts[last] += 1;
      }

      final z = _zoneFromRow(r);
      if (z == '舒适区') comfort++;
      else if (z == '恐慌区') panic++;
      else learning++;
    }

    for (int i = 0; i < sums.length; i++) {
      final avg = sums[i] / math.max(1, counts[i]);
      spots.add(FlSpot(i.toDouble(), avg));
    }

    final total = math.max(1, comfort + learning + panic);

    return Scaffold(
      appBar: AppBar(title: const Text('趋势报告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CupertinoSegmentedControl<int>(
                  groupValue: _days,
                  onValueChanged: (v) {
                    setState(() => _days = v);
                    _load();
                  },
                  children: const {
                    7: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('7天')),
                    30: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('30天')),
                  },
                ),
                const SizedBox(height: 16),
                Text('趋势仅统计已保存记录（本区间共 ${_records.length} 条）。若刚测完但未点击“保存本次测评”，不会出现在这里。', style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
                const SizedBox(height: 10),
                _card(
                  title: '综合唤醒（0–10）',
                  child: SizedBox(
                    height: 220,
                    child: spots.isEmpty
                        ? const Center(child: Text('暂无数据'))
                        : LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: math.max(0, spots.length - 1).toDouble(),
                              minY: 0,
                              maxY: 10,
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 2,
                                    reservedSize: 32,
                                    getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: math.max(1, (labels.length / 6).ceil()).toDouble(),
                                    getTitlesWidget: (v, meta) {
                                      // fl_chart may call this with fractional values; only
                                      // render labels on integer x positions to avoid repeats.
                                      if ((v - v.roundToDouble()).abs() > 0.01) return const SizedBox.shrink();
                                      final idx = v.round();
                                      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(labels[idx], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: spots.length >= 3,
                                  barWidth: 3,
                                  dotData: FlDotData(show: spots.length <= 12),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: '三区占比',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _chip('舒适区', '${(comfort * 100 / total).toStringAsFixed(0)}%'),
                          _chip('学习区', '${(learning * 100 / total).toStringAsFixed(0)}%'),
                          _chip('恐慌区', '${(panic * 100 / total).toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            maxY: 100,
                            gridData: FlGridData(show: true),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 20,
                                  reservedSize: 32,
                                  getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, meta) {
                                    switch (v.toInt()) {
                                      case 0:
                                        return const Padding(padding: EdgeInsets.only(top: 6), child: Text('舒适', style: TextStyle(fontSize: 10)));
                                      case 1:
                                        return const Padding(padding: EdgeInsets.only(top: 6), child: Text('学习', style: TextStyle(fontSize: 10)));
                                      case 2:
                                        return const Padding(padding: EdgeInsets.only(top: 6), child: Text('恐慌', style: TextStyle(fontSize: 10)));
                                      default:
                                        return const SizedBox.shrink();
                                    }
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: comfort * 100.0 / total, width: 18)]),
                              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: learning * 100.0 / total, width: 18)]),
                              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: panic * 100.0 / total, width: 18)]),
                            ],
                          ),
                        ),
                      ),
                      const Text('说明：该占比来源于你每次测评保存时的“三区判定”。', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
