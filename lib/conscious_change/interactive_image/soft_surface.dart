import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'artwork.dart';
import 'region_geometry.dart';

class SurfaceContact {
  const SurfaceContact(this.region, this.position, this.pressure,
      {this.drag = Offset.zero, this.released = false});

  final ImageRegion region;
  final Offset position;
  final double pressure;
  final Offset drag;
  final bool released;

  SurfaceContact release() =>
      SurfaceContact(region, position, pressure, drag: drag, released: true);
}

class SoftSurface extends StatefulWidget {
  const SoftSurface({
    super.key,
    required this.photo,
    required this.contact,
    required this.transform,
    required this.background,
    required this.child,
  });

  final ImageProvider photo;
  final ValueListenable<SurfaceContact?> contact;
  final TransformationController transform;
  final Color background;
  final Widget child;

  @override
  State<SoftSurface> createState() => _SoftSurfaceState();
}

class _SoftSurfaceState extends State<SoftSurface>
    with SingleTickerProviderStateMixin {
  static final _program = ui.FragmentProgram.fromAsset(
      'assets/interactive_image/soft_surface.frag');

  late final _settle = AnimationController(vsync: this, value: 1);
  late final _listener = ImageStreamListener(_onImage, onError: (_, __) {});
  ImageStream? _stream;
  ImageInfo? _photo;
  ui.FragmentShader? _shader;
  bool _reduceMotion = false;
  double _start = 0;
  SurfaceContact? _contact;

  @override
  void initState() {
    super.initState();
    widget.contact.addListener(_updateContact);
    _program.then((program) {
      if (mounted) setState(() => _shader = program.fragmentShader());
    }, onError: (Object _) {
      // The original photo still renders if runtime effects are unavailable.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _resolvePhoto();
    _updateContact();
  }

  @override
  void didUpdateWidget(covariant SoftSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo != widget.photo) _resolvePhoto();
    if (oldWidget.contact != widget.contact) {
      oldWidget.contact.removeListener(_updateContact);
      widget.contact.addListener(_updateContact);
      _updateContact();
    }
  }

  void _resolvePhoto() {
    final next = widget.photo.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _photo?.dispose();
    _photo = null;
    _stream = next..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final previous = _photo;
    setState(() => _photo = info);
    previous?.dispose();
  }

  double get _indentation {
    final contact = _contact;
    if (contact == null) return 0;
    final time = _settle.value;
    if (contact.released) {
      return _start * (1 - time) * math.exp(-2.8 * time) * math.cos(5.1 * time);
    }
    return ui.lerpDouble(
        _start, contact.pressure, Curves.easeOut.transform(time))!;
  }

  void _updateContact() {
    final next = widget.contact.value;
    if (identical(next, _contact) && !_reduceMotion) return;
    _start = next != null &&
            !next.released &&
            (_contact == null ||
                _contact!.released ||
                _contact!.region.id != next.region.id)
        ? next.pressure * 0.46
        : _indentation;
    _contact = next;
    if (next == null || _reduceMotion) {
      if (next?.released ?? false) _contact = null;
      _settle.value = 1;
      return;
    }
    _settle.duration = Duration(milliseconds: next.released ? 380 : 140);
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    widget.contact.removeListener(_updateContact);
    _stream?.removeListener(_listener);
    _photo?.dispose();
    _shader?.dispose();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _SoftSurfacePainter(this)),
          ),
        ),
      ]);
}

class _SoftSurfacePainter extends CustomPainter {
  _SoftSurfacePainter(this.surface)
      : super(
            repaint:
                Listenable.merge([surface._settle, surface.widget.transform]));

  final _SoftSurfaceState surface;

  @override
  void paint(Canvas canvas, Size size) {
    final contact = surface._contact;
    final photo = surface._photo?.image;
    final shader = surface._shader;
    final indentation = surface._indentation;
    if (contact == null ||
        photo == null ||
        shader == null ||
        indentation.abs() < 0.002 ||
        size.isEmpty) return;

    final bounds = Offset.zero & size;
    final fitted = applyBoxFit(BoxFit.contain,
        Size(photo.width.toDouble(), photo.height.toDouble()), size);
    final photoRect = Alignment.center.inscribe(fitted.destination, bounds);
    final path = regionPath(contact.region.polygon, bounds);
    final center = imagePoint(contact.position, bounds);
    final scale = surface.widget.transform.value.getMaxScaleOnAxis();
    final radius =
        (path.getBounds().shortestSide * scale * 0.58).clamp(25.0, 72.0) /
            scale;
    final drag = surface._reduceMotion
        ? Offset.zero
        : contact.drag * (1 - Curves.easeOut.transform(surface._settle.value));
    final background = surface.widget.background;
    shader
      ..setFloat(0, photoRect.left)
      ..setFloat(1, photoRect.top)
      ..setFloat(2, photoRect.width)
      ..setFloat(3, photoRect.height)
      ..setFloat(4, center.dx)
      ..setFloat(5, center.dy)
      ..setFloat(6, drag.dx)
      ..setFloat(7, drag.dy)
      ..setFloat(8, radius)
      ..setFloat(9, indentation)
      ..setFloat(10, background.r)
      ..setFloat(11, background.g)
      ..setFloat(12, background.b)
      ..setImageSampler(0, photo);
    canvas.save();
    canvas.clipRect(photoRect);
    canvas.clipPath(path);
    canvas.drawRect(Rect.fromCircle(center: center, radius: radius * 1.3),
        Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SoftSurfacePainter oldDelegate) => true;
}
