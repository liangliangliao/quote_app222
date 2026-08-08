import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_dao.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database database;
  late XiangjiGoalMentorDao dao;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = XiangjiGoalMentorDao(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('claims at most once per day, retries failures and audits delivery',
      () async {
    final goal = await dao.createAndActivateGoal(_draft());
    await dao.saveReminderSettings(
      const XiangjiReminderSettings(
        enabled: true,
        timeOfDay: '09:00',
        quietStart: '22:00',
        quietEnd: '08:00',
        taskUid: 'test-task',
      ),
    );
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final expectedKey =
        'goal:${goal.id}:${now.year}-${two(now.month)}-${two(now.day)}';

    final first = await dao.claimScheduledReminder(now: now);
    expect(first, isNotNull);
    expect(first!.goalId, goal.id);
    expect(first.deliveryKey, expectedKey);
    expect(await dao.claimScheduledReminder(now: now), isNull);

    await dao.markScheduledReminderFailed(first.deliveryKey, 'plugin error');
    final retry = await dao.claimScheduledReminder(now: now);
    expect(retry, isNotNull);
    await dao.markScheduledReminderDelivered(retry!.deliveryKey);
    expect(await dao.claimScheduledReminder(now: now), isNull);

    final rows = await database.query('xiangji_reminder_deliveries');
    expect(rows, hasLength(1));
    expect(rows.single['status'], 'delivered');
    expect(rows.single['attempt_count'], 2);
    expect(rows.single['content_type'], 'action');

    final exported = jsonDecode(await dao.exportJson()) as Map<String, dynamic>;
    expect(exported['xiangji_reminder_deliveries'], hasLength(1));

    await dao.deleteAllData();
    final deliveryCount = await database.rawQuery(
      'SELECT COUNT(*) AS delivery_count FROM xiangji_reminder_deliveries',
    );
    expect(
      deliveryCount.single['delivery_count'],
      0,
    );
  });

  test('disabled reminders never create a delivery claim', () async {
    await dao.createAndActivateGoal(_draft());
    expect(await dao.claimScheduledReminder(), isNull);
    expect(await database.query('xiangji_reminder_deliveries'), isEmpty);
  });

  test('persists mentor selection history and 8-step progress', () async {
    final goal = await dao.createAndActivateGoal(_draft());
    expect(await dao.mentorSelectionHistory(goal.id), hasLength(1));

    const guidance = XiangjiGuidance(
      systemId: 'frankl',
      mentorName: '维克多·弗兰克尔',
      mechanismId: 'meaning_responsibility',
      mechanismLabel: '意义与责任',
      coreJudgment: '意义需要在具体责任中被回应。',
      selectionReason: '用户主动选择。',
      boundaryNote: '不替代危机支持。',
      knowledgeView: '通过责任与自我超越理解目标。',
      structureText: '价值—目标—责任—行动。',
      detailText: '区分意义与自我强迫。',
      actionDerivation: '回应一件具体责任。',
      confidence: 1,
      sources: <XiangjiSourceCitation>[],
    );
    final updated = await dao.changeMentor(
      goal: goal,
      guidance: guidance,
    );
    expect(updated.primaryThinkerId, 'frankl');
    final history = await dao.mentorSelectionHistory(goal.id);
    expect(history, hasLength(2));
    expect(history.first['previous_thinker_id'], 'yangming');

    await dao.saveMentorSettingProgress(
      goalId: goal.id,
      thinkerId: 'frankl',
      stepIndex: 2,
      answers: const <String, String>{
        '听见责任': '先照顾正在依赖我的人',
        '区分选择': '今天先完成一次沟通',
      },
      completed: false,
    );
    final progress = await dao.mentorSettingProgress(goal.id);
    expect(progress['thinker_id'], 'frankl');
    expect(progress['step_index'], 2);
    expect(progress['answers'], isA<Map>());

    final exported = jsonDecode(await dao.exportJson()) as Map<String, dynamic>;
    expect(exported['schema_version'], '1.4.0');
    expect(exported['knowledge_version'], '2.1.0');
    expect(exported['xiangji_mentor_selections'], hasLength(2));
    expect(exported['xiangji_mentor_setting_progress'], hasLength(1));

    await dao.recordAnalyticsEvent(
      'source_opened',
      goalId: goal.id,
      properties: const <String, Object?>{
        'source_id': 'book-1',
        'user_text': '这段原话不得进入事件表',
      },
    );
    final analytics = await dao.analyticsSnapshot();
    expect(analytics['goal_confirmed'], 1);
    expect(analytics['mentor_selected'], 2);
    expect(analytics['source_opened'], 1);
    final sourceEvent = (await database.query(
      'xiangji_analytics_events',
      where: 'event_name = ?',
      whereArgs: const <Object?>['source_opened'],
    ))
        .single;
    expect(sourceEvent['properties_json'], contains('book-1'));
    expect(sourceEvent['properties_json'], isNot(contains('这段原话')));
    expect(await dao.featureFlags(), hasLength(5));
    expect(await dao.featureEnabled('goal_first_v21'), isTrue);
    await dao.setFeatureFlagForOperations(
      'goal_first_v21',
      enabled: false,
      rolloutPercent: 0,
    );
    expect(await dao.featureEnabled('goal_first_v21'), isFalse);
    expect((await dao.localIdentity())['account_mode'], 'personal_local');
  });
}

XiangjiGoalDraft _draft() {
  const guidance = XiangjiGuidance(
    systemId: 'yangming',
    mentorName: '王阳明',
    mechanismId: 'knowledge_action_gap',
    mechanismLabel: '知行连接',
    coreJudgment: '先形成一个真实行动。',
    selectionReason: '这是可撤回的起点。',
    boundaryNote: '不替代专业支持。',
    knowledgeView: '知识需要进入行动。',
    structureText: '目标—行动—反馈。',
    detailText: '根据现实反馈调整。',
    actionDerivation: '写下第一句。',
    confidence: 0.8,
    sources: <XiangjiSourceCitation>[],
  );
  const step = XiangjiDailyStep(
    id: 0,
    goalId: 0,
    goalVersionId: 0,
    actionText: '写下第一句。',
    triggerContext: '打开文档时。',
    minimumDone: '一句。',
    evidenceRule: '保留文字。',
    controllabilityReason: '由自己控制。',
    smallerVariant: '写一个词。',
    sourceSystemId: 'yangming',
    status: 'ready',
    createdAtMs: 0,
  );
  return const XiangjiGoalDraft(
    originalText: '开始写作',
    whyText: '保留表达与成长',
    higherValues: <String>['自主', '成长'],
    successDefinition: '完成一个可控行动',
    scopeText: '未来七天',
    guidance: guidance,
    step: step,
  );
}
