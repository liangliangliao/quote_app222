import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/widgets/quote_art_layout.dart';
import 'package:quote_app/widgets/quote_calligraphy_text.dart';
import 'package:quote_app/services/quote_calligraphy_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  QuoteArtLayout compose(
    String text, {
    bool portrait = false,
    Size size = const Size(245, 365),
  }) => QuoteArtLayout.compose(
    text: text,
    size: size,
    signatureHeight: 30,
    hasPortrait: portrait,
    direction: TextDirection.ltr,
    span: (text, spacing) => quoteBodyTextSpan(
      text,
      TextStyle(
        fontSize: 32,
        height: 1.2,
        letterSpacing: spacing,
        color: QuoteArtworkTypography.ink,
        fontWeight: QuoteArtworkTypography.weight,
      ),
      QuoteCalligraphyStyle.xingshu,
    ),
  );

  test(
    'short sayings, prose and verse have distinct measured compositions',
    () {
      final short = compose('知行合一。');
      final prose = compose('人生的价值，在于不断发现自己，理解自己，并在每一个当下付诸行动。');
      final verse = compose('山川依旧\n春风又绿\n此刻出发');
      expect(short.pages.single.lines.single.align, TextAlign.center);
      expect(prose.pages.first.lines.first.align, TextAlign.start);
      expect(verse.pages.single.lines.map((line) => line.text), [
        '山川依旧',
        '春风又绿',
        '此刻出发',
      ]);
      expect(
        verse.pages.single.lines.every(
          (line) => line.align == TextAlign.center,
        ),
        isTrue,
      );
      expect(
        short.pages.first.lines.first.rect.top,
        greaterThan(prose.pages.first.lines.first.rect.top),
      );
      expect(short.leading, greaterThan(prose.leading));
    },
  );

  test(
    'long text preserves characters, graphemes and punctuation over pages',
    () {
      final text = List.filled(12, '愿你看见自己，也看见世界；不急于答案，仍向前走。').join();
      final layout = compose(text, portrait: true);
      expect(layout.pages.length, greaterThan(1));
      expect(
        layout.pages.expand((p) => p.lines).map((l) => l.text).join(),
        text,
      );
      for (final page in layout.pages) {
        for (final line in page.lines) {
          expect(RegExp(r'^[，。！？；：、]').hasMatch(line.text), isFalse);
          expect(RegExp(r'[（「『《]$').hasMatch(line.text), isFalse);
          expect(
            line.rect.bottom,
            lessThanOrEqualTo(layout.signatureTop - 17 + .01),
          );
          if (page.portrait != null)
            expect(line.rect.overlaps(page.portrait!), isFalse);
        }
      }
      final multilingual = compose('“Courage” 👨‍👩‍👧‍👦 是在害怕时，仍愿意向前走。');
      expect(
        multilingual.pages
            .expand((p) => p.lines)
            .map((l) => l.text)
            .join()
            .replaceAll(' ', ''),
        '“Courage” 👨‍👩‍👧‍👦 是在害怕时，仍愿意向前走。'.replaceAll(' ', ''),
      );
    },
  );

  test(
    'portrait space is shared with long prose and spared for short sayings',
    () {
      final short = compose('看见此刻。', portrait: true);
      final long = compose(
        List.filled(4, '不要因为路途遥远，就忘记出发时的勇气。').join(),
        portrait: true,
      );
      expect(
        short.pages.first.lines.first.rect.top,
        greaterThan(short.pages.first.portrait!.bottom),
      );
      final first = long.pages.first;
      expect(first.lines.first.rect.top, lessThan(first.portrait!.bottom));
      expect(first.lines.first.rect.right, lessThan(first.portrait!.left));
      expect(long.pages.skip(1).every((p) => p.portrait == null), isTrue);
    },
  );

  test('English words remain intact unless one word exceeds the paper width', () {
    const text =
        'No man is an island, entire of itself. Every man is a piece of the continent.';
    final layout = compose(text, size: const Size(420, 365));
    final lines = layout.pages.expand((p) => p.lines).toList();
    expect(
      lines.map((l) => l.text).join(' ').split(RegExp(r'\s+')),
      text.split(' '),
    );
    expect(compose('').pages.single.lines, isEmpty);
  });

  test('all brush styles and Latin spans honor the same size and weight', () {
    const base = TextStyle(
      fontSize: 32,
      color: QuoteArtworkTypography.ink,
      fontWeight: QuoteArtworkTypography.weight,
    );
    for (final style in QuoteCalligraphyStyle.values) {
      final span = quoteBodyTextSpan('知行 Truth', base, style);
      for (final child in span.children!.whereType<TextSpan>()) {
        expect(child.style!.fontSize, 32);
        expect(child.style!.fontWeight, QuoteArtworkTypography.weight);
        expect(child.style!.color, QuoteArtworkTypography.ink);
      }
    }
  });
}
