import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'action_mind_models.dart';

/// ActionMind 独立 DAO。
///
/// 只创建 action_mind_* 数据表与 action_mind_* KV，避免与其他模块融合。
class ActionMindDao {
  static const String profileKey = 'action_mind_profile_v1';

  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        scene TEXT,
        user_input TEXT,
        ai_response TEXT,
        target_clarification TEXT,
        mechanism_diagnosis TEXT,
        rewritten_goal TEXT,
        reality_obstacle TEXT,
        process_simulation TEXT,
        plan_json TEXT,
        emotion_handling TEXT,
        social_correction TEXT,
        feedback_questions TEXT,
        final_action TEXT,
        risk_level TEXT,
        raw_json TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        title TEXT,
        raw_wish TEXT,
        deep_goal TEXT,
        goal_source TEXT,
        intrinsic_external TEXT,
        approach_avoidance TEXT,
        ideal_ought TEXT,
        identity_layer TEXT,
        value_layer TEXT,
        project_layer TEXT,
        action_layer TEXT,
        obstacles TEXT,
        conflicts TEXT,
        status TEXT,
        autonomy_score INTEGER,
        meaning_score INTEGER,
        feasibility_score INTEGER,
        resource_fit_score INTEGER
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        trigger TEXT,
        action TEXT,
        obstacle_plan TEXT,
        temptation_plan TEXT,
        minimum_action TEXT,
        standard_action TEXT,
        challenge_action TEXT,
        environment_cue TEXT,
        status TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_emotions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        emotion TEXT,
        trigger TEXT,
        blocked_goal TEXT,
        signal TEXT,
        recovery_action TEXT,
        next_action TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        plan_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        gap TEXT,
        cause TEXT,
        emotion_feedback TEXT,
        learned TEXT,
        next_if_then TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_tool_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        tool_id TEXT,
        scene TEXT,
        title TEXT,
        user_input TEXT,
        ai_response TEXT,
        extracted_goal TEXT,
        extracted_plan TEXT,
        next_action TEXT,
        status TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_daily_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_key TEXT,
        created_at_ms INTEGER NOT NULL,
        main_goal TEXT,
        emotion TEXT,
        energy TEXT,
        obstacle TEXT,
        if_then TEXT,
        minimum_action TEXT,
        standard_action TEXT,
        challenge_action TEXT,
        recovery_action TEXT,
        ai_response TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS action_mind_life_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        period_key TEXT,
        identity_direction TEXT,
        primary_goal TEXT,
        supporting_goals TEXT,
        conflict_goals TEXT,
        paused_goals TEXT,
        low_maintenance_goals TEXT,
        weekly_focus TEXT,
        ai_response TEXT
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_sessions_created ON action_mind_sessions(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_goals_status ON action_mind_goals(status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_plans_goal_status ON action_mind_plans(goal_id, status, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_emotions_created ON action_mind_emotions(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_reviews_created ON action_mind_reviews(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_tool_runs_created ON action_mind_tool_runs(created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_tool_runs_tool ON action_mind_tool_runs(tool_id, created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_daily_cards_date ON action_mind_daily_cards(date_key, created_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_action_mind_life_snapshots_period ON action_mind_life_snapshots(period_key, created_at_ms DESC)');
  }

  Future<ActionMindProfile> loadProfile() async {
    final raw = await _kv.getString(profileKey);
    return ActionMindProfile.fromRaw(raw ?? '');
  }

  Future<void> saveProfile(ActionMindProfile profile) async {
    await _kv.setString(profileKey, profile.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch).encode());
  }

  Future<int> insertSession(ActionMindSession session) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await database.insert('action_mind_sessions', <String, Object?>{
      'created_at_ms': session.createdAtMs == 0 ? now : session.createdAtMs,
      'scene': session.scene,
      'user_input': session.userInput,
      'ai_response': session.aiResponse,
      'target_clarification': session.targetClarification,
      'mechanism_diagnosis': session.mechanismDiagnosis,
      'rewritten_goal': session.rewrittenGoal,
      'reality_obstacle': session.realityObstacle,
      'process_simulation': session.processSimulation,
      'plan_json': session.plan.encode(),
      'emotion_handling': session.emotionHandling,
      'social_correction': session.socialCorrection,
      'feedback_questions': session.feedbackQuestions,
      'final_action': session.finalAction,
      'risk_level': session.riskLevel,
      'raw_json': session.rawJson,
    });
    if (session.plan.hasPlan && !session.isSafetyRisk) {
      await insertPlan(session.plan.copyWith(goalId: 0));
    }
    return id;
  }

  Future<List<ActionMindSession>> listSessions({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query('action_mind_sessions', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindSession.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<int> insertGoal(ActionMindGoal goal) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('action_mind_goals', <String, Object?>{
      'created_at_ms': goal.createdAtMs == 0 ? now : goal.createdAtMs,
      'updated_at_ms': now,
      'title': goal.title,
      'raw_wish': goal.rawWish,
      'deep_goal': goal.deepGoal,
      'goal_source': goal.goalSource,
      'intrinsic_external': goal.intrinsicExternal,
      'approach_avoidance': goal.approachAvoidance,
      'ideal_ought': goal.idealOught,
      'identity_layer': goal.identityLayer,
      'value_layer': goal.valueLayer,
      'project_layer': goal.projectLayer,
      'action_layer': goal.actionLayer,
      'obstacles': goal.obstacles,
      'conflicts': goal.conflicts,
      'status': goal.status,
      'autonomy_score': goal.autonomyScore,
      'meaning_score': goal.meaningScore,
      'feasibility_score': goal.feasibilityScore,
      'resource_fit_score': goal.resourceFitScore,
    });
  }

  Future<void> updateGoal(ActionMindGoal goal) async {
    if (goal.id <= 0) return;
    final database = await _db;
    await database.update('action_mind_goals', <String, Object?>{
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      'title': goal.title,
      'raw_wish': goal.rawWish,
      'deep_goal': goal.deepGoal,
      'goal_source': goal.goalSource,
      'intrinsic_external': goal.intrinsicExternal,
      'approach_avoidance': goal.approachAvoidance,
      'ideal_ought': goal.idealOught,
      'identity_layer': goal.identityLayer,
      'value_layer': goal.valueLayer,
      'project_layer': goal.projectLayer,
      'action_layer': goal.actionLayer,
      'obstacles': goal.obstacles,
      'conflicts': goal.conflicts,
      'status': goal.status,
      'autonomy_score': goal.autonomyScore,
      'meaning_score': goal.meaningScore,
      'feasibility_score': goal.feasibilityScore,
      'resource_fit_score': goal.resourceFitScore,
    }, where: 'id = ?', whereArgs: <Object?>[goal.id]);
  }

  Future<List<ActionMindGoal>> listGoals({int limit = 100}) async {
    final database = await _db;
    final rows = await database.query('action_mind_goals', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindGoal.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<int> insertPlan(ActionMindPlan plan) async {
    if (!plan.hasPlan) return 0;
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('action_mind_plans', <String, Object?>{
      'goal_id': plan.goalId,
      'created_at_ms': plan.createdAtMs == 0 ? now : plan.createdAtMs,
      'updated_at_ms': now,
      'trigger': plan.trigger,
      'action': plan.action,
      'obstacle_plan': plan.obstaclePlan,
      'temptation_plan': plan.temptationPlan,
      'minimum_action': plan.minimumAction,
      'standard_action': plan.standardAction,
      'challenge_action': plan.challengeAction,
      'environment_cue': plan.environmentCue,
      'status': plan.status,
    });
  }

  Future<void> updatePlanStatus(int id, String status) async {
    if (id <= 0) return;
    final database = await _db;
    await database.update('action_mind_plans', <String, Object?>{
      'status': status,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<ActionMindPlan>> listPlans({int limit = 100}) async {
    final database = await _db;
    final rows = await database.query('action_mind_plans', orderBy: 'updated_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindPlan.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<int> insertEmotion(ActionMindEmotionLog log) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('action_mind_emotions', <String, Object?>{
      'created_at_ms': log.createdAtMs == 0 ? now : log.createdAtMs,
      'emotion': log.emotion,
      'trigger': log.trigger,
      'blocked_goal': log.blockedGoal,
      'signal': log.signal,
      'recovery_action': log.recoveryAction,
      'next_action': log.nextAction,
    });
  }

  Future<List<ActionMindEmotionLog>> listEmotions({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query('action_mind_emotions', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindEmotionLog.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<int> insertReview(ActionMindReview review) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await database.insert('action_mind_reviews', <String, Object?>{
      'goal_id': review.goalId,
      'plan_id': review.planId,
      'created_at_ms': review.createdAtMs == 0 ? now : review.createdAtMs,
      'completed': review.completed ? 1 : 0,
      'gap': review.gap,
      'cause': review.cause,
      'emotion_feedback': review.emotionFeedback,
      'learned': review.learned,
      'next_if_then': review.nextIfThen,
    });
    if (review.planId > 0 && review.completed) {
      await updatePlanStatus(review.planId, 'completed');
    }
    return id;
  }

  Future<List<ActionMindReview>> listReviews({int limit = 80}) async {
    final database = await _db;
    final rows = await database.query('action_mind_reviews', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindReview.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }


  Future<int> insertToolRun(ActionMindToolRun run) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('action_mind_tool_runs', <String, Object?>{
      'created_at_ms': run.createdAtMs == 0 ? now : run.createdAtMs,
      'tool_id': run.toolId,
      'scene': run.scene,
      'title': run.title,
      'user_input': run.userInput,
      'ai_response': run.aiResponse,
      'extracted_goal': run.extractedGoal,
      'extracted_plan': run.extractedPlan,
      'next_action': run.nextAction,
      'status': run.status,
    });
  }

  Future<List<ActionMindToolRun>> listToolRuns({int limit = 120}) async {
    final database = await _db;
    final rows = await database.query('action_mind_tool_runs', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindToolRun.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<int> insertDailyCard(ActionMindDailyCard card) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('action_mind_daily_cards', <String, Object?>{
      'date_key': card.dateKey,
      'created_at_ms': card.createdAtMs == 0 ? now : card.createdAtMs,
      'main_goal': card.mainGoal,
      'emotion': card.emotion,
      'energy': card.energy,
      'obstacle': card.obstacle,
      'if_then': card.ifThen,
      'minimum_action': card.minimumAction,
      'standard_action': card.standardAction,
      'challenge_action': card.challengeAction,
      'recovery_action': card.recoveryAction,
      'ai_response': card.aiResponse,
    });
  }

  Future<List<ActionMindDailyCard>> listDailyCards({int limit = 60}) async {
    final database = await _db;
    final rows = await database.query('action_mind_daily_cards', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindDailyCard.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<int> insertLifeSnapshot(ActionMindLifeSnapshot snapshot) async {
    final database = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return database.insert('action_mind_life_snapshots', <String, Object?>{
      'created_at_ms': snapshot.createdAtMs == 0 ? now : snapshot.createdAtMs,
      'period_key': snapshot.periodKey,
      'identity_direction': snapshot.identityDirection,
      'primary_goal': snapshot.primaryGoal,
      'supporting_goals': snapshot.supportingGoals,
      'conflict_goals': snapshot.conflictGoals,
      'paused_goals': snapshot.pausedGoals,
      'low_maintenance_goals': snapshot.lowMaintenanceGoals,
      'weekly_focus': snapshot.weeklyFocus,
      'ai_response': snapshot.aiResponse,
    });
  }

  Future<List<ActionMindLifeSnapshot>> listLifeSnapshots({int limit = 40}) async {
    final database = await _db;
    final rows = await database.query('action_mind_life_snapshots', orderBy: 'created_at_ms DESC', limit: limit);
    return rows.map((r) => ActionMindLifeSnapshot.fromJson(Map<String, dynamic>.from(r))).toList(growable: false);
  }

  Future<void> updateGoalStatus(int id, String status) async {
    if (id <= 0) return;
    final database = await _db;
    await database.update('action_mind_goals', <String, Object?>{
      'status': status,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deleteGoal(int id) async {
    if (id <= 0) return;
    final database = await _db;
    await database.delete('action_mind_goals', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> deletePlan(int id) async {
    if (id <= 0) return;
    final database = await _db;
    await database.delete('action_mind_plans', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<ActionMindStats> stats() async {
    final database = await _db;
    Future<int> count(String sql, [List<Object?> args = const <Object?>[]]) async {
      final rows = await database.rawQuery(sql, args);
      final raw = rows.first.values.first;
      return raw is int ? raw : int.tryParse((raw ?? '0').toString()) ?? 0;
    }
    return ActionMindStats(
      sessionCount: await count('SELECT COUNT(*) FROM action_mind_sessions'),
      goalCount: await count('SELECT COUNT(*) FROM action_mind_goals'),
      activeGoalCount: await count("SELECT COUNT(*) FROM action_mind_goals WHERE status = 'active'"),
      planCount: await count('SELECT COUNT(*) FROM action_mind_plans'),
      reviewCount: await count('SELECT COUNT(*) FROM action_mind_reviews'),
      emotionCount: await count('SELECT COUNT(*) FROM action_mind_emotions'),
    );
  }

  Future<String> goalsContextJson() async {
    final goals = await listGoals(limit: 20);
    final plans = await listPlans(limit: 20);
    return jsonEncode(<String, dynamic>{
      'goals': goals.map((g) => g.toJson()).toList(growable: false),
      'plans': plans.map((p) => p.toJson()).toList(growable: false),
    });
  }

  Future<String> recentContextJson() async {
    final sessions = await listSessions(limit: 8);
    final emotions = await listEmotions(limit: 8);
    final reviews = await listReviews(limit: 8);
    final toolRuns = await listToolRuns(limit: 8);
    final dailyCards = await listDailyCards(limit: 5);
    final snapshots = await listLifeSnapshots(limit: 3);
    return jsonEncode(<String, dynamic>{
      'sessions': sessions.map((s) => s.toJson()).toList(growable: false),
      'emotions': emotions.map((e) => e.toJson()).toList(growable: false),
      'reviews': reviews.map((r) => r.toJson()).toList(growable: false),
      'tool_runs': toolRuns.map((r) => r.toJson()).toList(growable: false),
      'daily_cards': dailyCards.map((c) => c.toJson()).toList(growable: false),
      'life_snapshots': snapshots.map((x) => x.toJson()).toList(growable: false),
    });
  }
}
