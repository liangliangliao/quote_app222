import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/data/kv_dao.dart';
import 'package:quote_app/pages/settings_page.dart';
import 'package:quote_app/services/global_ai_request_settings.dart';
import 'package:quote_app/services/global_ai_settings.dart';
import 'package:quote_app/services/native_guard.dart';
import 'package:quote_app/widgets/settings_dashboard.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'prp_plugin/fixtures.dart';
import 'prp_plugin/widget_test.dart' show prpIo, settlePrp;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;

  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('settings_dashboard_');
    databaseFactory = databaseFactoryFfiNoIsolate;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    await AppDatabase.instance();
  });
  tearDownAll(() async {
    await (await AppDatabase.instance()).close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await docs.delete(recursive: true);
  });

  Future<void> waitUntil(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 150 && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(ready(), isTrue, reason: 'local settings should finish loading');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dashboard opens every destination and shows the supplied status',
    (tester) async {
      final opened = <SettingsSection>[];
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsDashboard(
            summary: const SettingsAiSummary(
              provider: 'Gemini',
              model: 'my-saved-model',
              configured: true,
            ),
            onOpen: opened.add,
          ),
        ),
      );
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('my-saved-model'), findsOneWidget);
      expect(find.text('已配置'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      for (final section in [
        SettingsSection.ai,
        SettingsSection.prp,
        SettingsSection.voice,
        SettingsSection.prompts,
        SettingsSection.parameters,
        SettingsSection.semantic,
        SettingsSection.modules,
        SettingsSection.movies,
        SettingsSection.media,
        SettingsSection.data,
        SettingsSection.appearance,
        SettingsSection.logs,
      ]) {
        final entry = find.byKey(ValueKey('settings-entry-${section.name}'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(opened.last, section);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [
    (const Size(320, 720), 1.8),
    (const Size(390, 844), 1.0),
    (const Size(768, 1024), 1.6),
  ]) {
    testWidgets(
      'dashboard remains readable at ${viewport.$1} / ${viewport.$2}',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(viewport.$2)),
              child: child!,
            ),
            home: SettingsDashboard(
              summary: const SettingsAiSummary(
                provider: 'Azure',
                model: 'resource/a-long-deployment-name',
              ),
              onOpen: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('待配置'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-entry-logs')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saving request parameters preserves unrelated settings and drafts survive bus updates',
    (tester) async {
      final config = ConfigDao();
      final kv = KeyValueDao();
      final globalAi = GlobalAiSettings();
      await tester.runAsync(() async {
        await config.save(
          apiKey: 'test-before',
          model: 'test-model',
          endpoint: 'https://example.invalid/v1',
        );
        await globalAi.save(provider: 'openai', model: 'test-model');
        await kv.setString('ce_prompt_extra_openai', 'keep this template');
        await kv.setString(
          'ce_prompt_version_last_at_openai',
          'keep this version',
        );
      });
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await waitUntil(
        tester,
        () => find.text('test-model').evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('settings-entry-parameters')));
      await tester.pump();
      final save = find.byKey(const ValueKey('settings-save'));
      await waitUntil(
        tester,
        () =>
            save.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(save).onPressed != null,
      );
      final timeout = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '例如 90；留空则使用模块默认',
      );
      await tester.ensureVisible(timeout);
      await tester.enterText(timeout, '75');
      // A background update must not replace the draft or be overwritten by Save.
      await tester.runAsync(
        () => config.save(
          apiKey: 'test-updated-elsewhere',
          model: 'new-model',
          endpoint: 'https://example.invalid/new',
        ),
      );
      SimpleBus.settingsTick.value++;
      await tester.pump();
      expect(tester.widget<TextField>(timeout).controller!.text, '75');
      await tester.tap(save);
      await tester.pump();
      await waitUntil(
        tester,
        () =>
            find.byType(SettingsDashboard).evaluate().isNotEmpty &&
            save.evaluate().isEmpty,
      );
      await tester.runAsync(() async {
        expect(
          (await GlobalAiRequestSettings().getConfig()).timeoutSeconds,
          75,
        );
        expect((await config.getOne())['api_key'], 'test-updated-elsewhere');
        expect(
          (await config.getOne())['endpoint'],
          'https://example.invalid/new',
        );
        expect(
          await kv.getString('ce_prompt_extra_openai'),
          'keep this template',
        );
        expect(
          await kv.getString('ce_prompt_version_last_at_openai'),
          'keep this version',
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'configuration menus retain voice, template, import and module controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      for (final destination in {
        SettingsSection.voice: ['名言朗读服务商', '语音服务与声音库'],
        SettingsSection.prompts: ['提示词配置中心', '电影分析提示词', '首页侧栏 AI 主题开关'],
        SettingsSection.modules: [
          'PRP 插件 · 失败成长',
          '健康饮食配置',
          '心情与自尊问答',
          '运动与音乐',
          '提醒设置',
          '地图与位置服务',
          '日记设置',
        ],
        SettingsSection.data: ['上传量表模板文件', '选择文件', '导入', '提示词备份与恢复', '名言导入与历史'],
      }.entries) {
        final entry = find.byKey(
          ValueKey('settings-entry-${destination.key.name}'),
        );
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        await waitUntil(
          tester,
          () => find.text(destination.value.first).evaluate().isNotEmpty,
        );
        for (final label in destination.value) {
          final control = find.text(label);
          await tester.scrollUntilVisible(
            control,
            200,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(control, findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('returning during a local settings load disposes safely', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.tap(find.byKey(const ValueKey('settings-entry-voice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    Navigator.of(tester.element(find.byType(SettingsPage).last)).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'settings entry completes a manual PRP review and shows its sealed lesson',
      (tester) async {
    final fixture = PrpFixture();
    await tester.runAsync(fixture.open);
    addTearDown(() => PrpPlugin.instance = const NoopPrpPlugin());
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    final entry = find.byKey(const ValueKey('settings-entry-prp'));
    await waitUntil(tester, () => entry.evaluate().isNotEmpty);
    expect(entry.hitTestable(), findsOneWidget);
    await tester.tap(entry);
    await settlePrp(tester,
        until: find.byKey(const ValueKey('prp_master_switch')));
    final begin = find.byKey(const ValueKey('prp_begin_reflection'));
    expect(tester.widget<FilledButton>(begin).onPressed, isNull);
    expect(fixture.databaseOpens, 0);
    await tester.tap(find.byKey(const ValueKey('prp_master_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按这些选择开启'));
    await waitUntil(tester, () => fixture.runtime.enabled);
    expect(fixture.runtime.preferences.aiConsent, false);
    expect(fixture.runtime.preferences.surfaces[PrpSurface.quoteHome], false);
    expect(fixture.runtime.preferences.surfaces[PrpSurface.kindling], false);
    await settlePrp(tester, until: find.textContaining('已盖印 0 条'));
    expect(find.textContaining('首页调用点未开启'), findsOneWidget);
    expect(tester.widget<FilledButton>(begin).onPressed, isNotNull);
    await tester.tap(begin);
    await settlePrp(tester, until: find.text('先缓一缓'));
    expect(find.text('60 秒'), findsOneWidget);
    expect(find.text('把事实摆出来'), findsNothing);
    final rows = await prpIo(tester, () => fixture.db.query('prp_session'));
    expect(rows.single['surface'], 'failure_module');
    expect(rows.single['counts_offer'], 0);
    fixture.clock.advance(const Duration(seconds: 60));
    await tester.pump(const Duration(milliseconds: 250));
    Future<void> next(String title) async {
      final control = find.byKey(const ValueKey('prp_next'));
      await tester.ensureVisible(control);
      await tester.tap(control);
      await settlePrp(tester, until: find.text(title));
    }

    Future<void> enter(String label, String value) async {
      final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await next('把事实摆出来');
    await enter('原本希望做到什么？', '阅读20分钟');
    await enter('你的话', '今天先读了1页，后来打开短视频');
    await next('先看有效，再看无效');
    await enter('有效：这次有哪件事是对的？', '把书放到桌上读了1页');
    await enter('无效：当时什么没起作用？', '坐下后打开短视频');
    await next('把教训写成下一次的动作');
    await enter('最早出现的信号是什么？', '准备阅读时打开短视频');
    await enter('如果：一个能认出来的线索', '准备阅读时打开短视频');
    await enter('那么：一个可检验的小动作', '打开书读1页');
    await next('这条教训，你认可吗？');
    final stamp = find.byKey(const ValueKey('prp_seal_hold'));
    await tester.ensureVisible(stamp);
    final gesture = await tester.startGesture(tester.getCenter(stamp));
    fixture.clock.advance(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await settlePrp(tester, until: find.text('已盖印'));
    await gesture.up();
    await tester.ensureVisible(find.text('这次先到这里'));
    await tester.tap(find.text('这次先到这里'));
    await settlePrp(tester, until: begin);
    expect(find.text('先缓一缓'), findsNothing);
    expect(tester.widget<FilledButton>(begin).onPressed, isNotNull);
    await settlePrp(tester, until: find.textContaining('已盖印 1 条'));
    final book = find.text('我的教训手册');
    await tester.scrollUntilVisible(book, 300,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(book);
    await settlePrp(tester, until: find.textContaining('打开书读1页'));
    final lessons = await prpIo(tester, () => fixture.runtime.store.lessons());
    expect(lessons.single.state, 'sealed');
    expect(lessons.single.triggerText, '阅读20分钟');
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });
}
