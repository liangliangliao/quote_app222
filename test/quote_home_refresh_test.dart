import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/pages/home_page.dart';
import 'package:quote_app/services/native_guard.dart';
import 'package:quote_app/services/quote_author_signature_service.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _DelayedSignature extends QuoteAuthorSignatureService {
  final answer = Completer<String?>();
  String? name;
  @override
  String? displayName(String author, {String originalName = ''}) =>
      author == '西蒙娜·韦伊'
      ? name
      : super.displayName(author, originalName: originalName);
  @override
  Future<String?> resolve(String author, {String originalName = ''}) async {
    if (author != '西蒙娜·韦伊')
      return super.resolve(author, originalName: originalName);
    return name ??= await answer.future;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;
  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('quote_home_refresh_');
    databaseFactory = databaseFactoryFfiNoIsolate;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      (_) async => null,
    );
    await AppDatabase.instance();
  });
  tearDownAll(() async {
    await (await AppDatabase.instance()).close();
    await docs.delete(recursive: true);
  });
  setUp(() async {
    rootBundle.evict('assets/fallback/camus_fallback.json');
    rootBundle.evict('AssetManifest.json');
    final db = await AppDatabase.instance();
    await db.delete('quotes');
    await db.delete('tasks');
  });

  testWidgets(
    'home keeps its poster on repeated refreshes and shows a newly notified quote',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      Future<void> advance() async {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
      }

      for (var i = 0; i < 100; i++) {
        await advance();
        if (find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
            tester
                    .widget<PosterPureFlutter>(find.byType(PosterPureFlutter))
                    .quote !=
                '名言加载中…')
          break;
      }
      final original = tester
          .widget<PosterPureFlutter>(find.byType(PosterPureFlutter))
          .quote;
      expect(original, isNot('名言加载中…'));
      SimpleBus.pokeHome();
      for (var i = 0; i < 40; i++) {
        await advance();
      }
      expect(
        tester.widget<PosterPureFlutter>(find.byType(PosterPureFlutter)).quote,
        original,
      );

      final taskUid = await TaskDao().create(
        name: '测试任务',
        type: 'manual',
        status: 'off',
      );
      final uid = await QuoteDao().insertQuote(
        taskUid: taskUid,
        content: '新的提醒值得被看见',
        authorName: '测试作者',
      );
      await QuoteDao().markNotifiedByUid(uid);
      SimpleBus.pokeHome();
      for (var i = 0; i < 100; i++) {
        await advance();
        if (tester
                .widget<PosterPureFlutter>(find.byType(PosterPureFlutter))
                .quote ==
            '新的提醒值得被看见')
          break;
      }
      expect(
        tester.widget<PosterPureFlutter>(find.byType(PosterPureFlutter)).quote,
        '新的提醒值得被看见',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'an asynchronous original signature keeps the quote excerpt and spacing still',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final text = List.filled(8, '专注使我们更清楚地看见眼前的世界，而不是急于给一切下结论。').join();
      await tester.runAsync(() async {
        final task = await TaskDao().create(
          name: '署名',
          type: 'manual',
          status: 'off',
        );
        final uid = await QuoteDao().insertQuote(
          taskUid: task,
          content: text,
          authorName: '西蒙娜·韦伊',
        );
        await QuoteDao().markNotifiedByUid(uid);
      });
      final signatures = _DelayedSignature();
      await tester.pumpWidget(
        MaterialApp(home: HomePage(signatures: signatures)),
      );
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        if (find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
            tester
                    .widget<PosterPureFlutter>(find.byType(PosterPureFlutter))
                    .quote ==
                text)
          break;
      }
      expect(
        tester.widget<PosterPureFlutter>(find.byType(PosterPureFlutter)).quote,
        text,
      );
      expect(
        tester
            .widget<PosterPureFlutter>(find.byType(PosterPureFlutter))
            .signaturePending,
        isTrue,
      );
      final before = tester.getRect(find.byKey(const ValueKey('quote-body')));
      final beforeLines = find.descendant(
        of: find.byKey(const ValueKey('quote-body')),
        matching: find.byType(Text),
      );
      final firstLine = tester.getRect(beforeLines.first);
      signatures.answer.complete('Simone Weil');
      await tester.pumpAndSettle();
      final poster = tester.widget<PosterPureFlutter>(
        find.byType(PosterPureFlutter),
      );
      expect(poster.originalAuthor, 'Simone Weil');
      expect(poster.quote, text);
      expect(poster.signaturePending, isFalse);
      expect(find.byType(PageView), findsNothing);
      expect(tester.getRect(find.byKey(const ValueKey('quote-body'))), before);
      expect(tester.getRect(beforeLines.first), firstLine);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
