import 'dart:convert';

import 'xiangji_models.dart';

/// Runtime input for the Rev.5.2 Signature Capability Router.
///
/// Callers pass observable state and explicit workflow signals. The router may
/// also infer obvious triggers from text, but it never treats that inference as
/// a user-confirmed fact.
class XiangjiSignatureMethodContext {
  const XiangjiSignatureMethodContext({
    required this.problemId,
    required this.problemState,
    this.rawText = '',
    this.requestedMethodIds = const <String>[],
    this.sourceRefs = const <String>[],
    this.facts = const <String>[],
    this.experiences = const <String>[],
    this.interpretations = const <String>[],
    this.causalCandidates = const <String>[],
    this.counterevidence = const <String>[],
    this.candidateGaps = const <Map<String, Object?>>[],
    this.missingPreconditions = const <String>[],
    this.decisiveDifference = '',
    this.vagueExperience = '',
    this.abstractLabel = '',
    this.highImpactClaim = '',
    this.weakestPremise = '',
    this.complexModel = false,
    this.groundWeak = false,
    this.realityConflict = false,
    this.goalNeedsAudit = false,
    this.pathAsGoal = false,
    this.prediction = '',
    this.reality = const <String, Object?>{},
    this.realityVerdict = '',
    this.earliestFailedLayer = '',
    this.operatorTitle = '',
    this.operatorMechanism = '',
    this.operatorExpectedEffect = '',
    this.operatorCost = '',
    this.operatorRisk = 'low',
    this.operatorReversibility = 'high',
    this.operatorInformationValue = 'medium',
    this.actionMode = false,
    this.visibleLimit = 3,
    this.createdAtMs = 0,
    this.eventIdPrefix = '',
  });

  final String problemId;
  final XiangjiProblemState problemState;
  final String rawText;
  final List<String> requestedMethodIds;
  final List<String> sourceRefs;
  final List<String> facts;
  final List<String> experiences;
  final List<String> interpretations;
  final List<String> causalCandidates;
  final List<String> counterevidence;
  final List<Map<String, Object?>> candidateGaps;
  final List<String> missingPreconditions;
  final String decisiveDifference;
  final String vagueExperience;
  final String abstractLabel;
  final String highImpactClaim;
  final String weakestPremise;
  final bool complexModel;
  final bool groundWeak;
  final bool realityConflict;
  final bool goalNeedsAudit;
  final bool pathAsGoal;
  final String prediction;
  final Map<String, Object?> reality;
  final String realityVerdict;
  final String earliestFailedLayer;
  final String operatorTitle;
  final String operatorMechanism;
  final String operatorExpectedEffect;
  final String operatorCost;
  final String operatorRisk;
  final String operatorReversibility;
  final String operatorInformationValue;
  final bool actionMode;
  final int visibleLimit;
  final int createdAtMs;
  final String eventIdPrefix;
}

class XiangjiSignatureRouterResult {
  const XiangjiSignatureRouterResult({
    required this.before,
    required this.after,
    required this.events,
  });

  final XiangjiSolverSnapshot before;
  final XiangjiSolverSnapshot after;
  final List<XiangjiMethodEvent> events;

  List<XiangjiMethodEvent> get visibleEvents =>
      events.where((event) => event.userVisible).toList();
}

/// Contextual router and deterministic state transformer for MEC-001..014.
///
/// It is intentionally independent of Flutter and providers so every method
/// can be exercised offline and its state effect can be verified in E2E tests.
class XiangjiSignatureCapabilityRouter {
  const XiangjiSignatureCapabilityRouter();

  static const List<String> capabilityIds = <String>[
    'MEC-001',
    'MEC-002',
    'MEC-003',
    'MEC-004',
    'MEC-005',
    'MEC-006',
    'MEC-007',
    'MEC-008',
    'MEC-009',
    'MEC-010',
    'MEC-011',
    'MEC-012',
    'MEC-013',
    'MEC-014',
  ];

  XiangjiSignatureRouterResult route({
    required XiangjiSolverSnapshot state,
    required XiangjiSignatureMethodContext context,
  }) {
    if (state.problemId != context.problemId) {
      throw ArgumentError('Signature router 的 Problem 与 SolverSnapshot 不一致。');
    }
    final selected = _select(context, state);
    var working = state;
    final events = <XiangjiMethodEvent>[];
    final now = context.createdAtMs > 0
        ? context.createdAtMs
        : DateTime.now().millisecondsSinceEpoch;
    final visibleLimit = context.visibleLimit.clamp(0, 3).toInt();

    for (var index = 0; index < selected.length; index++) {
      final methodId = selected[index];
      final before = working;
      final mutation = _apply(methodId, before, context);
      final semanticChanged = _semanticJson(before) != _semanticJson(mutation.state);
      working = mutation.state.copyWith(
        stateVersion:
            before.stateVersion + (semanticChanged ? 1 : 0),
        promptVersion: 'rev5.2',
        updatedAtMs: now,
      );
      final prefix = context.eventIdPrefix.trim().isEmpty
          ? 'xf_method_${context.problemId}_$now'
          : context.eventIdPrefix.trim();
      events.add(XiangjiMethodEvent(
        id: '$prefix-${methodId.toLowerCase()}-$index',
        methodId: methodId,
        problemId: context.problemId,
        stateVersion: working.stateVersion,
        trigger: mutation.trigger,
        sourceRefs: context.sourceRefs,
        beforeStateRefs: _stateRefs(before),
        operationSummary: mutation.operationSummary,
        dataMutations: mutation.dataMutations,
        afterStateRefs: _stateRefs(working),
        decisionEffect: mutation.decisionEffect,
        userVisibleSummary: mutation.userVisibleSummary,
        realityTest: mutation.realityTest,
        learningLink: mutation.learningLink,
        changedState: semanticChanged,
        retainedStateReason: semanticChanged
            ? ''
            : '检查了当前根据与反证，没有足够理由改变当前解题状态。',
        userVisible:
            !context.actionMode && index < visibleLimit,
        createdAtMs: now + index,
      ));
    }

    return XiangjiSignatureRouterResult(
      before: state,
      after: working,
      events: events,
    );
  }

