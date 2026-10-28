import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/pages/home_page.dart';
import 'package:quote_app/services/native_guard.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
