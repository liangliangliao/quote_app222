import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/quote_calligraphy_settings.dart';
import 'package:quote_app/widgets/quote_calligraphy_text.dart';

void main() {
  test('calligraphy preferences are opt-in and fall back to xingshu', () {
    const preferences = QuoteCalligraphyPreferences();

    expect(preferences.animationEnabled, isFalse);
    expect(preferences.style, QuoteCalligraphyStyle.xingshu);
    expect(
      QuoteCalligraphyStyle.parse('unknown'),
      QuoteCalligraphyStyle.xingshu,
    );
    expect(
      QuoteCalligraphyStyle.parse('kaishu'),
      QuoteCalligraphyStyle.kaishu,
    );
    expect(
      QuoteCalligraphyStyle.parse('caoshu'),
      QuoteCalligraphyStyle.caoshu,
    );
  });

  test('mixed author signature preserves every character and its order', () {
    const source = '— 王阳明 Wang Yangming，《传习录》';
    final span = quoteAuthorSignatureSpan(
      source,
      const TextStyle(fontSize: 14),
    );

    expect(span.toPlainText(), source);
    final families = span.children!
        .whereType<TextSpan>()
        .map((child) => child.style?.fontFamily)
        .toSet();
    expect(families, contains(quoteChineseSignatureFont));
    expect(families, contains(quoteLatinSignatureFont));
    expect(
      span.children!
          .whereType<TextSpan>()
          .map((child) => child.style?.fontWeight)
          .toSet(),
      {FontWeight.w500},
    );
  });

  test('each body style resolves to its dedicated bundled typeface', () {
    const base = TextStyle(fontSize: 20);

    for (final style in QuoteCalligraphyStyle.values) {
      final resolved = quoteCalligraphyTextStyle(base, style);
      expect(resolved.fontFamily, style.fontFamily);
      expect(resolved.fontWeight, FontWeight.w500);
    }
  });

  test('English quotations use the classical literary serif face', () {
    expect(
      quotePrefersLiteraryEnglish(
        'No man is an island, entire of itself; every man is a piece of the continent.',
      ),
      isTrue,
    );
    expect(quotePrefersLiteraryEnglish('知行合一，止于至善。'), isFalse);
    final style = quoteLiteraryTextStyle(const TextStyle(fontSize: 20));
    expect(style.fontFamily, quoteLiterarySerifFont);
    expect(style.fontWeight, FontWeight.w600);
  });

  testWidgets('writing reveal keeps final paragraph geometry stable',
      (tester) async {
    const key = ValueKey('animated-calligraphy');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: CalligraphyWritingText(
                key: key,
                text: '心有山海，静而不争。千里之行，始于足下。',
                style: quoteCalligraphyTextStyle(
                  const TextStyle(fontSize: 24),
                  QuoteCalligraphyStyle.xingshu,
                ),
                calligraphyStyle: QuoteCalligraphyStyle.xingshu,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    final initial = tester.getSize(find.byKey(key));
    await tester.pump(const Duration(seconds: 10));
    final completed = tester.getSize(find.byKey(key));

    expect(initial, completed);
    expect(initial.height, greaterThan(0));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
