import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('JEV action workflow mixes noul score and choice outputs', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '明天 8:00 出门',
      'user_reported_conditions': {
        'commitment': '已经决定必须做',
        'physical_state': ['精力充足']
      }
    }, 'jev-latest');
    final questions = request['questions'] as Map;
    expect(questions, contains('start_on_time'));
    expect(questions, contains('start_eventually'));
    expect(questions, contains('complete_as_planned'));
    expect(questions, contains('hard_blocker'));
    expect(questions, contains('dominant_failure_mode'));
    expect(questions, contains('most_decisive_missing_domain'));
    for (final key in EvidenceGrowthJev.actionFactors.keys) {
      expect(questions, contains('factor_$key'));
      expect((questions['factor_$key'] as Map)['type'], 'score');
    }

    final scoreAnswer = {
      'type': 'score',
      'score': 2.8,
      'confidence': .82,
      'legend': {
        '0': 'blocks',
        '1': 'somewhat blocks',
        '2': 'neutral',
        '3': 'supports',
        '4': 'strongly supports'
      },
      'probabilities': {'0': .02, '1': .08, '2': .2, '3': .5, '4': .2}
    };
    final parsed = EvidenceGrowthJev.parseAction({
      'model': 'jev-latest',
      'answers': {
        'start_on_time': {'type': 'noul', 'noul': .72},
        'start_eventually': {'type': 'noul', 'noul': .84},
        'complete_as_planned': {'type': 'noul', 'noul': .67},
        'hard_blocker': {'type': 'noul', 'noul': .11},
        for (final key in EvidenceGrowthJev.actionFactors.keys)
          'factor_$key': scoreAnswer,
        'dominant_failure_mode': {
          'type': 'choice',
          'choice': 'decision_reopened',
          'confidence': .74,
          'probabilities': {
            'decision_reopened': .55,
            'aversive_state': .25,
            'insufficient_evidence': .2
          }
        },
        'most_decisive_missing_domain': {
          'type': 'choice',
          'choice': 'history_habit',
          'confidence': .69,
          'probabilities': {'history_habit': .6, 'none': .4}
        },
      },
      'usage': {'input_tokens': 10, 'output_tokens': 20}
    });
    expect(parsed['overall'], .72);
    expect((parsed['forecasts'] as Map)['start_eventually'], .84);
    expect((parsed['factors'] as Map)['decision_stability']['score'], .7);
    expect((parsed['factors'] as Map)['decision_stability']['confidence'], .82);
    expect((parsed['dominant_failure_mode'] as Map)['choice'],
        'decision_reopened');
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
    expect(EvidenceGrowthActionPredictionService.band(.9), '很可能按计划发生');
    expect(EvidenceGrowthActionPredictionService.band(.6), '有一定把握，但仍可能被打断');
    expect(EvidenceGrowthActionPredictionService.band(.2), '当前执行条件较弱，容易拖延或不执行');
  });
}
