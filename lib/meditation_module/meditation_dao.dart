import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'meditation_models.dart';

class MeditationDao {
  Future<Database> _database() async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_key TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0,
        before_mood INTEGER,
        after_mood INTEGER,
        distraction_level INTEGER,
        body_relax_level INTEGER,
        current_state TEXT,
        note TEXT,
        ai_feedback TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        default_duration_minutes INTEGER NOT NULL DEFAULT 5,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        default_background_sound TEXT,
        show_script_text INTEGER NOT NULL DEFAULT 1,
        sleep_mode_enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_habit_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        completed_count INTEGER NOT NULL DEFAULT 0,
        total_seconds INTEGER NOT NULL DEFAULT 0,
        main_type TEXT,
        mood_delta INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');


    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_ai_outputs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feature TEXT NOT NULL,
        input_json TEXT,
        output_text TEXT NOT NULL,
        parsed_json TEXT,
        provider TEXT,
        model TEXT,
        success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        created_at INTEGER NOT NULL
      )
    ''');



    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_custom_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_key TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        is_sleep INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'local_imported',
        steps_json TEXT NOT NULL,
        ending_reflection TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_weekly_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        week_start TEXT NOT NULL,
        week_end TEXT NOT NULL,
        summary_text TEXT NOT NULL,
        stats_json TEXT,
        ai_output_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meditation_segment_audio_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_key TEXT NOT NULL,
        session_title TEXT NOT NULL,
        session_source TEXT NOT NULL,
        segment_index INTEGER NOT NULL,
        start_second INTEGER NOT NULL DEFAULT 0,
        text_hash TEXT NOT NULL,
        voice_key TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT 'elevenlabs',
        model TEXT,
        tts_audio_id TEXT,
        audio_path TEXT NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        keep_forever INTEGER NOT NULL DEFAULT 0,
        last_used_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(session_key, segment_index, text_hash, voice_key, model)
      )
    ''');
  }

  Future<int> insertRecord(MeditationRecord record) async {
    final db = await _database();
    final id = await db.insert('meditation_records', record.toMap()..remove('id'));
    await _upsertDailyStats(record);
    return id;
  }

  Future<void> _upsertDailyStats(MeditationRecord record) async {
    if (!record.completed) return;
    final db = await _database();
    final date = _dateKey(DateTime.fromMillisecondsSinceEpoch(record.startedAt));
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query('meditation_habit_stats', where: 'date = ?', whereArgs: [date], limit: 1);
    final moodDelta = record.beforeMood != null && record.afterMood != null
        ? (record.beforeMood! - record.afterMood!)
        : null;
    if (existing.isEmpty) {
      await db.insert('meditation_habit_stats', {
        'date': date,
        'completed_count': 1,
        'total_seconds': record.durationSeconds,
        'main_type': record.type,
        'mood_delta': moodDelta,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      final row = existing.first;
      await db.update(
        'meditation_habit_stats',
        {
          'completed_count': ((row['completed_count'] as int?) ?? 0) + 1,
          'total_seconds': ((row['total_seconds'] as int?) ?? 0) + record.durationSeconds,
          'main_type': record.type,
          'mood_delta': moodDelta ?? row['mood_delta'],
          'updated_at': now,
        },
        where: 'date = ?',
        whereArgs: [date],
      );
    }
  }

  Future<List<MeditationRecord>> recentRecords({int limit = 30}) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_records',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(MeditationRecord.fromMap).toList();
  }

  Future<MeditationStats> loadStats() async {
    final db = await _database();
    final totalRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(duration_seconds), 0) AS total_seconds,
        COUNT(*) AS total_count
      FROM meditation_records
      WHERE completed = 1
    ''');
    final totalSeconds = _asInt(totalRows.first['total_seconds']);
    final totalCount = _asInt(totalRows.first['total_count']);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final todayRows = await db.rawQuery('''
      SELECT COALESCE(SUM(duration_seconds), 0) AS seconds
      FROM meditation_records
      WHERE completed = 1 AND started_at >= ? AND started_at < ?
    ''', [todayStart, tomorrowStart]);
    final todaySeconds = _asInt(todayRows.first['seconds']);

    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekRows = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM meditation_records
      WHERE completed = 1 AND started_at >= ?
    ''', [weekStart.millisecondsSinceEpoch]);
    final weekCount = _asInt(weekRows.first['count']);

    final typeRows = await db.rawQuery('''
      SELECT type, COUNT(*) AS count
      FROM meditation_records
      WHERE completed = 1
      GROUP BY type
      ORDER BY count DESC
      LIMIT 1
    ''');

    final datesRows = await db.query(
      'meditation_habit_stats',
      columns: ['date'],
      where: 'completed_count > 0',
      orderBy: 'date DESC',
    );
    final dateSet = datesRows.map((e) => (e['date'] ?? '').toString()).where((e) => e.isNotEmpty).toSet();
    int streak = 0;
    var day = DateTime(now.year, now.month, now.day);
    while (dateSet.contains(_dateKey(day))) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }

    return MeditationStats(
      totalSeconds: totalSeconds,
      todaySeconds: todaySeconds,
      weekCompletedCount: weekCount,
      streakDays: streak,
      totalCompletedCount: totalCount,
      mostUsedType: typeRows.isEmpty ? null : typeRows.first['type']?.toString(),
    );
  }

  Future<List<MeditationRecord>> recordsSince(int sinceMs, {int limit = 200}) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_records',
      where: 'completed = 1 AND started_at >= ?',
      whereArgs: [sinceMs],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(MeditationRecord.fromMap).toList();
  }

  Future<int> insertAiOutput({
    required String feature,
    String? inputJson,
    required String outputText,
    String? parsedJson,
    String? provider,
    String? model,
    bool success = true,
    String? errorMessage,
  }) async {
    final db = await _database();
    return db.insert('meditation_ai_outputs', {
      'feature': feature,
      'input_json': inputJson,
      'output_text': outputText,
      'parsed_json': parsedJson,
      'provider': provider,
      'model': model,
      'success': success ? 1 : 0,
      'error_message': errorMessage,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> insertWeeklySummary(MeditationWeeklySummary summary) async {
    final db = await _database();
    return db.insert('meditation_weekly_summaries', summary.toMap()..remove('id'));
  }

  Future<MeditationWeeklySummary?> latestWeeklySummary() async {
    final db = await _database();
    final rows = await db.query(
      'meditation_weekly_summaries',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeditationWeeklySummary.fromMap(rows.first);
  }



  Future<int> upsertCustomSession(MeditationSessionTemplate session) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'meditation_custom_sessions',
      columns: ['id', 'created_at'],
      where: 'session_key = ?',
      whereArgs: [session.key],
      limit: 1,
    );
    final map = _sessionToCustomMap(session, now, rows.isEmpty ? now : _asInt(rows.first['created_at']));
    if (rows.isEmpty) {
      return db.insert('meditation_custom_sessions', map);
    }
    await db.update(
      'meditation_custom_sessions',
      map..remove('id'),
      where: 'session_key = ?',
      whereArgs: [session.key],
    );
    return _asInt(rows.first['id']);
  }

  Future<List<MeditationSessionTemplate>> customSessions() async {
    final db = await _database();
    final rows = await db.query(
      'meditation_custom_sessions',
      orderBy: 'created_at DESC',
    );
    return rows.map(_sessionFromCustomMap).toList();
  }

  Future<void> deleteCustomSession(String sessionKey) async {
    final db = await _database();
    await db.delete('meditation_custom_sessions', where: 'session_key = ?', whereArgs: [sessionKey]);
  }

  Future<void> upsertSegmentAudioCache(MeditationSegmentAudioCache cache) async {
    final db = await _database();
    final map = cache.toMap()..remove('id');
    await db.insert(
      'meditation_segment_audio_cache',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MeditationSegmentAudioCache>> segmentAudioCachesForSession(String sessionKey) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_segment_audio_cache',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
      orderBy: 'segment_index ASC',
    );
    return rows.map(MeditationSegmentAudioCache.fromMap).toList();
  }

  Future<MeditationSegmentAudioCache?> latestSegmentAudioCacheForSegment({
    required String sessionKey,
    required int segmentIndex,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_segment_audio_cache',
      where: 'session_key = ? AND segment_index = ?',
      whereArgs: [sessionKey, segmentIndex],
      orderBy: 'updated_at DESC, last_used_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeditationSegmentAudioCache.fromMap(rows.first);
  }

  Future<int> deleteSegmentAudioCachesForSession(String sessionKey) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_segment_audio_cache',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
    );
    var deleted = 0;
    for (final row in rows) {
      await _deleteSegmentAudioCacheRow(db, row);
      deleted += 1;
    }
    return deleted;
  }

  Future<MeditationSegmentAudioCache?> findSegmentAudioCache({
    required String sessionKey,
    required int segmentIndex,
    required String textHash,
    required String voiceKey,
    required String model,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_segment_audio_cache',
      where: 'session_key = ? AND segment_index = ? AND text_hash = ? AND voice_key = ? AND model = ?',
      whereArgs: [sessionKey, segmentIndex, textHash, voiceKey, model],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeditationSegmentAudioCache.fromMap(rows.first);
  }

  Future<void> markSegmentAudioUsed(int id) async {
    final db = await _database();
    await db.update(
      'meditation_segment_audio_cache',
      {'last_used_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setSegmentAudioKeepForeverForSession(String sessionKey, bool keepForever) async {
    final db = await _database();
    await db.update(
      'meditation_segment_audio_cache',
      {
        'keep_forever': keepForever ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'session_key = ?',
      whereArgs: [sessionKey],
    );
  }

  Future<bool> isSegmentAudioCacheProtected(String sessionKey) async {
    final db = await _database();
    final rows = await db.query(
      'meditation_segment_audio_cache',
      columns: ['keep_forever'],
      where: 'session_key = ? AND keep_forever = 1',
      whereArgs: [sessionKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<MeditationAudioCacheStats> loadSegmentAudioCacheStats() async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS count,
        COALESCE(SUM(file_size), 0) AS bytes,
        COALESCE(SUM(CASE WHEN keep_forever = 1 THEN 1 ELSE 0 END), 0) AS protected_count,
        COALESCE(SUM(CASE WHEN keep_forever = 1 THEN file_size ELSE 0 END), 0) AS protected_bytes
      FROM meditation_segment_audio_cache
    ''');
    final row = rows.first;
    return MeditationAudioCacheStats(
      fileCount: _asInt(row['count']),
      totalBytes: _asInt(row['bytes']),
      protectedCount: _asInt(row['protected_count']),
      protectedBytes: _asInt(row['protected_bytes']),
    );
  }

  Future<int> cleanupSegmentAudioCache({
    int maxBytes = 300 * 1024 * 1024,
    int aiRetentionDays = 14,
    bool clearAll = false,
    bool clearUnprotected = false,
  }) async {
    final db = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final toDelete = <Map<String, Object?>>[];

    if (clearAll) {
      toDelete.addAll(await db.query('meditation_segment_audio_cache'));
    } else if (clearUnprotected) {
      toDelete.addAll(await db.query(
        'meditation_segment_audio_cache',
        where: 'keep_forever = 0',
      ));
    } else {
      final cutoff = now - aiRetentionDays.clamp(1, 3650).toInt() * 24 * 60 * 60 * 1000;
      toDelete.addAll(await db.query(
        'meditation_segment_audio_cache',
        where: "keep_forever = 0 AND session_source = 'ai_generated' AND last_used_at < ?",
        whereArgs: [cutoff],
      ));

      final stats = await loadSegmentAudioCacheStats();
      if (stats.totalBytes > maxBytes) {
        final rows = await db.query(
          'meditation_segment_audio_cache',
          where: 'keep_forever = 0',
          orderBy: "CASE WHEN session_source = 'ai_generated' THEN 0 WHEN session_source = 'local_imported' THEN 1 ELSE 2 END ASC, last_used_at ASC",
        );
        var projectedBytes = stats.totalBytes;
        final existingIds = toDelete.map((e) => _asInt(e['id'])).toSet();
        for (final row in rows) {
          if (projectedBytes <= maxBytes) break;
          final id = _asInt(row['id']);
          if (existingIds.contains(id)) continue;
          toDelete.add(row);
          existingIds.add(id);
          projectedBytes -= _asInt(row['file_size']);
        }
      }
    }

    var deleted = 0;
    final seen = <int>{};
    for (final row in toDelete) {
      final id = _asInt(row['id']);
      if (id == 0 || seen.contains(id)) continue;
      seen.add(id);
      await _deleteSegmentAudioCacheRow(db, row);
      deleted += 1;
    }
    return deleted;
  }

  Future<void> _deleteSegmentAudioCacheRow(Database db, Map<String, Object?> row) async {
    final id = _asInt(row['id']);
    final audioPath = (row['audio_path'] ?? '').toString();
    final ttsAudioId = (row['tts_audio_id'] ?? '').toString();
    await db.delete('meditation_segment_audio_cache', where: 'id = ?', whereArgs: [id]);

    final remaining = await db.query(
      'meditation_segment_audio_cache',
      columns: ['id'],
      where: 'audio_path = ?',
      whereArgs: [audioPath],
      limit: 1,
    );
    if (remaining.isNotEmpty) return;

    try {
      final file = File(audioPath);
      if (audioPath.isNotEmpty && await file.exists()) await file.delete();
    } catch (_) {}

    if (ttsAudioId.isNotEmpty) {
      await db.delete('tts_audio_file', where: 'id = ?', whereArgs: [ttsAudioId]);
    } else if (audioPath.isNotEmpty) {
      await db.delete('tts_audio_file', where: 'audio_file_path = ?', whereArgs: [audioPath]);
    }
  }

  Map<String, dynamic> _sessionToCustomMap(MeditationSessionTemplate session, int now, int createdAt) {
    return <String, dynamic>{
      'session_key': session.key,
      'title': session.title,
      'type': session.type,
      'category': session.category,
      'description': session.description,
      'duration_seconds': session.durationSeconds,
      'is_sleep': session.isSleep ? 1 : 0,
      'source': session.source,
      'steps_json': jsonEncode(session.steps.map((e) => e.toJson()).toList()),
      'ending_reflection': session.endingReflection,
      'created_at': createdAt,
      'updated_at': now,
    };
  }

  MeditationSessionTemplate _sessionFromCustomMap(Map<String, Object?> map) {
    final rawSteps = (map['steps_json'] ?? '[]').toString();
    final steps = <MeditationStep>[];
    try {
      final decoded = jsonDecode(rawSteps);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final start = _asInt(item['start'] ?? item['start_second'] ?? item['startSecond'] ?? item['start_seconds']);
          final text = (item['text'] ?? '').toString().trim();
          final pause = _asInt(item['pause_after_seconds'] ?? item['pauseAfterSeconds'] ?? item['pause_seconds'] ?? item['pause']);
          final intent = (item['intent'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            steps.add(MeditationStep(
              startSecond: start,
              text: text,
              pauseAfterSeconds: pause.clamp(0, 60).toInt(),
              intent: intent.isEmpty ? null : intent,
            ));
          }
        }
      }
    } catch (_) {}
    steps.sort((a, b) => a.startSecond.compareTo(b.startSecond));
    final safeSteps = steps.isEmpty
        ? const [MeditationStep(startSecond: 0, text: '现在，先坐下来，感受身体和呼吸。')]
        : steps;
    return MeditationSessionTemplate(
      key: (map['session_key'] ?? '').toString(),
      title: (map['title'] ?? '本地冥想脚本').toString(),
      type: (map['type'] ?? '本地脚本').toString(),
      category: (map['category'] ?? '本地上传').toString(),
      description: (map['description'] ?? '从本地脚本生成的冥想练习。').toString(),
      durationSeconds: _asInt(map['duration_seconds']).clamp(60, 3600).toInt(),
      isSleep: _asInt(map['is_sleep']) == 1,
      source: (map['source'] ?? 'local_imported').toString(),
      steps: safeSteps,
      endingReflection: (map['ending_reflection'] ?? '你已经完成了一次从脚本出发的静心练习。').toString(),
    );
  }

  Future<void> clearAllRecords() async {
    final db = await _database();
    await db.delete('meditation_records');
    await db.delete('meditation_habit_stats');
    await db.delete('meditation_weekly_summaries');
    await db.delete('meditation_ai_outputs');
  }

  String _dateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
