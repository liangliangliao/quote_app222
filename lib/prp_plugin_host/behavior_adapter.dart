import 'package:sqflite/sqflite.dart';

import '../prp_plugin/prp_plugin.dart';

class PrpBehaviorAdapter {
  const PrpBehaviorAdapter(this.openDatabase);
  final Future<Database> Function() openDatabase;
  int? _preset(String key) => key.startsWith('habit:preset:')
      ? int.tryParse(key.split(':').last)
      : null;

  Future<List<PrpEvidence>> evidence(PrpSignal signal) async {
    final preset = _preset(signal.subjectKey);
    if (preset == null) return [];
    final db = await openDatabase();
    if ((await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='behavior_observation_preset_checkins'"))
        .isEmpty) return [];
    final rows = await db.query('behavior_observation_preset_checkins',
        where: 'preset_id = ?',
        whereArgs: [preset],
        orderBy: 'check_date_ms DESC',
        limit: 7);
    return [
      for (final row in rows) ...[
        PrpEvidence(
            source: 'habit',
            id: '${row['id']}',
            label:
                '${DateTime.fromMillisecondsSinceEpoch((row['check_date_ms'] as num).toInt()).toString().substring(0, 10)} · 明确记录：${row['status']}'),
        if ('${row['missed_reason'] ?? ''}'.trim().isNotEmpty)
          PrpEvidence(
              source: 'habit_reason',
              id: '${row['id']}',
              label: '该次打卡附有用户自述，原文保留在行为追踪记录中',
              kind: 'self_report'),
      ]
    ];
  }

  Future<List<PrpDayMark>> recentDays(
      String subjectKey, DateTime now, int days) async {
    final preset = _preset(subjectKey);
    if (preset == null) return [];
    final db = await openDatabase();
    if ((await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='behavior_observation_preset_checkins'"))
        .isEmpty) return [];
    final start = DateTime(now.year, now.month, now.day - days + 1)
        .millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query('behavior_observation_preset_checkins',
        where: 'preset_id = ? AND check_date_ms >= ? AND check_date_ms < ?',
        whereArgs: [preset, start, end]);
    final statuses = {
      for (final row in rows)
        (row['check_date_ms'] as num).toInt(): '${row['status']}'
    };
    return List.generate(days, (i) {
      final day = DateTime(now.year, now.month, now.day - days + 1 + i)
          .millisecondsSinceEpoch;
      final status = statuses[day];
      return PrpDayMark(
          dateMs: day,
          status: status == 'done' || status == 'missed' ? status! : 'unknown');
    });
  }
}
