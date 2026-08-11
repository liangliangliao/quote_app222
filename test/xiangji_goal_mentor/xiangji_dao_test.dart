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

  test('upgrades a PR146 database without deleting goal, history or action',
      () async {
    await _seedPr146Goal(database);

    final loadedLegacyGoal = await dao.activeGoal();
    expect(loadedLegacyGoal, isNotNull);
    final legacyGoal = loadedLegacyGoal!;
    expect(legacyGoal.primaryThinkerId, 'yangming');
    expect(legacyGoal.originalText, '保留旧目标原话');
    final legacyStep = await dao.currentStep(legacyGoal.id);
    expect(legacyStep?.actionText, '保留旧版当前行动');
    final automaticallySeeded = await dao.mentorKnowledgeMigrations(
      goalId: legacyGoal.id,
    );
    expect(automaticallySeeded, hasLength(1));
    expect(automaticallySeeded.single.requiresReselection, isTrue);

    final migration = await dao.ensureMentorKnowledgeCompatibility(
      goal: legacyGoal,
      validMentorIds: const <String>{
        'adler',
        'aristotle',
        'carver_scheier',
        'dewey',
        'epictetus',
        'frankl',
        'girard',
        'locke_latham',
        'nietzsche',
        'positive_psychology',
      },
      targetKnowledgeVersion: '2.1.0',
    );

    expect(migration, isNotNull);
    final pendingMigration = migration!;
    expect(pendingMigration.fromThinkerId, 'yangming');
    expect(pendingMigration.requiresReselection, isTrue);
    expect(await dao.mentorKnowledgeMigrations(goalId: legacyGoal.id), hasLength(1));
    expect((await dao.activeGoal())!.primaryThinkerId, 'yangming');
    expect(await dao.goalVersions(legacyGoal.id), hasLength(1));
    await dao.saveReminderSettings(
      const XiangjiReminderSettings(
        enabled: true,
        timeOfDay: '09:00',
        quietStart: '22:00',
        quietEnd: '08:00',
        taskUid: 'upgrade-test',
      ),
    );
    expect(await dao.claimScheduledReminder(), isNull);

    final updated = await dao.changeMentor(
      goal: legacyGoal,
      guidance: _v21Guidance(),
      reason: '知识库升级后由用户重新选择导师',
      reasonCode: 'knowledge_upgrade_reselected',
      kbVersion: '2.1.0',
    );
    await dao.replaceCurrentStep(
      updated,
      _v21Step(),
      trigger: 'mentor_changed_after_kb_upgrade',
    );

    final reloadedGoal = await dao.activeGoal();
    expect(reloadedGoal, isNotNull);
    final reloaded = reloadedGoal!;
    expect(reloaded.primaryThinkerId, 'adler');
    expect(reloaded.originalText, '保留旧目标原话');
    expect(await dao.goalVersions(reloaded.id), hasLength(1));
    expect((await dao.currentStep(reloaded.id))!.actionText, '完成一个勇气行动');
    final migrations = await dao.mentorKnowledgeMigrations(goalId: reloaded.id);
    expect(migrations, hasLength(1));
    expect(migrations.single.status, 'resolved');
    expect(migrations.single.resolvedThinkerId, 'adler');
    expect(
      await dao.ensureMentorKnowledgeCompatibility(
        goal: reloaded,
        validMentorIds: const <String>{'adler'},
        targetKnowledgeVersion: '2.1.0',
      ),
      isNull,
    );

    final stepRows = await database.query(
      'xiangji_daily_steps',
      where: 'goal_id = ?',
      whereArgs: <Object?>[reloaded.id],
      orderBy: 'id',
    );
    expect(stepRows, hasLength(2));
    expect(stepRows.first['status'], 'replaced');
    expect(stepRows.last['status'], 'ready');
    expect(await dao.claimScheduledReminder(), isNotNull);

    final exported = jsonDecode(await dao.exportJson()) as Map<String, dynamic>;
    expect(exported['xiangji_mentor_kb_migrations'], hasLength(1));
  });
}

