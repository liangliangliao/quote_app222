import 'xiangji_agent_service.dart';
import 'xiangji_rev3_models.dart';

/// Runtime form of SCK-001..018. This is deliberately executable policy, not
/// a philosophy/help page: orchestration, user-question gating and draft
/// generation all call this kernel.
class XiangjiSckRuntime {
  const XiangjiSckRuntime();

  static const Map<String, String> rules = <String, String>{
    'SCK-001': '态势模型只是可修订的主体模型，不冒充客观现实',
    'SCK-002': '经验、观察、解释、预测和抽象必须分层',
    'SCK-003': '先理解具体因果态势，再使用抽象概念与规则',
    'SCK-004': '重要结果默认保留多个竞争性原因',
    'SCK-005': '高影响求解前必须经过判断力的同异、边界和反例审查',
    'SCK-006': '概念是二阶表示，不是新的外部事实',
    'SCK-007': '重要判断必须可递归追溯到经验、证据或明确悬空',
    'SCK-008': '抽象、学术性和模型复杂度不增加确定性',
    'SCK-009': '系统化程度与认识状态分别保存',
    'SCK-010': '形式有效不能替代前提的现实根据',
    'SCK-011': '直接观察保留条件、模糊度和替代解释',
    'SCK-012': '身体感觉、情绪和非概念经验保留其异质性',
    'SCK-013': '抽象标签必须能回到实例、反例与未解释细节',
    'SCK-014': '概念、规则、预测与现实持续对照',
    'SCK-015': '每个关键算子必须说明机制、所减差距和服务目标',
    'SCK-016': '先审目标与价值；理性规划不替用户选择价值',
    'SCK-017': '信息足以支持可逆一步时停止继续分析',
    'SCK-018': '现实反驳预测时保留旧版本并修订模型',
  };

  bool shouldAskUser(XiangjiInformationNeed need) =>
      need.missing &&
      !need.canInfer &&
      need.decisionImpact.rank >= XiangjiDecisionImpact.high.rank &&
      !need.scoutingPossible;

  XiangjiAskUserDecision evaluateAskUserGuard(
    List<XiangjiInformationNeed> needs, {
    bool userDecisionPending = false,
  }) {
    if (userDecisionPending) {
      return const XiangjiAskUserDecision(
        outcome: XiangjiAskUserOutcome.userDecision,
        reason: '分析已完成，下一步涉及用户价值或现实承诺。',
      );
    }
    final askable = needs.where(shouldAskUser).toList()
      ..sort((a, b) =>
          b.decisionValuePerBurden.compareTo(a.decisionValuePerBurden));
    if (askable.isNotEmpty) {
      return XiangjiAskUserDecision(
        outcome: XiangjiAskUserOutcome.askOne,
        selectedNeed: askable.first.copyWith(selectedForQuestion: true),
        reason: '该信息缺失、影响高、现有上下文不可推断，且无法用低成本可逆侦察替代。',
      );
    }
    final scouts = needs
        .where((need) =>
            need.missing &&
            !need.canInfer &&
            need.scoutingPossible &&
            need.decisionImpact.rank >= XiangjiDecisionImpact.high.rank)
        .toList()
      ..sort((a, b) =>
          b.decisionValuePerBurden.compareTo(a.decisionValuePerBurden));
    if (scouts.isNotEmpty) {
      return XiangjiAskUserDecision(
        outcome: XiangjiAskUserOutcome.scoutInReality,
        scoutingNeeds: scouts,
        reason: '未知项更适合由低成本现实侦察清偿，不把它变成用户表单。',
      );
    }
    return const XiangjiAskUserDecision(
      outcome: XiangjiAskUserOutcome.continueAutonomous,
      reason: '没有满足 Missing + HighImpact + CannotInfer 的阻塞性未知。',
    );
  }

