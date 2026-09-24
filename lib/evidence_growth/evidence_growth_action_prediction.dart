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

  /// Human-readable mechanism descriptions used by the diagnostic cards.
  /// They explain *how* a factor can matter without pretending the model has
  /// proven a hidden psychological cause.
  static const factorMechanismsZh = <String, String>{
    'intention': '决定本身不稳定时，临场更容易重新讨论“做不做”，从而让启动被取消。',
    'experiential_attitude': '临近行动时的直接厌恶、焦虑或抗拒会提高回避倾向，尤其会影响第一步启动。',
    'instrumental_attitude': '如果当下更看重成本而不是结果价值，行动在临场权衡中更容易被放弃。',
    'injunctive_norm': '重要他人的明确期待、责任或监督可能增强执行；缺失时通常不应自动视为阻碍。',
    'descriptive_norm': '身边人的实际行为可提供社会线索，但只有在当前行为确实受同伴影响时才重要。',
    'self_efficacy': '如果预期自己做不好，常见结果是延迟开始、缩小投入或直接回避第一步。',
    'perceived_control': '即使想做，若主观上觉得时间、资源或局面不受自己控制，也可能不启动。',
    'knowledge_skills': '缺少完成行为所需的知识或技能时，行动可能卡在“不知道怎么做”的具体步骤。',
    'salience': '关键时刻若目标没有进入注意，原本的决定可能被当下情绪、习惯或其他任务替代。',
    'environmental_constraints': '交通、时间、资源、权限、身体条件或第三方依赖可以直接让行为无法按计划发生。',
    'habit': '熟悉情境会自动唤起旧反应；竞争习惯越强，越容易在没有重新思考时把行动带偏。',
    'implementation_intention': '只有“想做”还不够；明确的情境→第一步连接可减少临场再次决策与拖延。',
  };

  static const factorInterventionsZh = <String, String>{
    'intention': '把决定冻结成一个不可临场重开的最小承诺，并写清什么新事实才允许改变决定。',
    'experiential_attitude': '把第一步缩小到能带着不舒服完成，并提前写好“出现抗拒也执行”的应对句。',
    'instrumental_attitude': '把做与不做的近期代价写成具体事实，在行动前只看这张对照而不重新泛化权衡。',
    'injunctive_norm': '若社会责任确实重要，可增加一个真实的预约、同伴等待或公开承诺。',
    'descriptive_norm': '若同伴行为确实影响你，选择更支持目标行为的同伴、场景或范例。',
    'self_efficacy': '把任务缩到一个你确信能完成的第一步，完成后再扩大，而不是先证明整件事都能做好。',
    'perceived_control': '把不可控部分与可控第一步分开，只对今天能控制的动作做承诺。',
    'knowledge_skills': '在行动前补齐一个最关键的知识/技能缺口，并把“学会”的判据写成可验证动作。',
    'salience': '在关键时间和地点设置外部提醒或视觉线索，让行动在需要启动时进入注意。',
    'environmental_constraints': '先清除一个真正会阻断执行的现实条件，例如路线、费用、权限、材料或时间冲突。',
    'habit': '提前移走最容易抢走行动的替代行为，并让目标行为成为默认路径。',
    'implementation_intention': '写成明确的 If-Then：当具体情境X出现，我不再讨论，立即执行第一步Y。',
  };


  /// Final diagnosis is organized as a behavior process instead of a flat
  /// list of low scores. This lets the user see where execution first breaks.
  static const factorProcessStageZh = <String, String>{
    'environmental_constraints': '现实前提',
    'knowledge_skills': '能力准备',
    'instrumental_attitude': '结果权衡',
    'experiential_attitude': '临场情绪',
    'injunctive_norm': '社会责任',
    'descriptive_norm': '社会线索',
    'self_efficacy': '能否做到',
    'perceived_control': '可控性感受',
    'intention': '决定形成／稳定',
    'implementation_intention': '启动触发',
    'salience': '关键时刻注意',
    'habit': '自动习惯／替代行为',
  };

  static const factorProcessStageOrder = <String, int>{
    'environmental_constraints': 10,
    'knowledge_skills': 20,
    'instrumental_attitude': 30,
    'experiential_attitude': 40,
    'injunctive_norm': 45,
    'descriptive_norm': 46,
    'self_efficacy': 50,
    'perceived_control': 55,
    'intention': 60,
    'implementation_intention': 70,
    'salience': 80,
    'habit': 90,
  };

  static const diagnosticDomains = <String, GrowthData>{
    'reality': {
      'label': '客观可行性／现实阻力',
      'constructs': ['environmental_constraints', 'perceived_control']
    },
    'decision': {
      'label': '行动意向／决策稳定',
      'constructs': ['intention']
    },
    'emotion': {
      'label': '临场情绪／回避',
      'constructs': ['experiential_attitude']
    },
    'value': {
      'label': '收益代价／价值显著性',
      'constructs': ['instrumental_attitude', 'salience']
    },
    'efficacy': {
      'label': '自我效能／控制感',
      'constructs': ['self_efficacy', 'perceived_control']
    },
    'planning': {
      'label': '计划具体度／启动触发',
      'constructs': ['implementation_intention']
    },
    'habit': {
      'label': '习惯／替代行为竞争',
      'constructs': ['habit']
    },
    'social': {
      'label': '重要他人／外部责任',
      'constructs': ['injunctive_norm', 'descriptive_norm']
    },
    'skills': {
      'label': '知识技能／前置准备',
      'constructs': ['knowledge_skills', 'environmental_constraints']
    },
    'history': {
      'label': '相似历史／是否反复出现',
      'constructs': ['habit']
    },
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
    bool requireJev = false,
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

    // Repeated weakness evidence must come from genuinely similar *resolved*
    // actions. A one-off current blocker is not promoted to a stable personal
    // weakness. Old records without diagnostic fields simply do not count.
    final pastDiagnosticFailures = resolved
        .where((r) => const {'FAILED', 'NOT_DONE', 'LATE', 'PARTIAL'}
            .contains(r['outcome']))
        .toList();
    final pastBarrierCounts = <String, int>{};
    final pastBarrierObserved = <String, int>{};
    for (final past in pastDiagnosticFailures) {
      final pastFactors = growthMap(past['factors']);
      for (final entry in pastFactors.entries) {
        final row = growthMap(entry.value);
        if (row.isEmpty) continue;
        pastBarrierObserved[entry.key] =
            (pastBarrierObserved[entry.key] ?? 0) + 1;
        final evidenceStatus = '${row['evidence_status'] ?? ''}';
        final bottleneck =
            (row['bottleneck_probability'] as num?)?.toDouble();
        final legacyRisk = '${row['status'] ?? ''}' == 'RISK';
        if ((const {'adverse', 'mixed'}.contains(evidenceStatus) &&
                bottleneck != null &&
                bottleneck >= .55) ||
            (bottleneck == null && legacyRisk)) {
          pastBarrierCounts[entry.key] =
              (pastBarrierCounts[entry.key] ?? 0) + 1;
        }
      }
      // Earlier saved versions may have top_risks but not factor diagnostics.
      if (pastFactors.isEmpty) {
        for (final row in growthRows(past['top_risks'])) {
          final key = '${row['key'] ?? ''}'.trim();
          if (key.isEmpty) continue;
          pastBarrierObserved[key] = (pastBarrierObserved[key] ?? 0) + 1;
          pastBarrierCounts[key] = (pastBarrierCounts[key] ?? 0) + 1;
        }
      }
    }

    state['action_profile'] = profile;
    state['clarification_answers'] = clarificationAnswers;
    state['selected_theories'] = _validTheoryIds(
        selectedTheoryIds.isEmpty
            ? growthStrings(profile['selected_theories'])
            : selectedTheoryIds);
    state['theory_factor_answers'] = theoryFactorAnswers;

    final theoryQuestionnaire =
        growthRows(profile['theory_factor_questionnaire']);
    var theoryKnownCount = 0;
    var theoryUnknownCount = 0;
    var theoryMissingCount = 0;
    for (final row in theoryQuestionnaire) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final answer = growthMap(theoryFactorAnswers[id]);
      if (answer.isEmpty) {
        theoryMissingCount++;
        continue;
      }
      if ('${answer['option_id'] ?? ''}' == 'unknown') {
        theoryUnknownCount++;
      } else {
        theoryKnownCount++;
      }
    }
    final theoryTotalCount =
        theoryKnownCount + theoryUnknownCount + theoryMissingCount;
    final theoryResponseCoverage = theoryTotalCount == 0
        ? 1.0
        : (theoryKnownCount + theoryUnknownCount) / theoryTotalCount;
    final theoryKnownEvidenceCoverage = theoryTotalCount == 0
        ? 1.0
        : theoryKnownCount / theoryTotalCount;
    state['theory_input_completeness'] = {
      'total': theoryTotalCount,
      'known_answers': theoryKnownCount,
      'explicit_unknown': theoryUnknownCount,
      'unselected_missing': theoryMissingCount,
      'response_coverage': theoryResponseCoverage,
      'known_evidence_coverage': theoryKnownEvidenceCoverage,
      'missing_rule':
          'Unselected items are missing evidence: no 0/2/4 score, no neutral imputation, and no negative penalty.'
    };

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
      // First-pass JEV remains independent from the LLM. It receives the raw
      // user-confirmed theory answers and action facts, not the LLM's
      // conclusions. A later LLM synthesis may compare both outputs.
      jev = await _jev.assessAction(state, apiKey: jevApiKey.trim());
    }

    final jevTheoryRoles = growthMap(jev['theory_factor_roles']);
    final theoryFeedbackRows = <GrowthData>[];
    for (final item in theoryQuestionnaire) {
      final factorId = '${item['id'] ?? ''}'.trim();
      if (factorId.isEmpty) continue;
      final answer = growthMap(theoryFactorAnswers[factorId]);
      if (answer.isEmpty) continue;
      final optionId = '${answer['option_id'] ?? ''}'.trim();
      final optionLabel = '${answer['option_label'] ?? ''}'.trim();
      final role = growthMap(jevTheoryRoles[factorId]);
      theoryFeedbackRows.add({
        'factor_id': factorId,
        'factor_label': item['label'],
        'question': item['question'],
        'theory_ids': growthStrings(item['theory_ids']),
        'option_id': optionId,
        'option_label': optionLabel,
        'confirmed_by_user': answer['confirmed_by_user'] == true,
        'selection_source': answer['prefill_source'] ?? 'MANUAL',
        'ordinal_level':
            EvidenceBehaviorTheoryCatalog.ordinalLevel(factorId, optionId),
        'jev_role': role['choice'] ?? '',
        'jev_role_confidence': _prob(role['confidence']),
        'jev_role_probabilities': growthMap(role['probabilities']),
      });
    }
    final theoryFeedbackSynthesis = await _synthesizeTheoryFeedback(
      state: state,
      profile: profile,
      aiAssessment: ai,
      jevAssessment: jev,
      theoryFeedbackRows: theoryFeedbackRows,
    );

    GrowthData finalJevAdjudication = {
      'status': 'LOCAL',
      'reason': jev['status'] == 'JEV'
          ? 'NOT_RUN'
          : '${jev['reason'] ?? 'FIRST_PASS_JEV_UNAVAILABLE'}',
    };
    if (jev['status'] == 'JEV' && jevApiKey.trim().isNotEmpty) {
      finalJevAdjudication = await _jev.assessTheorySynthesis(
        state: state,
        theoryFeedbackRows: theoryFeedbackRows,
        llmSynthesis: theoryFeedbackSynthesis,
        firstPassJev: jev,
        apiKey: jevApiKey.trim(),
      );
    }

    if (requireJev) {
      if (jev['status'] != 'JEV') {
        throw StateError(
            'JEV_FIRST_PASS_FAILED:${jev['reason'] ?? 'UNKNOWN'}');
      }
      if (finalJevAdjudication['status'] != 'JEV') {
        throw StateError(
            'JEV_FINAL_ADJUDICATION_FAILED:${finalJevAdjudication['reason'] ?? 'UNKNOWN'}');
      }
    }

    final adjudicationCatalog =
        growthRows(finalJevAdjudication['candidate_catalog']);
    final adjudicationVerdicts =
        growthMap(finalJevAdjudication['conclusion_verdicts']);
    final primaryAdjudication =
        growthMap(finalJevAdjudication['primary_conclusion']);
    final synthesisQuality =
        growthMap(finalJevAdjudication['synthesis_quality']);
    final catalogByKey = <String, GrowthData>{
      for (final row in adjudicationCatalog)
        if ('${row['key'] ?? ''}'.isNotEmpty) '${row['key']}': row
    };
    final llmConclusionRows =
        growthRows(theoryFeedbackSynthesis['core_conclusions']);
    final llmConclusionById = <String, GrowthData>{
      for (final row in llmConclusionRows)
        if ('${row['id'] ?? ''}'.isNotEmpty) '${row['id']}': row
    };

    final jointTheoryConclusions = <GrowthData>[];
    for (final catalog in adjudicationCatalog) {
      final key = '${catalog['key'] ?? ''}';
      final id = '${catalog['id'] ?? ''}';
      final candidate = growthMap(llmConclusionById[id]);
      if (candidate.isEmpty) continue;
      final verdict = growthMap(adjudicationVerdicts[key]);
      final choice = '${verdict['choice'] ?? ''}';
      final confidence = _prob(verdict['confidence']);
      if (!const {'supported', 'partially_supported'}.contains(choice) ||
          (confidence ?? 0) < .55) {
        continue;
      }
      jointTheoryConclusions.add({
        ...candidate,
        'jev_final_verdict': choice,
        'jev_final_confidence': confidence,
        'jev_final_probabilities': growthMap(verdict['probabilities']),
        'jointly_supported': true,
      });
    }

    final primaryCandidateKey =
        '${primaryAdjudication['choice'] ?? ''}'.trim();
    final primaryCatalog = growthMap(catalogByKey[primaryCandidateKey]);
    final primaryCandidateId = '${primaryCatalog['id'] ?? ''}'.trim();
    final primaryJointConclusion = primaryCandidateId.isEmpty
        ? <String, dynamic>{}
        : jointTheoryConclusions
            .where((row) => '${row['id'] ?? ''}' == primaryCandidateId)
            .cast<GrowthData>()
            .fold<GrowthData>(
                <String, dynamic>{},
                (previous, element) =>
                    previous.isEmpty ? element : previous);

    final jointDecisionComplete = jev['status'] == 'JEV' &&
        finalJevAdjudication['status'] == 'JEV' &&
        '${synthesisQuality['choice'] ?? ''}' == 'joint_supported';
    final jointDecisionMode = jointDecisionComplete
        ? 'LLM_JEV_JOINT'
        : jev['status'] == 'JEV' &&
                finalJevAdjudication['status'] == 'JEV'
            ? 'LLM_JEV_DISAGREEMENT_OR_INSUFFICIENT'
            : jev['status'] == 'JEV'
                ? 'JEV_FIRST_PASS_ONLY'
                : 'LLM_ONLY_DEGRADED';

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
    final finalJevEstimate =
        _prob(finalJevAdjudication['final_event_probability']);

    // The final percentage is no longer an arbitrary AI/JEV average. When the
    // JEV final adjudication succeeds, it re-evaluates the raw user input,
    // confirmed theory questionnaire, first-pass JEV judgements and LLM
    // synthesis together and emits the final typed probability. First-pass JEV
    // is only the fallback JEV probability.
    final rawEstimate = finalJevEstimate ?? jevEstimate ?? aiEstimate;
    var forecastSource = finalJevEstimate != null
        ? 'JEV_FINAL_SYNTHESIS'
        : jevEstimate != null
            ? 'JEV_PRIMARY'
            : aiEstimate != null
                ? 'AI_FALLBACK'
                : 'NO_MODEL_ESTIMATE';
    double? estimate = rawEstimate;
    double historyWeight = 0;
    if (estimate == null && baseline != null && resolved.length >= 5) {
      estimate = baseline;
      forecastSource = 'HISTORY_ONLY';
      historyWeight = 1;
    }

    final factors = <String, GrowthData>{};
    final aiFactors = growthMap(ai['factors']);
    final jevFactors = growthMap(jev['factors']);
    final jevEvidenceStates = growthMap(jev['factor_evidence']);
    final jevBottlenecks = growthMap(jev['factor_bottlenecks']);
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
      final theoryOrdinalLevel = theoryFactorId.isEmpty
          ? null
          : EvidenceBehaviorTheoryCatalog.ordinalLevel(
              theoryFactorId, theoryOptionId);
      final hasTheoryAnswer = theoryAnswer.isNotEmpty;
      final theoryUnknown = hasTheoryAnswer && theoryOptionId == 'unknown';

      final useTheory = hasTheoryAnswer;
      final useJev = !useTheory && j != null;
      final jevEvidenceRow = growthMap(jevEvidenceStates[key]);
      final jevEvidenceChoice = '${jevEvidenceRow['choice'] ?? ''}';
      final jevEvidenceConfidence = _prob(jevEvidenceRow['confidence']);
      final theoryEvidenceStatus = theoryUnknown
          ? 'insufficient'
          : theoryOrdinalLevel == null
              ? ''
              : theoryOrdinalLevel <= 1
                  ? 'adverse'
                  : theoryOrdinalLevel >= 3
                      ? 'supportive'
                      : 'mixed';
      final modelEvidenceStatus = const {
        'adverse',
        'mixed',
        'supportive',
        'insufficient'
      }.contains(jevEvidenceChoice)
          ? jevEvidenceChoice
          : aiStatus == 'RISK'
              ? 'adverse'
              : aiStatus == 'SUPPORT'
                  ? 'supportive'
                  : aiStatus == 'UNKNOWN'
                      ? 'insufficient'
                      : 'mixed';
      final evidenceStatus =
          useTheory && theoryEvidenceStatus.isNotEmpty
              ? theoryEvidenceStatus
              : modelEvidenceStatus;
      final evidenceStatusConfidence =
          useTheory && theoryEvidenceStatus.isNotEmpty
              ? 1.0
              : jevEvidenceConfidence;
      final bottleneckProbability = _prob(jevBottlenecks[key]);

      final score = useTheory
          ? (theoryOrdinalLevel == null ? null : theoryOrdinalLevel / 4)
          : useJev
              ? j
              : a;
      final confidence = useTheory
          ? null
          : useJev
              ? jConfidence
              : aiConfidence;
      final unknown = evidenceStatus == 'insufficient' ||
          (useTheory
              ? theoryUnknown || score == null
              : score == null ||
                  (useJev
                      ? (confidence ?? 0) < .45 &&
                          score >= .35 &&
                          score <= .65
                      : aiStatus == 'UNKNOWN' &&
                          (confidence == null || confidence < .5)));

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
        'evidence_status': evidenceStatus,
        'evidence_status_confidence': evidenceStatusConfidence,
        'bottleneck_probability': bottleneckProbability,
        'past_failure_observations': pastBarrierObserved[key] ?? 0,
        'past_barrier_recurrence_count': pastBarrierCounts[key] ?? 0,
        'recurrence_status': (pastBarrierCounts[key] ?? 0) >= 2
            ? 'REPEATED'
            : (pastBarrierCounts[key] ?? 0) == 1
                ? 'SEEN_ONCE'
                : 'NOT_ESTABLISHED',
        'diagnostic_role': evidenceStatus == 'insufficient'
            ? 'UNKNOWN'
            : bottleneckProbability != null &&
                    bottleneckProbability >= .60 &&
                    const {'adverse', 'mixed'}.contains(evidenceStatus)
                ? 'CURRENT_BOTTLENECK'
                : evidenceStatus == 'supportive'
                    ? 'CURRENT_SUPPORT'
                    : 'SECONDARY_OR_MIXED',
        'mechanism': isDynamic
            ? '${dynamicByKey[key]!['condition'] ?? ''}'.trim()
            : factorMechanismsZh[construct] ?? '',
        'intervention': factorInterventionsZh[construct] ?? '',
        'unknown': unknown,
        'source': source,
        'is_dynamic': isDynamic,
        'theory_construct': construct,
        'theory_group': _theoryGroup(construct),
        'theory_answer': theoryAnswer,
        'ordinal_level': theoryOrdinalLevel,
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

    int legacyRiskTier(GrowthData row) {
      if (row['source'] == 'USER_CONFIRMED_THEORY') {
        final level = row['ordinal_level'];
        if (level == 0) return 3;
        if (level == 1) return 2;
        return 0;
      }
      final score = (row['score'] as num?)?.toDouble();
      if (score == null) return 0;
      if (score <= .20) return 3;
      if (score < .50) return 2;
      return 0;
    }

    bool hasReliableEvidenceState(GrowthData row) {
      if (row['source'] == 'USER_CONFIRMED_THEORY') return true;
      final c = row['evidence_status_confidence'];
      return c is num && c.toDouble() >= .55;
    }

    final diagnosticBarrierRows = factors.entries
        .where((e) {
          final row = e.value;
          final status = '${row['evidence_status'] ?? ''}';
          final p = (row['bottleneck_probability'] as num?)?.toDouble();
          return row['unknown'] != true &&
              const {'adverse', 'mixed'}.contains(status) &&
              p != null &&
              p >= .55 &&
              hasReliableEvidenceState(row);
        })
        .toList()
      ..sort((a, b) {
        final ap =
            (a.value['bottleneck_probability'] as num?)?.toDouble() ?? 0;
        final bp =
            (b.value['bottleneck_probability'] as num?)?.toDouble() ?? 0;
        final pCompare = bp.compareTo(ap);
        if (pCompare != 0) return pCompare;
        final as =
            (a.value['evidence_status_confidence'] as num?)?.toDouble() ?? 0;
        final bs =
            (b.value['evidence_status_confidence'] as num?)?.toDouble() ?? 0;
        return bs.compareTo(as);
      });

    // When JEV diagnostics are unavailable, retain the old low-score heuristic
    // only as an explicitly marked fallback candidate list. When JEV is
    // available but does not establish a bottleneck, do not manufacture one.
    final fallbackRiskRows = jevEstimate == null
        ? (factors.entries
            .where((e) {
              final row = e.value;
              final strength = row['evidence_strength'];
              return row['unknown'] != true &&
                  legacyRiskTier(row) > 0 &&
                  strength is num &&
                  strength.toDouble() >= .55;
            })
            .toList()
          ..sort((a, b) {
            final tierCompare =
                legacyRiskTier(b.value).compareTo(legacyRiskTier(a.value));
            if (tierCompare != 0) return tierCompare;
            final as =
                (a.value['evidence_strength'] as num?)?.toDouble() ?? .5;
            final bs =
                (b.value['evidence_strength'] as num?)?.toDouble() ?? .5;
            return bs.compareTo(as);
          }))
        : <MapEntry<String, GrowthData>>[];

    final riskRows = diagnosticBarrierRows.isNotEmpty
        ? diagnosticBarrierRows
        : fallbackRiskRows;

    // "Key weakness" is stricter than "current blocker": repeated occurrence
    // in similar failed actions is considered first, then current bottleneck
    // strength. This avoids calling a one-time obstacle a personal weakness.
    final keyWeaknessRows = [...riskRows]
      ..sort((a, b) {
        final ar =
            (a.value['past_barrier_recurrence_count'] as num?)?.toInt() ?? 0;
        final br =
            (b.value['past_barrier_recurrence_count'] as num?)?.toInt() ?? 0;
        final recurringCompare = br.compareTo(ar);
        if (recurringCompare != 0) return recurringCompare;
        final ap =
            (a.value['bottleneck_probability'] as num?)?.toDouble() ?? 0;
        final bp =
            (b.value['bottleneck_probability'] as num?)?.toDouble() ?? 0;
        return bp.compareTo(ap);
      });

    final supportRows = factors.entries
        .where((e) =>
            e.value['unknown'] != true &&
            e.value['evidence_status'] == 'supportive')
        .toList()
      ..sort((a, b) {
        final av = (a.value['score'] as num?)?.toDouble() ?? 0;
        final bv = (b.value['score'] as num?)?.toDouble() ?? 0;
        return bv.compareTo(av);
      });

    final unknownRows = factors.entries
        .where((e) => e.value['evidence_status'] == 'insufficient')
        .toList()
      ..sort((a, b) {
        final ad = a.value['is_dynamic'] == true ? 1 : 0;
        final bd = b.value['is_dynamic'] == true ? 1 : 0;
        return ad.compareTo(bd);
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
    final selectedFailureRows = failureCatalog
        .where((row) => '${row['id'] ?? ''}' == dominantFailureKey)
        .toList();
    final selectedFailure =
        selectedFailureRows.isEmpty ? <String, dynamic>{} : selectedFailureRows.first;
    final dominantFailureFactorId =
        '${selectedFailure['factor_id'] ?? ''}'.trim();
    final dominantFailureConstruct = dominantFailureFactorId.isEmpty
        ? ''
        : EvidenceBehaviorTheoryCatalog
            .canonicalConstruct(dominantFailureFactorId);
    final dominantMatchesBarrier = diagnosticBarrierRows.any((entry) {
      final row = entry.value;
      final construct = '${row['theory_construct'] ?? entry.key}';
      return dominantFailureFactorId == entry.key ||
          dominantFailureFactorId == construct ||
          (dominantFailureConstruct.isNotEmpty &&
              dominantFailureConstruct == construct);
    });
    final hardBlockerProbability = _prob(jev['hard_blocker']);
    final dominantEvidenceGrounded =
        '${selectedFailure['source'] ?? ''}' == 'USER_THEORY_OPTION' ||
            dominantMatchesBarrier ||
            ((hardBlockerProbability ?? 0) >= .70 &&
                dominantFailureKey == 'environmental_constraint');
    final dominantFailureDisplayable =
        dominantFailureKey.isNotEmpty &&
            dominantFailureKey != 'insufficient_evidence' &&
            (_prob(dominantFailure['confidence']) ?? 0) >= .65 &&
            dominantEvidenceGrounded;

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
    // Keep the same source hierarchy as the main forecast. Do not create an
    // arbitrary 50/50 ensemble between AI and JEV for the hypothetical case.
    final improvementEstimate =
        improvementJevEstimate ?? improvementAi;
    final improvementGain =
        improvementEstimate != null && estimate != null
            ? improvementEstimate - estimate
            : null;

    final weaknessRows = keyWeaknessRows.take(4).toList();
    final weaknessKeys = weaknessRows.map((e) => e.key).toSet();
    final failureChainRows = [...weaknessRows]
      ..sort((a, b) {
        final ac = '${a.value['theory_construct'] ?? a.key}';
        final bc = '${b.value['theory_construct'] ?? b.key}';
        return (factorProcessStageOrder[ac] ?? 999)
            .compareTo(factorProcessStageOrder[bc] ?? 999);
      });

    final coverageRows = <GrowthData>[];
    for (final domain in diagnosticDomains.entries) {
      final constructs = growthStrings(domain.value['constructs']);
      final matched = factors.entries
          .where((e) => constructs.contains(
              '${e.value['theory_construct'] ?? e.key}'))
          .toList();
      final known = matched
          .where((e) => e.value['evidence_status'] != 'insufficient')
          .toList();
      final risk = known.any((e) => const {'adverse', 'mixed'}
          .contains('${e.value['evidence_status'] ?? ''}'));
      final support =
          known.any((e) => e.value['evidence_status'] == 'supportive');
      String status;
      if (domain.key == 'history') {
        status = pastDiagnosticFailures.isEmpty
            ? 'UNKNOWN'
            : weaknessRows.any((e) =>
                    ((e.value['past_barrier_recurrence_count'] as num?)
                            ?.toInt() ??
                        0) >=
                    2)
                ? 'RISK'
                : 'KNOWN';
      } else if (matched.isEmpty) {
        status = 'NOT_RELEVANT_OR_NOT_SELECTED';
      } else if (known.isEmpty) {
        status = 'UNKNOWN';
      } else if (risk) {
        status = 'RISK';
      } else if (support) {
        status = 'SUPPORT';
      } else {
        status = 'KNOWN';
      }
      coverageRows.add({
        'id': domain.key,
        'label': domain.value['label'],
        'status': status,
        'matched_factor_keys': matched.map((e) => e.key).toList(),
        'known_evidence_count': known.length,
      });
    }
    final knownCoverageCount = coverageRows
        .where((row) => !const {
              'UNKNOWN',
              'NOT_RELEVANT_OR_NOT_SELECTED'
            }.contains(row['status']))
        .length;
    final unknownCoverageCount =
        coverageRows.where((row) => row['status'] == 'UNKNOWN').length;

    final repeatedWeaknesses = weaknessRows
        .where((e) =>
            ((e.value['past_barrier_recurrence_count'] as num?)?.toInt() ??
                0) >=
            2)
        .toList();
    final centralWeakness = repeatedWeaknesses.isNotEmpty
        ? repeatedWeaknesses.first
        : (weaknessRows.isNotEmpty ? weaknessRows.first : null);
    final centralWeaknessLabel =
        centralWeakness == null ? '' : '${centralWeakness.value['label']}';
    final centralRepeated = centralWeakness != null &&
        ((centralWeakness.value['past_barrier_recurrence_count'] as num?)
                    ?.toInt() ??
                0) >=
            2;
    final fallbackDiagnosisHeadline = centralWeakness == null
        ? '当前证据还不足以锁定一个关键弱点；先补最关键事实，再做判断。'
        : centralRepeated
            ? '当前最值得优先改正的反复弱点：$centralWeaknessLabel'
            : '当前最值得优先验证的行动瓶颈：$centralWeaknessLabel（尚不能仅凭一次情境定义为长期弱点）';
    final theorySynthesisConclusions =
        growthRows(theoryFeedbackSynthesis['core_conclusions']);
    final theorySynthesisBottomLine =
        '${theoryFeedbackSynthesis['bottom_line'] ?? ''}'.trim();
    final theorySynthesisPattern =
        '${theoryFeedbackSynthesis['integrated_pattern'] ?? ''}'.trim();
    final primaryJointTitle =
        '${primaryJointConclusion['title'] ?? ''}'.trim();
    final diagnosisHeadline = jointDecisionComplete && primaryJointTitle.isNotEmpty
        ? primaryJointTitle
        : jointDecisionComplete && theorySynthesisBottomLine.isNotEmpty
            ? theorySynthesisBottomLine
            : !jointDecisionComplete && jev['status'] == 'JEV'
                ? 'LLM 与 JEV 尚未形成足够一致的最终结论；请查看分歧或补充证据。'
                : theorySynthesisBottomLine.isNotEmpty
                    ? 'JEV未参与最终裁决：$theorySynthesisBottomLine'
                    : fallbackDiagnosisHeadline;
    final theoryReviewFactorIds = <String>{
      for (final row in jointTheoryConclusions.isNotEmpty
          ? jointTheoryConclusions
          : theorySynthesisConclusions)
        ...growthStrings(row['factor_ids'])
    };

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
        'jev_final_synthesis_probability': finalJevEstimate,
        'jev_first_pass_status': jev['status'],
        'jev_first_pass_reason': jev['reason'],
        'jev_final_adjudication_status': finalJevAdjudication['status'],
        'jev_final_adjudication_reason': finalJevAdjudication['reason'],
        'joint_decision_mode': jointDecisionMode,
        'joint_decision_complete': jointDecisionComplete,
        'ai_fallback_probability': aiEstimate,
        'history_baseline': baseline,
        'history_weight': historyWeight,
        'posthoc_history_blend_applied': false,
        'history_usage':
            'Personal history is supplied to JEV as evidence. It is not blended a second time with an arbitrary manual weight; history-only fallback is used only when no model estimate exists and at least 5 similar outcomes are available.',
        'factor_scores_are_not_probability_weights': true,
        'jev_confidence_semantics':
            'JEV confidence is model-reported confidence for its typed answer; it is not a statistical confidence interval or observed accuracy rate.',
        'bottleneck_semantics':
            'A bottleneck noul is a model judgement that the factor is currently materially obstructive under supplied evidence. It is not a causal-effect estimate, regression coefficient, or validated probability of causation.',
        'theory_option_score_semantics':
            'Confirmed standardized options are ordinal categories (0<1<2<3<4). Adjacent distances are not assumed equal. Ordinal levels are for display/categorical blocker ordering only; they are not fitted coefficients, fixed theory weights, or behavior probabilities.',
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
      'theory_input_completeness':
          growthMap(state['theory_input_completeness']),
      'clarification_answers': clarificationAnswers,
      'jev_workflow': {
        'primary_event_id': primaryEventId,
        'events': eventRows,
        'hard_blocker': hardBlockerProbability,
        'dominant_failure_mode': dominantFailureKey,
        'dominant_failure_label':
            failureLabels[dominantFailureKey] ?? dominantFailureKey,
        'dominant_failure_confidence':
            _prob(dominantFailure['confidence']),
        'dominant_failure_displayable': dominantFailureDisplayable,
        'dominant_failure_grounded': dominantEvidenceGrounded,
        'dominant_failure_factor_id': dominantFailureFactorId,
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
            'evidence_status': e.value['evidence_status'],
            'evidence_status_confidence':
                e.value['evidence_status_confidence'],
            'bottleneck_probability': e.value['bottleneck_probability'],
            'diagnostic_role': e.value['diagnostic_role'],
            'diagnostic_basis': diagnosticBarrierRows.contains(e)
                ? 'JEV_BOTTLENECK'
                : 'LEGACY_SCORE_FALLBACK',
            'ordinal_level': e.value['ordinal_level'],
            'evidence': e.value['evidence'],
            'mechanism': e.value['mechanism'],
            'intervention': e.value['intervention'],
            'verification':
                '先只改变“${activeLabels[e.key]}”这一条件，再重新预测并记录现实结果；若执行明显改善，才更支持它是真正关键杠杆。',
          }
      ],
      'behavior_diagnosis': {
        'version': 'behavior_diagnosis_v3_theory_feedback',
        'headline': diagnosisHeadline,
        'purpose':
            '以用户亲自确认的理论关键因素为一等证据，由JEV独立判断各因素在当前行动中的角色，再由LLM综合因素之间的交互、冲突与阶段断裂；通用IBM瓶颈仅作为辅助校验。',
        'theory_feedback_analysis': {
          'status': theoryFeedbackSynthesis['status'],
          'selected_theories': growthStrings(state['selected_theories']),
          'confirmed_factor_count': theoryFeedbackRows.length,
          'factor_rows': theoryFeedbackRows,
          'jev_integrated_pattern':
              growthMap(jev['theory_feedback_pattern']),
          'llm_integrated_pattern': theorySynthesisPattern,
          'pattern_explanation':
              theoryFeedbackSynthesis['pattern_explanation'],
          'bottom_line': theorySynthesisBottomLine,
          'llm_candidate_conclusions': theorySynthesisConclusions,
          'jev_final_adjudication': finalJevAdjudication,
          'joint_decision_mode': jointDecisionMode,
          'joint_decision_complete': jointDecisionComplete,
          'joint_conclusions': jointTheoryConclusions,
          'primary_joint_conclusion': primaryJointConclusion,
          'synthesis_quality': synthesisQuality,
          'core_conclusions': jointDecisionComplete
              ? jointTheoryConclusions
              : <GrowthData>[],
          'interactions':
              growthRows(theoryFeedbackSynthesis['interactions']),
          'unknowns': growthStrings(theoryFeedbackSynthesis['unknowns']),
          'rule':
              '用户确认的理论选项是一等证据。LLM先生成跨因素综合候选；JEV在最终阶段独立裁决每个候选，只有JEV支持且联合质量判定为joint_supported的结论才会升级为正式联合结论。JEV失败或与LLM显著分歧时，不再伪装成“LLM+JEV最终结论”。',
        },
        'key_weaknesses': [
          for (final e in weaknessRows)
            {
              'key': e.key,
              'label': e.value['label'],
              'construct': e.value['theory_construct'],
              'stage': factorProcessStageZh[
                      '${e.value['theory_construct'] ?? e.key}'] ??
                  '行动过程',
              'classification':
                  ((e.value['past_barrier_recurrence_count'] as num?)
                                  ?.toInt() ??
                              0) >=
                          2
                      ? 'RECURRING_WEAKNESS'
                      : 'CURRENT_BOTTLENECK',
              'current_evidence': e.value['evidence'],
              'evidence_status': e.value['evidence_status'],
              'bottleneck_probability':
                  e.value['bottleneck_probability'],
              'past_failure_observations':
                  e.value['past_failure_observations'],
              'past_recurrence_count':
                  e.value['past_barrier_recurrence_count'],
              'mechanism': e.value['mechanism'],
              'correction': e.value['intervention'],
              'review_question':
                  '现实结果出来后检查：这次“${e.value['label']}”是否真的在行动断点前出现？若已经改善，行动是否随之改善？',
              'falsifier':
                  '如果这一条件已经明显改善但行动仍然失败，或多次失败时它都没有出现，就应降低它作为关键弱点的优先级。',
            }
        ],
        'failure_chain': [
          for (var i = 0; i < failureChainRows.length; i++)
            {
              'order': i + 1,
              'factor_key': failureChainRows[i].key,
              'stage': factorProcessStageZh[
                      '${failureChainRows[i].value['theory_construct'] ?? failureChainRows[i].key}'] ??
                  '行动过程',
              'label': failureChainRows[i].value['label'],
              'evidence': failureChainRows[i].value['evidence'],
              'mechanism': failureChainRows[i].value['mechanism'],
            }
        ],
        'coverage': coverageRows,
        'coverage_summary': {
          'domains_scanned': coverageRows.length,
          'domains_with_evidence': knownCoverageCount,
          'domains_unknown': unknownCoverageCount,
          'note':
              '“全面”指这些诊断域都被扫描；没有事实的域明确保留为未知，而不是由模型猜测补齐。',
        },
        'protective_factors': [
          for (final e in supportRows.take(4))
            {
              'key': e.key,
              'label': e.value['label'],
              'evidence': e.value['evidence'],
              'mechanism': e.value['mechanism'],
            }
        ],
        'review_blueprint': {
          'compare_keys': <String>{...theoryReviewFactorIds, ...weaknessKeys}.toList(),
          'questions': [
            '结果：目标行动最终是按计划发生、延迟、部分完成，还是没有发生？',
            if (theorySynthesisConclusions.isNotEmpty)
              '理论结论验证：哪些用户确认因素真的在行动前发挥了作用——${theorySynthesisConclusions.take(3).map((e) => e['title']).join('；')}？',
            if (weaknessRows.isNotEmpty)
              '断点：最先出现问题的是哪一个环节——${weaknessRows.map((e) => e.value['label']).join('、')}，还是一个当前未识别的新因素？',
            for (final row in theorySynthesisConclusions.take(3))
              if ('${row['review_focus'] ?? ''}'.trim().isNotEmpty)
                '${row['review_focus']}',
            '机制：失败前发生了什么具体事件、念头、感受或现实阻力？不要只记录“我不想做”。',
            '干预：本次是否真正执行了针对综合结论中的关键抓手？',
            '更新：现实结果支持、削弱还是推翻了当前“关键弱点/因素交互”假设？',
          ],
          'update_rule':
              '复盘不是证明模型正确，而是用现实结果更新弱点假设；连续反复出现才逐步升级为稳定模式。',
        },
      },
      'diagnostic_summary': {
        'version': 'evidence_bottleneck_v1',
        'rule':
            '关键阻碍不再按“最低分”直接排序。JEV必须同时判断：当前存在不利/混合证据，并且该因素足以构成主预测事件的现实瓶颈；缺失证据不会被当作阻碍。',
        'barrier_count': diagnosticBarrierRows.length,
        'uses_jev_bottleneck_judgement': jevEstimate != null,
        'supports': [
          for (final e in supportRows.take(3))
            {
              'key': e.key,
              'label': activeLabels[e.key],
              'evidence': e.value['evidence'],
              'mechanism': e.value['mechanism'],
              'source': e.value['source'],
            }
        ],
        'unknowns': [
          for (final e in unknownRows.take(3))
            {
              'key': e.key,
              'label': activeLabels[e.key],
              'evidence': e.value['evidence'],
              'mechanism': e.value['mechanism'],
              'next_check':
                  '补充一个关于“${activeLabels[e.key]}”的具体事实后再判断，不用猜。',
            }
        ],
      },
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
          ? '当前同类行动真实结果不足5次；个人历史仅作为模型可见的有限证据，不做人工加权。'
          : '同类个人历史已作为JEV输入证据；程序不再用未经验证的固定权重把历史基线二次混入概率，避免重复计算。',
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
12. AUTO_SELECTED：selected=true 且 suitability>=0.75。若没有任何理论达到0.72，仍选择 suitability 最高的一个作为 PRIMARY。
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
              ((r['suitability'] as num?)?.toDouble() ?? 0) >= .75)
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
        'auto_threshold': .75,
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
      'auto_threshold': .75,
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
          'suitability': .75,
          'selected': true,
          'role': 'COMPLEMENTARY',
          'reason': '补充态度、规范与知觉控制',
          'matched_needs': ['意向形成']
        },
        {
          'theory_id': 'COM_B',
          'suitability': .75,
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

  Future<GrowthData> _synthesizeTheoryFeedback({
    required GrowthData state,
    required GrowthData profile,
    required GrowthData aiAssessment,
    required GrowthData jevAssessment,
    required List<GrowthData> theoryFeedbackRows,
  }) async {
    if (theoryFeedbackRows.isEmpty) {
      return {
        'status': 'LOCAL',
        'reason': 'NO_CONFIRMED_THEORY_FEEDBACK',
        'integrated_pattern': '',
        'core_conclusions': <GrowthData>[],
        'interactions': <GrowthData>[],
        'unknowns': <String>[],
      };
    }

    final selectedTheoryIds = growthStrings(state['selected_theories']);
    final theoryDetails =
        EvidenceBehaviorTheoryCatalog.theoryRows(selectedTheoryIds);
    final jevPattern = growthMap(jevAssessment['theory_feedback_pattern']);

    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (_) {
      return _localTheoryFeedbackSynthesis(
        theoryFeedbackRows,
        jevPattern: jevPattern,
        reason: 'AI_CONFIG_UNAVAILABLE',
      );
    }
    if (!config.available) {
      return _localTheoryFeedbackSynthesis(
        theoryFeedbackRows,
        jevPattern: jevPattern,
        reason: 'AI_NOT_CONFIGURED',
      );
    }

    try {
      final raw = await _ai.generateText(
        purpose: 'evidence_growth.action_prediction.theory_feedback_synthesis',
        systemPrompt: '''
你是“行为理论反馈综合诊断器”。你的核心任务不是重新给问卷打分，而是基于用户已经亲自确认的理论关键因素，结合JEV独立typed判断和当前行动事实，形成对“为什么这次行动容易成功/失败”的综合结论。

证据优先级：
1. 用户确认的 theory factor option 是一等证据，不能被LLM/JEV改写成相反选项。
2. JEV theory role 是对该已确认因素在当前行动中的角色判断，可用于判断它更像关键阻碍、次要风险、保护因素或低相关；JEV不是因果真理。
3. selection_source 只表示选项最初来自手动选择还是LLM+JEV预填；用户提交后的选项才进入这里。预填置信度本身不是行为证据，禁止拿它当权重。
4. 用户原始行动事实、相似历史和已确认补充信息。
5. 第一阶段LLM分析只能作为交叉解释，不能覆盖以上证据。

必须做到：
- 保留各理论自己的结构。TPB、IBM、COM-B、SCT、HAPA、执行意图不能全部压成IBM字段。
- 真正“综合”多个因素：优先寻找因素之间的组合关系、矛盾和阶段断裂，而不是逐项复述问卷。
- 典型但非强制模式包括：意向强但计划/行动控制弱；反思性动机强但自动性动机拉向相反方向；能力够但机会不足；结果价值高但自我效能低；能启动但维持/恢复机制弱。
- 同一个心理构念被多个理论重复测量时，只作为同一证据链的交叉支持，禁止机械重复计数。
- “关键弱点”必须说明：哪些用户确认因素共同支持、JEV是否一致、为什么它能解释当前行为断点、有什么反证/替代解释。
- 不把一次状态写成人格标签；使用“当前模式/本次关键弱点假设/反复模式（仅有历史证据时）”。
- 必须给后续改正和复盘留下可验证项。
- 如果证据冲突或不足，要明确写出来，不强行得出单一结论。
- 不输出隐藏推理过程，只输出结构化结论。
- 只输出JSON。

结论类型：
CORE_WEAKNESS = 当前最关键的弱点/断点假设
INTERACTION = 多因素相互作用或冲突
PROTECTIVE = 明显保护因素
UNCERTAINTY = 仍需补证据的重要问题
''',
        prompt: '''ACTION:
${jsonEncode({
          'plan': state['plan'],
          'scheduled_at': state['scheduled_at'],
          'additional_notes': state['additional_notes'],
          'similar_history_report': state['similar_history_report'],
          'normalized_action': profile['normalized_action'],
          'action_mode': profile['action_mode'],
          'forecast_events': profile['forecast_events'],
        })}

SELECTED_THEORIES:
${jsonEncode(theoryDetails)}

USER_CONFIRMED_THEORY_FEEDBACK_WITH_JEV_ROLE:
${jsonEncode(theoryFeedbackRows)}

JEV_INTEGRATED_PATTERN:
${jsonEncode(jevPattern)}

JEV_PRIMARY:
${jsonEncode({
          'overall': jevAssessment['overall'],
          'dominant_failure_mode': jevAssessment['dominant_failure_mode'],
          'hard_blocker': jevAssessment['hard_blocker'],
        })}

LLM_FIRST_PASS_CROSSCHECK:
${jsonEncode({
          'summary': aiAssessment['summary'],
          'headline_reason': aiAssessment['headline_reason'],
          'failure_modes': aiAssessment['failure_modes'],
        })}

返回：
{
  "integrated_pattern":"一句话描述由多个理论因素共同形成的当前行为模式",
  "pattern_explanation":"2-4句，说明从哪些用户确认因素组合出这个模式，以及JEV是否支持",
  "core_conclusions":[
    {
      "id":"short_id",
      "type":"CORE_WEAKNESS|INTERACTION|PROTECTIVE|UNCERTAINTY",
      "title":"自然中文结论",
      "factor_ids":["必须来自USER_CONFIRMED_THEORY_FEEDBACK_WITH_JEV_ROLE"],
      "theory_ids":["必须来自SELECTED_THEORIES"],
      "epistemic_status":"STRONG|MODERATE|TENTATIVE",
      "mechanism":"因素之间如何共同影响当前行为",
      "why_key":"为什么它比单独某个低分更关键",
      "counterevidence":"已有反证、冲突或尚未排除的替代解释；没有则写空字符串",
      "correction":"针对这个综合模式最优先改变的1个具体抓手",
      "review_focus":"现实结果回来后最应该验证什么"
    }
  ],
  "interactions":[
    {
      "factor_ids":[],
      "label":"例如：意向—执行鸿沟",
      "description":"两个或多个用户确认因素之间的关系"
    }
  ],
  "unknowns":["最多4条真正限制结论可靠性的未知信息"],
  "bottom_line":"1-2句最终综合结论，优先回答：这次最可能卡在哪里、用户真正需要改什么"
}''',
        expectJson: true,
        temperature: .08,
        maxTokens: 2300,
      ).timeout(const Duration(seconds: 28));

      final decoded = _decode(raw);
      final validFactorIds =
          theoryFeedbackRows.map((e) => '${e['factor_id']}').toSet();
      final validTheoryIds = selectedTheoryIds.toSet();
      final conclusions = <GrowthData>[];
      for (final row in growthRows(decoded['core_conclusions']).take(6)) {
        final ids = growthStrings(row['factor_ids'])
            .where(validFactorIds.contains)
            .toSet()
            .toList();
        if (ids.isEmpty) continue;
        final type = '${row['type'] ?? ''}'.toUpperCase();
        final epistemic =
            '${row['epistemic_status'] ?? 'TENTATIVE'}'.toUpperCase();
        conclusions.add({
          'id': _cleanUserText('${row['id'] ?? ''}'),
          'type': const {
            'CORE_WEAKNESS',
            'INTERACTION',
            'PROTECTIVE',
            'UNCERTAINTY'
          }.contains(type)
              ? type
              : 'INTERACTION',
          'title': _cleanUserText('${row['title'] ?? ''}'),
          'factor_ids': ids,
          'theory_ids': growthStrings(row['theory_ids'])
              .where(validTheoryIds.contains)
              .toSet()
              .toList(),
          'epistemic_status':
              const {'STRONG', 'MODERATE', 'TENTATIVE'}.contains(epistemic)
                  ? epistemic
                  : 'TENTATIVE',
          'mechanism': _cleanUserText('${row['mechanism'] ?? ''}'),
          'why_key': _cleanUserText('${row['why_key'] ?? ''}'),
          'counterevidence':
              _cleanUserText('${row['counterevidence'] ?? ''}'),
          'correction': _cleanUserText('${row['correction'] ?? ''}'),
          'review_focus':
              _cleanUserText('${row['review_focus'] ?? ''}'),
        });
      }

      final interactions = <GrowthData>[];
      for (final row in growthRows(decoded['interactions']).take(6)) {
        final ids = growthStrings(row['factor_ids'])
            .where(validFactorIds.contains)
            .toSet()
            .toList();
        if (ids.length < 2) continue;
        interactions.add({
          'factor_ids': ids,
          'label': _cleanUserText('${row['label'] ?? ''}'),
          'description':
              _cleanUserText('${row['description'] ?? ''}'),
        });
      }

      return {
        'status': 'AI_SYNTHESIS',
        'model': config.displayModel,
        'integrated_pattern':
            _cleanUserText('${decoded['integrated_pattern'] ?? ''}'),
        'pattern_explanation':
            _cleanUserText('${decoded['pattern_explanation'] ?? ''}'),
        'bottom_line':
            _cleanUserText('${decoded['bottom_line'] ?? ''}'),
        'core_conclusions': conclusions,
        'interactions': interactions,
        'unknowns': growthStrings(decoded['unknowns'])
            .map(_cleanUserText)
            .where((e) => e.isNotEmpty)
            .take(4)
            .toList(),
        'jev_pattern': jevPattern,
      };
    } catch (_) {
      return _localTheoryFeedbackSynthesis(
        theoryFeedbackRows,
        jevPattern: jevPattern,
        reason: 'AI_SYNTHESIS_FAILED',
      );
    }
  }

  GrowthData _localTheoryFeedbackSynthesis(
    List<GrowthData> rows, {
    required GrowthData jevPattern,
    required String reason,
  }) {
    final priorities = rows.where((row) {
      final role = '${row['jev_role'] ?? ''}';
      final ordinal = row['ordinal_level'];
      return role == 'key_blocker' ||
          role == 'secondary_risk' ||
          (ordinal is num && ordinal.toInt() <= 1);
    }).toList()
      ..sort((a, b) {
        int rank(GrowthData row) {
          final role = '${row['jev_role'] ?? ''}';
          if (role == 'key_blocker') return 3;
          if (role == 'secondary_risk') return 2;
          final ordinal = row['ordinal_level'];
          return ordinal is num && ordinal.toInt() <= 1 ? 1 : 0;
        }
        final r = rank(b).compareTo(rank(a));
        if (r != 0) return r;
        return ((_prob(b['jev_role_confidence']) ?? 0)
            .compareTo(_prob(a['jev_role_confidence']) ?? 0));
      });

    return {
      'status': 'LOCAL_SYNTHESIS',
      'reason': reason,
      'integrated_pattern': '${jevPattern['choice'] ?? ''}',
      'pattern_explanation':
          '当前无法完成LLM二次综合；以下只按用户确认理论因素与JEV独立角色判断保留候选，不推断隐藏心理原因。',
      'bottom_line': priorities.isEmpty
          ? '用户确认的理论因素中暂未形成一个足够明确的核心阻碍。'
          : '当前最应优先核对：${priorities.take(3).map((e) => e['factor_label']).join('、')}。',
      'core_conclusions': [
        for (final row in priorities.take(4))
          {
            'id': 'factor_${row['factor_id']}',
            'type': 'CORE_WEAKNESS',
            'title':
                '${row['factor_label']}：${row['option_label']}',
            'factor_ids': [row['factor_id']],
            'theory_ids': row['theory_ids'],
            'epistemic_status':
                row['jev_role'] == 'key_blocker' ? 'MODERATE' : 'TENTATIVE',
            'mechanism': '',
            'why_key':
                '这是用户确认的理论因素；JEV角色判断为${row['jev_role'] ?? '未判断'}。',
            'counterevidence': '',
            'correction': '',
            'review_focus':
                '现实结果回来后检查该因素是否真的出现在行动断点之前。',
          }
      ],
      'interactions': <GrowthData>[],
      'unknowns': <String>[],
      'jev_pattern': jevPattern,
    };
  }

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
    final diagnosis = growthMap(rows[index]['behavior_diagnosis']);
    final reviewBlueprint = growthMap(diagnosis['review_blueprint']);
    final theoryFeedback =
        growthMap(diagnosis['theory_feedback_analysis']);
    final weaknessSnapshot = growthRows(diagnosis['key_weaknesses'])
        .take(4)
        .map((row) => {
              'key': row['key'],
              'label': row['label'],
              'classification': row['classification'],
              'bottleneck_probability': row['bottleneck_probability'],
              'past_recurrence_count': row['past_recurrence_count'],
            })
        .toList();
    final theoryConclusionSnapshot =
        growthRows(theoryFeedback['core_conclusions'])
            .take(6)
            .map((row) => {
                  'id': row['id'],
                  'type': row['type'],
                  'title': row['title'],
                  'factor_ids': growthStrings(row['factor_ids']),
                  'theory_ids': growthStrings(row['theory_ids']),
                  'epistemic_status': row['epistemic_status'],
                  'correction': row['correction'],
                  'review_focus': row['review_focus'],
                })
            .toList();
    final outcomeAt = DateTime.now().millisecondsSinceEpoch;
    rows[index] = {
      ...rows[index],
      'outcome': outcome,
      'outcome_at_ms': outcomeAt,
      if (diagnosis.isNotEmpty)
        'diagnostic_review': {
          'status': 'PENDING',
          'created_at_ms': outcomeAt,
          'outcome': outcome,
          'compare_keys': growthStrings(reviewBlueprint['compare_keys']),
          'questions': growthStrings(reviewBlueprint['questions']),
          'weakness_hypothesis_snapshot': weaknessSnapshot,
          'theory_conclusion_snapshot': theoryConclusionSnapshot,
          'theory_factor_snapshot':
              growthRows(theoryFeedback['factor_rows']).take(32).toList(),
          'rule':
              '现实结果用于支持、削弱或推翻预测时保存的理论综合结论与弱点假设；用户确认的理论因素保留原值，不把一次结果直接解释成稳定人格特征。',
        },
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
