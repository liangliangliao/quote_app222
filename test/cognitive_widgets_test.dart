import 'package:quote_app/pages/history_page.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/thought_taxonomy_seed.dart';
import 'package:quote_app/data/quote_insight_store.dart';
import 'package:quote_app/diary/diary_dao.dart';
import 'package:quote_app/diary/entry_editor_page.dart';
import 'package:quote_app/epistemic/cognitive_models.dart';
import 'package:quote_app/epistemic/cognitive_preferences.dart';
import 'package:quote_app/epistemic/cognitive_service.dart';
import 'package:quote_app/epistemic/cognitive_settings.dart';
import 'package:quote_app/epistemic/cognitive_sheet.dart';
import 'package:quote_app/epistemic/cognitive_store.dart';
import 'package:quote_app/epistemic/cognitive_training.dart';
import 'package:quote_app/epistemic/history_knowledge_view.dart';
import 'package:quote_app/epistemic/movie_cognition.dart';
import 'package:quote_app/epistemic/concept_explorer.dart';
import 'package:quote_app/epistemic/cognitive_recap.dart';
import 'package:quote_app/epistemic/quote_concept_catalog.dart';
import 'package:quote_app/epistemic/quote_cognitive_reader.dart';
import 'package:quote_app/epistemic/gentle_counterexample.dart';
import 'package:quote_app/epistemic/cognitive_hint_budget.dart';
import 'package:quote_app/epistemic/cognitive_usage.dart';
import 'package:quote_app/epistemic/cognitive_reflection.dart';
import 'package:quote_app/services/quote_visual_script_service.dart';
import 'package:quote_app/widgets/thought_record_dialog.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_comparison_sheet.dart';
import 'package:quote_app/widgets/thought_taxonomy_mindmap.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'cognitive_core_test.dart' as core;

class _ScopeHistoryDao extends QuoteDao {
  final List<Map<String, dynamic>> rows;
  _ScopeHistoryDao(this.rows);
  @override
  Future<List<Map<String, dynamic>>> latest(
          {int limit = 100, int offset = 0, String? q}) async =>
      rows
          .where((r) => q == null || '${r['content']}'.contains(q))
          .skip(offset)
          .take(limit)
          .toList();
}

