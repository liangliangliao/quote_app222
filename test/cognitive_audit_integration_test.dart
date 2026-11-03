import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/comparison_revisions.dart';
import 'package:quote_app/epistemic/philosophy_benchmark.dart';
import 'package:quote_app/epistemic/philosophy_benchmark_page.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/ai_request_audit.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';
import 'package:quote_app/services/semantic_json_transport.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NativeHttp extends HttpOverrides {}

class _LoopbackAi extends UnifiedAiService {
  final String endpoint;
  _LoopbackAi(this.endpoint);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'azure',
          apiKey: 'local-test-only',
          model: 'gpt-6-luna',
          endpoint: endpoint,
          label: '测试',
          displayModel: '本地假服务',
          available: true);
}

class _BenchmarkAi extends _LoopbackAi {
  int calls = 0;
  _BenchmarkAi() : super('https://example.invalid');
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
    calls++;
    return jsonEncode(_map(philosophyCases.first.sources.first.text));
  }
}

Map<String, dynamic> _map(String source) => {
      'schema_version': 3,
      'recommended_view': 'hierarchy',
      'concepts': [
        {
          'id': 'definition',
          'label': '正方形',
          'definition': '四边相等且四角为直角的四边形',
          'kind': 'concept',
          'status': 'definition',
          'references': [
            {'source': 'A', 'excerpt': source}
          ]
        }
      ],
      'hierarchy': [],
      'relations': [],
      'grounds': [],
      'judgments': [],
    };
