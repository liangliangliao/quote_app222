import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A modest increase from the original brush typography, without heavy ink.
/// Content length changes composition and excerpt length, never this type size.
abstract final class QuoteArtworkTypography {
  static const bodySize = 25.0;
  static const signatureSize = 21.0;
  static const ink = Color(0xff211a16);
  static const weight = FontWeight.w600;
  static const signatureRuleWidth = 20.0;
  static const signatureRuleGap = 9.0;
}

class QuoteArtLine {
  const QuoteArtLine(this.text, this.rect, this.align);
  final String text;
  final Rect rect;
  final TextAlign align;

  QuoteArtLine shifted(double dy) =>
      QuoteArtLine(text, rect.shift(Offset(0, dy)), align);
}

/// One quiet composition: a measured excerpt, a portrait, and a following
/// signature. Complete quotations remain available in the full reader.
class QuoteArtLayout {
  const QuoteArtLayout({
    required this.lines,
    required this.portrait,
    required this.contentBounds,
    required this.signatureRect,
    required this.footerRect,
    required this.leading,
    required this.letterSpacing,
    required this.isTruncated,
  });

  final List<QuoteArtLine> lines;
  final Rect? portrait;
  final Rect contentBounds, signatureRect, footerRect;
  final double leading, letterSpacing;
  final bool isTruncated;

