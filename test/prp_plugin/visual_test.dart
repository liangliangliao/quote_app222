import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/widgets/settings_dashboard.dart';

import 'fixtures.dart';
import 'widget_test.dart' show prpIo, settlePrp;

/// These are deterministic Flutter-rendered review images, not device captures.
void main() {
  testWidgets('review screenshots: off/on, pause, seal, playbook and recall',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('PrpReviewFont')
      ..addFont(rootBundle.load('assets/fonts/MaShanZheng-Regular.ttf'));
    final brush = FontLoader('QuoteXingShu')
      ..addFont(rootBundle.load('assets/fonts/ZhiMangXing-Regular.ttf'));
    final kai = FontLoader('QuoteKaiShu')
      ..addFont(rootBundle.load('assets/fonts/MaShanZheng-Regular.ttf'));
    final latin = FontLoader('QuoteLiterarySerif')
      ..addFont(rootBundle.load('assets/fonts/LibreBaskerville-Variable.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(() => Future.wait(
        [font.load(), brush.load(), kai.load(), latin.load(), icons.load()]));
    final f = PrpFixture();
    await tester.runAsync(f.open);
    addTearDown(() {
      PrpPlugin.instance = const NoopPrpPlugin();
    });

    Future<void> screen(Widget body, {bool dark = false}) async {
      await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('prp_review_screen'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                brightness: dark ? Brightness.dark : Brightness.light,
                fontFamily: 'PrpReviewFont',
                fontFamilyFallback: const ['QuoteLiterarySerif'],
                colorSchemeSeed: const Color(0xff56568b)),
            home: body,
          )));
      await settlePrp(tester);
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> capture(String name) async {
      await expectLater(find.byKey(const ValueKey('prp_review_screen')),
          matchesGoldenFile('../../docs/prp/screenshots/$name.png'));
    }

    await screen(
        SettingsDashboard(summary: const SettingsAiSummary(), onOpen: (_) {}));
    await capture('PRP_09_settings_entry');
    await screen(f.runtime.settingsPage());
    await capture('PRP_01_settings_off');
    await prpIo(tester, () => f.enable());
    await screen(f.runtime.settingsPage());
    await capture('PRP_02_settings_on');

    final pause = (await prpIo(
        tester, () => f.runtime.signal(f.signal(ref: 'visual:pause'))))!;
    await screen(Scaffold(
        appBar: AppBar(title: const Text('行为追踪 · PRP')),
        body: SingleChildScrollView(child: f.runtime.sessionCard(pause))));
    await capture('PRP_03_pause');

    // Invalidate the old mounted offer before replacing the review surface.
    await prpIo(tester,
        () => f.runtime.updatePreferences(f.runtime.preferences.copyWith()));
    final seal = (await prpIo(
        tester, () => f.runtime.signal(f.signal(ref: 'visual:seal'))))!;
    final lesson = f.lesson(sentences: const [
      PrpSentence('我觉得需要整段空闲时间才能开始', PrpSentenceKind.interpretation,
          revision: '今天把开始的时间留给了短视频')
    ]);
    await prpIo(
        tester,
        () => f.runtime
            .saveDraft(seal, lesson, step: PrpStep.seal, pauseSeconds: 30));
    await screen(Scaffold(
        appBar: AppBar(title: const Text('我认可这条教训')),
        body: SingleChildScrollView(child: f.runtime.sessionCard(seal))));
    await capture('PRP_04_seal_preview');
    final sealed = await prpIo(
        tester,
        () => f.runtime
            .seal(seal, lesson, pauseSeconds: 30, heldMilliseconds: 3000));
    expect(sealed, isNotNull);
    await prpIo(tester, () => f.runtime.finishZoom(seal, 3));

    await screen(Scaffold(
        appBar: AppBar(title: const Text('我的教训手册')),
        body: SingleChildScrollView(
            child: f.runtime.playbook(management: true))));
    await capture('PRP_05_playbook');
    await screen(Scaffold(
        appBar: AppBar(title: const Text('下一次 · 每日确认')),
        body: f.runtime.recallChip(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            location: 'habit_reminder'))));
    await capture('PRP_06_recall');
    final darkOffer = (await prpIo(
        tester, () => f.runtime.signal(f.signal(ref: 'visual:dark'))))!;
    await screen(
        Scaffold(
            appBar: AppBar(title: const Text('美丽的敌人 · 深色宿主')),
            body:
                SingleChildScrollView(child: f.runtime.sessionCard(darkOffer))),
        dark: true);
    await capture('PRP_07_dark_host');
    final input = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '可以写一句，也可以什么都不写');
    await tester.enterText(input, '我不想活了');
    await settlePrp(tester, until: find.text('先照顾此刻的安全'));
    await capture('PRP_08_safety_exit');
    await prpIo(
        tester,
        () => f.runtime
            .updatePreferences(f.runtime.preferences.copyWith(enabled: false)));
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });
}
