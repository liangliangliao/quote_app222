import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/external_data/todo_meaning_engine.dart';

void main() {
  const engine = TodoMeaningEngine();

  test('detects direct Chinese and English crisis signals', () {
    expect(engine.containsCrisisSignal('我最近有轻生的想法'), isTrue);
    expect(engine.containsCrisisSignal('我有自伤冲动'), isTrue);
    expect(engine.containsCrisisSignal('I want to end my life'), isTrue);
    expect(engine.containsCrisisSignal('我只是对工作方向很迷茫'), isFalse);
  });

  test('relationship responsibility selects relationship path', () {
    final snapshot = engine.buildSnapshot(
      input: const TodoMeaningScanInput(
        situation: '最近只顾工作，和家人疏远',
        unavoidableQuestion: '如何修复关系',
        recurringResponsibility: '照顾父母并认真倾听',
        waitingPerson: '父母正在等待我的回应',
        uniqueTask: '',
        avoidedResponsibility: '一直逃避打电话',
      ),
      goals: const [],
      todaySteps: const [],
      reflections: const [],
      nowMs: 123,
    );

    expect(snapshot.snapshotId, 'meaning_scan_123');
    expect(snapshot.primaryPath, 'relationship');
    expect(snapshot.selfTranscendence, greaterThanOrEqualTo(3));
    expect(snapshot.nextResponse, contains('父母'));
  });

  test('unavoidable hardship selects attitude path without glorifying pain', () {
    final snapshot = engine.buildSnapshot(
      input: const TodoMeaningScanInput(
        situation: '正在面对不可改变的离别',
        unavoidableQuestion: '如何带着失去继续生活',
        recurringResponsibility: '',
        waitingPerson: '',
        uniqueTask: '',
        avoidedResponsibility: '',
      ),
      goals: const [],
      todaySteps: const [],
      reflections: const [],
    );

    expect(snapshot.primaryPath, 'attitude');
    expect(snapshot.nextResponse, contains('可改变与不可改变'));
    expect(engine.classifyControllability('changeable'), contains('先解决问题'));
  });
}
