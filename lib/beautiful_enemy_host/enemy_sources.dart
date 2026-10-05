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
class HabitEvidenceSource extends EvidenceSource {
  HabitEvidenceSource();

  @override
  String get id => 'habit';

  @override
  Future<String?> watermark(Database db) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      'SELECT COUNT(*) AS c, COALESCE(MAX(updated_at_ms), 0) AS u, '
      'COALESCE(MAX(reviewed_at_ms), 0) AS r FROM behavior_observation_preset_checkins',
      const <Object?>[],
    );
    if (rows.isEmpty) return null;
    return '${rows.first['c']}:${rows.first['u']}:${rows.first['r']}';
  }

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
class JournalEvidenceSource extends EvidenceSource {
  JournalEvidenceSource();

  @override
  String get id => 'journal';

  @override
  Future<String?> watermark(Database db) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      'SELECT COUNT(*) AS c, COALESCE(MAX(updated_at_ms), 0) AS u FROM behavior_tracking_records',
      const <Object?>[],
    );
    if (rows.isEmpty) return null;
    return '${rows.first['c']}:${rows.first['u']}';
  }

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
class KindlingEvidenceSource extends EvidenceSource {
  KindlingEvidenceSource();

  @override
  String get id => 'kindling';

  @override
  Future<String?> watermark(Database db) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      'SELECT COUNT(*) AS c, COALESCE(MAX(id), 0) AS m FROM k_burn',
      const <Object?>[],
    );
    if (rows.isEmpty) return null;
    return '${rows.first['c']}:${rows.first['m']}';
  }

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
class KnowledgeEvidenceSource extends EvidenceSource {
  KnowledgeEvidenceSource();

  @override
  String get id => 'knowledge';

  @override
  Future<String?> watermark(Database db) async {
    final List<Map<String, Object?>> rows = await _safeQuery(
      db,
      'SELECT COUNT(*) AS c, COALESCE(MAX(created_at_ms), 0) AS m '
      'FROM evidence_growth_knowledge_transforms',
      const <Object?>[],
    );
    if (rows.isEmpty) return null;
    return '${rows.first['c']}:${rows.first['m']}';
  }

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

/// App 前台使用时长。
///
/// 这不是读宿主的表：时长由宿主的前台计时器每分钟记一次（见 [EnemyHostPresence]），
/// 这里只是让它出现在「允许采集的模块」里，授权开关和其它来源一致。
class UsageEvidenceSource extends EvidenceSource {
  UsageEvidenceSource();

  @override
  String get id => EnemyEngine.usageSourceId;

  @override
  String get label => '使用时长（App 前台时间，只记分钟数）';

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async => <EventDraft>[];
}

/// 其它模块的动静：哪个模块、何时有了新记录。**不读内容**，只看有没有新行和它的时间。
///
/// 用 `PRAGMA table_info` 自己找时间列；找不到或表不存在就跳过。表名全部来自下面的
/// 常量表，不拼接任何用户输入。标签是按表名推断的，可能不完全准确。
class ModuleActivitySource extends EvidenceSource {
  ModuleActivitySource();

  @override
  String get id => 'activity';

  @override
  String get label => '其它模块的动静（只记录何时有新记录，不读内容）';

  /// 表名 → 界面上叫它什么。
  static const Map<String, String> tables = <String, String>{
    'will_task_execution': '意志力 · 任务执行',
    'will_review_entry': '意志力 · 复盘',
    'goal_action_record': '目标 · 行动记录',
    'goal_effort_entries': '目标 · 投入记录',
    'goal_reflections': '目标 · 反思',
    'goal_step_reviews': '目标 · 步骤复盘',
    'woop_action_daily_checkins': 'WOOP · 每日打卡',
    'meditation_records': '冥想',
    'sport_records': '运动',
    'daily_diet_entries': '饮食记录',
    'james_will_logs': '意志力日志',
    'xiangji_checkins': '向己 · 打卡',
    'ce_action_step_records': '行动步骤',
    'change_abc_journals': 'ABC 日记',
    'self_help_records': '自助记录',
    'realistic_optimism_action_logs': '现实乐观 · 行动',
    'realistic_positivity_os_checkins': '现实积极 · 打卡',
    'evidence_growth_journal': '证据成长 · 日志',
    'goal_raisebase_check_ins': '目标 · 打卡',
    'vision_reflections': '愿景 · 反思',
    'act_compass_practice_logs': '行动罗盘 · 练习',
    'affect_recovery_logs': '情绪恢复',
    'emotions': '情绪记录',
    'tasks': '待办',
  };

