import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'db.dart';

/// DAO for the "Change · Self-help" module.
///
/// The table is: self_help_records
///
/// We store both subjective (STAI-6, affective sliders) and objective (camera PPG)
/// metrics, plus a derived zone classification.
class SelfHelpDao {
  Future<int> insertRecord({
    required int timestampMs,
    int? stai6Score,
    double? stai6Prorated,
    double? arousal0To100,
    double? valence0To100,
    double? demand0To100,
    double? resources0To100,
    double? distress0To100,
    double? bpm,
    double? rmssdMs,
    double? signalQuality,
    // Composite model outputs
    double? arousal0To10,
    double? confidence0To1,
    double? subjectiveIndex0To1,
    double? physiologicalIndex0To1,
    String? modelVersion,
    String? modelExplain,
    String? warningsJson,
    // Wearable snapshot (Fitbit, best-effort)
    double? fitbitRestingBpm,
    double? fitbitCurrentBpm,
    double? fitbitHrvRmssdMs,
    double? fitbitBreathingRate,
    double? fitbitSleepMinutes,
    double? fitbitSleepEfficiency,
    double? fitbitSteps,
    double? fitbitSpo2Avg,
    double? fitbitSkinTempDev,
    double? fitbitActiveZoneMinutes,
    double? fitbitCardioScore,
    String? zone,
    String? note,
  }) async {
    final db = await AppDatabase.instance();
    return await db.insert('self_help_records', {
      'timestamp_ms': timestampMs,
      'stai6_score': stai6Score,
      'stai6_prorated': stai6Prorated,
      'arousal_0_100': arousal0To100,
      'valence_0_100': valence0To100,
      'demand_0_100': demand0To100,
      'resources_0_100': resources0To100,
      'distress_0_100': distress0To100,
      'bpm': bpm,
      'rmssd_ms': rmssdMs,
      'signal_quality': signalQuality,
      'arousal_0_10': arousal0To10,
      'confidence_0_1': confidence0To1,
      'subjective_index_0_1': subjectiveIndex0To1,
      'physiological_index_0_1': physiologicalIndex0To1,
      'model_version': modelVersion,
      'model_explain': modelExplain,
      'warnings_json': warningsJson,
      'fitbit_resting_bpm': fitbitRestingBpm,
      'fitbit_current_bpm': fitbitCurrentBpm,
      'fitbit_hrv_rmssd_ms': fitbitHrvRmssdMs,
      'fitbit_breathing_rate': fitbitBreathingRate,
      'fitbit_sleep_minutes': fitbitSleepMinutes,
      'fitbit_sleep_efficiency': fitbitSleepEfficiency,
      'fitbit_steps': fitbitSteps,
      'fitbit_spo2_avg': fitbitSpo2Avg,
      'fitbit_skin_temp_dev': fitbitSkinTempDev,
      'fitbit_active_zone_minutes': fitbitActiveZoneMinutes,
      'fitbit_cardio_score': fitbitCardioScore,
      'zone': zone,
      'note': note,
    });
  }

  Future<List<Map<String, dynamic>>> recordsInLastDays(int days) async {
    final db = await AppDatabase.instance();
    final since = DateTime.now().millisecondsSinceEpoch - days * 24 * 60 * 60 * 1000;
    return await db.query(
      'self_help_records',
      where: 'timestamp_ms >= ?',
      whereArgs: [since],
      orderBy: 'timestamp_ms ASC, id ASC',
    );
  }

  Future<Map<String, dynamic>?> latestRecord() async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'self_help_records',
      orderBy: 'timestamp_ms DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> recentRecords({int limit = 14}) async {
    final db = await AppDatabase.instance();
    return await db.query(
      'self_help_records',
      orderBy: 'timestamp_ms DESC, id DESC',
      limit: limit,
    );
  }
}

/// DAO for Fitbit auth tokens and cached endpoint JSON.
class FitbitDao {
  Future<void> upsertAuth({
    required String userId,
    required String accessToken,
    required String refreshToken,
    required String scope,
    required int expiresAtMs,
  }) async {
    final db = await AppDatabase.instance();
    // Keep a single row per user.
    final existing = await db.query('fitbit_auth', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('fitbit_auth', {
        'user_id': userId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'scope': scope,
        'expires_at_ms': expiresAtMs,
      });
    } else {
      await db.update(
        'fitbit_auth',
        {
          'access_token': accessToken,
          'refresh_token': refreshToken,
          'scope': scope,
          'expires_at_ms': expiresAtMs,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
  }

  Future<Map<String, dynamic>?> getAuth() async {
    final db = await AppDatabase.instance();
    final rows = await db.query('fitbit_auth', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertCache({
    required String cacheKey,
    required String endpoint,
    required String date,
    required Map<String, dynamic> json,
  }) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'fitbit_cache',
      {
        'cache_key': cacheKey,
        'endpoint': endpoint,
        'date': date,
        'json': jsonEncode(json),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCache(String cacheKey) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('fitbit_cache', where: 'cache_key = ?', whereArgs: [cacheKey], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final raw = (row['json'] ?? '') as String;
    if (raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }


  Future<int> countCachesForDate(String date) async {
    final db = await AppDatabase.instance();
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM fitbit_cache WHERE date = ?', [date]);
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> listCachesForDate(String date) async {
    final db = await AppDatabase.instance();
    final rows = await db.query('fitbit_cache', where: 'date = ?', whereArgs: [date], orderBy: 'endpoint ASC');
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final raw = (row['json'] ?? '') as String;
      Map<String, dynamic>? json;
      if (raw.isNotEmpty) {
        try {
          json = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          json = null;
        }
      }
      out.add({
        'cache_key': row['cache_key'],
        'endpoint': row['endpoint'],
        'updated_at_ms': row['updated_at_ms'],
        'json': json,
      });
    }
    return out;
  }
}

