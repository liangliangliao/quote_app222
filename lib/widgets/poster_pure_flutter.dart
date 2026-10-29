import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/quote_calligraphy_settings.dart';
import '../models/quote_insight.dart';
import 'quote_reading_insights.dart';
import 'quote_adaptive_frame.dart';
import 'quote_calligraphy_text.dart';
import 'quote_portrait_cutout.dart';

ImageProvider? _posterAvatar(String raw) {
  if (raw.startsWith('data:')) {
    try { return MemoryImage(base64Decode(raw.substring(raw.indexOf(',') + 1))); }
    catch (_) { return null; }
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) return NetworkImage(raw);
  if (raw.startsWith('assets/')) return AssetImage(raw);
  if (raw.startsWith('/')) return FileImage(File(raw));
  return null;
}

/// Measure the real painting bounds before placing text. No foreground masks
/// or remembered scroll offsets can obscure the first or last line.
class PosterPureFlutter extends StatelessWidget {
  const PosterPureFlutter({
    super.key, required this.topic, required this.quote, required this.author,
    required this.note, required this.avatar,
    this.woodBgAsset = QuoteAdaptiveFrame.defaultBackgroundAsset, this.aiFramePath,
    this.animateCalligraphy = false,
    this.calligraphyStyle = QuoteCalligraphyStyle.xingshu,
    this.englishFontStyle = QuoteEnglishFontStyle.baskerville,
    this.quoteReference,
  });
  final String topic, quote, author, note, avatar, woodBgAsset;
  final String? aiFramePath;
  final bool animateCalligraphy;
  final QuoteCalligraphyStyle calligraphyStyle;
  final QuoteEnglishFontStyle englishFontStyle;
  final QuoteReference? quoteReference;

  void _openReading(BuildContext context) {
    final readingQuoteStyle = quotePrefersLiteraryEnglish(quote)
        ? quoteLiteraryTextStyle(
            const TextStyle(fontSize: 21, height: 1.65),
          )
        : const TextStyle(
            fontSize: 21,
            height: 1.65,
            fontWeight: FontWeight.w600,
          );
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white, showDragHandle: true,
      builder: (context) => SafeArea(top: false, child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .80,
        child: SingleChildScrollView(
          key: const ValueKey('quote-full-reading'),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: SelectionArea(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topic.trim().isNotEmpty) ...[
                Text(topic,
                    style: const TextStyle(fontSize: 20, height: 1.5)),
                const SizedBox(height: 20),
              ],
              Text(quote, style: readingQuoteStyle),
              if (author.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                QuoteAuthorSignature(author,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
              if (note.trim().isNotEmpty) ...[
                const SizedBox(height: 26),
                const Text('解读 · 一种理解', style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 8),
                Text(note, style: const TextStyle(fontSize: 17, height: 1.7)),
              ],
              QuoteReadingInsights(quote: quoteReference ?? QuoteReference(id: '', content: quote)),
            ],
          )),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620),
    child: AspectRatio(aspectRatio: 2 / 3,
      child: LayoutBuilder(builder: (context, constraints) {
        final fullPaper = QuoteAdaptiveFrame.scaleRect(
          QuoteAdaptiveFrame.textSafeRect, constraints.biggest);
        final hasArtwork = aiFramePath?.trim().isNotEmpty ?? false;
        final reservedScene = hasArtwork
            ? fullPaper.height * (quote.runes.length > 80 ? .18 : .25) : 0.0;
        final paper = Rect.fromLTRB(fullPaper.left, fullPaper.top,
            fullPaper.right, fullPaper.bottom - reservedScene);
        return Stack(fit: StackFit.expand, children: [
          QuoteAdaptiveFrame(backgroundAsset: woodBgAsset,
            aiImagePath: aiFramePath, quoteCharacters: quote.runes.length),
          Positioned.fromRect(rect: paper, child: _PaperComposition(
            quote: quote, author: author, avatar: avatar,
            animateCalligraphy: animateCalligraphy,
            calligraphyStyle: calligraphyStyle,
            englishFontStyle: englishFontStyle,
            onRead: () => _openReading(context))),
        ]);
      }),
    ),
  ));
}

