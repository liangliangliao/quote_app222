import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'will_mirror_models.dart';

class WillMirrorKnowledgeManifest {
  const WillMirrorKnowledgeManifest({
    required this.kbVersion,
    required this.schemaVersion,
    required this.translationRevision,
    required this.recordCount,
    required this.recordsSha256,
    required this.retrievalMode,
    required this.releaseBoundaries,
  });

  final String kbVersion;
  final String schemaVersion;
  final String translationRevision;
  final int recordCount;
  final String recordsSha256;
  final String retrievalMode;
  final List<String> releaseBoundaries;

  factory WillMirrorKnowledgeManifest.fromJson(Map<String, dynamic> json) {
    final boundaries = json['release_boundaries'];
    return WillMirrorKnowledgeManifest(
      kbVersion: (json['kb_version'] ?? '').toString(),
      schemaVersion: (json['schema_version'] ?? '').toString(),
      translationRevision: (json['translation_revision'] ?? '').toString(),
      recordCount: int.tryParse((json['record_count'] ?? 0).toString()) ?? 0,
      recordsSha256: (json['records_sha256'] ?? '').toString(),
      retrievalMode: (json['retrieval_mode'] ?? '').toString(),
      releaseBoundaries: boundaries is List
          ? boundaries.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
    );
  }
}

class WillMirrorKnowledgeValidation {
  const WillMirrorKnowledgeValidation({
    required this.valid,
    required this.issues,
    required this.integrityCheck,
  });

  final bool valid;
  final List<String> issues;
  final String integrityCheck;
}

/// App-bundled, versioned Evidence KB.
///
/// JSONL remains the canonical interchange format. On first use it is verified
/// against the manifest and compiled into a physically separate, read-only
/// SQLite database. Runtime retrieval is deliberately hybrid but transparent:
/// lexical text, tags, authority, fidelity and module fit. No vector model is
/// claimed in this release.
class WillMirrorKnowledgeRepository {
  WillMirrorKnowledgeRepository({
    DatabaseFactory? factory,
    Future<String> Function()? baseDirectoryProvider,
    Future<String> Function(String key)? assetLoader,
  })  : _factoryOverride = factory,
        _baseDirectoryProvider = baseDirectoryProvider,
        _assetLoader = assetLoader;

  static const String recordsAsset =
      'assets/will_mirror/kb_records_v4.jsonl';
  static const String manifestAsset =
      'assets/will_mirror/manifest_v4.json';
  static const String databaseName = 'will_mirror_kb.sqlite';

  final DatabaseFactory? _factoryOverride;
  final Future<String> Function()? _baseDirectoryProvider;
  final Future<String> Function(String key)? _assetLoader;
  List<WillMirrorKnowledgePassage>? _records;
  WillMirrorKnowledgeManifest? _manifest;
  Database? _readOnlyDatabase;
  Future<void>? _initializing;
  String? _databasePath;

  DatabaseFactory get _factory => _factoryOverride ?? databaseFactory;

  Future<String> _loadAsset(String key) {
    return _assetLoader == null ? rootBundle.loadString(key) : _assetLoader!(key);
  }

  Future<void> initialize() async {
    if (_records != null && _manifest != null) return;
    if (_initializing != null) return _initializing!;
    _initializing = _initializeInternal();
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    final rawRecords = await _loadAsset(recordsAsset);
    final manifestJson = jsonDecode(await _loadAsset(manifestAsset));
    if (manifestJson is! Map) {
      throw const FormatException('意志之镜 KB manifest 不是 JSON 对象。');
    }
    final manifest = WillMirrorKnowledgeManifest.fromJson(
      manifestJson.map((key, value) => MapEntry(key.toString(), value)),
    );
    final digest = sha256.convert(utf8.encode(rawRecords)).toString();
    if (digest != manifest.recordsSha256) {
      throw StateError('意志之镜 KB 完整性校验失败，已拒绝加载。');
    }
    final records = parseJsonLines(rawRecords);
    final issues = validateRecords(records);
    if (records.length != manifest.recordCount) {
      issues.add(
        'manifest record_count=${manifest.recordCount}，实际=${records.length}',
      );
    }
    if (issues.isNotEmpty) {
      throw StateError('意志之镜 KB 结构校验失败：${issues.join('；')}');
    }
    _manifest = manifest;
    _records = records;
    await _ensureCompiledDatabase(records, manifest, digest);
  }

