import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_mirror/will_mirror_discover_entry.dart';
import 'package:quote_app/will_mirror/will_mirror_home_page.dart';
import 'package:quote_app/will_mirror/will_mirror_models.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_models.dart';
import 'package:quote_app/will_mirror/will_mirror_practice_page.dart';
import 'package:quote_app/will_mirror/will_mirror_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Discover entry has stable key and opens Will Mirror',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WillMirrorDiscoverEntry(onTap: () => opened = true),
        ),
      ),
    );

    expect(find.byKey(WillMirrorDiscoverEntry.entryKey), findsOneWidget);
    expect(find.text('意志之镜 · 把想法变成行动'), findsOneWidget);
    expect(find.textContaining('今天第一步'), findsOneWidget);

    await tester.tap(find.byKey(WillMirrorDiscoverEntry.entryKey));
    expect(opened, isTrue);
  });

  testWidgets('home starts with one need input, one primary action and help',
      (tester) async {
    final vault = _EmptyWillMirrorVault();
    addTearDown(vault.close);

    await tester.pumpWidget(
      MaterialApp(
        home: WillMirrorHomePage(vault: vault),
      ),
    );
    await _pumpUntilVisible(tester, find.text('今天，你想解决什么？'));

    expect(find.byKey(WillMirrorHomePage.primaryInputKey), findsOneWidget);
    expect(find.byKey(WillMirrorHomePage.primaryActionKey), findsOneWidget);
    expect(find.byKey(WillMirrorHomePage.assistantKey), findsOneWidget);
    expect(find.text('看完整案例'), findsOneWidget);
    expect(find.text('怎么用'), findsOneWidget);
    expect(find.text('进阶工具'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('不诊断、不治疗'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('不诊断、不治疗'), findsOneWidget);
  });

  testWidgets('practice wizard turns a need into three grounded routes',
      (tester) async {
    final vault = _EmptyWillMirrorVault();
    addTearDown(vault.close);
    await tester.pumpWidget(
      MaterialApp(
        home: WillMirrorPracticePage(
          vault: vault,
          initialText: '完成作品集初稿',
        ),
      ),
    );
    await _pumpUntilVisible(tester, find.text('你今天最想改变什么？'));
    await tester.enterText(
      find.byKey(WillMirrorPracticePage.outcomeFieldKey),
      '有两页可以展示的草稿',
    );
    await tester.tap(find.byKey(WillMirrorPracticePage.nextButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('选今天最适合你的方式'), findsOneWidget);

    await tester.tap(find.byKey(WillMirrorPracticePage.nextButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('三个都能产出，选最想试的'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('wm_route_act_now')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('wm_route_understand_then_act')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wm_route_seven_day_experiment')),
      findsOneWidget,
    );
    expect(find.textContaining('做到哪算完成'), findsWidgets);
  });
}

Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('目标组件未在 20 帧内出现：$finder');
}

class _EmptyWillMirrorVault extends WillMirrorVault {
  @override
  Future<WillMirrorGoal?> activeGoal() async => null;

  @override
  Future<WillMirrorExperiment?> activeExperiment() async => null;

  @override
  Future<WillMirrorActionPlan?> activeActionPlan() async => null;

  @override
  Future<WillMirrorPracticeProfile?> practiceProfile() async => null;
}
