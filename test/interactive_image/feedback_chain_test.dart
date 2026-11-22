import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'reads existing single actions and stores ordered gesture and voice chains',
      () {
    const region = ImageRegion(
        id: 'region',
        label: '区域',
        group: RegionGroup.object,
        polygon: [Offset(0, 0), Offset(1, 0), Offset(1, 1)]);
    final old = ImageRegion.fromJson({
      ...region.toJson(),
      'rules': {'tap': 'highlight', 'hold': 'books'}
    });
    expect(old.rules[TouchGesture.tap],
        const [FeedbackStep(TouchAction.highlight)]);
    expect(
        old.rules[TouchGesture.hold], const [FeedbackStep(TouchAction.books)]);
    const link =
        'https://chatgpt.com/g/g-p-00000000000000000000000000000000/project';
    const chain = [
      FeedbackStep(TouchAction.vibration),
      FeedbackStep(TouchAction.link, value: link)
    ];
    final configured = old.copyWith(
        rules: {TouchGesture.tap: chain},
        voiceRules: const [VoiceFeedback('打开项目', chain)]);
    final restored = ImageRegion.fromJson(configured.toJson());
    expect(restored.rules[TouchGesture.tap], chain);
    expect(restored.voiceRules.single.phrase, '打开项目');
    expect(restored.voiceRules.single.steps, chain);
    expect(feedbackLink(link)!.toString(), link);
    expect(feedbackLink('intent://example.com/#Intent;end'), isNull);
    expect(feedbackLink('https://example.com@chatgpt.com'), isNull);
    expect(FeedbackSettings.fromJson({}).wakePhrase, defaultWakePhrase);
    expect(
        FeedbackSettings.fromJson(const FeedbackSettings(
                    wakePhrase: '小画板', allowSystemSpeech: true)
                .toJson())
            .wakePhrase,
        '小画板');
  });

  test('wake word gates voice commands and expires or clears after one match',
      () {
    final matcher = WakePhraseMatcher('小画板');
    final start = DateTime(2026);
    const commands = {'开始播放'};
    expect(matcher.commandFor(['开始播放'], start, commands), isNull);
    expect(matcher.commandFor(['小画板，开始播放。'], start, commands), '开始播放');
    expect(matcher.commandFor(['开始播放'], start, commands), isNull);
    expect(matcher.commandFor(['小 画 板！'], start, commands), isNull);
    expect(matcher.armedAt(start), isTrue);
    expect(
        matcher.commandFor(
            ['开始播报', '开始播放'], start.add(const Duration(seconds: 1)), commands),
        '开始播放');
    matcher.commandFor(['小画板'], start, commands);
    expect(
        matcher.commandFor(
            ['开始播放'], start.add(const Duration(seconds: 9)), commands),
        isNull);
  });

  test('keeps media referenced by any gesture or voice rule during cleanup',
      () async {
    final folder = await Directory.systemTemp.createTemp('feedback-media-');
    addTearDown(() => folder.delete(recursive: true));
    final media = await Directory('${folder.path}/media').create();
    final gestureFile =
        await File('${media.path}/${'a' * 32}.audio').writeAsString('gesture');
    final voiceFile =
        await File('${media.path}/${'b' * 32}.video').writeAsString('voice');
    final removed =
        await File('${media.path}/${'c' * 32}.video').writeAsString('removed');
    final region = ImageRegion(
        id: 'region',
        label: '区域',
        group: RegionGroup.object,
        polygon: const [Offset(0, 0), Offset(1, 0), Offset(1, 1)],
        targetId: 'second-person',
        rules: {
          TouchGesture.tap: [
            FeedbackStep(TouchAction.audio,
                value: gestureFile.uri.pathSegments.last)
          ]
        },
        voiceRules: [
          VoiceFeedback('看视频', [
            FeedbackStep(TouchAction.video,
                value: voiceFile.uri.pathSegments.last)
          ])
        ]);
    await ArtworkRepository()
        .cleanUnusedMedia(folder, ArtworkEdits(regions: [region]));
    expect(await gestureFile.exists(), isTrue);
    expect(await voiceFile.exists(), isTrue);
    expect(await removed.exists(), isFalse);
  });
}
