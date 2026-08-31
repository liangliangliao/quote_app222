import 'dart:convert';

/// The user-facing product contract for Future Strategist V6.2.
///
/// The solver, knowledge graph and agent orchestration remain rich internally,
/// but the default experience is deliberately small: describe one real need,
/// choose one workable route, act once, and let new reality revise the model.
class XiangjiPracticalFlowStep {
  const XiangjiPracticalFlowStep({
    required this.id,
    required this.title,
    required this.userAction,
    required this.systemWork,
    required this.output,
    required this.coreConceptIds,
  });

  final String id;
  final String title;
  final String userAction;
  final String systemWork;
  final String output;
  final List<String> coreConceptIds;
}

class XiangjiFeatureGuide {
  const XiangjiFeatureGuide({
    required this.id,
    required this.title,
    required this.aliases,
    required this.what,
    required this.whenToUse,
    required this.whatToProvide,
    required this.steps,
    required this.output,
    required this.why,
    required this.problemSolved,
    required this.coreConceptIds,
    required this.knowledgeSource,
    this.thinkerNames = const <String>['叔本华'],
    this.startPrompt = '',
    this.destination = '',
  });

  final String id;
  final String title;
  final List<String> aliases;
  final String what;
  final String whenToUse;
  final String whatToProvide;
  final List<String> steps;
  final String output;
  final String why;
  final String problemSolved;
  final List<String> coreConceptIds;
  final String knowledgeSource;
  final List<String> thinkerNames;
  final String startPrompt;
  final String destination;

  Map<String, Object?> toPromptMap() => <String, Object?>{
        'id': id,
        'title': title,
        'aliases': aliases,
        'what': what,
        'when_to_use': whenToUse,
        'what_to_provide': whatToProvide,
        'steps': steps,
        'output': output,
        'why': why,
        'problem_solved': problemSolved,
        'l0_core_concept_ids': coreConceptIds,
        'knowledge_source': knowledgeSource,
        'thinker_names': thinkerNames,
        'start_prompt': startPrompt,
        'destination': destination,
      };
}

class XiangjiUserPreferenceProfile {
  const XiangjiUserPreferenceProfile({
    this.interestTags = const <String>['清晰步骤', '看见进展'],
    this.valueTags = const <String>['成长'],
    this.strengthTags = const <String>[],
    this.energyLevel = 'medium',
    this.supportStyle = 'direct',
    this.preferredMinutes = 10,
    this.updatedAtMs = 0,
  });

  final List<String> interestTags;
  final List<String> valueTags;
  final List<String> strengthTags;
  final String energyLevel;
  final String supportStyle;
  final int preferredMinutes;
  final int updatedAtMs;

  String get energyLabel => switch (energyLevel) {
        'low' => '现在能量较低',
        'high' => '现在可以接受挑战',
        _ => '现在能量一般',
      };

  String get supportStyleLabel => switch (supportStyle) {
        'gentle' => '温和陪伴',
        'challenge' => '友好挑战',
        _ => '简洁直接',
      };

  Map<String, Object?> toDatabaseMap() => <String, Object?>{
        'id': 'default',
        'interest_tags_json': jsonEncode(interestTags),
        'value_tags_json': jsonEncode(valueTags),
        'strength_tags_json': jsonEncode(strengthTags),
        'energy_level': energyLevel,
        'support_style': supportStyle,
        'preferred_minutes': preferredMinutes,
        'updated_at_ms': updatedAtMs > 0
            ? updatedAtMs
            : DateTime.now().millisecondsSinceEpoch,
      };

  Map<String, Object?> toPromptMap() => <String, Object?>{
        'interests': interestTags,
        'values': valueTags,
        'strengths': strengthTags,
        'current_energy': energyLevel,
        'support_style': supportStyle,
        'preferred_minutes': preferredMinutes,
        'constraint': '只调整表达、行动负担和呈现方式，不替代现实证据。',
      };

  factory XiangjiUserPreferenceProfile.fromMap(Map<String, Object?> row) =>
      XiangjiUserPreferenceProfile(
        interestTags: _jsonStrings(row['interest_tags_json'],
            fallback: const <String>['清晰步骤', '看见进展']),
        valueTags: _jsonStrings(row['value_tags_json'],
            fallback: const <String>['成长']),
        strengthTags: _jsonStrings(row['strength_tags_json']),
        energyLevel: (row['energy_level'] ?? 'medium').toString(),
        supportStyle: (row['support_style'] ?? 'direct').toString(),
        preferredMinutes: _supportedPreferredMinutes(
          row['preferred_minutes'],
        ),
        updatedAtMs: _positiveInt(row['updated_at_ms'], 0),
      );
}

class XiangjiActionChoice {
  const XiangjiActionChoice({
    required this.id,
    required this.label,
    required this.action,
    required this.minutes,
    required this.stopCondition,
    required this.fitReason,
    required this.mechanism,
    required this.prediction,
    required this.coreConceptIds,
    required this.visibleOutput,
    required this.completionSignal,
    required this.recoveryAction,
    required this.principlePractice,
    required this.transferQuestion,
    required this.motivationCue,
    required this.knowledgeSource,
    this.activeMethodLabels = const <String>[],
    this.thinkerNames = const <String>['叔本华'],
    this.preferred = false,
  });

  final String id;
  final String label;
  final String action;
  final int minutes;
  final String stopCondition;
  final String fitReason;
  final String mechanism;
  final String prediction;
  final List<String> coreConceptIds;
  final String visibleOutput;
  final String completionSignal;
  final String recoveryAction;
  final String principlePractice;
  final String transferQuestion;
  final String motivationCue;
  final String knowledgeSource;
  final List<String> activeMethodLabels;
  final List<String> thinkerNames;
  final bool preferred;
}

class XiangjiPersonalizedActionChoiceEngine {
  const XiangjiPersonalizedActionChoiceEngine();

