import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/quote_frame_theme.dart';

/// 3D 外观木质相框：四段 45° 榫角木料、各向异性的木纤维纹、
/// 弧形年轮、清漆反射、外侧厚度和向画芯凹入的倒角阴影。
/// 四边使用固定随机种子构造纹理，滚动时不抖动，无图片网络依赖。
class WoodFrame3dOverlay extends StatelessWidget {
  const WoodFrame3dOverlay({super.key, required this.theme, this.finish});

  final QuoteFrameTheme theme;
  final String? finish;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: WoodFrame3dPainter(_resolveFinish(finish, theme)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// 光照贴图是 Flutter 画布上的 2.5D 拟真木质材质，并不使用实时 3D 模型。
enum WoodFinish { walnut, oak, rosewood, ash }

WoodFinish _resolveFinish(String? requested, QuoteFrameTheme theme) {
  switch (requested) {
    case 'walnut': return WoodFinish.walnut;
    case 'oak': return WoodFinish.oak;
    case 'rosewood': return WoodFinish.rosewood;
    case 'ash': return WoodFinish.ash;
  }
  // 默认统一采用与参考图接近的暖胡桃木，不再用灰色白蜡木。
  // 只有主动选择的 AI 风格才使用其他木料。
  return WoodFinish.walnut;
}

class WoodFrame3dPainter extends CustomPainter {
  const WoodFrame3dPainter(this.finish);

  final WoodFinish finish;

  Color get _base {
    switch (finish) {
      case WoodFinish.walnut: return const Color(0xff87502b);
      case WoodFinish.oak: return const Color(0xffb27b45);
      case WoodFinish.rosewood: return const Color(0xff7b3027);
      case WoodFinish.ash: return const Color(0xff897d6c);
    }
  }

  Color _light(double factor) => Color.lerp(_base, Colors.white, factor)!;
  Color _dark(double factor) => Color.lerp(_base, Colors.black, factor)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (!w.isFinite || !h.isFinite || w < 36 || h < 36) return;

    // 保持画芯比例较大；手机首页约 13-20dp 的实体木框。
    final edge = (w * .060).clamp(8.0, 21.0);
    const outer = 2.5;
    final x0 = outer, x1 = w - outer, y0 = outer, y1 = h - outer;
    final ix0 = x0 + edge, ix1 = x1 - edge;
    final iy0 = y0 + edge, iy1 = y1 - edge;
    if (ix1 <= ix0 || iy1 <= iy0) return;

    // 关键修复：这是一个四边木料组成的“空心框”而不是实心矩形！
    // 旧版本先 drawRRect 填满整个框面，把后方所有名言文字和插画盖住。
    // 这里用 PathOperation.difference 扣除透明画芯，只给木框的环形部分着色。
    final outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(x0, y0, x1, y1), const Radius.circular(3)));
    final innerRect = Rect.fromLTRB(ix0, iy0, ix1, iy1);
    final innerPath = Path()..addRect(innerRect);
    final ring = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawShadow(ring, Colors.black.withValues(alpha:.35),
        math.max(2, edge*.48), false);
    canvas.drawPath(ring,
      Paint()..shader=LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_light(.39),_base,_dark(.38)],
        stops: const [0,.46,1],
      ).createShader(Rect.fromLTRB(x0,y0,x1,y1)));

    final top = Path()
      ..moveTo(x0,y0)..lineTo(x1,y0)..lineTo(ix1,iy0)..lineTo(ix0,iy0)..close();
    final right = Path()
      ..moveTo(x1,y0)..lineTo(x1,y1)..lineTo(ix1,iy1)..lineTo(ix1,iy0)..close();
    final bottom = Path()
      ..moveTo(x1,y1)..lineTo(x0,y1)..lineTo(ix0,iy1)..lineTo(ix1,iy1)..close();
    final left = Path()
      ..moveTo(x0,y1)..lineTo(x0,y0)..lineTo(ix0,iy0)..lineTo(ix0,iy1)..close();

    _plank(canvas, top, Rect.fromLTRB(x0,y0,x1,iy0), horizontal:true, index:0);
    _plank(canvas, left, Rect.fromLTRB(x0,y0,ix0,y1), horizontal:false, index:1);
    _plank(canvas, right, Rect.fromLTRB(ix1,y0,x1,y1), horizontal:false, index:2);
    _plank(canvas, bottom, Rect.fromLTRB(x0,iy1,x1,y1), horizontal:true, index:3);

    final seam = Paint()
      ..color = _dark(.56).withValues(alpha:.68)
      ..strokeWidth = .85
      ..style = PaintingStyle.stroke;
    // 四角 45 度拼接缝。
    canvas.drawLine(Offset(x0,y0),Offset(ix0,iy0),seam);
    canvas.drawLine(Offset(x1,y0),Offset(ix1,iy0),seam);
    canvas.drawLine(Offset(x0,y1),Offset(ix0,iy1),seam);
    canvas.drawLine(Offset(x1,y1),Offset(ix1,iy1),seam);

    // 框内倒角：上/左高光、下/右吸光，形成 3D 内凹空间。
    final inner = Rect.fromLTRB(ix0,iy0,ix1,iy1);
    final outerHighlight = Paint()
      ..style=PaintingStyle.stroke
      ..strokeWidth=1.1
      ..color=_light(.72).withValues(alpha:.65);
    canvas.drawLine(Offset(x0+2,y0+1),Offset(x1-2,y0+1),outerHighlight);
    canvas.drawLine(Offset(x0+1,y0+2),Offset(x0+1,y1-2),outerHighlight);
    canvas.drawLine(Offset(x0+3,y1-1),Offset(x1-3,y1-1),
      Paint()..color=_dark(.65).withValues(alpha:.86)..strokeWidth=1.4);
    canvas.drawLine(Offset(x1-1,y0+3),Offset(x1-1,y1-3),
      Paint()..color=_dark(.58).withValues(alpha:.75)..strokeWidth=1.1);

    // 画芯边缘：薄金属色装饰线和阴影，避免出现“平面描边矩形”。
    canvas.drawRect(inner.inflate(1.5), Paint()
      ..color=_light(.4).withValues(alpha:.82)
      ..style=PaintingStyle.stroke
      ..strokeWidth=1.8);
    canvas.drawLine(Offset(ix0,iy0),Offset(ix1,iy0),
      Paint()..color=Colors.black.withValues(alpha:.40)..strokeWidth=math.max(1.5,edge*.16));
    canvas.drawLine(Offset(ix0,iy0),Offset(ix0,iy1),
      Paint()..color=Colors.black.withValues(alpha:.33)..strokeWidth=math.max(1.2,edge*.12));
    canvas.drawLine(Offset(ix0,iy1),Offset(ix1,iy1),
      Paint()..color=_light(.42).withValues(alpha:.72)..strokeWidth=1.4);
  }

  void _plank(Canvas canvas, Path polygon, Rect bounds, {
    required bool horizontal,
    required int index,
  }) {
    final colors = index == 0
      ? [_light(.40), _light(.15), _base, _dark(.22)]
      : index == 1
        ? [_light(.27),_base,_dark(.31),_dark(.43)]
        : index == 2
          ? [_dark(.14),_base,_dark(.44),_dark(.55)]
          : [_light(.10),_base,_dark(.23),_dark(.42)];

    canvas.save();
    canvas.clipPath(polygon);
    canvas.drawRect(bounds, Paint()..shader=LinearGradient(
      begin: horizontal ? Alignment.topCenter : Alignment.centerLeft,
      end: horizontal ? Alignment.bottomCenter : Alignment.centerRight,
      colors: colors,
      stops: const [0,.25,.78,1],
    ).createShader(bounds));

    final length = horizontal ? bounds.width : bounds.height;
    final breadth = horizontal ? bounds.height : bounds.width;
    final rand=math.Random(index * 719 + finish.index * 133 + 913);
    // 纤维沿木板长轴，叠加低频波浪和少量断续纹，让木纹非规则重复。
    for (int k=0;k<65;k++) {
      final band=breadth*(.05 + rand.nextDouble()*.90);
      final start=rand.nextDouble()*length*.12;
      final end=length*(.76 + rand.nextDouble()*.25);
      final bend=(rand.nextDouble()-.5)*breadth*.13;
      final width=.2+rand.nextDouble()*(k%6==0?1.10:.52);
      final path=Path();
      if(horizontal) {
        path.moveTo(bounds.left+start,bounds.top+band);
        path.cubicTo(bounds.left+length*.32,bounds.top+band+bend,
          bounds.left+length*.65,bounds.top+band-bend*.6,
          bounds.left+end,bounds.top+band);
      } else {
        path.moveTo(bounds.left+band,bounds.top+start);
        path.cubicTo(bounds.left+band+bend,bounds.top+length*.32,
          bounds.left+band-bend*.6,bounds.top+length*.65,
          bounds.left+band,bounds.top+end);
      }
      canvas.drawPath(path,Paint()
        ..style=PaintingStyle.stroke
        ..strokeWidth=width
        ..color=(k%3==0 ? _light(.60) : _dark(.70))
            .withValues(alpha:.055+rand.nextDouble()*.23));
    }

    // 零星的木节/年轮；与长轴同向拉伸，切角处裁掉溢出。
    final knots = (length > 110 && breadth > 10) ? 1 : 0;
    for(int i=0;i<knots;i++){
      final at=length*(.26+rand.nextDouble()*.48);
      final across=breadth*(.35+rand.nextDouble()*.3);
      final center=horizontal
        ? Offset(bounds.left+at,bounds.top+across)
        : Offset(bounds.left+across,bounds.top+at);
      for(int ring=3;ring>=1;ring--){
        final knot=Rect.fromCenter(center:center,
          width:horizontal ? breadth*(.44+ring*.13) : breadth*(.12+ring*.07),
          height:horizontal ? breadth*(.12+ring*.07) : breadth*(.44+ring*.13));
        canvas.drawOval(knot, Paint()
          ..color=_dark(.82).withValues(alpha:.14)
          ..style=PaintingStyle.stroke
          ..strokeWidth=.55);
      }
    }
    // 清漆表面的纵向窄高光是“木质光泽”，而不是金属纯色描边。
    final sheen=Rect.fromLTWH(
      bounds.left+(horizontal?0:breadth*.13),
      bounds.top+(horizontal?breadth*.12:0),
      horizontal?length:breadth*.10,
      horizontal?breadth*.13:length,
    );
    canvas.drawRect(sheen,Paint()..color=Colors.white.withValues(alpha:.095));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WoodFrame3dPainter oldDelegate) =>
      oldDelegate.finish != finish;
}
