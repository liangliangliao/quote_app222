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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
