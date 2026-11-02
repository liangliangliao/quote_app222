import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/pages/history_page.dart';
import 'package:quote_app/pages/logs_page.dart';
import 'package:quote_app/pages/tasks_page.dart';
import 'package:quote_app/services/native_guard.dart';
import 'package:quote_app/services/quote_ai_service.dart';
import 'package:quote_app/utils/quote_change_bus.dart';
import 'package:quote_app/widgets/discovery_directory.dart';
import 'package:quote_app/widgets/quote_figure_picker.dart';

void _signalQuoteFromBackground(SendPort finished) {
  QuoteChangeBus.notifyWrite();
  finished.send(true);
}

void main() {
  test('background quote writes reach the foreground port', () async {
    final events = ReceivePort();
    final finished = ReceivePort();
    ui.IsolateNameServer.removePortNameMapping(QuoteChangeBus.portName);
    expect(
      ui.IsolateNameServer.registerPortWithName(
        events.sendPort,
        QuoteChangeBus.portName,
      ),
      isTrue,
    );
    try {
      final received = events.first.timeout(const Duration(seconds: 5));
      await Isolate.spawn(_signalQuoteFromBackground, finished.sendPort);
      await finished.first.timeout(const Duration(seconds: 5));
      await received;
    } finally {
      ui.IsolateNameServer.removePortNameMapping(QuoteChangeBus.portName);
      events.close();
      finished.close();
    }
  });

  test(
    'every field has a broad catalog and requested figures remain selectable',
    () {
      for (final entry in quoteFigureCatalog.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(22), reason: entry.key);
        expect(
          entry.value.toSet().length,
          entry.value.length,
          reason: entry.key,
        );
      }
      final names = quoteFigureCatalog.values
          .expand((values) => values)
          .join('、');
      for (final name in [
        '萨特',
        'Tal Ben-Shahar',
        '弗洛伊德',
        '阿德勒',
        '班杜拉',
        '老子',
        '莫言',
        '托妮·莫里森',
        '石黑一雄',
      ]) {
        expect(names, contains(name));
      }
    },
  );

  testWidgets('figure search keeps the ordered selection across categories', (
    tester,
  ) async {
    final selected = <String>{'已有的自定义选择'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => QuoteFigurePicker(
                selected: selected,
                onChanged: (value) => setState(
                  () => selected
                    ..clear()
                    ..addAll(value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('quote-figure-search')),
      '萨特',
    );
    await tester.pump();
    await tester.tap(
      find.ancestor(
        of: find.text('萨特').last,
        matching: find.byType(FilterChip),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('quote-figure-search')),
      '班杜拉',
    );
    await tester.pump();
    await tester.tap(
      find.ancestor(
        of: find.text('阿尔伯特·班杜拉'),
        matching: find.byType(FilterChip),
      ),
    );
    await tester.pump();
    expect(selected.toList(), ['已有的自定义选择', '萨特', '阿尔伯特·班杜拉']);
    expect(find.text('已有的自定义选择'), findsOneWidget);
  });

  testWidgets(
    'history retains its snapshot while a write refreshes, then shows the new quote',
    (tester) async {
      final rows = <Map<String, dynamic>>[
        {'id': 1, 'quote_uid': 'old', 'content': '原有名言'},
      ];
      Completer<List<Map<String, dynamic>>>? pending;
      Future<List<Map<String, dynamic>>> load({
        required int limit,
        required int offset,
        String? q,
      }) async {
        if (pending != null) return pending!.future;
        return rows
            .where((row) => q == null || row['content'].toString().contains(q))
            .skip(offset)
            .take(limit)
            .toList();
      }

      await tester.pumpWidget(MaterialApp(home: HistoryPage(loadQuotes: load)));
      await tester.pump();
      expect(find.text('原有名言'), findsOneWidget);

      pending = Completer<List<Map<String, dynamic>>>();
      QuoteChangeBus.deliver();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('原有名言'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      rows.insert(0, {'id': 2, 'quote_uid': 'new', 'content': '新加入的名言'});
      pending!.complete(List.of(rows));
      pending = null;
      await tester.pump();
      await tester.pump();
      expect(find.text('原有名言'), findsOneWidget);
      expect(find.text('新加入的名言'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '新加入');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.text('新加入的名言'), findsOneWidget);
      expect(find.text('原有名言'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('history notices native writes while its tab is visible', (
    tester,
  ) async {
    final rows = <Map<String, dynamic>>[
      {'id': 1, 'quote_uid': 'old', 'content': '先前的名言'},
    ];
    final requestedLimits = <int>[];
    Future<List<Map<String, dynamic>>> load({
      required int limit,
      required int offset,
      String? q,
    }) async {
      requestedLimits.add(limit);
      return rows.skip(offset).take(limit).toList();
    }

    SimpleBus.navIndex.value = 1;
    await tester.pumpWidget(MaterialApp(home: HistoryPage(loadQuotes: load)));
    await tester.pump();
    requestedLimits.clear();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(requestedLimits, [1]);
    requestedLimits.clear();
    rows.insert(0, {'id': 2, 'quote_uid': 'native', 'content': '原生写入的名言'});
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(requestedLimits, [1, 100]);
    expect(find.text('先前的名言'), findsOneWidget);
    expect(find.text('原生写入的名言'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    SimpleBus.navIndex.value = 0;
  });

  testWidgets('task tab filters existing tasks and delegates add and edit', (
    tester,
  ) async {
    final tasks = <Map<String, dynamic>>[
      {
        'task_uid': 'one',
        'name': '晨间名言',
        'type': 'manual',
        'status': 'on',
        'freq_type': 'daily',
      },
      {
        'task_uid': 'two',
        'name': '晚间阅读',
        'type': 'auto',
        'status': 'off',
        'freq_type': 'daily',
      },
    ];
    Map<String, dynamic>? edited;
    var created = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TasksPage(
          loadTasks: () async => tasks,
          openEditor: (task) async {
            if (task == null) {
              created = true;
            } else {
              edited = task;
            }
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('task-create')));
    await tester.pump();
    expect(created, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('task-card-one')));
    await tester.tap(find.byKey(const ValueKey('task-card-one')));
    await tester.pump();
    expect(edited?['task_uid'], 'one');
    await tester.ensureVisible(find.text('已暂停').first);
    await tester.tap(find.text('已暂停').first);
    await tester.pump();
    expect(find.text('晨间名言'), findsNothing);
    expect(find.text('晚间阅读'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('task countdowns pause and resume with the task tab', (
    tester,
  ) async {
    final tasks = <Map<String, dynamic>>[
      {'task_uid': 'one', 'name': '第一条', 'type': 'manual', 'status': 'on'},
      {'task_uid': 'two', 'name': '第二条', 'type': 'manual', 'status': 'on'},
    ];
    Widget page(bool active) => MaterialApp(
      home: TasksPage(
        active: active,
        loadTasks: () async => tasks,
        openEditor: (_) async {},
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pump();
    await tester.pumpWidget(page(true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('log updates keep the existing entries visible while loading', (
    tester,
  ) async {
    final rows = <Map<String, dynamic>>[
      {'id': 1, 'log_uid': 'old', 'detail': '旧日志内容', 'task_name': '系统'},
    ];
    Completer<List<Map<String, dynamic>>>? pending;
    Future<List<Map<String, dynamic>>> load({
      required int limit,
      required int offset,
      required String keyword,
      required bool deepseekOnly,
      required bool errorOnly,
    }) async {
      if (pending != null) return pending!.future;
      return rows.skip(offset).take(limit).toList();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LogsPage(loadLogs: load)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('旧日志内容'), findsOneWidget);
    pending = Completer<List<Map<String, dynamic>>>();
    SimpleBus.pokeLogs();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.textContaining('旧日志内容'), findsOneWidget);
    rows.insert(0, {
      'id': 2,
      'log_uid': 'new',
      'detail': '新日志内容',
      'task_name': '系统',
    });
    pending!.complete(List.of(rows));
    pending = null;
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('新日志内容'), findsOneWidget);
    expect(find.textContaining('旧日志内容'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'discovery categories and search reveal destinations without a long list',
    (tester) async {
      var opened = '';
      final destinations = [
        DiscoveryDestination(
          title: '日记',
          subtitle: '记录此刻',
          icon: Icons.edit,
          categories: const {'认识自己'},
          recommended: true,
          onTap: () => opened = '日记',
        ),
        DiscoveryDestination(
          title: '电影',
          subtitle: '探索故事',
          icon: Icons.movie,
          categories: const {'灵感天地'},
          onTap: () => opened = '电影',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoveryDirectory(
              destinations: destinations,
              onRefresh: () async {},
            ),
          ),
        ),
      );
      expect(find.text('日记'), findsOneWidget);
      expect(find.text('电影'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('discover-search')),
        '故事',
      );
      await tester.pump();
      expect(find.text('电影'), findsOneWidget);
      await tester.tap(find.text('电影'));
      expect(opened, '电影');
      await tester.tap(find.byKey(const ValueKey('discover-category-认识自己')));
      await tester.pump();
      expect(find.text('日记'), findsOneWidget);
      expect(find.text('电影'), findsNothing);
    },
  );

  testWidgets(
    'task and discovery screens fit a narrow display with larger text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app(Widget child) => MaterialApp(
        builder: (context, screen) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.25)),
          child: screen!,
        ),
        home: child,
      );
      await tester.pumpWidget(
        app(
          TasksPage(
            loadTasks: () async => [
              {
                'task_uid': 'one',
                'name': '晨间名言与思想',
                'type': 'manual',
                'status': 'on',
                'freq_type': 'daily',
              },
            ],
            openEditor: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: DiscoveryDirectory(
              destinations: [
                DiscoveryDestination(
                  title: '愿景与目标',
                  subtitle: '为重要的方向留出时间',
                  icon: Icons.flag,
                  categories: const {'行动成长'},
                  recommended: true,
                  onTap: () {},
                ),
              ],
              onRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
