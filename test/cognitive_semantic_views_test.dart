import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/concept_explorer.dart';
import 'package:quote_app/epistemic/concept_hierarchy_view.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/quote_cognitive_reader.dart';
import 'package:quote_app/epistemic/quote_concept_catalog.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/widgets/quote_comparison_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/cognition_v4.dart';

class ScriptedAi extends UnifiedAiService {
  final List<dynamic> answers;
  int calls = 0;
  final List<String> prompts = [];
  ScriptedAi(this.answers);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'test-model',
          endpoint: 'https://example.invalid',
          label: 'test',
          displayModel: '验收样例 · 模拟模型',
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
    final answer = answers[calls.clamp(0, answers.length - 1)];
    calls++;
    if (answer is Exception) throw answer;
    if (answer is Completer<String>) return answer.future;
    return answer is String ? answer : jsonEncode(answer);
  }
}

class ComparisonFixture extends QuoteComparisonService {
  @override
  Future<QuoteComparison> compareForPurpose(QuoteReference a, QuoteReference b,
          ComparisonPurpose purpose, String conditions) async =>
      QuoteComparison(
          common: '都涉及人如何面向生活。',
          difference: 'A讨论意义与回应，B讨论意欲活动。',
          notEquivalent: '回应责任不能直接等同于意欲虚无。',
          limitation: '具体处境尚需补充。',
          relation: QuoteRelation.contrast,
          semanticMap: comparisonMap(),
          modelDisplayName: '验收样例 · 模拟模型');
}