  /// A03 always precedes A05/A06. Strategic work always includes automatic
  /// A07-A11 gates and ends in A00/A12 synthesis; users never select roles.
  List<XiangjiAgentId> orchestrationPlan({
    required bool majorDecision,
    bool realityFeedback = false,
    bool backgroundWatch = false,
  }) {
    if (realityFeedback) {
      return <XiangjiAgentId>[
        XiangjiAgentId.reviewHistorian,
        XiangjiAgentId.judgmentEngine,
        XiangjiAgentId.problemFramer,
        XiangjiAgentId.solver,
        if (majorDecision) ...const <XiangjiAgentId>[
          XiangjiAgentId.campaignSelector,
          XiangjiAgentId.resourcePlanner,
          XiangjiAgentId.strategist,
          XiangjiAgentId.redTeam,
          XiangjiAgentId.wargameContingency,
        ],
        XiangjiAgentId.chiefStrategist,
        XiangjiAgentId.methodTranslator,
        XiangjiAgentId.personalScienceLearner,
        XiangjiAgentId.methodEffectValidator,
        XiangjiAgentId.antiTemplateValidator,
      ];
    }
    if (backgroundWatch) {
      return const <XiangjiAgentId>[
        XiangjiAgentId.monitor,
        XiangjiAgentId.chiefStrategist,
      ];
    }
    return <XiangjiAgentId>[
      XiangjiAgentId.epistemicAuditor,
      XiangjiAgentId.causalAnalyst,
      XiangjiAgentId.judgmentEngine,
      XiangjiAgentId.groundingAuditor,
      XiangjiAgentId.problemFramer,
      XiangjiAgentId.solver,
      if (majorDecision) ...const <XiangjiAgentId>[
        XiangjiAgentId.campaignSelector,
        XiangjiAgentId.resourcePlanner,
        XiangjiAgentId.strategist,
        XiangjiAgentId.redTeam,
        XiangjiAgentId.wargameContingency,
      ],
      XiangjiAgentId.chiefStrategist,
      XiangjiAgentId.actionOfficer,
      XiangjiAgentId.methodTranslator,
      XiangjiAgentId.methodEffectValidator,
      XiangjiAgentId.antiTemplateValidator,
    ];
  }

  List<XiangjiOrchestrationState> orchestrationStates({
    required bool majorDecision,
  }) =>
      <XiangjiOrchestrationState>[
        XiangjiOrchestrationState.cognitiveModeling,
        XiangjiOrchestrationState.problemSolving,
        if (majorDecision) XiangjiOrchestrationState.strategicCouncil,
        XiangjiOrchestrationState.actionCompression,
      ];

