import 'semantic_contract.dart';
import 'dart:convert';
import '../models/quote_insight.dart';
import 'concept_analysis.dart';

class ScopeSource {
  final String id, text, title, origin;
  const ScopeSource(this.id, this.text,
      {this.title = '', this.origin = 'quote'});
  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'title': title, 'origin': origin};
}

class ScopeReference {
  final String source, excerpt;
  const ScopeReference(this.source, this.excerpt);
  Map<String, dynamic> toJson() => {'source': source, 'excerpt': excerpt};
}

enum EpistemicViewKind {
  circles('含义圈'),
  grounds('四重根据'),
  abstraction('直观与抽象'),
  hierarchy('概念树'),
  judgment('判断力');

  const EpistemicViewKind(this.label);
  final String label;
}

/// Request context also participates in cache and pending-request identity.
class SemanticContext {
  final String purpose, conditions, conceptId, conceptLabel, conceptDefinition;
  const SemanticContext(
      {this.purpose = '',
      this.conditions = '',
      this.conceptId = '',
      this.conceptLabel = '',
      this.conceptDefinition = ''});
  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'conditions': conditions,
        'concept_id': conceptId,
        'concept_label': conceptLabel,
        'concept_definition': conceptDefinition,
      };
}

class AnalysisIssue {
  final String path, message;
  final bool retryable;
  final Map<String, dynamic>? originalItem;
  const AnalysisIssue(this.path, this.message,
      {this.retryable = true, this.originalItem});
  Map<String, dynamic> toJson() => {
        'path': path,
        'message': message,
        'retryable': retryable,
        if (originalItem != null) 'original_item': originalItem
      };
}

/// A contextual concept or an individual experience, never a taxonomy DB row.
class SemanticConcept {
  final String id, label, definition, kind, status, universe;
  final String observed, retained, omitted, counterExample;
  final List<ScopeReference> references;
  const SemanticConcept(
      {required this.id,
      required this.label,
      required this.definition,
      this.kind = 'concept',
      this.status = 'interpretation',
      this.universe = '',
      this.observed = '',
      this.retained = '',
      this.omitted = '',
      this.counterExample = '',
      this.references = const []});
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'definition': definition,
        'kind': kind,
        'status': status,
        'universe': universe,
        'observed': observed,
        'retained': retained,
        'omitted': omitted,
        'counter_example': counterExample,
        'references': references.map((r) => r.toJson()).toList(),
      };
}

class ConceptHierarchyEdge {
  final String parent, child, kind, explanation;
  final List<ScopeReference> references;
  const ConceptHierarchyEdge(
      this.parent, this.child, this.kind, this.explanation, this.references);
  Map<String, dynamic> toJson() => {
        'parent': parent,
        'child': child,
        'kind': kind,
        'explanation': explanation,
        'references': references.map((r) => r.toJson()).toList(),
      };
}

class JudgmentInsight {
  final String placement,
      question,
      common,
      difference,
      decisive,
      conditions,
      basis,
      unknown;
  final List<ScopeReference> references;
  const JudgmentInsight(
      {required this.placement,
      required this.question,
      this.common = '',
      this.difference = '',
      this.decisive = '',
      this.conditions = '',
      this.basis = '',
      this.unknown = '',
      this.references = const []});
  Map<String, dynamic> toJson() => {
        'placement': placement,
        'question': question,
        'common': common,
        'difference': difference,
        'decisive': decisive,
        'conditions': conditions,
        'basis': basis,
        'unknown': unknown,
        'references': references.map((r) => r.toJson()).toList(),
      };
}

class SemanticRelation {
  final String placement, statement, status, outcome;
  final ConceptScope? scope;
  final List<ScopeReference> references;
  final List<String> nodeIds, partIds;
  final String universeId;
  const SemanticRelation(
      this.placement, this.statement, this.status, this.scope, this.references,
      {this.outcome = '',
      this.nodeIds = const [],
      this.partIds = const [],
      this.universeId = ''});
  SemanticVerification get verification => PropositionConsistency.check(
      statement, references.map((r) => r.excerpt).join('\n'));
  Map<String, dynamic> toJson() => {
        'verification': verification.toJson(),
        'placement': placement,
        'statement': statement,
        'status': status,
        'outcome': outcome,
        'scope': scope?.toJson(),
        'node_ids': nodeIds,
        'part_ids': partIds,
        'universe_id': universeId,
        'references': references.map((r) => r.toJson()).toList(),
      };
}

