import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:quote_app/conscious_change/interactive_image/artwork.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_canvas.dart';
import 'package:quote_app/conscious_change/interactive_image/effort_meter.dart';
import 'package:quote_app/conscious_change/interactive_image/interaction_player.dart';
import 'package:quote_app/conscious_change/interactive_image/region_geometry.dart';

void main() {
  testWidgets(
      'tap, long press and swipe use the transformed image and pinch cancels them',
      (tester) async {
    final folder = Directory.systemTemp.createTempSync('interaction-player-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/preview.png')
      ..writeAsBytesSync(image.encodePng(image.Image(120, 60)));
    final actions = <TouchAction>[];
    await tester.pumpWidget(MaterialApp(
      home: InteractionPlayer(
        artwork: Artwork(
            id: 'test',
            title: '图片',
            format: 'png',
            width: 120,
            height: 60,
            createdAt: DateTime(2026)),
        file: file,
        regions: const [
          ImageRegion(
            id: 'test',
            label: '区域',
            group: RegionGroup.object,
            polygon: [
              Offset(0.2, 0.2),
              Offset(0.45, 0.2),
              Offset(0.45, 0.65),
              Offset(0.2, 0.65)
            ],
            rules: {
              TouchGesture.tap: [FeedbackStep(TouchAction.learning)],
              TouchGesture.hold: [FeedbackStep(TouchAction.books)],
              TouchGesture.swipe: [FeedbackStep(TouchAction.books)]
            },
          ),
        ],
        settings:
            const FeedbackSettings(effortDifficulty: EffortDifficulty.easy),
        openPage: (action) async => actions.add(action),
      ),
    ));
    final canvasFinder = find.byType(ArtworkCanvas);
    final view = tester.getRect(canvasFinder);
    final canvas = tester.widget<ArtworkCanvas>(canvasFinder);
    final imageRect = artworkRect(view.size, 2);
    final coords = ArtworkCoordinates(imageRect, canvas.transform);
    final target = const Offset(0.32, 0.4);

    final corner = view.topLeft + const Offset(3, 3);
    await tester.tapAt(corner);
    expect(actions, isEmpty);
    final initialTarget = view.topLeft + coords.viewPoint(target);
    await tester.tapAt(initialTarget);
    await tester.pump();
    expect(find.text('33%'), findsOneWidget);
    expect(actions, isEmpty);
    await tester.pump(const Duration(milliseconds: 651));
    expect(find.text('0%'), findsOneWidget);
    expect(actions, isEmpty);

    final zoom = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-180, -150, 0);
    canvas.transform.value = zoom;
    await tester.pump();
    final transformedTarget = view.topLeft + coords.viewPoint(target);
    await tester.tapAt(transformedTarget);
    await tester.tapAt(transformedTarget);
    await tester.pump();
    expect(find.text('66%'), findsOneWidget);
    expect(actions, isEmpty);
    await tester.tapAt(transformedTarget);
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    expect(actions, [TouchAction.learning]);

    final shortHold = await tester.startGesture(transformedTarget, pointer: 10);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('继续按住'), findsOneWidget);
    expect(actions, hasLength(1));
    await shortHold.up();
    await tester.pump();
    expect(find.text('0%'), findsOneWidget);
    expect(actions, hasLength(1));

    final held = await tester.startGesture(transformedTarget, pointer: 11);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    expect(actions, [TouchAction.learning, TouchAction.books]);
    await held.up();

    final slide = await tester.startGesture(transformedTarget, pointer: 12);
    await slide.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(find.text('40%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 361));
    expect(find.text('0%'), findsOneWidget);
    await slide.moveBy(const Offset(65, 0));
    await slide.up();
    await tester.pump();
    expect(find.text('0%'), findsOneWidget);
    expect(actions, hasLength(2));

    final completedSlide =
        await tester.startGesture(transformedTarget, pointer: 13);
    await completedSlide.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(find.text('60%'), findsOneWidget);
    await completedSlide.moveBy(const Offset(-45, 0));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    expect(
        actions, [TouchAction.learning, TouchAction.books, TouchAction.books]);
    await completedSlide.up();

    await tester.tapAt(transformedTarget);
    final firstFinger =
        await tester.startGesture(transformedTarget, pointer: 14);
    final secondFinger = await tester
        .startGesture(transformedTarget + const Offset(25, 0), pointer: 15);
    await tester.pump(const Duration(milliseconds: 1000));
    await firstFinger.up();
    await secondFinger.up();
    expect(find.text('0%'), findsOneWidget);
    expect(actions, hasLength(3));

    await tester.tap(find.byTooltip('暂停互动'));
    await tester.pump();
    await tester.tapAt(transformedTarget);
    expect(actions, hasLength(3));
    expect(find.text('互动已暂停'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'keeps the effort bar above the original image and runs feedback steps in order',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    final folder = Directory.systemTemp.createTempSync('interaction-chain-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/original.png')
      ..writeAsBytesSync(image.encodePng(image.Image(120, 60)));
    final firstStep = Completer<void>();
    final actions = <TouchAction>[];
    await tester.pumpWidget(MaterialApp(
        home: InteractionPlayer(
      artwork: Artwork(
          id: 'test',
          title: '图片',
          format: 'png',
          width: 120,
          height: 60,
          createdAt: DateTime(2026)),
      file: file,
      settings: const FeedbackSettings(effortDifficulty: EffortDifficulty.easy),
      regions: const [
        ImageRegion(
            id: 'region',
            label: '区域',
            group: RegionGroup.object,
            polygon: [
              Offset(0.2, 0.2),
              Offset(0.8, 0.2),
              Offset(0.8, 0.8),
              Offset(0.2, 0.8)
            ],
            rules: {
              TouchGesture.tap: [
                FeedbackStep(TouchAction.learning),
                FeedbackStep(TouchAction.books)
              ]
            })
      ],
      openPage: (action) async {
        actions.add(action);
        if (action == TouchAction.learning) await firstStep.future;
      },
    )));
    final finder = find.byType(ArtworkCanvas);
    final canvas = tester.getRect(finder);
    final meter = tester.getRect(find.byType(EffortMeter));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(meter.bottom, lessThanOrEqualTo(canvas.top));
    expect(canvas.bottom, screen.bottom);
    expect(canvas.width, screen.width);
    expect(meter.top, lessThan(24));
    expect(tester.widget<ArtworkCanvas>(finder).original, isTrue);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(tester.getCenter(finder));
    }
    await tester.pump();
    expect(actions, isEmpty);
    await tester.pump(const Duration(milliseconds: 180));
    expect(actions, [TouchAction.learning]);
    firstStep.complete();
    await tester.pump();
    expect(actions, [TouchAction.learning, TouchAction.books]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'exiting the preview cancels unfinished effort during the exit animation',
      (tester) async {
    final folder = Directory.systemTemp.createTempSync('interaction-exit-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/preview.png')
      ..writeAsBytesSync(image.encodePng(image.Image(120, 60)));
    final actions = <TouchAction>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/preview'),
                    child: const Text('打开预览'),
                  ))),
      routes: {
        '/preview': (context) => InteractionPlayer(
              artwork: Artwork(
                  id: 'test',
                  title: '图片',
                  format: 'png',
                  width: 120,
                  height: 60,
                  createdAt: DateTime(2026)),
              file: file,
              settings: const FeedbackSettings(
                  effortDifficulty: EffortDifficulty.easy),
              openPage: (action) async => actions.add(action),
              regions: const [
                ImageRegion(
                    id: 'region',
                    label: '区域',
                    group: RegionGroup.object,
                    polygon: [
                      Offset(0.2, 0.2),
                      Offset(0.8, 0.2),
                      Offset(0.8, 0.8),
                      Offset(0.2, 0.8)
                    ],
                    rules: {
                      TouchGesture.hold: [FeedbackStep(TouchAction.books)]
                    })
              ],
            )
      },
    ));
    await tester.tap(find.text('打开预览'));
    await tester.pumpAndSettle();
    final held =
        await tester.startGesture(tester.getCenter(find.byType(ArtworkCanvas)));
    await tester.pump(const Duration(milliseconds: 880));
    expect(find.text('继续按住'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 200));
    await held.up();
    await tester.pumpAndSettle();
    expect(actions, isEmpty);
    expect(find.text('打开预览'), findsOneWidget);
  });
}
