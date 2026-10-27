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
import 'package:quote_app/widgets/quote_portrait_cutout.dart';
import 'package:quote_app/widgets/quote_calligraphy_text.dart';
import 'package:quote_app/services/quote_calligraphy_settings.dart';

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
    QuoteEnglishFontStyle englishFontStyle =
        QuoteEnglishFontStyle.baskerville,
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
            child: ColoredBox(color: Colors.white, child: PosterPureFlutter(
              topic: '成为那样的人', quote: text, author: author,
              note: explanation,
              avatar: portrait ? 'assets/avatars/talbenshahar .jpeg' : '',
              englishFontStyle: englishFontStyle,
            ))),
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

  testWidgets('topic and explanation stay out of the framed artwork',
      (tester) async {
    await mount(tester, 360, text: '知行合一，止于至善。');

    expect(find.text('成为那样的人'), findsNothing);
    expect(find.text(note), findsNothing);
    expect(find.byKey(const ValueKey('quote-topic')), findsNothing);
    expect(find.byKey(const ValueKey('quote-note')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await tester.pumpAndSettle();

    final reader = find.byKey(const ValueKey('quote-full-reading'));
    expect(find.descendant(of: reader, matching: find.text('成为那样的人')),
        findsOneWidget);
    expect(find.descendant(of: reader, matching: find.text(note)),
        findsOneWidget);
  });

  testWidgets('full reader keeps the original non-calligraphy typography',
      (tester) async {
    const mixedQuote =
        '真理发生于一个观念，它因事件而成为真理。 Truth happens to an idea.';
    await mount(tester, 360, text: mixedQuote);

    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await tester.pumpAndSettle();

    final reader = find.byKey(const ValueKey('quote-full-reading'));
    final quoteFinder = find.descendant(
      of: reader,
      matching: find.text(mixedQuote),
    );
    expect(quoteFinder, findsOneWidget);
    final quoteWidget = tester.widget<Text>(quoteFinder);
    expect(quoteWidget.data, mixedQuote);
    expect(quoteWidget.textSpan, isNull);
    expect(quoteWidget.style?.fontFamily, isNull);
  });

  testWidgets('selected English font is applied to the home artwork',
      (tester) async {
    const englishQuote = 'No man is an island, entire of itself.';
    await mount(
      tester,
      360,
      text: englishQuote,
      englishFontStyle: QuoteEnglishFontStyle.playfairDisplay,
    );

    final body = tester.widget<Text>(
      find.byKey(const ValueKey('quote-body')),
    );
    final families = (body.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .map((span) => span.style?.fontFamily)
        .toSet();
    expect(families, contains(quotePlayfairDisplayFont));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short quotation and attribution are vertically balanced',
      (tester) async {
    await mount(tester, 360, text: '知行合一，止于至善。');

    final frame = tester.getRect(find.byType(QuoteAdaptiveFrame));
    final paper = QuoteAdaptiveFrame.scaleRect(
      QuoteAdaptiveFrame.textSafeRect,
      frame.size,
    ).shift(frame.topLeft);
    final footer = tester.getRect(
      find.byKey(const ValueKey('quote-read-more-region')),
    );
    final body = tester.getRect(find.byKey(const ValueKey('quote-body')));
    final attribution =
        tester.getRect(find.byKey(const ValueKey('quote-author')));
    final contentMidpoint = (paper.top + footer.top) / 2;
    final artworkMidpoint = (body.top + attribution.bottom) / 2;

    expect(artworkMidpoint, closeTo(contentMidpoint, 1.5));
    expect(body.top, greaterThanOrEqualTo(paper.top));
    expect(attribution.bottom, lessThanOrEqualTo(footer.top));
    expect(tester.takeException(), isNull);
  });

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
    // Pump between native stages: provider resolve, pixel readback, isolate
    // matting and PNG encoding each completes on a different event turn.
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      if (find.byKey(const ValueKey('quote-portrait-composited')).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
    final composited = find.byKey(const ValueKey('quote-portrait-composited'));
    expect(composited, findsOneWidget);
    final portrait = tester.widget<Image>(composited);
    await tester.runAsync(() => precacheImage(portrait.image, tester.element(composited)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final viewport = tester.getRect(
      find.byKey(const ValueKey('quote-portrait-viewport')));
    expect(viewport.width, greaterThanOrEqualTo(68));
    expect(viewport.width / viewport.height, closeTo(.78, .001));
    expect(tester.getRect(composited), viewport,
      reason: 'The source image must fill exactly the clipped safe viewport');
    expect(find.descendant(
      of: find.byKey(const ValueKey('quote-portrait-viewport')),
      matching: find.byType(ClipRect)),
      findsOneWidget,
      reason: 'The clip must contain the image and both edge-blend shaders');
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
    File('${dir.path}/white-wall-build7.png').writeAsBytesSync(bytes);
    final preview = img.encodeJpg(img.decodeImage(bytes)!, quality: 86);
    // The CI log offers a compact, directly inspectable render for this fix.
    print('QUOTE_PREVIEW_BASE64:${base64Encode(preview)}');
    image.dispose();
    });
  });

  testWidgets('all portrait sources use one fixed clipped window', (tester) async {
    const sources = [
      'assets/avatars/talbenshahar .jpeg',
      'assets/avatars/Albert_Camus_1945_(cropped).jpg',
      'assets/avatars/250px-William_James_b1842c.jpg',
      'assets/avatars/schopenhauer.jpg',
    ];
    await tester.binding.setSurfaceSize(const Size(420, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        key: const ValueKey('portrait-grid-boundary'),
        child: ColoredBox(
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final source in sources)
                QuotePortraitCutout(
                  image: AssetImage(source),
                  width: 78,
                  height: 100,
                ),
            ],
          ),
        ),
      ),
    )));
    await tester.pump();
    final portraitContext = tester.element(find.byType(QuotePortraitCutout).first);
    await tester.runAsync(() async {
      for (final source in sources) {
        await precacheImage(AssetImage(source), portraitContext);
      }
    });
    await tester.pumpAndSettle();
    final viewports = find.byKey(const ValueKey('quote-portrait-viewport'));
    expect(viewports, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      expect(tester.getSize(viewports.at(i)), const Size(78, 100));
    }
    final clips = find.descendant(of: viewports, matching: find.byType(ClipRect));
    expect(clips, findsNWidgets(4));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('portrait-grid-boundary')));
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/quote-frame-preview')
        ..createSync(recursive: true);
      File('${dir.path}/fixed-portrait-grid-build7.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  });
}
