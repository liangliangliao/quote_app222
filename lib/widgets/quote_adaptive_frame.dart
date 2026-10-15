import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/quote_frame_theme.dart';

/// 原生可绘制的语义相框。文字由上层 Flutter Text 渲染，避免 AI 绘制错字。
/// 即便没有网络/API Key，每条名言也会自动得到与主题相应的画面。
class QuoteAdaptiveFrame extends StatelessWidget {
  const QuoteAdaptiveFrame({
    super.key,
    required this.theme,
    this.aiImagePath,
    this.quoteCharacters = 0,
  });

  final QuoteFrameTheme theme;
  final String? aiImagePath;
  final int quoteCharacters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final edge = (constraints.maxWidth * .060).clamp(8.0, 21.0) + 2.5;
      final longQuote = quoteCharacters > 80;
      final midQuote = quoteCharacters > 48;
      final path = aiImagePath;
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _SemanticFramePainter(theme)),
          if (path != null && path.isNotEmpty)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(edge),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    child: Image.file(
                      File(path),
                      key: ValueKey(path),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          // 即使长名言也能阅读：文字优先；画的高对比主体限定在底部。
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(edge),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .44, .75, 1],
                    colors: [
                      const Color(0xfffaf7ef).withValues(alpha:.94),
                      const Color(0xfffaf7ef).withValues(alpha:.89),
                      const Color(0xfffaf7ef).withValues(alpha: longQuote ? .79 : (midQuote ? .66 : .38)),
                      const Color(0xfffaf7ef).withValues(alpha: longQuote ? .62 : (midQuote ? .43 : .13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _FrameColors {
  const _FrameColors(this.wood, this.paper, this.ink, this.accent);
  final Color wood;
  final Color paper;
  final Color ink;
  final Color accent;
}

_FrameColors _colors(QuoteScene scene) {
  switch (scene) {
    case QuoteScene.growth:
      return const _FrameColors(Color(0xff806d4d), Color(0xfff7f5e8), Color(0xff637b60), Color(0xffadc6a0));
    case QuoteScene.courage:
      return const _FrameColors(Color(0xff5a5966), Color(0xfff5f1eb), Color(0xff647082), Color(0xffdfae74));
    case QuoteScene.resilience:
      return const _FrameColors(Color(0xff60594c), Color(0xfff5f4ec), Color(0xff53665d), Color(0xffd7b585));
    case QuoteScene.serenity:
      return const _FrameColors(Color(0xff6d776d), Color(0xfff4f7f3), Color(0xff799792), Color(0xffcadbd4));
    case QuoteScene.time:
      return const _FrameColors(Color(0xff806445), Color(0xfffbf3e5), Color(0xffad8963), Color(0xffe2c69c));
    case QuoteScene.affection:
      return const _FrameColors(Color(0xff876b6a), Color(0xfffff5f2), Color(0xffb98892), Color(0xffeac4c6));
    case QuoteScene.reflection:
      return const _FrameColors(Color(0xff555d74), Color(0xfff1f2f7), Color(0xff7b829f), Color(0xffc4cadd));
    case QuoteScene.freedom:
      return const _FrameColors(Color(0xff637b86), Color(0xfff1f7f8), Color(0xff7095a1), Color(0xffc4d9da));
    case QuoteScene.hope:
      return const _FrameColors(Color(0xffa07757), Color(0xfffff7e9), Color(0xffc29876), Color(0xfff3c985));
    case QuoteScene.journey:
      return const _FrameColors(Color(0xff785d46), Color(0xfff9f3e8), Color(0xff8b998a), Color(0xffd7c39f));
  }
}

class _SemanticFramePainter extends CustomPainter {
  const _SemanticFramePainter(this.theme);
  final QuoteFrameTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = _colors(theme.scene);
    final w = size.width, h = size.height;
    final edge = (w * .060).clamp(8.0, 21.0) + 2.5;
    canvas.drawRect(Offset.zero & size, Paint()..color = c.paper);
    final paper = Rect.fromLTWH(edge, edge, w - edge * 2, h - edge * 2);
    canvas.drawRect(paper, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.paper, Color.lerp(c.paper, c.accent, .16)!],
      ).createShader(paper));

    canvas.save();
    canvas.clipRect(paper);
    final stroke = Paint()
      ..color = c.ink.withOpacity(.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, w * .0024)
      ..strokeCap = StrokeCap.round;
    final faint = Paint()
      ..color = c.accent.withOpacity(.30)
      ..style = PaintingStyle.fill;

    // 使用归一化坐标，大小卡片共享同一幅隐喻图。
    Offset p(double x, double y) => Offset(w * x, h * y);
    void line(double x1, double y1, double x2, double y2, [Paint? paint]) =>
      canvas.drawLine(p(x1,y1), p(x2,y2), paint ?? stroke);
    void circle(double x, double y, double radius, Paint paint) =>
      canvas.drawCircle(p(x,y), w * radius, paint);

    void mountains({bool peak = false}) {
      final back = Path()
        ..moveTo(0, h*.89)
        ..lineTo(w*.17, h*.72)
        ..lineTo(w*.34, h*.81)
        ..lineTo(w*.54, peak ? h*.63 : h*.74)
        ..lineTo(w*.76, h*.85)
        ..lineTo(w, h*.71)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(back, Paint()..color = c.accent.withOpacity(.27));
      final front = Path()
        ..moveTo(0,h*.96)
        ..lineTo(w*.21,h*.84)
        ..lineTo(w*.44,h*.92)
        ..lineTo(w*.69,h*.79)
        ..lineTo(w,h*.92)
        ..lineTo(w,h)..lineTo(0,h)..close();
      canvas.drawPath(front, Paint()..color = c.ink.withOpacity(.19));
    }

    void sun(double x, double y, double radius) {
      circle(x,y,radius, Paint()..color=c.accent.withOpacity(.39));
      circle(x,y,radius*.60, Paint()..color=c.accent.withOpacity(.53));
    }

    void birds(double x, double y) {
      for (int k=0;k<3;k++) {
        final xx=x+k*.08, yy=y+(k%2)*.018;
        final bird=Path()..moveTo(w*(xx-.022), h*yy)
          ..quadraticBezierTo(w*(xx-.008),h*(yy-.018),w*xx,h*yy)
          ..quadraticBezierTo(w*(xx+.012),h*(yy-.013),w*(xx+.024),h*(yy-.003));
        canvas.drawPath(bird, stroke);
      }
    }

    void tree({bool weather=false}) {
      final trunk=Path()
        ..moveTo(w*.77,h*.96)
        ..cubicTo(w*.77,h*.84,w*.72,h*.78,w*.72,h*.68)
        ..moveTo(w*.73,h*.80)
        ..quadraticBezierTo(w*.61,h*.73,w*.61,h*.66)
        ..moveTo(w*.73,h*.76)
        ..quadraticBezierTo(w*.86,h*.69,w*.83,h*.63)
        ..moveTo(w*.72,h*.70)
        ..quadraticBezierTo(w*.69,h*.64,w*.67,h*.62);
      canvas.drawPath(trunk, Paint()
        ..color=c.ink.withOpacity(.69)
        ..style=PaintingStyle.stroke
        ..strokeWidth=math.max(2,w*.015)
        ..strokeCap=StrokeCap.round);
      for(final center in <Offset>[p(.61,.65),p(.69,.61),p(.83,.64),p(.84,.71),p(.66,.72)]) {
        canvas.drawOval(
          Rect.fromCenter(center:center,width:w*(weather ? .18 : .15),height:h*.063),
          Paint()..color=c.ink.withOpacity(weather ? .40 : .29),
        );
      }
    }

    void water() {
      for(var i=0;i<6;i++) {
        final y=.81+i*.034;
        line(.09,y,.40+(i%3)*.09,y, stroke);
        line(.59,y+.008,.91,y+.008, stroke);
      }
    }

    void flowerBranch() {
      final path=Path()..moveTo(w*.77,h*.99)
        ..cubicTo(w*.63,h*.88,w*.77,h*.71,w*.64,h*.60)
        ..moveTo(w*.72,h*.82)
        ..quadraticBezierTo(w*.51,h*.79,w*.49,h*.70);
      canvas.drawPath(path, stroke..strokeWidth=math.max(1.3,w*.009));
      for(final a in <Offset>[p(.64,.60),p(.72,.71),p(.52,.71),p(.62,.82),p(.74,.87)]) {
        for(var k=0;k<5;k++) {
          final angle=k*math.pi*2/5;
          canvas.drawCircle(
            a+Offset(math.cos(angle)*w*.019,math.sin(angle)*w*.019),
            w*.017, Paint()..color=c.ink.withOpacity(.25),
          );
        }
        canvas.drawCircle(a,w*.008,Paint()..color=c.wood.withOpacity(.32));
      }
    }

    switch (theme.scene) {
      case QuoteScene.growth:
        mountains(); tree(); sun(.22,.79,.055);
        break;
      case QuoteScene.courage:
        mountains(peak:true); sun(.79,.63,.08); birds(.18,.69);
        break;
      case QuoteScene.resilience:
        mountains(peak:true); tree(weather:true); sun(.19,.70,.065);
        for(var i=0;i<7;i++) line(.13+i*.10,.60,.07+i*.10,.65,stroke);
        break;
      case QuoteScene.serenity:
        mountains(); water();
        line(.20,.06,.13,.19); line(.20,.10,.28,.18);
        line(.23,.12,.31,.14); line(.18,.12,.11,.15);
        sun(.81,.75,.06);
        break;
      case QuoteScene.time:
        mountains(); sun(.78,.70,.065);
        final x=w*.76, y=h*.83, rw=w*.055, rh=h*.11;
        final glass=Path()..moveTo(x-rw,y-rh)..lineTo(x+rw,y-rh)
          ..lineTo(x-rw*.8,y+rh)..lineTo(x+rw*.8,y+rh)
          ..lineTo(x-rw,y-rh)..close();
        canvas.drawPath(glass,stroke);
        circle(.76,.84,.018,Paint()..color=c.ink.withOpacity(.30));
        break;
      case QuoteScene.affection:
        flowerBranch(); sun(.21,.74,.08);
        break;
      case QuoteScene.reflection:
        mountains();
        for(var i=0;i<20;i++) {
          final x=.13+(i*37%71)/100;
          final y=.63+(i*13%27)/100;
          circle(x,y,.0035+(i%3)*.0017,Paint()..color=c.ink.withOpacity(.40));
        }
        circle(.73,.71,.072,stroke);
        break;
      case QuoteScene.freedom:
        mountains(); water(); birds(.54,.69); birds(.19,.73);
        break;
      case QuoteScene.hope:
        mountains(); sun(.5,.73,.105); water();
        break;
      case QuoteScene.journey:
        mountains(peak:true); sun(.79,.66,.075);
        final road=Path()..moveTo(w*.44,h)
          ..quadraticBezierTo(w*.60,h*.86,w*.48,h*.81)
          ..quadraticBezierTo(w*.42,h*.77,w*.59,h*.73);
        canvas.drawPath(road,stroke..strokeWidth=math.max(2.0,w*.018));
        break;
    }
    // 少量淡色纸纹点，保持顶部文本区域清洁。
    for (int i=0;i<28;i++) {
      circle(.1+(i*29%81)/100,.12+(i*17%54)/100,.0013,faint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SemanticFramePainter old) => old.theme.scene != theme.scene;
}