class GroundDiagram {
  final String kind, from, to, link, status, position;
  final List<ScopeReference> references;
  const GroundDiagram(
      this.kind, this.from, this.to, this.link, this.status, this.references,
      {this.position = ''});
  String get limitation => switch (kind) {
        'time' || 'space' => '这里记录继起或位置线索；时间戳与地点不构成时间、空间先验形式的证明。',
        'cause' => '区分原句提出的因果条件与已经证实的原因；先后不证明因果。',
        'evidence' => '这里是相信或提出判断的根据，与对象变化的原因分别核对。',
        'motive' => '动机只依据明确报告；材料未明示时保持未知，不推断潜意识。',
        _ => ''
      };
  String get root => switch (kind) {
        'cause' => '生成根据 · 因果与条件',
        'evidence' => '认识根据 · 判断的依据',
        'time' || 'space' => '存在根据 · 时间与空间',
        'motive' => '行动根据 · 动机',
        _ => ''
      };
  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (position.isNotEmpty) 'spatial_relation': position,
        'from': from,
        'to': to,
        'link': link,
        'status': status,
        'references': references.map((r) => r.toJson()).toList(),
      };
}

/// Read old identities without ever exposing endpoints or their hashes in UI.
String readableModelName(String raw) {
  final text = raw.trim();
  if (text.startsWith('[')) {
    try {
      final parts = jsonDecode(text);
      if (parts is List &&
          parts.length >= 2 &&
          parts[0] is String &&
          parts[1] is String) {
        return readableModelName('${parts[0]} / ${parts[1]}');
      }
    } catch (_) {
      return '';
    }
    return '';
  }
  if (text.contains('://') || text.length > 160 || text.contains('['))
    return '';
  final parts = text.split(RegExp(r'\s*/\s*'));
  return parts.length > 1 && parts.first.toLowerCase() == 'azure'
      ? 'Azure / ${parts.last}'
      : text;
}

class SemanticScope {
  static const version = 3;
  final List<SemanticRelation> relations;
  final List<GroundDiagram> grounds;
  final List<SemanticConcept> concepts;
  final List<ConceptHierarchyEdge> hierarchy;
  final List<JudgmentInsight> judgments;
  final List<AnalysisIssue> issues;
  final EpistemicViewKind? recommendedView;
  final String model;
  final int sourceVersion;
  final String materialKind;
  final List<SemanticProposition> propositions;
  bool get legacy => sourceVersion < version;
  const SemanticScope(this.relations, this.grounds,
      {this.model = '',
      this.sourceVersion = version,
      this.materialKind = 'unknown',
      this.propositions = const [],
      this.concepts = const [],
      this.hierarchy = const [],
      this.judgments = const [],
      this.issues = const [],
      this.recommendedView});

  bool get hasContent =>
      propositions.isNotEmpty ||
      relations.isNotEmpty ||
      grounds.isNotEmpty ||
      concepts.isNotEmpty ||
      judgments.isNotEmpty;
  bool get needsRepair => issues.any((e) => e.retryable);
  List<EpistemicViewKind> get availableViews => [
        if (relations.any((r) => r.scope != null)) EpistemicViewKind.circles,
        if (grounds.isNotEmpty) EpistemicViewKind.grounds,
        if (concepts.any((c) =>
            [c.observed, c.retained, c.omitted].any((s) => s.isNotEmpty)))
          EpistemicViewKind.abstraction,
        if (concepts.isNotEmpty) EpistemicViewKind.hierarchy,
        if (propositions.isNotEmpty ||
            judgments.isNotEmpty ||
            relations.any((r) => r.scope == null))
          EpistemicViewKind.judgment,
      ];
  EpistemicViewKind? get primaryView {
    final views = availableViews;
    if (recommendedView != null && views.contains(recommendedView))
      return recommendedView;
    return views.contains(EpistemicViewKind.circles)
        ? EpistemicViewKind.circles
        : views.contains(EpistemicViewKind.judgment)
            ? EpistemicViewKind.judgment
            : views.firstOrNull;
  }

