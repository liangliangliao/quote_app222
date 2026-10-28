import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/dao.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/pages/settings_page.dart';
import 'package:quote_app/pages/logs_page.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory docs;
  var opened = false;
  setUpAll(() async {
    docs = await Directory.systemTemp.createTemp('quote_editor_');
    databaseFactory = databaseFactoryFfiNoIsolate;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      (_) async => null,
    );
    await AppDatabase.instance();
    opened = true;
  });
  tearDownAll(() async {
    if (opened) await (await AppDatabase.instance()).close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('native.scheduler'),
      null,
    );
    await docs.delete(recursive: true);
  });

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Finder dropdown(String label) => find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String> && w.decoration.labelText == label,
  );
  Future<void> waitForEditor(WidgetTester tester, Future<void> editor) async {
    var closed = false;
    editor.then((_) => closed = true);
    for (var i = 0; i < 100 && !closed; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(closed, isTrue, reason: 'the editor should close after saving');
    await tester.pumpAndSettle();
  }

  testWidgets('new and edited AI tasks preserve their choices and schedule', (
    tester,
  ) async {
    final key = GlobalKey<SettingsPageState>();
    await tester.pumpWidget(MaterialApp(home: SettingsPage(key: key)));
    await tester.pump();
    final createEditor = key.currentState!.openTaskEditor(null);
    await tester.pumpAndSettle();
    expect(find.text('新增任务'), findsOneWidget);
    await tester.enterText(field('任务名称'), '每天读一句');
    await tester.tap(dropdown('任务类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 自动获取').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('quote-figure-search')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-figure-search')),
      '萨特',
    );
    await tester.pump();
    final sartreChip = find.ancestor(
      of: find.text('萨特').last,
      matching: find.byType(FilterChip),
    );
    await tester.ensureVisible(sartreChip);
    await tester.tap(sartreChip);
    await tester.pump();
    await tester.ensureVisible(field('自定义人物'));
    await tester.enterText(field('自定义人物'), '我的导师');
    await tester.ensureVisible(dropdown('主题或类别'));
    await tester.tap(dropdown('主题或类别'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义主题').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('自定义主题'));
    await tester.enterText(field('自定义主题'), '重新开始');
    await tester.ensureVisible(field('想表达或面对的内容'));
    await tester.enterText(field('想表达或面对的内容'), '寻找面对变化的勇气');
    await tester.ensureVisible(find.text('启用任务'));
    await tester.tap(find.text('启用任务'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await waitForEditor(tester, createEditor);
    final tasks = await TaskDao().all();
    expect(tasks, hasLength(1));
    expect(tasks.single['status'], 'off');
    expect(tasks.single['freq_type'], 'daily');
    final config = QuoteAiTaskConfig.fromTask(tasks.single);
    expect(config.selectedFigures, ['萨特']);
    expect(config.customFigures, ['我的导师']);
    expect(config.theme, '重新开始');
    expect(config.userDescription, '寻找面对变化的勇气');

    final editEditor = key.currentState!.openTaskEditor(tasks.single);
    await tester.pumpAndSettle();
    expect(find.text('编辑任务'), findsOneWidget);
    expect(tester.widget<TextField>(field('自定义人物')).controller?.text, '我的导师');
    expect(tester.widget<TextField>(field('自定义主题')).controller?.text, '重新开始');
    await tester.ensureVisible(field('想表达或面对的内容'));
    await tester.enterText(field('想表达或面对的内容'), '给自己更多耐心');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await waitForEditor(tester, editEditor);
    final edited = await TaskDao().getByUid(
      tasks.single['task_uid'].toString(),
    );
    expect(QuoteAiTaskConfig.fromTask(edited!).userDescription, '给自己更多耐心');
    expect(QuoteAiTaskConfig.fromTask(edited).customFigures, ['我的导师']);

    final foreignUid = await TaskDao().create(
      name: '向己目标',
      type: 'xiangji_goal',
      status: 'off',
      prompt: '模块原有内容',
      freqCustom: '{"module":"xiangji"}',
    );
    final foreignTask = await TaskDao().getByUid(foreignUid);
    final foreignEditor = key.currentState!.openTaskEditor(foreignTask);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(dropdown('任务类型'))
          .onChanged,
      isNull,
    );
    await tester.enterText(field('任务名称'), '向己目标提醒');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await waitForEditor(tester, foreignEditor);
    final foreignAfter = await TaskDao().getByUid(foreignUid);
    expect(foreignAfter!['type'], 'xiangji_goal');
    expect(foreignAfter['prompt'], '模块原有内容');
    expect(foreignAfter['freq_custom'], '{"module":"xiangji"}');

    final manualEditor = key.currentState!.openTaskEditor(null);
    await tester.pumpAndSettle();
    await tester.enterText(field('任务名称'), '珍藏一句话');
    await tester.ensureVisible(field('名人名言'));
    await tester.enterText(field('名人名言'), '生活由选择构成');
    await tester.ensureVisible(find.text('启用任务'));
    await tester.tap(find.text('启用任务'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await waitForEditor(tester, manualEditor);
    final manual = (await TaskDao().all()).singleWhere(
      (task) => task['name'] == '珍藏一句话',
    );
    expect(
      (await QuoteDao().latestForTask(
        manual['task_uid'].toString(),
      ))?['content'],
      '生活由选择构成',
    );

    final manualEdit = key.currentState!.openTaskEditor(manual);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('名人名言'));
    await tester.enterText(field('名人名言'), '认真生活，慢慢成长');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await waitForEditor(tester, manualEdit);
    expect(
      (await QuoteDao().latestForTask(
        manual['task_uid'].toString(),
      ))?['content'],
      '认真生活，慢慢成长',
    );

    final countBeforeDuplicate = (await TaskDao().all()).length;
    final duplicateEditor = key.currentState!.openTaskEditor(null);
    await tester.pumpAndSettle();
    await tester.enterText(field('任务名称'), '重复的任务');
    await tester.ensureVisible(field('名人名言'));
    await tester.enterText(field('名人名言'), '认真生活，慢慢成长');
    await tester.ensureVisible(find.text('启用任务'));
    await tester.tap(find.text('启用任务'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect((await TaskDao().all()).length, countBeforeDuplicate);
    expect(find.text('新增任务'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    await waitForEditor(tester, duplicateEditor);

    await tester.ensureVisible(find.text('运行日志'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('运行日志'));
    await tester.pumpAndSettle();
    expect(find.byType(LogsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
