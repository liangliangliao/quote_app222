import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'evidence_growth_behavior_theories.dart';
import 'evidence_growth_journey_models.dart';

/// Forecast bookkeeping and empirical validation. No theory supplies universal
/// probability coefficients. Model confidence is never used as a sample weight.
class EvidenceForecastScience {
  static const version = 'action_forecast_v2';
  static const contractVersion = 'observable_event_v1';

  static double? probability(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 1
          ? value.toDouble()
          : null;

  static String text(Object? value, [int max = 1800]) {
    final s = '${value ?? ''}'.trim();
    return s.length > max ? s.substring(0, max) : s;
  }

  static GrowthData contract(GrowthData input) => {
        'version': contractVersion,
        'success_criterion': text(input['success_criterion'], 600),
        'observation_window': text(input['observation_window'], 300),
        'context_class': text(input['context_class'], 400),
        'confirmed': input['confirmed'] == true,
      };

  static bool validContract(GrowthData value) =>
      value['confirmed'] == true &&
      text(value['success_criterion']).isNotEmpty &&
      text(value['observation_window']).isNotEmpty;

  /// Only an explicitly named comparable context can pool trials. Exact event
  /// definition and observation-window semantics must also agree.
  static String comparisonKey(GrowthData value, String mode) {
    if (!validContract(value) || text(value['context_class']).isEmpty)
      return '';
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              contractVersion,
              mode,
              text(value['success_criterion']),
              text(value['observation_window']),
              text(value['context_class']),
            ]),
          ),
        )
        .toString();
  }

  static String modelSignature(GrowthData ai, GrowthData jev, String source) =>
      jsonEncode([version, ai['model'] ?? '', jev['model'] ?? '', source]);

  static String inputFingerprint(GrowthData state) => sha256
      .convert(utf8.encode(jsonEncode({
        for (final key in const [
          'plan',
          'scheduled_at',
          'user_reported_conditions',
          'additional_notes',
          'similar_history_report',
          'analysis_correction',
          'journey',
          'clarification_answers',
          'event_contract'
        ])
          key: state[key],
        'selected_theories': (growthStrings(state['selected_theories'])
          ..sort()),
        'answers': {
          for (final key
              in (growthMap(state['theory_factor_answers']).keys.toList()
                ..sort()))
            key: growthMap(
                growthMap(state['theory_factor_answers'])[key])['option_id']
        },
      })))
      .toString();

  static double? outcome(GrowthData row) {
    if (const {'PENDING', 'CANCELLED', 'UNOBSERVED'}.contains(row['outcome']))
      return null;
    final explicit = row['primary_event_observed'];
    if (explicit is bool) return explicit ? 1 : 0;
    // v2 outcomes must explicitly resolve the frozen event, even when partial.
    if (row['science_version'] == version) return null;
    if (const {'SUCCESS', 'ON_TIME'}.contains(row['outcome'])) return 1;
    if (const {'FAILED', 'NOT_DONE'}.contains(row['outcome'])) return 0;
    return null;
  }

  static String trialId(GrowthData row) => text(row['trial_id']).isNotEmpty
      ? text(row['trial_id'])
      : text(row['id']);

  /// One last prospectively saved prediction per real trial, never several
  /// revisions of a single event. No censored, simulated or post-outcome data.
  static List<GrowthData> eligible(
    List<GrowthData> rows, {
    required String key,
    required String signature,
    int? beforeMs,
  }) {
    if (key.isEmpty || signature.isEmpty) return [];
    final before = beforeMs ?? DateTime.now().millisecondsSinceEpoch;
    final latest = <String, GrowthData>{};
    // Select latest revisions BEFORE filtering outcomes: an older answered
    // revision must not survive when the latest revision is pending/censored.
    for (final row in rows) {
      if (row['science_version'] != version || row['hypothetical'] == true)
        continue;
      final id = trialId(row);
      final created = (row['created_at_ms'] as num?)?.toInt() ?? 0;
      if (id.isEmpty || created <= 0 || created >= before) continue;
      final old = latest[id];
      if (old == null || created > (old['created_at_ms'] as num))
        latest[id] = row;
    }
    final result = latest.values.where((row) {
      final created = (row['created_at_ms'] as num).toInt();
      final observed = (row['outcome_at_ms'] as num?)?.toInt() ?? 0;
      return row['comparison_key'] == key &&
          row['model_signature'] == signature &&
          validContract(growthMap(row['event_contract'])) &&
          observed > created &&
          observed < before &&
          outcome(row) != null &&
          probability(row['raw_model_estimate']) != null &&
          probability(row['estimate']) != null;
    }).toList();
    result.sort(
      (a, b) =>
          (a['outcome_at_ms'] as num).compareTo(b['outcome_at_ms'] as num),
    );
    return result;
  }

  static double _logit(double p) {
    final q = p.clamp(.001, .999);
    return math.log(q / (1 - q));
  }

  static double _sigmoid(double x) => 1 / (1 + math.exp(-x.clamp(-30, 30)));

  static List<double> _fitCalibration(List<GrowthData> samples) {
    var a = 0.0;
    var b = 1.0;
    for (var iter = 0; iter < 600; iter++) {
      var ga = 2 * a;
      var gb = 2 * (b - 1);
      for (final row in samples) {
        final x = _logit(probability(row['raw_model_estimate'])!);
        final error = _sigmoid(a + b * x) - outcome(row)!;
        ga += error;
        gb += error * x;
      }
      a -= .06 * ga / samples.length;
      b = (b - .06 * gb / samples.length).clamp(0.0, 4.0);
    }
    return [a, b];
  }

  static GrowthData _metrics(
    List<GrowthData> rows,
    double Function(GrowthData) predict,
  ) {
    if (rows.isEmpty) return {'count': 0};
    var brier = 0.0;
    var loss = 0.0;
    var total = 0.0;
    var events = 0.0;
    for (final row in rows) {
      final p = predict(row);
      final y = outcome(row)!;
      brier += math.pow(p - y, 2).toDouble();
      final q = p.clamp(.000001, .999999);
      loss -= y * math.log(q) + (1 - y) * math.log(1 - q);
      total += p;
      events += y;
    }
    return {
      'count': rows.length,
      'brier': brier / rows.length,
      'log_loss': loss / rows.length,
      'mean_prediction': total / rows.length,
      'observed_rate': events / rows.length,
    };
  }

  /// Conservative operational gates, not universal statistical guarantees.
  /// Chronological holdout must beat the raw model on Brier AND log loss.
  static GrowthData calibrate(double? raw, List<GrowthData> rows) {
    final positives = rows.where((r) => outcome(r) == 1).length;
    final base = <String, dynamic>{
      'status': raw == null ? 'NO_RAW_ESTIMATE' : 'UNCALIBRATED',
      'probability': raw,
      'raw_probability': raw,
      'sample_count': rows.length,
      'positive_count': positives,
      'negative_count': rows.length - positives,
      'scope': 'EXACT_EVENT_CONTEXT_MODEL',
      'minimum_rule':
          '至少60次独立同类行动，成功/失败各至少10次；按结果时间保留后30%验证，且验证集成功/失败各至少3次。阈值是保守工程门槛，不保证准确。',
    };
    if (raw == null ||
        rows.length < 60 ||
        positives < 10 ||
        rows.length - positives < 10) return base;
    final split = (rows.length * .7).floor();
    final holdout = rows.skip(split).toList();
    final firstPrediction = holdout
        .map((r) => (r['created_at_ms'] as num).toInt())
        .reduce(math.min);
    final train = rows
        .take(split)
        .where((r) => (r['outcome_at_ms'] as num) < firstPrediction)
        .toList();
    if (train.length < 40)
      return {...base, 'status': 'INSUFFICIENT_TEMPORAL_SEPARATION'};
    if ([train, holdout].any(
      (rs) =>
          rs.where((r) => outcome(r) == 1).length < 3 ||
          rs.where((r) => outcome(r) == 0).length < 3,
    )) return base;
    final fit = _fitCalibration(train);
    final rawMetrics = _metrics(
      holdout,
      (r) => probability(r['raw_model_estimate'])!,
    );
    final adjusted = _metrics(
      holdout,
      (r) => _sigmoid(
        fit[0] + fit[1] * _logit(probability(r['raw_model_estimate'])!),
      ),
    );
    final improves = (adjusted['brier'] as double) + .002 <
            (rawMetrics['brier'] as double) &&
        (adjusted['log_loss'] as double) < (rawMetrics['log_loss'] as double);
    final audited = {
      ...base,
      'holdout_count': holdout.length,
      'holdout_raw': rawMetrics,
      'holdout_calibrated': adjusted,
      'holdout_passed': improves,
    };
    if (!improves)
      return {...audited, 'status': 'CALIBRATION_REJECTED_ON_HOLDOUT'};
    final full = _fitCalibration(rows);
    return {
      ...audited,
      'status': 'PERSONAL_PLATT_CALIBRATED',
      'probability': _sigmoid(full[0] + full[1] * _logit(raw)),
      'intercept': full[0],
      'slope': full[1],
      'method': '正则化逻辑校准；时间留出验证通过后，仅用先前独立结果拟合。个人试用校准，不是外部验证或因果模型。',
    };
  }

  static GrowthData validation(List<GrowthData> rows) {
    final raw = _metrics(rows, (r) => probability(r['raw_model_estimate'])!);
    final shown = _metrics(rows, (r) => probability(r['estimate'])!);
    final bins = <GrowthData>[];
    for (var i = 0; i < 5; i++) {
      final subset = rows.where((r) {
        final p = probability(r['estimate'])!;
        return p >= i / 5 && (i == 4 ? p <= 1 : p < (i + 1) / 5);
      }).toList();
      bins.add({
        'lower': i / 5,
        'upper': (i + 1) / 5,
        ..._metrics(subset, (r) => probability(r['estimate'])!),
      });
    }
    return {
      'raw_count': rows.length,
      'final_count': rows.length,
      'raw_brier': raw['brier'],
      'final_brier': shown['brier'],
      'raw_log_loss': raw['log_loss'],
      'final_log_loss': shown['log_loss'],
      'raw_mean_prediction': raw['mean_prediction'],
      'final_mean_prediction': shown['mean_prediction'],
      'observed_rate': shown['observed_rate'],
      'reliability_bins': bins,
      'note':
          '仅比较同事件定义、同情境组、同模型版本、每次行动最后一次事前预测；取消、未观察、未确认主事件的部分完成和旧版记录不进入统计。Brier/对数损失越低越好；一次结果不能证明概率正确或错误。',
    };
  }

  /// Context-specific categorical associations learned only when prospective
  /// data can support them. Five-level options are NOT equal-interval numbers.
  static GrowthData learnedAssociations(
    List<GrowthData> rows,
    GrowthData currentAnswers,
  ) {
    final unavailable = <String, dynamic>{
      'status': 'INSUFFICIENT_DATA',
      'sample_count': rows.length,
      'coefficients': <GrowthData>[],
      'note':
          '没有预设“科学权重”。同一因素去重；态度→意向等上游下游关系不机械相加。至少120次同类独立结果后尝试学习类别关联，时间留出效果不佳则不采用。',
    };
    if (rows.length < 120 ||
        rows.where((r) => outcome(r) == 1).length < 20 ||
        rows.where((r) => outcome(r) == 0).length < 20) return unavailable;
    final split = (rows.length * .7).floor();
    final holdout = rows.skip(split).toList();
    final firstPrediction = holdout
        .map((r) => (r['created_at_ms'] as num).toInt())
        .reduce(math.min);
    final train = rows
        .take(split)
        .where((r) => (r['outcome_at_ms'] as num) < firstPrediction)
        .toList();
    if (train.length < 80 ||
        [train, holdout].any((rs) =>
            rs.where((r) => outcome(r) == 1).length < 5 ||
            rs.where((r) => outcome(r) == 0).length < 5))
      return {...unavailable, 'status': 'INSUFFICIENT_TEMPORAL_SEPARATION'};
    final features = <String>[];
    final counts = <String, int>{};
    for (final row in train) {
      for (final entry in growthMap(row['theory_factor_answers']).entries) {
        final answer = growthMap(entry.value);
        final option = text(answer['option_id']);
        if (answer['confirmed_by_user'] != true ||
            option == 'unknown' ||
            EvidenceBehaviorTheoryCatalog.option(entry.key, option) == null)
          continue;
        final key = '${entry.key}:$option';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    features.addAll(
      counts.keys
          .where((k) => counts[k]! >= 15 && counts[k]! <= train.length - 15)
          .toList()
        ..sort(),
    );
    // Limit model complexity relative to independent training observations.
    if (features.isEmpty || features.length > train.length ~/ 10)
      return {...unavailable, 'status': 'INSUFFICIENT_FEATURE_SUPPORT'};
    List<double> vector(GrowthData answers) => [
          for (final f in features)
            growthMap(answers[f.split(':').first])['confirmed_by_user'] ==
                        true &&
                    growthMap(answers[f.split(':').first])['option_id'] ==
                        f.split(':').last
                ? 1
                : 0,
        ];
    final xs = train
        .map((r) => vector(growthMap(r['theory_factor_answers'])))
        .toList();
    final weights = List<double>.filled(features.length, 0);
    var intercept = _logit(
      (train.where((r) => outcome(r) == 1).length + 1) / (train.length + 2),
    );
    for (var iter = 0; iter < 500; iter++) {
      final grad = weights.map((w) => 8 * w).toList();
      var gi = 0.0;
      for (var i = 0; i < train.length; i++) {
        var logit = intercept;
        for (var j = 0; j < weights.length; j++) {
          logit += weights[j] * xs[i][j];
        }
        final error = _sigmoid(logit) - outcome(train[i])!;
        gi += error;
        for (var j = 0; j < weights.length; j++) {
          grad[j] += error * xs[i][j];
        }
      }
      intercept -= .1 * gi / train.length;
      for (var j = 0; j < weights.length; j++) {
        weights[j] -= .1 * grad[j] / train.length;
      }
    }
    double predict(GrowthData answers) {
      final x = vector(answers);
      var z = intercept;
      for (var j = 0; j < weights.length; j++) {
        z += weights[j] * x[j];
      }
      return _sigmoid(z);
    }

    final fitted = _metrics(
      holdout,
      (r) => predict(growthMap(r['theory_factor_answers'])),
    );
    final raw = _metrics(holdout, (r) => probability(r['raw_model_estimate'])!);
    final baseRate =
        (train.where((r) => outcome(r) == 1).length + 1) / (train.length + 2);
    final baseline = _metrics(holdout, (_) => baseRate);
    final passed = [raw, baseline].every(
      (m) =>
          (fitted['brier'] as double) + .002 < (m['brier'] as double) &&
          (fitted['log_loss'] as double) < (m['log_loss'] as double),
    );
    return {
      ...unavailable,
      'status':
          passed ? 'EXPLORATORY_VALIDATED_ASSOCIATIONS' : 'REJECTED_ON_HOLDOUT',
      'holdout_count': holdout.length,
      'holdout_model': fitted,
      'holdout_raw': raw,
      'holdout_base_rate': baseline,
      'estimate': passed ? predict(currentAnswers) : null,
      'coefficients': passed
          ? [
              for (var j = 0; j < features.length; j++)
                {
                  'factor_id': features[j].split(':').first,
                  'option_id': features[j].split(':').last,
                  'coefficient': weights[j],
                  'training_count': counts[features[j]],
                },
            ]
          : <GrowthData>[],
      'note':
          '类别指示变量的L2正则逻辑回归，按时间留出验证并同时比较原始JEV与训练期基线。系数是条件关联，受重叠构念影响，不是因果权重或固定百分比；仅辅助交叉检查，不覆盖主预测。',
    };
  }

  static GrowthData report(GrowthData result, List<GrowthData> eligibleRows) {
    final provenance = growthMap(result['forecast_provenance']);
    final predictions = <double>[
      for (final p in [
        provenance['ai_fallback_probability'],
        provenance['jev_primary_event_probability'],
        provenance['jev_final_synthesis_probability'],
      ])
        if (probability(p) != null) probability(p)!,
    ];
    final analysis = growthMap(
      growthMap(result['behavior_diagnosis'])['theory_feedback_analysis'],
    );
    final candidates = growthRows(analysis['llm_candidate_conclusions']);
    final finalJev = growthMap(analysis['jev_final_adjudication']);
    final catalog = growthRows(finalJev['candidate_catalog']);
    final rootVerdicts = growthMap(finalJev['root_cause_verdicts']);
    final feasibility = growthMap(finalJev['intervention_feasibility']);
    final scenarios = growthMap(finalJev['intervention_probabilities']);
    final recommendation = growthMap(finalJev['recommended_intervention']);
    final roots = <GrowthData>[];
    for (final row in candidates) {
      final match = catalog.where((c) => c['id'] == row['id']).toList();
      final key = match.isEmpty ? '' : text(match.first['key']);
      final verdict = growthMap(
        growthMap(finalJev['conclusion_verdicts'])[key],
      );
      final scenarioP = probability(scenarios[key]);
      roots.add({
        ...row, 'evidence_verdict': verdict,
        'root_verdict': growthMap(rootVerdicts[key]),
        'feasibility': growthMap(feasibility[key]),
        'scenario_probability': scenarioP,
        // Both are uncalibrated probabilities for the SAME frozen event.
        'model_sensitivity_delta': scenarioP == null ||
                probability(result['raw_model_estimate']) == null
            ? null
            : scenarioP - probability(result['raw_model_estimate'])!,
        'causal_status': 'HYPOTHESIS_NOT_PROVEN',
        'jev_reviewed_excerpt':
            match.isNotEmpty && match.first['narrative_excerpted'] == true,
        'recommended': recommendation['choice'] == key &&
            (probability(recommendation['confidence']) ?? 0) >= .55 &&
            const {'supported', 'partially_supported'}
                .contains(verdict['choice']) &&
            growthMap(rootVerdicts[key])['choice'] != 'contradicted' &&
            const {'feasible', 'conditional'}
                .contains(growthMap(feasibility[key])['choice']),
      });
    }
    roots.sort((a, b) => (b['recommended'] == true ? 1 : 0)
        .compareTo(a['recommended'] == true ? 1 : 0));
    return {
      'version': version,
      'event_contract': result['event_contract'],
      'evidence_completeness': result['theory_input_completeness'],
      'model_spread': predictions.length < 2
          ? null
          : {
              'low': predictions.reduce(math.min),
              'high': predictions.reduce(math.max),
              'label': '各阶段模型判断跨度，不是统计置信区间；LLM与JEV共享信息，不能当独立投票。',
            },
      'roots_and_experiments': roots,
      'decision_recommendation': recommendation,
      'weight_analysis': learnedAssociations(
        eligibleRows,
        growthMap(result['theory_factor_answers']),
      ),
      'calibration': result['probability_calibration'],
      'validation': result['forecast_validation'],
      'cycle_policy':
          '预测 → 检验原因假设 → 理解理论 → 记录态度与现实条件变化 → 确认后重预测 → 实际行动 → 复盘。没有新增事实就不重复刷分；合理停止、改目标或取消也是可选决策。成功标准与观察窗口改变时必须新建行动。',
      'precision_note':
          '百分比是待现实检验的估计。模型一致、讲解深入或态度自评分提高，都不等于行动已经改善；不保证找到唯一根因或最优方案。',
    };
  }
}
