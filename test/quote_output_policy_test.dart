import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/kv_dao.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';
import 'package:quote_app/services/ai_output_policy.dart';
import 'package:quote_app/services/ai_request_audit.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/widgets/ai_budget_panel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Native extends HttpOverrides {}

class _Ai extends UnifiedAiService {
  final String address, provider;
  _Ai(this.address, this.provider);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: provider,
          apiKey: 'test-only',
          model: provider == 'azure' ? 'gpt-6-luna' : 'test-model',
          endpoint: address,
          label: '离线服务',
          displayModel: '回环服务',
          available: true);
}

class _ClaudeAi extends UnifiedAiService {
  final String address;
  _ClaudeAi(this.address);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'azure',
          apiKey: 'test-only',
          model: 'claude-test',
          deployment: 'claude-test',
          endpoint: address,
          label: '离线服务',
          displayModel: '回环服务',
          available: true);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory folder;
  late Database db;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    folder = await Directory.systemTemp.createTemp('unbounded-output-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => folder.path);
    db = await AppDatabase.instance();
    await KeyValueDao()
        .setString(GlobalAiRequestSettings.maxOutputTokensKey, '90000');
    await KeyValueDao().setString('ai.task_budget.cognition.semantic', '24000');
  });
  tearDownAll(() async {
    await db.close();
    await folder.delete(recursive: true);
  });
  const keys = [
    'max_tokens',
    'max_completion_tokens',
    'max_output_tokens',
    'maxOutputTokens'
  ];
  for (final provider in [
    'azure',
    'openai',
    'deepseek',
    'openrouter',
    'edenai',
    'xgrok',
    'gemini'
  ]) {
    test(
        '$provider omits optional output quotas for both text and chat despite old settings',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <Map>[];
      server.listen((request) async {
        expect(request.method, 'POST');
        bodies.add(jsonDecode(await utf8.decoder.bind(request).join()));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'choices': [
            {
              'message': {'content': '{"ok":true}'},
              'finish_reason': 'stop'
            }
          ],
          'usage': {'prompt_tokens': 12, 'completion_tokens': 8}
        }));
        await request.response.close();
      });
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          final ai =
              _Ai('http://127.0.0.1:${server.port}/chat/completions', provider);
          expect(
              await ai.generateText(
                  prompt: '测试',
                  purpose: 'cognition.semantic.v7',
                  maxTokens: 4000,
                  expectJson: true),
              contains('ok'));
          expect(
              await ai.generateChatMessages(
                  messages: const [
                    UnifiedAiChatMessage(role: 'user', content: '测试')
                  ],
                  purpose: 'output.policy.chat',
                  maxTokens: 2000,
                  expectJson: true),
              contains('ok'));
        }, _Native());
      } finally {
        await server.close(force: true);
      }
      expect(bodies.length, 2);
      expect(
          bodies.every((body) => keys.every((key) => !body.containsKey(key))),
          isTrue);
      final cfg = await GlobalAiRequestSettings().getConfig();
      expect(cfg.maxOutputTokens, isNull);
      expect(cfg.resolveMaxTokens(1800), 0);
    });
  }
  test('OpenAI Responses also omits max_output_tokens', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map? body;
    server.listen((request) async {
      body = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': '{"ok":true}'}
            ]
          }
        ],
        'status': 'completed'
      }));
      await request.response.close();
    });
    try {
      await HttpOverrides.runWithHttpOverrides(() async {
        await _Ai('http://127.0.0.1:${server.port}/responses', 'openai')
            .generateText(
                prompt: '测试',
                purpose: 'cognition.semantic.v7',
                maxTokens: 10000,
                expectJson: true);
      }, _Native());
    } finally {
      await server.close(force: true);
    }
    expect(body!.containsKey('max_output_tokens'), isFalse);
  });
  test(
      'mandatory Anthropic field uses advertised model capacity and caches metadata, never a task budget',
      () async {
    var reads = 0;
    final client = MockClient((request) async {
      reads++;
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/models/custom-capacity');
      return http.Response(
          jsonEncode({'id': 'custom-capacity', 'max_tokens': 163840}), 200);
    });
    final uri = Uri.parse('https://example.invalid/v1/messages');
    expect(
        await AiOutputPolicy.anthropicCapacity(uri, {}, 'custom-capacity',
            client: client),
        163840);
    expect(
        await AiOutputPolicy.anthropicCapacity(uri, {}, 'custom-capacity',
            client: client),
        163840);
    expect(reads, 1);
    client.close();
  });
  test(
      'Claude semantic text and chat use advertised deployment capacity and stream without paid probing or retries',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var metadataReads = 0;
    final sent = <Map>[];
    server.listen((request) async {
      if (request.method == 'GET') {
        metadataReads++;
        expect(request.uri.path, '/anthropic/v1/models/claude-test');
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"max_tokens":163840}');
        await request.response.close();
        return;
      }
      sent.add(jsonDecode(await utf8.decoder.bind(request).join()));
      expect(request.headers.value('Accept'), 'text/event-stream');
      request.response.headers.contentType =
          ContentType('text', 'event-stream');
      for (final event in [
        {
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': '{"ok":true}'}
        },
        {
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
          'usage': {'output_tokens': 8}
        },
        {'type': 'message_stop'}
      ]) {
        request.response.writeln('data: ${jsonEncode(event)}\n');
      }
      await request.response.close();
    });
    final operation = AiOperation('claude-output-test');
    try {
      await HttpOverrides.runWithHttpOverrides(() async {
        final ai =
            _ClaudeAi('http://127.0.0.1:${server.port}/anthropic/v1/messages');
        await AiRequestAudit.runOperation(operation, () async {
          expect(
              await ai.generateText(
                  prompt: '测试',
                  purpose: 'cognition.semantic.v7',
                  maxTokens: 2000,
                  expectJson: true),
              contains('ok'));
          expect(
              await ai.generateChatMessages(
                  messages: const [
                    UnifiedAiChatMessage(role: 'user', content: '测试')
                  ],
                  purpose: 'cognition.semantic.v7',
                  maxTokens: 4000,
                  expectJson: true),
              contains('ok'));
        });
      }, _Native());
    } finally {
      await server.close(force: true);
    }
    expect(metadataReads, 1);
    expect(sent.length, 2);
    expect(sent.every((b) => b['max_tokens'] == 163840 && b['stream'] == true),
        isTrue);
    expect(
        operation.attempts.every((r) =>
            r['budget']['application_limit'] == null &&
            r['budget']['provider_required_capacity'] == 163840),
        isTrue);
  });
  test(
      'usage labels distinguish historical budgets from new unlimited requests and required protocol capacity',
      () {
    expect(
        aiHistoricalOutputPolicy({
          'budget': {'effective': 90000}
        }),
        '历史请求的输出上限：90000');
    expect(
        aiHistoricalOutputPolicy({
          'budget': {'policy': 'service_capacity', 'application_limit': null}
        }),
        '应用输出上限：未设置');
    expect(
        aiHistoricalOutputPolicy({
          'budget': {
            'policy': 'service_capacity',
            'provider_required_capacity': 163840
          }
        }),
        contains('协议必填的模型容量 163840'));
  });
  test(
      'unknown required capacity never silently falls back to an arbitrary quota',
      () async {
    final client = MockClient((_) async => http.Response('{}', 404));
    await expectLater(
        AiOutputPolicy.anthropicCapacity(
            Uri.parse('https://example.invalid/v1/messages'),
            {},
            'unknown-capacity',
            client: client),
        throwsStateError);
    client.close();
  });
  test(
      'all direct Dart adapters and native voice have no optional output fields or length-escalation loop',
      () {
    final sources = [
      'lib/concept_engine/concept_engine_service.dart',
      'lib/movie_role_lab/movie_role_lab_service.dart',
      'lib/evidence_growth/evidence_growth_reference_research.dart',
      'lib/zhixing_tree/zhixing_remote_knowledge_service.dart',
      'lib/will_mirror/integration/private_model.dart',
    ];
    for (final path in sources) {
      final source = File(path).readAsStringSync();
      expect(
          RegExp(r"'max_(?:output_tokens|completion_tokens|tokens)'\s*:")
              .hasMatch(source),
          isFalse,
          reason: path);
      if (source.contains("body['max_tokens']"))
        expect(source, contains('AiOutputPolicy.anthropicCapacity'));
    }
    final native = File(
            'android/app/src/main/kotlin/com/example/quote_app/VoiceAlarmActivity.kt')
        .readAsStringSync();
    expect(
        RegExp(r'\.put\("max_(?:output_tokens|completion_tokens|tokens)"')
            .hasMatch(native),
        isFalse);
    expect(native, isNot(contains('.put(maxTokensField,')));
    expect(native, isNot(contains('ai.call.retryLength')));
  });
}
