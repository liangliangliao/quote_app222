import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhixing_tree/zhixing_engine.dart';
import 'package:quote_app/zhixing_tree/zhixing_models.dart';

void main() {
  final engine = ZhixingEngine();
  const profile = ZhixingActionProfile();

  ZhixingDiagnosis diagnosis({
    required String problem,
    String autonomy = 'yes',
    String clarity = 'clear',
    String barrier = 'thought',
    String discomfort = 'moderate',
    String experience = 'sometimes',
    String phase = 'start',
    int minutes = 10,
  }) {
    return ZhixingDiagnosis(
      id: 'test',
      createdAtMs: 1,
      problem: problem,
      autonomy: autonomy,
      clarity: clarity,
      barrier: barrier,
      discomfort: discomfort,
      experience: experience,
      phase: phase,
      availableMinutes: minutes,
      values: const <String>['成长'],
    );
  }

  test('fearful job application routes to graded breakthrough', () {
    final item = engine.generateLocal(
      diagnosis: diagnosis(
        problem: '我知道应该找工作，但害怕被拒绝，一直不敢投递。',
        barrier: 'emotion',
        discomfort: 'strong',
      ),
      profile: profile,
    );

    expect(item.challengeType, ZhixingChallengeType.breakthrough);
    expect(item.difficulty, ZhixingDifficulty.l1);
    expect(item.thoughtMatch.dominant, contains('ACT'));
    expect(item.firstPhysicalAction, isNotEmpty);
    expect(item.successEvidence, contains('投递'));
    expect(item.action, isNotEmpty);
  });

  test('fatigue routes to recovery and rewards water', () {
    final item = engine.generateLocal(
      diagnosis: diagnosis(
        problem: '最近长期过劳，晚上仍逼自己继续工作。',
        barrier: 'energy',
        discomfort: 'strong',
      ),
      profile: profile,
    );

    expect(item.challengeType, ZhixingChallengeType.recovery);
    expect(item.rewardXp, 5);
    expect(item.rewardCoins, 6);
    expect(item.rewardWater, 2);
    expect(item.action, contains('恢复'));
  });

  test('non-autonomous goal is calibrated before execution', () {
    final item = engine.generateLocal(
      diagnosis: diagnosis(
        problem: '这是别人期待我做的目标，我并不确定自己想不想继续。',
        autonomy: 'no',
        clarity: 'vague',
        barrier: 'meaning',
      ),
      profile: profile,
    );

    expect(item.challengeType, ZhixingChallengeType.direction);
    expect(item.thoughtMatch.dominant, contains('自我决定'));
    expect(item.action, contains('继续、修改或暂停'));
  });

  test('explicit boundary request routes to stop-loss', () {
    final item = engine.generateLocal(
      diagnosis: diagnosis(
        problem: '我需要对一项持续伤害自己的不合理要求明确拒绝，并设下边界。',
        barrier: 'environment',
      ),
      profile: profile,
    );

    expect(item.challengeType, ZhixingChallengeType.stopLoss);
    expect(item.action, contains('停止条件或边界'));
  });

  test('crisis language bypasses ordinary challenge and rewards', () {
    final item = engine.generateLocal(
      diagnosis: diagnosis(
        problem: '我不想活了，想伤害自己。',
        barrier: 'emotion',
        discomfort: 'unbearable',
      ),
      profile: profile,
    );

    expect(item.risk, ZhixingRiskLevel.crisis);
    expect(item.isSafetyRoute, isTrue);
    expect(item.rewardXp, 0);
    expect(item.rewardCoins, 0);
    expect(item.action, contains('联系'));
    expect(item.safetyMessage, isNotEmpty);
  });

  test('prescription survives JSON round trip', () {
    final original = engine.generateLocal(
      diagnosis: diagnosis(problem: '我想开始学习数学，但总是拖延。'),
      profile: profile,
    );
    final restored = ZhixingPrescription.decode(original.encode());

    expect(restored.id, original.id);
    expect(restored.challengeType, original.challengeType);
    expect(restored.thoughtMatch.dominant, original.thoughtMatch.dominant);
    expect(restored.firstPhysicalAction, original.firstPhysicalAction);
    expect(restored.rewardCoins, original.rewardCoins);
  });
}