  List<String> _select(
    XiangjiSignatureMethodContext context,
    XiangjiSolverSnapshot state,
  ) {
    if (context.requestedMethodIds.isNotEmpty) {
      final requested = context.requestedMethodIds.toSet();
      final invalid = requested.difference(capabilityIds.toSet());
      if (invalid.isNotEmpty) {
        throw ArgumentError('未知 Signature Method：${invalid.join(', ')}');
      }
      return context.requestedMethodIds.toSet().toList();
    }

    final selected = <String>[];
    final text = <String>[
      context.rawText,
      ...context.experiences,
      ...context.interpretations,
    ].join(' ');
    final hasFeeling = RegExp(r'害怕|恐惧|抗拒|焦虑|胸口|心慌|不想|感觉')
        .hasMatch(text);
    final hasAbsoluteCause = RegExp(r'所以|说明|一定|肯定|就是因为|证明')
        .hasMatch(text);
    final vague = context.vagueExperience.isNotEmpty ||
        RegExp(r'说不清|不对劲|怪怪的|难以描述').hasMatch(text);

    switch (context.problemState) {
      case XiangjiProblemState.captured:
      case XiangjiProblemState.formalizing:
        if (context.interpretations.isNotEmpty &&
            (context.experiences.isNotEmpty || context.facts.isNotEmpty)) {
          selected.add('MEC-001');
        }
        if (hasFeeling && hasAbsoluteCause) selected.add('MEC-002');
        if (context.causalCandidates.isNotEmpty ||
            RegExp(r'原因|为什么|总是|导致').hasMatch(text)) {
          selected.add('MEC-003');
        }
        if (vague) selected.add('MEC-005');
        break;
      case XiangjiProblemState.epistemicReview:
        if (context.highImpactClaim.isNotEmpty || context.groundWeak) {
          selected.add('MEC-007');
        }
        if (context.complexModel) selected.add('MEC-008');
        break;
      case XiangjiProblemState.conceptReview:
        if (context.decisiveDifference.isNotEmpty) selected.add('MEC-004');
        if (context.abstractLabel.isNotEmpty) selected.add('MEC-006');
        selected.add('MEC-010');
        break;
      case XiangjiProblemState.solving:
        if (state.goalSummary.isNotEmpty) selected.add('MEC-011');
        if (state.keyGapSummary.isNotEmpty) selected.add('MEC-012');
        if (context.highImpactClaim.isNotEmpty || context.groundWeak) {
          selected.add('MEC-007');
        }
        break;
      case XiangjiProblemState.actionReady:
      case XiangjiProblemState.executing:
        if (context.prediction.isNotEmpty) selected.add('MEC-013');
        break;
      case XiangjiProblemState.verifying:
        selected.add('MEC-013');
        if (context.realityConflict) {
          selected.addAll(const <String>['MEC-009', 'MEC-014']);
        }
        break;
      case XiangjiProblemState.backtracking:
        selected.addAll(const <String>['MEC-014', 'MEC-009']);
        break;
      case XiangjiProblemState.resolved:
      case XiangjiProblemState.archived:
        break;
    }
    return capabilityIds.where(selected.toSet().contains).toList();
  }

  _MethodMutation _apply(
    String methodId,
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    switch (methodId) {
      case 'MEC-001':
        return _experienceVsInterpretation(state, context);
      case 'MEC-002':
        return _feelingVsExternalCause(state, context);
      case 'MEC-003':
        return _competingCausality(state, context);
      case 'MEC-004':
        return _judgmentComparison(state, context);
      case 'MEC-005':
        return _unconceptualizedExperience(state, context);
      case 'MEC-006':
        return _conceptFidelity(state, context);
      case 'MEC-007':
        return _groundExplorer(state, context);
      case 'MEC-008':
        return _proofAudit(state, context);
      case 'MEC-009':
        return _conceptRealityConflict(state, context);
      case 'MEC-010':
        return _goalAudit(state, context);
      case 'MEC-011':
        return _gapRadar(state, context);
      case 'MEC-012':
        return _operatorSolver(state, context);
      case 'MEC-013':
        return _predictionRealityLedger(state, context);
      case 'MEC-014':
        return _backtrackInspector(state, context);
      default:
        throw ArgumentError('未知 Signature Method：$methodId');
    }
  }

