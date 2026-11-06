import 'semantic_contract.dart';
import '../models/quote_insight.dart';

/// Optional additions. Legacy notes remain readable without these fields.
class ConceptAbstraction {
  final String term,
      definition,
      observed,
      retained,
      omitted,
      counterExample,
      memberExample,
      nonMember;
  const ConceptAbstraction({
    required this.term,
    required this.definition,
    required this.observed,
    required this.retained,
    required this.omitted,
    required this.counterExample,
    this.memberExample = '',
    this.nonMember = '',
  });

  static List<ConceptAbstraction> parse(dynamic raw) => [
        for (final value in raw is List ? raw.take(60) : const [])
          if (insightText(insightObject(value), 'term').isNotEmpty &&
              insightText(insightObject(value), 'definition').isNotEmpty)
            ConceptAbstraction(
              memberExample:
                  insightText(insightObject(value), 'member_example'),
              nonMember: insightText(insightObject(value), 'non_member'),
              term: insightText(insightObject(value), 'term'),
              definition: insightText(insightObject(value), 'definition'),
              observed: insightText(insightObject(value), 'observed'),
              retained: insightText(insightObject(value), 'retained'),
              omitted: insightText(insightObject(value), 'omitted'),
              counterExample:
                  insightText(insightObject(value), 'counter_example'),
            ),
      ];
  Map<String, dynamic> toJson() => {
        'term': term,
        'member_example': memberExample,
        'non_member': nonMember,
        'definition': definition,
        'observed': observed,
        'retained': retained,
        'omitted': omitted,
        'counter_example': counterExample,
      };
}

class ScopePart {
  final String term, criterion, example;
  const ScopePart(this.term, this.criterion, this.example);
  Map<String, dynamic> toJson() =>
      {'term': term, 'criterion': criterion, 'example': example};
}

/// A proposed set model, never a proof that the quote is universally true.
/// Simulated classifications have an explicit identity separate from claims
/// anchored in the selected text. Invalid relationships are not drawn.
class ConceptScope {
  final QuoteRelation relation;
  final String universe,
      setA,
      setB,
      criterionA,
      criterionB,
      basis,
      justification,
      intersection,
      onlyA,
      onlyB,
      otherMember;
  final bool illustration;
  final String basisKind;
  final List<ScopePart> parts;
  const ConceptScope({
    required this.relation,
    required this.universe,
    required this.setA,
    required this.setB,
    required this.criterionA,
    required this.criterionB,
    required this.basis,
    required this.justification,
    this.intersection = '',
    this.onlyA = '',
    this.onlyB = '',
    this.otherMember = '',
    this.illustration = false,
    this.basisKind = 'source_assertion',
    this.parts = const [],
  });

  static ConceptScope? parse(dynamic raw, String original) {
    final m = insightObject(raw);
    if (MeaningCircleContract.gaps(m).isNotEmpty) return null;
    final type = insightText(m, 'relation_type');
    final relation =
        QuoteRelation.values.where((r) => r.name == type).firstOrNull;
    if (![
      QuoteRelation.equal,
      QuoteRelation.partition,
      QuoteRelation.siblings,
      QuoteRelation.overlap,
      QuoteRelation.subset,
      QuoteRelation.superset,
      QuoteRelation.disjoint,
    ].contains(relation)) return null;
    if (m['relation_scope'] != 'extension' ||
        [
          'universe',
          'set_a',
          'set_b',
          'criterion_a',
          'criterion_b',
          'justification',
        ].any((k) => insightText(m, k).isEmpty)) return null;
    final basis = insightText(m, 'basis');
    final simulated = m['illustration'] == true;
    if (!simulated && (basis.runes.length < 2 || !original.contains(basis))) {
      return null;
    }
    return ConceptScope(
      parts: [
        for (final raw in m['parts'] is List ? m['parts'] as List : const [])
          ScopePart(
              insightText(insightObject(raw), 'term'),
              insightText(insightObject(raw), 'criterion'),
              insightText(insightObject(raw), 'example'))
      ],
      relation: relation!,
      universe: insightText(m, 'universe'),
      setA: insightText(m, 'set_a'),
      setB: insightText(m, 'set_b'),
      criterionA: insightText(m, 'criterion_a'),
      criterionB: insightText(m, 'criterion_b'),
      basis: basis,
      justification: insightText(m, 'justification'),
      intersection: insightText(m, 'intersection'),
      onlyA: insightText(m, 'only_a'),
      onlyB: insightText(m, 'only_b'),
      otherMember: insightText(m, 'other_member'),
      illustration: simulated,
      basisKind: insightText(m, 'basis_kind').isNotEmpty ? insightText(m, 'basis_kind') : simulated ? 'teaching_example' : 'source_assertion',
    );
  }

  Map<String, dynamic> toJson() => {
        if (parts.isNotEmpty) 'parts': parts.map((p) => p.toJson()).toList(),
        'relation_type': relation.name,
        'relation_scope': 'extension',
        'universe': universe,
        'set_a': setA,
        'set_b': setB,
        'criterion_a': criterionA,
        'criterion_b': criterionB,
        'basis': basis,
        'justification': justification,
        'intersection': intersection,
        'only_a': onlyA,
        'only_b': onlyB,
        if (otherMember.isNotEmpty) 'other_member': otherMember,
        'illustration': illustration,
        'basis_kind': basisKind,
      };
}
