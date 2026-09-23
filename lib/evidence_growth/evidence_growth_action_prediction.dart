import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
import 'evidence_growth_behavior_theories.dart';
import 'evidence_growth_jev.dart';
import 'evidence_growth_journey_models.dart';

/// AI + JEV action execution forecasting.
///
/// The headline value remains a model estimate until enough personal outcomes
/// are collected. Unknown evidence is kept neutral instead of being converted
/// into a negative signal.
class EvidenceGrowthActionPredictionService {
  EvidenceGrowthActionPredictionService({
    required EvidenceGrowthDao dao,
    UnifiedAiService? ai,
    EvidenceGrowthJev? jev,
  })  : _dao = dao,
        _ai = ai ?? UnifiedAiService(),
        _jev = jev ?? EvidenceGrowthJev();

  final EvidenceGrowthDao _dao;
  final UnifiedAiService _ai;
  final EvidenceGrowthJev _jev;

  static const historySetting = 'action_prediction_history_v1';

  /// Every score means "how much this factor supports execution".
  static const factorLabels = EvidenceGrowthJev.actionFactorLabels;
  /// Preserved predictor pool from the original work-attendance prototype.
  ///
  /// These conditions are not shown as mandatory fixed fields. The LLM
  /// selects only the ones relevant to the current action and maps each one
  /// back to the IBM construct that explains why it matters.
  static const preservedFactorCatalog = <String, GrowthData>{
    'feasibility': {
      'label': '客观可行性',
      'ibm_construct': 'environmental_constraints',
      'condition':
          'Required access, money, transport, permission and resources are actually available.'
    },
    'time_capacity': {
      'label': '时间可用性',
      'ibm_construct': 'environmental_constraints',
      'condition':
          'There is enough usable time and no schedule collision that blocks the target behavior.'
    },
    'physical_capacity': {
      'label': '身体／精力状态',
      'ibm_construct': 'perceived_control',
      'condition':
          'Current sleep, energy and physical condition are sufficient for the target behavior.'
    },
    'prerequisite_readiness': {
      'label': '前置准备完整度',
      'ibm_construct': 'environmental_constraints',
      'condition':
          'Required materials, information, route, account, permission or other prerequisites are ready.'
    },
    'commitment': {
      'label': '行动承诺强度',
      'ibm_construct': 'intention',
      'condition':
          'The person has made a sufficiently strong current decision to perform the target behavior.'
    },
    'value_salience': {
      'label': '价值／后果的临场显著性',
      'ibm_construct': 'salience',
      'condition':
          'The reason, consequence or value of acting is likely to remain salient at the critical moment.'
    },
    'emotion': {
      'label': '临场情绪支持度',
      'ibm_construct': 'experiential_attitude',
      'condition':
          'The expected immediate emotional experience supports rather than suppresses the target behavior.'
    },
    'self_efficacy': {
      'label': '自我效能',
      'ibm_construct': 'self_efficacy',
      'condition':
          'The person believes they can successfully perform the target behavior or its next required step.'
    },
    'decision_stability': {
      'label': '决策稳定性',
      'ibm_construct': 'intention',
      'condition':
          'The action decision is stable and is unlikely to be reopened without genuinely new information.'
    },
    'specificity': {
      'label': '计划具体度',
      'ibm_construct': 'implementation_intention',
      'condition':
          'The plan specifies a concrete next action, timing or context clearly enough to execute.'
    },
    'trigger': {
      'label': '启动触发清晰度',
      'ibm_construct': 'implementation_intention',
      'condition':
          'A clear cue or if-then trigger connects the critical situation to the first action.'
    },
    'preparation': {
      'label': '环境准备度',
      'ibm_construct': 'environmental_constraints',
      'condition':
          'The immediate environment is prepared so execution can begin with little setup.'
    },
    'friction': {
      'label': '现实阻力可克服性',
      'ibm_construct': 'environmental_constraints',
      'condition':
          'Distance, effort, complexity, cost and other practical friction are manageable.'
    },
    'alternatives': {
      'label': '替代行为竞争',
      'ibm_construct': 'habit',
      'condition':
          'Immediately easier, habitual or more rewarding alternatives are unlikely to displace the target behavior.'
    },
    'external_commitment': {
      'label': '外部约束／责任',
      'ibm_construct': 'injunctive_norm',
      'condition':
          'Appointments, accountability, deadlines, people waiting or immediate consequences support follow-through.'
    },
    'history_habit': {
      'label': '相似历史／习惯支持',
      'ibm_construct': 'habit',
      'condition':
          'Genuinely similar past behavior and contextual habits support the target behavior in this situation.'
    },
  };


  static const failureModeLabels = <String, String>{
    'intention_failure': '行动意向不足或尚未真正形成决定',
    'agency_failure': '自我效能或知觉控制不足',
    'knowledge_skill_gap': '知识或技能不足',
    'low_salience': '关键时刻行动没有进入注意',
    'environmental_constraint': '环境／现实约束阻断',
    'habit_competition': '既有习惯把行为拉向另一方向',
    'implementation_gap': '有意向但缺少触发执行的具体计划',
    'insufficient_evidence': '证据不足，暂时无法锁定一个机制',
    // Legacy labels are retained so old saved predictions remain readable.
    'objective_blocker': '客观条件直接阻断',
    'weak_commitment': '当前承诺强度不足',
    'aversive_state': '临场情绪／身体状态压住行动',
    'unclear_start': '不知道到点后的第一步是什么',
    'practical_friction': '现实摩擦过大',
    'competing_alternative': '更舒服的替代行为抢走行动',
    'low_self_efficacy': '预期自己做不好而不启动',
    'decision_reopened': '临场重新打开“去不去”的决定',
  };

  static const missingDomainLabels = <String, String>{
    'feasibility_resources': '客观可行性：交通、钱、权限、资源是否真的具备？',
    'time_schedule': '时间条件：起床、通勤、冲突和缓冲时间是否足够？',
    'physical_state': '身体状态：睡眠、疲劳、身体不适会不会卡住启动？',
    'commitment_value': '行动承诺：这件事现在到底有多重要、多不可退让？',
    'emotion_avoidance': '临场状态：焦虑、无趣、害怕、抵触会有多强？',
    'competition': '竞争行为：到时候最容易把你吸走的替代行为是什么？',
    'self_efficacy': '自我效能：你是否相信自己能完成第一步？',
    'decision_stability': '决策稳定性：到点会直接执行，还是重新讨论去不去？',
    'trigger_preparation': '启动条件：具体触发、第一步和提前准备是否明确？',
    'history_habit': '相似历史：过去真正类似的情境通常发生了什么？',
    'none': '目前没有一个特别关键的缺失信息域。',
  };

  Future<GrowthData> prepareAction({
    required String plan,
    DateTime? scheduledAt,
    String context = '',
    String similarHistory = '',
    String analysisCorrection = '',
    GrowthData structuredContext = const {},
    List<String> selectedTheoryIds = const [],
    bool autoSelectTheories = true,
    String jevApiKey = '',
    GrowthJourney? journey,
  }) async {
    final action = plan.trim();
    if (action.isEmpty) throw ArgumentError('请先写清楚准备做什么');
    final state = <String, dynamic>{
      'plan': action,
      'scheduled_at': scheduledAt?.toIso8601String() ?? '',
      'user_reported_conditions': structuredContext,
      'additional_notes': context.trim(),
      'similar_history_report': similarHistory.trim(),
      'analysis_correction': analysisCorrection.trim(),
      'selected_theories': autoSelectTheories
          ? <String>[]
          : _validTheoryIds(selectedTheoryIds),
      'theory_selection_mode':
          autoSelectTheories ? 'AUTO' : 'MANUAL',
      if (journey != null)
        'journey': {
          'goal': journey.title,
          'node': journey.node,
          'status': journey.status,
          'current_facts': journey.data['current'],
          'belief': journey.data['belief'],
          'plan': journey.plan,
          'next_change': journey.data['next_change'],
        },
    };
    final profile = await _interpretAction(state);
    if (profile['analysis_status'] != 'READY') return profile;

    final theorySelection = await _recommendTheories(state, profile);
    final recommendedTheoryIds =
        growthStrings(theorySelection['auto_selected_theories']);
    final finalTheoryIds = autoSelectTheories
        ? _validTheoryIds(recommendedTheoryIds)
        : _validTheoryIds(selectedTheoryIds);

    return _attachTheoryQuestionnaire(
      state,
      profile,
      selectedTheoryIds: finalTheoryIds,
      jevApiKey: jevApiKey.trim(),
      theorySelectionAnalysis: theorySelection,
      theorySelectionMode: autoSelectTheories ? 'AUTO' : 'MANUAL',
    );
  }

