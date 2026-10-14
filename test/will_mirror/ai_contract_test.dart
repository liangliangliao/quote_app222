import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/will_mirror/ai/pipeline.dart';
import 'package:quote_app/will_mirror/ai/protocol.dart';
import 'package:quote_app/will_mirror/ai/decisions_gateway.dart';
import 'package:quote_app/will_mirror/domain/model.dart';
import 'package:quote_app/will_mirror/domain/ranking.dart';
import 'package:quote_app/will_mirror/integration/private_model.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'fixtures.dart';

class FunctionModel implements StructuredModel {
  FunctionModel(this.respond);
  final Future<Json> Function(AnalysisStage, String, Json) respond;
  int calls = 0;
  @override
  Future<bool> available() async => true;
  @override
  Future<String> label() async => 'contract fixture';
  @override
  Future<Json> complete(
      {required AnalysisStage stage,
      required String system,
      required String prompt,
      required Json schema,
      required CancelToken cancel}) async {
    cancel.check();
    calls++;
    return respond(stage, prompt, schema);
  }
}

class ConfigHost extends UnifiedAiService {
  ConfigHost(this.config);
  final UnifiedAiResolvedConfig config;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      config;
}

AnalysisConsent grant(CaseFile f,
        {Set<String>? ids, Set<String> external = const {}}) =>
    AnalysisConsent(
        runId: newId('run'),
        caseId: f.id,
        revision: f.revision,
        evidenceIds: ids ?? f.facts.map((n) => n.id).toSet(),
        sourceCaseIds: external,
        grantedAt: DateTime.now().toUtc());
Json inputOf(String prompt) =>
    jsonMap(jsonDecode(prompt.split('本次授权数据：').last.split('\n上次输出').first));
Json row(MirrorNode n, String id) => {
      'id': id,
      'kind': n.kind.name,
      'body': n.body,
      'evidenceIds': n.evidenceIds,
      'counterIds': n.counterIds,
      'links': n.links,
      'revisionOf': n.revisionOf
    };

