import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../beautiful_enemy/beautiful_enemy.dart'
    show DraftValidator, SafetyValve, EnemyDao, EnemyEngine, LocalFactOracle;
import '../prp_plugin/prp_plugin.dart';

class PrpEnemyAdapter {
  const PrpEnemyAdapter(this.openDatabase);
  final Future<Database> Function() openDatabase;

  PrpGuardResult guardText(String text) => PrpGuardResult(
        crisis: SafetyValve.isCrisis(text),
        truce: SafetyValve.isTruce(text),
        problems: [
          if (DraftValidator.containsBanned(text)) 'banned_content',
          if (DraftValidator.profanityMarkers.any(text.contains))
            'profanity_not_allowed',
        ],
      );

  Future<Map<String, String>> settings() async {
    final db = await openDatabase();
    final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='be_setting'");
    if (exists.isEmpty) return {};
    return {
      for (final row in await db.query('be_setting'))
        '${row['key']}': '${row['value'] ?? ''}'
    };
  }

  Future<PrpGovernance> governance(DateTime now) async {
    final values = await settings();
    final start =
        (int.tryParse(values['quiet_start_hour'] ?? '') ?? 23).clamp(0, 23);
    final end =
        (int.tryParse(values['quiet_end_hour'] ?? '') ?? 7).clamp(0, 23);
    final quiet = start == end
        ? false
        : start < end
            ? now.hour >= start && now.hour < end
            : now.hour >= start || now.hour < end;
    return PrpGovernance(
        quiet: quiet,
        muted: (int.tryParse(values['muted_until_ms'] ?? '') ?? 0) >
            now.millisecondsSinceEpoch);
  }

  Future<void> safetyExit(DateTime now, {bool crisis = true}) async {
    final db = await openDatabase();
    final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='be_setting'");
    if (exists.isEmpty) return;
    // Reuse the existing safety valve, without creating or migrating enemy tables.
    final engine = EnemyEngine(
        dao: EnemyDao(db), oracle: const LocalFactOracle(), clock: () => now);
    await engine.muteFor24h(crisis: crisis);
  }

  Future<List<PrpEvidence>> evidence(PrpSignal signal) async {
    final id = int.tryParse(signal.subjectKey.replaceFirst('commitment:', ''));
    if (id == null) return [];
    final db = await openDatabase();
    if ((await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='be_commitment'"))
        .isEmpty) return [];
    final rows =
        await db.query('be_commitment', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return [];
    final row = rows.first;
    return [
      PrpEvidence(
          source: 'commitment',
          id: '$id',
          label: '字据 #$id；明确记录的状态：${row['status']}')
    ];
  }

  Future<List<PrpDayMark>> recentDays(
      String subjectKey, DateTime now, int days) async {
    final id = int.tryParse(subjectKey.replaceFirst('commitment:', ''));
    if (id == null) return [];
    final db = await openDatabase();
    if ((await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='be_commitment'"))
        .isEmpty) return [];
    final commitments =
        await db.query('be_commitment', columns: ['id', 'status']);
    if (!commitments.any((r) => r['id'] == id)) return [];
    final statuses = {
      for (final r in commitments) (r['id'] as num).toInt(): '${r['status']}'
    };
    final start = DateTime(now.year, now.month, now.day - days + 1)
        .millisecondsSinceEpoch;
    final end =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final counts = <int, List<int>>{};
    final seen = <int>{};
    void record(int key, int time, bool done) {
      if (!seen.add(key)) return;
      final date = DateTime.fromMillisecondsSinceEpoch(time);
      final day =
          DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      counts.putIfAbsent(day, () => [0, 0])[done ? 0 : 1]++;
    }

    final eventsExist = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='be_event'"))
        .isNotEmpty;
    if (eventsExist) {
      final rows = await db.query('be_event',
          columns: ['type', 'payload', 'ts'],
          where:
              "source='commitment' AND type IN ('commitment_done','commitment_missed') AND ts>=? AND ts<?",
          whereArgs: [start, end],
          orderBy: 'ts DESC');
      for (final r in rows) {
        try {
          final payload = jsonDecode('${r['payload']}') as Map;
          final key = (payload['commitment_id'] as num).toInt();
          final done =
              r['type'] == 'commitment_done' && statuses[key] == 'done';
          final missed = r['type'] == 'commitment_missed' &&
              statuses[key] == 'missed' &&
              payload['confirmed_by_user'] == true;
          if (done || missed) record(key, (r['ts'] as num).toInt(), done);
        } catch (_) {
          /* Malformed/legacy automatic events provide no reliable outcome. */
        }
      }
    }
    final sessionsExist = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='prp_session'"))
        .isNotEmpty;
    if (sessionsExist) {
      final rows = await db.query('prp_session',
          columns: ['subject_key', 'started_ms'],
          where:
              "trigger_kind='commitment_missed' AND started_ms>=? AND started_ms<?",
          whereArgs: [start, end]);
      for (final r in rows) {
        final key =
            int.tryParse('${r['subject_key']}'.replaceFirst('commitment:', ''));
        if (key != null && statuses[key] == 'missed')
          record(key, (r['started_ms'] as num).toInt(), false);
      }
    }
    return List.generate(days, (i) {
      final date = DateTime(now.year, now.month, now.day - days + 1 + i)
          .millisecondsSinceEpoch;
      final value = counts[date] ?? [0, 0];
      final status = value[0] > 0 && value[1] > 0
          ? 'mixed'
          : value[0] > 0
              ? 'done'
              : value[1] > 0
                  ? 'missed'
                  : 'unknown';
      return PrpDayMark(
          dateMs: date,
          status: status,
          completedCount: value[0],
          missedCount: value[1]);
    });
  }
}
