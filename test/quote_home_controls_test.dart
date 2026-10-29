import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/services/quote_library_store.dart';
import 'package:quote_app/pages/home_page.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_library_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;
  String copied = '';
  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('quote_home_controls_');
    databaseFactory = databaseFactoryFfiNoIsolate;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      (_) async => null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'].toString();
        return null;
      },
    );
    await AppDatabase.instance();
  });
  tearDownAll(() async {
    await (await AppDatabase.instance()).close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      null,
    );
    await docs.delete(recursive: true);
  });
  setUp(() {
    // Cached asset futures belong to the fake async zone that first read them.
    rootBundle.evict('assets/fallback/camus_fallback.json');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      (_) async => null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'].toString();
        return null;
      },
    );
  });

  Future<void> until(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 180 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
    }
    expect(ready(), isTrue, reason: 'the local reading action should finish');
    await tester.pumpAndSettle();
  }

  String displayed(WidgetTester tester) =>
      tester.widget<PosterPureFlutter>(find.byType(PosterPureFlutter)).quote;
  Finder action(String name) => find.byKey(ValueKey('home-$name'));

  test('library identity and signature survive home payload normalization', () {
    final payload = {
      'quote': '我们反抗，故我们存在。',
      'topic': '尊严',
      'author': '——加缪《反抗者》',
      'source': '反抗者',
    };
    final stored = QuoteLibraryStore.normalize(payload);
    expect(stored['author_name'], '加缪');
    expect(stored['source_from'], '反抗者');
    expect(
      QuoteLibraryStore.identity(stored),
      QuoteLibraryStore.identity(payload),
    );
  });

  testWidgets(
    'bundled quotations can be collected and shared before any task exists',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await until(
        tester,
        () =>
            find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
            displayed(tester) != '名言加载中…',
      );
      final quote = displayed(tester);
      await tester.tap(action('share'));
      await tester.pumpAndSettle();
      expect(copied, contains(quote));
      await tester.tap(action('favorite'));
      await until(tester, () => find.text('已收藏').evaluate().isNotEmpty);
      await tester.runAsync(() async {
        final collection = await QuoteLibraryStore().favorites();
        expect(collection.any((row) => row['content'] == quote), isTrue);
      });
      expect(action('pin'), findsNothing);
      await tester.runAsync(() async => expect(await TaskDao().all(), isEmpty));
      await tester.tap(action('favorite'));
      await until(tester, () => find.text('已收藏').evaluate().isEmpty);
      await tester.runAsync(
        () async => expect(await QuoteLibraryStore().favorites(), isEmpty),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('search and next quotation change the actual shared quotation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const first = '界面也能安静地成长。';
    const second = '给重要的事留一点时间。';
    await tester.runAsync(() async {
      final task = await TaskDao().create(
        name: '阅读',
        type: 'manual',
        status: 'off',
      );
      await QuoteDao().insertQuote(
        taskUid: task,
        content: first,
        authorName: 'Albert Camus',
        theme: '成长',
      );
      await QuoteDao().insertQuote(
        taskUid: task,
        content: second,
        authorName: 'Albert Camus',
        theme: '日常',
      );
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await until(
      tester,
      () =>
          find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
          displayed(tester) != '名言加载中…',
    );
    await tester.tap(action('search'));
    await tester.pump();
    await until(
      tester,
      () =>
          find
              .byKey(const ValueKey('quote-library-search'))
              .evaluate()
              .isNotEmpty &&
          find.text(first).evaluate().isNotEmpty,
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-library-search')),
      '界面也能',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await until(tester, () => find.text(second).evaluate().isEmpty);
    await tester.tap(find.text(first));
    await tester.pumpAndSettle();
    expect(displayed(tester), first);
    await tester.tap(action('share'));
    await tester.pumpAndSettle();
    expect(copied, contains(first));
    expect(copied, isNot(contains(second)));
    await tester.tap(action('next'));
    await until(tester, () => displayed(tester) == second);
    await tester.tap(action('share'));
    await tester.pumpAndSettle();
    expect(copied, contains(second));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the collection remains available in a new library instance', (
    tester,
  ) async {
    final payload = {'quote': '一条值得重读的名言', 'topic': '珍藏', 'author': '测试作者'};
    await tester.runAsync(() => QuoteLibraryStore().setFavorite(payload, true));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuoteLibrarySheet(favoritesOnly: true)),
      ),
    );
    await until(tester, () => find.text('一条值得重读的名言').evaluate().isNotEmpty);
    expect(find.text('测试作者 · 珍藏'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('more menu fits larger text and opens the saved collection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.25)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await until(
      tester,
      () =>
          find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
          displayed(tester) != '名言加载中…',
    );
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('固定的名言集'), findsNothing);
    expect(find.text('我收藏的名言'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('我收藏的名言'));
    await tester.pump();
    await until(
      tester,
      () => find.byType(QuoteLibrarySheet).evaluate().isNotEmpty,
    );
    expect(find.text('名言书房'), findsOneWidget);
    Navigator.of(tester.element(find.byType(QuoteLibrarySheet))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
