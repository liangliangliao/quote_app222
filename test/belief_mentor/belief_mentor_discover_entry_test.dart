import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/belief_lab/belief_mentor_dao.dart';
import 'package:quote_app/belief_lab/belief_mentor_discover_entry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('发现之旅入口说明完整闭环并可打开产品', (tester) async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final dao = BeliefMentorDao(database: database);
    await dao.ensureSchema(database);
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeliefMentorDiscoverEntry(dao: dao, onTap: () => opened = true),
        ),
      ),
    );
    // Avoid an unbounded settle around the loading indicator: if database
    // initialization fails, the test should fail quickly instead of waiting
    // for Flutter's long pumpAndSettle timeout.
    for (var i = 0; i < 30; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(BeliefMentorDiscoverEntry.entryKey)
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.byKey(BeliefMentorDiscoverEntry.entryKey), findsOneWidget);
    expect(find.text('Belief Mentor'), findsOneWidget);
    expect(find.textContaining('识别限制性信念'), findsOneWidget);

    await tester.tap(find.byKey(BeliefMentorDiscoverEntry.entryKey));
    expect(opened, isTrue);
  });
}
