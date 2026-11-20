import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:quote_app/conscious_change/interactive_image/artwork.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_canvas.dart';
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
              TouchGesture.tap: TouchAction.learning,
              TouchGesture.hold: TouchAction.books,
              TouchGesture.swipe: TouchAction.books
            },
          ),
        ],
        settings: const FeedbackSettings(),
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
    await tester.tapAt(view.topLeft + coords.viewPoint(target));
    await tester.pump();
    expect(actions, [TouchAction.learning]);

    final zoom = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-180, -150, 0);
    canvas.transform.value = zoom;
    await tester.pump();
    final transformedTarget = view.topLeft + coords.viewPoint(target);
    await tester.tapAt(transformedTarget);
    await tester.pump();
    expect(actions, [TouchAction.learning, TouchAction.learning]);

    final held = await tester.startGesture(transformedTarget, pointer: 10);
    await tester.pump(const Duration(milliseconds: 510));
    await held.up();
    await tester.pump();
    expect(actions.last, TouchAction.books);
    expect(actions, hasLength(3));

    final slide = await tester.startGesture(transformedTarget, pointer: 11);
    await slide.moveBy(const Offset(32, 0));
    await slide.up();
    await tester.pump();
    expect(actions.last, TouchAction.books);
    expect(actions, hasLength(4));

    final firstFinger =
        await tester.startGesture(transformedTarget, pointer: 12);
    final secondFinger = await tester
        .startGesture(transformedTarget + const Offset(25, 0), pointer: 13);
    await tester.pump(const Duration(milliseconds: 600));
    await firstFinger.up();
    await secondFinger.up();
    expect(actions, hasLength(4));

    await tester.tap(find.byTooltip('暂停互动'));
    await tester.pump();
    await tester.tapAt(transformedTarget);
    expect(actions, hasLength(4));
    expect(find.text('互动已暂停'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
