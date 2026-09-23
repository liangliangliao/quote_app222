import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('JEV action request and response cover all execution factors', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '明天 8:00 出门',
      'current_context': '已经预约'
    }, 'jev-latest');
    final questions = request['questions'] as Map;
    expect(questions, contains('execute_on_time'));
    for (final key in EvidenceGrowthJev.actionFactors.keys) {
      expect(questions, contains('factor_$key'));
    }

    final answers = <String, dynamic>{
      'execute_on_time': {'type': 'noul', 'noul': .72},
      for (final key in EvidenceGrowthJev.actionFactors.keys)
        'factor_$key': {'type': 'noul', 'noul': .61},
    };
    final parsed = EvidenceGrowthJev.parseAction({
      'model': 'jev-latest',
      'answers': answers,
      'usage': {'input_tokens': 10}
    });
    expect(parsed['overall'], .72);
    expect((parsed['factors'] as Map)['decision_stability'], .61);
  });

  test('action prediction history stores outcomes for later calibration', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final dao = EvidenceGrowthDao(database: () async => db);
    await dao.ensureTables();
    final service = EvidenceGrowthActionPredictionService(dao: dao);

    await service.savePrediction({
      'id': 'p1',
      'plan': '去体检',
      'estimate': .64,
      'outcome': 'PENDING',
      'scheduled_at_ms': 1,
    });
    await service.recordOutcome('p1', 'ON_TIME');

    final rows = await service.history();
    expect(rows, hasLength(1));
    expect(rows.single['outcome'], 'ON_TIME');
  });

  test('prediction bands remain descriptive rather than guaranteed', () {
    expect(EvidenceGrowthActionPredictionService.band(.9), '执行条件很强');
    expect(EvidenceGrowthActionPredictionService.band(.6), '中等，仍有明显变数');
    expect(EvidenceGrowthActionPredictionService.band(.2), '较低，计划结构容易失效');
  });
}
