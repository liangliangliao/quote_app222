import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/kindling/kindling.dart';
import 'package:quote_app/kindling/src/copy.dart';
import 'package:quote_app/kindling/src/data/kindling_dao.dart';
import 'package:quote_app/kindling/src/ui/list_page.dart';
import 'package:quote_app/kindling/src/ui/probe_sheet.dart';
import 'package:quote_app/kindling/src/ui/recall_page.dart';
import 'package:quote_app/kindling/src/ui/resistance_page.dart';
import 'package:quote_app/kindling/src/ui/verdict_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  final List<Directory> tempDirs = <Directory>[];

  // 每个用例一份独立的库文件。
  //
  // 不能用 inMemoryDatabasePath：sqflite 按路径缓存已打开的库，而这里又不能在
  // tearDown 里关库——页面进场时发出的查询走真实事件循环，用例断言完时可能还在
  // 途中，提前关库只会报 database_closed。不关库 + 同一个 ':memory:' 路径，
  // 下一个用例就会拿到上一个用例的数据。各用一份临时文件即可两头都躲开。
  setUp(() async {
    final Directory dir =
        await Directory.systemTemp.createTemp('kindling_widget_test_');
    tempDirs.add(dir);
    db = await databaseFactoryFfi.openDatabase('${dir.path}/kindling.db');
    await KindlingSchema.createAll(db);
  });

  tearDownAll(() async {
    for (final Directory dir in tempDirs) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // 临时目录清不掉不影响结论。
      }
    }
  });

  /// 数据库调用走真实事件循环，pumpAndSettle 单独驱动不到，需要交替放行。
  ///
  /// [until] 给出后，一旦目标出现就提前返回；否则跑满轮次。固定轮次在并行跑
  /// 多个测试文件时会因为机器变慢而抖动，所以这里按条件收敛而不是按次数。
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    for (int i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      if (until != null && until.evaluate().isNotEmpty) return;
      if (until == null && i >= 5) return;
    }
    if (until != null) {
      fail('等不到 $until，界面没有到达预期状态');
    }
  }

  /// [ready] 是这个用例进场后要碰的第一个东西——等它出现，才算首屏加载完成。
  Future<void> pumpEntry(
    WidgetTester tester, {
    Finder? ready,
    KindlingOracle? oracle,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: oracle == null
            ? KindlingEntry.build(db: db)
            : KindlingEntry.build(db: db, oracle: oracle),
      ),
    );
    await settle(tester, until: ready ?? find.text(KCopy.emptyDirect));
  }

  testWidgets('an empty list offers 回溯, 十五分钟 and 直接写一个 only',
      (WidgetTester tester) async {
    await pumpEntry(tester);

    expect(find.text(KCopy.title), findsOneWidget);
    expect(find.text(KCopy.emptyList), findsOneWidget);
    expect(find.text(KCopy.emptyDirect), findsOneWidget);
    expect(find.text(KCopy.recall), findsOneWidget);
    expect(find.text(KCopy.burn), findsOneWidget);
    expect(find.text(KCopy.releasedWithCount(0)), findsOneWidget);

    // 顶部没有「新建目标」之类的按钮。
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);

    // 空清单时「十五分钟」不可用，也不给任何提示。
    final OutlinedButton burnButton = tester.widget<OutlinedButton>(
      find.byKey(KindlingListPage.burnKey),
    );
    expect(burnButton.onPressed, isNull);
  });

  testWidgets('直接写一个 immediately asks the verdict question',
      (WidgetTester tester) async {
    await pumpEntry(tester);

    await tester.tap(find.text(KCopy.emptyDirect));
    await settle(tester, until: find.byKey(KindlingListPage.directKey));
    await tester.enterText(
      find.byKey(KindlingListPage.directKey),
      '把 §9 那段译完',
    );
    await tester.tap(find.text(KCopy.save));
    await settle(tester, until: find.byKey(KindlingVerdictSheet.sheetKey));

    expect(find.byKey(KindlingVerdictSheet.sheetKey), findsOneWidget);
    expect(find.text(KCopy.verdictQ), findsOneWidget);
    expect(find.text(KCopy.verdictYes), findsOneWidget);
    expect(find.text(KCopy.verdictNo), findsOneWidget);
    expect(find.text(KCopy.verdictIdk), findsOneWidget);

    await tester.tap(find.byKey(KindlingVerdictSheet.yesKey));
    await settle(tester, until: find.text('把 §9 那段译完'));

    expect(find.text('把 §9 那段译完'), findsOneWidget);
    expect(find.text(KCopy.emptyList), findsNothing);
  });

  testWidgets('answering 不做 keeps the item and moves it to 放掉的',
      (WidgetTester tester) async {
    await pumpEntry(tester);

    await tester.tap(find.text(KCopy.emptyDirect));
    await settle(tester, until: find.byKey(KindlingListPage.directKey));
    await tester.enterText(
      find.byKey(KindlingListPage.directKey),
      '写一份没人要的周报',
    );
    await tester.tap(find.text(KCopy.save));
    await settle(tester, until: find.byKey(KindlingVerdictSheet.noKey));

    await tester.tap(find.byKey(KindlingVerdictSheet.noKey));
    await settle(tester, until: find.text(KCopy.verdictNoTip));

    expect(find.text(KCopy.verdictNoTip), findsOneWidget);
    await tester.tap(find.text(KCopy.done));
    await settle(tester, until: find.text(KCopy.releasedWithCount(1)));

    expect(find.text(KCopy.emptyList), findsOneWidget);
    expect(find.text(KCopy.releasedWithCount(1)), findsOneWidget);

    // 放掉的里可以拿回来。
    await tester.tap(find.byKey(KindlingListPage.releasedKey));
    await settle(tester, until: find.text(KCopy.releasedTip));
    expect(find.text(KCopy.releasedTip), findsOneWidget);
    expect(find.text('写一份没人要的周报'), findsOneWidget);
    expect(find.text(KCopy.releaseReasonVerdict), findsOneWidget);

    await tester.tap(find.text(KCopy.restore));
    await settle(tester, until: find.text(KCopy.emptyReleased));
    expect(find.text('写一份没人要的周报'), findsNothing);
  });

  testWidgets('long press opens 换个说法 / 问一句 / 卡住了 / 放掉',
      (WidgetTester tester) async {
    // 直接落库要走真实事件循环，否则 fake async 里永远等不到结果。
    await tester.runAsync(
      () => KindlingDao(db).insertItem(title: '修 XX 的渲染 bug'),
    );
    await pumpEntry(tester, ready: find.text('修 XX 的渲染 bug'));

    await tester.longPress(find.text('修 XX 的渲染 bug'));
    await settle(tester, until: find.text(KCopy.menuRename));

    expect(find.text(KCopy.menuProbe), findsOneWidget);
    expect(find.text(KCopy.menuRename), findsOneWidget);
    expect(find.text(KCopy.menuVerdict), findsOneWidget);
    expect(find.text(KCopy.menuResistance), findsOneWidget);
    expect(find.text(KCopy.menuRelease), findsOneWidget);
  });

  testWidgets('痒度自评只给措辞，不给任何数字', (WidgetTester tester) async {
    await tester.runAsync(
      () => KindlingDao(db).insertItem(title: '修 XX 的渲染 bug'),
    );
    await pumpEntry(tester, ready: find.text('修 XX 的渲染 bug'));

    await tester.longPress(find.text('修 XX 的渲染 bug'));
    await settle(tester, until: find.text(KCopy.menuProbe));
    await tester.tap(find.text(KCopy.menuProbe));
    await settle(tester, until: find.byKey(KindlingProbeSheet.sheetKey));

    for (final String rung in KCopy.probeLadder) {
      expect(find.text(rung), findsOneWidget);
    }
    // 五档措辞里不出现数字、百分号或星级。
    for (final String rung in KCopy.probeLadder) {
      expect(RegExp(r'[0-9%★☆]').hasMatch(rung), isFalse);
    }

    await tester.tap(find.text(KCopy.probe4));
    await settle(tester);

    final List<Map<String, Object?>> rows = await tester.runAsync(
          () => db.query('k_probe'),
        ) ??
        <Map<String, Object?>>[];
    expect(rows.single['score'], 4, reason: '最上面一档是最痒');
    // 答完不给任何反馈。
    expect(find.byKey(KindlingProbeSheet.sheetKey), findsNothing);
  });

  testWidgets('换个说法可以顺手留一句备注', (WidgetTester tester) async {
    await tester.runAsync(
      () => KindlingDao(db).insertItem(title: '修 XX 的渲染 bug'),
    );
    await pumpEntry(tester, ready: find.text('修 XX 的渲染 bug'));

    await tester.longPress(find.text('修 XX 的渲染 bug'));
    await settle(tester, until: find.text(KCopy.menuRename));
    await tester.tap(find.text(KCopy.menuRename));
    await settle(tester, until: find.byKey(KindlingListPage.noteKey));

    await tester.enterText(find.byKey(KindlingListPage.noteKey), '拖了三个月了');
    await tester.tap(find.text(KCopy.save));
    await settle(tester);

    final List<Map<String, Object?>> rows =
        await tester.runAsync(() => db.query('k_item')) ??
            <Map<String, Object?>>[];
    expect(rows.single['note'], '拖了三个月了');
    // 备注只是留给自己看的，不出现在清单上。
    expect(find.text('拖了三个月了'), findsNothing);
  });

  testWidgets('卡住了 only asks and ends with the fixed closing line',
      (WidgetTester tester) async {
    // 直接落库要走真实事件循环，否则 fake async 里永远等不到结果。
    await tester.runAsync(
      () => KindlingDao(db).insertItem(title: '修 XX 的渲染 bug'),
    );
    await pumpEntry(tester, ready: find.text('修 XX 的渲染 bug'));

    await tester.longPress(find.text('修 XX 的渲染 bug'));
    await settle(tester, until: find.text(KCopy.menuResistance));
    await tester.tap(find.text(KCopy.menuResistance));
    await settle(tester, until: find.text(KCopy.resistance1));

    for (final String question in KCopy.resistanceLadder) {
      await settle(tester, until: find.text(question));
      expect(find.text(question), findsOneWidget);
      await tester.tap(find.text(KCopy.skip));
      await settle(tester);
    }

    await settle(tester, until: find.text(KCopy.resistanceEnd));
    expect(find.text(KCopy.resistanceEnd), findsOneWidget);
    // 无总结、无建议列表、无「推荐行动」。
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('卡住了 进场立刻有第一问，不等追问器', (WidgetTester tester) async {
    await tester.runAsync(
      () => KindlingDao(db).insertItem(title: '修 XX 的渲染 bug'),
    );
    // 一个永远不返回的追问器：真机上就是那次卡住的云端请求。
    await pumpEntry(
      tester,
      ready: find.text('修 XX 的渲染 bug'),
      oracle: const _StalledOracle(),
    );

    await tester.longPress(find.text('修 XX 的渲染 bug'));
    await settle(tester, until: find.text(KCopy.menuResistance));
    await tester.tap(find.text(KCopy.menuResistance));
    await tester.pumpAndSettle();

    // 没有等待，也没有白屏：第一问当场就在。
    expect(find.text(KCopy.resistance1), findsOneWidget);
    expect(find.byKey(KindlingResistancePage.inputKey), findsOneWidget);
  });

  testWidgets('回溯 turns raw answers into candidates the user may keep',
      (WidgetTester tester) async {
    await pumpEntry(tester);

    await tester.tap(find.text(KCopy.recall));
    await settle(tester, until: find.text(KCopy.qLostTrack));

    expect(find.text(KCopy.qLostTrack), findsOneWidget);
    await tester.enterText(
      find.byKey(KindlingRecallPage.inputKey),
      '改渲染管线到三点。译完第九节',
    );
    await tester.tap(find.text(KCopy.next));
    await settle(tester, until: find.text(KCopy.qItch));

    expect(find.text(KCopy.qItch), findsOneWidget);
    await tester.tap(find.text(KCopy.next));
    await settle(tester, until: find.text(KCopy.qEnvy));

    expect(find.text(KCopy.qEnvy), findsOneWidget);
    await tester.tap(find.text(KCopy.done));
    await settle(tester, until: find.text(KCopy.pickHint));

    expect(find.text(KCopy.pickHint), findsOneWidget);
    expect(find.text('改渲染管线到三点'), findsOneWidget);
    expect(find.text('译完第九节'), findsOneWidget);

    await tester.tap(find.text(KCopy.done));
    await settle(tester);

    // 回溯建出来的火种同样要过一次判别式，一条一问。
    for (int i = 0; i < 2; i++) {
      await settle(tester, until: find.byKey(KindlingVerdictSheet.sheetKey));
      expect(find.byKey(KindlingVerdictSheet.sheetKey), findsOneWidget);
      await tester.tap(find.byKey(KindlingVerdictSheet.yesKey));
      await settle(tester);
    }

    expect(find.byKey(KindlingVerdictSheet.sheetKey), findsNothing);
    expect(find.text('改渲染管线到三点'), findsOneWidget);
    expect(find.text('译完第九节'), findsOneWidget);
  });

  testWidgets('the discover entry hands the tap back to the host',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KindlingDiscoverEntry(onTap: () => taps += 1),
        ),
      ),
    );

    expect(find.text(KCopy.title), findsOneWidget);
    await tester.tap(find.byKey(KindlingDiscoverEntry.entryKey));
    await settle(tester);
    expect(taps, 1);
  });
}

/// 永远不返回的追问器：用来证明界面不靠它也能立刻出内容。
class _StalledOracle implements KindlingOracle {
  const _StalledOracle();

  @override
  Future<List<String>> extractCandidates(Map<String, String> answers) =>
      Completer<List<String>>().future;

  @override
  Future<String?> nextResistanceQuestion(
    List<({String q, String? a})> history,
  ) =>
      Completer<String?>().future;
}
