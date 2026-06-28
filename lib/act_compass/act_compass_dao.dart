import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'act_compass_models.dart';

/// 行愿 Compass 独立 DAO。
///
/// 只创建 act_compass_* 数据表与 act_compass_* KV，避免与其他模块融合。
class ActCompassDao {
  static const String profileKey = 'act_compass_profile_v1';
  static const String radarKey = 'act_compass_flex_radar_v1';

  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS act_compass_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        scene TEXT,
        user_input TEXT,
        ai_response TEXT,
        focus_processes_json TEXT,
        heard_summary TEXT,
        process_observation TEXT,
        grounding_practice TEXT,
        thought_story TEXT,
        defusion_sentence TEXT,
        acceptance_sentence TEXT,
        values_json TEXT,
        action_json TEXT,
        review_questions_json TEXT,
        risk_level TEXT,
        output_mode TEXT,
        raw_json TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS act_compass_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        source_session_id INTEGER,
        value_direction TEXT,
        obstacle TEXT,
        thought_story TEXT,
        defusion_sentence TEXT,
        acceptance_sentence TEXT,
        micro_action TEXT,
        start_time TEXT,
        duration TEXT,
        success_criteria TEXT,
        if_pain_then TEXT,
        status TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS act_compass_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        what_happened TEXT,
        values_lived TEXT,
        experiences TEXT,
        learned TEXT,
        next_action TEXT,
        self_thanks TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS act_compass_practice_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        process TEXT,
        scene TEXT,
        title TEXT,
        user_input TEXT,
        ai_guidance TEXT,
        value_direction TEXT,
        learned TEXT,
        duration_minutes INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS act_compass_value_experiments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        title TEXT,
        value_direction TEXT,
        why_it_matters TEXT,
        experiment_steps TEXT,
        expected_obstacle TEXT,
        act_response TEXT,
        start_at_ms INTEGER,
        end_at_ms INTEGER,
        status TEXT,
        review TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_act_compass_sessions_created ON act_compass_sessions(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_act_compass_sessions_scene ON act_compass_sessions(scene, created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_act_compass_actions_status ON act_compass_actions(status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_act_compass_reviews_action ON act_compass_reviews(action_id, created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_act_compass_practice_created ON act_compass_practice_logs(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_act_compass_experiment_status ON act_compass_value_experiments(status, updated_at_ms DESC)');
  }

  Future<ActCompassProfile> loadProfile() async {
    final raw = await _kv.getString(profileKey);
    return ActCompassProfile.fromRaw(raw ?? '');
  }

  Future<void> saveProfile(ActCompassProfile profile) async {
    await _kv.setString(profileKey, profile.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).encode());
  }

  Future<ActCompassFlexRadar> loadRadar() async {
    final raw = await _kv.getString(radarKey);
    return ActCompassFlexRadar.fromRaw(raw ?? '');
  }

  Future<void> saveRadar(ActCompassFlexRadar radar) async {
    await _kv.setString(radarKey, radar.encode());
  }

  Future<int> insertSession(ActCompassSessionRecord record) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await database.insert('act_compass_sessions', <String, Object?>{
      'created_at_ms': record.createdAtMs == 0 ? now : record.createdAtMs,
      'updated_at_ms': record.updatedAtMs == 0 ? now : record.updatedAtMs,
      'scene': record.scene,
      'user_input': record.userInput,
      'ai_response': record.aiResponse,
      'focus_processes_json': jsonEncode(record.focusProcesses),
      'heard_summary': record.heardSummary,
      'process_observation': record.processObservation,
      'grounding_practice': record.groundingPractice,
      'thought_story': record.thoughtStory,
      'defusion_sentence': record.defusionSentence,
      'acceptance_sentence': record.acceptanceSentence,
      'values_json': jsonEncode(record.values),
      'action_json': record.actionCard.encode(),
      'review_questions_json': jsonEncode(record.reviewQuestions),
      'risk_level': record.riskLevel,
      'output_mode': record.outputMode,
      'raw_json': record.rawJson,
    });
    if (record.actionCard.hasAction && !record.isSafetyRisk) {
      await insertAction(record.actionCard.copyWith(sourceSessionId: id));
    }
    return id;
  }

  Future<int> insertAction(ActCompassActionCard action) async {
    if (!action.hasAction) return 0;
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('act_compass_actions', <String, Object?>{
      'created_at_ms': action.createdAtMs == 0 ? now : action.createdAtMs,
      'updated_at_ms': action.updatedAtMs == 0 ? now : action.updatedAtMs,
      'source_session_id': action.sourceSessionId,
      'value_direction': action.valueDirection,
      'obstacle': action.obstacle,
      'thought_story': action.thoughtStory,
      'defusion_sentence': action.defusionSentence,
      'acceptance_sentence': action.acceptanceSentence,
      'micro_action': action.microAction,
      'start_time': action.startTime,
      'duration': action.duration,
      'success_criteria': action.successCriteria,
      'if_pain_then': action.ifPainThen,
      'status': action.status,
    });
  }

  Future<void> updateActionStatus(int id, String status) async {
    final database = await _db;
    await database.update(
      'act_compass_actions',
      <String, Object?>{'status': status, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> insertReview(ActCompassReviewRecord review) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await database.insert('act_compass_reviews', <String, Object?>{
      'action_id': review.actionId,
      'created_at_ms': review.createdAtMs == 0 ? now : review.createdAtMs,
      'completed': review.completed ? 1 : 0,
      'what_happened': review.whatHappened,
      'values_lived': review.valuesLived,
      'experiences': review.experiences,
      'learned': review.learned,
      'next_action': review.nextAction,
      'self_thanks': review.selfThanks,
    });
    if (review.actionId > 0) {
      await updateActionStatus(review.actionId, review.completed ? 'completed' : 'reviewed');
    }
    return id;
  }

  Future<List<ActCompassSessionRecord>> listSessions({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query('act_compass_sessions', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(ActCompassSessionRecord.fromMap).toList(growable: false);
  }

  Future<List<ActCompassActionCard>> listActions({int limit = 80, String? status}) async {
    final database = await _db;
    final rows = await database.query(
      'act_compass_actions',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(ActCompassActionCard.fromMap).toList(growable: false);
  }

  Future<List<ActCompassReviewRecord>> listReviews({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query('act_compass_reviews', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(ActCompassReviewRecord.fromMap).toList(growable: false);
  }


  Future<int> insertPracticeLog(ActCompassPracticeLog log) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('act_compass_practice_logs', <String, Object?>{
      'created_at_ms': log.createdAtMs == 0 ? now : log.createdAtMs,
      'process': log.process,
      'scene': log.scene,
      'title': log.title,
      'user_input': log.userInput,
      'ai_guidance': log.aiGuidance,
      'value_direction': log.valueDirection,
      'learned': log.learned,
      'duration_minutes': log.durationMinutes,
    });
  }

  Future<List<ActCompassPracticeLog>> listPracticeLogs({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query('act_compass_practice_logs', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map(ActCompassPracticeLog.fromMap).toList(growable: false);
  }

  Future<int> insertValueExperiment(ActCompassValueExperiment experiment) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('act_compass_value_experiments', <String, Object?>{
      'created_at_ms': experiment.createdAtMs == 0 ? now : experiment.createdAtMs,
      'updated_at_ms': experiment.updatedAtMs == 0 ? now : experiment.updatedAtMs,
      'title': experiment.title,
      'value_direction': experiment.valueDirection,
      'why_it_matters': experiment.whyItMatters,
      'experiment_steps': experiment.experimentSteps,
      'expected_obstacle': experiment.expectedObstacle,
      'act_response': experiment.actResponse,
      'start_at_ms': experiment.startAtMs,
      'end_at_ms': experiment.endAtMs,
      'status': experiment.status,
      'review': experiment.review,
    });
  }

  Future<void> updateValueExperiment(ActCompassValueExperiment experiment) async {
    if (experiment.id <= 0) return;
    final database = await _db;
    await database.update(
      'act_compass_value_experiments',
      <String, Object?>{
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        'title': experiment.title,
        'value_direction': experiment.valueDirection,
        'why_it_matters': experiment.whyItMatters,
        'experiment_steps': experiment.experimentSteps,
        'expected_obstacle': experiment.expectedObstacle,
        'act_response': experiment.actResponse,
        'start_at_ms': experiment.startAtMs,
        'end_at_ms': experiment.endAtMs,
        'status': experiment.status,
        'review': experiment.review,
      },
      where: 'id = ?',
      whereArgs: <Object?>[experiment.id],
    );
  }

  Future<List<ActCompassValueExperiment>> listValueExperiments({int limit = 80, String? status}) async {
    final database = await _db;
    final rows = await database.query(
      'act_compass_value_experiments',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(ActCompassValueExperiment.fromMap).toList(growable: false);
  }

  Future<ActCompassPersonalizationSnapshot> personalizationSnapshot() async {
    final profile = await loadProfile();
    final radar = await loadRadar();
    final sessions = await listSessions(limit: 80);
    final actions = await listActions(limit: 80);
    final reviews = await listReviews(limit: 80);

    List<String> top(Iterable<String> values, int limit) {
      final map = <String, int>{};
      for (final raw in values) {
        final value = raw.trim();
        if (value.isEmpty) continue;
        map[value] = (map[value] ?? 0) + 1;
      }
      final entries = map.entries.toList(growable: false)..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(limit).map((e) => e.key).toList(growable: false);
    }

    final stories = top(<String>[
      ...sessions.map((s) => s.thoughtStory),
      ...actions.map((a) => a.thoughtStory),
      ...profile.commonStories.split(RegExp(r'[,，;；\n]')),
    ], 6);
    final obstacles = top(<String>[
      ...actions.map((a) => a.obstacle),
      ...sessions.map((s) => s.actionCard.obstacle),
      ...profile.avoidancePatterns.split(RegExp(r'[,，;；\n]')),
    ], 6);
    final values = top(<String>[
      ...profile.coreValues,
      ...sessions.expand((s) => s.values),
      ...actions.map((a) => a.valueDirection),
      ...reviews.map((r) => r.valuesLived),
    ], 8);
    final responses = top(<String>[
      ...actions.map((a) => a.ifPainThen),
      ...actions.map((a) => a.defusionSentence),
      ...profile.effectivePractices.split(RegExp(r'[,，;；\n]')),
    ], 6);
    return ActCompassPersonalizationSnapshot(
      frequentStories: stories,
      frequentObstacles: obstacles,
      frequentValues: values,
      effectiveResponses: responses,
      weakestProcess: radar.weakestLabel,
      nextFocus: '本周优先练习“${radar.weakestLabel}”，并把行动继续缩小到能在 5–15 分钟内开始。',
    );
  }

  Future<ActCompassStats> stats() async {
    final database = await _db;
    Future<int> count(String sql, [List<Object?> args = const <Object?>[]]) async {
      final rows = await database.rawQuery(sql, args);
      final v = rows.isEmpty ? 0 : rows.first.values.first;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final sessions = await count('SELECT COUNT(*) FROM act_compass_sessions');
    final actions = await count('SELECT COUNT(*) FROM act_compass_actions');
    final completed = await count('SELECT COUNT(*) FROM act_compass_actions WHERE status = ?', <Object?>['completed']);
    final reviews = await count('SELECT COUNT(*) FROM act_compass_reviews');
    final valueActions = await count("SELECT COUNT(*) FROM act_compass_actions WHERE TRIM(value_direction) <> ''");
    final practices = await count('SELECT COUNT(*) FROM act_compass_practice_logs');
    final experiments = await count('SELECT COUNT(*) FROM act_compass_value_experiments');
    final activeExperiments = await count('SELECT COUNT(*) FROM act_compass_value_experiments WHERE status = ?', <Object?>['active']);
    return ActCompassStats(
      sessionCount: sessions,
      actionCount: actions,
      completedActionCount: completed,
      reviewCount: reviews,
      valueActionCount: valueActions,
      practiceCount: practices,
      experimentCount: experiments,
      activeExperimentCount: activeExperiments,
    );
  }

  Future<String> recentContextJson() async {
    final sessions = await listSessions(limit: 6);
    final actions = await listActions(limit: 8);
    final reviews = await listReviews(limit: 8);
    final practices = await listPracticeLogs(limit: 8);
    final experiments = await listValueExperiments(limit: 8);
    return jsonEncode(<String, dynamic>{
      'recent_sessions': sessions.map((s) => <String, dynamic>{
            'scene': s.scene,
            'user_input': s.userInput,
            'values': s.values,
            'thought_story': s.thoughtStory,
            'action': s.actionCard.microAction,
            'risk_level': s.riskLevel,
          }).toList(growable: false),
      'recent_actions': actions.map((a) => <String, dynamic>{
            'value_direction': a.valueDirection,
            'micro_action': a.microAction,
            'status': a.status,
            'obstacle': a.obstacle,
          }).toList(growable: false),
      'recent_reviews': reviews.map((r) => <String, dynamic>{
            'completed': r.completed,
            'values_lived': r.valuesLived,
            'learned': r.learned,
            'next_action': r.nextAction,
          }).toList(growable: false),
      'recent_practices': practices.map((p) => <String, dynamic>{
            'process': p.process,
            'scene': p.scene,
            'title': p.title,
            'value_direction': p.valueDirection,
            'learned': p.learned,
          }).toList(growable: false),
      'recent_value_experiments': experiments.map((e) => <String, dynamic>{
            'title': e.title,
            'value_direction': e.valueDirection,
            'status': e.status,
            'steps': e.experimentSteps,
            'review': e.review,
          }).toList(growable: false),
    });
  }
}
