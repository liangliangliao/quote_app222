import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'defense_compass_models.dart';

/// 自我防御罗盘独立 DAO。
///
/// 仅创建 defense_compass_* 表与 defense_compass_* KV，避免与其他已有模块融合。
class DefenseCompassDao {
  static const String profileKey = 'defense_compass_profile_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS defense_compass_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        scene TEXT,
        output_mode TEXT,
        user_input TEXT,
        ai_response TEXT,
        event_summary TEXT,
        facts TEXT,
        interpretation TEXT,
        emotions_json TEXT,
        hidden_emotions_json TEXT,
        id_wishes_json TEXT,
        superego_prohibitions_json TEXT,
        external_reality TEXT,
        primary_anxiety_source TEXT,
        anxiety_explanation TEXT,
        defense_mechanisms_json TEXT,
        defense_evidence TEXT,
        protective_function TEXT,
        long_term_cost TEXT,
        reality_check TEXT,
        micro_action TEXT,
        output_card_type TEXT,
        risk_level TEXT,
        raw_json TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS defense_compass_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        action_type TEXT,
        action_text TEXT,
        difficulty TEXT,
        status TEXT,
        reflection TEXT,
        after_emotion TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS defense_compass_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        report_type TEXT,
        period_label TEXT,
        title TEXT,
        content TEXT,
        raw_json TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS defense_compass_course_progress (
        course_id TEXT PRIMARY KEY,
        updated_at_ms INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_defense_compass_sessions_created ON defense_compass_sessions(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_defense_compass_actions_status ON defense_compass_actions(status, created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_defense_compass_reports_created ON defense_compass_reports(created_at_ms DESC)');
  }

  Future<DefenseCompassProfile> loadProfile() async {
    final raw = await _kv.getString(profileKey);
    if (raw == null || raw.trim().isEmpty) return const DefenseCompassProfile();
    return DefenseCompassProfile.fromRaw(raw);
  }

  Future<void> saveProfile(DefenseCompassProfile profile) async {
    final next = profile.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    await _kv.setString(profileKey, next.encode());
  }

  Future<int> insertSession(DefenseCompassSession session) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = session.copyWith(
      createdAtMs: session.createdAtMs == 0 ? now : session.createdAtMs,
      updatedAtMs: now,
    );
    final id = await database.insert('defense_compass_sessions', row.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
    final action = row.microAction.trim();
    if (action.isNotEmpty && row.riskLevel != 'crisis' && row.riskLevel != 'high') {
      await insertAction(DefenseCompassAction(
        sessionId: id,
        createdAtMs: now,
        updatedAtMs: now,
        actionType: _inferActionType(row),
        actionText: action,
        difficulty: 'low',
        status: 'open',
      ));
    }
    if (row.scene == 'monthly_review' || row.outputCardType == 'monthly_report') {
      await insertReport(DefenseCompassReport(
        createdAtMs: now,
        reportType: 'monthly_review',
        periodLabel: _currentMonthLabel(),
        title: row.eventSummary.trim().isEmpty ? '月度成长报告' : row.eventSummary.trim(),
        content: row.aiResponse.trim().isEmpty ? row.rawJson : row.aiResponse,
        rawJson: row.rawJson,
      ));
    }
    return id;
  }

  Future<int> insertAction(DefenseCompassAction action) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = action.copyWith(
      createdAtMs: action.createdAtMs == 0 ? now : action.createdAtMs,
      updatedAtMs: now,
    );
    return database.insert('defense_compass_actions', row.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAction(DefenseCompassAction action) async {
    if (action.id <= 0) return;
    final database = await _db;
    await database.update(
      'defense_compass_actions',
      action.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).toDb(),
      where: 'id = ?',
      whereArgs: <Object?>[action.id],
    );
  }

  Future<int> insertReport(DefenseCompassReport report) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = report.copyWith(createdAtMs: report.createdAtMs == 0 ? now : report.createdAtMs);
    return database.insert('defense_compass_reports', row.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DefenseCompassReport>> listReports({int limit = 36}) async {
    final database = await _db;
    final rows = await database.query(
      'defense_compass_reports',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(DefenseCompassReport.fromDb).toList(growable: false);
  }

  Future<void> upsertCourseProgress(DefenseCompassCourseProgress progress) async {
    final database = await _db;
    await database.insert(
      'defense_compass_course_progress',
      progress.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, DefenseCompassCourseProgress>> listCourseProgress() async {
    final database = await _db;
    final rows = await database.query('defense_compass_course_progress');
    return <String, DefenseCompassCourseProgress>{
      for (final row in rows)
        DefenseCompassCourseProgress.fromDb(row).courseId: DefenseCompassCourseProgress.fromDb(row),
    };
  }

  Future<List<DefenseCompassSession>> listSessions({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query(
      'defense_compass_sessions',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(DefenseCompassSession.fromDb).toList(growable: false);
  }

  Future<List<DefenseCompassAction>> listActions({int limit = 120, String? status}) async {
    final database = await _db;
    final rows = await database.query(
      'defense_compass_actions',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(DefenseCompassAction.fromDb).toList(growable: false);
  }

  Future<void> clearAll() async {
    final database = await _db;
    await database.delete('defense_compass_actions');
    await database.delete('defense_compass_reports');
    await database.delete('defense_compass_course_progress');
    await database.delete('defense_compass_sessions');
    await _kv.setString(profileKey, '');
  }

  Future<String> recentContextJson({int limit = 12}) async {
    final sessions = await listSessions(limit: limit);
    final actions = await listActions(limit: 20);
    final reports = await listReports(limit: 6);
    final courses = await listCourseProgress();
    return jsonEncode(<String, dynamic>{
      'recent_sessions': sessions.map((s) => <String, dynamic>{
            'created_at_ms': s.createdAtMs,
            'scene': s.scene,
            'event_summary': s.eventSummary,
            'emotions': s.emotions,
            'primary_anxiety_source': s.primaryAnxietySource,
            'defense_mechanisms': s.defenseMechanisms,
            'micro_action': s.microAction,
            'risk_level': s.riskLevel,
          }).toList(growable: false),
      'recent_actions': actions.map((a) => <String, dynamic>{
            'action_type': a.actionType,
            'action_text': a.actionText,
            'status': a.status,
            'reflection': a.reflection,
            'after_emotion': a.afterEmotion,
          }).toList(growable: false),
      'recent_reports': reports.map((r) => <String, dynamic>{
            'period_label': r.periodLabel,
            'title': r.title,
            'content_preview': r.content.length > 300 ? "${r.content.substring(0, 300)}…" : r.content,
          }).toList(growable: false),
      'course_progress': courses.values.map((c) => <String, dynamic>{
            'course_id': c.courseId,
            'completed': c.completed,
            'note': c.note,
          }).toList(growable: false),
    });
  }

  Future<DefenseCompassStats> stats() async {
    final sessions = await listSessions(limit: 500);
    final actions = await listActions(limit: 500);
    final reports = await listReports(limit: 500);
    final courses = await listCourseProgress();
    final defense = <String, int>{};
    final anxiety = <String, int>{};
    final scenes = <String, int>{};
    final actionTypes = <String, int>{};
    final actionStatuses = <String, int>{};
    for (final s in sessions) {
      scenes[s.scene] = (scenes[s.scene] ?? 0) + 1;
      if (s.primaryAnxietySource.trim().isNotEmpty) {
        anxiety[s.primaryAnxietySource] = (anxiety[s.primaryAnxietySource] ?? 0) + 1;
      }
      for (final d in s.defenseMechanisms) {
        if (d.trim().isEmpty) continue;
        defense[d] = (defense[d] ?? 0) + 1;
      }
    }
    for (final a in actions) {
      if (a.actionType.trim().isNotEmpty) {
        actionTypes[a.actionType] = (actionTypes[a.actionType] ?? 0) + 1;
      }
      actionStatuses[a.status] = (actionStatuses[a.status] ?? 0) + 1;
    }
    return DefenseCompassStats(
      sessionCount: sessions.length,
      actionCount: actions.length,
      completedActionCount: actions.where((a) => a.status == 'completed').length,
      reportCount: reports.length,
      completedCourseCount: courses.values.where((c) => c.completed).length,
      defenseCounts: _sortMap(defense),
      anxietyCounts: _sortMap(anxiety),
      sceneCounts: _sortMap(scenes),
      actionTypeCounts: _sortMap(actionTypes),
      actionStatusCounts: _sortMap(actionStatuses),
    );
  }

  Map<String, int> _sortMap(Map<String, int> raw) {
    final entries = raw.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map<String, int>.fromEntries(entries.take(12));
  }

  String _currentMonthLabel() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  String _inferActionType(DefenseCompassSession s) {
    final joined = '${s.scene} ${s.defenseMechanisms.join(' ')} ${s.microAction}';
    if (joined.contains('现实检验') || joined.contains('投射') || joined.contains('验证')) return 'reality_check';
    if (joined.contains('情绪') || joined.contains('停留') || joined.contains('容纳')) return 'affect_tolerance';
    if (joined.contains('愿望') || joined.contains('需求') || joined.contains('表达')) return 'wish_integration';
    if (joined.contains('边界') || joined.contains('拒绝')) return 'boundary';
    if (joined.contains('自我限制') || joined.contains('恢复')) return 'capacity_recovery';
    if (joined.contains('关系') || joined.contains('沟通')) return 'relationship_repair';
    return 'micro_action';
  }
}
