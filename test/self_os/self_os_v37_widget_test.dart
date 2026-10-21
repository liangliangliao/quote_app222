import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'package:quote_app/self_os/self_os_case_page.dart';
import 'package:quote_app/self_os/self_os_horizon_view.dart';
import 'package:quote_app/self_os/self_os_action_focus.dart';
import 'package:quote_app/self_os/self_os_widgets.dart';
import 'package:quote_app/self_os/self_os_workbench.dart';
import 'self_os_widget_test.dart' show MemoryRepository, offlineAi;
import 'self_os_domain_test.dart' show plannedCase;
import 'self_os_v37_rules_test.dart' show decision, node, link, proof;

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 350,
      scrollable: find
          .descendant(
              of: find.byKey(const ValueKey('self_os_workbench')),
              matching: find.byType(Scrollable))
          .first,
      maxScrolls: 80);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('取消路线取舍后，选择器回到已保存状态而不假装成为主线', (tester) async {
    final c = plannedCase()..v37 = decision();
    var requested = '';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      SelfOsWorkbench(
        value: c,
        profile: SelfOsProfile(),
        history: [c],
        onChanged: () async => true,
        onAi: (_) async {},
        onEngine: (_) {},
        onProfile: (_) async {},
        onRouteState: (_, status) async {
          requested = status;
        },
      )
    ]))));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('route_status_a_experimental_0'));
    await tester.scrollUntilVisible(picker, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前主路线').last);
    await tester.pumpAndSettle();
    expect(requested, 'active');
    expect(c.v37.routes.first.status, 'experimental');
    final reset = find.byKey(const ValueKey('route_status_a_experimental_1'));
    expect(reset, findsOneWidget);
    expect(
        find.descendant(of: reset, matching: find.text('低成本实验')), findsWidgets);
  });
  testWidgets('五个工作台在窄屏大字体下可切换，风险未知保持阻塞', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = SelfOsCase(problem: '我的下一步选择');
    final repo = MemoryRepository();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: [c],
            profile: SelfOsProfile())));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      final tab = find.byKey(ValueKey('workbench_tab_$i'));
      await scrollTo(tester, tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    final first = find.byKey(const ValueKey('workbench_tab_0'));
    await scrollTo(tester, first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('确认风险与行动边界'));
    expect(find.text('风险待确认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手动添加关键未知并关联工作台，保存后可恢复', (tester) async {
    final repo = MemoryRepository();
    final c = plannedCase()..v37 = decision();
    await tester.pumpWidget(MaterialApp(
        home: SelfOsCasePage(
            value: c,
            repository: repo,
            ai: offlineAi(),
            history: [c],
            profile: SelfOsProfile(),
            initialWorkspace: 1)));
    await tester.pumpAndSettle();
    final add = find.text('手动记录关键未知');
    await scrollTo(tester, add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('v37_edit_question')), '需要多少可用时间？');
    final reason = find.byKey(const ValueKey('v37_edit_reason'));
    await tester.ensureVisible(reason);
    await tester.enterText(reason, '这会决定选择哪条路');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.v37.gaps.single.text('question'), '需要多少可用时间？');
    expect(repo.records[c.id]!.v37.gaps.single.sensitivity, 'unknown');
    expect(tester.takeException(), isNull);
  });

  testWidgets('因果图支持三个时间层、查看依据与未来路径回流', (tester) async {
    final s = decision()..evidence.add(proof());
    for (var i = 1; i <= 6; i++) {
      s.nodes.add(node('n$i', i));
      if (i > 1) s.edges.add(link('n${i - 1}', 'n$i'));
    }
    s.futureOptions.add(OsFutureOption({
      'routeId': 'a',
      'nodeId': 'n6',
      'delta': 'opened',
      'title': '可尝试的新路径',
      'condition': '能力达到可验证水平'
    }));
    var adopted = false;
    await tester.pumpWidget(MaterialApp(
        home: SelfOsTheme(
            child: Scaffold(
                body: SingleChildScrollView(
                    child: SelfOsHorizonView(
                        state: s,
                        onEditNode: (_) {},
                        onExpand: (_) {},
                        onFutureRoute: (_) => adopted = true))))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('causal_node_n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('causal_node_n6')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('causal_node_n1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('可观察的状态改变'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('horizon_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('causal_node_n5')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('horizon_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('causal_node_n6')), findsOneWidget);
    await tester.ensureVisible(find.text('叠加未来选择空间'));
    await tester.tap(find.text('叠加未来选择空间'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('带入选择空间继续比较'));
    await tester.tap(find.text('带入选择空间继续比较'));
    await tester.pumpAndSettle();
    expect(adopted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('现场只显示一条已封存提示，后台暂停，计时后衔接第一步', (tester) async {
    final snapshot = plannedCase().evidenceSnapshot();
    osMap(snapshot['v37']);
    (snapshot['v37'] as Map)['settings'] = {
      'holdCue': '我只需要走到门口',
      'holdSeconds': 10
    };
    await tester
        .pumpWidget(MaterialApp(home: SelfOsActionFocus(snapshot: snapshot)));
    await tester.pump();
    expect(find.byKey(const ValueKey('single_action_cue')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('focus_first_action')))
            .onPressed,
        isNull);
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(find.textContaining('7 秒'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 7));
    await tester.tap(find.byKey(const ValueKey('focus_first_action')));
    await tester.pump();
    expect(find.text('已经迈出第一步。'), findsOneWidget);
    expect(find.text('到达节点，记录真实行动'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('可以拒绝提示；出现新信息可随时重审，不能自动算作已行动', (tester) async {
    Map<String, dynamic>? result;
    final snapshot = plannedCase().evidenceSnapshot();
    (snapshot['v37'] as Map)['settings'] = {
      'holdCue': '用户认可的观念',
      'holdSeconds': 20
    };
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  SelfOsActionFocus(snapshot: snapshot)));
                    },
                    child: const Text('进入现场'))))));
    await tester.tap(find.text('进入现场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('这条提示不适合此刻，直接执行第一步'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('focus_first_action')))
            .onPressed,
        isNotNull);
    await tester.ensureVisible(find.text('出现重要新信息，先重审'));
    await tester.tap(find.text('出现重要新信息，先重审'));
    await tester.pumpAndSettle();
    expect(result?['result'], 'reconsider');
    expect(result?['firstActionStarted'], isFalse);
    expect(result?['declined'], isTrue);
    expect(result?['cueUsed'], isFalse);
  });
}
