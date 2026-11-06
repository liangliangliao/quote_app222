import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/data/db.dart';
import 'package:quote_app/beautiful_enemy/beautiful_enemy.dart';
import 'package:quote_app/beautiful_enemy/src/ui/enemy_tabs.dart';
import 'package:quote_app/behavior_tracking/behavior_observation_presets.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_dao.dart';
import 'package:quote_app/behavior_tracking/behavior_tracking_models.dart';
import 'package:quote_app/failure_module/failure_module_home_page.dart';
import 'package:quote_app/failure_module/pages/fp_practice_runner_page.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/ui/session_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'fixtures.dart';
import 'widget_test.dart' show prpIo, settlePrp;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late PrpFixture f;
  setUpAll(() async {
    sqfliteFfiInit();
    docs = await Directory.systemTemp.createTemp('prp_callers_');
    databaseFactory = databaseFactoryFfiNoIsolate;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => docs.path);
    await AppDatabase.instance();
  });
  tearDownAll(() async {
    await (await AppDatabase.instance()).close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), null);
    await docs.delete(recursive: true);
  });
  setUp(() async {
    f = PrpFixture();
    await f.open();
  });
  tearDown(() => PrpPlugin.instance = const NoopPrpPlugin());

  for (final label in ['我刚失败了：3P急救', '直接练：失败复盘（AAR）']) {
    for (final enabled in [true, false]) {
      testWidgets(
          'actual failure entry $label selects exactly one form with PRP=$enabled',
          (tester) async {
        if (enabled) await tester.runAsync(f.enable);
        await tester
            .pumpWidget(const MaterialApp(home: FailureModuleHomePage()));
        await settlePrp(tester, until: find.text(label));
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await settlePrp(tester,
            until: enabled
                ? find.text('先缓一缓')
                : find.byType(FpPracticeRunnerPage));
        expect(find.byType(PrpSessionCard),
            enabled ? findsOneWidget : findsNothing);
        expect(find.byType(FpPracticeRunnerPage),
            enabled ? findsNothing : findsOneWidget);
        expect(find.text('为什么没做到？'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settlePrp(tester);
      });
    }
  }

  testWidgets(
      'actual behavior daily confirmation offers PRP only after an explicit missed click',
      (tester) async {
    await tester.runAsync(() async {
      await f.enable();
      final now = DateTime.now().millisecondsSinceEpoch;
      await BehaviorTrackingDao().savePreset(BehaviorPreset(
          createdAtMs: now,
          updatedAtMs: now,
          name: '阅读十分钟',
          category: '学习',
          primaryLayer: 'action',
          unit: '分钟',
          reminderEnabled: false,
          weekdays: const [1, 2, 3, 4, 5, 6, 7],
          active: true,
          notes: '',
          sortOrder: 0));
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BehaviorObservationPresetsPage(
                categories: const ['学习'], onRecordsChanged: () {}))));
    await settlePrp(tester, until: find.text('新增预设行为'));
    expect(f.runtime.pendingOffer(PrpSurface.behavior), isNull);
    await tester.scrollUntilVisible(find.text('未完成'), 250,
        scrollable: find.byType(Scrollable).last, maxScrolls: 30);
    final miss = find.text('未完成').first;
    await tester.ensureVisible(miss);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(miss);
    await settlePrp(tester, until: find.text('先缓一缓'));
    expect(find.byType(PrpSessionCard), findsOneWidget);
    final sessions = await prpIo(tester, () => f.db.query('prp_session'));
    expect(sessions.single['trigger_kind'], 'habit_missed');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'actual enemy commitment missed control opens PRP and suppresses the old attribution dialog',
      (tester) async {
    late EnemyEngine engine;
    await tester.runAsync(() async {
      await f.enable();
      final dao = EnemyDao(f.db);
      await dao.ensureSchema();
      engine = EnemyEngine(
          dao: dao, oracle: const LocalFactOracle(), clock: f.clock.call);
      await engine.addCommitment('打开书读一页',
          due: f.clock.now.add(const Duration(hours: 2)));
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommitmentsTab(
                engine: engine, presence: EnemyPresence(engine: engine)))));
    await settlePrp(tester, until: find.byTooltip('没做到'));
    await tester.ensureVisible(find.byTooltip('没做到'));
    await tester.tap(find.byTooltip('没做到'));
    await settlePrp(tester, until: find.text('先缓一缓'));
    expect(find.byType(PrpSessionCard), findsOneWidget);
    expect(find.text('为什么没做到？'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });
}
