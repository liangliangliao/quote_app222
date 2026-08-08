import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_dao.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_goal_mentor_page.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_knowledge_repository.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PR146 旧导师不会再触发全屏错误并可重新选择', (tester) async {
    final dao = _UpgradePageDao();

    await tester.pumpWidget(
      MaterialApp(
        home: XiangjiGoalMentorPage(
          dao: dao,
          knowledgeRepository: XiangjiKnowledgeRepository(),
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find
          .text('知识库已升级，请重新选择目标导师')
          .evaluate()
          .isNotEmpty,
      '旧导师升级提示出现',
    );

    expect(find.text('知识库已升级，请重新选择目标导师'), findsOneWidget);
    expect(find.text('保留覆盖安装前的目标'), findsOneWidget);
    expect(find.text('当前导师不在受控知识库中'), findsNothing);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('目标'), findsOneWidget);
    expect(find.text('书库'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    final reselectButton = find.byKey(
      const ValueKey<String>('xiangji_reselect_mentor_after_upgrade'),
    );
    await tester.ensureVisible(reselectButton);
    await tester.pump();
    await tester.tap(reselectButton);
    await _pumpUntil(
      tester,
      () => find.text('目标导师与知识路径').evaluate().isNotEmpty,
      '导师重新选择页打开',
    );
    expect(find.text('目标导师与知识路径'), findsOneWidget);
    expect(find.text('选择一位导师，保持一条判断路径'), findsOneWidget);

    await tester.tap(find.text('选择这位导师'));
    await _pumpUntil(
      tester,
      () => find.text('目标导师与知识路径').evaluate().isEmpty,
      '导师选择完成并返回目标页',
    );

    expect(find.text('知识库已升级，请重新选择目标导师'), findsNothing);
    final upgradedGoal = dao.goal;
    expect(upgradedGoal.primaryThinkerId, 'adler');
    expect(dao.migration.status, 'resolved');
    expect(dao.migration.resolvedThinkerId, 'adler');
    expect(dao.step.sourceSystemId, 'adler');
  });
}

class _UpgradePageDao extends XiangjiGoalMentorDao {
  XiangjiGoal goal = const XiangjiGoal(
    id: 1,
    versionId: 1,
    state: XiangjiGoalState.active,
    isActive: true,
    originalText: '保留覆盖安装前的目标',
    whyText: '保留覆盖安装前的原因',
    higherValues: <String>['自主', '成长'],
    successDefinition: '留下现实证据',
    scopeText: '未来七天',
    primaryThinkerId: 'yangming',
    currentNodeId: 'knowledge_action_gap',
    createdAtMs: 1,
    updatedAtMs: 1,
  );

  XiangjiDailyStep step = const XiangjiDailyStep(
    id: 1,
    goalId: 1,
    goalVersionId: 1,
    actionText: '保留覆盖安装前的行动',
    triggerContext: '打开应用时',
    minimumDone: '完成一分钟',
    evidenceRule: '保留记录',
    controllabilityReason: '由用户控制',
    smallerVariant: '先做十秒',
    sourceSystemId: 'yangming',
    status: 'ready',
    createdAtMs: 1,
  );

  XiangjiMentorKnowledgeMigration migration =
      const XiangjiMentorKnowledgeMigration(
    id: 1,
    goalId: 1,
    fromThinkerId: 'yangming',
    targetKnowledgeVersion: '2.1.0',
    status: 'reselection_required',
    resolvedThinkerId: '',
    detectedAtMs: 1,
    resolvedAtMs: 0,
  );

  @override
  Future<XiangjiGoal?> activeGoal() async => goal;

  @override
  Future<void> markGoalSeen(int goalId) async {}

  @override
  Future<XiangjiMentorKnowledgeMigration?>
      ensureMentorKnowledgeCompatibility({
    required XiangjiGoal goal,
    required Set<String> validMentorIds,
    required String targetKnowledgeVersion,
  }) async =>
          migration.requiresReselection ? migration : null;

  @override
  Future<XiangjiDailyStep?> currentStep(int goalId) async => step;

  @override
  Future<List<XiangjiGrowthEvidence>> evidenceForGoal(int goalId) async =>
      const <XiangjiGrowthEvidence>[];

  @override
  Future<List<XiangjiGoal>> allGoals() async => <XiangjiGoal>[goal];

  @override
  Future<List<Map<String, Object?>>> goalVersions(int goalId) async =>
      const <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> stateEvents(int goalId) async =>
      const <Map<String, Object?>>[];

  @override
  Future<XiangjiReminderSettings> reminderSettings() async =>
      XiangjiReminderSettings.defaults();

  @override
  Future<List<XiangjiBookInfo>> importedBooks() async =>
      const <XiangjiBookInfo>[];

  @override
  Future<List<XiangjiProviderMirror>> pendingProviderDeletions() async =>
      const <XiangjiProviderMirror>[];

  @override
  Future<bool> featureEnabled(String flagKey) async => true;

  @override
  Future<void> recordAnalyticsEvent(
    String eventName, {
    int? goalId,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {}

  @override
  Future<XiangjiGoal> changeMentor({
    required XiangjiGoal goal,
    required XiangjiGuidance guidance,
    String reason = '用户主动更换导师',
    String reasonCode = 'user_changed',
    String kbVersion = '2.1.0',
  }) async {
    this.goal = XiangjiGoal(
      id: goal.id,
      versionId: goal.versionId,
      state: goal.state,
      isActive: goal.isActive,
      originalText: goal.originalText,
      whyText: goal.whyText,
      higherValues: goal.higherValues,
      successDefinition: goal.successDefinition,
      scopeText: goal.scopeText,
      primaryThinkerId: guidance.systemId,
      currentNodeId: guidance.mechanismId,
      createdAtMs: goal.createdAtMs,
      updatedAtMs: 2,
    );
    migration = XiangjiMentorKnowledgeMigration(
      id: migration.id,
      goalId: migration.goalId,
      fromThinkerId: migration.fromThinkerId,
      targetKnowledgeVersion: migration.targetKnowledgeVersion,
      status: 'resolved',
      resolvedThinkerId: guidance.systemId,
      detectedAtMs: migration.detectedAtMs,
      resolvedAtMs: 2,
    );
    return this.goal;
  }

  @override
  Future<XiangjiDailyStep> replaceCurrentStep(
    XiangjiGoal goal,
    XiangjiDailyStep next, {
    String trigger = 'step_replaced',
  }) async {
    step = XiangjiDailyStep(
      id: 2,
      goalId: goal.id,
      goalVersionId: goal.versionId,
      actionText: next.actionText,
      triggerContext: next.triggerContext,
      minimumDone: next.minimumDone,
      evidenceRule: next.evidenceRule,
      controllabilityReason: next.controllabilityReason,
      smallerVariant: next.smallerVariant,
      sourceSystemId: next.sourceSystemId,
      status: next.status,
      createdAtMs: 2,
    );
    return step;
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  fail('等待超时：$description');
}
