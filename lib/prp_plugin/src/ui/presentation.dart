import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keep the neutral paper readable inside the enemy's dark theme.
ThemeData prpPaperTheme(BuildContext context,
        {Color seed = const Color(0xff56568b)}) =>
    ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xff30363b),
          displayColor: const Color(0xff30363b)),
      inputDecorationTheme:
          const InputDecorationTheme(border: OutlineInputBorder()),
    );

class PrpLedgerReveal extends StatelessWidget {
  const PrpLedgerReveal({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve:
            Interval(index * .2, .6 + index * .2, curve: Curves.easeOutCubic),
        child: child,
        builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .001)
                ..rotateY((1 - value) * 1.35),
              child: child,
            )),
      );
}

class PrpCrossedOutText extends StatelessWidget {
  const PrpCrossedOutText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (_, value, __) => Stack(children: [
              Text(text, style: style),
              Positioned.fill(
                  child: IgnorePointer(
                      child: CustomPaint(
                          painter: _InkStrike(
                              text: text,
                              style: style,
                              scaler: scaler,
                              direction: direction,
                              progress: value)))),
            ]));
  }
}

class _InkStrike extends CustomPainter {
  const _InkStrike(
      {required this.text,
      required this.style,
      required this.scaler,
      required this.direction,
      required this.progress});
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler)
      ..layout(maxWidth: size.width);
    final lines = painter.computeLineMetrics();
    var remaining =
        lines.fold<double>(0, (sum, line) => sum + line.width) * progress;
    final ink = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (final line in lines) {
      if (remaining <= 0) break;
      final length = math.min(line.width, remaining);
      final y = line.baseline - line.ascent * .36;
      canvas.drawLine(Offset(line.left, y), Offset(line.left + length, y), ink);
      remaining -= length;
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_InkStrike old) =>
      text != old.text ||
      style != old.style ||
      scaler != old.scaler ||
      direction != old.direction ||
      progress != old.progress;
}