class _PaperComposition extends StatelessWidget {
  const _PaperComposition({
    required this.quote, required this.author,
    required this.avatar, required this.onRead,
    required this.animateCalligraphy, required this.calligraphyStyle,
    required this.englishFontStyle,
  });
  final String quote, author, avatar;
  final VoidCallback onRead;
  final bool animateCalligraphy;
  final QuoteCalligraphyStyle calligraphyStyle;
  final QuoteEnglishFontStyle englishFontStyle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, bounds) {
          final width = bounds.maxWidth;
          final height = bounds.maxHeight;
          final portrait = _posterAvatar(avatar.trim());
          final hasAvatar = portrait != null;
          final isLiteraryEnglish = quotePrefersLiteraryEnglish(quote);
          final direction = Directionality.of(context);
          final baseStyle = DefaultTextStyle.of(context).style;
          final gap = (width * .041).clamp(5.0, 12.0).toDouble();
          final authorStyle = baseStyle.copyWith(
            fontSize: (width * .050).clamp(9.0, 15.0),
            height: 1.4,
            color: const Color(0xff544b44),
            fontWeight: FontWeight.w600,
          );
          final footerStyle = baseStyle.copyWith(
            fontSize: (width * .047).clamp(9.0, 14.0),
            height: 1.5,
            color: const Color(0xff625c55),
            fontWeight: FontWeight.w600,
          );

          double measureSpan(
            InlineSpan span,
            double maxWidth, {
            int? maxLines,
          }) {
            final painter = TextPainter(
              text: span,
              textDirection: direction,
              textScaler: TextScaler.noScaling,
              maxLines: maxLines,
              ellipsis: maxLines == null ? null : '…',
            )..layout(maxWidth: maxWidth);
            final result = painter.height;
            painter.dispose();
            return result;
          }

          // The portrait keeps its fixed clipped window. It reserves only its
          // own top band; short quotations can still centre naturally below it.
          final portraitWidth = (width * .275).clamp(46.0, 88.0).toDouble();
          final portraitHeight = portraitWidth / .78;
          final topReserve = hasAvatar ? portraitHeight + gap : 0.0;
          final footerHeight =
              (width * .105).clamp(22.0, 30.0).toDouble();
          final contentHeight =
              math.max(1.0, height - topReserve - footerHeight);
          final hasAuthor = author.trim().isNotEmpty;
          final authorSpan = quoteAuthorSignatureSpan(author, authorStyle);
          final authorHeight = hasAuthor
              ? measureSpan(authorSpan, width, maxLines: 3)
              : 0.0;
          final authorGap = hasAuthor ? gap : 0.0;
          final quoteCapacity =
              math.max(1.0, contentHeight - authorHeight - authorGap);

          var quoteSize = isLiteraryEnglish
              ? (width * .078).clamp(14.0, 25.0).toDouble()
              : (width * .091).clamp(15.0, 29.0).toDouble();
          final minimumSize = isLiteraryEnglish
              ? (width * .057).clamp(11.5, 17.5).toDouble()
              : (width * .067).clamp(12.0, 19.5).toDouble();

          TextStyle quoteBaseStyle() {
            return baseStyle.copyWith(
              fontSize: quoteSize,
              height: 1.47,
              letterSpacing: .45,
              fontWeight: FontWeight.w800,
              color: const Color(0xff25211d),
            );
          }

          TextSpan quoteSpan([String? text]) => quoteBodyTextSpan(
                text ?? quote,
                quoteBaseStyle(),
                calligraphyStyle,
                englishFontStyle,
              );

          while (quoteSize > minimumSize &&
              measureSpan(quoteSpan(), width) > quoteCapacity) {
            quoteSize = math.max(minimumSize, quoteSize - .25);
          }

          final fullQuoteHeight = measureSpan(quoteSpan(), width);
          final lineProbe = isLiteraryEnglish ? 'Ag' : '名言';
          final quoteLineHeight = measureSpan(quoteSpan(lineProbe), width);
          final quoteLines = fullQuoteHeight <= quoteCapacity + .5
              ? null
              : math.max(1, (quoteCapacity / quoteLineHeight).floor());
          final quoteHeight =
              measureSpan(quoteSpan(), width, maxLines: quoteLines);
          final blockHeight = quoteHeight + authorGap + authorHeight;
          final blockTop = topReserve +
              math.max(0.0, (contentHeight - blockHeight) / 2);

          Widget quoteBody() {
            if (animateCalligraphy) {
              return CalligraphyWritingText(
                key: const ValueKey('quote-body'),
                text: quote,
                maxLines: quoteLines,
                overflow: quoteLines == null
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: quoteBaseStyle(),
                calligraphyStyle: calligraphyStyle,
                englishFontStyle: englishFontStyle,
              );
            }
            return Text.rich(
              quoteSpan(),
              key: const ValueKey('quote-body'),
              maxLines: quoteLines,
              overflow: quoteLines == null
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            );
          }

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (hasAvatar)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: QuotePortraitCutout(
                      image: portrait!,
                      width: portraitWidth,
                      height: portraitHeight,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: blockTop,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      quoteBody(),
                      if (hasAuthor) ...[
                        SizedBox(height: authorGap),
                        QuoteAuthorSignature(
                          author,
                          key: const ValueKey('quote-author'),
                          textAlign: TextAlign.right,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: authorStyle,
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: footerHeight,
                  child: Align(
                    key: const ValueKey('quote-read-more-region'),
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      key: const ValueKey('quote-read-more'),
                      onTap: onRead,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '阅读全文与解读  ›',
                          style: footerStyle.copyWith(
                            fontSize: math.min(
                              12.0,
                              footerStyle.fontSize!,
                            ),
                            color: const Color(0xff776a5d),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
