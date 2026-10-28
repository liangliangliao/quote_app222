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
  testWidgets('上传后直接保存全部文字，无需逐项确认', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final text = '我害怕失败，经常拖延。\n' + '弱点描述' * 600;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EnemyGrowthTab(
      engine: engine, importer: () async => (name: '我的弱点.txt', text: text)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传弱点文件'));
    await tester.pumpAndSettle();
    final profile = (await engine.growth.load())!;
    expect(profile.originalText, text);
    expect(profile.weaknesses.map((w) => w.description).join(), text);
    expect(profile.weaknesses.length, greaterThan(1));
    expect(find.text('核对并确认成长档案'), findsNothing);
    final context = (await engine.snapshot()).digest.json['growth_profile'] as Map;
    expect(context['original_text'], text);
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
