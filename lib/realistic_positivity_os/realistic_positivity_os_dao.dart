import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'realistic_positivity_os_models.dart';
import 'realistic_positivity_os_prompt_config.dart';

/// 真实积极行动系统独立 DAO。
///
/// 仅创建 realistic_positivity_os_* 表和 realistic_positivity_os_* KV，
/// 不复用、不改造、不融合其他既有模块的数据结构。
class RealisticPositivityOsDao {
  static const String profileKey = 'realistic_positivity_os_profile_v1';
  final KeyValueDao _kv = KeyValueDao();

  Future<Database> get _db async {
    final db = await AppDatabase.instance();
    await ensureTables(db: db);
    return db;
  }

  Future<void> ensureTables({Database? db}) async {
    final database = db ?? await AppDatabase.instance();
    await database.execute('''
      CREATE TABLE IF NOT EXISTS realistic_positivity_os_records (
        id TEXT PRIMARY KEY,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        scene_type TEXT NOT NULL,
        title TEXT NOT NULL,
        risk_level TEXT NOT NULL DEFAULT 'low',
        user_input TEXT NOT NULL DEFAULT '',
        payload_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_records_updated ON realistic_positivity_os_records(updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_records_scene ON realistic_positivity_os_records(scene_type, updated_at_ms DESC)');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS realistic_positivity_os_assets (
        id TEXT PRIMARY KEY,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        asset_type TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        tags_json TEXT NOT NULL DEFAULT '[]',
        source_record_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_assets_type ON realistic_positivity_os_assets(asset_type, updated_at_ms DESC)');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS realistic_positivity_os_action_evidence (
        id TEXT PRIMARY KEY,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        source_record_id TEXT NOT NULL DEFAULT '',
        action_title TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'planned',
        evidence_text TEXT NOT NULL DEFAULT '',
        reflection TEXT NOT NULL DEFAULT ''
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_evidence_updated ON realistic_positivity_os_action_evidence(updated_at_ms DESC)');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS realistic_positivity_os_experiments (
        id TEXT PRIMARY KEY,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'active',
        plan_json TEXT NOT NULL DEFAULT '{}',
        progress_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_experiments_updated ON realistic_positivity_os_experiments(updated_at_ms DESC)');
    await _ensureColumn(database, 'realistic_positivity_os_experiments', 'scene_type', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(database, 'realistic_positivity_os_experiments', 'source_record_id', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(database, 'realistic_positivity_os_experiments', 'day_index', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(database, 'realistic_positivity_os_experiments', 'horizon_days', 'INTEGER NOT NULL DEFAULT 7');
    await _ensureColumn(database, 'realistic_positivity_os_experiments', 'metrics_json', "TEXT NOT NULL DEFAULT '{}'");

    await database.execute('''
      CREATE TABLE IF NOT EXISTS realistic_positivity_os_checkins (
        id TEXT PRIMARY KEY,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        experiment_id TEXT NOT NULL DEFAULT '',
        checkin_date TEXT NOT NULL DEFAULT '',
        completed_action TEXT NOT NULL DEFAULT '',
        emotion_note TEXT NOT NULL DEFAULT '',
        zone TEXT NOT NULL DEFAULT 'stretch',
        reflection TEXT NOT NULL DEFAULT '',
        next_adjustment TEXT NOT NULL DEFAULT ''
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_checkins_experiment ON realistic_positivity_os_checkins(experiment_id, updated_at_ms DESC)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_rpo_checkins_updated ON realistic_positivity_os_checkins(updated_at_ms DESC)');
  }

  Future<void> _ensureColumn(Database database, String table, String column, String definition) async {
    final rows = await database.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => (row['name'] ?? '').toString() == column);
    if (!exists) {
      await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<RpoProfile> loadProfile() async => RpoProfile.fromRaw(await _kv.getString(profileKey));

  Future<void> saveProfile(RpoProfile profile) async {
    final updated = RpoProfile(
      commonEmotions: profile.commonEmotions,
      commonOldQuestions: profile.commonOldQuestions,
      commonPatterns: profile.commonPatterns,
      currentTroubles: profile.currentTroubles,
      supportPeople: profile.supportPeople,
      relationshipMap: profile.relationshipMap,
      stretchAreas: profile.stretchAreas,
      gratitudeAssets: profile.gratitudeAssets,
      peakExperiences: profile.peakExperiences,
      identityEvidence: profile.identityEvidence,
      valueBindings: profile.valueBindings,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _kv.setString(profileKey, updated.encode());
  }

  Future<void> upsertRecord(RpoPracticeRecord item) async {
    final db = await _db;
    await db.insert(
      'realistic_positivity_os_records',
      <String, Object?>{
        'id': item.id,
        'created_at_ms': item.createdAtMs,
        'updated_at_ms': item.updatedAtMs,
        'scene_type': item.sceneType,
        'title': item.title,
        'risk_level': item.riskLevel,
        'user_input': item.userInput,
        'payload_json': jsonEncode(item.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RpoPracticeRecord>> listRecords({int limit = 80, String? sceneType}) async {
    final db = await _db;
    final rows = await db.query(
      'realistic_positivity_os_records',
      where: (sceneType == null || sceneType.trim().isEmpty) ? null : 'scene_type = ?',
      whereArgs: (sceneType == null || sceneType.trim().isEmpty) ? null : <Object?>[sceneType.trim()],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
    return rows.map(RpoPracticeRecord.fromRow).toList(growable: false);
  }

  Future<void> deleteRecord(String id) async {
    final db = await _db;
    await db.delete('realistic_positivity_os_records', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> addAsset({
    required String assetType,
    required String title,
    String content = '',
    List<String> tags = const <String>[],
    String sourceRecordId = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db;
    final id = 'rpo_asset_${now}_${title.hashCode.abs()}';
    await db.insert(
      'realistic_positivity_os_assets',
      <String, Object?>{
        'id': id,
        'created_at_ms': now,
        'updated_at_ms': now,
        'asset_type': assetType,
        'title': title,
        'content': content,
        'tags_json': jsonEncode(tags),
        'source_record_id': sourceRecordId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listAssets({int limit = 80, String? assetType}) async {
    final db = await _db;
    return db.query(
      'realistic_positivity_os_assets',
      where: (assetType == null || assetType.trim().isEmpty) ? null : 'asset_type = ?',
      whereArgs: (assetType == null || assetType.trim().isEmpty) ? null : <Object?>[assetType.trim()],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> addActionEvidence({
    required String sourceRecordId,
    required String actionTitle,
    String status = 'planned',
    String evidenceText = '',
    String reflection = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db;
    final id = 'rpo_ev_${now}_${actionTitle.hashCode.abs()}';
    await db.insert(
      'realistic_positivity_os_action_evidence',
      <String, Object?>{
        'id': id,
        'created_at_ms': now,
        'updated_at_ms': now,
        'source_record_id': sourceRecordId,
        'action_title': actionTitle,
        'status': status,
        'evidence_text': evidenceText,
        'reflection': reflection,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listActionEvidence({int limit = 80}) async {
    final db = await _db;
    return db.query(
      'realistic_positivity_os_action_evidence',
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<RpoStats> stats() async {
    final records = await listRecords(limit: 1000);
    final assets = await listAssets(limit: 1000);
    final evidence = await listActionEvidence(limit: 1000);
    int countScene(String scene) => records.where((e) => e.sceneType == scene).length;
    return RpoStats(
      totalRecords: records.length,
      gratitudeCount: countScene('gratitude'),
      emotionCount: countScene('emotional_processing') + countScene('meaning_making'),
      changeCount: countScene('change_lab') + countScene('abc_change'),
      actionCount: countScene('behavior_first') + evidence.length,
      stretchCount: countScene('stretch_zone'),
      relationshipCount: countScene('relational_gratitude'),
      peakCount: countScene('savoring_peak'),
      crisisCount: records.where((e) => e.riskLevel == 'crisis' || e.riskLevel == 'high').length,
      identityEvidenceCount: assets.where((e) => (e['asset_type'] ?? '').toString() == 'identity_evidence').length + evidence.length,
    );
  }

  Future<void> materializeRecordAssets(RpoPracticeRecord item) async {
    if (item.microAction.title.trim().isNotEmpty) {
      await addActionEvidence(sourceRecordId: item.id, actionTitle: item.microAction.title, status: 'planned');
    }
    if (item.identityEvidence.trim().isNotEmpty) {
      await addAsset(
        assetType: 'identity_evidence',
        title: '新身份证据',
        content: item.identityEvidence,
        tags: item.coreValues,
        sourceRecordId: item.id,
      );
    }
    if (item.sceneType == 'gratitude' && item.realSituation.trim().isNotEmpty) {
      await addAsset(
        assetType: 'gratitude_asset',
        title: item.title,
        content: item.realSituation,
        tags: item.coreValues,
        sourceRecordId: item.id,
      );
    }
    if (item.sceneType == 'savoring_peak' && item.savoringOrMeaningMaking.trim().isNotEmpty) {
      await addAsset(
        assetType: 'peak_experience',
        title: item.title,
        content: item.savoringOrMeaningMaking,
        tags: item.coreValues,
        sourceRecordId: item.id,
      );
    }
    if (item.valueBinding.isNotEmpty) {
      await addAsset(
        assetType: 'value_binding',
        title: item.valueBinding.oldPattern.isEmpty ? '价值绑定' : item.valueBinding.oldPattern,
        content: '${item.valueBinding.boundValue}\n${item.valueBinding.painfulForm}\n${item.valueBinding.healthyExpression}',
        tags: item.coreValues,
        sourceRecordId: item.id,
      );
    }
  }


  Future<void> updateActionEvidence({
    required String id,
    String? status,
    String? evidenceText,
    String? reflection,
  }) async {
    final db = await _db;
    final values = <String, Object?>{'updated_at_ms': DateTime.now().millisecondsSinceEpoch};
    if (status != null) values['status'] = status;
    if (evidenceText != null) values['evidence_text'] = evidenceText;
    if (reflection != null) values['reflection'] = reflection;
    await db.update('realistic_positivity_os_action_evidence', values, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> applyRecordToProfile(RpoPracticeRecord item) async {
    final profile = await loadProfile();
    List<String> merge(List<String> old, Iterable<String> add, {int limit = 80}) {
      final seen = <String>{};
      final result = <String>[];
      for (final value in <String>[...add, ...old]) {
        final clean = value.trim();
        if (clean.isEmpty || seen.contains(clean)) continue;
        seen.add(clean);
        result.add(clean);
        if (result.length >= limit) break;
      }
      return result;
    }
    final bindings = <RpoValueBinding>[];
    if (item.valueBinding.isNotEmpty) bindings.add(item.valueBinding);
    bindings.addAll(profile.valueBindings);
    final uniqueBindings = <String, RpoValueBinding>{};
    for (final b in bindings) {
      final key = '${b.oldPattern}|${b.boundValue}|${b.healthyExpression}';
      if (!uniqueBindings.containsKey(key)) uniqueBindings[key] = b;
    }
    await saveProfile(RpoProfile(
      commonEmotions: profile.commonEmotions,
      commonOldQuestions: merge(profile.commonOldQuestions, <String>[item.oldQuestion], limit: 50),
      commonPatterns: merge(profile.commonPatterns, <String>[item.valueBinding.oldPattern], limit: 50),
      currentTroubles: merge(profile.currentTroubles, <String>[item.userInput], limit: 30),
      supportPeople: profile.supportPeople,
      relationshipMap: merge(profile.relationshipMap, <String>[item.relationshipAction], limit: 60),
      stretchAreas: merge(profile.stretchAreas, <String>[item.stretchZone.nextChallenge], limit: 40),
      gratitudeAssets: merge(profile.gratitudeAssets, item.sceneType == 'gratitude' ? <String>[item.realSituation] : const <String>[], limit: 80),
      peakExperiences: merge(profile.peakExperiences, item.sceneType == 'savoring_peak' ? <String>[item.savoringOrMeaningMaking] : const <String>[], limit: 60),
      identityEvidence: merge(profile.identityEvidence, <String>[item.identityEvidence], limit: 100),
      valueBindings: uniqueBindings.values.take(50).toList(growable: false),
    ));
  }


  Future<void> createExperiment({
    required String title,
    required String status,
    required String planJson,
    String progressJson = '{}',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db;
    await db.insert(
      'realistic_positivity_os_experiments',
      <String, Object?>{
        'id': 'rpo_exp_${now}_${title.hashCode.abs()}',
        'created_at_ms': now,
        'updated_at_ms': now,
        'title': title,
        'status': status,
        'plan_json': planJson,
        'progress_json': progressJson.trim().isEmpty ? '{}' : progressJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listExperiments({int limit = 80, String? status}) async {
    final db = await _db;
    return db.query(
      'realistic_positivity_os_experiments',
      where: (status == null || status.trim().isEmpty) ? null : 'status = ?',
      whereArgs: (status == null || status.trim().isEmpty) ? null : <Object?>[status.trim()],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> updateExperimentProgress({required String id, required Map<String, dynamic> progress}) async {
    final db = await _db;
    await db.update(
      'realistic_positivity_os_experiments',
      <String, Object?>{
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        'progress_json': jsonEncode(progress),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updateExperimentStatus({required String id, required String status}) async {
    final db = await _db;
    await db.update(
      'realistic_positivity_os_experiments',
      <String, Object?>{
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteExperiment(String id) async {
    final db = await _db;
    await db.delete('realistic_positivity_os_experiments', where: 'id = ?', whereArgs: <Object?>[id]);
  }


  Future<void> createExperimentFromRecord(RpoPracticeRecord item, {int horizonDays = 7, String status = 'active'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeHorizon = horizonDays.clamp(1, 90).toInt();
    final plan = <String, dynamic>{
      'source': 'practice_record',
      'source_record_id': item.id,
      'scene_type': item.sceneType,
      'title': item.microAction.title.trim().isEmpty ? item.title : item.microAction.title,
      'course_reference': '《哈佛积极心理学》Lecture 9–10',
      'core_values': item.coreValues,
      'better_question': item.betterQuestion,
      'reflection_question': item.reflectionQuestion,
      'micro_action': item.microAction.toJson(),
      'abc_plan': item.abcPlan.toJson(),
      'value_binding': item.valueBinding.toJson(),
      'stretch_zone': item.stretchZone.toJson(),
      'identity_evidence': item.identityEvidence,
      'daily_loop': <String>[
        '看见真实处境',
        '允许情绪或重温积极经验',
        '执行一个 2–10 分钟行动',
        '记录 Comfort / Stretch / Panic 状态',
        '写下一句新身份证据或下一步微调',
      ],
    };
    final title = plan['title'].toString().trim().isEmpty ? 'RPO 行动实验' : plan['title'].toString();
    final db = await _db;
    await db.insert(
      'realistic_positivity_os_experiments',
      <String, Object?>{
        'id': 'rpo_exp_${now}_${title.hashCode.abs()}',
        'created_at_ms': now,
        'updated_at_ms': now,
        'title': title,
        'status': status,
        'scene_type': item.sceneType,
        'source_record_id': item.id,
        'day_index': 0,
        'horizon_days': safeHorizon,
        'plan_json': jsonEncode(plan),
        'progress_json': jsonEncode(<String, dynamic>{'completed_days': <int>[], 'notes': <String>[]}),
        'metrics_json': jsonEncode(<String, dynamic>{'checkins': 0, 'panic_count': 0, 'stretch_count': 0, 'comfort_count': 0}),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateExperiment({
    required String id,
    String? status,
    int? dayIndex,
    Map<String, dynamic>? metrics,
    Map<String, dynamic>? progress,
  }) async {
    final db = await _db;
    final values = <String, Object?>{'updated_at_ms': DateTime.now().millisecondsSinceEpoch};
    if (status != null) values['status'] = status;
    if (dayIndex != null) values['day_index'] = dayIndex;
    if (metrics != null) values['metrics_json'] = jsonEncode(metrics);
    if (progress != null) values['progress_json'] = jsonEncode(progress);
    await db.update('realistic_positivity_os_experiments', values, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> addCheckIn({
    required String experimentId,
    required String completedAction,
    required String emotionNote,
    required String zone,
    required String reflection,
    required String nextAdjustment,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final date = DateTime.now().toIso8601String().split('T').first;
    final db = await _db;
    await db.insert(
      'realistic_positivity_os_checkins',
      <String, Object?>{
        'id': 'rpo_ci_${now}_${experimentId.hashCode.abs()}',
        'created_at_ms': now,
        'updated_at_ms': now,
        'experiment_id': experimentId,
        'checkin_date': date,
        'completed_action': completedAction,
        'emotion_note': emotionNote,
        'zone': zone,
        'reflection': reflection,
        'next_adjustment': nextAdjustment,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final rows = await db.query('realistic_positivity_os_experiments', where: 'id = ?', whereArgs: <Object?>[experimentId], limit: 1);
    if (rows.isNotEmpty) {
      final exp = rows.first;
      final currentDay = int.tryParse((exp['day_index'] ?? '0').toString()) ?? 0;
      final horizon = int.tryParse((exp['horizon_days'] ?? '7').toString()) ?? 7;
      final metrics = _decodeMap(exp['metrics_json']);
      final progress = _decodeMap(exp['progress_json']);
      metrics['checkins'] = (metrics['checkins'] is int ? metrics['checkins'] as int : int.tryParse((metrics['checkins'] ?? '0').toString()) ?? 0) + 1;
      metrics['last_zone'] = zone;
      metrics['last_reflection'] = reflection;
      metrics['last_completed_action'] = completedAction;
      metrics['last_checkin_date'] = date;
      metrics['${zone}_count'] = (metrics['${zone}_count'] is int ? metrics['${zone}_count'] as int : int.tryParse((metrics['${zone}_count'] ?? '0').toString()) ?? 0) + 1;
      final completedDays = <int>{..._intList(progress['completed_days']), currentDay + 1}.toList()..sort();
      progress['completed_days'] = completedDays;
      progress['last_next_adjustment'] = nextAdjustment;
      final nextDay = (currentDay + 1).clamp(0, horizon).toInt();
      final nextStatus = zone == 'panic' ? 'needs_support' : (nextDay >= horizon ? 'ready_review' : (exp['status'] ?? 'active').toString());
      await updateExperiment(id: experimentId, status: nextStatus, dayIndex: nextDay, metrics: metrics, progress: progress);
    }
    if (completedAction.trim().isNotEmpty || reflection.trim().isNotEmpty) {
      await addActionEvidence(
        sourceRecordId: experimentId,
        actionTitle: completedAction.trim().isEmpty ? 'RPO 实验 Check-in' : completedAction.trim(),
        status: 'done',
        evidenceText: completedAction.trim(),
        reflection: reflection.trim(),
      );
      if (reflection.trim().isNotEmpty) {
        await addAsset(assetType: 'identity_evidence', title: '实验 Check-in 身份证据', content: reflection.trim(), tags: <String>['experiment', zone], sourceRecordId: experimentId);
      }
    }
  }

  Future<List<Map<String, Object?>>> listCheckIns({int limit = 200, String? experimentId}) async {
    final db = await _db;
    return db.query(
      'realistic_positivity_os_checkins',
      where: (experimentId == null || experimentId.trim().isEmpty) ? null : 'experiment_id = ?',
      whereArgs: (experimentId == null || experimentId.trim().isEmpty) ? null : <Object?>[experimentId.trim()],
      orderBy: 'updated_at_ms DESC',
      limit: limit,
    );
  }

  Future<Map<String, int>> coverageCounts() async {
    final records = await listRecords(limit: 5000);
    final assets = await listAssets(limit: 5000);
    final evidence = await listActionEvidence(limit: 5000);
    final experiments = await listExperiments(limit: 1000);
    final checkins = await listCheckIns(limit: 5000);
    final profile = await loadProfile();
    int countScene(String scene) => records.where((e) => e.sceneType == scene).length;
    int countAssets(String type) => assets.where((e) => (e['asset_type'] ?? '').toString() == type).length;
    return <String, int>{
      'onboarding': countScene('onboarding') + profile.currentTroubles.length + profile.commonEmotions.length + profile.commonOldQuestions.length + profile.valueBindings.length + profile.supportPeople.length + profile.stretchAreas.length,
      'reality_lens': countScene('reality_lens'),
      'question_reframing': countScene('question_reframing') + profile.commonOldQuestions.length,
      'gratitude': countScene('gratitude') + countAssets('gratitude_asset') + profile.gratitudeAssets.length,
      'relational_gratitude': countScene('relational_gratitude') + profile.relationshipMap.length,
      'emotional_processing': countScene('emotional_processing'),
      'meaning_making': countScene('meaning_making'),
      'savoring_peak': countScene('savoring_peak') + countAssets('peak_experience') + profile.peakExperiences.length,
      'change_lab': countScene('change_lab') + countAssets('value_binding') + profile.valueBindings.length,
      'abc_change': countScene('abc_change'),
      'behavior_first': countScene('behavior_first'),
      'stretch_zone': countScene('stretch_zone') + profile.stretchAreas.length,
      'weekly_integration': countScene('weekly_integration'),
      'safety_support': records.where((e) => e.riskLevel == 'high' || e.riskLevel == 'crisis' || e.sceneType == 'crisis').length,
      'identity_evidence': evidence.length + countAssets('identity_evidence') + profile.identityEvidence.length,
      'action_experiments': experiments.length,
      'checkins': checkins.length,
      'profile_archive': assets.length + profile.gratitudeAssets.length + profile.peakExperiences.length + profile.identityEvidence.length + profile.valueBindings.length,
      'prompt_center': RealisticPositivityOsPromptConfig.allIds.length,
    };
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<int> _intList(Object? raw) {
    if (raw is List) return raw.map((e) => int.tryParse(e.toString())).whereType<int>().toList(growable: false);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        return _intList(decoded);
      } catch (_) {}
    }
    return const <int>[];
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('realistic_positivity_os_records');
    await db.delete('realistic_positivity_os_assets');
    await db.delete('realistic_positivity_os_action_evidence');
    await db.delete('realistic_positivity_os_experiments');
    await db.delete('realistic_positivity_os_checkins');
    await _kv.setString(profileKey, const RpoProfile().encode());
  }
}