  Future<GrowthData> predict({
    required String plan,
    DateTime? scheduledAt,
    String context = '',
    String similarHistory = '',
    String analysisCorrection = '',
    GrowthData structuredContext = const {},
    GrowthData actionProfile = const {},
    GrowthData clarificationAnswers = const {},
    List<String> selectedTheoryIds = const [],
    GrowthData theoryFactorAnswers = const {},
    GrowthJourney? journey,
    String jevApiKey = '',
  }) async {
    final action = plan.trim();
    if (action.isEmpty) throw ArgumentError('请先写清楚接下来准备做什么');
    if (action.length > 2000 ||
        context.length > 6000 ||
        similarHistory.length > 4000) {
      throw ArgumentError('输入过长，请保留真正会影响这次行动的事实');
    }

    final records = await history();
    final allResolved = records
        .where((r) => const {
              'SUCCESS',
              'PARTIAL',
              'FAILED',
              'ON_TIME',
              'LATE',
              'NOT_DONE'
            }.contains(r['outcome']))
        .toList();

    final state = <String, dynamic>{
      'plan': action,
      'scheduled_at': scheduledAt?.toIso8601String() ?? '',
      'user_reported_conditions': structuredContext,
      'additional_notes': context.trim(),
      'similar_history_report': similarHistory.trim(),
      'analysis_correction': analysisCorrection.trim(),
      'selected_theories': _validTheoryIds(selectedTheoryIds),
      'theory_factor_answers': theoryFactorAnswers,
      if (journey != null)
        'journey': {
          'goal': journey.title,
          'node': journey.node,
          'status': journey.status,
          'current_facts': journey.data['current'],
          'belief': journey.data['belief'],
          'plan': journey.plan,
          'next_change': journey.data['next_change'],
        },
    };

    // IBM treats habit/past behavior as behavior-specific. Do not calibrate a
    // "submit report" forecast with unrelated records such as "go running".
    var profile =
        actionProfile.isEmpty ? await _interpretAction(state) : actionProfile;
    if (actionProfile.isEmpty && profile['analysis_status'] == 'READY') {
      profile = await _attachTheoryQuestionnaire(
        state,
        profile,
        selectedTheoryIds: _validTheoryIds(selectedTheoryIds),
        jevApiKey: jevApiKey.trim(),
      );
    }
    final targetMode = '${profile['action_mode'] ?? ''}'.trim();
    final targetTags = growthStrings(profile['action_tags']).toSet();

    bool similarBehavior(GrowthData row) {
      final past = growthMap(row['action_profile']);
      if (past.isEmpty) return false;
      final mode = '${past['action_mode'] ?? ''}'.trim();
      if (targetMode.isEmpty || mode != targetMode) return false;
      final tags = growthStrings(past['action_tags']).toSet();
      if (targetTags.isEmpty || tags.isEmpty) return true;
      return targetTags.any(tags.contains);
    }

    final resolved = allResolved.where(similarBehavior).toList();
    final successes = resolved
        .where((r) => const {'SUCCESS', 'ON_TIME'}.contains(r['outcome']))
        .length;
    final baseline =
        resolved.isEmpty ? null : (successes + 1) / (resolved.length + 2);

    state['action_profile'] = profile;
    state['clarification_answers'] = clarificationAnswers;
    state['selected_theories'] = _validTheoryIds(
        selectedTheoryIds.isEmpty
            ? growthStrings(profile['selected_theories'])
            : selectedTheoryIds);
    state['theory_factor_answers'] = theoryFactorAnswers;
    state['personal_history_summary'] = {
      'resolved_count': resolved.length,
      'all_resolved_count': allResolved.length,
      'success_count': successes,
      'smoothed_success_rate': baseline,
      'match_rule': 'same_action_mode_and_overlapping_tags_when_available',
      'recent': [
        for (final r in resolved.take(12))
          {
            'plan': r['plan'],
            'forecast': r['estimate'],
            'outcome': r['outcome'],
            'action_mode':
                growthMap(r['action_profile'])['action_mode'] ?? '',
          }
      ]
    };

    final ai = await _aiAssessment(state);
    GrowthData jev = {'status': 'LOCAL', 'reason': 'JEV_NOT_CONFIGURED'};
    if (jevApiKey.trim().isNotEmpty) {
      // Keep JEV independent from the LLM. It sees the same raw state but not
      // the LLM's intermediate scores or conclusions, avoiding anchoring.
      jev = await _jev.assessAction(state, apiKey: jevApiKey.trim());
    }

    final aiEstimate = _prob(ai['execution_likelihood']);
    final eventProbabilities = growthMap(jev['events']);
    final profileEvents = growthRows(profile['forecast_events']);
    final primaryEvents =
        profileEvents.where((e) => e['primary'] == true).toList();
    final primaryEvent = primaryEvents.isNotEmpty
        ? primaryEvents.first
        : (profileEvents.isNotEmpty ? profileEvents.first : <String, dynamic>{});
    final primaryEventId = '${primaryEvent['id'] ?? 'primary_success'}';
    final jevEstimate =
        _prob(eventProbabilities[primaryEventId]) ?? _prob(jev['overall']);

    // JEV is the primary forecast engine when configured because its output is
    // a typed probabilistic decision. The LLM remains an interpreter and
    // cross-check, not an equally weighted probability source.
    final rawEstimate = jevEstimate ?? aiEstimate;
    final forecastSource =
        jevEstimate != null ? 'JEV_PRIMARY' : aiEstimate != null ? 'AI_FALLBACK' : 'HISTORY_ONLY';

    double? estimate = rawEstimate;
    double historyWeight = 0;
    if (estimate != null && baseline != null && resolved.length >= 3) {
      historyWeight =
          (resolved.length / 30 * .30).clamp(0, .30).toDouble();
      estimate = estimate * (1 - historyWeight) + baseline * historyWeight;
    } else if (estimate == null && baseline != null && resolved.length >= 5) {
      estimate = baseline;
      historyWeight = 1;
    }

    final factors = <String, GrowthData>{};
    final aiFactors = growthMap(ai['factors']);
    final jevFactors = growthMap(jev['factors']);
    final activeLabels = <String, String>{};

    final requestedCore = growthStrings(profile['relevant_core_factors'])
        .where(factorLabels.containsKey)
        .toSet();
    final coreKeys = requestedCore.isEmpty
        ? factorLabels.keys.toList()
        : <String>{
            ...EvidenceGrowthJev.ibmDirectFactors,
            ...requestedCore,
            'implementation_intention',
          }.toList();
    for (final key in coreKeys) {
      activeLabels[key] = factorLabels[key]!;
    }

    final dynamicByKey = <String, GrowthData>{};
    for (final row in growthRows(profile['dynamic_factors']).take(24)) {
      final rawId = '${row['id'] ?? ''}'
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
      if (rawId.isEmpty) continue;
      final key = 'dynamic_$rawId';
      final label = '${row['label'] ?? ''}'.trim();
      if (label.isEmpty) continue;
      activeLabels[key] = label;
      dynamicByKey[key] = row;
    }

    for (final key in activeLabels.keys) {
      final aiRow = growthMap(aiFactors[key]);
      final jevRow = growthMap(jevFactors[key]);
      final a = _prob(aiRow['score']);
      final j = _prob(jevRow['score']);
      final jConfidence = _prob(jevRow['confidence']);
      final aiConfidence = _prob(aiRow['confidence']);
      final aiStatus = '${aiRow['status'] ?? 'UNKNOWN'}';
      final isDynamic = dynamicByKey.containsKey(key);
      final construct = isDynamic
          ? '${dynamicByKey[key]!['ibm_construct'] ?? 'environmental_constraints'}'
          : key;

      // Once the user has confirmed a standardized theory option, that answer
      // is direct evidence. Do not ask JEV to overwrite it with a second,
      // opaque score. Convert the ordered program option transparently to
      // 0..4 support only for factor display/risk ranking; it is NOT a
      // behavior probability and NOT a fitted theory coefficient.
      final theoryAnswer =
          isDynamic ? <String, dynamic>{} : _confirmedTheoryAnswer(construct, state);
      final theoryFactorId = '${theoryAnswer['factor_id'] ?? ''}';
      final theoryOptionId = '${theoryAnswer['option_id'] ?? ''}';
      final theoryRawScore = theoryFactorId.isEmpty
          ? null
          : EvidenceBehaviorTheoryCatalog.supportScore(
              theoryFactorId, theoryOptionId);
      final hasTheoryAnswer = theoryAnswer.isNotEmpty;
      final theoryUnknown = hasTheoryAnswer && theoryOptionId == 'unknown';

      final useTheory = hasTheoryAnswer;
      final useJev = !useTheory && j != null;
      final score = useTheory
          ? (theoryRawScore == null ? null : theoryRawScore / 4)
          : useJev
              ? j
              : a;
      final confidence = useTheory
          ? null
          : useJev
              ? jConfidence
              : aiConfidence;
      final unknown = useTheory
          ? theoryUnknown || score == null
          : score == null ||
              (useJev
                  ? (confidence ?? 0) < .45 &&
                      score >= .35 &&
                      score <= .65
                  : aiStatus == 'UNKNOWN' &&
                      (confidence == null || confidence < .5));

      final source = useTheory
          ? 'USER_CONFIRMED_THEORY'
          : useJev
              ? 'JEV'
              : a != null
                  ? 'AI'
                  : 'NONE';
      final evidenceStrength = useTheory
          ? 1.0
          : useJev
              ? (jConfidence ?? .5)
              : (aiConfidence ?? .4);

      factors[key] = {
        'label': activeLabels[key],
        'score': score,
        'display_score': unknown ? null : score,
        'confidence': confidence,
        'evidence_strength': evidenceStrength,
        'unknown': unknown,
        'source': source,
        'is_dynamic': isDynamic,
        'theory_construct': construct,
        'theory_group': _theoryGroup(construct),
        'theory_answer': theoryAnswer,
        'ai': a,
        'jev': j,
        'jev_raw_score': jevRow['raw_score'],
        'jev_probabilities': jevRow['probabilities'],
        'status': unknown
            ? 'UNKNOWN'
            : score < .45
                ? 'RISK'
                : score >= .65
                    ? 'SUPPORT'
                    : 'MIXED',
        'evidence': isDynamic
            ? _dynamicEvidence(dynamicByKey[key]!)
            : _humanEvidence(
                key, '${aiRow['evidence'] ?? ''}', state, resolved.length),
      };
    }

    final riskRows = factors.entries
        .where((e) {
          final row = e.value;
          final score = row['score'];
          final strength = row['evidence_strength'];
          return row['unknown'] != true &&
              score is num &&
              score < .5 &&
              strength is num &&
              strength.toDouble() >= .55;
        })
        .toList()
      ..sort((a, b) {
        double priority(GrowthData row) {
          final score = (row['score'] as num?)?.toDouble() ?? 1;
          final strength =
              (row['evidence_strength'] as num?)?.toDouble() ?? .5;
          return (1 - score) * strength;
        }

        return priority(b.value).compareTo(priority(a.value));
      });

    final disagreement = aiEstimate != null &&
        jevEstimate != null &&
        (aiEstimate - jevEstimate).abs() >= .20;

    final dominantFailure = growthMap(jev['dominant_failure_mode']);
    final missingQuestion =
        growthMap(jev['most_decisive_missing_question']);
    final dominantFailureKey = '${dominantFailure['choice'] ?? ''}';
    final missingQuestionKey = '${missingQuestion['choice'] ?? ''}';

    final failureCatalog = growthRows(jev['failure_mode_catalog']);
    final failureLabels = <String, String>{
      ...failureModeLabels,
      for (final row in growthRows(profile['failure_modes']))
        '${row['id'] ?? ''}': '${row['label'] ?? ''}',
      for (final row in failureCatalog)
        '${row['id'] ?? ''}': '${row['label'] ?? ''}',
    };
    final questionLabels = <String, String>{
      for (final row in growthRows(profile['clarifying_questions']))
        '${row['id'] ?? ''}': '${row['question'] ?? ''}',
    };
    final eventRows = <GrowthData>[
      for (final row in profileEvents)
        {
          ...row,
          'probability':
              _prob(eventProbabilities['${row['id'] ?? ''}']),
        }
    ];

    final improvement = growthMap(ai['improvement_scenario']);
    final improvementChanges =
        growthStrings(improvement['changes']).take(4).toList();
    final improvementAi = _prob(improvement['execution_likelihood']);
    GrowthData improvementJev = {
      'status': 'LOCAL',
      'reason': 'JEV_NOT_CONFIGURED'
    };
    if (improvementChanges.isNotEmpty &&
        jevApiKey.trim().isNotEmpty &&
        improvementAi != null) {
      improvementJev = await _jev.assessAction({
        ...state,
        'plan': '${improvement['revised_plan'] ?? action}',
        'hypothetical': true,
        'hypothetical_changes': improvementChanges,
      }, apiKey: jevApiKey.trim());
    }
    final improvementJevEstimate = _prob(improvementJev['overall']);
    final improvementModels = <double>[
      if (improvementAi != null) improvementAi,
      if (improvementJevEstimate != null) improvementJevEstimate,
    ];
    final improvementEstimate = improvementModels.isEmpty
        ? null
        : improvementModels.reduce((a, b) => a + b) /
            improvementModels.length;
    final improvementGain =
        improvementEstimate != null && estimate != null
            ? improvementEstimate - estimate
            : null;

    final id = 'ap_${DateTime.now().microsecondsSinceEpoch}';

    return {
      'id': id,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      'plan': action,
      'scheduled_at_ms': scheduledAt?.millisecondsSinceEpoch ?? 0,
      'context': context.trim(),
      'structured_context': structuredContext,
      'similar_history': similarHistory.trim(),
      'journey_id': journey?.id ?? '',
      'estimate_available': estimate != null,
      'estimate': estimate,
      'band': estimate == null ? '信息不足' : band(estimate),
      'forecast_source': forecastSource,
      'raw_model_estimate': rawEstimate,
      'forecast_provenance': {
        'primary_source': forecastSource,
        'jev_primary_event_probability': jevEstimate,
        'ai_fallback_probability': aiEstimate,
        'history_baseline': baseline,
        'history_weight': historyWeight,
        'factor_scores_are_not_probability_weights': true,
        'jev_confidence_semantics':
            'JEV confidence is model-reported confidence for its typed answer; it is not a statistical confidence interval or observed accuracy rate.',
        'theory_option_score_semantics':
            'Confirmed standardized options are transparently mapped from ordered blocker→support choices to 0..4 for factor display/ranking only; they are not fitted behavioral coefficients.',
      },
      'agreement': disagreement
          ? 'MODEL_DISAGREEMENT'
          : aiEstimate != null && jevEstimate != null
              ? 'MODEL_AGREEMENT'
              : 'SINGLE_MODEL',
      'headline': '${ai['summary'] ?? ''}'.trim(),
      'headline_reason': '${ai['headline_reason'] ?? ''}'.trim(),
      'ai': ai,
      'jev': jev,
      'action_profile': profile,
      'theory': {
        'selected_ids': growthStrings(state['selected_theories']),
        'models': EvidenceBehaviorTheoryCatalog.theoryRows(
            growthStrings(state['selected_theories'])),
        'questionnaire':
            growthRows(profile['theory_factor_questionnaire']),
        'answers': theoryFactorAnswers,
        'note':
            '理论负责定义需要观察的构念与标准选项；相同构念去重。LLM/JEV只做可审计预填，用户最终选择进入预测；原上班模型中的因素仅在理论未覆盖时作为补充。',
      },
      'theory_factor_answers': theoryFactorAnswers,
      'clarification_answers': clarificationAnswers,
      'jev_workflow': {
        'primary_event_id': primaryEventId,
        'events': eventRows,
        'hard_blocker': _prob(jev['hard_blocker']),
        'dominant_failure_mode': dominantFailureKey,
        'dominant_failure_label':
            failureLabels[dominantFailureKey] ?? dominantFailureKey,
        'dominant_failure_confidence':
            _prob(dominantFailure['confidence']),
        'dominant_failure_displayable':
            dominantFailureKey.isNotEmpty &&
                dominantFailureKey != 'insufficient_evidence' &&
                (_prob(dominantFailure['confidence']) ?? 0) >= .60,
        'dominant_failure_probabilities':
            growthMap(dominantFailure['probabilities']),
        'dominant_failure_evidence': (() {
          final rows = failureCatalog
              .where((row) => '${row['id'] ?? ''}' == dominantFailureKey)
              .toList();
          if (rows.isEmpty) return '';
          return '${rows.first['evidence'] ?? ''}';
        })(),
        'dominant_failure_source': (() {
          final rows = failureCatalog
              .where((row) => '${row['id'] ?? ''}' == dominantFailureKey)
              .toList();
          if (rows.isEmpty) return '';
          return '${rows.first['source'] ?? ''}';
        })(),
        'most_decisive_missing_question': missingQuestionKey,
        'most_decisive_missing_label':
            questionLabels[missingQuestionKey] ?? missingQuestionKey,
        'missing_question_confidence': _prob(missingQuestion['confidence']),
        'missing_question_probabilities':
            growthMap(missingQuestion['probabilities']),
      },
      'history_baseline': {
        'resolved_count': resolved.length,
        'all_resolved_count': allResolved.length,
        'success_count': successes,
        'rate': baseline,
        'weight': historyWeight,
        'behavior_specific': true,
      },
      'factors': factors,
      'top_risks': [
        for (final e in riskRows.take(3))
          {
            'key': e.key,
            'label': activeLabels[e.key],
            'score': e.value['score'],
            'source': e.value['source'],
            'evidence_strength': e.value['evidence_strength'],
            'priority':
                (1 - ((e.value['score'] as num?)?.toDouble() ?? 1)) *
                    ((e.value['evidence_strength'] as num?)?.toDouble() ?? .5),
            'evidence': e.value['evidence'],
          }
      ],
      'missing_information':
          growthStrings(ai['missing_information']).take(4).toList(),
      'failure_modes': growthStrings(ai['failure_modes']).take(4).toList(),
      'protective_actions':
          growthStrings(ai['protective_actions']).take(3).toList(),
      'improvement_scenario': {
        'revised_plan': '${improvement['revised_plan'] ?? ''}'.trim(),
        'changes': improvementChanges,
        'explanation': '${improvement['explanation'] ?? ''}'.trim(),
        'ai_estimate': improvementAi,
        'jev_estimate': improvementJevEstimate,
        'estimate': improvementEstimate,
        'gain': improvementGain,
        'is_hypothetical': true,
      },
      'calibration_note': resolved.length < 5
          ? '当前同类行动的真实结果还不足5次，所以不会拿其他类型行动硬凑个人基线；主要依赖理论结构 + AI/JEV 判断。'
          : '个人基线只使用行动类型相同、且标签相近的历史结果进行有限校准；它仍然是预测，不是保证。',
      'outcome': 'PENDING',
    };
  }

