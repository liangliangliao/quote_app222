import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/pages/home_page.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/services/quote_library_store.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_home_scene.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'widget_test.dart' show prpIo;

class _OwnQuotes extends NoopPrpPlugin {
  bool on = true;
  int calls = 0;
  static const text = '如果准备阅读时打开短视频，我就关掉手机读1页';
  @override
  bool enabledFor(PrpSurface surface) => on && surface == PrpSurface.quoteHome;
  @override
  bool get quoteStreamEnabled => on;
  @override
  Future<List<PrpQuote>> quotesForStream() async => on && calls++ == 0
      ? const [PrpQuote(lessonId: 7, text: text, author: '我')]
      : const [];
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    docs = await Directory.systemTemp.createTemp('prp_quote_home_');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('native.scheduler'), (_) async => null);
    await AppDatabase.instance();
  });
  tearDownAll(() async {
    await (await AppDatabase.instance()).close();
    await docs.delete(recursive: true);
  });

  testWidgets(
      'personal quote is ephemeral, cannot pollute favorites, and disappears with valid history on disable',
      (tester) async {
    final plugin = _OwnQuotes();
    PrpPlugin.instance = plugin;
    addTearDown(() {
      PrpPlugin.instance = const NoopPrpPlugin();
    });
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    Future<void> until(bool Function() ready) async {
      for (var i = 0; i < 160 && !ready(); i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 32));
      }
      expect(ready(), true);
    }

    String quote() =>
        tester.widget<PosterPureFlutter>(find.byType(PosterPureFlutter)).quote;
    await until(() =>
        find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
        quote() != '名言加载中…');
    final original = quote();
    await tester.tap(find.byKey(const ValueKey('home-next')));
    await until(() => quote() == _OwnQuotes.text);
    expect(find.text('己言\n已盖印'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-favorite')));
    await tester.pump(const Duration(milliseconds: 100));
    final favorites =
        await prpIo(tester, () => QuoteLibraryStore().favorites());
    expect(
        favorites.where((row) => row['content'] == _OwnQuotes.text), isEmpty);
    final db = await AppDatabase.instance();
    expect(
        await prpIo(
            tester,
            () => db.query('quotes',
                where: 'content = ?', whereArgs: [_OwnQuotes.text])),
        isEmpty);
    tester.widget<QuoteHomeScene>(find.byType(QuoteHomeScene)).onHistory(0);
    await until(() => quote() == original);
    expect(
        tester.widget<QuoteHomeScene>(find.byType(QuoteHomeScene)).historyIndex,
        0);
    tester.widget<QuoteHomeScene>(find.byType(QuoteHomeScene)).onHistory(1);
    await until(() => quote() == _OwnQuotes.text);
    expect(
        tester.widget<QuoteHomeScene>(find.byType(QuoteHomeScene)).historyCount,
        2);
    plugin.on = false;
    PrpPlugin.changed();
    await until(() => quote() == original);
    expect(find.text('己言\n已盖印'), findsNothing);
    final scene = tester.widget<QuoteHomeScene>(find.byType(QuoteHomeScene));
    expect(scene.historyIndex, lessThan(scene.historyCount));
    await tester.pumpWidget(const SizedBox());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });
}