  /// Malformed items are isolated; a wholly unusable reply is still an error.
  static SemanticScope parse(dynamic raw, List<ScopeSource> sources,
      {String model = ''}) {
    final map = insightObject(raw);
    final inputVersion =
        (map['source_schema_version'] ?? map['schema_version']) is int
            ? (map['source_schema_version'] ?? map['schema_version']) as int
            : 1;
    final ids = sources.map((s) => s.id).toSet();
    final issues = <AnalysisIssue>[];
    final nodes = <String, SemanticConcept>{};
    final relations = <SemanticRelation>[];
    final hierarchy = <ConceptHierarchyEdge>[];
    final grounds = <GroundDiagram>[];
    final judgments = <JudgmentInsight>[];
    final propositions = <SemanticProposition>[];
    final propositionIds = <String>{};
    final referenceTable = <String, ScopeReference>{};
    for (final entry
        in map['evidence'] is List ? map['evidence'] as List : const []) {
      final evidence = insightObject(entry);
      final id = insightText(evidence, 'id'),
          source = insightText(evidence, 'source'),
          excerpt = insightText(evidence, 'excerpt');
      if (id.isEmpty ||
          referenceTable.containsKey(id) ||
          excerpt.isEmpty ||
          !sources.any((s) => s.id == source && s.text.contains(excerpt))) {
        issues.add(const AnalysisIssue('evidence', '引用表存在重复身份或不对应原文的摘录'));
      } else {
        referenceTable[id] = ScopeReference(source, excerpt);
      }
    }
    List<dynamic> items(String key, int limit) {
      final raw = map[key];
      if (raw is! List) return [];
      if (raw.length > limit)
        issues.add(AnalysisIssue(key, '响应超过本视图可接收的 $limit 项；其余项目未载入，请按分支展开。'));
      return raw.take(limit).toList();
    }

    void attempt(String path, void Function() parse) {
      try {
        parse();
      } on FormatException catch (e) {
        final match = RegExp(r'^([a-z_]+)\[(\d+)\]$').firstMatch(path);
        final list = match == null ? null : map[match.group(1)];
        final index = match == null ? -1 : int.parse(match.group(2)!);
        final original = list is List && index >= 0 && index < list.length
            ? insightObject(list[index])
            : null;
        issues.add(AnalysisIssue(path, e.message, originalItem: original));
      }
    }

    List<ScopeReference> refs(dynamic raw) {
      final result = <ScopeReference>[];
      for (final value in raw is List ? raw : const []) {
        final refId = value is String
            ? value
            : value is Map
                ? value['ref']
                : null;
        if (refId is String) {
          final ref = referenceTable[refId];
          if (ref == null) throw const FormatException('引用表中没有该依据身份');
          result.add(ref);
          continue;
        }
        final m = insightObject(value),
            id = insightText(insightObject(value), 'source');
        final excerpt = insightText(m, 'excerpt');
        if (excerpt.isEmpty ||
            !sources.any((s) => s.id == id && s.text.contains(excerpt))) {
          throw const FormatException('图形引用与所选原文不符，请重新分析');
        }
        result.add(ScopeReference(id, excerpt));
      }
      if (result.isEmpty) throw const FormatException('图形缺少原文依据');
      return result;
    }

    void placement(String p, List<ScopeReference> references) {
      if (!(ids.contains(p) || (ids.length > 1 && p == 'cross'))) {
        throw const FormatException('概念图分析对象与本次选择不符');
      }
      if (p == 'cross'
          ? references.map((r) => r.source).toSet().length < 2
          : !references.every((r) => r.source == p)) {
        throw const FormatException('关系须对应本句；跨材料关系须分别引用参与材料');
      }
    }

    List<String> strings(dynamic v) =>
        v is List ? v.whereType<String>().toList() : [];
    for (final entry in items('propositions', 80).indexed) {
      attempt('propositions[${entry.$1}]', () {
        final m = insightObject(entry.$2);
        final evidence =
            referenceTable[insightText(m, 'evidence_ref')]?.excerpt ??
                insightText(m, 'evidence');
        final conclusion = insightText(m, 'conclusion');
        if (evidence.isEmpty ||
            !sources.any((s) => s.text.contains(evidence)) ||
            conclusion.isEmpty) {
          throw const FormatException('命题缺少可定位的原文或结论');
        }
        final check = PropositionConsistency.check(conclusion, evidence,
            subject: insightText(m, 'subject'),
            predicate: insightText(m, 'predicate'),
            quantifier: insightText(m, 'quantifier'),
            polarity: insightText(m, 'polarity'),
            condition: insightText(m, 'condition'),
            modality: insightText(m, 'modality'));
        final id = insightText(m, 'id').isEmpty
            ? 'p:${insightHash([evidence, conclusion])}'
            : insightText(m, 'id');
        if (!propositionIds.add(id)) throw const FormatException('不同命题须使用独立身份');
        propositions.add(SemanticProposition(
            id: id,
            subject: insightText(m, 'subject'),
            predicate: insightText(m, 'predicate'),
            quantifier: insightText(m, 'quantifier'),
            polarity: insightText(m, 'polarity'),
            condition: insightText(m, 'condition'),
            modality: insightText(m, 'modality'),
            conclusion: conclusion,
            evidence: evidence,
            origin: insightText(m, 'origin'),
            verification: check));
        if (check.status == VerificationStatus.contradicted ||
            check.reason.contains('强化了')) {
          issues.add(AnalysisIssue(
              'propositions[${entry.$1}].consistency', check.reason,
              retryable: false));
        }
      });
    }
    for (final entry in items('concepts', 180).indexed) {
      attempt('concepts[${entry.$1}]', () {
        final m = insightObject(entry.$2),
            id = insightText(insightObject(entry.$2), 'id');
        final kind = insightText(m, 'kind'), status = insightText(m, 'status');
        if (id.isEmpty ||
            nodes.containsKey(id) ||
            insightText(m, 'label').isEmpty ||
            insightText(m, 'definition').isEmpty ||
            !['concept', 'experience', 'formal'].contains(kind) ||
            !['text_claim', 'interpretation', 'definition', 'example']
                .contains(status)) {
          throw const FormatException('概念需要独立身份、含义及材料或示例标记');
        }
        nodes[id] = SemanticConcept(
            id: id,
            label: insightText(m, 'label'),
            definition: insightText(m, 'definition'),
            kind: kind,
            status: status,
            universe: insightText(m, 'universe'),
            observed: insightText(m, 'observed'),
            retained: insightText(m, 'retained'),
            omitted: insightText(m, 'omitted'),
            counterExample: insightText(m, 'counter_example'),
            references: refs(m['references']));
      });
    }
    for (final entry in items('hierarchy', 256).indexed) {
      attempt('hierarchy[${entry.$1}]', () {
        final m = insightObject(entry.$2),
            parent = insightText(insightObject(entry.$2), 'parent');
        final child = insightText(m, 'child'), kind = insightText(m, 'kind');
        if (!nodes.containsKey(parent) ||
            !nodes.containsKey(child) ||
            parent == child ||
            nodes[parent]!.kind != 'concept' ||
            !['subtype', 'mediation', 'grounding', 'instance'].contains(kind) ||
            (['instance', 'grounding'].contains(kind)) !=
                (['experience', 'formal'].contains(nodes[child]!.kind)) ||
            insightText(m, 'explanation').isEmpty) {
          throw const FormatException('链路须区分下位限定、概念依赖和直观依据，且连接已知节点');
        }
        bool reaches(String at, Set<String> seen) =>
            at == parent ||
            (seen.add(at) &&
                hierarchy
                    .where((e) => e.parent == at)
                    .any((e) => reaches(e.child, seen)));
        if (reaches(child, {})) throw const FormatException('概念层级出现循环');
        hierarchy.add(ConceptHierarchyEdge(parent, child, kind,
            insightText(m, 'explanation'), refs(m['references'])));
      });
    }
    String legacyNode(String label, String criterion, String universe, String p,
        List<ScopeReference> references) {
      final id = 'legacy:${insightHash([p, universe, label, criterion])}';
      nodes.putIfAbsent(
          id,
          () => SemanticConcept(
              id: id,
              label: label,
              definition: criterion,
              universe: universe,
              references: references));
      return id;
    }

    for (final entry in items('relations', 80).indexed) {
      attempt('relations[${entry.$1}]', () {
        final m = insightObject(entry.$2),
            p = insightText(insightObject(entry.$2), 'placement');
        final references = refs(m['references']);
        placement(p, references);
        final scopeMap = insightObject(m['scope']);
        if (insightText(scopeMap, 'basis').isEmpty &&
            scopeMap['basis_ref'] is String) {
          scopeMap['basis'] =
              referenceTable[scopeMap['basis_ref']]?.excerpt ?? '';
        }
        ConceptScope? scope;
        final declaredIds = strings(m['node_ids']);
        if (scopeMap.isNotEmpty &&
            declaredIds.length == 2 &&
            declaredIds.every(nodes.containsKey)) {
          for (var i = 0; i < 2; i++) {
            final node = nodes[declaredIds[i]]!, suffix = i == 0 ? 'a' : 'b';
            if (insightText(scopeMap, 'set_$suffix').isEmpty)
              scopeMap['set_$suffix'] = node.label;
            if (insightText(scopeMap, 'criterion_$suffix').isEmpty)
              scopeMap['criterion_$suffix'] = node.definition;
            if (inputVersion >= 3 &&
                PropositionConsistency.normalize(
                        insightText(scopeMap, 'criterion_$suffix')) !=
                    PropositionConsistency.normalize(node.definition)) {
              throw const FormatException('关系中的成员判准改变了已有概念定义；同名异义须使用独立身份');
            }
          }
        }
        if (scopeMap.isNotEmpty) {
          final gaps = MeaningCircleContract.gaps(scopeMap);
          if (gaps.isNotEmpty) throw FormatException(gaps.join('；'));
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
            _ => <String>[]
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
        var statement = insightText(m, 'statement');
        var status = insightText(m, 'status');
        if (statement.isEmpty ||
            !['text_claim', 'interpretation', 'definition', 'unknown']
                .contains(status) ||
            (scope != null && status == 'unknown')) {
          throw const FormatException('图形缺少判断的理由或认识状态');
        }
        final consistency = PropositionConsistency.check(
            statement, references.map((r) => r.excerpt).join('\n'));
        if (scope?.illustration != true &&
            (consistency.status == VerificationStatus.contradicted ||
                consistency.reason.contains('强化了'))) {
          scope = null;
          status = 'unknown';
          statement = '$statement\n${consistency.reason}';
          issues.add(AnalysisIssue(
              'relations[${entry.$1}].consistency', consistency.reason,
              retryable: false));
        }
        var nodeIds = strings(m['node_ids']);
        var partIds = strings(m['part_ids']);
        var universeId = insightText(m, 'universe_id');
        if (scope != null) {
          if (nodeIds.isEmpty) {
            nodeIds = [
              legacyNode(
                  scope.setA, scope.criterionA, scope.universe, p, references),
              legacyNode(
                  scope.setB, scope.criterionB, scope.universe, p, references)
            ];
            if (scope.parts.isNotEmpty ||
                scope.relation == QuoteRelation.siblings) {
              universeId = legacyNode(scope.universe, scope.universe,
                  scope.universe, p, references);
              partIds = [
                for (final part in scope.parts)
                  legacyNode(
                      part.term, part.criterion, scope.universe, p, references)
              ];
            }
          }
          if (nodeIds.length != 2 ||
              nodeIds.toSet().length != 2 ||
              nodeIds.any((id) =>
                  !nodes.containsKey(id) || nodes[id]!.kind != 'concept') ||
              nodes[nodeIds[0]]!.label != scope.setA ||
              nodes[nodeIds[1]]!.label != scope.setB ||
              partIds.length != scope.parts.length ||
              partIds.toSet().length != partIds.length ||
              partIds.any((id) =>
                  !nodes.containsKey(id) || nodes[id]!.kind != 'concept') ||
              partIds.indexed.any((part) =>
                  nodes[part.$2]!.label != scope!.parts[part.$1].term) ||
              ((scope.parts.isNotEmpty ||
                      scope.relation == QuoteRelation.siblings) &&
                  !nodes.containsKey(universeId))) {
            throw const FormatException('关系节点身份与概念、子类或上位范围不一致');
          }
        }
        final outcome = scope != null
            ? 'drawable'
            : insightText(m, 'outcome') == 'needs_context' ||
                    status == 'unknown'
                ? 'needs_context'
                : 'non_extensional';
        relations.add(SemanticRelation(p, statement, status, scope, references,
            nodeIds: nodeIds,
            partIds: partIds,
            universeId: universeId,
            outcome: outcome));
      });
    }
    for (final entry in items('grounds', 64).indexed) {
      attempt('grounds[${entry.$1}]', () {
        final m = insightObject(entry.$2),
            kind = insightText(insightObject(entry.$2), 'kind');
        final status = insightText(m, 'status'),
            position = insightText(m, 'spatial_relation');
        if (!['evidence', 'cause', 'time', 'space', 'motive'].contains(kind) ||
            !['text_claim', 'interpretation', 'unknown'].contains(status) ||
            ['from', 'to', 'link'].any((k) => insightText(m, k).isEmpty)) {
          throw const FormatException('根据图须区分认识根据、因果、时间、空间与动机');
        }
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
      });
    }
    for (final entry in items('judgments', 64).indexed) {
      attempt('judgments[${entry.$1}]', () {
        final m = insightObject(entry.$2),
            p = insightText(insightObject(entry.$2), 'placement');
        final references = refs(m['references']);
        placement(p, references);
        if (insightText(m, 'question').isEmpty ||
            [insightText(m, 'difference'), insightText(m, 'basis')]
                .every((s) => s.isEmpty)) {
          throw const FormatException('判断力分析须指出当前问题及区分或根据');
        }
        judgments.add(JudgmentInsight(
            placement: p,
            question: insightText(m, 'question'),
            common: insightText(m, 'common'),
            difference: insightText(m, 'difference'),
            decisive: insightText(m, 'decisive'),
            conditions: insightText(m, 'conditions'),
            basis: insightText(m, 'basis'),
            unknown: insightText(m, 'unknown'),
            references: references));
      });
    }
    final badRelations = <int>{};
    final containment = <String, List<(String, int)>>{};
    final proper = <(String, String, int)>[];
    String vertex(SemanticRelation r, String id) => '${r.scope!.universe}::$id';
    for (final indexed in relations.indexed) {
      final r = indexed.$2, scope = r.scope;
      if (scope == null || r.nodeIds.length != 2) continue;
      final a = vertex(r, r.nodeIds[0]), b = vertex(r, r.nodeIds[1]);
      void edge(String from, String to) =>
          containment.putIfAbsent(from, () => []).add((to, indexed.$1));
      if (scope.relation == QuoteRelation.equal) {
        edge(a, b);
        edge(b, a);
      }
      if (scope.relation == QuoteRelation.subset) {
        edge(a, b);
        proper.add((a, b, indexed.$1));
      }
      if (scope.relation == QuoteRelation.superset) {
        edge(b, a);
        proper.add((b, a, indexed.$1));
      }
      for (var j = 0; j < indexed.$1; j++) {
        final other = relations[j], previous = other.scope;
        if (previous == null ||
            other.nodeIds.length != 2 ||
            previous.universe != scope.universe ||
            other.nodeIds.toSet().difference(r.nodeIds.toSet()).isNotEmpty)
          continue;
        final types = {scope.relation, previous.relation};
        if ((types.contains(QuoteRelation.overlap) &&
                types.any((t) => [
                      QuoteRelation.subset,
                      QuoteRelation.superset,
                      QuoteRelation.equal,
                      QuoteRelation.siblings
                    ].contains(t))) ||
            (types.contains(QuoteRelation.siblings) &&
                types.any((t) => [
                      QuoteRelation.subset,
                      QuoteRelation.superset,
                      QuoteRelation.equal
                    ].contains(t)))) {
          badRelations.addAll([indexed.$1, j]);
        }
      }
    }
    for (final (a, b, index) in proper) {
      final queue = <(String, List<int>)>[(b, [])], seen = <String>{};
      for (var i = 0; i < queue.length; i++) {
        final (at, path) = queue[i];
        if (at == a) {
          badRelations.addAll([index, ...path]);
          break;
        }
        if (!seen.add(at)) continue;
        for (final (next, relation) in containment[at] ?? <(String, int)>[]) {
          queue.add((next, [...path, relation]));
        }
      }
    }
    for (final index in badRelations) {
      final r = relations[index];
      const reason = '这些外延断言在同一论域不能同时成立；请核对包含方向或互斥/交叉判准，尚不能判断应采纳哪条。';
      issues.add(
          AnalysisIssue('relations[$index]', reason, originalItem: r.toJson()));
      relations[index] = SemanticRelation(
          r.placement, '${r.statement}\n$reason', 'unknown', null, r.references,
          nodeIds: r.nodeIds,
          partIds: r.partIds,
          universeId: r.universeId,
          outcome: 'needs_context');
    }
    // Persist diagnostics so a partial cached response can still be repaired.
    for (final raw in items('issues', 60)) {
      final m = insightObject(raw),
          message = insightText(insightObject(raw), 'message');
      if (message.isNotEmpty &&
          !issues.any((i) => i.path == insightText(m, 'path'))) {
        issues.add(AnalysisIssue(insightText(m, 'path'), message,
            retryable: m['retryable'] != false,
            originalItem: m['original_item'] is Map
                ? insightObject(m['original_item'])
                : null));
      }
    }
    final recommendation = insightText(map, 'recommended_view');
    final result = SemanticScope(relations, grounds,
        sourceVersion:
            (map['source_schema_version'] ?? map['schema_version']) is int
                ? (map['source_schema_version'] ?? map['schema_version']) as int
                : 1,
        materialKind: const [
          'fact',
          'definition',
          'metaphor',
          'argument',
          'experience'
        ].contains(map['material_kind'])
            ? '${map['material_kind']}'
            : 'unknown',
        propositions: propositions,
        concepts: nodes.values.toList(),
        hierarchy: hierarchy,
        judgments: judgments,
        issues: issues,
        model: readableModelName(model),
        recommendedView: EpistemicViewKind.values
            .where((k) => k.name == recommendation)
            .firstOrNull);
    if (!result.hasContent)
      throw FormatException(issues.firstOrNull?.message ?? '分析未返回可用内容，请重新分析');
    return result;
  }

  /// A repaired item replaces its previous version; untouched valid items survive.
  SemanticScope merge(SemanticScope other) {
    List<T> combine<T>(List<T> a, List<T> b, String Function(T) key) {
      final map = {for (final v in a) key(v): v};
      for (final v in b) {
        map[key(v)] = v;
      }
      return map.values.toList();
    }

    return SemanticScope(
        combine(
            relations,
            other.relations,
            (r) =>
                '${r.placement}:${r.nodeIds.isEmpty ? r.statement : r.nodeIds.join('|')}'),
        combine(grounds, other.grounds, (g) => '${g.kind}:${g.from}:${g.to}'),
        model: other.model.isEmpty ? model : other.model,
        sourceVersion: sourceVersion < other.sourceVersion
            ? sourceVersion
            : other.sourceVersion,
        materialKind:
            other.materialKind == 'unknown' ? materialKind : other.materialKind,
        propositions: combine(propositions, other.propositions, (p) => p.id),
        concepts: combine(concepts, other.concepts, (c) => c.id),
        hierarchy: combine(
            hierarchy, other.hierarchy, (e) => '${e.parent}:${e.child}'),
        judgments: combine(
            judgments, other.judgments, (j) => '${j.placement}:${j.question}'),
        issues: other.issues,
        recommendedView: other.recommendedView ?? recommendedView);
  }

  Map<String, dynamic> toJson() => {
        'schema_version': version,
        'source_schema_version': sourceVersion,
        'material_kind': materialKind,
        'propositions': propositions.map((p) => p.toJson()).toList(),
        'recommended_view': recommendedView?.name,
        'concepts': concepts.map((c) => c.toJson()).toList(),
        'hierarchy': hierarchy.map((e) => e.toJson()).toList(),
        'judgments': judgments.map((j) => j.toJson()).toList(),
        'relations': relations.map((r) => r.toJson()).toList(),
        'grounds': grounds.map((g) => g.toJson()).toList(),
        'issues': issues.map((e) => e.toJson()).toList(),
      };
}
