import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/beautiful_enemy/src/ui/enemy_growth_tab.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late EnemyEngine engine;
  setUp(() async {
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    engine = await EnemyEntry.buildEngine(db: db);
  });
  tearDown(() async => db.close());
  testWidgets('上传先预览，用户确认目标后保存；停用立即退出后续上下文', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EnemyGrowthTab(
                engine: engine,
                importer: () async =>
                    (name: '我的弱点.txt', text: '我害怕失败，经常拖延。')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传弱点文件'));
    await tester.pumpAndSettle();
    expect(find.text('核对并确认成长档案'), findsOneWidget);
    expect(await engine.growth.load(), isNull);
    await tester.tap(find.text('确认保存并用于后续活动'));
    await tester.pumpAndSettle();
    expect(find.text('请至少确认一个希望改善的弱点。'), findsOneWidget);
    await tester.tap(find.text('从原文按段落整理候选弱点'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(4), '遇到恐惧仍尝试一步');
    await tester.ensureVisible(find.text('确认保存并用于后续活动'));
    await tester.tap(find.text('确认保存并用于后续活动'));
    await tester.pumpAndSettle();
    expect((await engine.growth.load())!.weaknesses.single.description,
        '我害怕失败，经常拖延。');
    expect(find.textContaining('我自述的弱点'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await engine.snapshot()).digest.json['growth_profile'], isEmpty);
  });
  testWidgets('取消导入不改变已有档案，也不会创建新档案', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EnemyGrowthTab(engine: engine, importer: () async => null))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传弱点文件'));
    await tester.pumpAndSettle();
    expect(await engine.growth.load(), isNull);
    expect(find.text('核对并确认成长档案'), findsNothing);
  });
}
