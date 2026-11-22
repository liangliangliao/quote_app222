import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'touch_effort.dart';

class EffortMeter extends StatelessWidget {
  const EffortMeter({super.key, required this.effort});

  final TouchEffort effort;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<EffortProgress>(
        valueListenable: effort,
        builder: (context, progress, _) {
          final active = progress.gesture;
          final value = '${progress.percent}%';
          final hint = progress.reached
              ? '已达成'
              : switch (active) {
                  TouchGesture.tap => '继续点击同一区域',
                  TouchGesture.hold => '继续按住',
                  TouchGesture.swipe => '继续滑动',
                  null => '连续操作，达到 100% 后触发反馈',
                };
          final reduceMotion = MediaQuery.disableAnimationsOf(context);
          final duration = reduceMotion || progress.reached
              ? Duration.zero
              : Duration(milliseconds: active == TouchGesture.hold ? 45 : 160);
          return Semantics(
            container: true,
            label: '触屏努力值，${effort.difficulty.label}难度',
            value: value,
            hint: hint,
            liveRegion: progress.reached,
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 304),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xEE25170F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: progress.reached
                          ? const Color(0xFFFFDF83)
                          : const Color(0xFF966539)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 7, 13, 7),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text('努力值 · ${effort.difficulty.label}',
                                  style: const TextStyle(
                                      color: Color(0xFFFFEDD0),
                                      fontWeight: FontWeight.w700))),
                          Text(value,
                              style: const TextStyle(
                                  color: Color(0xFFFFDC7B),
                                  fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: progress.value),
                          duration: duration,
                          curve: Curves.easeOut,
                          builder: (context, fraction, _) => SizedBox(
                            width: double.infinity,
                            height: 16,
                            child: progress.reached && !reduceMotion
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 1, end: 0),
                                    duration: const Duration(milliseconds: 660),
                                    curve: Curves.easeOut,
                                    builder: (context, burst, _) => CustomPaint(
                                        painter: _GoldGauge(fraction, burst)),
                                  )
                                : CustomPaint(painter: _GoldGauge(fraction, 0)),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(hint,
                            style: const TextStyle(
                                color: Color(0xFFF7D9AE), fontSize: 12)),
                      ]),
                ),
              ),
            ),
          );
        },
      );
}

class _GoldGauge extends CustomPainter {
  const _GoldGauge(this.progress, this.burst);

  final double progress;
  final double burst;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 20;
    const gap = 2.0;
    final bounds = (Offset.zero & size).deflate(1);
    final inner = bounds.deflate(2);
    if (inner.width <= (segments - 1) * gap || inner.height <= 0) return;
    final rail = RRect.fromRectAndRadius(bounds, const Radius.circular(4));
    final segmentWidth = (inner.width - (segments - 1) * gap) / segments;
    final fillEnd = inner.left + inner.width * progress;

    if (burst > 0) {
      canvas.drawRRect(
          rail.inflate(1),
          Paint()
            ..color = const Color(0xFFFFD26A).withValues(alpha: 0.8 * burst)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5));
    }
    canvas.drawRRect(rail, Paint()..color = const Color(0xFF3B2115));
    canvas.drawRRect(
        rail,
        Paint()
          ..color = const Color(0xFFB47B40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF0B2), Color(0xFFFFC453), Color(0xFFC57726)],
      ).createShader(inner);
    for (var index = 0; index < segments; index++) {
      final left = inner.left + index * (segmentWidth + gap);
      final segment =
          Rect.fromLTWH(left, inner.top, segmentWidth, inner.height);
      final tile = RRect.fromRectAndRadius(segment, const Radius.circular(1.2));
      canvas.drawRRect(tile, Paint()..color = const Color(0xFF583520));
      if (fillEnd <= left) continue;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
          left, inner.top, math.min(fillEnd, segment.right), inner.bottom));
      canvas.drawRRect(tile, gold);
      canvas.restore();
    }

    if (progress > 0 && progress < 1) {
      final spark = Rect.fromCenter(
          center: Offset(fillEnd, inner.center.dy), width: 20, height: 14);
      canvas.save();
      canvas.clipRRect(rail);
      canvas.drawOval(
          spark,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0xF0FFF4BE), Color(0x00FFCA6B)],
            ).createShader(spark));
      canvas.restore();
    } else if (burst > 0) {
      canvas.drawRRect(
          rail,
          Paint()
            ..color = const Color(0xFFFFF1BD).withValues(alpha: 0.36 * burst));
    }
  }

  @override
  bool shouldRepaint(covariant _GoldGauge oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.burst != burst;
}
