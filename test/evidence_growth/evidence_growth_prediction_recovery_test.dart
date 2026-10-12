import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_report_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_forecast_science.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_prediction_run.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reference_forecast.dart';
import 'package:quote_app/services/unified_ai_service.dart';

import 'jev_wire_contract.dart';

class RecoveryDao extends EvidenceGrowthDao {
  RecoveryDao() : super(database: () => throw StateError('No database needed'));
  final settings = <String, String>{};
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async =>
      settings[key] ?? fallback;
  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }
}

class RecoveryAi extends UnifiedAiService {
  RecoveryAi(this.respond, {this.model = 'recovery-model'});
  final FutureOr<String> Function(String purpose, String prompt) respond;
  final String model;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'fake',
          apiKey: 'test',
          model: model,
          endpoint: '',
          label: 'test',
          displayModel: model,
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

const firstPurpose = 'evidence_growth.action_prediction';
const synthesisPurpose = '$firstPurpose.theory_feedback_synthesis';
final recoveryContract = EvidenceForecastScience.contract({
  'success_criterion': '连续跑步10分钟',
  'observation_window': '明天下午',
  'context_class': '附近公园，无已知健康或交通限制',
  'confirmed': true,
});
final recoveryProfile = <String, dynamic>{
  'analysis_status': 'READY',
  'action_mode': 'START',
  'action_tags': ['跑步'],
  'normalized_action': '明天跑步10分钟',
  'theory_factor_questionnaire': [
    {
      'id': 'intention',
      'label': '行动意向',
      'theory_ids': ['TPB']
    },
  ],
};

String recoveryReply(String purpose, {double probability = .85}) =>
    jsonEncode(purpose == firstPurpose
        ? {
            'execution_likelihood': probability,
            'summary': '已决定去跑步',
            'factors': {
              for (final id
                  in EvidenceGrowthActionPredictionService.factorLabels.keys)
                id: {
                  'score': .8,
                  'confidence': .8,
                  'importance': .5,
                  'status': 'SUPPORT',
                  'evidence': '当前条件支持跑步'
                }
            },
          }
        : {
            'pattern_code': 'no_major_theory_blocker',
            'integrated_pattern': '意向明确，未见必要条件失败',
            'core_conclusions': [
              {
                'type': 'PROTECTIVE',
                'factor_ids': ['intention'],
                'theory_ids': ['TPB'],
                'title': '明确的行动决定支持执行',
                'observed_basis': '已确认行动意向',
                'minimum_action': '按约定时段带上跑鞋出门'
              },
            ],
          });

Future<GrowthData> startRecovery(EvidenceGrowthActionPredictionService service,
        {GrowthData cycleContext = const {}}) =>
    service.predict(
      plan: '明天去跑步',
      actionProfile: recoveryProfile,
      eventContract: recoveryContract,
      selectedTheoryIds: ['TPB'],
      theoryFactorAnswers: {
        'intention': {'option_id': 'firm', 'confirmed_by_user': true},
      },
      jevApiKey: 'test',
      requireJev: true,
      cycleContext: cycleContext,
    );

bool finalRequest(http.Request request) =>
    growthMap(growthMap(jsonDecode(request.body))['questions'])
        .containsKey('synthesis_event_probability');

void main() {
  for (final failure in [
    'llm_first',
    'jev_first',
    'llm_synthesis',
    'jev_final'
  ]) {
    test(
        'resume $failure after reopening only executes missing and dependent work',
        () async {
      final dao = RecoveryDao();
      final initialAiCalls = <String>[];
      var firstEventCalls = 0;
      final initial = EvidenceGrowthActionPredictionService(
        dao: dao,
        ai: RecoveryAi((purpose, prompt) {
          initialAiCalls.add(purpose);
          if ((failure == 'llm_first' && purpose == firstPurpose) ||
              (failure == 'llm_synthesis' && purpose == synthesisPurpose)) {
            throw TimeoutException('temporary provider timeout');
          }
          return recoveryReply(purpose);
        }),
        jev: EvidenceGrowthJev(client: MockClient((request) async {
          validateJevWireRequest(request);
          final questions =
              growthMap(growthMap(jsonDecode(request.body))['questions']);
          if (questions.keys.any((k) => k.startsWith('event_')))
            firstEventCalls++;
          if ((failure == 'jev_first' && !finalRequest(request)) ||
              (failure == 'jev_final' && finalRequest(request)))
            return http.Response('{}', 503);
          return validJevWireReply(request);
        })),
      );
      final partial = await startRecovery(initial);
      expect(partial['pipeline_status'], 'PARTIAL');
      expect(partial['estimate'], isNull);
      expect(growthMap(partial['ai'])['execution_likelihood'],
          failure == 'llm_first' ? isNull : .85);
      expect(firstEventCalls, 1);
      await initial.savePrediction(partial);
      final retryAiCalls = <String>[];
      final retryJevRequests = <http.Request>[];
      final reopened = EvidenceGrowthActionPredictionService(
        dao: dao,
        ai: RecoveryAi((purpose, prompt) {
          retryAiCalls.add(purpose);
          return recoveryReply(purpose);
        }),
        jev: EvidenceGrowthJev(client: MockClient((request) async {
          validateJevWireRequest(request);
          retryJevRequests.add(request);
          return validJevWireReply(request);
        })),
      );
      final completed = failure == 'jev_final'
          ? await startRecovery(reopened, cycleContext: {
              'trial_id': partial['trial_id'],
              'parent_prediction_id': partial['id']
            })
          : await reopened.resumePrediction('${partial['id']}',
              jevApiKey: 'test');
      expect(completed['pipeline_status'], 'COMPLETE',
          reason: '${completed['pipeline_errors']}');
      expect(completed['estimate'], isNotNull);
      expect(completed['trial_id'], partial['trial_id']);
      expect(completed['event_contract'], partial['event_contract']);
      expect(completed['execution_state'], partial['execution_state']);
      if (failure != 'llm_first') expect(completed['ai'], partial['ai']);
      expect(
          retryAiCalls,
          failure == 'llm_first'
              ? [firstPurpose, synthesisPurpose]
              : failure == 'jev_final'
                  ? isEmpty
                  : [synthesisPurpose]);
      if (failure != 'jev_first') {
        expect(retryJevRequests, hasLength(1));
        expect(finalRequest(retryJevRequests.single), isTrue);
        expect(completed['jev'], partial['jev']);
      }
      await reopened.savePrediction(completed);
      expect(await reopened.history(), hasLength(2));
      await expectLater(
          reopened.resumePrediction('${partial['id']}', jevApiKey: 'test'),
          throwsStateError);
      await expectLater(
          reopened.resumePrediction('${completed['id']}', jevApiKey: 'test'),
          throwsStateError);
    });
  }

  test(
      'typed core batches remain bounded and validated successes survive process restart',
      () async {
    final dao = RecoveryDao();
    var coreBatch = 0;
    var eventRequests = 0;
    final initial = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) => recoveryReply(purpose)),
      jev: EvidenceGrowthJev(client: MockClient((request) async {
        validateJevWireRequest(request);
        final questions =
            growthMap(growthMap(jsonDecode(request.body))['questions']);
        if (!finalRequest(request)) {
          expect(questions.length, lessThanOrEqualTo(16));
          coreBatch++;
          if (questions.keys.any((k) => k.startsWith('event_')))
            eventRequests++;
          if (coreBatch == 2) return http.Response('{}', 503);
        }
        return validJevWireReply(request);
      })),
    );
    final partial = await startRecovery(initial);
    expect(partial['pipeline_status'], 'PARTIAL');
    expect(growthMap(partial['jev'])['overall'], .85);
    expect(growthMap(partial['jev'])['core_batches_complete'], isFalse);
    expect(eventRequests, 1);
    await initial.savePrediction(partial);
    final reopened = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) => recoveryReply(purpose)),
      jev: EvidenceGrowthJev(client: MockClient((request) async {
        validateJevWireRequest(request);
        final questions =
            growthMap(growthMap(jsonDecode(request.body))['questions']);
        if (!finalRequest(request)) {
          expect(questions.length, lessThanOrEqualTo(16));
          if (questions.keys.any((k) => k.startsWith('event_')))
            eventRequests++;
        }
        return validJevWireReply(request);
      })),
    );
    final completed =
        await reopened.resumePrediction('${partial['id']}', jevApiKey: 'test');
    expect(completed['pipeline_status'], 'COMPLETE',
        reason: '${completed['pipeline_warnings']}');
    expect(eventRequests, 1,
        reason: 'the frozen primary event must not be sent again');
    expect(growthMap(completed['jev'])['overall'], .85);
  });

  testWidgets(
      'healthy provider work beyond 120 seconds is not abandoned by a second deadline',
      (tester) async {
    final dao = RecoveryDao();
    var calls = 0;
    final service = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) async {
        calls++;
        await Future<void>.delayed(const Duration(seconds: 121));
        return recoveryReply(purpose);
      }),
      jev: EvidenceGrowthJev(
          client: MockClient((request) async => validJevWireReply(request))),
    );
    GrowthData? result;
    final future = startRecovery(service).then((value) => result = value);
    await tester.pump();
    for (var i = 0; i < 5 && result == null; i++) {
      await tester.pump(const Duration(seconds: 121));
    }
    expect(result, isNotNull, reason: 'provider calls started: $calls');
    await future;
    final output = result!;
    expect(calls, 2);
    expect(output['pipeline_status'], 'COMPLETE');
  });

  test(
      'changing the AI model invalidates its completed analysis and dependent stages',
      () async {
    final dao = RecoveryDao();
    final initial = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) => recoveryReply(purpose)),
      jev: EvidenceGrowthJev(
          client: MockClient((request) async => finalRequest(request)
              ? http.Response('{}', 503)
              : validJevWireReply(request))),
    );
    final partial = await startRecovery(initial);
    await initial.savePrediction(partial);
    final retryAiCalls = <String>[];
    var jevCalls = 0;
    final service = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) {
        retryAiCalls.add(purpose);
        return recoveryReply(purpose, probability: .65);
      }, model: 'new-model'),
      jev: EvidenceGrowthJev(client: MockClient((request) async {
        jevCalls++;
        expect(finalRequest(request), isTrue);
        return validJevWireReply(request);
      })),
    );
    final result =
        await service.resumePrediction('${partial['id']}', jevApiKey: 'test');
    expect(result['pipeline_status'], 'COMPLETE');
    expect(retryAiCalls, [firstPurpose, synthesisPurpose]);
    expect(growthMap(result['ai'])['execution_likelihood'], .65);
    expect(jevCalls, 1);
  });

  for (final malformed in [
    '{"pattern_code":',
    '{}',
    '{"pattern_code":"no_major_theory_blocker","integrated_pattern":"明确","core_conclusions":[{"factor_ids":["invented"]}]}'
  ]) {
    test(
        'malformed synthesis remains partial and is retried without repeating the first passes: $malformed',
        () async {
      final dao = RecoveryDao();
      final service = EvidenceGrowthActionPredictionService(
        dao: dao,
        ai: RecoveryAi((purpose, _) =>
            purpose == firstPurpose ? recoveryReply(purpose) : malformed),
        jev: EvidenceGrowthJev(
            client: MockClient((request) async => validJevWireReply(request))),
      );
      final partial = await startRecovery(service);
      expect(partial['estimate'], isNull);
      expect(growthMap(partial['forecast_provenance'])['llm_synthesis_reason'],
          'RESPONSE_PARSE_FAILED');
      expect(EvidenceGrowthForecastReportPage.completionNotice(partial),
          contains('返回结果不完整'));
      await service.savePrediction(partial);
      final resumed = EvidenceGrowthActionPredictionService(
        dao: dao,
        ai: RecoveryAi((purpose, _) {
          expect(purpose, synthesisPurpose);
          return recoveryReply(purpose);
        }),
        jev: EvidenceGrowthJev(client: MockClient((request) async {
          expect(finalRequest(request), isTrue);
          return validJevWireReply(request);
        })),
      );
      expect(
          (await resumed.resumePrediction('${partial['id']}',
              jevApiKey: 'test'))['pipeline_status'],
          'COMPLETE');
    });
  }

  test(
      'report identifies AI authentication failures and never copies response bodies or credentials',
      () async {
    final dao = RecoveryDao();
    final service = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) {
        if (purpose == synthesisPurpose)
          throw Exception('HTTP 401: SECRET_TOKEN private response');
        return recoveryReply(purpose);
      }),
      jev: EvidenceGrowthJev(
          client: MockClient((request) async => validJevWireReply(request))),
    );
    final partial = await startRecovery(service);
    expect(EvidenceGrowthForecastReportPage.completionNotice(partial),
        contains('重新配置AI'));
    final diagnostic = EvidenceGrowthForecastReportPage.diagnostics(partial);
    expect(diagnostic, contains('LLM综合: LOCAL_SYNTHESIS; HTTP_401; HTTP 401'));
    expect(diagnostic, isNot(contains('SECRET_TOKEN')));
    expect(jsonEncode(partial), isNot(contains('private response')));
    expect(dao.settings[EvidencePredictionRun.setting],
        isNot(contains('SECRET_TOKEN')));
  });

  testWidgets('final JEV review arriving after 30 seconds is accepted',
      (tester) async {
    final service = EvidenceGrowthActionPredictionService(
      dao: RecoveryDao(),
      ai: RecoveryAi((purpose, _) => recoveryReply(purpose)),
      jev: EvidenceGrowthJev(client: MockClient((request) async {
        if (finalRequest(request))
          await Future<void>.delayed(const Duration(seconds: 35));
        return validJevWireReply(request);
      })),
    );
    GrowthData? result;
    final future = startRecovery(service).then((p) => result = p);
    await tester.pump();
    for (var i = 0; i < 3 && result == null; i++) {
      await tester.pump(const Duration(seconds: 35));
    }
    expect(result, isNotNull);
    await future;
    expect(result!['pipeline_status'], 'COMPLETE');
  });

  test(
      'empty optional questionnaire does not leave synthesis in a permanent retry loop',
      () async {
    final service = EvidenceGrowthActionPredictionService(
      dao: RecoveryDao(),
      ai: RecoveryAi((purpose, _) => purpose == firstPurpose
          ? recoveryReply(purpose)
          : jsonEncode({
              'pattern_code': 'insufficient_evidence',
              'integrated_pattern': '未提交理论因素，不推断根因',
              'core_conclusions': [],
              'interactions': []
            })),
      jev: EvidenceGrowthJev(
          client: MockClient((request) async => validJevWireReply(request))),
    );
    final output = await service.predict(
        plan: '明天去跑步',
        actionProfile: {
          ...recoveryProfile,
          'theory_factor_questionnaire': [],
        },
        eventContract: recoveryContract,
        selectedTheoryIds: ['TPB'],
        jevApiKey: 'test',
        requireJev: true);
    expect(output['pipeline_status'], 'COMPLETE');
    final analysis = growthMap(
        growthMap(output['behavior_diagnosis'])['theory_feedback_analysis']);
    expect(analysis['llm_candidate_conclusions'], isEmpty);
  });

  test(
      'a legacy partial report resumes from its saved successful model results',
      () async {
    final dao = RecoveryDao();
    final initial = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) => recoveryReply(purpose)),
      jev: EvidenceGrowthJev(
          client: MockClient((request) async => finalRequest(request)
              ? http.Response('{}', 503)
              : validJevWireReply(request))),
    );
    final partial = await startRecovery(initial);
    for (final key in [
      'execution_state',
      'execution_identity',
      'execution_run_id'
    ]) {
      partial.remove(key);
    }
    await initial.savePrediction(partial);
    await dao.setSetting(EvidencePredictionRun.setting, '');
    var finalCalls = 0;
    final reopened = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) =>
          throw StateError('must reuse the legacy LLM analysis')),
      jev: EvidenceGrowthJev(client: MockClient((request) async {
        expect(finalRequest(request), isTrue);
        finalCalls++;
        return validJevWireReply(request);
      })),
    );
    final result =
        await reopened.resumePrediction('${partial['id']}', jevApiKey: 'test');
    expect(result['pipeline_status'], 'COMPLETE');
    expect(finalCalls, 1);
    expect(result['ai'], partial['ai']);
  });

  test('cooldown keeps an already validated primary JEV estimate', () async {
    var calls = 0;
    final jev = EvidenceGrowthJev(client: MockClient((request) async {
      calls++;
      return calls == 2 ? http.Response('{}', 429) : validJevWireReply(request);
    }));
    final state = {'plan': '明天去跑步'};
    final partial = await jev.assessAction(state, apiKey: 'test');
    expect(partial['status'], 'JEV');
    expect(partial['overall'], .85);
    final retried =
        await jev.assessAction(state, apiKey: 'test', priorAssessment: partial);
    expect(retried['overall'], .85);
    expect(retried['retry_error'], 'COOLDOWN');
    expect(calls, 2, reason: 'cooldown must not send new requests');
  });

  test(
      'reference forecast retry keeps the same person, works and LLM analysis without new API research',
      () async {
    final dao = RecoveryDao();
    final input = <String, dynamic>{
      'reference_mode': 'PERSON',
      'person_type': 'KNOWN',
      'person_identity': '朋友',
      'action': '明天跑步',
      'fixed_external_context': '同一公园与资源',
      'event_contract': recoveryContract
    };
    final sources = <GrowthData>[
      {
        'id': 'user_1',
        'kind': 'USER_SUPPLIED',
        'title': '用户提供',
        'content': '朋友每周跑步三次'
      }
    ];
    final profile = EvidenceGrowthReferenceForecast.normalizeProfile({
      'execution_likelihood': .85,
      'theory_explanation': '相关跑步习惯支持行动',
      'claims': [
        {
          'claim': '每周跑步三次',
          'source_id': 'user_1',
          'quote': '每周跑步三次',
          'support_score': .85,
          'importance': .8,
          'direction': 'supportive',
          'evidence_kind': 'PAST_BEHAVIOR'
        }
      ],
    }, sources);
    final partial = EvidenceGrowthReferenceForecast.assemble(
        input: input,
        profile: profile,
        sources: sources,
        jev: {'status': 'UNAVAILABLE', 'reason': 'HTTP_503'},
        model: 'recovery-model');
    await dao.setSetting(
        EvidenceGrowthReferenceForecast.historySetting, jsonEncode([partial]));
    final service = EvidenceGrowthReferenceForecast(
      dao: dao,
      ai: RecoveryAi(
          (purpose, _) => throw StateError('must not research or regenerate')),
      jev: EvidenceGrowthJev(client: MockClient((request) async {
        validateJevWireRequest(request);
        expect(request.body, isNot(contains('execution_likelihood')));
        return validJevWireReply(request);
      })),
    );
    final result =
        await service.resumePrediction('${partial['id']}', jevApiKey: 'test');
    expect(result['prediction_complete'], isTrue);
    expect(result['profile'], partial['profile']);
    expect(result['sources'], partial['sources']);
    expect(result['input_snapshot'], partial['input_snapshot']);
    expect(await service.history(), hasLength(2));
  });

  test('recorded outcomes stop resumption before any provider calls', () async {
    final dao = RecoveryDao();
    final service = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, _) => recoveryReply(purpose)),
      jev: EvidenceGrowthJev(
          client: MockClient((request) async => http.Response('{}', 503))),
    );
    final partial = await startRecovery(service);
    await service.savePrediction(partial);
    await dao.setSetting(
        EvidenceGrowthActionPredictionService.historySetting,
        jsonEncode([
          {...partial, 'outcome': 'SUCCESS', 'primary_event_observed': true}
        ]));
    final forbidden = EvidenceGrowthActionPredictionService(
      dao: dao,
      ai: RecoveryAi((purpose, prompt) => throw StateError('must not call AI')),
      jev: EvidenceGrowthJev(
          client:
              MockClient((_) async => throw StateError('must not call JEV'))),
    );
    await expectLater(
        forbidden.resumePrediction('${partial['id']}', jevApiKey: 'test'),
        throwsStateError);
  });
}