  XiangjiSituationDraft buildLocalDraft(
    String utterance, {
    List<String> attachmentRefs = const <String>[],
    String attachmentText = '',
    bool forceStrategic = false,
  }) {
    final raw = utterance.trim();
    if (raw.isEmpty) throw ArgumentError('请先告诉军师你想要什么、发生了什么，或卡在哪里。');
    final sourceText = <String>[raw, attachmentText.trim()]
        .where((item) => item.isNotEmpty)
        .join('\n');
    final sentences = _sentences(sourceText);
    final major = forceStrategic || _matches(sourceText, _majorDecisionTerms);
    final highRisk = _matches(sourceText, _highRiskTerms);
    final irreversible = _matches(sourceText, _irreversibleTerms);
    final notWorthFighting = _matches(sourceText, _lowValueConflictTerms);
    final opportunityWindow = _matches(sourceText, _opportunityTerms);
    final emotions = sentences.where((text) => _matches(text, _experienceTerms)).toList();
    final interpretations = sentences
        .where((text) => _matches(text, _interpretationTerms))
        .toList();
    final predictions = sentences
        .where((text) => _matches(text, _predictionTerms))
        .toList();
    final facts = _extractObservedFacts(sentences);
    final need = _inferNeed(raw);
    final assumptions = _hiddenAssumptions(raw, major: major);
    final constraints = _constraintsFor(
      sourceText,
      highRisk: highRisk,
      irreversible: irreversible,
    );
    final urgentIrreversible =
        irreversible && _matches(sourceText, _urgentTerms);
    final hasBoundaryData = RegExp(
      r'(?:截止|最迟|期限|预算|损失|违约|撤回|退出成本|上限)[^\n。！？]{0,24}(?:\d|今天|明天|本周|下周|随时|没有|不能|可以|无)',
    ).hasMatch(sourceText);
    final decisiveEvidencePresent =
        _matches(sourceText, _decisiveEvidenceTerms);
    final resourcesReady = _matches(sourceText, _resourceReadyTerms);
    final commitmentBoundaryReady = hasBoundaryData ||
        _matches(sourceText, _commitmentBoundaryReadyTerms);
    final readyForBoundedCommitment = decisiveEvidencePresent &&
        resourcesReady &&
        commitmentBoundaryReady;

    final informationNeeds = <XiangjiInformationNeed>[];
    if (urgentIrreversible && !commitmentBoundaryReady) {
      informationNeeds.add(XiangjiInformationNeed(
        id: 'decision_boundary',
        question: '最迟何时必须决定，以及撤回、违约或失败的现实成本上限是什么？',
        missingField: 'irreversible_decision_boundary',
        decisionImpact: XiangjiDecisionImpact.critical,
        scoutingPossible: false,
        expectedValueOfInformation: 10,
        userBurden: 1,
      ));
    } else if (major && !decisiveEvidencePresent) {
      informationNeeds.add(const XiangjiInformationNeed(
        id: 'route_discriminator',
        question: '哪一个现实结果最能区分“继续、试探、等待或退出”四条路线？',
        missingField: 'route_discriminating_evidence',
        decisionImpact: XiangjiDecisionImpact.high,
        scoutingPossible: true,
        scoutingOption: '先做一次不承诺长期资源的现实访谈、样品、小项目或数据核实。',
        expectedValueOfInformation: 8,
        userBurden: 4,
      ));
    }

    final trueProblem = _trueProblemFor(
      raw,
      need: need,
      major: major,
      notWorthFighting: notWorthFighting,
    );
    final opportunityReady = opportunityWindow && readyForBoundedCommitment;
    late final String targetGap;
    if (urgentIrreversible && !commitmentBoundaryReady) {
      targetGap = '缺少决定期限、不可逆成本与可退出边界';
    } else if (opportunityReady) {
      targetGap = '如何在窗口有效期内，用限额投入兑现已经得到支持的机制';
    } else if (readyForBoundedCommitment) {
      targetGap = '检验已获支持的机制能否稳定推进成功判据';
    } else if (major) {
      targetGap = '缺少能区分多条战略路线的现实证据';
    } else {
      targetGap = '缺少一个能验证当前理解的可观察结果';
    }
    final scout = major
        ? '在不做长期承诺的前提下，完成一次 25 分钟现实侦察：核实最可能改变路线选择的关键假设'
        : '用 15 分钟完成一个最小可逆实验，并记录实际发生了什么';
    late final String currentAction;
    if (urgentIrreversible && !commitmentBoundaryReady) {
      currentAction = '先暂停不可逆承诺，补齐决定期限与退出成本';
    } else if (notWorthFighting) {
      currentAction =
          '暂停对这场争论追加回应 24 小时，并写下一条它实际推进核心结果的可观察证据；没有证据就停止恋战';
    } else if (opportunityReady) {
      currentAction =
          '在已经明确的资源上限与退出条件内，围绕已获支持的机制集中推进一个周期，并记录领先指标';
    } else if (readyForBoundedCommitment) {
      currentAction = '围绕已获支持的机制限额推进一个周期，并按事前成功判据记录现实结果';
    } else if (opportunityWindow) {
      currentAction = '用 25 分钟核实机会窗口、资源上限与退出条件；三项成立后再集中一个周期';
    } else {
      currentAction = scout;
    }
    final changeSignals = major
        ? '关键假设被新事实反驳；资源消耗连续上升但结果两周期不变；出现更低成本、更可逆的路线。'
        : '最小实验没有缩小差距；现实结果与事前预测相反；出现新的高影响约束。';

    final caseLabel = need.length > 18 ? '${need.substring(0, 18)}…' : need;
    final scoutAssumption = facts.isEmpty
        ? '能够取得至少一个与“$caseLabel”直接相关的现实样本'
        : '新增样本能区分当前至少两个候选原因';
    final preferRetreat = notWorthFighting;
    final preferHold = !preferRetreat &&
        major &&
        urgentIrreversible &&
        !commitmentBoundaryReady;
    final preferOpportunity =
        !preferRetreat && !preferHold && opportunityReady;
    final preferBounded = !preferRetreat &&
        !preferHold &&
        !preferOpportunity &&
        readyForBoundedCommitment;
    final preferScout = !preferRetreat &&
        !preferHold &&
        !preferOpportunity &&
        !preferBounded;
    final options = <Map<String, Object?>>[
      <String, Object?>{
        'name': '先验证“$caseLabel”的关键未知',
        'type': 'case_discriminating_scout',
        'preferred': preferScout,
        'target_gap': targetGap,
        'mechanism_for_this_case':
            '执行“$currentAction”，让不同候选原因产生可比较的现实结果。',
        'key_assumption': scoutAssumption,
        'benefits': const <String>['直接增加能改变下一步的现实信息', '保留退出与修订空间'],
        'costs': const <String>['短期内仍不会得到终局答案'],
        'opportunity_cost': '占用一个短复核周期，但不会锁死长期资源。',
        'reversibility': 'high',
        'assumptions': <String>[scoutAssumption],
        'why_preferred': preferScout
            ? '当前最稀缺的是能区分路线的事实；这条路线以最低不可逆成本直接减少“$targetGap”。'
            : '',
        'why_not_other_options':
            '直接加码会把尚未验证的解释当成事实；单纯等待又不会主动产生新信息。',
        'switch_trigger':
            '若现实样本已经稳定支持同一机制，转为限额推进；若反驳核心前提，回溯并重构。',
        'stop_conditions': <String>['连续两轮没有新增决定信息', changeSignals],
        'user_summary': '先用现实区分原因，再决定是否投入更多。',
      },
      <String, Object?>{
        'name': '围绕“$caseLabel”限额推进一个周期',
        'type': 'case_bounded_commitment',
        'preferred': preferBounded,
        'target_gap': targetGap,
        'mechanism_for_this_case':
            '在明确时间与资源上限内重复当前有效机制，以检验它能否稳定推进成功判据。',
        'key_assumption': '当前机制已有初步现实支持，且资源上限与退出条件能够被执行',
        'benefits': const <String>['更快检验机制能否稳定产生结果', '形成跨周期领先指标'],
        'costs': const <String>['占用更多时间、注意力或资金', '错误前提的代价会上升'],
        'opportunity_cost': '该周期内减少其他路线可用的注意力与资源。',
        'reversibility': irreversible ? 'low' : 'medium',
        'assumptions': const <String>['成功判据、资源上限和退出条件已经明确'],
        'why_preferred': preferBounded
            ? '关键未知已有决定性现实支持，资源上限与退出边界也已明确；继续侦察的边际价值低于限额推进。'
            : '',
        'why_not_other_options': preferBounded
            ? '继续等待或重复侦察不会充分利用已解决的未知；一次性重押又超过现有证据边界。'
            : '现阶段现实支持或资源边界仍不足，因此不作为首选；条件成立后再切换。',
        'switch_trigger': '出现稳定领先指标时继续；预测落空或触及资源上限时转回侦察或退出。',
        'stop_conditions': <String>['触及预设资源上限仍未出现领先指标', changeSignals],
        'user_summary': '只投入一个可复核周期，用结果决定是否继续。',
      },
      if (major)
        <String, Object?>{
          'name': '为“$caseLabel”保全资源并等待触发',
          'type': 'case_hold_with_trigger',
          'preferred': preferHold,
          'target_gap': targetGap,
          'mechanism_for_this_case': '暂停新增承诺，预先定义会让等待结束的事实或期限。',
          'key_assumption': '等待期间不会产生超过可承受上限的不可恢复损失',
          'benefits': const <String>['保护关键资源', '避免在认识债务下过早承诺'],
          'costs': const <String>['可能承担窗口缩小的代价'],
          'opportunity_cost': '承担等待期间的窗口损失，并延后对核心机制的验证。',
          'reversibility': 'high',
          'assumptions': const <String>['等待不会立即造成不可恢复损失'],
          'why_preferred': preferHold
              ? '当前承诺不可逆且决定期限或退出成本尚不清楚；先保全资源能够避免把边界未知变成现实损失。'
              : '',
          'why_not_other_options': preferHold
              ? '直接推进会跨过尚未明确的不可逆边界；普通侦察也不能替代用户必须确认的承诺边界。'
              : '如果低成本侦察已经可行，纯等待的信息收益更低。',
          'switch_trigger': '决定期限临近、关键事实出现或等待成本超过上限时重新军议。',
          'stop_conditions': const <String>['窗口或约束发生明确变化', '到达预设复核时间'],
          'user_summary': '先保全资源，但用明确触发避免无限拖延。',
        },
      if (notWorthFighting)
        <String, Object?>{
          'name': '停止为“$caseLabel”继续恋战',
          'type': 'case_retreat',
          'preferred': preferRetreat,
          'target_gap': '继续投入未能推进真正要保护的结果',
          'mechanism_for_this_case': '停止新增回应，把注意力转回可观察的核心结果。',
          'key_assumption': '继续争论不能实质改变目标结果',
          'benefits': const <String>['收回注意力与时间', '停止沉没成本升级'],
          'costs': const <String>['放弃即时证明或情绪回报'],
          'opportunity_cost': '放弃继续争论可能带来的低概率收益。',
          'reversibility': 'high',
          'assumptions': const <String>['争论不再推进核心结果'],
          'why_preferred': '当前投入与目标结果脱节，继续加码只会扩大沉没成本。',
          'why_not_other_options': '试探和集中都仍在给低价值战线追加主力。',
          'switch_trigger': '出现能实质改变核心结果的新事实时再重新评估。',
          'stop_conditions': const <String>['出现能实质改变结果的新证据'],
          'user_summary': '停止加码，把资源收回到真正重要的结果。',
        },
      if (opportunityWindow)
        <String, Object?>{
          'name': '核实后抓住“$caseLabel”的窗口',
          'type': 'case_opportunity_concentration',
          'preferred': preferOpportunity,
          'target_gap': '机会窗口、可用资源与退出路径是否同时真实成立',
          'mechanism_for_this_case': '先核实三项窗口条件，再在限额周期内集中主力。',
          'key_assumption': '窗口真实、资源上限明确且退出路径可执行',
          'benefits': const <String>['利用时间敏感机会', '缩短验证周期'],
          'costs': const <String>['短期占用更多主力资源'],
          'opportunity_cost': '集中期间暂停其他非主战线投入。',
          'reversibility': 'medium',
          'assumptions': const <String>['窗口真实', '资源上限明确', '退出路径存在'],
          'why_preferred': preferOpportunity
              ? '机会窗口、关键机制、资源上限与退出路径都已有现实根据；限额集中最能把时间优势转成目标结果。'
              : '',
          'why_not_other_options': preferOpportunity
              ? '继续等待或重复侦察会消耗已经确认的窗口；无限加码又没有保留退出纪律。'
              : '三项条件尚未核实时，直接集中会放大误判代价。',
          'switch_trigger': '三项条件全部核实后转为集中；任一失效则回到保全或侦察。',
          'stop_conditions': const <String>['窗口条件失效', '触及预设资源上限'],
          'user_summary': '先核实窗口，再限额集中，不把“机会”当成事实。',
        },
    ];

    late final String judgment;
    late final String recommendation;
    if (urgentIrreversible && !commitmentBoundaryReady) {
      judgment = '当前不是继续优化方案的时候；不可逆边界尚不清楚，先冻结承诺。';
      recommendation = '先补齐一个决定性边界，再继续谋划。';
    } else if (notWorthFighting) {
      judgment = '这场争论若不能推进核心结果，就不值得继续消耗主力；停止恋战是战略选择，不是失败。';
      recommendation = '优先停止加码这场低价值争论，把注意力收回到真正要保护或推进的结果。';
    } else if (opportunityReady) {
      judgment = '关键机制与窗口条件已经得到支持，当前应在明确上限内集中，而不是继续重复侦察。';
      recommendation = '采用限额集中路线，在窗口内推进一个周期并严格执行退出条件。';
    } else if (readyForBoundedCommitment) {
      judgment = '关键未知与资源边界已经满足，当前应从侦察切换为限额推进并验证稳定性。';
      recommendation = '采用限额推进路线，不再机械重复侦察。';
    } else if (opportunityWindow) {
      judgment = '机会可能有时间价值，但窗口、资源与退出边界仍需先核实。';
      recommendation = '先核实窗口和退出边界；成立时限额集中，不成立就保全资源。';
    } else if (major) {
      judgment = '目前最有价值的是用可逆行动取得能区分路线的现实证据。';
      recommendation = '优先采用可逆试探，暂不把资源一次押在单一路线。';
    } else {
      judgment = '目前最有价值的不是继续抽象分析，而是用低成本行动取得能改变判断的现实证据。';
      recommendation = '先做最小可逆实验，以现实结果替代继续猜测。';
    }

    return XiangjiSituationDraft(
      need: need,
      summary: '用户正在处理“$need”。当前模型保留原话，并把观察、体验、解释和预测分开；这只是可修订的 AI 模型。',
      trueProblem: trueProblem,
      goal: major ? '形成一项有胜利、止损与复核边界的现实决策' : '用现实反馈缩小关键差距',
      valueLink: '在重要结果、可承受风险与个人自主之间保持一致',
      successCriteria: major
          ? '获得至少一条能区分路线的现实证据，并能明确采用、调整、等待或退出'
          : '完成一个可观察的最小实验，并能据结果继续、调整或停止',
      exitCriteria: '若触及时间、金钱、安全或关系边界仍未出现预期信号，就暂停并重构问题。',
      judgment: judgment,
      recommendation: recommendation,
      why: readyForBoundedCommitment
          ? '决定性现实证据、可用资源与承诺边界已经同时具备；因此把首选从继续侦察切换为限额推进，同时保留停止与回溯条件。'
          : '当前根据主要来自用户原话${attachmentRefs.isEmpty ? '' : '和所附材料'}，认识状态仍是暂时支持；可逆侦察能以较低成本清偿最关键未知。',
      currentAction: currentAction,
      targetGap: targetGap,
      operatorMechanism: '把关键假设放进现实，通过可观察结果区分竞争解释，而不是要求用户先填完内部分析表。',
      strategicMeaning: major ? '保留兵力和后手，同时提高下一轮决断质量。' : '尽快进入“行动—现实—修正”闭环。',
      groundingReason: facts.isEmpty
          ? '目前仅有用户原话与直接体验，外部事实尚未独立核实。'
          : '根据来自用户报告的可观察事件；外部原因仍保留为候选解释。',
      prediction: '完成当前一步后，应至少得到一条可观察事实，足以支持继续、调整、等待或停止中的一个选择。',
      changeSignals: changeSignals,
      observedFacts: facts,
      bodyExperiences: emotions,
      userInterpretations: interpretations,
      predictions: predictions,
      assumptions: assumptions,
      constraints: constraints,
      unknowns: informationNeeds.map((item) => item.question).toList(),
      causalHypotheses: _caseCauses(sourceText, need),
      relevantSimilarities: const <String>['都涉及重要结果与不确定性'],
      relevantDifferences: _judgmentDifferences(
        sourceText,
        major: major,
        irreversible: irreversible,
      ),
      counterexamples: const <String>['一次失败不等于方向永远错误；一次成功也不证明路线长期有效。'],
      subGoals: <String>[
        '保留用户原话并识别当前需要',
        '找到最可能改变判断的一个未知',
        '执行可逆验证并记录现实',
        '用现实修订问题、概念与下一步',
      ],
      operators: options,
      strategyOptions: options,
      redTeam: <String>[
        '[假设] 最脆弱前提：一次小样本可能不能代表长期结果。',
        '[假设] 失败路径：把“做了行动”误当成“目标已经推进”。',
        '[规则] 反证要求：若投入上升而领先指标连续两轮不变，应停止原路线。',
      ],
      informationNeeds: informationNeeds,
      expectedMinutes:
          urgentIrreversible && !commitmentBoundaryReady ? 10 : (major ? 25 : 15),
      majorDecision: major,
      highRisk: highRisk,
      irreversible: irreversible,
      epistemicStatus: informationNeeds.isEmpty ? 'PROVISIONAL' : 'EPISTEMIC_DEBT',
    );
  }

