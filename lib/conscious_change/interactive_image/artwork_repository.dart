import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'artwork.dart';
import 'original_artwork_image.dart';

const maxArtworkBytes = 25 * 1024 * 1024;
const _maxSourcePixels = 32 * 1000 * 1000;
const _maxPreviewSide = 1920;

class ArtworkImportException implements Exception {
  const ArtworkImportException(this.message);
  final String message;
}

class ArtworkRepository {
  ArtworkRepository({Directory? directory}) : _directory = directory;

  final Directory? _directory;
  late final Future<Directory> _root = _open();

  Future<Directory> _open() async {
    final root = _directory ??
        Directory(p.join(
          (await getApplicationSupportDirectory()).path,
          'interactive_image_v1',
        ));
    await root.create(recursive: true);
    await for (final entry in root.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (name.startsWith('.stage-') || name.startsWith('.deleted-')) {
        try {
          await entry.delete(recursive: true);
        } on FileSystemException {
          // Retry stale cleanup the next time the library opens.
        }
      }
    }
    return root;
  }

  File originalFile(Directory folder, Artwork artwork) =>
      File(p.join(folder.path, 'original.${artwork.format}'));

  File mediaFile(Directory folder, String name) {
    if (!validFeedbackMediaName(name)) throw const FormatException();
    return File(p.join(folder.path, 'media', name));
  }

  Future<void> cleanUnusedMedia(Directory folder, ArtworkEdits saved) async {
    final media = Directory(p.join(folder.path, 'media'));
    if (!await media.exists()) return;
    final referenced = {
      for (final region in saved.regions)
        for (final step in region.allSteps)
          if (step.action.isFile) step.value,
    };
    await for (final file in media.list(followLinks: false)) {
      if (file is File && !referenced.contains(p.basename(file.path))) {
        await file.delete();
      }
    }
  }

  File previewFile(Directory folder) =>
      File(p.join(folder.path, 'preview.png'));
  File thumbnailFile(Directory folder) =>
      File(p.join(folder.path, 'thumbnail.png'));

  Future<Directory> folderFor(Artwork artwork) async => _folder(artwork.id);

