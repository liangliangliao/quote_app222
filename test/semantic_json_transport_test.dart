import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'fixtures/schopenhauer_forms.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';
import 'package:quote_app/services/semantic_json_transport.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const passage = 'There is no recipe for living that suits all cases.';

class NativeHttp extends HttpOverrides {}

class LoopbackSemanticAi extends UnifiedAiService {
  final String endpoint;
  final String provider;
  LoopbackSemanticAi(this.endpoint, {this.provider = 'azure'});
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: provider,
          apiKey: 'fixture',
          model: 'gpt-6-luna',
          endpoint: endpoint,
          label: '模拟',
          displayModel: '模拟模型',
          available: true);
}

String event(Map<String, dynamic> value) => 'data: ${jsonEncode(value)}\n\n';
String piece(String text) => event({
      'choices': [
        {
          'delta': {'content': text}
        }
      ]
    });

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory docs;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('semantic-stream-tests-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    db = await AppDatabase.instance();
    await GlobalAiRequestSettings().saveRaw(
        timeoutSeconds: '',
        maxOutputTokens: '64000',
        temperature: '',
        topP: '',
        retryCount: '3',
        retryDelayMs: '0');
  });
  tearDownAll(() async {
    await db.close();
    await docs.delete(recursive: true);
  });
  Future<void> serverTest(Future<void> Function(HttpRequest) respond,
      Future<void> Function(String) run) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      await respond(r);
    });
    try {
      await HttpOverrides.runWithHttpOverrides(
          () => run(
              'http://127.0.0.1:${server.port}/models/chat/completions?api-version=2024-05-01-preview'),
          NativeHttp());
    } finally {
      await server.close(force: true);
    }
  }

  Future<void> broken(HttpRequest request, String? body) async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    if (body != null) {
      final bytes = utf8.encode(body);
      socket.add(utf8.encode(
          'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nContent-Length: ${bytes.length + 200}\r\nConnection: close\r\n\r\n'));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } else {
      socket.destroy();
    }
  }

  test(
      'complete reading maps stream through Azure without application output caps and cache once',
      () async {
    var calls = 0;
    Map<String, dynamic>? sent;
    const readingSources = [ScopeSource('A', wangQuote)];
    final expected = wangForms();
    expected['concepts'][0]['definition'] = '为某一修习目标进行练习的可辨认的 活动片段。';
    final answer = jsonEncode(expected);
    final events = StringBuffer(': keep-alive\n\n')
      ..write(event({
        'choices': [
          {
            'delta': {'reasoning_content': '不是最终 JSON'}
          }
        ]
      }));
    for (var i = 0; i < answer.length; i += 71)
      events.write(piece(answer.substring(i, math.min(i + 71, answer.length))));
    events.write(event({
      'choices': [
        {'delta': {}, 'finish_reason': 'stop'}
      ]
    }));
    events.write('data: [DONE]\n\n');
    await serverTest((request) async {
      calls++;
      sent = jsonDecode(await utf8.decoder.bind(request).join());
      if (sent!['stream'] != true) {
        await broken(request, null);
        return;
      }
      request.response.headers.set(
          HttpHeaders.contentTypeHeader, 'text/event-stream; charset=utf-8');
      final bytes = utf8.encode(events.toString());
      for (var i = 0; i < bytes.length; i += 113) {
        request.response.add(bytes.sublist(i, math.min(i + 113, bytes.length)));
        await request.response.flush();
      }
      await request.response.close();
    }, (endpoint) async {
      final service = SemanticScopeService(
          ai: LoopbackSemanticAi(endpoint),
          store: CognitiveStore(database: () async => db));
      final result = await service.analyze(
          readingSources, '完整阅读流式验收',
          context: readingMapContext, force: true);
      expect(result.needsRepair, isFalse);
      expect(result.issues, isEmpty); // All conceptual content is traceable; no paid repair.
      expect(result.concepts.first.definition, contains('可辨认的 活动'));
      expect(calls, 1);
      expect(sent!['response_format'], {'type': 'json_object'});
      expect(sent!.containsKey('max_completion_tokens'), isFalse);
      expect(sent!.containsKey('temperature'), isFalse);
      await service.analyze(readingSources, '完整阅读流式验收',
          context: readingMapContext);
      expect(calls, 1);
    });
  });
  test(
      'screenshot header-close failure sends once, with no format-repair request',
      () async {
    var calls = 0;
    await serverTest((request) async {
      calls++;
      await utf8.decoder.bind(request).join();
      await broken(request, null);
    }, (endpoint) async {
      final service = SemanticScopeService(ai: LoopbackSemanticAi(endpoint));
      await expectLater(
          service.analyze(const [ScopeSource('A', passage)], '响应头断线',
              context: readingMapContext, force: true),
          throwsA(isA<SemanticRequestException>()
              .having((e) => e.message, 'message', contains('连接'))));
      expect(calls, 1);
    });
  });
  test(
      'mid-JSON disconnect saves raw failure for review without caching a drawable map or paid repair',
      () async {
    var calls = 0;
    await serverTest((request) async {
      calls++;
      await utf8.decoder.bind(request).join();
      await broken(request, piece('{"concepts":['));
    }, (endpoint) async {
      final service = SemanticScopeService(ai: LoopbackSemanticAi(endpoint));
      await expectLater(
          service.analyze(const [ScopeSource('A', passage)], '半截 JSON',
              context: readingMapContext, force: true),
          throwsA(isA<SemanticRequestException>()));
      expect(calls, 1);
      expect(
          await service.cached(const [ScopeSource('A', passage)], '半截 JSON',
              context: readingMapContext),
          isNull);
      final failed = (await service.archive.history(
          const [ScopeSource('A', passage)], '半截 JSON', readingMapContext)).first;
      expect(failed.status, 'failed');
      expect(failed.raw, contains('concepts'));
    });
  });
  test(
      'explicit output truncation is actionable and never triggers another request',
      () async {
    var calls = 0;
    await serverTest((request) async {
      calls++;
      await utf8.decoder.bind(request).join();
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
      request.response.write(piece('{"concepts":['));
      request.response.write(event({
        'choices': [
          {'delta': {}, 'finish_reason': 'length'}
        ]
      }));
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    }, (endpoint) async {
      await expectLater(
          LoopbackSemanticAi(endpoint).generateText(
              prompt: 'JSON',
              purpose: 'cognition.semantic.v3',
              expectJson: true),
          throwsA(isA<SemanticRequestException>()
              .having((e) => e.message, 'message', contains('未完整返回'))));
      expect(calls, 1);
    });
  });
  test('gateways returning one ordinary JSON response remain compatible',
      () async {
    await serverTest((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'choices': [
          {
            'message': {'content': '{"ok":"完整"}'},
            'finish_reason': 'stop'
          }
        ]
      }));
      await request.response.close();
    }, (endpoint) async {
      expect(
          jsonDecode(await LoopbackSemanticAi(endpoint).generateText(
              prompt: 'JSON',
              purpose: 'cognition.semantic.v3',
              expectJson: true)),
          {'ok': '完整'});
    });
  });
  test('HTTP errors keep their status and ignore the global retry multiplier',
      () async {
    var calls = 0;
    await serverTest((request) async {
      calls++;
      await utf8.decoder.bind(request).join();
      request.response.statusCode = 401;
      request.response.write('{"error":"fixture unauthorized"}');
      await request.response.close();
    }, (endpoint) async {
      await expectLater(
          LoopbackSemanticAi(endpoint).generateText(
              prompt: 'JSON',
              purpose: 'cognition.semantic.v3',
              expectJson: true),
          throwsA(predicate((e) => e.toString().contains('HTTP 401'))));
      expect(calls, 1);
    });
  });
  test(
      'Responses deltas ignore reasoning and do not duplicate the completed body',
      () {
    final stream = SemanticJsonStream();
    stream.addEnvelope(
        {'type': 'response.reasoning_text.delta', 'delta': 'not JSON'});
    stream.addEnvelope(
        {'type': 'response.output_text.delta', 'delta': '{"value":"a '});
    stream.addEnvelope({'type': 'response.output_text.delta', 'delta': 'b"}'});
    stream.addEnvelope({
      'type': 'response.completed',
      'response': {
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': '{"value":"a b"}'}
            ]
          }
        ]
      }
    });
    expect(jsonDecode(stream.finish()), {'value': 'a b'});
  });
  test('multi-line SSE fields and keep-alives assemble one answer', () {
    final stream = SemanticJsonStream();
    for (final line in [
      ': ping',
      '',
      'event: message',
      'data: {"choices": [',
      'data: {"delta":{"content":"{\\"x\\":1}"},"finish_reason":"stop"}]}',
      '',
      'data: [DONE]',
      ''
    ]) stream.addLine(line);
    expect(jsonDecode(stream.finish()), {'x': 1});
  });
  test(
      'reasoning-only and unfinished streams cannot masquerade as complete answers',
      () {
    final reasoning = SemanticJsonStream()
      ..addEnvelope({
        'choices': [
          {
            'delta': {'reasoning_content': '{"fake":1}'},
            'finish_reason': 'stop'
          }
        ]
      });
    expect(reasoning.finish, throwsA(isA<SemanticRequestException>()));
    final partial = SemanticJsonStream()
      ..addEnvelope({
        'choices': [
          {
            'delta': {'content': '{"x":'}
          }
        ]
      });
    expect(partial.finish, throwsA(isA<SemanticRequestException>()));
  });
  test(
      'complete JSON survives a missing terminal marker and a connection closing late',
      () async {
    await serverTest((request) async {
      await utf8.decoder.bind(request).join();
      await broken(request, piece('{"ok":true}'));
    }, (endpoint) async {
      final result = await LoopbackSemanticAi(endpoint).generateText(
          prompt: 'JSON', purpose: 'cognition.semantic.v3', expectJson: true);
      expect(jsonDecode(result), {'ok': true});
    });
  });
  test('the total deadline closes a stalled stream without another send',
      () async {
    var calls = 0;
    await serverTest((request) async {
      calls++;
      await utf8.decoder.bind(request).join();
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
      request.response.write(': waiting\n\n');
      await request.response.flush();
    }, (endpoint) async {
      await expectLater(
          SemanticJsonTransport(totalTimeout: const Duration(milliseconds: 150))
              .post(
                  uri: Uri.parse(endpoint),
                  headers: const {'Content-Type': 'application/json'},
                  body: const {'stream': true},
                  idleTimeout: const Duration(seconds: 2)),
          throwsA(isA<SemanticRequestException>()
              .having((e) => e.message, 'message', contains('超时'))));
      expect(calls, 1);
    });
  });
}
