import 'dart:convert';

import 'xiangji_models.dart';
import 'xiangji_rev3_models.dart';
import 'xiangji_rev4_models.dart';

class XiangjiInputClassifier {
  const XiangjiInputClassifier();

  bool isExplicitActionFeedback(
    String input, {
    required bool hasActiveAction,
  }) {
    final text = input.trim();
    return _matches(text, _actionFeedbackSignals) ||
        (hasActiveAction && _matches(text, _shortFeedbackSignals));
  }

  XiangjiInputClassification classify({
    required String input,
    XiangjiProblemRecord? activeProblem,
    bool explicitNewProblem = false,
    bool hasActiveAction = false,
  }) {
    final text = input.trim();
    if (explicitNewProblem || _matches(text, _newProblemSignals)) {
      return const XiangjiInputClassification(
        type: XiangjiInputType.newProblem,
        updateExistingProblem: false,
        reason: '用户明确开启独立议题；保留旧问题，不把两个目标混在一起。',
      );
    }

    final type = _typeFor(text, hasActiveAction: hasActiveAction);
    if (activeProblem == null) {
      return XiangjiInputClassification(
        type: type,
        updateExistingProblem: false,
        reason: '当前没有可继续的主问题，因此为这项需要建立稳定问题身份。',
      );
    }

    if (type != XiangjiInputType.need) {
      return XiangjiInputClassification(
        type: type,
        updateExistingProblem: true,
        targetProblemId: activeProblem.id,
        reason: '${type.label}默认更新当前问题，不因新消息创建平行问题。',
        confidence: 0.96,
      );
    }

    final overlap = _semanticOverlap(
      text,
      <String>[
        activeProblem.rawQuestion,
        activeProblem.reframedQuestion,
        activeProblem.goalText,
      ],
    );
    if (overlap >= 0.18 || _matches(text, _continuationSignals)) {
      return XiangjiInputClassification(
        type: type,
        updateExistingProblem: true,
        targetProblemId: activeProblem.id,
        reason: '新的表达仍服务同一核心目标，继续更新现有问题状态。',
        confidence: (0.72 + overlap).clamp(0, 0.98).toDouble(),
      );
    }
    return XiangjiInputClassification(
      type: XiangjiInputType.newProblem,
      updateExistingProblem: false,
      reason: '新的需要与当前问题缺少目标相关联系，建立独立问题，旧问题保持不变。',
      confidence: 0.78,
    );
  }

  XiangjiInputType _typeFor(
    String text, {
    required bool hasActiveAction,
  }) {
    if (_matches(text, _correctionSignals)) {
      return XiangjiInputType.correction;
    }
    if (isExplicitActionFeedback(
      text,
      hasActiveAction: hasActiveAction,
    )) {
      return XiangjiInputType.actionFeedback;
    }
    // A stated goal remains a Need even when the same sentence also includes
    // background facts such as "已经" or "连续". Its semantic overlap with the
    // active problem then decides whether to continue or create a new problem.
    if (_matches(text, _needSignals)) return XiangjiInputType.need;
    if (_matches(text, _experienceSignals)) {
      return XiangjiInputType.experience;
    }
    if (_matches(text, _factSignals)) return XiangjiInputType.newFact;
    return hasActiveAction
        ? XiangjiInputType.actionFeedback
        : XiangjiInputType.need;
  }

  double _semanticOverlap(String input, List<String> candidates) {
    final left = _bigrams(_normalizeNeed(input));
    if (left.isEmpty) return 0;
    var best = 0.0;
    for (final candidate in candidates) {
      final right = _bigrams(_normalizeNeed(candidate));
      if (right.isEmpty) continue;
      final shared = left.intersection(right).length;
      final score = shared / (left.length < right.length ? left.length : right.length);
      if (score > best) best = score;
    }
    return best;
  }

