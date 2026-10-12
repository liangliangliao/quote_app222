import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_science.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_defaults.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_forecast.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_forecast_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_report.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_research.dart';
import 'package:quote_app/services/unified_ai_service.dart';

import 'jev_wire_contract.dart';

class ReferenceMemoryDao extends EvidenceGrowthDao {
  ReferenceMemoryDao() : super(database: () => throw StateError('unused'));
  final settings = <String, String>{};
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async =>
      settings[key] ?? fallback;
  @override
  Future<void> setSetting(String key, String value) async =>
      settings[key] = value;
}

class ReferenceAi extends UnifiedAiService {
  ReferenceAi({this.provider = 'fake', this.respond});
  final String provider;
  final String Function(String purpose, String prompt)? respond;
  final calls = <String>[];
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
        provider: provider,
        apiKey: 'test-key',
        model: 'grok-4.5',
        endpoint: 'https://api.x.ai/v1/chat/completions',
        label: 'test',
        displayModel: 'test-model',
        available: true,
      );
  @override
  Future<String> generateText(
      {required String prompt,
      required String purpose,
      String? systemPrompt,
      int maxTokens = 1800,
      bool expectJson = false,
      String? forcedProvider,
      String? forcedModel,
      double? temperature}) async {
    calls.add(purpose);
    if (respond != null) return respond!(purpose, prompt);
    if (purpose.endsWith('research_plan')) {
      return jsonEncode({
        'aliases': ['Tal Ben-Shahar'],
        'queries': [
          {'query': 'Tal Ben-Shahar', 'language': 'en'},
        ]
      });
    }
    return jsonEncode(profile());
  }
}

GrowthData profile({String source = ''}) => {
      'identity_summary': '按所选人群或人物资料暂定',
      'claims': [
        {
          'dimension': '习惯',
          'claim': '假设过去有运动经验，会较容易开始跑步',
          'source_id': source,
          'quote': source.isEmpty ? '' : '过去有运动经验',
          'relevance': '经验帮助启动，但不等于习惯在6点跑步'
        },
        {
          'dimension': '态度',
          'claim': '假设已经了解行动，但尚未承诺',
          'relevance': '自主意愿与早起习惯影响实际执行'
        },
      ],
      'theory_explanation': '运动经验帮助能力，实际启动仍受到兴趣、意愿和早起习惯影响。',
      'past_behavior_analysis': '相似经历只能作为间接线索',
      'attitude_and_personality_hypotheses': '自律为条件假设，并非已核实性格',
      'scenarios': [
        {
          'label': '有相似习惯',
          'assumptions': ['经常早起运动']
        },
        {
          'label': '没有相似习惯',
          'assumptions': ['通常不在早晨运动']
        },
      ],
      'unknowns': ['当前意愿'],
    };

GrowthData input({bool person = false, String personType = 'PUBLIC'}) {
  final defaults = ReferenceForecastDefaults.forAction('明天早上6点去跑步');
  return {
    'reference_mode': person ? 'PERSON' : 'WORLD',
    'person_type': personType,
    'person_identity': person ? 'talbenshahar' : '',
    'identity_confirmed': false,
    'action': '明天早上6点去跑步',
    'event_contract': EvidenceForecastScience.contract({
      'success_criterion': '准时出门跑1公里',
      'observation_window': '1天',
      'confirmed': true,
    }),
    'fixed_external_context': '无特别要求',
    'population_definition': person ? '' : '正常健康的所有成年人',
    'reference_evidence': '',
    'default_assumptions': defaults['fixed_external_context'],
  };
}

http.Response jsonResponse(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code,
        headers: {'content-type': 'application/json; charset=utf-8'});

