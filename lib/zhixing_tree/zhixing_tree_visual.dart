import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'zhixing_models.dart';

class ZhixingTreePainter extends CustomPainter {
  final ZxTreeState state;

  const ZhixingTreePainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.84);
    final scale =
        math.min(size.width / 300, size.height / 270).toDouble();
    final vitality = (state.vitality / 100).clamp(0.0, 1.0).toDouble();
    final dormant = state.dormant;
    final leafColor = dormant
        ? const Color(0xFF9A927E)
        : Color.lerp(
            const Color(0xFF9A6C43),
            const Color(0xFF3F8D52),
            vitality,
          )!;
    final trunk = Paint()
      ..color = dormant ? const Color(0xFF71695D) : const Color(0xFF77563B)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leaves = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;
    final ground = Paint()
      ..color = const Color(0xFF6E8A51).withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 9 * scale),
        width: 210 * scale,
        height: 32 * scale,
      ),
      ground,
    );

    if (state.stage == 'seed') {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy - 4 * scale),
          width: 28 * scale,
          height: 18 * scale,
        ),
        Paint()..color = const Color(0xFF8A5A35),
      );
      trunk.strokeWidth = 4 * scale;
      canvas.drawLine(
        Offset(center.dx, center.dy - 6 * scale),
        Offset(center.dx, center.dy - 40 * scale),
        trunk,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + 10 * scale, center.dy - 34 * scale),
          width: 23 * scale,
          height: 12 * scale,
        ),
        leaves,
      );
      return;
    }

    final level = switch (state.stage) {
      'sapling' => 1,
      'young' => 2,
      'branching' => 3,
      'canopy' => 4,
      'towering' => 5,
      _ => 1,
    };
    final height = (82 + level * 22) * scale;
    final top = Offset(center.dx, center.dy - height);
    trunk.strokeWidth = (8 + level * 1.6) * scale;
    canvas.drawLine(center, top, trunk);

    final branchCount = 2 + level * 2;
    final random = math.Random(37 + level);
    for (var i = 0; i < branchCount; i++) {
      final ratio = 0.28 + (i / math.max(1, branchCount - 1)) * 0.58;
      final origin = Offset(center.dx, center.dy - height * ratio);
      final direction = i.isEven ? -1.0 : 1.0;
      final length =
          (30 + level * 7 + random.nextDouble() * 14) * scale;
      final end = Offset(
        origin.dx + direction * length,
        origin.dy - (17 + random.nextDouble() * 18) * scale,
      );
      trunk.strokeWidth = (4 + level * 0.45) * scale;
      canvas.drawLine(origin, end, trunk);
      final radius = (16 + level * 3.5) * scale;
      canvas.drawCircle(end, radius, leaves);
      if (level >= 3) {
        canvas.drawCircle(
          Offset(end.dx + direction * 10 * scale, end.dy - 8 * scale),
          radius * 0.78,
          leaves,
        );
      }
    }
    canvas.drawCircle(
      top,
      (25 + level * 5) * scale,
      leaves,
    );

    if (vitality >= 0.6 && !dormant) {
      final fruit = Paint()..color = const Color(0xFFE4A741);
      final fruitCount = math.max(1, level - 1).toInt();
      for (var i = 0; i < fruitCount; i++) {
        final x = center.dx + (i.isEven ? -1 : 1) * (18 + i * 8) * scale;
        final y = top.dy + (28 + i * 11) * scale;
        canvas.drawCircle(Offset(x, y), 4.5 * scale, fruit);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ZhixingTreePainter oldDelegate) =>
      oldDelegate.state.toJson().toString() != state.toJson().toString();
}
