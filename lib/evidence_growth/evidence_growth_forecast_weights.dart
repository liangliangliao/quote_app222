import 'dart:math' as math;

import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';

/// Transparent, provisional model aggregation, not learned causal weights.
/// Importance is assessed by changing a factor's state, independently of how
/// adverse its current state is. Ordinal questionnaire levels are never used
/// as interval coefficients or event probabilities here.
class EvidenceForecastWeights {
  static const version = 'contextual_factor_pool_v1';
  static double? _p(Object? value) =>
      EvidenceForecastScience.probability(value);

  static GrowthData analyze(GrowthData factors) {
    final groups = <String, GrowthData>{};
    final unassessed = <String>[];
    final unknown = <String>[];
    var assessedImportance = 0.0;
    var knownImportance = 0.0;
    double? cap;
    final caps = <GrowthData>[];
    for (final entry in factors.entries) {
      final row = growthMap(entry.value);
      final aiImportance = _p(row['ai_importance']);
      final jevImportance = _p(row['jev_importance']);
      final importance = aiImportance != null && jevImportance != null
          ? (aiImportance + jevImportance) / 2
          : jevImportance ?? aiImportance;
      if (importance == null) {
        unassessed.add(entry.key);
        continue;
      }
      final group = EvidenceForecastScience.text(row['weight_group']).isNotEmpty
          ? '${row['weight_group']}'
          : EvidenceForecastScience.text(row['theory_construct']).isNotEmpty
              ? '${row['theory_construct']}'
              : entry.key;
      final previous = groups[group];
      // A construct gets one budget, using its best-supported representative.
      // Repeating an item in another theory cannot increase its influence.
      final strength = _p(row['evidence_strength']) ?? 0;
      final priority =
          importance * (row['unknown'] == true ? 0 : 1) + strength * .0001;
      final state = '${row['evidence_status'] ?? ''}';
      bool compatible(double? score) =>
          score != null &&
          (state == 'supportive'
              ? score >= .5
              : state == 'adverse'
                  ? score <= .5
                  : true);
      final a = _p(row['ai']);
      final j = _p(row['jev']);
      // Model support assessments must agree with the confirmed categorical
      // evidence. Never convert a questionnaire's ordinal level into a weight.
      final scores = [if (compatible(a)) a!, if (compatible(j)) j!];
      final support =
          row['unknown'] == true || state == 'insufficient' || scores.isEmpty
              ? null
              : scores.reduce((a, b) => a + b) / scores.length;
      final bottleneck = _p(row['bottleneck_probability']) ?? 0;
      final evidence = EvidenceForecastScience.text(row['evidence']);
      // Check every necessary obstacle before deduplication: overlapping
      // positive evidence must not hide a directly established failed gate.
      if (row['fact_grounded'] == true &&
          importance >= .75 &&
          state == 'adverse' &&
          support != null &&
          support <= .25 &&
          bottleneck >= .6 &&
          evidence.isNotEmpty) {
        final ceiling = (1 - importance * (1 - support) * bottleneck)
            .clamp(0.0, 1.0)
            .toDouble();
        cap = cap == null ? ceiling : math.min(cap, ceiling);
        caps.add({
          'key': entry.key,
          'label': row['label'],
          'ceiling': ceiling,
          'evidence': evidence,
          'importance': importance,
          'mechanism': row['mechanism'],
          'intervention': row['intervention']
        });
      }
      if (previous != null && (previous['_priority'] as double) >= priority) {
        continue;
      }
      groups[group] = {
        ...row,
        'key': entry.key,
        'group': group,
        'importance': importance,
        'support': support,
        'importance_source': aiImportance != null && jevImportance != null
            ? 'LLM_JEV'
            : jevImportance != null
                ? 'JEV'
                : 'LLM',
        '_priority': priority,
      };
    }
    for (final row in groups.values) {
      assessedImportance += row['importance'] as double;
      if (row['support'] != null) {
        knownImportance += row['importance'] as double;
      } else {
        unknown.add('${row['label'] ?? row['key']}');
      }
    }
    final ranked = <GrowthData>[];
    var supportShare = 0.0;
    var opposingShare = 0.0;
    var mixedShare = 0.0;
    var balance = 0.0;
    for (final row in groups.values) {
      final support = _p(row['support']);
      if (support == null || knownImportance <= 0) continue;
      final importance = row['importance'] as double;
      final weight = importance / knownImportance;
      balance += weight * support;
      final state = '${row['evidence_status']}';
      if (state == 'supportive') {
        supportShare += weight;
      } else if (state == 'adverse') {
        opposingShare += weight;
      } else {
        mixedShare += weight;
      }
      ranked.add({
        for (final entry in row.entries)
          if (entry.key != '_priority') entry.key: entry.value,
        'weight': weight,
        'support_contribution': weight * support,
        'opposition_contribution': weight * (1 - support),
      });
    }
    ranked.sort(
        (a, b) => (b['weight'] as double).compareTo(a['weight'] as double));
    for (var i = 0; i < ranked.length; i++) {
      ranked[i]['rank'] = i + 1;
    }
    return {
      'version': version,
      'status': ranked.isEmpty ? 'UNASSESSED' : 'WEIGHTED',
      'factors': ranked,
      'support_share': ranked.isEmpty ? null : supportShare,
      'opposing_share': ranked.isEmpty ? null : opposingShare,
      'mixed_share': ranked.isEmpty ? null : mixedShare,
      'support_index': ranked.isEmpty ? null : balance,
      'evidence_coverage':
          assessedImportance <= 0 ? null : knownImportance / assessedImportance,
      'unassessed_factors': unassessed,
      'unknown_factors': unknown,
      'probability_ceiling': cap,
      'critical_obstacles': caps,
      'note': '权重是针对本次行动的模型重要性判断；因素占比和支持度不是实测发生率。',
    };
  }

