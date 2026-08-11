import 'dart:convert';

import 'package:flutter/services.dart';

import 'xiangji_models.dart';

class XiangjiEvidenceRecord {
  const XiangjiEvidenceRecord({
    required this.id,
    required this.sourceId,
    required this.locator,
    required this.claim,
    required this.summary,
    required this.boundary,
  });

  final String id;
  final String sourceId;
  final String locator;
  final String claim;
  final String summary;
  final String boundary;

  factory XiangjiEvidenceRecord.fromJson(Map<String, dynamic> json) {
    return XiangjiEvidenceRecord(
      id: (json['evidence_id'] ?? '').toString(),
      sourceId: (json['source_id'] ?? '').toString(),
      locator: (json['locator'] ?? '').toString(),
      claim: (json['claim'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      boundary: (json['boundary'] ?? '').toString(),
    );
  }
}

class XiangjiKnowledgeSystem {
  const XiangjiKnowledgeSystem({
    required this.id,
    required this.displayName,
    required this.thinker,
    required this.coreValues,
    required this.coreIdeas,
    required this.knowledgeView,
    required this.actionView,
    required this.splitDiagnosis,
    required this.transformationPath,
    required this.decisionCue,
    required this.tensions,
    required this.sourceIds,
    required this.evidence,
  });

  final String id;
  final String displayName;
  final String thinker;
  final List<String> coreValues;
  final List<String> coreIdeas;
  final String knowledgeView;
  final String actionView;
  final String splitDiagnosis;
  final String transformationPath;
  final String decisionCue;
  final List<String> tensions;
  final List<String> sourceIds;
  final List<XiangjiEvidenceRecord> evidence;

  factory XiangjiKnowledgeSystem.fromJson(Map<String, dynamic> json) {
    return XiangjiKnowledgeSystem(
      id: (json['systemId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      thinker: (json['thinker'] ?? '').toString(),
      coreValues: _strings(json['coreValues']),
      coreIdeas: _strings(json['coreIdeas']),
      knowledgeView: (json['knowledgeView'] ?? '').toString(),
      actionView: (json['actionView'] ?? '').toString(),
      splitDiagnosis: (json['splitDiagnosis'] ?? '').toString(),
      transformationPath: (json['transformationPath'] ?? '').toString(),
      decisionCue: (json['decisionCue'] ?? '').toString(),
      tensions: _strings(json['tensions']),
      sourceIds: _strings(json['sourceIds']),
      evidence: _maps(json['evidenceHighlights'])
          .map(XiangjiEvidenceRecord.fromJson)
          .toList(growable: false),
    );
  }
}

class XiangjiKnowledgeCatalog {
  const XiangjiKnowledgeCatalog({
    required this.version,
    required this.title,
    required this.systems,
    required this.books,
  });

  final String version;
  final String title;
  final List<XiangjiKnowledgeSystem> systems;
  final List<XiangjiBookInfo> books;

  XiangjiKnowledgeSystem? system(String id) {
    for (final item in systems) {
      if (item.id == id) return item;
    }
    return null;
  }

  XiangjiBookInfo? book(String id) {
    for (final item in books) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<XiangjiSourceCitation> citationsFor(
    XiangjiKnowledgeSystem system, {
    int limit = 3,
  }) {
    final citations = <XiangjiSourceCitation>[];
    for (final item in system.evidence.take(limit)) {
      final source = book(item.sourceId);
      if (source == null || item.id.isEmpty || item.locator.isEmpty) continue;
      citations.add(
        XiangjiSourceCitation(
          evidenceId: item.id,
          sourceId: item.sourceId,
          bookTitle: source.title,
          author: source.author,
          locator: item.locator,
          claim: item.claim,
          summary: item.summary,
          boundary: item.boundary,
          contentType: 'source_paraphrase',
        ),
      );
    }
    return citations;
  }
}

class XiangjiKnowledgeRepository {
  static const String assetPath =
      'assets/zhixing_tree/knowledge_systems_v2_0.json';

  XiangjiKnowledgeCatalog? _cache;

  Future<XiangjiKnowledgeCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('向己知识资产不是有效对象');
    }
    final catalog = fromJson(decoded);
    _cache = catalog;
    return catalog;
  }

  XiangjiKnowledgeCatalog fromJson(Map<String, dynamic> json) {
    final systems = _maps(json['systems'])
        .map(XiangjiKnowledgeSystem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
    final books = _maps(json['works'])
        .map(
          (item) => XiangjiBookInfo(
            id: (item['source_id'] ?? '').toString(),
            title: (item['title'] ?? '').toString(),
            author: (item['author'] ?? '').toString(),
            edition: (item['edition'] ?? '').toString(),
            sourceStatus: (item['source_status'] ?? '').toString(),
            builtIn: true,
            contentHash: (item['source_sha256'] ?? '').toString(),
            parseStatus: 'verified',
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
    if (systems.isEmpty || books.isEmpty) {
      throw const FormatException('向己知识资产缺少思想体系或书籍来源');
    }
    return XiangjiKnowledgeCatalog(
      version: (json['knowledge_version'] ?? 'unknown').toString(),
      title: (json['knowledge_title'] ?? '本地目标知识库').toString(),
      systems: systems,
      books: books,
    );
  }
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}