  List<XiangjiActionChoice> build({
    required String baseAction,
    required String mechanism,
    required String prediction,
    required int expectedMinutes,
    required XiangjiUserPreferenceProfile profile,
    String goal = '',
    String keyGap = '',
    String valueLink = '',
    String groundingReason = '',
    List<String> activeCoreConceptIds = const <String>[],
    List<String> activeMethodLabels = const <String>[],
    List<String> activeKnowledgeSources = const <String>[],
  }) {
    final action = baseAction.trim();
    if (action.isEmpty) return const <XiangjiActionChoice>[];
    final effectiveMechanism = mechanism.trim().isEmpty
        ? '把当前计划变成一次可观察的现实尝试，再用结果决定是否继续。'
        : mechanism.trim();
    final effectivePrediction = prediction.trim().isEmpty
        ? '完成后应至少获得一条能支持、反驳或缩小当前判断的现实信息。'
        : prediction.trim();
    final solverMinutes = expectedMinutes <= 0
        ? profile.preferredMinutes
        : expectedMinutes.clamp(3, 25).toInt();
    final steadyMinutes = solverMinutes < profile.preferredMinutes
        ? solverMinutes
        : profile.preferredMinutes;
    final challengeMinutes = profile.preferredMinutes;
    final prefersChallenge = profile.energyLevel == 'high' &&
        (profile.interestTags.contains('探索挑战') ||
            profile.supportStyle == 'challenge');
    final prefersTiny = profile.energyLevel == 'low' ||
        profile.preferredMinutes <= 5 ||
        profile.interestTags.contains('轻松开始');
    final value = profile.valueTags.isEmpty
        ? (valueLink.trim().isEmpty ? '真正想要的结果' : valueLink.trim())
        : profile.valueTags.first;
    const lifeDomains = <String>['创作', '学习', '事业', '关系', '身心', '探索'];
    final interest = profile.interestTags.firstWhere(
      lifeDomains.contains,
      orElse: () => profile.interestTags.isEmpty
          ? '清晰步骤'
          : profile.interestTags.first,
    );
    final strength = profile.strengthTags.isEmpty
        ? '已经愿意面对这道题'
        : profile.strengthTags.first;
    final effectiveGoal = goal.trim().isEmpty ? '让现实向目标前进' : goal.trim();
    final effectiveGap = keyGap.trim().isEmpty ? '当前最关键的未知' : keyGap.trim();
    final methods = _uniqueStrings(activeMethodLabels).take(3).toList();
    final sources = _uniqueStrings(activeKnowledgeSources).take(3).toList();
    final sourceText = sources.isNotEmpty
        ? '叔本华 L0 认识论内核；本轮方法来源：${sources.join('；')}'
        : groundingReason.trim().isNotEmpty
            ? '叔本华 L0 与本轮现实根据：${groundingReason.trim()}'
            : '叔本华 L0：抽象判断必须回到经验世界验证。';
    final practicedMethod = methods.isEmpty
        ? '把抽象判断送回经验世界检验'
        : methods.join('、');
    final sharedCore = _uniqueStrings(activeCoreConceptIds);
    List<String> concepts(List<String> fallback) =>
        _uniqueStrings(<String>[...sharedCore, ...fallback]);
    final interestCue = _interestCue(interest);
    final recovery = _recoveryFor(
      energyLevel: profile.energyLevel,
      strength: strength,
      baseAction: action,
    );
    return <XiangjiActionChoice>[
      XiangjiActionChoice(
        id: 'tiny_start',
        label: '轻松起步',
        action: '先只做 3 分钟启动：准备这一步需要的东西并开始第一小段；3 分钟后可以停，也可以继续“$action”。',
        minutes: 3,
        stopCondition: '完成第一个启动动作或达到 3 分钟就可以停止；是否继续由用户当下决定。',
        fitReason: '用你的“$strength”把启动负担降到最低；$interestCue',
        mechanism: '降低启动所需能量，不要求一次完成整件事；开始后的真实体验会决定下一步。',
        prediction: '如果主要障碍是启动负担，开始 3 分钟后阻力应出现可观察变化。',
        coreConceptIds: concepts(
          const <String>['SC-K0-004', 'SC-K0-014', 'SC-K0-022'],
        ),
        visibleOutput: '一条“我已开始”的可观察记录，以及启动前后阻力有无变化。',
        completionSignal: '第一个启动动作完成，并记下“继续 / 停止 / 仍受阻”之一。',
        recoveryAction: recovery,
        principlePractice: '你正在练习“$practicedMethod”：先看实际启动体验，不用“我没有毅力”提前定性。',
        transferQuestion: '下次再遇到类似阻力时，哪个 3 分钟启动动作最容易复用？',
        motivationCue: '这一步不是证明意志力，而是为你重视的“$value”取得第一条现实进展。',
        knowledgeSource: sourceText,
        activeMethodLabels: methods,
        preferred: prefersTiny,
      ),
      XiangjiActionChoice(
        id: 'steady_step',
        label: '稳步推进',
        action: action,
        minutes: steadyMinutes,
        stopCondition: '完成这一轮可观察动作，或达到 $steadyMinutes 分钟仍无关键信号时停止并回来反馈。',
        fitReason: '直接缩小“$effectiveGap”，并借力你的“$strength”做出一份看得见的成果。',
        mechanism: effectiveMechanism,
        prediction: effectivePrediction,
        coreConceptIds: concepts(
          const <String>['SC-K0-005', 'SC-K0-020', 'SC-K0-024'],
        ),
        visibleOutput: '一份可保存、发送、展示或比较的小成果，外加本轮耗时和实际结果。',
        completionSignal: '成果已经离开“想法”状态，成为可被自己或外部世界检查的对象。',
        recoveryAction: recovery,
        principlePractice: '你正在练习“$practicedMethod”：不停在概念里，用可观察产出检查手段是否真的推进目标。',
        transferQuestion: '这次哪个手段真正推动了“$effectiveGoal”，哪一部分只是看起来很忙？',
        motivationCue: '今天的意义是为“$value”产出一份真实成果，不是完成一个抽象打卡。',
        knowledgeSource: sourceText,
        activeMethodLabels: methods,
        preferred: !prefersTiny && !prefersChallenge,
      ),
      XiangjiActionChoice(
        id: 'reality_challenge',
        label: '现实挑战',
        action: '把这一步做成一次现实挑战：$action；结束前必须拿到并记录一条外部可观察结果。',
        minutes: challengeMinutes,
        stopCondition: '拿到一条外部可观察结果即停止；若触及安全、资源或时间上限，立即停止而不要求硬撑。',
        fitReason: '把“$interest”变成一次现实侦察，用你的“$strength”去区分竞争原因，不是硬撑。',
        mechanism: '把抽象计划变成外部世界中的一次可验证尝试，并保留停止条件。',
        prediction: effectivePrediction,
        coreConceptIds: concepts(
          const <String>['SC-K0-001', 'SC-K0-016', 'SC-K0-024'],
        ),
        visibleOutput: '一条能支持、反驳或区分当前候选原因的外部证据。',
        completionSignal: '已获得一条可复核的外部回应，或在约定时间内明确记录“无信号”。',
        recoveryAction: recovery,
        principlePractice: '你正在练习“$practicedMethod”：让不同原因对现实结果作出不同预测。',
        transferQuestion: '本轮证据排除了哪个原因？还有哪个关键未知需要下一次区分？',
        motivationCue: '把这当成一次为“$value”寻找线索的现实任务；任何结果都是情报，不是对你的评价。',
        knowledgeSource: sourceText,
        activeMethodLabels: methods,
        preferred: prefersChallenge,
      ),
    ];
  }

