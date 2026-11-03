import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/concept_hierarchy_view.dart';
import 'package:quote_app/epistemic/history_timeline.dart';
import 'package:quote_app/epistemic/quote_cognitive_reader.dart';
import 'package:quote_app/epistemic/reading_illustration.dart';
import 'package:quote_app/epistemic/reading_map_quality.dart';
import 'package:quote_app/epistemic/semantic_scope.dart';
import 'package:quote_app/epistemic/semantic_scope_service.dart';
import 'package:quote_app/epistemic/semantic_scope_view.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/services/semantic_json_transport.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const recipeQuote =
    'The shoe that fits one person pinches another; there is no recipe for living that suits all cases.';
Map<String, dynamic> record(String id, String text, DateTime time,
        {String author = '黑格尔'}) =>
    {
      'quote_uid': id,
      'content': text,
      'author_name': author,
      'inserted_at': time.toIso8601String(),
      'created_at': time.millisecondsSinceEpoch,
    };
List<Map<String, dynamic>> timelineRows() => [
      record('later', '花蕾随着花朵的绽放而消逝；人们可以说，花朵否定了花蕾。果实出现时，花朵又显得是植物存在的一种形式。',
          DateTime(2026, 11, 2, 18)),
      record('old', '花蕾在花朵绽放时消逝；人们可以说，花朵否定了花蕾。', DateTime(2026, 11, 1, 15)),
      record('early', recipeQuote, DateTime(2026, 11, 2, 8), author: '卡尔·荣格'),
      record('now', '花蕾在花朵绽放时消失了，人们可以说，前者被后者否定了；同样，果实出现时，花朵被说明为植物的一种形式。',
          DateTime(2026, 11, 2, 12)),
    ];

