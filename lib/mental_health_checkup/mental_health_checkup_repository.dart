import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../data/kv_dao.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_generation_batch.dart';
import 'mental_health_indicator_governance.dart';
import 'mental_health_checkup_backup.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_models.dart';
import 'mental_health_checkup_platform.dart';
import 'mental_health_knowledge_models.dart';

class CheckupCourseEvidence {
  final String locationId;
  final int lecture;
  final String section;
  final String sourceStructure;
  final String language;
  final int globalParagraphIndex;
  final int lecturePosition;
  final int page;
  final String pageMethod;
  final String text;
  final String sourceFile;
  final String sourceSha256;

  const CheckupCourseEvidence({
    required this.locationId,
    required this.lecture,
    required this.section,
    required this.sourceStructure,
    required this.language,
    required this.globalParagraphIndex,
    required this.lecturePosition,
    required this.page,
    required this.pageMethod,
    required this.text,
    required this.sourceFile,
    required this.sourceSha256,
  });

  factory CheckupCourseEvidence.fromDatabase(Map<String, Object?> row) =>
      CheckupCourseEvidence(
        locationId: (row['location_id'] ?? '').toString(),
        lecture: (row['lecture_no'] as num?)?.toInt() ?? 0,
        section: (row['section'] ?? '').toString(),
        sourceStructure: (row['source_structure'] ?? '').toString(),
        language: (row['language'] ?? '').toString(),
        globalParagraphIndex:
            (row['global_paragraph_index'] as num?)?.toInt() ?? 0,
        lecturePosition: (row['lecture_position'] as num?)?.toInt() ?? 0,
        page: (row['page_no'] as num?)?.toInt() ?? 0,
        pageMethod: (row['page_method'] ?? '').toString(),
        text: (row['content'] ?? '').toString(),
        sourceFile: (row['source_file'] ?? '').toString(),
        sourceSha256: (row['source_sha256'] ?? '').toString(),
      );
}

class CheckupEvidenceTrace {
  final String relationId;
  final String indicatorId;
  final String evidenceRole;
  final String locationId;
  final String sourceLevel;
  final String excerpt;
  final double? confidence;
  final String reviewStatus;
  final int lecture;
  final int page;
  final String section;
  final String courseText;

  const CheckupEvidenceTrace({
    required this.relationId,
    required this.indicatorId,
    required this.evidenceRole,
    required this.locationId,
    required this.sourceLevel,
    required this.excerpt,
    required this.confidence,
    required this.reviewStatus,
    required this.lecture,
    required this.page,
    required this.section,
    required this.courseText,
  });

  factory CheckupEvidenceTrace.fromDatabase(Map<String, Object?> row) =>
      CheckupEvidenceTrace(
        relationId: (row['relation_id'] ?? '').toString(),
        indicatorId: (row['indicator_id'] ?? '').toString(),
        evidenceRole: (row['evidence_role'] ?? '').toString(),
        locationId: (row['location_id'] ?? '').toString(),
        sourceLevel: (row['source_level'] ?? '').toString(),
        excerpt: (row['excerpt'] ?? '').toString(),
        confidence: (row['confidence'] as num?)?.toDouble(),
        reviewStatus: (row['review_status'] ?? '').toString(),
        lecture: (row['lecture_no'] as num?)?.toInt() ?? 0,
        page: (row['page_no'] as num?)?.toInt() ?? 0,
        section: (row['section'] ?? '').toString(),
        courseText: (row['course_text'] ?? '').toString(),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'relation_id': relationId,
        'indicator_id': indicatorId,
        'evidence_role': evidenceRole,
        'location_id': locationId,
        'source_level': sourceLevel,
        'excerpt': excerpt,
        'confidence': confidence,
        'review_status': reviewStatus,
        'lecture': lecture,
        'page': page,
        'section': section,
        'course_text': courseText,
      };
}

class MentalHealthCheckupRepository {
  static const int _schemaVersion = 8;
  static const String _legacyStateKey = 'mental_health_checkup.state.v25';
  static const String _legacyDraftKey = 'mental_health_checkup.draft.v25';
  static const String _promptPrefix = 'ai_prompt.mental_health_checkup.';
  static const String _profileId = 'local';
  static const String _draftId = 'active';
  static const String _courseSeedFile = 'course_location_index.jsonl';
  static const String _evidenceSeedFile = 'indicator_evidence_graph.jsonl';

  final KeyValueDao _kv;
  final MentalHealthCheckupPlatform _platform;
  Future<void>? _initializing;

  MentalHealthCheckupRepository({
    KeyValueDao? keyValueDao,
    MentalHealthCheckupPlatform? platform,
  })  : _kv = keyValueDao ?? KeyValueDao(),
        _platform = platform ?? const MentalHealthCheckupPlatform();