  String _interestCue(String interest) => switch (interest) {
        '创作' => '把第一步做成一份小作品，而不是抽象任务。',
        '学习' => '把第一步当作一次短练习，结束后说出一个新发现。',
        '关系' => '优先形成一次真实而低压的互动。',
        '身心' => '优先观察身体与能量的真实变化。',
        '探索' || '探索挑战' => '把第一步当作寻找线索的小挑战。',
        _ => '只要形成一条可观察进展，就算完成。',
      };

  String _recoveryFor({
    required String energyLevel,
    required String strength,
    required String baseAction,
  }) {
    if (energyLevel == 'low') {
      return '如果还是动不了，只准备“$baseAction”所需的一样东西，记下当时能量后停止；这是现实样本，不是失败。';
    }
    return '如果卡住，使用你的“$strength”只缩小一次：保留动词，把对象或数量减半，然后再做 3 分钟。';
  }
}

class XiangjiUsageAssistantContext {
  const XiangjiUsageAssistantContext({
    this.problemId = '',
    this.problem = '',
    this.goal = '',
    this.keyGap = '',
    this.judgment = '',
    this.currentActionId = '',
    this.currentAction = '',
    this.actionState = '',
    this.actionStateLabel = '',
    this.prediction = '',
    this.stopCondition = '',
    this.recoveryAction = '',
    this.principlePractice = '',
    this.transferQuestion = '',
    this.knowledgeSource = '',
    this.coreConceptIds = const <String>[],
    this.activeMethodLabels = const <String>[],
    this.completedRealityRounds = 0,
  });

  final String problemId;
  final String problem;
  final String goal;
  final String keyGap;
  final String judgment;
  final String currentActionId;
  final String currentAction;
  final String actionState;
  final String actionStateLabel;
  final String prediction;
  final String stopCondition;
  final String recoveryAction;
  final String principlePractice;
  final String transferQuestion;
  final String knowledgeSource;
  final List<String> coreConceptIds;
  final List<String> activeMethodLabels;
  final int completedRealityRounds;

  bool get hasProblem => problemId.isNotEmpty || problem.isNotEmpty;
  bool get hasCurrentAction =>
      currentActionId.isNotEmpty || currentAction.isNotEmpty;

  Map<String, Object?> toPromptMap() => <String, Object?>{
        'problem': problem,
        'goal': goal,
        'key_gap': keyGap,
        'current_judgment': judgment,
        'current_action': currentAction,
        'action_state': actionStateLabel,
        'prediction': prediction,
        'stop_condition': stopCondition,
        'recovery_action': recoveryAction,
        'principle_practice': principlePractice,
        'transfer_question': transferQuestion,
        'knowledge_source': knowledgeSource,
        'l0_core_concept_ids': coreConceptIds,
        'active_methods': activeMethodLabels,
        'completed_reality_rounds': completedRealityRounds,
      };
}

