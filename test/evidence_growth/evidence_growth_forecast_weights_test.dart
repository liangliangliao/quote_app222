import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_weights.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';

GrowthData factor(
  double importance,
  double support, {
  String group = '',
  bool unknown = false,
  double bottleneck = 0,
  bool grounded = true,
}) =>
    {
      'label': group,
      'theory_construct': group,
      'ai_importance': importance,
      'jev_importance': importance,
      'ai': support,
      'jev': support,
      'unknown': unknown,
      'evidence_status': unknown
          ? 'insufficient'
          : support > .5
              ? 'supportive'
              : 'adverse',
      'evidence': '用户确认的条件',
      'fact_grounded': grounded,
      'bottleneck_probability': bottleneck,
    };

void main() {
  test(
      'large action importance assessment is batched without losing core evidence',
      () async {
    var requests = 0;
    final jev = EvidenceGrowthJev(client: MockClient((request) async {
      requests++;
      expect(utf8.encode(request.body).length, lessThanOrEqualTo(64000));
      final body = growthMap(jsonDecode(request.body));
      return http.Response(
          jsonEncode({
            'model': 'test',
            'answers': {
              for (final q in growthMap(body['questions']).entries)
                q.key: switch (growthMap(q.value)['type']) {
                  'score' => {'type': 'score', 'score': 3, 'confidence': .8},
                  'noul' => {'type': 'noul', 'noul': .7},
                  _ => {
                      'type': 'choice',
                      'confidence': .8,
                      'choice':
                          growthMap(growthMap(q.value)['criteria']).keys.first
                    },
                },
            }
          }),
          200);
    }));
    final result = await jev.assessAction({
      'plan': '完成一个资源准备复杂的行动',
      'action_profile': {
        'dynamic_factors': [
          for (var i = 0; i < 24; i++)
            {
              'id': 'condition_$i',
              'label': '条件$i',
              'condition':
                'Distinct prerequisite $i: ${List.filled(150, 'x').join()}',
              'ibm_construct': 'environmental_constraints'
            },
        ]
      },
    }, apiKey: 'test');
    expect(result['status'], 'JEV', reason: '$result');
    expect(result['importance_batched'], isTrue);
    expect(result['importance_batch_complete'], isTrue);
    expect(growthMap(result['factor_importance']), hasLength(36));
    expect(growthMap(result['events']), isNotEmpty);
    expect(requests, greaterThan(1));
  });
  test('a severely adverse minor item cannot override important supports', () {
    final analysis = EvidenceForecastWeights.analyze({
      'intention': factor(.9, .9, group: 'intention'),
      'ability': factor(.8, .9, group: 'ability'),
      'habit': factor(.7, .9, group: 'habit'),
      'approval': factor(.05, .05, group: 'approval', bottleneck: .99),
    });
    final result = EvidenceForecastWeights.combine(
        analysis: analysis, llm: .85, jev: .54, adjudication: .48);
    expect(analysis['support_share'], greaterThan(.97));
    expect(analysis['probability_ceiling'], isNull);
    expect(result['probability'], greaterThan(.78));
    expect(result['probability'], lessThan(.9));
    expect(growthRows(analysis['factors']).last['key'], 'approval');
    expect(
        growthRows(result['components'])
            .where((r) => '${r['source']}'.startsWith('JEV'))
            .fold<double>(0, (sum, row) => sum + (row['weight'] as double)),
        lessThan(.3));
  });

  test('many supports do not erase one evidenced necessary failed condition',
      () {
    final analysis = EvidenceForecastWeights.analyze({
      'access': factor(.95, .05, group: 'access', bottleneck: .99),
      for (var i = 0; i < 12; i++)
        'support_$i': factor(.3, .95, group: 'support_$i'),
    });
    final result = EvidenceForecastWeights.combine(
        analysis: analysis, llm: .9, jev: .9, adjudication: .9);
    expect(analysis['support_share'], greaterThan(.75));
    expect(result['probability'], lessThan(.11));
    expect(result['ceiling_applied'], isTrue);
  });

  test('unverified adverse hypotheses cannot impose a prerequisite ceiling',
      () {
    final analysis = EvidenceForecastWeights.analyze({
      'guess':
          factor(.95, .05, group: 'guess', bottleneck: .99, grounded: false),
    });
    expect(analysis['probability_ceiling'], isNull);
    expect(analysis['critical_obstacles'], isEmpty);
  });

  test(
      'deduplication cannot hide a critical failed gate behind a supportive alias',
      () {
    final analysis = EvidenceForecastWeights.analyze({
      'resources': factor(1, .95, group: 'opportunity'),
      'permission': factor(.9, .05, group: 'opportunity', bottleneck: .99),
    });
    final result =
        EvidenceForecastWeights.combine(analysis: analysis, llm: .9, jev: .9);
    expect(growthRows(analysis['factors']), hasLength(1));
    expect(
        growthRows(analysis['critical_obstacles']).single['key'], 'permission');
    expect(result['probability'], lessThan(.16));
  });

  test(
      'unknown factors reduce evidence coverage without creating negative votes',
      () {
    final analysis = EvidenceForecastWeights.analyze({
      'known': factor(.8, .9, group: 'known'),
      'unknown': factor(.95, 0, group: 'unknown', unknown: true),
    });
    expect(analysis['support_index'], .9);
    expect(analysis['support_share'], 1);
    expect(analysis['opposing_share'], 0);
    expect(analysis['evidence_coverage'], lessThan(.5));
    expect(growthRows(analysis['factors']), hasLength(1));
  });

  test('overlapping theory constructs receive one budget', () {
    final one = EvidenceForecastWeights.analyze({
      'intention': factor(.9, .9, group: 'intention'),
      'habit': factor(.6, .3, group: 'habit'),
    });
    final duplicate = EvidenceForecastWeights.analyze({
      'intention': factor(.9, .9, group: 'intention'),
      'tpb_intention': factor(.9, .9, group: 'intention'),
      'habit': factor(.6, .3, group: 'habit'),
    });
    expect(duplicate['support_index'], one['support_index']);
    expect(growthRows(duplicate['factors']), hasLength(2));
    expect(
        growthRows(duplicate['factors'])
            .fold<double>(0, (sum, row) => sum + (row['weight'] as double)),
        closeTo(1, 1e-9));
  });

  test('importance changes priority independently of the current support score',
      () {
    GrowthData analyze(double adverseImportance) =>
        EvidenceForecastWeights.analyze({
          'favorable': factor(.8, .9, group: 'favorable'),
          'adverse': factor(adverseImportance, .1, group: 'adverse'),
        });
    expect(analyze(.9)['support_index'],
        lessThan(analyze(.1)['support_index'] as double));
    expect(growthRows(analyze(.9)['factors']).first['key'], 'adverse');
    expect(growthRows(analyze(.1)['factors']).first['key'], 'favorable');
  });

  test('pooling is symmetric and does not systematically inflate predictions',
      () {
    final positive =
        EvidenceForecastWeights.analyze({'x': factor(.7, .8, group: 'x')});
    final negative =
        EvidenceForecastWeights.analyze({'x': factor(.7, .2, group: 'x')});
    final a = EvidenceForecastWeights.combine(
        analysis: positive, llm: .9, jev: .55, adjudication: .6);
    final b = EvidenceForecastWeights.combine(
        analysis: negative, llm: .1, jev: .45, adjudication: .4);
    expect(a['probability'], closeTo(1 - (b['probability'] as double), 1e-9));
  });

  test(
      'old or malformed weights are explicit fallbacks, not invented coefficients',
      () {
    final analysis = EvidenceForecastWeights.analyze({
      'x': {
        'ai_importance': double.nan,
        'jev_importance': 9,
        'score': .1,
        'ordinal_level': 0
      },
    });
    final result = EvidenceForecastWeights.combine(
        analysis: analysis, llm: .8, jev: .5, adjudication: .57);
    expect(analysis['status'], 'UNASSESSED');
    expect(result['status'], 'WEIGHTS_UNAVAILABLE');
    expect(result['probability'], .57);
  });
}
