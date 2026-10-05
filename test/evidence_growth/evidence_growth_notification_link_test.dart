import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_runtime.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_store.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_notification_link.dart';
import 'package:quote_app/evidence_growth/evidence_growth_notification_inbox.dart';
import 'package:quote_app/evidence_growth/evidence_growth_reminder_plan.dart';

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EvidenceGrowthDao(database: () async => db);
    await dao.ensureTables();
  });
  tearDown(() => db.close());
  Future<GrowthJourney> goal([String input = '准备作品，希望获得反馈']) async {
    var j = await dao.journeys.create(input);
    return dao.journeys.change(j, 'contract',
        {'goal': j.title, 'current': '已有一份草稿', 'criterion': '收到一条具体反馈'});
  }

  Future<RealityTrial> trial(GrowthJourney j) async =>
      dao.createTrial(EvidenceGrowthJourneyRuntime.compile(j),
          prediction: '收到一条具体反馈',
          probability: .5,
          reviewAt: DateTime.now().add(const Duration(hours: 2)),
          riskConfirmed: true,
          operatorInputs: {
            'journey_id': j.id,
            'journey_version': '${j.version}',
            'remind': 'true',
            'scheduled_start_ms':
                '${DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch}'
          });
  test(
      'seven kinds carry the intended actionable node, independently of knowledge module',
      () {
    final expected = {
      'trial_start': 'ACTION',
      'recovery_end': 'ACTION',
      'trial_review_due': 'OUTCOME',
      'missing_result': 'OUTCOME',
      'journey_review': 'REVIEW',
      'repeated_avoidance': 'CHANGE',
      'journey_maintenance': 'MAINTENANCE_GATE'
    };
    for (final e in expected.entries) {
      final link = GrowthNotificationLink.parse(jsonEncode(
          {'module': 'evidence_growth', 'type': e.key, 'trial_id': 't1'}))!;
      expect(link.targets.single.node, e.value);
    }
  });
  test('new grouped payload preserves distinct records, journey IDs and nodes',
      () {
    final link = GrowthNotificationLink.parse(jsonEncode({
      'module': 'evidence_growth',
      'tap_token': 'tap-1',
      'targets': [
        {
          'trial_id': 't1',
          'journey_id': 'j1',
          'node': 'ACTION',
          'title': '作品 · 开始'
        },
        {
          'trial_id': 't2',
          'journey_id': 'j2',
          'node': 'OUTCOME',
          'title': '练习 · 反馈'
        },
        {'trial_id': 't1', 'journey_id': 'j1', 'node': 'ACTION'}
      ]
    }))!;
    expect(link.targets, hasLength(2));
    expect(link.targets[1].trialId, 't2');
    expect(link.targets[1].journeyId, 'j2');
    expect(link.targets[1].node, 'OUTCOME');
    expect(link.tapToken, 'tap-1');
  });
  test(
      'legacy trial and journey links remain supported; unrelated or invalid data rejected',
      () {
    expect(
        GrowthNotificationLink.parse('evidence_growth:trial-1')!
            .targets
            .single
            .trialId,
        'trial-1');
    expect(
        GrowthNotificationLink.parse(jsonEncode({
          'module': 'evidence_growth',
          'trial_id': 'journey:j1',
          'type': 'journey_review'
        }))!
            .targets
            .single
            .journeyId,
        'j1');
    expect(GrowthNotificationLink.parse('evidence_growth_wrong:t1'), isNull);
    expect(GrowthNotificationLink.parse('{broken'), isNull);
    expect(GrowthNotificationLink.parse('{"module":"other","trial_id":"t1"}'),
        isNull);
  });
  test(
      'trial notification opens that exact trial at its requested node without changing state',
      () async {
    var j = await goal();
    final t = await trial(j);
    j = (await dao.journeys.find(j.id))!;
    final d = await GrowthNotificationDestination.resolve(
        dao,
        GrowthNotificationTarget(
            trialId: t.id, journeyId: j.id, node: 'OUTCOME'));
    expect(d.page, 'TRIAL');
    expect(d.trial!.id, t.id);
    expect(d.node, 'OUTCOME');
    expect((await dao.byId(t.id))!.status, 'READY');
    expect((await dao.journeys.find(j.id))!.version, j.version);
  });
  test(
      'result already captured goes to readiness choice, never forces AI review',
      () async {
    final j = await goal();
    var t = await trial(j);
    t = await dao.captureResult(t,
        didAction: false,
        actualOutcome: '未开始，先保留记录',
        unexpected: '',
        resultStatus: 'NOT_DONE');
    final d = await GrowthNotificationDestination.resolve(
        dao, GrowthNotificationTarget(trialId: t.id, node: 'OUTCOME'));
    expect(d.page, 'JOURNEY');
    expect(d.node, 'REVIEW');
    expect(d.journey!.data['readiness'], 'UNKNOWN');
    expect((await dao.byId(t.id))!.status, 'RESULT_CAPTURED');
  });
  test(
      'old cycle notification opens original archive rather than the new active trial',
      () async {
    var j = await goal();
    final t = await trial(j);
    j = (await dao.journeys.find(j.id))!;
    await EvidenceGrowthJourneyStore.put(
        db, j.copy({'trial_id': 'a-new-trial', 'cycle': j.cycle + 1}));
    final d = await GrowthNotificationDestination.resolve(
        dao,
        GrowthNotificationTarget(
            trialId: t.id, journeyId: j.id, node: 'OUTCOME'));
    expect(d.page, 'ARCHIVE');
    expect(d.trial!.id, t.id);
    expect(d.message, contains('原行动'));
  });
  test('deleted and mismatched records never open an unrelated goal', () async {
    final a = await goal(), b = await goal('整理桌面');
    final t = await trial(a);
    expect(
        (await GrowthNotificationDestination.resolve(
                dao, const GrowthNotificationTarget(trialId: 'deleted')))
            .page,
        'MISSING');
    expect(
        (await GrowthNotificationDestination.resolve(
                dao, GrowthNotificationTarget(trialId: t.id, journeyId: b.id)))
            .page,
        'MISSING');
    expect(
        (await GrowthNotificationDestination.resolve(
                dao, const GrowthNotificationTarget(journeyId: 'deleted')))
            .page,
        'MISSING');
  });
  test(
      'deferred review and maintaining checks retain exact journey and readiness',
      () async {
    var j = await goal();
    j = await dao.journeys.change(j, 'outcome', {'facts': '收到一个建议'});
    j = await dao.journeys.change(j, 'readiness', {'value': 'DEFERRED'});
    final d = await GrowthNotificationDestination.resolve(
        dao, GrowthNotificationTarget(journeyId: j.id, node: 'REVIEW'));
    expect(d.page, 'JOURNEY');
    expect(d.journey!.id, j.id);
    expect(d.journey!.data['readiness'], 'DEFERRED');
    await EvidenceGrowthJourneyStore.put(
        db, j.copy({'status': 'MAINTAINING', 'node': 'MAINTENANCE_GATE'}));
    final m = await GrowthNotificationDestination.resolve(dao,
        GrowthNotificationTarget(journeyId: j.id, node: 'MAINTENANCE_GATE'));
    expect(m.node, 'MAINTENANCE_GATE');
    expect(m.journey!.status, 'MAINTAINING');
  });
  test(
      'planned notifications identify module, node, action and original prediction',
      () async {
    final j = await goal();
    final t = await trial(j);
    final plans = EvidenceGrowthReminderPlan.build(
        t, DateTime.now().millisecondsSinceEpoch);
    expect(
        plans.every((p) => p.title.contains('证据成长') && p.title.contains('节点')),
        isTrue);
    expect(plans.firstWhere((p) => p.kind == 'trial_start').body,
        contains(t.actionInstruction));
    expect(plans.firstWhere((p) => p.kind == 'missing_result').body,
        contains(t.prediction));
  });
  testWidgets(
      'grouped notification lets user choose the exact target and shows each node',
      (tester) async {
    const a = GrowthNotificationTarget(
        trialId: 'first',
        node: 'ACTION',
        title: '证据成长 · 行动节点',
        summary: '作品：开始整理一段');
    const b = GrowthNotificationTarget(
        trialId: 'second',
        node: 'OUTCOME',
        title: '证据成长 · 结果节点',
        summary: '练习：补充现实反馈');
    GrowthNotificationTarget? selected;
    await tester.pumpWidget(MaterialApp(
        home: EvidenceGrowthNotificationInbox(
            targets: const [a, b],
            onOpen: (t) async {
              selected = t;
            })));
    expect(find.text(a.summary), findsOneWidget);
    expect(find.text(b.summary), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(b.key)));
    await tester.pumpAndSettle();
    expect(selected!.trialId, 'second');
    expect(selected!.node, 'OUTCOME');
    await tester.pumpWidget(const SizedBox());
  });
}
