import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'zhixing_models.dart';

class ZxKnowledgePackageInfo {
  final String packageId;
  final String version;
  final String ruleVersion;
  final String publishedAt;
  final int sourceCount;
  final String reviewStatus;
  final int systemCount;
  final int evidenceCount;
  final String expectedSha256;
  final String actualSha256;
  final String expectedCatalogSha256;
  final String actualCatalogSha256;
  final bool contentIntegrityValid;
  final bool catalogIntegrityValid;
  final bool integrityValid;

  const ZxKnowledgePackageInfo({
    required this.packageId,
    required this.version,
    required this.ruleVersion,
    required this.publishedAt,
    required this.sourceCount,
    required this.reviewStatus,
    required this.systemCount,
    required this.evidenceCount,
    required this.expectedSha256,
    required this.actualSha256,
    required this.expectedCatalogSha256,
    required this.actualCatalogSha256,
    required this.contentIntegrityValid,
    required this.catalogIntegrityValid,
    required this.integrityValid,
  });
}

class ZxKnowledgeRepository {
  static const String manifestAsset =
      'assets/zhixing_tree/knowledge_manifest_v2_0.json';
  static const String contentAsset =
      'assets/zhixing_tree/knowledge_v2_0.md';
  static const String catalogAsset =
      'assets/zhixing_tree/knowledge_systems_v2_0.json';

  ZxKnowledgePackageInfo? _packageInfo;
  List<ZxWork> _works = const <ZxWork>[];
  List<ZxThinkerLens> _lenses = const <ZxThinkerLens>[];
  List<ZxEvidenceItem> _evidence = const <ZxEvidenceItem>[];
  String _rawKnowledge = '';

  bool get isLoaded => _packageInfo != null;
  ZxKnowledgePackageInfo get packageInfo {
    final value = _packageInfo;
    if (value == null) {
      throw StateError('Knowledge package has not been loaded.');
    }
    return value;
  }

  List<ZxWork> get works => List<ZxWork>.unmodifiable(_works);
  List<ZxThinkerLens> get lenses =>
      List<ZxThinkerLens>.unmodifiable(_lenses);
  List<ZxEvidenceItem> get evidence =>
      List<ZxEvidenceItem>.unmodifiable(_evidence);
  String get rawKnowledge => _rawKnowledge;

  Future<void> load() async {
    if (isLoaded) return;
    final manifestRaw = await rootBundle.loadString(manifestAsset);
    final knowledgeRaw = await rootBundle.loadString(contentAsset);
    final catalogRaw = await rootBundle.loadString(catalogAsset);
    final decoded = jsonDecode(manifestRaw);
    if (decoded is! Map) {
      throw const FormatException('Invalid knowledge manifest root.');
    }
    final root = Map<String, dynamic>.from(decoded);
    final manifest = Map<String, dynamic>.from(
      root['manifest'] as Map? ?? const <String, dynamic>{},
    );
    final expectedHash = (manifest['content_sha256'] ?? '').toString();
    final actualHash = sha256.convert(utf8.encode(knowledgeRaw)).toString();
    final expectedCatalogHash =
        (manifest['catalog_sha256'] ?? '').toString();
    final actualCatalogHash =
        sha256.convert(utf8.encode(catalogRaw)).toString();
    final contentIntegrityValid =
        expectedHash.isNotEmpty && expectedHash == actualHash;
    final catalogIntegrityValid = expectedCatalogHash.isNotEmpty &&
        expectedCatalogHash == actualCatalogHash;

    _works = _mapList(root['works']).map(ZxWork.fromJson).toList(growable: false);
    _lenses =
        _mapList(root['lenses']).map(ZxThinkerLens.fromJson).toList(growable: false);
    _rawKnowledge = knowledgeRaw;
    _evidence = _parseEvidence(knowledgeRaw);
    _packageInfo = ZxKnowledgePackageInfo(
      packageId: (manifest['package_id'] ?? '').toString(),
      version: (manifest['version'] ?? '').toString(),
      ruleVersion: (manifest['rule_version'] ?? '').toString(),
      publishedAt: (manifest['published_at'] ?? '').toString(),
      sourceCount: _asInt(manifest['source_count']),
      reviewStatus: (manifest['review_status'] ?? '').toString(),
      systemCount: _asInt(manifest['system_count']),
      evidenceCount: _asInt(manifest['evidence_count']),
      expectedSha256: expectedHash,
      actualSha256: actualHash,
      expectedCatalogSha256: expectedCatalogHash,
      actualCatalogSha256: actualCatalogHash,
      contentIntegrityValid: contentIntegrityValid,
      catalogIntegrityValid: catalogIntegrityValid,
      integrityValid: contentIntegrityValid && catalogIntegrityValid,
    );
    _validatePackage();
  }

