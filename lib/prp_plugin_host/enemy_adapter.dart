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
    final rows = await db.query('be_commitment',
        columns: ['created_ms', 'status'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return [];
    final row = rows.first;
    final created =
        DateTime.fromMillisecondsSinceEpoch((row['created_ms'] as num).toInt());
    final day = DateTime(created.year, created.month, created.day)
        .millisecondsSinceEpoch;
    return List.generate(days, (i) {
      final date = DateTime(now.year, now.month, now.day - days + 1 + i)
          .millisecondsSinceEpoch;
      final status = date == day && ['done', 'missed'].contains(row['status'])
          ? '${row['status']}'
          : 'unknown';
      return PrpDayMark(dateMs: date, status: status);
    });
  }
}
