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
    Size signature = const Size(128, 28),
  }) => QuoteArtLayout.compose(
    text: text,
    size: size,
    signatureSize: signature,
    hasPortrait: portrait,
    direction: TextDirection.ltr,
    span: (text, spacing) => quoteBodyTextSpan(
      text,
      TextStyle(
        fontSize: QuoteArtworkTypography.bodySize,
        height: 1.2,
        letterSpacing: spacing,
        color: QuoteArtworkTypography.ink,
        fontWeight: QuoteArtworkTypography.weight,
      ),
      QuoteCalligraphyStyle.xingshu,
    ),
  );
  String normalize(String value) => value.replaceAll(RegExp(r'\s+'), '');

  test(
    'short sayings, prose and verse keep distinct balanced compositions',
    () {
      final short = compose('知行合一。');
      final prose = compose('人生的价值，在于不断发现自己，理解自己，并在每一个当下付诸行动。');
      final verse = compose('山川依旧\n春风又绿\n此刻出发');
      expect(short.lines.single.align, TextAlign.center);
      expect(prose.lines.first.align, TextAlign.start);
      expect(verse.lines.map((line) => line.text), ['山川依旧', '春风又绿', '此刻出发']);
      expect(
        verse.lines.every((line) => line.align == TextAlign.center),
        isTrue,
      );
      expect(
        short.lines.first.rect.top,
        greaterThan(prose.lines.first.rect.top),
      );
      expect(short.contentBounds.left, greaterThan(prose.contentBounds.left));
      expect(short.leading, greaterThan(prose.leading));
    },
  );

  test('long quotations become a genuine prefix with one fitted ellipsis', () {
    final text = List.filled(12, '愿你看见自己，也看见世界；不急于答案，仍向前走。').join();
    final layout = compose(text, portrait: true);
    final visible = layout.lines.map((l) => l.text).join();
    expect(layout.isTruncated, isTrue);
    expect(visible.endsWith('…'), isTrue);
    expect('…'.allMatches(visible).length, 1);
    expect(text.startsWith(visible.substring(0, visible.length - 1)), isTrue);
    expect(visible.length, greaterThan(24));
    for (final line in layout.lines) {
      expect(RegExp(r'^[，。！？；：、]').hasMatch(line.text), isFalse);
      expect(RegExp(r'[（「『《]$').hasMatch(line.text), isFalse);
      expect(line.rect.left, greaterThanOrEqualTo(layout.contentBounds.left));
      expect(
        line.rect.bottom,
        lessThanOrEqualTo(layout.contentBounds.bottom + .01),
      );
      expect(line.rect.overlaps(layout.portrait!), isFalse);
    }
  });

  test(
    'portrait space is shared with long prose and spared for short sayings',
    () {
      final short = compose('看见此刻。', portrait: true);
      final long = compose(
        List.filled(4, '不要因为路途遥远，就忘记出发时的勇气。').join(),
        portrait: true,
      );
      expect(short.lines.first.rect.top, greaterThan(short.portrait!.bottom));
      expect(long.lines.first.rect.top, lessThan(long.portrait!.bottom));
      expect(long.lines.first.rect.right, lessThan(long.portrait!.left));
    },
  );

  test(
    'signatures follow the text ending and keep their own frame margins',
    () {
      final short = compose('看见此刻。');
      final medium = compose('我们反抗，故我们存在。每一个选择，都让我们更接近自己。');
      final long = compose(List.filled(5, '将注意力还给此刻，让行动自己说话。').join());
      expect(
        short.signatureRect.top,
        isNot(closeTo(long.signatureRect.top, 1)),
      );
      expect(
        short.signatureRect.left,
        isNot(closeTo(medium.signatureRect.left, 1)),
      );
      for (final layout in [short, medium, long]) {
        expect(layout.signatureRect.left, greaterThanOrEqualTo(12));
        expect(layout.signatureRect.right, lessThanOrEqualTo(245 - 12));
        expect(
          layout.signatureRect.top,
          greaterThan(layout.lines.last.rect.bottom + 10),
        );
        expect(layout.signatureRect.bottom, lessThan(layout.footerRect.top));
      }
      final pending = compose('让想法在行动中生根。', signature: const Size(50, 27));
      final resolved = compose('让想法在行动中生根。', signature: const Size(145, 52));
      expect(
        pending.lines.map((l) => l.rect),
        resolved.lines.map((l) => l.rect),
      );
    },
  );

  test('quote and signature use spare vertical space as one centred group', () {
    final samples = ['知行合一。', '给自己一些耐心，让每一个选择，都有重新开始的可能。',
      List.filled(6, '在行动中认识自己，让重要的事情慢慢发生。').join()];
    for (final text in samples) {
      for (final portrait in [false, true]) {
        final layout = compose(text, portrait: portrait);
        final belowPortrait = portrait && layout.lines.first.rect.top > layout.portrait!.bottom;
        final readingTop = belowPortrait ? layout.portrait!.bottom + 12 : layout.contentBounds.top;
        final availableCentre = (readingTop + layout.footerRect.top - 10) / 2;
        final visualCentre = (layout.lines.first.rect.top + layout.signatureRect.bottom) / 2;
        expect((visualCentre - availableCentre).abs(), lessThan(16));
      }
    }
  });

  test('a short phrase ending is not stranded before a Chinese comma', () {
    const text = '现实和想象的区别，因此每一个真实的行动都值得被认真地看见。';
    final layout = compose(text);
    expect(layout.lines.any((line) => RegExp(r'^[\u3400-\u9fff][，。；]').hasMatch(line.text)), isFalse);
    expect(text.startsWith(layout.lines.map((line) => line.text).join().replaceAll('…', '')), isTrue);
  });

  test('English words and complete multilingual graphemes remain intact', () {
    const english =
        'No man is an island, entire of itself. Every man is a piece of the continent.';
    final layout = compose(english, size: const Size(420, 365));
    expect(layout.isTruncated, isFalse);
    expect(
      layout.lines.map((l) => l.text).join(' ').split(RegExp(r'\s+')),
      english.split(' '),
    );
    const multilingual = '“Courage” 👨‍👩‍👧‍👦 是在害怕时，仍愿意向前走。';
    final mixed = compose(multilingual);
    expect(
      normalize(mixed.lines.map((l) => l.text).join()),
      normalize(multilingual),
    );
    expect(compose('').lines, isEmpty);
  });

  test(
    'moderate size and ink weight stay consistent across brush and Latin faces',
    () {
      const base = TextStyle(
        fontSize: 23,
        color: QuoteArtworkTypography.ink,
        fontWeight: FontWeight.w500,
      );
      for (final style in QuoteCalligraphyStyle.values) {
        final span = quoteBodyTextSpan('知行 Truth', base, style);
        for (final child in span.children!.whereType<TextSpan>()) {
          expect(child.style!.fontSize, 23);
          expect(child.style!.fontWeight, FontWeight.w500);
          expect(child.style!.color, QuoteArtworkTypography.ink);
        }
      }
    },
  );
}
