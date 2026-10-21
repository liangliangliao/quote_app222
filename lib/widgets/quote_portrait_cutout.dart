import 'package:flutter/material.dart';

/// A fixed portrait window that keeps the source photograph sharp and blends
/// only a very narrow strip at its edge into the white paper.
///
/// The clip deliberately wraps both masks. This guarantees that no shader or
/// source pixel can paint outside the portrait's allocated rectangle.
class QuotePortraitCutout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('quote-portrait-viewport'),
      width: width,
      height: height,
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0, .055, .945, 1],
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
          ).createShader(bounds),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .022, .94, 1],
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
            ).createShader(bounds),
            child: Image(
              key: const ValueKey('quote-portrait-composited'),
              image: image,
              width: width,
              height: height,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
