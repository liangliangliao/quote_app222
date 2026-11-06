import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/services/unified_ai_service.dart';

/// Legacy comparison fixtures explicitly report missing semantic definitions.
Map<String, dynamic> unresolvedMap(List<ScopeSource> sources) => {
      'relations': [
        for (final s in sources)
          {
            'placement': s.id,
            'status': 'unknown',
            'scope': null,
            'statement': '当前材料未充分界定概念成员，须先澄清判断所用的尺度。',
            'references': [
              {'source': s.id, 'excerpt': s.text}
            ]
          },
        if (sources.length > 1)
          {
            'placement': 'cross',
            'status': 'unknown',
            'scope': null,
            'statement': '不同材料的概念须分别界定，尚不能推出外延关系。',
            'references': [
              for (final s in sources) {'source': s.id, 'excerpt': s.text}
            ]
          }
      ],
      'grounds': []
    };

const semanticSentence =
    '同一论域中，平面等边三角形与平面等角三角形外延重合；马属于动物；平面三角形按角分为锐角、直角、钝角三类；红色物体与花部分相交；水和土都属于物质而未穷尽它。';
Map<String, dynamic> scopeFixture(String type) => {
      'relation_type': type,
      'relation_scope': 'extension',
      'universe': '动物',
      'set_a': '马',
      'set_b': '动物',
      'criterion_a': '动物中属于马类的个体',
      'criterion_b': '属于动物的个体',
      'basis': '马属于动物',
      'justification': '按明确的成员判准判定所列关系。',
      'intersection': '一匹马',
      'only_a': '',
      'only_b': '一只猫',
      'other_member': '空气',
      'parts': [],
      'illustration': false,
    };
Map<String, dynamic> relationFixture(String type) {
  final scope = scopeFixture(type);
  if (type == 'equal')
    scope.addAll(
        {'set_a': '平面等边三角形', 'set_b': '平面等角三角形', 'universe': '非退化欧氏平面三角形'});
  if (type == 'partition')
    scope.addAll({
      'universe': '非退化欧氏平面三角形',
      'set_a': '按角的分类',
      'set_b': '三角形',
      'parts': [
        for (final term in ['锐角三角形', '直角三角形', '钝角三角形'])
          {'term': term, 'criterion': '按最大角的类型', 'example': '对应的欧氏平面三角形'}
      ]
    });
  if (type == 'overlap')
    scope.addAll({
      'set_a': '红色物体',
      'set_b': '花',
      'universe': '可观察的物体',
      'intersection': '红花',
      'only_a': '红布',
      'only_b': '白花'
    });
  if (type == 'siblings')
    scope.addAll({
      'set_a': '水',
      'set_b': '土',
      'universe': '按选文词义划分的物质种类',
      'only_a': '水',
      'only_b': '土',
      'other_member': '空气'
    });
  if (type == 'equal') scope.addAll({'only_a': '', 'only_b': ''});
  if (type == 'partition' || type == 'siblings') scope['intersection'] = '';
  final excerpt = switch (type) {
    'equal' => '平面等边三角形与平面等角三角形外延重合',
    'partition' => '平面三角形按角分为锐角、直角、钝角三类',
    'overlap' => '红色物体与花部分相交',
    'siblings' => '水和土都属于物质而未穷尽它',
    _ => '马属于动物'
  };
  scope['basis'] = excerpt;
  if (type == 'equal')
    scope.addAll({
      'criterion_a': '欧氏平面中三边相等',
      'criterion_b': '欧氏平面中三角相等',
      'intersection': '边长相同的平面三角形'
    });
  if (type == 'overlap')
    scope.addAll({'criterion_a': '可见表面为红色', 'criterion_b': '属于花的对象'});
  if (type == 'siblings')
    scope.addAll({'criterion_a': '按选文用水的物质类别', 'criterion_b': '按选文用土的物质类别'});
  if (type == 'partition')
    scope.addAll({
      'criterion_a': '最大角小于90度的三角形',
      'criterion_b': '最大角恰为90度的三角形',
      'parts': [
        {
          'term': '锐角三角形',
          'criterion': '最大角小于90度',
          'example': '三角分别为60度、60度、60度'
        },
        {
          'term': '直角三角形',
          'criterion': '有一个角等于90度',
          'example': '三角分别为30度、60度、90度'
        },
        {
          'term': '钝角三角形',
          'criterion': '有一个角大于90度',
          'example': '三角分别为30度、40度、110度'
        }
      ]
    });
  return {
    'placement': 'A',
    'status': 'text_claim',
    'statement': '依照选文中的概念和所列判准进行分类。',
    'scope': scope,
    'references': [
      {'source': 'A', 'excerpt': excerpt}
    ]
  };
}

