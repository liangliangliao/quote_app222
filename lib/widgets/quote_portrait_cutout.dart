import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/quote_portrait_matte.dart';

/// A sharp portrait with a border-connected background matte. The face and
/// clothing stay opaque; only the narrow perimeter and the bust's lower edge fade.
class QuotePortraitCutout extends StatefulWidget {
  const QuotePortraitCutout({
    super.key,
    required this.image,
    required this.width,
    required this.height,
  });
  final ImageProvider image;
  final double width;
  final double height;

  @override
  State<QuotePortraitCutout> createState() => _QuotePortraitCutoutState();
}

class _QuotePortraitCutoutState extends State<QuotePortraitCutout> {
  static final _cache = <Object, Future<Uint8List>>{};
  Future<Uint8List>? _portrait;
  ImageConfiguration? _configuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final configuration = createLocalImageConfiguration(context);
    if (_configuration != configuration) {
      _configuration = configuration;
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant QuotePortraitCutout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _load();
  }

  void _load() {
    final provider = widget.image;
    final configuration = _configuration ?? ImageConfiguration.empty;
    _portrait = () async {
      final key = await provider.obtainKey(configuration);
      if (_cache.length >= 24 && !_cache.containsKey(key)) {
        _cache.remove(_cache.keys.first);
      }
      return _cache.putIfAbsent(key, () => _prepare(provider, configuration));
    }();
  }

  static Future<Uint8List> _prepare(
      ImageProvider provider, ImageConfiguration configuration) async {
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(configuration);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) { if (!completer.isCompleted) completer.complete(info.clone()); },
      onError: (Object error, StackTrace? stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    ImageInfo? info;
    ui.Image? result;
    try {
      info = await completer.future.timeout(const Duration(seconds: 15));
      final data = await info.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Portrait pixels are unavailable');
      final pixels = await compute(mattePortraitRgba, <String, Object>{
        'pixels': data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        'width': info.image.width,
        'height': info.image.height,
      });
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(pixels, info.image.width, info.image.height,
          ui.PixelFormat.rgba8888, decoded.complete);
      result = await decoded.future;
      final png = await result.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Portrait encoding failed');
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      stream.removeListener(listener);
      info?.dispose();
      result?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [0, .035, .965, 1],
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: [0, .025, .88, 1],
            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          ).createShader(bounds),
          child: FutureBuilder<Uint8List>(
            future: _portrait,
            builder: (context, snapshot) => Image(
              image: snapshot.hasData ? MemoryImage(snapshot.data!) : widget.image,
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              gaplessPlayback: false,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