void main() {
  test(
      'minimal consent excludes unselected raw data and all of its derivatives',
      () {
    var f = prepared();
    final private = commands.record(f, NodeKind.evidence, {
      'text': 'SENSITIVE_SENTINEL',
      'category': 'capability',
      'source': 'self_report',
      'sensitive': true,
      'scope': 'case_only'
    });
    f = commands.append(f, [private]);
    final derived = motive(f, 1, refs: [private.id]);
    f = commands.append(f, [derived]);
    final visible = CaseAnalysisPipeline.permittedNodes(
        f, grant(f, ids: {f.nodes.first.id}), {}, {});
    expect(visible.map((n) => n.id), isNot(contains(private.id)));
    expect(visible.map((n) => n.id), isNot(contains(derived.id)));
    expect(canonicalJson(visible.map((n) => n.toJson()).toList()),
        isNot(contains('SENSITIVE_SENTINEL')));
  });
  test('cross-case selection requires both explicit case and evidence grants',
      () {
    final a = newCase(), b = newCase('EXTERNAL_SENTINEL');
    final map = {b.nodes.first.id: b.nodes.first};
    final own = grant(a, ids: {a.nodes.first.id, b.nodes.first.id});
    expect(
        CaseAnalysisPipeline.permittedNodes(a, own, map, {}).map((n) => n.id),
        isNot(contains(b.nodes.first.id)));
    final both =
        grant(a, ids: {a.nodes.first.id, b.nodes.first.id}, external: {b.id});
    expect(
        CaseAnalysisPipeline.permittedNodes(a, both, map, {}).map((n) => n.id),
        contains(b.nodes.first.id));
  });
  test('seals are sent only if the complete linked source set was authorized',
      () {
    var f = prepared();
    f = commands.sealPlan(f, planBody(f));
    final rootOnly = grant(f, ids: {f.nodes.first.id});
    expect(
        CaseAnalysisPipeline.permittedNodes(f, rootOnly, {}, {})
            .any((n) => n.kind == NodeKind.seal),
        isFalse);
    final complete = grant(f);
    expect(
        CaseAnalysisPipeline.permittedNodes(f, complete, {}, {})
            .any((n) => n.kind == NodeKind.seal),
        isTrue);
  });
  test(
      'stage schema repair is bounded and unauthorized references never commit',
      () async {
    final f = prepared();
    final model = FunctionModel((stage, prompt, schema) async {
      final data = inputOf(prompt);
      return {
        'records': [
          row(motive(f, 1, refs: ['UNSENT']), '${data['idPrefix']}1')
        ],
        'summary': 'fixture',
        'unknowns': []
      };
    });
    var commits = 0;
    await expectLater(
        CaseAnalysisPipeline(model).run(
            file: f,
            consent: grant(f),
            cancel: CancelToken(),
            onlyStage: AnalysisStage.motives,
            commit: (a, b, s) async {
              commits++;
            },
            progress: (s, d) {}),
        throwsA(isA<MirrorProblem>()));
    expect(model.calls, 2);
    expect(commits, 0);
  });
  test('cancellation before model request retains the original case', () async {
    final f = newCase();
    final model = FunctionModel((s, p, j) async => {});
    final cancel = CancelToken()..cancel();
    await expectLater(
        CaseAnalysisPipeline(model).run(
            file: f,
            consent: grant(f),
            cancel: cancel,
            commit: (a, b, s) async => fail('late write'),
            progress: (s, d) {}),
        throwsA(isA<MirrorProblem>()));
    expect(model.calls, 0);
  });
  test(
      'multi-batch generation and independent semantic audit produce an honest bounded pool',
      () async {
    final f = prepared();
    var index = 0, audits = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      if (prompt.startsWith('这是独立语义审查')) {
        audits++;
        final values = jsonDecode(prompt.split('\n').last) as List;
        return {
          'items': [
            for (final n in values)
              {'id': n['id'], 'duplicateOf': null, 'reason': '契约测试占位，不作为真实质量评估'}
          ]
        };
      }
      final data = inputOf(prompt);
      return {
        'records': [
          for (var n = 0; n < 18; n++)
            row(motive(f, index++), '${data['idPrefix']}$n')
        ],
        'summary': '契约测试候选',
        'unknowns': []
      };
    });
    final checkpoints = <CaseFile>[];
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.motives,
        commit: (a, b, s) async {
          checkpoints.add(b);
        },
        progress: (s, d) {});
    expect(result.current(NodeKind.motive), hasLength(54));
    expect(audits, 3);
    expect(checkpoints, hasLength(4));
    expect(result.latest(NodeKind.recommendation)!.objects('ranked'),
        hasLength(5));
  });
  test('semantic paraphrases do not get counted just to reach fifty', () async {
    final f = prepared();
    var index = 0;
    final model = FunctionModel((stage, prompt, schema) async {
      if (prompt.startsWith('这是独立语义审查')) {
        final values = jsonDecode(prompt.split('\n').last) as List;
        return {
          'items': [
            for (var i = 0; i < values.length; i++)
              {
                'id': values[i]['id'],
                'duplicateOf': i == 0 ? null : values.first['id'],
                'reason': '契约测试：相同机制的改写'
              }
          ]
        };
      }
      final data = inputOf(prompt);
      return {
        'records': [
          for (var n = 0; n < 18; n++)
            row(motive(f, index++), '${data['idPrefix']}$n')
        ],
        'summary': '重复候选',
        'unknowns': []
      };
    });
    final result = await CaseAnalysisPipeline(model).run(
        file: f,
        consent: grant(f),
        cancel: CancelToken(),
        onlyStage: AnalysisStage.motives,
        commit: (a, b, s) async {},
        progress: (s, d) {});
    expect(result.current(NodeKind.motive), hasLength(1));
    expect(result.analysisMessage, contains('尚未达到 50 条'));
    expect(model.calls, 8);
  });
  test(
      'OpenAI structured request uses host config without storing or logging content',
      () async {
    late Json sent;
    late Uri endpoint;
    final host = ConfigHost(const UnifiedAiResolvedConfig(
        provider: 'openai',
        apiKey: 'test-token',
        model: 'gpt-test',
        endpoint: 'https://example.test/v1/responses',
        label: 'test',
        displayModel: 'test',
        available: true));
    final model = HostPrivateModel(
        host: host,
        clientFactory: () => MockClient((request) async {
              sent = jsonMap(jsonDecode(request.body));
              endpoint = request.url;
              expect(request.headers['Authorization'], 'Bearer test-token');
              return http.Response(
                  jsonEncode({
                    'status': 'completed',
                    'output': [
                      {
                        'content': [
                          {
                            'type': 'output_text',
                            'text':
                                '{"records":[],"summary":"ok","unknowns":[]}'
                          }
                        ]
                      }
                    ]
                  }),
                  200);
            }));
    final result = await model.complete(
        stage: AnalysisStage.understand,
        system: systemProtocol,
        prompt: 'private test',
        schema: stageSchema(AnalysisStage.understand),
        cancel: CancelToken());
    expect(result['summary'], 'ok');
    expect(endpoint.path, '/v1/responses');
    expect(sent['store'], false);
    expect(sent['text']['format']['strict'], true);
  });
  test('private model never forwards upstream error bodies', () async {
    final host = ConfigHost(const UnifiedAiResolvedConfig(
        provider: 'deepseek',
        apiKey: 'test',
        model: 'test',
        endpoint: 'https://example.test/chat/completions',
        label: 'test',
        displayModel: 'test',
        available: true));
    final model = HostPrivateModel(
        host: host,
        clientFactory: () => MockClient(
            (request) async => http.Response('PRIVATE_UPSTREAM_BODY', 429)));
    try {
      await model.complete(
          stage: AnalysisStage.understand,
          system: '',
          prompt: '',
          schema: {},
          cancel: CancelToken());
      fail('expected error');
    } on MirrorProblem catch (e) {
      expect(e.message, contains('429'));
      expect(e.message, isNot(contains('PRIVATE_UPSTREAM_BODY')));
    }
  });
  test('Decisions refusal and name mismatch have no manufactured zero scores',
      () async {
    var f = prepared();
    f = commands.append(f, [motive(f, 1)]);
    final gateway = DecisionsGateway(
        clientFactory: () => MockClient((request) async => http.Response(
            jsonEncode({
              'rubric_version': rubricVersion,
              'case_id': f.id,
              'model': 'gpt-6-luna',
              'scores': [
                {'motive_id': 'forged', 'facets': []}
              ]
            }),
            200)));
    final rank = await gateway.score(
        f,
        const MirrorSettings(
            remoteScoring: true,
            gatewayUrl: 'https://example.test',
            gatewayAccessToken: 'test-test-test-test'),
        CancelToken());
    expect(rank.text('method'), 'rules');
    expect(rank.objects('ranked').single['priority'], isNull);
  });
  test(
      'strict model schemas require every declared property and no additional properties',
      () {
    void visit(dynamic node) {
      if (node is Map) {
        if (node['type'] == 'object') {
          expect(node['additionalProperties'], false);
          expect((node['required'] as List).toSet(),
              (node['properties'] as Map).keys.toSet());
        }
        for (final value in node.values) {
          visit(value);
        }
      } else if (node is List) {
        for (final value in node) {
          visit(value);
        }
      }
    }

    for (final stage in AnalysisStage.values) {
      visit(stageSchema(stage));
    }
  });
}
