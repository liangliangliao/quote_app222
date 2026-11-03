import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/concept_analysis.dart';
import 'package:quote_app/epistemic/concept_circle_preview.dart';
import 'package:quote_app/epistemic/concept_meaning_network.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/grounding_path_view.dart';
import 'package:quote_app/epistemic/legacy_concept_view.dart';
import 'package:quote_app/epistemic/quote_cognitive_reader.dart';
import 'package:quote_app/epistemic/reading_illustration.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/unified_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const recipe =
    'There is no recipe for living that suits all cases. Each person must examine the conditions of their own life.';
const travel = '旅行可以带来见闻，也会花费金钱；新增的欲望和内心的安定需要分别判断。';

class ReadingAi extends UnifiedAiService {
  final List<dynamic> answers;
  final prompts = <String>[];
  int calls = 0;
  ReadingAi(this.answers);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'reading-fixture',
          endpoint: 'https://example.invalid',
          label: '模拟',
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
    final value = answers[calls.clamp(0, answers.length - 1)];
    calls++;
    return value is String ? value : jsonEncode(value);
  }
}

Map<String, dynamic> shallow(String text) => {
      'concepts': [
        {
          'id': 'fit',
          'label': '个体适配',
          'definition': '建议要适合个人',
          'kind': 'concept',
          'references': [
            {'source': 'A', 'excerpt': text}
          ]
        },
        {
          'id': 'bad',
          'label': '“个体适配”的具体表现',
          'definition': '个体适配的具体表现',
          'kind': 'experience',
          'status': 'example',
          'references': [
            {'source': 'A', 'excerpt': text}
          ]
        }
      ],
      'hierarchy': [
        {
          'parent': 'fit',
          'child': 'bad',
          'kind': 'instance',
          'explanation': '实例',
          'references': [
            {'source': 'A', 'excerpt': text}
          ]
        }
      ],
      'relations': [],
      'grounds': [],
      'judgments': []
    };
