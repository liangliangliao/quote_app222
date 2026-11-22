import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import 'touch_effort.dart';

class EffortMeter extends StatelessWidget {
  const EffortMeter({super.key, required this.effort, this.idleHint});

  final TouchEffort effort;
  final String? idleHint;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<EffortProgress>(
        valueListenable: effort,
        builder: (context, progress, _) {
          final active = progress.gesture;
          final value = progress.percentLabel;
          final hint = progress.reached
              ? '已达成'
              : switch (active) {
                  TouchGesture.tap => '继续点击同一区域',
                  TouchGesture.hold => '继续按住',
                  TouchGesture.swipe => '继续滑动',
                  null => idleHint ?? '连续操作，达到 100% 后触发反馈',
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
                            height: 19,
                            child: _EffortRail(
                              progress: progress,
                              fraction: fraction,
                              animate: !reduceMotion,
                            ),
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

class _EffortRail extends StatefulWidget {
  const _EffortRail(
      {required this.progress, required this.fraction, required this.animate});

  final EffortProgress progress;
  final double fraction;
  final bool animate;

  @override
  State<_EffortRail> createState() => _EffortRailState();
}

class _EffortRailState extends State<_EffortRail>
    with SingleTickerProviderStateMixin {
  static const _pulseTime = 0.42;
  static const _burstTime = 0.66;
  final _clock = ValueNotifier(0.0);
  late final Ticker _ticker = createTicker(_tick);
  double _lastImpulse = 0;

  bool get _steady =>
      widget.progress.gesture == TouchGesture.hold && !widget.progress.reached;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant _EffortRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        (!identical(oldWidget.progress, widget.progress) &&
            (!_steady || oldWidget.progress.gesture != TouchGesture.hold))) {
      _syncClock();
    }
  }

  void _syncClock() {
    if (!widget.animate || widget.progress.gesture == null) {
      _ticker.stop();
      return;
    }
    if (!_ticker.isActive) {
      _clock.value = 0;
      _ticker.start();
    }
    _lastImpulse = _clock.value;
  }

  void _tick(Duration elapsed) {
    _clock.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final duration = widget.progress.reached ? _burstTime : _pulseTime;
    if (!_steady && _clock.value - _lastImpulse >= duration) _ticker.stop();
  }

  double get _burst => widget.animate && widget.progress.reached
      ? (1 - (_clock.value - _lastImpulse) / _burstTime).clamp(0.0, 1.0)
      : 0;

  double get _energy {
    if (!widget.animate || widget.progress.gesture == null) return 0;
    if (_steady) return 0.54 + 0.19 * math.sin(_clock.value * 6);
    if (widget.progress.reached) return _burst;
    final remaining =
        (1 - (_clock.value - _lastImpulse) / _pulseTime).clamp(0.0, 1.0);
    return widget.progress.impulse * remaining * remaining;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: CustomPaint(painter: _GoldGauge(this)));
}

class _GoldGauge extends CustomPainter {
  _GoldGauge(this.motion) : super(repaint: motion._clock);

  final _EffortRailState motion;

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 20;
    const gap = 2.0;
    final progress = motion.widget.fraction;
    final burst = motion._burst;
    final energy = motion._energy;
    final speed = switch (motion.widget.progress.gesture) {
      TouchGesture.swipe => 17.0,
      TouchGesture.tap => 13.0,
      _ => 8.0,
    };
    final phase = motion._clock.value * speed;
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

    final tilePaint = Paint();
    final gold = Paint();
    for (var index = 0; index < segments; index++) {
      final left = inner.left + index * (segmentWidth + gap);
      final segment =
          Rect.fromLTWH(left, inner.top, segmentWidth, inner.height);
      final tile = RRect.fromRectAndRadius(segment, const Radius.circular(1.2));
      final wave = (1 + math.sin(index * 0.76 - phase)) / 2;
      final heat = wave * wave * energy;
      tilePaint.color =
          Color.lerp(const Color(0xFF583520), const Color(0xFFA44C19), heat)!;
      canvas.drawRRect(tile, tilePaint);
      if (fillEnd <= left) continue;
      final molten = Rect.fromLTRB(left, inner.top + energy * (1 - wave) * 4,
          segment.right, inner.bottom);
      gold.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(const Color(0xFFFFE39C), const Color(0xFFFFFFE7), heat)!,
          Color.lerp(const Color(0xFFF9AD40), const Color(0xFFFFD95E), heat)!,
          const Color(0xFFBD6B1C),
        ],
      ).createShader(molten);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
          left, inner.top, math.min(fillEnd, segment.right), inner.bottom));
      canvas.drawRRect(
          RRect.fromRectAndRadius(molten, const Radius.circular(1.2)), gold);
      canvas.restore();
    }

    if (progress > 0 && progress < 1) {
      final spark = Rect.fromCenter(
          center: Offset(fillEnd, inner.center.dy),
          width: 12 + energy * 28,
          height: 10 + energy * 14);
      canvas.save();
      canvas.clipRRect(rail);
      canvas.drawOval(
          spark,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFF4BE).withValues(alpha: 0.64 + energy * 0.36),
                const Color(0x00FFCA6B),
              ],
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
  bool shouldRepaint(covariant _GoldGauge oldDelegate) => true;
}
