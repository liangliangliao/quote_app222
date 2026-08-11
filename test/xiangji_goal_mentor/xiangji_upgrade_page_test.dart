import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_mentor_upgrade_card.dart';

void main() {
  testWidgets('PR146 旧导师显示无损升级提示和重新选择入口', (tester) async {
    var reselectRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XiangjiMentorUpgradeCard(
            fromThinkerId: 'yangming',
            onReselect: () => reselectRequested = true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(XiangjiMentorUpgradeCard.cardKey),
      findsOneWidget,
    );
    expect(find.text('知识库已升级，请重新选择目标导师'), findsOneWidget);
    expect(find.textContaining('原导师：王阳明'), findsOneWidget);
    expect(
      find.textContaining('目标原话、版本、行动、证据、私人书籍和历史记录均已保留'),
      findsOneWidget,
    );
    expect(find.text('当前导师不在受控知识库中'), findsNothing);

    await tester.tap(find.byKey(XiangjiMentorUpgradeCard.reselectKey));
    expect(reselectRequested, isTrue);
  });
}
