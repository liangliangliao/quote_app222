import '../models/quote_insight.dart';
import 'concept_analysis.dart';

/// Every relation belongs to an explicit reading task and exact source spans.
/// Archive membership is deliberately absent from this model.
class ScopeSource {
  final String id, text, title;
  const ScopeSource(this.id, this.text, {this.title = ''});
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'title': title};
}

class ScopeReference {
  final String source, excerpt;
  const ScopeReference(this.source, this.excerpt);
  Map<String, dynamic> toJson() => {'source': source, 'excerpt': excerpt};
}

class SemanticRelation {
  final String placement, statement, status;
  final ConceptScope? scope;
  final List<ScopeReference> references;
  const SemanticRelation(
      this.placement, this.statement, this.status, this.scope, this.references);
}

class GroundDiagram {
  final String kind, from, to, link, status, position;
  final List<ScopeReference> references;
  const GroundDiagram(
      this.kind, this.from, this.to, this.link, this.status, this.references,
      {this.position = ''});
  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (position.isNotEmpty) 'spatial_relation': position,
        'from': from,
        'to': to,
        'link': link,
        'status': status,
        'references': references.map((r) => r.toJson()).toList()
      };
}

class SemanticScope {
  static const version = 1;
  final List<SemanticRelation> relations;
  final List<GroundDiagram> grounds;
  final String model;
  const SemanticScope(this.relations, this.grounds, {this.model = ''});

  static SemanticScope parse(dynamic raw, List<ScopeSource> sources,
      {String model = ''}) {
    final map = insightObject(raw);
    final ids = sources.map((s) => s.id).toSet();
    List<ScopeReference> refs(dynamic raw) {
      final result = <ScopeReference>[];
      for (final value in raw is List ? raw : const []) {
        final m = insightObject(value);
        final id = insightText(m, 'source'),
            excerpt = insightText(m, 'excerpt');
        if (excerpt.isEmpty ||
            !sources.any((s) => s.id == id && s.text.contains(excerpt))) {
          throw const FormatException('图形引用与所选原文不符，请重新分析');
        }
        result.add(ScopeReference(id, excerpt));
      }
      if (result.isEmpty) throw const FormatException('图形缺少原文依据');
      return result;
    }

    final relations = <SemanticRelation>[];
    for (final value in map['relations'] is List
        ? (map['relations'] as List).take(12)
        : const []) {
      final m = insightObject(value),
          placement = insightText(insightObject(value), 'placement');
      if (!(ids.contains(placement) ||
          (ids.length > 1 && placement == 'cross'))) {
        throw const FormatException('概念图分析对象与本次选择不符');
      }
      final references = refs(m['references']);
      if (placement == 'cross' &&
          references.map((r) => r.source).toSet().length < 2) {
        throw const FormatException('跨材料关系须分别对应至少两份参与材料');
      }
      if (placement != 'cross' &&
          !references.any((r) => r.source == placement)) {
        throw const FormatException('句内关系缺少本句依据');
      }
      final scopeMap = insightObject(m['scope']);
      ConceptScope? scope;
      if (scopeMap.isNotEmpty) {
        scope = ConceptScope.parse(
            scopeMap, references.map((r) => r.excerpt).join('\n'));
        if (scope == null ||
            scope.relation == QuoteRelation.disjoint ||
            scope.setA == scope.setB) {
          throw const FormatException('概念关系必须对应第九节五种图式及明确判准');
        }
        final needed = switch (scope.relation) {
          QuoteRelation.equal => [scope.intersection],
          QuoteRelation.subset => [scope.intersection, scope.onlyB],
          QuoteRelation.superset => [scope.intersection, scope.onlyA],
          QuoteRelation.overlap => [
              scope.intersection,
              scope.onlyA,
              scope.onlyB
            ],
          QuoteRelation.siblings => [
              scope.onlyA,
              scope.onlyB,
              scope.otherMember
            ],
          _ => <String>[],
        };
        if (needed.any((s) => s.isEmpty))
          throw const FormatException('图形缺少对应区域的成员与范围依据');
        if (scope.relation == QuoteRelation.partition &&
            (scope.parts.length < 2 ||
                scope.parts
                    .any((p) => p.criterion.isEmpty || p.example.isEmpty))) {
          throw const FormatException('穷尽划分需要各个子类的判准和实例');
        }
      }
      final statement = insightText(m, 'statement'),
          status = insightText(m, 'status');
      if (statement.isEmpty ||
          !['text_claim', 'interpretation', 'definition', 'unknown']
              .contains(status) ||
          (scope != null && status == 'unknown'))
        throw const FormatException('图形缺少判断的理由或认识状态');
      relations.add(
          SemanticRelation(placement, statement, status, scope, references));
    }
    if (relations.isEmpty ||
        !ids.every((id) => relations.any((r) => r.placement == id)) ||
        (ids.length > 1 && !relations.any((r) => r.placement == 'cross'))) {
      throw const FormatException('须分别分析各句中的概念及它们之间的关系');
    }
    final grounds = <GroundDiagram>[];
    for (final value in map['grounds'] is List
        ? (map['grounds'] as List).take(10)
        : const []) {
      final m = insightObject(value),
          kind = insightText(insightObject(value), 'kind');
      final status = insightText(m, 'status');
      if (!['evidence', 'cause', 'time', 'space', 'motive'].contains(kind) ||
          !['text_claim', 'interpretation', 'unknown'].contains(status) ||
          ['from', 'to', 'link'].any((k) => insightText(m, k).isEmpty)) {
        throw const FormatException('根据图须区分认识根据、因果、时间、空间与动机');
      }
      final position = insightText(m, 'spatial_relation');
      if (kind == 'space' &&
          ![
            'left',
            'right',
            'above',
            'below',
            'inside',
            'outside',
            'unspecified'
          ].contains(position)) {
        throw const FormatException('空间图缺少原文中对象的相对位置');
      }
      grounds.add(GroundDiagram(
          kind,
          insightText(m, 'from'),
          insightText(m, 'to'),
          insightText(m, 'link'),
          status,
          refs(m['references']),
          position: position));
    }
    return SemanticScope(relations, grounds, model: model);
  }

  Map<String, dynamic> toJson() => {
        'relations': [
          for (final r in relations)
            {
              'placement': r.placement,
              'statement': r.statement,
              'status': r.status,
              'scope': r.scope?.toJson(),
              'references': r.references.map((e) => e.toJson()).toList()
            }
        ],
        'grounds': grounds.map((g) => g.toJson()).toList(),
      };
}
