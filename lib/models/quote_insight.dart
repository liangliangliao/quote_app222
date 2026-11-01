import 'dart:convert';

import 'package:crypto/crypto.dart';

enum EpistemicStatus { supported, provisional, unresolved }

enum ContentKind { quote, example, interpretation, prediction }

enum SourceStatus { verified, unverified, disputed }

enum QuoteRelation {
  equal,
  partition,
  siblings,
  overlap,
  subset,
  superset,
  disjoint,
  analogy,
  contrast,
  cause,
  condition,
  evidence,
  unknown
}

Map<String, dynamic> insightObject(dynamic value) {
  try {
    if (value is String) value = jsonDecode(value);
    if (value is Map) return Map<String, dynamic>.from(value);
  } catch (_) {}
  return <String, dynamic>{};
}

String insightText(Map<String, dynamic> map, String key) =>
    map[key] is String ? (map[key] as String).trim() : '';

String insightHash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

/// Model output is never a reviewed source. Only the local review path can
/// create a verified record, with a locator, reviewer and review date.
class EpistemicSource {
  final SourceStatus status;
  final String locator;
  final String verifiedBy;
  final String verifiedAt;

  const EpistemicSource({
    this.status = SourceStatus.unverified,
    this.locator = '',
    this.verifiedBy = '',
    this.verifiedAt = '',
  });

  factory EpistemicSource.fromModelJson(dynamic value,
      {String fallbackLocator = ''}) {
    final map = insightObject(value);
    return EpistemicSource(
      status: insightText(map, 'source_status') == 'disputed'
          ? SourceStatus.disputed
          : SourceStatus.unverified,
      locator: insightText(map, 'locator').isEmpty
          ? fallbackLocator
          : insightText(map, 'locator'),
    );
  }

  factory EpistemicSource.fromStoredJson(dynamic value) {
    final map = insightObject(value);
    final locator = insightText(map, 'locator');
    final reviewer = insightText(map, 'verified_by');
    final date = insightText(map, 'verified_at');
    final status = insightText(map, 'source_status');
    final reviewed = status == 'verified' &&
        locator.isNotEmpty &&
        reviewer.isNotEmpty &&
        DateTime.tryParse(date) != null;
    return EpistemicSource(
      status: reviewed
          ? SourceStatus.verified
          : status == 'disputed'
              ? SourceStatus.disputed
              : SourceStatus.unverified,
      locator: locator,
      verifiedBy: reviewed ? reviewer : '',
      verifiedAt: reviewed ? date : '',
    );
  }

  factory EpistemicSource.fromReviewedRecord({
    required String locator,
    required String verifiedBy,
    required DateTime verifiedAt,
  }) {
    if (locator.trim().isEmpty || verifiedBy.trim().isEmpty) {
      throw ArgumentError('已核对出处必须有可追溯定位与审核者');
    }
    return EpistemicSource(
        status: SourceStatus.verified,
        locator: locator.trim(),
        verifiedBy: verifiedBy.trim(),
        verifiedAt: verifiedAt.toUtc().toIso8601String());
  }

  String get label {
    if (status == SourceStatus.verified) return '已核对出处';
    if (status == SourceStatus.disputed) return '出处有争议';
    if (locator.isEmpty || RegExp(r'待考|不详|未知|不确定|无法|未核').hasMatch(locator))
      return '出处待考';
    return '待核对出处';
  }

  Map<String, dynamic> toJson() => {
        'source_status': status.name,
        'locator': locator,
        if (status == SourceStatus.verified) 'verified_by': verifiedBy,
        if (status == SourceStatus.verified) 'verified_at': verifiedAt,
      };
}

class QuoteReference {
  final String id, content, author, source;
  const QuoteReference(
      {required this.id,
      required this.content,
      this.author = '',
      this.source = ''});

  factory QuoteReference.fromRow(Map<String, dynamic> row) => QuoteReference(
        id: (row['quote_uid'] ?? row['fixed_uid'] ?? '').toString(),
        content: (row['content'] ?? '').toString(),
        author: (row['author_name'] ?? '').toString(),
        source: (row['source_from'] ?? '').toString(),
      );

  factory QuoteReference.fromPosterPayload(Map<String, dynamic> payload) =>
      QuoteReference(
        id: (payload['quoteUid'] ?? '').toString(),
        content: (payload['quote'] ?? '').toString(),
        author: (payload['quoteAuthor'] ?? payload['author'] ?? '').toString(),
        source: (payload['source'] ?? '').toString(),
      );

  // Content identity also works for pinned copies and survives physical shuffle.
  // Changing attribution or text invalidates an attached analysis.
  String get contentKey =>
      insightHash([content.trim(), author.trim(), source.trim()]);
  Map<String, dynamic> toPromptJson(String label) => {
        'label': label,
        'quote_id': id.isEmpty ? contentKey : id,
        'content': content,
        'author': author,
        'source_unverified': source,
      };
}

class QuoteAnalysisAddon {
  static const version = 1;
  final String concreteExample,
      commonality,
      criticalDifference,
      boundary,
      analysisBasis;
  final List<String> sourceRefs;
  final List<String> concepts;
  final EpistemicSource source;
  final String modelSourceAssessment;
  final Map<String, dynamic> cognition;