  String _normalizeNeed(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'^(?:现实反馈|更正|纠正|另外|还有|我想要|我想|我要|我希望|我需要|请帮我|帮我)[：:\s，,]*'), '')
      .replaceAll(RegExp(r'[\s，。！？、；：,.!?;:\-]+'), '');

  Set<String> _bigrams(String value) {
    final runes = value.runes.toList(growable: false);
    if (runes.isEmpty) return const <String>{};
    if (runes.length == 1) return <String>{value};
    return <String>{
      for (var index = 0; index + 1 < runes.length; index++)
        String.fromCharCodes(runes.sublist(index, index + 2)),
    };
  }

  bool _matches(String value, List<String> terms) =>
      terms.any(value.contains);

  static const List<String> _newProblemSignals = <String>[
    '另外一个问题',
    '另一个问题',
    '新的问题',
    '换个话题',
    '另外我还要',
    '同时还有一件独立的事',
  ];
  static const List<String> _continuationSignals = <String>[
    '继续',
    '还是这个问题',
    '关于刚才',
    '接着',
    '又',
  ];
  static const List<String> _correctionSignals = <String>[
    '更正',
    '纠正',
    '不是',
    '你理解错了',
    '真正的情况是',
    '我刚才说错了',
  ];
  static const List<String> _actionFeedbackSignals = <String>[
    '现实反馈',
    '我做了',
    '我试了',
    '已经完成',
    '完成了',
    '做了但',
    '还是没去',
    '今天仍没',
    '今天还是没',
    '没人回复',
    '没有回复',
    '结果是',
    '实际发生',
  ];
  static const List<String> _shortFeedbackSignals = <String>[
    '没有',
    '没做',
    '没去',
    '失败',
    '成功',
    '卡住',
    '反而',
  ];
  static const List<String> _experienceSignals = <String>[
    '我感觉',
    '我觉得',
    '我害怕',
    '我担心',
    '我抗拒',
    '不想去',
    '不对劲',
    '说不清',
    '胸口',
    '焦虑',
    '紧张',
    '难受',
    '疲惫',
  ];
  static const List<String> _factSignals = <String>[
    '今天',
    '昨天',
    '已经',
    '收到',
    '投了',
    '面试',
    '对方说',
    '发生了',
    '连续',
  ];
  static const List<String> _needSignals = <String>[
    '我想',
    '我要',
    '我希望',
    '我需要',
    '如何',
    '怎样',
    '怎么办',
  ];
}

class XiangjiProblemStateManager {
  const XiangjiProblemStateManager();

  XiangjiPersistentProblemState lifecycleFor({
    required XiangjiInputClassification classification,
    required XiangjiSituationDraft draft,
    bool awaitingClarification = false,
    bool userDoesNotKnow = false,
    bool realityContradicted = false,
  }) {
    if (realityContradicted) return XiangjiPersistentProblemState.backtrack;
    if (classification.type == XiangjiInputType.correction) {
      return XiangjiPersistentProblemState.reframe;
    }
    if (classification.type == XiangjiInputType.actionFeedback) {
      return XiangjiPersistentProblemState.continuing;
    }
    if (awaitingClarification) return XiangjiPersistentProblemState.modeling;
    if (userDoesNotKnow ||
        draft.informationNeeds.any(
          (need) => need.missing && need.scoutingPossible,
        )) {
      return XiangjiPersistentProblemState.scouting;
    }
    return draft.currentAction.trim().isEmpty
        ? XiangjiPersistentProblemState.solving
        : XiangjiPersistentProblemState.actionReady;
  }

  Map<String, Object?> buildVersion({
    required String problemId,
    required int version,
    required XiangjiPersistentProblemState state,
    required XiangjiSituationDraft draft,
    required Map<String, Object?>? previousState,
    required String generatedBy,
    required List<String> sourceRefs,
  }) {
    final previousUnknowns = _decodeList(previousState?['unknowns_json']);
    final resolved = previousUnknowns
        .where((item) => !draft.unknowns.contains(item))
        .toList();
    return <String, Object?>{
      'problem_id': problemId,
      'version_no': version,
      'lifecycle_state': state.wire,
      'facts_json': jsonEncode(draft.observedFacts),
      'unknowns_json': jsonEncode(draft.unknowns),
      'assumptions_json': jsonEncode(draft.assumptions),
      'constraints_json': jsonEncode(draft.constraints),
      'key_gap': draft.targetGap,
      'current_hypotheses_json': jsonEncode(draft.causalHypotheses),
      'selected_operator_json': jsonEncode(<String, Object?>{
        'action': draft.currentAction,
        'mechanism': draft.operatorMechanism,
        'target_gap': draft.targetGap,
        'prediction': draft.prediction,
      }),
      'resolved_items_json': jsonEncode(resolved),
      'current_focus': draft.targetGap,
      'current_experiment': draft.currentAction,
      'next_verification': draft.prediction,
      'generated_by': generatedBy,
      'source_refs_json': jsonEncode(sourceRefs),
      'stale_reason': '',
    };
  }

