import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:quote_app/conscious_change/interactive_image/artwork.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_canvas.dart';
import 'package:quote_app/conscious_change/interactive_image/effort_meter.dart';
import 'package:quote_app/conscious_change/interactive_image/interaction_player.dart';
import 'package:quote_app/conscious_change/interactive_image/original_artwork_image.dart';
import 'package:quote_app/conscious_change/interactive_image/region_geometry.dart';

void main() {
  testWidgets(
      'a region deforms under the finger and the effort rail moves at a fixed value',
      (tester) async {
    final folder = Directory.systemTemp.createTempSync('soft-surface-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final texture = image.Image(280, 140);
    for (var y = 0; y < texture.height; y++) {
      for (var x = 0; x < texture.width; x++) {
        final detail = (x % 9) * 4;
        texture.setPixelRgba(
            x, y, 120 + y ~/ 2 + detail, 55 + y ~/ 3, 45 + detail);
      }
    }
    final file = File('${folder.path}/texture.png')
      ..writeAsBytesSync(image.encodePng(texture));
    final snapshotKey = GlobalKey();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));
    await tester.runAsync(() async {
      await precacheImage(
          OriginalArtworkImage(file), tester.element(find.byType(SizedBox)));
      await ui.FragmentProgram.fromAsset(
          'assets/interactive_image/soft_surface.frag');
    });
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: snapshotKey,
        child: InteractionPlayer(
          artwork: Artwork(
              id: 'test',
              title: '图片',
              format: 'png',
              width: 280,
              height: 140,
              createdAt: DateTime(2026)),
          file: file,
          regions: const [
            ImageRegion(
              id: 'test',
              label: '区域',
              group: RegionGroup.object,
              polygon: [
                Offset(0.2, 0.2),
                Offset(0.5, 0.2),
                Offset(0.5, 0.75),
                Offset(0.2, 0.75)
              ],
              rules: {
                TouchGesture.tap: [FeedbackStep(TouchAction.learning)]
              },
            ),
          ],
          settings:
              const FeedbackSettings(effortDifficulty: EffortDifficulty.easy),
          openPage: (_) async =>
              fail('A single touch must not unlock feedback'),
        ),
      ),
    ));
    final finder = find.byType(ArtworkCanvas);
    await tester.pump();
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(snapshotKey));
    Future<ByteData> snapshot() async => (await tester.runAsync(() async {
          final frame = await boundary.toImage();
          try {
            return await frame.toByteData();
          } finally {
            frame.dispose();
          }
        }))!;

    final view = tester.getRect(finder);
    final photo = artworkRect(view.size, 2).shift(view.topLeft);
    final contact = imagePoint(const Offset(0.48, 0.49), photo);
    final outside = imagePoint(const Offset(0.51, 0.49), photo);
    final destination = imagePoint(const Offset(0.30, 0.51), photo);
    int pixel(ByteData frame, Offset point) => frame.getUint32(
        (point.dy.floor() * boundary.size.width.floor() + point.dx.floor()) *
            4);

    final original = await snapshot();
    final finger = await tester.startGesture(contact);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final pressed = await snapshot();
    expect(pixel(pressed, contact), isNot(pixel(original, contact)));
    expect(pixel(pressed, outside), pixel(original, outside));

    await finger.moveTo(destination);
    await tester.pump();
    final moved = await snapshot();
    expect(pixel(moved, destination), isNot(pixel(original, destination)));
    expect(pixel(moved, contact), pixel(original, contact));
    await finger.up();
    await tester.pump();
    final releasing = await snapshot();
    expect(pixel(releasing, destination), isNot(pixel(original, destination)));
    await tester.pump(const Duration(milliseconds: 400));
    final released = await snapshot();
    expect(pixel(released, destination), pixel(original, destination));

    final crossing = await tester.startGesture(outside);
    await crossing.moveTo(contact);
    await tester.pump();
    final entered = await snapshot();
    expect(pixel(entered, contact), isNot(pixel(original, contact)));
    expect(pixel(entered, outside), pixel(original, outside));
    await crossing.cancel();
    await tester.pump();
    expect(pixel(await snapshot(), contact), pixel(original, contact));

    final tap = await tester.startGesture(contact);
    await tap.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(find.text('33%'), findsOneWidget);
    final firstWave = await snapshot();
    await tester.pump(const Duration(milliseconds: 70));
    final secondWave = await snapshot();
    expect(find.text('33%'), findsOneWidget);
    final rail = tester.getRect(find.descendant(
        of: find.byType(EffortMeter), matching: find.byType(CustomPaint)));
    expect(
        [
          for (var x = rail.center.dx; x < rail.right - 4; x += 3)
            pixel(firstWave, Offset(x, rail.center.dy))
        ],
        isNot(equals([
          for (var x = rail.center.dx; x < rail.right - 4; x += 3)
            pixel(secondWave, Offset(x, rail.center.dy))
        ])));
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
