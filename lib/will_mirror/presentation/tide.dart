import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A quiet 2.5-D scene subscribed to real case state. It has no random rewards
/// or business writes. Unknown outcomes keep their veiled, unlit state.
class MotiveTide extends StatefulWidget {
  const MotiveTide(
      {super.key,
      required this.caption,
      this.phase = 'prepare',
      this.evidenceCount = 0,
      this.animate = false,
      this.height = 165,
      this.onTap});
  final String caption, phase;
  final int evidenceCount;
  final bool animate;
  final double height;
  final VoidCallback? onTap;
  @override
  State<MotiveTide> createState() => _MotiveTideState();
}

class _MotiveTideState extends State<MotiveTide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant MotiveTide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (widget.animate && !reduce) {
      _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: '动机之潮。${widget.caption}',
      image: true,
      button: widget.onTap != null,
      child: ExcludeSemantics(
          child: GestureDetector(
              onTap: widget.onTap,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                      height: widget.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedBuilder(
                              animation: _motion,
                              builder: (_, __) => CustomPaint(
                                  painter: _TidePainter(_motion.value,
                                      widget.phase, widget.evidenceCount))),
                          Positioned(
                              left: 20,
                              right: 20,
                              bottom: 18,
                              child: Text(widget.caption,
                                  style: const TextStyle(
                                      color: Color(0xffecf0e8),
                                      fontSize: 13,
                                      height: 1.5))),
                          const Positioned(
                              left: 20,
                              top: 18,
                              child: Text('动 机 之 潮',
                                  style: TextStyle(
                                      color: Color(0xffd7e6df),
                                      fontSize: 11,
                                      letterSpacing: 3)))
                        ],
                      ))))));
}

class _TidePainter extends CustomPainter {
  _TidePainter(this.t, this.phase, this.count);
  final double t;
  final String phase;
  final int count;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff173c44),
                Color(0xff255c63),
                Color(0xff102b3b)
              ]).createShader(rect));
    for (var layer = 0; layer < 5; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width + 4; x += 4) {
        final y = size.height * (.43 + layer * .09) +
            math.sin(x / size.width * math.pi * 2 +
                    layer * .7 +
                    t * math.pi * 2) *
                (8 + layer * 3);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(const Color(0xff70b6ad),
                    const Color(0xff193f53), layer / 5)!
                .withValues(alpha: .12 + layer * .02));
    }
    final center = Offset(size.width * .77, size.height * .4);
    canvas.drawCircle(
        center,
        28,
        Paint()
          ..color = const Color(0xffb3c7a7).withValues(alpha: .07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(center, 19,
        Paint()..color = const Color(0xffd7d9af).withValues(alpha: .8));
    canvas.drawCircle(center + const Offset(7, -4), 18,
        Paint()..color = const Color(0xff245661));
    if (phase == 'waiting') {
      canvas.drawCircle(
          Offset(size.width * .48, size.height * .54),
          19,
          Paint()
            ..color = const Color(0xffd2b88b).withValues(alpha: .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawLine(
          Offset(size.width * .48, size.height * .54 - 9),
          Offset(size.width * .48, size.height * .54 + 9),
          Paint()
            ..color = const Color(0xffd2b88b)
            ..strokeWidth = 1);
    }
    // Only the number of recorded observations lights the real evidence path.
    final lit = phase == 'revealed' ? count.clamp(0, 12) : 0;
    for (var i = 0; i < 12; i++) {
      final x = size.width * (.14 + i * .054),
          y = size.height * .61 + math.sin(i * .65 + t * math.pi * 2) * 10;
      final paint = Paint()
        ..color = (i < lit ? const Color(0xffe2c28b) : const Color(0xff95c2ba))
            .withValues(alpha: i < lit ? 0.9 : 0.2);
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 4, y - 3, x + 10, y)
        ..quadraticBezierTo(x + 4, y + 3, x, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TidePainter old) =>
      old.t != t || old.phase != phase || old.count != count;
}
