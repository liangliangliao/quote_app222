import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../data/db.dart';
import '../models/action_engine_models.dart';

class ActionEngineDao {
  Future<void> ensureSchema() async {
    final db = await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_action_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id TEXT UNIQUE,
        concept TEXT NOT NULL,
        goal TEXT,
        domain TEXT,
        title TEXT,
        source_direction_id TEXT,
        source_direction_title TEXT,
        provider TEXT,
        model TEXT,
        transport_mode TEXT,
        plan_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_action_executions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        execution_id TEXT UNIQUE,
        plan_id TEXT NOT NULL,
        concept TEXT NOT NULL,
        status TEXT NOT NULL,
        total_steps INTEGER NOT NULL,
        completed_steps INTEGER NOT NULL,
        friction_count INTEGER NOT NULL DEFAULT 0,
        feedback_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_action_step_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        execution_id TEXT NOT NULL,
        step_id TEXT NOT NULL,
        step_order INTEGER NOT NULL,
        step_text TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        encountered_friction INTEGER NOT NULL DEFAULT 0,
        friction_type TEXT,
        fallback_action TEXT,
        user_note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_action_friction_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        execution_id TEXT NOT NULL,
        step_id TEXT,
        friction_type TEXT NOT NULL,
        friction_reason TEXT,
        suggested_fallback TEXT,
        chosen_fallback TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ce_action_growth_snapshot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concept TEXT NOT NULL UNIQUE,
        total_plans INTEGER NOT NULL DEFAULT 0,
        total_executions INTEGER NOT NULL DEFAULT 0,
        completed_executions INTEGER NOT NULL DEFAULT 0,
        total_frictions INTEGER NOT NULL DEFAULT 0,
        most_common_direction TEXT,
        most_common_friction_type TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> savePlan(ActionPlan plan) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    await db.insert(
      'ce_action_plans',
      {
        'plan_id': plan.planId,
        'concept': plan.concept,
        'goal': plan.goal,
        'domain': plan.domain,
        'title': plan.title,
        'source_direction_id': plan.sourceDirectionId,
        'source_direction_title': plan.sourceDirectionTitle,
        'provider': plan.provider,
        'model': plan.model,
        'transport_mode': plan.transportMode,
        'plan_json': jsonEncode(plan.toPlanJson()),
        'created_at': plan.createdAt.toIso8601String(),
        'updated_at': plan.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _refreshGrowth(plan.concept);
  }

  Future<List<ActionPlan>> listPlans({int limit = 50}) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_action_plans', orderBy: 'updated_at DESC', limit: limit);
    return rows.map(ActionPlan.fromMap).toList();
  }

  Future<ActionPlan?> getPlan(String planId) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_action_plans', where: 'plan_id = ?', whereArgs: [planId], limit: 1);
    if (rows.isEmpty) return null;
    return ActionPlan.fromMap(rows.first);
  }

  Future<void> saveExecution({
    required ActionExecution execution,
    required List<ActionStepExecution> stepRecords,
  }) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    await db.transaction((txn) async {
      await txn.insert(
        'ce_action_executions',
        {
          'execution_id': execution.executionId,
          'plan_id': execution.planId,
          'concept': execution.concept,
          'status': execution.status,
          'total_steps': execution.totalSteps,
          'completed_steps': execution.completedSteps,
          'friction_count': execution.frictionCount,
          'feedback_json': jsonEncode(execution.feedback),
          'created_at': execution.createdAt.toIso8601String(),
          'updated_at': execution.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('ce_action_step_records', where: 'execution_id = ?', whereArgs: [execution.executionId]);
      for (final step in stepRecords) {
        await txn.insert('ce_action_step_records', {
          'execution_id': execution.executionId,
          'step_id': step.stepId,
          'step_order': step.stepOrder,
          'step_text': step.stepText,
          'completed': step.completed ? 1 : 0,
          'encountered_friction': step.encounteredFriction ? 1 : 0,
          'friction_type': step.frictionType,
          'fallback_action': step.fallbackAction,
          'user_note': step.userNote,
          'created_at': execution.updatedAt.toIso8601String(),
          'updated_at': execution.updatedAt.toIso8601String(),
        });
      }
    });
    await _refreshGrowth(execution.concept);
  }

  Future<void> logFriction({
    required String executionId,
    required String stepId,
    required String frictionType,
    String? frictionReason,
    String? suggestedFallback,
    String? chosenFallback,
  }) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    await db.insert('ce_action_friction_events', {
      'execution_id': executionId,
      'step_id': stepId,
      'friction_type': frictionType,
      'friction_reason': frictionReason,
      'suggested_fallback': suggestedFallback,
      'chosen_fallback': chosenFallback,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ActionExecution>> listExecutions({int limit = 50}) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_action_executions', orderBy: 'updated_at DESC', limit: limit);
    return rows.map(ActionExecution.fromMap).toList();
  }

  Future<List<ActionStepExecution>> listStepRecords(String executionId) async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_action_step_records', where: 'execution_id = ?', whereArgs: [executionId], orderBy: 'step_order ASC');
    return rows.map(ActionStepExecution.fromMap).toList();
  }

  Future<List<ActionGrowthSnapshot>> listGrowth() async {
    final db = await AppDatabase.instance();
    await ensureSchema();
    final rows = await db.query('ce_action_growth_snapshot', orderBy: 'updated_at DESC');
    return rows.map(ActionGrowthSnapshot.fromMap).toList();
  }

  Future<void> _refreshGrowth(String concept) async {
    final db = await AppDatabase.instance();
    final planRows = await db.query('ce_action_plans', where: 'concept = ?', whereArgs: [concept]);
    final execRows = await db.query('ce_action_executions', where: 'concept = ?', whereArgs: [concept]);
    final frictionRows = await db.rawQuery(
      'SELECT friction_type, COUNT(*) as c FROM ce_action_friction_events e JOIN ce_action_executions x ON e.execution_id = x.execution_id WHERE x.concept = ? GROUP BY friction_type ORDER BY c DESC',
      [concept],
    );
    final dirCounts = <String, int>{};
    for (final row in planRows) {
      final title = (row['source_direction_title'] ?? '').toString();
      if (title.isNotEmpty) dirCounts[title] = (dirCounts[title] ?? 0) + 1;
    }
    String commonDirection = '';
    if (dirCounts.isNotEmpty) {
      commonDirection = dirCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    final completed = execRows.where((e) => (e['status'] ?? '') == 'completed').length;
    final totalFrictions = execRows.fold<int>(0, (sum, e) => sum + ((e['friction_count'] as int?) ?? 0));
    final commonFriction = frictionRows.isEmpty ? '' : (frictionRows.first['friction_type'] ?? '').toString();
    await db.insert(
      'ce_action_growth_snapshot',
      {
        'concept': concept,
        'total_plans': planRows.length,
        'total_executions': execRows.length,
        'completed_executions': completed,
        'total_frictions': totalFrictions,
        'most_common_direction': commonDirection,
        'most_common_friction_type': commonFriction,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
