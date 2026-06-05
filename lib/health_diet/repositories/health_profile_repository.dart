import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../../utils/debug_logger.dart';
import '../models/health_profile.dart';

class HealthProfileRepository {
  static const String defaultUserId = 'local_user';

  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  Future<HealthProfile?> latestProfile({String userId = defaultUserId}) async {
    final db = await _db();
    final rows = await db.query(
      'health_profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final profileId = int.tryParse((row['id'] ?? '').toString());
    final conditions = profileId == null
        ? <String>[]
        : await _codesFor(db, 'health_conditions', profileId, 'condition_code');
    final restrictions = profileId == null
        ? <String>[]
        : await _codesFor(db, 'diet_restrictions', profileId, 'restriction_code');
    final preferences = profileId == null
        ? <String>[]
        : await _codesFor(db, 'diet_preferences', profileId, 'preference_code');
    return HealthProfile(
      id: profileId,
      userId: (row['user_id'] ?? defaultUserId).toString(),
      gender: (row['gender'] ?? 'unknown').toString(),
      age: int.tryParse((row['age'] ?? '').toString()),
      heightCm: double.tryParse((row['height_cm'] ?? '').toString()),
      weightKg: double.tryParse((row['weight_kg'] ?? '').toString()),
      activityLevel: (row['activity_level'] ?? 'normal').toString(),
      mainGoal: (row['main_goal'] ?? 'balanced').toString(),
      conditions: conditions,
      restrictions: restrictions,
      preferences: preferences,
      createdAt: row['created_at']?.toString(),
      updatedAt: row['updated_at']?.toString(),
    );
  }

  Future<int> saveProfile(HealthProfile profile) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final latest = await latestProfile(userId: profile.userId);
    final data = <String, Object?>{
      'user_id': profile.userId,
      'gender': profile.gender,
      'age': profile.age,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'activity_level': profile.activityLevel,
      'main_goal': profile.mainGoal,
      'updated_at': now,
    };
    late final int profileId;
    if (latest?.id != null) {
      profileId = latest!.id!;
      await db.update('health_profiles', data, where: 'id = ?', whereArgs: [profileId]);
    } else {
      data['created_at'] = now;
      profileId = await db.insert('health_profiles', data);
    }
    await _replaceCodes(db, 'health_conditions', profileId, 'condition_code', profile.conditions);
    await _replaceCodes(db, 'diet_restrictions', profileId, 'restriction_code', profile.restrictions);
    await _replaceCodes(db, 'diet_preferences', profileId, 'preference_code', profile.preferences);
    await DLog.i('health_diet.profile', '健康饮食档案已保存 profileId=$profileId');
    return profileId;
  }

  Future<void> addRecommendationLog({
    required String requestType,
    String? userQuery,
    String? dataSources,
    String? aiProvider,
    String? aiModel,
    String? prompt,
    String? response,
    String? parsedJson,
    String status = 'ok',
    String? errorMessage,
    int? profileId,
  }) async {
    final db = await _db();
    await db.insert('health_recommendation_logs', {
      'profile_id': profileId,
      'request_type': requestType,
      'user_query': userQuery,
      'data_sources': dataSources,
      'ai_provider': aiProvider,
      'ai_model': aiModel,
      'prompt': prompt,
      'response': response,
      'parsed_json': parsedJson,
      'status': status,
      'error_message': errorMessage,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<String>> _codesFor(Database db, String table, int profileId, String codeColumn) async {
    final rows = await db.query(table, where: 'profile_id = ?', whereArgs: [profileId]);
    return rows
        .map((row) => (row[codeColumn] ?? '').toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
  }

  Future<void> _replaceCodes(
    Database db,
    String table,
    int profileId,
    String codeColumn,
    List<String> codes,
  ) async {
    await db.delete(table, where: 'profile_id = ?', whereArgs: [profileId]);
    for (final code in codes.where((value) => value.trim().isNotEmpty)) {
      final data = <String, Object?>{
        'profile_id': profileId,
        codeColumn: code,
        'created_at': DateTime.now().toIso8601String(),
      };
      if (table == 'health_conditions') {
        data['condition_name'] = code;
      } else if (table == 'diet_restrictions') {
        data['restriction_name'] = code;
        data['restriction_type'] = code.contains('allergy') ? 'allergy' : 'preference';
      } else if (table == 'diet_preferences') {
        data['preference_name'] = code;
      }
      await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