  static List<String> _validTheoryIds(Iterable<String> ids) {
    final selected = ids
        .where(EvidenceBehaviorTheoryCatalog.theories.containsKey)
        .toSet()
        .toList();
    return selected.isEmpty
        ? EvidenceBehaviorTheoryCatalog.defaultTheoryIds.toList()
        : selected;
  }

  Future<GrowthData> _recommendTheories(
      GrowthData state, GrowthData profile) async {
    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (_) {
      return _fallbackTheorySelection();
    }
    if (!config.available) return _fallbackTheorySelection();

    try {
      final theoryRows = EvidenceBehaviorTheoryCatalog.theories.values
          .map((e) => {
                'id': e['id'],
                'name': e['name'],
                'scope': e['scope'],
                'description': e['description'],
                'structure': e['structure'],
                'is_extension': e['is_extension'] == true,
              })
          .toList();

      final raw = await _ai.generateText(
        purpose: 'evidence_growth.action_interpretation.theory_selection',
        systemPrompt: '''
你是“行为预测理论路由器”。任务不是预测行为概率，而是判断当前这个具体行动最适合用哪些理论/扩展来测量与解释。

候选包括 TPB、IBM、COM-B、SCT、HAPA、IMPLEMENTATION_INTENTION。

必须遵守：
1. 目标是“最小但足够”的理论组合，而不是理论越多越好。通常自动选择1~3个；只有确有互补价值时最多4个。
2. suitability 是“这个理论对当前行动预测/诊断的适配度”，不是理论优劣，也不是行为成功概率。
3. IBM：适合通用行动预测，尤其要同时处理意向及知识技能、显著性、环境约束、习惯等意向→行为条件。
4. TPB：当态度、主观规范、知觉行为控制与意向形成是核心问题时价值高。
5. COM-B：当能力、机会、反思/自动动机中存在明显瓶颈，需要系统诊断行为条件时价值高。
6. SCT：当自我效能、技能学习、目标/自我调节、榜样学习、强化或环境互动是核心机制时价值高。
7. HAPA：主要用于健康相关行为，尤其涉及形成意向、行动/应对计划、维持、复发和恢复时价值高。普通一次性非健康任务不要因为“有计划”就选HAPA。
8. IMPLEMENTATION_INTENTION：它是意志性扩展，不是完整理论。只有“已经想做/决定做但经常没有真正启动”、需要明确情境触发和第一步时才应高适配。
9. 重叠理论不要机械同时选择。若两个理论覆盖高度重复，只保留更能解释当前问题的那个；若互补，说明各自角色。
10. 必须综合用户原始输入、补充事实、过去相似行为、AI解析出的行动类型/边界/失败机制。不要根据用户人格做无根据推断。
11. 对全部候选都给 suitability 0~1、role、reason；selected 表示是否建议自动勾选。
12. AUTO_SELECTED：selected=true 且 suitability>=0.72。若没有任何理论达到0.72，仍选择 suitability 最高的一个作为 PRIMARY。
13. 只输出JSON，不输出额外文字。
''',
        prompt: '''USER_INPUT:
${jsonEncode({
          'plan': state['plan'],
          'scheduled_at': state['scheduled_at'],
          'additional_notes': state['additional_notes'],
          'similar_history_report': state['similar_history_report'],
          'analysis_correction': state['analysis_correction'],
        })}

ACTION_PROFILE:
${jsonEncode({
          'normalized_action': profile['normalized_action'],
          'action_mode': profile['action_mode'],
          'action_tags': profile['action_tags'],
          'interpretation': profile['interpretation'],
          'selected_preserved_factors':
              profile['selected_preserved_factors'],
          'adaptive_dynamic_factors':
              profile['adaptive_dynamic_factors'],
          'failure_modes': profile['failure_modes'],
        })}

CANDIDATES:
${jsonEncode(theoryRows)}

返回：
{
  "recommendations":[
    {
      "theory_id":"IBM",
      "suitability":0.0,
      "selected":true,
      "role":"PRIMARY|COMPLEMENTARY|NOT_NEEDED",
      "reason":"最多42个中文字符",
      "matched_needs":["最多3个简短标签"]
    }
  ],
  "selection_summary":"一句话说明为什么是这个最小组合"
}''',
        expectJson: true,
        temperature: .05,
        maxTokens: 1300,
      );
      final decoded = _decode(raw);
      final recommendations = <GrowthData>[];
      for (final row in growthRows(decoded['recommendations'])) {
        final id = '${row['theory_id'] ?? ''}';
        if (!EvidenceBehaviorTheoryCatalog.theories.containsKey(id)) continue;
        final suitability = _prob(row['suitability']);
        if (suitability == null) continue;
        final role = '${row['role'] ?? 'NOT_NEEDED'}'.toUpperCase();
        recommendations.add({
          'theory_id': id,
          'suitability': suitability,
          'selected': row['selected'] == true,
          'role': const {'PRIMARY', 'COMPLEMENTARY', 'NOT_NEEDED'}
                  .contains(role)
              ? role
              : 'NOT_NEEDED',
          'reason': _cleanUserText('${row['reason'] ?? ''}'),
          'matched_needs':
              growthStrings(row['matched_needs']).take(3).toList(),
        });
      }
      if (recommendations.isEmpty) return _fallbackTheorySelection();

      recommendations.sort((a, b) =>
          ((b['suitability'] as num?)?.toDouble() ?? 0).compareTo(
              (a['suitability'] as num?)?.toDouble() ?? 0));

      var autoIds = recommendations
          .where((r) =>
              r['selected'] == true &&
              ((r['suitability'] as num?)?.toDouble() ?? 0) >= .72)
          .map((r) => '${r['theory_id']}')
          .take(4)
          .toList();

      if (autoIds.isEmpty && recommendations.isNotEmpty) {
        autoIds = ['${recommendations.first['theory_id']}'];
        recommendations.first['selected'] = true;
        recommendations.first['role'] = 'PRIMARY';
      }

      return {
        'status': 'AI',
        'auto_threshold': .72,
        'auto_selected_theories': autoIds,
        'recommendations': recommendations,
        'selection_summary':
            _cleanUserText('${decoded['selection_summary'] ?? ''}'),
      };
    } catch (_) {
      return _fallbackTheorySelection();
    }
  }