  static GrowthData combine({
    required GrowthData analysis,
    double? llm,
    double? jev,
    double? adjudication,
    double? hardBlocker,
    bool groundedHardBlocker = false,
  }) {
    final balance = _p(analysis['support_index']);
    if (balance == null) {
      return {
        'probability': adjudication ?? jev ?? llm,
        'source': 'UNWEIGHTED_MODEL_FALLBACK',
        'components': <GrowthData>[],
        'status': 'WEIGHTS_UNAVAILABLE'
      };
    }
    final coverage = _p(analysis['evidence_coverage']) ?? 0;
    final components = <GrowthData>[];
    // A provisional linear pool. The two dependent JEV stages share one
    // budget. Disagreement with explicit factor evidence reduces that budget
    // symmetrically; it never automatically rewards optimistic predictions.
    void add(String source, double? probability, double budget) {
      if (probability == null || budget <= 0) return;
      final consistency = 1 / (1 + 4 * (probability - balance).abs());
      components.add({
        'source': source,
        'probability': probability,
        'budget': budget * consistency
      });
    }

    add('FACTOR_SUPPORT', balance, coverage);
    add('LLM', llm, 1);
    final jevCount = (jev != null ? 1 : 0) + (adjudication != null ? 1 : 0);
    if (jevCount > 0) {
      add('JEV_FIRST', jev, 1 / jevCount);
      add('JEV_REVIEW', adjudication, 1 / jevCount);
    }
    final budget =
        components.fold<double>(0, (a, r) => a + (r['budget'] as double));
    if (budget <= 0) return {'probability': null, 'status': 'NO_ESTIMATE'};
    var pooled = 0.0;
    for (final component in components) {
      component['weight'] = (component.remove('budget') as double) / budget;
      pooled += (component['weight'] as double) *
          (component['probability'] as double);
    }
    var cap = _p(analysis['probability_ceiling']);
    if (groundedHardBlocker && hardBlocker != null && hardBlocker >= .85) {
      final hardCap = 1 - hardBlocker;
      cap = cap == null ? hardCap : math.min(cap, hardCap);
    }
    return {
      'probability': cap == null ? pooled : math.min(pooled, cap),
      'before_ceiling': pooled,
      'probability_ceiling': cap,
      'ceiling_applied': cap != null && pooled > cap,
      'components': components,
      'source': version,
      'status': 'WEIGHTED',
    };
  }
}
