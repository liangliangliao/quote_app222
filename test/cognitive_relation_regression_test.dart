import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/epistemic/concept_circle_preview.dart';
import 'package:quote_app/epistemic/concept_connections.dart';
import 'package:quote_app/epistemic/concept_connection_routes.dart';
import 'package:quote_app/epistemic/concept_hierarchy_view.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/semantic_contract.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures/meaning_relations.dart';
import 'support/circle_fixture.dart';

class _FixtureAi extends UnifiedAiService {
  final Map<String, dynamic> response;
  final prompts = <String>[];
  int? budget;
  _FixtureAi(this.response);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'fixture',
          endpoint: 'https://example.invalid',
          label: '测试',
          displayModel: 'UI验收样例 · 非真实模型',
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
    budget = maxTokens;
    return jsonEncode(response);
  }
}

const sources = [ScopeSource('A', winterQuote)];
SemanticScope winter() => SemanticScope.parse(winterMap(), sources);
SemanticContext expansionContext(SemanticScope base) {
  final node = base.concepts.singleWhere((c) => c.id == 'winter');
  return SemanticContext(
      conceptId: node.id,
      conceptLabel: node.label,
      conceptDefinition: node.definition,
      existingConcepts: base.concepts,
      existingHierarchy: base.hierarchy,
      existingLinks: base.meaningLinks,
      existingRelations: base.relations);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final font = File('/tmp/quote-preview-cjk.otf');
    if (font.existsSync())
      await (FontLoader('PreviewCJK')
            ..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync()))))
          .load();
  });
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    GlobalAiRequestSettings.cached = const GlobalAiRequestConfig(
        timeoutSeconds: null,
        maxOutputTokens: 90000,
        temperature: null,
        topP: null,
        retryCount: null,
        retryDelayMs: null);
  });
  tearDown(() async => db.close());
  SemanticScopeService service(_FixtureAi ai) => SemanticScopeService(
      ai: ai, store: CognitiveStore(database: () async => db));

  test('literary relations survive round trip without becoming class inclusion',
      () {
    final result = winter();
    expect(result.meaningLinks.map((e) => e.kind),
        ['contrast', 'metaphor', 'predication']);
    expect(result.hierarchy.map((e) => e.kind), ['grounding']);
    expect(result.relations, isEmpty);
    expect(result.availableViews, contains(EpistemicViewKind.connections));
    expect(result.availableViews, isNot(contains(EpistemicViewKind.circles)));
    final restored = SemanticScope.parse(result.toJson(), sources);
    expect(restored.meaningLinks.length, 3);
    expect(restored.meaningLinks[1].references.single.excerpt, winterQuote);
    expect(restored.legacy, isTrue); // The old schema is never relabeled as v5.
  });
  test('non-hierarchical links misplaced by a gateway retain their actual type',
      () {
    final raw = winterMap();
    (raw['hierarchy'] as List).add({
      'parent': 'summer',
      'child': 'strength',
      'kind': 'metaphor',
      'explanation': '以夏天解释内在生命力，不是夏天的下位类。',
      'references': ['e1']
    });
    raw['meaning_links'] = [];
    final parsed = SemanticScope.parse(raw, sources);
    expect(parsed.hierarchy.map((e) => e.kind), ['grounding']);
    expect(parsed.meaningLinks.single.kind, 'metaphor');
  });
  test('missing endpoints and invented extracts cannot produce visible links',
      () {
    final raw = winterMap();
    raw['meaning_links'] = [
      meaningLink('winter', 'absent', 'contrast', '缺少端点'),
      meaningLink('winter', 'strength', 'cause', '错误的因果')
        ..['references'] = [
          {'source': 'A', 'excerpt': '原句没有的证据'}
        ],
    ];
    final parsed = SemanticScope.parse(raw, sources);
    expect(parsed.meaningLinks, isEmpty);
    expect(parsed.needsRepair, isTrue);
    expect(parsed.concepts.length, 4);
  });
  test('a non-extensional relation cannot bypass endpoint checks', () {
    final raw = winterMap();
    raw['relations'] = [
      {
        'placement': 'A',
        'statement': '意象对照',
        'status': 'interpretation',
        'scope': null,
        'node_ids': ['winter', 'absent'],
        'references': ['e1'],
      }
    ];
    final result = SemanticScope.parse(raw, sources);
    expect(result.relations, isEmpty);
    expect(result.issues.any((i) => i.message.contains('已知概念')), isTrue);
  });
  test('expansion refers to old focus and peer IDs without repeating old nodes',
      () async {
    final ai = _FixtureAi(winterExpansion()), base = winter();
    final delta = await service(ai)
        .analyze(sources, '反馈回归', context: expansionContext(base));
    expect(ai.prompts.length, 1);
    expect(ai.budget, 4000);
    expect(ai.prompts.single, contains('existing_concepts'));
    expect(ai.prompts.single, contains('内在生命力'));
    expect(delta.issues, isEmpty);
    final merged = base.merge(delta);
    expect(merged.concepts.length, 5);
    expect(merged.meaningLinks.length, 5);
    expect(merged.hierarchy.single.child, 'report-event');
    final edges = conceptConnections(merged);
    expect(edges.any((e) => e.from == 'winter' && e.to == 'winter/adversity'),
        isTrue);
    expect(edges.any((e) => e.from == 'winter/adversity' && e.to == 'strength'),
        isTrue);
    expect(
        SemanticScope.parse(merged.toJson(), sources).meaningLinks.length, 5);
  });
  test(
      'an expansion can attach through an old neighbour connected to the focus',
      () async {
    final raw = winterExpansion();
    (raw['meaning_links'] as List).removeAt(0);
    final result = await service(_FixtureAi(raw))
        .analyze(sources, '间接连接', context: expansionContext(winter()));
    expect(result.concepts.any((n) => n.id == 'winter/adversity'), isTrue);
    expect(result.needsRepair, isFalse);
  });
  test('disconnected expansion is isolated and cannot overwrite a saved graph',
      () async {
    final ai = _FixtureAi(winterExpansion(orphan: true));
    final store = service(ai), base = winter();
    await store.remember(sources, '保留原图', base);
    final delta =
        await store.analyze(sources, '保留原图', context: expansionContext(base));
    expect(delta.concepts.map((n) => n.id), base.concepts.map((n) => n.id));
    expect(delta.issues.any((i) => i.path == 'expansion.connections'), isTrue);
    expect((await store.cached(sources, '保留原图'))!.meaningLinks.length, 3);
    expect(ai.prompts.length, 1); // No paid repair loop.
  });
  test('a patch cannot redefine a canonical old peer', () async {
    final raw = winterExpansion();
    (raw['concepts'] as List).add(meaningNode('strength', '内在生命力', '偷偷改成夏季气温'));
    final result = await service(_FixtureAi(raw))
        .analyze(sources, '身份保护', context: expansionContext(winter()));
    expect(result.concepts.singleWhere((n) => n.id == 'strength').definition,
        winter().concepts.singleWhere((n) => n.id == 'strength').definition);
    expect(result.issues.any((i) => i.message.contains('身份或含义')), isTrue);
  });
  test('an old-node ID-only reference is resolved from the canonical graph',
      () async {
    final raw = winterExpansion();
    (raw['concepts'] as List).add({'id': 'strength'});
    (raw['concepts'] as List).add({'id': 'winter'});
    final result = await service(_FixtureAi(raw))
        .analyze(sources, '旧身份引用', context: expansionContext(winter()));
    expect(result.needsRepair, isFalse);
    expect(result.concepts.length, 5);
  });
  test(
      'plain model IDs are namespaced and their old/new endpoints rewritten together',
      () async {
    final raw = winterExpansion();
    (raw['concepts'] as List).single['id'] = 'new-context';
    for (final e in raw['meaning_links'] as List) {
      if (e['from'] == 'winter/adversity') e['from'] = 'new-context';
      if (e['to'] == 'winter/adversity') e['to'] = 'new-context';
    }
    final result = await service(_FixtureAi(raw))
        .analyze(sources, '身份适配', context: expansionContext(winter()));
    expect(result.needsRepair, isFalse);
    expect(result.concepts.any((n) => n.id == 'winter/new-context'), isTrue);
    expect(
        result.meaningLinks
            .any((e) => e.from == 'winter/new-context' && e.to == 'strength'),
        isTrue);
  });
  test('an unrelated missing-condition paraphrase is not diagnosed as omission',
      () {
    final same = PropositionConsistency.check(winterQuote, winterQuote,
        condition: '置于“隆冬”这一文学背景');
    expect(same.status, VerificationStatus.supported);
    final paraphrase = PropositionConsistency.check('在艰难中仍发现内在生命力', winterQuote,
        condition: '隆冬中的自我发现');
    expect(paraphrase.status, VerificationStatus.unknown);
    expect(paraphrase.reason, isNot(contains('遗漏')));
    final stronger = PropositionConsistency.check('所有人一定幸福', '如果得到所需帮助，人会感到幸福',
        condition: '如果得到所需帮助');
    expect(stronger.status, VerificationStatus.unknown);
    expect(stronger.reason, contains('强化'));
  });
  test(
      'connections share identities across hierarchy, meaning graph and circle UI',
      () {
    final value = winter(), edges = conceptConnections(winter());
    expect(edges.length, 4);
    final layout = ConceptConnectionLayout.build(value.concepts, edges);
    for (final a in layout.boxes.entries) {
      expect(a.value.left, greaterThanOrEqualTo(0));
      expect(a.value.bottom, lessThanOrEqualTo(layout.size.height));
      for (final b in layout.boxes.entries.where((b) => b.key != a.key)) {
        expect(a.value.overlaps(b.value), isFalse);
      }
    }
  });
  test('merging a branch retains unresolved issues on old graph', () {
    final old = SemanticScope(winter().relations, winter().grounds,
        concepts: winter().concepts,
        issues: const [AnalysisIssue('old-premise', '原有前提待核对')]);
    final merged = old.merge(winter());
    expect(merged.issues.single.path, 'old-premise');
  });
  test('a distant new-to-old line never crosses an intervening concept',
      () async {
    final base = winter(),
        delta = await service(_FixtureAi(winterExpansion()))
            .analyze(sources, '绕行测试', context: expansionContext(winter()));
    final graph = base.merge(delta),
        links = conceptConnections(base.merge(delta));
    final layout = ConceptConnectionLayout.build(graph.concepts, links);
    for (final e in links) {
      final route =
          routeConceptConnection(e.from, e.to, layout.boxes, layout.size);
      expect(route.length, greaterThanOrEqualTo(2), reason: e.identity);
      for (var i = 1; i < route.length; i++) {
        for (final box in layout.boxes.entries) {
          expect(
              conceptSegmentCrosses(
                  route[i - 1], route[i], box.value.deflate(.1)),
              isFalse,
              reason: '${e.identity} crosses ${box.key}');
        }
      }
    }
  });
  test(
      'explicit repair must reconnect the orphan instead of asserting resolved',
      () async {
    final base = winter();
    final broken = await service(_FixtureAi(winterExpansion(orphan: true)))
        .analyze(sources, '修复断线', context: expansionContext(base));
    final valid = winterExpansion()
      ..['resolved_paths'] = ['expansion.connections'];
    final fixed = await service(_FixtureAi(valid))
        .repair(sources, '修复断线', base.merge(broken));
    expect(fixed.concepts.any((c) => c.id == 'winter/adversity'), isTrue);
    expect(fixed.issues.any((i) => i.path == 'expansion.connections'), isFalse);
    final fake = winterExpansion(orphan: true)
      ..['resolved_paths'] = ['expansion.connections'];
    final unfinished = await service(_FixtureAi(fake))
        .repair(sources, '未修复', base.merge(broken));
    expect(unfinished.concepts.any((c) => c.id == 'winter/adversity'), isFalse);
    expect(unfinished.issues.any((i) => i.path == 'expansion.connections'),
        isTrue);
  });
  test('a partial comparison reading cannot discard valid semantic links', () {
    final result = QuoteComparisonService.parseResponse(
        jsonEncode({
          'common': '都涉及主体内部维持生活的力量，但使用不同概念。',
          'critical_difference': 'A叙述在困境中发现生命力；B比较欲求虚无与不再欲求，关涉欲求活动及其对象。',
          'not_equivalent': '生命韧性的隐喻不等于关于欲求活动的偏好判断。',
          'limitation': '不能据此证明普遍心理规律，译文与语境仍需核对。',
          'semantic_map': winterMap(),
          'reading_b': {'anchor': '不对应原文', 'abstractions': []},
        }),
        const QuoteReference(id: 'A', content: winterQuote),
        const QuoteReference(id: 'B', content: willingQuote),
        requireReadings: true);
    final graph = SemanticScope.parse(result.semanticMap,
        const [ScopeSource('A', winterQuote), ScopeSource('B', willingQuote)]);
    expect(graph.meaningLinks.length, 3);
    expect(graph.propositions.length, 1);
    expect(graph.materialKind, 'metaphor');
    expect(graph.issues.any((i) => i.path == 'reading_b'), isTrue);
  });

  test('a cross-passage link must cite both endpoint sources', () {
    final raw = winterMap();
    (raw['evidence'] as List)
        .add({'id': 'e2', 'source': 'B', 'excerpt': willingQuote});
    (raw['concepts'] as List).add(
        meaningNode('desire', '意欲虚无', '意欲活动以虚无为对象')..['references'] = ['e2']);
    raw['meaning_links'] = [
      meaningLink('strength', 'desire', 'contrast', '区分生命韧性与欲求活动')
    ];
    const pair = [
      ScopeSource('A', winterQuote),
      ScopeSource('B', willingQuote)
    ];
    final bad = SemanticScope.parse(raw, pair);
    expect(bad.meaningLinks, isEmpty);
    expect(bad.issues.any((i) => i.message.contains('覆盖两端')), isTrue);
    (raw['meaning_links'] as List).single['references'] = ['e1', 'e2'];
    expect(SemanticScope.parse(raw, pair).meaningLinks.single.to, 'desire');
  });
  test('an existing Euler relation also anchors an incremental branch',
      () async {
    const pair = [
      ScopeSource('A', winterQuote),
      ScopeSource('B', willingQuote)
    ];
    final base = SemanticScope.parse(
        teachingCircleFixture(winterQuote, willingQuote), pair);
    final a = base.concepts[0], b = base.concepts[1];
    final raw = <String, dynamic>{
      'schema_version': 4,
      'evidence': [
        {'id': 'e1', 'source': 'A', 'excerpt': winterQuote}
      ],
      'concepts': [meaningNode('${a.id}/new', '局部解释', '只对当前教学模型进行的局部解释')],
      'meaning_links': [
        meaningLink('${a.id}/new', b.id, 'association', '通过已有关系连回所选概念')
      ],
    };
    final result = await service(_FixtureAi(raw)).analyze(pair, '外延节点展开',
        context: SemanticContext(
            conceptId: a.id,
            conceptLabel: a.label,
            conceptDefinition: a.definition,
            existingConcepts: base.concepts,
            existingRelations: base.relations));
    expect(result.needsRepair, isFalse);
    expect(result.concepts.any((n) => n.id == '${a.id}/new'), isTrue);
  });
  test('explicit comparison refresh clears legacy fallback versions too',
      () async {
    const a = QuoteReference(id: 'A', content: winterQuote),
        b = QuoteReference(id: 'B', content: willingQuote);
    final ai = _FixtureAi({}),
        storage = QuoteInsightStore(database: () async => db);
    final old = QuoteComparison(
        relation: QuoteRelation.contrast,
        common: '旧共同点',
        difference: '旧差异',
        notEquivalent: '旧区分',
        limitation: '旧边界');
    final model = jsonEncode(
        ['test', 'fixture', insightHash('https://example.invalid'), 'fixture']);
    for (final v in [8, 7, 6]) {
      await storage.saveComparison(
          QuoteComparisonService.cacheKey(a, b,
              modelIdentity: model, promptVersion: v),
          old);
    }
    final comparisons = QuoteComparisonService(ai: ai, store: storage);
    expect((await comparisons.compare(a, b)).common, '旧共同点');
    expect(ai.prompts, isEmpty);
    await comparisons.clearCache(a, b);
    for (final v in [8, 7, 6]) {
      expect(
          await storage.readComparison(QuoteComparisonService.cacheKey(a, b,
              modelIdentity: model, promptVersion: v)),
          isNull);
    }
  });

  test('adding an article or repeating a definition cannot create a subtype',
      () {
    final raw = winterMap();
    (raw['concepts'] as List).add(
        meaningNode('summer/reworded', '一个不可战胜的夏天', '这是同一意象的改写，没有新增成员判准。'));
    (raw['hierarchy'] as List).add({
      'parent': 'summer',
      'child': 'summer/reworded',
      'kind': 'subtype',
      'explanation': '从夏天到一个夏天',
      'references': ['e1']
    });
    final result = SemanticScope.parse(raw, sources);
    expect(result.hierarchy.any((e) => e.kind == 'subtype'), isFalse);
    expect(result.issues.any((i) => i.message.contains('新增类属判准')), isTrue);
  });
  test('identical extension criteria cannot support a proper subset', () {
    final raw =
        teachingCircleFixture(winterQuote, willingQuote, type: 'subset');
    final scope = (raw['relations'] as List).single['scope'];
    scope['criterion_b'] = scope['criterion_a'];
    raw['concepts'] = [
      meaningNode('summer', '不可战胜的夏天', '原句中的内在季节意象')
        ..['references'] = [
          {'source': 'A', 'excerpt': winterQuote}
        ]
    ];
    final result = SemanticScope.parse(raw,
        const [ScopeSource('A', winterQuote), ScopeSource('B', willingQuote)]);
    expect(result.relations.any((r) => r.scope != null), isFalse);
    expect(result.issues.any((i) => i.message.contains('相同成员判准')), isTrue);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, Widget body,
      {double width = 420, double scale = 1}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(Size(width, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('meaning-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'PreviewCJK',
                colorSchemeSeed: const Color(0xff967d50)),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                backgroundColor: const Color(0xfffcf7eb),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), child: body)))));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('meaning-preview')))
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/cognitive-preview/v10-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  List<ConceptConnectionPainter> painters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<ConceptConnectionPainter>()
      .toList();

  testWidgets('metaphor and contrast remain separate from extensional circles',
      (tester) async {
    await mount(tester, ConceptMeaningNetwork(value: winter()));
    expect(find.byType(ConceptCirclePreview), findsNothing);
    expect(painters(tester), isEmpty);
    expect(find.text('本次回复漏掉了含义圈'), findsOneWidget);
    await mount(tester, ConceptCirclePreview(value: winter()));
    expect(painters(tester).single.connections.map((e) => e.kind),
        containsAll(['metaphor', 'contrast', 'predication']));
    expect(find.textContaining('独立概念预览'), findsNothing);
    await capture(tester, 'winter-meaning-links');
  });
  testWidgets(
      'real expansion action passes the old graph and paints new-to-old edges',
      (tester) async {
    final ai = _FixtureAi(winterExpansion());
    SemanticScope? displayed;
    await mount(
        tester,
        SemanticScopePanel(
            sources: sources,
            initial: winter(),
            preferredView: EpistemicViewKind.connections,
            service: service(ai),
            onResult: (value) => displayed = value));
    expect(ai.prompts, isEmpty);
    final node = find.byKey(const ValueKey('meaning-node-winter'));
    await tester.ensureVisible(node);
    await tester.tap(node);
    await settle(tester);
    final expand = find.descendant(
        of: find.byType(BottomSheet), matching: find.text('展开相关概念'));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await settle(tester);
    expect(ai.prompts.length, 1);
    expect(displayed!.concepts.length, 5);
    expect(displayed!.meaningLinks.length, 5);
    final drawn = painters(tester).single.connections;
    expect(drawn.any((e) => e.from == 'winter/adversity' && e.to == 'strength'),
        isTrue);
    expect(drawn.any((e) => e.from == 'winter' && e.to == 'winter/adversity'),
        isTrue);
    expect(ai.prompts.single, contains('existing_links'));
    await mount(tester, ConceptCirclePreview(value: displayed!));
    await capture(tester, 'expanded-new-and-old');
    await mount(tester, ConceptHierarchyView(value: displayed!));
    expect(painters(tester), isEmpty);
    expect(find.text('尚未建立类属层级'), findsOneWidget);
    expect(find.text('一般概念 · 共同规定'), findsNothing);
    await capture(tester, 'tree-typed-relations');
  });
  testWidgets('semantic view retains labels with large text',
      (tester) async {
    await mount(tester, ConceptCirclePreview(value: winter()),
        width: 320, scale: 2);
    expect(painters(tester).single.connections.length, 3);
    expect(find.byKey(const ValueKey('meaning-node-strength')), findsOneWidget);
    await capture(tester, 'meaning-large-text');
  });
}