class _Comparisons extends QuoteComparisonService {
  final List<(ComparisonPurpose, String)> requests = [];
  @override
  Future<QuoteComparison> compareForPurpose(QuoteReference a, QuoteReference b,
      ComparisonPurpose purpose, String conditions) async {
    requests.add((purpose, conditions));
    return QuoteComparison(
        common: '共同关注持续行动',
        difference: purpose.label,
        notEquivalent: '目标不等于方法',
        limitation: conditions.isEmpty ? '条件尚待补充' : conditions,
        relation: QuoteRelation.contrast);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late Database db;
  const quote = QuoteReference(
      id: 'cognitive-test', content: '坚持目标，也要根据新信息调整方法。', author: '测试示例');
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('cognitive_widgets_');
    databaseFactory = databaseFactoryFfi;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path);
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
    await (FontLoader('QuoteXingShu')
          ..addFont(rootBundle.load('assets/fonts/ZhiMangXing-Regular.ttf')))
        .load();
    await (FontLoader('QuoteSignatureLatin')
          ..addFont(rootBundle.load('assets/fonts/Allura-Regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() async =>
      CognitivePreferenceStore.instance.update(const CognitivePreferences()));
  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester, Widget home,
      {double width = 430,
      double scale = 1,
      double height = 932,
      EdgeInsets? viewInsets}) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('cognitive-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'PreviewCJK'),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: viewInsets,
                    size: viewInsets == null ? null : Size(width, height)),
                child: child!),
            home: home)));
    await tester.pump();
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
      if (finder.evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    expect(finder, findsWidgets);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('cognitive-preview')));
      final im = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/cognitive-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      im.dispose();
    });
  }

  Future<void> enable(WidgetTester tester) async =>
      tester.runAsync(() => CognitivePreferenceStore.instance
          .update(const CognitivePreferences(enabled: true)));

  testWidgets(
      'named mode toggle persists and hides cognitive preferences when disabled',
      (tester) async {
    await mount(
        tester,
        const Scaffold(
            body: SingleChildScrollView(child: CognitiveSettingsSection())));
    expect(find.text('叔本华认知风格'), findsOneWidget);
    expect(find.text('直观优先'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('schopenhauer-style-toggle')));
    await waitFor(tester, find.text('直观优先'));
    expect(CognitivePreferenceStore.active, isTrue);
    await capture(tester, '10-settings-enabled');
    await tester.tap(find.byKey(const ValueKey('schopenhauer-style-toggle')));
    await waitFor(tester, find.textContaining('默认模式：'));
    final reopened = CognitivePreferenceStore();
    await tester.runAsync(() => reopened.load());
    expect(reopened.value.enabled, isFalse);
    expect(find.text('概念优先'), findsNothing);
    reopened.dispose();
  });

  testWidgets(
      'actual poster entry returns to legacy reader after mode is disabled',
      (tester) async {
    await tester.runAsync(() => QuoteInsightStore().saveAddon(
        quote,
        const QuoteAnalysisAddon(
            concreteExample: '模拟：遇到封路，改换路线继续前进。',
            commonality: '持续朝向目标',
            criticalDifference: '方法可以改变',
            boundary: '目标本身也可能需要修订',
            concepts: ['坚持', '判断'])));
    final poster = Scaffold(
        body: PosterPureFlutter(
            topic: '行动',
            quote: quote.content,
            author: quote.author,
            avatar: '',
            note: '原有解读内容',
            quoteReference: quote));
    await enable(tester);
    await mount(tester, poster);
    expect(find.text('直观'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await waitFor(tester, find.text('模拟：遇到封路，改换路线继续前进。'));
    expect(find.text('模拟：遇到封路，改换路线继续前进。'), findsOneWidget);
    await capture(tester, '02-reader-intuition');
    await tester.tap(find.text('概念'));
    await tester.pumpAndSettle();
    expect(find.text('坚持'), findsOneWidget);
    Navigator.of(tester.element(find.text('直观'))).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await waitFor(tester, find.text('具体是什么样子'));
    expect(find.text('直观'), findsNothing);
    expect(find.text('原有解读内容'), findsOneWidget);
  });

  testWidgets(
      'diary selection uses real context menu and leaves original row unchanged',
      (tester) async {
    final ai = core.FakeCognitiveAi();
    final service = CognitiveService(ai: ai);
    const full = '没有选中的前文。\n${core.text}\n没有选中的结尾。';
    final dao = DiaryDao();
    late int notebook, entry;
    late Map<String, Object?> before;
    await tester.runAsync(() async {
      await dao.ensureSchema();
      notebook = await dao.createNotebook('测试日记');
      entry = await dao.upsertEntry(DiaryEntry(
          id: 0,
          notebookId: notebook,
          entryTime: 1770000000000,
          weatherCode: null,
          weatherName: null,
          moodName: null,
          moodIcon: null,
          content: full,
          preview: full,
          starred: 0));
      before =
          (await db.query('entries', where: 'id=?', whereArgs: [entry])).single;
    });
    final key = GlobalKey<EntryEditorPageState>();
    await mount(
        tester,
        EntryEditorPage(
            key: key,
            notebookId: notebook,
            entryId: entry,
            cognitiveService: service,
            useBackground: false));
    await waitFor(tester, find.text(full));
    final readOnlyGate = find
        .ancestor(
            of: find.byType(EditableText).first,
            matching: find.byType(AbsorbPointer))
        .first;
    expect(tester.widget<AbsorbPointer>(readOnlyGate).absorbing, isTrue);
    await enable(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<AbsorbPointer>(readOnlyGate).absorbing, isFalse);
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(tester.widget<AbsorbPointer>(readOnlyGate).absorbing, isTrue);
    await enable(tester);
    await tester.pumpAndSettle();
    final state =
        tester.state<EditableTextState>(find.byType(EditableText).first);
    state.widget.focusNode.requestFocus();
    await tester.pumpAndSettle();
    state.widget.controller.selection = TextSelection(
        baseOffset: full.indexOf(core.text),
        extentOffset: full.indexOf(core.text) + core.text.length);
    await tester.pump();
    expect(state.showToolbar(), isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('区分事实与解释'));
    await waitFor(tester, find.text('AI 暂定理解 · 可修改或拒绝'));
    expect(ai.calls, 1);
    expect(ai.lastPrompt, isNot(contains('没有选中的')));
    expect(find.byType(DropdownButton<StatementKind>), findsNWidgets(4));
    await capture(tester, '05-diary-classification');
    await tester.tap(find.byType(DropdownButton<StatementKind>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂定判断').last);
    await waitFor(tester, find.text('撤销上一次分类修改'));
    final edited =
        await tester.runAsync(() => service.store.forRecord('diary', '$entry'));
    expect(edited!.single.analysis.spans.first.kind, StatementKind.judgment);
    await tester.ensureVisible(find.text('撤销上一次分类修改'));
    await tester.tap(find.text('撤销上一次分类修改'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('采纳这条注释'), 300,
        scrollable: find
            .descendant(
                of: find.byType(CognitiveAnalysisSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('采纳这条注释'));
    await waitFor(tester, find.text('撤销采纳'));
    final notes =
        await tester.runAsync(() => service.store.forRecord('diary', '$entry'));
    expect(notes!.single.accepted, isTrue);
    expect(notes.single.analysis.spans.first.kind, StatementKind.reportedEvent);
    await tester.runAsync(() => key.currentState!.saveIfDirty());
    final after = await tester
        .runAsync(() => db.query('entries', where: 'id=?', whereArgs: [entry]));
    expect(after!.single, before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('graph counts, zoom and timeline authors remain selectable',
      (tester) async {
    await enable(tester);
    final rows = [
      for (var i = 1; i <= 4; i++)
        <String, dynamic>{
          'quote_uid': 'graph-$i',
          'content': '实际名言 $i',
          'author_name': i <= 2 ? '甲' : '乙',
          'theme': i <= 3 ? '成长' : '自由',
          'inserted_at': '2026-10-30T00:00:00Z'
        }
    ];
    int opens = 0, selections = 0;
    Widget view(int mode) => Scaffold(
        body: HistoryKnowledgeView(
            rows: rows,
            mode: mode,
            onOpen: (_) => opens++,
            onSelect: (_) => selections++,
            selectedKeys: const {},
            onLoadMore: () {},
            hasMore: false,
            loading: false));
    await mount(tester, view(1));
    await waitFor(tester, find.textContaining('已载入 4 条名言'));
    await tester.tap(find.text('概念星图'));
    await tester.pumpAndSettle();
    expect(find.text('成长 3'), findsOneWidget);
    await capture(tester, '03-history-constellation');
    await tester.tap(find.byTooltip('放大关系图'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('加入比较').first, 240,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.byTooltip('加入比较').first);
    expect(selections, 1);
    await mount(tester, view(2));
    expect(find.text('2026年10月30日'), findsOneWidget);
    await tester.tap(find.text('实际名言 1'));
    expect(opens, 1);
    await mount(tester, view(3));
    expect(find.textContaining('甲'), findsWidgets);
  });

  testWidgets(
      'legacy James records expose a grounded exercise before optional comparison',
      (tester) async {
    await enable(tester);
    final service = _Comparisons();
    const a = QuoteReference(
        id: 'wj-short', author: '威廉·詹姆斯', content: '我的经验就是我同意去注意的东西。');
    const b = QuoteReference(
        id: 'wj-long',
        author: '威廉·詹姆斯',
        content:
            '“我的经验，就是我同意去注意的东西。只有那些我留意到的事物才塑造我的心灵。”（原文：“My experience is what I agree to attend to.”）');
    await mount(tester, const Scaffold(body: SizedBox()),
        width: 390, height: 800);
    final ctx = tester.element(find.byType(Scaffold));
    showQuoteComparison(ctx, a, b, service: service);
    await waitFor(tester, find.text('疑似同段引文'));
    final diagram = find.byKey(const ValueKey('quote-set-diagram'));
    expect(diagram.hitTestable(), findsOneWidget);
    expect(service.requests, isEmpty);
    await tester.tapAt(tester.getCenter(diagram));
    await tester.pumpAndSettle();
    expect(find.textContaining('杯沿的小缺口'), findsOneWidget);
    await capture(tester, 'real-james-comparison');
    await tester.tap(find.text('B 句中概念'));
    await tester.pumpAndSettle();
    expect(find.textContaining('可察觉的细节'), findsWidgets);
    expect(service.requests, isEmpty);
  });

  testWidgets(
      'an unrelated saved concept with no pair still opens as a single scope',
      (tester) async {
    await enable(tester);
    const ref = QuoteReference(
        id: 'anonymous-review',
        content: '不知道稿件作者身份的评审仍可依照相同标准评分。',
        author: '案例');
    await tester.runAsync(() => QuoteInsightStore().saveAddon(
        ref,
        const QuoteAnalysisAddon(cognition: {
          'abstractions': [
            {
              'term': '匿名评审',
              'definition': '评审时作者身份对评审人隐藏',
              'observed': '案例中的稿件评分',
              'retained': '作者身份隐藏',
              'omitted': '稿件主题',
              'member_example': '隐去署名后独立评阅稿件',
              'non_member': '评审人知晓作者身份后打分',
              'counter_example': '没有公开分数不足以判断是否匿名'
            }
          ]
        })));
    await mount(
        tester,
        const Scaffold(
            body: QuoteCognitiveReader(
                quote: ref, topic: '评审', authorLabel: '案例', note: '')));
    await waitFor(tester, find.text('概念含义圈 · 单一范围'));
    expect(find.text('隐去署名后独立评阅稿件'), findsOneWidget);
    await tester.tap(find.text('圈外 · 边界检验'));
    await tester.pumpAndSettle();
    expect(find.text('评审人知晓作者身份后打分'), findsOneWidget);
  });

  testWidgets(
      'mountain passage opens its overlapping scopes through the home poster',
      (tester) async {
    await enable(tester);
    const ref = QuoteReference(
        id: 'mountain-prototype',
        author: 'Tal Ben-Shahar',
        content: '幸福并非抵达山顶，也不是漫无目的地在山间攀爬。幸福是朝着山顶攀登的体验。');
    await mount(
        tester,
        Scaffold(
            body: PosterPureFlutter(
                topic: '幸福与攀登',
                quote: ref.content,
                author: ref.author,
                avatar: '',
                note: '',
                quoteReference: ref)),
        width: 390,
        height: 800);
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await waitFor(tester, find.text('概念含义圈 · 部分交集'));
    final diagram = find.byKey(const ValueKey('quote-set-diagram'));
    expect(diagram.hitTestable(), findsOneWidget);
    await tester.tapAt(tester.getCenter(diagram));
    await tester.pumpAndSettle();
    expect(find.textContaining('眼前的云海'), findsOneWidget);
    await capture(tester, 'real-mountain-intersection');
  });

  testWidgets(
      'Hegel opens from the poster with sibling concepts and a visible temporal illustration',
      (tester) async {
    await enable(tester);
    const ref = QuoteReference(
        id: 'hegel-botany',
        author: '黑格尔',
        source: '《精神现象学》序言，版本和页码待核对。',
        content:
            '“花蕾在花朵绽放时消逝。人们可以说，花朵否定了花蕾。果实出现时，花朵又显得是植物存在的一种不充分形式。果实取代花朵，成为植物的真理。”（据原意翻译）');
    await mount(
        tester,
        Scaffold(
            body: PosterPureFlutter(
                topic: '发展中的否定、连续与转化',
                quote: ref.content,
                author: '黑格尔 《很长的出处说明》',
                avatar: '',
                note: '',
                quoteReference: ref)),
        width: 390,
        height: 800);
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await waitFor(tester, find.text('概念含义圈 · 同属上位范围但未穷尽'));
    await capture(tester, 'real-hegel-reading');
    expect(find.byKey(const ValueKey('quote-set-diagram')).hitTestable(),
        findsOneWidget);
    final diagram = find.byKey(const ValueKey('quote-set-diagram'));
    await tester.tapAt(tester.getCenter(diagram) + const Offset(0, -35));
    await tester.pumpAndSettle();
    expect(find.textContaining('再过数周'), findsOneWidget);
    await tester.ensureVisible(find.text('形态随时间变化 · 植物示意'));
    await tester.pumpAndSettle();
    await capture(tester, 'real-hegel-stages');
  });

  testWidgets(
      'record extensions are computed from loaded members and link back to records',
      (tester) async {
    await enable(tester);
    final rows = [
      {'quote_uid': 'scope1', 'content': '我同意去注意的东西进入经验', 'theme': '注意力与经验'},
      {'quote_uid': 'scope2', 'content': '注意会受到干扰', 'theme': '注意力'},
      {'quote_uid': 'scope3', 'content': '另一次观察', 'theme': '经验'},
    ];
    await mount(tester, HistoryPage(dao: _ScopeHistoryDao(rows)),
        width: 390, height: 800);
    await waitFor(tester, find.text('关系图'));
    await tester.tap(find.text('关系图'));
    await waitFor(tester, find.text('概念含义圈 · 部分交集'));
    final diagram = find.byKey(const ValueKey('quote-set-diagram'));
    await tester.tapAt(tester.getCenter(diagram));
    await tester.pumpAndSettle();
    expect(find.text('共同 区域的成员 · 1 条'), findsOneWidget);
    final member = find.text('我同意去注意的东西进入经验').first;
    await tester.timedDrag(
        diagram, const Offset(0, -150), const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(member.hitTestable(), findsOneWidget);
    await capture(tester, 'real-history-extension');
    await tester.tap(member);
    await waitFor(tester, find.byKey(const ValueKey('quote-full-reading')));
    expect(find.text('我同意去注意的东西进入经验'), findsWidgets);
  });

  testWidgets(
      'comparison goals request a distinct analysis and legacy mode restores all sections',
      (tester) async {
    await enable(tester);
    final service = _Comparisons();
    await mount(
        tester,
        Scaffold(
            body: QuoteComparisonSheet(
                a: quote,
                b: const QuoteReference(id: 'other', content: '目标需要审视，行动需要检验。'),
                service: service)));
    await waitFor(tester, find.text('判断目的'));
    await tester.tap(find.text('选择行动'));
    await tester.pumpAndSettle();
    expect(service.requests.last.$1, ComparisonPurpose.action);
    await tester.tap(find.text('改变情境或条件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '面对不可逆操作');
    await tester.ensureVisible(find.text('按此情境重新比较'));
    await tester.tap(find.text('按此情境重新比较'));
    await tester.pumpAndSettle();
    expect(service.requests.last.$2, '面对不可逆操作');
    await tester.runAsync(() => CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true, reduceMotion: true)));
    await tester.pumpAndSettle();
    for (final tile
        in tester.widgetList<ExpansionTile>(find.byType(ExpansionTile))) {
      expect(tile.expansionAnimationStyle?.duration, Duration.zero);
    }
    await capture(tester, '04-comparison-purpose');
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.text('判断目的'), findsNothing);
    expect(find.text('不能直接等同的部分'), findsOneWidget);
  });

  testWidgets(
      'training changes decisive conditions without scoring a person; narrow text remains usable',
      (tester) async {
    await enable(tester);
    await mount(
        tester,
        const Scaffold(
            body: SingleChildScrollView(child: CognitiveTrainingPanel())),
        width: 320,
        scale: 1.8);
    expect(find.text('识别共同点'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true, prompts: false)));
    await tester.pumpAndSettle();
    expect(find.text('识别共同点'), findsNothing);
    expect(find.text('选取记录，回顾认识的变化'), findsOneWidget);
    await mount(tester, JudgmentExercisePage(exercise: judgmentExercises[1]));
    await tester.tap(find.text('用时短，暂选甲路'));
    await tester.pumpAndSettle();
    expect(find.textContaining('与当前条件相符'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('坡度与身体条件，暂选乙路'));
    await tester.pumpAndSettle();
    expect(find.textContaining('与当前条件相符'), findsOneWidget);
    await capture(tester, '09-training-conditions');
  });

  testWidgets('structured movie data stays readable in both modes',
      (tester) async {
    const movie = MovieCognition(
        narrative: '保留的完整电影解读',
        overview: '主人公独自攀登。',
        boundary: '简介省略了人物背景',
        scenes: [],
        analogies: [
          CognitiveExample(
              situation: '每天练习写作', connection: '持续行动', boundary: '目标不同')
        ],
        concepts: [
          '坚持'
        ],
        characters: [
          '人物动机仍待核对'
        ]);
    await enable(tester);
    await mount(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: MovieCognitionView(text: movie.encode()))));
    await tester.tap(find.text('现实关联'));
    await tester.pumpAndSettle();
    expect(find.text('模拟情境 · 非影片事实'), findsOneWidget);
    await capture(tester, '07-movie-analogy');
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.text('情节'), findsNothing);
    expect(find.text('保留的完整电影解读'), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).style,
        const TextStyle(fontSize: 14, height: 1.55));
    await enable(tester);
    await tester.pumpAndSettle();
    expect(find.text('情节'), findsOneWidget);
  });

  testWidgets(
      'concept tree links parent child examples and comparison without generating on browse',
      (tester) async {
    await enable(tester);
    await tester.runAsync(() async {
      await VisionDao().listThoughtRootNodes();
      for (final row in [
        {'uid': 'test-general', 'title': '幸福', 'parent_uid': null},
        {
          'uid': 'test-specific',
          'title': '过程中的幸福',
          'parent_uid': 'test-general'
        },
      ]) {
        await db.insert(
            'vision_node',
            {
              'taxonomy_id': kThoughtTaxonomyId,
              'slug': row['uid'],
              'node_kind': 'concept',
              ...row
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final note = CognitiveNote(
          id: 'concept-example',
          task: CognitiveTask.concept,
          selection: CognitiveSelection.fromText(
              module: 'concept',
              recordId: 'test-specific',
              title: '过程中的幸福',
              fullText: '过程中的幸福'),
          analysis: const CognitiveAnalysis(
              summary: '在活动过程中体验到的满足。',
              boundary: '过程不总是愉快，目标和身体条件也会影响体验。',
              counterExample: '重复一项不认同的活动未必带来满足。',
              examples: [
                CognitiveExample(
                    situation: '练习绘画时享受观察与尝试。',
                    connection: '满足发生在过程之中。',
                    boundary: '不保证最终结果符合预期。')
              ]),
          modelInfo: 'fixture',
          createdAt: '2026-10-30T00:00:00Z');
      await CognitiveStore().save(note);
    });
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await mount(
        tester,
        const Scaffold(
            body: Column(children: [
          ThoughtTaxonomyMindMap(
              selectedUids: ['test-general', 'test-specific']),
          CognitiveSelectableText(
              text: '这一次的体验需要核查适用范围。',
              module: 'thought',
              recordId: 'mode-transition',
              title: '念头'),
        ])));
    await waitFor(tester, find.text('过程中的幸福'));
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.text('过程中的幸福'));
    await tester.pumpAndSettle();
    expect(find.byType(ConceptExplorer), findsNothing);
    await enable(tester);
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(SelectableText, '这一次的体验需要核查适用范围。'), findsOneWidget);
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.text('过程中的幸福'));
    await tester.pumpAndSettle();
    expect(find.byType(ConceptExplorer), findsNothing);
    await enable(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('过程中的幸福'));
    await waitFor(tester, find.text('具体表现 · 模拟示例'));
    expect(find.text('返回上位概念：幸福'), findsOneWidget);
    await capture(tester, '06-concept-examples');
    await tester.tap(find.text('返回上位概念：幸福'));
    await waitFor(tester, find.widgetWithText(ListTile, '过程中的幸福'));
    await tester.tap(find.text('含义关系'));
    await tester.pumpAndSettle();
    expect(find.text('从当前分支选择两个概念'), findsOneWidget);
    await tester.tap(find.text('从当前分支选择两个概念'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '比较所选概念'))
            .onPressed,
        isNull);
  });

  testWidgets(
      'concept title resolves hierarchy and asks before merging homonyms',
      (tester) async {
    await enable(tester);
    await tester.runAsync(() async {
      await VisionDao().listThoughtRootNodes();
      for (final node in [
        {'uid': 'audit-parent', 'title': '上位概念_完整性', 'parent_uid': null},
        {
          'uid': 'audit-unique',
          'title': '特定体验_完整性',
          'parent_uid': 'audit-parent'
        },
        {
          'uid': 'audit-leaf',
          'title': '具体特征_完整性',
          'parent_uid': 'audit-unique'
        },
        {
          'uid': 'audit-poly-a',
          'title': '多义_完整性',
          'parent_uid': 'audit-parent'
        },
        {'uid': 'audit-poly-b', 'title': '多义_完整性', 'parent_uid': 'audit-leaf'},
      ]) {
        await db.insert(
            'vision_node',
            {
              'taxonomy_id': kThoughtTaxonomyId,
              'slug': node['uid'],
              'node_kind': 'concept',
              ...node,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await mount(tester, const ConceptExplorer(title: '特定体验_完整性'));
    await waitFor(tester, find.text('具体特征_完整性'));
    expect(find.text('返回上位概念：上位概念_完整性'), findsOneWidget);
    await capture(tester, '06-concept-resolved-hierarchy');
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.text('叔本华认知风格已关闭'), findsOneWidget);
    expect(find.text('具体特征_完整性'), findsNothing);
    await enable(tester);
    await tester.pumpAndSettle();
    expect(find.text('具体特征_完整性'), findsOneWidget);
    await mount(tester, const SizedBox());
    await mount(tester, const ConceptExplorer(title: '多义_完整性'));
    await waitFor(tester, find.textContaining('发现多个同名分类'));
    expect(find.textContaining('audit-poly-'), findsNothing);
    await tester.tap(
        find.widgetWithText(ListTile, '上位分类：上位概念_完整性 → 特定体验_完整性 → 具体特征_完整性'));
    await waitFor(tester, find.text('返回上位概念：具体特征_完整性'));
  });

  testWidgets(
      'tagged related quotes load beyond the first page and open the reader',
      (tester) async {
    await enable(tester);
    final rows = List.generate(
        31,
        (i) => <String, dynamic>{
              'quote_uid': 'catalog-audit-$i',
              'content': '目录名言$i',
              'author_name': '测试示例',
            });
    await tester.runAsync(() async {
      for (final row in rows) {
        await QuoteInsightStore().saveAddon(QuoteReference.fromRow(row),
            const QuoteAnalysisAddon(concepts: ['目录_完整性']));
      }
    });
    final catalog = QuoteConceptCatalog(
        readPage: (limit, offset) async =>
            rows.skip(offset).take(limit).toList());
    await mount(tester, ConceptExplorer(title: '目录_完整性', catalog: catalog));
    await waitFor(tester, find.text('从具体经验中辨认共同规定，同时保留差异。'));
    await tester.tap(find.text('相关名言'));
    await waitFor(tester, find.text('目录名言0'));
    await tester.scrollUntilVisible(find.text('继续加载相关名言'), 450);
    await tester.tap(find.text('继续加载相关名言'));
    await waitFor(tester, find.text('目录名言30'));
    await tester.ensureVisible(find.text('目录名言30'));
    await tester.tap(find.text('目录名言30'));
    await waitFor(tester, find.text('直观'));
    expect(find.text('判断'), findsOneWidget);
  });

  testWidgets(
      'every loaded history concept remains accessible after the first 24',
      (tester) async {
    await enable(tester);
    final rows = List.generate(
        30,
        (i) => <String, dynamic>{
              'quote_uid': 'graph-audit-$i',
              'content': '星图名言$i',
              'theme': '编号${i.toString().padLeft(2, '0')}',
            });
    var opens = 0;
    await mount(
        tester,
        Scaffold(
            body: HistoryKnowledgeView(
                rows: rows,
                mode: 1,
                onOpen: (_) => opens++,
                onSelect: (_) {},
                selectedKeys: const {},
                onLoadMore: () {},
                hasMore: false,
                loading: false)));
    await waitFor(tester, find.text('概念星图'));
    await tester.tap(find.text('概念星图'));
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('编号00 1'));
    expect(find.text('编号29 1'), findsNothing);
    await tester.tap(find.byTooltip('下一组概念'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编号29 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('星图名言29'), 350,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('星图名言29'));
    expect(opens, 1);
    await tester
        .ensureVisible(find.byKey(const ValueKey('history-concept-search')));
    await tester.enterText(
        find.byKey(const ValueKey('history-concept-search')), '编号29');
    await tester.pumpAndSettle();
    expect(find.text('编号29 1'), findsOneWidget);
    expect(find.text('编号24 1'), findsNothing);
    await capture(tester, '03-history-search-all-concepts');
    await tester.enterText(
        find.byKey(const ValueKey('history-concept-search')), '不存在的概念');
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无匹配概念'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'analysis, recap and training routes observe mode off without generating',
      (tester) async {
    final ai = core.FakeCognitiveAi();
    final service = CognitiveService(ai: ai);
    await mount(
        tester,
        Scaffold(
            body: CognitiveAnalysisSheet(
                selection: CognitiveSelection.fromText(
                    module: 'diary',
                    recordId: 'disabled-audit',
                    title: '日记',
                    fullText: core.text),
                task: CognitiveTask.diary,
                service: service)));
    expect(find.text('叔本华认知风格已关闭'), findsOneWidget);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    expect(ai.calls, 0);
    await enable(tester);
    await waitFor(tester, find.text('采纳这条注释'));
    expect(ai.calls, 1);
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.text('采纳这条注释'), findsNothing);
    expect(find.text(core.text), findsOneWidget);
    await enable(tester);
    await tester.pumpAndSettle();
    expect(ai.calls, 1);
    await mount(
        tester, JudgmentExercisePage(exercise: judgmentExercises.first));
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.text('改变条件，再作判断'), findsNothing);
    expect(find.text('叔本华认知风格已关闭'), findsOneWidget);
    await mount(tester, CognitiveRecapPage(service: service));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(ai.calls, 1);
    await enable(tester);
    await waitFor(tester, find.textContaining('这是保存时的选文与判断快照'));
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('叔本华认知风格已关闭'), findsOneWidget);
  });

  testWidgets(
      'thought composer checks scope locally and keeps the original save result',
      (tester) async {
    await enable(tester);
    await tester.runAsync(() => db.delete('app_kv',
        where: 'key IN (?,?)',
        whereArgs: [CognitiveHintBudget.key, CognitiveHintBudget.legacyKey]));
    ThoughtRecordResult? saved;
    await mount(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      saved = await showDialog<ThoughtRecordResult>(
                          context: context,
                          builder: (_) => const ThoughtRecordDialog());
                    },
                    child: const Text('记录念头')))),
        width: 320,
        height: 700,
        scale: 1.8);
    await tester.tap(find.text('记录念头'));
    await waitFor(tester, find.byType(TextField));
    const original = '保留前文。以后永远找不到工作。保留结尾。';
    await tester.enterText(find.byType(TextField).first, original);
    await tester.pump(const Duration(milliseconds: 750));
    await waitFor(tester, find.text('看看这句话的适用范围'));
    final notesBefore = await tester.runAsync(() => db
        .query('app_kv', where: 'key GLOB ?', whereArgs: ['cognition.note.*']));
    await tester.tap(find.text('看看这句话的适用范围'));
    await tester.pumpAndSettle();
    expect(find.text('以后永远找不到工作。'), findsOneWidget);
    expect(find.textContaining('可能反例：是否有过一次不同的结果'), findsOneWidget);
    await capture(tester, '11-discovery-local-scope');
    await tester.runAsync(() =>
        CognitivePreferenceStore.instance.update(const CognitivePreferences()));
    await tester.pumpAndSettle();
    expect(find.text('叔本华认知风格已关闭'), findsOneWidget);
    Navigator.of(tester.element(find.text('叔本华认知风格已关闭'))).pop();
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        original);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved!.thought, original);
    final notesAfter = await tester.runAsync(() => db
        .query('app_kv', where: 'key GLOB ?', whereArgs: ['cognition.note.*']));
    expect(notesAfter!.length, notesBefore!.length);
  });

  testWidgets(
      'grounding expands exact material and respects reduced motion and source boundaries',
      (tester) async {
    await tester.runAsync(() => CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true, reduceMotion: true)));
    const original = '今天没有参加面试。原因还不能确定。';
    final selection = CognitiveSelection.fromText(
        module: 'diary',
        recordId: 'ground-ui',
        title: '日记',
        fullText: original);
    final note = CognitiveNote(
        id: 'ground-ui',
        task: CognitiveTask.calibration,
        selection: selection,
        analysis: const CognitiveAnalysis(
            summary: '一次经历不足以判断以后',
            boundary: '长期结果仍未知',
            basis: '仅能定位这次经历',
            evidence: [
              CognitiveEvidence(start: 0, end: 9, excerpt: '今天没有参加面试。')
            ]),
        modelInfo: 'fixture',
        createdAt: '2026-11-01T00:00:00Z');
    final ai = core.FakeCognitiveAi();
    await mount(
        tester,
        Scaffold(
            body: CognitiveAnalysisSheet(
                selection: selection,
                task: note.task,
                initialNote: note,
                service: CognitiveService(ai: ai))),
        width: 320,
        scale: 1.8);
    expect(find.text('仅能定位这次经历'), findsNothing);
    await tester.scrollUntilVisible(find.text('判断依据'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('判断依据'));
    await tester.pumpAndSettle();
    expect(find.text('仅能定位这次经历'), findsOneWidget);
    expect(find.text('原文对应 · 尚未外部核实'), findsOneWidget);
    final tile = tester.widget<ExpansionTile>(
        find.byKey(const ValueKey('cognitive-evidence')));
    expect(tile.expansionAnimationStyle!.duration, Duration.zero);
    expect(ai.calls, 0);
    await capture(tester, '12-selected-grounding');
    await tester.runAsync(() => CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true, grounds: false)));
    await tester.pumpAndSettle();
    expect(find.text('判断依据'), findsNothing);
  });

  testWidgets(
      'existing-record card links a new business judgment and supports rollback without a solver call',
      (tester) async {
    await enable(tester);
    Widget card(String observation, String judgment, {String evidence = ''}) =>
        Scaffold(
            body: SingleChildScrollView(
                child: CognitiveReflectionCard(
                    module: 'record-ui',
                    recordId: 'one-business-record',
                    observation: observation,
                    judgment: judgment,
                    basis: '当前记录中的材料',
                    newEvidence: evidence)));
    await mount(tester, card('第一次没有完成。', '当前方法可能不合适。'));
    await tester.tap(find.text('保存本次理解与修订笔记'));
    await waitFor(tester, find.text('记录中的暂定理解 · 可修改或拒绝'));
    await tester.tap(find.byTooltip('关闭分析'));
    await tester.pumpAndSettle();
    await mount(
        tester, card('第二次调整方法后完成。', '调整方法后可以改善结果。', evidence: '第二次调整方法后完成。'));
    await tester.tap(find.text('保存本次理解与修订笔记'));
    await waitFor(tester, find.text('把当前判断接入修订记录'));
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '第二次调整方法后完成。');
    await tester.tap(find.text('保存这次改判'));
    await waitFor(tester, find.text('记录中的暂定理解 · 可修改或拒绝'));
    var notes = await tester.runAsync(
        () => CognitiveStore().forRecord('record-ui', 'one-business-record'));
    expect(notes, hasLength(1));
    expect(notes!.single.selection.text, '第一次没有完成。');
    expect(notes.single.revisions.single.previous, '当前方法可能不合适。');
    expect(notes.single.currentJudgment, '调整方法后可以改善结果。');
    await tester.scrollUntilVisible(find.text('回退到此前判断'), 300,
        scrollable: find
            .descendant(
                of: find.byType(CognitiveAnalysisSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('回退到此前判断'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    notes = await tester.runAsync(
        () => CognitiveStore().forRecord('record-ui', 'one-business-record'));
    expect(notes!.single.revisions.length, 2);
    expect(notes.single.currentJudgment, '当前方法可能不合适。');
  });

  testWidgets(
      'usage settings are voluntary and expose only clearable local counts',
      (tester) async {
    await enable(tester);
    await tester.runAsync(() => CognitiveUsageStore.instance.clear());
    await mount(
        tester,
        const Scaffold(
            body: SingleChildScrollView(child: CognitiveSettingsSection())),
        width: 320,
        scale: 1.8);
    const title = '匿名使用记录（仅此设备）';
    await tester.scrollUntilVisible(find.text(title), 350);
    expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
            .value,
        isFalse);
    await tester.tap(find.text(title));
    for (var i = 0;
        i < 100 && !CognitivePreferenceStore.instance.value.usageEnabled;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(CognitivePreferenceStore.instance.value.usageEnabled, isTrue);
    await tester.runAsync(() async {
      await CognitiveUsageStore.instance.record(CognitiveEvent.basisOpened);
      await CognitiveUsageStore.instance.record(CognitiveEvent.accepted);
    });
    await tester.scrollUntilVisible(find.text('查看 / 清除本地匿名计数'), 300);
    await tester.tap(find.text('查看 / 清除本地匿名计数'));
    await waitFor(tester, find.text('展开判断依据：1'));
    expect(find.text('采纳建议：1'), findsOneWidget);
    await capture(tester, '13-opt-in-local-counts');
    await tester.tap(find.text('清除本地计数'));
    await waitFor(tester, find.text('暂无记录。可在设置中自愿启用。'));
    expect(await tester.runAsync(() => CognitiveUsageStore.instance.read()),
        isEmpty);
  });

  testWidgets(
      'cached visual clauses remain optional and motion can be disabled',
      (tester) async {
    await tester.runAsync(() => CognitivePreferenceStore.instance
        .update(const CognitivePreferences(enabled: true, reduceMotion: true)));
    final script = QuoteVisualScript.fromJson({
      'meaning': '根据材料调整行动方式',
      'metaphor': '岔路与行走作为视觉类比',
      'scene': '一位行者在山间岔路停步观察，再沿安全的山路继续前进，远处保留柔和的光线。',
      'relationship': '路线变化对应方法调整，山峰只表示一种方向。',
      'limitations': '不能说明任何改变都是正确的，也不能证明因果。',
      'clause_mappings': [
        {'quote_segment': '调整方法', 'visible_relation': '行者根据路况选择另一条道路'}
      ],
    }, originalQuote: '面对新材料，调整方法。');
    await mount(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: QuoteVisualExplanation(
                    topic: '行动', quote: '面对新材料，调整方法。', script: script))),
        width: 320,
        scale: 1.8);
    expect(find.textContaining('路线变化对应方法调整'), findsNothing);
    await tester.tap(find.text('画面如何对应原句'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不能证明因果'), findsOneWidget);
    await tester.tap(find.textContaining('“调整方法”'));
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.selected == true),
        findsOneWidget);
    for (final container in tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))) {
      expect(container.duration, Duration.zero);
    }
    await capture(tester, '14-cached-visual-correspondence');
  });

  testWidgets(
      'recap requires selection, previews provenance and blocks oversized material before AI',
      (tester) async {
    await enable(tester);
    CognitiveNote item(String id, String title, String value) => CognitiveNote(
        id: id,
        task: CognitiveTask.reflection,
        accepted: true,
        selection: CognitiveSelection.fromText(
            module: 'diary', recordId: id, title: title, fullText: value),
        analysis: const CognitiveAnalysis(
            summary: '最初判断', basis: '所选记录', boundary: '仍需检验'),
        modelInfo: 'fixture',
        createdAt: '2026-11-01T00:00:00Z');
    await tester.runAsync(() async {
      await db.delete('app_kv',
          where: 'key GLOB ?', whereArgs: ['cognition.note.*']);
      await CognitiveStore().save(item('recap-other', '另一条经历-R', '未选中的私密资料-R'));
      await CognitiveStore().save(item('recap-picked', '选择经历-R', '主动选择的经历-R'));
    });
    final ai = core.FakeCognitiveAi();
    await mount(tester, CognitiveRecapPage(service: CognitiveService(ai: ai)));
    await waitFor(tester, find.text('选择经历-R · 日记'));
    for (final box
        in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
      expect(box.value, isFalse);
    }
    await tester.scrollUntilVisible(find.text('仅分析所选 0 条记录'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('仅分析所选 0 条记录'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
    await tester.scrollUntilVisible(find.text('选择经历-R · 日记'), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('选择经历-R · 日记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看将发送的完整内容').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('将发送的定位与依据'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('将发送的定位与依据'));
    await tester.pumpAndSettle();
    expect(find.textContaining('记录定位：diary / recap-picked'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('仅分析所选 1 条记录'), 350,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('仅分析所选 1 条记录'));
    await waitFor(tester, find.text('认识回顾'));
    expect(ai.calls, 1);
    expect(ai.lastPrompt, contains('主动选择的经历-R'));
    expect(ai.lastPrompt, isNot(contains('未选中的私密资料-R')));
    await tester.tap(find.byTooltip('关闭分析'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => CognitiveStore()
        .save(item('recap-long', '超长快照-R', List.filled(13000, '字').join())));
    await tester.tap(find.byTooltip('刷新可选记录'));
    await waitFor(tester, find.text('选取记录，回顾认识的变化'));
    await tester.scrollUntilVisible(find.text('超长快照-R · 日记'), -300,
        scrollable: find.byType(Scrollable).first);
    await waitFor(tester, find.text('超长快照-R · 日记'));
    await tester.tap(find.text('超长快照-R · 日记'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请减少条数或改选较短注释'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('仅分析所选 1 条记录'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<FilledButton>(find
                .ancestor(
                    of: find.text('仅分析所选 1 条记录'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first)
            .onPressed,
        isNull);
    expect(ai.calls, 1);
  });

  testWidgets('scope input remains usable with keyboard and double-size text',
      (tester) async {
    await enable(tester);
    await tester.runAsync(() => db.delete('app_kv',
        where: 'key IN (?,?)',
        whereArgs: [CognitiveHintBudget.key, CognitiveHintBudget.legacyKey]));
    await mount(tester, const ThoughtRecordDialog(initialText: '我永远都会失败。'),
        width: 320,
        height: 700,
        scale: 2,
        viewInsets: const EdgeInsets.only(bottom: 320));
    await tester.pump(const Duration(milliseconds: 750));
    await waitFor(tester, find.text('看看这句话的适用范围'));
    expect(tester.takeException(), isNull);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '我永远都会失败。');
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets(
      'gentle challenge is dismissible and appears at most once per local day',
      (tester) async {
    await tester.runAsync(() => db.delete('app_kv',
        where: 'key IN (?,?)',
        whereArgs: [CognitiveHintBudget.key, CognitiveHintBudget.legacyKey]));
    await mount(
        tester,
        const Scaffold(
            body:
                GentleCounterexample(recordId: 'message-1', text: '我每次都做不好。')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.text('是否也存在一次例外？'), findsNothing);
    await enable(tester);
    await waitFor(tester, find.text('是否也存在一次例外？'));
    await tester.tap(find.byTooltip('今天不再提示'));
    await tester.pumpAndSettle();
    expect(find.text('是否也存在一次例外？'), findsNothing);
    await mount(
        tester,
        const Scaffold(
            body: GentleCounterexample(
                key: ValueKey('next-message'),
                recordId: 'message-2',
                text: '我总是如此。')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    expect(find.text('是否也存在一次例外？'), findsNothing);
  });

  testWidgets(
      'judgment revision keeps evidence and prior judgment; stale anchors prevent acceptance',
      (tester) async {
    await enable(tester);
    final selection = CognitiveSelection.fromText(
        module: 'reflection-test',
        recordId: 'revision',
        title: '认识闭环',
        fullText: '本次尝试没有完成。');
    final note = CognitiveNote(
        id: 'revision',
        task: CognitiveTask.reflection,
        selection: selection,
        analysis: const CognitiveAnalysis(
            summary: '这次没有完成，所以以后都不会完成。',
            concepts: ['范围', '判断'],
            basis: '本次尝试的记录',
            boundary: '一次记录不足以判断所有情境',
            questions: ['换一种方法是否可能有不同结果？']),
        modelInfo: 'manual-test',
        createdAt: '2026-10-30T00:00:00Z');
    await tester.runAsync(() => CognitiveStore().save(note));
    await mount(
        tester,
        Scaffold(
            body: CognitiveAnalysisSheet(
                selection: selection,
                task: note.task,
                initialNote: note,
                currentText: () => selection.text)));
    await capture(tester, '08-cognitive-loop');
    await tester.scrollUntilVisible(find.text('新证据与修订'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('新证据与修订'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '具体的新材料或反例'), '调整方法后完成了下一次尝试。');
    await tester.enterText(
        find.widgetWithText(TextField, '修订后的判断'), '一次失败不能决定以后的每次尝试。');
    await tester.tap(find.text('保存修订'));
    await waitFor(tester, find.text('判断修订记录'));
    expect(tester.takeException(), isNull);
    var saved = (await tester.runAsync(
            () => CognitiveStore().forRecord('reflection-test', 'revision')))!
        .single;
    expect(saved.revisions.single.previous, note.analysis.summary);
    expect(saved.revisions.single.evidence, '调整方法后完成了下一次尝试。');
    await tester.ensureVisible(find.text('回退到此前判断'));
    await tester.tap(find.text('回退到此前判断'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    saved = (await tester.runAsync(
            () => CognitiveStore().forRecord('reflection-test', 'revision')))!
        .single;
    expect(saved.currentJudgment, note.analysis.summary);
    expect(saved.revisions.length, 2);
    await mount(
        tester,
        Scaffold(
            body: CognitiveAnalysisSheet(
                key: const ValueKey('stale'),
                selection: selection,
                task: note.task,
                initialNote: saved,
                currentText: () => '原文已编辑。')));
    expect(find.textContaining('位置已失效'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('采纳这条注释'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '采纳这条注释'))
            .onPressed,
        isNull);
  });
}