EvidenceGrowthJev judge(
        {String quality = 'insufficient',
        int status = 200,
        void Function(GrowthData)? inspect}) =>
    EvidenceGrowthJev(client: MockClient((req) async {
      final body = growthMap(jsonDecode(req.body));
      expect(utf8.encode(req.body).length, lessThanOrEqualTo(64000));
      inspect?.call(body);
      if (status != 200) return jsonResponse({}, status);
      return jsonResponse({
        'model': 'test-jev',
        'answers': {
          for (final e in growthMap(body['questions']).entries)
            e.key: growthMap(e.value)['type'] == 'noul'
                ? {
                    'type': 'noul',
                    'noul': switch (e.key) {
                      'plausible_low' => .2,
                      'plausible_high' => .75,
                      'scenario_1' => .7,
                      'scenario_2' => .25,
                      _ => .43,
                    }
                  }
                : {
                    'type': 'choice',
                    'confidence': .7,
                    'choice': switch (e.key) {
                      'evidence_quality' => quality,
                      'estimate_confidence' => 'medium',
                      _ => 'habit',
                    }
                  },
        },
      });
    }));

GrowthData citedResponse() => {
      'status': 'completed',
      'output': [
        {'type': 'web_search_call', 'status': 'completed'},
        {
          'type': 'message',
          'content': [
            {
              'type': 'output_text',
              'text': '资料摘要：过去有运动经验。当前日程未知。',
              'annotations': [
                {
                  'type': 'url_citation',
                  'url': 'https://example.org/biography',
                  'title': '测试人物资料'
                },
              ]
            },
          ]
        },
      ],
    };

