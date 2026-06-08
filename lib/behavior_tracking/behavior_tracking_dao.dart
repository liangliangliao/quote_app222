import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import 'behavior_tracking_models.dart';

class BehaviorTrackingDao {
  static const String tableName = 'behavior_tracking_records';
  static const String categoriesTable = 'behavior_observation_categories';
  static const String presetsTable = 'behavior_observation_presets';
  static const String presetCheckinsTable = 'behavior_observation_preset_checkins';
  static const String presetDailyReviewsTable = 'behavior_observation_preset_daily_reviews';
  static const String presetAiAnalysesTable = 'behavior_observation_preset_ai_analyses';
  static const String settingsTable = 'behavior_observation_settings';

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db);
    return db;
  }

  Future<void> ensureTables([Database? database]) async {
    final db = database ?? await AppDatabase.instance();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        record_date_ms INTEGER NOT NULL,
        mode TEXT,
        entry_mode TEXT,
        template_key TEXT,
        method_name TEXT,
        primary_layer TEXT,
        category TEXT,
        title TEXT,
        source TEXT,
        privacy_level TEXT,
        start_minute INTEGER,
        end_minute INTEGER,
        project_key TEXT,
        focus_score INTEGER,
        behavior TEXT,
        reason TEXT,
        outcome TEXT,
        planned_value REAL,
        actual_value REAL,
        unit TEXT,
        completion_state TEXT,
        evidence_type TEXT,
        reason_tags_json TEXT,
        emotion TEXT,
        emotion_secondary TEXT,
        emotion_intensity INTEGER,
        valence_score INTEGER,
        arousal_score INTEGER,
        perceived_control INTEGER,
        trigger_text TEXT,
        cognition TEXT,
        reaction TEXT,
        automatic_thought TEXT,
        belief_strength INTEGER,
        distortion_codes_json TEXT,
        alternative_thought TEXT,
        if_plan TEXT,
        then_plan TEXT,
        short_term_result TEXT,
        long_term_impact TEXT,
        benefit_score INTEGER,
        regret_score INTEGER,
        goal_alignment TEXT,
        next_day_energy_delta INTEGER,
        alternative TEXT,
        environment TEXT,
        location_type TEXT,
        people_context TEXT,
        phone_distance TEXT,
        noise_level INTEGER,
        workspace_clutter INTEGER,
        cue_tags_json TEXT,
        body_state TEXT,
        sleep TEXT,
        sleep_start_minute INTEGER,
        sleep_end_minute INTEGER,
        sleep_duration_min INTEGER,
        sleep_quality INTEGER,
        energy_morning INTEGER,
        caffeine_mg INTEGER,
        steps INTEGER,
        exercise_min INTEGER,
        important_behaviors TEXT,
        time_waste TEXT,
        mood TEXT,
        tomorrow_adjustment TEXT,
        notes TEXT,
        tags_json TEXT,
        template_answers_json TEXT
      )
    ''');
    await _ensureColumns(db);
    await _ensureCategoryTable(db);
    await _ensurePresetTables(db);
    await _ensureSettingsTable(db);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_date ON $tableName(record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_category ON $tableName(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_mode ON $tableName(mode, record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_layer ON $tableName(primary_layer, record_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_updated ON $tableName(updated_at_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_tracking_source ON $tableName(source, record_date_ms DESC)');
  }

  Future<void> _ensureColumns(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info($tableName)');
    final existing = info.map((row) => row['name']?.toString()).whereType<String>().toSet();
    final columns = <String, String>{
      'entry_mode': 'TEXT',
      'template_key': 'TEXT',
      'method_name': 'TEXT',
      'source': 'TEXT',
      'privacy_level': 'TEXT',
      'project_key': 'TEXT',
      'focus_score': 'INTEGER',
      'planned_value': 'REAL',
      'actual_value': 'REAL',
      'unit': 'TEXT',
      'completion_state': 'TEXT',
      'evidence_type': 'TEXT',
      'reason_tags_json': 'TEXT',
      'emotion_secondary': 'TEXT',
      'valence_score': 'INTEGER',
      'arousal_score': 'INTEGER',
      'perceived_control': 'INTEGER',
      'automatic_thought': 'TEXT',
      'belief_strength': 'INTEGER',
      'distortion_codes_json': 'TEXT',
      'alternative_thought': 'TEXT',
      'if_plan': 'TEXT',
      'then_plan': 'TEXT',
      'benefit_score': 'INTEGER',
      'regret_score': 'INTEGER',
      'goal_alignment': 'TEXT',
      'next_day_energy_delta': 'INTEGER',
      'location_type': 'TEXT',
      'people_context': 'TEXT',
      'phone_distance': 'TEXT',
      'noise_level': 'INTEGER',
      'workspace_clutter': 'INTEGER',
      'cue_tags_json': 'TEXT',
      'sleep_start_minute': 'INTEGER',
      'sleep_end_minute': 'INTEGER',
      'sleep_duration_min': 'INTEGER',
      'sleep_quality': 'INTEGER',
      'energy_morning': 'INTEGER',
      'caffeine_mg': 'INTEGER',
      'steps': 'INTEGER',
      'exercise_min': 'INTEGER',
      'template_answers_json': 'TEXT',
    };
    for (final entry in columns.entries) {
      if (!existing.contains(entry.key)) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
  }


  Future<void> _ensureCategoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $categoriesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        builtin INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < behaviorCategories.length; i++) {
      await db.insert(
        categoriesTable,
        {
          'name': behaviorCategories[i],
          'builtin': 1,
          'sort_order': i,
          'created_at_ms': now,
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _ensurePresetTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $presetsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        name TEXT NOT NULL,
        category TEXT,
        primary_layer TEXT,
        target_value REAL,
        unit TEXT,
        default_duration_min INTEGER,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_hour INTEGER,
        reminder_minute INTEGER,
        reminder_fullscreen INTEGER NOT NULL DEFAULT 1,
        reminder_vibrate INTEGER NOT NULL DEFAULT 1,
        weekdays_json TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        sort_order INTEGER NOT NULL DEFAULT 1000
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $presetCheckinsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        preset_id INTEGER NOT NULL,
        check_date_ms INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        actual_value REAL,
        actual_duration_min INTEGER,
        note TEXT,
        missed_reason TEXT,
        carry_forward INTEGER NOT NULL DEFAULT 0,
        reviewed_at_ms INTEGER,
        record_id INTEGER,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        UNIQUE(preset_id, check_date_ms)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $presetDailyReviewsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        review_date_ms INTEGER NOT NULL UNIQUE,
        total_count INTEGER NOT NULL DEFAULT 0,
        done_count INTEGER NOT NULL DEFAULT 0,
        missed_count INTEGER NOT NULL DEFAULT 0,
        completion_rate REAL NOT NULL DEFAULT 0,
        details_json TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $presetAiAnalysesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        review_date_ms INTEGER NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'pending',
        analysis_json TEXT,
        raw_text TEXT,
        error_message TEXT,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
    final presetInfo = await db.rawQuery('PRAGMA table_info($presetsTable)');
    final presetColumns = presetInfo.map((row) => row['name']?.toString()).whereType<String>().toSet();
    final presetNeeded = <String, String>{
      'reminder_enabled': 'INTEGER NOT NULL DEFAULT 0',
      'reminder_hour': 'INTEGER',
      'reminder_minute': 'INTEGER',
      'reminder_fullscreen': 'INTEGER NOT NULL DEFAULT 1',
      'reminder_vibrate': 'INTEGER NOT NULL DEFAULT 1',
    };
    for (final entry in presetNeeded.entries) {
      if (!presetColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE $presetsTable ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
    final checkInfo = await db.rawQuery('PRAGMA table_info($presetCheckinsTable)');
    final checkColumns = checkInfo.map((row) => row['name']?.toString()).whereType<String>().toSet();
    final checkNeeded = <String, String>{
      'missed_reason': 'TEXT',
      'carry_forward': 'INTEGER NOT NULL DEFAULT 0',
      'reviewed_at_ms': 'INTEGER',
    };
    for (final entry in checkNeeded.entries) {
      if (!checkColumns.contains(entry.key)) {
        await db.execute('ALTER TABLE $presetCheckinsTable ADD COLUMN ${entry.key} ${entry.value}');
      }
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_presets_active ON $presetsTable(active, sort_order ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_preset_checkins_date ON $presetCheckinsTable(check_date_ms DESC, preset_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_preset_daily_reviews_date ON $presetDailyReviewsTable(review_date_ms DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_preset_ai_analyses_date ON $presetAiAnalysesTable(review_date_ms DESC)');
  }


  Future<void> _ensureSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at_ms INTEGER NOT NULL
      )
    ''');
  }

  Future<BehaviorPresetDailyReviewSettings> dailyReviewSettings() async {
    final db = await _db;
    final rows = await db.query(settingsTable, where: 'key = ?', whereArgs: ['preset_daily_review_settings'], limit: 1);
    if (rows.isEmpty) return BehaviorPresetDailyReviewSettings.defaults();
    try {
      final decoded = jsonDecode((rows.first['value'] ?? '{}').toString());
      if (decoded is Map) {
        return BehaviorPresetDailyReviewSettings.fromJson(decoded.map<String, dynamic>((key, value) => MapEntry(key.toString(), value)));
      }
    } catch (_) {}
    return BehaviorPresetDailyReviewSettings.defaults();
  }

  Future<void> saveDailyReviewSettings(BehaviorPresetDailyReviewSettings settings) async {
    final db = await _db;
    await db.insert(
      settingsTable,
      {
        'key': 'preset_daily_review_settings',
        'value': jsonEncode(settings.toJson()),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> categories() async {
    final db = await _db;
    final rows = await db.query(categoriesTable, orderBy: 'builtin DESC, sort_order ASC, name ASC');
    final names = rows.map((e) => (e['name'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toList();
    final merged = <String>[...behaviorCategories];
    for (final name in names) {
      if (!merged.contains(name)) merged.add(name);
    }
    final customFromRecords = await db.rawQuery('SELECT DISTINCT category FROM $tableName WHERE category IS NOT NULL AND TRIM(category) <> "" ORDER BY category ASC');
    for (final row in customFromRecords) {
      final name = (row['category'] ?? '').toString().trim();
      final hiddenImportBucket = name == '待确认' || name == '娱乐/社交待确认' || name == '计划待确认' || name == '计划时间块待确认';
      if (name.isNotEmpty && !hiddenImportBucket && !merged.contains(name)) merged.add(name);
    }
    return merged;
  }

  Future<int> saveCategory(String rawName) async {
    final db = await _db;
    final name = rawName.trim();
    if (name.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert(
      categoriesTable,
      {
        'name': name,
        'builtin': behaviorCategories.contains(name) ? 1 : 0,
        'sort_order': behaviorCategories.contains(name) ? behaviorCategories.indexOf(name) : 1000,
        'created_at_ms': now,
        'updated_at_ms': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteCustomCategory(String rawName) async {
    final db = await _db;
    final name = rawName.trim();
    if (name.isEmpty || behaviorCategories.contains(name)) return;
    await db.delete(categoriesTable, where: 'name = ? AND builtin = 0', whereArgs: [name]);
  }

  Future<int> save(BehaviorTrackingRecord record) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = record.copyWith(updatedAtMs: now, createdAtMs: record.id == null ? now : record.createdAtMs).toMap();
    if (record.id == null) {
      data.remove('id');
      return db.insert(tableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update(tableName, data, where: 'id = ?', whereArgs: [record.id]);
    return record.id!;
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete every behavior observation record.
  ///
  /// This intentionally only clears the observation record table. It keeps
  /// categories, reminder plans, data-source settings, and other module
  /// configuration so the user can start a clean record history without
  /// losing setup.
  Future<int> deleteAllRecords() async {
    final db = await _db;
    return db.delete(tableName);
  }

  Future<List<BehaviorTrackingRecord>> recent({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query(tableName, orderBy: 'record_date_ms DESC, id DESC', limit: limit);
    return rows.map(BehaviorTrackingRecord.fromMap).toList();
  }

  Future<List<BehaviorTrackingRecord>> between(DateTime startInclusive, DateTime endExclusive) async {
    final db = await _db;
    final rows = await db.query(
      tableName,
      where: 'record_date_ms >= ? AND record_date_ms < ?',
      whereArgs: [
        DateTime(startInclusive.year, startInclusive.month, startInclusive.day).millisecondsSinceEpoch,
        DateTime(endExclusive.year, endExclusive.month, endExclusive.day).millisecondsSinceEpoch,
      ],
      orderBy: 'record_date_ms DESC, start_minute ASC, id DESC',
    );
    return rows.map(BehaviorTrackingRecord.fromMap).toList();
  }

  Future<List<BehaviorTrackingRecord>> today() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return between(start, start.add(const Duration(days: 1)));
  }

  Future<List<BehaviorPreset>> presets({bool includeInactive = false}) async {
    final db = await _db;
    final rows = await db.query(
      presetsTable,
      where: includeInactive ? null : 'active = 1',
      orderBy: 'active DESC, sort_order ASC, updated_at_ms DESC, id DESC',
    );
    return rows.map(BehaviorPreset.fromMap).toList();
  }

  Future<int> savePreset(BehaviorPreset preset) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = preset.copyWith(
      updatedAtMs: now,
      createdAtMs: preset.id == null ? now : preset.createdAtMs,
    ).toMap();
    if (preset.id == null) {
      data.remove('id');
      return db.insert(presetsTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await db.update(presetsTable, data, where: 'id = ?', whereArgs: [preset.id]);
    return preset.id!;
  }

  Future<void> deactivatePreset(int id) async {
    final db = await _db;
    await db.update(
      presetsTable,
      {'active': 0, 'updated_at_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BehaviorPresetCheckIn>> presetCheckIns(DateTime date) async {
    final db = await _db;
    final day = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final rows = await db.query(presetCheckinsTable, where: 'check_date_ms = ?', whereArgs: [day]);
    return rows.map(BehaviorPresetCheckIn.fromMap).toList();
  }

  Future<Map<int, BehaviorPresetCheckIn>> presetCheckInMap(DateTime date) async {
    final list = await presetCheckIns(date);
    return {for (final item in list) item.presetId: item};
  }

  Future<List<BehaviorPresetCheckIn>> recentPresetCheckIns({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query(presetCheckinsTable, orderBy: 'check_date_ms DESC, updated_at_ms DESC', limit: limit);
    return rows.map(BehaviorPresetCheckIn.fromMap).toList();
  }

  Future<BehaviorPresetCheckIn> setPresetCheckIn({
    required BehaviorPreset preset,
    required DateTime date,
    required String status,
    double? actualValue,
    int? actualDurationMin,
    String note = '',
    String missedReason = '',
    bool carryForward = false,
    int? reviewedAtMs,
  }) async {
    final db = await _db;
    if (preset.id == null) {
      throw StateError('预设行为尚未保存，不能确认完成情况。');
    }
    final day = DateTime(date.year, date.month, date.day);
    final dayMs = day.millisecondsSinceEpoch;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final oldRows = await db.query(
      presetCheckinsTable,
      where: 'preset_id = ? AND check_date_ms = ?',
      whereArgs: [preset.id, dayMs],
      limit: 1,
    );
    final old = oldRows.isEmpty ? null : BehaviorPresetCheckIn.fromMap(oldRows.first);
    int? recordId = old?.recordId;

    if (status == 'done') {
      final duration = actualDurationMin ?? preset.defaultDurationMin;
      final now = DateTime.now();
      final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
      final nowMinute = now.hour * 60 + now.minute;
      final start = (duration != null && duration > 0 && isToday) ? (nowMinute - duration + 24 * 60) % (24 * 60) : null;
      final record = BehaviorTrackingRecord.blank(
        mode: 'planned_behavior_checkin',
        templateKey: 'planned_behavior',
        entryMode: 'preset_confirmation',
        primaryLayer: preset.primaryLayer.ifEmpty('行为层面'),
      ).copyWith(
        id: recordId,
        recordDateMs: dayMs,
        title: '预设行为 · ${preset.name}',
        category: preset.category.ifEmpty('其他'),
        source: 'planned_behavior',
        privacyLevel: 'local_sensitive',
        behavior: preset.name,
        plannedValue: preset.targetValue,
        actualValue: actualValue ?? preset.targetValue,
        clearPlannedValue: preset.targetValue == null,
        clearActualValue: actualValue == null && preset.targetValue == null,
        unit: preset.unit,
        completionState: '已完成',
        evidenceType: 'preset_checkin',
        startMinute: start,
        endMinute: start == null ? null : nowMinute,
        clearStartMinute: start == null,
        clearEndMinute: start == null,
        notes: note.trim().ifEmpty(preset.notes),
        tags: ['预设行为', '计划行为', preset.category.ifEmpty('其他')],
        templateAnswersJson: jsonEncode({
          'presetId': preset.id,
          'presetName': preset.name,
          'checkDateMs': dayMs,
          'status': status,
          'actualValue': actualValue,
          'actualDurationMin': actualDurationMin,
        }),
      );
      recordId = await save(record);
    } else {
      if (recordId != null) {
        await delete(recordId);
        recordId = null;
      }
    }

    final data = {
      'preset_id': preset.id,
      'check_date_ms': dayMs,
      'status': status,
      'actual_value': actualValue,
      'actual_duration_min': actualDurationMin,
      'note': note.trim(),
      'missed_reason': missedReason.trim(),
      'carry_forward': carryForward ? 1 : 0,
      'reviewed_at_ms': reviewedAtMs,
      'record_id': recordId,
      'created_at_ms': old?.createdAtMs ?? nowMs,
      'updated_at_ms': nowMs,
    };
    if (old == null) {
      final id = await db.insert(presetCheckinsTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
      return BehaviorPresetCheckIn.fromMap({...data, 'id': id});
    }
    await db.update(presetCheckinsTable, data, where: 'id = ?', whereArgs: [old.id]);
    return BehaviorPresetCheckIn.fromMap({...data, 'id': old.id});
  }


  Future<int> saveDailyPresetReview(BehaviorPresetDailyReviewRecord review) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = DateTime(review.reviewDate.year, review.reviewDate.month, review.reviewDate.day).millisecondsSinceEpoch;
    final oldRows = await db.query(presetDailyReviewsTable, where: 'review_date_ms = ?', whereArgs: [day], limit: 1);
    final data = review.toMap()
      ..remove('id')
      ..['review_date_ms'] = day
      ..['created_at_ms'] = oldRows.isEmpty ? now : (oldRows.first['created_at_ms'] ?? now)
      ..['updated_at_ms'] = now;
    if (oldRows.isEmpty) {
      return db.insert(presetDailyReviewsTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final id = oldRows.first['id'] as int;
    await db.update(presetDailyReviewsTable, data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<List<BehaviorPresetDailyReviewRecord>> recentDailyPresetReviews({int limit = 120}) async {
    final db = await _db;
    final rows = await db.query(presetDailyReviewsTable, orderBy: 'review_date_ms DESC', limit: limit);
    return rows.map(BehaviorPresetDailyReviewRecord.fromMap).toList();
  }


  Future<int> savePresetAiAnalysis(BehaviorPresetAiAnalysisRecord record) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = DateTime(record.reviewDate.year, record.reviewDate.month, record.reviewDate.day).millisecondsSinceEpoch;
    final oldRows = await db.query(presetAiAnalysesTable, where: 'review_date_ms = ?', whereArgs: [day], limit: 1);
    final data = record.toMap()
      ..remove('id')
      ..['review_date_ms'] = day
      ..['created_at_ms'] = oldRows.isEmpty ? now : (oldRows.first['created_at_ms'] ?? now)
      ..['updated_at_ms'] = now;
    if (oldRows.isEmpty) {
      return db.insert(presetAiAnalysesTable, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final id = oldRows.first['id'] as int;
    await db.update(presetAiAnalysesTable, data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  Future<BehaviorPresetAiAnalysisRecord?> presetAiAnalysisForDate(DateTime date) async {
    final db = await _db;
    final day = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final rows = await db.query(presetAiAnalysesTable, where: 'review_date_ms = ?', whereArgs: [day], limit: 1);
    if (rows.isEmpty) return null;
    return BehaviorPresetAiAnalysisRecord.fromMap(rows.first);
  }

  Future<List<BehaviorPresetAiAnalysisRecord>> recentPresetAiAnalyses({int limit = 120}) async {
    final db = await _db;
    final rows = await db.query(presetAiAnalysesTable, orderBy: 'review_date_ms DESC', limit: limit);
    return rows.map(BehaviorPresetAiAnalysisRecord.fromMap).toList();
  }

  Future<String> exportJson({int limit = 5000}) async {
    final records = await recent(limit: limit);
    final presetList = await presets(includeInactive: true);
    final checkIns = await recentPresetCheckIns(limit: limit);
    final reviews = await recentDailyPresetReviews(limit: limit);
    final aiAnalyses = await recentPresetAiAnalyses(limit: limit);
    final payload = {
      'schema_version': 4,
      'module': 'behavior_observation',
      'exported_at_ms': DateTime.now().millisecondsSinceEpoch,
      'records': records.map((e) => e.toMap()).toList(),
      'behavior_presets': presetList.map((e) => e.toMap()).toList(),
      'behavior_preset_checkins': checkIns.map((e) => e.toMap()).toList(),
      'behavior_preset_daily_reviews': reviews.map((e) => e.toMap()).toList(),
      'behavior_preset_ai_analyses': aiAnalyses.map((e) => e.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> exportCsv({int limit = 5000}) async {
    final records = await recent(limit: limit);
    final buffer = StringBuffer();
    final headers = <String>[
      'id','date','template','layer','category','title','start','end','duration_min','behavior','trigger','emotion','intensity','automatic_thought','short_term','long_term','environment','body_state','tags','notes'
    ];
    buffer.writeln(headers.map(_csvCell).join(','));
    for (final r in records) {
      final date = r.recordDate.toIso8601String().split('T').first;
      final row = [
        r.id?.toString() ?? '',
        date,
        r.templateLabel,
        r.primaryLayer,
        r.category,
        r.title,
        BehaviorTrackingRecord.formatMinute(r.startMinute),
        BehaviorTrackingRecord.formatMinute(r.endMinute),
        r.durationMinutes?.toString() ?? '',
        r.behavior,
        r.trigger,
        r.emotion,
        r.emotionIntensity?.toString() ?? '',
        r.automaticThought,
        r.shortTermResult,
        r.longTermImpact,
        r.environment,
        r.bodyState,
        r.tags.join('|'),
        r.notes,
      ];
      buffer.writeln(row.map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  Future<String> exportMarkdown({int limit = 500}) async {
    final records = await recent(limit: limit);
    final buffer = StringBuffer('# 行为观察导出\n\n');
    buffer.writeln('导出时间：${DateTime.now().toIso8601String()}\n');
    for (final r in records) {
      final date = r.recordDate.toIso8601String().split('T').first;
      buffer.writeln('## $date · ${r.title.trim().isEmpty ? r.templateLabel : r.title}\n');
      buffer.writeln('- 模板：${r.templateLabel}');
      buffer.writeln('- 层面：${r.primaryLayer}');
      if (r.timeRangeLabel.isNotEmpty) buffer.writeln('- 时间：${r.timeRangeLabel}（${r.durationMinutes ?? 0}分钟）');
      if (r.category.trim().isNotEmpty) buffer.writeln('- 类别：${r.category}');
      if (r.behavior.trim().isNotEmpty) buffer.writeln('- 行为：${r.behavior}');
      if (r.trigger.trim().isNotEmpty) buffer.writeln('- 触发：${r.trigger}');
      if (r.emotion.trim().isNotEmpty) buffer.writeln('- 情绪：${r.emotion}${r.emotionIntensity == null ? '' : ' ${r.emotionIntensity}/10'}');
      if (r.automaticThought.trim().isNotEmpty) buffer.writeln('- 自动想法：${r.automaticThought}');
      if (r.shortTermResult.trim().isNotEmpty) buffer.writeln('- 短期结果：${r.shortTermResult}');
      if (r.longTermImpact.trim().isNotEmpty) buffer.writeln('- 长期影响：${r.longTermImpact}');
      if (r.notes.trim().isNotEmpty) buffer.writeln('- 备注：${r.notes}');
      if (r.tags.isNotEmpty) buffer.writeln('- 标签：${r.tags.join('、')}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _csvCell(String raw) {
    final escaped = raw.replaceAll('"', '""');
    return '"$escaped"';
  }
}
