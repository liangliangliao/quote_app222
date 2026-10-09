import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_optimizer.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_science.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_weights.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_report_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_forecast.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_report.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';

GrowthData condition(
        {double importance = .9,
        String status = 'adverse',
        bool necessary = false,
        bool grounded = true,
        String group = 'opportunity'}) =>
    {
      'label': '进入场地的许可',
      'ai_importance': importance,
      'jev_importance': importance,
      'ai': status == 'supportive' ? .95 : .05,
      'jev': status == 'supportive' ? .95 : .05,
      'weight_group': group,
      'evidence_status': status,
      'unknown': status == 'insufficient',
      'necessary_prerequisite': necessary,
      'fact_grounded': grounded,
      'evidence': '已确认许可尚未通过',
      'bottleneck_probability': .95,
      'intervention': '核实许可，并提交所缺材料',
    };

// Controlled simulations test the learning mechanism. They are deliberately
// not represented as observations of any real user or reference person.
List<GrowthData> simulatedTrials({int count = 160, bool shift = false}) => [
      for (var i = 0; i < count; i++)
        {
          'id': 'simulation_$i',
          'trial_id': 'simulation_$i',
          'science_version': EvidenceForecastScience.version,
          'optimizer_version': EvidenceForecastOptimizer.version,
          'comparison_key': 'same-running-event',
          'model_signature': 'same-model',
          'event_contract': {
            'confirmed': true,
            'success_criterion': '跑步10分钟',
            'observation_window': '本次约定的一天',
            'context_class': '普通日常运动'
          },
          'created_at_ms': 1000 + i * 100,
          'outcome_at_ms': 1050 + i * 100,
          'outcome': 'SUCCESS',
          'primary_event_observed':
              shift && i >= (count * .6).floor() ? i.isOdd : i.isEven,
          'prediction_complete': true,
          'optimizer_components': {
            'LLM': i.isEven ? .9 : .1,
            'JEV': i.isEven ? .1 : .9
          },
          'raw_model_estimate': .5,
          'baseline_v3_estimate': .5,
          'estimate': .5,
        },
    ];

