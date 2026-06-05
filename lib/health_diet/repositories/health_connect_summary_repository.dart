import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../data/db.dart';
import '../models/health_connect_daily_summary.dart';
import 'health_profile_repository.dart';

class HealthConnectSummaryRepository {
  Future<Database> _db() async {
    await AppDatabase.ensureHealthDietTables();
    return AppDatabase.instance();
  }

  String todayDate() => DateTime.now().toIso8601String().substring(0, 10);

  Future<HealthConnectDailySummary?> latestForDate({
    String userId = HealthProfileRepository.defaultUserId,
    String? date,
  }) async {
    final db = await _db();
    final rows = await db.query(
      'health_connect_daily_summary',
      where: 'user_id = ? AND summary_date = ?',
      whereArgs: [userId, date ?? todayDate()],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HealthConnectDailySummary.fromMap(rows.first);
  }

  Future<int> upsert(HealthConnectDailySummary summary) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final existing = await latestForDate(userId: summary.userId, date: summary.summaryDate);
    final map = summary.toMap()
      ..remove('id')
      ..['updated_at'] = now
      ..['created_at'] = summary.createdAt ?? existing?.createdAt ?? now;
    if (existing?.id != null) {
      await db.update('health_connect_daily_summary', map, where: 'id = ?', whereArgs: [existing!.id]);
      return existing.id!;
    }
    return db.insert('health_connect_daily_summary', map);
  }

  Future<int> upsertFromNativeMap({
    String userId = HealthProfileRepository.defaultUserId,
    String? date,
    required Map<String, Object?> map,
  }) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v.toString());
    }

    double? asDouble(Object? v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return upsert(HealthConnectDailySummary(
      userId: userId,
      summaryDate: date ?? todayDate(),
      steps: asInt(map['steps']),
      sleepMinutes: asInt(map['sleepMinutes']),
      exerciseMinutes: asInt(map['exerciseMinutes']),
      activeCalories: asDouble(map['activeCalories']),
      weightKg: asDouble(map['weightKg']),
      restingHeartRate: asDouble(map['restingHeartRate']),
      status: (map['status'] ?? 'synced').toString(),
      message: map['message']?.toString(),
      rawJson: jsonEncode(map),
    ));
  }
}
