import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_dao.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_goal_mentor_page.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_knowledge_repository.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('PR146 旧导师不会再触发全屏错误并可重新选择', (tester) async {
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(database.close);
    final dao = XiangjiGoalMentorDao(database: database);
    await dao.createAndActivateGoal(_legacyDraft());

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
    final upgradedGoal = (await dao.activeGoal())!;
    expect(upgradedGoal.primaryThinkerId, 'adler');
    final migrations = await dao.mentorKnowledgeMigrations();
    expect(migrations.single.status, 'resolved');
    expect(migrations.single.resolvedThinkerId, 'adler');
    expect((await dao.currentStep(upgradedGoal.id))!.sourceSystemId, 'adler');
  });
}

XiangjiGoalDraft _legacyDraft() {
  const guidance = XiangjiGuidance(
    systemId: 'yangming',
    mentorName: '王阳明',
    mechanismId: 'knowledge_action_gap',
    mechanismLabel: '知行连接',
    coreJudgment: '先形成一个真实行动。',
    selectionReason: 'PR146 旧知识体系。',
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
    actionText: '保留覆盖安装前的行动',
    triggerContext: '打开应用时',
    minimumDone: '完成一分钟',
    evidenceRule: '保留记录',
    controllabilityReason: '由用户控制',
    smallerVariant: '先做十秒',
    sourceSystemId: 'yangming',
    status: 'ready',
    createdAtMs: 0,
  );
  return const XiangjiGoalDraft(
    originalText: '保留覆盖安装前的目标',
    whyText: '保留覆盖安装前的原因',
    higherValues: <String>['自主', '成长'],
    successDefinition: '留下现实证据',
    scopeText: '未来七天',
    guidance: guidance,
    step: step,
  );
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