void main() {
  test('factor scores alone can never manufacture an event probability', () {
    final analysis =
        EvidenceForecastWeights.analyze({'f': condition(status: 'supportive')});
    expect(analysis['support_index'], isNotNull);
    expect(
        EvidenceForecastOptimizer.aggregate(analysis: analysis)['probability'],
        isNull);
  });

  test(
      'factor support is diagnostic and does not inject ordinal values into probability',
      () {
    final favorable =
        EvidenceForecastWeights.analyze({'f': condition(status: 'supportive')});
    final adverse = EvidenceForecastWeights.analyze({'f': condition()});
    final a = EvidenceForecastOptimizer.aggregate(
        analysis: favorable, llm: .8, jev: .6);
    final b = EvidenceForecastOptimizer.aggregate(
        analysis: adverse, llm: .8, jev: .6);
    expect(a['probability'], closeTo(.7, 1e-9));
    expect(b['probability'], a['probability']);
    expect(growthRows(a['components']).map((r) => r['source']), ['LLM', 'JEV']);
  });

  test('two dependent JEV passes share one model-family budget', () {
    final once =
        EvidenceForecastOptimizer.aggregate(analysis: {}, llm: .9, jev: .1);
    final twice = EvidenceForecastOptimizer.aggregate(
        analysis: {}, llm: .9, jev: .1, review: .1);
    expect(twice['probability'], once['probability']);
    expect(growthRows(twice['components']), hasLength(2));
  });

  test(
      'importance alone cannot turn motivation or social approval into a necessary gate',
      () {
    final f = condition(group: 'motivation');
    final analysis = EvidenceForecastWeights.analyze({'f': f});
    expect(analysis['probability_ceiling'], isNull);
    expect(
        EvidenceForecastOptimizer.aggregate(
            analysis: analysis, llm: .9, jev: .9)['probability'],
        .9);
  });

  test('an evidenced necessary prerequisite still restricts an optimistic pool',
      () {
    final analysis =
        EvidenceForecastWeights.analyze({'f': condition(necessary: true)});
    final result = EvidenceForecastOptimizer.aggregate(
        analysis: analysis, llm: .9, jev: .95);
    expect(result['probability'], lessThan(.25));
    expect(result['ceiling_applied'], isTrue);
  });

  test('speculative prerequisites and minor obstacles cannot impose ceilings',
      () {
    for (final f in [
      condition(necessary: true, grounded: false),
      condition(necessary: true, importance: .05)
    ]) {
      final analysis = EvidenceForecastWeights.analyze({'f': f});
      expect(analysis['probability_ceiling'], isNull);
    }
  });

  test(
      'convex event pooling treats optimistic and pessimistic changes symmetrically',
      () {
    final low =
        EvidenceForecastOptimizer.aggregate(analysis: {}, llm: .2, jev: .4);
    final high =
        EvidenceForecastOptimizer.aggregate(analysis: {}, llm: .8, jev: .6);
    expect((low['probability'] as double) + (high['probability'] as double),
        closeTo(1, 1e-9));
  });

  test(
      'temporally validated stacking exceeds the 10 percent target in a controlled simulation',
      () {
    final result = EvidenceForecastOptimizer.aggregate(
        analysis: {}, llm: .9, jev: .1, eligibleRows: simulatedTrials());
    final learned = growthMap(result['pool_learning']);
    expect(learned['status'], 'TEMPORALLY_VALIDATED_POOL');
    expect(learned['llm_weight'], .9);
    final audit = growthMap(learned['validation']);
    expect(audit['target_verified'], isTrue);
    expect(audit['relative_brier_reduction'], greaterThan(.10));
    expect(growthMap(audit['relative_brier_reduction_interval'])['low'],
        greaterThan(.10));
    expect(result['probability'], closeTo(.82, 1e-9));
  });

  test('a shifted chronological holdout rejects learned weights', () {
    final result = EvidenceForecastOptimizer.aggregate(
        analysis: {},
        llm: .9,
        jev: .1,
        eligibleRows: simulatedTrials(shift: true));
    expect(growthMap(result['pool_learning'])['status'], 'REJECTED_ON_HOLDOUT');
    expect(result['probability'], .5);
  });

  test('the learner also favors JEV when its real-outcome component is better',
      () {
    final rows = simulatedTrials();
    for (final r in rows) {
      final c = growthMap(r['optimizer_components']);
      r['optimizer_components'] = {'LLM': c['JEV'], 'JEV': c['LLM']};
    }
    final result = EvidenceForecastOptimizer.aggregate(
        analysis: {}, llm: .1, jev: .9, eligibleRows: rows);
    expect(growthMap(result['pool_learning'])['llm_weight'], .1);
    expect(result['probability'], closeTo(.82, 1e-9));
  });

  test(
      'fitting cannot use training outcomes observed after holdout predictions',
      () {
    final rows = simulatedTrials();
    for (final r in rows.take(96)) {
      r['outcome_at_ms'] = 999999;
    }
    final learned = EvidenceForecastOptimizer.learnedPool(rows);
    expect(learned['status'], 'INSUFFICIENT_TEMPORAL_SEPARATION');
  });

  test(
      'unknown components and another optimizer version cannot train this pool',
      () {
    final rows = simulatedTrials();
    for (final r in rows) {
      r['optimizer_version'] = 'another-version';
    }
    expect(EvidenceForecastOptimizer.learnedPool(rows)['sample_count'], 0);
    for (final r in rows) {
      r['optimizer_version'] = EvidenceForecastOptimizer.version;
      r['optimizer_components'] = {'LLM': .8};
    }
    expect(EvidenceForecastOptimizer.learnedPool(rows)['sample_count'], 0);
  });

  test('paired verification reports Brier, log loss and accuracy separately',
      () {
    final audit = EvidenceForecastScience.compareProbabilities([
      for (var i = 0; i < 80; i++)
        {
          'baseline': .5,
          'candidate': i.isEven ? .8 : .2,
          'outcome': i.isEven ? 1 : 0
        },
    ]);
    expect(audit['target_verified'], isTrue);
    expect(audit['baseline_brier'], .25);
    expect(audit['candidate_brier'], closeTo(.04, 1e-9));
    expect(audit['relative_brier_reduction'], closeTo(.84, 1e-9));
    expect(audit['baseline_accuracy'], .5);
    expect(audit['candidate_accuracy'], 1);
    expect(audit['accuracy_point_change'], .5);
  });

  test(
      'no data, one outcome class and zero baseline loss never verify improvement',
      () {
    expect(EvidenceForecastScience.compareProbabilities([])['target_verified'],
        isFalse);
    final oneClass = EvidenceForecastScience.compareProbabilities([
      for (var i = 0; i < 100; i++)
        {'baseline': .6, 'candidate': .9, 'outcome': 1},
    ]);
    expect(oneClass['status'], 'INSUFFICIENT_REAL_OUTCOMES');
    final zero = EvidenceForecastScience.compareProbabilities([
      for (var i = 0; i < 80; i++)
        {
          'baseline': i.isEven ? 1 : 0,
          'candidate': i.isEven ? 1 : 0,
          'outcome': i.isEven ? 1 : 0
        },
    ]);
    expect(zero['status'], 'ZERO_BASELINE_ERROR');
    expect(zero['relative_brier_reduction'], isNull);
  });

  test(
      'better binary accuracy alone does not verify the probability improvement target',
      () {
    final audit = EvidenceForecastScience.compareProbabilities([
      for (var i = 0; i < 80; i++)
        {
          'baseline': i.isEven ? .51 : .49,
          'candidate': i.isEven ? .52 : .48,
          'outcome': i.isEven ? 1 : 0
        },
    ]);
    expect(audit['candidate_accuracy'], 1);
    expect(audit['target_verified'], isFalse);
  });

  test(
      'prospective pairing excludes partial, hypothetical, censored and future trials',
      () {
    final rows = simulatedTrials(count: 8);
    rows[0]['prediction_complete'] = false;
    rows[1]['hypothetical'] = true;
    rows[2]['outcome'] = 'CANCELLED';
    rows[3]['outcome_at_ms'] = 999999;
    rows[4]['model_signature'] = 'different-model';
    final eligible = EvidenceForecastScience.eligible(rows,
        key: 'same-running-event', signature: 'same-model', beforeMs: 10000);
    expect(eligible, hasLength(3));
    expect(EvidenceForecastOptimizer.performance(eligible)['count'], 3);
  });

  test(
      'placeholder contracts cannot contaminate empirical accuracy or calibration',
      () {
    for (final placeholder in ['无', '未知', 'none', 'N/A']) {
      expect(
          EvidenceForecastScience.validContract({
            'confirmed': true,
            'success_criterion': placeholder,
            'observation_window': '明天一天'
          }),
          isFalse);
    }
    expect(
        EvidenceForecastScience.validContract({
          'confirmed': true,
          'success_criterion': '没有吸烟',
          'observation_window': '明天一天'
        }),
        isTrue);
  });

  test(
      'guidance prioritizes necessary prerequisites and keeps unknowns as questions',
      () {
    final factors = <String, GrowthData>{
      'permission': condition(necessary: true),
      'approval': condition(importance: .05, group: 'norm'),
      'skill': {
        ...condition(status: 'insufficient', group: 'skill'),
        'label': '必要技能'
      },
    };
    final result = EvidenceForecastOptimizer.guidance(
        factors: factors,
        analysis: EvidenceForecastWeights.analyze(factors),
        proposed: [
          {
            'factor_id': 'permission',
            'cue': '确认缺少许可材料时',
            'first_step': '补交申请材料',
            'fallback': '向管理人员核对申请进度',
            'check': '收到明确许可后再按原标准行动'
          },
          {'factor_id': 'invented', 'first_step': '编造的步骤'},
        ]);
    final steps = growthRows(result['steps']);
    expect(steps, hasLength(1));
    expect(steps.first['priority'], 'PREREQUISITE');
    expect(steps.first['plan'], '当确认缺少许可材料时，就补交申请材料');
    expect(steps.first['check'], contains('原标准'));
    expect(growthRows(result['verification_questions']).single['factor_id'],
        'skill');
  });

  test('reference JEV state omits every peer score and behavioral conclusion',
      () {
    final state = EvidenceGrowthReferenceForecast.independentJudgeState({
      'reference_mode': 'PERSON',
      'person_identity': '测试人物'
    }, {
      'execution_likelihood': .85,
      'likely_behavior': '一定会做',
      'likely_attitude': '强烈支持',
      'theory_explanation': '断言会执行',
      'claims': [
        {
          'id': 'claim_1',
          'claim': '公开作品提倡运动',
          'importance': .9,
          'support_score': .95,
          'direction': 'supportive',
          'quote': '提倡日常运动',
          'evidence_scope': 'ATTITUDE_ONLY'
        }
      ],
    }, [
      {'id': 'book', 'title': '测试作品', 'content': '提倡日常运动'}
    ]);
    final text = jsonEncode(state);
    for (final forbidden in [
      'execution_likelihood',
      'likely_behavior',
      'support_score',
      'theory_explanation',
      '一定会做',
      '断言会执行',
      '0.85'
    ]) {
      expect(text, isNot(contains(forbidden)));
    }
    expect(text, contains('提倡日常运动'));
  });

  test(
      'authored philosophy and past failure cannot prove a current failed prerequisite',
      () {
    for (final kind in ['AUTHORED_WORK', 'PAST_BEHAVIOR']) {
      final p = EvidenceGrowthReferenceForecast.normalizeProfile({
        'claims': [
          {
            'claim': '测试说法',
            'source_id': 's',
            'quote': '过去没有条件执行',
            'evidence_kind': kind,
            'necessary_prerequisite': true,
            'importance': .95,
            'support_score': .05,
            'direction': 'adverse'
          },
        ]
      }, [
        {'id': 's', 'kind': 'PUBLISHED_WORKS_COLLECTION', 'content': '过去没有条件执行'}
      ]);
      expect(growthRows(p['claims']).single['necessary_prerequisite'], isFalse);
      final result = EvidenceGrowthReferenceForecast.assemble(
          input: {},
          profile: {
            ...p,
            'execution_likelihood': .85,
          },
          sources: [],
          model: 'test',
          jev: {
            'status': 'JEV',
            'answers': {
              'event': .85,
              'hard_blocker': .99,
            }
          });
      expect(result['estimate'], .85);
    }
  });

  test('reference can retain a clearly labelled LLM estimate after JEV failure',
      () {
    final result = EvidenceGrowthReferenceForecast.assemble(
        input: {},
        profile: {
          'execution_likelihood': .85,
        },
        sources: [],
        model: 'test',
        jev: {'status': 'UNAVAILABLE', 'reason': 'HTTP_503'});
    expect(result['estimate'], .85);
    expect(result['preliminary'], isTrue);
    expect(ReferenceForecastReport.markdown(result), contains('初步估计（仅LLM）'));
    expect(growthMap(result['performance_comparison'])['target_verified'],
        isFalse);
  });

  test(
      'reference source excerpts include late relevant passages within a bounded payload',
      () {
    final content = '${List.filled(1500, '背景').join()}\n当前事实：今天许可已通过，跑步路线可用。';
    final profile = EvidenceGrowthReferenceForecast.normalizeProfile({
      'claims': [
        {
          'claim': '当前具备路线许可',
          'source_id': 's',
          'quote': '今天许可已通过，跑步路线可用',
          'evidence_kind': 'CURRENT_CONDITION'
        },
      ]
    }, [
      {'id': 's', 'content': content, 'kind': 'USER_SUPPLIED'}
    ]);
    final state = EvidenceGrowthReferenceForecast.independentJudgeState(
        {},
        profile,
        [
          {'id': 's', 'content': content, 'kind': 'USER_SUPPLIED'}
        ]);
    final excerpt = '${growthRows(state['sources']).single['content_excerpt']}';
    expect(excerpt, contains('今天许可已通过'));
    expect(excerpt.length, lessThanOrEqualTo(1200));
  });

  test(
      'scenario sensitivity compares the same JEV review instead of the pooled score',
      () {
    final report = EvidenceForecastScience.report({
      'raw_model_estimate': .5,
      'forecast_provenance': {'jev_final_synthesis_probability': .3},
      'behavior_diagnosis': {
        'theory_feedback_analysis': {
          'llm_candidate_conclusions': [
            {'id': 'c', 'minimum_action': '补交许可材料'}
          ],
          'jev_final_adjudication': {
            'candidate_catalog': [
              {'id': 'c', 'key': 'k'}
            ],
            'intervention_probabilities': {'k': .7},
          },
        }
      },
    }, []);
    expect(
        growthRows(report['roots_and_experiments'])
            .single['model_sensitivity_delta'],
        closeTo(.4, 1e-9));
  });

  testWidgets(
      'new actionable guidance and verification render on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prediction = <String, dynamic>{
      'estimate': .7,
      'plan': '明天跑步10分钟',
      'outcome': 'PENDING',
      'action_guidance': {
        'steps': [
          {
            'priority': 'ACTION',
            'label': '启动线索',
            'plan': '当到达已确认的行动时段，就穿鞋出门',
            'fallback': '先检查原路线是否可用',
            'check': '在原窗口完成跑步10分钟',
            'basis': '有已提供的依据'
          }
        ],
        'verification_questions': [
          {'question': '明天约定时段路线是否可用？'}
        ],
      },
      'performance_comparison':
          EvidenceForecastScience.compareProbabilities([]),
    };
    final report = EvidenceGrowthForecastReportPage.markdown(prediction);
    expect(report, contains('穿鞋出门'));
    expect(report, contains('原窗口完成跑步10分钟'));
    expect(report, contains('明天约定时段路线是否可用'));
    await tester.pumpWidget(MaterialApp(
        home: EvidenceGrowthForecastReportPage(prediction: prediction)));
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('a later optional reference batch failure preserves the primary event',
      () async {
    var batches = 0;
    final jev = EvidenceGrowthJev(client: MockClient((request) async {
      batches++;
      if (batches == 2) return http.Response('{}', 503);
      return http.Response(
          jsonEncode({
            'answers': {
              for (final k
                  in growthMap(growthMap(jsonDecode(request.body))['questions'])
                      .keys)
                k: {'type': 'noul', 'noul': .8},
            }
          }),
          200);
    }));
    final result = await jev.assessForecastQuestions(state: {}, questions: {
      'event': {'type': 'noul'},
      for (var i = 0; i < 30; i++) 'extra_$i': {'type': 'noul'},
    }, apiKey: 'test');
    expect(result['status'], 'JEV');
    expect(growthMap(result['answers'])['event'], .8);
    expect(result['optional_batches_complete'], isFalse);
  });

  test(
      'report shows insufficient verification and deterioration without inflated percentages',
      () {
    expect(
        EvidenceGrowthForecastReportPage.improvementNote({
          'performance_comparison':
              EvidenceForecastScience.compareProbabilities([]),
        }),
        contains('待验证'));
    expect(
        EvidenceGrowthForecastReportPage.improvementNote({
          'performance_comparison': {
            'count': 80,
            'status': 'TARGET_NOT_DEMONSTRATED',
            'relative_brier_reduction': -.2,
            'target_verified': false
          },
        }),
        contains('增加20.0%'));
  });
}