  static QuoteArtLayout compose({
    required String text,
    required Size size,
    required InlineSpan Function(String text, double spacing) span,
    required TextDirection direction,
    required Size signatureSize,
    required bool hasPortrait,
  }) {
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final characters = text.characters.toList(growable: false);
    final han = RegExp(r'[\u3400-\u9fff]').allMatches(text).length;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final english = han < 3 && words > 1;
    final units = english ? words : characters.length;
    final compact = units <= (english ? 8 : 16);
    final dense = units > (english ? 28 : 48);
    final verse = '\n'.allMatches(text).length >= 2;
    final leading =
        QuoteArtworkTypography.bodySize *
        (compact ? 1.70 : (dense ? 1.50 : 1.56));
    final spacing = compact ? .65 : (dense ? .30 : .45);

    // Longer passages can use a little more paper, but no passage may press
    // against the wood. Short sayings keep the generous margins of a poem.
    final inset = (size.width * (compact ? .105 : (dense ? .065 : .08)))
        .clamp(12.0, 28.0)
        .toDouble();
    final top = (size.height * .035).clamp(9.0, 18.0).toDouble();
    final right = size.width - inset;
    const footerHeight = 26.0;
    final footer = Rect.fromLTWH(
      inset,
      size.height - footerHeight,
      math.max(1, size.width - inset * 2),
      footerHeight,
    );
    // This reserved band is stable while an original name is being resolved.
    final band = math.max(size.width < 190 ? 80.0 : 58.0, signatureSize.height);
    final signatureBottom = footer.top - 10;
    final bodyBottom = math.max(top + leading, signatureBottom - band - 18);
    final content = Rect.fromLTRB(inset, top, right, bodyBottom);
    final portraitWidth = (content.width * (dense ? .25 : .28))
        .clamp(42.0, 70.0)
        .toDouble();
    final portrait = hasPortrait
        ? Rect.fromLTWH(
            right - portraitWidth,
            top,
            portraitWidth,
            portraitWidth / .78,
          )
        : null;
    final closing = RegExp(r'^[，。！？；：、,.!?;:)\]」』”’》】]$');
    final opening = RegExp(r'^[（(\[「『“‘《【]$');
    final pause = RegExp(r'[，。！？；：、,.!?;:]$');
    final sentenceEnd = RegExp(r'[。！？.!?][」』”’》】]?$');
    final hanging = RegExp(r'^[的之与和但并而把被将让不未在]$');

    double measure(String value) {
      final painter = TextPainter(
        text: span(value, spacing),
        textDirection: direction,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    int breakAt(int start, double width) {
      var end = start;
      while (end < characters.length &&
          characters[end] != '\n' &&
          end - start < 180) {
        end++;
      }
      var low = 1;
      var high = end - start;
      var fit = 1;
      while (low <= high) {
        final count = (low + high) ~/ 2;
        if (measure(characters.sublist(start, start + count).join()) <= width) {
          fit = count;
          low = count + 1;
        } else {
          high = count - 1;
        }
      }
      var stop = math.min(end, start + fit);
      if (stop < end) {
        final minimum = english
            ? start + 1
            : start + math.max(1, (fit * .52).ceil());
        for (var at = stop; at >= minimum; at--) {
          if ((english && characters[at].trim().isEmpty) ||
              (!english && pause.hasMatch(characters[at - 1]))) {
            stop = at;
            break;
          }
        }
        while (stop > start + 1 && closing.hasMatch(characters[stop])) {
          stop--;
        }
        while (stop > start + 1 && opening.hasMatch(characters[stop - 1])) {
          stop--;
        }
        // Keep a Chinese linking particle or negation with the following words.
        if (!english &&
            stop > start + 2 &&
            hanging.hasMatch(characters[stop - 1]))
          stop--;
      }
      return math.max(start + 1, stop);
    }

    // Probe only as far as this sheet can use; very long quotations never need
    // to lay out hundreds of hidden pages just to display an excerpt.
    var fullWidthLines = 0;
    for (var cursor = 0; cursor < characters.length;) {
      if (characters[cursor].trim().isEmpty) {
        cursor++;
        continue;
      }
      cursor = breakAt(cursor, content.width);
      fullWidthLines++;
      if (fullWidthLines * leading > content.height) break;
    }
    final belowPortrait =
        portrait != null &&
        portrait.bottom + 12 + fullWidthLines * leading <= bodyBottom;
    var y = belowPortrait ? portrait.bottom + 12 : top;
    var cursor = 0;
    final lines = <QuoteArtLine>[];
    while (cursor < characters.length) {
      if (characters[cursor] == '\n') {
        cursor++;
        if (lines.isNotEmpty) y += leading * (verse ? .12 : .18);
        continue;
      }
      if (characters[cursor].trim().isEmpty) {
        cursor++;
        continue;
      }
      if (y + leading > bodyBottom + .01) break;
      final besidePortrait = portrait != null && y < portrait.bottom + 10;
      final lineRight = besidePortrait ? portrait.left - 14 : right;
      final available = math.max(1.0, lineRight - inset);
      final end = breakAt(cursor, available);
      final value = characters.sublist(cursor, end).join().trim();
      lines.add(
        QuoteArtLine(
          value,
          Rect.fromLTWH(inset, y, available, leading),
          !besidePortrait && (compact || verse)
              ? TextAlign.center
              : TextAlign.start,
        ),
      );
      cursor = end;
      y += leading;
      if (!dense && sentenceEnd.hasMatch(value)) y += leading * .10;
    }
    final truncated = cursor < characters.length;
    if (truncated && lines.isNotEmpty) {
      final last = lines.removeLast();
      var tail = last.text.characters.toList();
      const ellipsis = '…';
      while (tail.isNotEmpty &&
          measure('${tail.join()}$ellipsis') > last.rect.width) {
        tail.removeLast();
      }
      // End English excerpts at a word and avoid a dangling Chinese comma or
      // linking word, without discarding a large portion of the visible line.
      if (english &&
          cursor < characters.length &&
          !RegExp(r'\s').hasMatch(characters[cursor])) {
        final boundary = tail.lastIndexWhere((c) => c.trim().isEmpty);
        if (boundary >= tail.length * .45) tail = tail.sublist(0, boundary);
      }
      while (tail.isNotEmpty &&
          (tail.last.trim().isEmpty ||
              RegExp(r'^[，。；：、,;:（(“‘《]$').hasMatch(tail.last) ||
              (!english && hanging.hasMatch(tail.last)))) {
        tail.removeLast();
      }
      lines.add(QuoteArtLine('${tail.join()}$ellipsis', last.rect, last.align));
    }
    if (lines.isNotEmpty) {
      final room = math.max(0.0, bodyBottom - lines.last.rect.bottom);
      final shift = room * (compact ? .44 : (dense ? .10 : .28));
      for (var i = 0; i < lines.length; i++) {
        lines[i] = lines[i].shifted(shift);
      }
    }

    final signatureWidth = math.min(signatureSize.width, content.width);
    final signatureHeight = signatureSize.height;
    final last = lines.isEmpty ? null : lines.last;
    final lastWidth = last == null ? 0.0 : measure(last.text);
    final lastRight = last == null
        ? content.center.dx
        : last.rect.left +
              (last.align == TextAlign.center
                  ? (last.rect.width + lastWidth) / 2
                  : lastWidth);
    final tailFill = lastWidth / content.width;
    // Follow the last phrase's visual centre; short endings draw the signature
    // inward. A full final line allows it a little farther right, with margins.
    final desiredRight = compact || verse
        ? content.center.dx + math.max(signatureWidth / 2, content.width * .24)
        : math.max(
            content.center.dx + signatureWidth * .32,
            lastRight + (tailFill < .6 ? 12 : -8),
          );
    final signatureLeft = (desiredRight - signatureWidth)
        .clamp(
          content.left,
          math.max(content.left, content.right - signatureWidth - 6),
        )
        .toDouble();
    final gap = compact ? 23.0 : (dense ? 16.0 : 20.0);
    final afterBody = last?.rect.bottom ?? (portrait?.bottom ?? content.top);
    final signatureTop = (afterBody + gap)
        .clamp(top, math.max(top, signatureBottom - signatureHeight))
        .toDouble();

    return QuoteArtLayout(
      lines: List.unmodifiable(lines),
      portrait: portrait,
      contentBounds: content,
      signatureRect: Rect.fromLTWH(
        signatureLeft,
        signatureTop,
        signatureWidth,
        signatureHeight,
      ),
      footerRect: footer,
      leading: leading,
      letterSpacing: spacing,
      isTruncated: truncated,
    );
  }
}
