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

  /// A02 always precedes A05/A06. Strategic work always includes an automatic
  /// A08 red team and ends in A00 synthesis; users never select these roles.
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
        if (majorDecision) XiangjiAgentId.strategist,
        if (majorDecision) XiangjiAgentId.redTeam,
        XiangjiAgentId.chiefStrategist,
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
      if (majorDecision) XiangjiAgentId.strategist,
      if (majorDecision) XiangjiAgentId.redTeam,
      XiangjiAgentId.chiefStrategist,
      XiangjiAgentId.actionOfficer,
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

    final informationNeeds = <XiangjiInformationNeed>[];
    if (urgentIrreversible && !hasBoundaryData) {
      informationNeeds.add(XiangjiInformationNeed(
        id: 'decision_boundary',
        question: '最迟何时必须决定，以及撤回、违约或失败的现实成本上限是什么？',
        missingField: 'irreversible_decision_boundary',
        decisionImpact: XiangjiDecisionImpact.critical,
        scoutingPossible: false,
        expectedValueOfInformation: 10,
        userBurden: 1,
      ));
    } else if (major) {
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
    final targetGap = urgentIrreversible
        ? '缺少决定期限、不可逆成本与可退出边界'
        : major
            ? '缺少能区分多条战略路线的现实证据'
            : '缺少一个能验证当前理解的可观察结果';
    final scout = major
        ? '在不做长期承诺的前提下，完成一次 25 分钟现实侦察：核实最可能改变路线选择的关键假设'
        : '用 15 分钟完成一个最小可逆实验，并记录实际发生了什么';
    final currentAction = urgentIrreversible && !hasBoundaryData
        ? '先暂停不可逆承诺，补齐决定期限与退出成本'
        : notWorthFighting
            ? '暂停对这场争论追加回应 24 小时，并写下一条它实际推进核心结果的可观察证据；没有证据就停止恋战'
            : opportunityWindow
                ? '用 25 分钟核实机会窗口、资源上限与退出条件；三项成立后再集中一个周期'
                : scout;
    final changeSignals = major
        ? '关键假设被新事实反驳；资源消耗连续上升但结果两周期不变；出现更低成本、更可逆的路线。'
        : '最小实验没有缩小差距；现实结果与事前预测相反；出现新的高影响约束。';

    final options = <Map<String, Object?>>[
      <String, Object?>{
        'name': '可逆试探',
        'type': 'scout',
        'benefits': const <String>['低成本获得真实反馈', '保留退出空间'],
        'costs': const <String>['结论仍是暂时的'],
        'opportunity_cost': '占用一次短周期验证时间，但不锁死长期资源',
        'reversibility': 'high',
        'assumptions': const <String>['存在可接触的现实样本或信息源'],
        'stop_conditions': const <String>['连续两轮没有新增决定信息'],
      },
      <String, Object?>{
        'name': '限额集中推进',
        'type': 'bounded_commitment',
        'benefits': const <String>['更快检验执行与结果链'],
        'costs': const <String>['消耗更多时间与注意力'],
        'opportunity_cost': '暂时减少其他路线的时间与注意力',
        'reversibility': irreversible ? 'low' : 'medium',
        'assumptions': const <String>['成功判据与资源上限已明确'],
        'stop_conditions': const <String>['触及资源上限仍未出现领先指标'],
      },
      if (major)
        <String, Object?>{
          'name': '等待/保全',
          'type': 'hold',
          'benefits': const <String>['保护关键资源', '等待更高价值信息'],
          'costs': const <String>['可能错过窗口'],
          'opportunity_cost': '承担等待期间的窗口损失',
          'reversibility': 'high',
          'assumptions': const <String>['等待不会立即造成不可恢复损失'],
          'stop_conditions': const <String>['窗口或约束发生明确变化'],
        },
      if (notWorthFighting)
        <String, Object?>{
          'name': '停止恋战',
          'type': 'retreat',
          'benefits': const <String>['收回注意力与时间', '停止沉没成本升级'],
          'costs': const <String>['放弃证明或即时情绪回报'],
          'opportunity_cost': '放弃继续争论可能带来的低概率收益',
          'reversibility': 'high',
          'assumptions': const <String>['争论不再推进核心结果'],
          'stop_conditions': const <String>['出现能实质改变结果的新证据'],
        },
      if (opportunityWindow)
        <String, Object?>{
          'name': '窗口期集中',
          'type': 'opportunity_concentration',
          'benefits': const <String>['利用时间敏感机会', '缩短验证周期'],
          'costs': const <String>['短期占用更多主力资源'],
          'opportunity_cost': '集中期间暂停其他非主战线投入',
          'reversibility': 'medium',
          'assumptions': const <String>['窗口真实、资源上限明确、退出路径存在'],
          'stop_conditions': const <String>['窗口条件失效或触及预设资源上限'],
        },
    ];

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
      judgment: urgentIrreversible && !hasBoundaryData
          ? '当前不是继续优化方案的时候；不可逆边界尚不清楚，先冻结承诺。'
          : notWorthFighting
              ? '这场争论若不能推进核心结果，就不值得继续消耗主力；停止恋战是战略选择，不是失败。'
              : '目前最有价值的不是继续抽象分析，而是用一个低成本、可逆行动取得能改变判断的现实证据。',
      recommendation: urgentIrreversible && !hasBoundaryData
          ? '先补齐一个决定性边界，再继续谋划。'
          : notWorthFighting
              ? '优先停止加码这场低价值争论，把注意力收回到真正要保护或推进的结果。'
              : opportunityWindow
                  ? '先核实窗口和退出边界；成立时限额集中，不成立就保全资源。'
                  : major
                      ? '优先采用“可逆试探”，暂不把资源一次押在单一路线。'
                      : '先做最小可逆实验，以现实结果替代继续猜测。',
      why: '当前根据主要来自用户原话${attachmentRefs.isEmpty ? '' : '和所附材料'}，认识状态仍是暂时支持；可逆侦察能以较低成本清偿最关键未知。',
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
      causalHypotheses: const <String>[
        '信息不足或反馈样本太少 | 获取一个独立现实样本后比较',
        '目标、路径或价值被混在一起 | 分别写出结果判据与可替代路径',
        '资源/能力与当前路线不匹配 | 用限额试探比较投入和领先指标',
      ],
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
      expectedMinutes: urgentIrreversible && !hasBoundaryData ? 10 : (major ? 25 : 15),
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
}