  static const List<String> _timeColumns = <String>[
    'created_at_ms',
    'updated_at_ms',
    'created_at',
    'updated_at',
    'recorded_at',
    'timestamp',
    'ts',
    'time_ms',
    'date_ms',
  ];

  /// 同一个模块 10 分钟内的多条新记录合并成一次「动静」。
  static const int bucketMs = 10 * 60 * 1000;
  static const int perTableLimit = 20;

  /// 往回看多久。看两周，是为了认出「曾经常有记录、最近一直没有」的沉寂模块；
  /// 敌人只对刚发生的动静插话（见 EnemyPresence.freshWindow），旧的只作为背景。
  static const int lookbackMs = 14 * 24 * 3600 * 1000;

  final Map<int, Map<String, String>> _plans = <int, Map<String, String>>{};

  /// 这个库里实际存在、且找得到时间列的表 → 时间列。每个库只探测一次。
  Future<Map<String, String>> _plan(Database db) async {
    final int key = identityHashCode(db);
    final Map<String, String>? cached = _plans[key];
    if (cached != null) return cached;
    final Map<String, String> plan = <String, String>{};
    for (final String table in tables.keys) {
      try {
        final List<Map<String, Object?>> info = await db.rawQuery('PRAGMA table_info("$table")');
        if (info.isEmpty) continue;
        final Set<String> cols =
            info.map((Map<String, Object?> r) => (r['name'] ?? '').toString()).toSet();
        for (final String c in _timeColumns) {
          if (cols.contains(c)) {
            plan[table] = c;
            break;
          }
        }
      } catch (_) {
        continue;
      }
    }
    _plans[key] = plan;
    return plan;
  }

  @override
  Future<String?> watermark(Database db) async {
    final Map<String, String> plan = await _plan(db);
    if (plan.isEmpty) return null;
    final String sql = plan.keys
        .map((String t) => 'SELECT \'$t\' AS t, COALESCE(MAX(rowid), 0) AS m FROM "$t"')
        .join(' UNION ALL ');
    final List<Map<String, Object?>> rows = await _safeQuery(db, sql, const <Object?>[]);
    if (rows.isEmpty) return null;
    return rows.map((Map<String, Object?> r) => '${r['t']}=${r['m']}').join(',');
  }

  @override
  Future<List<EventDraft>> collect(Database db, int sinceMs) async {
    final Map<String, String> plan = await _plan(db);
    final int floor = DateTime.now().millisecondsSinceEpoch - lookbackMs;
    final int from = sinceMs > floor ? sinceMs : floor;
    final List<EventDraft> out = <EventDraft>[];
    for (final MapEntry<String, String> e in plan.entries) {
      final String table = e.key;
      final String col = e.value;
      final List<Map<String, Object?>> rows = await _safeQuery(
        db,
        'SELECT rowid AS rid, "$col" AS ts FROM "$table" ORDER BY rowid DESC LIMIT $perTableLimit',
        const <Object?>[],
      );
      for (final Map<String, Object?> r in rows) {
        final int? ms = parseTimestamp(r['ts']);
        if (ms == null || ms < from) continue;
        out.add(EventDraft(
          ts: ms,
          source: id,
          type: 'module_activity',
          dedupeKey: 'activity:$table:${ms ~/ bucketMs}',
          payload: <String, dynamic>{
            'subject': 'table:$table',
            'label': tables[table] ?? table,
            'day': _dayKey(ms),
          },
        ));
      }
    }
    return out;
  }

  /// 毫秒、秒、数字字符串、ISO 时间都认；认不出来返回 null。
  static int? parseTimestamp(Object? v) {
    if (v == null) return null;
    num? n;
    if (v is num) {
      n = v;
    } else {
      final String s = v.toString().trim();
      if (s.isEmpty) return null;
      n = num.tryParse(s);
      if (n == null) return DateTime.tryParse(s)?.millisecondsSinceEpoch;
    }
    if (n >= 1000000000000) return n.toInt(); // 毫秒
    if (n >= 1000000000) return (n * 1000).toInt(); // 秒
    return null;
  }
}

/// 宿主接入的全部证据来源。以后要让敌人多看一个模块，就在这里加一个类。
List<EvidenceSource> defaultEnemySources() => <EvidenceSource>[
      HabitEvidenceSource(),
      JournalEvidenceSource(),
      KindlingEvidenceSource(),
      KnowledgeEvidenceSource(),
      ModuleActivitySource(),
      UsageEvidenceSource(),
    ];