  Future<void> initialize(MentalHealthCheckupCatalog catalog) async {
    final future = _initializing ??= _initialize(catalog);
    try {
      await future;
    } catch (_) {
      if (identical(_initializing, future)) _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize(MentalHealthCheckupCatalog catalog) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await _importReferenceSeedsIfNeeded(db, catalog);
    await _importLegacyContentCandidatesIfNeeded(db, catalog);
    await _migrateLegacyStateIfNeeded(db);
  }

  Future<void> _ensureSchema(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_profile (
          id TEXT PRIMARY KEY,
          install_id TEXT NOT NULL,
          onboarding_accepted INTEGER NOT NULL DEFAULT 0,
          settings_json TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_sessions (
          id TEXT PRIMARY KEY,
          completed_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_answers (
          session_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          answered_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          PRIMARY KEY (session_id, question_id),
          FOREIGN KEY (session_id) REFERENCES mh_sessions(id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_plans (
          id TEXT PRIMARY KEY,
          status TEXT NOT NULL,
          started_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_execution_logs (
          plan_id TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          PRIMARY KEY (plan_id, created_at_ms),
          FOREIGN KEY (plan_id) REFERENCES mh_plans(id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_retests (
          id TEXT PRIMARY KEY,
          plan_id TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          FOREIGN KEY (plan_id) REFERENCES mh_plans(id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_drafts (
          id TEXT PRIMARY KEY,
          updated_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_content_candidates (
          id TEXT PRIMARY KEY,
          indicator_id TEXT NOT NULL,
          content_kind TEXT NOT NULL,
          content_code TEXT NOT NULL,
          stage TEXT NOT NULL,
          version INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_content_audit_events (
          id TEXT PRIMARY KEY,
          candidate_id TEXT NOT NULL,
          from_stage TEXT NOT NULL,
          to_stage TEXT NOT NULL,
          actor TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          FOREIGN KEY (candidate_id) REFERENCES mh_content_candidates(id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_indicator_candidates (
          id TEXT PRIMARY KEY,
          proposed_indicator_id TEXT NOT NULL,
          lecture_no INTEGER NOT NULL,
          stage TEXT NOT NULL,
          version INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_indicator_audit_events (
          id TEXT PRIMARY KEY,
          candidate_id TEXT NOT NULL,
          from_stage TEXT NOT NULL,
          to_stage TEXT NOT NULL,
          actor TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          FOREIGN KEY (candidate_id) REFERENCES mh_indicator_candidates(id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_provider_knowledge_resources (
          id TEXT PRIMARY KEY,
          provider TEXT NOT NULL,
          account_fingerprint TEXT NOT NULL,
          course_version TEXT NOT NULL,
          source_sha256 TEXT NOT NULL,
          status TEXT NOT NULL,
          enabled INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_generation_batches (
          id TEXT PRIMARY KEY,
          status TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_generation_jobs (
          id TEXT PRIMARY KEY,
          batch_id TEXT NOT NULL,
          indicator_id TEXT NOT NULL,
          content_code TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          FOREIGN KEY (batch_id) REFERENCES mh_generation_batches(id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_content_candidate_indicator '
        'ON mh_content_candidates(indicator_id, content_kind, content_code)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_content_candidate_stage '
        'ON mh_content_candidates(stage, updated_at_ms DESC)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_content_audit_candidate '
        'ON mh_content_audit_events(candidate_id, created_at_ms)',
      );
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS '
        'idx_mh_indicator_candidate_proposed_version '
        'ON mh_indicator_candidates(proposed_indicator_id, version)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_indicator_candidate_stage '
        'ON mh_indicator_candidates(stage, updated_at_ms DESC)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_indicator_audit_candidate '
        'ON mh_indicator_audit_events(candidate_id, created_at_ms)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_provider_resource_lookup '
        'ON mh_provider_knowledge_resources('
        'provider, account_fingerprint, enabled, updated_at_ms DESC)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_generation_batch_status '
        'ON mh_generation_batches(status, updated_at_ms DESC)',
      );
      await txn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_mh_generation_job_slot '
        'ON mh_generation_jobs(batch_id, indicator_id, content_code)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_generation_job_status '
        'ON mh_generation_jobs(batch_id, status, updated_at_ms)',
      );
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_indicators (
          indicator_id TEXT PRIMARY KEY,
          lecture_no INTEGER NOT NULL,
          area TEXT NOT NULL,
          name TEXT NOT NULL,
          indicator_type TEXT NOT NULL,
          definition_location TEXT NOT NULL,
          low_location TEXT NOT NULL,
          high_location TEXT NOT NULL,
          action_location TEXT NOT NULL,
          direct_evidence_count INTEGER NOT NULL,
          directness TEXT NOT NULL,
          review_status TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_course_locations (
          location_id TEXT PRIMARY KEY,
          lecture_no INTEGER NOT NULL,
          section TEXT NOT NULL,
          source_structure TEXT NOT NULL,
          language TEXT NOT NULL,
          global_paragraph_index INTEGER NOT NULL,
          lecture_position INTEGER NOT NULL,
          page_no INTEGER NOT NULL,
          page_method TEXT NOT NULL,
          content TEXT NOT NULL,
          source_file TEXT NOT NULL,
          source_sha256 TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS mh_indicator_evidence (
          relation_id TEXT PRIMARY KEY,
          indicator_id TEXT NOT NULL,
          evidence_role TEXT NOT NULL,
          location_id TEXT NOT NULL,
          source_level TEXT NOT NULL,
          excerpt TEXT NOT NULL,
          confidence REAL,
          review_status TEXT NOT NULL,
          FOREIGN KEY (indicator_id) REFERENCES mh_indicators(indicator_id)
            ON DELETE CASCADE,
          FOREIGN KEY (location_id) REFERENCES mh_course_locations(location_id)
            ON DELETE CASCADE
        )
      ''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_evidence_indicator '
        'ON mh_indicator_evidence(indicator_id)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_evidence_location '
        'ON mh_indicator_evidence(location_id)',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_mh_course_lecture '
        'ON mh_course_locations(lecture_no, lecture_position)',
      );
      try {
        await txn.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS mh_course_locations_fts
          USING fts4(location_id, content)
        ''');
        await _putMeta(txn, 'fts_enabled', '1');
      } catch (_) {
        await _putMeta(txn, 'fts_enabled', '0');
      }

      final stored = await txn.query(
        'mh_meta',
        columns: <String>['value'],
        where: 'key = ?',
        whereArgs: <Object?>['schema_version'],
        limit: 1,
      );
      final oldVersion = stored.isEmpty
          ? 0
          : int.tryParse((stored.first['value'] ?? '0').toString()) ?? 0;
      if (oldVersion > _schemaVersion) {
        throw StateError('心理健康体检数据库版本过新：$oldVersion');
      }
      await _runMigrations(txn, oldVersion);
      await _putMeta(txn, 'schema_version', '$_schemaVersion');
    });
  }

  Future<void> _runMigrations(DatabaseExecutor db, int oldVersion) async {
    if (oldVersion < 1) {
      await _putMeta(db, 'migration_1', 'normalized_state_tables');
    }
    if (oldVersion < 2) {
      await _putMeta(db, 'migration_2', 'course_location_fts');
    }
    if (oldVersion < 3) {
      await _putMeta(db, 'migration_3', 'encrypted_contact_settings');
    }
    if (oldVersion < 4) {
      await _putMeta(
        db,
        'migration_4',
        'indicator_and_evidence_reference_tables',
      );
    }
    if (oldVersion < 5) {
      await _putMeta(
        db,
        'migration_5',
        'content_candidate_governance_and_audit',
      );
    }
    if (oldVersion < 6) {
      await _putMeta(
        db,
        'migration_6',
        'indicator_candidate_governance_and_audit',
      );
    }
    if (oldVersion < 7) {
      await _putMeta(
        db,
        'migration_7',
        'provider_knowledge_resource_lifecycle',
      );
    }
    if (oldVersion < 8) {
      await _putMeta(db, 'migration_8', 'resumable_content_generation_batches');
    }
  }

  Future<void> _importReferenceSeedsIfNeeded(
    Database db,
    MentalHealthCheckupCatalog catalog,
  ) async {
    final currentVersion = await _meta(db, 'course_seed_version');
    final courseCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM mh_course_locations'),
        ) ??
        0;
    final indicatorCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM mh_indicators'),
        ) ??
        0;
    final evidenceCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM mh_indicator_evidence'),
        ) ??
        0;
    if (currentVersion == catalog.validation.version &&
        courseCount == 2253 &&
        indicatorCount == 345 &&
        evidenceCount == 1380) {
      return;
    }

    final seedBytes = await Future.wait<Uint8List>(<Future<Uint8List>>[
      _loadSeedBytes(_courseSeedFile),
      _loadSeedBytes(_evidenceSeedFile),
    ]);
    final courseLines = const LineSplitter()
        .convert(utf8.decode(seedBytes[0]))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    final evidenceLines = const LineSplitter()
        .convert(utf8.decode(seedBytes[1]))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (courseLines.length != 2253) {
      throw StateError('课程定位索引应为2253条，实际为${courseLines.length}条。');
    }
    if (catalog.indicators.length != 345 || evidenceLines.length != 1380) {
      throw StateError(
        '指标/证据关系数量不符：'
        '${catalog.indicators.length}/345，${evidenceLines.length}/1380。',
      );
    }

    await db.transaction((txn) async {
      await txn.delete('mh_indicator_evidence');
      await txn.delete('mh_indicators');
      await txn.delete('mh_course_locations');
      final ftsEnabled = await _meta(txn, 'fts_enabled') == '1';
      if (ftsEnabled) await txn.delete('mh_course_locations_fts');
      final batch = txn.batch();
      final indicatorIds = <String>{};
      for (final indicator in catalog.indicators) {
        if (indicator.id.isEmpty || !indicatorIds.add(indicator.id)) {
          throw StateError('指标ID缺失或重复：${indicator.id}');
        }
        batch.insert(
            'mh_indicators',
            <String, Object?>{
              'indicator_id': indicator.id,
              'lecture_no': indicator.lecture,
              'area': indicator.area,
              'name': indicator.name,
              'indicator_type': indicator.type,
              'definition_location': indicator.definitionLocation,
              'low_location': indicator.lowLocation,
              'high_location': indicator.highLocation,
              'action_location': indicator.actionLocation,
              'direct_evidence_count': indicator.directEvidenceCount,
              'directness': indicator.directness,
              'review_status': indicator.reviewStatus,
            },
            conflictAlgorithm: ConflictAlgorithm.abort);
      }

      final courseLocationIds = <String>{};
      for (final line in courseLines) {
        final row = Map<String, dynamic>.from(jsonDecode(line) as Map);
        final values = <String, Object?>{
          'location_id': (row['定位单元ID'] ?? '').toString(),
          'lecture_no': (row['讲次'] as num?)?.toInt() ?? 0,
          'section': (row['章节'] ?? '').toString(),
          'source_structure': (row['来源结构'] ?? '').toString(),
          'language': (row['语言'] ?? '').toString(),
          'global_paragraph_index': (row['全局段落索引'] as num?)?.toInt() ?? 0,
          'lecture_position': (row['讲内位置'] as num?)?.toInt() ?? 0,
          'page_no': (row['固定页'] as num?)?.toInt() ?? 0,
          'page_method': (row['页码方法'] ?? '').toString(),
          'content': (row['原文全文'] ?? '').toString(),
          'source_file': (row['课程文件'] ?? '').toString(),
          'source_sha256': (row['SHA256'] ?? '').toString(),
        };
        final locationId = values['location_id']!.toString();
        if (locationId.isEmpty || !courseLocationIds.add(locationId)) {
          throw StateError('课程定位ID缺失或重复：$locationId');
        }
        batch.insert(
          'mh_course_locations',
          values,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        if (ftsEnabled) {
          batch.insert('mh_course_locations_fts', <String, Object?>{
            'location_id': values['location_id'],
            'content': values['content'],
          });
        }
      }

      final relationIds = <String>{};
      for (final line in evidenceLines) {
        final row = Map<String, dynamic>.from(jsonDecode(line) as Map);
        final indicatorId = (row['指标ID'] ?? '').toString();
        final locationId = (row['定位单元ID'] ?? '').toString();
        final role = (row['证据角色'] ?? '').toString();
        final relationId = '$indicatorId|$role|$locationId';
        if (!indicatorIds.contains(indicatorId) ||
            !courseLocationIds.contains(locationId)) {
          throw StateError('证据关系引用不存在：$relationId');
        }
        if (!relationIds.add(relationId)) {
          throw StateError('证据关系ID重复：$relationId');
        }
        batch.insert(
            'mh_indicator_evidence',
            <String, Object?>{
              'relation_id': relationId,
              'indicator_id': indicatorId,
              'evidence_role': role,
              'location_id': locationId,
              'source_level': (row['证据等级'] ?? '').toString(),
              'excerpt': (row['原文摘录'] ?? '').toString(),
              'confidence': (row['置信度'] as num?)?.toDouble(),
              'review_status': (row['审核状态'] ?? '').toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.abort);
      }
      await batch.commit(noResult: true);
      await _putMeta(txn, 'course_seed_version', catalog.validation.version);
      await _putMeta(txn, 'course_seed_count', '${courseLines.length}');
      await _putMeta(txn, 'indicator_seed_count', '${indicatorIds.length}');
      await _putMeta(txn, 'evidence_seed_count', '${relationIds.length}');
    });
  }

  Future<void> _migrateLegacyStateIfNeeded(Database db) async {
    final profileCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM mh_profile'),
        ) ??
        0;
    if (profileCount > 0) return;

    final legacyRaw = await _kv.getString(_legacyStateKey);
    MentalHealthCheckupState state;
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      try {
        state = MentalHealthCheckupState.decode(legacyRaw);
      } catch (_) {
        state = const MentalHealthCheckupState();
      }
    } else {
      state = const MentalHealthCheckupState();
    }
    state = _ensureInstallId(state);
    await _persistState(db, state);

    final legacyDraft = await _kv.getString(_legacyDraftKey);
    if (legacyDraft != null && legacyDraft.trim().isNotEmpty) {
      try {
        jsonDecode(legacyDraft);
        await db.insert(
            'mh_drafts',
            <String, Object?>{
              'id': _draftId,
              'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
              'payload_json': legacyDraft,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
    await db.delete(
      'notify_config',
      where: 'key = ? OR key = ?',
      whereArgs: <Object?>[_legacyStateKey, _legacyDraftKey],
    );
  }

  Future<void> _importLegacyContentCandidatesIfNeeded(
    Database db,
    MentalHealthCheckupCatalog catalog,
  ) async {
    final storedVersion = await _meta(db, 'legacy_content_seed_version');
    final storedCount = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM mh_content_candidates WHERE id LIKE 'LEGACY-%'",
          ),
        ) ??
        0;
    if (storedVersion == catalog.validation.version && storedCount == 138) {
      return;
    }
    final candidates = catalog.legacyContentCandidates;
    final attitudeCount = candidates
        .where(
          (candidate) => candidate.kind == CheckupContentKind.assessmentItem,
        )
        .length;
    final behaviorCount = candidates
        .where((candidate) => candidate.kind == CheckupContentKind.behaviorTask)
        .length;
    if (candidates.length != 138 ||
        attitudeCount != 92 ||
        behaviorCount != 46) {
      throw StateError(
        '历史内容数量不符：'
        '${candidates.length}/138，题目$attitudeCount/92，'
        '任务$behaviorCount/46。',
      );
    }
    final indicatorIds =
        catalog.indicators.map((indicator) => indicator.id).toSet();
    final candidateIds = <String>{};
    await db.transaction((txn) async {
      for (final candidate in candidates) {
        if (!candidateIds.add(candidate.candidateId) ||
            !indicatorIds.contains(candidate.primaryIndicatorId) ||
            candidate.stage != CheckupCandidateStage.candidate) {
          throw StateError('历史候选映射无效：${candidate.candidateId}');
        }
        await txn.insert(
            'mh_content_candidates',
            <String, Object?>{
              'id': candidate.candidateId,
              'indicator_id': candidate.primaryIndicatorId,
              'content_kind': candidate.kind.name,
              'content_code': candidate.contentCode,
              'stage': candidate.stage.name,
              'version': candidate.version,
              'updated_at_ms': candidate.updatedAtMs,
              'payload_json': jsonEncode(candidate.toJson()),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await _putMeta(
        txn,
        'legacy_content_seed_version',
        catalog.validation.version,
      );
      await _putMeta(txn, 'legacy_content_seed_count', '${candidates.length}');
    });
  }

  Future<MentalHealthCheckupState> load({
    MentalHealthCheckupCatalog? catalog,
  }) async {
    if (catalog != null) {
      await initialize(catalog);
    } else {
      final db = await AppDatabase.instance();
      await _ensureSchema(db);
    }
    final db = await AppDatabase.instance();
    final profiles = await db.query(
      'mh_profile',
      where: 'id = ?',
      whereArgs: <Object?>[_profileId],
      limit: 1,
    );
    if (profiles.isEmpty) {
      final fresh = _ensureInstallId(const MentalHealthCheckupState());
      await _persistState(db, fresh);
      return fresh;
    }
    final profile = profiles.first;
    final settings = await _decodeSettings(
      Map<String, dynamic>.from(
        jsonDecode((profile['settings_json'] ?? '{}').toString()) as Map,
      ),
    );

    final sessionRows = await db.query(
      'mh_sessions',
      orderBy: 'completed_at_ms DESC',
    );
    final answerRows = await db.query(
      'mh_answers',
      orderBy: 'answered_at_ms ASC',
    );
    final answersBySession = <String, List<Map<String, dynamic>>>{};
    for (final row in answerRows) {
      final id = (row['session_id'] ?? '').toString();
      final answer = Map<String, dynamic>.from(
        jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
      );
      answersBySession
          .putIfAbsent(id, () => <Map<String, dynamic>>[])
          .add(answer);
    }
    final sessions = sessionRows.map((row) {
      final payload = Map<String, dynamic>.from(
        jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
      );
      payload['answers'] =
          answersBySession[(row['id'] ?? '').toString()] ?? const <Object?>[];
      return CheckupSession.fromJson(payload);
    }).toList(growable: false);

    final logRows = await db.query(
      'mh_execution_logs',
      orderBy: 'created_at_ms DESC',
    );
    final logsByPlan = <String, List<Map<String, dynamic>>>{};
    for (final row in logRows) {
      final id = (row['plan_id'] ?? '').toString();
      final log = Map<String, dynamic>.from(
        jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
      );
      logsByPlan.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(log);
    }
    final planRows = await db.query('mh_plans', orderBy: 'started_at_ms DESC');
    final plans = planRows.map((row) {
      final payload = Map<String, dynamic>.from(
        jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
      );
      payload['logs'] =
          logsByPlan[(row['id'] ?? '').toString()] ?? const <Object?>[];
      return CheckupPrescriptionPlan.fromJson(payload);
    }).toList(growable: false);

    final retestRows = await db.query(
      'mh_retests',
      orderBy: 'created_at_ms DESC',
    );
    final retests = retestRows
        .map(
          (row) => CheckupRetestRecord.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
    return MentalHealthCheckupState(
      schemaVersion: _schemaVersion,
      installId: (profile['install_id'] ?? '').toString(),
      onboardingAccepted:
          (profile['onboarding_accepted'] as num?)?.toInt() == 1,
      settings: settings,
      sessions: sessions,
      plans: plans,
      retests: retests,
    );
  }

  Future<void> save(MentalHealthCheckupState state) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await _persistState(db, _ensureInstallId(state));
  }

  Future<void> _persistState(
    Database db,
    MentalHealthCheckupState state,
  ) async {
    final normalized = _ensureInstallId(state);
    final settingsJson = jsonEncode(await _encodeSettings(normalized.settings));
    await db.transaction((txn) async {
      await txn.insert(
          'mh_profile',
          <String, Object?>{
            'id': _profileId,
            'install_id': normalized.installId,
            'onboarding_accepted': normalized.onboardingAccepted ? 1 : 0,
            'settings_json': settingsJson,
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('mh_answers');
      await txn.delete('mh_sessions');
      await txn.delete('mh_execution_logs');
      await txn.delete('mh_retests');
      await txn.delete('mh_plans');

      for (final session in normalized.sessions) {
        final payload = session.toJson();
        payload['answers'] = const <Object?>[];
        await txn.insert('mh_sessions', <String, Object?>{
          'id': session.id,
          'completed_at_ms': session.completedAtMs,
          'payload_json': jsonEncode(payload),
        });
        for (final answer in session.answers) {
          await txn.insert('mh_answers', <String, Object?>{
            'session_id': session.id,
            'question_id': answer.questionId,
            'answered_at_ms': answer.answeredAtMs,
            'payload_json': jsonEncode(answer.toJson()),
          });
        }
      }
      for (final plan in normalized.plans) {
        final payload = plan.toJson();
        payload['logs'] = const <Object?>[];
        await txn.insert('mh_plans', <String, Object?>{
          'id': plan.id,
          'status': plan.status.name,
          'started_at_ms': plan.startedAtMs,
          'payload_json': jsonEncode(payload),
        });
        for (final log in plan.logs) {
          await txn.insert('mh_execution_logs', <String, Object?>{
            'plan_id': plan.id,
            'created_at_ms': log.createdAtMs,
            'payload_json': jsonEncode(log.toJson()),
          });
        }
      }
      for (final retest in normalized.retests) {
        await txn.insert('mh_retests', <String, Object?>{
          'id': retest.id,
          'plan_id': retest.planId,
          'created_at_ms': retest.createdAtMs,
          'payload_json': jsonEncode(retest.toJson()),
        });
      }
    });
  }

  Future<MentalHealthCheckupState> acceptOnboarding(
    MentalHealthCheckupState state,
  ) async {
    final next = _ensureInstallId(state).copyWith(onboardingAccepted: true);
    await save(next);
    return next;
  }

  Future<MentalHealthCheckupState> updateSettings(
    MentalHealthCheckupState state,
    MentalHealthCheckupSettings settings,
  ) async {
    final next = _ensureInstallId(state).copyWith(settings: settings);
    await save(next);
    return next;
  }

  Future<void> saveCompletedSession(CheckupSession session) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      final payload = session.toJson();
      payload['answers'] = const <Object?>[];
      await txn.insert(
          'mh_sessions',
          <String, Object?>{
            'id': session.id,
            'completed_at_ms': session.completedAtMs,
            'payload_json': jsonEncode(payload),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'mh_answers',
        where: 'session_id = ?',
        whereArgs: <Object?>[session.id],
      );
      for (final answer in session.answers) {
        await txn.insert('mh_answers', <String, Object?>{
          'session_id': session.id,
          'question_id': answer.questionId,
          'answered_at_ms': answer.answeredAtMs,
          'payload_json': jsonEncode(answer.toJson()),
        });
      }
      await txn.delete(
        'mh_drafts',
        where: 'id = ?',
        whereArgs: <Object?>[_draftId],
      );
    });
  }

  Future<MentalHealthCheckupState> addSession(
    MentalHealthCheckupState state,
    CheckupSession session,
  ) async {
    final sessions = <CheckupSession>[
      session,
      ...state.sessions.where((item) => item.id != session.id),
    ];
    final next = _ensureInstallId(state).copyWith(sessions: sessions);
    await save(next);
    await clearDraft();
    return next;
  }

  Future<MentalHealthCheckupState> upsertPlan(
    MentalHealthCheckupState state,
    CheckupPrescriptionPlan plan,
  ) async {
    final plans = <CheckupPrescriptionPlan>[
      plan,
      ...state.plans.where((item) => item.id != plan.id),
    ];
    final next = _ensureInstallId(state).copyWith(plans: plans);
    await save(next);
    return next;
  }

  Future<MentalHealthCheckupState> appendExecutionLog(
    MentalHealthCheckupState state,
    String planId,
    CheckupExecutionLog log,
  ) async {
    final plans = state.plans.map((plan) {
      if (plan.id != planId) return plan;
      return plan.copyWith(logs: <CheckupExecutionLog>[log, ...plan.logs]);
    }).toList(growable: false);
    final next = _ensureInstallId(state).copyWith(plans: plans);
    await save(next);
    return next;
  }

  Future<MentalHealthCheckupState> completeRetest({
    required MentalHealthCheckupState state,
    required CheckupSession session,
    required CheckupRetestRecord retest,
    required CheckupPrescriptionPlan updatedPlan,
  }) async {
    final sessions = <CheckupSession>[
      session,
      ...state.sessions.where((item) => item.id != session.id),
    ];
    final plans = <CheckupPrescriptionPlan>[
      updatedPlan,
      ...state.plans.where((item) => item.id != updatedPlan.id),
    ];
    final retests = <CheckupRetestRecord>[
      retest,
      ...state.retests.where((item) => item.id != retest.id),
    ];
    final next = _ensureInstallId(
      state,
    ).copyWith(sessions: sessions, plans: plans, retests: retests);
    await save(next);
    await clearDraft();
    return next;
  }

  Future<void> saveDraft({
    required String sessionId,
    required String modeId,
    required String modeName,
    required String? focusDomainId,
    required int startedAtMs,
    required int currentIndex,
    required List<CheckupAnswer> answers,
    List<String> questionIds = const <String>[],
    CheckupAssessmentPlan assessmentPlan = const CheckupAssessmentPlan(),
  }) async {
    final payload = <String, Object?>{
      'session_id': sessionId,
      'mode_id': modeId,
      'mode_name': modeName,
      'focus_domain_id': focusDomainId,
      'started_at_ms': startedAtMs,
      'current_index': currentIndex,
      'question_ids': questionIds,
      'answers':
          answers.map((answer) => answer.toJson()).toList(growable: false),
      'assessment_plan': assessmentPlan.toJson(),
    };
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.insert(
        'mh_drafts',
        <String, Object?>{
          'id': _draftId,
          'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
          'payload_json': jsonEncode(payload),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.query(
      'mh_drafts',
      where: 'id = ?',
      whereArgs: <Object?>[_draftId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(
        jsonDecode((rows.first['payload_json'] ?? '{}').toString()) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft() async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.delete(
      'mh_drafts',
      where: 'id = ?',
      whereArgs: <Object?>[_draftId],
    );
  }

  Future<List<CheckupContentCandidate>> loadContentCandidates({
    String? indicatorId,
    CheckupCandidateStage? stage,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final clauses = <String>[];
    final args = <Object?>[];
    if (indicatorId != null && indicatorId.trim().isNotEmpty) {
      clauses.add('indicator_id = ?');
      args.add(indicatorId.trim());
    }
    if (stage != null) {
      clauses.add('stage = ?');
      args.add(stage.name);
    }
    final rows = await db.query(
      'mh_content_candidates',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at_ms DESC, version DESC',
    );
    return rows
        .map(
          (row) => CheckupContentCandidate.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveContentCandidate(CheckupContentCandidate candidate) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      final existing = await txn.query(
        'mh_content_candidates',
        columns: <String>['stage', 'payload_json'],
        where: 'id = ?',
        whereArgs: <Object?>[candidate.candidateId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingStage = (existing.first['stage'] ?? '').toString();
        if (existingStage == CheckupCandidateStage.official.name ||
            existingStage == CheckupCandidateStage.retired.name) {
          final existingPayload =
              (existing.first['payload_json'] ?? '').toString();
          if (existingPayload != jsonEncode(candidate.toJson())) {
            throw StateError('正式或已停用内容不可覆盖；请派生新版本。');
          }
          return;
        }
      }
      await _putContentCandidate(txn, candidate);
    });
  }

  Future<void> saveContentTransition(
    CheckupCandidateTransition transition,
  ) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      final currentRows = await txn.query(
        'mh_content_candidates',
        columns: <String>['stage'],
        where: 'id = ?',
        whereArgs: <Object?>[transition.candidate.candidateId],
        limit: 1,
      );
      if (currentRows.isEmpty) throw StateError('候选内容不存在，无法变更状态。');
      final currentStage = (currentRows.first['stage'] ?? '').toString();
      if (currentStage != transition.auditEvent.fromStage.name ||
          transition.candidate.stage != transition.auditEvent.toStage) {
        throw StateError('候选状态已变化，请刷新后重试。');
      }
      if (transition.candidate.stage == CheckupCandidateStage.official) {
        final locationIds = <String>{
          ...transition.candidate.evidenceLocationIds,
          transition.candidate.definitionLocation,
          transition.candidate.lowLocation,
          transition.candidate.highLocation,
          transition.candidate.actionLocation,
        }..removeWhere((value) => value.trim().isEmpty);
        if (locationIds.isEmpty) {
          throw StateError('正式指标没有课程证据位置。');
        }
        final locationRows = await txn.query(
          'mh_course_locations',
          columns: <String>['location_id', 'lecture_no'],
          where: 'location_id IN '
              '(${List<String>.filled(locationIds.length, '?').join(',')})',
          whereArgs: locationIds.toList(growable: false),
        );
        if (locationRows.length != locationIds.length) {
          throw StateError('存在无法在本地课程知识库验证的证据位置ID。');
        }
        if (locationRows.any(
          (row) =>
              (row['lecture_no'] as num?)?.toInt() !=
              transition.candidate.lecture,
        )) {
          throw StateError('课程证据位置与候选指标讲次不一致。');
        }
        final seededIndicatorConflicts = Sqflite.firstIntValue(
              await txn.rawQuery(
                '''
                SELECT COUNT(*)
                FROM mh_indicators
                WHERE indicator_id = ?
                ''',
                <Object?>[transition.candidate.proposedIndicatorId],
              ),
            ) ??
            0;
        if (seededIndicatorConflicts > 0) {
          throw StateError('候选指标ID与内置正式指标冲突。');
        }
        final conflicts = Sqflite.firstIntValue(
              await txn.rawQuery(
                '''
                SELECT COUNT(*)
                FROM mh_content_candidates
                WHERE indicator_id = ? AND content_kind = ?
                  AND content_code = ? AND version = ?
                  AND stage = ? AND id != ?
                ''',
                <Object?>[
                  transition.candidate.primaryIndicatorId,
                  transition.candidate.kind.name,
                  transition.candidate.contentCode,
                  transition.candidate.version,
                  CheckupCandidateStage.official.name,
                  transition.candidate.candidateId,
                ],
              ),
            ) ??
            0;
        if (conflicts > 0) {
          throw StateError('同一指标、内容类型和版本已经存在正式内容。');
        }
      }
      await _putContentCandidate(txn, transition.candidate);
      await txn.insert(
          'mh_content_audit_events',
          <String, Object?>{
            'id': transition.auditEvent.id,
            'candidate_id': transition.auditEvent.candidateId,
            'from_stage': transition.auditEvent.fromStage.name,
            'to_stage': transition.auditEvent.toStage.name,
            'actor': transition.auditEvent.actor,
            'created_at_ms': transition.auditEvent.createdAtMs,
            'payload_json': jsonEncode(transition.auditEvent.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.abort);
    });
  }

  Future<List<CheckupContentAuditEvent>> loadContentAudit(
    String candidateId,
  ) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.query(
      'mh_content_audit_events',
      where: 'candidate_id = ?',
      whereArgs: <Object?>[candidateId],
      orderBy: 'created_at_ms ASC',
    );
    return rows
        .map(
          (row) => CheckupContentAuditEvent.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CheckupIndicatorCandidate>> loadIndicatorCandidates({
    CheckupCandidateStage? stage,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.query(
      'mh_indicator_candidates',
      where: stage == null ? null : 'stage = ?',
      whereArgs: stage == null ? null : <Object?>[stage.name],
      orderBy: 'updated_at_ms DESC, version DESC',
    );
    return rows
        .map(
          (row) => CheckupIndicatorCandidate.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveIndicatorCandidate(
    CheckupIndicatorCandidate candidate,
  ) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      final existing = await txn.query(
        'mh_indicator_candidates',
        columns: <String>['stage', 'payload_json'],
        where: 'id = ?',
        whereArgs: <Object?>[candidate.candidateId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingStage = (existing.first['stage'] ?? '').toString();
        if (existingStage == CheckupCandidateStage.official.name ||
            existingStage == CheckupCandidateStage.retired.name) {
          if ((existing.first['payload_json'] ?? '').toString() !=
              jsonEncode(candidate.toJson())) {
            throw StateError('正式或已停用指标不可覆盖；请派生新版本。');
          }
          return;
        }
      }
      await _putIndicatorCandidate(txn, candidate);
    });
  }

  Future<void> saveIndicatorTransition(
    CheckupIndicatorTransition transition,
  ) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      final rows = await txn.query(
        'mh_indicator_candidates',
        columns: <String>['stage'],
        where: 'id = ?',
        whereArgs: <Object?>[transition.candidate.candidateId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('候选指标不存在，无法变更状态。');
      final currentStage = (rows.first['stage'] ?? '').toString();
      if (currentStage != transition.auditEvent.fromStage.name ||
          transition.candidate.stage != transition.auditEvent.toStage) {
        throw StateError('候选指标状态已变化，请刷新后重试。');
      }
      if (transition.candidate.stage == CheckupCandidateStage.official) {
        final conflicts = Sqflite.firstIntValue(
              await txn.rawQuery(
                '''
                SELECT COUNT(*)
                FROM mh_indicator_candidates
                WHERE proposed_indicator_id = ? AND version = ?
                  AND stage = ? AND id != ?
                ''',
                <Object?>[
                  transition.candidate.proposedIndicatorId,
                  transition.candidate.version,
                  CheckupCandidateStage.official.name,
                  transition.candidate.candidateId,
                ],
              ),
            ) ??
            0;
        if (conflicts > 0) {
          throw StateError('同一候选指标和版本已经存在正式记录。');
        }
      }
      await _putIndicatorCandidate(txn, transition.candidate);
      await txn.insert(
          'mh_indicator_audit_events',
          <String, Object?>{
            'id': transition.auditEvent.id,
            'candidate_id': transition.auditEvent.candidateId,
            'from_stage': transition.auditEvent.fromStage.name,
            'to_stage': transition.auditEvent.toStage.name,
            'actor': transition.auditEvent.actor,
            'created_at_ms': transition.auditEvent.createdAtMs,
            'payload_json': jsonEncode(transition.auditEvent.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.abort);
    });
  }

  Future<List<CheckupIndicatorAuditEvent>> loadIndicatorAudit(
    String candidateId,
  ) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.query(
      'mh_indicator_audit_events',
      where: 'candidate_id = ?',
      whereArgs: <Object?>[candidateId],
      orderBy: 'created_at_ms ASC',
    );
    return rows
        .map(
          (row) => CheckupIndicatorAuditEvent.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CheckupCourseEvidence>> searchCourseEvidence(
    String query, {
    int? lecture,
    int limit = 30,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final trimmed = query.trim();
    if (trimmed.isEmpty && lecture == null)
      return const <CheckupCourseEvidence>[];
    final boundedLimit = limit.clamp(1, 50).toInt();
    List<Map<String, Object?>> rows = const <Map<String, Object?>>[];

    if (trimmed.isNotEmpty) {
      final lectureClause = lecture == null ? '' : 'AND c.lecture_no = ?';
      final pattern = '%$trimmed%';
      final args = <Object?>[pattern, pattern, pattern, pattern];
      if (lecture != null) args.add(lecture);
      args.add(boundedLimit);
      rows = await db.rawQuery('''
        SELECT DISTINCT c.*
        FROM mh_indicator_evidence e
        JOIN mh_indicators i ON i.indicator_id = e.indicator_id
        JOIN mh_course_locations c ON c.location_id = e.location_id
        WHERE (
          i.indicator_id LIKE ? OR i.name LIKE ? OR
          e.location_id LIKE ? OR e.excerpt LIKE ?
        ) $lectureClause
        ORDER BY c.lecture_no, c.lecture_position
        LIMIT ?
        ''', args);
    }

    final asciiTokens = trimmed
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), ' ')
        .split(' ')
        .where((token) => token.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final ftsEnabled = await _meta(db, 'fts_enabled') == '1';
    if (rows.isEmpty &&
        trimmed.isNotEmpty &&
        asciiTokens.isNotEmpty &&
        ftsEnabled) {
      final whereLecture = lecture == null ? '' : 'AND c.lecture_no = ?';
      final args = <Object?>[asciiTokens.join(' AND ')];
      if (lecture != null) args.add(lecture);
      args.add(boundedLimit);
      try {
        rows = await db.rawQuery('''
          SELECT c.*
          FROM mh_course_locations_fts f
          JOIN mh_course_locations c ON c.location_id = f.location_id
          WHERE f.content MATCH ? $whereLecture
          ORDER BY c.lecture_no, c.lecture_position
          LIMIT ?
          ''', args);
      } catch (_) {
        rows = const <Map<String, Object?>>[];
      }
    }
    if (rows.isEmpty) {
      final clauses = <String>[];
      final args = <Object?>[];
      if (trimmed.isNotEmpty) {
        clauses.add('(location_id LIKE ? OR content LIKE ? OR section LIKE ?)');
        args.addAll(<Object?>['%$trimmed%', '%$trimmed%', '%$trimmed%']);
      }
      if (lecture != null) {
        clauses.add('lecture_no = ?');
        args.add(lecture);
      }
      rows = await db.query(
        'mh_course_locations',
        where: clauses.join(' AND '),
        whereArgs: args,
        orderBy: 'lecture_no, lecture_position',
        limit: boundedLimit,
      );
    }
    return rows.map(CheckupCourseEvidence.fromDatabase).toList(growable: false);
  }

  Future<CheckupCourseEvidence?> evidenceByLocation(String locationId) async {
    final rows = await searchCourseEvidence(locationId, limit: 1);
    for (final row in rows) {
      if (row.locationId == locationId) return row;
    }
    return null;
  }

  Future<List<CheckupEvidenceTrace>> evidenceTracesForIndicators(
    Iterable<String> indicatorIds, {
    int limit = 48,
  }) async {
    final ids = indicatorIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(40)
        .toList(growable: false);
    if (ids.isEmpty) return const <CheckupEvidenceTrace>[];
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final placeholders = List<String>.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT e.*, c.lecture_no, c.page_no, c.section,
             c.content AS course_text
      FROM mh_indicator_evidence e
      JOIN mh_course_locations c ON c.location_id = e.location_id
      WHERE e.indicator_id IN ($placeholders)
      ORDER BY e.indicator_id, e.evidence_role,
               COALESCE(e.confidence, 0) DESC, c.lecture_position
      LIMIT ?
      ''',
      <Object?>[...ids, limit.clamp(1, 120).toInt()],
    );
    final traces =
        rows.map(CheckupEvidenceTrace.fromDatabase).toList(growable: true);
    final foundIds = traces.map((trace) => trace.indicatorId).toSet();
    final missingIds = ids.where((id) => !foundIds.contains(id)).toSet();
    if (missingIds.isNotEmpty) {
      final candidateRows = await db.query(
        'mh_indicator_candidates',
        where: 'proposed_indicator_id IN '
            '(${List<String>.filled(missingIds.length, '?').join(',')})',
        whereArgs: missingIds.toList(growable: false),
        orderBy: 'version DESC, updated_at_ms DESC',
      );
      final seenCandidateIds = <String>{};
      for (final row in candidateRows) {
        final candidate = CheckupIndicatorCandidate.fromJson(
          Map<String, dynamic>.from(
            jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
          ),
        );
        if (!seenCandidateIds.add(candidate.proposedIndicatorId)) continue;
        final roles = <String, String>{
          'DEF': candidate.definitionLocation,
          'LOW': candidate.lowLocation,
          'HIGH': candidate.highLocation,
          'ACT': candidate.actionLocation,
        };
        for (final entry in roles.entries) {
          final locationId = entry.value.trim();
          if (locationId.isEmpty) continue;
          final locations = await db.query(
            'mh_course_locations',
            where: 'location_id = ?',
            whereArgs: <Object?>[locationId],
            limit: 1,
          );
          if (locations.isEmpty) continue;
          final location = locations.first;
          traces.add(
            CheckupEvidenceTrace(
              relationId: 'IND-CAND-${candidate.candidateId}-${entry.key}',
              indicatorId: candidate.proposedIndicatorId,
              evidenceRole: entry.key,
              locationId: locationId,
              sourceLevel: candidate.sourceLevel,
              excerpt: (location['content'] ?? '').toString(),
              confidence: null,
              reviewStatus: candidate.stage.name,
              lecture: (location['lecture_no'] as num?)?.toInt() ?? 0,
              page: (location['page_no'] as num?)?.toInt() ?? 0,
              section: (location['section'] ?? '').toString(),
              courseText: (location['content'] ?? '').toString(),
            ),
          );
        }
      }
    }
    return traces.take(limit.clamp(1, 120).toInt()).toList(growable: false);
  }

  Future<List<CheckupEvidenceTrace>> evidenceTracesForLecture(
    int lecture, {
    int limit = 80,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.rawQuery(
      '''
      SELECT c.location_id, c.lecture_no, c.page_no, c.section,
             c.content AS course_text
      FROM mh_course_locations c
      WHERE c.lecture_no = ?
      ORDER BY c.lecture_position, c.location_id
      LIMIT ?
      ''',
      <Object?>[lecture.clamp(1, 23).toInt(), limit.clamp(1, 160).toInt()],
    );
    return rows
        .map(
          (row) => CheckupEvidenceTrace(
            relationId: 'COURSE-${(row['location_id'] ?? '').toString()}',
            indicatorId: '',
            evidenceRole: 'COURSE',
            locationId: (row['location_id'] ?? '').toString(),
            sourceLevel: '课程原文',
            excerpt: (row['course_text'] ?? '').toString(),
            confidence: null,
            reviewStatus: '待候选指标审核',
            lecture: (row['lecture_no'] as num?)?.toInt() ?? 0,
            page: (row['page_no'] as num?)?.toInt() ?? 0,
            section: (row['section'] ?? '').toString(),
            courseText: (row['course_text'] ?? '').toString(),
          ),
        )
        .toList(growable: false);
  }

  Future<CheckupKnowledgeCorpus> buildCourseKnowledgeCorpus({
    required MentalHealthCheckupCatalog catalog,
  }) async {
    final db = await AppDatabase.instance();
    await initialize(catalog);
    final locations = await db.query(
      'mh_course_locations',
      orderBy: 'lecture_no, lecture_position, location_id',
    );
    final relations = await db.query(
      'mh_indicator_evidence',
      orderBy: 'indicator_id, evidence_role, relation_id',
    );
    final governedRows = await db.query(
      'mh_indicator_candidates',
      where: 'stage = ?',
      whereArgs: <Object?>[CheckupCandidateStage.official.name],
      orderBy: 'proposed_indicator_id, version DESC, updated_at_ms DESC',
    );
    final governedRelations = <Map<String, Object?>>[];
    final governedIds = <String>{};
    final catalogIds =
        catalog.indicators.map((indicator) => indicator.id).toSet();
    for (final row in governedRows) {
      final candidate = CheckupIndicatorCandidate.fromJson(
        Map<String, dynamic>.from(
          jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
        ),
      );
      if (!catalogIds.contains(candidate.proposedIndicatorId) ||
          !governedIds.add(candidate.proposedIndicatorId)) {
        continue;
      }
      final locations = <String, String>{
        'DEF': candidate.definitionLocation,
        'LOW': candidate.lowLocation,
        'HIGH': candidate.highLocation,
        'ACT': candidate.actionLocation,
      };
      for (final entry in locations.entries) {
        if (entry.value.trim().isEmpty) continue;
        governedRelations.add(<String, Object?>{
          'relation_id': 'IND-CAND-${candidate.candidateId}-${entry.key}',
          'indicator_id': candidate.proposedIndicatorId,
          'evidence_role': entry.key,
          'location_id': entry.value.trim(),
          'source_level': candidate.sourceLevel,
          'excerpt': '',
          'confidence': null,
          'review_status': '课程专家签发',
        });
      }
    }
    final relationCount = relations.length + governedRelations.length;
    final buffer = StringBuffer();
    buffer.writeln(
      jsonEncode(<String, Object?>{
        'record_type': 'manifest',
        'module': 'mental_health_checkup',
        'course_version': catalog.validation.version,
        'rule_version': MentalHealthCheckupCatalog.ruleVersion,
        'privacy_scope': 'course_knowledge_only',
        'contains_user_health_data': false,
        'indicator_count': catalog.indicators.length,
        'course_location_count': locations.length,
        'evidence_relation_count': relationCount,
      }),
    );
    for (final indicator in catalog.indicators) {
      buffer.writeln(
        jsonEncode(<String, Object?>{
          'record_type': 'indicator',
          'indicator_id': indicator.id,
          'lecture': indicator.lecture,
          'area': indicator.area,
          'name': indicator.name,
          'indicator_type': indicator.type,
          'definition_location': indicator.definitionLocation,
          'low_location': indicator.lowLocation,
          'high_location': indicator.highLocation,
          'action_location': indicator.actionLocation,
          'source_directness': indicator.directness,
          'review_status': indicator.reviewStatus,
        }),
      );
    }
    for (final row in locations) {
      buffer.writeln(
        jsonEncode(<String, Object?>{'record_type': 'course_location', ...row}),
      );
    }
    for (final row in relations) {
      buffer.writeln(
        jsonEncode(<String, Object?>{
          'record_type': 'indicator_evidence',
          ...row,
        }),
      );
    }
    for (final row in governedRelations) {
      buffer.writeln(
        jsonEncode(<String, Object?>{
          'record_type': 'indicator_evidence',
          ...row,
        }),
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final digest = sha256.convert(bytes).toString();
    final safeVersion = catalog.validation.version.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]+'),
      '_',
    );
    return CheckupKnowledgeCorpus(
      courseVersion: catalog.validation.version,
      sourceSha256: digest,
      fileName: 'mental_health_course_$safeVersion.jsonl',
      bytes: bytes,
      courseLocationCount: locations.length,
      evidenceRelationCount: relationCount,
      indicatorCount: catalog.indicators.length,
    );
  }

  Future<List<CheckupProviderKnowledgeResource>>
      loadProviderKnowledgeResources({
    String? provider,
    String? accountFingerprint,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final clauses = <String>[];
    final args = <Object?>[];
    if ((provider ?? '').trim().isNotEmpty) {
      clauses.add('provider = ?');
      args.add(provider!.trim().toLowerCase());
    }
    if ((accountFingerprint ?? '').trim().isNotEmpty) {
      clauses.add('account_fingerprint = ?');
      args.add(accountFingerprint!.trim());
    }
    final rows = await db.query(
      'mh_provider_knowledge_resources',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at_ms DESC',
    );
    return rows
        .map(
          (row) => CheckupProviderKnowledgeResource.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveProviderKnowledgeResource(
    CheckupProviderKnowledgeResource resource,
  ) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      if (resource.enabled) {
        final rows = await txn.query(
          'mh_provider_knowledge_resources',
          columns: <String>['id', 'payload_json'],
          where: 'provider = ? AND account_fingerprint = ? AND enabled = 1 '
              'AND id != ?',
          whereArgs: <Object?>[
            resource.provider,
            resource.accountFingerprint,
            resource.id,
          ],
        );
        for (final row in rows) {
          final previous = CheckupProviderKnowledgeResource.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          );
          await _putProviderKnowledgeResource(
            txn,
            previous.copyWith(
              enabled: false,
              status: previous.status == CheckupKnowledgeResourceStatus.ready
                  ? CheckupKnowledgeResourceStatus.stale
                  : previous.status,
              lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      }
      await _putProviderKnowledgeResource(txn, resource);
    });
  }

  Future<void> detachProviderKnowledgeResource(String id) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.query(
      'mh_provider_knowledge_resources',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final resource = CheckupProviderKnowledgeResource.fromJson(
      Map<String, dynamic>.from(
        jsonDecode((rows.first['payload_json'] ?? '{}').toString()) as Map,
      ),
    );
    await _putProviderKnowledgeResource(
      db,
      resource.copyWith(
        enabled: false,
        status: CheckupKnowledgeResourceStatus.detached,
        lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<CheckupGenerationBatch> createGenerationBatch({
    required String name,
    required bool useAi,
    required Iterable<CheckupContentGenerationPlan> plans,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final batchId = 'content-batch-${clock.microsecondsSinceEpoch}';
    final jobs = CheckupGenerationJob.expandPlans(
      batchId: batchId,
      plans: plans,
      useAi: useAi,
      now: clock,
    );
    final batch = CheckupGenerationBatch(
      id: batchId,
      name: name.trim().isEmpty ? '${useAi ? 'AI' : '本地'}课程内容批次' : name.trim(),
      useAi: useAi,
      status: CheckupGenerationBatchStatus.queued,
      totalJobs: jobs.length,
      completedJobs: 0,
      failedJobs: 0,
      createdAtMs: clock.millisecondsSinceEpoch,
      updatedAtMs: clock.millisecondsSinceEpoch,
    );
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      await _putGenerationBatch(txn, batch);
      for (final job in jobs) {
        await _putGenerationJob(txn, job);
      }
    });
    return batch;
  }

  Future<List<CheckupGenerationBatch>> loadGenerationBatches() async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final rows = await db.query(
      'mh_generation_batches',
      orderBy: 'updated_at_ms DESC',
    );
    return rows
        .map(
          (row) => CheckupGenerationBatch.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CheckupGenerationJob>> loadGenerationJobs(
    String batchId, {
    Set<CheckupGenerationJobStatus>? statuses,
    int? limit,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final clauses = <String>['batch_id = ?'];
    final args = <Object?>[batchId];
    if (statuses != null && statuses.isNotEmpty) {
      clauses.add(
        'status IN (${List<String>.filled(statuses.length, '?').join(',')})',
      );
      args.addAll(statuses.map((status) => status.name));
    }
    final rows = await db.query(
      'mh_generation_jobs',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at_ms, indicator_id, content_code',
      limit: limit?.clamp(1, 500).toInt(),
    );
    return rows
        .map(
          (row) => CheckupGenerationJob.fromJson(
            Map<String, dynamic>.from(
              jsonDecode((row['payload_json'] ?? '{}').toString()) as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveGenerationJob(CheckupGenerationJob job) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await _putGenerationJob(db, job);
    await refreshGenerationBatch(job.batchId);
  }

  Future<CheckupGenerationBatch?> refreshGenerationBatch(
    String batchId, {
    CheckupGenerationBatchStatus? forceStatus,
  }) async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    final batchRows = await db.query(
      'mh_generation_batches',
      where: 'id = ?',
      whereArgs: <Object?>[batchId],
      limit: 1,
    );
    if (batchRows.isEmpty) return null;
    final batch = CheckupGenerationBatch.fromJson(
      Map<String, dynamic>.from(
        jsonDecode((batchRows.first['payload_json'] ?? '{}').toString()) as Map,
      ),
    );
    final jobs = await loadGenerationJobs(batchId);
    final completed = jobs.where((job) => job.terminal).length;
    final failed = jobs
        .where((job) => job.status == CheckupGenerationJobStatus.failed)
        .length;
    final pending = jobs.any(
      (job) =>
          job.status == CheckupGenerationJobStatus.queued ||
          job.status == CheckupGenerationJobStatus.running,
    );
    final status = forceStatus ??
        (!pending && failed == 0
            ? CheckupGenerationBatchStatus.completed
            : batch.status);
    final updated = batch.copyWith(
      status: status,
      totalJobs: jobs.length,
      completedJobs: completed,
      failedJobs: failed,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _putGenerationBatch(db, updated);
    return updated;
  }

  Future<void> setGenerationBatchStatus(
    String batchId,
    CheckupGenerationBatchStatus status,
  ) async {
    final batch = await refreshGenerationBatch(batchId, forceStatus: status);
    if (batch == null) return;
    if (status != CheckupGenerationBatchStatus.cancelled) return;
    final db = await AppDatabase.instance();
    final queued = await loadGenerationJobs(
      batchId,
      statuses: const <CheckupGenerationJobStatus>{
        CheckupGenerationJobStatus.queued,
        CheckupGenerationJobStatus.running,
      },
    );
    await db.transaction((txn) async {
      for (final job in queued) {
        await _putGenerationJob(
          txn,
          job.copyWith(
            status: CheckupGenerationJobStatus.cancelled,
            error: '用户取消',
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    });
    await refreshGenerationBatch(
      batchId,
      forceStatus: CheckupGenerationBatchStatus.cancelled,
    );
  }

  Future<void> retryFailedGenerationJobs(String batchId) async {
    final failed = await loadGenerationJobs(
      batchId,
      statuses: const <CheckupGenerationJobStatus>{
        CheckupGenerationJobStatus.failed,
      },
    );
    final db = await AppDatabase.instance();
    await db.transaction((txn) async {
      for (final job in failed) {
        await _putGenerationJob(
          txn,
          job.copyWith(
            status: CheckupGenerationJobStatus.queued,
            error: '',
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    });
    await refreshGenerationBatch(
      batchId,
      forceStatus: CheckupGenerationBatchStatus.paused,
    );
  }

  Future<bool> exportEncryptedBackup({
    required MentalHealthCheckupCatalog catalog,
    required String password,
  }) async {
    final state = await load(catalog: catalog);
    final payload = MentalHealthBackupEnvelope.create(
      state: state,
      seedVersion: catalog.validation.version,
    );
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return _platform.exportEncryptedBackup(
      payload: payload,
      password: password,
      suggestedName: '心理健康体检备份_$date.ppcheckup',
    );
  }

  Future<MentalHealthCheckupState?> importEncryptedBackup({
    required MentalHealthCheckupCatalog catalog,
    required String password,
  }) async {
    final current = await load(catalog: catalog);
    final raw = await _platform.importEncryptedBackup(password: password);
    if (raw == null) return null;
    final imported = MentalHealthBackupEnvelope.validateAndDecode(
      raw: raw,
      expectedSeedVersion: catalog.validation.version,
      currentInstallId: current.installId,
    );
    await save(imported);
    return imported;
  }

  Future<bool> exportReportPdf(CheckupReport report) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      report.createdAtMs,
    ).toIso8601String().substring(0, 10);
    return _platform.exportReportPdf(
      suggestedName: '心理健康体检报告_$date.pdf',
      title: '心理健康体检 · 课程型报告',
      lines: _reportLines(report),
    );
  }

  Future<void> syncPlatformSettings(MentalHealthCheckupState state) async {
    final settings = state.settings;
    CheckupPrescriptionPlan? reminderPlan;
    for (final plan in state.plans) {
      if (plan.status == CheckupPlanStatus.active ||
          plan.status == CheckupPlanStatus.maintenance) {
        reminderPlan = plan;
        break;
      }
    }
    await _platform.setSecureScreen(
      settings.secureScreen || settings.appLockEnabled,
    );
    await _platform.scheduleReminders(
      enabled: settings.remindersEnabled && reminderPlan != null,
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
      lockScreenPrivacy: settings.lockScreenPrivacy,
      nextRetestAtMs: reminderPlan?.nextRetestAtMs,
    );
  }

  Future<void> setSecureScreenEnabled(bool enabled) =>
      _platform.setSecureScreen(enabled);

  Future<bool> canAuthenticateAppLock() => _platform.canAuthenticateAppLock();

  Future<bool> authenticateAppLock() => _platform.authenticateAppLock();

  Future<void> clearAllModuleData() async {
    final db = await AppDatabase.instance();
    await _ensureSchema(db);
    await db.transaction((txn) async {
      for (final table in const <String>[
        'mh_indicator_audit_events',
        'mh_indicator_candidates',
        'mh_content_audit_events',
        'mh_content_candidates',
        'mh_generation_jobs',
        'mh_generation_batches',
        'mh_provider_knowledge_resources',
        'mh_answers',
        'mh_sessions',
        'mh_execution_logs',
        'mh_retests',
        'mh_plans',
        'mh_drafts',
        'mh_profile',
        'mh_indicator_evidence',
        'mh_indicators',
        'mh_course_locations',
      ]) {
        await txn.delete(table);
      }
      if (await _meta(txn, 'fts_enabled') == '1') {
        await txn.delete('mh_course_locations_fts');
      }
      await txn.delete(
        'mh_meta',
        where: 'key != ?',
        whereArgs: <Object?>['schema_version'],
      );
      await txn.delete(
        'notify_config',
        where: 'key = ? OR key = ? OR key LIKE ?',
        whereArgs: <Object?>[
          _legacyStateKey,
          _legacyDraftKey,
          '$_promptPrefix%',
        ],
      );
    });
    await _platform.clearSecurityAndReminders();
    _initializing = null;
  }

  MentalHealthCheckupState _ensureInstallId(MentalHealthCheckupState state) {
    if (state.installId.trim().isNotEmpty) return state;
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final id = 'install_${base64UrlEncode(bytes).replaceAll('=', '')}';
    return state.copyWith(installId: id);
  }

  Future<Map<String, Object?>> _encodeSettings(
    MentalHealthCheckupSettings settings,
  ) async {
    final json = settings.toJson();
    json['emergency_number'] = await _platform.encryptSensitiveText(
      settings.emergencyNumber,
    );
    json['crisis_number'] = await _platform.encryptSensitiveText(
      settings.crisisNumber,
    );
    return json;
  }

  Future<MentalHealthCheckupSettings> _decodeSettings(
    Map<String, dynamic> json,
  ) async {
    try {
      json['emergency_number'] = await _platform.decryptSensitiveText(
        (json['emergency_number'] ?? '').toString(),
      );
      json['crisis_number'] = await _platform.decryptSensitiveText(
        (json['crisis_number'] ?? '').toString(),
      );
    } catch (_) {
      json['emergency_number'] = '';
      json['crisis_number'] = '';
    }
    return MentalHealthCheckupSettings.fromJson(json);
  }

  static List<String> _reportLines(CheckupReport report) {
    final lines = <String>[
      '生成时间：${DateTime.fromMillisecondsSinceEpoch(report.createdAtMs)}',
      '规则版本：${report.ruleVersion}；课程种子版本：${report.seedVersion}',
      '安全状态：${report.safetyStatus.name}',
      '综合分：${report.overallScore.toStringAsFixed(1)}',
      '覆盖度：${report.coverage.toStringAsFixed(1)}%；'
          '数据质量：${report.dataQuality.toStringAsFixed(1)}%',
      '现实功能影响：${report.functionImpact}/4',
    ];
    if (report.knowledgeScore != null) {
      lines.add(
        'K/A/B：${report.knowledgeScore!.toStringAsFixed(1)} / '
        '${report.attitudeScore?.toStringAsFixed(1) ?? '—'} / '
        '${report.behaviorScore?.toStringAsFixed(1) ?? '—'}',
      );
    }
    lines
      ..add('')
      ..add('表层发现')
      ..addAll(report.surfaceFindings.map((item) => '• $item'));
    if (report.diagnoses.isNotEmpty) {
      lines
        ..add('')
        ..add('课程机制候选');
      for (final diagnosis in report.diagnoses) {
        lines
          ..add('${diagnosis.name}（置信度 ${diagnosis.confidence}）')
          ..add('支持：${diagnosis.supportingEvidence.join('；')}')
          ..add('冲突：${diagnosis.conflictingEvidence.join('；')}')
          ..add('替代解释：${diagnosis.alternativeHypotheses.join('；')}');
      }
    }
    if (report.prescriptions.isNotEmpty) {
      final prescription = report.prescriptions.first;
      lines
        ..add('')
        ..add('当前课程行动')
        ..add('${prescription.theme}：${prescription.startingAction}')
        ..add('剂量：${prescription.dose}')
        ..add('停止规则：${prescription.stopRule}');
    }
    lines
      ..add('')
      ..add('课程证据')
      ..addAll(report.courseEvidence.map((item) => '• $item'))
      ..add('')
      ..add('边界声明')
      ..addAll(report.sourceBoundaries.map((item) => '• $item'));
    return lines;
  }

  static Future<Uint8List> _loadSeedBytes(String file) async {
    try {
      final data = await rootBundle.load(
        '${MentalHealthCheckupCatalog.assetRoot}/$file',
      );
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      final data = await rootBundle.load(
        '${MentalHealthCheckupCatalog.assetRoot}/$file.gz',
      );
      final compressed = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return Uint8List.fromList(gzip.decode(compressed));
    }
  }

  static Future<String?> _meta(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'mh_meta',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.first['value'] ?? '').toString();
  }

  static Future<void> _putMeta(
    DatabaseExecutor db,
    String key,
    String value,
  ) async {
    await db.insert(
        'mh_meta',
        <String, Object?>{
          'key': key,
          'value': value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _putContentCandidate(
    DatabaseExecutor db,
    CheckupContentCandidate candidate,
  ) async {
    await db.insert(
        'mh_content_candidates',
        <String, Object?>{
          'id': candidate.candidateId,
          'indicator_id': candidate.primaryIndicatorId,
          'content_kind': candidate.kind.name,
          'content_code': candidate.contentCode,
          'stage': candidate.stage.name,
          'version': candidate.version,
          'updated_at_ms': candidate.updatedAtMs,
          'payload_json': jsonEncode(candidate.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _putIndicatorCandidate(
    DatabaseExecutor db,
    CheckupIndicatorCandidate candidate,
  ) async {
    await db.insert(
        'mh_indicator_candidates',
        <String, Object?>{
          'id': candidate.candidateId,
          'proposed_indicator_id': candidate.proposedIndicatorId,
          'lecture_no': candidate.lecture,
          'stage': candidate.stage.name,
          'version': candidate.version,
          'updated_at_ms': candidate.updatedAtMs,
          'payload_json': jsonEncode(candidate.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _putProviderKnowledgeResource(
    DatabaseExecutor db,
    CheckupProviderKnowledgeResource resource,
  ) async {
    await db.insert(
      'mh_provider_knowledge_resources',
      <String, Object?>{
        'id': resource.id,
        'provider': resource.provider,
        'account_fingerprint': resource.accountFingerprint,
        'course_version': resource.courseVersion,
        'source_sha256': resource.sourceSha256,
        'status': resource.status.name,
        'enabled': resource.enabled ? 1 : 0,
        'updated_at_ms': resource.lastVerifiedAtMs,
        'payload_json': jsonEncode(resource.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _putGenerationBatch(
    DatabaseExecutor db,
    CheckupGenerationBatch batch,
  ) async {
    await db.insert(
        'mh_generation_batches',
        <String, Object?>{
          'id': batch.id,
          'status': batch.status.name,
          'created_at_ms': batch.createdAtMs,
          'updated_at_ms': batch.updatedAtMs,
          'payload_json': jsonEncode(batch.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> _putGenerationJob(
    DatabaseExecutor db,
    CheckupGenerationJob job,
  ) async {
    await db.insert(
        'mh_generation_jobs',
        <String, Object?>{
          'id': job.id,
          'batch_id': job.batchId,
          'indicator_id': job.indicatorId,
          'content_code': job.contentCode,
          'status': job.status.name,
          'created_at_ms': job.createdAtMs,
          'updated_at_ms': job.updatedAtMs,
          'payload_json': jsonEncode(job.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