Future<void> _seedPr146Goal(Database database) async {
  await database.execute('''
    CREATE TABLE xiangji_goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      status TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 0,
      current_version_id INTEGER,
      primary_thinker_id TEXT,
      current_node_id TEXT,
      current_pathway_id TEXT,
      last_interaction_at_ms INTEGER,
      created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE xiangji_goal_versions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      goal_id INTEGER NOT NULL,
      original_text TEXT NOT NULL,
      ai_summary TEXT,
      why_text TEXT NOT NULL,
      higher_values_json TEXT NOT NULL,
      success_definition TEXT,
      scope_text TEXT,
      created_by TEXT NOT NULL DEFAULT 'user_confirmed',
      created_at_ms INTEGER NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE xiangji_daily_steps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      goal_id INTEGER NOT NULL,
      goal_version_id INTEGER NOT NULL,
      action_text TEXT NOT NULL,
      trigger_context TEXT NOT NULL,
      minimum_done TEXT NOT NULL,
      evidence_rule TEXT NOT NULL,
      controllability_reason TEXT NOT NULL,
      smaller_variant TEXT NOT NULL,
      source_system_id TEXT,
      status TEXT NOT NULL DEFAULT 'ready',
      created_at_ms INTEGER NOT NULL,
      updated_at_ms INTEGER NOT NULL
    )
  ''');
  const now = 1700000000000;
  final goalId = await database.insert('xiangji_goals', <String, Object?>{
    'status': 'active',
    'is_active': 1,
    'primary_thinker_id': 'yangming',
    'current_node_id': 'knowledge_action_gap',
    'current_pathway_id': 'legacy_pr146',
    'last_interaction_at_ms': now,
    'created_at_ms': now,
    'updated_at_ms': now,
  });
  final versionId = await database.insert(
    'xiangji_goal_versions',
    <String, Object?>{
      'goal_id': goalId,
      'original_text': '保留旧目标原话',
      'ai_summary': '保留旧目标原话',
      'why_text': '保留旧目标原因',
      'higher_values_json': jsonEncode(<String>['自主', '成长']),
      'success_definition': '留下现实证据',
      'scope_text': '未来七天',
      'created_by': 'user_confirmed',
      'created_at_ms': now,
    },
  );
  await database.update(
    'xiangji_goals',
    <String, Object?>{'current_version_id': versionId},
    where: 'id = ?',
    whereArgs: <Object?>[goalId],
  );
  await database.insert('xiangji_daily_steps', <String, Object?>{
    'goal_id': goalId,
    'goal_version_id': versionId,
    'action_text': '保留旧版当前行动',
    'trigger_context': '打开应用时',
    'minimum_done': '完成一分钟',
    'evidence_rule': '保留一条记录',
    'controllability_reason': '由用户控制',
    'smaller_variant': '先做十秒',
    'source_system_id': 'yangming',
    'status': 'ready',
    'created_at_ms': now,
    'updated_at_ms': now,
  });
}

XiangjiGuidance _v21Guidance() {
  return const XiangjiGuidance(
    systemId: 'adler',
    mentorName: '阿尔弗雷德·阿德勒',
    mechanismId: 'courage_and_social_interest',
    mechanismLabel: '勇气与社会兴趣',
    coreJudgment: '把证明型目标改写为任务型目标。',
    selectionReason: '用户在升级后主动选择。',
    boundaryNote: '不把导师选择变成人格标签。',
    knowledgeView: '目标揭示生活方向。',
    structureText: '方向—任务—勇气—贡献。',
    detailText: '区分证明和参与。',
    actionDerivation: '完成一个勇气行动。',
    confidence: 1,
    sources: <XiangjiSourceCitation>[],
  );
}

XiangjiDailyStep _v21Step() {
  return const XiangjiDailyStep(
    id: 0,
    goalId: 0,
    goalVersionId: 0,
    actionText: '完成一个勇气行动',
    triggerContext: '今天第一次想到目标时',
    minimumDone: '完成最小一步',
    evidenceRule: '记录现实结果',
    controllabilityReason: '行动本身由用户控制',
    smallerVariant: '先做十秒',
    sourceSystemId: 'adler',
    status: 'ready',
    createdAtMs: 0,
  );
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
