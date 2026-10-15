import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/services/quote_frame_theme.dart';
import 'package:quote_app/services/quote_visual_script_service.dart';
import 'package:quote_app/widgets/wood_frame_3d_overlay.dart';
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
    expect(spec.imagePrompt(quoteCharacters: 130), contains('BOTTOM 22%'));
    expect(spec.imagePrompt(quoteCharacters: 20), contains('BOTTOM 36%'));
    expect(spec.imagePrompt(quoteCharacters: 80), contains('No typography'));
  });

  testWidgets('bundled default quotes still exist and load without network', (tester) async {
    final contents = await rootBundle.loadString('assets/fallback/camus_fallback.json');
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
    expect(prompt, contains('MUST independently interpret'));
    expect(prompt, contains('No typography'));
  });

  testWidgets('wood ring does not cover the quote/artwork center', (tester) async {
    final key = GlobalKey();
    final theme = QuoteFrameTheme.resolve(topic:'哲学', quote:'认识你自己');
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child: RepaintBoundary(key:key, child: SizedBox(width:240,height:360,
        child: Stack(fit:StackFit.expand,children:[
          const ColoredBox(color:Color(0xfff7efe4)),
          WoodFrame3dOverlay(theme:theme),
        ]),
      )),
    ))));
    await tester.pump();
    final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image=await boundary.toImage(pixelRatio:1);
    final bytes=(await image.toByteData(format:ui.ImageByteFormat.rawRgba))!;
    int channel(int x,int y,int c)=> bytes.getUint8((y*240+x)*4+c);
    // 同一画框中心应保留画芯的颜色，旧版会变成深灰褐色且覆盖名言。
    expect(channel(120,180,0), greaterThan(225));
    expect(channel(120,180,1), greaterThan(210));
    expect(channel(120,180,2), greaterThan(190));
    // 木料内的像素应该明显深于画芯，确实画出了环状木框。
    expect(channel(10,180,0), lessThan(220));
  });

  testWidgets('3D wood overlay and content remain paintable at mobile card scale', (tester) async {
    final theme = QuoteFrameTheme.resolve(topic: '成长', quote: '努力成长');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 300,height: 450,child: Stack(
        fit: StackFit.expand,
        children:[
          QuoteAdaptiveFrame(theme: theme, quoteCharacters: 115),
          const Center(child: Text('名言字形由 Flutter 独立渲染')),
          WoodFrame3dOverlay(theme: theme, finish: 'walnut'),
        ],
      )),
    ))));
    expect(find.text('名言字形由 Flutter 独立渲染'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