class SemanticFakeAi extends UnifiedAiService {
  final Map<String, dynamic> answer;
  int calls = 0;
  SemanticFakeAi(this.answer);
  @override
  Future<UnifiedAiResolvedConfig> resolveGlobalConfig(
          {String? forcedProvider, String? forcedModel}) async =>
      const UnifiedAiResolvedConfig(
          provider: 'test',
          apiKey: '',
          model: 'semantic-test',
          endpoint: 'https://example.invalid',
          label: 'test',
          displayModel: 'semantic-test',
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
    calls++;
    return jsonEncode(answer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'PreviewCJK': '/tmp/quote-preview-cjk.otf',
      'MaterialIcons':
          '/workspace/scratch/flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    }.entries) {
      final f = File(entry.value);
      if (f.existsSync())
        await (FontLoader(entry.key)
              ..addFont(
                  Future.value(ByteData.sublistView(f.readAsBytesSync()))))
            .load();
    }
  });
  const sources = [ScopeSource('A', semanticSentence)];
  test('canonical five patterns retain parent, direction and exhaustive parts',
      () {
    for (final type in [
      'equal',
      'subset',
      'partition',
      'overlap',
      'siblings'
    ]) {
      final r = SemanticScope.parse({
        'relations': [relationFixture(type)],
        'grounds': []
      }, sources);
      final restored = SemanticScope.parse(r.toJson(), sources);
      expect(restored.relations.single.scope!.relation.name, type);
      if (type == 'partition')
        expect(restored.relations.single.scope!.parts.length, 3);
    }
  });
  test('independent views survive absent or invalid cross-passage geometry',
      () {
    const two = [ScopeSource('A', '轻视不等于恨'), ScopeSource('B', '欣赏生活美好')];
    final m = unresolvedMap(two);
    expect(SemanticScope.parse(m, two).relations.length, 3);
    final broken = jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    (broken['relations'] as List).removeLast();
    expect(SemanticScope.parse(broken, two).relations.length, 2);
    final wrong = jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    wrong['relations'][2]['references'][1]['excerpt'] = '原文没有的证据';
    final partial = SemanticScope.parse(wrong, two);
    expect(partial.relations.length, 2);
    expect(partial.issues.single.message, contains('原文不符'));
  });
  test('counts and isolated single concepts cannot establish a diagram', () {
    final invalid = relationFixture('disjoint');
    expect(
        () => SemanticScope.parse({
              'relations': [invalid]
            }, sources),
        throwsFormatException);
    invalid['scope'] = scopeFixture('equal')..['set_b'] = '马';
    expect(
        () => SemanticScope.parse({
              'relations': [invalid]
            }, sources),
        throwsFormatException);
    invalid['scope'] = scopeFixture('partition');
    expect(
        () => SemanticScope.parse({
              'relations': [invalid]
            }, sources),
        throwsFormatException);
    invalid['scope'] = scopeFixture('siblings')..['other_member'] = '';
    expect(
        () => SemanticScope.parse({
              'relations': [invalid]
            }, sources),
        throwsFormatException);
  });
  test('grounds preserve distinct relation types and source direction', () {
    final m = {
      'relations': [relationFixture('subset')],
      'grounds': [
        for (final kind in ['evidence', 'cause', 'time', 'space'])
          {
            'kind': kind,
            'from': '原句中的前项',
            'to': '原句中的后项',
            'link': '依原句关系',
            'status': 'text_claim',
            'spatial_relation': kind == 'space' ? 'right' : '',
            'references': [
              {'source': 'A', 'excerpt': '马属于动物'}
            ]
          }
      ]
    };
    final result = SemanticScope.parse(m, sources);
    expect(result.grounds.map((g) => g.kind),
        ['evidence', 'cause', 'time', 'space']);
    expect(SemanticScope.parse(result.toJson(), sources).grounds.last.position,
        'right');
  });
  test(
      'model results are cached by selected material and invalid regeneration preserves them',
      () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final store = CognitiveStore(database: () async => db);
    final answer = {
      'relations': [relationFixture('subset')],
      'grounds': []
    };
    final ai = SemanticFakeAi(answer);
    final service = SemanticScopeService(ai: ai, store: store);
    expect(await service.cached(sources, '句内'), isNull);
    await Future.wait(
        [service.analyze(sources, '句内'), service.analyze(sources, '句内')]);
    expect(ai.calls, 1);
    expect((await service.cached(sources, '句内'))!.relations.single.scope!.setA,
        '马');
    expect(await service.cached(const [ScopeSource('A', '另一条完全不同的材料')], '句内'),
        isNull);
    answer['relations'] = [];
    final failing = SemanticScopeService(ai: ai, store: store);
    await expectLater(
        failing.analyze(sources, '句内', force: true), throwsFormatException);
    expect((await service.cached(sources, '句内'))!.relations.single.scope!.setA,
        '马');
    await db.close();
  });

  testWidgets(
      'five real geometries and four ground diagrams render with taps and large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final type in [
      'equal',
      'subset',
      'partition',
      'overlap',
      'siblings'
    ]) {
      final value = SemanticScope.parse({
        'relations': [relationFixture(type)],
        'grounds': []
      }, sources, model: '验收样例');
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'PreviewCJK'),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: RepaintBoundary(
                      key: const ValueKey('capture'),
                      child: Container(
                          color: const Color(0xfffcf7eb),
                          padding: const EdgeInsets.all(16),
                          child: SemanticScopeView(
                              value: value, sources: sources)))))));
      await tester.pumpAndSettle();
      if (type == 'partition') {
        await tester.ensureVisible(find.text('2　直角三角形'));
        await tester.tap(find.text('2　直角三角形'));
        await tester.pumpAndSettle();
        expect(find.textContaining('30度、60度、90度'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('capture')))
            .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File('build/cognitive-preview/five-$type.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    final grounds = [
      for (final kind in ['evidence', 'cause', 'time', 'space'])
        GroundDiagram(kind, '材料中的依据或前项', '结论或后项', '原文主张仍需检验', 'text_claim',
            const [ScopeReference('A', '马属于动物')],
            position: kind == 'space' ? 'right' : '')
    ];
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'PreviewCJK'),
        home: Scaffold(
            body: SingleChildScrollView(
                child: RepaintBoundary(
                    key: const ValueKey('capture'),
                    child: Column(children: [
                      for (final g in grounds) GroundRelationView(g)
                    ]))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('capture')))
          .toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/cognitive-preview/ground-types.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(
                    textScaler: TextScaler.linear(2), size: Size(320, 800)),
                child: SingleChildScrollView(
                    child: Column(children: [
                  for (final g in grounds) GroundRelationView(g)
                ]))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
