import 'package:sqflite/sqflite.dart';

import '../beautiful_enemy/beautiful_enemy.dart';

String _dayKey(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

Future<List<Map<String, Object?>>> _safeQuery(
  Database db,
  String sql,
  List<Object?> args,
) async {
  try {
    return await db.rawQuery(sql, args);
  } catch (_) {
    // 表还没建（模块没用过）或结构不同：当作没有证据，不抛。
    return <Map<String, Object?>>[];
  }
}

/// 行为追踪里的预设行为打卡：完成 / 未完成 / 跳过。
class HabitEvidenceSource implements EvidenceSource {
  const HabitEvidenceSource();

  @override
  String get id => 'habit';

  @override
  String get label => '预设行为打卡（行为追踪）';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      '''
      SELECT c.id AS id, c.preset_id AS preset_id, c.check_date_ms AS check_date_ms,
             c.status AS status, c.reviewed_at_ms AS reviewed_at_ms,
             c.updated_at_ms AS updated_at_ms, c.missed_reason AS missed_reason,
             p.name AS name
      FROM behavior_observation_preset_checkins c
      LEFT JOIN behavior_observation_presets p ON p.id = c.preset_id
      WHERE c.check_date_ms >= ? AND c.status IN ('done', 'missed', 'skipped')
      ''',
      <Object?>[sinceMs],
    );
    final List<EventDraft> out = <EventDraft>[];
    for (final Map<String, Object?> r in rows) {
      final String status = (r['status'] ?? '').toString();
      final int dayMs = _int(r['check_date_ms']);
      final int ts = _int(r['reviewed_at_ms'], 0) > 0
          ? _int(r['reviewed_at_ms'])
          : (_int(r['updated_at_ms'], 0) > 0 ? _int(r['updated_at_ms']) : dayMs);
      out.add(EventDraft(
        ts: ts,
        source: id,
        type: 'habit_$status',
        dedupeKey: 'habit:${r['id']}:$status',
        payload: <String, dynamic>{
          'subject': 'preset:${r['preset_id']}',
          'label': (r['name'] ?? '').toString(),
          'day': _dayKey(dayMs),
          'reason': (r['missed_reason'] ?? '').toString(),
        },
      ));
    }
    return out;
  }
}

/// 行为追踪里的行为记录。不含两类：预设打卡自动生成的（已由 habit 来源覆盖，避免重复），
/// 以及 AI 生成的每日总结（那是转述，不是发生过的事，不能当证据）。
class JournalEvidenceSource implements EvidenceSource {
  const JournalEvidenceSource();

  @override
  String get id => 'journal';

  @override
  String get label => '行为记录（行为追踪）';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      '''
      SELECT id, created_at_ms, record_date_ms, title, category
      FROM behavior_tracking_records
      WHERE created_at_ms >= ?
        AND COALESCE(source, '') NOT IN ('planned_behavior', 'auto_daily_summary')
      ''',
      <Object?>[sinceMs],
    );
    return rows
        .map((Map<String, Object?> r) => EventDraft(
              ts: _int(r['created_at_ms']),
              source: id,
              type: 'journal_entry',
              dedupeKey: 'journal:${r['id']}',
              payload: <String, dynamic>{
                'subject': 'record:${r['id']}',
                'label': (r['title'] ?? '').toString(),
                'day': _dayKey(_int(r['record_date_ms'], _int(r['created_at_ms']))),
              },
            ))
        .toList();
  }
}

/// 火种的十五分钟：完成或中途退出。
class KindlingEvidenceSource implements EvidenceSource {
  const KindlingEvidenceSource();

  @override
  String get id => 'kindling';

  @override
  String get label => '火种（十五分钟）';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      '''
      SELECT b.id AS id, b.started_at AS started_at, b.seconds AS seconds,
             b.aborted AS aborted, i.title AS title
      FROM k_burn b LEFT JOIN k_item i ON i.id = b.item_id
      WHERE b.started_at >= ?
      ''',
      <Object?>[sinceMs],
    );
    return rows.map((Map<String, Object?> r) {
      final bool aborted = _int(r['aborted']) == 1;
      final int start = _int(r['started_at']);
      return EventDraft(
        ts: start,
        source: id,
        type: aborted ? 'kindling_aborted' : 'kindling_completed',
        dedupeKey: 'kindling:${r['id']}',
        payload: <String, dynamic>{
          'subject': 'burn:${r['id']}',
          'label': (r['title'] ?? '').toString(),
          'day': _dayKey(start),
          'minutes': (_int(r['seconds']) / 60).round(),
        },
      );
    }).toList();
  }
}

/// 知识卡片的「6 步转换」成功记录。
class KnowledgeEvidenceSource implements EvidenceSource {
  const KnowledgeEvidenceSource();

  @override
  String get id => 'knowledge';

  @override
  String get label => '知识卡片转换（发现之旅）';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      '''
      SELECT transform_id, node_title, created_at_ms
      FROM evidence_growth_knowledge_transforms
      WHERE created_at_ms >= ?
      ''',
      <Object?>[sinceMs],
    );
    return rows
        .map((Map<String, Object?> r) => EventDraft(
              ts: _int(r['created_at_ms']),
              source: id,
              type: 'knowledge_converted',
              dedupeKey: 'knowledge:${r['transform_id']}',
              payload: <String, dynamic>{
                'subject': 'transform:${r['transform_id']}',
                'label': (r['node_title'] ?? '').toString(),
                'day': _dayKey(_int(r['created_at_ms'])),
              },
            ))
        .toList();
  }
}

/// 宿主接入的全部证据来源。以后要让敌人多看一个模块，就在这里加一个类。
List<EvidenceSource> defaultEnemySources() => const <EvidenceSource>[
      HabitEvidenceSource(),
      JournalEvidenceSource(),
      KindlingEvidenceSource(),
      KnowledgeEvidenceSource(),
    ];