  bool operatorHasMechanism(XiangjiSituationDraft draft) =>
      draft.currentAction.trim().isNotEmpty &&
      draft.targetGap.trim().isNotEmpty &&
      draft.operatorMechanism.trim().isNotEmpty &&
      draft.strategicMeaning.trim().isNotEmpty &&
      draft.groundingReason.trim().isNotEmpty &&
      draft.prediction.trim().isNotEmpty;

  String reconcilePrediction({
    required String prediction,
    required String realityFeedback,
  }) {
    final feedback = realityFeedback.trim();
    if (feedback.isEmpty) return 'indeterminate';
    if (_matches(feedback, const <String>[
      '没有', '未', '相反', '反而', '失败', '不符合', '无人回复', '没人回复'
    ])) {
      return 'contradicts';
    }
    if (_matches(feedback, const <String>['部分', '一点', '但', '同时', '不完全'])) {
      return 'partially_supports';
    }
    return prediction.trim().isEmpty ? 'indeterminate' : 'supports';
  }

  XiangjiRealityExtraction extractRealityFeedback(String feedback) {
    final sentences = _sentences(feedback);
    final experiences = sentences
        .where((item) => _matches(item, _experienceTerms))
        .take(5)
        .toList();
    final interpretations = sentences
        .where((item) => _matches(item, _interpretationTerms))
        .take(5)
        .toList();
    final unexpected = sentences
        .where((item) => _matches(item, const <String>[
              '但', '却', '反而', '没有', '没', '未', '意外', '原来', '相反',
            ]))
        .take(5)
        .toList();
    final facts = _extractObservedFacts(sentences)
        .where((item) => !experiences.contains(item))
        .take(5)
        .toList();
    return XiangjiRealityExtraction(
      facts: facts.isEmpty && sentences.isNotEmpty
          ? <String>['用户报告了一项主观体验：${sentences.first}']
          : facts,
      experiences: experiences,
      unexpected: unexpected,
      interpretations: interpretations,
    );
  }