  void _validatePackage() {
    final info = packageInfo;
    if (!info.integrityValid) {
      throw StateError('Knowledge package integrity validation failed.');
    }
    if (_works.length != info.sourceCount) {
      throw StateError(
        'Knowledge source count mismatch: ${_works.length}/${info.sourceCount}.',
      );
    }
    if (info.systemCount != 17) {
      throw StateError(
        'Knowledge system count mismatch: ${info.systemCount}/17.',
      );
    }
    if (_evidence.length != info.evidenceCount) {
      throw StateError(
        'Knowledge evidence count mismatch: '
        '${_evidence.length}/${info.evidenceCount}.',
      );
    }
    final sourceIds = _works.map((item) => item.sourceId).toSet();
    final lensIds = <String>{};
    for (final lens in _lenses) {
      if (!sourceIds.contains(lens.sourceId)) {
        throw StateError(
          'Lens ${lens.id} references missing source ${lens.sourceId}.',
        );
      }
      if (!lensIds.add(lens.id)) {
        throw StateError('Duplicate lens id: ${lens.id}.');
      }
      for (final locator in lens.evidenceLinks) {
        if (!_rawKnowledge.contains(locator)) {
          throw StateError(
            'Lens ${lens.id} references missing locator $locator.',
          );
        }
      }
    }
  }

  ZxThinkerLens? lensById(String id) {
    for (final item in _lenses) {
      if (item.id == id) return item;
    }
    return null;
  }

  ZxWork? workBySourceId(String sourceId) {
    for (final item in _works) {
      if (item.sourceId == sourceId) return item;
    }
    return null;
  }

  ZxEvidenceItem? evidenceByLocator(String locator) {
    final normalized = _normalizeLocator(locator);
    for (final item in _evidence) {
      if (_normalizeLocator(item.locator) == normalized) return item;
    }
    return null;
  }

  bool locatorExists(String locator) =>
      locator.trim().isNotEmpty && _rawKnowledge.contains(locator.trim());

  List<ZxEvidenceItem> evidenceForLens(ZxThinkerLens lens) {
    final result = <ZxEvidenceItem>[];
    for (final locator in lens.evidenceLinks) {
      final item = evidenceByLocator(locator);
      if (item != null) {
        result.add(item);
      } else if (locatorExists(locator)) {
        result.add(
          ZxEvidenceItem(
            id: 'EV-${_safeId(locator)}',
            sourceId: lens.sourceId,
            locator: locator,
            title: lens.name,
            summary: '定位键存在于V2.0累计知识库，打开全文可查看上下文。',
            use: lens.mechanism,
            boundary: lens.contraindications,
            contentType: 'original_claim',
            tags: <String>[lens.thinker, lens.name],
          ),
        );
      }
    }
    return result;
  }

