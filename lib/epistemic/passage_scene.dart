import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'reading_scope.dart';

/// The narrow wording match is shared with the reading exercise. Other
/// passages continue to use their own cached/generated artwork.
class PassageScene extends StatelessWidget {
  final String text;
  const PassageScene(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final botanical = isBotanicalPassage(text);
    if (!botanical && !isAttentionPassage(text)) return const SizedBox.shrink();
    return Semantics(
        image: true,
        label: botanical
            ? '模拟观察，同一枝条在花蕾、开花、结果三个时刻的形态。'
            : '模拟观察，红杯和钥匙同时可见，观察者首先留意红杯。',
        child: Column(children: [
          AspectRatio(
              aspectRatio: 3.1,
              child: CustomPaint(
                  painter: _ScenePainter(botanical),
                  child: const SizedBox.expand())),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final label
                    in botanical ? ['花蕾', '开放的花', '果实'] : ['桌上的两个物体', '先留意红杯'])
                  Expanded(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12)))
              ])),
          Padding(
              padding: const EdgeInsets.all(8),
              child: Text(botanical ? '形态随时间变化 · 植物示意' : '可见与留意 · 模拟场景',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xff756b58)))),
        ]));
  }
}

class _ScenePainter extends CustomPainter {
  final bool botanical;
  const _ScenePainter(this.botanical);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 310, size.height / 100);
    final pen = Paint()..isAntiAlias = true;
    void oval(Rect r, int color) {
      pen.color = Color(color);
      canvas.drawOval(r, pen);
    }

    void line(Offset a, Offset b, int color, double width) {
      canvas.drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..color = Color(color));
    }

    if (botanical) {
      for (var i = 0; i < 3; i++) {
        final x = 52.0 + 103 * i;
        line(Offset(x - 9, 91), Offset(x, 47), 0xff6a7850, 2.2);
        canvas.save();
        canvas.translate(x - 7, 78);
        canvas.rotate(-.56);
        oval(const Rect.fromLTWH(0, -6, 22, 9), 0xff859562);
        canvas.restore();
        if (i == 0) {
          oval(Rect.fromCenter(center: Offset(x, 44), width: 16, height: 29),
              0xffba7584);
          final calyx = Path()
            ..moveTo(x - 10, 45)
            ..lineTo(x, 61)
            ..lineTo(x + 10, 42)
            ..lineTo(x + 1, 51)
            ..close();
          canvas.drawPath(calyx, pen..color = const Color(0xff6e895a));
        } else if (i == 1) {
          canvas.save();
          canvas.translate(x, 43);
          for (var j = 0; j < 6; j++) {
            canvas.rotate(math.pi / 3);
            oval(const Rect.fromLTWH(-7, -22, 14, 23), 0xffd3979b);
          }
          canvas.drawCircle(
              Offset.zero, 6, pen..color = const Color(0xffb78846));
          canvas.restore();
        } else {
          line(Offset(x, 63), Offset(x + 2, 26), 0xff61744d, 2);
          oval(
              Rect.fromCenter(center: Offset(x + 1, 46), width: 31, height: 33),
              0xffb86b4c);
          oval(Rect.fromLTWH(x - 8, 34, 6, 11), 0xffdda180);
        }
      }
    } else {
      for (final start in [0.0, 155.0]) {
        final x = start + 54;
        line(Offset(start + 14, 76), Offset(start + 139, 76), 0xffab9273, 2);
        if (start > 0)
          canvas.drawCircle(
              Offset(x, 49), 32, pen..color = const Color(0x22e3ab51));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x - 15, 36, 30, 36), const Radius.circular(5)),
            pen..color = const Color(0xffaa5948));
        oval(Rect.fromLTWH(x - 15, 32, 30, 8), 0xffd7a088);
        final stroke = Paint()
          ..color = const Color(0xffa85545)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawArc(Rect.fromLTWH(x + 9, 41, 17, 20), -math.pi / 2, math.pi,
            false, stroke);
        stroke.color = const Color(0xff79735e);
        canvas.drawCircle(Offset(start + 99, 67), 6, stroke);
        line(Offset(start + 104, 69), Offset(start + 122, 72), 0xff79735e, 3);
        line(Offset(start + 118, 71), Offset(start + 119, 66), 0xff79735e, 3);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.botanical != botanical;
}
