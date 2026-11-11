import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'ai_contract_test.dart' show validResponse;
import 'fixtures.dart';

class _Host extends NoopPrpHost {
  int aiCalls = 0, exits = 0;
  String? response;
  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async {
    aiCalls++;
    return response;
  }

  @override
  Future<void> safetyExit({bool crisis = true}) async {
    exits++;
  }
}

void main() {
  late TalFixture f;
  late _Host host;
  late TalEnvironment env;
  setUp(() async {
    f = TalFixture();
    await f.open();
    host = _Host();
    env = TalEnvironment(ledger: f.ledger, host: host, aiEnabled: () => true);
  });
  tearDown(() async => f.db.close());

  Future<void> panel(WidgetTester tester,
      {Future<void> Function(TalRecord)? onSaved, String? eventId}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TalReflectionPanel(
                    environment: env, onSaved: onSaved, eventId: eventId)))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> input(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  Future<void> step(WidgetTester tester, int i) =>
      tap(tester, find.byKey(ValueKey('tal_step_$i')));
  Future<void> more(WidgetTester tester, String text) async {
    await tap(tester, find.text('练习方式'));
    await tap(tester, find.text(text));
  }

  testWidgets(
      'default starts with facts only; all five steps can be skipped to L0',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byKey(const ValueKey('tal_felt_then')), findsNothing);
    expect(find.byKey(const ValueKey('tal_action')), findsNothing);
    for (var i = 0; i < 4; i++) {
      await tap(tester, find.byKey(const ValueKey('tal_flow_skip')));
    }
    await tap(tester, find.byKey(const ValueKey('tal_save_flow')));
    expect(saved!.level, 'L0 记录');
    expect(saved!.choice, TalChoice.undecided);
    expect(saved!.trials, isEmpty);
    expect(saved!.reminderConsent, isFalse);
    expect(host.aiCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'job search: facts -> experience -> unknown -> one next action -> real feedback',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: TalReflectionPage(environment: env)));
    await tester.pumpAndSettle();
    await input(tester, 'tal_plan', '今天找工作');
    await input(tester, 'tal_observed', '今天没去找工作');
    await tap(tester, find.byKey(const ValueKey('tal_flow_next')));
    expect(find.byKey(const ValueKey('tal_plan')), findsNothing);
    await input(tester, 'tal_did', '打开招聘页后就关掉了，原因不清楚');
    await tap(tester, find.byKey(const ValueKey('tal_flow_next')));
    await tap(tester, find.text('还不清楚'));
    await tap(tester, find.byKey(const ValueKey('tal_flow_next')));
    await tap(tester, find.text('调整'));
    await input(tester, 'tal_action', '收藏 1 个符合要求的岗位');
    await input(tester, 'tal_trigger', '明天晚饭后打开招聘页时');
    await input(tester, 'tal_check', '查看收藏列表和岗位要求');
    await tap(tester, find.byKey(const ValueKey('tal_flow_next')));
    expect(find.textContaining('收藏 1 个符合要求的岗位'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_flow')));
    expect(find.text('计划已保存，等待现实验证'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tal_feedback_observation')), findsNothing);
    expect(find.byKey(const ValueKey('tal_lesson_revision')), findsNothing);
    await tap(tester, find.byKey(const ValueKey('tal_open_feedback')));
    expect(find.text('1. 这个动作做了吗？'), findsOneWidget);
    expect(find.text('2. 结果如何？'), findsOneWidget);
    expect(find.byKey(const ValueKey('tal_plan')), findsNothing);
    await tap(tester, find.text('做了'));
    await tap(tester, find.text('这次有帮助'));
    await tap(tester, find.byKey(const ValueKey('tal_save_feedback')));
    final records = await f.records();
    await tester.pumpAndSettle();
    expect(find.textContaining('最近一次反馈：行动做了；这次有帮助'), findsOneWidget);
    expect(records, hasLength(1));
    expect(records.single.plan, '今天找工作');
    expect(records.single.lesson, '还不清楚');
    expect(records.single.currentTrial!.evidence.single['action_done'], isTrue);
    expect(records.single.level, 'L3 执行');
    expect(records.single.validatedByUser, isFalse);
    expect(host.aiCalls, 0);
  });

  testWidgets(
      'can start from an action without filling any emotional questions',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await tap(tester, find.text('我想直接考虑下一次'));
    await tap(tester, find.text('继续'));
    await input(tester, 'tal_action', '读一页');
    await input(tester, 'tal_trigger', '晚饭后');
    await input(tester, 'tal_check', '页码');
    await step(tester, 4);
    await tap(tester, find.byKey(const ValueKey('tal_save_flow')));
    expect(saved!.currentTrial!.action, '读一页');
    expect(saved!.reflection['felt_then'], isEmpty);
    expect(saved!.plan, isEmpty);
  });

  testWidgets(
      'partial action survives pause, reopening, and deliberate clearing',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await step(tester, 3);
    await tap(tester, find.text('调整'));
    await input(tester, 'tal_action', '先看看岗位要求');
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.trials, isEmpty);
    expect(saved!.choice, TalChoice.pause);
    final id = saved!.eventId;
    await tester.pumpWidget(const SizedBox());
    await panel(tester, eventId: id, onSaved: (r) async {
      saved = r;
    });
    await step(tester, 3);
    await tap(tester, find.text('调整'));
    expect(find.text('先看看岗位要求'), findsOneWidget);
    await input(tester, 'tal_action', '');
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['draft_action'], isEmpty);
    expect(await f.records(), hasLength(1));
  });

  testWidgets('pause and exit stop an existing action reminder',
      (tester) async {
    final record = await f.planned();
    await panel(tester, eventId: record.eventId);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    final paused = (await f.ledger.get(record.eventId))!;
    expect(paused.choice, TalChoice.pause);
    expect(paused.reminderConsent, isFalse);
    expect(paused.trials, hasLength(1));
    await step(tester, 3);
    await tap(tester, find.text('重新评估 / 退出'));
    await step(tester, 4);
    await tap(tester, find.byKey(const ValueKey('tal_save_flow')));
    expect((await f.ledger.get(record.eventId))!.state, TalState.goalExited);
  });

  testWidgets(
      'standard writing preserves facts and current feelings across mode changes',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await input(tester, 'tal_observed', '计划落空');
    await more(tester, '标准书写 · 10–15 分钟');
    expect(find.byKey(const ValueKey('tal_felt_now')), findsOneWidget);
    await input(tester, 'tal_felt_now', '现在想先休息');
    await more(tester, '简短记录 · 1–3 分钟');
    await more(tester, '标准书写 · 10–15 分钟');
    expect(find.text('现在想先休息'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.observed, '计划落空');
    expect(saved!.reflection['felt_now'], '现在想先休息');
    expect(saved!.trials, isEmpty);
  });

  testWidgets(
      'original PRP permits perspective first and freely returning to permission',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await more(tester, '原著 PRP 三步 · 可自由往返');
    await tap(tester, find.text('拉远视野'));
    await input(tester, 'practice_perspective', '一年后再看，仍有其他选择');
    await tap(tester, find.text('允许'));
    await tap(tester, find.text('拉远视野'));
    expect(find.text('一年后再看，仍有其他选择'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_use_practice')));
    expect(find.text('一年后再看，仍有其他选择'), findsNothing);
    expect(find.textContaining('拉远视野：一年后'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['perspective'], contains('其他选择'));
    expect(saved!.reflection['permission'], isEmpty);
    expect(saved!.trials, isEmpty);
    expect(await f.records(), hasLength(1));
  });

  testWidgets(
      'real case C18 leads to its specific exercise and returns to the same event',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await input(tester, 'tal_observed', '写作计划被接送孩子打断');
    await more(tester, '塔尔真实案例');
    final story = loadCatalog().storiesFor(null).first;
    expect(story['id'], 'C18');
    expect(find.text('明确做过什么：${story['reported_action']}'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_case_practice_C18_prp')));
    await tap(tester, find.text('重构'));
    await input(tester, 'practice_reconstruction', '减少今天的安排，留出陪孩子的时间');
    await tap(tester, find.byKey(const ValueKey('tal_use_practice')));
    expect(find.text('这次没有按计划发生什么？'), findsOneWidget);
    expect(find.textContaining('减少今天的安排'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.observed, '写作计划被接送孩子打断');
    expect(saved!.reflection['source_case'], 'C18');
    expect(saved!.reflection['reconstruction'], contains('陪孩子'));
    expect(saved!.trials, isEmpty);
    expect(await f.records(), hasLength(1));
    expect(host.aiCalls, 0);
  });

  testWidgets(
      'choosing Unbundling opens retained/reduced practice rather than just a method label',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await input(tester, 'tal_observed', '担心失去责任心，所以反复检查到深夜');
    await step(tester, 2);
    await tap(tester, find.text('需要帮助时，试一个练习'));
    expect(find.text('分开想保留和想减少的部分'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, '做这个练习').first);
    await input(tester, 'practice_keep_value', '责任心');
    await input(tester, 'practice_reduce_behavior', '反复检查到深夜');
    await tap(tester, find.byKey(const ValueKey('tal_use_practice')));
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['keep_value'], '责任心');
    expect(saved!.reflection['reduce_behavior'], contains('深夜'));
    expect(saved!.trials, isEmpty);
  });

  testWidgets(
      'literal catastrophic words show their basis without diagnosing or calling AI',
      (tester) async {
    await panel(tester);
    await input(tester, 'tal_observed', '今天没做，说明我一辈子没希望');
    await step(tester, 2);
    await tap(tester, find.text('需要帮助时，试一个练习'));
    expect(find.text('检查有没有遗漏事实'), findsOneWidget);
    expect(find.textContaining('原话：“一辈子没希望”'), findsOneWidget);
    expect(host.aiCalls, 0);
  });

  testWidgets('AI preview denial sends nothing and local steps remain usable',
      (tester) async {
    await panel(tester);
    await input(tester, 'tal_observed', '今天没去找工作');
    await more(tester, '可选 AI 整理');
    expect(find.text('本次发送 AI 的内容'), findsOneWidget);
    expect(find.textContaining('今天没去找工作'), findsWidgets);
    await tap(tester, find.text('仅用本地'));
    expect(host.aiCalls, 0);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(await f.records(), hasLength(1));
  });

  testWidgets(
      'AI adoption is explicit, editable and does not decide a goal or execute a plan',
      (tester) async {
    TalRecord? saved;
    final response = validResponse();
    response['proposed_trial'] = {
      'action': '收藏一个岗位',
      'trigger_or_time': '晚饭后',
      'completion_evidence': '收藏列表',
      'optional': true
    };
    host.response = jsonEncode(response);
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await input(tester, 'tal_observed', '今天没去找工作');
    await more(tester, '可选 AI 整理');
    await tap(tester, find.text('同意本次发送'));
    expect(host.aiCalls, 1);
    expect(find.text('AI 候选 · 尚待你核对'), findsOneWidget);
    await tap(tester, find.text('采用候选，放进可编辑草稿'));
    expect(find.text('这个目标接下来怎么处理，由你决定。'), findsOneWidget);
    expect(find.byKey(const ValueKey('tal_action')), findsNothing);
    await tap(tester, find.text('调整'));
    expect(find.text('收藏一个岗位'), findsOneWidget);
    await input(tester, 'tal_action', '先看一个岗位的具体要求');
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['draft_action'], '先看一个岗位的具体要求');
    expect(saved!.trials, isEmpty);
  });

  testWidgets(
      'not done follow-up stays unknown and does not ask for another reflection',
      (tester) async {
    final record = await f.planned();
    await tester.pumpWidget(MaterialApp(
        home: TalRecordPage(eventId: record.eventId, environment: env)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tal_open_feedback')));
    await tap(tester, find.text('没有做'));
    expect(find.text('这次有帮助'), findsNothing);
    expect(find.byKey(const ValueKey('tal_lesson_revision')), findsNothing);
    await tap(tester, find.byKey(const ValueKey('tal_save_feedback')));
    final result = (await f.ledger.get(record.eventId))!;
    expect(result.currentTrial!.evidence.single['action_done'], isFalse);
    expect(result.currentTrial!.evidence.single['outcome'], 'unclear');
    expect(result.level, 'L2 计划');
  });

  testWidgets(
      'crisis input immediately ends reflection and creates no record or AI call',
      (tester) async {
    await panel(tester);
    await input(tester, 'tal_observed', '我现在想伤害自己');
    expect(find.text('先照顾你的安全'), findsOneWidget);
    expect(find.byKey(const ValueKey('tal_save_draft')), findsNothing);
    expect(host.exits, 1);
    expect(host.aiCalls, 0);
    expect(await f.records(), isEmpty);
  });

  testWidgets('crisis during a case exercise blocks returning a draft',
      (tester) async {
    await panel(tester);
    await more(tester, '原著 PRP 三步 · 可自由往返');
    await input(tester, 'practice_permission', '我现在想伤害自己');
    expect(find.text('先照顾你的安全'), findsOneWidget);
    expect(find.byKey(const ValueKey('tal_use_practice')), findsNothing);
    expect(host.exits, 1);
    expect(await f.records(), isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('先照顾你的安全'), findsOneWidget);
  });

  testWidgets('crisis in follow-up does not append feedback', (tester) async {
    final record = await f.planned();
    await tester.pumpWidget(MaterialApp(
        home: TalRecordPage(eventId: record.eventId, environment: env)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('tal_open_feedback')));
    await input(tester, 'tal_feedback_observation', '我现在想伤害自己');
    expect(find.text('先照顾你的安全'), findsWidgets);
    expect(find.byKey(const ValueKey('tal_save_feedback')), findsNothing);
    expect(
        (await f.ledger.get(record.eventId))!.currentTrial!.evidence, isEmpty);
    expect(host.exits, 1);
    Navigator.of(tester.element(find.byType(TalRecordPage))).pop();
    await tester.pumpAndSettle();
    expect(find.text('先照顾你的安全'), findsOneWidget);
    expect(find.byKey(const ValueKey('tal_open_feedback')), findsNothing);
  });
}
