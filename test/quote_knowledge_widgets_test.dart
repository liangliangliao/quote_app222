import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/quote_knowledge/constellation_view.dart';
import 'package:quote_app/quote_knowledge/management_sheet.dart';
import 'package:quote_app/quote_knowledge/models.dart';
import 'package:quote_app/quote_knowledge/repository.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/widgets/quote_comparison_sheet.dart';
import 'package:quote_app/widgets/quote_portrait.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const quoteA =
    QuoteReference(id: 'nietzsche', content: '凡不能杀死我的，使我更强大。', author: '尼采');
const quoteB = QuoteReference(
    id: 'tal',
    content: '幸福并非抵达山顶，也不是漫无目的地在山间攀爬；幸福是朝着山顶攀登的体验。',
    author: 'Tal Ben-Shahar');

class PrototypeComparison extends QuoteComparisonService {
  int calls = 0;
  @override
  Future<QuoteComparison> compareForPurpose(QuoteReference a, QuoteReference b,
      ComparisonPurpose purpose, String conditions) async {
    calls++;
    return const QuoteComparison(
        common: '有方向地成长',
        difference: 'A关注承受挑战后的力量，B关注朝向目标时的体验价值。',
        notEquivalent: '承受挑战不一定感到愉悦；愉悦体验也不一定包含挑战。',
        limitation: '圆圈只描述构造的学习经历示例，不能概括所有苦难或幸福。',
        relation: QuoteRelation.overlap,
        relationScope: 'extension',
        setA: '经历挑战',
        setB: '愉悦体验',
        basisA: '艰难完成练习，当时没有乐趣。',
        basisB: '轻松欣赏风景，没有面对挑战。',
        universe: '模拟练习：可分别回忆的学习经历',
        groundedInQuotes: true,
        justification: '以两句的挑战和过程体验为线索构造具体练习，不代表两位作者主张了集合关系。',
        modelDisplayName: '验收样例 · 模拟模型');
  }
}