  Future<Directory> _folder(String id) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) throw const FormatException();
    return Directory(p.join((await _root).path, id));
  }

  Future<List<Artwork>> list() async {
    final artworks = <Artwork>[];
    await for (final entry in (await _root).list(followLinks: false)) {
      if (entry is! Directory || p.basename(entry.path).startsWith('.'))
        continue;
      try {
        final artwork = Artwork.fromJson(await _read(entry, 'artwork.json'));
        if (artwork.id == p.basename(entry.path)) artworks.add(artwork);
      } on Exception {
        // Keep a damaged entry isolated from the other works.
      }
    }
    return artworks..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Artwork> importImage(File input, String name) async {
    final size = await input.length();
    if (size > maxArtworkBytes) {
      throw const ArtworkImportException('图片超过 25 MB，请选择较小的图片。');
    }
    final bytes = await input.readAsBytes();
    final format = _imageFormat(bytes);
    if (format == null) {
      throw const ArtworkImportException('无法读取这张图片，请选择有效的 JPG、PNG 或 WebP。');
    }
    final stage = await (await _root).createTemp('.stage-');
    try {
      final dimensions = await _writePreviews(stage, bytes);
      final artwork = Artwork(
        id: newArtworkId(),
        title: _titleFromName(name),
        format: format,
        width: dimensions.$1,
        height: dimensions.$2,
        createdAt: DateTime.now(),
      );
      await File(p.join(stage.path, 'original.$format'))
          .writeAsBytes(bytes, flush: true);
      await _write(stage, 'artwork.json', artwork.toJson());
      await _write(stage, 'edits.json', const ArtworkEdits().toJson());
      await stage.rename((await _folder(artwork.id)).path);
      return artwork;
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  String? _imageFormat(List<int> bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) return 'jpg';
    if (const [137, 80, 78, 71, 13, 10, 26, 10]
        .asMap()
        .entries
        .every((entry) => bytes[entry.key] == entry.value)) return 'png';
    if (String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') return 'webp';
    return null;
  }

  String _titleFromName(String name) {
    final title = p.basenameWithoutExtension(name).trim();
    return title.isEmpty ? '未命名作品' : String.fromCharCodes(title.runes.take(60));
  }

  Future<(int, int)> _writePreviews(Directory folder, Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final pixels = descriptor.width * descriptor.height;
      if (pixels > _maxSourcePixels ||
          math.max(descriptor.width, descriptor.height) > 16000) {
        throw const ArtworkImportException('图片分辨率过高，请缩小后重新导入。');
      }
      final isWide = descriptor.width >= descriptor.height;
      codec = await descriptor.instantiateCodec(
        targetWidth:
            isWide ? math.min(_maxPreviewSide, descriptor.width) : null,
        targetHeight:
            isWide ? null : math.min(_maxPreviewSide, descriptor.height),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const ArtworkImportException('无法生成图片预览。');
      await previewFile(folder).writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true);
      await _writeThumbnail(folder, image);
      return (descriptor.width, descriptor.height);
    } on StateError {
      throw const ArtworkImportException('图片已损坏或设备无法解码，请换一张图片。');
    } on ArgumentError {
      throw const ArtworkImportException('图片已损坏或设备无法解码，请换一张图片。');
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> _writeThumbnail(Directory folder, ui.Image source) async {
    // Persist only a tiny, blurred derivative for the private library grid.
    const side = 18.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const target = Rect.fromLTWH(0, 0, side, side);
    final size = Size(source.width.toDouble(), source.height.toDouble());
    final crop = Alignment.center.inscribe(
        applyBoxFit(BoxFit.cover, size, target.size).source,
        Offset.zero & size);
    canvas.drawImageRect(
        source,
        crop,
        target,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ui.ImageFilter.blur(
              sigmaX: 2, sigmaY: 2, tileMode: TileMode.clamp));
    final picture = recorder.endRecording();
    try {
      final thumbnail = await picture.toImage(side.toInt(), side.toInt());
      try {
        final data = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          await thumbnailFile(folder).writeAsBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              flush: true);
        }
      } finally {
        thumbnail.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  Future<Artwork> rename(Artwork artwork, String title) async {
    final updated = artwork.renamed(title);
    await _write(await _folder(artwork.id), 'artwork.json', updated.toJson());
    return updated;
  }

  Future<Artwork> duplicate(Artwork artwork) async {
    final source = await _folder(artwork.id);
    final stage = await (await _root).createTemp('.stage-');
    try {
      await _copyContents(source, stage);
      final duplicate = Artwork(
        id: newArtworkId(),
        title: '${String.fromCharCodes(artwork.title.runes.take(54))} · 副本',
        format: artwork.format,
        width: artwork.width,
        height: artwork.height,
        createdAt: DateTime.now(),
      );
      await _write(stage, 'artwork.json', duplicate.toJson());
      await stage.rename((await _folder(duplicate.id)).path);
      return duplicate;
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<void> _copyContents(Directory source, Directory destination) async {
    await for (final entry in source.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (name.endsWith('.tmp')) continue;
      final target = p.join(destination.path, name);
      if (entry is File) await entry.copy(target);
      if (entry is Directory)
        await _copyContents(entry, await Directory(target).create());
    }
  }

  Future<void> delete(Artwork artwork) async {
    final source = await _folder(artwork.id);
    await OriginalArtworkImage(originalFile(source, artwork)).evict();
    await FileImage(previewFile(source)).evict();
    await FileImage(thumbnailFile(source)).evict();
    final removed = await source
        .rename(p.join((await _root).path, '.deleted-${artwork.id}'));
    await removed.delete(recursive: true);
  }

  Future<ArtworkEdits> loadEdits(Directory folder) async =>
      ArtworkEdits.fromJson(await _read(folder, 'edits.json'));

  Future<void> saveEdits(Directory folder, ArtworkEdits edits) =>
      _write(folder, 'edits.json', edits.toJson());

  Future<FeedbackSettings> loadSettings() async {
    final root = await _root;
    if (!await File(p.join(root.path, 'feedback.json')).exists())
      return const FeedbackSettings();
    return FeedbackSettings.fromJson(await _read(root, 'feedback.json'));
  }

  Future<void> saveSettings(FeedbackSettings settings) async =>
      _write(await _root, 'feedback.json', settings.toJson());

  Future<void> saveAnalysis(
      Directory folder, String id, Map<String, Object?> raw) async {
    final runs = await Directory(p.join(folder.path, 'analysis')).create();
    await _write(runs, '$id.json', raw);
  }

  Future<Map<String, dynamic>> loadAnalysis(Directory folder, String id) =>
      _read(Directory(p.join(folder.path, 'analysis')), '$id.json');

  Future<Map<String, dynamic>> _read(Directory folder, String name) async =>
      jsonDecode(await File(p.join(folder.path, name)).readAsString())
          as Map<String, dynamic>;

  Future<void> _write(
      Directory folder, String name, Map<String, Object?> value) async {
    final file = File(p.join(folder.path, name));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }
}
