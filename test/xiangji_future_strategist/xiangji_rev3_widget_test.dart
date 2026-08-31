import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_guidance_pages.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_practical_product.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_practical_widgets.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_repository.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_rev3_models.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_strategist_conversation.dart';

void main() {
  testWidgets('TC-UX-R3-01/accessible natural-language entry at 200% text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final dao = XiangjiDao();
    final repository = _EmptyHistoryRepository(dao);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: XiangjiStrategistConversationPanel(
              repository: repository,
              dao: dao,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('与军师对话'), findsOneWidget);
    final input = tester.widget<TextField>(
      find.byKey(
        const ValueKey<String>('xiangji_strategist_input'),
      ),
    );
    expect(
      input.decoration?.hintText,
      '只写一句也可以：我想要…… / 我卡在…… / 实际发生了……',
    );
    expect(find.byTooltip('语音输入'), findsOneWidget);
    expect(find.byTooltip('添加附件'), findsOneWidget);
    expect(find.byTooltip('不会用？问使用助手'), findsOneWidget);
    expect(find.text('给我一个现实下一步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC-UX-V62 practical result defaults to choice and one action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    var selected = 'steady_step';

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  XiangjiPracticalDecisionCard(
                    problem: '每天浏览岗位却没有发出申请',
                    goal: '一周内获得可比较的真实反馈',
                    keyGap: '缺少真实投递样本',
                    judgment: '先用一次真实投递区分方向、材料和渠道问题。',
                    choices: const XiangjiPersonalizedActionChoiceEngine().build(
                      baseAction: '发出一份定向申请',
                      mechanism: '用真实投递获得外部反馈',
                      prediction: '会得到回复或一个可修改差异',
                      expectedMinutes: 15,
                      profile: XiangjiUserPreferenceProfile(),
                    ),
                    selectedChoiceId: selected,
                    onChoiceSelected: (value) =>
                        setState(() => selected = value),
                    onStart: () {},
                    onModify: () {},
                    onOppose: () {},
                    onShowDetails: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('现在只需要决定一件事'), findsOneWidget);
    expect(find.text('轻松起步'), findsOneWidget);
    expect(find.text('稳步推进'), findsOneWidget);
    expect(find.text('现实挑战'), findsOneWidget);
    expect(find.text('选择这条并开始'), findsOneWidget);
    expect(find.text('SituationModel'), findsNothing);
    expect(find.text('AgentRun'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TC-UX-V63 guided case rehearses the complete useful loop',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final example = XiangjiPracticalProductContract.guidedCases.first;

    await tester.pumpWidget(
      MaterialApp(
        home: XiangjiGuidedCasePracticePage(example: example),
      ),
    );

    expect(find.text('1. 从真实需要开始'), findsOneWidget);
    expect(find.text('核心思想家'), findsOneWidget);
    expect(find.text('叔本华'), findsOneWidget);

    for (final expectedTitle in <String>[
      '2. 把事实与解释分开',
      '3. 选一个能产生现实的办法',
      '4. 让现实改判并带走方法',
    ]) {
      final next = find.byKey(
        const ValueKey<String>('xiangji_case_practice_next'),
      );
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text(expectedTitle), findsOneWidget);
    }

    expect(find.text(example.revision), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('xiangji_case_practice_finish')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _EmptyHistoryRepository extends XiangjiRepository {
  _EmptyHistoryRepository(XiangjiDao dao) : super(dao: dao);

  @override
  Future<List<XiangjiDecisionDraftRecord>> decisionDrafts({
    int limit = 20,
  }) async =>
      const <XiangjiDecisionDraftRecord>[];

  @override
  Future<XiangjiUserPreferenceProfile> userPreferenceProfile() async =>
      const XiangjiUserPreferenceProfile();
}