  GrowthData _fallbackTheorySelection() {
    return {
      'status': 'RULE_FALLBACK',
      'auto_threshold': .72,
      'auto_selected_theories':
          EvidenceBehaviorTheoryCatalog.defaultTheoryIds.toList(),
      'selection_summary':
          'AI理论匹配当前不可用，暂用通用组合 IBM + TPB + COM-B；用户可自行修改。',
      'recommendations': [
        {
          'theory_id': 'IBM',
          'suitability': .85,
          'selected': true,
          'role': 'PRIMARY',
          'reason': '通用行为发生预测主干',
          'matched_needs': ['意向到行为']
        },
        {
          'theory_id': 'TPB',
          'suitability': .72,
          'selected': true,
          'role': 'COMPLEMENTARY',
          'reason': '补充态度、规范与知觉控制',
          'matched_needs': ['意向形成']
        },
        {
          'theory_id': 'COM_B',
          'suitability': .72,
          'selected': true,
          'role': 'COMPLEMENTARY',
          'reason': '补充能力、机会与动机诊断',
          'matched_needs': ['行为条件']
        }
      ],
    };
  }

  Future<GrowthData> _attachTheoryQuestionnaire(
    GrowthData state,
    GrowthData profile, {
    required List<String> selectedTheoryIds,
    required String jevApiKey,
    GrowthData theorySelectionAnalysis = const {},
    String theorySelectionMode = 'MANUAL',
  }) async {
    final theories = _validTheoryIds(selectedTheoryIds);
    final factorDefs =
        EvidenceBehaviorTheoryCatalog.activeFactors(theories).toList();
    final factorIds =
        factorDefs.map((e) => '${e['id']}').where((e) => e.isNotEmpty).toList();

    final llmPrefill =
        await _aiTheoryOptionSuggestions(state, profile, theories, factorDefs);
    GrowthData jevPrefill = {'status': 'LOCAL', 'reason': 'NO_KEY'};
    if (jevApiKey.isNotEmpty && factorIds.isNotEmpty) {
      final jevState = <String, dynamic>{
        ...state,
        'action_profile': {
          'normalized_action': profile['normalized_action'],
          'action_mode': profile['action_mode'],
          'action_tags': profile['action_tags'],
          'forecast_events': profile['forecast_events'],
        },
        'selected_theories': theories,
      };
      jevPrefill = await _jev.assessTheoryOptions(
        jevState,
        factorIds,
        apiKey: jevApiKey,
      );
    }

    final llmRows = growthMap(llmPrefill['selections']);
    final jevRows = growthMap(jevPrefill['selections']);
    final questionnaire = <GrowthData>[];

    for (final factor in factorDefs) {
      final id = '${factor['id']}';
      final llm = growthMap(llmRows[id]);
      final jev = growthMap(jevRows[id]);
      final llmOption = '${llm['option_id'] ?? ''}';
      final jevOption = '${jev['option_id'] ?? ''}';
      final llmConfidence = _prob(llm['confidence']);
      final jevConfidence = _prob(jev['confidence']);
      final agree = llmOption.isNotEmpty &&
          llmOption == jevOption &&
          llmOption != 'unknown';
      final autoConfidence = agree &&
              llmConfidence != null &&
              jevConfidence != null
          ? (llmConfidence < jevConfidence ? llmConfidence : jevConfidence)
          : null;
      final autoSelected = autoConfidence != null && autoConfidence >= .75;

      final theoryIds = growthStrings(factor['theories'])
          .where(theories.contains)
          .toList();
      questionnaire.add({
        ...factor,
        'theory_ids': theoryIds,
        'llm_suggestion': llm,
        'jev_suggestion': jev,
        'auto_selected': autoSelected,
        'auto_option_id': autoSelected ? llmOption : '',
        'auto_confidence': autoConfidence,
        'auto_rule':
            'LLM与JEV选择同一选项，且双方置信度最低值≥75%时才自动选中',
      });
    }

    final coverage = EvidenceBehaviorTheoryCatalog.coverageKeys(theories);
    final selectedPreserved =
        growthRows(profile['selected_preserved_factors']);
    final supplemental = <GrowthData>[];
    final coveredPreserved = <GrowthData>[];
    for (final row in selectedPreserved) {
      final catalogId = '${row['catalog_id'] ?? ''}';
      final construct = '${row['ibm_construct'] ?? ''}';
      if (coverage.contains(catalogId) || coverage.contains(construct)) {
        coveredPreserved.add(row);
      } else {
        supplemental.add(row);
      }
    }
    final adaptive = growthRows(profile['adaptive_dynamic_factors']);

    return {
      ...profile,
      'version': 'multi_theory_action_v3',
      'theory_model': 'MULTI_THEORY_ACTION_PREDICTION_V3',
      'selected_theories': theories,
      'selected_theory_details':
          EvidenceBehaviorTheoryCatalog.theoryRows(theories),
      'theory_selection_mode': theorySelectionMode,
      'theory_selection_analysis': theorySelectionAnalysis,
      'theory_recommendations':
          growthRows(theorySelectionAnalysis['recommendations']),
      'theory_factor_questionnaire': questionnaire,
      'theory_prefill_status': {
        'llm': llmPrefill['status'] ?? 'LOCAL',
        'jev': jevPrefill['status'] ?? 'LOCAL',
        'auto_threshold': .75,
      },
      'preserved_factors_all_selected': selectedPreserved,
      'theory_covered_preserved_factors': coveredPreserved,
      'supplemental_preserved_factors': supplemental,
      'selected_preserved_factors': supplemental,
      'dynamic_factors': <GrowthData>[
        ...supplemental,
        ...adaptive,
      ],
    };
  }

