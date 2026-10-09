import 'dart:math' as math;

import 'evidence_growth_forecast_science.dart';
import 'evidence_growth_journey_models.dart';

/// Event forecasts alone enter this pool. Ordinal factor support and model
/// confidence are diagnostics, never a substitute for an event probability.
class EvidenceForecastOptimizer {
  static const version = 'event_pool_v4';
  static double? _p(Object? value) =>
      EvidenceForecastScience.probability(value);

  static GrowthData components({double? llm, double? jev, double? review}) {
    final judges = [if (_p(jev) != null) jev!, if (_p(review) != null) review!];
    return {
      if (_p(llm) != null) 'LLM': llm,
      // A review sees upstream conclusions and shares the JEV family's budget.
      if (judges.isNotEmpty)
        'JEV': judges.reduce((a, b) => a + b) / judges.length,
    };
  }

  static double _fitWeight(List<GrowthData> rows) {
    var numerator = 0.0;
    var denominator = 0.0;
    for (final row in rows) {
      final c = growthMap(row['optimizer_components']);
      final a = _p(c['LLM'])!;
      final j = _p(c['JEV'])!;
      final d = a - j;
      numerator += d * (EvidenceForecastScience.outcome(row)! - j);
      denominator += d * d;
    }
    // Convex least-squares stacking with a prior at equal family weights.
    // These regularization constants are engineering safeguards, not causal
    // coefficients. Fitting has no access to the current event's outcome.
    const priorStrength = 2.0;
    return ((numerator + priorStrength * .5) / (denominator + priorStrength))
        .clamp(.1, .9)
        .toDouble();
  }

  static GrowthData learnedPool(List<GrowthData> eligibleRows) {
    final rows = eligibleRows.where((r) {
      final c = growthMap(r['optimizer_components']);
      return r['optimizer_version'] == version &&
          _p(c['LLM']) != null &&
          _p(c['JEV']) != null &&
          EvidenceForecastScience.outcome(r) != null;
    }).toList()
      ..sort((a, b) =>
          (a['outcome_at_ms'] as num).compareTo(b['outcome_at_ms'] as num));
    final base = <String, dynamic>{
      'status': 'INSUFFICIENT_DATA',
      'llm_weight': .5,
      'sample_count': rows.length,
      'target_relative_brier_reduction': .10,
    };
    if (rows.length < 100 ||
        rows.where((r) => EvidenceForecastScience.outcome(r) == 1).length <
            15 ||
        rows.where((r) => EvidenceForecastScience.outcome(r) == 0).length <
            15) {
      return base;
    }
    final split = (rows.length * .6).floor();
    final holdout = rows.skip(split).toList();
    final firstPrediction = holdout
        .map((r) => (r['created_at_ms'] as num).toInt())
        .reduce(math.min);
    final train = rows
        .take(split)
        .where((r) => (r['outcome_at_ms'] as num) < firstPrediction)
        .toList();
    if (train.length < 50 ||
        [train, holdout].any((set) =>
            set.where((r) => EvidenceForecastScience.outcome(r) == 1).length <
                5 ||
            set.where((r) => EvidenceForecastScience.outcome(r) == 0).length <
                5)) {
      return {...base, 'status': 'INSUFFICIENT_TEMPORAL_SEPARATION'};
    }
    final weight = _fitWeight(train);
    final audit = EvidenceForecastScience.compareProbabilities([
      for (final r in holdout)
        {
          'outcome': EvidenceForecastScience.outcome(r),
          'baseline': (_p(growthMap(r['optimizer_components'])['LLM'])! +
                  _p(growthMap(r['optimizer_components'])['JEV'])!) /
              2,
          'candidate': weight *
                  _p(growthMap(r['optimizer_components'])['LLM'])! +
              (1 - weight) * _p(growthMap(r['optimizer_components'])['JEV'])!,
        },
    ], minimumCount: 30, minimumPerClass: 5);
    if (audit['target_verified'] != true) {
      return {...base, 'status': 'REJECTED_ON_HOLDOUT', 'validation': audit};
    }
    return {
      ...base, 'status': 'TEMPORALLY_VALIDATED_POOL',
      // Freeze the actually validated fit. Refitting on its holdout would
      // deploy weights different from those that earned the validation.
      'llm_weight': weight, 'training_count': train.length,
      'holdout_count': holdout.length, 'validation': audit,
    };
  }

