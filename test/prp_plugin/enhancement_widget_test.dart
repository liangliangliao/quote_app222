import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/prp_plugin/prp_plugin.dart';
import 'package:quote_app/prp_plugin/src/runtime.dart';
import 'package:quote_app/prp_plugin/src/ui/experiments.dart';
import 'package:quote_app/prp_plugin/src/ui/feature_pages.dart';
import 'fixtures.dart';
import 'widget_test.dart' show prpIo, settlePrp;

void main() {
  late PrpFixture f;
  setUp(() async {
    f = PrpFixture();
    await f.open();
  });
  tearDown(() {
    PrpPlugin.instance = const NoopPrpPlugin();
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settlePrp(tester);
  }

  testWidgets(
      'forecast UI saves actuals once and preserves a readable record when disabled',
      (tester) async {
    await tester.runAsync(() async {
      await f.enable();
      await f.runtime
          .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    });
    await tester
        .pumpWidget(MaterialApp(home: PrpForecastPage(runtime: f.runtime)));
    await settlePrp(tester);
    await tap(tester, find.byKey(const ValueKey('prp_forecast_new')));
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_label')), '给同事发一条消息');
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_days')), '3');
    await tap(tester, find.byKey(const ValueKey('prp_forecast_save')));
    await settlePrp(tester, until: find.text('事情过去了，补记实际'));
    await tap(tester, find.text('事情过去了，补记实际'));
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_days')), '0');
    await tap(tester, find.byKey(const ValueKey('prp_forecast_save')));
    await settlePrp(tester, until: find.text('实际为 0 的维度不计算倍数。'));
    expect(find.text('事情过去了，补记实际'), findsNothing);
    await prpIo(
        tester,
        () => f.runtime
            .updatePreferences(f.runtime.preferences.copyWith(enabled: false)));
    await settlePrp(tester, until: find.textContaining('记录已保留'));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('prp_forecast_new')))
            .onPressed,
        isNull);
    expect((await prpIo(tester, () => f.runtime.forecasts())).single.actualDays,
        0);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'crisis in a new prediction closes its editor, presents help and stores no label',
      (tester) async {
    await tester.runAsync(() async {
      await f.enable();
      await f.runtime
          .updatePreferences(f.runtime.preferences.copyWith(forecasts: true));
    });
    await tester
        .pumpWidget(MaterialApp(home: PrpForecastPage(runtime: f.runtime)));
    await settlePrp(tester);
    await tap(tester, find.byKey(const ValueKey('prp_forecast_new')));
    await tester.enterText(
        find.byKey(const ValueKey('prp_forecast_label')), '我不想活了');
    await settlePrp(tester, until: find.text('先照顾此刻的安全'));
    expect(find.byKey(const ValueKey('prp_forecast_label')), findsNothing);
    expect(await prpIo(tester, () => f.runtime.exportData()),
        isNot(contains('不想活')));
    expect(f.host.safetyExits, 1);
    await tester.pumpWidget(const SizedBox());
    await settlePrp(tester);
  });

  testWidgets(
      'press and release remain an unscored experiment and disabling closes its actual route',
      (tester) async {
    await tester.runAsync(() async {
      await f.enable();
      await f.runtime
          .updatePreferences(f.runtime.preferences.copyWith(particles: true));
    });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('打开实验'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                PrpParticlesPage(runtime: f.runtime))))))));
    await tap(tester, find.text('打开实验'));
    final canvas = find.byKey(const ValueKey('prp_particle_canvas'));
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('按住时：粒子散开'), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('松手后：粒子缓缓回落'), findsOneWidget);
    expect(f.databaseOpens, 0);
    await prpIo(
        tester,
        () => f.runtime
            .updatePreferences(f.runtime.preferences.copyWith(enabled: false)));
    await settlePrp(tester, until: find.text('打开实验'));
    expect(find.byType(PrpParticlesPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
