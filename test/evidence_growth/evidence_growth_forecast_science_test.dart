import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_review.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_review_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_report_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_science.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_forecast.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_forecast_page.dart';
import 'package:quote_app/services/unified_ai_service.dart';

final contract = EvidenceForecastScience.contract({
  'success_criterion': '完成登记',
  'observation_window': '预约前30分钟',
  'context_class': '同一通勤与预约条件',
  'confirmed': true,
});

GrowthData trial(int i, {double raw = .9, bool? event}) => {
      'id': 'p$i',
      'trial_id': 't$i',
      'science_version': EvidenceForecastScience.version,
      'event_contract': contract,
      'comparison_key': 'key',
      'model_signature': 'model',
      'created_at_ms': 1000 + i * 100,
      'outcome_at_ms': 1050 + i * 100,
      'outcome': (event ?? i.isEven) ? 'SUCCESS' : 'FAILED',
      'primary_event_observed': event ?? i.isEven,
      'raw_model_estimate': raw,
      'estimate': raw,
      'theory_factor_answers': {
        'intention': {
          'option_id': (event ?? i.isEven) ? 'firm' : 'none',
          'confirmed_by_user': true
        }
      },
    };

class TestAi extends UnifiedAiService {
  TestAi(this.respond);
  final String Function(String purpose, String prompt) respond;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'fake',
          apiKey: 'test',
          model: 'fake',
          endpoint: '',
          label: 'test',
          displayModel: 'fake-v1',
          available: true);
  @override
  Future<String> generateText(
          {required String prompt,
          required String purpose,
          String? systemPrompt,
          int maxTokens = 1800,
          bool expectJson = false,
          String? forcedProvider,
          String? forcedModel,
          double? temperature}) async =>
      respond(purpose, prompt);
}

class MemoryForecastDao extends EvidenceGrowthDao {
  MemoryForecastDao()
      : super(database: () => throw StateError('No database in widget test'));
  final settings = <String, String>{};
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async =>
      settings[key] ?? fallback;
  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }
}