  Future<GrowthData> _aiTheoryOptionSuggestions(
    GrowthData state,
    GrowthData profile,
    List<String> theoryIds,
    List<Map<String, Object?>> factors,
  ) async {
    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (_) {
      return {'status': 'LOCAL', 'reason': 'AI_CONFIG_ERROR'};
    }
    if (!config.available || factors.isEmpty) {
      return {'status': 'LOCAL', 'reason': 'AI_NOT_AVAILABLE'};
    }

    try {
      final compactFactors = [
        for (final factor in factors)
          {
            'id': factor['id'],
            'label': factor['label'],
            'question': factor['question'],
            'options': factor['options'],
          }
      ];
      final raw = await _ai.generateText(
        purpose: 'evidence_growth.action_interpretation.theory_prefill',
        systemPrompt: '''
你负责根据用户明确表达的事实，为行为预测理论问卷提供“可审计的预填建议”，不是最终预测器。

规则：
1. 只有用户原话或明确补充事实与某个选项高度匹配时才建议；不能根据人格、常识或刻板印象补全。
2. confidence表示“这段事实与该标准选项完全匹配”的把握，不是行动成功概率。
3. confidence < 0.75 仍可以给建议，但程序不会自动选中；没有足够证据的因素直接省略。
4. evidence 必须是用户输入中的短证据，最多36个中文字符。
5. option_id 必须来自该factor提供的options。
6. 这里只负责标准选项预填；理论适配已经在独立路由阶段完成。
7. 只输出JSON，尽量精炼。
''',
        prompt: '''USER_STATE:
${jsonEncode({
          'plan': state['plan'],
          'scheduled_at': state['scheduled_at'],
          'additional_notes': state['additional_notes'],
          'similar_history_report': state['similar_history_report'],
          'analysis_correction': state['analysis_correction'],
          'normalized_action': profile['normalized_action'],
          'interpretation': profile['interpretation'],
        })}

SELECTED_THEORIES:
${jsonEncode(EvidenceBehaviorTheoryCatalog.theoryRows(theoryIds))}

FACTORS:
${jsonEncode(compactFactors)}

ALL_THEORIES:
${jsonEncode(EvidenceBehaviorTheoryCatalog.theories.values
            .map((e) => {
                  'id': e['id'],
                  'name': e['name'],
                  'scope': e['scope'],
                  'description': e['description'],
                })
            .toList())}

返回：
{
  "selections":[
    {"factor_id":"","option_id":"","confidence":0.0,"evidence":""}
  ]
}''',
        expectJson: true,
        temperature: .05,
        maxTokens: 1500,
      );
      final decoded = _decode(raw);
      final selections = <String, GrowthData>{};
      for (final row in growthRows(decoded['selections']).take(40)) {
        final factorId = '${row['factor_id'] ?? ''}';
        final optionId = '${row['option_id'] ?? ''}';
        final factor = EvidenceBehaviorTheoryCatalog.factor(factorId);
        final option =
            EvidenceBehaviorTheoryCatalog.option(factorId, optionId);
        final confidence = _prob(row['confidence']);
        if (factor == null || option == null || confidence == null) continue;
        selections[factorId] = {
          'option_id': optionId,
          'confidence': confidence,
          'evidence': _cleanUserText('${row['evidence'] ?? ''}'),
          'source': 'LLM',
        };
      }
      return {
        'status': 'AI',
        'selections': selections,
      };
    } catch (_) {
      return {'status': 'LOCAL', 'reason': 'AI_PREFILL_FAILED'};
    }
  }