class XiangjiGuidedCase {
  const XiangjiGuidedCase({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.need,
    required this.realityFacts,
    required this.userInterpretations,
    required this.competingCauses,
    required this.goal,
    required this.keyGap,
    required this.routeChoices,
    required this.selectedAction,
    required this.prediction,
    required this.realityResult,
    required this.revision,
    required this.nextStep,
    required this.coreConceptIds,
    required this.sourceLabel,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String need;
  final List<String> realityFacts;
  final List<String> userInterpretations;
  final List<String> competingCauses;
  final String goal;
  final String keyGap;
  final List<String> routeChoices;
  final String selectedAction;
  final String prediction;
  final String realityResult;
  final String revision;
  final String nextStep;
  final List<String> coreConceptIds;
  final String sourceLabel;
  final int sortOrder;

  Map<String, Object?> toDatabaseMap() => <String, Object?>{
        'id': id,
        'title': title,
        'summary': summary,
        'category': category,
        'sort_order': sortOrder,
        'source_label': sourceLabel,
        'case_json': jsonEncode(<String, Object?>{
          'need': need,
          'reality_facts': realityFacts,
          'user_interpretations': userInterpretations,
          'competing_causes': competingCauses,
          'goal': goal,
          'key_gap': keyGap,
          'route_choices': routeChoices,
          'selected_action': selectedAction,
          'prediction': prediction,
          'reality_result': realityResult,
          'revision': revision,
          'next_step': nextStep,
          'core_concept_ids': coreConceptIds,
        }),
        'created_at_ms': 1,
      };

  factory XiangjiGuidedCase.fromMap(Map<String, Object?> row) {
    final raw = row['case_json'];
    final decoded = raw is String && raw.isNotEmpty
        ? jsonDecode(raw)
        : const <String, Object?>{};
    final data = decoded is Map
        ? decoded.map((key, dynamic value) =>
            MapEntry(key.toString(), value as Object?))
        : const <String, Object?>{};
    return XiangjiGuidedCase(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      summary: (row['summary'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      need: (data['need'] ?? '').toString(),
      realityFacts: _objectStrings(data['reality_facts']),
      userInterpretations: _objectStrings(data['user_interpretations']),
      competingCauses: _objectStrings(data['competing_causes']),
      goal: (data['goal'] ?? '').toString(),
      keyGap: (data['key_gap'] ?? '').toString(),
      routeChoices: _objectStrings(data['route_choices']),
      selectedAction: (data['selected_action'] ?? '').toString(),
      prediction: (data['prediction'] ?? '').toString(),
      realityResult: (data['reality_result'] ?? '').toString(),
      revision: (data['revision'] ?? '').toString(),
      nextStep: (data['next_step'] ?? '').toString(),
      coreConceptIds: _objectStrings(data['core_concept_ids']),
      sourceLabel: (row['source_label'] ?? '').toString(),
      sortOrder: _positiveInt(row['sort_order'], 0),
    );
  }
}

class XiangjiUsageAssistantAnswer {
  const XiangjiUsageAssistantAnswer({
    required this.title,
    required this.answer,
    required this.steps,
    required this.guideId,
    required this.coreConceptIds,
    required this.knowledgeSource,
    this.thinkerNames = const <String>['叔本华'],
    this.startPrompt = '',
    this.destination = '',
    this.aiEnhanced = false,
  });

  final String title;
  final String answer;
  final List<String> steps;
  final String guideId;
  final List<String> coreConceptIds;
  final String knowledgeSource;
  final List<String> thinkerNames;
  final String startPrompt;
  final String destination;
  final bool aiEnhanced;

  XiangjiUsageAssistantAnswer copyWith({
    String? title,
    String? answer,
    List<String>? steps,
    bool? aiEnhanced,
  }) =>
      XiangjiUsageAssistantAnswer(
        title: title ?? this.title,
        answer: answer ?? this.answer,
        steps: steps ?? this.steps,
        guideId: guideId,
        coreConceptIds: coreConceptIds,
        knowledgeSource: knowledgeSource,
        thinkerNames: thinkerNames,
        startPrompt: startPrompt,
        destination: destination,
        aiEnhanced: aiEnhanced ?? this.aiEnhanced,
      );
}

class XiangjiPracticalProductContract {
  const XiangjiPracticalProductContract._();

  static const String version = 'V6.3-Knowledge-to-Outcome';
  static const String knowledgeSourceId = 'XF-PRODUCT-GUIDE-V6.3';
  static const String mission =
      '把一个真实问题或目标，转换成今天能做的一步，并用行动后的现实继续修正。';
  static const String ethicalBoundary =
      '通过自主选择、兴趣匹配、低门槛行动、可见产出和失败可恢复增强持续使用；禁止羞耻、威胁、创伤利用、敌人刺激、断签惩罚和制造依赖。';

  static const List<XiangjiPracticalFlowStep> coreLoop =
      <XiangjiPracticalFlowStep>[
    XiangjiPracticalFlowStep(
      id: 'say_need',
      title: '1. 说出需要',
      userAction: '用一句话说问题、目标、卡点或行动结果；不用先整理。',
      systemWork: '保留原话，区分实际发生、体验、解释、目标与未知。',
      output: '一条被正确理解、可由用户修改的真问题。',
      coreConceptIds: <String>['SC-K0-001', 'SC-K0-002', 'SC-K0-014'],
    ),
    XiangjiPracticalFlowStep(
      id: 'choose_route',
      title: '2. 选择办法',
      userAction: '从轻松起步、稳步推进、现实挑战中选一条。',
      systemWork: '比较根据、竞争原因、关键差距、成本与可逆性。',
      output: '一条适合当前能量、兴趣和现实约束的办法。',
      coreConceptIds: <String>['SC-K0-005', 'SC-K0-011', 'SC-K0-016'],
    ),
    XiangjiPracticalFlowStep(
      id: 'do_one_action',
      title: '3. 只做一步',
      userAction: '在时间边界内完成当前动作，做到停止条件就回来。',
      systemWork: '隐藏非必要分析，保留目的、机制和事前预测。',
      output: '现实中的行为或外部结果，而不是新的计划文字。',
      coreConceptIds: <String>['SC-K0-020', 'SC-K0-022'],
    ),
    XiangjiPracticalFlowStep(
      id: 'reality_review',
      title: '4. 让现实改判',
      userAction: '只报告实际做了什么、发生了什么、哪里意外。',
      systemWork: '对照预测，继续、缩小、换法、回溯或停止。',
      output: '一条可复用经验和下一步；失败不会被解释成意志薄弱。',
      coreConceptIds: <String>['SC-K0-021', 'SC-K0-023', 'SC-K0-024'],
    ),
  ];

  static const List<XiangjiFeatureGuide> featureGuides =
      <XiangjiFeatureGuide>[
    XiangjiFeatureGuide(
      id: 'bring_need',
      title: '说出一个问题或目标',
      aliases: <String>['开始', '怎么用', '问题', '目标', '需要', '想要', '不知道从哪开始'],
      what: '未来军师的唯一默认入口。你只需要说出想改变什么、发生了什么或卡在哪里。',
      whenToUse: '有目标、困境、犹豫、失败反馈，或只是知道自己不想维持现状时。',
      whatToProvide: '一句原话就够；时间、人物、数字或已发生行为有多少写多少。',
      steps: <String>['说一句真实处境', '核对军师理解的问题', '选择一条现实办法'],
      output: '真问题、当前关键差距和一个可执行动作。',
      why: '经验世界与抽象解释必须先分开，目标也要有现实判据。',
      problemSolved: '解决“不知道该打开哪个功能、也不知道该怎么填”的问题。',
      coreConceptIds: <String>['SC-K0-001', 'SC-K0-002', 'SC-K0-020'],
      knowledgeSource: '叔本华 L0：经验/抽象分层；V5 目标操作化；P0 用户负担规则。',
      startPrompt: '我现在想解决的是：',
      destination: 'conversation',
    ),
    XiangjiFeatureGuide(
      id: 'choose_action',
      title: '选择适合自己的现实办法',
      aliases: <String>['选择', '方案', '办法', '路线', '轻松', '挑战', '兴趣', '个性'],
      what: '同一个正确方向提供三种负担：轻松起步、稳步推进、现实挑战。',
      whenToUse: '军师已经形成下一步，但你觉得太累、太无聊或不适合自己时。',
      whatToProvide: '当前能量、喜欢的方式、可用时间和值得保护的结果。',
      steps: <String>['查看三种负担', '选择最愿意执行的一条', '必要时修改动作'],
      output: '一条由你确认、带时间边界和现实预测的行动。',
      why: '方法必须受现实条件和决定性差异约束，不能用同一模板要求所有人。',
      problemSolved: '解决“建议理论上正确，但我根本不想做或做不动”的问题。',
      coreConceptIds: <String>['SC-K0-011', 'SC-K0-020', 'SC-K0-022'],
      knowledgeSource: '叔本华判断力、抽象目标操作化、熟练行动与过度反省。',
      destination: 'conversation',
    ),
    XiangjiFeatureGuide(
      id: 'personalize_experience',
      title: '选择适合我的使用方式',
      aliases: <String>['偏好', '量表', '测评', '兴趣', '优势', '个性化', '能量', '语气'],
      what: '用不到 60 秒选择兴趣、价值、优势、当前能量、表达语气和可投入时间；它不是人格诊断。',
      whenToUse: '建议太重、太轻、太无聊，或你希望军师更直接、更温和、更有挑战时。',
      whatToProvide: '只选择愿意透露的项目；可以全部跳过，也可以随时修改。',
      steps: <String>['选择容易开始的方式', '选择当前能量和时间', '保存后重新生成三种行动负担'],
      output: '更符合当前状态的轻松起步、稳步推进和现实挑战；事实判断不会因偏好而改变。',
      why: '判断力必须尊重具体情形的决定性差异；个性信息只能调整呈现与负担，不能冒充现实根据。',
      problemSolved: '解决“方案像统一模板，不符合我的兴趣、能量和时间”的问题。',
      coreConceptIds: <String>['SC-K0-005', 'SC-K0-011', 'SC-K0-018'],
      knowledgeSource: '叔本华认识根据、判断力与“系统性不等于确定性”；V6.2 自主个性化边界。',
      destination: 'preferences',
    ),
    XiangjiFeatureGuide(
      id: 'action_mode',
      title: '当前唯一行动',
      aliases: <String>['行动', '执行', '开始做', '提醒', '计时', '今天做什么'],
      what: '行动时只显示当前一步、为什么做、做到什么程度停止，以及回来要记录什么。',
      whenToUse: '已经认可一个办法，准备进入现实行动时。',
      whatToProvide: '不需要继续填表；按需绑定 Todo 提醒。',
      steps: <String>['开始行动', '达到时间或停止条件', '记录实际结果'],
      output: '一项真实行动及其可观察结果。',
      why: '行动模式要隐藏不必要反思，避免抽象监控破坏执行。',
      problemSolved: '解决“计划很多、真正行动时大脑空白”的问题。',
      coreConceptIds: <String>['SC-K0-004', 'SC-K0-022', 'SC-K0-024'],
      knowledgeSource: '叔本华：概念与直观根本不同；熟练行动；现实修订。',
      destination: 'current_action',
    ),
    XiangjiFeatureGuide(
      id: 'reality_feedback',
      title: '行动后回报现实',
      aliases: <String>['反馈', '复盘', '没做', '失败', '受阻', '做到了', '结果', '回来'],
      what: '不是评价自己，而是把行动后的新现实交给军师重新计算。',
      whenToUse: '做到了、只做了一部分、完全没开始、受阻或结果相反时都要用。',
      whatToProvide: '实际做了什么、发生了什么、哪里和预想不同；1—3 条即可。',
      steps: <String>['选择结果状态', '写现实事实', '查看继续/缩小/换法/停止'],
      output: '预测—现实对照、经验、改判和下一步。',
      why: '行动完成不等于问题解决；新经验世界 I′ 对旧概念拥有修订权。',
      problemSolved: '解决“失败后只责怪自己，不知道下一步怎么改”的问题。',
      coreConceptIds: <String>['SC-K0-014', 'SC-K0-021', 'SC-K0-024'],
      knowledgeSource: '叔本华感觉阶梯、可证伪个人规则、现实修订。',
      startPrompt: '我回来反馈上一步：实际发生的是……',
      destination: 'conversation',
    ),
    XiangjiFeatureGuide(
      id: 'full_problem',
      title: '完整解题台',
      aliases: <String>['完整分析', '为什么', '原因', '假设', '差距', '解题台', '问题工作页'],
      what: '按需查看事实、解释、竞争原因、根据、目标、差距、办法、预测与回溯。',
      whenToUse: '重大决定、反复失败，或你想核对军师为什么这样判断时。',
      whatToProvide: '通常不用额外输入；只在关键未知真的改变路线时回答一个问题。',
      steps: <String>['核对事实与解释', '查看竞争原因和根据', '核对办法与停止条件'],
      output: '一份可审计、可修改、不会覆盖原话的完整问题模型。',
      why: '重要判断必须能回到认识根据；证明长度不能补救弱前提。',
      problemSolved: '解决“AI 给了答案，但不知道凭什么、是否可靠”的问题。',
      coreConceptIds: <String>['SC-K0-005', 'SC-K0-006', 'SC-K0-019'],
      knowledgeSource: '叔本华认识根据、泉水—水渠与弱前提审查。',
      destination: 'problem_workspace',
    ),
    XiangjiFeatureGuide(
      id: 'grounding_and_debt',
      title: '检查一个判断凭什么成立',
      aliases: <String>['凭什么', '证据', '根据', '接地', '认识债务', '概念循环', '未知', '可靠'],
      what: '沿着判断的根据链一直追到现实材料，发现概念相互证明、关键未知或最弱前提。',
      whenToUse: '一句结论会改变重要决定，但证据说不清，或分析越做越长仍不放心时。',
      whatToProvide: '已有记录、数字、具体经历或可靠来源；没有也可以直接说“不知道”。',
      steps: <String>['展开根据链', '标出概念循环与最弱前提', '把最高影响未知变成低风险侦察'],
      output: '根据强度、认识债务和一条补证行动；不会用更多概念假装确定。',
      why: '间接判断像水渠，最终必须回到经验泉水；无现实出口的循环不能增加认识。',
      problemSolved: '解决“AI 说得很完整，但关键结论其实没有现实依据”的问题。',
      coreConceptIds: <String>[
        'SC-K0-005',
        'SC-K0-006',
        'SC-K0-007',
        'SC-K0-008',
        'SC-K0-009',
        'SC-K0-019',
      ],
      knowledgeSource: '叔本华 Erkenntnisgrund、泉水—水渠；V5 概念循环、认识债务与根据率。',
      startPrompt: '我想核对这个判断凭什么成立：',
      destination: 'conversation',
    ),
    XiangjiFeatureGuide(
      id: 'intuition_and_cause',
      title: '把说不清的感觉变成可验证线索',
      aliases: <String>['感觉不对', '说不清', '直觉', '害怕', '原因', '为什么会这样', '因果'],
      what: '先保留尚未概念化的直觉，再分开身体、体验、冲动、外部解释和未来预测，并比较多个可能原因。',
      whenToUse: '你真实感到不安或抗拒，但还说不清发生了什么，或很快认定只有一个原因时。',
      whatToProvide: '具体场景、身体变化、对方实际言行和时间顺序；不必先给它命名。',
      steps: <String>['按原样保存感觉', '把外部解释降为候选', '用一个安全观察区分原因'],
      output: '被尊重的真实体验、2—5 个候选原因和一个安全的区分观察。',
      why: '直观不能被概念穷尽；体验是真的，但关于外部原因的解释仍需知性与现实检验。',
      problemSolved: '解决“不是被粗暴否定感觉，就是立刻被贴上焦虑/创伤等标签”的问题。',
      coreConceptIds: <String>['SC-K0-004', 'SC-K0-013', 'SC-K0-014', 'SC-K0-015', 'SC-K0-016'],
      knowledgeSource: '叔本华直观/概念之别、未概念化直觉、感觉阶梯与知性因果；V5 区分实验。',
      startPrompt: '我说不清，但这个具体场景让我觉得不对：',
      destination: 'conversation',
    ),
    XiangjiFeatureGuide(
      id: 'major_campaign',
      title: '重大目标与多路线比较',
      aliases: <String>['重大决定', '长期目标', '项目', '战役', '辞职', '转行', '创业'],
      what: '只为跨周期、资源较大或不易撤回的问题比较路线、代价、后手和退出条件。',
      whenToUse: '选择会持续影响时间、金钱、关系或职业方向时。',
      whatToProvide: '真正想保护的结果、现实期限、可承受上限；缺少时军师只问一个关键项。',
      steps: <String>['审查是否值得投入', '比较 2—3 条不同机制路线', '选择后手与退出条件'],
      output: '一条首选路线、替代路线、停止条件和下一次复核时间。',
      why: '系统性不等于确定性；高影响判断要增加根据与可逆性。',
      problemSolved: '解决“在重要选择上凭冲动重押，或一直分析却不决断”的问题。',
      coreConceptIds: <String>['SC-K0-009', 'SC-K0-018', 'SC-K0-019'],
      knowledgeSource: '叔本华认识根据强度、系统性/确定性和证明边界。',
      startPrompt: '这是一个重要决定，我想实现的是：',
      destination: 'conversation',
    ),
    XiangjiFeatureGuide(
      id: 'examples',
      title: '完整案例与操作示范',
      aliases: <String>['案例', '示例', '演示', '参考', '怎么填', '操作说明'],
      what: '查看一个问题如何从原话走到行动、现实结果、改判和下一步。',
      whenToUse: '第一次使用，或仍不明白某个字段和流程时。',
      whatToProvide: '无需输入；也可以把示例句子改成自己的处境再开始。',
      steps: <String>['看原始需要', '看三种办法和选择理由', '看现实如何改变下一步'],
      output: '一套可模仿但不会污染个人数据的完整参考。',
      why: '判断力通过案例中的相同点、差异和反例成长，不能只学定义。',
      problemSolved: '解决“知道功能叫什么，但还是不知道实际怎样用”的问题。',
      coreConceptIds: <String>['SC-K0-010', 'SC-K0-011', 'SC-K0-012'],
      knowledgeSource: '叔本华镶嵌画、判断力与概念边界。',
      destination: 'examples',
    ),
    XiangjiFeatureGuide(
      id: 'epistemic_world',
      title: '我的认识变化',
      aliases: <String>['认识世界', '经验世界', '概念世界', '我学到了什么', '改变'],
      what: '查看哪些是实际发生、哪些是你的解释、哪些判断被现实支持或推翻。',
      whenToUse: '想理解自己为什么改判，或检查是否把感觉直接当成外部原因时。',
      whatToProvide: '无需额外填写；内容来自真实问题与行动反馈。',
      steps: <String>['看经验世界 I', '看概念世界 C', '看现实验算与版本变化'],
      output: '一份个人认识如何被现实逐步修订的记录。',
      why: '概念是表象的表象，不能覆盖经验；新现实拥有修订权。',
      problemSolved: '解决“我形成了结论，却不知道它来自事实还是解释”的问题。',
      coreConceptIds: <String>['SC-K0-001', 'SC-K0-002', 'SC-K0-003', 'SC-K0-024'],
      knowledgeSource: '叔本华世界作为表象、抽象反思与现实修订。',
      destination: 'epistemic_world',
    ),
    XiangjiFeatureGuide(
      id: 'personal_science',
      title: '复盘与个人经验科学',
      aliases: <String>['经验', '规律', '历史', '战史', '成长', '练习次数'],
      what: '把多次行动的条件、预测、结果、反例和修订组织成可复核的个人规律。',
      whenToUse: '同类问题已经出现多次，想知道什么方法在什么条件下真的有效时。',
      whatToProvide: '持续回填现实即可；系统不会用阅读量或打卡天数冒充成长。',
      steps: <String>['保留每轮预测与结果', '积累反例和适用条件', '形成可证伪个人规则'],
      output: '有样本次数、条件、反例、置信度和版本的个人经验。',
      why: '经验只有形成系统联系并接受反例，才成为个人经验科学。',
      problemSolved: '解决“经历很多次，但每次失败后仍从头开始”的问题。',
      coreConceptIds: <String>['SC-K0-021', 'SC-K0-023', 'SC-K0-024'],
      knowledgeSource: '叔本华 Wissenschaft、归纳边界与现实修订。',
      destination: 'history',
    ),
    XiangjiFeatureGuide(
      id: 'knowledge_basis',
      title: '查看思想与知识依据',
      aliases: <String>['叔本华', '知识库', '思想家', '概念', '来源', '依据', '理论'],
      what: '查看某项功能受哪个原概念、产品规则和来源约束，以及它如何改变当前解法。',
      whenToUse: '想深入学习、核对来源，或质疑某项功能是否脱离知识库时。',
      whatToProvide: '无需填写；从当前问题的“为什么”进入最容易理解。',
      steps: <String>['先看本轮实际生效原则', '再看概念的通俗含义', '最后展开来源定位'],
      output: '思想 → 认知操作 → 产品功能 → 本案例行动的完整映射。',
      why: '知识必须表现为状态与决策变化，不能只做品牌说明。',
      problemSolved: '解决“页面有很多思想，却不知道它实际做了什么”的问题。',
      coreConceptIds: <String>['SC-K0-003', 'SC-K0-005', 'SC-K0-023'],
      knowledgeSource: '叔本华 L0 核心、MEC-001..014 与 P0 方法效果门禁。',
      destination: 'knowledge',
    ),
    XiangjiFeatureGuide(
      id: 'settings_ai_data',
      title: 'AI、主动提醒与数据设置',
      aliases: <String>['设置', 'AI', '模型', '隐私', '敏感', '数据', '导出', '删除', '监督', '通知'],
      what: '管理 AI 服务、敏感信息授权、主动监督、导出和删除；本地求解与内置说明在 AI 不可用时仍可继续。',
      whenToUse: '需要切换 AI、决定是否发送敏感材料、调整主动提醒，或导出/删除模块数据时。',
      whatToProvide: '只在你主动选择时配置；敏感信息默认不外发，删除前会明确确认范围。',
      steps: <String>['查看当前 AI 与隐私状态', '只开启需要的能力', '按需导出、关闭监督或删除数据'],
      output: '可审计的服务状态、用户授权和数据控制结果。',
      why: '复杂系统不能冒充确定性，AI 判断必须接受相同根据与现实规则；用户拥有最终控制权。',
      problemSolved: '解决“不知道 AI 是否在工作、数据去了哪里、怎样关闭或带走”的问题。',
      coreConceptIds: <String>['SC-K0-002', 'SC-K0-018', 'SC-K0-019', 'SC-K0-024'],
      knowledgeSource: '叔本华抽象反思、系统性/确定性与弱前提边界；P0 用户主权、隐私和可审计性。',
      destination: 'settings',
    ),
    XiangjiFeatureGuide(
      id: 'usage_assistant',
      title: '使用助手',
      aliases: <String>['助手', '不会用', '怎么填', '找不到', '带我操作', '帮助'],
      what: '用自然语言回答功能是什么、何时用、填什么、为什么，并把你带到正确入口。',
      whenToUse: '任何不确定下一步、找不到功能或看不懂字段的时候。',
      whatToProvide: '直接问问题；也可以只说“我不知道该怎么开始”。',
      steps: <String>['提出使用问题', '查看最短步骤', '点击按这个开始'],
      output: '一段通俗回答、操作步骤、知识依据和正确入口。',
      why: '语言用于澄清隐藏概念链；说明必须回到用户实际要完成的结果。',
      problemSolved: '解决“功能很多、名称陌生、无从下手”的问题。',
      coreConceptIds: <String>['SC-K0-004', 'SC-K0-017', 'SC-K0-020'],
      knowledgeSource: '叔本华概念/直观之别、理性与语言、目标操作化。',
      destination: 'assistant',
    ),
  ];

  static const List<XiangjiGuidedCase> guidedCases = <XiangjiGuidedCase>[
    XiangjiGuidedCase(
      id: 'case_leave_for_trial_shift',
      title: '答应第二天试岗，却在出门前放弃',
      summary: '示范如何把“我没毅力”改造成可验证的启动问题。',
      category: '行动启动',
      need: '我已经答应明天去试岗，但担心闹钟响后又反复犹豫，最后不去。',
      realityFacts: <String>['已经完成面试并约定时间', '过去出现过醒来后犹豫、没有出门'],
      userInterpretations: <String>['我可能就是没有毅力', '设目标对我没有用'],
      competingCauses: <String>[
        '睡眠和身体能量不足',
        '临近行动时的威胁感把犹豫放大',
        '计划只写了“去上班”，没有固定起床后的第一个动作',
      ],
      goal: '在约定时间前真正到达试岗地点；是否长期留下由到场后的现实再决定。',
      keyGap: '尚未区分“根本不想要这份工作”和“出门前启动阻力”哪个在主导。',
      routeChoices: <String>[
        '轻松起步：前一晚把衣物和材料放门口，闹钟响后只做穿鞋站到门外。',
        '稳步推进：把起床到抵达拆成三个无需重新决定的动作并设出门截止点。',
        '现实挑战：按路线到达最近交通站点，再决定继续或按退出条件返回。',
      ],
      selectedAction: '前一晚准备好所需物品；闹钟响后不判断整份工作，只完成穿鞋、拿包、站到门外三个动作。',
      prediction: '如果主要阻力来自启动与反复决策，提前准备并取消晨间再决定后，离开房间的时间会明显缩短。',
      realityResult: '示例结果：按时站到门外，仍然紧张，但已经能够继续走到交通站点。',
      revision: '“紧张”和“无法行动”不是同一件事；本轮更支持启动结构是可改变因素，不足以证明工作一定适合。',
      nextStep: '下一次继续记录到场后的真实体验、工作条件和是否满足个人判据，再决定是否留下。',
      coreConceptIds: <String>['SC-K0-001', 'SC-K0-002', 'SC-K0-014', 'SC-K0-016', 'SC-K0-022', 'SC-K0-024'],
      sourceLabel: '叔本华感觉阶梯、竞争原因、熟练行动与现实修订；V5 持续问题求解。',
      sortOrder: 1,
    ),
    XiangjiGuidedCase(
      id: 'case_find_work',
      title: '想找到工作，却每天不知道先做什么',
      summary: '示范如何把长期抽象目标压缩为可观察的求职反馈。',
      category: '目标推进',
      need: '我想找到一份能够接受的工作，但每天看很多信息，最后没有实际产出。',
      realityFacts: <String>['浏览过多个职位', '当天没有发出定向申请', '尚无可比较的回复数据'],
      userInterpretations: <String>['可能所有方向都不适合我'],
      competingCauses: <String>['筛选条件不清', '材料与职位不匹配', '信息浏览替代了真实投递'],
      goal: '一周内形成可比较的真实反馈，并知道下一步优先调整方向、材料还是渠道。',
      keyGap: '当前缺少一个真实职位上的投递—回复样本，无法区分三个候选原因。',
      routeChoices: <String>[
        '轻松起步：收藏一个满足三项硬条件的职位并写出匹配点。',
        '稳步推进：完成并发出一份定向申请。',
        '现实挑战：联系一个真实招聘方，获得明确回复或拒绝。',
      ],
      selectedAction: '用 15 分钟选一个真实职位，对照三项硬条件修改并发出一份材料，保存职位和发送记录。',
      prediction: '如果主要瓶颈是材料或方向，这次真实投递会产生比继续浏览更明确的回应或待改差异。',
      realityResult: '示例结果：材料已发出，24 小时没有回复；记录显示职位要求中的一项技能没有在简历中体现。',
      revision: '“没有回复”不能证明所有工作都不适合；当前先测试材料呈现与渠道，而不是形成终身结论。',
      nextStep: '只修改缺失技能的可验证经历表达，再向两个相似职位投递并比较回复。',
      coreConceptIds: <String>['SC-K0-005', 'SC-K0-011', 'SC-K0-020', 'SC-K0-021', 'SC-K0-024'],
      sourceLabel: '叔本华认识根据、判断力、目标操作化、归纳边界与现实修订。',
      sortOrder: 2,
    ),
    XiangjiGuidedCase(
      id: 'case_go_for_walk',
      title: '想出去走走，但现在完全不想动',
      summary: '示范低能量时怎样不靠自责获得一个最小现实变化。',
      category: '低能量行动',
      need: '我知道出去走走可能有帮助，但现在只想躺着，一点也不想动。',
      realityFacts: <String>['当前躺着', '主观上不想动', '还没有尝试改变任何一个条件'],
      userInterpretations: <String>['我可能没有动力', '今天又会失败'],
      competingCauses: <String>['身体能量低', '任务“出去运动”过大', '当前环境没有启动提示'],
      goal: '不要求完成运动，只获得一个能判断下一步的身体和行动样本。',
      keyGap: '尚不知道阻力是否会在完成第一个极小动作后变化。',
      routeChoices: <String>[
        '轻松起步：只把一只脚放到地上并坐起 30 秒。',
        '稳步推进：穿鞋走到门外，允许立刻回来。',
        '现实挑战：走到楼下或最近路口，记录身体变化。',
      ],
      selectedAction: '先坐起来、穿鞋并站到门外；门外停留 1 分钟后可以自由决定继续或回来。',
      prediction: '如果任务过大是主要障碍，把目标缩到门外 1 分钟后，行动阻力或身体状态应出现可观察变化。',
      realityResult: '示例结果：站到门外后仍不想运动，但愿意走到楼下，回来时比开始前清醒一些。',
      revision: '本轮支持“缩小动作能改变启动状态”，但不把一次结果升级为每天都有效的永久规律。',
      nextStep: '下次在不同能量条件下重复一次，记录何时有效、何时需要休息或其他支持。',
      coreConceptIds: <String>['SC-K0-004', 'SC-K0-014', 'SC-K0-021', 'SC-K0-022', 'SC-K0-024'],
      sourceLabel: '叔本华直观/概念之别、感觉阶梯、归纳边界、行动与现实修订。',
      sortOrder: 3,
    ),
  ];

  static XiangjiFeatureGuide guideForId(String id) => featureGuides.firstWhere(
        (guide) => guide.id == id,
        orElse: () => featureGuides.first,
      );

  static XiangjiUsageAssistantAnswer answerLocally(
    String question, {
    XiangjiUsageAssistantContext? context,
  }) {
    final query = question.trim().toLowerCase();
    if (query.isEmpty) return _answerFor(featureGuides.first);
    final contextual = _contextualAnswer(query, context);
    if (contextual != null) return contextual;
    XiangjiFeatureGuide best = featureGuides.first;
    var bestScore = -1;
    for (final guide in featureGuides) {
      var score = 0;
      for (final alias in guide.aliases) {
        if (query.contains(alias.toLowerCase())) score += alias.length + 2;
      }
      if (query.contains(guide.title.toLowerCase())) score += 20;
      if (score > bestScore) {
        best = guide;
        bestScore = score;
      }
    }
    return _answerFor(best);
  }

  static XiangjiUsageAssistantAnswer _answerFor(XiangjiFeatureGuide guide) =>
      XiangjiUsageAssistantAnswer(
        title: guide.title,
        answer: '${guide.what}\n\n你什么时候用：${guide.whenToUse}\n你只要提供：${guide.whatToProvide}\n最终得到：${guide.output}',
        steps: guide.steps,
        guideId: guide.id,
        coreConceptIds: guide.coreConceptIds,
        knowledgeSource: guide.knowledgeSource,
        thinkerNames: guide.thinkerNames,
        startPrompt: guide.startPrompt,
        destination: guide.destination,
      );

  static XiangjiUsageAssistantAnswer? _contextualAnswer(
    String query,
    XiangjiUsageAssistantContext? context,
  ) {
    if (context == null) return null;
    final asksCurrent = <String>[
      '现在', '此刻', '下一步', '该做什么', '怎么开始', '卡住', '做不了', '没完成',
    ].any(query.contains);
    final asksWhy = <String>[
      '为什么这一步', '为什么这样做', '什么依据', '哪个思想', '哪个概念',
    ].any(query.contains);
    if (asksWhy && context.hasCurrentAction) {
      final guide = guideForId('action_mode');
      final methods = context.activeMethodLabels.isEmpty
          ? '本轮的经验—抽象—现实修订方法'
          : context.activeMethodLabels.join('、');
      return XiangjiUsageAssistantAnswer(
        title: '这一步为什么值得做',
        answer: '当前要缩小的差距是：${_orFallback(context.keyGap, '还缺一条能改变下一步的现实信息')}。\n\n'
            '所以不是让你再阅读一个概念，而是做：${context.currentAction}。\n\n'
            '本轮实际调用的方法：$methods。${context.principlePractice.isEmpty ? '' : '\n${context.principlePractice}'}',
        steps: <String>[
          '核对当前动作是否真的缩小关键差距',
          '按停止条件只做这一步',
          '将现实结果与事前预测对照',
        ],
        guideId: guide.id,
        coreConceptIds: context.coreConceptIds.isEmpty
            ? guide.coreConceptIds
            : context.coreConceptIds,
        knowledgeSource: context.knowledgeSource.isEmpty
            ? guide.knowledgeSource
            : context.knowledgeSource,
        thinkerNames: guide.thinkerNames,
        destination: 'current_action',
      );
    }
    if (!asksCurrent) return null;
    if (!context.hasProblem) {
      final guide = guideForId('bring_need');
      return _answerFor(guide).copyWith(
        title: '从一句真实需要开始',
        answer: '你还没有正在求解的问题。不用先学概念，只说“我想要什么 / 实际发生了什么 / 我卡在哪里”。',
      );
    }
    if (!context.hasCurrentAction) {
      final guide = guideForId('bring_need');
      return XiangjiUsageAssistantAnswer(
        title: '继续当前问题',
        answer: '你正在解决：${context.problem}。\n当前还需要形成一条可执行动作；关键差距是：${_orFallback(context.keyGap, '尚未确定')}。',
        steps: const <String>[
          '回到当前对话',
          '核对对问题的理解',
          '回答唯一关键未知，或选择“我不知道”',
        ],
        guideId: guide.id,
        coreConceptIds: context.coreConceptIds.isEmpty
            ? guide.coreConceptIds
            : context.coreConceptIds,
        knowledgeSource: context.knowledgeSource.isEmpty
            ? guide.knowledgeSource
            : context.knowledgeSource,
        thinkerNames: guide.thinkerNames,
        destination: 'conversation',
      );
    }
    final guide = guideForId(
      context.actionState == 'DONE' ? 'reality_feedback' : 'action_mode',
    );
    late final String directAnswer;
    late final List<String> steps;
    if (context.actionState == 'BLOCKED' || query.contains('卡住')) {
      directAnswer = '你不需要重新规划整个问题。当前动作是：${context.currentAction}\n\n'
          '受阻时的降级动作：${_orFallback(context.recoveryAction, '把对象或数量减半，只做 3 分钟；仍受阻就记录现实后停止')}。';
      steps = <String>[
        '先执行降级动作',
        '达到停止条件就停',
        '如实记录是否启动、阻碍在哪里',
      ];
    } else if (context.actionState == 'DONE') {
      directAnswer = '当前行动已完成，但问题还不能因此宣布解决。现在只需回报实际发生了什么，让现实检查事前预测：${context.prediction}';
      steps = const <String>[
        '打开当前行动',
        '写 1–3 条可观察事实和意外',
        '查看改判、练会的方法和新的一步',
      ];
    } else {
      directAnswer = '你现在只做这一件事：${context.currentAction}\n\n'
          '做到这里就停：${_orFallback(context.stopCondition, '达到时间边界或取得一条现实结果')}。';
      steps = const <String>[
        '打开当前行动并确认开始',
        '只做屏幕上的当前一步',
        '停止后回报现实，不评价自己',
      ];
    }
    return XiangjiUsageAssistantAnswer(
      title: '你现在该做的一步',
      answer: directAnswer,
      steps: steps,
      guideId: guide.id,
      coreConceptIds: context.coreConceptIds.isEmpty
          ? guide.coreConceptIds
          : context.coreConceptIds,
      knowledgeSource: context.knowledgeSource.isEmpty
          ? guide.knowledgeSource
          : context.knowledgeSource,
      thinkerNames: guide.thinkerNames,
      destination: 'current_action',
    );
  }

  static String assistantKnowledgeJson() => jsonEncode(<String, Object?>{
        'mission': mission,
        'ethical_boundary': ethicalBoundary,
        'core_loop': coreLoop
            .map((step) => <String, Object?>{
                  'title': step.title,
                  'user_action': step.userAction,
                  'system_work': step.systemWork,
                  'output': step.output,
                  'l0_core_concept_ids': step.coreConceptIds,
                })
            .toList(),
        'feature_guides':
            featureGuides.map((guide) => guide.toPromptMap()).toList(),
      });
}

String _orFallback(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();

List<String> _uniqueStrings(Iterable<String> values) => values
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .fold<List<String>>(<String>[], (result, value) {
      if (!result.contains(value)) result.add(value);
      return result;
    });

List<String> _jsonStrings(
  Object? raw, {
  List<String> fallback = const <String>[],
}) {
  if (raw == null) return fallback;
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    final values = _objectStrings(decoded);
    return values.isEmpty ? fallback : values;
  } catch (_) {
    return fallback;
  }
}

List<String> _objectStrings(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _positiveInt(Object? raw, int fallback) {
  final parsed = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  return parsed == null || parsed < 0 ? fallback : parsed;
}

int _supportedPreferredMinutes(Object? raw) {
  final parsed = _positiveInt(raw, 10);
  if (parsed <= 5) return 3;
  if (parsed <= 15) return 10;
  return 20;
}
