import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';
import 'package:quote_app/widgets/quote_adaptive_frame.dart';
import 'package:quote_app/widgets/quote_art_layout.dart';
import 'package:quote_app/widgets/quote_calligraphy_text.dart';
import 'package:quote_app/widgets/quote_portrait_cutout.dart';
import 'package:quote_app/services/quote_calligraphy_settings.dart';

const quote =
    '你的大脑分不清现实和想象的区别，因此你可以先在内心模拟自己想成为的样子。当你在脑海中一遍遍练习变得轻松、冷静和包容，你就更容易在现实中真的那样去做。';
const author =
    '— Tal Ben-Shahar, Harvard Positive Psychology (Happiness) Course';
const note = '在脑海中练习如何面对困难，观察自己的身体、情绪与行动，再在现实中检验这些想象。想象不能取代现实行动。';
const export = bool.fromEnvironment('QUOTE_ART_PREVIEW');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'original author suffix punctuation is preserved independently of legacy citations',
    () {
      expect(
        quoteFrameAuthor('马丁·路德·金', originalAuthor: 'Martin Luther King, Jr.'),
        'Martin Luther King, Jr.',
      );
      expect(quoteFrameAuthor(author), 'Tal Ben-Shahar');
    },
  );
  setUpAll(() async {
    // Real typefaces also exercise the line fitter with proportional metrics.
    for (final face in {
      'QuoteXingShu': 'assets/fonts/ZhiMangXing-Regular.ttf',
      'QuoteKaiShu': 'assets/fonts/MaShanZheng-Regular.ttf',
      'QuoteCaoShu': 'assets/fonts/LiuJianMaoCao-Regular.ttf',
      'QuoteSignatureLatin': 'assets/fonts/Allura-Regular.ttf',
      'QuoteLiterarySerif': 'assets/fonts/LibreBaskerville-Variable.ttf',
      'QuotePlayfairDisplay': 'assets/fonts/PlayfairDisplay-Variable.ttf',
    }.entries) {
      final loader = FontLoader(face.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(File(face.value).readAsBytesSync()),
          ),
        );
      await loader.load();
    }
  });

  Future<void> mount(
    WidgetTester tester,
    double width, {
    String text = quote,
    String explanation = note,
    bool portrait = false,
    double scale = 1,
    bool animate = false,
    bool settle = true,
    String originalAuthor = '',
    String source = '',
    QuoteEnglishFontStyle englishFontStyle = QuoteEnglishFontStyle.baskerville,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, width * 1.5));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: export ? 'QuoteKaiShu' : null),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, width * 1.5),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(
              key: const ValueKey('preview-boundary'),
              child: PosterPureFlutter(
                topic: '成为那样的人',
                quote: text,
                author: author,
                originalAuthor: originalAuthor,
                source: source,
                note: explanation,
                animateCalligraphy: animate,
                avatar: portrait ? 'assets/avatars/talbenshahar .jpeg' : '',
                englishFontStyle: englishFontStyle,
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder bodyLines() => find.descendant(
    of: find.byKey(const ValueKey('quote-body')),
    matching: find.byType(Text),
  );
  Iterable<TextSpan> spans(TextSpan span) sync* {
    yield span;
    for (final child in span.children ?? <InlineSpan>[]) {
      if (child is TextSpan) yield* spans(child);
    }
  }

  for (final width in [240.0, 320.0, 360.0, 412.0, 620.0]) {
    testWidgets('large complete lines stay inside paper at width $width', (
      tester,
    ) async {
      await mount(tester, width, portrait: true);
      final frame = tester.getRect(find.byType(QuoteAdaptiveFrame));
      final paper = QuoteAdaptiveFrame.scaleRect(
        QuoteAdaptiveFrame.textSafeRect,
        frame.size,
      ).shift(frame.topLeft);
      final signature = tester.getRect(
        find.byKey(const ValueKey('quote-author')),
      );
      final viewport = tester.getRect(
        find.byKey(const ValueKey('quote-portrait-viewport')),
      );
      for (final element in bodyLines().evaluate()) {
        final line = find.byWidget(element.widget);
        final rect = tester.getRect(line);
        expect(rect.top, greaterThanOrEqualTo(paper.top - .5));
        expect(rect.bottom, lessThanOrEqualTo(signature.top));
        expect(rect.left, greaterThanOrEqualTo(paper.left + 11.5));
        expect(rect.right, lessThanOrEqualTo(paper.right - 11.5));
        expect(rect.overlaps(viewport), isFalse);
        expect(
          tester.renderObject<RenderParagraph>(line).didExceedMaxLines,
          isFalse,
        );
      }
      expect(signature.bottom, lessThanOrEqualTo(paper.bottom - 26));
      expect(signature.right, lessThanOrEqualTo(paper.right - 11.5));
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'short, long and English quotes retain the same restrained 25 point ink',
    (tester) async {
      for (final text in [
        '知行合一，止于至善。',
        quote,
        List.filled(6, quote).join(),
        'No man is an island, entire of itself.',
      ]) {
        await mount(tester, 360, text: text);
        expect(bodyLines(), findsWidgets);
        for (final line in tester.widgetList<Text>(bodyLines())) {
          for (final span in spans(line.textSpan! as TextSpan)) {
            expect(span.style!.fontSize, 25);
            expect(span.style!.fontWeight, QuoteArtworkTypography.weight);
            expect(span.style!.color, QuoteArtworkTypography.ink);
          }
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'only the original-language dark signature appears on the artwork',
    (tester) async {
      await mount(
        tester,
        360,
        text: '知行合一，止于至善。',
        originalAuthor: 'Sigmund Freud',
        source: '文明及其不满',
      );
      final signature = tester.widget<QuoteAuthorSignature>(
        find.byKey(const ValueKey('quote-author')),
      );
      expect(signature.text, 'Sigmund Freud');
      expect(signature.style.color, QuoteArtworkTypography.ink);
      expect(signature.style.fontWeight, QuoteArtworkTypography.weight);
      final nativeSpan = quoteAuthorSignatureSpan(
        signature.text,
        signature.style,
      );
      expect(
        nativeSpan.children!.whereType<TextSpan>().every(
          (span) => span.style!.fontWeight == QuoteArtworkTypography.weight,
        ),
        isTrue,
      );
      expect(find.textContaining('文明及其不满'), findsNothing);
      expect(find.text(note), findsNothing);
      final bodyBottom = bodyLines()
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)).bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(
        tester.getRect(find.byKey(const ValueKey('quote-author'))).top,
        greaterThan(bodyBottom),
      );
      await tester.tap(find.byKey(const ValueKey('quote-read-more')));
      await tester.pumpAndSettle();
      expect(find.text('出处：文明及其不满'), findsOneWidget);
      expect(find.text(note), findsOneWidget);
    },
  );

  testWidgets('legacy combined attribution keeps its source only in reading', (
    tester,
  ) async {
    await mount(tester, 360, text: '千里之行，始于足下。');
    final signature = tester.widget<QuoteAuthorSignature>(
      find.byKey(const ValueKey('quote-author')),
    );
    expect(signature.text, 'Tal Ben-Shahar');
    expect(find.textContaining('Harvard'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quote-read-more')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('出处：Harvard Positive Psychology'),
      findsOneWidget,
    );
  });

  testWidgets(
    'long artwork uses a restrained excerpt without page numbers or swiping',
    (tester) async {
      final complete = List.filled(3, quote).join();
      await mount(tester, 360, text: complete, portrait: true);
      expect(find.byType(PageView), findsNothing);
      expect(find.byKey(const ValueKey('quote-page-count')), findsNothing);
      final visible = tester
          .widgetList<Text>(bodyLines())
          .map((line) => line.textSpan!.toPlainText())
          .join();
      expect(visible.endsWith('…'), isTrue);
      expect(
        complete.startsWith(visible.substring(0, visible.length - 1)),
        isTrue,
      );
      expect(visible.length, greaterThan(30));
      await tester.tap(find.byKey(const ValueKey('quote-read-more')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('quote-reader-body')))
            .data,
        complete,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the excerpt stays still across rebuilds and a new quote appears immediately',
    (tester) async {
      final long = List.filled(3, quote).join();
      await mount(tester, 360, text: long);
      final before = tester
          .widgetList<Text>(bodyLines())
          .map((line) => line.textSpan!.toPlainText())
          .join();
      await mount(tester, 360, text: long, originalAuthor: 'Tal Ben-Shahar');
      expect(
        tester
            .widgetList<Text>(bodyLines())
            .map((line) => line.textSpan!.toPlainText())
            .join(),
        before,
      );
      await mount(tester, 360, text: '知行合一。', settle: false);
      expect(
        tester
            .widgetList<Text>(bodyLines())
            .map((line) => line.textSpan!.toPlainText())
            .join(),
        '知行合一。',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the signature has a leading rule and moves with its composition',
    (tester) async {
      await mount(tester, 400, text: '看见此刻。', originalAuthor: 'Sigmund Freud');
      final short = tester.getRect(
        find.byKey(const ValueKey('quote-author-region')),
      );
      expect(
        find.byKey(const ValueKey('quote-signature-rule')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('quote-signature-rule')))
            .width,
        20,
      );
      await mount(
        tester,
        400,
        text: List.filled(3, quote).join(),
        originalAuthor: 'Sigmund Freud',
      );
      final long = tester.getRect(
        find.byKey(const ValueKey('quote-author-region')),
      );
      expect(short.top, isNot(closeTo(long.top, 1)));
      expect(short.left, isNot(closeTo(long.left, 1)));
      final frame = tester.getRect(find.byType(QuoteAdaptiveFrame));
      final paper = QuoteAdaptiveFrame.scaleRect(
        QuoteAdaptiveFrame.textSafeRect,
        frame.size,
      ).shift(frame.topLeft);
      expect(long.right, lessThanOrEqualTo(paper.right - 12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected English face and ink writing keep the fixed type size',
    (tester) async {
      await mount(
        tester,
        360,
        text: 'No man is an island, entire of itself.',
        englishFontStyle: QuoteEnglishFontStyle.playfairDisplay,
      );
      final families = tester
          .widgetList<Text>(bodyLines())
          .expand((line) => spans(line.textSpan! as TextSpan))
          .map((span) => span.style?.fontFamily)
          .toSet();
      expect(families, contains(quotePlayfairDisplayFont));
      await mount(tester, 360, animate: true);
      for (final line in tester.widgetList<CalligraphyWritingText>(
        find.byType(CalligraphyWritingText),
      )) {
        expect(line.style.fontSize, 25);
        expect(line.overflow, TextOverflow.visible);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full reader keeps complete text and accessible non-calligraphy typography',
    (tester) async {
      final longQuote = List.filled(8, quote).join();
      final longNote = List.filled(10, note).join();
      await mount(
        tester,
        320,
        text: longQuote,
        explanation: longNote,
        scale: 2,
      );
      await tester.tap(find.byKey(const ValueKey('quote-read-more')));
      await tester.pumpAndSettle();
      final body = tester.widget<Text>(
        find.byKey(const ValueKey('quote-reader-body')),
      );
      expect(body.data, longQuote);
      expect(body.textSpan, isNull);
      expect(body.style?.fontFamily, isNull);
      expect(find.text(longNote), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  if (export) {
    for (final entry in {
      'short': '知行合一，止于至善。',
      'medium': '在隆冬之中，我终于在自己内心发现了一个不可战胜的夏天。',
      'long': quote,
    }.entries) {
      testWidgets('export ${entry.key} artwork', (tester) async {
        await mount(tester, 400, text: entry.value, portrait: true);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('preview-boundary')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/quote-frame-preview')
            ..createSync(recursive: true);
          File(
            '${dir.path}/${entry.key}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }

  testWidgets('all portraits retain the same clipped proportions', (
    tester,
  ) async {
    const sources = [
      'assets/avatars/talbenshahar .jpeg',
      'assets/avatars/Albert_Camus_1945_(cropped).jpg',
      'assets/avatars/250px-William_James_b1842c.jpg',
      'assets/avatars/schopenhauer.jpg',
    ];
    await tester.binding.setSurfaceSize(const Size(420, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
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
    );
    await tester.pumpAndSettle();
    final viewports = find.byKey(const ValueKey('quote-portrait-viewport'));
    expect(viewports, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      expect(tester.getSize(viewports.at(i)), const Size(78, 100));
    }
    expect(
      find.descendant(of: viewports, matching: find.byType(ClipRect)),
      findsNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });
}
