import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Reads the unchanged source at its original resolution and keeps the frame
/// still so that even animated WebP files stay aligned with their regions.
class OriginalArtworkImage extends FileImage {
  const OriginalArtworkImage(super.file);

  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_decode(key, decode));

  Future<ImageInfo> _decode(FileImage key, ImageDecoderCallback decode) async {
    final codec =
        await decode(await ui.ImmutableBuffer.fromFilePath(key.file.path));
    try {
      return ImageInfo(
          image: (await codec.getNextFrame()).image, scale: key.scale);
    } finally {
      codec.dispose();
    }
  }
}
