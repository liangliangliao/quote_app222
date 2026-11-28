import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:quote_app/conscious_change/interactive_image/artwork.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_canvas.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_repository.dart';
import 'package:quote_app/conscious_change/interactive_image/feedback_editor.dart';
import 'package:quote_app/conscious_change/interactive_image/region_editor_page.dart';
import 'package:quote_app/conscious_change/interactive_image/region_geometry.dart';

void main() {
  testWidgets('draws a region, undoes and redoes it, and saves its feedback',
      (tester) async {
    final folder = Directory.systemTemp.createTempSync('region-editor-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final repository = _EditorRepository();
    repository
        .previewFile(folder)
        .writeAsBytesSync(image.encodePng(image.Image(120, 60)));
    await tester.pumpWidget(MaterialApp(
      home: RegionEditorPage(
        artwork: Artwork(
            id: 'test',
            title: '图片',
            format: 'png',
            width: 120,
            height: 60,
            createdAt: DateTime(2026)),
        folder: folder,
        repository: repository,
        edits: const ArtworkEdits(),
        settings: const FeedbackSettings(),
        openPage: (_) async {},
      ),
    ));
    await tester.tap(find.text('手动画区域'));
    await tester.pumpAndSettle();
    final view = tester.getRect(find.byType(ArtworkCanvas));
    final rect = artworkRect(view.size, 2);
    for (final point in const [
      Offset(0.2, 0.2),
      Offset(0.65, 0.2),
      Offset(0.45, 0.7)
    ]) {
      await tester.tapAt(view.topLeft + imagePoint(point, rect));
      await tester.pump();
    }
    await tester.tap(find.text('保存轮廓'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '书架');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('书架'), findsWidgets);

    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(find.text('保存轮廓'), findsOneWidget);
    await tester.tap(find.byTooltip('重做'));
    await tester.pumpAndSettle();
    expect(find.text('书架'), findsWidgets);

    await tester.scrollUntilVisible(find.text('手势与语音反馈'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('手势与语音反馈'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('点击'));
    await tester.tap(find.text('点击'));
    await tester.pumpAndSettle();
    for (final feedback in ['高亮区域', '轻震动']) {
      await tester.tap(find.text('添加反馈'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(feedback).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('反馈步骤选项').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('上移'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存顺序'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存规则'));
    await tester.tap(find.text('保存规则'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 个手势'), findsWidgets);
    expect(repository.saved.regions.single.rules[TouchGesture.tap], const [
      FeedbackStep(TouchAction.vibration),
      FeedbackStep(TouchAction.highlight),
    ]);
  });

  testWidgets('saves an app by name with the keyboard open on a short screen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 600);
    addTearDown(tester.view.reset);
    final artwork = Artwork(
        id: 'test',
        title: '图片',
        format: 'png',
        width: 120,
        height: 60,
        createdAt: DateTime(2026));
    ImageRegion? saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      child: const Text('配置区域'),
                      onPressed: () async {
                        saved = await editRegionRules(
                            context,
                            artwork,
                            const ImageRegion(
                                id: 'region',
                                label: '区域',
                                group: RegionGroup.object,
                                polygon: [
                                  Offset.zero,
                                  Offset(1, 0),
                                  Offset(1, 1)
                                ]),
                            const FeedbackSettings(),
                            (region, steps) async {});
                      },
                    )))));
    await tester.tap(find.text('配置区域'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('点击'));
    await tester.tap(find.text('点击'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加反馈'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('打开手机应用'), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('打开手机应用'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '应用名称'), 'ChatGPT');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('按此名称查找'));
    await tester.tap(find.text('按此名称查找'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存顺序'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存规则'));
    await tester.tap(find.text('保存规则'));
    await tester.pumpAndSettle();
    expect(saved?.rules[TouchGesture.tap],
        const [FeedbackStep(TouchAction.app, name: 'ChatGPT')]);
  });
}

class _EditorRepository extends ArtworkRepository {
  ArtworkEdits saved = const ArtworkEdits();

  @override
  Future<void> saveEdits(Directory folder, ArtworkEdits edits) async {
    saved = edits;
  }
}
