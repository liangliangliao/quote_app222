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
