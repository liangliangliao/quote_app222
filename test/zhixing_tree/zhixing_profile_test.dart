import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/zhixing_tree/zhixing_engine.dart';
import 'package:quote_app/zhixing_tree/zhixing_models.dart';

void main() {
  final engine = ZhixingEngine();

  test('diagnosis updates a dynamic context profile without labels', () {
    const current = ZhixingActionProfile();
    const diagnosis = ZhixingDiagnosis(
      id: 'd1',
      createdAtMs: 1,
      problem: '我为了证明给别人看而逼自己完成一个目标。',
      autonomy: 'no',
      clarity: 'vague',
      barrier: 'meaning',
      discomfort: 'strong',
      experience: 'never',
      phase: 'start',
      availableMinutes: 5,
      values: <String>[],
    );

    final updated = engine.profileAfterDiagnosis(current, diagnosis);

    expect(updated.autonomy, lessThan(current.autonomy));
    expect(updated.selfEfficacy, lessThan(current.selfEfficacy));
    expect(updated.updatedAtMs, greaterThan(0));
  });

  test('completed evidence raises mastery signals', () {
    const current = ZhixingActionProfile(selfEfficacy: .3, opportunity: .3);
    const diagnosis = ZhixingDiagnosis(
      id: 'd2',
      createdAtMs: 1,
      problem: '开始学习',
      autonomy: 'yes',
      clarity: 'clear',
      barrier: 'thought',
      discomfort: 'moderate',
      experience: 'sometimes',
      phase: 'start',
      availableMinutes: 10,
      values: <String>['学习'],
    );
    final action = engine.generateLocal(diagnosis: diagnosis, profile: current);
    const evidence = ZhixingEvidence(
      id: 'e1',
      prescriptionId: 'a1',
      createdAtMs: 2,
      completed: true,
      predictedDiscomfort: 7,
      actualDiscomfort: 4,
      fit: '准确',
      scale: '合适',
      factResult: '完成了十分钟学习并保存笔记。',
      learning: '开始后比预测容易。',
      nextStep: '明天保持同样尺度。',
    );

    final updated = engine.profileAfterEvidence(current, action, evidence);

    expect(updated.selfEfficacy, greaterThan(current.selfEfficacy));
    expect(updated.opportunity, greaterThan(current.opportunity));
    expect(updated.completedCount, 1);
  });
}
