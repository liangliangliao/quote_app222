import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'artwork.dart';
import 'original_artwork_image.dart';
import 'region_geometry.dart';

class ArtworkCoordinates {
  const ArtworkCoordinates(this.image, this.transform);

  final Rect image;
  final TransformationController transform;

  Offset? pointAt(Offset local, {bool clamp = false}) =>
      normalizedPoint(transform.toScene(local), image, clamp: clamp);

  Offset viewPoint(Offset point) =>
      MatrixUtils.transformPoint(transform.value, imagePoint(point, image));
}

const _imageError =
    Center(child: Text('图片预览不可用', style: TextStyle(color: Colors.white)));

typedef ArtworkPointer = void Function(
    PointerEvent event, ArtworkCoordinates coordinates);

class ArtworkCanvas extends StatelessWidget {
  const ArtworkCanvas({
    super.key,
    required this.file,
    required this.aspectRatio,
    required this.transform,
    required this.panEnabled,
    this.original = false,
    this.fallbackFile,
    this.regions = const [],
    this.selectedId,
    this.draft,
    this.activePoint,
    this.feedback,
    this.pulse = false,
    this.animation,
    this.onDown,
    this.onMove,
    this.onUp,
    this.onCancel,
  });

  final File file;
  final double aspectRatio;
  final TransformationController transform;
  final bool panEnabled;
  final bool original;
  final File? fallbackFile;
  final List<ImageRegion> regions;
  final String? selectedId;
  final PolygonDraft? draft;
  final int? activePoint;
  final ImageRegion? feedback;
  final bool pulse;
  final Animation<double>? animation;
  final ArtworkPointer? onDown;
  final ArtworkPointer? onMove;
  final ArtworkPointer? onUp;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final image = artworkRect(size, aspectRatio);
          final coordinates = ArtworkCoordinates(image, transform);
          return ColoredBox(
            color: const Color(0xFF131621),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => onDown?.call(event, coordinates),
              onPointerMove: (event) => onMove?.call(event, coordinates),
              onPointerUp: (event) => onUp?.call(event, coordinates),
              onPointerCancel: (_) => onCancel?.call(),
              child: InteractiveViewer(
                transformationController: transform,
                panEnabled: panEnabled,
                minScale: 1,
                maxScale: 5,
                child: SizedBox.fromSize(
                  size: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fromRect(
                        rect: image,
                        child: Image(
                          image: original
                              ? OriginalArtworkImage(file)
                              : FileImage(file),
                          fit: BoxFit.contain,
                          filterQuality: original
                              ? FilterQuality.high
                              : FilterQuality.medium,
                          excludeFromSemantics: true,
                          errorBuilder: (context, error, stackTrace) {
                            final backup = fallbackFile;
                            if (backup == null) return _imageError;
                            return Image.file(backup,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                errorBuilder: (context, error, stackTrace) =>
                                    _imageError);
                          },
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _RegionPainter(
                            image: image,
                            transform: transform,
                            regions: regions,
                            selectedId: selectedId,
                            draft: draft,
                            activePoint: activePoint,
                            feedback: feedback,
                            pulse: pulse,
                            animation: animation,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.image,
    required this.transform,
    required this.regions,
    required this.selectedId,
    required this.draft,
    required this.activePoint,
    required this.feedback,
    required this.pulse,
    required this.animation,
  }) : super(repaint: Listenable.merge([transform, animation]));

  final Rect image;
  final TransformationController transform;
  final List<ImageRegion> regions;
  final String? selectedId;
  final PolygonDraft? draft;
  final int? activePoint;
  final ImageRegion? feedback;
  final bool pulse;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.value.getMaxScaleOnAxis();
    canvas.save();
    canvas.clipRect(image.inflate(5 / scale));
    for (final region in regions) {
      if (region.id == draft?.regionId) continue;
      final selected = region.id == selectedId;
      final review = region.source == RegionSource.proposed;
      final color = review
          ? const Color(0xFFFFCE73)
          : selected
              ? const Color(0xFFC0C3FF)
              : const Color(0xFF83E7DA);
      final opacity = region.enabled ? 1.0 : 0.55;
      final path = regionPath(region.polygon, image);
      canvas.drawPath(
          path,
          Paint()
            ..color =
                color.withValues(alpha: (selected ? 0.32 : 0.17) * opacity));
      _stroke(canvas, path, color.withValues(alpha: opacity),
          (selected ? 2.5 : 1.2) / scale,
          dashed: review);
    }
    final points = draft?.points ?? const <Offset>[];
    if (points.isNotEmpty) {
      final path = regionPath(points, image, close: points.length >= 3);
      const color = Color(0xFFC0C3FF);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.23));
      _stroke(canvas, path, color, 2 / scale);
      for (var i = 0; i < points.length; i++) {
        final center = imagePoint(points[i], image);
        canvas.drawCircle(
            center, 6 / scale, Paint()..color = const Color(0xFF171746));
        canvas.drawCircle(center, 4 / scale,
            Paint()..color = i == activePoint ? Colors.white : color);
      }
    }
    final response = feedback;
    if (response != null && animation != null) {
      final progress = animation!.value;
      final path = regionPath(response.polygon, image);
      final color = const Color(0xFFE3E4FF).withValues(alpha: 1 - progress);
      canvas.save();
      if (pulse) {
        final center = path.getBounds().center;
        final magnification = 1 + 0.13 * math.sin(math.pi * progress);
        canvas.translate(center.dx, center.dy);
        canvas.scale(magnification);
        canvas.translate(-center.dx, -center.dy);
      }
      canvas.drawPath(
          path, Paint()..color = color.withValues(alpha: color.a * 0.59));
      _stroke(canvas, path, color, 4 / scale);
      canvas.restore();
    }
    canvas.restore();
  }

  void _stroke(Canvas canvas, Path path, Color color, double width,
      {bool dashed = false}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final edge in path.computeMetrics()) {
      for (var start = 0.0; start < edge.length; start += 9 * width) {
        canvas.drawPath(
            edge.extractPath(start, math.min(start + 5 * width, edge.length)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) => true;
}