class ControlledScopes extends SemanticScopeService {
  final requests = <Completer<SemanticScope>>[];
  @override
  Future<SemanticScope?> cached(List<ScopeSource> sources, String focus,
          {SemanticContext context = const SemanticContext()}) async =>
      null;
  @override
  Future<SemanticScope> analyze(List<ScopeSource> sources, String focus,
      {bool force = false, SemanticContext context = const SemanticContext()}) {
    final request = Completer<SemanticScope>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;
  late Database appDb;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('semantic-views-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    await (FontLoader('QuoteSignatureLatin')
          ..addFont(rootBundle.load('assets/fonts/Allura-Regular.ttf')))
        .load();
    appDb = await AppDatabase.instance();
    await CognitivePreferenceStore.instance.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in {'PreviewCJK': '/tmp/quote-preview-cjk.otf'}.entries) {
      final file = File(font.value);
      if (file.existsSync())
        await (FontLoader(font.key)
              ..addFont(
                  Future.value(ByteData.sublistView(file.readAsBytesSync()))))
            .load();
    }
  });
  tearDownAll(() async {
    await appDb.close();
    await docs.delete(recursive: true);
  });
  setUp(() async => CognitivePreferenceStore.instance.update(
      const CognitivePreferences(
          enabled: true, style: CognitiveStyle.conceptual)));

  test(
      'hierarchy preserves subtype versus individual experience and contextual IDs',
      () {
    final value = happinessScope();
    expect(value.hierarchy.map((e) => e.kind), ['subtype', 'instance']);
    expect(value.concepts.last.kind, 'experience');
    final restored = SemanticScope.parse(
        value.toJson(), const [ScopeSource('A', happiness)]);
    expect(restored.hierarchy.last.child, 'walk');
    final raw = happinessMap();
    (raw['concepts'] as List)
        .add(node('other-happiness', '幸福', '另一语境中的同名词', happiness));
    expect(
        SemanticScope.parse(raw, const [ScopeSource('A', happiness)])
            .concepts
            .where((n) => n.label == '幸福')
            .length,
        2);
    (raw['hierarchy'] as List).add({
      'parent': 'process',
      'child': 'happiness',
      'kind': 'subtype',
      'explanation': '错误循环',
      'references': refs('A', happiness)
    });
    final partial =
        SemanticScope.parse(raw, const [ScopeSource('A', happiness)]);
    expect(partial.hierarchy.length, 2);
    expect(partial.needsRepair, isTrue);
  });
  test('four circles satisfy nested and multiple overlap constraints together',
      () {
    final cluster = ConceptCircleLayout.build(networkScope()).single;
    expect(cluster.verified, isTrue);
    expect(cluster.circles.length, 4);
    MeaningCircle c(String id) =>
        cluster.circles.singleWhere((c) => c.ids.contains(id));
    expect((c('apple').center - c('fruit').center).distance + c('apple').radius,
        lessThan(c('fruit').radius));
    expect(
        (c('banana').center - c('fruit').center).distance + c('banana').radius,
        lessThan(c('fruit').radius));
    for (final id in ['fruit', 'apple']) {
      final a = c('red'), b = c(id), d = (a.center - b.center).distance;
      expect(d, lessThan(a.radius + b.radius));
      expect(d, greaterThan((a.radius - b.radius).abs()));
    }
  });
  test('contradictory circle constraints use local diagrams', () {
    final raw = networkMap();
    final inverse = jsonDecode(jsonEncode((raw['relations'] as List).first))
        as Map<String, dynamic>;
    inverse['node_ids'] = ['fruit', 'apple'];
    inverse['scope'].addAll({
      'set_a': '水果',
      'set_b': '苹果',
      'criterion_a': '可供食用的果实',
      'criterion_b': '属于苹果的果实'
    });
    (raw['relations'] as List).add(inverse);
    final value =
        SemanticScope.parse(raw, const [ScopeSource('A', networkText)]);
    expect(
        value.issues.any((issue) => issue.message.contains('不能同时成立')), isTrue);
    expect(value.relations.where((r) => r.scope != null).length,
        lessThan((raw['relations'] as List).length));
  });
  test('non-set philosophical questions recommend grounded alternate views',
      () {
    final value = SemanticScope.parse(comparisonMap(),
        const [ScopeSource('A', frankl), ScopeSource('B', willing)]);
    expect(value.relations, isEmpty);
    expect(value.primaryView, EpistemicViewKind.judgment);
    expect(value.judgments.map((j) => j.placement), ['A', 'B', 'cross']);
    expect(value.needsRepair, isFalse);
    final data = comparisonMap()..['recommended_view'] = 'circles';
    expect(
        SemanticScope.parse(data, const [
          ScopeSource('A', frankl),
          ScopeSource('B', willing)
        ]).primaryView,
        EpistemicViewKind.judgment);
    expect(const GroundDiagram('time', '', '', '', '', []).root,
        const GroundDiagram('space', '', '', '', '', []).root);
    expect(
        readableModelName(
            '["azure","resource/gpt-6-luna","endpoint-hash","deployment"]'),
        'Azure / gpt-6-luna');
  });
  test(
      'a bad relation preserves visible hierarchy without an automatic paid repair',
      () async {
    final raw = happinessMap();
    raw['relations'] = [
      {
        'placement': 'A',
        'statement': '返回缺字段',
        'status': 'text_claim',
        'references': refs('A', happiness),
        'scope': {'relation_type': 'overlap'}
      }
    ];
    final ai = ScriptedAi([raw, Exception('offline')]);
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final service = SemanticScopeService(
        ai: ai, store: CognitiveStore(database: () async => db));
    final result =
        await service.analyze(const [ScopeSource('A', happiness)], '概念树');
    expect(ai.calls, 1);
    expect(result.hierarchy.length, 2);
    expect(result.needsRepair, isTrue);
    expect(await service.cached(const [ScopeSource('A', happiness)], '概念树'),
        isNull);
    await db.close();
  });
  test(
      'genuine uncertainty has no repair loop and cache separates conditions and focus',
      () async {
    final focused = comparisonMap();
    focused['concepts'] = (focused['concepts'] as List)
        .where((n) => n['id'] == 'meaning')
        .toList();
    final ai = ScriptedAi([comparisonMap(), comparisonMap(), focused]);
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final service = SemanticScopeService(
        ai: ai, store: CognitiveStore(database: () async => db));
    const sources = [ScopeSource('A', frankl), ScopeSource('B', willing)];
    const first = SemanticContext(purpose: '行动', conditions: '低风险');
    await Future.wait([
      service.analyze(sources, '比较', context: first),
      service.analyze(sources, '比较', context: first)
    ]);
    expect(ai.calls, 1);
    await service.analyze(sources, '比较',
        context: const SemanticContext(purpose: '行动', conditions: '不可逆'));
    await service.analyze(sources, '比较',
        context:
            const SemanticContext(conceptId: 'meaning', conceptLabel: '生命的意义'));
    expect(ai.calls, 3);
    expect(
        await service.cached(sources, '比较',
            context: const SemanticContext(conditions: '未选择')),
        isNull);
    expect(ai.prompts.last, contains('concept_id'));
    await db.close();
  });
  test(
      'expansion isolates unrelated concept IDs instead of overwriting their meanings',
      () async {
    final ai = ScriptedAi([comparisonMap()]);
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final service = SemanticScopeService(
        ai: ai, store: CognitiveStore(database: () async => db));
    final result = await service.analyze(
        const [ScopeSource('A', frankl), ScopeSource('B', willing)], '展开',
        context:
            const SemanticContext(conceptId: 'meaning', conceptLabel: '生命的意义'));
    expect(ai.calls, 1);
    expect(result.concepts.map((n) => n.id), ['meaning']);
    expect(result.issues.any((e) => e.message.contains('概念身份')), isTrue);
    await db.close();
  });

  test('old v1 cached results stay readable without exposing model identities',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final store = CognitiveStore(database: () async => db);
    await store.database;
    const sources = [ScopeSource('A', happiness)];
    final old = {
      'relations': [
        {
          'placement': 'A',
          'statement': '当前材料需要先澄清幸福的判准。',
          'status': 'unknown',
          'scope': null,
          'references': refs('A', happiness)
        }
      ],
      'grounds': []
    };
    final key = 'cognition.semantic.1.${insightHash([
          sources.map((s) => {...s.toJson()}..remove('origin')).toList(),
          '旧阅读',
          'last'
        ])}';
    await db.insert('app_kv', {
      'key': key,
      'value': jsonEncode({
        'analysis': old,
        'model': '["azure","resource/gpt-6-luna","hash","deployment"]'
      })
    });
    final value =
        await SemanticScopeService(store: store).cached(sources, '旧阅读');
    expect(value!.primaryView, EpistemicViewKind.judgment);
    expect(value.model, 'Azure / gpt-6-luna');
    await db.close();
  });

  test(
      'a comparison preserves useful prose without silently repairing its diagram',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final raw = {
      'common': '共同讨论如何面对生活',
      'critical_difference': '意义与意欲使用不同判断尺度',
      'not_equivalent': '不能直接等同',
      'limitation': '需要具体情境',
      'relation_type': 'contrast',
      'semantic_map': {'relations': []}
    };
    final ai = ScriptedAi([raw, comparisonMap()]);
    final service = QuoteComparisonService(
        ai: ai, store: QuoteInsightStore(database: () async => db));
    const a = QuoteReference(id: 'a', content: frankl),
        b = QuoteReference(id: 'b', content: willing);
    final result = await service.compare(a, b);
    expect(ai.calls, 1);
    expect(result.difference, raw['critical_difference']);
    expect(result.semanticMap['judgments'], hasLength(1));
    expect(result.semanticMap['issues'], isNotEmpty);
    expect(result.modelDisplayName, '验收样例 · 模拟模型');
    await service.compare(a, b);
    expect(ai.calls, 1);
    await db.close();
  });

  test(
      'related quote catalog finds analyzed concepts absent from literal wording',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final insights = QuoteInsightStore(database: () async => db);
    final row = {
      'quote_uid': 'semantic-quote',
      'content': happiness,
      'theme': '幸福'
    };
    final quote = QuoteReference.fromRow(row);
    await insights.saveSemanticConcepts(quote, ['过程中的幸福']);
    final catalog = QuoteConceptCatalog(
        insights: insights,
        notes: CognitiveStore(database: () async => db),
        readPage: (limit, offset) async => offset == 0 ? [row] : []);
    final page = await catalog.find('过程中的幸福');
    expect(page.matches.single.reason, ConceptQuoteReason.semanticAnalysis);
    expect(page.matches.single.explanation, contains('AI 暂定理解'));
    final changed = QuoteReference.fromRow({...row, 'content': '修改后的名言'});
    expect((await insights.readSemanticConcepts([changed]))[changed.contentKey],
        isNull);
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  Future<void> mount(WidgetTester tester, Widget child,
      {double scale = 1}) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('v4-capture'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'PreviewCJK'),
            home: MediaQuery(
                data: MediaQueryData(
                    size: const Size(390, 900),
                    textScaler: TextScaler.linear(scale)),
                child: Scaffold(body: child)))));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('v4-capture')))
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('build/cognitive-preview/v4-$name.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'a late result for old material cannot replace the current canvas',
      (tester) async {
    final service = ControlledScopes();
    final material = ValueNotifier(happiness);
    addTearDown(material.dispose);
    await mount(
        tester,
        SingleChildScrollView(
            child: ValueListenableBuilder<String>(
                valueListenable: material,
                builder: (context, text, _) => SemanticScopePanel(
                    sources: [ScopeSource('A', text)], service: service))));
    await tester.tap(find.text('分析概念关系并绘图'));
    await tester.pump();
    material.value = networkText;
    await settle(tester);
    await tester.tap(find.text('分析概念关系并绘图'));
    await tester.pump();
    service.requests[1].complete(networkScope());
    await settle(tester);
    service.requests[0].complete(happinessScope());
    await settle(tester);
    expect(find.byType(ConceptMeaningNetwork), findsOneWidget);
    expect(find.text('沿山路前进的体验'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets(
      'disabled circle preference preserves the concept tree without circle controls',
      (tester) async {
    await mount(
        tester,
        SingleChildScrollView(
            child: SemanticScopeView(
                value: networkScope(),
                sources: const [ScopeSource('A', networkText)],
                allowCircles: false)));
    expect(find.byType(ConceptMeaningNetwork), findsNothing);
    expect(find.byType(ConceptHierarchyView), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '含义圈'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fullscreen tree nodes open an inspector and return to a parent',
      (tester) async {
    await mount(
        tester,
        SingleChildScrollView(
            child: ConceptHierarchyView(value: happinessScope())));
    await tester.tap(find.byTooltip('全屏查看'));
    await settle(tester);
    await tester.tap(find.widgetWithText(InkWell, '沿山路前进的体验').last);
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    final parent = find.descendant(
        of: find.byType(BottomSheet), matching: find.text('具体实例：过程中的幸福'));
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await settle(tester);
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('过程中的幸福')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reading concept tab opens the actual hierarchy and passes original context to details',
      (tester) async {
    await tester.runAsync(() => SemanticScopeService().remember(
        const [ScopeSource('A', happiness)], '分析整句中的概念及其关系', happinessScope()));
    await mount(
        tester,
        const QuoteCognitiveReader(
            quote: QuoteReference(id: 'v4-happiness', content: happiness),
            topic: '幸福',
            authorLabel: '验收样例',
            note: ''));
    expect(find.byType(ConceptHierarchyView), findsOneWidget);
    final indexed = await tester.runAsync(() => QuoteInsightStore()
        .readSemanticConcepts(
            [const QuoteReference(id: 'v4-happiness', content: happiness)]));
    expect(indexed!.values.single, contains('过程中的幸福'));
    expect(find.widgetWithText(ChoiceChip, '概念树'), findsOneWidget);
    await capture(tester, 'reading-tree');
    await tester.ensureVisible(find.text('追踪概念的直观链路'));
    await tester.tap(find.text('追踪概念的直观链路'));
    await settle(tester);
    await tester
        .ensureVisible(find.byKey(const ValueKey('grounding-node-walk')));
    await tester.tap(find.byKey(const ValueKey('grounding-node-walk')));
    await settle(tester);
    expect(find.textContaining('具体经验 · 模拟示例'), findsOneWidget);
    await tester.ensureVisible(find.text('相关名言与概念详情'));
    await tester.tap(find.text('相关名言与概念详情'));
    await settle(tester);
    final explorer =
        tester.widget<ConceptExplorer>(find.byType(ConceptExplorer));
    expect(explorer.contextSources.single.text, happiness);
    expect(explorer.focusNodeId, 'walk');
    expect(explorer.nodeUid, isNull);
  });
  testWidgets('multiple circles zoom, reset and open fullscreen at large text',
      (tester) async {
    await mount(
        tester,
        SingleChildScrollView(
            child: ConceptMeaningNetwork(value: networkScope())),
        scale: 1);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'meaning-network');
    await mount(
        tester,
        SingleChildScrollView(
            child: ConceptMeaningNetwork(value: networkScope())),
        scale: 2);
    await tester.tap(find.byTooltip('全屏查看'));
    await settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byTooltip('适合画布'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'screenshot quote comparison shows judgment and supported alternatives instead of pending chips',
      (tester) async {
    await mount(
        tester,
        QuoteComparisonSheet(
            a: const QuoteReference(id: 'frankl', content: frankl),
            b: const QuoteReference(id: 'willing', content: willing),
            service: ComparisonFixture()));
    expect(find.text('判断力 · 围绕当前目的辨清同异'), findsOneWidget);
    expect(find.textContaining('待确定'), findsNothing);
    expect(find.textContaining('endpoint-hash'), findsNothing);
    await capture(tester, 'comparison-judgment');
    await tester.ensureVisible(
        find.byKey(const ValueKey('comparison-semantic-details')));
    await tester.tap(find.text('概念与依据'));
    await settle(tester);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '直观与抽象'));
    await tester.tap(find.widgetWithText(ChoiceChip, '直观与抽象'));
    await settle(tester);
    expect(find.text('具体材料 → 保留的共同规定 → 被省略的个别细节'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
