import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/ui/session_card.dart';
import 'package:quote_app/prp_plugin/src/ui/playbook.dart';

import 'fixtures.dart';

Future<void> settlePrp(WidgetTester tester, {Finder? until}) async {
  int? foundAt;
  for (var i = 0; i < 150; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 16));
    if (until != null && until.evaluate().isNotEmpty) foundAt ??= i;
    if (foundAt != null && i - foundAt >= 30) return;
    if (until == null && i >= 30) return;
  }
  if (until != null) fail('Widget did not appear: $until');
}

Future<T> prpIo<T>(WidgetTester tester, Future<T> Function() action) async {
  final result = Completer<T>();
  unawaited(action().then(result.complete, onError: result.completeError));
  for (var i = 0; i < 200 && !result.isCompleted; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (!result.isCompleted)
    fail('PRP I/O did not complete while pumping both clocks');
  return result.future;
}

void main() {
  late PrpFixture f;
  setUp(() async {
    f = PrpFixture();
    await f.open();
  });
  // As with the existing kindling widget suite, page disposal may still have
  // FFI work in flight. Each test owns a distinct connection; process shutdown
  // releases it, avoiding a fake-clock deadlock from closing in tearDown.
  tearDown(() {
    PrpPlugin.instance = const NoopPrpPlugin();
  });

  Future<PrpOffer> offer(WidgetTester tester,
      {PrpStep step = PrpStep.pause, bool manual = false}) async {
    return (await tester.runAsync(() async {
      await f.enable();
      final s = f.signal(
          surface: manual ? PrpSurface.failureModule : PrpSurface.behavior,
          kind: manual ? 'manual' : 'habit_missed');
      final result = (await f.runtime.signal(s))!;
      if (step != PrpStep.pause)
        await f.runtime.saveDraft(result, f.lesson(source: s.surface),
            step: step, pauseSeconds: 30);
      return result;
    }))!;
  }

  Future<void> mount(WidgetTester tester, PrpOffer offer) async {
    tester.view.physicalSize = const Size(480, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: f.runtime.sessionCard(offer)))));
    await settlePrp(tester, until: find.byType(PrpSessionCard));
    await settlePrp(tester,
        until: find.text(switch (offer.signal.kind) { _ => '暂时跳过，存草稿' }));
  }

  testWidgets(
      'pause hides every analysis field and gates the next button for the actual duration',
      (tester) async {
    final o = await offer(tester);
    await mount(tester, o);
    expect(find.text('把事实摆出来'), findsNothing);
    expect(find.byKey(const ValueKey('prp_next')), findsNothing);
    expect(find.text('30 秒'), findsOneWidget);
    f.clock.advance(const Duration(seconds: 29));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('prp_next')), findsNothing);
    f.clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('开始对账'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('prp_next')));
    await tester.tap(find.byKey(const ValueKey('prp_next')));
    await settlePrp(tester, until: find.text('把事实摆出来'));
    await settlePrp(tester);
    final row = await prpIo(
        tester, () async => (await f.db.query('prp_session')).single);
    expect(row['pause_sec'], 30);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets('background time does not count as time spent pausing',
      (tester) async {
    final o = await offer(tester);
    await mount(tester, o);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    f.clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('30 秒'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    f.clock.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('开始对账'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'a short preset goal can be clarified without losing its original source',
      (tester) async {
    final o = (await tester.runAsync(() async {
      await f.enable();
      final result = (await f.runtime.signal(PrpSignal(
          surface: PrpSurface.behavior,
          kind: 'habit_missed',
          subjectKey: 'habit:preset:5',
          expected: '运动',
          tsMs: f.runtime.nowMs,
          reference: 'short-goal',
          confirmed: true)))!;
      final draft = PrpLesson.fromMap(
          {...f.lesson().toMap(), 'id': 0, 'trigger_text': '运动'});
      await f.runtime
          .saveDraft(result, draft, step: PrpStep.ledger, pauseSeconds: 30);
      return result;
    }))!;
    await mount(tester, o);
    final next = find.byKey(const ValueKey('prp_next'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await settlePrp(tester);
    expect(find.textContaining('先写下原本希望做到的具体事情'), findsOneWidget);
    final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '原本希望做到什么？');
    await tester.ensureVisible(field);
    await tester.enterText(field, '下楼走路十分钟');
    expect(find.text('来源原文：运动'), findsOneWidget);
    await tester.ensureVisible(next);
    await tester.tap(next);
    await settlePrp(tester, until: find.text('先看有效，再看无效'));
    final row = await prpIo(
        tester, () async => (await f.runtime.store.lessons()).single);
    expect(row.triggerText, '下楼走路十分钟');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'a short hold never seals; a full three-second hold seals once with a visible stamp',
      (tester) async {
    final o = await offer(tester, step: PrpStep.seal);
    await mount(tester, o);
    final target = find.byKey(const ValueKey('prp_seal_hold'));
    await tester.ensureVisible(target);
    var gesture = await tester.startGesture(tester.getCenter(target));
    f.clock.advance(const Duration(milliseconds: 2999));
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();
    await settlePrp(tester);
    expect(f.host.sealed, isEmpty);
    gesture = await tester.startGesture(tester.getCenter(target));
    f.clock.advance(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(seconds: 3));
    await settlePrp(tester, until: find.text('已盖印'));
    await gesture.up();
    expect(f.host.sealed, hasLength(1));
    expect((await prpIo(tester, () => f.runtime.store.lessons())).single.state,
        'sealed');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  for (final entry in <(PrpStep, String)>[
    (PrpStep.pause, '可以写一句，也可以什么都不写'),
    (PrpStep.ledger, '原本希望做到什么？'),
    (PrpStep.ledger, '你的话'),
    (PrpStep.columns, '有效：这次有哪件事是对的？'),
    (PrpStep.columns, '无效：当时什么没起作用？'),
    (PrpStep.columns, '这件事让我看见了什么？（可留空）'),
    (PrpStep.signal, '最早出现的信号是什么？'),
    (PrpStep.signal, '如果：一个能认出来的线索'),
    (PrpStep.signal, '那么：一个可检验的小动作'),
  ]) {
    testWidgets(
        'crisis input in ${entry.$2} leaves help visible and stores no crisis text',
        (tester) async {
      final o = await offer(tester, step: entry.$1, manual: true);
      await mount(tester, o);
      final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.$2);
      await tester.ensureVisible(field);
      await tester.enterText(field, '我不想活了');
      await settlePrp(tester, until: find.text('先照顾此刻的安全'));
      final row = await prpIo(
          tester, () async => (await f.db.query('prp_session')).single);
      expect(row['outcome'], 'crisis_exit');
      expect(await prpIo(tester, () => f.runtime.exportData()),
          isNot(contains('不想活')));
      expect(find.textContaining('12356'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await settlePrp(tester);
    });
  }

  testWidgets(
      'disabling removes a mounted session immediately without a final draft write',
      (tester) async {
    final o = await offer(tester);
    await mount(tester, o);
    final before =
        await prpIo(tester, () => f.db.rawQuery('SELECT total_changes() AS n'));
    await prpIo(
        tester,
        () => f.runtime
            .updatePreferences(f.runtime.preferences.copyWith(enabled: false)));
    await tester.pump();
    await settlePrp(tester);
    expect(find.byType(PrpSessionCard), findsNothing);
    expect(find.text('先缓一缓'), findsNothing);
    expect(
        await prpIo(tester, () => f.db.rawQuery('SELECT total_changes() AS n')),
        before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'manual fact classification and crossed-out revisions survive moving to the next step',
      (tester) async {
    final o = await offer(tester, step: PrpStep.ledger);
    await mount(tester, o);
    final thought = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '你的话');
    await tester.enterText(thought, '我觉得需要整段空闲时间才能开始');
    await tester.ensureVisible(find.text('分成事实 / 解释 / 自责'));
    await tester.tap(find.text('分成事实 / 解释 / 自责'));
    await tester.pump();
    await tester.ensureVisible(find.text('划掉 / 修订'));
    await tester.tap(find.text('划掉 / 修订'));
    await tester.pumpAndSettle();
    final revision = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '换成更贴近事实的一句话');
    await tester.enterText(revision, '今天先读1页也有进展');
    await tester.tap(find.text('保留修订'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('prp_next')));
    await tester.tap(find.byKey(const ValueKey('prp_next')));
    await settlePrp(tester);
    final lesson =
        (await prpIo(tester, () => f.runtime.store.lessons())).single;
    expect(lesson.sentences.single.revision, '今天先读1页也有进展');
    expect(lesson.sentences.single.text, '我觉得需要整段空闲时间才能开始');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'crisis in a revision closes its editor and keeps the help route visible',
      (tester) async {
    final o = await offer(tester, step: PrpStep.ledger);
    await mount(tester, o);
    final thought = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '你的话');
    await tester.enterText(thought, '我觉得需要整段空闲时间才能开始');
    await tester.ensureVisible(find.text('分成事实 / 解释 / 自责'));
    await tester.tap(find.text('分成事实 / 解释 / 自责'));
    await tester.pump();
    await tester.ensureVisible(find.text('划掉 / 修订'));
    await tester.tap(find.text('划掉 / 修订'));
    await tester.pumpAndSettle();
    final revision = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '换成更贴近事实的一句话');
    await tester.enterText(revision, '我不想活了');
    await settlePrp(tester, until: find.text('先照顾此刻的安全'));
    expect(find.text('划掉解释，保留修改'), findsNothing);
    final row = await prpIo(
        tester, () async => (await f.db.query('prp_session')).single);
    expect(row['outcome'], 'crisis_exit');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets('disabling closes a full-screen offer including its PRP app bar',
      (tester) async {
    final o = await offer(tester);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (ctx) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        f.runtime.showOffer(ctx, o, fullScreen: true),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await settlePrp(tester, until: find.text('暂时跳过，存草稿'));
    await prpIo(
        tester,
        () => f.runtime
            .updatePreferences(f.runtime.preferences.copyWith(enabled: false)));
    await settlePrp(tester, until: find.text('open'));
    expect(find.text('缓一缓 · 对账 · 留下一条教训'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets('voice note stops at 15 seconds and saves only its local path',
      (tester) async {
    final lesson = await tester.runAsync(() async {
      await f.enable();
      final l = await f.seal();
      await f.runtime
          .updatePreferences(f.runtime.preferences.copyWith(voice: true));
      return l;
    });
    f.host.recordingPath = '/local/prp_voice/test.m4a';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PrpVoiceControl(runtime: f.runtime, lesson: lesson!))));
    await tester.tap(find.text('录下自己的提醒'));
    await settlePrp(tester);
    await tester.pump(const Duration(seconds: 15));
    await settlePrp(tester);
    expect(f.host.recordingStops, 1);
    expect(
        (await prpIo(tester, () => f.runtime.store.lesson(lesson.id)))!
            .voicePath,
        '/local/prp_voice/test.m4a');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets('paper and safety text remain readable inside a dark enemy host',
      (tester) async {
    final o = await offer(tester);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: SingleChildScrollView(child: f.runtime.sessionCard(o)))));
    await settlePrp(tester, until: find.text('先缓一缓'));
    final body = tester.element(find.text('现在的难受程度：5 / 10'));
    expect(Theme.of(body).brightness, Brightness.light);
    final foreground = DefaultTextStyle.of(body).style.color!;
    final contrast = (const Color(0xfff7f5f0).computeLuminance() + .05) /
        (foreground.computeLuminance() + .05);
    expect(contrast, greaterThan(4.5));
    final input = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '可以写一句，也可以什么都不写');
    await tester.enterText(input, '我不想活了');
    await settlePrp(tester, until: find.text('先照顾此刻的安全'));
    expect(Theme.of(tester.element(find.text('先照顾此刻的安全'))).brightness,
        Brightness.light);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'dragging a sentence to self-blame excludes it from the saved ledger',
      (tester) async {
    final o = await offer(tester, step: PrpStep.ledger);
    await mount(tester, o);
    final thought = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '你的话');
    await tester.enterText(thought, '今天读了1页。可能因为太累');
    await tester.ensureVisible(find.text('分成事实 / 解释 / 自责'));
    await tester.tap(find.text('分成事实 / 解释 / 自责'));
    await tester.pumpAndSettle();
    final source = find.text('今天读了1页');
    final target = find.widgetWithText(Chip, '拖到这里：自责');
    await tester.ensureVisible(source);
    final gesture = await tester.startGesture(tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('自责 · 不入账'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('prp_next')));
    await tester.tap(find.byKey(const ValueKey('prp_next')));
    await settlePrp(tester);
    final saved = (await prpIo(tester, () => f.runtime.store.lessons())).single;
    expect(saved.sentences.any((s) => s.text == '今天读了1页'), false);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'late AI classification never replaces facts edited while waiting',
      (tester) async {
    final o = (await tester.runAsync(() async {
      await f.enable();
      await f.runtime
          .updatePreferences(f.runtime.preferences.copyWith(aiConsent: true));
      final o = (await f.runtime.signal(f.signal()))!;
      await f.runtime
          .saveDraft(o, f.lesson(), step: PrpStep.ledger, pauseSeconds: 30);
      return o;
    }))!;
    f.host.aiPending = Completer<String?>();
    await mount(tester, o);
    final thought = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '你的话');
    await tester.enterText(thought, '今天读了1页');
    final ai = find.text('用 AI 辅助分类（失败时使用离线结果）');
    await tester.ensureVisible(ai);
    await tester.tap(ai);
    await settlePrp(tester);
    await tester.enterText(thought, '今天读了2页');
    f.host.aiPending!
        .complete('{"sentences":[{"text":"今天读了1页","kind":"fact"}]}');
    await settlePrp(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('prp_next')));
    await tester.tap(find.byKey(const ValueKey('prp_next')));
    await settlePrp(tester);
    final saved = (await prpIo(tester, () => f.runtime.store.lessons())).single;
    expect(saved.sentences.single.text, '今天读了2页');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'clearing data removes an already displayed recall without navigating away',
      (tester) async {
    await prpIo(tester, () => f.enable());
    final lesson = (await tester.runAsync(() => f.seal()))!;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: f.runtime.recallChip(const PrpContext(
                surface: PrpSurface.behavior,
                subjectKey: 'habit:preset:5',
                location: 'habit_reminder')))));
    final rule = find.text('「${lesson.rule}」');
    await settlePrp(tester, until: rule);
    await prpIo(tester, f.runtime.clearData);
    await settlePrp(tester);
    expect(rule, findsNothing);
    expect(await prpIo(tester, () => f.db.query('prp_recall')), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'skipping a full-screen offer saves a draft and closes its own page',
      (tester) async {
    final o = await offer(tester);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (ctx) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        f.runtime.showOffer(ctx, o, fullScreen: true),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await settlePrp(tester, until: find.text('暂时跳过，存草稿'));
    await tester.ensureVisible(find.text('暂时跳过，存草稿'));
    await tester.tap(find.text('暂时跳过，存草稿'));
    await settlePrp(tester, until: find.text('open'));
    await tester.pumpAndSettle();
    final lessons = await prpIo(tester, () => f.runtime.store.lessons());
    expect(lessons.single.state, 'draft');
    expect(find.text('先缓一缓'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });
}