  Future<GrowthData> _interpretAction(GrowthData state) async {
    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (e) {
      return _fallbackActionProfile(
        state,
        reason: 'AI_CONFIG_ERROR',
        detail: _safeAnalysisError(e),
      );
    }
    if (!config.available) {
      return _fallbackActionProfile(
        state,
        reason: 'AI_NOT_CONFIGURED',
        detail: '当前统一AI配置不可用，请检查供应商、模型和API Key。',
        provider: config.provider,
        model: config.displayModel,
      );
    }

    try {
      // IMPORTANT: keep the interpretation pipeline split into several compact
      // JSON calls. Global AI settings may cap output tokens (e.g. 2200).
      // A single giant JSON response used to be truncated mid-object even
      // though the provider returned HTTP 200, which silently forced fallback.
      final coreRaw = await _ai.generateText(
        purpose: 'evidence_growth.action_interpretation.core',
        systemPrompt: '''
你是“通用行动语义解释器”的第1阶段。只负责定义行为与预测事件，不做概率预测。
使用 IBM 作为理论骨架，但这一阶段不要展开因素明细。

要求：
1. 把用户输入转成明确、可观察、可证伪的目标行为。
2. 区分 INITIATE / COMPLETE / SUSTAIN / REFRAIN / REPEAT / INTERACT / SEQUENCE / OTHER。
3. forecast_events 只给1~3个，只能一个 primary=true。
4. interpretation 2~4句，必须说明：你把用户真正要做的行动理解成什么；什么算成功；哪些边界仍未知。
5. assumptions 只放用户没明确说但你暂时采用的假设，最多4条。
6. relevant_core_factors 只从 IBM/执行意图允许构念中选。
7. analysis_checks 只输出简短覆盖项，不输出内部推理链。
8. 如果 analysis_correction 非空，必须优先吸收。
9. 只输出JSON；内容精炼，避免冗长。
''',
        prompt: '''INPUT:
${jsonEncode(state)}

允许构念：
intention,experiential_attitude,instrumental_attitude,injunctive_norm,descriptive_norm,self_efficacy,perceived_control,knowledge_skills,salience,environmental_constraints,habit,implementation_intention

返回：
{
  "normalized_action":"",
  "action_mode":"INITIATE|COMPLETE|SUSTAIN|REFRAIN|REPEAT|INTERACT|SEQUENCE|OTHER",
  "action_tags":["2~5个稳定标签"],
  "interpretation":"",
  "assumptions":[],
  "analysis_checks":[],
  "coverage_summary":"",
  "forecast_events":[
    {"id":"event_id","label":"","true_criterion":"English observable true criterion","false_criterion":"English observable false criterion","primary":true}
  ],
  "relevant_core_factors":[]
}''',
        expectJson: true,
        temperature: .05,
        maxTokens: 1500,
      );
      if (coreRaw.trim().isEmpty) {
        return _fallbackActionProfile(
          state,
          reason: 'AI_EMPTY_CORE_RESPONSE',
          detail: 'AI已响应请求，但行为理解阶段没有返回内容。',
          provider: config.provider,
          model: config.displayModel,
        );
      }
      final core = _decode(coreRaw);

      final factorRaw = await _ai.generateText(
        purpose: 'evidence_growth.action_interpretation.factors',
        systemPrompt: '''
你是“通用行动语义解释器”的第2阶段：只负责找关键预测因素，不做概率预测。

必须同时做两件事：
A. 从 PRESERVED_FACTOR_CATALOG（最早上班/到场原型的16类因素）中筛选当前行动真正相关的因素。
B. 再补充当前行动独有、旧目录没有具体覆盖好的动态因素，并映射到IBM构念。

覆盖扫描必须包括：客观可行性、时间资源、身体能力、前置准备、意向/承诺、价值/后果、情绪/回避、自我效能/控制、计划具体度、启动触发、环境准备、现实摩擦、替代行为、外部责任、相似历史/习惯，以及当前行动特有依赖。

规则：
1. 旧因素重要就必须保留，不要因为采用IBM而删除。
2. 不相关的旧因素不要硬塞。
3. 每个 selection_reason 最多28个中文字符；evidence 最多36个中文字符，必须来自用户输入，未知则空字符串。
4. dynamic_factors 最多6个；selection_reason同样简短。
5. 不得把假设写成事实。
6. 只输出JSON，严禁额外解释。
''',
        prompt: '''INPUT:
${jsonEncode(state)}

ACTION_CONTRACT:
${jsonEncode({
          'normalized_action': core['normalized_action'],
          'action_mode': core['action_mode'],
          'forecast_events': core['forecast_events'],
          'relevant_core_factors': core['relevant_core_factors'],
        })}

PRESERVED_FACTOR_CATALOG:
${jsonEncode(preservedFactorCatalog)}

返回：
{
  "selected_preserved_factors":[
    {"id":"catalog_id","selection_reason":"","evidence":""}
  ],
  "dynamic_factors":[
    {"id":"factor_id","label":"","ibm_construct":"允许构念之一","condition":"English condition supporting the primary event","selection_reason":"","evidence":""}
  ]
}''',
        expectJson: true,
        temperature: .05,
        maxTokens: 1900,
      );
      if (factorRaw.trim().isEmpty) {
        return _fallbackActionProfile(
          state,
          reason: 'AI_EMPTY_FACTOR_RESPONSE',
          detail: 'AI完成了行为理解，但关键因素选择阶段没有返回内容。',
          provider: config.provider,
          model: config.displayModel,
        );
      }
      final factorPart = _decode(factorRaw);

      final questionRaw = await _ai.generateText(
        purpose: 'evidence_growth.action_interpretation.questions',
        systemPrompt: '''
你是“通用行动语义解释器”的第3阶段：只负责找关键缺失信息与失败机制，不做概率预测。

规则：
1. clarifying_questions 最多5个，只问最可能显著改变预测的缺失事实。
2. 每一问必须具体、容易回答，并标记IBM构念。
3. failure_modes 最多5个，要针对当前具体行动，不要写泛泛的“可能失败”。
4. 不重复已经从用户输入中明确知道的事实。
5. 不把假设当事实。
6. 文本尽量简洁，只输出JSON。
''',
        prompt: '''INPUT:
${jsonEncode(state)}

ACTION_CONTRACT:
${jsonEncode({
          'normalized_action': core['normalized_action'],
          'action_mode': core['action_mode'],
          'forecast_events': core['forecast_events'],
        })}

SELECTED_FACTORS:
${jsonEncode({
          'selected_preserved_factors':
              factorPart['selected_preserved_factors'],
          'dynamic_factors': factorPart['dynamic_factors'],
        })}

返回：
{
  "clarifying_questions":[
    {"id":"missing_fact","question":"","why":"","ibm_construct":"允许构念之一","criticality":0.0,"answer_type":"text|choice","options":[]}
  ],
  "failure_modes":[
    {"id":"specific_failure","label":"","ibm_construct":"允许构念之一","criterion":"English criterion"}
  ]
}''',
        expectJson: true,
        temperature: .05,
        maxTokens: 1500,
      );
      if (questionRaw.trim().isEmpty) {
        return _fallbackActionProfile(
          state,
          reason: 'AI_EMPTY_QUESTION_RESPONSE',
          detail: 'AI已完成行为理解和因素选择，但缺失信息分析阶段没有返回内容。',
          provider: config.provider,
          model: config.displayModel,
        );
      }
      final questionPart = _decode(questionRaw);

      final decoded = <String, dynamic>{
        ...core,
        'selected_preserved_factors':
            factorPart['selected_preserved_factors'] ?? const [],
        'dynamic_factors': factorPart['dynamic_factors'] ?? const [],
        'clarifying_questions':
            questionPart['clarifying_questions'] ?? const [],
        'failure_modes': questionPart['failure_modes'] ?? const [],
      };

      final events = growthRows(decoded['forecast_events'])
          .where((e) =>
              '${e['id'] ?? ''}'.trim().isNotEmpty &&
              '${e['label'] ?? ''}'.trim().isNotEmpty &&
              '${e['true_criterion'] ?? ''}'.trim().isNotEmpty &&
              '${e['false_criterion'] ?? ''}'.trim().isNotEmpty)
          .take(4)
          .toList();
      if (events.isEmpty) {
        return _fallbackActionProfile(
          state,
          reason: 'AI_INVALID_ACTION_CONTRACT',
          detail: 'AI返回了内容，但没有生成有效的可观察预测事件。',
          provider: config.provider,
          model: config.displayModel,
        );
      }

      var primarySeen = false;
      for (final event in events) {
        if (event['primary'] == true && !primarySeen) {
          primarySeen = true;
        } else {
          event['primary'] = false;
        }
      }
      if (!primarySeen) events.first['primary'] = true;

      const allowedModes = {
        'INITIATE',
        'COMPLETE',
        'SUSTAIN',
        'REFRAIN',
        'REPEAT',
        'INTERACT',
        'SEQUENCE',
        'OTHER'
      };
      final mode = '${decoded['action_mode'] ?? 'OTHER'}'.toUpperCase();

      String profileId(Object? raw, String fallback) {
        var value = '$raw'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        while (value.startsWith('_')) {
          value = value.substring(1);
        }
        while (value.endsWith('_')) {
          value = value.substring(0, value.length - 1);
        }
        return value.isEmpty ? fallback : value;
      }

      final preservedRows = <GrowthData>[];
      final preservedSeen = <String>{};
      for (final row
          in growthRows(decoded['selected_preserved_factors']).take(16)) {
        final catalogId = profileId(row['id'], '');
        final catalog = preservedFactorCatalog[catalogId];
        if (catalog == null || !preservedSeen.add(catalogId)) continue;
        preservedRows.add({
          'id': 'preserved_$catalogId',
          'catalog_id': catalogId,
          'label': catalog['label'],
          'ibm_construct': catalog['ibm_construct'],
          'condition': catalog['condition'],
          'selection_reason':
              _cleanUserText('${row['selection_reason'] ?? ''}'),
          'evidence': _cleanUserText('${row['evidence'] ?? ''}'),
          'source': 'PRESERVED_BASELINE',
        });
      }

      final omittedPreserved = <GrowthData>[
        for (final entry in preservedFactorCatalog.entries)
          if (!preservedSeen.contains(entry.key))
            {
              'id': entry.key,
              'label': entry.value['label'],
              'ibm_construct': entry.value['ibm_construct'],
            }
      ];

      final adaptiveRows = <GrowthData>[];
      final adaptiveSeen = <String>{};
      for (final row in growthRows(decoded['dynamic_factors']).take(8)) {
        final rawId =
            profileId(row['id'], 'factor_${adaptiveRows.length + 1}');
        final id = 'adaptive_$rawId';
        final label = _cleanUserText('${row['label'] ?? ''}');
        final condition = '${row['condition'] ?? ''}'.trim();
        final construct = '${row['ibm_construct'] ?? ''}'.trim();
        if (label.isEmpty ||
            condition.isEmpty ||
            !factorLabels.containsKey(construct) ||
            !adaptiveSeen.add(id)) {
          continue;
        }
        adaptiveRows.add({
          'id': id,
          'label': label,
          'ibm_construct': construct,
          'condition': condition,
          'selection_reason':
              _cleanUserText('${row['selection_reason'] ?? ''}'),
          'evidence': _cleanUserText('${row['evidence'] ?? ''}'),
          'source': 'AI_DYNAMIC',
        });
      }

      final analysisChecks = growthStrings(decoded['analysis_checks'])
          .map(_cleanUserText)
          .where((e) => e.isNotEmpty)
          .take(8)
          .toList();
      final assumptions = growthStrings(decoded['assumptions'])
          .map(_cleanUserText)
          .where((e) => e.isNotEmpty)
          .take(6)
          .toList();

      return {
        'version': 'ibm_action_v2',
        'analysis_status': 'READY',
        'analysis_provider': config.provider,
        'analysis_model': config.displayModel,
        'analysis_error_code': '',
        'analysis_error_detail': '',
        'analysis_stages': const [
          {'id': 'core', 'label': '行为理解与成功事件', 'status': 'READY'},
          {'id': 'factors', 'label': '关键因素筛选与动态补充', 'status': 'READY'},
          {'id': 'questions', 'label': '缺失信息与失败机制', 'status': 'READY'},
        ],
        'theory_model': 'IBM_2015_PLUS_IMPLEMENTATION_INTENTION',
        'normalized_action':
            _cleanUserText('${decoded['normalized_action'] ?? ''}').isEmpty
                ? '${state['plan'] ?? ''}'.trim()
                : _cleanUserText('${decoded['normalized_action']}'),
        'action_mode': allowedModes.contains(mode) ? mode : 'OTHER',
        'action_tags': growthStrings(decoded['action_tags']).take(5).toList(),
        'interpretation':
            _cleanUserText('${decoded['interpretation'] ?? ''}'),
        'assumptions': assumptions,
        'analysis_checks': analysisChecks,
        'coverage_summary':
            _cleanUserText('${decoded['coverage_summary'] ?? ''}'),
        'analysis_correction_applied':
            '${state['analysis_correction'] ?? ''}'.trim(),
        'forecast_events': events,
        'relevant_core_factors': growthStrings(decoded['relevant_core_factors'])
            .where(factorLabels.containsKey)
            .toSet()
            .toList(),
        'selected_preserved_factors': preservedRows,
        'omitted_preserved_factors': omittedPreserved,
        'adaptive_dynamic_factors': adaptiveRows,
        'dynamic_factors': <GrowthData>[
          ...preservedRows,
          ...adaptiveRows,
        ],
        'clarifying_questions':
            growthRows(decoded['clarifying_questions']).take(5).toList(),
        'failure_modes':
            growthRows(decoded['failure_modes']).take(6).toList(),
      };
    } catch (e) {
      return _fallbackActionProfile(
        state,
        reason: 'AI_ANALYSIS_FAILED',
        detail: _safeAnalysisError(e),
        provider: config.provider,
        model: config.displayModel,
      );
    }
  }

  GrowthData _fallbackActionProfile(
    GrowthData state, {
    String reason = 'AI_UNAVAILABLE',
    String detail = '',
    String provider = '',
    String model = '',
  }) => {
        'version': 'ibm_action_v2_fallback',
        'analysis_status': 'FALLBACK',
        'analysis_provider': provider,
        'analysis_model': model,
        'analysis_error_code': reason,
        'analysis_error_detail': detail,
        'analysis_stages': const [],
        'theory_model': 'IBM_2015_PLUS_IMPLEMENTATION_INTENTION',
        'normalized_action': '${state['plan'] ?? ''}'.trim(),
        'action_mode': 'OTHER',
        'action_tags': <String>[],
        'interpretation': '按你输入的原始行动进行预测；当前无法完成更细的行为语义解析，因此保留 IBM 全部核心构念。',
        'assumptions': <String>[],
        'analysis_checks': <String>[],
        'coverage_summary': 'AI语义分析当前不可用，未动态选择原型因素；JEV只能使用通用理论构念。',
        'analysis_correction_applied':
            '${state['analysis_correction'] ?? ''}'.trim(),
        'forecast_events': [
          {
            'id': 'primary_success',
            'label': '目标行动按约定发生',
            'true_criterion':
                'The observable action described by the user occurs within the intended opportunity or horizon.',
            'false_criterion':
                'The observable action described by the user does not occur within the intended opportunity or horizon.',
            'primary': true,
          }
        ],
        'relevant_core_factors': factorLabels.keys.toList(),
        'selected_preserved_factors': <GrowthData>[],
        'omitted_preserved_factors': [
          for (final entry in preservedFactorCatalog.entries)
            {
              'id': entry.key,
              'label': entry.value['label'],
              'ibm_construct': entry.value['ibm_construct'],
            }
        ],
        'adaptive_dynamic_factors': <GrowthData>[],
        'dynamic_factors': <GrowthData>[],
        'clarifying_questions': <GrowthData>[],
        'failure_modes': <GrowthData>[],
      };

