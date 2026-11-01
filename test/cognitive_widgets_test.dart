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
import 'package:quote_app/epistemic/gentle_counterexample.dart';
import 'package:quote_app/models/quote_insight.dart';
import 'package:quote_app/services/quote_comparison_service.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_comparison_sheet.dart';
import 'package:quote_app/widgets/thought_taxonomy_mindmap.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'cognitive_core_test.dart' as core;

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
      {double width = 430, double scale = 1}) async {
    await tester.binding.setSurfaceSize(Size(width, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('cognitive-preview'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'PreviewCJK'),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
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
      'gentle challenge is dismissible and appears at most once per local day',
      (tester) async {
    await enable(tester);
    await tester.runAsync(() => db.delete('app_kv',
        where: 'key=?', whereArgs: ['cognition.gentle.last_day']));
    await mount(
        tester,
        const Scaffold(
            body:
                GentleCounterexample(recordId: 'message-1', text: '我每次都做不好。')));
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
