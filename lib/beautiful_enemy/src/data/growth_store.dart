import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/growth_profile.dart';

class EnemyGrowthStore {
  const EnemyGrowthStore(this.db);
  final Database db;
  static const String profileKey = 'growth_profile_v1';

  Future<EnemyGrowthProfile?> load() async {
    final rows =
        await db.query('be_setting', where: 'key = ?', whereArgs: [profileKey]);
    if (rows.isEmpty || rows.first['value'] == null) return null;
    return EnemyGrowthProfile.fromJson(
        jsonDecode(rows.first['value'] as String) as Map<String, dynamic>);
  }

  Future<void> save(EnemyGrowthProfile profile) async {
    if (profile.originalText.length > EnemyGrowthProfile.maxTextChars ||
        profile.weaknesses.isEmpty ||
        profile.weaknesses.any((w) =>
            w.id.isEmpty ||
            w.description.trim().isEmpty ||
            w.description.length > 500 ||
            w.goal.length > 300) ||
        profile.weaknesses.map((w) => w.id).toSet().length !=
            profile.weaknesses.length ||
        profile.strengths.length > 500 ||
        profile.values.length > 500) {
      throw const FormatException('请提供有效的弱点内容，每项不超过 500 字。');
    }
    await db.insert('be_setting',
        {'key': profileKey, 'value': jsonEncode(profile.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setEnabled(bool enabled) async {
    final p = await load();
    if (p == null) return;
    await save(EnemyGrowthProfile(
        sourceName: p.sourceName,
        originalText: p.originalText,
        weaknesses: p.weaknesses,
        updatedMs: p.updatedMs,
        enabled: enabled,
        strengths: p.strengths,
        values: p.values));
  }

  /// 删除档案和弱点关联，不删除用户已接受的独立承诺。
  Future<void> delete() => db.transaction((tx) async {
        await tx
            .delete('be_setting', where: 'key = ?', whereArgs: [profileKey]);
        await tx.delete('be_growth_action');
      });

  Future<List<Map<String, Object?>>> actions({int limit = 50}) =>
      db.rawQuery('''
    SELECT g.*, c.text AS action, c.due_ms, c.status
    FROM be_growth_action g JOIN be_commitment c ON c.id = g.commitment_id
    ORDER BY g.created_ms DESC, g.commitment_id DESC LIMIT ?''', [limit]);

  Future<int> review(
      int commitmentId, String observation, String adjustment) async {
    if (observation.trim().isEmpty ||
        observation.length > 1000 ||
        adjustment.length > 500) {
      throw const FormatException('请写具体结果（1000 字内）和下次调整（500 字内）。');
    }
    return db.update('be_growth_action',
        {'observation': observation.trim(), 'adjustment': adjustment.trim()},
        where: 'commitment_id = ?', whereArgs: [commitmentId]);
  }

  /// 与承诺及事件同一个事务，确保弱点关联不会丢失或留下半条行动。
  Future<int> createAction(
          {required GrowthWeakness weakness,
          required String action,
          required String obstaclePlan,
          required String evidence,
          required int nowMs,
          required int dueMs}) =>
      db.transaction((tx) async {
        final int id = await tx.insert('be_commitment', {
          'text': action,
          'created_ms': nowMs,
          'due_ms': dueMs,
          'status': 'open',
          'origin': 'growth_profile'
        });
        await tx.insert('be_growth_action', {
          'commitment_id': id,
          'weakness_id': weakness.id,
          'weakness': weakness.description,
          'goal': weakness.goal,
          'obstacle_plan': obstaclePlan,
          'evidence': evidence,
          'created_ms': nowMs
        });
        final d = DateTime.fromMillisecondsSinceEpoch(nowMs);
        await tx.insert('be_event', {
          'ts': nowMs,
          'source': 'commitment',
          'type': 'commitment_created',
          'dedupe_key': 'commitment:$id:commitment_created',
          'payload': jsonEncode({
            'commitment_id': id,
            'subject': 'commitment:$id',
            'label': action,
            'day':
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
          })
        });
        return id;
      });

  Future<Map<String, dynamic>> context() async {
    final profile = await load();
    if (profile == null || !profile.enabled) return <String, dynamic>{};
    final ids = profile.weaknesses.map((w) => w.id).toSet();
    return {
      ...profile.toContext(),
      'actions': (await actions(limit: 50))
          .where((a) => ids.contains(a['weakness_id']))
          .take(10)
          .map((a) => {
                ...a,
                'result_source': 'user_report_not_independently_verified',
              })
          .toList()
    };
  }
}