SemanticScope travelMap() {
  final refs = [
        {'source': 'A', 'excerpt': travel}
      ],
      nodes = <Map<String, dynamic>>[],
      edges = <Map<String, dynamic>>[],
      relations = <Map<String, dynamic>>[];
  void n(String id, String label, String definition, {bool example = false}) =>
      nodes.add({
        'id': id,
        'label': label,
        'definition': definition,
        'kind': example ? 'experience' : 'concept',
        'status': example ? 'example' : 'definition',
        'references': refs
      });
  void e(String p, String c, {bool ground = false}) => edges.add({
        'parent': p,
        'child': c,
        'kind': ground ? 'grounding' : 'subtype',
        'explanation': ground ? '这段可观察的模拟为概念提供内容。' : '在上位规定中进一步限定这类活动。',
        'references': refs
      });
  n('act', '活动', '人在条件中进行的活动。');
  n('trip', '出行活动', '活动中离开惯常地点的行动。');
  e('act', 'trip');
  n('learn', '观察性的旅行', '出行中有意识观察并记录差别的活动。');
  e('trip', 'learn');
  n('street', '走访历史街区', '观察性旅行中，针对一处历史街区的活动。');
  e('learn', 'street');
  n('walk', '周六在老街对比两处门窗', '模拟：周六上午九点，旅人在老街先后观察两处门窗，拍下形状差别并记下对应街号。',
      example: true);
  e('street', 'walk', ground: true);
  const labels = ['规划旅行', '照顾身体状态', '核对旅途支出', '记录新的见闻', '辨认新增欲望', '观察心绪安定'];
  const cases = [
    '只在桌上规划路线，尚未核对个人体力。',
    '安排徒步路线时，核对自己连续两天的步数和疲劳。',
    '为恢复体力选择旅店休息，同时核对一晚住宿支出。',
    '记录博物馆门票支出，同时记下展柜中新见的地名。',
    '记下新地名后，发现自己又想去更多地方。',
    '察觉继续旅行的欲望时，放下手机看水面，记录到心绪变化。',
    '只在河边观察平静水面，尚未继续制定出行计划。'
  ];
  for (var i = 0; i < cases.length; i++)
    n('case$i', cases[i],
        '模拟：旅途中一位观察者记录：${cases[i]} 这是一张限定情境中的行动记录卡，不能推广到全部旅行。',
        example: true);
  for (var i = 0; i < labels.length; i++) {
    n('c$i', labels[i], '本次有限记录中呈现${labels[i]}这一活动的卡片，成员仅为卡$i和卡${i + 1}。');
    e('c$i', 'case$i', ground: true);
    e('c$i', 'case${i + 1}', ground: true);
    if (i < labels.length - 1)
      relations.add({
        'placement': 'A',
        'status': 'definition',
        'statement': '按这组记录的成员同时呈现两种活动，展示有限模拟中的交叠。',
        'references': refs,
        'node_ids': ['c$i', 'c${i + 1}'],
        'scope': {
          'relation_type': 'overlap',
          'relation_scope': 'extension',
          'universe': '本次旅行练习的7张模拟记录卡',
          'set_a': labels[i],
          'set_b': labels[i + 1],
          'criterion_a': '卡$i及卡${i + 1}出现${labels[i]}。',
          'criterion_b': '卡${i + 1}及卡${i + 2}出现${labels[i + 1]}。',
          'basis': travel,
          'justification': '由逐张记录定义成员，不断言原句证明了所有旅行的因果。',
          'only_a': cases[i],
          'intersection': cases[i + 1],
          'only_b': cases[i + 2],
          'illustration': true
        }
      });
  }
  return SemanticScope.parse({
    'schema_version': 2,
    'concepts': nodes,
    'hierarchy': edges,
    'relations': relations,
    'grounds': [],
    'judgments': []
  }, const [
    ScopeSource('A', travel)
  ]);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory docs;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('grounded-reading-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    db = await AppDatabase.instance();
    await CognitivePreferenceStore.instance.load();
    final font = File('/tmp/quote-preview-cjk.otf');
    if (font.existsSync())
      await (FontLoader('PreviewCJK')
            ..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync()))))
          .load();
    for (final entry in {
      'QuoteLiterarySerif': 'assets/fonts/LibreBaskerville-Variable.ttf',
      'QuoteSignatureLatin': 'assets/fonts/Allura-Regular.ttf',
      'QuoteXingShu': 'assets/fonts/ZhiMangXing-Regular.ttf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value)))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  tearDownAll(() async {
    await db.close();
    await docs.delete(recursive: true);
  });
  setUp(() async => CognitivePreferenceStore.instance.update(
      const CognitivePreferences(
          enabled: true, style: CognitiveStyle.conceptual)));
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, Widget body,
      {double scale = 1, double width = 390}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('grounded-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'PreviewCJK',
                colorSchemeSeed: const Color(0xff977a4c)),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                backgroundColor: const Color(0xfffbf8ef), body: body))));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('grounded-preview')));
      final img = await boundary.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/quote-knowledge-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
    });
  }

  test(
      'section 9 chains are finite, mediated and every concept reaches concrete material',
      () {
    final value = readingIllustration(recipe)!;
    expect(
        readingIllustration('There is a universal recipe for living.'), isNull);
    expect(ReadingMapQuality.issues(value), isEmpty);
    expect(ReadingMapQuality.depth(value), greaterThanOrEqualTo(5));
    expect(value.hierarchy.any((e) => e.kind == 'mediation'), isTrue);
    expect(value.hierarchy.any((e) => e.kind == 'grounding'), isTrue);
    expect(
        value.concepts
            .where((c) => c.kind == 'experience')
            .any((c) => ReadingMapQuality.placeholder(c.label)),
        isFalse);
    final missing = value.toJson();
    (missing['hierarchy'] as List).removeWhere((e) => e['kind'] == 'grounding');
    final bad = SemanticScope.parse(missing, const [ScopeSource('A', recipe)]);
    expect(
        ReadingMapQuality.issues(bad).any((i) => i.path == 'reading.grounding'),
        isTrue);
  });
  test(
      'long circle chain uses one verified canvas and checkable member examples',
      () {
    final value = readingIllustration(recipe)!,
        clusters = ConceptCircleLayout.build(value);
    expect(clusters, hasLength(1));
    expect(clusters.single.verified, isTrue);
    expect(clusters.single.circles, hasLength(6));
    expect(
        value.relations.every((r) =>
            r.scope!.illustration &&
            r.scope!.intersection.isNotEmpty &&
            r.scope!.onlyA.isNotEmpty &&
            r.scope!.onlyB.isNotEmpty),
        isTrue);
    expect(clusters.single.size.width, lessThan(1000));
  });
  test(
      'saved concrete examples replace the term plus concrete-manifestation placeholder',
      () {
    final value = legacyConceptView('匿名评审需要隐去作者身份。', [
      const ConceptAbstraction(
          term: '匿名评审',
          definition: '作者身份对评审者隐藏',
          observed: '',
          retained: '隐藏身份',
          omitted: '稿件主题',
          counterExample: '知道作者是谁',
          memberExample: '模拟：编辑删除稿件署名后交给评审，评审独立写下评分和依据。')
    ], [])!;
    expect(value.concepts.last.label, contains('编辑删除稿件署名'));
    expect(value.concepts.last.label, isNot(contains('具体表现')));
  });
  test(
      'generic responses require explicit retry; successful maps alone are cached',
      () async {
    expect(readingIllustration(travel), isNull);
    final good = travelMap();
    expect(ReadingMapQuality.issues(good), isEmpty);
    final ai = ReadingAi([shallow(travel), good.toJson()]);
    final service = SemanticScopeService(
        ai: ai, store: CognitiveStore(database: () async => db));
    final result = await service.analyze(
        const [ScopeSource('A', travel)], '完整阅读验收',
        context: readingMapContext, force: true);
    expect(ai.calls, 1);
    expect(ReadingMapQuality.issues(result), isNotEmpty);
    expect(result.needsRepair, isTrue);
    expect(ai.prompts.first, contains('没有固定层数'));
    await service.analyze(const [ScopeSource('A', travel)], '完整阅读验收',
        context: readingMapContext);
    expect(ai.calls, 2);
  });
  testWidgets(
      'actual reader has grounded chains and circle tab never substitutes a hierarchy',
      (tester) async {
    final ai = ReadingAi([readingIllustration(recipe)!.toJson()]);
    final service = SemanticScopeService(ai: ai);
    await mount(
        tester,
        QuoteCognitiveReader(
            quote: const QuoteReference(id: 'recipe-v7', content: recipe),
            topic: '生活处方与个体条件',
            authorLabel: '署名待核对',
            note: '',
            semanticService: service));
    expect(ai.calls, 0);
    expect(find.byType(GroundingPathView), findsNothing);
    final generate = find.text('生成概念树与适用的含义圈');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await settle(tester);
    expect(ai.calls, 1);
    await tester.ensureVisible(find.text('追踪概念的直观链路'));
    await tester.tap(find.text('追踪概念的直观链路'));
    await settle(tester);
    expect(find.byType(GroundingPathView), findsOneWidget);
    await capture(tester, 'reading-grounded-chain');
    await tester.ensureVisible(
        find.byKey(const ValueKey('grounding-node-night-example')));
    await capture(tester, 'reading-concrete-intuition');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '含义圈'));
    await tester.tap(find.widgetWithText(ChoiceChip, '含义圈'));
    await settle(tester);
    expect(find.byType(ConceptMeaningNetwork), findsOneWidget);
    expect(find.byType(GroundingPathView), findsNothing);
    expect(find.textContaining('当前内容更适合'), findsNothing);
    expect(ai.calls, 1);
    await tester.ensureVisible(find.byType(ConceptMeaningNetwork));
    await capture(tester, 'reading-multiple-circles');
    await tester.ensureVisible(find.text('按新版重新分析概念与连线'));
    await tester.tap(find.text('按新版重新分析概念与连线'));
    await settle(tester);
    expect(ai.calls, 2);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '概念树'));
    await tester.tap(find.widgetWithText(ChoiceChip, '概念树'));
    await settle(tester);
    expect(ai.calls, 2);
  });
  testWidgets(
      'an unresolved circle request retains circles and large text stays readable',
      (tester) async {
    final value =
        SemanticScope.parse(shallow(travel), const [ScopeSource('A', travel)]);
    await mount(
        tester,
        SingleChildScrollView(
            child: SemanticScopeView(
                value: value,
                sources: const [ScopeSource('A', travel)],
                preferredView: EpistemicViewKind.circles)),
        width: 320,
        scale: 2);
    expect(find.byType(ConceptCirclePreview), findsOneWidget);
    expect(find.byType(GroundingPathView), findsNothing);
    expect(tester.takeException(), isNull);
    await mount(
        tester,
        SingleChildScrollView(
            child: SemanticScopeView(
                value: travelMap(),
                sources: const [ScopeSource('A', travel)],
                preferredView: EpistemicViewKind.circles)),
        width: 320,
        scale: 2);
    expect(find.byType(ConceptMeaningNetwork), findsOneWidget);
    await capture(tester, 'reading-circles-large-text');
  });
}
