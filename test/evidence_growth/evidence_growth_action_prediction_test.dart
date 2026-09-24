import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:quote_app/evidence_growth/evidence_growth_action_prediction.dart';
import 'package:quote_app/evidence_growth/evidence_growth_behavior_theories.dart';
import 'package:quote_app/evidence_growth/evidence_growth_dao.dart';
import 'package:quote_app/evidence_growth/evidence_growth_jev.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('theory catalog matches source-theory core constructs', () {
    List<String> factorIds(String theory) =>
        (EvidenceBehaviorTheoryCatalog.theories[theory]!['factor_ids'] as List)
            .cast<String>();

    expect(
        factorIds('TPB'),
        containsAll([
          'intention',
          'attitude_toward_behavior',
          'subjective_norm',
          'perceived_behavioral_control',
          'actual_behavioral_control',
        ]));
    expect(
        EvidenceBehaviorTheoryCatalog.theories['TPB']!['belief_basis'],
        containsAll([
          'behavioral_beliefs',
          'normative_beliefs',
          'control_beliefs'
        ]));

    expect(
        factorIds('IBM'),
        containsAll([
          'intention',
          'experiential_attitude',
          'instrumental_attitude',
          'injunctive_norm',
          'descriptive_norm',
          'self_efficacy',
          'perceived_control',
          'knowledge_skills',
          'salience',
          'environmental_constraints',
          'habit',
        ]));

    expect(
        factorIds('COM_B'),
        equals([
          'physical_capability',
          'psychological_capability',
          'physical_opportunity',
          'social_opportunity',
          'reflective_motivation',
          'automatic_motivation',
        ]));

    expect(
        factorIds('SCT'),
        containsAll([
          'behavioral_capability',
          'self_efficacy',
          'outcome_expectations',
          'outcome_value',
          'goals',
          'self_regulation',
          'observational_learning',
          'reinforcement',
          'environmental_influences',
        ]));

    expect(
        factorIds('HAPA'),
        containsAll([
          'risk_perception',
          'outcome_expectations',
          'action_self_efficacy',
          'intention',
          'action_planning',
          'coping_planning',
          'maintenance_self_efficacy',
          'recovery_self_efficacy',
          'action_control',
          'barriers_resources',
        ]));

    expect(
        factorIds('IMPLEMENTATION_INTENTION'),
        equals([
          'intention',
          'implementation_intention',
          'cue_clarity',
          'response_specificity',
        ]));
    expect(
        EvidenceBehaviorTheoryCatalog
            .theories['IMPLEMENTATION_INTENTION']!['is_extension'],
        isTrue);

    for (final theory in EvidenceBehaviorTheoryCatalog.theories.values) {
      for (final id in (theory['factor_ids'] as List).cast<String>()) {
        expect(EvidenceBehaviorTheoryCatalog.factor(id), isNotNull,
            reason: '${theory['id']} references missing factor $id');
      }
    }
  });

  test('cross-theory aliases do not collapse distinct constructs', () {
    expect(
        EvidenceBehaviorTheoryCatalog.canonicalConstruct(
            'reflective_motivation'),
        'reflective_motivation');
    expect(EvidenceBehaviorTheoryCatalog.canonicalConstruct('action_planning'),
        'action_planning');
    expect(
        EvidenceBehaviorTheoryCatalog.canonicalConstruct(
            'action_self_efficacy'),
        'action_self_efficacy');
    expect(
        EvidenceBehaviorTheoryCatalog.canonicalConstruct(
            'attitude_toward_behavior'),
        'attitude_toward_behavior');

    final cue = EvidenceBehaviorTheoryCatalog.factor('cue_clarity')!;
    final cueOptions = (cue['options'] as List)
        .map((e) => (e as Map)['id'])
        .toList();
    expect(cueOptions, isNot(contains('automatic')));
  });

  test('major behavior theory packs expose deduplicated standard factors', () {
    expect(
        EvidenceBehaviorTheoryCatalog.theories.keys,
        containsAll([
          'TPB',
          'IBM',
          'COM_B',
          'SCT',
          'HAPA',
          'IMPLEMENTATION_INTENTION'
        ]));
    final factors = EvidenceBehaviorTheoryCatalog.activeFactors(
        ['TPB', 'IBM', 'COM_B']);
    final ids = factors.map((e) => e['id']).toList();
    expect(ids.where((id) => id == 'intention').length, 1);
    expect(ids.where((id) => id == 'self_efficacy').length, 1);
    expect(ids, contains('physical_opportunity'));
    expect(
        EvidenceBehaviorTheoryCatalog.option('intention', 'firm')?['label'],
        contains('坚定'));
    expect(
        EvidenceBehaviorTheoryCatalog.coverageKeys(['IBM', 'COM_B']),
        containsAll(['feasibility', 'physical_capacity', 'history_habit']));
  });

  test('theory catalog preserves source-theory construct coverage', () {
    final allTheoryIds = EvidenceBehaviorTheoryCatalog.theories.keys.toList();
    final allFactors = EvidenceBehaviorTheoryCatalog.activeFactors(allTheoryIds);
    expect(allFactors.length, greaterThan(28));

    for (final theory in EvidenceBehaviorTheoryCatalog.theories.values) {
      final factorIds = (theory['factor_ids'] as List).cast<String>();
      for (final id in factorIds) {
        expect(EvidenceBehaviorTheoryCatalog.factor(id), isNotNull,
            reason: '${theory['id']} references missing factor $id');
      }
    }

    final tpb = EvidenceBehaviorTheoryCatalog.theories['TPB']!;
    expect((tpb['factor_ids'] as List),
        containsAll(['intention', 'attitude_toward_behavior',
          'subjective_norm', 'perceived_behavioral_control',
          'actual_behavioral_control']));
    expect((tpb['belief_basis'] as List),
        containsAll(['behavioral_beliefs', 'normative_beliefs',
          'control_beliefs']));

    final ibm = EvidenceBehaviorTheoryCatalog.theories['IBM']!;
    expect((ibm['factor_ids'] as List), containsAll([
      'intention',
      'experiential_attitude',
      'instrumental_attitude',
      'injunctive_norm',
      'descriptive_norm',
      'self_efficacy',
      'perceived_control',
      'knowledge_skills',
      'salience',
      'environmental_constraints',
      'habit',
    ]));

    final comb = EvidenceBehaviorTheoryCatalog.theories['COM_B']!;
    expect((comb['factor_ids'] as List), containsAll([
      'physical_capability',
      'psychological_capability',
      'physical_opportunity',
      'social_opportunity',
      'reflective_motivation',
      'automatic_motivation',
    ]));

    final sct = EvidenceBehaviorTheoryCatalog.theories['SCT']!;
    expect((sct['factor_ids'] as List), containsAll([
      'behavioral_capability',
      'self_efficacy',
      'outcome_expectations',
      'outcome_value',
      'goals',
      'self_regulation',
      'observational_learning',
      'reinforcement',
      'environmental_influences',
    ]));

    final hapa = EvidenceBehaviorTheoryCatalog.theories['HAPA']!;
    expect((hapa['factor_ids'] as List), containsAll([
      'risk_perception',
      'outcome_expectations',
      'action_self_efficacy',
      'intention',
      'action_planning',
      'coping_planning',
      'maintenance_self_efficacy',
      'recovery_self_efficacy',
      'action_control',
      'barriers_resources',
    ]));

    final ii =
        EvidenceBehaviorTheoryCatalog.theories['IMPLEMENTATION_INTENTION']!;
    expect(ii['is_extension'], isTrue);
    expect((ii['factor_ids'] as List), containsAll([
      'intention',
      'implementation_intention',
      'cue_clarity',
      'response_specificity',
    ]));
  });

  test('JEV theory prefill uses typed choices for theory options', () {
    final request = EvidenceGrowthJev.theoryPrefillRequest(
      {
        'plan': '明天重新去找工作',
        'additional_notes': '我已经决定要继续找，但有点害怕'
      },
      ['intention', 'self_efficacy'],
      'jev-latest',
    );
    final questions = request['questions'] as Map;
    expect((questions['theory_intention'] as Map)['type'], 'choice');
    expect((questions['theory_self_efficacy'] as Map)['type'], 'choice');
    expect(
        ((questions['theory_intention'] as Map)['criteria'] as Map),
        contains('unknown'));

    final parsed = EvidenceGrowthJev.parseTheoryPrefill({
      'model': 'jev-latest',
      'answers': {
        'theory_intention': {
          'type': 'choice',
          'choice': 'firm',
          'confidence': .84,
          'probabilities': {'firm': .84, 'clear': .12, 'unknown': .04}
        },
        'theory_self_efficacy': {
          'type': 'choice',
          'choice': 'unknown',
          'confidence': .78,
          'probabilities': {'unknown': .78, 'medium': .22}
        }
      }
    });
    final selections = parsed['selections'] as Map;
    expect(selections['intention']['option_id'], 'firm');
    expect(selections['intention']['confidence'], .84);
  });

  test('confirmed theory options use ordinal levels, not interval weights', () {
    expect(
        EvidenceBehaviorTheoryCatalog.ordinalLevel(
            'knowledge_skills', 'adequate'),
        3);
    expect(
        EvidenceBehaviorTheoryCatalog.ordinalLevel('intention', 'firm'),
        4);
    expect(
        EvidenceBehaviorTheoryCatalog.ordinalLevel('intention', 'unknown'),
        isNull);
    expect(
        EvidenceBehaviorTheoryCatalog.ordinalLevel(
            'risk_perception', 'very_high'),
        isNull,
        reason:
            'HAPA risk perception must not be forced into a monotonic support weight');
  });

  test('JEV action request explicitly honors confirmed theory answers', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '今天重新去找工作',
      'selected_theories': ['IBM'],
      'theory_factor_answers': {
        'knowledge_skills': {
          'option_id': 'adequate',
          'option_label': '基本具备',
          'confirmed_by_user': true,
        },
        'intention': {
          'option_id': 'weak',
          'option_label': '有一点想法，但随时可以不做',
          'confirmed_by_user': true,
        },
      },
      'action_profile': {
        'forecast_events': [
          {
            'id': 'restart_job_search',
            'label': '完成一次具体求职行动',
            'true_criterion': 'At least one concrete job search action occurs.',
            'false_criterion': 'No concrete job search action occurs.',
            'primary': true,
          }
        ],
        'relevant_core_factors': ['intention', 'knowledge_skills'],
        'dynamic_factors': [],
        'clarifying_questions': [],
        'failure_modes': [],
      }
    }, 'jev-latest');

    final questions = request['questions'] as Map;
    final theoreticalModels =
        ((request['state'] as Map)['theoretical_models'] as Map);
    expect('${theoreticalModels['rule']}',
        contains('Unselected theory item is missing evidence'));
    final event = questions['event_restart_job_search'] as Map;
    expect('${event['instructions']}',
        contains('do not impute a neutral score'));
    final skills = questions['factor_knowledge_skills'] as Map;
    expect('${skills['instructions']}',
        contains('explicitly confirmed the standardized option'));
    expect('${skills['instructions']}', contains('基本具备'));
    expect(questions, contains('theory_role_knowledge_skills'));
    expect(questions, contains('theory_role_intention'));
    expect(questions, contains('theory_feedback_pattern'));
    final theoryRole = questions['theory_role_intention'] as Map;
    expect(theoryRole['type'], 'choice');
    expect('${theoryRole['instructions']}',
        contains('User-confirmed option'));
    expect((theoryRole['criteria'] as Map).keys,
        containsAll([
          'key_blocker',
          'secondary_risk',
          'protective',
          'low_relevance',
          'uncertain'
        ]));

    final failure = questions['dominant_failure_mode'] as Map;
    final criteria = failure['criteria'] as Map;
    expect(criteria.keys.any((k) => '$k'.contains('theory_intention_blocker')),
        isTrue);
  });

  test('JEV bottleneck noul is limited to direct behavior and execution factors', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '明早去上班',
      'selected_theories': ['IBM'],
      'theory_factor_answers': {
        'perceived_control': {
          'option_id': 'mostly_controlled',
          'option_label': '大部分在我控制之内',
          'confirmed_by_user': true,
        },
        'intention': {
          'option_id': 'clear',
          'option_label': '已经明确决定要做',
          'confirmed_by_user': true,
        }
      },
      'action_profile': {
        'forecast_events': [
          {
            'id': 'go_work',
            'label': '按计划去上班',
            'true_criterion': 'The person goes to work as planned.',
            'false_criterion': 'The person does not go to work as planned.',
            'primary': true,
          }
        ],
        'relevant_core_factors': [
          'perceived_control',
          'intention',
          'knowledge_skills',
          'environmental_constraints'
        ],
        'dynamic_factors': [],
        'clarifying_questions': [],
        'failure_modes': [],
      }
    }, 'jev-latest');

    final questions = request['questions'] as Map;
    expect(questions, contains('evidence_perceived_control'));
    expect(questions, isNot(contains('bottleneck_perceived_control')),
        reason:
            'Perceived control is an upstream intention-formation construct; use JEV theory role rather than a direct behavior bottleneck noul.');
    expect(questions, contains('bottleneck_intention'));
    expect(questions, contains('bottleneck_knowledge_skills'));
    expect(questions, contains('bottleneck_environmental_constraints'));
    expect(questions, contains('bottleneck_implementation_intention'));
  });

  test('JEV request strips pseudo-scores and keeps unselected factors missing', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '今天重新去找工作',
      'selected_theories': ['IBM'],
      'theory_factor_answers': {
        'intention': {
          'option_id': 'clear',
          'option_label': '已经明确决定要做',
          'confirmed_by_user': true,
          'support_score': 3.0,
          'prefill_confidence': .91,
        },
      },
      'action_profile': {
        'forecast_events': [
          {
            'id': 'restart_job_search',
            'label': '完成一次具体求职行动',
            'true_criterion': 'At least one concrete job search action occurs.',
            'false_criterion': 'No concrete job search action occurs.',
            'primary': true,
          }
        ],
        'relevant_core_factors': ['intention', 'knowledge_skills'],
        'dynamic_factors': [],
        'clarifying_questions': [],
        'failure_modes': [],
      }
    }, 'jev-latest');

    final state = (request['state'] as Map)['action_prediction'] as Map;
    final answers = state['theory_factor_answers'] as Map;
    final intention = answers['intention'] as Map;
    expect(intention.containsKey('support_score'), isFalse);
    expect(intention.containsKey('prefill_confidence'), isFalse);
    expect(intention['option_id'], 'clear');

    final missing = (state['unanswered_theory_factor_ids'] as List).cast<String>();
    expect(missing, contains('knowledge_skills'));
    expect(missing, contains('habit'));

    final theoretical = (request['state'] as Map)['theoretical_models'] as Map;
    expect('${theoretical['rule']}', contains('MISSING evidence'));
  });

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
            'evidence': '饭后和同事在一起时会明显想抽烟'
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
    expect(questions, contains('evidence_intention'));
    expect(questions, contains('bottleneck_intention'));
    expect(questions, contains('evidence_dynamic_smoking_cues'));
    expect(questions, contains('bottleneck_dynamic_smoking_cues'));
    expect(questions, contains('dominant_failure_mode'));
    expect('${(questions['bottleneck_intention'] as Map)['instructions']}',
        contains('material bottleneck'));
    expect('${(questions['evidence_intention'] as Map)['instructions']}',
        contains('CURRENT EVIDENCE STATE'));
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
        'evidence_intention': {
          'type': 'choice',
          'choice': 'adverse',
          'confidence': .88,
          'probabilities': {
            'adverse': .88,
            'mixed': .08,
            'supportive': .02,
            'insufficient': .02
          }
        },
        'bottleneck_intention': {'type': 'noul', 'noul': .81},
        'evidence_dynamic_smoking_cues': {
          'type': 'choice',
          'choice': 'mixed',
          'confidence': .73,
          'probabilities': {
            'adverse': .20,
            'mixed': .73,
            'supportive': .02,
            'insufficient': .05
          }
        },
        'bottleneck_dynamic_smoking_cues': {
          'type': 'noul',
          'noul': .67
        },
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
    expect(
        (parsed['factor_evidence'] as Map)['intention']['choice'], 'adverse');
    expect((parsed['factor_bottlenecks'] as Map)['intention'], .81);
    expect(
        (parsed['factor_evidence'] as Map)['dynamic_smoking_cues']['choice'],
        'mixed');
    expect((parsed['factor_bottlenecks'] as Map)['dynamic_smoking_cues'], .67);
    expect((parsed['dominant_failure_mode'] as Map)['choice'],
        'cue_triggered_lapse');
  });

  test('JEV parses independent roles for user-confirmed theory factors', () {
    final parsed = EvidenceGrowthJev.parseAction({
      'model': 'jev-latest',
      'answers': {
        'event_primary_success': {'type': 'noul', 'noul': .42},
        'hard_blocker': {'type': 'noul', 'noul': .08},
        'theory_role_intention': {
          'type': 'choice',
          'choice': 'protective',
          'confidence': .86,
          'probabilities': {
            'protective': .86,
            'key_blocker': .04,
            'secondary_risk': .04,
            'low_relevance': .04,
            'uncertain': .02
          }
        },
        'theory_role_action_planning': {
          'type': 'choice',
          'choice': 'key_blocker',
          'confidence': .82,
          'probabilities': {
            'key_blocker': .82,
            'secondary_risk': .10,
            'protective': .02,
            'low_relevance': .02,
            'uncertain': .04
          }
        },
        'theory_feedback_pattern': {
          'type': 'choice',
          'choice': 'intention_behavior_gap',
          'confidence': .88,
          'probabilities': {
            'intention_behavior_gap': .88,
            'multi_factor_conflict': .08,
            'insufficient_evidence': .04
          }
        },
        'dominant_failure_mode': {
          'type': 'choice',
          'choice': 'insufficient_evidence',
          'confidence': .7,
          'probabilities': {'insufficient_evidence': .7}
        }
      }
    });
    final roles = parsed['theory_factor_roles'] as Map;
    expect(roles['intention']['choice'], 'protective');
    expect(roles['action_planning']['choice'], 'key_blocker');
    expect((parsed['theory_feedback_pattern'] as Map)['choice'],
        'intention_behavior_gap');
  });

  test('JEV dynamic factor selection rejects steps and rewards incremental predictors', () {
    final request = EvidenceGrowthJev.dynamicFactorSelectionRequest(
      state: {
        'plan': '明早去上班',
        'scheduled_at': '2026-09-25T08:00:00',
        'additional_notes': '闹钟响后经常继续躺着，偶尔会重新考虑要不要去',
        'similar_history_report': '过去两次都是临出门前放弃',
      },
      profile: {
        'normalized_action': '明早按时出门并到岗',
        'action_mode': 'SEQUENCE',
        'forecast_events': [
          {
            'id': 'arrive_work',
            'label': '按计划到岗',
            'true_criterion': 'The person arrives at work as planned.',
            'false_criterion': 'The person does not arrive at work as planned.',
            'primary': true,
          }
        ],
        'selected_preserved_factors': [
          {
            'id': 'preserved_time_capacity',
            'catalog_id': 'time_capacity',
            'label': '时间可用性',
            'ibm_construct': 'environmental_constraints',
          }
        ]
      },
      candidates: [
        {
          'id': 'adaptive_alarm_exit_minutes',
          'label': '响铃后固定出门时窗',
          'ibm_construct': 'implementation_intention',
          'condition': 'Leave within a fixed number of minutes after alarm.',
          'selection_reason': '把启动变具体',
          'evidence': '',
          'predictive_relevance': .72,
          'counterfactual_effect': 'MEDIUM',
          'why_not_existing_factor': '比一般执行意图更具体',
          'failure_path': '拖延导致错过出门时点',
        },
        {
          'id': 'adaptive_reopen_decision',
          'label': '临出门重新开启去不去的决策',
          'ibm_construct': 'intention',
          'condition':
              'The prior decision remains closed unless genuinely new information appears.',
          'selection_reason': '过去失败发生在临出门重新犹豫',
          'evidence': '过去两次都是临出门前放弃',
          'predictive_relevance': .92,
          'counterfactual_effect': 'LARGE',
          'why_not_existing_factor': '捕捉当前行动特有的临界时刻重新决策模式',
          'failure_path': '已经形成的意向在执行前被重新打开并被回避取代',
        }
      ],
      selectedTheoryIds: ['IBM', 'IMPLEMENTATION_INTENTION'],
      model: 'jev-latest',
    );

    final questions = request['questions'] as Map;
    expect(questions, contains('dynamic_role_candidate_1'));
    expect(questions, contains('dynamic_role_candidate_2'));
    expect(questions, contains('dynamic_primary'));
    expect(
        '${(questions['dynamic_role_candidate_1'] as Map)['instructions']}',
        contains('incremental predictive value'));

    final parsed = EvidenceGrowthJev.parseDynamicFactorSelection({
      'model': 'jev-latest',
      'answers': {
        'dynamic_role_candidate_1': {
          'type': 'choice',
          'choice': 'outcome_or_step',
          'confidence': .91,
          'probabilities': {
            'outcome_or_step': .91,
            'high_value': .02,
            'moderate_value': .03,
            'low_value': .02,
            'duplicate': .01,
            'insufficient': .01,
          }
        },
        'dynamic_role_candidate_2': {
          'type': 'choice',
          'choice': 'high_value',
          'confidence': .88,
          'probabilities': {
            'high_value': .88,
            'moderate_value': .07,
            'low_value': .01,
            'duplicate': .01,
            'outcome_or_step': .01,
            'insufficient': .02,
          }
        },
        'dynamic_primary': {
          'type': 'choice',
          'choice': 'candidate_2',
          'confidence': .86,
          'probabilities': {
            'candidate_1': .05,
            'candidate_2': .86,
            'none': .09,
          }
        },
      }
    });

    expect((parsed['roles'] as Map)['candidate_1']['choice'],
        'outcome_or_step');
    expect((parsed['roles'] as Map)['candidate_2']['choice'], 'high_value');
    expect((parsed['primary'] as Map)['choice'], 'candidate_2');
  });

  test('JEV final adjudication independently judges LLM theory conclusions', () {
    final request = EvidenceGrowthJev.theorySynthesisRequest(
      state: {
        'plan': '明早去体检',
        'scheduled_at': '2026-09-25T08:00:00',
        'selected_theories': ['HAPA', 'IMPLEMENTATION_INTENTION'],
        'theory_factor_answers': {
          'intention': {
            'option_id': 'firm',
            'option_label': '已经坚定决定要做',
            'confirmed_by_user': true,
          },
          'action_planning': {
            'option_id': 'weak',
            'option_label': '只有大概想法，没有具体安排',
            'confirmed_by_user': true,
          }
        },
        'action_profile': {
          'normalized_action': '按计划到达体检',
          'action_mode': 'INITIATE',
          'action_tags': ['体检', '到场'],
          'forecast_events': [
            {
              'id': 'attend_exam',
              'label': '按计划到达体检',
              'primary': true,
            }
          ],
          'theory_factor_questionnaire': [
            {'id': 'should_not_be_forwarded_in_final_adjudication'}
          ]
        }
      },
      theoryFeedbackRows: [
        {
          'factor_id': 'intention',
          'factor_label': '行动意向',
          'option_label': '已经坚定决定要做',
          'jev_role': 'protective',
        },
        {
          'factor_id': 'action_planning',
          'factor_label': '行动计划',
          'option_label': '只有大概想法，没有具体安排',
          'jev_role': 'key_blocker',
        }
      ],
      llmSynthesis: {
        'integrated_pattern': '意向—行为转化断裂',
        'bottom_line': '想做，但启动计划不足。',
        'core_conclusions': [
          {
            'id': 'intention_execution_gap',
            'type': 'CORE_WEAKNESS',
            'title': '意向存在，但计划不足阻断启动',
            'factor_ids': ['intention', 'action_planning'],
            'theory_ids': ['HAPA', 'IMPLEMENTATION_INTENTION'],
            'mechanism': '强意向没有被具体计划转成启动行为',
            'why_key': '解释了想做但没启动',
            'counterevidence': '',
            'correction': '形成具体行动计划',
            'review_focus': '到点是否直接启动',
          }
        ]
      },
      firstPassJev: {
        'status': 'JEV',
        'events': {'attend_exam': .44},
        'overall': .44,
        'theory_factor_roles': {
          'intention': {'choice': 'protective'},
          'action_planning': {'choice': 'key_blocker'},
        },
        'theory_feedback_pattern': {
          'choice': 'intention_behavior_gap',
          'confidence': .86,
        },
        'dominant_failure_mode': {
          'choice': 'implementation_gap',
          'confidence': .78,
        }
      },
      model: 'jev-latest',
    );

    final questions = request['questions'] as Map;
    expect(questions, contains('synthesis_event_probability'));
    expect(questions, contains('synthesis_support_candidate_1'));
    expect(questions, contains('synthesis_primary'));
    expect(questions, contains('synthesis_quality'));
    final actionState =
        ((request['state'] as Map)['action_prediction'] as Map);
    final compactProfile = actionState['action_profile'] as Map;
    expect(compactProfile, isNot(contains('theory_factor_questionnaire')));

    final parsed = EvidenceGrowthJev.parseTheorySynthesis({
      'model': 'jev-latest',
      'answers': {
        'synthesis_event_probability': {
          'type': 'noul',
          'noul': .38,
        },
        'synthesis_support_candidate_1': {
          'type': 'choice',
          'choice': 'supported',
          'confidence': .87,
          'probabilities': {
            'supported': .87,
            'partially_supported': .08,
            'contradicted': .02,
            'insufficient': .03,
          }
        },
        'synthesis_primary': {
          'type': 'choice',
          'choice': 'candidate_1',
          'confidence': .84,
          'probabilities': {'candidate_1': .84, 'none': .16}
        },
        'synthesis_quality': {
          'type': 'choice',
          'choice': 'joint_supported',
          'confidence': .82,
          'probabilities': {
            'joint_supported': .82,
            'material_disagreement': .10,
            'insufficient_evidence': .08,
          }
        },
      }
    });
    expect(parsed['final_event_probability'], .38);
    expect(
        (parsed['conclusion_verdicts'] as Map)['candidate_1']['choice'],
        'supported');
    expect((parsed['primary_conclusion'] as Map)['choice'], 'candidate_1');
    expect((parsed['synthesis_quality'] as Map)['choice'], 'joint_supported');
  });

  test('diagnostic evidence criteria keep missing separate from mixed', () {
    final request = EvidenceGrowthJev.actionRequest({
      'plan': '明早去体检',
      'selected_theories': ['IBM'],
      'theory_factor_answers': {
        'intention': {
          'option_id': 'firm',
          'option_label': '已经坚定决定要做',
          'confirmed_by_user': true,
        }
      },
      'action_profile': {
        'forecast_events': [
          {
            'id': 'attend_exam',
            'label': '按计划到达体检',
            'true_criterion': 'The person attends the exam as planned.',
            'false_criterion': 'The person does not attend the exam as planned.',
            'primary': true,
          }
        ],
        'relevant_core_factors': ['intention', 'implementation_intention'],
        'dynamic_factors': [],
        'clarifying_questions': [],
        'failure_modes': [],
      }
    }, 'jev-latest');

    final questions = request['questions'] as Map;
    final evidence = questions['evidence_intention'] as Map;
    final criteria = evidence['criteria'] as Map;
    expect(criteria.keys,
        containsAll(['adverse', 'mixed', 'supportive', 'insufficient']));
    expect('${criteria['insufficient']}', contains('Missing evidence'));
    expect('${(questions['dominant_failure_mode'] as Map)['instructions']}',
        contains('CURRENT RISK PATHWAY'));
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
      'behavior_diagnosis': {
        'theory_feedback_analysis': {
          'factor_rows': [
            {
              'factor_id': 'implementation_intention',
              'factor_label': '执行意图',
              'option_label': '没有形成明确If-Then',
              'jev_role': 'key_blocker',
            }
          ],
          'core_conclusions': [
            {
              'id': 'intention_execution_gap',
              'type': 'CORE_WEAKNESS',
              'title': '意向存在，但启动联结不足',
              'factor_ids': ['implementation_intention'],
              'theory_ids': ['IMPLEMENTATION_INTENTION'],
              'epistemic_status': 'MODERATE',
              'correction': '形成明确If-Then',
              'review_focus': '关键情境出现时是否立即启动',
            }
          ]
        },
        'key_weaknesses': [
          {
            'key': 'implementation_intention',
            'label': '启动触发',
            'classification': 'CURRENT_BOTTLENECK',
            'bottleneck_probability': .72,
            'past_recurrence_count': 0,
          }
        ],
        'review_blueprint': {
          'compare_keys': ['implementation_intention'],
          'questions': ['这次启动触发是否真的在行动断点前出现？'],
        }
      }
    });
    await service.recordOutcome('p1', 'SUCCESS');

    final rows = await service.history();
    expect(rows, hasLength(1));
    expect(rows.single['outcome'], 'SUCCESS');
    final review = rows.single['diagnostic_review'] as Map;
    expect(review['status'], 'PENDING');
    expect(review['outcome'], 'SUCCESS');
    expect((review['compare_keys'] as List),
        contains('implementation_intention'));
    expect((review['weakness_hypothesis_snapshot'] as List), hasLength(1));
    expect((review['theory_conclusion_snapshot'] as List), hasLength(1));
    expect(
        (review['theory_conclusion_snapshot'] as List).first['factor_ids'],
        contains('implementation_intention'));
    expect((review['theory_factor_snapshot'] as List), hasLength(1));
  });

  test('diagnostic model distinguishes current bottleneck from repeated weakness', () {
    expect(
        EvidenceGrowthActionPredictionService.factorProcessStageZh['intention'],
        contains('决定'));
    expect(
        EvidenceGrowthActionPredictionService
            .factorProcessStageOrder['implementation_intention'],
        greaterThan(
            EvidenceGrowthActionPredictionService
                .factorProcessStageOrder['intention']!));
    expect(
        EvidenceGrowthActionPredictionService.diagnosticDomains.keys,
        containsAll([
          'reality',
          'decision',
          'emotion',
          'value',
          'efficacy',
          'planning',
          'habit',
          'social',
          'skills',
          'history'
        ]));
  });

  test('prediction bands remain descriptive rather than guaranteed', () {
    expect(EvidenceGrowthActionPredictionService.band(.9), '很可能按计划发生');
    expect(EvidenceGrowthActionPredictionService.band(.6), '有一定把握，但仍可能被打断');
    expect(EvidenceGrowthActionPredictionService.band(.2), '当前执行条件较弱，容易拖延或不执行');
  });
}
