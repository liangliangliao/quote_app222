import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import '../services/quote_calligraphy_settings.dart';

const String quoteLatinSignatureFont = 'QuoteSignatureLatin';
const String quoteChineseSignatureFont = 'QuoteXingShu';
const String quoteLiterarySerifFont = 'QuoteLiterarySerif';

enum _SignatureScript { latin, han }

bool _isHan(String character) {
  if (character.isEmpty) return false;
  final value = character.runes.first;
  return (value >= 0x3400 && value <= 0x4dbf) ||
      (value >= 0x4e00 && value <= 0x9fff) ||
      (value >= 0xf900 && value <= 0xfaff);
}

bool _isLatinOrDigit(String character) {
  if (character.isEmpty) return false;
  return RegExp(r'[A-Za-z0-9\u00c0-\u024f]').hasMatch(character);
}

/// Uses the literary face only when Latin letters clearly dominate. Mixed
/// Chinese quotations therefore retain their Chinese composition.
bool quotePrefersLiteraryEnglish(String text) {
  var latin = 0;
  var han = 0;
  for (final character in text.characters) {
    if (_isHan(character)) {
      han += 1;
    } else if (_isLatinOrDigit(character)) {
      latin += 1;
    }
  }
  return latin > 0 && latin >= math.max(3, han * 2);
}

TextStyle quoteLiteraryTextStyle(TextStyle base) => base.copyWith(
      fontFamily: quoteLiterarySerifFont,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      height: 1.56,
      letterSpacing: .12,
      color: const Color(0xff211d19),
    );

/// Builds mixed-script signature spans without changing source order, spaces,
/// punctuation or explicit line breaks.
TextSpan quoteAuthorSignatureSpan(String text, TextStyle baseStyle) {
  final characters = text.characters.toList(growable: false);
  var firstScript = _SignatureScript.latin;
  for (final character in characters) {
    if (_isHan(character)) {
      firstScript = _SignatureScript.han;
      break;
    }
    if (_isLatinOrDigit(character)) {
      firstScript = _SignatureScript.latin;
      break;
    }
  }

  final spans = <TextSpan>[];
  var active = firstScript;
  var buffer = StringBuffer();

  TextStyle styleFor(_SignatureScript script) {
    if (script == _SignatureScript.han) {
      return baseStyle.copyWith(
        fontFamily: quoteChineseSignatureFont,
        fontSize: (baseStyle.fontSize ?? 14) * 1.08,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
        letterSpacing: .25,
        height: 1.30,
      );
    }
    return baseStyle.copyWith(
      fontFamily: quoteLatinSignatureFont,
      fontSize: (baseStyle.fontSize ?? 14) * 1.23,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      letterSpacing: .12,
      height: 1.23,
    );
  }

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString(), style: styleFor(active)));
    buffer = StringBuffer();
  }

  for (var index = 0; index < characters.length; index++) {
    final character = characters[index];
    _SignatureScript? next;
    if (_isHan(character)) {
      next = _SignatureScript.han;
    } else if (_isLatinOrDigit(character)) {
      next = _SignatureScript.latin;
    }
    if (next != null && next != active) {
      flush();
      active = next;
    }
    buffer.write(character);
  }
  flush();
  return TextSpan(style: baseStyle, children: spans);
}

class QuoteAuthorSignature extends StatelessWidget {
  const QuoteAuthorSignature(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.right,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) => Text.rich(
        quoteAuthorSignatureSpan(text, style),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
}

TextStyle quoteCalligraphyTextStyle(
  TextStyle base,
  QuoteCalligraphyStyle style,
) {
  final fontSize = base.fontSize ?? 20;
  return base.copyWith(
    fontFamily: style.fontFamily,
    fontSize: style == QuoteCalligraphyStyle.caoshu
        ? fontSize * 1.06
        : fontSize,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.normal,
    height: style == QuoteCalligraphyStyle.kaishu ? 1.50 : 1.47,
    letterSpacing: switch (style) {
      QuoteCalligraphyStyle.xingshu => .9,
      QuoteCalligraphyStyle.kaishu => 1.3,
      QuoteCalligraphyStyle.caoshu => 1.05,
    },
    color: const Color(0xff211a16),
  );
}

/// Keeps the complete final paragraph laid out from frame one, then reveals
/// each glyph in place. This avoids the line jumping of a typewriter effect
/// while producing a restrained brush-on-paper rhythm.
class CalligraphyWritingText extends StatefulWidget {
  const CalligraphyWritingText({
    super.key,
    required this.text,
    required this.style,
    required this.calligraphyStyle,
    this.maxLines,
    this.overflow = TextOverflow.visible,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final QuoteCalligraphyStyle calligraphyStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  @override
  State<CalligraphyWritingText> createState() =>
      _CalligraphyWritingTextState();
}

class _CalligraphyWritingTextState extends State<CalligraphyWritingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _duration {
    final milliseconds = widget.text.characters.length * 78;
    return Duration(milliseconds: milliseconds.clamp(1800, 9000).toInt());
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant CalligraphyWritingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.calligraphyStyle != widget.calligraphyStyle) {
      _controller.duration = _duration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: Directionality.of(context),
        textAlign: widget.textAlign,
        textScaler: TextScaler.noScaling,
        maxLines: widget.maxLines,
        ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
      )..layout(maxWidth: constraints.maxWidth);
      final height = painter.height;
      painter.dispose();
      final disableAnimation =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      return Semantics(
        label: widget.text,
        child: SizedBox(
          width: constraints.maxWidth,
          height: height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _InkWritingPainter(
                text: widget.text,
                style: style,
                textDirection: Directionality.of(context),
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
                ellipsis:
                    widget.overflow == TextOverflow.ellipsis ? '…' : null,
                progress: disableAnimation ? 1 : _controller.value,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _InkWritingPainter extends CustomPainter {
  const _InkWritingPainter({
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textAlign,
    required this.maxLines,
    required this.ellipsis,
    required this.progress,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final TextAlign textAlign;
  final int? maxLines;
  final String? ellipsis;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: textAlign,
      textScaler: TextScaler.noScaling,
      maxLines: maxLines,
      ellipsis: ellipsis,
    )..layout(maxWidth: size.width);
    if (progress >= .999) {
      painter.paint(canvas, Offset.zero);
      painter.dispose();
      return;
    }

    final units = <List<TextBox>>[];
    var offset = 0;
    for (final character in text.characters) {
      final end = offset + character.length;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: end),
      );
      if (boxes.isNotEmpty) units.add(boxes);
      offset = end;
    }
    if (units.isEmpty) {
      painter.dispose();
      return;
    }

    final scaled = progress.clamp(0.0, 1.0) * units.length;
    final completed = scaled.floor().clamp(0, units.length).toInt();
    final currentProgress = Curves.easeOutCubic.transform(scaled - scaled.floor());
    final reveal = Path();
    for (var index = 0; index < completed; index++) {
      for (final box in units[index]) {
        reveal.addRect(box.toRect().inflate(.7));
      }
    }
    if (completed < units.length) {
      for (final box in units[completed]) {
        final rect = box.toRect().inflate(.7);
        final diagonalLead = math.max(.08, currentProgress);
        reveal.addRect(Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.left + rect.width * diagonalLead,
          rect.bottom,
        ));
      }
    }
    canvas.save();
    canvas.clipPath(reveal);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _InkWritingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.maxLines != maxLines;
}