  const QuoteAnalysisAddon({
    this.concreteExample = '',
    this.commonality = '',
    this.criticalDifference = '',
    this.boundary = '',
    this.analysisBasis = '',
    this.sourceRefs = const [],
    this.concepts = const [],
    this.source = const EpistemicSource(),
    this.modelSourceAssessment = '',
    this.cognition = const {},
  });

  // AI interpretation is provisional regardless of the model's confidence.
  EpistemicStatus get status => EpistemicStatus.provisional;
  ContentKind get contentKind => ContentKind.interpretation;
  bool get hasReadingContent =>
      concreteExample.isNotEmpty ||
      commonality.isNotEmpty ||
      criticalDifference.isNotEmpty ||
      boundary.isNotEmpty;

  factory QuoteAnalysisAddon.fromModelJson(dynamic value,
      {String source = ''}) {
    final map = insightObject(value);
    final refs = map['source_refs'];
    final concepts = map['concepts'];
    return QuoteAnalysisAddon(
      cognition: insightObject(map['cognition']),
      concreteExample: insightText(map, 'concrete_example'),
      commonality: insightText(map, 'commonality'),
      criticalDifference: insightText(map, 'critical_difference'),
      boundary: insightText(map, 'boundary'),
      analysisBasis: insightText(map, 'analysis_basis'),
      sourceRefs: refs is List
          ? refs
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .take(8)
              .toList()
          : const [],
      concepts: concepts is List
          ? concepts
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .take(8)
              .toList()
          : const [],
      source: EpistemicSource.fromModelJson(map['epistemic_source'] ?? map,
          fallbackLocator: source),
      modelSourceAssessment: insightText(map, 'source_confidence'),
    );
  }

  factory QuoteAnalysisAddon.fromStoredJson(dynamic value) {
    final map = insightObject(value);
    if (map['version'] != version) return const QuoteAnalysisAddon();
    final parsed = QuoteAnalysisAddon.fromModelJson(map);
    return QuoteAnalysisAddon(
      cognition: parsed.cognition,
      concreteExample: parsed.concreteExample,
      commonality: parsed.commonality,
      criticalDifference: parsed.criticalDifference,
      boundary: parsed.boundary,
      analysisBasis: parsed.analysisBasis,
      sourceRefs: parsed.sourceRefs,
      concepts: parsed.concepts,
      source: EpistemicSource.fromStoredJson(map['epistemic_source']),
      modelSourceAssessment: parsed.modelSourceAssessment,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'concrete_example': concreteExample,
        'commonality': commonality,
        'critical_difference': criticalDifference,
        'boundary': boundary,
        'analysis_basis': analysisBasis,
        'source_refs': sourceRefs,
        'concepts': concepts,
        'cognition': cognition,
        'epistemic_source': source.toJson(),
        'source_confidence': modelSourceAssessment,
        'epistemic_status': status.name,
        'content_kind': contentKind.name,
      };
}

class QuoteComparison {
  final String common, difference, notEquivalent, limitation;
  final QuoteRelation relation;
  final String relationScope, justification, setA, setB, basisA, basisB;
  final String relationDirection, universe;
  final bool groundedInQuotes;
  final String modelInfo;

  const QuoteComparison(
      {required this.common,
      required this.difference,
      required this.notEquivalent,
      required this.limitation,
      required this.relation,
      this.relationScope = '',
      this.justification = '',
      this.setA = '',
      this.setB = '',
      this.basisA = '',
      this.basisB = '',
      this.groundedInQuotes = false,
      this.modelInfo = '',
      this.relationDirection = '',
      this.universe = ''});

  EpistemicStatus get status => EpistemicStatus.provisional;
  bool get canDrawSets =>
      const [
        QuoteRelation.equal,
        QuoteRelation.partition,
        QuoteRelation.siblings,
        QuoteRelation.overlap,
        QuoteRelation.subset,
        QuoteRelation.superset,
        QuoteRelation.disjoint
      ].contains(relation) &&
      (![QuoteRelation.partition, QuoteRelation.siblings].contains(relation) ||
          universe.isNotEmpty) &&
      relationScope == 'extension' &&
      groundedInQuotes &&
      justification.isNotEmpty &&
      setA.isNotEmpty &&
      setB.isNotEmpty;

  String get relationLabel => const {
        QuoteRelation.equal: '外延重合',
        QuoteRelation.partition: '互斥且穷尽上位范围',
        QuoteRelation.siblings: '同属上位范围但未穷尽',
        QuoteRelation.overlap: '部分交集',
        QuoteRelation.subset: 'A 包含于 B',
        QuoteRelation.superset: 'A 包含 B',
        QuoteRelation.disjoint: '相互排斥',
        QuoteRelation.analogy: '类比',
        QuoteRelation.contrast: '对照',
        QuoteRelation.cause: '因果假设',
        QuoteRelation.condition: '条件关系',
        QuoteRelation.evidence: '认识根据',
        QuoteRelation.unknown: '关系尚不确定',
      }[relation]!;

  Map<String, dynamic> toJson() => {
        'common': common,
        'critical_difference': difference,
        'not_equivalent': notEquivalent,
        'limitation': limitation,
        'relation_type': relation.name,
        'relation_scope': relationScope,
        'relation_justification': justification,
        'set_a': setA,
        'set_b': setB,
        'basis_a': basisA,
        'basis_b': basisB,
        'model_info': modelInfo,
        'relation_direction': relationDirection,
        'universe': universe,
        'epistemic_status': status.name,
      };
}
