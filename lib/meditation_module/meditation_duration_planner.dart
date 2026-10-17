import 'dart:math' as math;

import 'meditation_mentor_guidance.dart';
import 'meditation_models.dart';

class MeditationDurationPlan {
  final List<MeditationStep> steps;
  final int targetSeconds;
  final int originalMinimumSeconds;
  final int durationSeconds;
  final bool pausesAdjusted;

  const MeditationDurationPlan({
    required this.steps,
    required this.targetSeconds,
    required this.originalMinimumSeconds,
    required this.durationSeconds,
    required this.pausesAdjusted,
  });

  bool get exceedsTarget => durationSeconds > targetSeconds;
}

/// Fit reducible silence first. Never discard narration or force faster speech.
class MeditationDurationPlanner {
  static MeditationDurationPlan plan(
      List<MeditationStep> steps, int targetSeconds) {
    final minimum = steps.fold<int>(
        0,
        (sum, step) =>
            sum +
            MeditationMentorGuidance.speechSeconds(step.text) +
            step.pauseAfterSeconds);
    var adjusted = steps;
    if (minimum > targetSeconds) {
      final capacities = steps.map((step) {
        final core = RegExp(
                r'body_emotion|allow_experience|embodied_shift|real_life_rehearsal')
            .hasMatch(step.intent ?? '');
        // Preserve an existing shorter pause, and protect 8 seconds after a
        // core invitation when the model actually provided that much time.
        final floor = targetSeconds <= 120 ? 1 : (core ? 8 : 4);
        return math.max(0, step.pauseAfterSeconds - floor);
      }).toList();
      final total = capacities.fold<int>(0, (sum, value) => sum + value);
      final reduction = math.min(minimum - targetSeconds, total);
      final cuts = capacities
          .map((capacity) => total == 0 ? 0 : reduction * capacity ~/ total)
          .toList();
      var remaining = reduction - cuts.fold<int>(0, (sum, cut) => sum + cut);
      // Proportional rounding leaves fewer than one second per segment.
      for (var i = 0; i < cuts.length && remaining > 0; i++) {
        if (cuts[i] >= capacities[i]) continue;
        cuts[i]++;
        remaining--;
      }
      adjusted = List.generate(steps.length, (i) {
        final step = steps[i];
        return MeditationStep(
          startSecond: step.startSecond,
          text: step.text,
          intent: step.intent,
          pauseAfterSeconds: step.pauseAfterSeconds - cuts[i],
        );
      });
    }
    final required = adjusted.fold<int>(
        0,
        (sum, step) =>
            sum +
            MeditationMentorGuidance.speechSeconds(step.text) +
            step.pauseAfterSeconds);
    final duration = math.max(targetSeconds, required);
    return MeditationDurationPlan(
      steps: MeditationMentorGuidance.schedule(adjusted, duration),
      targetSeconds: targetSeconds,
      originalMinimumSeconds: minimum,
      durationSeconds: duration,
      pausesAdjusted: minimum != required,
    );
  }
}
