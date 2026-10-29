import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/quote_calligraphy_settings.dart';
import 'quote_adaptive_frame.dart';
import 'quote_art_layout.dart';
import 'quote_calligraphy_text.dart';
import 'quote_portrait_cutout.dart';

ImageProvider? _posterAvatar(String raw) {
  if (raw.startsWith('data:')) {
    try {
      return MemoryImage(base64Decode(raw.substring(raw.indexOf(',') + 1)));
    } catch (_) {
      return null;
    }
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return NetworkImage(raw);
  }
  if (raw.startsWith('assets/')) return AssetImage(raw);
  if (raw.startsWith('/')) return FileImage(File(raw));
  return null;
}

/// Older fallback/favourite records combined the author and citation. Only
/// the author belongs on the artwork; the complete citation stays in reading.
String quoteFrameAuthor(String author, {String originalAuthor = ''}) {
  if (originalAuthor.trim().isNotEmpty) {
    return originalAuthor.trim().replaceFirst(RegExp(r'^[—–\-\s]+'), '');
  }
  return author
      .trim()
      .replaceFirst(RegExp(r'^[—–\-\s]+'), '')
      .split(RegExp(r'《|,|，|\n|\(|（'))
      .first
      .trim();
}

String _legacySource(String author) {
  final value = author.trim().replaceFirst(RegExp(r'^[—–\-\s]+'), '');
  final match = RegExp(r'《|,|，|\n|\(|（').firstMatch(value);
  if (match == null) return '';
  return value
      .substring(match.start)
      .replaceFirst(RegExp(r'^[,，\s]+'), '')
      .trim();
}

class PosterPureFlutter extends StatelessWidget {
  const PosterPureFlutter({
    super.key,
    required this.topic,
    required this.quote,
    required this.author,
    required this.note,
    required this.avatar,
    this.originalAuthor = '',
    this.signaturePending = false,
    this.source = '',
    this.woodBgAsset = QuoteAdaptiveFrame.defaultBackgroundAsset,
    this.aiFramePath,
    this.animateCalligraphy = false,
    this.calligraphyStyle = QuoteCalligraphyStyle.xingshu,
    this.englishFontStyle = QuoteEnglishFontStyle.baskerville,
  });

  final String topic, quote, author, originalAuthor, source, note, avatar;
  final String woodBgAsset;
  final String? aiFramePath;
  final bool animateCalligraphy;
  final bool signaturePending;
  final QuoteCalligraphyStyle calligraphyStyle;
  final QuoteEnglishFontStyle englishFontStyle;

