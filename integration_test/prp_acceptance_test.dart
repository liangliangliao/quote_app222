import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quote_app/main.dart' as app;
import 'package:quote_app/data/db.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_dao.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_models.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/build_info.dart';
import 'package:quote_app/prp_plugin/src/runtime.dart';
import 'package:quote_app/widgets/poster_pure_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'PRP Android acceptance: actual settings, sealing, optional features, quote and off/clear',
      (tester) async {
    expect(const bool.fromEnvironment('PRP_ACCEPTANCE'), true,
        reason: 'Disposable emulator build only');
    final db = await AppDatabase.instance();
    // Deterministic fixture governance. Plugin/AI consent defaults are untouched.
    final dao = EnemyDao(db);
    await dao.ensureSchema();
    await dao.setSetting('quiet_start_hour', '0');
    await dao.setSetting('quiet_end_hour', '0');
    app.main();
    Future<void> until(bool Function() ready, {int seconds = 35}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!ready() && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(ready(), true, reason: 'Expected UI state before timeout');
    }

    Future<void> visible(Finder target) async {
      // A returning settings route can coexist with the outgoing PRP route
      // during its pop animation. Never scroll that outgoing session or an
      // inner TextField's Scrollable while looking for a settings entry.
      await tester.pump(const Duration(milliseconds: 400));
      if (target.evaluate().isEmpty) {
        final routeScroll = find.byElementPredicate((element) =>
            element.widget is Scrollable &&
            (element.widget as Scrollable).axisDirection ==
                AxisDirection.down &&
            ModalRoute.of(element)?.isCurrent == true);
        await until(() => routeScroll.evaluate().isNotEmpty);
        final scroll = routeScroll.first;
        for (var i = 0; i < 15; i++) {
          final position = tester.state<ScrollableState>(scroll).position;
          if (position.pixels <= position.minScrollExtent + 1) break;
          await tester.drag(scroll, const Offset(0, 700));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.scrollUntilVisible(target, 250,
            scrollable: scroll, maxScrolls: 60);
      }
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> tap(Finder target) async {
      await visible(target);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> switchTo(String label, bool value) async {
      final control = find.widgetWithText(SwitchListTile, label);
      await visible(control);
      if (tester.widget<SwitchListTile>(control).value != value)
        await tester.tap(control);
      await until(() =>
          control.evaluate().isNotEmpty &&
          tester.widget<SwitchListTile>(control).value == value &&
          tester.widget<SwitchListTile>(control).onChanged != null);
    }

    Future<void> enter(String label, String value) async {
      final target = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label);
      await visible(target);
      await tester.enterText(target, value);
      await tester.pump(const Duration(milliseconds: 250));
    }

    var surfaceReady = false;
    Future<void> shot(String name) async {
      if (!surfaceReady) {
        await binding.convertFlutterSurfaceToImage();
        surfaceReady = true;
      }
      await tester.pump(const Duration(milliseconds: 350));
      await binding.takeScreenshot(name);
    }

    Future<void> back() async {
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await until(() => find.text('设置').evaluate().isNotEmpty);
    await tester.tap(find.text('设置').last);
    await tester.pump(const Duration(seconds: 1));
    await tap(find.byKey(const ValueKey('settings-entry-prp')));
    await until(() =>
        find.byKey(const ValueKey('prp_master_switch')).evaluate().isNotEmpty);
    final runtime = PrpPlugin.instance as PrpRuntime;
    expect(runtime.preferences.enabled, false);
    expect(runtime.preferences.aiConsent, false);
    expect(runtime.preferences.forecasts, false);
    expect(runtime.preferences.nativeReminders, false);
    expect(runtime.preferences.particles, false);
    expect(runtime.preferences.draftQuotes, false);
    await shot('android_01_off');
    await tap(find.byKey(const ValueKey('prp_master_switch')));
    await tap(find.text('按这些选择开启'));
    await until(() => runtime.enabled);
    expect(runtime.aiAllowed, false);
    await shot('android_02_enabled');
    await tap(find.byKey(const ValueKey('prp_begin_reflection')));
    await until(() => find.text('先缓一缓').evaluate().isNotEmpty);
    expect(find.text('把事实摆出来'), findsNothing);
    expect(find.byKey(const ValueKey('prp_next')), findsNothing);
    await shot('android_03_pause');
    await until(
        () => find.byKey(const ValueKey('prp_next')).evaluate().isNotEmpty,
        seconds: 80);
    Future<void> next(String title) async {
      await tap(find.byKey(const ValueKey('prp_next')));
      await until(() => find.text(title).evaluate().isNotEmpty);
    }

    await next('把事实摆出来');
    await enter('原本希望做到什么？', '阅读20分钟');
    await enter('你的话', '今天读了1页，后来打开短视频');
    await next('先看有效，再看无效');
    await enter('有效：这次有哪件事是对的？', '把书放到桌上读了1页');
    await enter('无效：当时什么没起作用？', '坐下后打开短视频');
    await enter('这件事让我看见了什么？（可留空）', '先读1页也留下了一个开始');
    await next('把教训写成下一次的动作');
    await enter('最早出现的信号是什么？', '准备阅读时打开短视频');
    await enter('如果：一个能认出来的线索', '准备阅读时打开短视频');
    await enter('那么：一个可检验的小动作', '打开书读1页');
    await next('这条教训，你认可吗？');
    await shot('android_04_seal_preview');
    final stamp = find.byKey(const ValueKey('prp_seal_hold'));
    await visible(stamp);
    final gesture = await tester.startGesture(tester.getCenter(stamp));
    await tester.pump(const Duration(seconds: 3));
    await until(() => find.text('已盖印').evaluate().isNotEmpty);
    await gesture.up();
    await shot('android_05_sealed');
    await tap(find.text('这次先到这里'));
    await until(() => find
        .byKey(const ValueKey('prp_begin_reflection'))
        .evaluate()
        .isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect((await db.query('prp_lesson')).where((r) => r['state'] == 'sealed'),
        hasLength(1));
    expect(
        (await db.query('fp_learning_card'))
            .where((r) => '${r['title']}'.startsWith('PRP')),
        hasLength(1));

    // Prediction/actual UI uses the persisted feature flag, not injected model results.
    await tap(find.byKey(const ValueKey('prp_quick_forecast')));
    await tap(find.text('开启并进入'));
    await tap(find.byKey(const ValueKey('prp_forecast_new')));
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_label')), '给同事发一条具体的问题');
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_days')), '3');
    await tap(find.byKey(const ValueKey('prp_forecast_save')));
    await until(() => find.text('事情过去了，补记实际').evaluate().isNotEmpty);
    await tap(find.text('事情过去了，补记实际'));
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_days')), '1');
    await tap(find.byKey(const ValueKey('prp_forecast_save')));
    await until(() => find.textContaining('实际：').evaluate().isNotEmpty);
    await shot('android_06_forecast');
    expect((await db.query('prp_forecast')).single['closed_ms'], isNotNull);
    await back();

    await tap(find.byKey(const ValueKey('prp_quick_particles')));
    await tap(find.text('开启并进入'));
    final canvas = find.byKey(const ValueKey('prp_particle_canvas'));
    await until(() => canvas.evaluate().isNotEmpty);
    final beforeEvents = (await db.query('prp_session')).length;
    final hold = await tester.startGesture(tester.getCenter(canvas));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('按住时：粒子散开'), findsOneWidget);
    await shot('android_07_particles_pressed');
    await hold.up();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('松手后：粒子缓缓回落'), findsOneWidget);
    await shot('android_08_particles_released');
    expect((await db.query('prp_session')).length, beforeEvents);
    await back();
    await tap(find.byKey(const ValueKey('prp_quick_quotes')));
    await tap(find.text('开启并进入'));
    await shot('android_09_draft_quotes');
    expect(find.text('先留下一个开始'), findsOneWidget);
    await back();

    await switchTo('自己的声音', true);
    await tap(find.text('我的教训手册'));
    await until(() => find.textContaining('打开书读1页').evaluate().isNotEmpty);
    await visible(find.text('录下自己的提醒'));
    await tap(find.text('录下自己的提醒'));
    await until(() => find.textContaining('结束录音').evaluate().isNotEmpty);
    await until(() => find.text('播放').evaluate().isNotEmpty, seconds: 22);
    final lesson = (await runtime.store.lessons(sealedOnly: true)).single;
    expect(lesson.voicePath, isNotEmpty);
    expect(await File(lesson.voicePath).length(), greaterThan(100));
    await tap(find.text('播放'));
    await shot('android_10_playbook_audio');
    await switchTo('允许作为自己的名言', true);
    await back();
    await switchTo('名人名言首页', true);
    await switchTo('自己的名言混入首页', true);
    await switchTo('火种', true);
    await tap(find.byKey(const ValueKey('prp_observation_entry')));
    await shot('android_11_observations');
    await back();
    await back();
    await tester.tap(find.text('首页').last);
    await tester.pump(const Duration(seconds: 1));
    await tap(find.byKey(const ValueKey('home-next')));
    await until(() =>
        find.byType(PosterPureFlutter).evaluate().isNotEmpty &&
        tester
                .widget<PosterPureFlutter>(find.byType(PosterPureFlutter))
                .quote ==
            lesson.rule);
    await shot('android_12_own_quote');
    await tap(find.byKey(const ValueKey('home-favorite')));
    expect(
        await db.query('quotes', where: 'content=?', whereArgs: [lesson.rule]),
        isEmpty);

    await tester.tap(find.text('设置').last);
    await tester.pump(const Duration(milliseconds: 800));
    await tap(find.byKey(const ValueKey('settings-entry-prp')));
    await until(() =>
        find.byKey(const ValueKey('prp_master_switch')).evaluate().isNotEmpty);
    await tap(find.byKey(const ValueKey('prp_begin_reflection')));
    await until(() => find.text('先缓一缓').evaluate().isNotEmpty);
    await enter('可以写一句，也可以什么都不写', '我不想活了');
    await until(() => find.text('先照顾此刻的安全').evaluate().isNotEmpty);
    await shot('android_13_safety');
    expect(await runtime.exportData(), isNot(contains('我不想活了')));
    await tester.tapAt(const Offset(8, 100));
    await tester.pump(const Duration(milliseconds: 800));
    await until(() =>
        find.byKey(const ValueKey('prp_master_switch')).evaluate().isNotEmpty);
    await switchTo('启用插件', false);
    await shot('android_14_off_retained');
    expect((await runtime.store.lessons(sealedOnly: true)).length, 1);
    await tap(find.text('清除 PRP 数据'));
    await tap(find.text('继续清除'));
    await tap(find.text('永久清除'));
    await until(() => find.text('PRP 数据已清除。').evaluate().isNotEmpty);
    for (final table in [
      'prp_lesson',
      'prp_session',
      'prp_recall',
      'prp_forecast',
      'prp_event'
    ]) {
      expect(await db.query(table), isEmpty, reason: table);
    }
    expect(await File(lesson.voicePath).exists(), false);
    expect(
        (await db.query('fp_learning_card'))
            .where((r) => '${r['title']}'.startsWith('PRP')),
        hasLength(1));

    // Prepare a real preset via the existing DAO for the separate native-only probe.
    final now = DateTime.now();
    final preset = await BehaviorTrackingDao().savePreset(BehaviorPreset(
        createdAtMs: now.millisecondsSinceEpoch,
        updatedAtMs: now.millisecondsSinceEpoch,
        name: 'CI 原生阅读预设',
        category: '学习',
        primaryLayer: 'action',
        unit: '页',
        reminderEnabled: true,
        reminderHour: now.hour,
        reminderMinute: now.minute,
        weekdays: const [1, 2, 3, 4, 5, 6, 7],
        active: true,
        notes: 'Disposable emulator acceptance fixture',
        sortOrder: 0));
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/prp_ci_fixture.json').writeAsString(jsonEncode(
        {'preset_id': preset, 'hour': now.hour, 'minute': now.minute}));
    binding.reportData = {
      ...?binding.reportData,
      'source_sha': PrpBuildInfo.sourceSha,
      'ui_acceptance': 'passed',
      'pause_actual_seconds': 60,
      'sealed_and_persisted': true,
      'forecast_actual_ui': true,
      'particle_no_failure_event': true,
      'local_recording': true,
      'own_quote_sql_pollution': false,
      'off_preserved_data': true,
      'clear_removed_audio': true,
      'physical_device': false
    };
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
