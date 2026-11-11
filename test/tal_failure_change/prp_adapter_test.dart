import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/fp_dao.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/runtime.dart';
import 'package:quote_app/prp_plugin_host/tal_adapter.dart';
import 'package:quote_app/prp_plugin_host/prp_host_impl.dart';
import '../prp_plugin/fixtures.dart';
import '../prp_plugin/widget_test.dart' show settlePrp, prpIo;

void main() {
  late PrpFixture f;
  late TalLessonLedger ledger;
  final connections = <PrpFixture>[];
  setUp(() async {
    f = PrpFixture();
    await f.open();
    connections.add(f);
    await f.enable(cap: 1);
    ledger = TalLessonLedger(
        dao: FpDao(openDatabase: () async => f.db), clock: f.clock.call);
  });
  // SQLite isolate shutdown must run outside the widget test's fake clock.
  tearDown(() => PrpPlugin.instance = const NoopPrpPlugin());
  tearDownAll(() async {
    for (final fixture in connections) {
      await fixture.db.close();
    }
  });
  testWidgets(
      'real offer opens light workflow, retains active-session governance, saves only FP content',
      (tester) async {
    final offer = (await prpIo(tester, () => f.runtime.signal(f.signal())))!;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TalPrpSession(
                    runtime: f.runtime,
                    offer: offer,
                    legacy: const Text('legacy exercise'))))));
    await settlePrp(tester, until: find.text('这次没有按计划发生什么？'));
    expect(f.runtime.hasActiveSession, isTrue);
    expect(find.text('这次没有按计划发生什么？'), findsOneWidget);
    expect(find.text('legacy exercise'), findsNothing);
    final button = find.byKey(const ValueKey('tal_save_draft'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settlePrp(tester);
    expect(await prpIo(tester, () => ledger.get(offer.signal.reference!)),
        isNotNull);
    expect(await prpIo(tester, () => f.db.query('prp_lesson')), isEmpty);
    expect(
        (await prpIo(tester, () => f.db.query('prp_session')))
            .single['outcome'],
        'saved_in_learning_card');
    expect(f.runtime.hasActiveSession, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'existing failure-module 3P and AAR entries keep their legacy training flow',
      (tester) async {
    final offer = (await prpIo(
        tester,
        () => f.runtime.signal(
            f.signal(surface: PrpSurface.failureModule, kind: 'manual'))))!;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TalPrpSession(
                runtime: f.runtime,
                offer: offer,
                legacy: const Text('已有 3P / AAR 训练')))));
    await settlePrp(tester, until: find.text('已有 3P / AAR 训练'));
    expect(find.text('已有 3P / AAR 训练'), findsOneWidget);
    expect(find.byType(TalReflectionPanel), findsNothing);
    expect(
        await prpIo(tester, () => ledger.get(offer.signal.reference!)), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('the existing PRP allocator respects the FP budget and ignore cooldown',
      () async {
    final r = PrpRuntime(
        settings: f.settings.adapter,
        store: f.runtime.store,
        host: f.host,
        clock: f.clock.call,
        additionalRecallBudget: (db, day, now) async {
          final budget = await TalLessonLedger.reminderBudget(db, day, now);
          return (
            used: budget.used,
            ignoredRecently: budget.ignoredRecently,
            quotedRecently: budget.quotedRecently
          );
        });
    await r.initialize();
    await ledger.captureManualEvent(
        eventId: 'fp', subjectKey: 'habit:preset:5');
    await ledger.saveDraft('fp',
        plan: '阅读',
        observed: '没读',
        reflection: {},
        choice: TalChoice.continueGoal,
        reminderConsent: true);
    await ledger.recordTrial('fp',
        methodId: 'personal_trial',
        action: '读 1 页',
        trigger: '拿起书时',
        check: '记录页码');
    final exposure = await ledger.nextRelevantAction(
        subjectKey: 'habit:preset:5',
        reference: 'next',
        dailyCap: 1,
        allowed: () => true);
    expect(exposure, isNotNull);
    final offer = (await r.signal(f.signal(ref: 'legacy')))!;
    final lesson = f.lesson(subject: 'habit:preset:5');
    await r.saveDraft(offer, lesson, step: PrpStep.seal, pauseSeconds: 30);
    await r.seal(offer, lesson, pauseSeconds: 30, heldMilliseconds: 3000);
    expect(
        await r.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            reference: 'legacy-context')),
        isEmpty);
    // A later day still observes a recent explicit ignore.
    await ledger.ignoreReminder('fp', 'next');
    f.clock.advance(const Duration(hours: 13));
    expect(
        await r.recallFor(const PrpContext(
            surface: PrpSurface.behavior,
            subjectKey: 'habit:preset:5',
            reference: 'next-day')),
        isEmpty);
  });
  testWidgets(
      'manual lesson is recalled by the existing text matcher with real SQLite governance',
      (tester) async {
    await prpIo(tester, () async {
      await ledger.captureManualEvent(eventId: 'manual:matching', plan: '找工作');
      await ledger.saveDraft('manual:matching',
          plan: '找工作',
          observed: '没去',
          reflection: {'lessons': '先核实一个合适岗位'},
          choice: TalChoice.continueGoal,
          reminderConsent: true);
      await ledger.recordTrial('manual:matching',
          methodId: 'personal_trial',
          action: '收藏 1 个岗位',
          trigger: '找工作',
          check: '收藏记录');
    });
    final runtime = PrpRuntime(
        settings: f.settings.adapter,
        store: f.runtime.store,
        host: PrpHostImpl(openDatabase: () async => f.db, clock: f.clock.call),
        clock: f.clock.call);
    await prpIo(tester, runtime.initialize);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TalPrpRecall(
                runtime: runtime,
                contextValue: const PrpContext(
                    surface: PrpSurface.behavior,
                    subjectKey: 'habit:preset:5',
                    text: '找工作',
                    reference: 'related-action'),
                legacy: const Text('legacy reminder')))));
    await settlePrp(tester, until: find.text('这次计划：收藏 1 个岗位'));
    expect(find.text('这次计划：收藏 1 个岗位'), findsOneWidget);
    expect(find.text('legacy reminder'), findsNothing);
    expect(
        (await prpIo(tester, () => ledger.get('manual:matching')))!.reminders,
        hasLength(1));
    final feedback = find.text('记录行动与结果');
    await tester.ensureVisible(feedback);
    await tester.tap(feedback);
    await settlePrp(tester, until: find.text('1. 这个动作做了吗？'));
    expect(find.text('1. 这个动作做了吗？'), findsOneWidget);
    expect(find.text('2. 结果如何？'), findsOneWidget);
    expect(find.byType(TalRecordPage), findsNothing);
    expect(find.byType(TalReflectionPanel), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
