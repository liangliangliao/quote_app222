import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/concept_hierarchy_view.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/cognitive_service.dart';
import 'package:quote_app/epistemic/cognitive_models.dart';
import 'package:quote_app/epistemic/concept_analysis.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'fixtures/purposeful_case.dart';

const originals = [ScopeSource('A', camusPassage)];
SemanticScope value([Map<String, dynamic>? raw]) =>
    SemanticScope.parse(raw ?? purposefulCase(), originals);
const cfg = UnifiedAiResolvedConfig(
    provider: 'test',
    apiKey: '',
    model: 'offline',
    endpoint: 'https://example.invalid',
    label: '测试',
    displayModel: '离线测试',
    available: true);

class _RepairAi extends UnifiedAiService {
  int calls = 0;
  final Map<String, dynamic> response;
  _RepairAi(this.response);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      cfg;
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
    return jsonEncode(response);
  }
}

class _RepairService extends SemanticScopeService {
  _RepairService(_RepairAi ai) : super(ai: ai);
  @override
  Future<void> remember(
      List<ScopeSource> sources, String focus, SemanticScope value,
      {SemanticContext context = const SemanticContext()}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final f = File('/tmp/quote-preview-cjk.otf');
    if (f.existsSync())
      await (FontLoader('CaseCJK')
            ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
          .load();
  });
  test(
      'case preserves source anchors, analysis purpose and natural core concepts',
      () {
    final v = value();
    expect(v.issues, isEmpty);
    expect(v.alignedCases.single.text, alignedStory);
    expect(v.conceptsForSource('A').map((n) => n.label),
        containsAll(['逆境', '韧性', '自我认识']));
    expect(
        v.conceptsForSource('A').any((n) => n.role == 'perspective'), isFalse);
    expect(v.classEdges.map((e) => e.child),
        ['adversity', 'resilience', 'awareness']);
    expect(v.scopeRelations.length, 3);
    expect(
        v.scopeRelations.every((r) => r.nodeIds.every((id) =>
            v.concepts.singleWhere((n) => n.id == id).role == 'perspective')),
        isTrue);
    expect(
        ReadingMapQuality.issues(v, requestedViews: ['hierarchy', 'circles'])
            .where((i) => i.retryable),
        isEmpty);
    expect(value(v.toJson()).alignedCases.single.alignment.length, 3);
    expect(ConceptCircleLayout.build(v).single.geometryConsistent, isTrue);
  });
  test(
      'overlapping meaning circles keep long labels readable inside their own regions',
      () {
    final v = value(), cluster = ConceptCircleLayout.build(v).single;
    final labels = meaningCircleLabels(
        cluster.circles, {for (final n in v.concepts) n.id: n},
        font: 'CaseCJK');
    for (final label in labels) {
      expect(label.painter.didExceedMaxLines, isFalse);
      final rect = label.rect, circle = label.circle;
      expect(
          [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]
              .every((p) => (p - circle.center).distance < circle.radius),
          isTrue);
      for (final other in labels) {
        if (other != label) expect(rect.overlaps(other.rect), isFalse);
      }
      label.painter.dispose();
    }
  });
  test('case events cannot be promoted to a report about the author or user',
      () {
    final m = purposefulCase();
    m['concepts'][7]['status'] = 'text_claim';
    final v = value(m);
    expect(v.concepts.any((n) => n.id == 'event'), isFalse);
    expect(v.issues.any((i) => i.message.contains('教学案例中的事件')), isTrue);
  });
  test('unanchored or conflicting cases cannot become invented source evidence',
      () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['aligned_cases'][0]['alignment'][0]['excerpt'] = '原句中并不存在的内容',
      (m) => m['aligned_cases'][0]['alignment'][0]['case_detail'] = '案例中不存在的事件',
      (m) => m['aligned_cases'][0]['id'] = 'A',
      (m) => m['aligned_cases'][0]['boundary'] = '',
    ]) {
      final m = purposefulCase();
      mutate(m);
      expect(() => value(m), throwsFormatException);
    }
  });
  test(
      'poetic season background is not a temporal edge or compulsory fourth root',
      () {
    final m = purposefulCase();
    m['grounds'] = [
      {
        'kind': 'time',
        'from': '在隆冬中所给出的时间背景',
        'to': '原句所述的发现事件',
        'status': 'text_claim',
        'references': ['q']
      }
    ];
    final v = value(m);
    expect(v.grounds, isEmpty);
    expect(v.issues.any((i) => i.path.startsWith('grounds')), isTrue);
    final normal = value();
    expect(normal.grounds.map((g) => g.kind), ['motive', 'time']);
    expect(normal.grounds.last.temporalRelation, 'before');
    expect(
        normal.grounds
            .every((g) => g.references.every((r) => r.source == 'C1')),
        isTrue);
  });
  test(
      'meta-expression taxonomy and grammatical counterexamples fail conceptual selection',
      () {
    final m = purposefulCase();
    m['concepts'][1]['label'] = '逆境中发现内在心理资源的隐喻性表达情形';
    m['concepts'][1]['counter_example'] = '单独说隆冬不足以体现语境用法';
    final v = value(m),
        issues = ReadingMapQuality.issues(v,
            requestedViews: ['hierarchy', 'circles']);
    expect(v.classEdges.any((e) => e.child == 'adversity'), isFalse);
    expect(issues.any((i) => i.path.startsWith('reading.selection.')), isTrue);
    expect(issues.any((i) => i.path.startsWith('reading.counterexample.')),
        isTrue);
  });
  test(
      'the actual service accepts a complete case analysis without another AI request',
      () async {
    final v = await SemanticScopeService().validateResponse(
        purposefulCase(), originals, '理解原意', cfg,
        context: readingMapContext);
    expect(v.needsRepair, isFalse);
    expect(v.analysisPurpose, contains('内在力量'));
    expect(v.alignedCases.single.title, '受挫后仍能继续尝试');
  });
  test(
      'expansion retains the existing case and visibly connects new and canonical old concepts',
      () async {
    final old = value(), raw = purposefulCase();
    raw.remove('aligned_cases');
    raw['concepts'] = [
      {
        'id': 'adjustment',
        'label': '受挫后的行动调整能力',
        'definition': '韧性中，通过改变方法恢复并继续活动的能力。',
        'kind': 'concept',
        'universe': '人的心理能力',
        'status': 'definition',
        'role': 'support',
        'selection_reason': '区分重复尝试与改变方法，对应案例修改简历。',
        'references': ['c']
      }
    ];
    raw['hierarchy'] = [
      {
        'parent': 'resilience',
        'child': 'adjustment',
        'kind': 'subtype',
        'differentia': '通过改变方法恢复并继续活动',
        'basis_kind': 'analytic_definition',
        'explanation': '保留在挫折中调整并继续行动的能力，再限定改变方法。',
        'references': ['c']
      }
    ];
    raw['relations'] = [];
    raw['grounds'] = [];
    final context = SemanticContext(
        conceptId: 'resilience',
        existingCases: old.alignedCases,
        existingConcepts: old.concepts,
        existingHierarchy: old.hierarchy,
        existingRelations: old.relations,
        inquiry: old.analysisPurpose);
    final patch = await SemanticScopeService()
        .validateResponse(raw, originals, '韧性', cfg, context: context);
    final merged = old.merge(patch);
    expect(patch.issues, isEmpty,
        reason: jsonEncode(patch.issues.map((i) => i.toJson()).toList()));
    expect(patch.alignedCases.single.text, alignedStory);
    expect(patch.hierarchy.single.child, 'resilience/adjustment');
    expect(
        merged.classEdges.any((e) =>
            e.parent == 'resilience' && e.child == 'resilience/adjustment'),
        isTrue);
    expect(merged.concepts.singleWhere((n) => n.id == 'resilience').definition,
        old.concepts.singleWhere((n) => n.id == 'resilience').definition);
    expect(context.toJson()['existing_cases'], isNotEmpty);
  });
  test(
      'explicit repair recomputes missing-sphere diagnostics from the actual merged result in one request',
      () async {
    final map = purposefulCase()..['relations'] = [];
    map['issues'] = ReadingMapQuality.issues(value(map),
            requestedViews: ['hierarchy', 'circles'])
        .map((i) => i.toJson())
        .toList();
    final ai = _RepairAi(purposefulCase()),
        fixed = await _RepairService(ai)
            .repair(originals, '理解', value(map), context: readingMapContext);
    expect(ai.calls, 1);
    expect(fixed.needsRepair, isFalse);
    expect(fixed.scopeRelations.length, 3);
    expect(fixed.alignedCases.single.text, alignedStory);
    expect(
        fixed.issues.any((i) => i.path == 'reading.meaning_spheres'), isFalse);
  });
  test(
      'related concept teaching adapts cases while diary spans remain tied to the chosen original',
      () {
    final selected = CognitiveSelection.fromText(
        module: 'quote', recordId: 'q', title: '', fullText: camusPassage);
    final prompt =
        CognitiveService.buildPrompt(selected, CognitiveTask.concept);
    expect(prompt, contains('高度一致'));
    expect(prompt, contains('教学案例'));
    final diary = CognitiveService.buildPrompt(selected, CognitiveTask.diary);
    expect(diary, contains('每个 spans.text 必须逐字来自选文'));
    expect(diary, contains('不遗漏、不改写'));
  });
  test(
      'comparison envelope uses the current schema and preserves aligned cases in derived readings',
      () {
    const a = QuoteReference(id: 'A', content: camusPassage),
        b = QuoteReference(id: 'B', content: '人宁愿意欲虚无，也不愿不欲。');
    final prompt = QuoteComparisonService.buildPrompt(a, b);
    expect(prompt, contains('"schema_version":6'));
    expect(prompt, contains('aligned_cases'));
    expect(prompt, contains('核心意义高度一致'));
    final comparison = QuoteComparisonService.parseResponse(
        jsonEncode({
          'semantic_map': purposefulCase(),
          'common': '两句都可围绕内在活动理解，但共同主题不能证明概念同一。',
          'critical_difference': 'A描述发现内在力量，B提出意欲与不欲的偏好。',
          'not_equivalent': '发现能力不等于选择意欲的对象。',
          'limitation': '案例说明A的一种读法，不证明B或作者经历。',
          'basis_a': '不可战胜的夏天',
          'basis_b': '意欲虚无'
        }),
        a,
        b,
        requireReadings: true);
    expect(
        ConceptAbstraction.parse(comparison.readingA['abstractions'])
            .map((n) => n.term),
        containsAll(['逆境', '韧性', '自我认识']));
    final graph = SemanticScope.parse(comparison.semanticMap,
        [const ScopeSource('A', camusPassage), ScopeSource('B', b.content)]);
    expect(graph.alignedCases.single.text, alignedStory);
    expect(graph.analysisPurpose, value().analysisPurpose);
  });
  Future<void> mount(WidgetTester t, Widget body,
      {double width = 500, double scale = 1}) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.binding.setSurfaceSize(Size(width, 1100));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(RepaintBoundary(
        key: const ValueKey('case-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'CaseCJK',
                colorSchemeSeed: const Color(0xff75679c)),
            builder: (c, ch) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: ch!),
            home: Scaffold(
                backgroundColor: const Color(0xfffaf6ee),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('离线教学案例验收 · 非真实模型输出',
                              style: TextStyle(fontSize: 12)),
                          body,
                        ]))))));
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('case-preview')))
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/cognitive-preview/v12-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'case, meaning alignment and scope are visible before the diagrams',
      (t) async {
    await mount(
        t,
        SemanticScopeView(
            value: value(),
            sources: originals,
            preferredView: EpistemicViewKind.circles));
    expect(find.text('相关教学案例 · 受挫后仍能继续尝试'), findsOneWidget);
    expect(find.text(alignedStory), findsOneWidget);
    expect(find.textContaining('当前考量：'), findsOneWidget);
    expect(find.text('本次回复漏掉了含义圈'), findsNothing);
    await capture(t, 'case-context');
  });
  testWidgets(
      'natural class hierarchy, experiential leaves and linked meaning scopes render',
      (t) async {
    await mount(
        t,
        Column(children: [
          const Text('相关案例：受挫后仍能继续尝试'),
          ConceptHierarchyView(value: value(), traceGrounding: true)
        ]));
    await capture(t, 'case-tree');
    expect(find.text('逆境'), findsWidgets);
    expect(find.textContaining('选取理由：'), findsOneWidget);
    await mount(
        t,
        Column(children: [
          const Text('相关案例：以生活经历比较逆境、内在力量与自我认识'),
          ConceptMeaningNetwork(value: value())
        ]));
    await capture(t, 'case-circles');
    await t.tap(find.text('展现韧性的经历').last);
    await t.pumpAndSettle();
    final core = find.text('本次共同尺度中的范围 · 对应核心概念：韧性');
    await t.ensureVisible(core);
    await t.tap(core);
    await t.pumpAndSettle();
    expect(find.text('韧性'), findsWidgets);
  });
  testWidgets(
      'missing scopes invite completing the common basis rather than denying any relationship',
      (t) async {
    final m = purposefulCase()..['relations'] = [];
    var regenerated = 0;
    await mount(
        t,
        SemanticScopeView(
            value: value(m),
            sources: originals,
            preferredView: EpistemicViewKind.circles,
            onRegenerate: () => regenerated++));
    final action = find.text('按本次考量补全共同尺度与含义圈');
    await t.ensureVisible(action);
    await t.tap(action);
    await t.pumpAndSettle();
    expect(regenerated, 1);
    expect(find.textContaining('不能建立'), findsNothing);
    await mount(
        t,
        SemanticScopeView(
            value: value(),
            sources: originals,
            preferredView: EpistemicViewKind.grounds),
        width: 320,
        scale: 2);
    expect(t.takeException(), isNull);
    await capture(t, 'case-large-text');
  });
}