  List<ZxKnowledgeSearchResult> search(
    String query, {
    String sourceId = '',
    int limit = 30,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final tokens = _queryTokens(normalizedQuery);
    final results = <ZxKnowledgeSearchResult>[];

    for (final lens in _lenses) {
      if (sourceId.isNotEmpty && lens.sourceId != sourceId) continue;
      final score = _score(
        query: normalizedQuery,
        tokens: tokens,
        text: lens.searchableText.toLowerCase(),
        locator: lens.evidenceLinks.join(' ').toLowerCase(),
      );
      if (normalizedQuery.isEmpty || score > 0) {
        results.add(
          ZxKnowledgeSearchResult(
            type: 'lens',
            id: lens.id,
            title: '${lens.thinker} · ${lens.name}',
            subtitle: lens.coreQuestion,
            summary: lens.mechanism,
            locator: lens.evidenceLinks.take(2).join(' · '),
            score: normalizedQuery.isEmpty ? 1 : score + 2,
          ),
        );
      }
    }

    for (final item in _evidence) {
      if (sourceId.isNotEmpty && item.sourceId != sourceId) continue;
      final score = _score(
        query: normalizedQuery,
        tokens: tokens,
        text: item.searchableText.toLowerCase(),
        locator: item.locator.toLowerCase(),
      );
      if (normalizedQuery.isEmpty || score > 0) {
        results.add(
          ZxKnowledgeSearchResult(
            type: 'evidence',
            id: item.id,
            title: item.title.isEmpty ? item.use : item.title,
            subtitle: '${item.sourceId} · ${item.contentType}',
            summary: item.summary,
            locator: item.locator,
            score: normalizedQuery.isEmpty ? 0.6 : score,
          ),
        );
      }
    }

    for (final work in _works) {
      if (sourceId.isNotEmpty && work.sourceId != sourceId) continue;
      final text =
          '${work.sourceId} ${work.title} ${work.author} ${work.evidenceRole} '
          '${work.evidenceTier}'
              .toLowerCase();
      final score = _score(
        query: normalizedQuery,
        tokens: tokens,
        text: text,
        locator: work.sourceId.toLowerCase(),
      );
      if (normalizedQuery.isEmpty || score > 0) {
        results.add(
          ZxKnowledgeSearchResult(
            type: 'work',
            id: work.sourceId,
            title: work.title,
            subtitle: '${work.author} · ${work.evidenceTier}',
            summary: work.evidenceRole,
            locator: work.sourceId,
            score: normalizedQuery.isEmpty ? 0.2 : score,
          ),
        );
      }
    }

    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.title.compareTo(b.title);
    });
    return results.take(limit).toList(growable: false);
  }

  List<Map<String, Object?>> indexRows() {
    final rows = <Map<String, Object?>>[];
    for (final lens in _lenses) {
      rows.add(<String, Object?>{
        'item_id': lens.id,
        'item_type': 'lens',
        'source_id': lens.sourceId,
        'title': '${lens.thinker} · ${lens.name}',
        'content': lens.searchableText,
        'locator': lens.evidenceLinks.join(' '),
        'package_version': packageInfo.version,
      });
    }
    for (final item in _evidence) {
      rows.add(<String, Object?>{
        'item_id': item.id,
        'item_type': 'evidence',
        'source_id': item.sourceId,
        'title': item.title,
        'content': item.searchableText,
        'locator': item.locator,
        'package_version': packageInfo.version,
      });
    }
    return rows;
  }

  List<ZxEvidenceItem> _parseEvidence(String markdown) {
    final items = <ZxEvidenceItem>[];
    final seen = <String>{};
    final detailed = RegExp(
      r'^\|\s*(KB-([A-Z]+)-\d+)\s+\[([^\]]+)\][^|]*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|',
    );
    final simple = RegExp(
      r'^\|\s*([A-Z]{2,4}-[A-Z0-9§—\-]+)\s*\|\s*([^|]+)\|\s*([^|]+)\|',
    );

    for (final rawLine in const LineSplitter().convert(markdown)) {
      final line = rawLine.trim();
      final detailedMatch = detailed.firstMatch(line);
      if (detailedMatch != null) {
        final locator = (detailedMatch.group(3) ?? '').trim();
        if (locator.isEmpty || !seen.add(_normalizeLocator(locator))) continue;
        items.add(
          ZxEvidenceItem(
            id: (detailedMatch.group(1) ?? 'EV-${_safeId(locator)}').trim(),
            sourceId: (detailedMatch.group(2) ?? '').trim(),
            locator: locator,
            title: (detailedMatch.group(4) ?? '').trim(),
            summary: (detailedMatch.group(5) ?? '').trim(),
            use: (detailedMatch.group(6) ?? '').trim(),
            boundary: (detailedMatch.group(7) ?? '').trim(),
            contentType: 'original_claim',
            tags: _evidenceTags(
              '${detailedMatch.group(4)} ${detailedMatch.group(6)}',
            ),
          ),
        );
        continue;
      }

      final simpleMatch = simple.firstMatch(line);
      if (simpleMatch == null) continue;
      final locator = (simpleMatch.group(1) ?? '').trim();
      if (!_looksLikeLocator(locator) ||
          !seen.add(_normalizeLocator(locator))) {
        continue;
      }
      final sourceId = locator.split('-').first;
      final summary = (simpleMatch.group(2) ?? '').trim();
      final use = (simpleMatch.group(3) ?? '').trim();
      items.add(
        ZxEvidenceItem(
          id: 'EV-${_safeId(locator)}',
          sourceId: sourceId,
          locator: locator,
          title: use,
          summary: summary,
          use: use,
          boundary: '适用边界与证据质量请查看该来源的思想镜头和知识库上下文。',
          contentType: 'original_claim',
          tags: _evidenceTags('$summary $use'),
        ),
      );
    }
    return items;
  }

  static bool _looksLikeLocator(String value) {
    if (!value.contains('-')) return false;
    const forbidden = <String>{
      'Source ID',
      'lens_id',
      'goal_id',
      'Work',
      'Concept',
      'COM-B',
    };
    if (forbidden.contains(value)) return false;
    return RegExp(r'^[A-Z]{2,4}-').hasMatch(value);
  }

  static List<String> _evidenceTags(String value) => value
      .split(RegExp(r'[\s、，,；;：:（）()]+'))
      .map((item) => item.trim())
      .where((item) => item.length >= 2)
      .take(10)
      .toList(growable: false);

  static List<String> _queryTokens(String query) {
    if (query.isEmpty) return const <String>[];
    final parts = query
        .split(RegExp(r'[\s、，,；;：:（）()]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (query.runes.length >= 4 && !query.contains(' ')) {
      final chars = query.runes.map(String.fromCharCode).toList(growable: false);
      for (var index = 0; index < chars.length - 1; index++) {
        parts.add('${chars[index]}${chars[index + 1]}');
      }
    }
    return parts.toList(growable: false);
  }

  static double _score({
    required String query,
    required List<String> tokens,
    required String text,
    required String locator,
  }) {
    if (query.isEmpty) return 1;
    var score = 0.0;
    if (locator == query) score += 12;
    if (locator.contains(query)) score += 8;
    if (text.contains(query)) score += 6;
    for (final token in tokens) {
      if (token.length < 2) continue;
      if (locator.contains(token)) score += 3;
      if (text.contains(token)) score += 1;
    }
    return score;
  }

  static String _normalizeLocator(String value) =>
      value.trim().replaceAll('—', '-').toUpperCase();

  static String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
