import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Only model output and native channels are simulated. Database, DAO, sidecar
// lookup, poster reader, history selection and comparison cache are real.
class _DeliveryAi extends UnifiedAiService {
  int calls = 0;
  bool available = true;

  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'delivery-test',
          endpoint: 'https://example.invalid',
          label: 'test',
          displayModel: 'delivery-test',
          available: available);

  @override
  Future<String> generateText({
    required String prompt,
    required String purpose,
    String? systemPrompt,
    int maxTokens = 1800,
    bool expectJson = false,
    String? forcedProvider,
    String? forcedModel,
    double? temperature,
  }) async {
    calls++;
    return jsonEncode({
      'common': '两句都关注面对困难时如何持续行动。',
      'critical_difference': '第一句允许根据新信息调整方法；第二句仍需辨明坚持的是目标还是方法。',
      'not_equivalent': '保持目标与重复同一种方法不能直接等同。',
      'limitation': '新信息是否可靠、目标是否合理，都可能改变判断。',
      'relation_type': 'contrast',
      'relation_scope': 'features',
    });
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;
  late Database db;
  late GeneratedQuote generated;
  late String generatedId, legacyId;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const native = MethodChannel('native.scheduler');

  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('quote_delivery_');
    databaseFactory = databaseFactoryFfi;
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (_) async => docs.path);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (_) async => null);
    db = await AppDatabase.instance();
    final taskId = await TaskDao().create(name: '阅读与比较验收', type: 'auto');
    generated = QuoteAiService.parseResponse(
        jsonEncode({
          'quote': '坚持目标，也要根据新信息调整方法。',
          'author': '测试示例',
          'source': '出处待考',
          'analysis': '目标与方法可以分别审视。以下内容用于验证阅读入口。',
          'practice_activities': ['记录一次尝试，根据观察调整下一步。'],
          'concrete_example': '示例：登山遇到封闭路线，保留登顶目标并改走安全路线。',
          'commonality': '都没有放弃目标。',
          'critical_difference': '是否根据新信息调整行动方式。',
          'boundary': '目标不合理或风险过高时，也可能需要放下目标。',
          'analysis_basis': '“坚持目标”与“调整方法”分别对应目的和手段。',
          'source_status':
              'verified', // A model must not grant itself verification.
          'source_confidence': '高',
        }),
        selectedFigure: '测试示例',
        fallbackTheme: '行动',
        nextCursor: 1);
    final dao = QuoteDao();
    generatedId = await dao.insertQuote(
        taskUid: taskId,
        content: generated.content,
        authorName: generated.author,
        sourceFrom: generated.source,
        explanation: generated.explanation);
    await QuoteInsightStore().saveAddon(
        QuoteReference(
            id: generatedId,
            content: generated.content,
            author: generated.author,
            source: generated.source),
        generated.readingAddon);
    legacyId = await dao.insertQuote(
        taskUid: taskId,
        content: '遇到困难时，继续努力。',
        authorName: '旧记录示例',
        sourceFrom: '出处待考',
        explanation: '原有解读保持不变。');

    final font = File('/tmp/quote-preview-cjk.otf');
    if (font.existsSync()) {
      await (FontLoader('QuotePreviewCJK')
            ..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync()))))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('QuoteXingShu')
          ..addFont(rootBundle.load('assets/fonts/ZhiMangXing-Regular.ttf')))
        .load();
  });

  tearDownAll(() async {
    await db.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(native, null);
    await docs.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('delivery-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'QuotePreviewCJK'),
            home: page)));
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    expect(finder, findsWidgets, reason: 'Production entry failed to load');
  }

  Future<void> capture(WidgetTester tester, String filename) async {
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('delivery-preview')));
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory('build/quote-insight-preview')
        ..createSync(recursive: true);
      File('${output.path}/$filename.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('saved analysis is visible through the actual poster reader',
      (tester) async {
    final rows = await tester.runAsync(() => QuoteDao().latest());
    final row = rows!.singleWhere((row) => row['quote_uid'] == generatedId);
    final payload = <String, dynamic>{
      'quote': row['content'],
      'quoteAuthor': row['author_name'],
      'author': '——${row['author_name']}',
      'source': row['source_from'],
      'quoteUid': row['quote_uid'],
    };
    await mount(
        tester,
        Scaffold(
            body: PosterPureFlutter(
                topic: '行动',
                quote: payload['quote'],
                author: payload['author'],
                note: row['explanation'],
                avatar: '',
                quoteReference: QuoteReference.fromPosterPayload(payload))));
    await tester.pumpAndSettle();
    expect(find.text('具体是什么样子'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await waitFor(tester, find.text('具体是什么样子'));
    expect(find.text('已核对出处'), findsNothing);
    expect(find.text('出处待考'), findsOneWidget);
    expect(find.text('相似与不同'), findsOneWidget);
    expect(find.text('哪些条件下不成立'), findsOneWidget);
    await tester.ensureVisible(find.text('具体是什么样子'));
    await tester.tap(find.text('具体是什么样子'));
    await tester.pumpAndSettle();
    expect(find.text(generated.readingAddon.concreteExample), findsOneWidget);
    await capture(tester, 'reading-example');
    final saved = await tester.runAsync(() => QuoteDao().latest());
    expect(
        saved!.singleWhere(
            (row) => row['quote_uid'] == generatedId)['explanation'],
        generated.explanation);
  });

  testWidgets(
      'stored old and new quotes compare from history and reopen offline',
      (tester) async {
    final ai = _DeliveryAi();
    final service = QuoteComparisonService(ai: ai);
    await mount(tester, HistoryPage(comparisonService: service));
    await waitFor(
        tester, find.byKey(ValueKey('quote-history-row-$generatedId')));
    expect(ai.calls, 0);
    await tester.tap(find.byKey(const ValueKey('quote-select-comparison')));
    await tester.tap(find.byKey(ValueKey('quote-history-row-$generatedId')));
    await tester.tap(find.byKey(ValueKey('quote-history-row-$legacyId')));
    await tester.pumpAndSettle();
    await capture(tester, 'history-selection');
    await tester.tap(find.byKey(const ValueKey('quote-start-comparison')));
    await waitFor(tester, find.text('决定性差异'));
    expect(ai.calls, 1);
    expect(find.text('不能直接等同的部分'), findsOneWidget);
    expect(find.text('适用条件与未知'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-set-diagram')), findsNothing);
    await tester.ensureVisible(find.text('共同点'));
    await tester.pumpAndSettle();
    await capture(tester, 'comparison-result');
    await tester.ensureVisible(find.byTooltip('关闭比较'));
    await tester.tap(find.byTooltip('关闭比较'));
    await tester.pumpAndSettle();
    ai.available = false;
    await tester.tap(find.byKey(const ValueKey('quote-start-comparison')));
    await waitFor(tester, find.text('决定性差异'));
    expect(ai.calls, 1, reason: 'Reopening cached results must work offline');
    expect(tester.takeException(), isNull);
  });
}