void main() {
  test('reference report explains a critical gate even when its construct is deduplicated', () {
    final result = EvidenceGrowthReferenceForecast.assemble(
      input: input(person: true),
      profile: {
        'execution_likelihood': .9,
        'claims': [
          {'id': 'available', 'dimension': '机会', 'claim': '场地平时可用',
            'importance': .95, 'support_score': .95, 'direction': 'supportive',
            'evidence_status': 'SOURCE_LINKED'},
          {'id': 'permission', 'dimension': '机会', 'claim': '进入许可未通过',
            'importance': .9, 'support_score': .05, 'direction': 'adverse',
            'evidence_status': 'SOURCE_LINKED', 'evidence_kind': 'CURRENT_CONDITION',
            'necessary_prerequisite': true, 'source_kind': 'USER_SUPPLIED',
            'quote': '指定场地的进入许可未通过',
            'obstacle_reason': '没有进入许可，无法在指定场地执行'},
        ],
      },
      sources: [],
      model: 'test',
      jev: {'status': 'JEV', 'answers': {'event': .9, 'hard_blocker': .99, 'bottleneck_permission': .99}},
    );
    expect(result['estimate'], lessThan(.2));
    expect(growthRows(growthMap(result['factor_weight_analysis'])['factors']), hasLength(1));
    final text = ReferenceForecastReport.markdown(result);
    expect(text, contains('进入许可未通过'));
    expect(text, contains('没有进入许可，无法在指定场地执行'));
    expect(text, contains('其他有利因素无法完全抵消'));
  });

  test('successful works fallback is reported as available public evidence', () {
    final text = ReferenceForecastReport.markdown({
      'input_snapshot': input(person: true),
      'profile': profile(),
      'research': {'status': 'NO_SOURCES'},
      'sources': [{'id': 'public_works', 'kind': 'PUBLISHED_WORKS_COLLECTION',
        'title': '测试人物公开观点引文集', 'content': '测试资料，不是真实人物引文。'}],
    });
    expect(text, contains('已读取公开著作与观点引文'));
    expect(text, isNot(contains('未取得可引用的网络资料')));
  });

  test('public works lookup retains original work headings and rejects different people', () async {
    final research = ReferenceWorksResearch(client: MockClient((request) async {
      expect(request.url.host, 'en.wikiquote.org');
      if (request.url.queryParameters['list'] == 'search') {
        return jsonResponse({'query': {'search': [
          {'pageid': 1, 'title': 'Tal Ben-Shahar'},
          {'pageid': 2, 'title': 'A Different Author'},
        ]}});
      }
      expect(request.url.queryParameters['pageid'], '1');
      return jsonResponse({'parse': {'wikitext':
        "== Happier ==\n* Exercise and health are useful habits.\n* This is a test excerpt, not a verified quotation.\n"}});
    }));
    final sources = await research.search(['Tal Ben-Shahar'], '明天跑步');
    expect(sources, hasLength(1));
    expect(sources.single['kind'], 'PUBLISHED_WORKS_COLLECTION');
    expect(sources.single['content'], contains('Happier'));
    expect(sources.single['content'], contains('Exercise and health'));
    expect(sources.single['limit'], contains('思想不等同于实际行为'));
    var parsed = false;
    final wrong = ReferenceWorksResearch(client: MockClient((request) async {
      if (request.url.queryParameters['action'] == 'parse') parsed = true;
      return jsonResponse({'query': {'search': [
        {'pageid': 3, 'title': 'Tal Ben-Shahar Junior'},
      ]}});
    }));
    expect(await wrong.search(['Tal Ben-Shahar'], '跑步'), isEmpty);
    expect(parsed, isFalse);
  });

  test('work title and viewpoint need matching provided source passages', () {
    final normalized = EvidenceGrowthReferenceForecast.normalizeProfile({
      'claims': [
        {'dimension': '态度', 'claim': '作品中表达重视运动',
          'source_id': 'book', 'quote': '运动有助于形成健康习惯',
          'evidence_kind': 'AUTHORED_WORK', 'work_title': '习惯与健康',
          'transfer_reason': '可能认可跑步，但不能据此断言明天执行',
          'importance': .7, 'support_score': .8, 'direction': 'supportive'},
        {'dimension': '态度', 'claim': '未经核实的名言', 'source_id': 'invented',
          'quote': '这句话不在资料中', 'work_title': '不存在的书',
          'evidence_kind': 'AUTHORED_WORK'},
      ],
    }, [{'id': 'book', 'kind': 'PUBLISHED_WORKS_COLLECTION',
      'content': '《习惯与健康》：运动有助于形成健康习惯。'}]);
    final claims = growthRows(normalized['claims']);
    expect(claims.first['work_title'], '习惯与健康');
    expect(claims.first['evidence_status'], 'SOURCE_LINKED');
    expect(claims.last['work_title'], isEmpty);
    expect(claims.last['evidence_status'], 'MODEL_ASSUMPTION');
    final text = ReferenceForecastReport.markdown({
      'profile': normalized, 'input_snapshot': input(person: true),
      'estimate_available': true, 'estimate': .8,
    });
    expect(text, contains('著作思想与本次行动'));
    expect(text, contains('《习惯与健康》'));
    expect(text, isNot(contains('《不存在的书》')));
  });

  test('person forecast pools important supports rather than copying a low JEV event score', () async {
    const excerpt = '《习惯与健康》提出：运动有助于形成健康习惯。';
    final dao = ReferenceMemoryDao();
    final ai = ReferenceAi(respond: (purpose, prompt) {
      expect(prompt, contains(excerpt));
      return jsonEncode({
        ...profile(), 'execution_likelihood': .85,
        'likely_attitude': '根据作品观点，可能认可运动的价值',
        'likely_behavior': '结合习惯条件，较可能执行',
        'claims': [
          {'dimension': '态度', 'claim': '认可健康习惯的价值',
            'source_id': 'book', 'quote': '运动有助于形成健康习惯',
            'work_title': '习惯与健康', 'evidence_kind': 'AUTHORED_WORK',
            'transfer_reason': '支持运动态度，执行仍取决于实际条件',
            'importance': .8, 'support_score': .9, 'direction': 'supportive'},
          {'dimension': '习惯', 'claim': '假设有相关运动习惯',
            'importance': .9, 'support_score': .9, 'direction': 'supportive'},
          {'dimension': '规范', 'claim': '缺少他人鼓励', 'importance': .05,
            'support_score': .05, 'direction': 'adverse',
            'obstacle_reason': '鼓励较少，但独立运动不依赖他人赞许'},
        ],
      });
    });
    final jev = EvidenceGrowthJev(client: MockClient((request) async {
      validateJevWireRequest(request);
      final questions = growthMap(growthMap(jsonDecode(request.body))['questions']);
      expect(questions.length, lessThanOrEqualTo(24));
      return jsonResponse({'model': 'test-jev', 'answers': {
        for (final entry in questions.entries) entry.key: switch (growthMap(entry.value)['type']) {
          'score' => {'type': 'score', 'confidence': .8,
            'score': entry.key.endsWith('claim_3') ? 0 : 4},
          'noul' => {'type': 'noul', 'noul': switch (entry.key) {
            'plausible_low' => .2, 'plausible_high' => .95,
            'hard_blocker' => .01, _ => .43,
          }},
          _ => {'type': 'choice', 'confidence': .8,
            'choice': entry.key == 'evidence_quality' ? 'adequate_for_rough_estimate'
                : entry.key == 'estimate_confidence' ? 'medium' : 'habit'},
        },
      }});
    }));
    final result = await EvidenceGrowthReferenceForecast(dao: dao, ai: ai, jev: jev).predict(
      input: input(person: true, personType: 'KNOWN'), jevApiKey: 'test',
      retrievedSources: [{'id': 'book', 'kind': 'USER_SUPPLIED',
        'title': '习惯与健康', 'content': excerpt}]);
    expect(result['raw_jev_estimate'], .43);
    expect(result['estimate'], greaterThan(.6));
    expect(result['estimate'], lessThan(.7));
    expect(growthMap(result['factor_weight_analysis'])['status'], 'WEIGHTED');
    expect(growthRows(growthMap(result['factor_weight_analysis'])['factors']).last['label'], '缺少他人鼓励');
    expect(ReferenceForecastReport.markdown(result), contains('可能态度'));
    expect(dao.settings[EvidenceGrowthActionPredictionService.historySetting], isNull);
  });

  test(
      'both screenshot scenarios yield rough results despite insufficient evidence',
      () {
    for (final person in [false, true]) {
      final r = EvidenceGrowthReferenceForecast.assemble(
        input: input(person: person),
        profile: profile(),
        sources: [],
        model: 'test',
        jev: {
          'status': 'JEV',
          'answers': {
            'event': .43,
            'plausible_low': .2,
            'plausible_high': .75,
            'evidence_quality': {'choice': 'insufficient'},
          }
        },
      );
      expect(r['estimate_available'], isTrue);
      expect(r['estimate'], .43);
      expect(r['estimate_confidence'], 'low');
      expect(r['status'], 'ROUGH_ASSUMPTION_ESTIMATE');
      expect(growthMap(r['assumption_range']), {'low': .2, 'high': .75});
      final text = ReferenceForecastReport.markdown(r);
      expect(text, contains('约45%'));
      expect(text, isNot(contains('尚不能估计')));
      expect(text, isNot(contains('identity_confirmed')));
    }
  });

  test(
      'defaults transfer across actions and never erase a hand-edited criterion',
      () {
    final running = ReferenceForecastDefaults.forAction('明天早上6点跑1公里');
    final learning = ReferenceForecastDefaults.forAction('每天学习30分钟，连续30天');
    expect(running['success_criterion'], contains('6点跑1公里'));
    expect(running['observation_window'], contains('明天'));
    expect(learning['success_criterion'], contains('连续30天'));
    expect(learning['observation_window'], contains('连续30天'));
    expect(learning['observation_window'], isNot(contains('观察30分钟')));
    for (final start in ['明天', '下周']) {
      final future =
          ReferenceForecastDefaults.forAction('$start开始每天学习30分钟，连续三十天');
      expect(future['observation_window'], contains(start));
      expect(future['observation_window'], contains('连续三十天'));
    }
    final session = ReferenceForecastDefaults.forAction('明天开始每天连续学习30分钟');
    expect(session['observation_window'], contains('明天'));
    expect(session['observation_window'], contains('观察7天'));
    expect(session['observation_window'], isNot(contains('周期：连续30分钟')));
    expect(learning['fixed_external_context'], contains('并不假定其已承诺'));
    final merged = ReferenceForecastDefaults.merge(
      current: {...running, 'success_criterion': '我自己写的标准'},
      previousDefaults: running,
      proposed: learning,
    );
    expect(merged['success_criterion'], '我自己写的标准');
    expect(
        merged['fixed_external_context'], learning['fixed_external_context']);
  });

  test(
      'public person automatically invokes Grok web search and retains real API citations',
      () async {
    var webCalls = 0;
    final ai = ReferenceAi(
        provider: 'xgrok',
        respond: (purpose, prompt) {
          expect(purpose, 'evidence_growth.reference_forecast');
          expect(prompt, contains('资料摘要：过去有运动经验'));
          return jsonEncode(profile(source: 'web_research'));
        });
    final service = EvidenceGrowthReferenceForecast(
      dao: ReferenceMemoryDao(),
      ai: ai,
      jev: judge(),
      client: MockClient((req) async {
        webCalls++;
        expect(req.method, 'POST');
        expect(req.url.toString(), 'https://api.x.ai/v1/responses');
        final body = growthMap(jsonDecode(req.body));
        expect(body['model'], 'grok-4.5');
        expect(body['store'], isFalse);
        expect(body['tools'], [
          {'type': 'web_search'}
        ]);
        expect(req.body, contains('talbenshahar'));
        expect(req.body, isNot(contains('用户的私人观察记录')));
        return jsonResponse(citedResponse());
      }),
    );
    final r = await service.predict(
      input: {...input(person: true), 'reference_evidence': '用户的私人观察记录'},
      jevApiKey: 'test',
    );
    expect(webCalls, 1);
    expect(r['estimate'], .43);
    expect(growthMap(r['research'])['status'], 'WEB');
    expect(
        growthRows(growthMap(r['profile'])['claims']).first['evidence_status'],
        'RESEARCH_LINKED');
    expect(ReferenceForecastReport.markdown(r),
        contains('https://example.org/biography'));
  });

  test(
      'failed web tool falls back to alias-aware public search, without an identity checkbox',
      () async {
    var requests = 0;
    final service = EvidenceGrowthReferenceForecast(
      dao: ReferenceMemoryDao(),
      ai: ReferenceAi(provider: 'xgrok'),
      jev: judge(),
      client: MockClient((req) async {
        requests++;
        if (req.url.host.endsWith('wikiquote.org')) return jsonResponse({}, 404);
        if (req.method == 'POST') return jsonResponse({}, 503);
        expect(req.url.host, 'en.wikipedia.org');
        if (req.url.queryParameters['list'] == 'search') {
          expect(req.url.queryParameters['srsearch'], 'Tal Ben-Shahar');
          return jsonResponse({
            'query': {
              'search': [
                {'pageid': 42, 'title': 'Tal Ben-Shahar', 'snippet': '人物条目'},
              ]
            }
          });
        }
        return jsonResponse({
          'query': {
            'pages': [
              {
                'pageid': 42,
                'title': 'Tal Ben-Shahar',
                'extract': '测试资料：过去有运动经验。'
              },
            ]
          }
        });
      }),
    );
    final r =
        await service.predict(input: input(person: true), jevApiKey: 'test');
    expect(requests, 5, reason: 'Biography lookup plus bounded bilingual works lookup');
    expect(r['estimate_available'], isTrue);
    expect(growthMap(r['research'])['status'], 'ENCYCLOPEDIA');
    expect(growthRows(r['sources']).single['url'],
        'https://en.wikipedia.org/?curid=42');
  });

  test(
      'no sources or ambiguous people still get low-confidence estimates without invented biographies',
      () async {
    for (final ambiguous in [false, true]) {
      final service = EvidenceGrowthReferenceForecast(
        dao: ReferenceMemoryDao(),
        ai: ReferenceAi(),
        jev: judge(),
        client: MockClient((req) async => jsonResponse({
              'query': {
                'search': [
                  if (ambiguous) ...[
                    {'pageid': 1, 'title': 'Tal Ben-Shahar'},
                    {'pageid': 2, 'title': 'Tal Ben-Shahar'},
                  ],
                ]
              }
            })),
      );
      final r =
          await service.predict(input: input(person: true), jevApiKey: 'test');
      expect(r['estimate'], .43);
      expect(r['estimate_confidence'], 'low');
      expect(r['sources'], isEmpty);
      expect(growthMap(r['research'])['status'],
          ambiguous ? 'AMBIGUOUS' : 'NO_SOURCES');
    }
  });

  test(
      'world search failure retains estimate and excludes irrelevant person fields from AI input',
      () async {
    final ai = ReferenceAi(respond: (purpose, prompt) {
      if (purpose.endsWith('research_plan'))
        return jsonEncode({
          'queries': [
            {'query': 'Running', 'language': 'en'}
          ]
        });
      expect(prompt, isNot(contains('person_identity')));
      expect(prompt, isNot(contains('identity_confirmed')));
      expect(prompt, isNot(contains('人物类型')));
      return jsonEncode(profile());
    });
    final service = EvidenceGrowthReferenceForecast(
      dao: ReferenceMemoryDao(),
      ai: ai,
      jev: judge(),
      client: MockClient((req) async => throw Exception('offline')),
    );
    final r = await service.predict(input: input(), jevApiKey: 'test');
    expect(r['estimate'], .43);
    expect(growthMap(r['research'])['status'], 'NO_SOURCES');
    expect(ReferenceForecastReport.markdown(r), contains('未取得可引用的网络资料'));
  });

  test(
      'known people are not publicly searched and technical failure is not called insufficient evidence',
      () async {
    final ai = ReferenceAi();
    final service = EvidenceGrowthReferenceForecast(
      dao: ReferenceMemoryDao(),
      ai: ai,
      jev: judge(status: 503),
      client: MockClient(
          (req) async => fail('No public search for a known person')),
    );
    final r = await service.predict(
        input: input(person: true, personType: 'KNOWN'), jevApiKey: 'test');
    expect(r['estimate'], isNull);
    expect(r['estimate_available'], isFalse);
    expect(r['status'], 'MODEL_UNAVAILABLE');
    expect(r['unavailable_reason'], contains('JEV判断未完成'));
    expect(r['unavailable_reason'], contains('服务暂时不可用'));
    expect(ai.calls, ['evidence_growth.reference_forecast']);
  });

  test(
      'uncited model URLs are never promoted to retrieved sources; incomplete responses rejected',
      () {
    expect(
        ReferenceWebResearch.parseSources({
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': 'I searched https://invented.example/fact'
                },
              ]
            },
          ]
        }),
        isEmpty);
    expect(
        ReferenceWebResearch.parseSources(
            {...citedResponse(), 'status': 'incomplete'}),
        isEmpty);
    expect(ReferenceWebResearch.publicUrl('javascript:alert(1)'), isEmpty);
    expect(ReferenceWebResearch.publicUrl('http://127.0.0.1/admin'), isEmpty);
  });

  test(
      'malformed probabilities cannot become available and reversed ranges use valid scenario envelope',
      () {
    for (final event in [null, double.nan, 2.0]) {
      final r = EvidenceGrowthReferenceForecast.assemble(
          input: input(),
          profile: {},
          sources: [],
          model: 'test',
          jev: {
            'status': 'JEV',
            'answers': {'event': event}
          });
      expect(r['estimate_available'], isFalse);
    }
    final r = EvidenceGrowthReferenceForecast.assemble(
        input: input(),
        profile: {
          'scenarios': [
            {'id': 'a'},
            {'id': 'b'}
          ]
        },
        sources: [],
        model: 'test',
        jev: {
          'status': 'JEV',
          'answers': {
            'event': .5,
            'plausible_low': .8,
            'plausible_high': .2,
            'a': .3,
            'b': .7
          }
        });
    expect(r['range_kind'], 'SCENARIO_ENVELOPE');
    expect(r['assumption_range'], {'low': .3, 'high': .7});
  });

  testWidgets(
      'one action auto-fills fields; manual edits survive a new action and submitting produces a result',
      (tester) async {
    final dao = ReferenceMemoryDao();
    final service = EvidenceGrowthReferenceForecast(
        dao: dao,
        ai: ReferenceAi(respond: (purpose, prompt) {
          if (purpose.endsWith('reference_defaults'))
            return jsonEncode({
              'success_criterion': 'AI建议的标准，不应覆盖手写标准',
              'observation_window': '后天6点至7点（AI细化）',
            });
          if (purpose.endsWith('research_plan')) return '{}';
          return jsonEncode(profile());
        }),
        jev: judge(),
        client: MockClient((req) async => jsonResponse({
              'query': {'search': []}
            })));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: EvidenceGrowthReferenceForecastPage(
      dao: dao,
      jevApiKey: 'test',
      service: service,
    )));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.enterText(field('要执行的行动'), '明天早上6点跑1公里');
    await tester.pump();
    expect(tester.widget<TextField>(field('可观察的成功标准')).controller!.text,
        contains('6点跑1公里'));
    await tester.enterText(field('可观察的成功标准'), '准时出门并跑完1公里');
    await tester.enterText(field('要执行的行动'), '后天早上6点跑1公里');
    await tester.pump();
    expect(tester.widget<TextField>(field('可观察的成功标准')).controller!.text,
        '准时出门并跑完1公里');
    expect(tester.widget<TextField>(field('相同的观察窗口／期限')).controller!.text,
        contains('后天'));
    await tester.ensureVisible(find.text('AI细化默认内容（保留手动修改）'));
    await tester.tap(find.text('AI细化默认内容（保留手动修改）'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('可观察的成功标准')).controller!.text,
        '准时出门并跑完1公里');
    expect(tester.widget<TextField>(field('相同的观察窗口／期限')).controller!.text,
        '后天6点至7点（AI细化）');
    await tester.scrollUntilVisible(find.text('联网分析＋JEV生成粗估报告'), 450,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('联网分析＋JEV生成粗估报告'));
    await tester.pumpAndSettle();
    final saved = (await service.history()).single;
    expect(saved['estimate'], .43);
    expect(
        growthMap(growthMap(saved['input_snapshot'])['event_contract'])[
            'success_criterion'],
        '准时出门并跑完1公里');
    expect(
        growthMap(growthMap(saved['input_snapshot'])['event_contract'])[
            'observation_window'],
        '后天6点至7点（AI细化）');
    expect(tester.takeException(), isNull);
  });

  test(
      'long reference analysis fits JEV transport while preserving the event and all factor claims',
      () async {
    String long(int n) => List.filled(n, '文').join();
    var judged = false;
    final service = EvidenceGrowthReferenceForecast(
      dao: ReferenceMemoryDao(),
      ai: ReferenceAi(
          respond: (purpose, prompt) => jsonEncode({
                'identity_summary': long(1000),
                'claims': [
                  for (var i = 0; i < 12; i++)
                    {
                      'dimension': long(100),
                      'claim': long(800),
                      'relevance': long(600),
                      'source_id': 's1',
                      'quote': long(400),
                    }
                ],
                'theory_explanation': long(2200),
                'past_behavior_analysis': long(1600),
                'attitude_and_personality_hypotheses': long(1300),
                'scenarios': [
                  for (var i = 0; i < 3; i++)
                    {
                      'label': long(200),
                      'assumptions': List.filled(4, long(500)),
                    }
                ],
                'unknowns': List.filled(8, long(600)),
              })),
      jev: judge(inspect: (body) {
        judged = true;
        final state = growthMap(growthMap(body['state'])['evidence']);
        expect(growthMap(state['raw_input'])['成功标准'], long(600));
        expect(growthRows(state['extracted_claims_to_verify']),
            hasLength(12));
      }),
    );
    final r = await service.predict(
        input: {
          ...input(person: true, personType: 'KNOWN'),
          'action': long(2000),
          'fixed_external_context': long(4000),
          'reference_evidence': long(600),
          'event_contract': {
            'confirmed': true,
            'success_criterion': long(600),
            'observation_window': long(300)
          },
        },
        jevApiKey: 'test',
        retrievedSources: [
          {'id': 's1', 'kind': 'PUBLIC_RETRIEVED', 'content': long(12000)},
          {'id': 's2', 'kind': 'PUBLIC_RETRIEVED', 'content': long(12000)},
        ]);
    expect(judged, isTrue);
    expect(r['estimate'], .43);
  });
}
