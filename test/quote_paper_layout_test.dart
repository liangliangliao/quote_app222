import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_adaptive_frame.dart';

const quote = '你的大脑分不清现实和想象的区别，因此你可以先在内心模拟自己想成为的样子。当你在脑海中一遍遍练习变得轻松、冷静和包容，你就更容易在现实中真的那样去做。';
const author = '— Tal Ben-Shahar, Harvard Positive Psychology (Happiness) Course';
const note = '这段话强调的是心理排练的力量：在脑海中练习如何面对现实中的困难，观察自己的身体、情绪与行动，再在现实中检验这些想象。想象本身不能保证结果，也不能取代现实行动。';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('/tmp/quote-preview-cjk.otf');
    if (font.existsSync()) {
      final loader = FontLoader('QuotePreviewCJK')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });
  Future<void> mount(WidgetTester tester, double width, {
    String text = quote, String explanation = note, bool portrait = false,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, width * 1.5));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'QuotePreviewCJK'),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, width * 1.5),
          textScaler: TextScaler.linear(scale)),
        child: Scaffold(backgroundColor: Colors.white,
          body: RepaintBoundary(key: const ValueKey('preview-boundary'),
            child: PosterPureFlutter(
              topic: '成为那样的人', quote: text, author: author,
              note: explanation,
              avatar: portrait ? 'assets/avatars/talbenshahar .jpeg' : '',
            )),
        ),
      ),
    ));
    await tester.pump();
  }

  for (final width in [240.0, 320.0, 360.0, 412.0, 620.0]) {
    testWidgets('complete lines stay inside paper at width $width', (tester) async {
      await mount(tester, width);
      final frame = tester.getRect(find.byType(QuoteAdaptiveFrame));
      final paper = QuoteAdaptiveFrame.scaleRect(
        QuoteAdaptiveFrame.textSafeRect, frame.size).shift(frame.topLeft);
      for (final name in ['quote-topic', 'quote-body', 'quote-author', 'quote-note']) {
        final finder = find.byKey(ValueKey(name));
        if (finder.evaluate().isEmpty) continue;
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(paper.top - .5));
        expect(rect.bottom, lessThanOrEqualTo(paper.bottom + .5));
      }
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long content remains available in a scalable complete reader', (tester) async {
    final longQuote = List.filled(8, quote).join();
    final longNote = List.filled(10, note).join();
    await mount(tester, 320, text: longQuote, explanation: longNote, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await tester.pumpAndSettle();
    final reader = find.byKey(const ValueKey('quote-full-reading'));
    expect(reader, findsOneWidget);
    expect(find.descendant(of: reader, matching: find.text(longQuote)), findsOneWidget);
    expect(find.descendant(of: reader, matching: find.text(longNote)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait composition and white wall render without clipping', (tester) async {
    await mount(tester, 400, portrait: true);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final body = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('quote-body')));
    expect(body.didExceedMaxLines, isFalse, reason: 'The screenshot quote must fit in full');
    await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview-boundary')));
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(raw, isNotNull);
    // The photographed perimeter must merge into the actual white page.
    for (final point in [const Offset(1, 250), const Offset(398, 250),
        const Offset(200, 1), const Offset(200, 598)]) {
      final index = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
      expect(raw!.getUint8(index), greaterThan(240));
      expect(raw.getUint8(index + 1), greaterThan(240));
      expect(raw.getUint8(index + 2), greaterThan(240));
    }
    final bytes = png!.buffer.asUint8List();
    final dir = Directory('build/quote-frame-preview')..createSync(recursive: true);
    File('${dir.path}/white-wall-build6.png').writeAsBytesSync(bytes);
    final preview = img.encodeJpg(img.decodeImage(bytes)!, quality: 86);
    // The CI log offers a compact, directly inspectable render for this fix.
    print('QUOTE_PREVIEW_BASE64:${base64Encode(preview)}');
    image.dispose();
    });
  });
}