  Future<GrowthData> _aiAssessment(GrowthData state) async {
    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (_) {
      return {'status': 'LOCAL', 'reason': 'AI_CONFIG_UNAVAILABLE'};
    }
    if (!config.available) {
      return {'status': 'LOCAL', 'reason': 'AI_NOT_CONFIGURED'};
    }

    try {
      final raw = await _ai
          .generateText(
            purpose: 'evidence_growth.action_prediction',
            systemPrompt: '''
你是“行动发生可能性预测器”的结构化交叉分析器。state.selected_theories 中是用户本次选择的行为理论，state.theory_factor_answers 是用户已经确认（或修改过）的理论标准选项，这些属于一等证据。不能只套一套理论，也不能把多套理论机械平均。IBM构念仍作为兼容性的公共解释层，但不是唯一理论。目标是解释一个具体行动为什么更可能发生或不发生；不替用户做价值判断。

兼容性的IBM公共解释层：
A. 意向形成层：
- experiential_attitude：做这件事时预期的感受/情绪评价
- instrumental_attitude：对结果、收益、代价的认知评价
- injunctive_norm：重要他人认为用户应不应该做
- descriptive_norm：重要他人实际上是否做/支持这种行为
- self_efficacy：相信自己能不能做到
- perceived_control：认为这件事在多大程度上受自己控制

B. IBM 直接行为决定因素：
- intention：是否已经形成清楚而有强度的行动决定
- knowledge_skills：是否具备所需知识和技能
- salience：到关键时刻这件事是否会进入注意、保持心理可及
- environmental_constraints：资源、时间、地点、权限、第三方、身体/环境等约束是否可克服
- habit：过去相似行为和情境习惯是否支持目标行为

C. 执行意图扩展：
- implementation_intention：是否形成明确 cue→action / if-then 连接，帮助跨越 intention-behavior gap

规则：
1. 只根据 state 事实分析。未知就是未知，不能把未提供的信息当负面事实。
2. 上述每个因素 score 0-1：1=当前事实强支持主预测事件发生；0=强阻碍。不要把 score 当概率。
3. status 只能 SUPPORT / RISK / UNKNOWN。信息不足时 UNKNOWN、score≈0.5、confidence低。
4. 先读取 state.selected_theories 与 state.theory_factor_answers。用户确认的标准选项优先于模型猜测；同一构念被多个理论共享时只作为一份证据，禁止重复加权。
5. 不要把理论或因素当作平级加权平均。TPB/IBM关注意向及其前因，COM-B关注能力/机会/动机系统，SCT关注自我效能/结果预期/自我调节，HAPA区分动机与意志阶段；只有用户选中的理论才进入本次解释。
6. action_profile.dynamic_factors 是针对当前具体行为提取的显著信念/现实条件；若存在，按其理论映射理解，不创造新的心理学理论。
7. 对 personal_history_summary 只使用“同类行为匹配后的历史”；没有同类历史时 habit 保持未知。绝不能用无关行为做强校准。
8. protective_actions 必须针对最弱的理论构念给出可执行物理动作，最多3条。
9. improvement_scenario 只改变1~3个可控理论构念，并明确是情景模拟。
10. execution_likelihood 是模型交叉判断，不是统计保证；JEV配置可用时它不是最终主预测值。
11. evidence、summary、headline_reason、failure_modes、protective_actions、missing_information 用自然中文，不输出内部字段名或推理过程。
12. 只输出 JSON。
''',
            prompt: '''STATE:
${jsonEncode(state)}
返回：
{
  "summary":"一句话结论，用本次已选择理论中最关键的构念解释瓶颈",
  "headline_reason":"1-2句自然中文解释，不得出现内部字段名",
  "execution_likelihood":0.0,
  "overall_confidence":0.0,
  "factors":{
    "intention":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "experiential_attitude":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "instrumental_attitude":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "injunctive_norm":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "descriptive_norm":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "self_efficacy":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "perceived_control":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "knowledge_skills":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "salience":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "environmental_constraints":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "habit":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""},
    "implementation_intention":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""}
  },
  "dynamic_factors":{
    "dynamic_<action_profile.dynamic_factors.id>":{"score":0.5,"confidence":0.0,"status":"UNKNOWN","evidence":""}
  },
  "missing_information":["最多4个真正会改变预测的问题，优先理论关键构念"],
  "failure_modes":["最多3条具体失败路径"],
  "protective_actions":["最多3条现在就能做的具体动作"],
  "improvement_scenario":{
    "revised_plan":"更可执行的一句话",
    "changes":["最多3条，并尽量指出改善的是哪个已选择理论构念"],
    "execution_likelihood":0.0,
    "explanation":"为什么这些改变可能提高执行机会；明确只是情景模拟"
  }
}''',
            expectJson: true,
            temperature: .1,
            maxTokens: 2200,
          )
          .timeout(const Duration(seconds: 25));

      final decoded = _decode(raw);
      final likelihood = _prob(decoded['execution_likelihood']);
      if (likelihood == null) {
        throw const FormatException('INVALID_LIKELIHOOD');
      }

      final output = <String, dynamic>{};
      final inputFactors = growthMap(decoded['factors']);
      for (final key in factorLabels.keys) {
        final row = growthMap(inputFactors[key]);
        final score = _prob(row['score']);
        final confidence = _prob(row['confidence']);
        final status = '${row['status'] ?? 'UNKNOWN'}'.toUpperCase();
        if (score == null ||
            confidence == null ||
            !const {'SUPPORT', 'RISK', 'UNKNOWN'}.contains(status)) {
          throw FormatException('INVALID_FACTOR_$key');
        }
        output[key] = {
          'score': score,
          'confidence': confidence,
          'status': status,
          'evidence': '${row['evidence'] ?? ''}'.trim(),
        };
      }

      final dynamicInput = growthMap(decoded['dynamic_factors']);
      final profile = growthMap(state['action_profile']);
      for (final item in growthRows(profile['dynamic_factors'])) {
        final rawId = '${item['id'] ?? ''}'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
        if (rawId.isEmpty) continue;
        final key = 'dynamic_$rawId';
        final row = growthMap(dynamicInput[key]);
        final score = _prob(row['score']);
        final confidence = _prob(row['confidence']);
        final status = '${row['status'] ?? 'UNKNOWN'}'.toUpperCase();
        output[key] = {
          'score': score ?? .5,
          'confidence': confidence ?? 0,
          'status': const {'SUPPORT', 'RISK', 'UNKNOWN'}.contains(status)
              ? status
              : 'UNKNOWN',
          'evidence': '${row['evidence'] ?? ''}'.trim(),
        };
      }

      final scenario = growthMap(decoded['improvement_scenario']);
      final scenarioLikelihood = _prob(scenario['execution_likelihood']);

      return {
        'status': 'AI',
        'model': config.displayModel,
        'summary': _cleanUserText('${decoded['summary'] ?? ''}'),
        'headline_reason':
            _cleanUserText('${decoded['headline_reason'] ?? ''}'),
        'execution_likelihood': likelihood,
        'overall_confidence': _prob(decoded['overall_confidence']),
        'factors': output,
        'missing_information': growthStrings(decoded['missing_information'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .toList(),
        'failure_modes': growthStrings(decoded['failure_modes'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .toList(),
        'protective_actions': growthStrings(decoded['protective_actions'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .toList(),
        'improvement_scenario': {
          'revised_plan':
              _cleanUserText('${scenario['revised_plan'] ?? ''}'),
          'changes': growthStrings(scenario['changes'])
              .map(_cleanUserText)
              .where((e) => e.isNotEmpty)
              .toList(),
          'execution_likelihood': scenarioLikelihood,
          'explanation':
              _cleanUserText('${scenario['explanation'] ?? ''}'),
        },
      };
    } catch (e) {
      return {
        'status': 'LOCAL',
        'reason': e is FormatException ? e.message : 'AI_REQUEST_FAILED'
      };
    }
  }

  Future<List<GrowthData>> history() async {
    final raw = await _dao.getSetting(historySetting);
    if (raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(growthMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePrediction(GrowthData result) async {
    final rows = await history();
    rows.insert(0, result);
    if (rows.length > 100) rows.removeRange(100, rows.length);
    await _dao.setSetting(historySetting, jsonEncode(rows));
  }

  Future<void> recordOutcome(String id, String outcome) async {
    if (!const {
      'SUCCESS',
      'PARTIAL',
      'FAILED',
      'ON_TIME',
      'LATE',
      'NOT_DONE'
    }.contains(outcome)) {
      throw ArgumentError('未知结果');
    }
    final rows = await history();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index < 0) throw StateError('预测记录不存在');
    rows[index] = {
      ...rows[index],
      'outcome': outcome,
      'outcome_at_ms': DateTime.now().millisecondsSinceEpoch,
    };
    await _dao.setSetting(historySetting, jsonEncode(rows));
  }

  Future<void> clearHistory() => _dao.setSetting(historySetting, '');

  static String band(double value) {
    if (value >= .85) return '很可能按计划发生';
    if (value >= .70) return '把握较高';
    if (value >= .55) return '有一定把握，但仍可能被打断';
    if (value >= .40) return '把握偏低，先修关键阻力';
    return '当前执行条件较弱，容易拖延或不执行';
  }

  static GrowthData _decode(String raw) {
    var text = raw.trim();
    if (text.isEmpty) throw const FormatException('EMPTY_AI_RESPONSE');

    final fence = String.fromCharCodes([96, 96, 96]);
    if (text.startsWith(fence)) {
      text = text.replaceFirst(RegExp(r'^\x60\x60\x60(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*\x60\x60\x60$'), '');
    }

    try {
      final value = jsonDecode(text);
      if (value is! Map) throw const FormatException('INVALID_JSON_OBJECT');
      return growthMap(value);
    } catch (_) {
      // Some providers still prepend a short sentence even with JSON mode.
      // Extract the first balanced top-level JSON object instead of silently
      // discarding an otherwise valid LLM analysis.
      final object = _extractBalancedJsonObject(text);
      if (object == null) {
        throw const FormatException('INVALID_AI_JSON');
      }
      final value = jsonDecode(object);
      if (value is! Map) throw const FormatException('INVALID_JSON_OBJECT');
      return growthMap(value);
    }
  }

  static String? _extractBalancedJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == 92) {
          escaped = true;
        } else if (ch == 34) {
          inString = false;
        }
        continue;
      }
      if (ch == 34) {
        inString = true;
      } else if (ch == 123) {
        depth++;
      } else if (ch == 125) {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  static String _safeAnalysisError(Object error) {
    var text = error.toString().trim();
    if (text.isEmpty) return error.runtimeType.toString();
    text = text
        .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._-]+'), 'Bearer ***')
        .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]+'), 'sk-***');
    if (text.length > 240) text = '${text.substring(0, 240)}…';
    return text;
  }

  static double? _prob(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final p = value.toDouble();
    if (p < 0 || p > 1) return null;
    return p;
  }

  static String _cleanUserText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (_looksTechnical(text)) return '';
    return text;
  }

  static bool _looksTechnical(String text) {
    const tokens = [
      'similar_history_report',
      'personal_history_summary',
      'resolved_count',
      'on_time_count',
      'smoothed_on_time_rate',
      'current_context',
      'structured_context',
      'recent=[]',
      'null',
    ];
    return tokens.any(text.contains) ||
        RegExp(r'\b[a-z]+_[a-z_]+\b').hasMatch(text);
  }

  static String _theoryGroup(String construct) {
    for (final entry in EvidenceGrowthJev.actionFactorGroups.entries) {
      if (entry.value.contains(construct)) return entry.key;
    }
    return 'ACTION_SPECIFIC';
  }

  static GrowthData _confirmedTheoryAnswer(
      String construct, GrowthData state) {
    final answers = growthMap(state['theory_factor_answers']);
    if (answers.isEmpty) return {};

    final direct = growthMap(answers[construct]);
    if (direct.isNotEmpty) {
      return {
        ...direct,
        'factor_id': construct,
        'construct': construct,
      };
    }

    for (final factorId
        in EvidenceBehaviorTheoryCatalog.factorIdsForConstruct(construct)) {
      final row = growthMap(answers[factorId]);
      if (row.isEmpty) continue;
      return {
        ...row,
        'factor_id': factorId,
        'construct': construct,
      };
    }
    return {};
  }

  static String _theoryAnswerEvidence(String construct, GrowthData state) {
    final answer = _confirmedTheoryAnswer(construct, state);
    if (answer.isEmpty) return '';
    final optionId = '${answer['option_id'] ?? ''}';
    final optionLabel = '${answer['option_label'] ?? ''}'.trim();
    if (optionId == 'unknown') {
      return optionLabel.isEmpty
          ? '你在理论标准选项中明确选择了“不清楚／无法判断”。'
          : '你在理论标准选项中选择了：“$optionLabel”。';
    }
    if (optionLabel.isEmpty) return '';
    return '你在理论标准选项中已经确认：“$optionLabel”。';
  }

  static String _dynamicEvidence(GrowthData row) {
    final evidence = _cleanUserText('${row['evidence'] ?? ''}');
    if (evidence.isNotEmpty) return evidence;
    final label = '${row['label'] ?? '这个行动特有因素'}'.trim();
    final construct = '${row['ibm_construct'] ?? ''}'.trim();
    final constructLabel =
        EvidenceGrowthJev.actionFactorLabels[construct] ?? construct;
    final source = '${row['source'] ?? ''}';
    final reason = _cleanUserText('${row['selection_reason'] ?? ''}');
    final origin = source == 'PRESERVED_BASELINE'
        ? '这是从原“去上班/到场”预测模型中保留下来的关键条件'
        : '这是AI针对当前行动新增的特有条件';
    final mapping =
        constructLabel.isEmpty ? '' : '，理论上归入“$constructLabel”';
    final selected = reason.isEmpty ? '' : '。选择理由：$reason';
    return '$origin：“$label”$mapping；当前没有明确事实时保持未知$selected。';
  }

  static String _humanEvidence(
      String key, String raw, GrowthData state, int resolvedCount) {
    final theoryEvidence = _theoryAnswerEvidence(key, state);
    if (theoryEvidence.isNotEmpty) return theoryEvidence;

    final cleaned = _cleanUserText(raw);
    if (cleaned.isNotEmpty) return cleaned;

    final structured = growthMap(state['user_reported_conditions']);
    final list = (String name) => growthStrings(structured[name]);
    final history = '${state['similar_history_report'] ?? ''}'.trim();

    switch (key) {
      case 'intention':
        final commitment = '${structured['commitment'] ?? ''}'.trim();
        final stability = '${structured['decision_stability'] ?? ''}'.trim();
        if (commitment.isEmpty && stability.isEmpty) {
          return '尚未明确这件事是“想做”，还是已经形成清楚而稳定的行动决定。';
        }
        return '当前行动决定：${[commitment, stability].where((e) => e.isNotEmpty).join('；')}。';
      case 'experiential_attitude':
        final values = list('emotions');
        return values.isEmpty
            ? '尚未说明想到或临近执行这件事时的直接感受。'
            : '当前与行动相关的直接感受：${values.join('、')}。';
      case 'instrumental_attitude':
        final value = '${structured['instrumental_attitude'] ?? ''}'.trim();
        return value.isEmpty
            ? '尚未说明你如何看待做与不做这件事的结果、收益和代价。'
            : '你当前对行动结果／代价的评价：$value。';
      case 'injunctive_norm':
        final explicit = '${structured['injunctive_norm'] ?? ''}'.trim();
        final values = list('commitments');
        if (explicit.isNotEmpty) return '你感受到的重要他人期望：$explicit。';
        return values.isEmpty
            ? '尚未说明重要他人是否期待、要求或支持你做这件事。'
            : '与重要他人期望相关的事实：${values.join('、')}。';
      case 'descriptive_norm':
        final value = '${structured['descriptive_norm'] ?? ''}'.trim();
        return value.isEmpty
            ? '尚未说明与你相关的人通常会不会做这种行为；若这对当前行动不重要，会保持中性或低置信度。'
            : '你观察到的重要他人实际行为：$value。';
      case 'self_efficacy':
        final value = '${structured['self_efficacy'] ?? ''}'.trim();
        return value.isEmpty
            ? '尚未说明你相信自己能否完成这个具体行为。'
            : '你对自己完成这件事的把握：$value。';
      case 'perceived_control':
        final explicit = '${structured['perceived_control'] ?? ''}'.trim();
        if (explicit.isNotEmpty) return '你对行为控制程度的主观判断：$explicit。';
        final feasibility = list('feasibility');
        final time = list('time_capacity');
        final frictions = list('frictions');
        final known = [...feasibility, ...time, ...frictions];
        return known.isEmpty
            ? '尚未说明你认为这件事在多大程度上真正受自己控制。'
            : '会影响你知觉控制的现实条件：${known.join('、')}。';
      case 'knowledge_skills':
        final value = '${structured['knowledge_skills'] ?? ''}'.trim();
        return value.isEmpty
            ? '尚未直接说明完成该行为需要的知识或技能是否已经具备；若行动本身不需要特殊技能，这项可接近中性。'
            : '你对知识／技能准备程度的判断：$value。';
      case 'salience':
        final value = '${structured['value_salience'] ?? ''}'.trim();
        final scheduled = '${state['scheduled_at'] ?? ''}'.trim();
        final values = list('execution_support');
        if (value.isEmpty && scheduled.isEmpty && values.isEmpty) {
          return '尚未说明到了关键时刻，这件事会通过提醒、情境线索或重要后果进入注意。';
        }
        return '已有可能让行动在关键时刻保持显著的条件：${[
          if (value.isNotEmpty) value,
          if (scheduled.isNotEmpty) '已设置时间',
          ...values
        ].join('、')}。';
      case 'environmental_constraints':
        final feasibility = list('feasibility');
        final time = list('time_capacity');
        final physical = list('physical_state');
        final frictions = list('frictions');
        final known = [...feasibility, ...time, ...physical, ...frictions];
        return known.isEmpty
            ? '尚未说明资源、时间、地点、权限、第三方依赖、身体或环境是否会形成现实约束。'
            : '当前已知的环境／现实约束信息：${known.join('、')}。';
      case 'habit':
        if (history.isNotEmpty) {
          return '你提供了真正相似行为的过去经历，这比一般性的“自我感觉”更适合判断习惯支持。';
        }
        if (resolvedCount == 0) {
          return '还没有匹配到同类行动的真实结果，因此习惯／过去行为暂时保持未知。';
        }
        return '已经匹配到 $resolvedCount 次同类真实行动结果，可作为习惯与个人基线的有限证据。';
      case 'implementation_intention':
        final values = list('execution_support');
        final scheduled = '${state['scheduled_at'] ?? ''}'.trim();
        if (values.isEmpty && scheduled.isEmpty) {
          return '尚未形成清楚的“当X发生→立即做Y”的启动连接；这属于执行意图扩展，不是IBM原始构念。';
        }
        return '已有的启动线索／准备：${[
          if (scheduled.isNotEmpty) '已设置时间',
          ...values
        ].join('、')}。';
      default:
        return '这一项目前还需要更多与该具体行为直接相关的现实信息。';
    }
  }
}
