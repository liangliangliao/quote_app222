import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/todo_goal_will_state.dart';

void main() {
  test('dominance follows user-calibrated strengths', () {
    const blocked = TodoGoalWillState(ideaId: 'idea', actionStrength: 45, obstacleStrength: 80);
    final actionLed = blocked.copyWith(actionStrength: 85, obstacleStrength: 60);

    expect(blocked.actionIdeaDominant, isFalse);
    expect(actionLed.actionIdeaDominant, isTrue);
  });

  test('distinguishes unfamiliar action image from bodily execution limits', () {
    const state = TodoGoalWillState(ideaId: 'idea');
    final unfamiliar = state.copyWith(actionExperience: 'new');
    final physicallyBlocked = state.copyWith(bodyCapability: 'blocked');

    expect(unfamiliar.needsActionDemonstration, isTrue);
    expect(unfamiliar.bodyExecutionBlocked, isFalse);
    expect(physicallyBlocked.needsActionDemonstration, isFalse);
    expect(physicallyBlocked.bodyExecutionBlocked, isTrue);
  });

  test('round trips persisted practice calibration', () {
    final source = TodoGoalWillState(
      ideaId: 'idea',
      selectedObstacle: '害怕失败',
      actionStrength: 72,
      obstacleStrength: 68,
      actionExperience: 'known',
      bodyCapability: 'adapt',
      attentionTargetSeconds: 60,
      rehearsalCompleted: true,
      firstActionCompleted: true,
      updatedAtMs: 123,
    );

    final restored = TodoGoalWillState.fromMap(source.toMap());
    expect(restored.selectedObstacle, source.selectedObstacle);
    expect(restored.actionStrength, 72);
    expect(restored.bodyCapability, 'adapt');
    expect(restored.rehearsalCompleted, isTrue);
    expect(restored.firstActionCompleted, isTrue);
  });
}
