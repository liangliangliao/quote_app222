import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'quote_adaptive_frame.dart';
import 'quote_portrait_cutout.dart';

ImageProvider _posterAvatar(String raw) {
  if (raw.startsWith('data:')) {
    try { return MemoryImage(base64Decode(raw.substring(raw.indexOf(',') + 1))); }
    catch (_) { return const AssetImage('assets/avatars/talbenshahar .jpeg'); }
  }
  if (raw.startsWith('http://') || raw.startsWith('https://')) return NetworkImage(raw);
  if (raw.startsWith('assets/')) return AssetImage(raw);
  if (raw.startsWith('/')) return FileImage(File(raw));
  return const AssetImage('assets/avatars/talbenshahar .jpeg');
}

/// Measure the real painting bounds before placing text. No foreground masks
/// or remembered scroll offsets can obscure the first or last line.
class PosterPureFlutter extends StatelessWidget {
  const PosterPureFlutter({
    super.key, required this.topic, required this.quote, required this.author,
    required this.note, required this.avatar,
    this.woodBgAsset = QuoteAdaptiveFrame.defaultBackgroundAsset, this.aiFramePath,
  });
  final String topic, quote, author, note, avatar, woodBgAsset;
  final String? aiFramePath;

  void _openReading(BuildContext context) {
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
              Text(topic, style: const TextStyle(fontSize: 20, height: 1.5)),
              const SizedBox(height: 20),
              Text(quote, style: const TextStyle(
                fontSize: 21, height: 1.65, fontWeight: FontWeight.w600)),
              if (author.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(author, textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
              if (note.trim().isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(note, style: const TextStyle(fontSize: 17, height: 1.7)),
              ],
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
        final paper = QuoteAdaptiveFrame.scaleRect(
          QuoteAdaptiveFrame.textSafeRect, constraints.biggest);
        return Stack(fit: StackFit.expand, children: [
          QuoteAdaptiveFrame(backgroundAsset: woodBgAsset,
            aiImagePath: aiFramePath, quoteCharacters: quote.runes.length),
          Positioned.fromRect(rect: paper, child: _PaperComposition(
            topic: topic, quote: quote, author: author, note: note, avatar: avatar,
            onRead: () => _openReading(context))),
        ]);
      }),
    ),
  ));
}

class _PaperComposition extends StatelessWidget {
  const _PaperComposition({
    required this.topic, required this.quote, required this.author,
    required this.note, required this.avatar, required this.onRead,
  });
  final String topic, quote, author, note, avatar;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final width = bounds.maxWidth, height = bounds.maxHeight;
    final hasAvatar = avatar.trim().isNotEmpty && avatar.trim() != 'null';
    final direction = Directionality.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;
    final titleStyle = baseStyle.copyWith(
      fontSize: (width * .069).clamp(11.0, 21.0), height: 1.35,
      color: const Color(0xff352c27), letterSpacing: .35);
    final authorStyle = baseStyle.copyWith(
      fontSize: (width * .050).clamp(9.0, 15.0), height: 1.4,
      color: const Color(0xff544b44), fontWeight: FontWeight.w500);
    final noteStyle = baseStyle.copyWith(
      fontSize: (width * .047).clamp(9.0, 14.0), height: 1.5,
      color: const Color(0xff625c55));
    double measure(String text, TextStyle style, double maxWidth, {int? maxLines}) {
      if (text.trim().isEmpty) return 0;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style), textDirection: direction,
        textScaler: TextScaler.noScaling, maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: maxWidth);
      final result = painter.height;
      painter.dispose();
      return result;
    }
    final portraitWidth = (width * .25).clamp(35.0, 82.0);
    final portraitHeight = portraitWidth * 1.22;
    final gap = (width * .041).clamp(5.0, 12.0);
    final titleWidth = width - (hasAvatar ? portraitWidth + gap : 0);
    final titleHeight = measure(topic, titleStyle, titleWidth, maxLines: 3);
    final headerHeight = math.max(titleHeight, hasAvatar ? portraitHeight : 0.0);
    final authorHeight = measure(author, authorStyle, width, maxLines: 3);
    final footerHeight = (width * .105).clamp(22.0, 30.0);
    final hasNote = note.trim().isNotEmpty;
    final noteLineHeight = measure('解读', noteStyle, width);
    final available = math.max(1.0, height - headerHeight - gap -
      authorHeight - (author.trim().isNotEmpty ? gap : 0) -
      (hasNote ? noteLineHeight * 2 + gap : 0) - footerHeight - 3);
    var quoteSize = (width * .083).clamp(14.0, 27.0).toDouble();
    final minimumSize = (width * .062).clamp(11.0, 18.0).toDouble();
    TextStyle quoteStyle() => baseStyle.copyWith(
      fontSize: quoteSize, height: 1.47, letterSpacing: .45,
      fontWeight: FontWeight.w700, color: const Color(0xff25211d));
    while (quoteSize > minimumSize &&
        measure(quote, quoteStyle(), width) > available) {
      quoteSize = math.max(minimumSize, quoteSize - .25);
    }
    final fullQuoteHeight = measure(quote, quoteStyle(), width);
    final quoteLineHeight = measure('名言', quoteStyle(), width);
    final quoteLines = fullQuoteHeight <= available ? null
      : math.max(1, (available / quoteLineHeight).floor());
    final quoteHeight = measure(quote, quoteStyle(), width, maxLines: quoteLines);
    final noteSpace = math.max(0.0, height - headerHeight - gap - quoteHeight -
      authorHeight - (author.trim().isNotEmpty ? gap : 0) -
      gap - footerHeight - 3);
    final noteLines = hasNote
      ? math.max(0, (noteSpace / math.max(1, noteLineHeight)).floor()) : 0;
    final needsReading = quoteLines != null ||
      measure(author, authorStyle, width) > authorHeight + .5 ||
      measure(topic, titleStyle, titleWidth) > titleHeight + .5 ||
      (hasNote && (noteLines == 0 || measure(note, noteStyle, width) > noteSpace));
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: headerHeight, child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Text(topic, key: const ValueKey('quote-topic'),
              maxLines: 3, overflow: TextOverflow.ellipsis, style: titleStyle)),
            if (hasAvatar) ...[
              SizedBox(width: gap),
              QuotePortraitCutout(image: _posterAvatar(avatar),
                width: portraitWidth, height: portraitHeight),
            ],
          ])),
        SizedBox(height: gap),
        Text(quote, key: const ValueKey('quote-body'), maxLines: quoteLines,
          overflow: quoteLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
          style: quoteStyle()),
        if (author.trim().isNotEmpty) ...[
          SizedBox(height: gap),
          Text(author, key: const ValueKey('quote-author'),
            textAlign: TextAlign.right, maxLines: 3,
            overflow: TextOverflow.ellipsis, style: authorStyle),
        ],
        if (hasNote && noteLines > 0) ...[
          SizedBox(height: gap),
          Text(note, key: const ValueKey('quote-note'), maxLines: noteLines,
            overflow: TextOverflow.ellipsis, style: noteStyle),
        ],
        const Spacer(),
        SizedBox(height: footerHeight, child: Align(
          alignment: Alignment.centerRight,
          child: InkWell(key: const ValueKey('quote-read-more'), onTap: onRead,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(needsReading ? '阅读全文与解读  ›' : '放大阅读  ›',
                style: noteStyle.copyWith(
                  fontSize: math.min(12.0, noteStyle.fontSize!),
                  color: const Color(0xff776a5d))))),
        )),
      ]),
    );
  });
}