Map<String, dynamic> _envelope(String text, {String reason = 'stop'}) => {
      'choices': [
        {
          'message': {'content': text},
          'finish_reason': reason
        }
      ],
      'usage': {
        'prompt_tokens': 52,
        'completion_tokens': 17,
        'completion_tokens_details': {'reasoning_tokens': 5}
      },
    };

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory docs;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('audit-integration-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    db = await AppDatabase.instance();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final font = File('/tmp/quote-preview-cjk.otf');
    if (font.existsSync())
      await (FontLoader('AuditCJK')
            ..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync()))))
          .load();
    await CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true));
    await GlobalAiRequestSettings().saveRaw(
        timeoutSeconds: '',
        maxOutputTokens: '90000',
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
      Future<void> Function(_LoopbackAi) run) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final listener = server.listen((request) async {
      try {
        await respond(request);
      } catch (_) {
        try {
          await request.response.close();
        } catch (_) {}
      }
    });
    try {
      await HttpOverrides.runZoned(
          () => run(_LoopbackAi(
              'http://127.0.0.1:${server.port}/openai/deployments/test/chat/completions')),
          createHttpClient: (context) =>
              _NativeHttp().createHttpClient(context));
    } finally {
      await server.close(force: true);
      await listener.cancel();
    }
  }

  test(
      'text and messages send the visible budget and meter one real attempt each',
      () async {
    final sent = <Map<String, dynamic>>[];
    final operation = AiOperation('audit-loopback');
    await serverTest((request) async {
      sent.add(Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join())));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_envelope(jsonEncode(_map('原句')))));
      await request.response.close();
    }, (ai) async {
      await AiRequestAudit.runOperation(operation, () async {
        await ai.generateText(
            prompt: '原句',
            purpose: 'cognition.semantic.v4',
            maxTokens: 10000,
            expectJson: true);
        await ai.generateChatMessages(
            messages: const [UnifiedAiChatMessage(role: 'user', content: '原句')],
            purpose: 'cognition.semantic.v4',
            maxTokens: 10000,
            expectJson: true);
      });
    });
    expect(sent, hasLength(2));
    expect(sent.map((b) => b['max_completion_tokens']), [10000, 10000]);
    expect(sent.every((b) => b['stream_options']['include_usage'] == true),
        isTrue);
    expect(operation.attempts, hasLength(2));
    expect(
        operation.attempts.every((r) =>
            r['usage']['input'] == 52 &&
            r['usage']['output'] == 17 &&
            r['usage']['reasoning_in_output'] == 5),
        isTrue);
    expect(operation.attempts.first['budget']['global_ceiling'], 90000);
  });
  test('Foundry inference preview does not receive OpenAI-only stream options',
      () async {
    Map? sent;
    await serverTest((request) async {
      sent = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_envelope('{"ok":true}')));
      await request.response.close();
    }, (ai) async {
      final preview = _LoopbackAi(
          ai.endpoint.replaceFirst('/openai/deployments/test/', '/models/'));
      await preview.generateText(
          prompt: '定义', purpose: 'cognition.semantic.v4', expectJson: true);
    });
    expect(sent!['stream'], isTrue);
    expect(sent!.containsKey('stream_options'), isFalse);
  });
  test('task override can exceed the old hidden 10000 cap', () async {
    await AiRequestAudit.setBudget('cognition.semantic.v4', 24000);
    Map? body;
    try {
      await serverTest((request) async {
        body = jsonDecode(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_envelope('{"ok":true}')));
        await request.response.close();
      }, (ai) async {
        await ai.generateText(
            prompt: '定义',
            purpose: 'cognition.semantic.v4',
            maxTokens: 10000,
            expectJson: true);
      });
      expect(body!['max_completion_tokens'], 24000);
    } finally {
      await AiRequestAudit.setBudget('cognition.semantic.v4', 10000);
    }
  });
  test(
      'length reports actual quota, records usage, never stacks three global retries',
      () async {
    var calls = 0;
    final operation = AiOperation('limit');
    await serverTest((request) async {
      calls++;
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response
          .write(jsonEncode(_envelope('{"incomplete":', reason: 'length')));
      await request.response.close();
    }, (ai) async {
      await expectLater(
          AiRequestAudit.runOperation(
              operation,
              () => ai.generateText(
                  prompt: '材料',
                  purpose: 'cognition.semantic.v4',
                  maxTokens: 10000,
                  expectJson: true)),
          throwsA(isA<SemanticRequestException>()
              .having((e) => e.message, 'actual quota', contains('10000'))));
    });
    expect(calls, 1);
    expect(operation.attempts, hasLength(1));
    expect(operation.attempts.single['failure'], 'output_limit');
    expect(operation.attempts.single['usage']['output'], 17);
  });
  test(
      'cancellation closes an active stream without accepting the partial JSON',
      () async {
    final started = Completer<void>();
    final operation = AiOperation('cancel');
    var calls = 0;
    await serverTest((request) async {
      calls++;
      await request.drain<void>();
      request.response.headers.set('content-type', 'text/event-stream');
      request.response.write(
          'data: {"choices":[{"delta":{"content":"{\\"concepts\\":"}}]}\n\n');
      await request.response.flush();
      started.complete();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await request.response.close();
    }, (ai) async {
      final future = AiRequestAudit.runOperation(
          operation,
          () => ai.generateText(
              prompt: '材料',
              purpose: 'cognition.semantic.v4',
              maxTokens: 10000,
              expectJson: true));
      final expectation =
          expectLater(future, throwsA(isA<SemanticRequestException>()));
      await started.future;
      operation.cancellation.cancel();
      await expectation;
    });
    expect(calls, 1);
    expect(operation.attempts.single['failure'], 'cancelled');
  });
  test('explicit local validation cannot start a paid repair', () async {
    final ai = _BenchmarkAi();
    final service = SemanticScopeService(
        ai: ai, store: CognitiveStore(database: () async => db));
    final input = _map('原句');
    input['hierarchy'] = [
      {'parent': 'definition', 'child': 'missing', 'kind': 'subtype'}
    ];
    final value = await service.validateResponse(input,
        const [ScopeSource('A', '原句')], '定义', await ai.resolveGlobalConfig());
    expect(value.needsRepair, isTrue);
    expect(ai.calls, 0);
    expect(value.issues.single.originalItem, isNotNull);
  });
  test('revision append, restoration and pair isolation preserve the original',
      () async {
    final revisions = ComparisonRevisionStore(
        store: CognitiveStore(database: () async => db));
    const a = QuoteReference(id: 'A', content: '方案甲'),
        b = QuoteReference(id: 'B', content: '方案乙');
    const efficient = QuoteComparison(
        common: '同一任务',
        difference: '甲耗时少',
        notEquivalent: '安全条件未知',
        limitation: '风险改变时重判',
        relation: QuoteRelation.contrast,
        justification: '给定材料只比较耗时');
    const safe = QuoteComparison(
        common: '同一任务',
        difference: '乙风险低',
        notEquivalent: '耗时不能代替安全',
        limitation: '风险与资源改变时重判',
        relation: QuoteRelation.contrast,
        justification: '新增风险报告');
    await revisions.append(a, b, efficient, '效率', '耗时优先');
    await revisions.append(a, b, safe, '安全', '风险优先');
    final prior = await revisions.read(a, b);
    await revisions.append(a, b, efficient, '效率', '耗时优先',
        restoredFrom: '${prior.first['id']}');
    final rows = await revisions.read(a, b);
    expect(rows, hasLength(3));
    expect(rows[1]['previous_difference'], '甲耗时少');
    expect(rows.last['restored_from'], prior.first['id']);
    expect(a.content, '方案甲');
    expect(
        await revisions.read(a, const QuoteReference(id: 'C', content: '其他材料')),
        isEmpty);
  });
  test(
      'database chronology orders before pagination regardless of physical IDs',
      () async {
    await db.delete('quotes');
    for (final row in [
      {
        'quote_uid': 'later',
        'content': '后',
        'inserted_at': '2026-11-03 09:00:00'
      },
      {
        'quote_uid': 'earlier',
        'content': '前',
        'inserted_at': '2026-11-01 09:00:00'
      },
      {
        'quote_uid': 'middle',
        'content': '中',
        'inserted_at': '2026-11-02 09:00:00'
      },
    ]) {
      await db.insert('quotes', row);
    }
    final first = await QuoteDao().chronological(limit: 2),
        next = await QuoteDao().chronological(limit: 2, offset: 2);
    expect([...first, ...next].map((r) => r['quote_uid']),
        ['earlier', 'middle', 'later']);
  });
  testWidgets(
      'benchmark browsing makes zero AI calls and explicit one case stays pending',
      (tester) async {
    final ai = _BenchmarkAi();
    final service = PhilosophyBenchmarkService(ai: ai);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('audit-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'AuditCJK'),
            home: PhilosophyBenchmarkPage(service: service))));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(ai.calls, 0);
    await tester.tap(find.text('A · 正方形与长方形'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('运行此组一次'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('运行此组一次'));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    final history = await tester.runAsync(service.history);
    final run = history!.first;
    expect(ai.calls, 1);
    expect(run['review_status'], 'pending');
    expect(run['raw_json'], isNotEmpty);
    expect(run['request_config']['global_output_ceiling'], 90000);
    expect(PhilosophyBenchmarkService.reviewStatus(run), 'pending');
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('audit-preview')));
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output =
          File('build/cognitive-preview/real-model-benchmark-v9.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
