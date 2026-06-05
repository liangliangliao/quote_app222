import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../models/health_diet_agent_models.dart';
import 'health_profile_repository.dart';

class HealthDietAgentRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  Future<HealthDietGoal?> activeGoal({String userId = HealthProfileRepository.defaultUserId}) async {
    final db = await _db();
    final rows = await db.query(
      'health_diet_goals',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HealthDietGoal.fromMap(rows.first);
  }

  Future<List<HealthDietGoal>> goals({String userId = HealthProfileRepository.defaultUserId, int limit = 30}) async {
    final db = await _db();
    final rows = await db.query(
      'health_diet_goals',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: "CASE WHEN status = 'active' THEN 0 ELSE 1 END, updated_at DESC, id DESC",
      limit: limit,
    );
    return rows.map(HealthDietGoal.fromMap).toList();
  }

  Future<int> saveGoal(HealthDietGoal goal) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    await db.update(
      'health_diet_goals',
      {'status': 'paused', 'updated_at': now},
      where: 'user_id = ? AND status = ?',
      whereArgs: [goal.userId, 'active'],
    );
    final id = await db.insert('health_diet_goals', goal.toInsertMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await ensureDefaultTasks(userId: goal.userId, goalId: id);
    await DLog.i('health_diet.agent.goal', '已保存健康饮食 Agent 目标 id=$id title=${goal.displayTitle}');
    return id;
  }

  Future<void> completeGoal(int goalId) async {
    final db = await _db();
    await db.update('health_diet_goals', {'status': 'completed', 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [goalId]);
  }

  Future<void> ensureDefaultTasks({String userId = HealthProfileRepository.defaultUserId, int? goalId}) async {
    final db = await _db();
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM health_diet_agent_tasks WHERE user_id = ? AND status = ?',
          [userId, 'pending'],
        )) ??
        0;
    if (count > 0) return;
    final now = DateTime.now().toIso8601String();
    final tasks = [
      ['morning_plan', '早晨生成今日饮食计划', '根据目标、睡眠、步数和昨日饮食安排当天饮食策略', 'daily_morning', '08:00', 90],
      ['meal_reminder', '提醒记录午餐/晚餐', '没有饮食分享时，Agent 无法判断真实饮食状态', 'daily_meal', '12:30/20:30', 70],
      ['diet_review', '晚间生成饮食复盘', '把今日饮食、Health Connect 和微行动执行情况合并复盘', 'daily_evening', '22:00', 85],
      ['weekly_report', '每周生成饮食习惯报告', '识别反复出现的高糖、高盐、早餐缺失等模式', 'weekly', 'Sunday 21:00', 80],
    ];
    for (final t in tasks) {
      await db.insert('health_diet_agent_tasks', {
        'user_id': userId,
        'goal_id': goalId,
        'task_type': t[0],
        'task_title': t[1],
        'task_reason': t[2],
        'trigger_type': t[3],
        'trigger_time': t[4],
        'priority': t[5],
        'status': 'pending',
        'evidence_json': '[]',
        'result_json': null,
        'created_at': now,
        'executed_at': null,
        'completed_at': null,
      });
    }
  }



  Future<void> completePendingTaskType({
    String userId = HealthProfileRepository.defaultUserId,
    required String taskType,
    Object? evidence,
    Object? result,
  }) async {
    final db = await _db();
    final rows = await db.query(
      'health_diet_agent_tasks',
      columns: ['id'],
      where: 'user_id = ? AND task_type = ? AND status = ?',
      whereArgs: [userId, taskType, 'pending'],
      orderBy: 'priority DESC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'health_diet_agent_tasks',
      {
        'status': 'completed',
        'evidence_json': evidence == null ? '[]' : jsonEncode(evidence),
        'result_json': result == null ? null : jsonEncode(result),
        'executed_at': now,
        'completed_at': now,
      },
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
  }

  Future<List<HealthDietAgentTask>> pendingTasks({String userId = HealthProfileRepository.defaultUserId, int limit = 20}) async {
    final db = await _db();
    final rows = await db.query(
      'health_diet_agent_tasks',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'pending'],
      orderBy: 'priority DESC, id ASC',
      limit: limit,
    );
    return rows.map(HealthDietAgentTask.fromMap).toList();
  }

  Future<void> upsertMemory({
    String userId = HealthProfileRepository.defaultUserId,
    required String memoryType,
    required String memoryKey,
    required String memoryValue,
    double confidence = 0.7,
    Object? evidence,
  }) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'health_diet_agent_memory',
      where: 'user_id = ? AND memory_type = ? AND memory_key = ?',
      whereArgs: [userId, memoryType, memoryKey],
      limit: 1,
    );
    final data = {
      'user_id': userId,
      'memory_type': memoryType,
      'memory_key': memoryKey,
      'memory_value': memoryValue,
      'confidence': confidence,
      'evidence_json': evidence == null ? null : jsonEncode(evidence),
      'last_seen_at': now,
      'updated_at': now,
    };
    if (rows.isEmpty) {
      await db.insert('health_diet_agent_memory', {...data, 'first_seen_at': now});
    } else {
      await db.update('health_diet_agent_memory', data, where: 'id = ?', whereArgs: [rows.first['id']]);
    }
  }

  Future<List<HealthDietAgentMemory>> memories({String userId = HealthProfileRepository.defaultUserId, int limit = 30}) async {
    final db = await _db();
    final rows = await db.query(
      'health_diet_agent_memory',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC, confidence DESC',
      limit: limit,
    );
    return rows.map(HealthDietAgentMemory.fromMap).toList();
  }

  Future<void> savePlan({
    String userId = HealthProfileRepository.defaultUserId,
    int? goalId,
    required String planDate,
    required String source,
    required Object planJson,
  }) async {
    final db = await _db();
    await db.insert('health_diet_agent_plans', {
      'user_id': userId,
      'goal_id': goalId,
      'plan_date': planDate,
      'source': source,
      'plan_json': jsonEncode(planJson),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
