import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_experience_widgets.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_rev3_models.dart';

void main() {
  testWidgets('G3/DOC-08 solver cockpit is first-class and uses user language',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: XiangjiSolverCockpitView(
              problem: '我是否应该继续当前工作',
              currentState: '已连续两周回避投递',
              goal: '在现金流安全前提下验证新方向',
              keyGap: '尚未区分是方向不匹配还是行动前焦虑',
              activeHypothesis: '方向不匹配；行动前焦虑',
              subgoal: '用一次可逆小实验区分原因',
              currentAction: '完成一次 20 分钟低承诺任务',
              mechanism: '用行动前后的可观察变化区分两个原因',
              prediction: '如果主要是行动前焦虑，开始后阻力会下降',
              originalNeed: '我想辞职但很害怕',
              realityFacts: <String>['已连续两周回避投递', '想到投递时胸口紧'],
              epistemicStatus: '当前材料暂时支持',
              keyGapReason: '它最影响目标，而且可由一次现实行动区分',
              actionBoundary: '20 分钟；出现明显不适就停止并回来验算',
              progressLabel: '正在持续求解',
              currentFocus: '区分当前最能改变路线的原因',
            ),
          ),
        ),
      ),
    );

    expect(find.text('军师解题台'), findsOneWidget);
    for (final label in <String>[
      '这道题',
      '现在实际处于什么状态',
      '当前最重要的事实与体验',
      '希望现实变成什么样',
      '目前最关键的差距',
      '为什么先解决它',
      '军师正在区分的原因',
      '当前判断有多稳',
      '先解决哪一小步',
      '当前唯一行动',
      '时间与边界',
      '为什么这个办法可能有效',
      '如果有效，现实中应该看到什么',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('S0'), findsNothing);
    expect(find.textContaining('KeyGap'), findsNothing);
    expect(find.textContaining('Operator'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DOC-08 cockpit remains usable at 200 percent text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: XiangjiSolverCockpitView(
                problem: '一道真实问题',
                currentState: '当前现实',
                goal: '可观察目标',
                keyGap: '唯一关键差距',
                activeHypothesis: '正在区分的原因',
                subgoal: '当前小步',
                currentAction: '唯一行动',
                mechanism: '作用机制',
                prediction: '可被反驳的事前预测',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('军师解题台'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DOC-08 changed method exposes trigger and before/after effect',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: XiangjiMethodEffectCard(
              event: XiangjiMethodEvent(
                id: 'event-1',
                methodId: 'MEC-011',
                problemId: 'problem-1',
                stateVersion: 2,
                trigger: 'CurrentState S0 与 Goal G 已足够明确',
                operationSummary: '重新排序当前差距',
                dataMutations: <Map<String, Object?>>[],
                decisionEffect: 'KeyGap 改变，因此 Operator 必须重算',
                userVisibleSummary: '现实让军师重新选择了当前最大差距。',
                realityTest: '下一次面试后检查转化信号是否改善',
                beforeStateRefs: <String, Object?>{
                  'key_gap': <String, Object?>{'label': '获得有效回复'},
                },
                afterStateRefs: <String, Object?>{
                  'key_gap': <String, Object?>{'label': '面试转化为录用'},
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('军师改判'));
    await tester.pumpAndSettle();

    expect(find.textContaining('持续问题求解'), findsOneWidget);
    expect(find.textContaining('七维差距雷达'), findsWidgets);
    expect(find.text('产品方案中的方法'), findsOneWidget);
    expect(find.text('对应的原概念 / 求解概念'), findsOneWidget);
    expect(find.text('这个概念在产品中意味着什么'), findsOneWidget);
    expect(find.text('军师在这道题里怎样使用'), findsOneWidget);
    expect(find.text('下次可以迁移的问题'), findsOneWidget);
    expect(find.text('什么现实或线索触发了它'), findsOneWidget);
    expect(find.text('此前怎样理解'), findsOneWidget);
    expect(find.textContaining('获得有效回复'), findsOneWidget);
    expect(find.text('现在怎样理解'), findsOneWidget);
    expect(find.textContaining('面试转化为录用'), findsOneWidget);
    expect(find.text('怎样改变当前解法'), findsOneWidget);
    expect(find.textContaining('S0'), findsNothing);
    expect(find.textContaining('KeyGap'), findsNothing);
    expect(find.textContaining('Operator'), findsNothing);
    expect(find.textContaining('叔本华认识纪律'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI participation is visible as auditable product work',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: XiangjiAiContributionCard(
              summary: XiangjiAiExecutionSummary(
                aiConfigured: true,
                provider: 'deepseek',
                model: 'deepseek-v4-pro',
                plannedAgentCount: 8,
                cloudAgentCount: 7,
                localAgentCount: 1,
                totalLatencyMs: 2300,
                redactedFieldCount: 2,
                cloudAgentLabels: <String>[
                  '经验分层',
                  '竞争因果',
                  '判断力仲裁',
                  '持续问题求解',
                ],
                changedArtifacts: <String>[
                  '重构了真问题',
                  '重新选择了当前关键差距',
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('AI 军师已参与本轮推演'), findsOneWidget);
    expect(find.textContaining('DeepSeek'), findsOneWidget);
    expect(find.text('AI 实际形成或更新了什么'), findsOneWidget);
    expect(find.textContaining('重构了真问题'), findsOneWidget);
    expect(find.text('本轮参与的认知角色'), findsOneWidget);
    expect(find.textContaining('经验分层'), findsOneWidget);
    expect(find.textContaining('隐藏 2 个直接标识'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local fallback is never presented as cloud AI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: XiangjiAiContributionCard(
              summary: XiangjiAiExecutionSummary(
                plannedAgentCount: 6,
                localAgentCount: 6,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('AI 未配置，本轮由本地求解内核完成'), findsOneWidget);
    expect(find.textContaining('不会伪装成云端 AI'), findsOneWidget);
    expect(find.text('AI 军师已参与本轮推演'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
