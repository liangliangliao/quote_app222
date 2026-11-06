import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/concept_circle_preview.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/quote_cognitive_reader.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/semantic_analysis_archive.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/quote_knowledge/history_meaning_view.dart';
import 'package:quote_app/quote_knowledge/repository.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/utils/ai_log_display.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/nietzsche_body.dart';

const sources = [ScopeSource('A', bodyQuote)];
const focus = '分析整句中的概念及其关系';

class _Ai extends UnifiedAiService {
  final prompts = <String>[];
  Completer<String>? delayed;
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'offline',
          endpoint: 'https://example.invalid',
          label: '离线',
          displayModel: '离线夹具',
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
      double? temperature}) async {
    prompts.add(prompt);
    return delayed == null ? jsonEncode(bodyGraph()) : await delayed!.future;
  }
}

class _FailingArchive extends SemanticAnalysisArchive {
  bool fail = true;
  _FailingArchive(Database db) : super(database: () async => db);
  @override
  Future<SavedSemanticAnalysis> save(
      List<ScopeSource> sources, String focus, SemanticContext context,
      {SemanticScope? analysis,
      String raw = '',
      String error = '',
      bool activate = true}) {
    if (fail) throw StateError('模拟本地写入失败');
    return super.save(sources, focus, context,
        analysis: analysis, raw: raw, error: error, activate: activate);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory folder;
  late Database db;
  late _Ai ai;
  late SemanticAnalysisArchive archive;
  late SemanticScopeService service;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    folder = await Directory.systemTemp.createTemp('grounded-widgets-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => folder.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    db = await AppDatabase.instance();
    await db.execute(
        'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)');
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final file = File('/tmp/quote-preview-cjk.otf');
    if (file.existsSync())
      await (FontLoader('GraphCJK')
            ..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync()))))
          .load();
  });
  tearDownAll(() async {
    await db.close();
    await folder.delete(recursive: true);
  });
  setUp(() async {
    await db.delete('app_kv',
        where: 'key GLOB ?', whereArgs: ['cognition.scope.saved.*']);
    await db.delete('app_kv',
        where: 'key GLOB ?', whereArgs: ['cognition.semantic.*']);
    await db.delete('quotes');
    await CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true));
    ai = _Ai();
    archive = SemanticAnalysisArchive(database: () async => db);
    service = SemanticScopeService(
        ai: ai,
        store: CognitiveStore(database: () async => db),
        archiveStore: archive);
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 20));
    }
    await t.pumpAndSettle();
  }

  Future<void> mount(WidgetTester t, Widget child,
      {double width = 500, double scale = 1}) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.binding.setSurfaceSize(Size(width, 1100));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(RepaintBoundary(
        key: const ValueKey('grounded-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'GraphCJK',
                colorSchemeSeed: const Color(0xff75679c)),
            builder: (c, ch) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: ch!),
            home: Scaffold(
                backgroundColor: const Color(0xfffaf7ee),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(12), child: child)))));
    await settle(t);
  }

  Future<void> capture(WidgetTester t, String name) async {
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('grounded-preview')))
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/cognitive-preview/v13-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<SemanticScope> saved() async {
    final v = SemanticScope.parse(bodyGraph(), sources);
    await archive.save(sources, focus, readingMapContext,
        analysis: v, raw: jsonEncode(bodyGraph()));
    return v;
  }

  testWidgets(
      'typed content graph and actual extension circles render, grounded in the concrete body case',
      (t) async {
    final v = (await t.runAsync(saved))!;
    await mount(
        t,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('截图名言 · 离线教学图验收（非真实模型输出）'),
          const Text(bodyQuote),
          ConceptCirclePreview(value: v, withGrounding: true)
        ]));
    await capture(t, 'typed-grounding');
    await mount(
        t,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('同一时段的一项自我评价 / 生活片段：分开论域'),
          ConceptMeaningNetwork(value: v)
        ]));
    expect(find.byType(ConceptMeaningNetwork), findsOneWidget);
    await capture(t, 'meaning-circles');
    await mount(t, GroundRelationView(v.grounds.single, value: v));
    expect(find.textContaining('1. 全不受身体需要影响'), findsOneWidget);
    expect(find.textContaining('2. 案例明确给出'), findsOneWidget);
    expect(find.textContaining('回到具体内容：尿意打断发言并去如厕'), findsOneWidget);
    await capture(t, 'epistemic-ground');
    await mount(t, GroundRelationView(v.grounds.single, value: v),
        width: 320, scale: 2);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'shared reader keeps a single analysis across intuition, concept, circle and judgment tabs; retry critiques old result',
      (t) async {
    await t.runAsync(saved);
    await mount(
        t,
        QuoteCognitiveReader(
            quote: const QuoteReference(
                id: 'body', content: bodyQuote, author: '尼采'),
            topic: '身体与自我评价',
            authorLabel: '尼采',
            note: '',
            semanticService: service));
    final state = t.state<SemanticScopePanelState>(
        find.byType(SemanticScopePanel, skipOffstage: false));
    for (final tab in ['概念', '含义圈', '判断', '直观']) {
      final target = find.text(tab).first;
      await t.ensureVisible(target);
      await t.tap(target);
      await settle(t);
      expect(
          identical(
              t.state(find.byType(SemanticScopePanel, skipOffstage: false)),
              state),
          isTrue);
      expect(find.byKey(const ValueKey('semantic-analysis-action')),
          findsOneWidget);
    }
    expect(ai.prompts, isEmpty);
    expect(find.textContaining('Token'), findsNothing);
    expect(find.textContaining('应用不设置'), findsNothing);
    await t
        .ensureVisible(find.byKey(const ValueKey('semantic-analysis-action')));
    await t.tap(find.byKey(const ValueKey('semantic-analysis-action')));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, '哪里不满意（可不填）'), '请核对身体部分和类属的区别，并补直观内容');
    await t.tap(find.text('重试深入分析'));
    await settle(t);
    expect(ai.prompts, hasLength(1));
    expect(ai.prompts.single, contains('请核对身体部分和类属的区别，并补直观内容'));
    expect(ai.prompts.single, contains('previous_analysis'));
    expect(
        await t
            .runAsync(() => archive.history(sources, focus, readingMapContext)),
        hasLength(2));
    unawaited(state.showSavedAnalyses());
    await settle(t);
    expect(find.text('本地分析版本'), findsOneWidget);
    expect(find.textContaining('完整结果'), findsNWidgets(2));
    await t.tap(find.textContaining('完整结果').last);
    await settle(t);
    expect(ai.prompts, hasLength(1));
  });

  testWidgets(
      'local-save retry keeps the returned graph and never calls AI again',
      (t) async {
    final failing = _FailingArchive(db);
    final svc = SemanticScopeService(
        ai: ai,
        store: CognitiveStore(database: () async => db),
        archiveStore: failing);
    final key = GlobalKey<SemanticScopePanelState>();
    await mount(
        t,
        SemanticScopePanel(
            key: key,
            sources: sources,
            focus: focus,
            analysisContext: readingMapContext,
            service: svc));
    await t.tap(find.byKey(const ValueKey('semantic-analysis-action')));
    await settle(t);
    expect(key.currentState!.result, isNotNull);
    expect(key.currentState!.savePending, isTrue);
    expect(ai.prompts, hasLength(1));
    failing.fail = false;
    await t.runAsync(() => key.currentState!.retrySave());
    await settle(t);
    expect(key.currentState!.savePending, isFalse);
    expect(
        (await t.runAsync(
                () => archive.current(sources, focus, readingMapContext)))!
            .analysis!
            .scopeRelations,
        hasLength(7));
    expect(ai.prompts, hasLength(1));
  });
  testWidgets(
      'history renders saved meaning regions without an automatic AI request and keeps definitions in separate sessions',
      (t) async {
    await t.runAsync(saved);
    final second = bodyGraph()..['purpose'] = '用另一考量理解身体与评价';
    await t.runAsync(() => archive.save(
        sources, '另一考量', const SemanticContext(purpose: '另一考量'),
        analysis: SemanticScope.parse(second, sources)));
    final row = {
      'quote_uid': 'body',
      'content': bodyQuote,
      'author_name': '尼采',
      'inserted_at': '2026-11-06T00:00:00Z'
    };
    await t.runAsync(() => db.insert('quotes', row));
    final repo = QuoteKnowledgeRepository(database: () async => db);
    await mount(
        t,
        HistoryMeaningView(
            repository: repo,
            quotes: [row],
            categoryLabel: '全部',
            service: service));
    expect(
        find.byKey(const ValueKey('history-meaning-circles')), findsOneWidget);
    expect(find.byType(ConceptMeaningNetwork), findsOneWidget);
    expect(
        (t.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)))
            .items,
        hasLength(2));
    expect(ai.prompts, isEmpty);
    await capture(t, 'history-meaning');
  });
  test(
      'log display removes usage fields but preserves original diagnostic records and answer text',
      () {
    const raw =
        'Provider: azure\nBody:\n{"usage":{"total_tokens":123},"budget":{"effective":90000},"request_parameters":{"temperature":0.2,"max_tokens":5000},"choices":[{"message":{"content":"原句包含 token 一词"}}]}';
    final display = aiLogDisplayDetail(raw);
    expect(display, isNot(contains('total_tokens')));
    expect(display, isNot(contains('max_tokens')));
    expect(display, isNot(contains('90000')));
    expect(display, contains('原句包含 token 一词'));
    expect(display, contains('temperature'));
    expect(raw, contains('total_tokens'));
  });
}
