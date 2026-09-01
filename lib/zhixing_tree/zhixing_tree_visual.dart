import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'zhixing_models.dart';

/// A code-rendered 3D tree that stays sharp in both the growth view and the
/// compact summary. Perspective, tapered curves and one consistent light
/// direction provide depth without shipping a stage-specific bitmap bundle.
class ZhixingTreeVisual extends StatefulWidget {
  const ZhixingTreeVisual({
    super.key,
    required this.state,
    this.animate = true,
  });

  final ZxTreeState state;
  final bool animate;

  @override
  State<ZhixingTreeVisual> createState() => _ZhixingTreeVisualState();
}

class _ZhixingTreeVisualState extends State<ZhixingTreeVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wind = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final lowComplexityStage =
        widget.state.stage == 'seed' || widget.state.stage == 'sapling';
    if (widget.animate && lowComplexityStage && !reduceMotion) {
      if (!_wind.isAnimating) _wind.repeat();
    } else {
      _wind
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ZhixingTreeVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        oldWidget.state.stage != widget.state.stage) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _wind.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: ZhixingTreePainter(widget.state, sway: _wind),
      isComplex: true,
      willChange: _wind.isAnimating,
    ),
  );
}

class ZhixingTreePainter extends CustomPainter {
  ZhixingTreePainter(this.state, {this.sway}) : super(repaint: sway);

  final ZxTreeState state;
  final Animation<double>? sway;

  static const Size _scene = Size(300, 270);
  static const Offset _base = Offset(150, 231);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = math.min(
      size.width / _scene.width,
      size.height / _scene.height,
    );
    canvas
      ..save()
      ..translate(
        (size.width - _scene.width * scale) / 2,
        (size.height - _scene.height * scale) / 2,
      )
      ..scale(scale);

    final level = switch (state.stage) {
      'seed' => 0,
      'sapling' => 1,
      'young' => 2,
      'branching' => 3,
      'canopy' => 4,
      'towering' => 5,
      _ => 1,
    };
    final vitality = (state.vitality / 100).clamp(0.0, 1.0).toDouble();
    final wind =
        math.sin((sway?.value ?? 0) * math.pi * 2) * (level == 0 ? 1.05 : 1.75);
    final compact = size.shortestSide < 145;

