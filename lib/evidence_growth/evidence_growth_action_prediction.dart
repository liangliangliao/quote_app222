import 'dart:convert';

import '../services/unified_ai_service.dart';
import 'evidence_growth_dao.dart';
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
    return _interpretAction(state);
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
    final profile =
        actionProfile.isEmpty ? await _interpretAction(state) : actionProfile;
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
    for (final row in growthRows(profile['dynamic_factors']).take(8)) {
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

      final useJev = j != null;
      final score = useJev ? j : a;
      final confidence = useJev ? jConfidence : aiConfidence;
      final unknown = score == null ||
          (useJev
              ? (confidence ?? 0) < .45 &&
                  score >= .35 &&
                  score <= .65
              : aiStatus == 'UNKNOWN' &&
                  (confidence == null || confidence < .5));

      factors[key] = {
        'label': activeLabels[key],
        'score': score,
        'display_score': unknown ? null : score,
        'confidence': confidence,
        'unknown': unknown,
        'source': useJev ? 'JEV' : a != null ? 'AI' : 'NONE',
        'is_dynamic': dynamicByKey.containsKey(key),
        'theory_construct': dynamicByKey.containsKey(key)
            ? '${dynamicByKey[key]!['ibm_construct'] ?? 'environmental_constraints'}'
            : key,
        'theory_group': _theoryGroup(dynamicByKey.containsKey(key)
            ? '${dynamicByKey[key]!['ibm_construct'] ?? 'environmental_constraints'}'
            : key),
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
        'evidence': dynamicByKey.containsKey(key)
            ? _dynamicEvidence(dynamicByKey[key]!)
            : _humanEvidence(
                key, '${aiRow['evidence'] ?? ''}', state, resolved.length),
      };
    }

    final riskRows = factors.entries
        .where((e) {
          final row = e.value;
          final score = row['score'];
          final confidence = row['confidence'];
          return row['unknown'] != true &&
              score is num &&
              score < .5 &&
              (confidence == null ||
                  (confidence is num && confidence.toDouble() >= .5));
        })
        .toList()
      ..sort((a, b) {
        final as = (a.value['score'] as num?)?.toDouble() ?? 1;
        final bs = (b.value['score'] as num?)?.toDouble() ?? 1;
        final ac = (a.value['confidence'] as num?)?.toDouble() ?? .5;
        final bc = (b.value['confidence'] as num?)?.toDouble() ?? .5;
        return (as + (1 - ac) * .25).compareTo(bs + (1 - bc) * .25);
      });

    final disagreement = aiEstimate != null &&
        jevEstimate != null &&
        (aiEstimate - jevEstimate).abs() >= .20;

    final dominantFailure = growthMap(jev['dominant_failure_mode']);
    final missingQuestion =
        growthMap(jev['most_decisive_missing_question']);
    final dominantFailureKey = '${dominantFailure['choice'] ?? ''}';
    final missingQuestionKey = '${missingQuestion['choice'] ?? ''}';

    final failureLabels = <String, String>{
      ...failureModeLabels,
      for (final row in growthRows(profile['failure_modes']))
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
        'name': 'Integrated Behavioral Model (IBM)',
        'extension': 'Implementation Intentions',
        'model_id': 'IBM_2015_PLUS_IMPLEMENTATION_INTENTION',
        'direct_behavior_constructs': EvidenceGrowthJev.ibmDirectFactors,
        'factor_groups': EvidenceGrowthJev.actionFactorGroups,
        'note':
            'IBM提供行为预测的理论结构；执行意图用于补充意向到真实行动之间的转化。模型系数不人为伪造，最终概率由JEV判断并用同类个人结果逐步校准。',
      },
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
        'dominant_failure_probabilities':
            growthMap(dominantFailure['probabilities']),
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

  Future<GrowthData> _interpretAction(GrowthData state) async {
    UnifiedAiResolvedConfig config;
    try {
      config = await _ai.resolveGlobalConfig();
    } catch (_) {
      return _fallbackActionProfile(state);
    }
    if (!config.available) return _fallbackActionProfile(state);

    try {
      final raw = await _ai.generateText(
        purpose: 'evidence_growth.action_interpretation',
        systemPrompt: '''
你是“通用行动语义解释器”，不是预测器。你的任务是把用户的一句话行动计划转换成可观察、可判定、适合 JEV 概率判断的 action profile。

理论主干必须使用 Integrated Behavioral Model（IBM，整合行为模型）：
- 行动意向 intention 是行为最接近的心理决定因素；
- 意向由态度、知觉规范与个人能动性形成；
- 态度拆成 experiential_attitude（做这件事的感受）和 instrumental_attitude（对结果/代价的判断）；
- 规范拆成 injunctive_norm（重要他人认为我应不应该做）和 descriptive_norm（重要他人实际上怎么做）；
- 个人能动性拆成 self_efficacy 与 perceived_control；
- intention 形成后，knowledge_skills、salience、environmental_constraints、habit 会直接影响意向能否转成真实行为；
- implementation_intention 不是 IBM 原始构念，而是明确标注的执行意图扩展，用于描述“如果X发生，我就立即做Y”的 cue→action 连接，以处理 intention-behavior gap。

必须遵守：
1. 不预测成功率，不评价人格，不做心理诊断。
2. 可以从语言中提取语义，但绝不能虚构现实事实。未知事实保持未知，并通过 clarifying_questions 提问。
3. 先定义“成功到底是什么可观察事件”。不同类型行动不能强行套“按时出门”：
   INITIATE=启动；COMPLETE=完成/提交；SUSTAIN=持续；REFRAIN=在时间窗内不做；REPEAT=重复/习惯；INTERACT=与人/系统互动；SEQUENCE=多步骤；OTHER=其他。
4. forecast_events 必须可观察、可证伪，1~4个，只能一个 primary=true。
5. relevant_core_factors 只能从以下理论构念选择：
intention,experiential_attitude,instrumental_attitude,injunctive_norm,descriptive_norm,self_efficacy,perceived_control,knowledge_skills,salience,environmental_constraints,habit,implementation_intention
   其中 IBM 的五个直接行为决定因素 intention,knowledge_skills,salience,environmental_constraints,habit 无论如何都会由程序保留；你主要负责判断哪些“意向前因”在当前行动中真正相关。
6. dynamic_factors 不是自由发明新心理学变量。它们必须是“当前具体行为中的显著信念/现实条件”，并映射到一个 ibm_construct。例：对方今晚是否会接电话→environmental_constraints；我认为道歉会改善关系→instrumental_attitude；想到跑步就很厌烦→experiential_attitude。
7. clarifying_questions 只问最可能显著改变预测的缺失事实，最多5个；每一问必须标明 ibm_construct。优先询问理论上关键但证据缺失的构念，不问泛泛问题。
8. failure_modes 最多6个，也尽量标明最接近的 ibm_construct。
9. action_tags 用于以后匹配“真正相似的过去行为”，必须具体且稳定，例如 work_submission、exercise_running、smoking_abstinence、social_apology_call；不要只写 goal/action/task 这种泛标签。
10. 所有 id 只用小写英文字母、数字、下划线。
11. 只输出 JSON。
''',
        prompt: '''INPUT:
${jsonEncode(state)}

返回：
{
  "version":"ibm_action_v2",
  "theory_model":"IBM_2015_PLUS_IMPLEMENTATION_INTENTION",
  "normalized_action":"把用户原话改写成明确、可观察的一句话",
  "action_mode":"INITIATE|COMPLETE|SUSTAIN|REFRAIN|REPEAT|INTERACT|SEQUENCE|OTHER",
  "action_tags":["2~5个具体稳定标签"],
  "interpretation":"一句自然中文说明你把这个行动理解成什么，不做预测",
  "forecast_events":[
    {
      "id":"observable_event",
      "label":"给用户看的事件名称",
      "true_criterion":"English: precise observable criterion for event=true",
      "false_criterion":"English: precise observable criterion for event=false",
      "primary":true
    }
  ],
  "relevant_core_factors":["从允许的IBM/扩展构念中选择"],
  "dynamic_factors":[
    {
      "id":"behavior_specific_belief",
      "label":"中文名称",
      "ibm_construct":"必须是允许的理论构念之一",
      "condition":"English condition whose presence supports the primary event",
      "evidence":"若输入中已有相关事实，用中文概括；没有则为空"
    }
  ],
  "clarifying_questions":[
    {
      "id":"missing_fact",
      "question":"中文具体问题？",
      "why":"为什么它会显著改变预测",
      "ibm_construct":"允许的理论构念之一",
      "criticality":0.0,
      "answer_type":"text|choice",
      "options":["choice时才给简短选项"]
    }
  ],
  "failure_modes":[
    {
      "id":"specific_failure",
      "label":"中文失败机制",
      "ibm_construct":"允许的理论构念之一",
      "criterion":"English criterion describing this failure mechanism"
    }
  ]
}''',
        expectJson: true,
        temperature: .05,
        maxTokens: 2200,
      ).timeout(const Duration(seconds: 25));

      final decoded = _decode(raw);
      final events = growthRows(decoded['forecast_events'])
          .where((e) =>
              '${e['id'] ?? ''}'.trim().isNotEmpty &&
              '${e['label'] ?? ''}'.trim().isNotEmpty &&
              '${e['true_criterion'] ?? ''}'.trim().isNotEmpty &&
              '${e['false_criterion'] ?? ''}'.trim().isNotEmpty)
          .take(4)
          .toList();
      if (events.isEmpty) return _fallbackActionProfile(state);

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

      return {
        'version': 'ibm_action_v2',
        'theory_model': 'IBM_2015_PLUS_IMPLEMENTATION_INTENTION',
        'normalized_action':
            _cleanUserText('${decoded['normalized_action'] ?? ''}').isEmpty
                ? '${state['plan'] ?? ''}'.trim()
                : _cleanUserText('${decoded['normalized_action']}'),
        'action_mode': allowedModes.contains(mode) ? mode : 'OTHER',
        'action_tags': growthStrings(decoded['action_tags']).take(5).toList(),
        'interpretation':
            _cleanUserText('${decoded['interpretation'] ?? ''}'),
        'forecast_events': events,
        'relevant_core_factors': growthStrings(decoded['relevant_core_factors'])
            .where(factorLabels.containsKey)
            .toSet()
            .toList(),
        'dynamic_factors':
            growthRows(decoded['dynamic_factors']).take(6).toList(),
        'clarifying_questions':
            growthRows(decoded['clarifying_questions']).take(5).toList(),
        'failure_modes':
            growthRows(decoded['failure_modes']).take(6).toList(),
      };
    } catch (_) {
      return _fallbackActionProfile(state);
    }
  }

  GrowthData _fallbackActionProfile(GrowthData state) => {
        'version': 'ibm_action_v2_fallback',
        'theory_model': 'IBM_2015_PLUS_IMPLEMENTATION_INTENTION',
        'normalized_action': '${state['plan'] ?? ''}'.trim(),
        'action_mode': 'OTHER',
        'action_tags': <String>[],
        'interpretation': '按你输入的原始行动进行预测；当前无法完成更细的行为语义解析，因此保留 IBM 全部核心构念。',
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
你是“行动发生可能性预测器”的结构化分析器。使用 Integrated Behavioral Model（IBM）作为理论主干，并把 implementation intention 明确当作独立的意向→行动扩展。目标是解释一个具体行动为什么更可能发生或不发生；不替用户做价值判断。

理论结构：
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
4. 不要把所有因素当作平级加权平均。态度/规范/agency主要解释 intention；IBM五个直接因素解释 intention 是否转成行为；implementation_intention 是额外的执行桥梁。
5. action_profile.dynamic_factors 是针对当前具体行为提取的显著信念/现实条件；若存在，按其 ibm_construct 理解，不创造新的心理学理论。
6. 对 personal_history_summary 只使用“同类行为匹配后的历史”；没有同类历史时 habit 保持未知。绝不能用无关行为做强校准。
7. protective_actions 必须针对最弱的理论构念给出可执行物理动作，最多3条。
8. improvement_scenario 只改变1~3个可控理论构念，并明确是情景模拟。
9. execution_likelihood 是模型交叉判断，不是统计保证；JEV配置可用时它不是最终主预测值。
10. evidence、summary、headline_reason、failure_modes、protective_actions、missing_information 用自然中文，不输出内部字段名或推理过程。
11. 只输出 JSON。
''',
            prompt: '''STATE:
${jsonEncode(state)}
返回：
{
  "summary":"一句话结论，必须用IBM构念解释最关键瓶颈",
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
    "changes":["最多3条，并尽量指出改善的是哪个IBM构念"],
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
    final fence = String.fromCharCodes([96, 96, 96]);
    if (text.startsWith(fence)) {
      text = text.replaceFirst(RegExp(r'^...(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*...$'), '');
    }
    final value = jsonDecode(text);
    if (value is! Map) throw const FormatException('INVALID_JSON_OBJECT');
    return growthMap(value);
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

  static String _dynamicEvidence(GrowthData row) {
    final evidence = _cleanUserText('${row['evidence'] ?? ''}');
    if (evidence.isNotEmpty) return evidence;
    final label = '${row['label'] ?? '这个行动特有因素'}'.trim();
    final construct = '${row['ibm_construct'] ?? ''}'.trim();
    final constructLabel =
        EvidenceGrowthJev.actionFactorLabels[construct] ?? construct;
    return constructLabel.isEmpty
        ? '这是“$label”这一具体行动中的显著信念／现实条件；当前没有明确事实时保持未知。'
        : '这是“$label”这一行为特有条件，理论上归入“$constructLabel”；当前没有明确事实时保持未知。';
  }

  static String _humanEvidence(
      String key, String raw, GrowthData state, int resolvedCount) {
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
