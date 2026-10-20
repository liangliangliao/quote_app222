import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/quote_frame_theme.dart';
import 'package:quote_app/services/quote_visual_script_service.dart';
import 'package:quote_app/widgets/quote_adaptive_frame.dart';

void main() {
  test('a complex existential quotation maps to visible threshold and self reflection', () {
    final theme = QuoteFrameTheme.resolve(
      topic: '高峰体验、存在之门与回到真正的自己',
      quote: '在这些扩展的瞬间里，我们瞥见了永恒的领域——存在本身。',
    );
    final spec = QuoteVisualScriptService.fallback(
      topic: '高峰体验、存在之门与回到真正的自己',
      quote: '在这些扩展的瞬间里，我们瞥见了永恒的领域——存在本身。',
      theme: theme,
    );
    expect(spec.scene, contains('门槛'));
    expect(spec.scene, contains('倒影'));
    expect(spec.relationship, contains('对应'));
    expect(spec.fromAi, false);
  });

  test('semantic script rejects vague content and remembers AI provenance', () {
    expect(
      () => QuoteVisualScript.fromJson({'meaning':'短','scene':'湖','metaphor':'天','relationship':'云'}),
      throwsFormatException,
    );
    final spec = QuoteVisualScript.fromJson({
      'meaning':'片刻的体验穿越熟悉的自我形象',
      'metaphor':'窄门与镜湖',
      'scene':'有人穿过狭窄洞口，来到宽广平静的镜湖边，水面倒影显露自己的样子，天空逐渐发亮。',
      'relationship':'窄门是瞬间，倒影是回到自己。',
      'frameFinish':'walnut',
      'fromAi':true,
    });
    expect(QuoteVisualScript.fromJson(spec.toJson()).fromAi, isTrue);
    expect(spec.frameFinish, 'walnut');
  });

  test('long quote reserves more visual space for text, all prompts forbid text drawing', () {
    final spec = QuoteVisualScriptService.fallback(
      topic: '行动', quote: '千里之行，始于足下。',
      theme: QuoteFrameTheme.resolve(topic:'行动',quote:'千里之行，始于足下。'),
    );
    expect(spec.isThemeOnly, isTrue);
    expect(spec.imagePrompt(quoteCharacters: 130), contains('BOTTOM 34%'));
    expect(spec.imagePrompt(quoteCharacters: 20), contains('BOTTOM 46%'));
    expect(spec.imagePrompt(quoteCharacters: 80), contains('No typography'));
  });

  test('bundled default quotes still exist and load without network', () {
    final contents = File('assets/fallback/camus_fallback.json').readAsStringSync();
    final items = jsonDecode(contents) as List<dynamic>;
    expect(items.length, greaterThan(4));
    expect(items.every((e) => e is Map && (e['quote'] ?? '').toString().trim().isNotEmpty), isTrue);
  });

  test('no-text-model prompt contains the exact quote for image interpretation', () {
    final spec = QuoteVisualScriptService.fallback(
      topic: '价值', quote: '我们反抗，故我们存在。',
      theme: QuoteFrameTheme.resolve(topic: '价值', quote: '我们反抗，故我们存在。'),
    );
    expect(spec.isThemeOnly, isTrue);
    final prompt = spec.imagePrompt(
      quoteCharacters: 12,
      originalQuote: '我们反抗，故我们存在。',
      topic: '价值',
    );
    expect(prompt, contains('我们反抗，故我们存在。'));
    expect(prompt, contains('PRIMARY SOURCE'));
    expect(prompt, contains('Independently interpret'));
    expect(prompt, contains('No typography'));
  });

  test('AI-reviewed prompt still keeps the exact quotation as ground truth', () {
    final spec = QuoteVisualScript.fromJson({
      'meaning': '失败是一次事件，不能独自证明一个人的全部能力。',
      'metaphor': '一张被标记的试卷与仍在继续搭建的桥',
      'scene': '桌面上放着一张有明显错误标记的试卷，旁边的人没有把它贴在自己的胸前，而是根据错误调整图纸，继续把一座尚未完成的模型桥搭向对岸。',
      'relationship': '一次错误对应试卷上的一个标记；继续修正并建桥对应能力仍可通过后续行动被检验。',
      'frameFinish': 'walnut',
      'fromAi': true,
    });
    const quote = '失败一次，只能说明这一次没有成功，不能证明我没有能力。';
    final prompt = spec.imagePrompt(
      quoteCharacters: quote.length,
      originalQuote: quote,
      topic: '失败与能力',
    );
    expect(prompt, contains(quote));
    expect(prompt, contains('same proposition'));
    expect(prompt, contains('clause-to-image mapping'));
  });

  test('the uploaded wooden frame is the only bundled default frame', () {
    final frame = File(QuoteAdaptiveFrame.defaultBackgroundAsset);
    expect(frame.existsSync(), isTrue);
    expect(frame.lengthSync(), greaterThan(100000));
    expect(File('assets/home_small_frame.png').existsSync(), isFalse);
  });

  test('AI artwork geometry stays inside the photographed wooden frame', () {
    final rect = QuoteAdaptiveFrame.scaleRect(
      QuoteAdaptiveFrame.artworkRect,
      const Size(300, 450),
    );
    expect(rect.left, closeTo(54, .01));
    expect(rect.top, closeTo(62.55, .01));
    expect(rect.right, closeTo(255, .01));
    expect(rect.bottom, closeTo(353.25, .01));
    expect(rect.contains(const Offset(150, 225)), isTrue);
    expect(rect.contains(const Offset(10, 225)), isFalse);
  });

  testWidgets('the home frame renders the uploaded asset at mobile scale', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: const SizedBox(
        width: 300,
        height: 450,
        child: QuoteAdaptiveFrame(quoteCharacters: 115),
      ),
    ))));
    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      QuoteAdaptiveFrame.defaultBackgroundAsset,
    );
    expect(tester.takeException(), isNull);
  });
}