  String _inferNeed(String raw) {
    var value = raw
        .replaceFirst(RegExp(r'^(我想|我希望|我需要|请帮我|帮我|我不知道怎么|怎样|如何)'), '')
        .trim();
    if (value.isEmpty || value == '办') return raw;
    return value.length > 90 ? '${value.substring(0, 90)}…' : value;
  }

  String _trueProblemFor(
    String raw, {
    required String need,
    required bool major,
    required bool notWorthFighting,
  }) {
    if (notWorthFighting) {
      return '真正要保护或推进的结果是什么，以及继续投入这场争论是否比停止恋战更值得？';
    }
    if (_matches(raw, const <String>['毅力', '坚持']) &&
        _matches(raw, const <String>['工作', '项目', '路线', '方向'])) {
      return '在训练毅力之前，当前工作或路线是否值得继续；若值得，哪一个现实障碍最先解决？';
    }
    return major
        ? '在不让恐惧或沉没成本替我决断的前提下，怎样用现实证据判断“$need”是否值得持续投入，并选择可退出的路线？'
        : '怎样把“$need”从模糊困境转成一个可验证、可修订的现实下一步？';
  }

  List<String> _extractObservedFacts(List<String> sentences) {
    final facts = <String>[];
    final seen = <String>{};
    for (final sentence in sentences) {
      final split = RegExp(r'(?:就是|说明|代表|意味着|所以|因此)')
          .firstMatch(sentence);
      if (split != null && split.start > 0) {
        final observation = sentence.substring(0, split.start).trim();
        if (observation.isNotEmpty && seen.add(observation)) {
          facts.add(observation);
        }
      }
      if ((_matches(sentence, _observableTerms) ||
              RegExp(r'\d').hasMatch(sentence)) &&
          !_matches(sentence, _interpretationTerms) &&
          seen.add(sentence)) {
        facts.add(sentence);
      }
    }
    return facts.take(12).toList();
  }

