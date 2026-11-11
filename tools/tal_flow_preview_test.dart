// Render the real Flutter widgets for a reviewable phone-width walkthrough.
// This is a widget-renderer preview, not an Android/emulator acceptance test.
// TAL_PREVIEW_FONT=/path/to/NotoSansCJKSC.otf TAL_PREVIEW_DIR=/tmp/tal-preview \
//   flutter test --no-pub tools/tal_flow_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import '../test/tal_failure_change/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['TAL_PREVIEW_DIR'];
  final font = Platform.environment['TAL_PREVIEW_FONT'];
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (font != null) {
      final loader = FontLoader('TalPreviewSans')
        ..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)));
      await loader.load();
    }
  });
  testWidgets('capture the five-step job search and follow-up journey',
      (tester) async {
    final f = TalFixture();
    await f.open();
    addTearDown(f.db.close);
    final env = TalEnvironment(ledger: f.ledger);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = GlobalKey();
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> input(String key, String text) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, text);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary =
          root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$directory/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(RepaintBoundary(
        key: root,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.indigo,
                scaffoldBackgroundColor: Colors.white,
                fontFamily: font == null ? null : 'TalPreviewSans'),
            home: TalReflectionPage(environment: env))));
    await tester.pumpAndSettle();
    await input('tal_plan', '今天找工作');
    await input('tal_observed', '打开招聘页后就关掉了，没有投递');
    await capture('01-facts');
    await tap(find.byKey(const ValueKey('tal_flow_next')));
    await input('tal_did', '有点犹豫，还不清楚自己为什么没有继续');
    await capture('02-experience');
    await tap(find.byKey(const ValueKey('tal_flow_next')));
    await tap(find.text('还不清楚'));
    await capture('03-insight');
    await tap(find.byKey(const ValueKey('tal_flow_next')));
    await tap(find.text('调整'));
    await input('tal_action', '先收藏 1 个符合要求的岗位');
    await input('tal_trigger', '明天晚饭后打开招聘页时');
    await input('tal_check', '查看收藏列表，对照岗位要求');
    await capture('04-next-action');
    await tap(find.byKey(const ValueKey('tal_flow_next')));
    await capture('05-save');
    await tap(find.byKey(const ValueKey('tal_save_flow')));
    await capture('06-awaiting-real-action');
    await tap(find.byKey(const ValueKey('tal_open_feedback')));
    await tap(find.text('做了'));
    await tap(find.text('效果还不清楚'));
    await capture('07-follow-up');
    await tap(find.byKey(const ValueKey('tal_save_feedback')));
    final records = await f.records();
    expect(records, hasLength(1));
    expect(records.single.level, 'L3 执行');
    await tester.pumpAndSettle();
    await capture('08-feedback-saved');
    await tap(find.byKey(const ValueKey('tal_edit_record')));
    await tap(find.text('练习方式'));
    await tap(find.text('塔尔真实案例'));
    await capture('09-real-case-C18');
    await tap(find.byKey(const ValueKey('tal_case_practice_C18_prp')));
    await tap(find.text('拉远视野'));
    await input('practice_perspective', '一次没有投递，不代表以后找不到工作');
    await capture('10-nonlinear-PRP');
    await tap(find.text('重构'));
    await input('practice_reconstruction', '先核对岗位是否合适，再决定投递');
    await tap(find.byKey(const ValueKey('tal_use_practice')));
    await capture('11-practice-back-in-same-draft');
  }, skip: directory == null);
}
