import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/failure_module/tal/tal_failure_change.dart';
import 'package:quote_app/prp_plugin/src/store.dart';
import 'fixtures.dart';

void main() {
  late TalFixture f;
  setUp(() async {
    f = TalFixture();
    await f.open();
  });
  tearDown(() async => f.db.close());

  test(
      'migration is additive, idempotent, concurrent-safe, and preserves legacy cards',
      () async {
    await f.db.execute('CREATE TABLE fp_learning_card (id INTEGER PRIMARY KEY, '
        'ts_ms INTEGER NOT NULL,title TEXT NOT NULL,body TEXT NOT NULL,tags_json TEXT NOT NULL DEFAULT \'[]\')');
    await f.db.insert('fp_learning_card',
        {'id': 7, 'ts_ms': 42, 'title': '旧卡', 'body': '旧原文'});
    await Future.wait([f.dao.ensureTables(), f.dao.ensureTables()]);
    await f.dao.ensureTables();
    final old = (await f.db.query('fp_learning_card')).single;
    expect(old['id'], 7);
    expect(old['body'], '旧原文');
    expect(old['tal_event_id'], isNull);
    final names = await f.db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    expect(names.where((r) => '${r['name']}'.startsWith('tal_')), isEmpty);
    await f.dao.updateLearningCard(id: 7, title: '旧卡修改', body: '仍可编辑');
    expect((await f.dao.listLearningCards()).single.body, '仍可编辑');
  });
  test(
      'T01 everything may be skipped; manual events do not imply confirmed failure',
      () async {
    var record = await f.ledger.captureManualEvent(eventId: 't01');
    record = await f.ledger.saveDraft(record.eventId,
        plan: '', observed: '', reflection: {}, choice: TalChoice.undecided);
    expect(record.state, TalState.eventRecorded);
    expect(record.level, 'L0 记录');
    expect(record.confirmed, isFalse);
    expect(record.trials, isEmpty);
    expect((await f.dao.listLearningCards()).single.talEventId, record.eventId);
  });
  test('T02 uncertainty is saved verbatim without manufacturing a cause',
      () async {
    await f.ledger
        .captureManualEvent(eventId: 't02', plan: '找工作', observed: '没去');
    final r = await f.ledger.saveDraft('t02',
        plan: '找工作',
        observed: '没去',
        reflection: {
          'felt_then': '困也抵触',
          'known_unknown': '记不清原因',
          'lessons': '还不清楚'
        },
        choice: TalChoice.pause);
    expect(r.reflection['known_unknown'], '记不清原因');
    expect(r.state, TalState.paused);
    expect(r.hasLesson, isFalse);
  });
  test('T04 explicit exit stops recall and creates no action obligation',
      () async {
    await f.planned();
    final r = await f.ledger.saveDraft('event:1',
        plan: '找工作',
        observed: '拒绝不适合岗位',
        reflection: {'lessons': '通勤不合适'},
        choice: TalChoice.exit,
        reminderConsent: true);
    expect(r.state, TalState.goalExited);
    expect(r.reminderConsent, isFalse);
    expect(
        await f.ledger.nextRelevantAction(
            subjectKey: r.subjectKey,
            reference: 'exit',
            dailyCap: 3,
            allowed: () => true),
        isNull);
  });
  test('T05/T06 only an explicit missed record creates an automatic event',
      () async {
    for (final status in ['pending', 'unknown', 'skipped', 'done']) {
      expect(
          await f.ledger.captureConfirmedMissed(
              eventId: status,
              subjectKey: 'x',
              plan: '',
              observed: '',
              status: status,
              userConfirmed: true,
              source: 'behavior'),
          isNull);
    }
    expect(
        await f.ledger.captureConfirmedMissed(
            eventId: 'no-consent',
            subjectKey: 'x',
            plan: '',
            observed: '',
            status: 'missed',
            userConfirmed: false,
            source: 'behavior'),
        isNull);
    expect(
        await f.ledger.captureConfirmedMissed(
            eventId: 'kindling',
            subjectKey: 'x',
            plan: '',
            observed: '',
            status: 'missed',
            userConfirmed: true,
            source: 'kindling'),
        isNull);
    expect(await f.dao.listLearningCards(), isEmpty);
  });
  test('T10 sadness permits a draft with no benefit, lesson or trial',
      () async {
    await f.ledger.captureManualEvent(eventId: 'sad');
    final r = await f.ledger.saveDraft('sad',
        plan: '',
        observed: '',
        reflection: {'felt_then': '很难过，不想马上复盘'},
        choice: TalChoice.pause);
    expect(r.trials, isEmpty);
    expect(r.lesson, isEmpty);
  });
  test(
      'T11/T17 opt-in, dedup, cooldown and three ignores stop repeated reminders',
      () async {
    var r = await f.planned();
    expect(
        (await f.ledger.nextRelevantAction(
            subjectKey: r.subjectKey,
            reference: 'first',
            dailyCap: 1,
            allowed: () => false)),
        isNull);
    expect(
        await f.ledger.nextRelevantAction(
            subjectKey: r.subjectKey,
            reference: 'first',
            dailyCap: 1,
            allowed: () => true),
        isNotNull);
    expect(
        await f.ledger.nextRelevantAction(
            subjectKey: r.subjectKey,
            reference: 'first',
            dailyCap: 1,
            allowed: () => true),
        isNull);
    for (var i = 0; i < 3; i++) {
      final ref = i == 0 ? 'first' : 'later:$i';
      if (i > 0) {
        f.now = f.now.add(const Duration(hours: 25));
        expect(
            await f.ledger.nextRelevantAction(
                subjectKey: r.subjectKey,
                reference: ref,
                dailyCap: 1,
                allowed: () => true),
            isNotNull);
      }
      r = await f.ledger.ignoreReminder(r.eventId, ref);
      expect(
          await f.ledger.nextRelevantAction(
              subjectKey: r.subjectKey,
              reference: 'same-day:$i',
              dailyCap: 3,
              allowed: () => true),
          isNull);
    }
    expect(r.reminderConsent, isFalse);
    expect(r.trials.single.evidence, isEmpty);
  });
  test(
      'old PRP and the inline adapter share cap; simultaneous claims stay within cap',
      () async {
    final a = await f.planned(id: 'a');
    final b = await f.planned(id: 'b', subject: 'habit:preset:6');
    final results = await Future.wait([
      f.ledger.nextRelevantAction(
          subjectKey: a.subjectKey,
          reference: 'a',
          dailyCap: 1,
          allowed: () => true),
      f.ledger.nextRelevantAction(
          subjectKey: b.subjectKey,
          reference: 'b',
          dailyCap: 1,
          allowed: () => true),
    ]);
    expect(results.whereType<TalRecord>(), hasLength(1));
    f.now = f.now.add(const Duration(days: 1));
    await PrpSchema.createAll(f.db);
    await f.db.insert('prp_recall', {
      'lesson_id': 1,
      'ts': f.now.millisecondsSinceEpoch,
      'surface': 'behavior',
      'context': 'habit_reminder'
    });
    expect(
        await f.ledger.nextRelevantAction(
            subjectKey: a.subjectKey,
            reference: 'legacy-used',
            dailyCap: 1,
            allowed: () => true),
        isNull);
  });
  test('T16 execution with unknown effect is not labelled effective', () async {
    var r = await f.planned();
    r = await f.ledger.appendOutcome(r.eventId,
        trialId: r.currentTrial!.id,
        evidenceId: 'e:1',
        actionDone: true,
        outcome: 'unclear',
        observation: '已收藏，还不知道有没有用');
    expect(r.state, TalState.outcomeUnclear);
    expect(r.level, 'L3 执行');
    expect(r.validatedByUser, isFalse);
    r = await f.ledger.appendOutcome(r.eventId,
        trialId: r.currentTrial!.id,
        evidenceId: 'e:2',
        actionDone: false,
        outcome: 'not_helped',
        observation: '下次没做');
    expect(r.state, TalState.savedUnfinished);
    expect(r.trials.single.evidence.last['outcome'], 'unclear');
  });
  test(
      'T18 crisis text never reaches SQLite in capture, reflection, trial or feedback',
      () async {
    await expectLater(
        f.ledger.captureManualEvent(eventId: 'crisis', observed: '我想自杀'),
        throwsA(isA<TalCrisisException>()));
    final r = await f.planned();
    expect(
        () => f.ledger.saveDraft(r.eventId,
            plan: '',
            observed: '',
            reflection: {'thought': '我不想活'},
            choice: TalChoice.pause),
        throwsA(isA<TalCrisisException>()));
    expect(
        () => f.ledger.appendOutcome(r.eventId,
            trialId: r.currentTrial!.id,
            evidenceId: 'crisis-outcome',
            actionDone: false,
            outcome: 'unclear',
            observation: '想伤害自己'),
        throwsA(isA<TalCrisisException>()));
    final json = jsonEncode(await f.db.query('fp_learning_card'));
    expect(json, isNot(contains('自杀')));
    expect(json, isNot(contains('伤害自己')));
  });
  test(
      'T19 same event id from multiple hosts creates one card without overwriting content',
      () async {
    final results = await Future.wait([
      f.ledger.captureConfirmedMissed(
          eventId: 'shared:123',
          subjectKey: 'x',
          plan: '原始计划',
          observed: '明确没做',
          status: 'missed',
          userConfirmed: true,
          source: 'behavior'),
      f.ledger.captureConfirmedMissed(
          eventId: 'shared:123',
          subjectKey: 'x',
          plan: '另一宿主描述',
          observed: '确认未完成',
          status: 'missed',
          userConfirmed: true,
          source: 'enemy'),
    ]);
    expect(results[0]!.cardId, results[1]!.cardId);
    expect(await f.dao.listLearningCards(), hasLength(1));
    expect((await f.ledger.get('shared:123'))!.plan, results[0]!.plan);
  });
  test(
      'a two-answer self-report saves without making evidence mandatory or validating effectiveness',
      () async {
    final r = await f.planned();
    final result = await f.ledger.appendOutcome(r.eventId,
        trialId: r.currentTrial!.id,
        evidenceId: 'two-answers',
        actionDone: true,
        outcome: 'helped',
        observation: '');
    expect(result.currentTrial!.state, TalState.outcomeHelped);
    expect(result.level, 'L3 执行');
    expect(result.validatedByUser, isFalse);
    await expectLater(f.ledger.validateLesson(r.eventId), throwsStateError);
  });
  test('T20 revisions preserve prior statements and immutable evidence history',
      () async {
    var r = await f.planned();
    final trialId = r.currentTrial!.id;
    r = await f.ledger.appendOutcome(r.eventId,
        trialId: trialId,
        evidenceId: 'proof',
        actionDone: true,
        outcome: 'helped',
        observation: '找到一个符合通勤要求的岗位');
    r = await f.ledger.validateLesson(r.eventId);
    expect(r.level, startsWith('L4'));
    final old = r.lesson;
    r = await f.ledger.reviseLesson(r.eventId, '新信息：还需要先核实薪资');
    expect(r.revisions.last['previous_statement'], old);
    expect(r.revisions.last['evidence_ids'], ['proof']);
    expect(
        r.trials.single.evidence.single['observed_outcome'], contains('通勤要求'));
    expect(r.validatedByUser, isFalse);
    expect(r.revisions.length, 2);
    // Duplicate feedback does not change the observation or add a second proof.
    r = await f.ledger.appendOutcome(r.eventId,
        trialId: trialId,
        evidenceId: 'proof',
        actionDone: true,
        outcome: 'not_helped',
        observation: '重复回调');
    expect(r.trials.single.evidence, hasLength(1));
    expect(r.trials.single.evidence.single['outcome'], 'helped');
  });
  test(
      'one trial has one primary intervention and a new trial keeps the old result',
      () async {
    var r = await f.planned();
    final id = r.currentTrial!.id;
    await f.ledger.appendOutcome(r.eventId,
        trialId: id,
        evidenceId: 'x',
        actionDone: true,
        outcome: 'not_helped',
        observation: '仍然没有合适的岗位');
    r = await f.ledger.recordTrial(r.eventId,
        methodId: 'trial_error',
        action: '联系 1 位熟人',
        trigger: '周三下班后',
        check: '是否取得一条岗位信息');
    expect(r.trials, hasLength(2));
    expect(r.currentTrial!.previousId, id);
    expect(r.trials.first.state, TalState.outcomeNotHelped);
    expect(r.currentTrial!.methodId, 'trial_error');
  });
  test(
      'export includes evidence; revocation and deletion leave unrelated historical cards intact',
      () async {
    final legacy = await f.dao.addLearningCard(title: '旧卡', body: '不修改');
    var r = await f.planned();
    await f.ledger.saveDraft(r.eventId,
        plan: r.plan,
        observed: r.observed,
        reflection: r.reflection,
        choice: r.choice,
        aiConsent: true);
    r = await f.ledger.revokeAi(r.eventId);
    expect(jsonDecode(r.exportJson)['ai_consent'], isFalse);
    expect(jsonDecode(r.exportJson)['trials'], hasLength(1));
    await f.ledger.delete(r.eventId);
    expect(await f.ledger.get(r.eventId), isNull);
    expect((await f.dao.listLearningCards()).single.id, legacy);
  });
  test(
      'switch-off during transaction rolls back a draft and never silently loses earlier evidence',
      () async {
    final r = await f.planned();
    var calls = 0;
    final guarded = TalLessonLedger(dao: f.dao, canWrite: () => ++calls < 2);
    await expectLater(
        guarded.reviseLesson(r.eventId, '不应写入'), throwsStateError);
    expect((await f.ledger.get(r.eventId))!.lesson, r.lesson);
  });
  test(
      'L5 requires user confirmation and improvement across three days and two contexts',
      () async {
    var r = await f.planned();
    final trial = r.currentTrial!.id;
    for (var i = 0; i < 3; i++) {
      r = await f.ledger.appendOutcome(r.eventId,
          trialId: trial,
          evidenceId: 'independent:$i',
          actionDone: true,
          outcome: 'helped',
          observation: '收藏列表出现了符合要求的岗位',
          context: i == 0 ? '家中' : '图书馆');
      if (i == 0)
        await expectLater(
            f.ledger.validateLesson(r.eventId, consolidated: true),
            throwsStateError);
      f.now = f.now.add(const Duration(days: 1));
    }
    expect(r.level, startsWith('L3'));
    r = await f.ledger.validateLesson(r.eventId, consolidated: true);
    expect(r.level, 'L5 巩固');
  });
  test(
      'personal reminder needs individual opt-in, shares the cap, waits 24 hours and creates no quotation',
      () async {
    final r = await f.planned();
    expect(
        await f.ledger
            .personalReminderForHome(dailyCap: 3, allowed: () => true),
        isNull);
    await f.ledger
        .setPersonalReminder(r.eventId, '我先核实一个岗位的要求', approved: true);
    expect(
        await f.ledger
            .personalReminderForHome(dailyCap: 3, allowed: () => false),
        isNull);
    final shown = await f.ledger
        .personalReminderForHome(dailyCap: 3, allowed: () => true);
    expect(shown!.quoteConsent, isTrue);
    expect(shown.level, startsWith('L2'));
    expect(
        await f.ledger
            .personalReminderForHome(dailyCap: 3, allowed: () => true),
        isNull);
    final budget = await TalLessonLedger.reminderBudget(
        f.db,
        DateTime(f.now.year, f.now.month, f.now.day).millisecondsSinceEpoch,
        f.now.millisecondsSinceEpoch);
    expect(budget.used, 1);
    expect(budget.quotedRecently, isTrue);
    expect(
        await f.ledger.nextRelevantAction(
            subjectKey: r.subjectKey,
            reference: 'after-quote',
            dailyCap: 1,
            allowed: () => true),
        isNull);
    f.now = f.now.add(const Duration(hours: 25));
    expect(
        await f.ledger
            .personalReminderForHome(dailyCap: 3, allowed: () => true),
        isNotNull);
    await f.ledger.setPersonalReminder(r.eventId, '', approved: false);
    expect((await f.ledger.get(r.eventId))!.quoteConsent, isFalse);
    expect(
        (await f.db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='quotes'")),
        isEmpty);
  });
}
