import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/utils/deepseek_logger.dart';
import 'package:quote_app/will_mirror/v28/case_ai.dart';
import 'package:quote_app/will_mirror/v28/case_analysis.dart';
import 'package:quote_app/will_mirror/v28/case_models.dart';
import 'package:quote_app/will_mirror/v28/case_workflow.dart';

class _Ai extends UnifiedAiService {
  _Ai(this.respond, {this.available = true});
  final String Function(WmJson, int) respond;
  final bool available;
  final List<WmJson> sent = [];
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'mock',
          apiKey: '',
          model: 'mock',
          endpoint: 'https://example.invalid',
          label: '模拟',
          displayModel: 'mock',
          available: available);
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
    expect(purpose, 'will_mirror.v28.case_analysis');
    final j = wmMap(jsonDecode(prompt));
    sent.add(j);
    return respond(j, sent.length);
  }
}

class _Sensitive {
  int reads = 0;
  @override
  String toString() {
    reads++;
    return 'PRIVATE_REQUEST_OR_ERROR';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WmCase c;
  final flow = WmWorkflow();
  setUp(() {
    c = flow.start('case', '允许发送的课题描述').change({'remoteAllowed': true});
  });
  WmJson answer(String name, {double score = 2, String type = 'score'}) => {
        'type': type,
        'name': name,
        'score': score,
        'confidence': .8,
        'probabilities': [
          for (var i = 0; i < 5; i++)
            {'value': i, 'probability': i == 2 ? 1.0 : 0.0}
        ],
      };

  test(
      'per-request evidence selection excludes unapproved facts from every model stage',
      () async {
    final allowed = c.evidence.first.id;
    c = flow.addEvidence(c, text: 'NEVER_SEND_未授权身体信息', kind: WmFactKind.fact);
    final ai = _Ai((j, round) {
      if (round == 1)
        return jsonEncode({...c.analysis.toJson(), 'motives': []});
      return jsonEncode({
        'motives': [
          for (final m in c.analysis.motives)
            {...m.toJson(), 'id': '${m.id}_$round'}
        ]
      });
    });
    final result = await WmCaseAi(ai: ai)
        .generate(c, allowedEvidenceIds: {allowed}, stillAllowed: () => true);
    expect(ai.sent, hasLength(4));
    expect(jsonEncode(ai.sent), isNot(contains('NEVER_SEND')));
    expect(result.analysis.motives.length, lessThan(50));
    expect(result.analysis.receipt, contains('不足'));
    expect(result.facets, isNull);
    expect(result.analysis.routes.every((r) => r.gate != WmGate.clear), isTrue);
  });

  test(
      'no credentials and malformed model references produce honest local fallbacks',
      () async {
    final disabled =
        _Ai((_, __) => throw StateError('must not send'), available: false);
    final result = await WmCaseAi(ai: disabled).generate(c,
        allowedEvidenceIds: {c.evidence.first.id}, stillAllowed: () => true);
    expect(disabled.sent, isEmpty);
    expect(result.analysis.receipt, contains('没有在线推理'));
    final invalid = _Ai((_, __) => jsonEncode({
          ...c.analysis.toJson(),
          'wants': [
            {
              ...c.analysis.wants.first.toJson(),
              'evidenceIds': ['invented']
            }
          ]
        }));
    final fallback = await WmCaseAi(ai: invalid).generate(c,
        allowedEvidenceIds: {c.evidence.first.id}, stillAllowed: () => true);
    expect(fallback.analysis.receipt, contains('本地'));
    expect(fallback.analysis.receipt, isNot(contains('invented')));
    expect(fallback.facets, isNull);
  });

  test('consent cancellation stops all later requests and rejects the response',
      () async {
    var consent = true;
    final ai = _Ai((_, __) {
      consent = false;
      return jsonEncode(c.analysis.toJson());
    });
    expect(
        () => WmCaseAi(ai: ai).generate(c,
            allowedEvidenceIds: {c.evidence.first.id},
            stillAllowed: () => consent),
        throwsA(isA<WmAnalysisCancelled>()));
    await Future<void>.delayed(Duration.zero);
    expect(ai.sent, hasLength(1));
    final unapproved = c.change({'remoteAllowed': false});
    expect(
        () => WmCaseAi(ai: ai).generate(unapproved,
            allowedEvidenceIds: {c.evidence.first.id},
            stillAllowed: () => true),
        throwsFormatException);
  });

  test('Decisions request follows fixed named 0–4 rubrics and exact model', () {
    final request = WmDecisionsClient.request(c, c.analysis.motives);
    expect(request['model'], 'gpt-6-luna');
    expect(
        wmMaps(request['questions']), hasLength(c.analysis.motives.length * 4));
    expect(wmMaps(request['questions']).first['name'],
        '${c.analysis.motives.first.id}__personal_fit');
    expect(wmMaps(wmMaps(request['questions']).first['levels']), hasLength(5));
  });

  test(
      'Decisions parser handles partial, refused, duplicate, swapped, inconsistent and out-of-range answers',
      () {
    final pool = c.analysis.motives;
    final name = '${pool.first.id}__personal_fit';
    final partial = WmDecisionsClient.parse({
      'answers': [answer(name)]
    }, pool);
    expect(partial[pool.first.id]!['personal_fit'], 2.0);
    expect(partial[pool.first.id]!['evidence_quality'], isNull);
    final refused = WmDecisionsClient.parse({
      'answers': [answer(name, type: 'refusal')]
    }, pool);
    expect(refused[pool.first.id]!['personal_fit'], isNull);
    for (final response in [
      {
        'answers': [answer(name), answer(name)]
      },
      {
        'answers': [answer('other__personal_fit')]
      },
      {
        'answers': [answer(name, score: 5)]
      },
      {
        'answers': [answer(name, score: 3)]
      },
      {
        'answers': [
          {...answer(name), 'confidence': -1}
        ]
      },
      {
        'answers': [
          {...answer(name), 'probabilities': []}
        ]
      },
    ]) {
      expect(
          () => WmDecisionsClient.parse(response, pool), throwsFormatException);
    }
    final ranked = const WmAnalysisEngine()
        .rank(c, runId: 'partial', now: 100, remoteFacets: partial);
    expect(wmMap(ranked['scores']), isEmpty);
  });

  test(
      'network failure or malformed response never masquerades as online scores',
      () async {
    for (final response in [
      http.Response('private upstream error', 503),
      http.Response('{"answers": [{"name":"wrong"}]}', 200)
    ]) {
      final scorer = WmDecisionsClient(
          endpoint:
              Uri.parse('https://example.invalid/v1/will-mirror/decisions'),
          accessToken: 'mock-service-token',
          client: MockClient((r) async {
            expect(r.headers['Authorization'], 'Bearer mock-service-token');
            expect(r.body, isNot(contains('apiKey')));
            return response;
          }));
      final result = await scorer.score(c, stillAllowed: () => true);
      expect(result.facets, isNull);
      expect(result.receipt, contains('本地规则降级'));
      expect(result.receipt, isNot(contains('private upstream')));
    }
  });

  test(
      'sensitive request, response and exception payloads are never formatted for host logs',
      () async {
    for (final module in [
      'will_mirror.analysis',
      'unified_ai.will_mirror.v28.case_analysis'
    ]) {
      final secret = _Sensitive();
      await DeepSeekLogger.logRequest(
          module: module,
          endpoint: 'https://example.invalid',
          headers: {'Authorization': 'secret'},
          body: secret);
      await DeepSeekLogger.logResponse(
          module: module,
          endpoint: 'https://example.invalid',
          statusCode: 200,
          body: secret);
      await DeepSeekLogger.logError(
          module: module, endpoint: 'https://example.invalid', error: secret);
      expect(secret.reads, 0);
    }
    expect(DeepSeekLogger.isPrivateModule('unified_ai.other_module'), isFalse);
  });
}
