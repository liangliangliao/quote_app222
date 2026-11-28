import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/voice_alarm/wakeup_history_page.dart';

void main() {
  const channel = MethodChannel('test/voice_alarm_history');
  const recent = '2026-11-27';
  const older = '2026-11-20';
  const oldYear = '2024-04-10';
  final loadedDates = <Object?>[];

  setUp(() {
    loadedDates.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getAiWakeupHistoryDates':
          return [oldYear, older, recent];
        case 'getAiWakeupHistory':
          final date = call.arguments['date'];
          loadedDates.add(date);
          return [
            {
              'title': date == older ? '备用提醒' : '已同步任务',
              'text': '记录正文 $date',
              'replayTask': date != older,
            },
            if (date == recent)
              {'title': '已保留的旧版本', 'text': '旧正文', 'replayTask': false},
          ];
        default:
          throw MissingPluginException(call.method);
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  testWidgets('browse saved days directly and select from the calendar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WakeupHistoryPage(channel: channel)),
    );
    await tester.pumpAndSettle();
    expect(loadedDates, [recent]);
    expect(find.byTooltip('较新的记录'), findsOneWidget);
    expect(find.text('已保留的旧版本'), findsOneWidget);

    await tester.tap(find.byTooltip('较早的记录'));
    await tester.pumpAndSettle();
    expect(loadedDates, [recent, older]);
    expect(find.text('备用提醒'), findsOneWidget);

    await tester.tap(find.text('$older（北京时间）'));
    await tester.pumpAndSettle();
    final dialog = find.byType(DatePickerDialog);
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, DateTime(2024, 4, 10));
    expect(calendar.selectableDayPredicate!(DateTime(2026, 11, 26)), isFalse);
    await tester.tap(find.descendant(of: dialog, matching: find.text('27')));
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(loadedDates, [recent, older, recent]);
    expect(find.text('已同步任务'), findsOneWidget);
  });

  testWidgets('confirm only a day with tasks and return the selected date', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final date = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const WakeupHistoryPage(
                      channel: channel,
                      chooseReplayDate: true,
                      initialDate: older,
                    ),
                  ),
                );
                if (!context.mounted || date == null) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('已选择 $date')));
              },
              child: const Text('选择历史任务'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择历史任务'));
    await tester.pumpAndSettle();
    expect(loadedDates, [older]);
    expect(find.text('这一天没有可播报的定时任务'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.byTooltip('较新的记录'));
    await tester.pumpAndSettle();
    expect(find.text('已保留的旧版本'), findsNothing);
    await tester.tap(find.text('使用这一天的 1 项任务'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 $recent'), findsOneWidget);
  });
}
