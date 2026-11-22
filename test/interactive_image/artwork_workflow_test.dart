import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:quote_app/conscious_change/interactive_image/artwork.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_repository.dart';
import 'package:quote_app/conscious_change/interactive_image/local_recognition.dart';
import 'package:quote_app/conscious_change/interactive_image/original_artwork_image.dart';
import 'package:quote_app/conscious_change/interactive_image/region_geometry.dart';

const _box = [
  Offset(0.2, 0.2),
  Offset(0.8, 0.2),
  Offset(0.8, 0.8),
  Offset(0.2, 0.8)
];
const _nested = [
  Offset(0.4, 0.4),
  Offset(0.6, 0.4),
  Offset(0.6, 0.6),
  Offset(0.4, 0.6)
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports three image formats and stores the displayed JPEG orientation',
      () async {
    final dir = await Directory.systemTemp.createTemp('artwork-import-');
    addTearDown(() => dir.delete(recursive: true));
    final repository =
        ArtworkRepository(directory: Directory('${dir.path}/works'));
    final png = image.Image(12, 20)..fill(image.getColor(238, 0, 0));
    final jpeg = image.encodeJpg(png);
    // Insert a big-endian EXIF orientation 6 between the JPEG signature and its first segment.
    final rotated = Uint8List.fromList([
      ...jpeg.take(2),
      ...base64Decode('/+EAIkV4aWYAAE1NACoAAAAIAAEBEgADAAAAAQAGAAAAAAAA'),
      ...jpeg.skip(2),
    ]);
    final variants = {
      'jpg': rotated,
      'png': image.encodePng(png),
      'webp': base64Decode(
          'UklGRigAAABXRUJQVlA4TBwAAAAvC8AEAA8Q87//8x8OhASEB/6vVU2I6P8E5MEK'),
    };
    for (final entry in variants.entries) {
      final input =
          await File('${dir.path}/pick.${entry.key}').writeAsBytes(entry.value);
      final work = await repository.importImage(input, '作品.${entry.key}');
      final folder = await repository.folderFor(work);
      expect(work.format, entry.key);
      expect(
          (work.width, work.height), entry.key == 'jpg' ? (20, 12) : (12, 20));
      expect(await File('${folder.path}/original.${entry.key}').readAsBytes(),
          entry.value);
      final preview = await ui.instantiateImageCodec(
          await repository.previewFile(folder).readAsBytes());
      final frame = (await preview.getNextFrame()).image;
      expect((frame.width, frame.height), (work.width, work.height));
      frame.dispose();
      preview.dispose();
      final thumb = image
          .decodePng(await repository.thumbnailFile(folder).readAsBytes())!;
      expect((thumb.width, thumb.height), (18, 18));
    }
    final invalid =
        await File('${dir.path}/invalid.png').writeAsString('not a PNG');
    await expectLater(repository.importImage(invalid, 'invalid.png'),
        throwsA(isA<ArtworkImportException>()));
    final large = File('${dir.path}/large.png');
    final handle = await large.open(mode: FileMode.write);
    await handle.truncate(maxArtworkBytes + 1);
    await handle.close();
    await expectLater(repository.importImage(large, 'large.png'),
        throwsA(isA<ArtworkImportException>()));
    expect(await repository.list(), hasLength(3));
  });

  test(
      'reopens a draft and feedback rules, duplicates and deletes files independently',
      () async {
    final dir = await Directory.systemTemp.createTemp('artwork-storage-');
    addTearDown(() => dir.delete(recursive: true));
    final storage = Directory('${dir.path}/works');
    final repository = ArtworkRepository(directory: storage);
    final png = await File('${dir.path}/pick.png')
        .writeAsBytes(image.encodePng(image.Image(12, 20)));
    final original = await repository.importImage(png, '画板.png');
    final folder = await repository.folderFor(original);
    const region = ImageRegion(
        id: 'book',
        label: '书籍',
        group: RegionGroup.object,
        polygon: _box,
        rules: {
          TouchGesture.tap: [FeedbackStep(TouchAction.learning)],
          TouchGesture.hold: [FeedbackStep(TouchAction.vibration)]
        });
    await repository.saveEdits(
        folder,
        const ArtworkEdits(
            regions: [region], draft: PolygonDraft('book', _nested)));
    await repository.saveSettings(const FeedbackSettings(
        visual: false,
        vibration: false,
        effortDifficulty: EffortDifficulty.hard));
    await repository.saveAnalysis(
        folder, 'run', {'model': 'test', 'processing': 'on-device'});
    final renamed = await repository.rename(original, '新名字');
    final copy = await repository.duplicate(renamed);
    expect(copy.id, isNot(original.id));
    expect(copy.title, '新名字 · 副本');
    final reopened = ArtworkRepository(directory: storage);
    final copyFolder = await reopened.folderFor(copy);
    final restored = await reopened.loadEdits(copyFolder);
    expect(restored.regions.single.rules, region.rules);
    expect(restored.draft?.points, _nested);
    final feedback = await reopened.loadSettings();
    expect(feedback.vibration, isFalse);
    expect(feedback.effortDifficulty, EffortDifficulty.hard);
    expect((await reopened.loadAnalysis(copyFolder, 'run'))['model'], 'test');
    await reopened.delete(renamed);
    expect(await folder.exists(), isFalse);
    expect(await reopened.previewFile(copyFolder).exists(), isTrue);
    expect((await reopened.list()).map((work) => work.id), [copy.id]);
  });

  test(
      'rejects self-intersections and hit-tests contain bounds and overlapping rules',
      () {
    final rect = artworkRect(const Size(300, 500), 2);
    expect(rect, const Rect.fromLTWH(0, 175, 300, 150));
    expect(normalizedPoint(const Offset(150, 60), rect), isNull);
    expect(normalizedPoint(imagePoint(const Offset(0.5, 0.5), rect), rect),
        const Offset(0.5, 0.5));
    expect(validPolygon(_box), isTrue);
    expect(validPolygon([_box[0], _box[2], _box[1], const Offset(0.3, 0.8)]),
        isFalse);
    const base = ImageRegion(
        id: 'head',
        label: '头面部',
        group: RegionGroup.head,
        polygon: _box,
        rules: {
          TouchGesture.tap: [FeedbackStep(TouchAction.sound)],
          TouchGesture.swipe: [FeedbackStep(TouchAction.pulse)]
        });
    const child = ImageRegion(
        id: 'nose',
        parentId: 'head',
        label: '鼻部',
        group: RegionGroup.head,
        polygon: _nested,
        rules: {
          TouchGesture.tap: [FeedbackStep(TouchAction.highlight)]
        });
    const point = Offset(0.5, 0.5);
    expect(
        hitRegion([base, child], point, gesture: TouchGesture.tap)?.id, 'nose');
    expect(
        hitRegion([base.copyWith(priority: 1), child], point,
                gesture: TouchGesture.tap)
            ?.id,
        'head');
    expect(hitRegion([base, child], point, gesture: TouchGesture.swipe)?.id,
        'head');
    expect(
        hitRegion([base, child.copyWith(enabled: false)], point,
                gesture: TouchGesture.tap)
            ?.id,
        'head');
    expect(
        hitRegion([base], const Offset(0.2, 0.2), gesture: TouchGesture.tap)
            ?.id,
        'head');
  });

  test(
      'recognition isolates people and preserves reviewed and dismissed regions',
      () {
    List<List<num?>> pose(double x) {
      final points = List.generate(33, (_) => <num?>[-1, -1, 0, 0.07, 0.07]);
      points[11] = [x, 0.2, 0, 0.95, 0.95];
      points[12] = [x + 0.08, 0.2, 0, 0.95, 0.95];
      points[23] = [x, 0.4, 0, 0.95, 0.95];
      points[24] = [x + 0.08, 0.4, 0, 0.95, 0.95];
      points[25] = [x, 0.65, 0, 0.55, 0.6];
      return points;
    }

    final result = RecognitionResult.fromJson({
      'id': 'run',
      'model': 'test',
      'pose': [pose(0.68), pose(0.2)]
    }, 1);
    expect(result.people, hasLength(2));
    final left = result.people.first;
    final right = result.people.last;
    expect(left.bounds.center.dx, lessThan(right.bounds.center.dx));
    final torso =
        left.regions.singleWhere((region) => region.group == RegionGroup.torso);
    final leg =
        left.regions.singleWhere((region) => region.group == RegionGroup.legs);
    expect(torso.source, RegionSource.detected);
    expect(leg.source, RegionSource.proposed);
    final reviewed = leg.copyWith(edited: true, rules: {
      TouchGesture.tap: [FeedbackStep(TouchAction.highlight)]
    });
    final edits = ArtworkEdits(regions: [reviewed], dismissed: {torso.id})
        .withTarget(right.id, result.id, right.regions);
    expect(edits.visibleRegions.map((region) => region.targetId).toSet(),
        {right.id});
    final next = edits.withTarget(left.id, result.id, left.regions);
    expect(next.visibleRegions, [reviewed]);
    expect(next.resetRecognition().visibleRegions, [reviewed]);
  });

  test('full-screen image provider decodes above the editor preview resolution',
      () async {
    final dir = await Directory.systemTemp.createTemp('artwork-original-');
    addTearDown(() => dir.delete(recursive: true));
    final repository =
        ArtworkRepository(directory: Directory('${dir.path}/works'));
    final source = await File('${dir.path}/original.png')
        .writeAsBytes(image.encodePng(image.Image(2300, 120)));
    final work = await repository.importImage(source, 'original.png');
    final folder = await repository.folderFor(work);
    final preview =
        image.decodePng(await repository.previewFile(folder).readAsBytes())!;
    expect(preview.width, 1920);
    final provider =
        OriginalArtworkImage(repository.originalFile(folder, work));
    final stream = provider.resolve(ImageConfiguration.empty);
    final resolution = Completer<(int, int)>();
    final listener = ImageStreamListener((frame, _) {
      resolution.complete((frame.image.width, frame.image.height));
      frame.dispose();
    }, onError: resolution.completeError);
    stream.addListener(listener);
    try {
      expect(await resolution.future, (2300, 120));
    } finally {
      stream.removeListener(listener);
      await provider.evict();
    }
  });
}
