import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_database.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_repository.dart';
import 'package:quote_app/xiangji_future_strategist/xiangji_strategist_conversation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('TC-UX-R3-01/accessible natural-language entry at 200% text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database =
        await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() => database.close());
    final dao = XiangjiDao(database: database);
    await dao.ensureSchema(database);
    final repository = XiangjiRepository(dao: dao);

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
    await tester.pumpAndSettle();

    expect(find.text('与军师对话'), findsOneWidget);
    final input = tester.widget<TextField>(
      find.byKey(
        const ValueKey<String>('xiangji_strategist_input'),
      ),
    );
    expect(
      input.decoration?.hintText,
      '告诉我你想要什么、发生了什么，或者你现在卡在哪里。',
    );
    expect(find.byTooltip('语音输入'), findsOneWidget);
    expect(find.byTooltip('添加附件'), findsOneWidget);
    expect(find.text('请军师分析'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