class FirstPageOnly extends QuoteDao {
  final List<Map<String, dynamic>> rows;
  FirstPageOnly(this.rows);
  @override
  Future<List<Map<String, dynamic>>> latest(
          {int limit = 100, int offset = 0, String? q}) async =>
      offset == 0 ? rows.take(2).toList() : [];
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory docs;
  late QuoteKnowledgeRepository repository;
  final rows = <Map<String, dynamic>>[];
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('knowledge-prototypes-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    final concurrent =
        await Future.wait(List.generate(3, (_) => AppDatabase.instance()));
    expect(concurrent.every((value) => identical(value, concurrent.first)),
        isTrue);
    db = concurrent.first;
    repository = QuoteKnowledgeRepository(database: () async => db);
    await repository.database;
    for (final font in {'PreviewCJK': '/tmp/quote-preview-cjk.otf'}.entries) {
      if (File(font.value).existsSync())
        await (FontLoader(font.key)
              ..addFont(Future.value(
                  ByteData.sublistView(File(font.value).readAsBytesSync()))))
            .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final cats = {for (final c in await repository.categories()) c.name: c.id};
    final self = await repository.createCategory('自我', '关于自我认识的名言');
    final nature = await repository.createCategory('自然', '关于自然与观察的名言');
    cats.addAll({'自我': self, '自然': nature});
    const counts = {
      '幸福': 32,
      '痛苦': 26,
      '成长': 24,
      '责任': 24,
      '自由': 18,
      '意义': 16,
      '自我': 14,
      '自然': 15
    };
    var index = 0;
    for (final entry in counts.entries) {
      for (var i = 0; i < entry.value; i++) {
        final ref = i.isEven ? quoteA : quoteB;
        final row = <String, dynamic>{
          'quote_uid': 'fixture-${index++}',
          'content': ref.content,
          'author_name': ref.author,
          'theme': entry.key,
          'inserted_at': '2026-11-02T00:00:00Z'
        };
        await db.insert('quotes', row);
        await repository
            .assignManually(knowledgeQuoteKey(row), [cats[entry.key]!]);
        rows.add(row);
      }
    }
    final child = await repository.createCategory('过程性的幸福', '在朝向目标的过程中体验到的幸福',
        parentId: cats['幸福']!);
    await repository
        .assignManually(knowledgeQuoteKey(rows.first), [child, cats['成长']!]);
  });
  tearDownAll(() async {
    await db.close();
    await docs.delete(recursive: true);
  });
  setUp(() async => CognitivePreferenceStore.instance
      .update(const CognitivePreferences(enabled: true)));
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, Widget home,
      {double width = 390, double scale = 1}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.binding.setSurfaceSize(Size(width, 880));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('knowledge-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'PreviewCJK',
                colorSchemeSeed: const Color(0xff8d7753)),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: home)));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('knowledge-preview')));
      final picture = await boundary.toImage(pixelRatio: 2);
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/quote-knowledge-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets(
      'actual History graph uses whole library and matches constellation prototype',
      (tester) async {
    var selection = 0;
    var nightReported = false;
    await mount(
        tester,
        HistoryPage(
            dao: FirstPageOnly(rows),
            knowledgeRepository: repository,
            onGraphChanged: (value) => nightReported = value));
    await tester.tap(find.text('关系图'));
    await settle(tester);
    expect(nightReported, isTrue);
    expect(find.text('(32)'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('洗牌（物理重排）'), findsNothing);
    expect(find.byType(QuotePortrait), findsWidgets);
    await capture(tester, 'history-constellation');
    final viewport =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewport.transformationController!.value =
        Matrix4.diagonal3Values(1.5, 1.5, 1);
    await tester.pump();
    expect(viewport.transformationController!.value.getMaxScaleOnAxis(), 1.5);
    await tester.tap(find.byTooltip('查看分类树'));
    await settle(tester);
    expect(find.textContaining('幸福  32'), findsOneWidget);
    await tester.tap(find.byTooltip('切换星图'));
    await settle(tester);
    await tester.tap(find.byTooltip('加入比较').first);
    await settle(tester);
    selection = tester
        .widget<QuoteKnowledgeConstellation>(
            find.byType(QuoteKnowledgeConstellation))
        .selectedKeys
        .length;
    expect(selection, 1);
    await tester.tap(find.byTooltip('分类管理'));
    await settle(tester);
    expect(find.text('一键分批整理旧记录'), findsOneWidget);
  });
  testWidgets(
      'comparison has paired portraits, four tabs and interactive validated diagram',
      (tester) async {
    final service = PrototypeComparison();
    await mount(
        tester,
        Scaffold(
            body:
                QuoteComparisonSheet(a: quoteA, b: quoteB, service: service)));
    expect(find.byType(QuotePortrait), findsNWidgets(2));
    expect(find.text('各自的分析'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-set-diagram')), findsOneWidget);
    await capture(tester, 'comparison-circles');
    await tester.tap(find.byKey(const ValueKey('comparison-tab-2')));
    await settle(tester);
    expect(service.calls, 1);
    await tester.tap(find.byKey(const ValueKey('comparison-tab-3')));
    await settle(tester);
    expect(find.textContaining('待确定'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      '320px, large text and reduced motion support both prototypes and management',
      (tester) async {
    await tester.runAsync(() => CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true, reduceMotion: true)));
    await mount(
        tester,
        Scaffold(
            body: QuoteKnowledgeConstellation(
                repository: repository,
                selectedKeys: const {},
                onOpen: (_) {},
                onSelect: (_) {})),
        width: 320,
        scale: 2);
    expect(tester.takeException(), isNull);
    await capture(tester, 'history-large-text');
    await tester.tap(find.byTooltip('全部类别'));
    await settle(tester);
    await tester.enterText(
        find.byKey(const ValueKey('history-concept-search')), '过程性');
    await settle(tester);
    expect(find.text('过程性的幸福'), findsOneWidget);
    await mount(
        tester,
        Scaffold(
            body: QuoteComparisonSheet(
                a: quoteA, b: quoteB, service: PrototypeComparison())),
        width: 320,
        scale: 2);
    expect(tester.takeException(), isNull);
    await capture(tester, 'comparison-large-text');
    await tester.scrollUntilVisible(find.text('选择行动'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('选择行动'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await mount(
        tester,
        Scaffold(
            body: QuoteKnowledgeManagement(
                repository: repository, quote: rows.first)),
        width: 320,
        scale: 2);
    expect(tester.takeException(), isNull);
  });
}
