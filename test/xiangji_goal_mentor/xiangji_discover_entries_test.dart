import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_discover_entries.dart';

void main() {
  testWidgets('发现之旅始终展示目标导师和未来军师两个独立入口',
      (tester) async {
    var goalMentorOpened = false;
    var futureStrategistOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XiangjiDiscoverEntries(
            onGoalMentorTap: () => goalMentorOpened = true,
            onFutureStrategistTap: () => futureStrategistOpened = true,
          ),
        ),
      ),
    );

    expect(find.text('向己 · 智能目标导师'), findsOneWidget);
    expect(find.text('向己 · 未来军师'), findsOneWidget);
    expect(
      find.byKey(XiangjiDiscoverEntries.goalMentorKey),
      findsOneWidget,
    );
    expect(
      find.byKey(XiangjiDiscoverEntries.futureStrategistKey),
      findsOneWidget,
    );

    await tester.tap(find.text('向己 · 智能目标导师'));
    await tester.tap(find.text('向己 · 未来军师'));

    expect(goalMentorOpened, isTrue);
    expect(futureStrategistOpened, isTrue);
  });
}
