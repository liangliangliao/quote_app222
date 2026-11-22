import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork.dart'
    show FeedbackSettings;
import 'package:quote_app/conscious_change/interactive_image/effort_tuning_dialog.dart';
import 'package:quote_app/conscious_change/interactive_image/touch_effort.dart';

void main() {
  test('the five presets use the requested multipliers on every threshold', () {
    final presets = [
      for (final difficulty in EffortDifficulty.values) difficulty.preset
    ];
    expect(presets.map((t) => t.taps),
        [3, 5 * 30, 8 * 30, 8 * 30 * 100, 8 * 30 * 500]);
    expect(presets.map((t) => t.swipeDistance),
        [100, 220 * 30, 360 * 30, 360 * 30 * 100, 360 * 30 * 500]);
    expect(presets.map((t) => t.holdTime.inMilliseconds),
        [900, 1500 * 30, 2400 * 30, 2400 * 30 * 100, 2400 * 30 * 500]);
  });

  for (final difficulty in EffortDifficulty.values) {
    testWidgets(
        '${difficulty.name} requires its full effort for all three gestures',
        (tester) async {
      final effort = TouchEffort(difficulty);
      final tuning = difficulty.preset;
      addTearDown(effort.dispose);
      var reached = false;
      for (var i = 1; i < tuning.taps; i++) {
        reached = effort.tap('region') || reached;
      }
      expect(reached, isFalse);
      expect(effort.value.percent, lessThan(100));
      expect(effort.tap('region'), isTrue);
      expect(effort.value.percent, 100);
      effort.reset();

      expect(effort.swipe(tuning.swipeDistance.toDouble() - 1), isFalse);
      expect(effort.value.percent, lessThan(100));
      expect(effort.swipe(1), isTrue);
      expect(effort.value.percent, 100);
      effort.reset();

      var completions = 0;
      effort.hold(Duration.zero, () => completions++);
      await tester.pump(tuning.holdTime - const Duration(milliseconds: 1));
      expect(completions, 0);
      expect(effort.value.percent, lessThan(100));
      await tester.pump(const Duration(milliseconds: 1));
      expect(completions, 1);
      expect(effort.value.percent, 100);
      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
      expect(effort.value.percent, 0);
    });
  }

  testWidgets('a tuned level applies its own tap and swipe gap',
      (tester) async {
    const custom = EffortTuning(
        taps: 2,
        swipeDistance: 20,
        holdTime: Duration(milliseconds: 100),
        tapGap: Duration(milliseconds: 200),
        swipeGap: Duration(milliseconds: 300));
    final effort = TouchEffort(EffortDifficulty.easy, tuning: custom);
    addTearDown(effort.dispose);
    expect(effort.tap('first'), isFalse);
    expect(effort.value.percent, 50);
    effort.beginPointer('second');
    expect(effort.value.percent, 0);
    expect(effort.tap('second'), isFalse);
    await tester.pump(custom.tapGap);
    expect(effort.value.percent, 0);
    expect(effort.swipe(10), isFalse);
    await tester.pump(custom.swipeGap);
    expect(effort.value.percent, 0);
    expect(effort.swipe(11), isFalse);
    expect(effort.swipe(9), isTrue);
    effort.reset();
    var triggered = false;
    effort.hold(const Duration(milliseconds: 50), () => triggered = true);
    await tester.pump(const Duration(milliseconds: 49));
    expect(triggered, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(triggered, isTrue);
    effort.reset();
  });

  test('settings keep overrides per level and can restore an individual preset',
      () {
    expect(FeedbackSettings.fromJson({}).effortDifficulty,
        EffortDifficulty.standard);
    expect(FeedbackSettings.fromJson({}).effortTuning.taps, 150);
    const custom = EffortTuning(
        taps: 2, swipeDistance: 20, holdTime: Duration(seconds: 4));
    final tuned =
        const FeedbackSettings(effortDifficulty: EffortDifficulty.extreme)
            .withEffortTuning(custom);
    final restored = FeedbackSettings.fromJson(tuned.toJson());
    expect(restored.effortDifficulty, EffortDifficulty.extreme);
    expect(restored.effortTuning.toJson(), custom.toJson());
    expect(
        restored
            .copyWith(effortDifficulty: EffortDifficulty.hard)
            .effortTuning
            .taps,
        240);
    expect(restored.withEffortTuning(null).effortTuning.taps, 120000);
    expect(const EffortProgress(value: 1 / 120000).percentLabel, '<0.001%');
    expect(const EffortProgress(value: 0.99999).percentLabel, '99%');
  });

  testWidgets('the edit sheet validates input and applies custom thresholds',
      (tester) async {
    EffortTuning? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      child: const Text('调节'),
                      onPressed: () async {
                        selected = (await editEffortTuning(
                                context,
                                EffortDifficulty.hard,
                                EffortDifficulty.hard.preset))
                            ?.value;
                      },
                    )))));
    await tester.tap(find.text('调节'));
    await tester.pumpAndSettle();
    final taps = find.widgetWithText(TextFormField, '连点次数');
    await tester.enterText(taps, '0');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效的正整数'), findsOneWidget);
    await tester.enterText(taps, '28');
    await tester.enterText(
        find.widgetWithText(TextFormField, '滑动距离（逻辑像素）'), '900');
    await tester.enterText(
        find.widgetWithText(TextFormField, '长按时长（秒）'), '45.125');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(selected?.taps, 28);
    expect(selected?.swipeDistance, 900);
    expect(selected?.holdTime, const Duration(milliseconds: 45125));
  });
}
