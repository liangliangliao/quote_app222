import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'adaptation_compass_models.dart';

/// Adaptation Compass 独立 DAO。
///
/// 只创建 adaptation_compass_* 表和 adaptation_compass_* KV，不复用 defense_compass 或其他模块表。
class AdaptationCompassDao {
  static const String profileKey = 'adaptation_compass_profile_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  scene TEXT NOT NULL,
  user_input TEXT NOT NULL,
  ai_response TEXT NOT NULL,
  event_summary TEXT,
  facts TEXT,
  interpretation TEXT,
  emotions_json TEXT,
  body_signals_json TEXT,
  needs_json TEXT,
  defense_layer TEXT,
  defense_mechanisms_json TEXT,
  protective_function TEXT,
  long_term_cost TEXT,
  reality_check TEXT,
  mature_alternatives_json TEXT,
  action_10m TEXT,
  action_24h TEXT,
  action_7d TEXT,
  relationship_impact TEXT,
  growth_question TEXT,
  development_task TEXT,
  balance_focus TEXT,
  generativity_step TEXT,
  risk_level TEXT,
  raw_json TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_sessions_created ON adaptation_compass_sessions(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_sessions_scene ON adaptation_compass_sessions(scene)');

    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  due_at_ms INTEGER,
  completed_at_ms INTEGER,
  source_session_id INTEGER,
  title TEXT NOT NULL,
  domain TEXT,
  horizon TEXT,
  status TEXT,
  reflection TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_actions_status ON adaptation_compass_actions(status, due_at_ms)');

    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_balance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  work_score INTEGER,
  love_score INTEGER,
  play_score INTEGER,
  body_score INTEGER,
  note TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_balance_created ON adaptation_compass_balance(created_at_ms DESC)');


    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_relationships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  name TEXT,
  type TEXT,
  trust_score INTEGER,
  intimacy_score INTEGER,
  conflict_score INTEGER,
  support_score INTEGER,
  boundary_score INTEGER,
  note TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_relationships_created ON adaptation_compass_relationships(created_at_ms DESC)');

    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_timeline (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  chapter TEXT,
  event TEXT,
  old_adaptation TEXT,
  mature_shift TEXT,
  evidence TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_timeline_created ON adaptation_compass_timeline(created_at_ms DESC)');

    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_contributions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  target TEXT,
  form TEXT,
  motivation TEXT,
  boundary TEXT,
  result TEXT,
  meaning_score INTEGER
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_contributions_created ON adaptation_compass_contributions(created_at_ms DESC)');

    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_health (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  sleep_quality INTEGER,
  alcohol_risk INTEGER,
  exercise_minutes INTEGER,
  stress_body INTEGER,
  symptoms TEXT,
  note TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_health_created ON adaptation_compass_health(created_at_ms DESC)');

    await database.execute('''
CREATE TABLE IF NOT EXISTS adaptation_compass_course_progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at_ms INTEGER NOT NULL,
  week INTEGER,
  title TEXT,
  status TEXT,
  reflection TEXT
)
''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_adaptation_compass_course_progress_week ON adaptation_compass_course_progress(week, created_at_ms DESC)');
  }

  Future<AdaptationCompassProfile> getProfile() async {
    final raw = await _kv.getString(profileKey) ?? '';
    return AdaptationCompassProfile.fromRaw(raw);
  }

  Future<void> saveProfile(AdaptationCompassProfile profile) async {
    await _kv.setString(profileKey, profile.encode());
  }

  Future<int> insertSession(AdaptationCompassSession session) async {
    final database = await _db;
    final id = await database.insert('adaptation_compass_sessions', session.toDb());
    await _createActionsFromSession(session.copyWith(id: id));
    return id;
  }

  Future<void> _createActionsFromSession(AdaptationCompassSession session) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final actions = <AdaptationCompassAction>[
      if (session.action10m.trim().isNotEmpty)
        AdaptationCompassAction(
          createdAtMs: now,
          dueAtMs: now + const Duration(minutes: 10).inMilliseconds,
          sourceSessionId: session.id,
          title: session.action10m,
          domain: '10分钟现实行动',
          horizon: '10m',
        ),
      if (session.action24h.trim().isNotEmpty)
        AdaptationCompassAction(
          createdAtMs: now,
          dueAtMs: now + const Duration(days: 1).inMilliseconds,
          sourceSessionId: session.id,
          title: session.action24h,
          domain: '24小时行动',
          horizon: '24h',
        ),
      if (session.action7d.trim().isNotEmpty)
        AdaptationCompassAction(
          createdAtMs: now,
          dueAtMs: now + const Duration(days: 7).inMilliseconds,
          sourceSessionId: session.id,
          title: session.action7d,
          domain: '7天成长行动',
          horizon: '7d',
        ),
    ];
    if (actions.isEmpty) return;
    final database = await _db;
    final batch = database.batch();
    for (final action in actions) {
      batch.insert('adaptation_compass_actions', action.toDb());
    }
    await batch.commit(noResult: true);
  }

  Future<List<AdaptationCompassSession>> recentSessions({int limit = 20}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_sessions', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassSession.fromDb).toList(growable: false);
  }

  Future<List<AdaptationCompassSession>> sessionsSince(int sinceMs) async {
    final database = await _db;
    final rows = await database.query(
      'adaptation_compass_sessions',
      where: 'created_at_ms >= ?',
      whereArgs: <Object?>[sinceMs],
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(AdaptationCompassSession.fromDb).toList(growable: false);
  }

  Future<List<AdaptationCompassAction>> recentActions({int limit = 30, String? status}) async {
    final database = await _db;
    final rows = await database.query(
      'adaptation_compass_actions',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
    return rows.map(AdaptationCompassAction.fromDb).toList(growable: false);
  }

  Future<void> updateActionStatus(AdaptationCompassAction action, String status, {String reflection = ''}) async {
    final database = await _db;
    await database.update(
      'adaptation_compass_actions',
      <String, dynamic>{
        'status': status,
        'completed_at_ms': status == 'done' ? DateTime.now().millisecondsSinceEpoch : 0,
        if (reflection.trim().isNotEmpty) 'reflection': reflection.trim(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[action.id],
    );
  }

  Future<int> insertBalance(AdaptationCompassBalanceEntry entry) async {
    final database = await _db;
    return database.insert('adaptation_compass_balance', entry.toDb());
  }

  Future<List<AdaptationCompassBalanceEntry>> recentBalance({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_balance', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassBalanceEntry.fromDb).toList(growable: false);
  }

  Future<String> recentContextJson({int limit = 8}) async {
    final sessions = await recentSessions(limit: limit);
    final actions = await recentActions(limit: 8);
    final balance = await recentBalance(limit: 7);
    final health = await recentHealth(limit: 7);
    final courseProgress = await recentCourseProgress(limit: 12);
    return jsonEncode(<String, dynamic>{
      'sessions': sessions.map((s) => <String, dynamic>{
            'scene': s.scene,
            'created_at_ms': s.createdAtMs,
            'summary': s.eventSummary,
            'defense_layer': s.defenseLayer,
            'defenses': s.defenseMechanisms,
            'mature_alternatives': s.matureAlternatives,
            'risk_level': s.riskLevel,
          }).toList(),
      'actions': actions.map((a) => <String, dynamic>{
            'title': a.title,
            'domain': a.domain,
            'horizon': a.horizon,
            'status': a.status,
          }).toList(),
      'balance': balance.map((b) => <String, dynamic>{
            'created_at_ms': b.createdAtMs,
            'work': b.work,
            'love': b.love,
            'play': b.play,
            'body': b.body,
          }).toList(),
      'relationships': (await recentRelationships(limit: 6)).map((r) => <String, dynamic>{
            'type': r.type,
            'name': r.name,
            'trust': r.trust,
            'intimacy': r.intimacy,
            'conflict': r.conflict,
            'support': r.support,
            'boundary': r.boundary,
          }).toList(),
      'timeline': (await recentTimeline(limit: 6)).map((t) => <String, dynamic>{
            'chapter': t.chapter,
            'event': t.event,
            'old_adaptation': t.oldAdaptation,
            'mature_shift': t.matureShift,
          }).toList(),
      'contributions': (await recentContributions(limit: 6)).map((c) => <String, dynamic>{
            'target': c.target,
            'form': c.form,
            'meaning': c.meaning,
          }).toList(),
      'health': health.map((h) => <String, dynamic>{
            'created_at_ms': h.createdAtMs,
            'sleep_quality': h.sleepQuality,
            'alcohol_risk': h.alcoholRisk,
            'exercise_minutes': h.exerciseMinutes,
            'stress_body': h.stressBody,
            'symptoms': h.symptoms,
          }).toList(),
      'course_progress': courseProgress.map((c) => <String, dynamic>{
            'week': c.week,
            'title': c.title,
            'status': c.status,
            'reflection': c.reflection,
          }).toList(),
    });
  }


  Future<int> insertRelationship(AdaptationCompassRelationshipEntry entry) async {
    final database = await _db;
    return database.insert('adaptation_compass_relationships', entry.toDb());
  }

  Future<List<AdaptationCompassRelationshipEntry>> recentRelationships({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_relationships', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassRelationshipEntry.fromDb).toList(growable: false);
  }

  Future<int> insertTimeline(AdaptationCompassTimelineEntry entry) async {
    final database = await _db;
    return database.insert('adaptation_compass_timeline', entry.toDb());
  }

  Future<List<AdaptationCompassTimelineEntry>> recentTimeline({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_timeline', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassTimelineEntry.fromDb).toList(growable: false);
  }

  Future<int> insertContribution(AdaptationCompassContributionEntry entry) async {
    final database = await _db;
    return database.insert('adaptation_compass_contributions', entry.toDb());
  }

  Future<List<AdaptationCompassContributionEntry>> recentContributions({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_contributions', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassContributionEntry.fromDb).toList(growable: false);
  }

  Future<int> insertHealth(AdaptationCompassHealthEntry entry) async {
    final database = await _db;
    return database.insert('adaptation_compass_health', entry.toDb());
  }

  Future<List<AdaptationCompassHealthEntry>> recentHealth({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_health', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassHealthEntry.fromDb).toList(growable: false);
  }

  Future<int> insertCourseProgress(AdaptationCompassCourseProgress entry) async {
    final database = await _db;
    return database.insert('adaptation_compass_course_progress', entry.toDb());
  }

  Future<List<AdaptationCompassCourseProgress>> recentCourseProgress({int limit = 30}) async {
    final database = await _db;
    final rows = await database.query('adaptation_compass_course_progress', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(AdaptationCompassCourseProgress.fromDb).toList(growable: false);
  }

  Future<String> exportAllJson() async {
    final profile = await getProfile();
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'module': 'adaptation_compass',
      'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
      'profile': profile.toJson(),
      'sessions': (await recentSessions(limit: 1000)).map((s) => s.toDb()).toList(),
      'actions': (await recentActions(limit: 1000)).map((a) => a.toDb()).toList(),
      'balance': (await recentBalance(limit: 1000)).map((b) => b.toDb()).toList(),
      'relationships': (await recentRelationships(limit: 1000)).map((r) => r.toDb()).toList(),
      'timeline': (await recentTimeline(limit: 1000)).map((t) => t.toDb()).toList(),
      'contributions': (await recentContributions(limit: 1000)).map((c) => c.toDb()).toList(),
      'health': (await recentHealth(limit: 1000)).map((h) => h.toDb()).toList(),
      'course_progress': (await recentCourseProgress(limit: 1000)).map((c) => c.toDb()).toList(),
    });
  }

  Future<void> clearProfile() async {
    await _kv.setString(profileKey, '');
  }

  Future<AdaptationCompassStats> stats() async {
    final database = await _db;
    final sessions = await recentSessions(limit: 300);
    final actionRows = await database.rawQuery('SELECT status, COUNT(*) AS c FROM adaptation_compass_actions GROUP BY status');
    int openActions = 0;
    int doneActions = 0;
    for (final row in actionRows) {
      final status = acText(row['status']);
      final count = acInt(row['c']);
      if (status == 'done') {
        doneActions += count;
      } else {
        openActions += count;
      }
    }
    final balanceRows = await recentBalance(limit: 30);
    double avg(List<int> values) => values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
    return AdaptationCompassStats(
      sessionCount: sessions.length,
      openActions: openActions,
      doneActions: doneActions,
      matureDefenseHits: sessions.where((s) => s.defenseLayer.contains('成熟')).length,
      immatureDefenseHits: sessions.where((s) => s.defenseLayer.contains('不成熟')).length,
      neuroticDefenseHits: sessions.where((s) => s.defenseLayer.contains('神经')).length,
      riskHits: sessions.where((s) => s.riskLevel == 'high' || s.riskLevel == 'crisis').length,
      avgWork: avg(balanceRows.map((e) => e.work).where((e) => e > 0).toList()),
      avgLove: avg(balanceRows.map((e) => e.love).where((e) => e > 0).toList()),
      avgPlay: avg(balanceRows.map((e) => e.play).where((e) => e > 0).toList()),
      avgBody: avg(balanceRows.map((e) => e.body).where((e) => e > 0).toList()),
    );
  }

  Future<void> clearAll() async {
    final database = await _db;
    await database.delete('adaptation_compass_sessions');
    await database.delete('adaptation_compass_actions');
    await database.delete('adaptation_compass_balance');
    await database.delete('adaptation_compass_relationships');
    await database.delete('adaptation_compass_timeline');
    await database.delete('adaptation_compass_contributions');
    await database.delete('adaptation_compass_health');
    await database.delete('adaptation_compass_course_progress');
    await clearProfile();
  }
}
