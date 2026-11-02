import '../models/quote_insight.dart';

String categoryNameKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s·•_\-—]+'), '').trim();
String categoryId(String parent, String name) =>
    'qkc_${insightHash([parent, categoryNameKey(name)]).substring(0, 24)}';
String knowledgeQuoteKey(Map<String, dynamic> row) {
  final uid = '${row['quote_uid'] ?? ''}'.trim();
  return uid.isEmpty ? 'legacy:${row['id']}' : uid;
}

String knowledgeInputHash(Map<String, dynamic> row) => insightHash([
      '${row['content'] ?? ''}',
      '${row['theme'] ?? ''}',
      '${row['explanation'] ?? ''}',
    ]);

class QuoteCategory {
  final String id, name, definition, parentId, origin;
  final int quoteCount;
  const QuoteCategory(
      {required this.id,
      required this.name,
      required this.definition,
      this.parentId = '',
      this.origin = 'ai',
      this.quoteCount = 0});
  factory QuoteCategory.fromRow(Map<String, dynamic> row) => QuoteCategory(
      id: '${row['id']}',
      name: '${row['name']}',
      definition: '${row['definition'] ?? ''}',
      parentId: '${row['parent_id'] ?? ''}',
      origin: '${row['origin'] ?? 'ai'}',
      quoteCount: (row['quote_count'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toPromptJson() =>
      {'id': id, 'name': name, 'definition': definition, 'parent_id': parentId};
}

class QuoteKnowledgeEdge {
  final String from, to, kind, explanation;
  final int weight;
  const QuoteKnowledgeEdge(this.from, this.to, this.kind,
      {this.explanation = '', this.weight = 1});
  String get label => switch (kind) {
        'subtopic' => '下位主题',
        'contrast' => '对照',
        'condition' => '条件主张',
        'cause_claim' => '因果主张',
        'cooccurrence' => '共同收录',
        _ => '相关概念',
      };
}

class QuoteKnowledgeGraph {
  final List<QuoteCategory> categories;
  final List<QuoteKnowledgeEdge> edges;
  final int quoteCount, pending, needsReview, legacyRemaining;
  const QuoteKnowledgeGraph(
      {this.categories = const [],
      this.edges = const [],
      this.quoteCount = 0,
      this.pending = 0,
      this.needsReview = 0,
      this.legacyRemaining = 0});
  List<QuoteCategory> get roots =>
      categories.where((c) => c.parentId.isEmpty).toList();
  List<QuoteCategory> children(String id) =>
      categories.where((c) => c.parentId == id).toList();
  QuoteCategory? category(String id) =>
      categories.where((c) => c.id == id).firstOrNull;
}

class ClassificationClaim {
  final String quoteKey, token, inputHash;
  final Map<String, dynamic> quote;
  const ClassificationClaim(
      this.quoteKey, this.token, this.inputHash, this.quote);
}

class CategoryProposal {
  final String ref, existingId, name, definition, parentRef, reason;
  final List<String> aliases;
  const CategoryProposal(
      {required this.ref,
      this.existingId = '',
      this.name = '',
      this.definition = '',
      this.parentRef = '',
      this.reason = '',
      this.aliases = const []});
}

class CategoryAssignment {
  final String categoryRef, evidence, reason;
  const CategoryAssignment(this.categoryRef, this.evidence, this.reason);
}

class CategoryRelationProposal {
  final String fromRef, toRef, kind, evidence, reason;
  const CategoryRelationProposal(
      this.fromRef, this.toRef, this.kind, this.evidence, this.reason);
}

class QuoteClassification {
  final List<CategoryProposal> categories;
  final List<CategoryAssignment> assignments;
  final List<CategoryRelationProposal> relations;
  final bool needsReview;
  final String reviewReason;
  const QuoteClassification(this.categories, this.assignments, this.relations,
      {this.needsReview = false, this.reviewReason = ''});

  static QuoteClassification parse(
      dynamic raw, String original, List<QuoteCategory> existing) {
    final map = insightObject(raw), known = {for (final c in existing) c.id: c};
    final categories = <CategoryProposal>[];
    final refs = <String>{...known.keys};
    final nodes = map['categories'];
    for (final value in nodes is List ? nodes.take(12) : const []) {
      final m = insightObject(value),
          ref = insightText(insightObject(value), 'ref');
      final id = insightText(m, 'existing_id');
      final name = insightText(m, 'name'),
          definition = insightText(m, 'definition');
      if (ref.isEmpty ||
          refs.contains(ref) ||
          (id.isNotEmpty && !known.containsKey(id)) ||
          (id.isEmpty &&
              (name.isEmpty ||
                  name.runes.length > 24 ||
                  definition.isEmpty ||
                  insightText(m, 'reason').isEmpty))) {
        throw const FormatException('分类需要可识别的类别、定义及新增理由');
      }
      refs.add(ref);
      categories.add(CategoryProposal(
          ref: ref,
          existingId: id,
          name: name,
          definition: definition,
          parentRef: insightText(m, 'parent_ref'),
          reason: insightText(m, 'reason'),
          aliases: m['aliases'] is List
              ? (m['aliases'] as List)
                  .whereType<String>()
                  .where((s) => s.trim().isNotEmpty && s.runes.length <= 24)
                  .take(6)
                  .toList()
              : []));
    }
    final parents = {for (final c in categories) c.ref: c.parentRef};
    for (final c in categories) {
      if (c.parentRef.isNotEmpty && !refs.contains(c.parentRef))
        throw const FormatException('上位类别不存在');
      final visited = <String>{c.ref};
      var parent = c.parentRef;
      while (parent.isNotEmpty && parents.containsKey(parent)) {
        if (!visited.add(parent)) throw const FormatException('分类层级不能形成循环');
        parent = parents[parent]!;
      }
    }
    final assignments = <CategoryAssignment>[];
    for (final value in map['assignments'] is List
        ? (map['assignments'] as List).take(4)
        : const []) {
      final m = insightObject(value),
          ref = insightText(insightObject(value), 'category_ref');
      final excerpt = insightText(m, 'evidence'),
          reason = insightText(m, 'reason');
      if (!refs.contains(ref) ||
          excerpt.isEmpty ||
          !original.contains(excerpt) ||
          reason.isEmpty) {
        throw const FormatException('名言分类必须对应已知类别及逐字原文依据');
      }
      assignments.add(CategoryAssignment(ref, excerpt, reason));
    }
    if (assignments.isEmpty) throw const FormatException('未返回有依据的名言归类');
    final relations = <CategoryRelationProposal>[];
    for (final value in map['relations'] is List
        ? (map['relations'] as List).take(8)
        : const []) {
      final m = insightObject(value),
          from = insightText(insightObject(value), 'from_ref'),
          to = insightText(insightObject(value), 'to_ref');
      final kind = insightText(m, 'kind'),
          excerpt = insightText(m, 'evidence'),
          reason = insightText(m, 'reason');
      if (!refs.contains(from) ||
          !refs.contains(to) ||
          from == to ||
          !['related', 'contrast', 'condition', 'cause_claim'].contains(kind) ||
          excerpt.isEmpty ||
          !original.contains(excerpt) ||
          reason.isEmpty) throw const FormatException('关系须保留类型、方向和原文依据');
      relations.add(CategoryRelationProposal(from, to, kind, excerpt, reason));
    }
    return QuoteClassification(categories, assignments, relations,
        needsReview: map['needs_review'] == true,
        reviewReason: insightText(map, 'review_reason'));
  }
}