  static GrowthData aggregate({
    required GrowthData analysis,
    double? llm,
    double? jev,
    double? review,
    double? hardBlocker,
    bool groundedHardBlocker = false,
    List<GrowthData> eligibleRows = const [],
  }) {
    final c = components(llm: llm, jev: jev, review: review);
    if (c.isEmpty) {
      return {
        'status': 'NO_ESTIMATE',
        'probability': null,
        'components': <GrowthData>[],
        'source': version
      };
    }
    final learned = c.length == 2
        ? learnedPool(eligibleRows)
        : <String, dynamic>{'status': 'SINGLE_FAMILY', 'llm_weight': .5};
    final llmWeight = learned['llm_weight'] as double;
    final weights = <String, double>{
      for (final key in c.keys)
        key: c.length == 1
            ? 1
            : key == 'LLM'
                ? llmWeight
                : 1 - llmWeight,
    };
    final pooled = c.entries.fold<double>(
        0, (value, e) => value + weights[e.key]! * (e.value as double));
    double? cap = _p(analysis['probability_ceiling']);
    final blocker = _p(hardBlocker);
    if (groundedHardBlocker && blocker != null && blocker >= .85) {
      cap = cap == null ? 1 - blocker : math.min(cap, 1 - blocker);
    }
    final estimates = [
      if (_p(llm) != null) llm!,
      if (_p(jev) != null) jev!,
      if (_p(review) != null) review!
    ];
    return {
      'status': 'EVENT_POOL',
      'source': version,
      'probability': cap == null ? pooled : math.min(pooled, cap),
      'before_ceiling': pooled,
      'probability_ceiling': cap,
      'ceiling_applied': cap != null && pooled > cap,
      'family_probabilities': c,
      'pool_learning': learned,
      'components': [
        for (final e in c.entries)
          {'source': e.key, 'probability': e.value, 'weight': weights[e.key]}
      ],
      'model_spread': estimates.reduce(math.max) - estimates.reduce(math.min),
      'model_range': {
        'low': estimates.reduce(math.min),
        'high': estimates.reduce(math.max)
      },
      'factor_support_is_diagnostic_only': true,
    };
  }

  static GrowthData performance(List<GrowthData> eligibleRows) =>
      EvidenceForecastScience.compareProbabilities([
        for (final r in eligibleRows)
          if (r['optimizer_version'] == version &&
              _p(r['baseline_v3_estimate']) != null &&
              _p(r['estimate']) != null)
            {
              'baseline': r['baseline_v3_estimate'],
              'candidate': r['estimate'],
              'outcome': EvidenceForecastScience.outcome(r)
            },
      ]);

  /// Concise guidance tied to an auditable factor, not a generic lecture.
  /// Unknown necessary conditions are verification tasks, not proven blockers.
  static GrowthData guidance(
      {required GrowthData factors,
      required GrowthData analysis,
      List<GrowthData> proposed = const [],
      bool reference = false}) {
    final steps = <GrowthData>[];
    final questions = <GrowthData>[];
    final critical = growthRows(analysis['critical_obstacles'])
        .map((r) => '${r['key']}')
        .toSet();
    final entries = factors.entries.toList()
      ..sort((a, b) {
        double priority(MapEntry<String, dynamic> e) {
          final r = growthMap(e.value);
          final importance = _p(r['importance']) ??
              _p(r['ai_importance']) ??
              _p(r['jev_importance']) ??
              0;
          final risk = r['evidence_status'] == 'adverse' ? 1.0 : .5;
          return (critical.contains(e.key) ? 10 : 0) +
              importance * risk +
              math.min(3, (r['past_barrier_recurrence_count'] as num?) ?? 0) *
                  .05;
        }

        return priority(b).compareTo(priority(a));
      });
    final proposedById = {
      for (final r in proposed)
        EvidenceForecastScience.text(r['factor_id'], 100): r
    };
    final usedGroups = <String>{};
    for (final e in entries) {
      final r = growthMap(e.value);
      final importance = _p(r['importance']) ??
          _p(r['ai_importance']) ??
          _p(r['jev_importance']) ??
          0;
      final label = EvidenceForecastScience.text(r['label'], 90);
      final unknown =
          r['unknown'] == true || r['evidence_status'] == 'insufficient';
      final proposal = growthMap(proposedById[e.key]);
      final question = EvidenceForecastScience.text(
          proposal['verification_question'] ?? r['verification_question'], 140);
      if (unknown && importance >= .5 && questions.length < 2) {
        questions.add({
          'factor_id': e.key,
          'label': label,
          'question':
              question.isNotEmpty ? question : '请先核实「$label」在这次行动中是否具备。',
          'importance': importance
        });
      }
      if (unknown ||
          !const {'adverse', 'mixed'}.contains(r['evidence_status']) ||
          importance < .25 ||
          steps.length >= 3) continue;
      final group = '${r['weight_group'] ?? e.key}';
      if (!usedGroups.add(group)) continue;
      final cue = EvidenceForecastScience.text(proposal['cue'], 100);
      final first = EvidenceForecastScience.text(proposal['first_step'], 160);
      final intervention = EvidenceForecastScience.text(r['intervention'], 160);
      if (first.isEmpty && intervention.isEmpty) continue;
      steps.add({
        'factor_id': e.key,
        'label': label,
        'priority': critical.contains(e.key) ? 'PREREQUISITE' : 'ACTION',
        'evidence': EvidenceForecastScience.text(r['evidence'], 140),
        'basis': r['fact_grounded'] == true
            ? '有已提供的依据'
            : EvidenceForecastScience.text(r['source_id']).isNotEmpty
                ? '从相关资料推测，需核实本次条件'
                : '依据当前假设，先核实',
        'plan': first.isEmpty
            ? intervention
            : cue.isEmpty
                ? first
                : '当$cue，就$first',
        'fallback': EvidenceForecastScience.text(proposal['fallback'], 140),
        'check': EvidenceForecastScience.text(proposal['check'], 140),
        'recurrence_count': r['past_barrier_recurrence_count'] ?? 0,
      });
    }
    return {
      'steps': steps,
      'verification_questions': questions,
      'kind': reference ? 'TRANSFER_LESSONS' : 'ACTION_GUIDANCE',
      'effects_are_unvalidated': true
    };
  }
}
