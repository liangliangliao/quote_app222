import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Typography is a constant of the artwork, never a function of quote length.
abstract final class QuoteArtworkTypography {
  static const bodySize = 32.0;
  static const signatureSize = 22.0;
  static const ink = Color(0xff211a16);
  static const weight = FontWeight.w800;
}

class QuoteArtLine {
  const QuoteArtLine(this.text, this.rect, this.align);
  final String text;
  final Rect rect;
  final TextAlign align;

  QuoteArtLine shifted(double dy) =>
      QuoteArtLine(text, rect.shift(Offset(0, dy)), align);
}

class QuoteArtPage {
  const QuoteArtPage(this.lines, this.portrait);
  final List<QuoteArtLine> lines;
  final Rect? portrait;
}

/// Fits complete, measured lines, using punctuation, verse and portrait space.
/// Extra content continues on another sheet at exactly the same type size.
class QuoteArtLayout {
  const QuoteArtLayout({
    required this.pages,
    required this.leading,
    required this.letterSpacing,
    required this.signatureTop,
    required this.footerHeight,
  });

  final List<QuoteArtPage> pages;
  final double leading, letterSpacing, signatureTop, footerHeight;

  static QuoteArtLayout compose({
    required String text,
    required Size size,
    required InlineSpan Function(String text, double spacing) span,
    required TextDirection direction,
    required double signatureHeight,
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
        (compact ? 1.62 : (dense ? 1.40 : 1.50));
    final spacing = compact ? .8 : (dense ? .25 : .5);
    const footer = 28.0;
    final signatureTop = size.height - footer - signatureHeight - 7;
    final bodyBottom = math.max(
      leading,
      signatureTop - (signatureHeight > 0 ? 17 : 7),
    );
    final portraitWidth = (size.width * (dense ? .24 : .28))
        .clamp(46.0, 76.0)
        .toDouble();
    final portrait = hasPortrait
        ? Rect.fromLTWH(
            size.width - portraitWidth,
            0,
            portraitWidth,
            portraitWidth / .78,
          )
        : null;
    final closing = RegExp(r'^[，。！？；：、,.!?;:)\]」』”’》】]$');
    final opening = RegExp(r'^[（(\[「『“‘《【]$');
    final pause = RegExp(r'[，。！？；：、,.!?;:]$');
    final sentenceEnd = RegExp(r'[。！？.!?][」』”’》】]?$');

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
            : start + math.max(1, (fit * .48).ceil());
        // Respect English words, and let Chinese clauses breathe at a pause.
        for (var at = stop; at >= minimum; at--) {
          final previous = characters[at - 1];
          if ((english && characters[at].trim().isEmpty) ||
              (!english && pause.hasMatch(previous))) {
            stop = at;
            break;
          }
        }
        // A punctuation mark belongs with the preceding phrase. Carry that
        // phrase onto the next line if the mark cannot fit here.
        while (stop > start + 1 && closing.hasMatch(characters[stop])) {
          stop--;
        }
        while (stop > start + 1 && opening.hasMatch(characters[stop - 1])) {
          stop--;
        }
      }
      return math.max(start + 1, stop);
    }

    // Short, self-contained sayings sit below the portrait. Longer prose uses
    // the left side of its top band instead of leaving that area empty.
    var fullWidthLines = 0;
    for (var cursor = 0; cursor < characters.length;) {
      if (characters[cursor].trim().isEmpty) {
        cursor++;
        continue;
      }
      cursor = breakAt(cursor, size.width);
      fullWidthLines++;
    }
    final belowPortrait =
        portrait != null &&
        portrait.bottom + 10 + fullWidthLines * leading <= bodyBottom;
    final pages = <QuoteArtPage>[];
    var cursor = 0;
    do {
      final first = pages.isEmpty;
      final image = first ? portrait : null;
      var y = first && belowPortrait ? portrait.bottom + 10 : 0.0;
      final lines = <QuoteArtLine>[];
      var paragraphStart = true;
      while (cursor < characters.length) {
        if (characters[cursor] == '\n') {
          cursor++;
          paragraphStart = true;
          if (lines.isNotEmpty) y += leading * .18;
          continue;
        }
        if (characters[cursor].trim().isEmpty) {
          cursor++;
          continue;
        }
        if (lines.isNotEmpty && y + leading > bodyBottom + .01) break;
        final besidePortrait = image != null && y < image.bottom + 7;
        final indent = dense && paragraphStart && !besidePortrait
            ? QuoteArtworkTypography.bodySize * .42
            : 0.0;
        final right = besidePortrait ? image.left - 10 : size.width;
        final width = math.max(1.0, right - indent);
        final end = breakAt(cursor, width);
        final value = characters.sublist(cursor, end).join().trim();
        final centered = !besidePortrait && (compact || verse);
        lines.add(
          QuoteArtLine(
            value,
            Rect.fromLTWH(indent, y, width, leading),
            centered ? TextAlign.center : TextAlign.start,
          ),
        );
        cursor = end;
        paragraphStart = false;
        y += leading;
        if (!dense && sentenceEnd.hasMatch(value)) y += leading * .10;
      }
      if (lines.isNotEmpty) {
        final room = math.max(0.0, bodyBottom - lines.last.rect.bottom);
        final shift = room * (compact ? .48 : (dense ? .12 : .30));
        pages.add(
          QuoteArtPage(
            List.unmodifiable(lines.map((line) => line.shifted(shift))),
            image,
          ),
        );
      } else {
        pages.add(QuoteArtPage(const [], image));
      }
    } while (cursor < characters.length);
    return QuoteArtLayout(
      pages: List.unmodifiable(pages),
      leading: leading,
      letterSpacing: spacing,
      signatureTop: signatureTop,
      footerHeight: footer,
    );
  }
}