  List<String> _decodeList(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is! List) return const <String>[];
      return value.map((item) => item.toString()).toList();
    } catch (_) {
      return const <String>[];
    }
  }
}

class XiangjiCognitiveExperienceGenerator {
  const XiangjiCognitiveExperienceGenerator();

  List<XiangjiCognitiveExperienceDraft> generate({
    required XiangjiSituationDraft draft,
    required String utterance,
    required String Function(String prefix) idFactory,
    bool hasPriorState = false,
    bool realityConflict = false,
    bool userCorrection = false,
    String oldModel = '',
    String newReality = '',
    bool methodTrainingEnabled = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <XiangjiCognitiveExperienceDraft>[];
    XiangjiCognitiveExperienceDraft card({
      required String trigger,
      required List<String> rules,
      required String message,
      required XiangjiCognitivePresentation presentation,
      Map<String, String> details = const <String, String>{},
      String method = '',
      String transfer = '',
    }) =>
        XiangjiCognitiveExperienceDraft(
          id: idFactory('xf_cognitive_experience'),
          trigger: trigger,
          sckRuleIds: rules,
          headline: presentation.label,
          userMessage: message,
          presentation: presentation,
          details: details,
          methodText: method,
          transferPrompt: methodTrainingEnabled ? transfer : '',
          createdAtMs: now,
        );

    final hasUnconceptualizedExperience = const <String>[
      '说不清',
      '不对劲',
      '难以描述',
      '不知道怎么形容',
    ].any(utterance.contains);
    if (hasUnconceptualizedExperience) {
      result.add(card(
        trigger: '用户报告尚不能被现成概念准确命名的体验',
        rules: const <String>['SCK-012', 'SCK-013', 'CEL-008'],
        message: '这份“说不清但不对劲”的体验已经按原样保留。现在不强迫给它贴标签，先观察它在什么场景出现、怎样变化。',
        presentation: XiangjiCognitivePresentation.experienceInterpretation,
        details: <String, String>{
          '按原话保留': utterance,
          '已经能描述的体验': draft.bodyExperiences.join('；'),
          '下一次只需观察': '出现的场景、身体变化、持续时间，以及什么让它增强或减弱。',
        },
        method: '有些真实体验暂时没有合适概念。先保留细节与出现条件，比急着归入人格或诊断标签更能保护现实信息。',
        transfer: '下次出现时，只记录“何时、何地、身体哪里、持续多久”，暂时不解释原因。',
      ));
    }

    if (utterance.startsWith('方法练习反馈：')) {
      final response = utterance.substring('方法练习反馈：'.length).trim();
      result.add(card(
        trigger: '用户完成了当前问题中的可选迁移练习',
        rules: const <String>['CEL-013', 'CEL-015'],
        message: '这次练习不是单独上课，而是在当前问题里检验方法。你的观察已经进入同一道题，军师会用它调整下一步。',
        presentation: XiangjiCognitivePresentation.learningMoment,
        details: <String, String>{
          '你的练习反馈': response,
          '军师的即时反馈': response.isEmpty
              ? '还缺少一个具体观察；下一次只记录实际出现了什么。'
              : '你已经把方法落到具体观察。现在把它与“${draft.changeSignals}”对照，看看它支持、削弱还是无法区分当前解释。',
          '怎样回到当前问题': draft.currentAction,
        },
        method: '迁移练习只有在改变当前判断或行动时才有价值。系统把练习反馈作为现实材料，而不是完成课程的勋章。',
        transfer: '用一句话标记：这次观察“支持 / 削弱 / 尚不能区分”哪一个当前解释？',
      ));
    }

    final split = _splitExperienceAndInterpretation(utterance, draft);
    if (split.$1.isNotEmpty || split.$2.isNotEmpty) {
      result.add(card(
        trigger: '用户体验与外部解释需要分层',
        rules: const <String>['SCK-002', 'SCK-011', 'CEL-002'],
        message: split.$1.isEmpty
            ? '你的解释已经保留下来；它还需要现实材料验证，暂时不把它当成外部事实。'
            : '“${split.$1}”作为你的真实体验被保留；“${split.$2.isEmpty ? '外部原因尚不确定' : split.$2}”是当前需要验证的解释。',
        presentation: XiangjiCognitivePresentation.experienceInterpretation,
        details: <String, String>{
          '实际发生 / 真实体验': split.$1,
          '当前解释': split.$2,
          '军师怎样处理': '不否定体验，也不把解释直接升级为事实。',
        },
        method: '这里使用了“把经验和解释分开”的方法。经验可以是真实的，同时它对外部原因的解释仍可能需要补证。这样既不否定你，也不给未经验证的判断加上确定性。',
        transfer: '下次遇到强烈感受时，先试着各写一句：“我实际体验到……”和“我现在把它解释为……”。',
      ));
    }

    result.add(card(
      trigger: '形成高影响 AI 判断',
      rules: const <String>['SCK-001', 'CEL-003'],
      message: '这是军师基于当前材料形成的理解，不是关于你的最终事实；新的现实可以让它被修订。',
      presentation: XiangjiCognitivePresentation.modelHumility,
      details: <String, String>{
        '当前判断': draft.judgment,
        '会改变它的现实': draft.changeSignals,
      },
      method: '模型谦逊不是少给建议，而是把建议和现实区分开。军师仍会明确推荐，同时保留什么事实会改变推荐。',
      transfer: '先找出当前判断中最容易被新事实改变的一句。',
    ));

    final causes = _causes(draft.causalHypotheses);
    if (causes.length >= 2) {
      final causeDetails = <String, String>{};
      for (var index = 0; index < causes.length; index++) {
        causeDetails['候选原因 ${index + 1}'] = causes[index].$1;
      }
      causeDetails['怎样区分'] = causes
          .map((item) => item.$2)
          .where((item) => item.isNotEmpty)
          .take(2)
          .join('；');
      result.add(card(
        trigger: '重要结果存在多个可区分原因',
        rules: const <String>['SCK-003', 'SCK-004', 'CEL-004'],
        message: '目前还不能确定单一原因。至少有 ${causes.length} 种解释；先用一个低成本现实实验区分它们。',
        presentation: XiangjiCognitivePresentation.competingCauses,
        details: causeDetails,
        method: '一个结果可能由不同机制产生，所以先找竞争解释，再设计能让它们给出不同预测的小实验。实验的目的不是证明某个人格标签，而是减少关键未知。',
        transfer: '在最相信的原因之外，再提出一个机制真正不同的可能原因。',
      ));
    }

    if (hasPriorState || draft.relevantDifferences.isNotEmpty) {
      result.add(card(
        trigger: '当前判断准备复用历史案例或旧概念',
        rules: const <String>['SCK-005', 'CEL-005'],
        message: draft.relevantDifferences.isEmpty
            ? '表面名称相同还不能说明机制相同；需要先找出会改变当前策略的差异。'
            : '这次不能只按旧标签处理。会改变策略的关键差异是：${draft.relevantDifferences.take(2).join('；')}。',
        presentation: XiangjiCognitivePresentation.caseComparison,
        details: <String, String>{
          '目标相关的相同点': draft.relevantSimilarities.join('；'),
          '关键差异': draft.relevantDifferences.join('；'),
          '反例 / 边界': draft.counterexamples.join('；'),
          '对下一步的影响': draft.judgment,
        },
        method: '判断力比较的重点不是罗列所有不同，而是找出哪些差异会改变当前目标、因果机制或行动路线。',
        transfer: '问自己：如果只允许保留一个差异，哪一个最可能改变下一步？',
      ));
    }

    result.add(card(
      trigger: '当前求解形成了可修订工作概念',
      rules: const <String>['SCK-006', 'SCK-013', 'CEL-007'],
      message: '当前概念只服务这道具体问题，不是关于你的永久标签；实例、反例、边界和仍解释不了的细节会一起保留。',
      presentation: XiangjiCognitivePresentation.conceptBoundary,
      details: <String, String>{
        '支持它的实例 / 判据': <String>[
          ...draft.observedFacts,
          draft.successCriteria,
        ].where((item) => item.trim().isNotEmpty).join('；'),
        '反例': draft.counterexamples.join('；'),
        '适用边界': '只适用于“${draft.trueProblem}”与当前已知约束。',
        '仍未解释的细节': draft.unknowns.join('；'),
      },
      method: '抽象概念只有能回到具体实例、反例和适用边界时才有用。解释不了的细节不会被标签吞掉，而会成为后续修订入口。',
      transfer: '为当前最重要的标签补一句：“它只在……条件下适用；它还解释不了……”。',
    ));

    result.add(card(
      trigger: '形成高影响建议',
      rules: const <String>['SCK-007', 'CEL-006'],
      message: '我这样判断主要依据当前原话和可观察材料；最弱前提仍需现实验证。逻辑可以成立，但现实结论仍可能未决。',
      presentation: XiangjiCognitivePresentation.groundingExplanation,
      details: <String, String>{
        '已确认事实': draft.observedFacts.join('；'),
        '支持当前判断': draft.groundingReason,
        '反例 / 不支持': draft.counterexamples.join('；'),
        '最弱前提': draft.redTeam.isEmpty ? draft.assumptions.join('；') : draft.redTeam.first,
        '当前未知': draft.unknowns.join('；'),
        '什么会改变判断': draft.changeSignals,
      },
      method: '认识根据追踪的是“这个判断凭什么成立”。如果链条停在未经验证的前提，系统会把它标成待清偿的未知，而不是用更长的解释掩盖。',
      transfer: '试着指出这项判断最依赖、却最少被现实验证的一个前提。',
    ));

    if (draft.assumptions.isNotEmpty || draft.unknowns.isNotEmpty) {
      final weakestPremise = draft.redTeam.isNotEmpty
          ? draft.redTeam.first
          : draft.assumptions.isEmpty
              ? draft.unknowns.first
              : draft.assumptions.first;
      result.add(card(
        trigger: '推理形式成立但关键前提仍缺现实支持',
        rules: const <String>['SCK-010', 'CEL-011'],
        message: '这条推理在形式上可以成立，但现实结论仍取决于尚未充分验证的前提：“$weakestPremise”。',
        presentation: XiangjiCognitivePresentation.premiseAudit,
        details: <String, String>{
          '当前最弱前提': weakestPremise,
          '现实仍未证明': draft.unknowns.join('；'),
          '怎样验证': draft.currentAction,
        },
        method: '逻辑只能说明“如果前提成立，结论怎样跟着成立”；它不能替现实证明前提是真的。重大建议因此必须暴露最弱前提。',
        transfer: '把当前结论改写成“如果……成立，那么……”，看看“如果”后面哪一句还缺现实支持。',
      ));
    }

    if (draft.epistemicStatus == 'EPISTEMIC_DEBT' || draft.unknowns.isNotEmpty) {
      result.add(card(
        trigger: '结构完整但底层根据仍弱',
        rules: const <String>['SCK-008', 'SCK-009', 'CEL-010'],
        message: '当前模型结构已经较完整，但底层根据仍有缺口，所以只能暂时支持，不能因分析复杂而提高确定性。',
        presentation: XiangjiCognitivePresentation.systematicityAudit,
        details: <String, String>{
          '体系完整度': '已形成问题、差距、候选原因、行动和预测',
          '认识状态': '仍有关键未知，需要现实补证',
        },
        method: '系统性回答“材料是否组织得完整”，认识状态回答“现实根据有多强”。两者分开，能避免漂亮报告制造虚假可靠感。',
        transfer: '分别给当前方案写一句“结构上还缺什么”和“证据上还缺什么”。',
      ));
    }

    result.add(card(
      trigger: '推荐一个关键行动',
      rules: const <String>['SCK-015', 'CEL-012'],
      message: '推荐这一步，不是为了完成任务数量，而是因为它会用“${draft.operatorMechanism}”减少“${draft.targetGap}”。',
      presentation: XiangjiCognitivePresentation.actionMechanism,
      details: <String, String>{
        '当前一步': draft.currentAction,
        '它减少的差距': draft.targetGap,
        '作用机制': draft.operatorMechanism,
        '事前预测': draft.prediction,
        '停止 / 切换信号': draft.changeSignals,
      },
      method: '行动只有在能减少当前差距、并产生可观察结果时才算求解算子。做完后要对照事前预测，而不是只记录“我努力了”。',
      transfer: '在行动前先补完一句：“如果这一步有效，我应该观察到……”。',
    ));

    if (realityConflict) {
      result.add(card(
        trigger: '新现实反驳旧概念或预测',
        rules: const <String>['SCK-014', 'SCK-018', 'CEL-009'],
        message: '现实正在挑战旧解释。系统会保留旧判断，回溯最早可能出错的层，并按新现实修订，而不是把失败归咎于你没有努力。',
        presentation: XiangjiCognitivePresentation.realityConflict,
        details: <String, String>{
          '旧解释 / 预测': oldModel,
          '新现实': newReality,
          '准备怎样修订': '先检查算子、前提和关键差距，再决定继续、回溯或重构。',
        },
        method: '概念和策略必须服从现实。预测落空时先修模型，并保留旧版本，才能真正从错误中学习。',
        transfer: '先区分：是行动没有执行，还是行动执行了但机制没有产生预期结果？',
      ));
    }

    if (userCorrection && !realityConflict) {
      result.add(card(
        trigger: '用户纠正了军师的旧理解',
        rules: const <String>['SCK-001', 'SCK-014', 'CEL-014'],
        message: '你的纠正已经成为新的现实依据。旧理解会保留为历史版本，当前模型会据此修订。',
        presentation: XiangjiCognitivePresentation.learningMoment,
        details: <String, String>{
          '旧理解': oldModel,
          '你提供的新现实': newReality,
          '修订后的理解': draft.judgment,
          '这次学到的方法': '让用户纠正优先于 AI 旧推断，并保留修订前后的版本。',
        },
        method: '模型修订不是抹掉错误，而是保留旧理解、新现实与新版本之间的关系，这样系统才能真正从纠正中学习。',
        transfer: '发现建议不贴合时，直接指出“哪一句理解错了，以及正确现实是什么”。',
      ));
    }

    result.add(card(
      trigger: '信息已经足以支持一个可逆下一步',
      rules: const <String>['SCK-017', 'CEL-017'],
      message: '当前信息已经足够支持一个可逆下一步。先行动，回来后让新现实继续推动同一道题。',
      presentation: XiangjiCognitivePresentation.actThenLearn,
      method: '反思的目的不是无限增加解释，而是找到足够安全、能产生新现实的一步。行动后再验算，认识才会继续生长。',
      transfer: '判断当前还缺的是“会改变行动的信息”，还是只是“让解释更完整的信息”。',
    ));
    return result;
  }

  Map<String, Object?> explanationCard(XiangjiSituationDraft draft) =>
      <String, Object?>{
        'headline': '为什么军师这么判断？',
        'facts_json': jsonEncode(draft.observedFacts),
        'interpretation': draft.judgment,
        'counterevidence_json': jsonEncode(draft.counterexamples),
        'weakest_premise': draft.redTeam.isEmpty
            ? draft.assumptions.join('；')
            : draft.redTeam.first,
        'uncertainty': draft.unknowns.join('；'),
        'what_changes_it': draft.changeSignals,
      };

  (String, String) _splitExperienceAndInterpretation(
    String utterance,
    XiangjiSituationDraft draft,
  ) {
    final match = RegExp(r'(.+?)(?:，|,)?(?:所以|因此|这说明|说明)(.+)').firstMatch(utterance);
    if (match != null) {
      return (match.group(1)?.trim() ?? '', match.group(2)?.trim() ?? '');
    }
    return (
      draft.bodyExperiences.isEmpty ? '' : draft.bodyExperiences.first,
      draft.userInterpretations.isEmpty ? '' : draft.userInterpretations.first,
    );
  }

  List<(String, String)> _causes(List<String> values) => values
      .map((value) {
        final parts = value.split('|').map((item) => item.trim()).toList();
        return (
          parts.isEmpty ? '' : parts.first,
          parts.length > 1 ? parts.sublist(1).join('；') : '',
        );
      })
      .where((item) => item.$1.isNotEmpty)
      .take(5)
      .toList();
}
