import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/conscious_change/interactive_image/artwork.dart'
    show FeedbackSettings;
import 'package:quote_app/conscious_change/interactive_image/touch_effort.dart';

void main() {
  for (final difficulty in EffortDifficulty.values) {
    testWidgets(
        '${difficulty.name} requires its full effort for all three gestures',
        (tester) async {
      final effort = TouchEffort(difficulty, const TestVSync());
      addTearDown(effort.dispose);
      for (var i = 1; i < difficulty.taps; i++) {
        expect(effort.tap('region'), isFalse);
        expect(effort.value.percent, lessThan(100));
      }
      expect(effort.tap('region'), isTrue);
      expect(effort.value.percent, 100);
      effort.reset();

      expect(effort.swipe(difficulty.swipeDistance - 1), isFalse);
      expect(effort.value.percent, lessThan(100));
      expect(effort.swipe(1), isTrue);
      expect(effort.value.percent, 100);
      effort.reset();

      var completions = 0;
      effort.hold(Duration.zero, () => completions++);
      await tester.pump();
      await tester.pump(difficulty.holdTime - const Duration(milliseconds: 1));
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

  testWidgets(
      'tap effort stays with its own region and expires after the tap gap',
      (tester) async {
    final effort = TouchEffort(EffortDifficulty.easy, const TestVSync());
    addTearDown(effort.dispose);
    expect(effort.tap('first'), isFalse);
    expect(effort.tap('first'), isFalse);
    effort.beginPointer('second');
    expect(effort.value.percent, 0);
    expect(effort.tap('second'), isFalse);
    expect(effort.value.percent, 33);
    await tester.pump(TouchEffort.tapGap);
    expect(effort.value.percent, 0);
  });

  test(
      'existing settings use standard effort and preserve a selected difficulty',
      () {
    expect(FeedbackSettings.fromJson({}).effortDifficulty,
        EffortDifficulty.standard);
    final settings = const FeedbackSettings()
        .copyWith(effortDifficulty: EffortDifficulty.hard);
    expect(FeedbackSettings.fromJson(settings.toJson()).effortDifficulty,
        EffortDifficulty.hard);
  });
}
