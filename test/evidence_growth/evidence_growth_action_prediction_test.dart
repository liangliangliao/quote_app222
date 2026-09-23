import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('original work-case predictor pool is preserved for dynamic reuse', () {
    final catalog =
        EvidenceGrowthActionPredictionService.preservedFactorCatalog;
    expect(catalog.length, 16);
    expect(
        catalog.keys,
        containsAll([
          'feasibility',
          'time_capacity',
          'physical_capacity',
          'prerequisite_readiness',
          'commitment',
          'value_salience',
          'emotion',
          'self_efficacy',
          'decision_stability',
          'specificity',
          'trigger',
          'preparation',
          'friction',
          'alternatives',
          'external_commitment',
          'history_habit',
        ]));
    expect(catalog['trigger']!['ibm_construct'], 'implementation_intention');
    expect(catalog['emotion']!['ibm_construct'], 'experiential_attitude');
    expect(catalog['friction']!['ibm_construct'], 'environmental_constraints');
  });

  test('JEV action workflow adapts to the interpreted action profile', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '未来7天不抽烟',
      'action_profile': {
        'forecast_events': [
          {
            'id': 'remain_abstinent',
            'label': '未来7天保持不抽烟',
            'true_criterion':
                'No smoking occurs during the next seven days.',
            'false_criterion':
                'At least one smoking episode occurs during the next seven days.',
            'primary': true,
          }
        ],
        'relevant_core_factors': [
          'intention',
          'experiential_attitude',
          'self_efficacy',
          'habit'
        ],
        'dynamic_factors': [
          {
            'id': 'smoking_cues',
            'label': '吸烟诱因暴露',
            'ibm_construct': 'environmental_constraints',
            'condition':
                'Exposure to smoking cues is low or effectively managed.',
            'evidence': ''
          }
        ],
        'clarifying_questions': [
          {
            'id': 'current_smoking_rate',
            'question': '你现在每天大约抽多少支烟？'
          }
        ],
        'failure_modes': [
          {
            'id': 'cue_triggered_lapse',
            'label': '诱因触发复吸',
            'criterion':
                'A smoking cue triggers at least one smoking episode.'
          }
        ]
      }
    }, 'jev-latest');
    final questions = request['questions'] as Map;
    expect(questions, contains('event_remain_abstinent'));
    expect(questions, contains('factor_intention'));
    expect(questions, contains('factor_habit'));
    expect(questions, contains('factor_implementation_intention'));
    expect(questions, contains('factor_dynamic_smoking_cues'));
    expect(questions, contains('dominant_failure_mode'));
    expect(questions, contains('most_decisive_missing_question'));
    expect(questions, isNot(contains('factor_injunctive_norm')));

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
        'event_remain_abstinent': {'type': 'noul', 'noul': .58},
        'hard_blocker': {'type': 'noul', 'noul': .04},
        'factor_intention': scoreAnswer,
        'factor_experiential_attitude': scoreAnswer,
        'factor_self_efficacy': scoreAnswer,
        'factor_habit': scoreAnswer,
        'factor_implementation_intention': scoreAnswer,
        'factor_dynamic_smoking_cues': scoreAnswer,
        'dominant_failure_mode': {
          'type': 'choice',
          'choice': 'cue_triggered_lapse',
          'confidence': .74,
          'probabilities': {
            'cue_triggered_lapse': .7,
            'insufficient_evidence': .3
          }
        },
        'most_decisive_missing_question': {
          'type': 'choice',
          'choice': 'current_smoking_rate',
          'confidence': .69,
          'probabilities': {'current_smoking_rate': .8, 'none': .2}
        },
      },
      'usage': {'input_tokens': 10, 'output_tokens': 20}
    });
    expect(parsed['overall'], .58);
    expect((parsed['events'] as Map)['remain_abstinent'], .58);
    expect((parsed['factors'] as Map)['dynamic_smoking_cues']['score'], .7);
    expect((parsed['dominant_failure_mode'] as Map)['choice'],
        'cue_triggered_lapse');
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
    await service.recordOutcome('p1', 'SUCCESS');

    final rows = await service.history();
    expect(rows, hasLength(1));
    expect(rows.single['outcome'], 'SUCCESS');
  });

  test('prediction bands remain descriptive rather than guaranteed', () {
    expect(EvidenceGrowthActionPredictionService.band(.9), '很可能按计划发生');
    expect(EvidenceGrowthActionPredictionService.band(.6), '有一定把握，但仍可能被打断');
    expect(EvidenceGrowthActionPredictionService.band(.2), '当前执行条件较弱，容易拖延或不执行');
  });
}