  List<String> _hiddenAssumptions(String raw, {required bool major}) {
    if (_matches(raw, const <String>['毅力', '坚持']) &&
        _matches(raw, const <String>['工作', '项目', '路线', '方向'])) {
      return const <String>['隐藏前提：当前工作或路线值得继续；该前提必须先由现实结果与价值边界审查。'];
    }
    if (_matches(raw, _lowValueConflictTerms)) {
      return const <String>['隐藏前提：证明对方错误或赢得争论会推进真正目标。'];
    }
    return <String>[
      major
          ? '当前想到的选项可能被误当成唯一可行路线。'
          : '当前解释可能被误当成唯一原因。',
    ];
  }

  List<String> _caseCauses(String sourceText, String need) {
    if (_matches(sourceText, const <String>[
      '工作', '离职', '辞职', '职业', '项目', '公司', '上班', '毅力', '坚持'
    ])) {
      return <String>[
        '工作内容或组织环境与真正重视的结果不匹配 | 比较一周内哪些具体任务增加或消耗目标相关能力',
        '能力、资源或反馈回路不足使投入难以转成进展 | 选择一个技能或反馈瓶颈做限额实验',
        '疲惫、焦虑或挫败体验被直接解释成“不适合” | 改变任务、休息与反馈条件后观察体验是否同步变化',
      ];
    }
    if (_matches(sourceText, const <String>[
      '关系', '伴侣', '朋友', '同事', '争论', '吵架', '沟通', '对方'
    ])) {
      return <String>[
        '双方目标或边界并未被具体表达 | 用一次只讨论可观察请求的对话比较结果',
        '互动机制反复触发防御而非内容本身不可解决 | 改变时机、媒介或表达方式后观察回应',
        '继续投入主要在满足证明冲动而非推进关系结果 | 暂停追加回应并记录核心结果是否受损',
      ];
    }
    if (_matches(sourceText, const <String>[
      '创业', '投资', '合同', '机会', '市场', '客户', '收入'
    ])) {
      return <String>[
        '需求或机会窗口尚未被真实行为验证 | 获取一个付费、签约或明确拒绝的市场样本',
        '价值主张成立但渠道、时机或信任机制不匹配 | 只改变一个渠道变量并比较转化信号',
        '资源约束使正确方向也无法按当前方案执行 | 用限额预算比较最小可行路径与资源消耗',
      ];
    }
    return <String>[
      '关于“$need”的现实样本仍太少 | 获取一个与当前判断独立的可观察样本',
      '目标、路径或价值可能被混在一起 | 分别比较结果判据与至少一条替代路径',
      '资源、能力或环境与当前办法不匹配 | 只改变一个关键条件并对照事前预测',
    ];
  }