void main() {
  setUpAll(sqfliteFfiInit);
  Future<EvidenceGrowthDao> dao() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final d = EvidenceGrowthDao(database: () async => db);
    await d.ensureTables();
    return d;
  }

  test(
      'pooling requires same explicit event, window and context; no tag shortcut',
      () {
    final key = EvidenceForecastScience.comparisonKey(contract, 'START');
    expect(key, isNotEmpty);
    expect(
        EvidenceForecastScience.comparisonKey(
            {...contract, 'success_criterion': '起床'}, 'START'),
        isNot(key));
    expect(
        EvidenceForecastScience.comparisonKey(
            {...contract, 'observation_window': '一天内'}, 'START'),
        isNot(key));
    expect(
        EvidenceForecastScience.comparisonKey(
            {...contract, 'context_class': ''}, 'START'),
        isEmpty);
    expect(
        EvidenceForecastScience.comparisonKey(
            {...contract, 'confirmed': false}, 'START'),
        isEmpty);
  });

  test(
      'calibration excludes duplicates, pending revisions, censoring, future data and different model',
      () {
    final rows = <GrowthData>[
      trial(1),
      {...trial(1), 'id': 'revision', 'created_at_ms': 1101, 'estimate': .4},
      trial(2),
      {
        ...trial(2),
        'id': 'pending',
        'created_at_ms': 1201,
        'primary_event_observed': null,
        'outcome': 'PENDING'
      },
      {...trial(3), 'comparison_key': 'other'},
      {...trial(4), 'model_signature': 'other'},
      {...trial(5), 'hypothetical': true},
      {...trial(6), 'science_version': 'legacy'},
      {...trial(7), 'primary_event_observed': null, 'outcome': 'CANCELLED'},
      {...trial(8), 'outcome_at_ms': 1500}, // Before its prediction.
      {...trial(9), 'outcome_at_ms': 20000},
    ];
    final eligible = EvidenceForecastScience.eligible(rows,
        key: 'key', signature: 'model', beforeMs: 10000);
    expect(eligible.map((r) => r['id']), ['revision']);
    expect(
        EvidenceForecastScience.eligible(rows,
            key: '', signature: 'model', beforeMs: 10000),
        isEmpty);
  });

  test(
      'partial outcome only enters binary metrics with explicit frozen-event observation',
      () {
    expect(
        EvidenceForecastScience.outcome({
          ...trial(1),
          'outcome': 'PARTIAL',
          'primary_event_observed': null
        }),
        isNull);
    expect(
        EvidenceForecastScience.outcome({
          ...trial(1),
          'outcome': 'PARTIAL',
          'primary_event_observed': true
        }),
        1);
    expect(
        EvidenceForecastScience.outcome({
          ...trial(1),
          'outcome': 'PARTIAL',
          'primary_event_observed': false
        }),
        0);
  });

  test(
      'calibration uses independent chronological holdout and improves a biased raw forecast',
      () {
    final rows = List.generate(100, (i) => trial(i));
    final calibrated = EvidenceForecastScience.calibrate(.9, rows);
    expect(calibrated['status'], 'PERSONAL_PLATT_CALIBRATED');
    expect(calibrated['holdout_count'], 30);
    expect(calibrated['probability'], inInclusiveRange(.45, .65));
    expect(growthMap(calibrated['holdout_calibrated'])['brier'],
        lessThan(growthMap(calibrated['holdout_raw'])['brier']));
    expect(
        EvidenceForecastScience.calibrate(.9, rows.take(30).toList())['status'],
        'UNCALIBRATED');
  });

  test(
      'a correct raw forecast is retained when calibration offers no holdout improvement',
      () {
    final rows = List.generate(100, (i) => trial(i, raw: i.isEven ? .99 : .01));
    final calibrated = EvidenceForecastScience.calibrate(.7, rows);
    expect(calibrated['status'], 'CALIBRATION_REJECTED_ON_HOLDOUT');
    expect(calibrated['probability'], .7);
  });

  test(
      'overlapping trials cannot leak future outcomes into temporal validation',
      () {
    final rows = List.generate(100,
        (i) => {...trial(i), 'created_at_ms': 1000, 'outcome_at_ms': 2000 + i});
    expect(EvidenceForecastScience.calibrate(.9, rows)['status'],
        'INSUFFICIENT_TEMPORAL_SEPARATION');
  });

  test(
      'weight learner uses observed categories and refuses sparse or unhelpful data',
      () {
    final rows = List.generate(160, (i) => trial(i, raw: .5));
    final learned = EvidenceForecastScience.learnedAssociations(rows, {
      'intention': {'option_id': 'firm', 'confirmed_by_user': true}
    });
    expect(learned['status'], 'EXPLORATORY_VALIDATED_ASSOCIATIONS');
    final coefficients = growthRows(learned['coefficients']);
    expect(
        coefficients.firstWhere((c) => c['option_id'] == 'firm')['coefficient'],
        greaterThan(0));
    expect(
        coefficients.firstWhere((c) => c['option_id'] == 'none')['coefficient'],
        lessThan(0));
    expect(
        EvidenceForecastScience.learnedAssociations(
            rows.take(50).toList(), {})['coefficients'],
        isEmpty);
    final unrelated = List.generate(
        160,
        (i) => {
              ...trial(i, raw: .5),
              'theory_factor_answers': {
                'intention': {
                  'option_id': i % 4 < 2 ? 'firm' : 'none',
                  'confirmed_by_user': true
                }
              }
            });
    expect(EvidenceForecastScience.learnedAssociations(unrelated, {})['status'],
        'REJECTED_ON_HOLDOUT');
  });

  test(
      'reported Brier uses paired rows and probability bins keep sparse counts visible',
      () {
    final report = EvidenceForecastScience.validation(
        [trial(0, raw: .8, event: true), trial(1, raw: .8, event: false)]);
    expect(report['final_brier'], closeTo(.34, 1e-9));
    expect(report['observed_rate'], .5);
    expect(growthRows(report['reliability_bins']).last['count'], 2);
  });

  test(
      'typed JEV parser rejects non-finite values, unknown choices and missing answers',
      () {
    final qs = <String, dynamic>{
      'p': {'type': 'noul'},
      'q': {
        'type': 'choice',
        'criteria': {'ok': 'ok'}
      }
    };
    GrowthData body(Object? p, String q) => {
          'answers': {
            'p': {'type': 'noul', 'noul': p},
            'q': {'type': 'choice', 'choice': q, 'confidence': .8}
          }
        };
    expect(
        () => EvidenceGrowthJev.parseForecastQuestions(
            body(double.nan, 'ok'), qs),
        throwsFormatException);
    expect(
        () =>
            EvidenceGrowthJev.parseForecastQuestions(body(.5, 'invented'), qs),
        throwsFormatException);
    expect(() => EvidenceGrowthJev.parseForecastQuestions({'answers': {}}, qs),
        throwsFormatException);
    expect(
        growthMap(EvidenceGrowthJev.parseForecastQuestions(
            body(.2, 'ok'), qs)['answers'])['p'],
        .2);
  });

  test(
      'reference personality claims need actual source quotes; fabricated sources remain assumptions',
      () {
    final p = EvidenceGrowthReferenceForecast.normalizeProfile({
      'claims': [
        {'claim': '过去按时参加了三次训练', 'source_id': 'u', 'quote': '按时参加三次训练'},
        {'claim': '从不拖延', 'source_id': 'invented-url', 'quote': '从不拖延'},
        {'claim': '未知性格', 'source_id': 'u', 'quote': '不存在的引文'},
      ]
    }, [
      {'id': 'u', 'content': '记录显示他按时参加三次训练。'}
    ]);
    final claims = growthRows(p['claims']);
    expect(claims.first['evidence_status'], 'SOURCE_LINKED');
    expect(
        claims.skip(1).every((c) => c['evidence_status'] == 'MODEL_ASSUMPTION'),
        isTrue);
  });

  test(
      'name-only person forecast suppresses a high JEV score and never poses as a precise estimate',
      () {
    final jev = {
      'status': 'JEV',
      'answers': {
        'event': .97,
        'evidence_quality': {'choice': 'adequate_for_rough_estimate'}
      }
    };
    final output = EvidenceGrowthReferenceForecast.assemble(
        input: {'reference_mode': 'PERSON', 'identity_confirmed': true},
        profile: {'claims': []},
        sources: [],
        jev: jev,
        model: 'fake');
    expect(output['estimate_available'], isFalse);
    expect(output['estimate'], isNull);
    final world = EvidenceGrowthReferenceForecast.assemble(
        input: {'reference_mode': 'WORLD'},
        profile: {},
        sources: [],
        jev: jev,
        model: 'fake');
    expect(world['estimate'], .97);
    expect(world['kind'], 'REFERENCE_COUNTERFACTUAL');
    expect('${world['note']}', contains('不能称为全球真实发生率'));
  });

  test(
      'same event intervention questions preserve constraints and include root alternatives',
      () {
    final request = EvidenceGrowthJev.theorySynthesisRequest(
        state: {
          'plan': '登记',
          'event_contract': contract,
          'action_profile': {
            'forecast_events': [
              {
                'id': 'event',
                'label': '完成登记',
                'primary': true,
                'true_criterion': '预约前30分钟完成登记'
              }
            ]
          }
        },
        theoryFeedbackRows: [],
        firstPassJev: {},
        model: 'fake',
        llmSynthesis: {
          'core_conclusions': [
            {
              'id': 'h1',
              'title': '触发不足',
              'factor_ids': ['intention'],
              'root_cause_hypothesis': '情境不明确',
              'alternative_explanation': '交通受阻',
              'changed_conditions': ['提前备好材料']
            }
          ]
        });
    final qs = growthMap(request['questions']);
    expect(
        qs.keys,
        containsAll([
          'root_evidence_candidate_1',
          'intervention_feasible_candidate_1',
          'intervention_event_candidate_1'
        ]));
    expect('${growthMap(qs['intervention_event_candidate_1'])['instructions']}',
        contains('keep the original success criterion'));
    expect(
        growthMap(
            growthMap(request['state'])['action_prediction'])['event_contract'],
        contract);
  });

  test(
      'snapshot writes prevent overwriting, same-fact reruns and superseded outcome duplication',
      () async {
    final d = await dao();
    final service = EvidenceGrowthActionPredictionService(dao: d);
    final original = {
      ...trial(1),
      'outcome': 'PENDING',
      'primary_event_observed': null,
      'input_fingerprint': 'same',
      'pipeline_status': 'COMPLETE',
      'scheduled_at_ms': 1
    };
    await service.savePrediction(original);
    await expectLater(service.savePrediction(original), throwsStateError);
    await expectLater(
        service.savePrediction({
          ...original,
          'id': 'p2',
          'parent_prediction_id': 'p1',
          'created_at_ms': 1200
        }),
        throwsStateError);
    await service.savePrediction({
      ...original,
      'id': 'p2',
      'parent_prediction_id': 'p1',
      'created_at_ms': 1200,
      'input_fingerprint': 'changed'
    });
    await expectLater(
        service.recordOutcome('p1', 'SUCCESS', primaryEventObserved: true),
        throwsStateError);
    await service.recordOutcome('p2', 'PARTIAL');
    expect(EvidenceForecastScience.outcome((await service.history()).first),
        isNull);
    await service.recordOutcome('p2', 'SUCCESS', primaryEventObserved: true);
    await service.saveReview('p2', {
      'status': 'DRAFT',
      'user_observations': {'timeline': '完成登记'}
    });
    final saved = (await service.history()).first;
    expect(saved['estimate'], original['estimate']);
    expect(growthMap(saved['event_contract']), contract);
    expect(growthMap(saved['diagnostic_review'])['status'], 'DRAFT');
  });

  for (final failFinal in [false, true]) {
    test(
        'full prediction pipeline preserves event and partial work: failFinal=$failFinal',
        () async {
      final d = MemoryForecastDao();
      var aiCalls = 0;
      var jevCalls = 0;
      final ai = TestAi((purpose, prompt) {
        aiCalls++;
        expect(prompt, contains('完成登记'));
        if (purpose == 'evidence_growth.action_prediction') {
          return jsonEncode({
            'execution_likelihood': .8,
            'summary': '已有明确行动意向',
            'factors': {
              for (final key
                  in EvidenceGrowthActionPredictionService.factorLabels.keys)
                key: {
                  'score': .9,
                  'confidence': .8,
                  'status': 'SUPPORT',
                  'evidence': '已确认意向坚定'
                }
            }
          });
        }
        expect(purpose,
            'evidence_growth.action_prediction.theory_feedback_synthesis');
        return jsonEncode({
          'pattern_code': 'insufficient_evidence',
          'integrated_pattern': '意向明确，现实准备仍待确认',
          'core_conclusions': [
            {
              'title': '先核实准备情况',
              'factor_ids': ['intention'],
              'theory_ids': ['TPB'],
              'root_cause_hypothesis': '行动线索尚不明确',
              'alternative_explanation': '外部交通变化',
              'falsifier': '已明确线索且按时启动',
              'changed_conditions': ['备好材料'],
              'minimum_action': '检查材料清单',
            }
          ],
        });
      });
      final jev = EvidenceGrowthJev(client: MockClient((request) async {
        jevCalls++;
        final body = growthMap(jsonDecode(request.body));
        final qs = growthMap(body['questions']);
        final isFinal = qs.containsKey('synthesis_event_probability');
        final requestState = growthMap(body['state']);
        expect(growthMap(requestState['action_prediction'])['event_contract'],
            contract);
        if (isFinal && failFinal) return http.Response('{}', 503);
        return http.Response(
            jsonEncode({
              'model': 'jev-fixed-test',
              'answers': {
                for (final e in qs.entries)
                  e.key: switch (growthMap(e.value)['type']) {
                    'noul' => {
                        'type': 'noul',
                        'noul':
                            e.key == 'synthesis_event_probability' ? .57 : .42
                      },
                    'score' => {'type': 'score', 'score': 2, 'confidence': .7},
                    _ => {
                        'type': 'choice',
                        'choice': growthMap(growthMap(e.value)['criteria'])
                            .keys
                            .first,
                        'confidence': .8
                      },
                  },
              },
            }),
            200);
      }));
      final service =
          EvidenceGrowthActionPredictionService(dao: d, ai: ai, jev: jev);
      await expectLater(
          service.predict(
              plan: '已经过期的行动',
              scheduledAt: DateTime.now().subtract(const Duration(days: 1))),
          throwsArgumentError);
      expect(aiCalls, 0);
      expect(jevCalls, 0);
      final profile = <String, dynamic>{
        'analysis_status': 'READY',
        'action_mode': 'START',
        'action_tags': ['登记'],
        'forecast_events': [
          {'id': 'old_event', 'primary': true, 'label': '旧模型事件'}
        ],
        'theory_factor_questionnaire': [
          {
            'id': 'intention',
            'label': '意向',
            'theory_ids': ['TPB']
          }
        ],
      };
      final answers = <String, dynamic>{
        'intention': {'option_id': 'firm', 'confirmed_by_user': true}
      };
      final output = await service.predict(
          plan: '去登记',
          actionProfile: profile,
          eventContract: contract,
          selectedTheoryIds: ['TPB'],
          theoryFactorAnswers: answers,
          jevApiKey: 'test',
          requireJev: true);
      expect(aiCalls, 2);
      expect(jevCalls, 2, reason: '${output['pipeline_errors']}');
      expect(output['pipeline_status'], failFinal ? 'PARTIAL' : 'COMPLETE');
      expect(output['estimate'], failFinal ? null : .57);
      expect(output['event_contract'], contract);
      expect(growthMap(output['ai'])['status'], 'AI',
          reason: '${output['ai']}');
      expect(
          growthRows(
              growthMap(output['scientific_report'])['roots_and_experiments']),
          hasLength(1));
      await service.savePrediction(output);
      expect(await service.history(), hasLength(1));
      if (!failFinal) {
        await expectLater(
            service.predict(
                plan: '去登记',
                actionProfile: profile,
                eventContract: contract,
                selectedTheoryIds: ['TPB'],
                theoryFactorAnswers: answers,
                jevApiKey: 'test',
                requireJev: true,
                cycleContext: {
                  'trial_id': output['trial_id'],
                  'parent_prediction_id': output['id']
                }),
            throwsStateError);
        expect(aiCalls, 2,
            reason: 'unchanged revisions must fail before paid calls');
        expect(jevCalls, 2);
      }
    });
  }

  test('final optional adjudication rejects choices outside its requested enum',
      () {
    final parsed = EvidenceGrowthJev.parseTheorySynthesis({
      'answers': {
        'synthesis_event_probability': {'type': 'noul', 'noul': .6},
        'synthesis_quality': {
          'type': 'choice',
          'choice': 'joint_supported',
          'confidence': .8
        },
        'recommended_intervention': {
          'type': 'choice',
          'choice': 'invented',
          'confidence': 1
        },
      },
    }, questions: {
      'recommended_intervention': {
        'criteria': {'clarify': 'Clarify'}
      }
    });
    expect(parsed['final_event_probability'], .6);
    expect(parsed['recommended_intervention'], isEmpty);
    expect(parsed['parse_warnings'],
        contains('INVALID_CHOICE_recommended_intervention'));
    expect(
        EvidenceForecastScience.outcome({
          ...trial(1),
          'outcome': 'CANCELLED',
          'primary_event_observed': true
        }),
        isNull);
  });

  test(
      'public biography lookup is bounded to public hosts, disambiguation is rejected',
      () async {
    final d = await dao();
    final service = EvidenceGrowthReferenceForecast(
        dao: d,
        client: MockClient((request) async {
          expect(request.url.host, 'zh.wikipedia.org');
          return http.Response(
              jsonEncode({
                'query': {
                  'pages': [
                    {
                      'pageid': 1,
                      'pageprops': {'disambiguation': ''},
                      'extract': '同名'
                    }
                  ]
                }
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await expectLater(
        service.readPublicPerson({'page_id': 1, 'language': 'zh'}),
        throwsStateError);
    await expectLater(
        service.searchPublicPerson('x', language: 'http://localhost'),
        throwsArgumentError);
  });

  test(
      'delayed outcome entry uses actual observation time to exclude hindsight',
      () async {
    final d = MemoryForecastDao();
    final service = EvidenceGrowthActionPredictionService(dao: d);
    final now = DateTime.now();
    await service.savePrediction({
      ...trial(1),
      'outcome': 'PENDING',
      'created_at_ms':
          now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
      'primary_event_observed': null
    });
    final observed = now.subtract(const Duration(hours: 1));
    await service.recordOutcome('p1', 'SUCCESS',
        primaryEventObserved: true, observedAt: observed);
    final rows = await service.history();
    expect(rows.single['outcome_at_ms'], observed.millisecondsSinceEpoch);
    expect(rows.single['outcome_recorded_at_ms'],
        greaterThan(observed.millisecondsSinceEpoch));
    expect(
        EvidenceForecastScience.eligible(rows, key: 'key', signature: 'model'),
        isEmpty);
    await expectLater(
        service.recordOutcome('p1', 'FAILED',
            primaryEventObserved: false,
            observedAt: now.add(const Duration(days: 1))),
        throwsArgumentError);
  });

  test(
      'long root analysis fits final JEV transport without deleting candidates or changes',
      () async {
    final longText = List.filled(800, '事实').join();
    final jev = EvidenceGrowthJev(client: MockClient((request) async {
      expect(utf8.encode(request.body).length, lessThanOrEqualTo(64000));
      final state = growthMap(growthMap(jsonDecode(request.body))['state']);
      final candidates =
          growthRows(growthMap(state['llm_candidate_synthesis'])['candidates']);
      expect(candidates, hasLength(6));
      expect(candidates.every((c) => c['narrative_excerpted'] == true), isTrue);
      expect(candidates.first['changed_conditions'], ['备好材料']);
      expect(growthMap(state['action_prediction'])['event_contract'], contract);
      return http.Response(
          jsonEncode({
            'answers': {
              'synthesis_event_probability': {'type': 'noul', 'noul': .5},
              'synthesis_quality': {
                'type': 'choice',
                'choice': 'insufficient_evidence',
                'confidence': .8
              },
            }
          }),
          200);
    }));
    final assessed = await jev.assessTheorySynthesis(
        state: {'plan': '登记', 'event_contract': contract},
        theoryFeedbackRows: [],
        firstPassJev: {'status': 'JEV'},
        apiKey: 'test',
        llmSynthesis: {
          'core_conclusions': List.generate(
              6,
              (i) => {
                    'id': 'h$i',
                    'title': '原因假设$i',
                    'changed_conditions': ['备好材料'],
                    for (final key in [
                      'mechanism',
                      'why_key',
                      'counterevidence',
                      'correction',
                      'review_focus',
                      'root_cause_hypothesis',
                      'observed_basis',
                      'maintaining_condition',
                      'alternative_explanation',
                      'falsifier',
                      'minimum_action',
                      'if_then',
                      'cost_and_risk'
                    ])
                      key: longText,
                  })
        });
    expect(assessed['status'], 'JEV');
    expect(assessed['narrative_excerpted'], isTrue);
  });

  test(
      'reference service truly calls LLM and JEV, persists separately and keeps raw sources',
      () async {
    final d = await dao();
    var calls = 0;
    final ai = TestAi((purpose, prompt) {
      expect(purpose, 'evidence_growth.reference_forecast');
      return jsonEncode({
        'identity_summary': '一个熟悉的人',
        'claims': [
          {
            'claim': '过去按时登记',
            'source_id': 'user_evidence',
            'quote': '过去三次都按时登记',
            'dimension': '历史'
          }
        ],
        'theory_explanation': '相似历史支持执行，但时间约束仍重要',
        'scenarios': [
          {
            'label': '习惯保持',
            'assumptions': ['相似习惯持续']
          }
        ],
        'unknowns': ['当天状态']
      });
    });
    final jev = EvidenceGrowthJev(client: MockClient((request) async {
      calls++;
      final body = growthMap(jsonDecode(request.body));
      expect('${growthMap(body['state'])['evidence']}', contains('同一条路线'));
      final qs = growthMap(body['questions']);
      return http.Response(
          jsonEncode({
            'model': 'jev-test',
            'answers': {
              for (final e in qs.entries)
                e.key: growthMap(e.value)['type'] == 'noul'
                    ? {'type': 'noul', 'noul': .6}
                    : {
                        'type': 'choice',
                        'choice': e.key == 'evidence_quality'
                            ? 'adequate_for_rough_estimate'
                            : 'habit',
                        'confidence': .8
                      }
            }
          }),
          200);
    }));
    final service = EvidenceGrowthReferenceForecast(dao: d, ai: ai, jev: jev);
    final result = await service.predict(input: {
      'reference_mode': 'PERSON',
      'person_identity': '张某，同行',
      'identity_confirmed': true,
      'action': '登记',
      'event_contract': contract,
      'fixed_external_context': '同一条路线、费用和时间',
      'reference_evidence': '我观察到他过去三次都按时登记。'
    }, jevApiKey: 'test');
    expect(result['estimate'], .6);
    expect(calls, 1);
    expect(await service.history(), hasLength(1));
    expect(
        await EvidenceGrowthActionPredictionService(dao: d).history(), isEmpty);
  });

  test(
      'review persists disagreement semantics and cannot rewrite the original forecast',
      () async {
    final prediction = {
      ...trial(1),
      'scientific_report': {
        'roots_and_experiments': [
          {'id': 'h', 'title': '准备不足'}
        ]
      }
    };
    final ai = TestAi((purpose, prompt) => jsonEncode({
          'summary': '原假设未确认',
          'next_experiment': '先核实交通',
          'hypothesis_updates': [
            {'id': 'h', 'verdict': 'WEAKENED', 'evidence': '材料齐全'},
            {'id': 'invented', 'verdict': 'SUPPORTED'}
          ]
        }));
    final jev = EvidenceGrowthJev(
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'answers': {
                'review_quality': {
                  'type': 'choice',
                  'choice': 'grounded',
                  'confidence': .9
                },
                'next_step': {
                  'type': 'choice',
                  'choice': 'clarify',
                  'confidence': .8
                },
                'hypothesis_0': {
                  'type': 'choice',
                  'choice': 'unresolved',
                  'confidence': .7
                },
              }
            }),
            200)));
    final reviewed = await EvidenceGrowthActionReview(ai: ai, jev: jev).analyze(
        prediction: prediction,
        observations: {'timeline': '材料齐全但错过班车'},
        jevApiKey: 'test');
    expect(reviewed['status'], 'COMPLETE');
    expect(
        growthRows(growthMap(reviewed['llm_analysis'])['hypothesis_updates']),
        hasLength(1));
    expect(
        growthMap(growthMap(growthMap(reviewed['jev_review'])['answers'])[
            'hypothesis_0'])['choice'],
        'unresolved');
    expect(prediction['estimate'], .9);
  });

  testWidgets(
      'report renders on a narrow phone and preserves frozen success criterion',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = {
      ...trial(1),
      'plan': '去登记',
      'scientific_report': {'roots_and_experiments': []}
    };
    await tester.pumpWidget(
        MaterialApp(home: EvidenceGrowthForecastReportPage(prediction: p)));
    expect(find.textContaining('达成标准：完成登记'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
        EvidenceGrowthForecastReportPage.markdown(p), contains('观察窗口：预约前30分钟'));
  });

  testWidgets(
      'reference entry supports world and person mode on a narrow phone',
      (tester) async {
    final d = MemoryForecastDao();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: EvidenceGrowthReferenceForecastPage(dao: d, jevApiKey: 'test')));
    await tester.pumpAndSettle();
    expect(find.text('全世界人群'), findsOneWidget);
    await tester.tap(find.text('指定人物'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('review saves actual observations without calling AI',
      (tester) async {
    final d = MemoryForecastDao();
    final service = EvidenceGrowthActionPredictionService(dao: d);
    final p = {
      ...trial(1),
      'outcome': 'PENDING',
      'primary_event_observed': null
    };
    await service.savePrediction(p);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: EvidenceGrowthActionReviewPage(
            prediction: p, service: service, jevApiKey: '')));
    await tester.enterText(find.byType(TextField).first, '到场后发现服务窗口临时关闭');
    await tester.scrollUntilVisible(find.text('先保存观察，稍后分析'), 500,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('先保存观察，稍后分析'));
    await tester.pumpAndSettle();
    final saved = (await service.history()).single;
    expect(saved['outcome'], 'UNOBSERVED');
    expect(
        growthMap(growthMap(saved['diagnostic_review'])['user_observations'])[
            'timeline'],
        '到场后发现服务窗口临时关闭');
    expect(saved['estimate'], p['estimate']);
    expect(tester.takeException(), isNull);
  });
}
