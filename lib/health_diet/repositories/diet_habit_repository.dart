import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../services/diet_habit_pattern_service.dart';
import '../models/diet_habit_models.dart';
import 'health_profile_repository.dart';

class DietHabitRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  Future<List<DietHabitPatternRecord>> activePatterns({String userId = HealthProfileRepository.defaultUserId}) async {
    final db = await _db();
    final rows = await db.query(
      'diet_habit_patterns',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      orderBy: 'frequency_count DESC, last_seen_at DESC, id DESC',
    );
    return rows.map(DietHabitPatternRecord.fromMap).toList();
  }

  Future<void> replaceActivePatterns(List<DietHabitPatternView> patterns, {String userId = HealthProfileRepository.defaultUserId}) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    await db.update('diet_habit_patterns', {'status': 'archived'}, where: 'user_id = ? AND status = ?', whereArgs: [userId, 'active']);
    for (final pattern in patterns) {
      await db.insert('diet_habit_patterns', {
        'user_id': userId,
        'pattern_type': pattern.patternType,
        'pattern_name': pattern.patternName,
        'evidence_json': jsonEncode(pattern.evidence),
        'frequency_count': pattern.frequencyCount,
        'first_seen_at': now,
        'last_seen_at': now,
        'status': 'active',
      });
    }
    await DLog.i('health_diet.habit', '已刷新饮食习惯模式 patterns=${patterns.length}');
  }

  Future<List<DietMicroAction>> microActions({String userId = HealthProfileRepository.defaultUserId, int limit = 40}) async {
    final db = await _db();
    final rows = await db.query(
      'diet_micro_actions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'action_date DESC, created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(DietMicroAction.fromMap).toList();
  }

  Future<DietMicroAction?> latestActiveAction({String userId = HealthProfileRepository.defaultUserId}) async {
    final db = await _db();
    final rows = await db.query(
      'diet_micro_actions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      orderBy: 'action_date DESC, created_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DietMicroAction.fromMap(rows.first);
  }

  Future<int> createMicroAction({
    String userId = HealthProfileRepository.defaultUserId,
    required String actionTitle,
    required String actionReason,
    String difficultyLevel = 'easy',
    String? relatedPattern,
    String? actionDate,
  }) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final date = actionDate ?? now.substring(0, 10);
    final id = await db.insert('diet_micro_actions', {
      'user_id': userId,
      'action_date': date,
      'action_title': actionTitle,
      'action_reason': actionReason,
      'difficulty_level': difficultyLevel,
      'related_pattern': relatedPattern,
      'status': 'active',
      'created_at': now,
      'completed_at': null,
    });
    await DLog.i('health_diet.micro_action', '已创建饮食微行动 actionId=$id title=$actionTitle');
    return id;
  }

  Future<void> completeMicroAction(int actionId) async {
    final db = await _db();
    await db.update(
      'diet_micro_actions',
      {'status': 'completed', 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  Future<void> reactivateMicroAction(int actionId) async {
    final db = await _db();
    await db.update(
      'diet_micro_actions',
      {'status': 'active', 'completed_at': null},
      where: 'id = ?',
      whereArgs: [actionId],
    );
  }

  Future<void> deleteMicroAction(int actionId) async {
    final db = await _db();
    await db.delete('diet_micro_actions', where: 'id = ?', whereArgs: [actionId]);
  }
}