  void _openReading(BuildContext context) {
    final readingQuoteStyle = quotePrefersLiteraryEnglish(quote)
        ? quoteLiteraryTextStyle(const TextStyle(fontSize: 21, height: 1.65))
        : const TextStyle(
            fontSize: 21,
            height: 1.65,
            fontWeight: FontWeight.w600,
          );
    final signature = quoteFrameAuthor(author, originalAuthor: originalAuthor);
    final citation = source.trim().isNotEmpty
        ? source.trim()
        : _legacySource(author);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .80,
          child: SingleChildScrollView(
            key: const ValueKey('quote-full-reading'),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (topic.trim().isNotEmpty) ...[
                    Text(
                      topic,
                      style: const TextStyle(fontSize: 20, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    quote,
                    key: const ValueKey('quote-reader-body'),
                    style: readingQuoteStyle,
                  ),
                  if (signature.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    QuoteAuthorSignature(
                      signature,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                  if (citation.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '出处：$citation',
                      key: const ValueKey('quote-reader-source'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                  if (note.trim().isNotEmpty) ...[
                    const SizedBox(height: 26),
                    Text(
                      note,
                      style: const TextStyle(fontSize: 17, height: 1.7),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final paper = QuoteAdaptiveFrame.scaleRect(
              QuoteAdaptiveFrame.textSafeRect,
              constraints.biggest,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                QuoteAdaptiveFrame(
                  backgroundAsset: woodBgAsset,
                  aiImagePath: aiFramePath,
                  quoteCharacters: quote.runes.length,
                ),
                Positioned.fromRect(
                  rect: paper,
                  child: _PaperComposition(
                    key: ValueKey(quote),
                    quote: quote,
                    author: signaturePending
                        ? ''
                        : quoteFrameAuthor(
                            author,
                            originalAuthor: originalAuthor,
                          ),
                    avatar: avatar,
                    animateCalligraphy: animateCalligraphy,
                    calligraphyStyle: calligraphyStyle,
                    englishFontStyle: englishFontStyle,
                    onRead: () => _openReading(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _PaperComposition extends StatefulWidget {
  const _PaperComposition({
    super.key,
    required this.quote,
    required this.author,
    required this.avatar,
    required this.onRead,
    required this.animateCalligraphy,
    required this.calligraphyStyle,
    required this.englishFontStyle,
  });
  final String quote, author, avatar;
  final VoidCallback onRead;
  final bool animateCalligraphy;
  final QuoteCalligraphyStyle calligraphyStyle;
  final QuoteEnglishFontStyle englishFontStyle;

  @override
  State<_PaperComposition> createState() => _PaperCompositionState();
}

class _PaperCompositionState extends State<_PaperComposition> {
  Object? _layoutKey;
  QuoteArtLayout? _cachedLayout;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final direction = Directionality.of(context);
      final image = _posterAvatar(widget.avatar.trim());
      const signatureStyle = TextStyle(
        fontSize: QuoteArtworkTypography.signatureSize,
        fontWeight: QuoteArtworkTypography.signatureWeight,
        color: QuoteArtworkTypography.ink,
        height: 1.25,
      );
      const ruleWidth = QuoteArtworkTypography.signatureRuleWidth;
      const ruleGap = QuoteArtworkTypography.signatureRuleGap;
      final signatureInset = (bounds.maxWidth * .105).clamp(12.0, 28.0);
      final nameAvailable = math.max(
        1.0,
        bounds.maxWidth - signatureInset * 2 - ruleWidth - ruleGap,
      );
      final authorPainter = TextPainter(
        text: quoteAuthorSignatureSpan(
          widget.author.isEmpty ? 'Ag' : widget.author,
          signatureStyle,
        ),
        textDirection: direction,
        textScaler: TextScaler.noScaling,
        maxLines: 3,
      )..layout(maxWidth: nameAvailable);
      final authorLines = authorPainter.computeLineMetrics();
      final widestAuthorLine = authorLines.fold<double>(0, (width, line) => math.max(width, line.width));
      final nameWidth = math.min(nameAvailable, widestAuthorLine.ceilToDouble() + 2);
      final signatureRuleInset = authorLines.isEmpty ? 0.0 : math.max(0.0, nameWidth - authorLines.first.width);
      final signatureSize = Size(nameWidth + ruleWidth + ruleGap, authorPainter.height);
      authorPainter.dispose();
      TextStyle bodyStyle(double spacing) => TextStyle(
        fontSize: QuoteArtworkTypography.bodySize,
        height: 1.20,
        letterSpacing: spacing,
        fontWeight: QuoteArtworkTypography.weight,
        color: QuoteArtworkTypography.ink,
      );
      TextSpan bodySpan(String value, double spacing) => quoteBodyTextSpan(
        value,
        bodyStyle(spacing),
        widget.calligraphyStyle,
        widget.englishFontStyle,
      );
      final layoutKey = (
        widget.quote,
        bounds.biggest,
        signatureSize,
        image != null,
        direction,
        widget.calligraphyStyle,
        widget.englishFontStyle,
      );
      final layout = _layoutKey == layoutKey && _cachedLayout != null
          ? _cachedLayout!
          : QuoteArtLayout.compose(
              text: widget.quote,
              size: bounds.biggest,
              span: bodySpan,
              direction: direction,
              signatureSize: signatureSize,
              hasPortrait: image != null,
            );
      _layoutKey = layoutKey;
      _cachedLayout = layout;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (layout.portrait != null)
              Positioned.fromRect(
                rect: layout.portrait!,
                child: ExcludeSemantics(
                  child: QuotePortraitCutout(
                    image: image!,
                    width: layout.portrait!.width,
                    height: layout.portrait!.height,
                  ),
                ),
              ),
            Positioned.fill(
              key: const ValueKey('quote-body'),
              child: Semantics(
                label: layout.lines.map((line) => line.text).join('\n'),
                excludeSemantics: true,
                child: Stack(
                  children: [
                    for (var line = 0; line < layout.lines.length; line++)
                      Positioned.fromRect(
                        rect: layout.lines[line].rect,
                        child: widget.animateCalligraphy
                            ? CalligraphyWritingText(
                                key: ValueKey('quote-line-$line'),
                                text: layout.lines[line].text,
                                style: bodyStyle(layout.letterSpacing),
                                calligraphyStyle: widget.calligraphyStyle,
                                englishFontStyle: widget.englishFontStyle,
                                textAlign: layout.lines[line].align,
                                maxLines: 1,
                              )
                            : Text.rich(
                                bodySpan(
                                  layout.lines[line].text,
                                  layout.letterSpacing,
                                ),
                                key: ValueKey('quote-line-$line'),
                                textAlign: layout.lines[line].align,
                                maxLines: 1,
                                softWrap: false,
                              ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.author.isNotEmpty)
              Positioned.fromRect(
                rect: layout.signatureRect,
                child: Stack(
                  key: const ValueKey('quote-author-region'),
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: signatureRuleInset,
                      top: QuoteArtworkTypography.signatureSize * .61,
                      child: Container(
                        key: const ValueKey('quote-signature-rule'),
                        width: ruleWidth,
                        height: 1.1,
                        color: QuoteArtworkTypography.ink,
                      ),
                    ),
                    Positioned(
                      left: ruleWidth + ruleGap,
                      right: 0,
                      top: 0,
                      child: QuoteAuthorSignature(
                        widget.author,
                        key: const ValueKey('quote-author'),
                        style: signatureStyle,
                        textAlign: TextAlign.right,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned.fromRect(
              rect: layout.footerRect,
              child: Align(
                key: const ValueKey('quote-read-more-region'),
                alignment: Alignment.centerRight,
                child: InkWell(
                  key: const ValueKey('quote-read-more'),
                  onTap: widget.onRead,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      layout.footerRect.width < 180 ? '全文与解读 ›' : '阅读全文与解读 ›',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff625c55),
                        fontFamilyFallback: [quoteLiterarySerifFont],
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
