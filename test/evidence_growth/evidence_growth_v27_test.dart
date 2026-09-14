import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_router.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_models.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_store.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_page.dart';
import 'package:quote_app/evidence_growth/evidence_growth_journey_api.dart';

void main() {
  late Database db;
  late EvidenceGrowthDao dao;
  late EvidenceGrowthJourneyStore store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = EvidenceGrowthDao(database: () async => db);
    await dao.ensureTables();
    store = dao.journeys;
  });
  tearDown(() => db.close());
  Future<GrowthJourney> goal([String text = '我想把作品发出去']) async {
    var j = await store.create(text);
    return store.change(j, 'contract', {
      'goal': j.title,
      'current': '作品准备好，尚未发送',
      'criterion': '收到一条具体反馈',
      'quality': '可撤回、不伤害他人',
      'belief': '我担心别人否定我'
    });
  }

  Future<RealityTrial> action(GrowthJourney j) async {
    final r = const EvidenceGrowthRouter()
        .route('作品已经准备，拖延没开始')
        .copyWith(goalState: j.title, currentState: '作品尚未发送', topGap: '开始实际发送');
    return dao.createTrial(r,
        prediction: '会收到一条修改建议',
        probability: .5,
        reviewAt: DateTime.now().add(const Duration(hours: 1)),
        riskConfirmed: true,
        operatorInputs: {
          'journey_id': j.id,
          'journey_version': '${j.version}',
          'scheduled_start_ms': '${DateTime.now().millisecondsSinceEpoch}',
          'duration_minutes': '5',
          'max_repeat': '3',
          'remind': 'true'
        });
  }

  Future<GrowthJourney> historicalCycle(GrowthJourney j,
      {String facts = '我发送了作品，收到一条具体反馈'}) async {
    j = await store.change(j, 'outcome', {'facts': facts});
    j = await store.change(j, 'readiness', {'value': 'READY_NOW'});
    j = await store.change(j, 'review', {'learning': '根据实际反馈调整下一步，不用一次结果定义自己'});
    return store.change(j, 'change', {
      'target': 'MODIFY',
      'reason': '采用这一条建议',
      'belief_after': '一次反馈帮助具体修改'
    });
  }

  test(
      'three full node cycles reach only the finite evidence gate; reopening preserves achievement',
      () async {
    var j = await goal();
    for (var i = 0; i < 3; i++) {
      var t = await dao.startTrial(await action(j));
      t = await dao.captureResult(t,
          didAction: true,
          actualOutcome: '收到一条针对排版的建议',
          unexpected: '',
          resultStatus: 'DONE');
      j = (await store.find(j.id))!;
      expect(j.node, 'OUTCOME');
      final review = TrialReviewResult(
          predictionOriginal: t.prediction,
          actualFacts: [t.actualOutcome],
          predictionError: '预测得到支持',
          failureClass: 'NO_FAILURE',
          learning: '真实反馈可以帮助改进',
          ruleUpdate: '保留小范围反馈',
          decision: 'ACT',
          nextChangeOneVariable: '再发送一次',
          knowledgeNodeIds: t.nodeIds);
      await expectLater(dao.saveReview(t, review), throwsStateError);
      j = await store.change(j, 'outcome', {'facts': t.actualOutcome});
      j = await store.change(j, 'readiness', {'value': 'READY_NOW'});
      t = await dao.saveReview(t, review);
      t = await dao.decide(t,
          decision: 'ACT', reason: '真实反馈帮助改进', nextAction: '保留反馈条件');
      j = (await store.find(j.id))!;
      expect(j.node, 'GOAL_GATE');
      expect(j.status, 'ACTIVE');
      expect((await dao.byId(t.id))!.prediction, '会收到一条修改建议');
      if (i < 2) j = await store.change(j, 'gate', {'choice': 'CONTINUE'});
    }
    await expectLater(
        store.change(j, 'gate', {'choice': 'ACHIEVED'}), throwsStateError);
    j = await store.change(j, 'criterion-evidence',
        {'facts': '实际收到三次针对作品的具体建议', 'met': true, 'quality_met': true});
    j = await store.change(j, 'gate', {'choice': 'ACHIEVED'});
    final id = j.data['dossier_id'];
    final immutable =
        (await store.history(j.id)).firstWhere((r) => r['id'] == id);
    j = await store.change(j, 'reopen', {'reason': '换了新项目，需要重新确认现实状态'});
    expect(j.cycle, 4);
    expect(j.data['criteria_evidence'], isEmpty);
    expect((await store.history(j.id)).firstWhere((r) => r['id'] == id),
        immutable);
    final nodes = (await store.history(j.id))
        .where((r) => r['kind'] == 'NODE_RUN')
        .toList();
    for (var cycle = 1; cycle <= 3; cycle++)
      expect(
          nodes.where((r) => r['cycle'] == cycle).map((r) => r['node']).toSet(),
          containsAll([
            'BELIEF',
            'GOAL',
            'ACTION',
            'OUTCOME',
            'REVIEW',
            'CHANGE',
            'BELIEF_CHECKPOINT'
          ]));
    expect(nodes.every((r) => growthRows(r['knowledge_evidence']).isNotEmpty),
        isTrue);
    await expectLater(
        db.update('evidence_growth_journal', {'kind': 'changed'},
            where: 'id=?', whereArgs: [id]),
        throwsA(isA<DatabaseException>()));
  });
  test(
      'six entry fragments remain user data; retrospective outcome never creates a prediction',
      () async {
    final profile = GrowthProblemProfile.resolve(
        '我相信会被评价；我想发作品；已经发出；结果被拒绝；我意识到没问清需求；我决定调整');
    expect(
        profile.fragments.map((f) => f['node']).toSet(),
        containsAll(
            ['BELIEF', 'GOAL', 'ACTION', 'OUTCOME', 'REVIEW', 'CHANGE']));
    var j = await goal('我屡次求职失败，重新安排计划直到找到工作');
    expect(j.profile.lifecycle, 'FINITE');
    j = await historicalCycle(j);
    expect(j.node, 'GOAL_GATE');
    expect(await db.query('evidence_growth_predictions'), isEmpty);
    final outcome =
        (await store.history(j.id)).firstWhere((r) => r['node'] == 'OUTCOME');
    expect(
        growthMap(outcome['input'])['prediction'], 'NOT_RECORDED_BEFORE_EVENT');
  });
  test(
      'exploration samples do not promote without a completed cycle and user choice',
      () async {
    var j = await goal('我不知道自己想要什么');
    expect(j.profile.mode, 'EXPLORE');
    expect(j.profile.lifecycle, 'EXPLORATORY');
    j = await store.change(j, 'candidate',
        {'statement': '尝试软件测试方向', 'evidence': '做过一次短任务，愿意进一步了解'});
    final id = growthRows(j.data['candidates']).single['id'];
    await expectLater(
        store.change(j, 'candidate-disposition',
            {'id': id, 'value': 'PROMOTE', 'confirmed': true}),
        throwsStateError);
    j = await historicalCycle(j);
    expect(j.node, 'DISCOVERY_GATE');
    await expectLater(
        store.change(j, 'gate', {'choice': 'ACHIEVED'}), throwsStateError);
    await expectLater(
        store
            .change(j, 'candidate-disposition', {'id': id, 'value': 'PROMOTE'}),
        throwsStateError);
    j = await store.change(j, 'candidate-disposition',
        {'id': id, 'value': 'PROMOTE', 'confirmed': true});
    final target =
        growthRows(j.data['candidates']).single['promoted_journey_id'];
    expect(target, isNotNull);
    j = await store.change(j, 'candidate-disposition',
        {'id': id, 'value': 'PROMOTE', 'confirmed': true});
    expect((await store.list()).length, 2);
    expect((await store.find(target))!.confirmed, isFalse);
    j = await store.change(j, 'gate', {'choice': 'PAUSE'});
    expect(j.status, 'PAUSED');
  });
  test(
      'continuous/recurring maintain, persist and recover without erasing stable history',
      () async {
    var j = await goal('我想保持每周运动');
    expect(j.profile.lifecycle, 'RECURRING');
    j = await historicalCycle(j);
    j = await store.change(j, 'maintenance-contract', {
      'acceptable_band': '每周有适合自己的运动',
      'ritual': '固定轻量运动窗口',
      'check_days': 7,
      'drift_signals': '连续两次中断',
      'recovery_rule': '缩小强度重新恢复'
    });
    await expectLater(
        store.change(j, 'gate', {'choice': 'ACHIEVED'}), throwsStateError);
    j = await store.change(
        j, 'maintenance-gate', {'facts': '过去三个月都在可接受区间', 'in_band': true});
    final dossier = j.data['dossier_id'];
    expect(j.status, 'MAINTAINING');
    final fresh = EvidenceGrowthDao(database: () async => db);
    await fresh.ensureTables();
    expect((await fresh.journeys.find(j.id))!.status, 'MAINTAINING');
    expect(
        await db.query('evidence_growth_reminders',
            where: "kind='journey_maintenance' AND state='pending'"),
        hasLength(1));
    j = await store.change(
        j, 'maintenance-gate', {'facts': '换班后连续中断两次', 'in_band': false});
    expect(j.status, 'RECOVERY_CYCLE');
    expect(j.cycle, 2);
    expect((await store.history(j.id)).any((r) => r['id'] == dossier), isTrue);
  });
  test(
      'portfolio conserves budgets, attention and protected recovery, including actual task times',
      () async {
    var a = await goal(), b = await goal('我想学习 Java');
    a = await store.change(a, 'allocation',
        {'minutes': 80, 'money': 0, 'energy': 3, 'risk': 0, 'priority': 1});
    b = await store.change(b, 'allocation',
        {'minutes': 80, 'money': 0, 'energy': 3, 'risk': 0, 'priority': 1});
    expect(growthStrings((await store.arbitration())['conflicts']),
        contains('时间超过组合预算'));
    await expectLater(action(a), throwsStateError);
    b = await store.change(b, 'status', {'value': 'PARKED'});
    expect(growthStrings((await store.arbitration())['conflicts']), isEmpty);
    final p = await store.portfolio();
    final now = DateTime.now().millisecondsSinceEpoch;
    await store.savePortfolio(growthInt(p['version']), {
      'protected_recovery': [
        {'start': now - 1000, 'end': now + 3600000}
      ]
    });
    await expectLater(action(a), throwsStateError);
  });
  test('two active goals cannot book the same time slot', () async {
    final a = await goal(), b = await goal('我想整理资料');
    await action(a);
    await expectLater(action(b), throwsStateError);
  });
  test(
      'dependencies block prerequisites, distinguish external wait, and reject cycles',
      () async {
    final a = await goal(), b = await goal('我想先整理作品');
    await store.addDependency(a.id, b.id, 'REQUIRES');
    expect((await store.dependencies(a.id))['status'], 'BLOCKED');
    await expectLater(
        store.addDependency(b.id, a.id, 'REQUIRES'), throwsStateError);
    await expectLater(action(a), throwsStateError);
    await store.addDependency(a.id, 'external:offer', 'REQUIRES');
    final p = await store.portfolio();
    await store.savePortfolio(growthInt(p['version']), {
      'external_conditions': {'external:offer': true}
    });
    expect(
        growthStrings((await store.dependencies(a.id))['blocked_by']), [b.id]);
  });
  test(
      'rejection object determines local effects; ambiguous and proposal rejection never terminate parent',
      () async {
    expect(GrowthProblemProfile.outcome('她拒绝了我')['route_effect'], 'NO_CLOSURE');
    expect(
        GrowthProblemProfile.outcome('她拒绝了求婚',
            object: 'PROPOSAL', explicit: true)['route_effect'],
        'STAGE_BLOCKED');
    var j = await goal();
    j = await store.change(j, 'route', {'title': '当前联系路线'});
    j = await store.change(j, 'outcome',
        {'facts': '对方明确拒绝继续关系', 'object': 'RELATIONSHIP', 'explicit': true});
    expect(growthRows(j.data['routes']).single['status'], 'CLOSED');
    expect(j.terminal, isFalse);
  });
  test(
      'deferred review survives restart with at most one opt-in reminder and no forced learning',
      () async {
    var j = await goal();
    j = await store.change(j, 'outcome', {'facts': '我收到拒绝，现在不想分析'});
    final at =
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
    j = await store
        .change(j, 'readiness', {'value': 'DEFERRED', 'remind_at_ms': at});
    await expectLater(
        store.change(j, 'review', {'learning': '硬生成积极意义'}), throwsStateError);
    j = await store
        .change(j, 'readiness', {'value': 'DEFERRED', 'remind_at_ms': at});
    expect((await store.find(j.id))!.data['readiness'], 'DEFERRED');
    expect(
        await db.query('evidence_growth_reminders',
            where: "kind='journey_review' AND state='pending'"),
        hasLength(1));
    j = await store.change(j, 'readiness', {'value': 'READY_NOW'});
    expect(
        await db.query('evidence_growth_reminders',
            where: "kind='journey_review' AND state='pending'"),
        isEmpty);
  });
  test(
      'shared-body metric and ongoing withdrawal override goal and action plan',
      () async {
    var j = await goal('今晚和女朋友做爱30分钟');
    expect(j.profile.scope, 'EPISODE');
    expect(j.profile.intimate, isTrue);
    expect(j.safeTitle, '私密目标');
    expect(
        () => GrowthProblemProfile.metric(j.profile, '30分钟', 'KPI',
            confirmed: true, selfControlled: true),
        throwsStateError);
    await expectLater(action(j), throwsStateError);
    j = await store.change(j, 'mutuality', {
      'value': 'MUTUAL_READY',
      'user_attested': true,
      'facts': '双方明确表示当下愿意'
    });
    final t = await action(j);
    j = (await store.find(j.id))!;
    j = await store.change(j, 'mutuality', {'value': 'WITHDRAWN'});
    await expectLater(dao.startTrial(t), throwsStateError);
    expect(EvidenceGrowthJourneyStore.allowsReminder(j), isFalse);
  });
  test(
      'shared participants cannot be impersonated; withdrawing keeps personal agency',
      () async {
    var j = await goal('我和妻子一起存钱');
    expect(j.profile.data['control_type'], 'SHARED_OWNED');
    await expectLater(
        store.change(j, 'participant', {
          'alias': '朋友',
          'role': 'CO_OWNER',
          'task_assignment_allowed': true
        }),
        throwsStateError);
    j = await store
        .change(j, 'participant', {'alias': '伴侣', 'role': 'CO_OWNER'});
    final p = growthRows(j.data['participants']).single;
    expect(p['participation_source'], 'USER_REPORTED');
    expect(p['task_assignment_allowed'], false);
    j = await store.change(j, 'participant-withdraw', {'id': p['id']});
    expect(j.status, 'PAUSED');
    expect(growthRows(j.data['participants']).single['status'], 'WITHDRAWN');
  });
  test(
      'plan revision binds tasks to immutable versions, separate from goal version',
      () async {
    var j = await goal();
    final version = j.contract['version'];
    await action(j);
    j = (await store.find(j.id))!;
    await expectLater(
        store.change(j, 'plan', {'reason': '失败一次'}), throwsStateError);
    // Retrospective path has no open task and permits evidence-backed revision only at gate.
    var other = await goal('我想写出一个提纲');
    other = await historicalCycle(other);
    other = await store.change(other, 'plan', {
      'operation': 'MODIFY',
      'field': 'strategy',
      'reason': '多次卡在开头',
      'evidence': '三次都没有产出',
      'change': '先写三个小标题',
      'expected_signal': '产出一个可讨论提纲'
    });
    expect(other.plan['version'], 2);
    expect(other.plan['strategy'], '先写三个小标题');
    expect(other.contract['version'], version);
  });
  test(
      'change attempt lapse retains baseline and previous observations; transferred assets need target evidence',
      () async {
    var j = await goal('我很懒，但正在尝试改变');
    expect(j.profile.data['self_judgment'], isNotNull);
    j = await store.change(j, 'change-attempt', {
      'observed_pattern': '到点没有开始',
      'context': '下班之后',
      'impact': '没有练习',
      'desired_pattern': '先做两分钟',
      'intervention': '放下手机',
      'baseline': '上周三次没有开始',
      'signal': '开始次数和恢复时间'
    });
    final id = growthRows(j.data['change_attempts']).single['id'];
    j = await store.change(j, 'change-observation',
        {'id': id, 'facts': '完成一次两分钟练习', 'state': 'CONSOLIDATING'});
    j = await store.change(j, 'change-observation',
        {'id': id, 'facts': '换班后又中断一次', 'state': 'LAPSE'});
    expect(
        growthRows(
            growthRows(j.data['change_attempts']).single['observations']),
        hasLength(2));
    final target = await goal('我想整理房间');
    await store.shareAsset(j, target.id, '先做两分钟', '一次练习中有效');
    expect((await store.history(target.id)).last['personal_evidence'], false);
    j = (await store.find(j.id))!;
    await store.shareAsset(j, target.id, '先做两分钟', '练习中有效',
        transferFacts: '用到整理房间，实际收好了桌面');
    expect((await store.history(target.id)).last['personal_evidence'], true);
  });
  test('stale versions, duplicate actions and API gate bypass fail atomically',
      () async {
    var j = await goal();
    final t = await action(j);
    await expectLater(action(j), throwsStateError);
    expect(await dao.recentTrials(), hasLength(1));
    j = (await store.find(j.id))!;
    await expectLater(
        EvidenceGrowthJourneyApi.dispatch(
            dao,
            'POST',
            Uri.parse('/v2.7/journeys/${j.id}/gate'),
            {'version': j.version, 'choice': 'ACHIEVED'}),
        throwsStateError);
    j = await store.change(j, 'status', {'value': 'PAUSED'});
    await expectLater(dao.startTrial(t), throwsStateError);
    expect((await dao.byId(t.id))!.status, 'READY');
  });
  test(
      'goal bundles restore exploration and immutable records, reject stale remote overwrite',
      () async {
    var j = await goal('我不知道自己想要什么');
    j = await store.change(
        j, 'candidate', {'statement': '试做一个小项目', 'evidence': '完成了一小时体验'});
    final bundle = await store.bundle(j.id);
    final otherDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    try {
      final other = EvidenceGrowthDao(database: () async => otherDb);
      await other.ensureTables();
      await other.journeys.importBundle(bundle, baseDigest: '');
      expect((await other.journeys.find(j.id))!.data, j.data);
      final digest =
          EvidenceGrowthDao.bundleDigest(await other.journeys.bundle(j.id));
      await expectLater(other.journeys.importBundle(bundle, baseDigest: ''),
          throwsStateError);
      final tampered = growthMap(jsonDecode(jsonEncode(bundle)));
      growthRows(tampered['records']);
      (tampered['records'] as List).first['kind'] = 'FORGED';
      await expectLater(
          other.journeys.importBundle(tampered, baseDigest: digest),
          throwsStateError);
    } finally {
      await otherDb.close();
    }
  });
  test(
      'pairwise orthogonal profile coverage and mandatory sensitive combinations preserve invariants',
      () {
    final dimensions = {
      'goal_mode': ['EXPLORE', 'SOLVE', 'ENRICH', 'MAINTAIN'],
      'scope': [
        'EPISODE',
        'SHORT_HORIZON',
        'LONG_HORIZON',
        'CONTINUOUS',
        'RECURRING'
      ],
      'control_type': ['SELF', 'MIXED', 'EXTERNAL_DEPENDENT', 'SHARED_OWNED'],
      'processing_state': ['READY', 'FACTS_ONLY', 'DEFERRED', 'RECOVERY_HOLD'],
      'risk_class': [
        'NORMAL',
        'SENSITIVE',
        'HIGH_RISK',
        'PROFESSIONAL_BOUNDARY'
      ]
    };
    final keys = dimensions.keys.toList();
    final covered = <String>{};
    var samples = 0;
    for (var i = 0; i < keys.length; i++)
      for (var k = i + 1; k < keys.length; k++)
        for (final a in dimensions[keys[i]]!)
          for (final b in dimensions[keys[k]]!) {
            final data = {
              ...GrowthProblemProfile.resolve('我想学习一项技能').data,
              keys[i]: a,
              keys[k]: b
            };
            data['lifecycle_type'] = data['goal_mode'] == 'EXPLORE'
                ? 'EXPLORATORY'
                : data['scope'] == 'CONTINUOUS'
                    ? 'CONTINUOUS'
                    : data['scope'] == 'RECURRING'
                        ? 'RECURRING'
                        : 'FINITE';
            final p = GrowthProblemProfile(data).checked();
            expect(p.data['gap'], isNot('ARCHITECTURE_GAP_REVIEW'));
            expect(p.data[keys[i]], a);
            expect(p.data[keys[k]], b);
            covered.add('${keys[i]}:$a|${keys[k]}:$b');
            samples++;
          }
    expect(samples, covered.length);
    expect(samples, greaterThan(150));
    final unfamiliar = GrowthProblemProfile({
      ...GrowthProblemProfile.resolve('新的故事').data,
      'control_type': 'UNREPRESENTABLE_RELATION'
    }).checked();
    expect(unfamiliar.data['gap'], 'ARCHITECTURE_GAP_REVIEW');
    expect(GrowthProblemProfile.resolve('求职专业策略').data['gap'],
        'DOMAIN_EVIDENCE_INSUFFICIENT');
    expect(GrowthProblemProfile.resolve('身体疼痛需要诊断').data['risk_class'],
        'PROFESSIONAL_BOUNDARY');
  });
  testWidgets(
      'home hides sensitive titles and binds a fresh input to an existing goal',
      (tester) async {
    await tester.runAsync(() async {
      final j = await goal('今晚亲密接触30分钟');
      GrowthJourney? opened;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: EvidenceGrowthJourneyHome(
                  dao: dao,
                  onOpen: (value) async {
                    opened = value;
                  }))));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text(j.title), findsNothing);
      expect(find.text('私密目标'), findsWidgets);
      await tester.enterText(
          find.byKey(const Key('journey-entry')), '这次已经结束，我想先记录事实');
      await tester.tap(find.text('从这件事继续'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('私密目标').last);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(opened!.id, j.id);
      expect(opened!.data['pending_entry'], '这次已经结束，我想先记录事实');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
