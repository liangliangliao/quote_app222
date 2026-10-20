import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/self_os/self_os_ai_service.dart';
import 'package:quote_app/self_os/self_os_guide_page.dart';
import 'package:quote_app/self_os/self_os_home_page.dart';
import 'package:quote_app/self_os/self_os_models.dart';
import 'self_os_guide_test.dart'
    show guideResponse, scenarioAi, experimentGuide, readyGuide;
import 'self_os_widget_test.dart' show MemoryRepository, offlineAi, fill;

class ReadFailRepository extends MemoryRepository {
  bool failRead = false;
  @override
  Future<List<SelfOsCase>> loadCases() {
    if (failRead) throw StateError('temporary read failure');
    return super.loadCases();
  }
}

Future<void> guideReveal(WidgetTester tester, Finder finder) async {
  final scroll = find
      .descendant(
          of: find.byKey(const ValueKey('self_os_guide')),
          matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(finder, 260,
      scrollable: scroll, maxScrolls: 60);
  await tester.pumpAndSettle();
}

Future<void> guideTap(WidgetTester tester, Finder finder) async {
  await guideReveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> guideFill(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await guideReveal(tester, field);
  await tester.enterText(field, value);
  await tester.pump();
}

Widget guideApp(SelfOsCase c, MemoryRepository repo, SelfOsAiService ai,
        {double scale = 1}) =>
    MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: SelfOsGuidePage(
            value: c,
            repository: repo,
            ai: ai,
            history: [c],
            profile: SelfOsProfile()));

void main() {
  testWidgets('修改动作后旧边界确认失效，必须重新确认才能封存', (tester) async {
    final c = experimentGuide(), repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi()));
    await tester.pumpAndSettle();
    await guideTap(tester, find.text('调整动作、预期与观察方式'));
    await guideFill(tester, 'guide_1_plan_action', '先花十分钟写下想确认的问题，不急着沟通');
    await tester.pump(const Duration(seconds: 1));
    expect(repo.records[c.id]!.guide.draft['costAccepted'], isFalse);
    expect(repo.records[c.id]!.guide.draft['reversible'], isFalse);
    await guideTap(tester, find.byKey(const ValueKey('guide_commit')));
    expect(repo.records[c.id]!.commitment, isNull);
    expect(find.textContaining('可承受、可撤回'), findsOneWidget);
  });

  testWidgets('纠正中途离开后恢复输入与纠正界面，不在草稿上自动重新分析', (tester) async {
    final c = readyGuide(), repo = MemoryRepository();
    await tester.pumpWidget(guideApp(c, repo, offlineAi()));
    await tester.pumpAndSettle();
    await guideTap(tester, find.text('理解有偏差，我来修正'));
    await guideFill(tester, 'guide_answer', '其实还有另外一件事，我还没说完');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(guideApp(repo.records[c.id]!, repo, offlineAi()));
    await tester.pumpAndSettle();
    expect(find.text('哪一处需要重新理解？'), findsOneWidget);
    await guideReveal(tester, find.byKey(const ValueKey('guide_answer')));
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('guide_answer')))
            .controller!
            .text,
        '其实还有另外一件事，我还没说完');
    expect(find.textContaining('AI 暂时不可用'), findsNothing);
  });

  testWidgets('详细分析返回时读取失败，后台保存不能覆盖详细页面的新记录', (tester) async {
    final c = experimentGuide(), repo = ReadFailRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分析与记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('欲求假设与 Why Tree'));
    await tester.pumpAndSettle();
    await fill(tester, 'goal', '在详细分析里补充的目标', engine: 'desire');
    repo.failRead = true;
    await tester.tap(find.byTooltip('保存并返回'));
    await tester.pumpAndSettle();
    expect(find.text('重试读取最新记录'), findsOneWidget);
    expect(repo.records[c.id]!.text('goal'), '在详细分析里补充的目标');
    final saved = jsonEncode(repo.records[c.id]!.toJson());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(jsonEncode(repo.records[c.id]!.toJson()), saved);
    repo.failRead = false;
    await tester.tap(find.text('重试读取最新记录'));
    await tester.pumpAndSettle();
    expect(find.text('重试读取最新记录'), findsNothing);
    expect(repo.records[c.id]!.text('goal'), '在详细分析里补充的目标');
    expect(tester.takeException(), isNull);
  });
  testWidgets('真实使用路径：说出困惑→一个追问→认可新理解→小行动→实际反馈', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MemoryRepository(), purposes = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: SelfOsHomePage(
            repository: repo, ai: scenarioAi(purposes: purposes))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我现在面临一个选择'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('dialog_problem')), '想换工作，又怕后悔。');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('self_os_guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('open_workbench')), findsNothing);
    expect(repo.records.values.single.desires, hasLength(5));
    await guideFill(tester, 'guide_answer', '我并不讨厌工作内容，只是不喜欢每个决定都要审批。');
    await guideTap(tester, find.byKey(const ValueKey('guide_send')));
    expect(repo.records.values.single.guide.frame!['insight']['after'],
        contains('自主空间'));
    expect(repo.records.values.single.acceptedDesires, isEmpty);
    await guideTap(tester, find.text('尝试的理由更清楚了'));
    await guideTap(tester, find.byKey(const ValueKey('guide_confirm')));
    expect(repo.records.values.single.guide.phase, 'plan');
    await guideFill(tester, 'guide_1_plan_trigger', '明天下午例会后，主管有空时');
    await guideTap(tester, find.byKey(const ValueKey('guide_cost')));
    await guideTap(tester, find.byKey(const ValueKey('guide_reversible')));
    await guideTap(tester, find.byKey(const ValueKey('guide_commit')));
    expect(repo.records.values.single.commitment!['commitmentScope'],
        'experiment');
    expect(repo.records.values.single.scores['planProbability'], isNull);
    expect(repo.records.values.single.reviewed, isFalse);
    await guideTap(tester, find.text('记录实际发生的事（也可以是没做）'));
    await guideTap(tester, find.text('做了一部分'));
    await guideFill(
        tester, 'guide_1_review_result', '主管同意了一个小任务由我决定，但其他事项仍要审批');
    await guideFill(tester, 'guide_1_review_context', '周三例会后的一对一沟通');
    await guideFill(tester, 'guide_1_review_learning', '部分边界可以谈，长期能否持续还需要观察');
    await guideTap(tester, find.byKey(const ValueKey('guide_review')));
    expect(repo.records.values.single.reviews, hasLength(1));
    expect(repo.records.values.single.reviews.single.outcome, 'partial');
    expect(find.text('这次，带走一条认识。'), findsOneWidget);
    expect(purposes, ['self_os.desires', 'self_os.guide', 'self_os.guide']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('纠正理解后重新追问，并保留原话，不替用户采纳解释', (tester) async {
    final repo = MemoryRepository();
    final c = SelfOsCase(problem: '想换工作，又怕后悔。');
    await tester.pumpWidget(guideApp(c, repo, scenarioAi()));
    await tester.pumpAndSettle();
    await guideTap(tester, find.text('理解有偏差，我来修正'));
    await guideFill(tester, 'guide_answer', '不是能力不足，是审批范围不清楚。');
    await guideTap(tester, find.byKey(const ValueKey('guide_send')));
    final saved = repo.records[c.id]!;
    expect(
        saved.guide.turns
            .where((t) => t['kind'] == 'correction')
            .single['text'],
        '不是能力不足，是审批范围不清楚。');
    expect(saved.guide.frame!['basis'][0]['quote'], '不是能力不足，是审批范围不清楚。');
    expect(saved.guide.confirmed, isFalse);
    expect(saved.commitment, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失败不前进也不丢输入，恢复后只发送一次', (tester) async {
    final repo = MemoryRepository();
    final c = SelfOsCase(problem: '想换工作，又怕后悔。');
    await tester.pumpWidget(guideApp(c, repo, scenarioAi()));
    await tester.pumpAndSettle();
    repo.fail = true;
    await guideFill(tester, 'guide_answer', '想保留工作内容，减少审批。');
    await guideTap(tester, find.byKey(const ValueKey('guide_send')));
    expect(repo.records[c.id]!.guide.turns.where((t) => t['role'] == 'user'),
        isEmpty);
    expect(find.textContaining('保存失败'), findsOneWidget);
    final input =
        tester.widget<TextField>(find.byKey(const ValueKey('guide_answer')));
    expect(input.controller!.text, '想保留工作内容，减少审批。');
    repo.fail = false;
    await guideTap(tester, find.byKey(const ValueKey('guide_send')));
    expect(repo.records[c.id]!.guide.turns.where((t) => t['role'] == 'user'),
        hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('停止等待后迟到结果不会覆盖草稿，AI故障下输入仍能自动保存', (tester) async {
    final pending = Completer<String>();
    final c = SelfOsCase(problem: '想换工作')
      ..desires.add(SelfOsDesire(title: '自主'));
    final repo = MemoryRepository();
    final ai = SelfOsAiService(
        generate: (
                {required prompt,
                required purpose,
                required systemPrompt,
                required maxTokens}) =>
            pending.future);
    await tester.pumpWidget(guideApp(c, repo, ai));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('停止等待'));
    await tester.pumpAndSettle();
    await guideFill(tester, 'guide_answer', '尚未发送但不能丢失');
    await tester.pump(const Duration(seconds: 1));
    pending.complete(jsonEncode(guideResponse('problem', c.problem)));
    await tester.pumpAndSettle();
    expect(repo.records[c.id]!.guide.frame, isNull);
    expect(repo.records[c.id]!.guide.compose, '尚未发送但不能丢失');
    expect(tester.takeException(), isNull);
  });

  testWidgets('重新打开继续已确认的计划，窄屏大字体无需再请求 AI', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = experimentGuide(), repo = MemoryRepository();
    await repo.saveCase(c);
    await tester.pumpWidget(guideApp(c, repo, offlineAi(), scale: 1.6));
    await tester.pumpAndSettle();
    expect(find.text('先试一小步'), findsOneWidget);
    await guideReveal(tester, find.byKey(const ValueKey('guide_commit')));
    expect(tester.takeException(), isNull);
    expect(repo.records[c.id]!.guide.draft['trigger'], '明天下午例会后，找主管空闲时');
    expect(find.textContaining('AI 暂时不可用'), findsNothing);
  });
}