class FailingMapService extends SemanticScopeService {
  int calls = 0;
  @override
  Future<SemanticScope?> cached(List<ScopeSource> sources, String focus,
          {SemanticContext context = const SemanticContext()}) async =>
      null;
  @override
  Future<SemanticScope> analyze(List<ScopeSource> sources, String focus,
      {bool force = false,
      SemanticContext context = const SemanticContext()}) async {
    calls++;
    if (calls == 1)
      throw const SemanticRequestException('连接在完整结果返回前中断。请检查网络后手动重试。');
    return readingIllustration(sources.first.text)!;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late Directory docs;
  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    docs = await Directory.systemTemp.createTemp('timeline-stream-ui-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    db = await AppDatabase.instance();
    await CognitivePreferenceStore.instance.load();
    final cjk = File('/tmp/quote-preview-cjk.otf');
    if (cjk.existsSync())
      await (FontLoader('PreviewCJK')
            ..addFont(
                Future.value(ByteData.sublistView(cjk.readAsBytesSync()))))
          .load();
    for (final font in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'QuoteLiterarySerif': 'assets/fonts/LibreBaskerville-Variable.ttf',
      'QuoteXingShu': 'assets/fonts/ZhiMangXing-Regular.ttf',
      'QuoteSignatureLatin': 'assets/fonts/Allura-Regular.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  tearDownAll(() async {
    await db.close();
    await docs.delete(recursive: true);
  });
  setUp(() async {
    await CognitivePreferenceStore.instance.update(const CognitivePreferences(
        enabled: true, style: CognitiveStyle.conceptual));
  });
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, Widget page,
      {double width = 390, double scale = 1}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('timeline-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                fontFamily: 'PreviewCJK',
                colorSchemeSeed: const Color(0xff8f77ad)),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: page)));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final shadows = debugDisableShadows;
    try {
      debugDisableShadows = false;
      void repaint(RenderObject node) {
        node.markNeedsPaint();
        node.visitChildren(repaint);
      }

      repaint(tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('timeline-preview'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('timeline-preview')));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/quote-knowledge-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    } finally {
      debugDisableShadows = shadows;
    }
  }

  Widget timeline(
          {List<Map<String, dynamic>>? rows,
          Set<String> selected = const {},
          void Function(Map<String, dynamic>)? onOpen,
          void Function(Map<String, dynamic>)? onSelect,
          VoidCallback? onLoadMore,
          bool loading = false}) =>
      Scaffold(
          body: QuoteHistoryTimeline(
              rows: rows ?? timelineRows(),
              selectedKeys: selected,
              onOpen: onOpen ?? (_) {},
              onSelect: onSelect ?? (_) {},
              hasMore: true,
              loading: loading,
              onLoadMore: onLoadMore ?? () {}));

  test(
      'shuffled history uses earliest days first with the same direction within each day',
      () {
    final rows = timelineRows(),
        before = rows.map((r) => r['quote_uid']).toList();
    final groups = groupTimelineRows(rows);
    expect(groups.map((g) => g.label), ['2026年11月1日', '2026年11月2日']);
    expect(groups.last.entries.map((e) => e.row['quote_uid']),
        ['early', 'now', 'later']);
    expect(rows.map((r) => r['quote_uid']), before);
  });
  test('missing timestamps stay unknown and valid creation time is a fallback',
      () {
    final known = timelineRows().first;
    final groups = groupTimelineRows([
      {'quote_uid': 'unknown', 'content': '未标时间'},
      {
        'quote_uid': 'fallback',
        'content': '备用时间',
        'inserted_at': 'bad',
        'created_at': known['created_at']
      },
      known,
    ]);
    expect(groups.last.label, '记录时间未知');
    expect(groups.first.entries, hasLength(2));
    expect(groups.last.entries.single.time, isNull);
  });
  test('equal timestamps are stable and do not invent a temporal difference',
      () {
    final t = DateTime(2026, 11, 2, 12);
    final groups =
        groupTimelineRows([record('a', '同刻甲', t), record('b', '同刻乙', t)]);
    expect(groups.single.entries.map((e) => e.row['quote_uid']), ['a', 'b']);
  });
  testWidgets(
      'ribbon nodes choose the reference; cards and plus retain their actions',
      (tester) async {
    var opened = '', selected = '', loads = 0;
    await mount(
        tester,
        timeline(
            onOpen: (r) => opened = r['quote_uid'],
            onSelect: (r) => selected = r['quote_uid'],
            onLoadMore: () => loads++));
    expect(find.text('② 前一刻'), findsOneWidget);
    expect(find.text('③ 此刻'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-node-early')));
    await tester.pump();
    expect(find.text('② 此刻'), findsOneWidget);
    final quote = find.byKey(const ValueKey('timeline-quote-early'));
    await tester
        .tap(find.descendant(of: quote, matching: find.byTooltip('加入比较')));
    expect(selected, 'early');
    await tester.tap(find.text(recipeQuote));
    expect(opened, 'early');
    await tester.scrollUntilVisible(find.text('加载更多名言'), 350);
    await tester.ensureVisible(find.text('加载更多名言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多名言'));
    expect(loads, 1);
  });
  testWidgets('unknown and equal-time records have explicit badges',
      (tester) async {
    final t = DateTime(2026, 11, 2, 12);
    await mount(
        tester,
        timeline(rows: [
          record('a', '同刻甲', t),
          record('b', '同刻乙', t),
          {'quote_uid': 'u', 'content': '未标时'}
        ]));
    expect(find.text('① 同刻'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('记录时间未知'), 200);
    expect(find.textContaining('未标时'), findsWidgets);
  });
  testWidgets(
      'real history entry keeps search, comparison selection and full reading',
      (tester) async {
    final rows = timelineRows();
    var query = '';
    await mount(tester, HistoryPage(loadQuotes: (
        {required int limit, required int offset, String? q}) async {
      query = q ?? '';
      return rows
          .where((r) => '${r['content']}'.contains(query))
          .skip(offset)
          .take(limit)
          .toList();
    }));
    await tester.tap(find.text('时间线'));
    await settle(tester);
    expect(
        find.byKey(const ValueKey('timeline-scenic-header')), findsOneWidget);
    await capture(tester, 'history-timeline');
    await tester.tap(find.byTooltip('加入比较').first);
    await tester.pump();
    expect(find.text('开始比较'), findsOneWidget);
    expect(find.byTooltip('取消比较选择'), findsOneWidget);
    await tester.tap(find.text(recipeQuote));
    await settle(tester);
    expect(find.byType(QuoteCognitiveReader), findsOneWidget);
    Navigator.of(tester.element(find.byType(QuoteCognitiveReader))).pop();
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '不存在的名言');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(query, '不存在的名言');
    expect(find.textContaining('暂无匹配名言'), findsOneWidget);
  });
  testWidgets('320px and double-size text keep timeline and selection usable',
      (tester) async {
    await mount(tester, timeline(), width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byTooltip('加入比较').first, 200);
    await capture(tester, 'history-timeline-large-text');
  });
  testWidgets(
      'transport failures keep the old tree and allow an explicit successful retry',
      (tester) async {
    final service = FailingMapService();
    await mount(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: SemanticScopePanel(
                    sources: const [ScopeSource('A', recipeQuote)],
                    initial: readingIllustration(recipeQuote),
                    service: service,
                    analysisContext: readingMapContext,
                    preferredView: EpistemicViewKind.hierarchy))));
    expect(service.calls, 0);
    await tester.ensureVisible(find.text('按新版重新分析概念与连线'));
    await tester.tap(find.text('按新版重新分析概念与连线'));
    await settle(tester);
    expect(service.calls, 1);
    expect(find.textContaining('连接在完整结果返回前中断'), findsOneWidget);
    expect(find.byType(ConceptHierarchyView), findsOneWidget);
    await capture(tester, 'reading-stream-retry');
    await tester.tap(find.text('按新版重新分析概念与连线'));
    await settle(tester);
    expect(service.calls, 2);
    expect(find.textContaining('连接在完整结果返回前中断'), findsNothing);
    expect(find.byType(ConceptHierarchyView), findsOneWidget);
  });
}