  static List<WillMirrorKnowledgePassage> parseJsonLines(String text) {
    final records = <WillMirrorKnowledgePassage>[];
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final decoded = jsonDecode(line);
      if (decoded is! Map) throw const FormatException('KB JSONL 行不是对象。');
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      if ((map['content_sha256'] ?? '').toString().isEmpty) {
        final digestSource = <String>[
          (map['record_id'] ?? '').toString(),
          (map['source_id'] ?? '').toString(),
          (map['locator_text'] ?? '').toString(),
          (map['original_text'] ?? '').toString(),
          (map['zh_translation'] ?? '').toString(),
          (map['product_rule'] ?? '').toString(),
          (map['misuse_boundary'] ?? '').toString(),
        ].join('\u001f');
        map['content_sha256'] =
            sha256.convert(utf8.encode(digestSource)).toString();
      }
      records.add(WillMirrorKnowledgePassage.fromJson(map));
    }
    return records;
  }

  static List<String> validateRecords(
    List<WillMirrorKnowledgePassage> records,
  ) {
    final issues = <String>[];
    final ids = <String>{};
    for (final item in records) {
      if (item.recordId.isEmpty || !ids.add(item.recordId)) {
        issues.add('record_id 缺失或重复：${item.recordId}');
      }
      if (item.sourceId.isEmpty || item.locatorText.isEmpty) {
        issues.add('${item.recordId} 缺少 source/locator');
      }
      if (item.zhTranslation.isEmpty || item.summary.isEmpty) {
        issues.add('${item.recordId} 缺少译文或忠实摘要');
      }
      if (item.misuseBoundary.isEmpty) {
        issues.add('${item.recordId} 缺少 misuse_boundary');
      }
      if (item.evidenceLevel == WillMirrorEvidenceLevel.c &&
          item.productRule.isEmpty) {
        issues.add('${item.recordId} 的 C 级规则缺少 product_rule');
      }
      if (item.contentSha256.length != 64) {
        issues.add('${item.recordId} 的 content_sha256 无效');
      }
    }
    return issues;
  }

  Future<String> _resolveDatabasePath() async {
    if (_databasePath != null) return _databasePath!;
    final directory = _baseDirectoryProvider == null
        ? (await getApplicationDocumentsDirectory()).path
        : await _baseDirectoryProvider!();
    _databasePath = p.join(directory, databaseName);
    return _databasePath!;
  }

  Future<void> _ensureCompiledDatabase(
    List<WillMirrorKnowledgePassage> records,
    WillMirrorKnowledgeManifest manifest,
    String recordsDigest,
  ) async {
    final path = await _resolveDatabasePath();
    if (await File(path).exists()) {
      try {
        final existing = await _factory.openDatabase(
          path,
          options: OpenDatabaseOptions(readOnly: true),
        );
        final meta = await existing.query('kb_meta');
        final values = <String, String>{
          for (final row in meta)
            row['meta_key'].toString(): row['meta_value'].toString(),
        };
        final integrity = await existing.rawQuery('PRAGMA integrity_check');
        final ok = integrity.isNotEmpty &&
            integrity.first.values.first.toString().toLowerCase() == 'ok';
        if (ok &&
            values['kb_version'] == manifest.kbVersion &&
            values['records_sha256'] == recordsDigest) {
          _readOnlyDatabase = existing;
          return;
        }
        await existing.close();
      } catch (_) {
        // A partial or old build is replaced atomically below.
      }
    }

    final tempPath = '$path.tmp';
    await _factory.deleteDatabase(tempPath);
    final writable = await _factory.openDatabase(
      tempPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => _createSchema(db),
      ),
    );
    try {
      await writable.transaction((txn) async {
        await txn.insert('kb_meta', <String, Object?>{
          'meta_key': 'kb_version',
          'meta_value': manifest.kbVersion,
        });
        await txn.insert('kb_meta', <String, Object?>{
          'meta_key': 'schema_version',
          'meta_value': manifest.schemaVersion,
        });
        await txn.insert('kb_meta', <String, Object?>{
          'meta_key': 'records_sha256',
          'meta_value': recordsDigest,
        });
        final sourceIds = <String>{};
        for (final item in records) {
          if (sourceIds.add(item.sourceId)) {
            await txn.insert('kb_source', <String, Object?>{
              'source_id': item.sourceId,
              'creator': item.creator,
              'work_title': item.workTitle,
              'canonical_url': item.canonicalUrl,
              'rights_status': item.rightsStatus,
            });
          }
          await txn.insert('kb_passage', <String, Object?>{
            'passage_id': item.recordId,
            'source_id': item.sourceId,
            'work_part': item.workPart,
            'section_ref': item.sectionRef,
            'locator_text': item.locatorText,
            'original_text': item.originalText,
            'zh_translation': item.zhTranslation,
            'translation_status': item.translationStatus,
            'evidence_level': item.evidenceLevel.value,
            'source_fidelity': item.sourceFidelity,
            'summary': item.summary,
            'methodological_implication': item.methodologicalImplication,
            'product_rule': item.productRule,
            'misuse_boundary': item.misuseBoundary,
            'content_sha256': item.contentSha256,
          });
          for (final tag in item.tags) {
            await txn.insert('kb_passage_tag', <String, Object?>{
              'passage_id': item.recordId,
              'tag': tag,
            });
          }
          for (final module in item.modules) {
            await txn.insert('kb_passage_module', <String, Object?>{
              'passage_id': item.recordId,
              'module': module,
            });
          }
          for (final code in item.hypothesisCodes) {
            for (final relation in item.relations) {
              await txn.insert('kb_hypothesis_link', <String, Object?>{
                'passage_id': item.recordId,
                'hypothesis_code': code,
                'relation_type': relation.value,
              });
            }
          }
          try {
            await txn.insert('kb_passage_fts', <String, Object?>{
              'passage_id': item.recordId,
              'original_text': item.originalText,
              'zh_translation': item.zhTranslation,
              'summary': item.summary,
              'tags': item.tags.join(' '),
            });
          } catch (_) {
            // Some Android SQLite builds omit FTS5. In-memory hybrid retrieval
            // remains available and the manifest reports its exact mode.
          }
        }
      });
      final integrity = await writable.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty ||
          integrity.first.values.first.toString().toLowerCase() != 'ok') {
        throw StateError('编译后的意志之镜 KB integrity_check 未通过。');
      }
    } finally {
      await writable.close();
    }

    final target = File(path);
    if (await target.exists()) await target.delete();
    await File(tempPath).rename(path);
    _readOnlyDatabase = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE kb_meta (
        meta_key TEXT PRIMARY KEY,
        meta_value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_source (
        source_id TEXT PRIMARY KEY,
        creator TEXT NOT NULL,
        work_title TEXT NOT NULL,
        canonical_url TEXT NOT NULL,
        rights_status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_passage (
        passage_id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        work_part TEXT NOT NULL,
        section_ref TEXT NOT NULL,
        locator_text TEXT NOT NULL,
        original_text TEXT NOT NULL,
        zh_translation TEXT NOT NULL,
        translation_status TEXT NOT NULL,
        evidence_level TEXT NOT NULL,
        source_fidelity REAL NOT NULL,
        summary TEXT NOT NULL,
        methodological_implication TEXT NOT NULL,
        product_rule TEXT NOT NULL,
        misuse_boundary TEXT NOT NULL,
        content_sha256 TEXT NOT NULL,
        FOREIGN KEY(source_id) REFERENCES kb_source(source_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_passage_tag (
        passage_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY(passage_id, tag),
        FOREIGN KEY(passage_id) REFERENCES kb_passage(passage_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_passage_module (
        passage_id TEXT NOT NULL,
        module TEXT NOT NULL,
        PRIMARY KEY(passage_id, module),
        FOREIGN KEY(passage_id) REFERENCES kb_passage(passage_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_hypothesis_link (
        passage_id TEXT NOT NULL,
        hypothesis_code TEXT NOT NULL,
        relation_type TEXT NOT NULL,
        PRIMARY KEY(passage_id, hypothesis_code, relation_type),
        FOREIGN KEY(passage_id) REFERENCES kb_passage(passage_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE kb_embedding (
        passage_id TEXT PRIMARY KEY,
        model_id TEXT,
        dimensions INTEGER,
        vector_f32 BLOB,
        FOREIGN KEY(passage_id) REFERENCES kb_passage(passage_id)
      )
    ''');
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE kb_passage_fts USING fts5(
          passage_id UNINDEXED,
          original_text,
          zh_translation,
          summary,
          tags
        )
      ''');
    } catch (_) {
      // See insertion fallback above.
    }
  }

  Future<WillMirrorKnowledgeManifest> manifest() async {
    await initialize();
    return _manifest!;
  }

  Future<List<WillMirrorKnowledgePassage>> allPassages() async {
    await initialize();
    return List<WillMirrorKnowledgePassage>.unmodifiable(_records!);
  }

  Future<WillMirrorKnowledgePassage?> passageById(String id) async {
    await initialize();
    for (final item in _records!) {
      if (item.recordId == id) return item;
    }
    return null;
  }

  Future<List<WillMirrorKnowledgePassage>> search(
    String query, {
    Set<WillMirrorRelation>? relations,
    Set<String>? modules,
    Set<WillMirrorEvidenceLevel>? levels,
    int limit = 8,
  }) async {
    await initialize();
    final normalizedQuery = _normalize(query);
    final queryTokens = _tokens(query);
    final scored = <(double, WillMirrorKnowledgePassage)>[];
    for (final item in _records!) {
      if (relations != null &&
          !item.relations.any((relation) => relations.contains(relation))) {
        continue;
      }
      if (modules != null &&
          !item.modules.any((module) => modules.contains(module))) {
        continue;
      }
      if (levels != null && !levels.contains(item.evidenceLevel)) continue;

      final body = _normalize(<String>[
        item.creator,
        item.workTitle,
        item.workPart,
        item.sectionRef,
        item.locatorText,
        item.originalText,
        item.zhTranslation,
        item.summary,
        item.methodologicalImplication,
        item.productRule,
        item.misuseBoundary,
      ].join(' '));
      final normalizedTags = _normalize(item.tags.join(' '));
      final normalizedModules = _normalize(item.modules.join(' '));
      final tokenHits = queryTokens.where(body.contains).length;
      final tagHits = queryTokens.where(normalizedTags.contains).length;
      final moduleHits = queryTokens.where(normalizedModules.contains).length;
      final exact = normalizedQuery.isNotEmpty && body.contains(normalizedQuery);
      final lexical = queryTokens.isEmpty
          ? 0.1
          : (tokenHits / queryTokens.length).clamp(0.0, 1.0).toDouble();
      final tag = queryTokens.isEmpty
          ? 0.0
          : (tagHits / queryTokens.length).clamp(0.0, 1.0).toDouble();
      final module = queryTokens.isEmpty
          ? 0.0
          : (moduleHits / queryTokens.length).clamp(0.0, 1.0).toDouble();
      final authority = switch (item.evidenceLevel) {
        WillMirrorEvidenceLevel.a => 1.0,
        WillMirrorEvidenceLevel.aCandidate => 0.62,
        WillMirrorEvidenceLevel.b => 0.82,
        WillMirrorEvidenceLevel.c => 0.68,
      };
      final score = (exact ? 0.2 : 0.0) +
          0.45 * lexical +
          0.2 * tag +
          0.15 * authority +
          0.1 * item.sourceFidelity +
          0.1 * module;
      if (score > 0.12) scored.add((score, item));
    }
    scored.sort((a, b) {
      final scoreOrder = b.$1.compareTo(a.$1);
      return scoreOrder != 0
          ? scoreOrder
          : a.$2.recordId.compareTo(b.$2.recordId);
    });
    return scored.take(limit).map((item) => item.$2).toList(growable: false);
  }

  Future<WillMirrorRetrievalBundle> retrieveForHypothesis(
    String hypothesis,
  ) async {
    final support = await search(
      '$hypothesis 行动 跨人生 自我一致',
      relations: <WillMirrorRelation>{WillMirrorRelation.supports},
      limit: 6,
    );
    final counter = await search(
      '$hypothesis 反证 限制 误用 社会 反对 条件',
      relations: <WillMirrorRelation>{
        WillMirrorRelation.limits,
        WillMirrorRelation.contradicts,
      },
      limit: 6,
    );
    final boundary = await search(
      '$hypothesis 边界 不能 证据不足 物自身 描述 规范',
      modules: <String>{'guardrail', 'boundary_detector', 'will_pattern'},
      limit: 6,
    );
    return WillMirrorRetrievalBundle(
      support: support,
      counter: counter,
      boundary: boundary,
    );
  }

  Future<WillMirrorKnowledgeValidation> validateCompiledDatabase() async {
    await initialize();
    final issues = validateRecords(_records!);
    var integrity = 'unavailable';
    final database = _readOnlyDatabase;
    if (database != null) {
      final rows = await database.rawQuery('PRAGMA integrity_check');
      integrity = rows.isEmpty ? 'empty' : rows.first.values.first.toString();
      if (integrity.toLowerCase() != 'ok') issues.add('SQLite: $integrity');
    }
    return WillMirrorKnowledgeValidation(
      valid: issues.isEmpty && integrity.toLowerCase() == 'ok',
      issues: issues,
      integrityCheck: integrity,
    );
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u3400-\u9fff]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> _tokens(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return <String>{};
    final tokens = <String>{};
    for (final part in normalized.split(' ')) {
      if (part.isEmpty) continue;
      tokens.add(part);
      if (RegExp(r'[\u3400-\u9fff]').hasMatch(part) && part.length > 2) {
        for (var i = 0; i < part.length - 1; i++) {
          tokens.add(part.substring(i, i + 2));
        }
      }
    }
    return tokens;
  }

  Future<void> close() async {
    final db = _readOnlyDatabase;
    _readOnlyDatabase = null;
    if (db != null) await db.close();
  }
}