  _MethodMutation _experienceVsInterpretation(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final current = <String, Object?>{
      ...state.currentState,
      'facts': context.facts,
      'experiences': context.experiences,
      'interpretations': context.interpretations,
      'interpretations_may_drive_goal': false,
    };
    return _MethodMutation(
      state: state.copyWith(currentState: current),
      trigger: '同一轮材料同时出现可观察/体验内容与解释性结论。',
      operationSummary: '把用户原话按事实、直接体验和解释分层，并限制无根据解释的决策权限。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'SolverSnapshot.current_state',
          'operation': 'separate',
          'fields': <String>['facts', 'experiences', 'interpretations'],
        },
        <String, Object?>{
          'object_type': 'Interpretation',
          'operation': 'block_decision_authority',
          'field': 'interpretations_may_drive_goal',
        },
      ],
      decisionEffect: '未获现实根据的解释不能直接决定目标、当前办法或战略路线。',
      userVisibleSummary: '体验和发生过的事被保留；“这意味着什么”暂时作为待验证解释。',
      realityTest: '补充可观察记录或独立来源，检查解释是否仍成立。',
      learningLink: '辨认“发生了什么”与“我如何解释它”。',
    );
  }

  _MethodMutation _feelingVsExternalCause(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final hypotheses = _copyMaps(state.hypotheses);
    final interpretation = context.interpretations.isEmpty
        ? '当前感觉所指向的外部原因'
        : context.interpretations.first;
    hypotheses.add(<String, Object?>{
      'id': 'feeling-external-cause-${state.stateVersion + 1}',
      'statement': interpretation,
      'kind': 'external_cause',
      'status': 'unresolved',
      'evidence_needed': '独立的安全事实、行为记录或可区分观察',
    });
    final current = <String, Object?>{
      ...state.currentState,
      'felt_signal_preserved': context.experiences.isEmpty
          ? context.rawText
          : context.experiences.first,
      'external_cause_is_fact': false,
    };
    return _MethodMutation(
      state: state.copyWith(
        currentState: current,
        hypotheses: hypotheses,
      ),
      trigger: '身体感觉、害怕或抗拒被直接用来推出外部事实。',
      operationSummary: '承认体验本身，同时把外部危险/他人动机降为待验证因果假设。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'Experience',
          'operation': 'preserve',
          'field': 'felt_signal_preserved',
        },
        <String, Object?>{
          'object_type': 'Hypothesis',
          'operation': 'create',
          'status': 'unresolved',
        },
      ],
      decisionEffect: '路线不再以“感觉=外部事实”为前提；高风险时先进入安全证据路径。',
      userVisibleSummary: '你的感觉是真的；它是否说明外部确有危险，还需要现实证据。',
      realityTest: '寻找一个能独立支持或反驳外部原因的安全观察。',
    );
  }

  _MethodMutation _competingCausality(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final rawCandidates = context.causalCandidates
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (rawCandidates.length < 2) {
      rawCandidates
        ..add('情境或资源条件暂时不足')
        ..add('行动前的回避、技能或预期机制在起作用');
    }
    final candidates = rawCandidates.take(5).toList();
    final hypotheses = <Map<String, Object?>>[
      for (var index = 0; index < candidates.length; index++)
        <String, Object?>{
          'id': 'causal-${state.stateVersion + 1}-$index',
          'statement': candidates[index],
          'mechanism': index.isEven ? 'environment_or_resource' : 'behavior_or_expectation',
          'supporting_facts': context.facts,
          'counterevidence_or_unknown': context.counterevidence,
          'discriminating_observation':
              '用一次低风险、可逆的小测试观察“${candidates[index]}”独有的信号',
          'status': 'candidate',
        },
    ];
    final gaps = _copyMaps(state.gaps)
      ..removeWhere((gap) => gap['type'] == 'information')
      ..add(<String, Object?>{
        'id': 'gap-info-${state.stateVersion + 1}',
        'type': 'information',
        'label': '尚未区分真正起作用的原因',
        'priority': 100,
      });
    return _MethodMutation(
      state: state.copyWith(hypotheses: hypotheses, gaps: gaps),
      trigger: '一个需要解释的结果被直接归为单一原因。',
      operationSummary: '建立机制不同且可由现实区分的候选原因，并为每个原因指定最小观察。',
      dataMutations: <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'Hypothesis',
          'operation': 'replace_candidates',
          'count': hypotheses.length,
        },
        const <String, Object?>{
          'object_type': 'Gap',
          'operation': 'upsert',
          'type': 'information',
        },
      ],
      decisionEffect: '原因未区分前，当前最大差距转为信息缺口，优先高信息价值的小实验。',
      userVisibleSummary: '军师没有把结果归咎于唯一原因，而是在比较 ${hypotheses.length} 个可区分机制。',
      realityTest: (hypotheses.first['discriminating_observation'] ?? '').toString(),
    );
  }

  _MethodMutation _judgmentComparison(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final difference = context.decisiveDifference.trim().isEmpty
        ? '当前关键条件与旧案例不同，不能机械复用旧标签或旧路线'
        : context.decisiveDifference.trim();
    final frame = <String, Object?>{
      ...state.problemFrame,
      'history_reuse_reviewed': true,
      'decisive_difference': difference,
    };
    final keyGap = <String, Object?>{
      'id': 'gap-judgment-${state.stateVersion + 1}',
      'type': 'capability',
      'label': '围绕决定性差异重新定位瓶颈：$difference',
      'priority': 100,
    };
    final operator = state.activeOperator.isEmpty
        ? const <String, Object?>{}
        : <String, Object?>{
            ...state.activeOperator,
            'status': 'invalidated_by_decisive_difference',
          };
    return _MethodMutation(
      state: state.copyWith(
        problemFrame: frame,
        keyGap: keyGap,
        activeOperator: operator,
      ),
      trigger: '准备复用历史案例、抽象标签或旧策略。',
      operationSummary: '比较相同点、不同点和会改变解法的决定性差异。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'ProblemFrame',
          'operation': 'set_decisive_difference',
        },
        <String, Object?>{
          'object_type': 'KeyGap',
          'operation': 'reselect',
        },
        <String, Object?>{
          'object_type': 'Operator',
          'operation': 'invalidate_if_reused',
        },
      ],
      decisionEffect: '旧真问题、差距与办法不再自动迁移，瓶颈按本次关键条件重算。',
      userVisibleSummary: '表面名称相似，但“$difference”会改变当前瓶颈和办法。',
      realityTest: '执行新路线后，观察该决定性差异是否确实解释了结果变化。',
      learningLink: '下次类比前先问：哪一个不同点会改变行动？',
    );
  }

  _MethodMutation _unconceptualizedExperience(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final signal = context.vagueExperience.trim().isNotEmpty
        ? context.vagueExperience.trim()
        : context.rawText.trim();
    final prior = _strings(state.currentState['unconceptualized_experiences']);
    final signals = <String>{...prior, if (signal.isNotEmpty) signal}.toList();
    final current = <String, Object?>{
      ...state.currentState,
      'unconceptualized_experiences': signals,
      'forced_label': false,
    };
    return _MethodMutation(
      state: state.copyWith(currentState: current),
      trigger: '用户报告“说不清但不对劲”等尚未形成稳定概念的体验。',
      operationSummary: '原样保存模糊体验及场景，不强迫套入现有标签。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'UnconceptualizedExperience',
          'operation': 'append',
        },
        <String, Object?>{
          'object_type': 'Concept',
          'operation': 'prevent_forced_label',
        },
      ],
      decisionEffect: '该信号可进入观察计划，但不会以未经验证的标签改变目标或战略路线。',
      userVisibleSummary: '先不急着给它命名；这份“不对劲”已按原样保留，等待跨场景比较。',
      realityTest: '在下一次出现时记录场景、身体信号和前后事件，寻找稳定同异。',
    );
  }

  _MethodMutation _conceptFidelity(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final label = context.abstractLabel.trim().isEmpty
        ? '当前抽象标签'
        : context.abstractLabel.trim();
    final strongCounterexample = context.counterevidence.isNotEmpty;
    final fidelity = <String, Object?>{
      'label': label,
      'scope': strongCounterexample ? '已收缩：仅适用于当前有支持的场景' : '待验证边界',
      'source_experiences': context.experiences,
      'positive_examples': context.facts,
      'counterexamples': context.counterevidence,
      'unexplained_details': context.vagueExperience.isEmpty
          ? const <String>['尚未被该标签解释的具体差异需继续保留']
          : <String>[context.vagueExperience],
      'abstract_compression_loss': '单一标签会遗漏时间、关系、资源和身体体验差异',
      'status': strongCounterexample ? 'scope_reduced' : 'provisional',
    };
    final frame = <String, Object?>{
      ...state.problemFrame,
      'concept_fidelity': fidelity,
    };
    return _MethodMutation(
      state: state.copyWith(problemFrame: frame),
      trigger: '一个抽象标签正准备覆盖复杂、具体的经历。',
      operationSummary: '审查标签的覆盖、遗漏、反例、范围和抽象压缩损失。',
      dataMutations: <Map<String, Object?>>[
        const <String, Object?>{
          'object_type': 'Concept',
          'operation': 'record_fidelity_profile',
        },
        <String, Object?>{
          'object_type': 'Concept.scope',
          'operation': strongCounterexample ? 'shrink' : 'retain_provisional',
        },
      ],
      decisionEffect: strongCounterexample
          ? '强反例使 ConceptScope 收缩，相关 Problem/Gap 需避免过度概括。'
          : '标签仅作暂时压缩，不得抹去未解释细节。',
      userVisibleSummary: '“$label”解释了一部分，但遗漏和反例仍被保留${strongCounterexample ? '，适用范围已收缩' : ''}。',
      realityTest: '找一个该标签预测应成立的场景，再检查具体事实是否一致。',
    );
  }

  _MethodMutation _groundExplorer(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final weak = context.groundWeak || context.facts.isEmpty;
    final weakest = context.weakestPremise.trim().isEmpty
        ? (weak ? '关键判断缺少直接事实或独立来源' : '仍需持续检查反证')
        : context.weakestPremise.trim();
    final profile = <String, Object?>{
      ...state.epistemicProfile,
      'ground_chain': <String, Object?>{
        'spring_direct_ground': context.facts,
        'aqueduct_inferences': context.interpretations,
        'counterevidence': context.counterevidence,
        'weakest_premise': weakest,
      },
      'epistemic_status': weak ? 'EPISTEMIC_DEBT' : 'PROVISIONAL',
      'commitment': weak ? 'scout_or_reversible_only' : 'provisional_action',
    };
    final operator = <String, Object?>{
      ...state.activeOperator,
      if (state.activeOperator.isNotEmpty)
        'commitment': weak ? 'scout_or_reversible_only' : 'provisional_action',
    };
    return _MethodMutation(
      state: state.copyWith(
        epistemicProfile: profile,
        activeOperator: operator,
      ),
      trigger: '高影响判断或建议需要说明其现实根据。',
      operationSummary: '沿推断水渠下钻到直接事实，标出反证、未知项和最弱前提。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'EpistemicProfile',
          'operation': 'write_ground_chain',
        },
        <String, Object?>{
          'object_type': 'Operator.commitment',
          'operation': 'calibrate_from_ground',
        },
      ],
      decisionEffect: weak
          ? '根据偏弱，行动承诺降为补证、侦察或可逆实验。'
          : '当前根据只支持暂时推进，并保留改变条件。',
      userVisibleSummary: weak
          ? '军师追到的直接根据仍偏弱；最弱前提是“$weakest”，因此先补证或小步试验。'
          : '判断已追到可核查事实，但仍按暂时支持而非绝对确定处理。',
      realityTest: weak
          ? '获取能直接检验“$weakest”的记录或独立来源。'
          : '用行动结果检查当前根据链能否预测现实。',
      learningLink: '点击“为什么”时区分直接泉水与中间水渠。',
    );
  }

  _MethodMutation _proofAudit(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final weak = context.groundWeak || context.facts.isEmpty;
    final profile = <String, Object?>{
      ...state.epistemicProfile,
      'systematicity': context.complexModel ? 'high' : 'reviewed',
      'proof_validity': 'separate_from_premise_truth',
      'epistemic_status': weak ? 'EPISTEMIC_DEBT' : 'PROVISIONAL',
      'truth_bonus_from_complexity': false,
      'weakest_premise': context.weakestPremise.isEmpty
          ? '底层前提的现实根据仍需核查'
          : context.weakestPremise,
    };
    final operator = <String, Object?>{
      ...state.activeOperator,
      if (weak && state.activeOperator.isNotEmpty)
        'commitment': 'scout_or_reversible_only',
    };
    return _MethodMutation(
      state: state.copyWith(
        epistemicProfile: profile,
        activeOperator: operator,
      ),
      trigger: '复杂模型、长推导或形式证明被用于提高现实确定性。',
      operationSummary: '把系统化程度、推理有效性与前提的现实认识状态分开评估。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'EpistemicProfile',
          'operation': 'separate_systematicity_and_status',
        },
        <String, Object?>{
          'object_type': 'Operator.commitment',
          'operation': 'remove_complexity_bonus',
        },
      ],
      decisionEffect: weak
          ? '模型虽完整但底层根据弱，推进降为补证或可逆行动。'
          : '推理结构可用，但结论仍维持暂时支持。',
      userVisibleSummary: '结构很完整不等于现实上更可靠；军师已按最弱前提重新校准行动承诺。',
      realityTest: '直接检验最弱前提，而不是继续延长推导。',
    );
  }

  _MethodMutation _conceptRealityConflict(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final frame = <String, Object?>{
      ...state.problemFrame,
      'concept_reality_mismatch': <String, Object?>{
        'detected': true,
        'old_model': state.problemFrame,
        'new_reality': context.reality,
        'requires_concept_review': true,
      },
    };
    final gap = <String, Object?>{
      'id': 'gap-mismatch-${state.stateVersion + 1}',
      'type': 'concept',
      'label': '旧解释无法预测新现实，需要修订概念或问题框架',
      'priority': 100,
    };
    final operator = state.activeOperator.isEmpty
        ? const <String, Object?>{}
        : <String, Object?>{
            ...state.activeOperator,
            'status': 'invalidated_by_reality',
          };
    return _MethodMutation(
      state: state.copyWith(
        problemFrame: frame,
        keyGap: gap,
        activeOperator: operator,
      ),
      trigger: '预测或旧规则与现实结果连续不符。',
      operationSummary: '登记 ConceptRealityMismatch，并把旧模型与新现实并列后重算下游状态。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'ConceptRealityMismatch',
          'operation': 'create',
        },
        <String, Object?>{
          'object_type': 'KeyGap',
          'operation': 'replace_with_model_mismatch',
        },
        <String, Object?>{
          'object_type': 'Operator',
          'operation': 'invalidate',
        },
      ],
      decisionEffect: '旧办法停止自动推进；真问题、当前概念或差距至少一项进入重算。',
      userVisibleSummary: '现实正在挑战旧解释；军师已停止沿旧办法加码，并把“模型与现实不一致”设为新缺口。',
      realityTest: '用修订后的概念产生一项新预测，再与下一次现实结果对账。',
    );
  }

  _MethodMutation _goalAudit(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final priorStatement = state.goalSummary;
    final requiresConfirmation = context.goalNeedsAudit || context.pathAsGoal;
    final goal = <String, Object?>{
      ...state.goalState,
      'statement': priorStatement,
      'ultimate_goal': requiresConfirmation ? '' : priorStatement,
      'means_or_path': context.pathAsGoal ? priorStatement : '',
      'audit_flags': <String>[
        if (context.pathAsGoal) 'path_as_goal',
        if (context.goalNeedsAudit) 'value_or_motive_requires_confirmation',
      ],
      'user_confirmation_required': requiresConfirmation,
      'version': state.stateVersion + 1,
    };
    final frame = <String, Object?>{
      ...state.problemFrame,
      'solver_gate': requiresConfirmation ? 'await_goal_confirmation' : 'goal_audited',
    };
    return _MethodMutation(
      state: state.copyWith(goalState: goal, problemFrame: frame),
      trigger: '目标即将进入优化，或它可能只是路径、证明冲动或沉没成本的延续。',
      operationSummary: '区分终极目标、手段和路径，并检查价值、羞耻逃避、报复、证明冲动与沉没成本。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'GoalVersion',
          'operation': 'create_or_audit',
        },
        <String, Object?>{
          'object_type': 'ProblemFrame.solver_gate',
          'operation': 'set',
        },
      ],
      decisionEffect: requiresConfirmation
          ? '在用户确认真正目标前暂停算子优化，避免高效地走错方向。'
          : '目标已通过路径与手段审查，可以进入差距求解。',
      userVisibleSummary: requiresConfirmation
          ? '“$priorStatement”可能更像一条路径；军师会先请你确认真正想实现的结果。'
          : '目标与路径已分开，接下来只优化能服务该目标的差距。',
      realityTest: '检查达成这条路径但未实现价值时，用户是否仍认为目标已完成。',
    );
  }

  _MethodMutation _gapRadar(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final candidates = context.candidateGaps.isNotEmpty
        ? _copyMaps(context.candidateGaps)
        : <Map<String, Object?>>[
            <String, Object?>{
              'id': 'gap-info-${state.stateVersion + 1}',
              'type': state.hypotheses.length > 1 ? 'information' : 'action',
              'label': state.hypotheses.length > 1
                  ? '尚未区分真正起作用的原因'
                  : '当前状态与成功判据之间缺少一次可验证行动',
              'priority': state.hypotheses.length > 1 ? 100 : 80,
            },
            <String, Object?>{
              'id': 'gap-capability-${state.stateVersion + 1}',
              'type': 'capability',
              'label': '完成目标所需能力或前提尚未确认',
              'priority': 60,
            },
          ];
    candidates.sort((left, right) =>
        _int(right['priority']).compareTo(_int(left['priority'])));
    final keyGap = <String, Object?>{
      ...candidates.first,
      'selected_reason': '对目标影响最大且当前可被行动或侦察改变',
    };
    return _MethodMutation(
      state: state.copyWith(gaps: candidates, keyGap: keyGap),
      trigger: '当前现实状态与现实目标已足够明确，可以比较差距。',
      operationSummary: '按信息、概念、能力、资源、环境、行动和风险维度比较差距并选出 KeyGap。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'GapVector',
          'operation': 'rank',
        },
        <String, Object?>{
          'object_type': 'KeyGap',
          'operation': 'select',
        },
      ],
      decisionEffect: '主行动只能服务当前最大差距；同一目标在不同现实状态下会选择不同办法。',
      userVisibleSummary: '离目标最大的可改变差距是“${keyGap['label']}”。',
      realityTest: '行动后重新测量该差距是否缩小；未缩小则更换假设或算子。',
    );
  }

  _MethodMutation _operatorSolver(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final gap = state.keyGapSummary.isEmpty
        ? '尚未明确的关键差距'
        : state.keyGapSummary;
    final missing = context.missingPreconditions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final subgoal = <String, Object?>{
      'id': 'subgoal-${state.stateVersion + 1}',
      'label': missing.isEmpty ? '缩小关键差距：$gap' : '先满足前提：${missing.first}',
      'kind': missing.isEmpty ? 'key_gap_subgoal' : 'precondition_subgoal',
      'target_gap': gap,
    };
    final graph = <String, Object?>{
      // Missing preconditions are jointly required. OR is reserved for
      // alternative routes when no blocking precondition is present.
      'logic': missing.isEmpty ? 'OR' : 'AND',
      'nodes': <Map<String, Object?>>[
        <String, Object?>{'id': 'goal', 'type': 'goal', 'label': state.goalSummary},
        <String, Object?>{'id': 'key_gap', 'type': 'key_gap', 'label': gap},
        subgoal,
        for (var index = 0; index < missing.length; index++)
          <String, Object?>{
            'id': 'precondition-$index',
            'type': 'precondition_subgoal',
            'label': missing[index],
          },
      ],
      'edges': <Map<String, Object?>>[
        const <String, Object?>{'from': 'goal', 'to': 'key_gap'},
        <String, Object?>{'from': 'key_gap', 'to': subgoal['id']},
        for (var index = 0; index < missing.length; index++)
          <String, Object?>{
            'from': subgoal['id'],
            'to': 'precondition-$index',
            'relation': 'requires',
          },
      ],
    };
    final title = missing.isNotEmpty
        ? '补齐前提：${missing.first}'
        : (context.operatorTitle.trim().isEmpty
            ? '执行一次能缩小当前关键差距的可逆行动'
            : context.operatorTitle.trim());
    final operator = <String, Object?>{
      'id': 'operator-${state.stateVersion + 1}',
      'title': title,
      'target_gap': gap,
      'mechanism': missing.isNotEmpty
          ? '先把缺失前提转成递归子目标，解除原算子的阻塞'
          : (context.operatorMechanism.trim().isEmpty
              ? '通过可观察行动直接改变或测量关键差距'
              : context.operatorMechanism.trim()),
      'preconditions': missing,
      'expected_effect': missing.isNotEmpty
          ? '前提“${missing.first}”形成可观察的满足证据，或被现实证伪后改换路线'
          : context.operatorExpectedEffect.trim().isEmpty
              ? (context.prediction.trim().isEmpty
                  ? '关键差距出现可观察变化'
                  : context.prediction.trim())
              : context.operatorExpectedEffect.trim(),
      'cost': context.operatorCost.trim(),
      'risk': context.operatorRisk,
      'reversibility': context.operatorReversibility,
      'information_value': context.operatorInformationValue,
      'prediction': missing.isNotEmpty
          ? '完成当前一步后，应能确认前提“${missing.first}”是否成立'
          : context.prediction,
      'status': 'selected',
      if (missing.isNotEmpty)
        'blocked_operator_title': context.operatorTitle.trim(),
    };
    return _MethodMutation(
      state: state.copyWith(
        subgoalGraph: graph,
        activeSubgoal: subgoal,
        candidateOperators: <Map<String, Object?>>[operator],
        activeOperator: operator,
      ),
      trigger: '当前最大差距已选定，需要生成当前小步、办法并检查生效前提。',
      operationSummary: '建立 AND/OR 子目标图；逐项检查算子前提，缺失前提递归转为 PreconditionSubGoal。',
      dataMutations: <Map<String, Object?>>[
        const <String, Object?>{
          'object_type': 'SubGoalGraph',
          'operation': 'create_or_replace',
        },
        <String, Object?>{
          'object_type': 'PreconditionSubGoal',
          'operation': missing.isEmpty ? 'not_required' : 'create',
          'count': missing.length,
        },
        const <String, Object?>{
          'object_type': 'Operator',
          'operation': 'select_with_full_contract',
        },
      ],
      decisionEffect: missing.isEmpty
          ? '选定能直接作用于当前最大差距的办法。'
          : '原算子暂不执行，先把缺失前提作为当前子目标求解。',
      userVisibleSummary: '当前先做“$title”；因为它通过“${operator['mechanism']}”服务最大差距。',
      realityTest: (operator['expected_effect'] ?? '').toString(),
    );
  }

  _MethodMutation _predictionRealityLedger(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    final previous = state.predictionSummary;
    final prediction = previous.isNotEmpty ? previous : context.prediction.trim();
    final hasReality = context.reality.isNotEmpty;
    final ledger = <String, Object?>{
      ...state.predictionLedger,
      'prediction': prediction,
      'precommitted': prediction.isNotEmpty,
      'locked': true,
      if (hasReality) 'reality': context.reality,
      if (hasReality)
        'verdict': context.realityVerdict.isEmpty
            ? (context.realityConflict ? 'refutes' : 'unreviewed')
            : context.realityVerdict,
      'post_hoc_rewrite_allowed': false,
    };
    final hypotheses = _copyMaps(state.hypotheses)
        .map((item) => <String, Object?>{
              ...item,
              if (hasReality && context.realityConflict)
                'status': 'challenged_by_reality',
            })
        .toList();
    final gaps = _copyMaps(state.gaps);
    if (hasReality && context.realityConflict) {
      gaps.add(<String, Object?>{
        'id': 'gap-reality-${state.stateVersion + 1}',
        'type': 'information',
        'label': '预测与现实相反，需要重估原因与差距',
        'priority': 100,
      });
    }
    return _MethodMutation(
      state: state.copyWith(
        predictionLedger: ledger,
        lastRealityResult: context.reality,
        hypotheses: hypotheses,
        gaps: gaps,
      ),
      trigger: hasReality ? '行动结果已返回，需要与事前预测逐项对账。' : '行动即将开始，需要锁定可被反驳的事前预测。',
      operationSummary: hasReality
          ? '保留原预测并登记 RealityResult，比较支持、部分支持、反驳或未知。'
          : '在行动前预注册 Prediction 并锁定版本，禁止事后改写。',
      dataMutations: <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'PredictionLedger',
          'operation': hasReality ? 'reconcile' : 'precommit_and_lock',
        },
        if (hasReality)
          const <String, Object?>{
            'object_type': 'RealityResult',
            'operation': 'link',
          },
        if (hasReality && context.realityConflict)
          const <String, Object?>{
            'object_type': 'Hypothesis/Gap',
            'operation': 'challenge_and_update',
          },
      ],
      decisionEffect: hasReality && context.realityConflict
          ? '原候选原因被现实挑战，差距进入重估，不再沿原办法自动推进。'
          : hasReality
              ? '现实结果进入下一轮求解，决定继续、调整或回溯。'
              : '后续验算将以这条未改写预测为基线。',
      userVisibleSummary: hasReality
          ? '原来预测“$prediction”；现实已回账${context.realityConflict ? '且方向相反，军师正在重算' : ''}。'
          : '行动前预测已锁定：“$prediction”。回来后会按这条原始预测验算。',
      realityTest: prediction.isEmpty ? '补写一项可观察、可反驳的行动预测。' : '行动后记录可观察事实并与“$prediction”对账。',
    );
  }

  _MethodMutation _backtrackInspector(
    XiangjiSolverSnapshot state,
    XiangjiSignatureMethodContext context,
  ) {
    const order = <String>[
      'Execution',
      'Operator',
      'Precondition',
      'SubGoal',
      'KeyGap',
      'Goal',
      'ProblemFrame',
      'Concept',
      'Judgment',
      'Fact',
    ];
    final earliest = context.earliestFailedLayer.trim().isEmpty
        ? (context.missingPreconditions.isNotEmpty ? 'Precondition' : 'Operator')
        : context.earliestFailedLayer.trim();
    final earliestLabel = _layerLabel(earliest);
    final entry = <String, Object?>{
      'id': 'backtrack-${state.stateVersion + 1}',
      'inspection_order': order,
      'earliest_failed_layer': earliest,
      'reality': context.reality,
      'reroute': earliest == 'Execution'
          ? '修正执行条件后重试'
          : '回到 $earliestLabel 重算，再生成新办法',
    };
    final history = _copyMaps(state.backtrackHistory)..add(entry);
    final operator = <String, Object?>{
      ...state.activeOperator,
      if (state.activeOperator.isNotEmpty) 'status': 'invalidated_by_backtrack',
    };
    final subgoal = <String, Object?>{
      'id': 'subgoal-backtrack-${state.stateVersion + 1}',
      'kind': 'backtrack_repair',
      'label': '回到 $earliestLabel 重算并验证新路线',
    };
    return _MethodMutation(
      state: state.copyWith(
        backtrackHistory: history,
        activeOperator: operator,
        activeSubgoal: subgoal,
      ),
      trigger: '现实与预测不符，或行动已完成但没有产生预期效果。',
      operationSummary: '按 Execution→Operator→Precondition→SubGoal→KeyGap→Goal→ProblemFrame→Concept→Judgment→Fact 逐层定位最早错误。',
      dataMutations: const <Map<String, Object?>>[
        <String, Object?>{
          'object_type': 'BacktrackHistory',
          'operation': 'append',
        },
        <String, Object?>{
          'object_type': 'Operator',
          'operation': 'invalidate',
        },
        <String, Object?>{
          'object_type': 'SubGoal',
          'operation': 'reroute',
        },
      ],
      decisionEffect: '最早需重算层定位为“$earliestLabel”；旧路线停止，当前小步改为修复该层。',
      userVisibleSummary: '不是笼统说“失败了”：目前最早需要重算的是“$earliestLabel”，接下来会从这里换路。',
      realityTest: '执行重算后的新路线，检查同一失败信号是否消失。',
      learningLink: '复盘时记录最早错误层，而不是只评价最终结果。',
    );
  }

  String _semanticJson(XiangjiSolverSnapshot state) => jsonEncode(
        <String, Object?>{
          ...state.toPromptMap(),
        }..remove('state_version')
          ..remove('prompt_version'),
      );

  String _layerLabel(String value) => switch (value) {
        'Execution' => '实际执行',
        'Operator' => '当前办法',
        'Precondition' => '办法的生效前提',
        'SubGoal' => '当前小步',
        'KeyGap' => '当前最大差距',
        'Goal' => '现实目标',
        'ProblemFrame' => '真问题定义',
        'Concept' => '理解现实所用的概念',
        'Judgment' => '当前判断',
        'Fact' => '事实与观察',
        _ => value,
      };

  Map<String, Object?> _stateRefs(XiangjiSolverSnapshot state) =>
      <String, Object?>{
        'problem_id': state.problemId,
        'state_version': state.stateVersion,
        'problem_frame': state.problemFrame,
        'current_state': state.currentState,
        'goal_state': state.goalState,
        'hypotheses': state.hypotheses,
        'key_gap': state.keyGap,
        'active_subgoal': state.activeSubgoal,
        'active_operator': state.activeOperator,
        'epistemic_profile': state.epistemicProfile,
        'prediction_ledger': state.predictionLedger,
      };

  List<Map<String, Object?>> _copyMaps(
    Iterable<Map<String, Object?>> values,
  ) =>
      values.map((value) => <String, Object?>{...value}).toList();

  List<String> _strings(Object? value) => value is List
      ? value.map((item) => item.toString()).toList()
      : const <String>[];

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _MethodMutation {
  const _MethodMutation({
    required this.state,
    required this.trigger,
    required this.operationSummary,
    required this.dataMutations,
    required this.decisionEffect,
    required this.userVisibleSummary,
    required this.realityTest,
    this.learningLink = '',
  });

  final XiangjiSolverSnapshot state;
  final String trigger;
  final String operationSummary;
  final List<Map<String, Object?>> dataMutations;
  final String decisionEffect;
  final String userVisibleSummary;
  final String realityTest;
  final String learningLink;
}