  List<String> _constraintsFor(
    String sourceText, {
    required bool highRisk,
    required bool irreversible,
  }) {
    final values = <String>['先把当前验证限制在一个可复核周期内。'];
    if (_matches(sourceText, _urgentTerms)) {
      values.add('存在时间边界；具体期限仍需以现实记录为准。');
    }
    if (irreversible) values.add('当前选择包含低可逆或不可逆承诺。');
    if (highRisk) values.add('安全、法律、医疗或重大财务边界需要专业复核。');
    return values;
  }

  List<String> _judgmentDifferences(
    String sourceText, {
    required bool major,
    required bool irreversible,
  }) {
    final values = <String>[
      major ? '本题需要跨周期资源与多路线比较' : '本题可先由单个可逆行动验证',
      irreversible ? '包含低可逆或不可逆承诺' : '当前一步可保持高可逆性',
    ];
    if (_matches(sourceText, const <String>['技能增长', '学到', '成长']) &&
        _matches(sourceText, const <String>['停滞', '没有进展', '原地'])) {
      values.add('表面都可叫“失败”，但一个增加了目标相关能力，另一个没有形成可复用进展。');
    }
    return values;
  }

  List<String> _sentences(String value) => value
      .split(RegExp(r'[\n。！？!?；;]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(12)
      .toList();

  bool _matches(String value, List<String> terms) =>
      terms.any((term) => value.contains(term));

  static const List<String> _majorDecisionTerms = <String>[
    '辞职', '离职', '转行', '创业', '结婚', '离婚', '买房', '卖房', '移民', '搬家',
    '投资', '合同', '合伙', '手术', '长期', '职业', '公司', '项目', '战略', '战役',
    '机会窗口', '窗口期',
  ];
  static const List<String> _highRiskTerms = <String>[
    '自杀', '伤害', '暴力', '违法', '手术', '疾病', '全部积蓄', '高杠杆', '不可逆',
  ];
  static const List<String> _irreversibleTerms = <String>[
    '不可逆', '辞职', '离婚', '结婚', '手术', '签约', '合同', '全部投入', '卖房', '移民',
  ];
  static const List<String> _urgentTerms = <String>[
    '马上', '现在', '今天', '立刻', '必须', '最后期限', '截止',
  ];
  static const List<String> _experienceTerms = <String>[
    '害怕', '担心', '焦虑', '难受', '紧张', '胸口', '睡不着', '生气', '开心', '疲惫',
    '不对劲', '说不清', '抗拒',
  ];
  static const List<String> _interpretationTerms = <String>[
    '觉得', '认为', '就是', '一定', '不适合', '没希望', '没用', '应该', '故意',
  ];
  static const List<String> _predictionTerms = <String>[
    '担心', '害怕', '恐怕', '可能会', '将会', '以后会', '一定会',
  ];
  static const List<String> _observableTerms = <String>[
    '已经', '发生', '收到', '完成', '做了', '投了', '回复', '说了', '去了', '连续', '今天',
    '昨天', '上周', '本周', '投递', '简历', 'offer', '面试', '成交', '收入', '花了',
  ];
  static const List<String> _lowValueConflictTerms = <String>[
    '低价值争论', '争论', '吵架', '争口气', '证明他错', '证明她错',
  ];
  static const List<String> _opportunityTerms = <String>[
    '机会窗口', '窗口期', '限时机会', '名额开放', '突然出现机会',
  ];
  static const List<String> _decisiveEvidenceTerms = <String>[
    '关键未知已解决', '关键未知已经解决', '已经验证', '已经确认', '证据已支持',
    '现实支持', '连续两轮有效', '连续两次有效', '机制已验证', '结果稳定',
  ];
  static const List<String> _resourceReadyTerms = <String>[
    '资源充足', '资源已经到位', '预算充足', '预算已明确', '时间充足', '时间已留出',
    '人手充足', '人手已到位', '注意力可集中', '能够投入一个周期',
  ];
  static const List<String> _commitmentBoundaryReadyTerms = <String>[
    '资源上限明确', '退出路径明确', '退出条件明确', '止损条件明确', '止损已明确',
    '期限已明确', '可随时退出', '撤回成本可承受',
  ];
}