    _drawAtmosphere(canvas, vitality, compact);
    _drawGround(canvas, vitality, compact);
    if (level == 0) {
      _drawSeedling(canvas, vitality, wind, compact);
    } else {
      _drawTree(canvas, level, vitality, wind, compact);
    }
    canvas.restore();
  }

  void _drawAtmosphere(Canvas canvas, double vitality, bool compact) {
    final radius = compact ? 72.0 : 104.0;
    canvas.drawCircle(
      const Offset(78, 58),
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(78, 58),
          radius,
          <Color>[
            const Color(0xFFFFF4C7).withValues(alpha: 0.22 + vitality * 0.08),
            const Color(0xFFE4F3E7).withValues(alpha: 0.08),
            Colors.transparent,
          ],
          const <double>[0, 0.48, 1],
        ),
    );
    if (!compact) {
      final rect = Rect.fromCenter(
        center: const Offset(150, 154),
        width: 248,
        height: 186,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, <Color>[
            Colors.white.withValues(alpha: 0.11),
            const Color(0xFFB9D7B7).withValues(alpha: 0.035),
          ]),
      );
    }
  }

  void _drawGround(Canvas canvas, double vitality, bool compact) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(151, 240), width: 225, height: 34),
      Paint()
        ..color = Colors.black.withValues(alpha: compact ? 0.13 : 0.11)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    final earth = Rect.fromCenter(
      center: const Offset(150, 234),
      width: 229,
      height: 34,
    );
    canvas.drawOval(
      earth,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(119, 227),
          128,
          <Color>[
            Color.lerp(
              const Color(0xFF827663),
              const Color(0xFF98B784),
              vitality,
            )!,
            Color.lerp(
              const Color(0xFF625744),
              const Color(0xFF668759),
              vitality,
            )!,
            const Color(0xFF2F4631).withValues(alpha: 0.72),
          ],
          const <double>[0, 0.68, 1],
        ),
    );
    canvas.drawArc(
      earth.deflate(2),
      math.pi * 1.08,
      math.pi * 0.84,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (!compact) {
      final random = math.Random(311);
      final speck = Paint()
        ..color = const Color(0xFF425B3B).withValues(alpha: 0.28);
      for (var i = 0; i < 20; i++) {
        final x = 63 + random.nextDouble() * 174;
        final normalized = (x - 150).abs() / 115;
        final y = 229 + random.nextDouble() * (10 * (1 - normalized));
        canvas.drawCircle(Offset(x, y), 0.65 + random.nextDouble(), speck);
      }
    }
  }

  void _drawSeedling(
    Canvas canvas,
    double vitality,
    double wind,
    bool compact,
  ) {
    final dormant = state.dormant;
    final stemTop = Offset(151 + wind, 146);
    final stem = Path()
      ..moveTo(149, 225)
      ..cubicTo(145, 203, 151 + wind * 0.35, 174, stemTop.dx, stemTop.dy);
    canvas.drawPath(
      stem.shift(const Offset(2.4, 2.8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );
    canvas.drawPath(
      stem,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(143, 222),
          const Offset(158, 145),
          <Color>[
            dormant ? const Color(0xFF625B4F) : const Color(0xFF65442F),
            dormant ? const Color(0xFF8A826E) : const Color(0xFF76A45C),
            dormant ? const Color(0xFFA19A85) : const Color(0xFFA9CC72),
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.4,
    );

    final leafDark = dormant
        ? const Color(0xFF77705E)
        : Color.lerp(
            const Color(0xFF75814A),
            const Color(0xFF397B45),
            vitality,
          )!;
    final leafLight = dormant
        ? const Color(0xFFAAA28B)
        : Color.lerp(
            const Color(0xFFAAA05B),
            const Color(0xFF83B85C),
            vitality,
          )!;
    _drawLeaf(
      canvas,
      center: Offset(167 + wind, 151),
      length: 38,
      width: 18,
      angle: -0.12 + wind * 0.01,
      dark: leafDark,
      light: leafLight,
      detail: !compact,
    );
    _drawLeaf(
      canvas,
      center: Offset(136 + wind * 0.55, 169),
      length: 31,
      width: 15,
      angle: math.pi + 0.18,
      dark: leafDark,
      light: leafLight,
      detail: !compact,
    );
    _drawLeaf(
      canvas,
      center: Offset(153 + wind * 1.1, 140),
      length: 19,
      width: 8,
      angle: -1.2,
      dark: leafDark,
      light: leafLight,
      detail: !compact,
    );

    final seedRect = Rect.fromCenter(
      center: const Offset(149, 222),
      width: 30,
      height: 18,
    );
    canvas
      ..save()
      ..translate(seedRect.center.dx, seedRect.center.dy)
      ..rotate(-0.12)
      ..translate(-seedRect.center.dx, -seedRect.center.dy)
      ..drawOval(
        seedRect,
        Paint()
          ..shader = ui.Gradient.linear(
            seedRect.topLeft,
            seedRect.bottomRight,
            const <Color>[
              Color(0xFFC08B54),
              Color(0xFF87532F),
              Color(0xFF4F3425),
            ],
          ),
      )
      ..drawArc(
        seedRect.deflate(3),
        -2.7,
        2.4,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      )
      ..restore();

    if (!compact) {
      final root = Path()
        ..moveTo(149, 224)
        ..cubicTo(144, 232, 135, 234, 129, 236)
        ..moveTo(151, 225)
        ..cubicTo(156, 231, 162, 233, 170, 235);
      canvas.drawPath(
        root,
        Paint()
          ..color = const Color(0xFF76503A).withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6,
      );
    }
  }

  void _drawTree(
    Canvas canvas,
    int level,
    double vitality,
    double wind,
    bool compact,
  ) {
    final dormant = state.dormant;
    final height = <double>[0, 126, 151, 174, 192, 200][level];
    final baseWidth = <double>[0, 15, 20, 26, 32, 38][level];
    final top = Offset(150 + wind * 1.25, _base.dy - height);
    final trunk = _Branch(
      start: _base,
      control: Offset(143 - wind * 0.25, _base.dy - height * 0.56),
      end: top,
      startWidth: baseWidth,
      endWidth: math.max(4.2, baseWidth * 0.2),
      depth: 0,
    );
    final branches = _makeBranches(level, height, baseWidth, wind);
    final clusters = _makeClusters(branches, top, level, wind);
    final woodDark = dormant
        ? const Color(0xFF4F4B43)
        : Color.lerp(
            const Color(0xFF4D382C),
            const Color(0xFF563A29),
            vitality,
          )!;
    final woodMid = dormant
        ? const Color(0xFF746E61)
        : Color.lerp(
            const Color(0xFF755841),
            const Color(0xFF805437),
            vitality,
          )!;
    final woodLight = dormant
        ? const Color(0xFF948D7B)
        : Color.lerp(
            const Color(0xFF9A7652),
            const Color(0xFFB17A48),
            vitality,
          )!;

    _drawRoots(canvas, baseWidth, woodDark, woodMid);
    _drawCanopyDepth(canvas, clusters, vitality, dormant);
    for (final branch in branches.reversed) {
      _drawWood(
        canvas,
        branch,
        dark: woodDark,
        mid: woodMid,
        light: woodLight,
        barkDetail: !compact && branch.depth <= 1,
      );
    }
    _drawWood(
      canvas,
      trunk,
      dark: woodDark,
      mid: woodMid,
      light: woodLight,
      barkDetail: true,
    );
    _drawFoliage(canvas, clusters, level, vitality, dormant, compact);
    if (!dormant && vitality >= 0.64 && level >= 2) {
      _drawFruit(canvas, clusters, level);
    }
  }

  List<_Branch> _makeBranches(
    int level,
    double height,
    double baseWidth,
    double wind,
  ) {
    final random = math.Random(7109 + level * 97);
    final branches = <_Branch>[];
    final primaryCount = 2 + level * 2;
    for (var i = 0; i < primaryCount; i++) {
      final ratio = 0.25 + (i / math.max(1, primaryCount - 1)) * 0.63;
      final side = i.isEven ? -1.0 : 1.0;
      final origin = Offset(
        150 + wind * ratio * 0.7 + math.sin(ratio * math.pi) * -5,
        _base.dy - height * ratio,
      );
      final reach = (27 + level * 7.7) * (0.82 + random.nextDouble() * 0.34);
      final rise = (17 + level * 2.8) * (0.78 + random.nextDouble() * 0.52);
      final end = Offset(
        origin.dx + side * reach + wind * ratio,
        origin.dy - rise,
      );
      final primary = _Branch(
        start: origin,
        control: Offset(
          origin.dx + side * reach * 0.44,
          origin.dy + (random.nextDouble() - 0.58) * 10,
        ),
        end: end,
        startWidth: baseWidth * (0.22 + ratio * 0.16),
        endWidth: math.max(1.3, baseWidth * 0.085),
        depth: 1,
      );
      branches.add(primary);

      if (level >= 2 && i >= 1) {
        final childStart = _quadraticPoint(primary, 0.64);
        final childSide = i % 3 == 0 ? -side : side;
        final childReach = reach * (0.43 + random.nextDouble() * 0.18);
        branches.add(
          _Branch(
            start: childStart,
            control: Offset(
              childStart.dx + childSide * childReach * 0.47,
              childStart.dy - 2,
            ),
            end: Offset(
              childStart.dx + childSide * childReach + wind * 0.35,
              childStart.dy - rise * (0.62 + random.nextDouble() * 0.42),
            ),
            startWidth: math.max(2, primary.startWidth * 0.58),
            endWidth: math.max(0.9, primary.startWidth * 0.18),
            depth: 2,
          ),
        );
      }
      if (level >= 4 && i > 2 && i.isOdd) {
        final twigStart = _quadraticPoint(primary, 0.78);
        final twigReach = reach * 0.34;
        branches.add(
          _Branch(
            start: twigStart,
            control: Offset(
              twigStart.dx - side * twigReach * 0.3,
              twigStart.dy - 4,
            ),
            end: Offset(
              twigStart.dx - side * twigReach,
              twigStart.dy - rise * 0.62,
            ),
            startWidth: math.max(1.8, primary.startWidth * 0.42),
            endWidth: 0.75,
            depth: 3,
          ),
        );
      }
    }
    branches.sort((a, b) => b.depth.compareTo(a.depth));
    return branches;
  }

  List<_LeafCluster> _makeClusters(
    List<_Branch> branches,
    Offset top,
    int level,
    double wind,
  ) {
    final random = math.Random(9023 + level * 53);
    final clusters = <_LeafCluster>[
      _LeafCluster(
        top + Offset(wind * 0.35, 2),
        18 + level * 3.2,
        14 + level * 2.5,
        2,
      ),
    ];
    for (final branch in branches) {
      final radius = branch.depth == 1 ? 14 + level * 2.2 : 10 + level * 1.7;
      clusters.add(
        _LeafCluster(
          branch.end + Offset(wind * 0.3, 0),
          radius * (0.9 + random.nextDouble() * 0.28),
          radius * (0.64 + random.nextDouble() * 0.2),
          branch.depth,
        ),
      );
    }
    if (level >= 3) {
      for (var i = 0; i < level + 1; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        clusters.add(
          _LeafCluster(
            Offset(
              150 + side * (22 + i * 6) + wind * 0.6,
              top.dy + 20 + i * 10,
            ),
            20 + level * 2.2,
            14 + level * 1.4,
            3,
          ),
        );
      }
    }
    clusters.sort((a, b) => b.depth.compareTo(a.depth));
    return clusters;
  }

  void _drawRoots(
    Canvas canvas,
    double baseWidth,
    Color woodDark,
    Color woodMid,
  ) {
    final roots = <_Branch>[
      _Branch(
        start: const Offset(148, 222),
        control: const Offset(119, 231),
        end: const Offset(88, 235),
        startWidth: baseWidth * 0.46,
        endWidth: 2.4,
        depth: 0,
      ),
      _Branch(
        start: const Offset(153, 223),
        control: const Offset(180, 229),
        end: const Offset(211, 235),
        startWidth: baseWidth * 0.4,
        endWidth: 2.1,
        depth: 0,
      ),
      _Branch(
        start: const Offset(150, 225),
        control: const Offset(143, 233),
        end: const Offset(130, 239),
        startWidth: baseWidth * 0.3,
        endWidth: 1.6,
        depth: 0,
      ),
    ];
    for (final root in roots) {
      _drawWood(
        canvas,
        root,
        dark: woodDark.withValues(alpha: 0.8),
        mid: woodMid.withValues(alpha: 0.82),
        light: woodMid.withValues(alpha: 0.66),
        barkDetail: false,
      );
    }
  }

  void _drawCanopyDepth(
    Canvas canvas,
    List<_LeafCluster> clusters,
    double vitality,
    bool dormant,
  ) {
    final dark = dormant
        ? const Color(0xFF5F5C50)
        : Color.lerp(
            const Color(0xFF645F39),
            const Color(0xFF245C36),
            vitality,
          )!;
    for (final cluster in clusters) {
      final rect = Rect.fromCenter(
        center: cluster.center + const Offset(2.5, 4),
        width: cluster.rx * 2.35,
        height: cluster.ry * 2.25,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center - Offset(cluster.rx * 0.3, cluster.ry * 0.35),
            cluster.rx * 1.35,
            <Color>[
              dark.withValues(alpha: 0.42),
              dark.withValues(alpha: 0.2),
              Colors.transparent,
            ],
            const <double>[0, 0.72, 1],
          ),
      );
    }
  }

  void _drawWood(
    Canvas canvas,
    _Branch branch, {
    required Color dark,
    required Color mid,
    required Color light,
    required bool barkDetail,
  }) {
    final shape = _taperedBranchPath(branch);
    canvas.drawPath(
      shape.shift(const Offset(2.2, 2.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    final bounds = shape.getBounds().inflate(2);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.topRight,
          <Color>[dark, mid, light, mid, dark],
          const <double>[0, 0.22, 0.48, 0.72, 1],
        ),
    );
    final centerline = Path()
      ..moveTo(branch.start.dx, branch.start.dy)
      ..quadraticBezierTo(
        branch.control.dx,
        branch.control.dy,
        branch.end.dx,
        branch.end.dy,
      );
    canvas.drawPath(
      centerline,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.55, branch.startWidth * 0.08),
    );
    if (barkDetail && branch.startWidth >= 9) {
      final bark = Paint()
        ..color = dark.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.75;
      for (final t in const <double>[0.2, 0.38, 0.57, 0.73, 0.86]) {
        final point = _quadraticPoint(branch, t);
        final tangent = _quadraticTangent(branch, t);
        final normal =
            Offset(-tangent.dy, tangent.dx) / math.max(0.001, tangent.distance);
        final half = branch.startWidth * (1 - t) * 0.22;
        canvas.drawLine(
          point - normal * half,
          point + normal * half * 0.7,
          bark,
        );
      }
    }
  }

  void _drawFoliage(
    Canvas canvas,
    List<_LeafCluster> clusters,
    int level,
    double vitality,
    bool dormant,
    bool compact,
  ) {
    final leafDark = dormant
        ? const Color(0xFF686354)
        : Color.lerp(
            const Color(0xFF6D6238),
            const Color(0xFF23633A),
            vitality,
          )!;
    final leafLight = dormant
        ? const Color(0xFF9D9681)
        : Color.lerp(
            const Color(0xFFAA9550),
            const Color(0xFF79B45A),
            vitality,
          )!;
    final density = dormant ? 0.58 : 0.64 + vitality * 0.36;
    final random = math.Random(12017 + level * 199);
    final targetLeafCount = compact ? 32 + level * 9 : 50 + level * 25;
    final leavesPerCluster =
        (targetLeafCount / math.max(1, clusters.length))
            .ceil()
            .clamp(3, 10)
            .toInt();
    for (final cluster in clusters) {
      final count = math.max(3, (leavesPerCluster * density).round());
      for (var i = 0; i < count; i++) {
        final angle = random.nextDouble() * math.pi * 2;
        final radius = math.sqrt(random.nextDouble());
        final center = Offset(
          cluster.center.dx + math.cos(angle) * cluster.rx * radius,
          cluster.center.dy + math.sin(angle) * cluster.ry * radius,
        );
        final leafAngle = angle * 0.34 + (i.isEven ? -0.22 : 0.34);
        final length =
            (compact ? 8.8 : 10.2) + random.nextDouble() * (3 + level * 0.45);
        final mix = 0.15 + random.nextDouble() * 0.72;
        _drawLeaf(
          canvas,
          center: center,
          length: length,
          width: length * (0.42 + random.nextDouble() * 0.13),
          angle: leafAngle,
          dark: Color.lerp(leafDark, leafLight, mix * 0.35)!,
          light: Color.lerp(leafDark, leafLight, mix)!,
          detail: !compact && i.isEven,
        );
      }
    }
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset center,
    required double length,
    required double width,
    required double angle,
    required Color dark,
    required Color light,
    required bool detail,
  }) {
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final start = center - direction * length * 0.5;
    final end = center + direction * length * 0.5;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        center.dx - direction.dx * length * 0.08 + normal.dx * width * 0.58,
        center.dy - direction.dy * length * 0.08 + normal.dy * width * 0.58,
        center.dx + direction.dx * length * 0.18 + normal.dx * width * 0.45,
        center.dy + direction.dy * length * 0.18 + normal.dy * width * 0.45,
        end.dx,
        end.dy,
      )
      ..cubicTo(
        center.dx + direction.dx * length * 0.18 - normal.dx * width * 0.45,
        center.dy + direction.dy * length * 0.18 - normal.dy * width * 0.45,
        center.dx - direction.dx * length * 0.08 - normal.dx * width * 0.58,
        center.dy - direction.dy * length * 0.08 - normal.dy * width * 0.58,
        start.dx,
        start.dy,
      )
      ..close();
    canvas.drawPath(
      path.shift(const Offset(1.1, 1.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          start + normal * width * 0.35,
          end - normal * width * 0.35,
          <Color>[light, Color.lerp(light, dark, 0.42)!, dark],
          const <double>[0, 0.5, 1],
        ),
    );
    if (detail) {
      canvas.drawLine(
        start + direction * length * 0.14,
        end - direction * length * 0.08,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.24)
          ..strokeWidth = 0.55
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawFruit(Canvas canvas, List<_LeafCluster> clusters, int level) {
    final usable = clusters.where((item) => item.depth <= 2).toList();
    final count = math.min(2 + level, usable.length);
    for (var i = 0; i < count; i++) {
      final cluster = usable[(i * 3 + 1) % usable.length];
      final center =
          cluster.center + Offset(i.isEven ? 5 : -7, cluster.ry * 0.55);
      final radius = 3.2 + level * 0.22;
      canvas.drawCircle(
        center + const Offset(1.2, 1.6),
        radius,
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center - const Offset(1.4, 1.7),
            radius * 1.15,
            const <Color>[
              Color(0xFFFFD778),
              Color(0xFFE69B38),
              Color(0xFF9C542E),
            ],
            const <double>[0, 0.58, 1],
          ),
      );
    }
  }

  Path _taperedBranchPath(_Branch branch) {
    const samples = 16;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final point = _quadraticPoint(branch, t);
      final tangent = _quadraticTangent(branch, t);
      final normal =
          Offset(-tangent.dy, tangent.dx) / math.max(0.001, tangent.distance);
      final eased = Curves.easeOut.transform(t);
      final width =
          ui.lerpDouble(branch.startWidth, branch.endWidth, eased)! / 2;
      left.add(point + normal * width);
      right.add(point - normal * width);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final point in left.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final point in right.reversed) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Offset _quadraticPoint(_Branch branch, double t) {
    final inverse = 1 - t;
    return branch.start * (inverse * inverse) +
        branch.control * (2 * inverse * t) +
        branch.end * (t * t);
  }

  Offset _quadraticTangent(_Branch branch, double t) =>
      (branch.control - branch.start) * (2 * (1 - t)) +
      (branch.end - branch.control) * (2 * t);

  @override
  bool shouldRepaint(covariant ZhixingTreePainter oldDelegate) =>
      oldDelegate.state.toJson().toString() != state.toJson().toString() ||
      oldDelegate.sway != sway;
}

class _Branch {
  const _Branch({
    required this.start,
    required this.control,
    required this.end,
    required this.startWidth,
    required this.endWidth,
    required this.depth,
  });

  final Offset start;
  final Offset control;
  final Offset end;
  final double startWidth;
  final double endWidth;
  final int depth;
}

class _LeafCluster {
  const _LeafCluster(this.center, this.rx, this.ry, this.depth);

  final Offset center;
  final double rx;
  final double ry;
  final int depth;
}
