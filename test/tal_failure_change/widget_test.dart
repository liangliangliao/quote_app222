import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'fixtures.dart';

class _Host extends NoopPrpHost {
  int aiCalls = 0, exits = 0;
  @override
  Future<String?> callAi(String task, Map<String, dynamic> input) async {
    aiCalls++;
    return null;
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
      {Future<void> Function(TalRecord)? onSaved}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child:
                    TalReflectionPanel(environment: env, onSaved: onSaved)))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('T01 light path saves all-empty record without analysis or AI',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    expect(find.text('简短 1–3 分钟'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved, isNotNull);
    expect(saved!.trials, isEmpty);
    expect(saved!.level, 'L0 记录');
    expect(host.aiCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'PRP allows perspective first, returning to permission, and skipping all other stages',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await tap(tester, find.text('PRP 三步'));
    await tap(tester, find.text('拉远视野'));
    await tester.enterText(
        find.byKey(const ValueKey('tal_perspective')), '一年后再看，仍有其他选择');
    await tap(tester, find.text('允许事实与情绪'));
    await tap(tester, find.text('拉远视野'));
    expect(find.text('一年后再看，仍有其他选择'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['perspective'], contains('其他选择'));
    expect(saved!.reflection['permission'], isEmpty);
    expect(saved!.trials, isEmpty);
  });
  testWidgets(
      'T09 user-selected Unbundling records separate retained and reduced parts',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await tap(tester, find.text('选择方法（可拒绝，也可以不用）'));
    await tap(tester, find.text('怕改变后失去珍视的品质'));
    expect(find.text('Unbundling Exercise'), findsOneWidget);
    await tap(tester, find.text('本次试这一种'));
    await tester.ensureVisible(find.byKey(const ValueKey('tal_keep_value')));
    await tester.enterText(find.byKey(const ValueKey('tal_keep_value')), '责任心');
    await tester
        .ensureVisible(find.byKey(const ValueKey('tal_reduce_behavior')));
    await tester.enterText(
        find.byKey(const ValueKey('tal_reduce_behavior')), '反复检查到深夜');
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['keep_value'], '责任心');
    expect(saved!.reflection['reduce_behavior'], contains('深夜'));
    expect(saved!.trials, isEmpty);
  });
  testWidgets(
      'T12 AI requires per-request preview and denying it sends nothing',
      (tester) async {
    await panel(tester);
    await tester.enterText(
        find.byKey(const ValueKey('tal_observed')), '今天没去找工作');
    await tap(tester, find.text('可选：让已有 AI 帮我整理'));
    expect(find.text('本次发送 AI 的内容'), findsOneWidget);
    expect(find.textContaining('今天没去找工作'), findsWidgets);
    await tap(tester, find.text('仅用本地'));
    expect(host.aiCalls, 0);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect((await f.dao.listLearningCards()), hasLength(1));
  });
  testWidgets(
      'T15 the light form supports responsibility before any optional advice',
      (tester) async {
    await panel(tester);
    expect(find.textContaining('承担责任和适当补救'), findsOneWidget);
    expect(host.aiCalls, 0);
  });
  testWidgets('T18 crisis input immediately exits, never saves or calls AI',
      (tester) async {
    await panel(tester);
    await tester.enterText(
        find.byKey(const ValueKey('tal_observed')), '我现在想伤害自己');
    await tester.pumpAndSettle();
    expect(find.text('先照顾你的安全'), findsOneWidget);
    expect(find.byKey(const ValueKey('tal_save_draft')), findsNothing);
    expect(host.exits, 1);
    expect(host.aiCalls, 0);
    expect(await f.dao.listLearningCards(), isEmpty);
  });
  testWidgets(
      'T16 feedback records execution while keeping unknown effect unverified',
      (tester) async {
    final record = await f.planned();
    await tester.pumpWidget(MaterialApp(
        home: TalRecordPage(eventId: record.eventId, environment: env)));
    await tester.pumpAndSettle();
    await tap(tester, find.text('还不知道'));
    await tester.tap(find.text('做了').last);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('tal_feedback_observation')));
    await tester.enterText(
        find.byKey(const ValueKey('tal_feedback_observation')),
        '已收藏一个岗位，效果还不知道');
    await tap(tester, find.byKey(const ValueKey('tal_save_feedback')));
    final saved = (await f.ledger.get(record.eventId))!;
    expect(saved.state, TalState.outcomeUnclear);
    expect(saved.level, 'L3 执行');
    expect(saved.validatedByUser, isFalse);
    // A double-tap/retry does not turn one observed result into two trials.
    await tap(tester, find.byKey(const ValueKey('tal_save_feedback')));
    expect((await f.ledger.get(record.eventId))!.trials.single.evidence,
        hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'personal reminder is enabled per record without claiming improved behavior',
      (tester) async {
    final record = await f.planned();
    await tester.pumpWidget(MaterialApp(
        home: TalRecordPage(eventId: record.eventId, environment: env)));
    await tester.pumpAndSettle();
    final entry = find.text('可选：改写为自己的个人提醒');
    await tester.scrollUntilVisible(entry, 300,
        scrollable: find.byType(Scrollable).first);
    await tap(tester, entry);
    final input = find.byKey(const ValueKey('tal_personal_reminder'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '先核实一个岗位的要求');
    await tap(tester, find.text('我同意将这一句作为首页个人提醒'));
    final saved = (await f.ledger.get(record.eventId))!;
    expect(saved.quoteConsent, isTrue);
    expect(saved.level, startsWith('L2'));
    expect(saved.trials.single.evidence, isEmpty);
    await tester.pumpAndSettle();
    await tap(tester, find.text('撤销此条首页展示授权'));
    expect((await f.ledger.get(record.eventId))!.quoteConsent, isFalse);
  });
  testWidgets(
      'standard mode opens the full experience and keeps writing when switching length',
      (tester) async {
    TalRecord? saved;
    await panel(tester, onSaved: (r) async {
      saved = r;
    });
    await tap(tester, find.text('标准'));
    final nowFeeling = find.byKey(const ValueKey('tal_felt_now'));
    expect(nowFeeling, findsOneWidget);
    await tester.ensureVisible(nowFeeling);
    await tester.enterText(nowFeeling, '现在想先休息');
    await tap(tester, find.text('简短 1–3 分钟'));
    await tap(tester, find.text('标准'));
    expect(find.text('现在想先休息'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('tal_save_draft')));
    expect(saved!.reflection['felt_now'], '现在想先休息');
    expect(saved!.trials, isEmpty);
  });
  testWidgets(
      'T03 literal user text routes to 3Ms with the actual quoted basis',
      (tester) async {
    await panel(tester);
    await tester.enterText(
        find.byKey(const ValueKey('tal_observed')), '今天没做，说明我一辈子没希望');
    await tester.pumpAndSettle();
    await tap(tester, find.text('选择方法（可拒绝，也可以不用）'));
    expect(find.text('3Ms / Zoom Out'), findsOneWidget);
    expect(find.textContaining('原话：“一辈子没希望”'), findsOneWidget);
    expect(host.aiCalls, 0);
  });
}
