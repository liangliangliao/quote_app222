import 'reading_map_quality.dart';
import '../models/quote_insight.dart';
import 'concept_analysis.dart';
import 'semantic_scope.dart';

/// Adapt only actual saved definitions and examples. No inferred subtype edges.
SemanticScope? legacyConceptView(String text,
    List<ConceptAbstraction> abstractions, List<ConceptScope> scopes) {
  if (abstractions.isEmpty && scopes.isEmpty) return null;
  final refs = [ScopeReference('A', text)];
  final nodes = <SemanticConcept>[];
  final edges = <ConceptHierarchyEdge>[];
  for (final a in abstractions) {
    final id = 'saved:${insightHash([a.term, a.definition])}';
    nodes.add(SemanticConcept(
        id: id,
        label: a.term,
        definition: a.definition,
        observed: a.observed,
        retained: a.retained,
        omitted: a.omitted,
        counterExample: a.counterExample,
        references: refs));
    final example = a.memberExample.isNotEmpty ? a.memberExample : a.observed;
    if (example.isNotEmpty && !ReadingMapQuality.placeholder(example)) {
      nodes.add(SemanticConcept(
          id: '$id/example',
          label: String.fromCharCodes(example
              .replaceFirst(RegExp(r'^(?:模拟|示例|例子)[：:]\s*'), '')
              .runes
              .take(36)),
          definition: example,
          kind: 'experience',
          status: 'example',
          references: refs));
      edges.add(ConceptHierarchyEdge(
          id, '$id/example', 'instance', '这个已保存的示例呈现“${a.term}”的部分规定。', refs));
    }
  }
  SemanticScope result = SemanticScope(const [], const [],
      sourceVersion: 1,
      concepts: nodes,
      hierarchy: edges,
      recommendedView: EpistemicViewKind.hierarchy);
  if (scopes.isNotEmpty) {
    try {
      final saved = SemanticScope.parse({
        'relations': [
          for (final s in scopes)
            {
              'placement': 'A',
              'statement': s.justification,
              'status': 'interpretation',
              'scope': s.toJson(),
              'references': refs.map((r) => r.toJson()).toList(),
            }
        ]
      }, [
        ScopeSource('A', text)
      ]);
      result = result.merge(saved);
    } catch (_) {
      /* Old definitions remain readable even if an old circle is incomplete. */
    }
  }
  return result.hasContent ? result : null;
}
