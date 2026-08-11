import 'xiangji_models.dart';
import 'xiangji_rev3_models.dart';

class XiangjiSituationModelTransitionContext {
  const XiangjiSituationModelTransitionContext({
    this.rawSourceSaved = false,
    this.experienceAndInferenceSeparated = false,
    this.judgmentCompleted = false,
    this.groundingCompleted = false,
    this.askUserGuardAllowsProgress = false,
    this.problemFramed = false,
    this.newRealityContradictsModel = false,
  });

  final bool rawSourceSaved;
  final bool experienceAndInferenceSeparated;
  final bool judgmentCompleted;
  final bool groundingCompleted;
  final bool askUserGuardAllowsProgress;
  final bool problemFramed;
  final bool newRealityContradictsModel;
}

class XiangjiSituationModelStateMachine {
  const XiangjiSituationModelStateMachine();

  static const Map<XiangjiSituationModelState,
      Set<XiangjiSituationModelState>> _edges =
      <XiangjiSituationModelState, Set<XiangjiSituationModelState>>{
    XiangjiSituationModelState.raw: <XiangjiSituationModelState>{
      XiangjiSituationModelState.parsed,
    },
    XiangjiSituationModelState.parsed: <XiangjiSituationModelState>{
      XiangjiSituationModelState.judged,
      XiangjiSituationModelState.needsClarification,
      XiangjiSituationModelState.stale,
    },
    XiangjiSituationModelState.judged: <XiangjiSituationModelState>{
      XiangjiSituationModelState.grounded,
      XiangjiSituationModelState.needsClarification,
      XiangjiSituationModelState.stale,
    },
    XiangjiSituationModelState.grounded: <XiangjiSituationModelState>{
      XiangjiSituationModelState.framed,
      XiangjiSituationModelState.needsClarification,
      XiangjiSituationModelState.stale,
    },
    XiangjiSituationModelState.needsClarification:
        <XiangjiSituationModelState>{
      XiangjiSituationModelState.parsed,
      XiangjiSituationModelState.judged,
      XiangjiSituationModelState.stale,
    },
    XiangjiSituationModelState.framed: <XiangjiSituationModelState>{
      XiangjiSituationModelState.stale,
    },
    XiangjiSituationModelState.stale: <XiangjiSituationModelState>{
      XiangjiSituationModelState.parsed,
    },
  };

  XiangjiTransitionDecision<XiangjiSituationModelState> evaluate(
    XiangjiSituationModelState from,
    XiangjiSituationModelState to,
    XiangjiSituationModelTransitionContext context,
  ) {
    if (!(_edges[from]?.contains(to) ?? false)) {
      return XiangjiTransitionDecision<XiangjiSituationModelState>.reject(
        from,
        to,
        'SituationModel 不能从 ${from.wire} 直接进入 ${to.wire}。',
      );
    }
    if (to == XiangjiSituationModelState.parsed &&
        (!context.rawSourceSaved ||
            !context.experienceAndInferenceSeparated)) {
      return XiangjiTransitionDecision<XiangjiSituationModelState>.reject(
        from,
        to,
        '必须先保存用户原话，并把用户经验与 AI 推断分开。',
      );
    }
    if (to == XiangjiSituationModelState.judged &&
        !context.judgmentCompleted) {
      return XiangjiTransitionDecision<XiangjiSituationModelState>.reject(
        from,
        to,
        'A02 尚未完成目的相关同异、边界与反例审查。',
      );
    }
    if (to == XiangjiSituationModelState.grounded &&
        !context.groundingCompleted) {
      return XiangjiTransitionDecision<XiangjiSituationModelState>.reject(
        from,
        to,
        'A03 尚未完成根据链与认识债务审查。',
      );
    }
    if (to == XiangjiSituationModelState.framed &&
        (!context.askUserGuardAllowsProgress || !context.problemFramed)) {
      return XiangjiTransitionDecision<XiangjiSituationModelState>.reject(
        from,
        to,
        'AskUserGuard 尚未放行，或真问题候选尚未形成。',
      );
    }
    if (context.newRealityContradictsModel &&
        to != XiangjiSituationModelState.stale) {
      return XiangjiTransitionDecision<XiangjiSituationModelState>.reject(
        from,
        to,
        '新现实反驳当前模型时必须先进入 STALE（SCK-018）。',
      );
    }
    return XiangjiTransitionDecision<XiangjiSituationModelState>.allow(
      from,
      to,
    );
  }
}

class XiangjiTransitionDecision<T> {
  const XiangjiTransitionDecision._({
    required this.allowed,
    required this.from,
    required this.to,
    required this.reason,
  });

  factory XiangjiTransitionDecision.allow(T from, T to) =>
      XiangjiTransitionDecision<T>._(
        allowed: true,
        from: from,
        to: to,
        reason: '',
      );

  factory XiangjiTransitionDecision.reject(T from, T to, String reason) =>
      XiangjiTransitionDecision<T>._(
        allowed: false,
        from: from,
        to: to,
        reason: reason,
      );

  final bool allowed;
  final T from;
  final T to;
  final String reason;

  void requireAllowed() {
    if (!allowed) throw StateError(reason);
  }
}

class XiangjiProblemTransitionContext {
  const XiangjiProblemTransitionContext({
    this.rawMaterialSaved = false,
    this.experienceAndInterpretationSeparated = false,
    this.groundingReviewed = false,
    this.criticalUnknownHandled = false,
    this.conceptsReviewed = false,
    this.reframedQuestionConfirmed = false,
    this.goalCriteriaDefined = false,
    this.operatorSelected = false,
    this.predictionPrecommitted = false,
    this.userConfirmedAction = false,
    this.realityResultPresent = false,
    this.resolutionCriteriaMet = false,
  });

  final bool rawMaterialSaved;
  final bool experienceAndInterpretationSeparated;
  final bool groundingReviewed;
  final bool criticalUnknownHandled;
  final bool conceptsReviewed;
  final bool reframedQuestionConfirmed;
  final bool goalCriteriaDefined;
  final bool operatorSelected;
  final bool predictionPrecommitted;
  final bool userConfirmedAction;
  final bool realityResultPresent;
  final bool resolutionCriteriaMet;
}

class XiangjiProblemStateMachine {
  const XiangjiProblemStateMachine();

  static const Map<XiangjiProblemState, Set<XiangjiProblemState>> _edges =
      <XiangjiProblemState, Set<XiangjiProblemState>>{
    XiangjiProblemState.captured: <XiangjiProblemState>{
      XiangjiProblemState.formalizing,
      XiangjiProblemState.archived,
    },
    XiangjiProblemState.formalizing: <XiangjiProblemState>{
      XiangjiProblemState.epistemicReview,
      XiangjiProblemState.archived,
    },
    XiangjiProblemState.epistemicReview: <XiangjiProblemState>{
      XiangjiProblemState.conceptReview,
      XiangjiProblemState.backtracking,
      XiangjiProblemState.archived,
    },
    XiangjiProblemState.conceptReview: <XiangjiProblemState>{
      XiangjiProblemState.solving,
      XiangjiProblemState.backtracking,
      XiangjiProblemState.archived,
    },
    XiangjiProblemState.solving: <XiangjiProblemState>{
      XiangjiProblemState.actionReady,
      XiangjiProblemState.backtracking,
      XiangjiProblemState.archived,
    },
    XiangjiProblemState.actionReady: <XiangjiProblemState>{
      XiangjiProblemState.executing,
      XiangjiProblemState.solving,
      XiangjiProblemState.archived,
    },
    XiangjiProblemState.executing: <XiangjiProblemState>{
      XiangjiProblemState.verifying,
      XiangjiProblemState.backtracking,
    },
    XiangjiProblemState.verifying: <XiangjiProblemState>{
      XiangjiProblemState.resolved,
      XiangjiProblemState.solving,
      XiangjiProblemState.backtracking,
    },
    XiangjiProblemState.backtracking: <XiangjiProblemState>{
      XiangjiProblemState.formalizing,
      XiangjiProblemState.epistemicReview,
      XiangjiProblemState.conceptReview,
      XiangjiProblemState.solving,
    },
    XiangjiProblemState.resolved: <XiangjiProblemState>{
      XiangjiProblemState.archived,
      XiangjiProblemState.formalizing,
    },
    XiangjiProblemState.archived: <XiangjiProblemState>{
      XiangjiProblemState.formalizing,
    },
  };

  XiangjiTransitionDecision<XiangjiProblemState> evaluate(
    XiangjiProblemState from,
    XiangjiProblemState to,
    XiangjiProblemTransitionContext context,
  ) {
    if (!(_edges[from]?.contains(to) ?? false)) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '问题不能从 ${from.label} 直接进入 ${to.label}；必须保留认识、概念、求解与验算链。',
      );
    }
    if (to == XiangjiProblemState.formalizing && !context.rawMaterialSaved) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '必须先保存用户原题、原始经验与上下文，不能用 AI 改写替代原始材料。',
      );
    }
    if (to == XiangjiProblemState.epistemicReview &&
        !context.experienceAndInterpretationSeparated) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '必须先分离事实、身体/体验、解释、因果、判断和预测。',
      );
    }
    if (to == XiangjiProblemState.conceptReview &&
        (!context.groundingReviewed || !context.criticalUnknownHandled)) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '关键判断尚未完成认识根据审查，或决定性未知尚未清偿/转为侦察行动。',
      );
    }
    if (to == XiangjiProblemState.solving &&
        (!context.conceptsReviewed || !context.reframedQuestionConfirmed)) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '真问题和概念边界必须由用户确认；系统不得偷换原题。',
      );
    }
    if (to == XiangjiProblemState.actionReady &&
        (!context.goalCriteriaDefined || !context.operatorSelected)) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '目标现实判据、差距和当前办法尚未完成。',
      );
    }
    if (to == XiangjiProblemState.executing &&
        (!context.operatorSelected ||
            !context.predictionPrecommitted ||
            !context.userConfirmedAction)) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '进入行动前必须选定当前办法、事前保存预测，并由用户明确确认。',
      );
    }
    if (to == XiangjiProblemState.verifying &&
        !context.realityResultPresent) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '行动结束后必须记录现实结果；任务完成不等于问题解决。',
      );
    }
    if (to == XiangjiProblemState.resolved &&
        (!context.realityResultPresent || !context.resolutionCriteriaMet)) {
      return XiangjiTransitionDecision<XiangjiProblemState>.reject(
        from,
        to,
        '缺少现实结果或尚未满足解决判据，不能把 Problem 标记为 RESOLVED。',
      );
    }
    return XiangjiTransitionDecision<XiangjiProblemState>.allow(from, to);
  }
}

class XiangjiCampaignTransitionContext {
  const XiangjiCampaignTransitionContext({
    this.worthinessReviewed = false,
    this.victoryAndExitCriteriaDefined = false,
    this.resourceBudgetDefined = false,
    this.criticalUnknownsHandled = false,
    this.strategyOptionCount = 0,
    this.redTeamComplete = false,
    this.userConfirmed = false,
    this.reviewRecorded = false,
  });

  final bool worthinessReviewed;
  final bool victoryAndExitCriteriaDefined;
  final bool resourceBudgetDefined;
  final bool criticalUnknownsHandled;
  final int strategyOptionCount;
  final bool redTeamComplete;
  final bool userConfirmed;
  final bool reviewRecorded;
}

class XiangjiCampaignStateMachine {
  const XiangjiCampaignStateMachine();

  static const Map<XiangjiCampaignState, Set<XiangjiCampaignState>> _edges =
      <XiangjiCampaignState, Set<XiangjiCampaignState>>{
    XiangjiCampaignState.idea: <XiangjiCampaignState>{
      XiangjiCampaignState.warWorthiness,
      XiangjiCampaignState.closed,
    },
    XiangjiCampaignState.warWorthiness: <XiangjiCampaignState>{
      XiangjiCampaignState.intel,
      XiangjiCampaignState.hold,
      XiangjiCampaignState.closed,
    },
    XiangjiCampaignState.intel: <XiangjiCampaignState>{
      XiangjiCampaignState.planning,
      XiangjiCampaignState.hold,
      XiangjiCampaignState.retreat,
    },
    XiangjiCampaignState.planning: <XiangjiCampaignState>{
      XiangjiCampaignState.redTeam,
      XiangjiCampaignState.intel,
      XiangjiCampaignState.hold,
    },
    XiangjiCampaignState.redTeam: <XiangjiCampaignState>{
      XiangjiCampaignState.decision,
      XiangjiCampaignState.planning,
      XiangjiCampaignState.intel,
    },
    XiangjiCampaignState.decision: <XiangjiCampaignState>{
      XiangjiCampaignState.prepare,
      XiangjiCampaignState.hold,
      XiangjiCampaignState.retreat,
    },
    XiangjiCampaignState.prepare: <XiangjiCampaignState>{
      XiangjiCampaignState.executing,
      XiangjiCampaignState.hold,
    },
    XiangjiCampaignState.executing: <XiangjiCampaignState>{
      XiangjiCampaignState.hold,
      XiangjiCampaignState.adjust,
      XiangjiCampaignState.retreat,
      XiangjiCampaignState.won,
      XiangjiCampaignState.lost,
    },
    XiangjiCampaignState.hold: <XiangjiCampaignState>{
      XiangjiCampaignState.intel,
      XiangjiCampaignState.executing,
      XiangjiCampaignState.retreat,
    },
    XiangjiCampaignState.adjust: <XiangjiCampaignState>{
      XiangjiCampaignState.planning,
      XiangjiCampaignState.retreat,
    },
    XiangjiCampaignState.retreat: <XiangjiCampaignState>{
      XiangjiCampaignState.closed,
    },
    XiangjiCampaignState.won: <XiangjiCampaignState>{
      XiangjiCampaignState.closed,
    },
    XiangjiCampaignState.lost: <XiangjiCampaignState>{
      XiangjiCampaignState.closed,
    },
    XiangjiCampaignState.closed: <XiangjiCampaignState>{},
  };

  XiangjiTransitionDecision<XiangjiCampaignState> evaluate(
    XiangjiCampaignState from,
    XiangjiCampaignState to,
    XiangjiCampaignTransitionContext context,
  ) {
    if (!(_edges[from]?.contains(to) ?? false)) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '战役不能从 ${from.label} 直接进入 ${to.label}。',
      );
    }
    if (to == XiangjiCampaignState.intel && !context.worthinessReviewed) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '创建大量行动前必须先回答“是否值得一战”。',
      );
    }
    if (to == XiangjiCampaignState.planning &&
        !context.criticalUnknownsHandled) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '决定性战争迷雾尚未侦察或明确接受，不能假装情报完整。',
      );
    }
    if (to == XiangjiCampaignState.redTeam &&
        (!context.victoryAndExitCriteriaDefined ||
            !context.resourceBudgetDefined ||
            context.strategyOptionCount < 2)) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '红队前必须定义胜利/止损、兵力预算并形成至少两个真正不同的战略。',
      );
    }
    if (to == XiangjiCampaignState.decision && !context.redTeamComplete) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '重大方案尚未经过红队与判断力仲裁。',
      );
    }
    if (to == XiangjiCampaignState.prepare && !context.userConfirmed) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        'AI 负责谋，用户负责断；没有用户确认不能进入准备/执行。',
      );
    }
    if (to == XiangjiCampaignState.executing &&
        (!context.worthinessReviewed ||
            !context.criticalUnknownsHandled ||
            !context.victoryAndExitCriteriaDefined ||
            !context.resourceBudgetDefined ||
            !context.redTeamComplete ||
            !context.userConfirmed)) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '正式推进必须完成值得一战、情报、胜利/止损、兵力、红队和用户决断。',
      );
    }
    if (to == XiangjiCampaignState.closed &&
        from != XiangjiCampaignState.idea &&
        !context.reviewRecorded) {
      return XiangjiTransitionDecision<XiangjiCampaignState>.reject(
        from,
        to,
        '战役结束必须形成战史复盘，不能只打一个完成勾。',
      );
    }
    return XiangjiTransitionDecision<XiangjiCampaignState>.allow(from, to);
  }
}

class XiangjiClaimTransitionContext {
  const XiangjiClaimTransitionContext({
    this.validGroundingCount = 0,
    this.independentValidationCount = 0,
    this.criticalPremisesComplete = false,
    this.hasStrongCounterevidence = false,
    this.isHighImpact = false,
    this.reviewCreatedNewVersion = false,
  });

  final int validGroundingCount;
  final int independentValidationCount;
  final bool criticalPremisesComplete;
  final bool hasStrongCounterevidence;
  final bool isHighImpact;
  final bool reviewCreatedNewVersion;
}

class XiangjiClaimStateMachine {
  const XiangjiClaimStateMachine();

  XiangjiTransitionDecision<XiangjiClaimState> evaluate(
    XiangjiClaimState from,
    XiangjiClaimState to,
    XiangjiClaimTransitionContext context,
  ) {
    if (to == XiangjiClaimState.grounded) {
      if (context.validGroundingCount == 0 ||
          !context.criticalPremisesComplete ||
          context.independentValidationCount == 0 ||
          context.hasStrongCounterevidence) {
        return XiangjiTransitionDecision<XiangjiClaimState>.reject(
          from,
          to,
          '高影响 Claim 只有在关键前提完整、存在有效根据与独立验证且无强冲突时才能 GROUNDED。',
        );
      }
    }
    if (from == XiangjiClaimState.grounded &&
        context.hasStrongCounterevidence &&
        to != XiangjiClaimState.conflicted) {
      return XiangjiTransitionDecision<XiangjiClaimState>.reject(
        from,
        to,
        '出现强反例/现实冲突时必须进入 CONFLICTED。',
      );
    }
    if (from == XiangjiClaimState.conflicted &&
        to == XiangjiClaimState.provisional &&
        !context.reviewCreatedNewVersion) {
      return XiangjiTransitionDecision<XiangjiClaimState>.reject(
        from,
        to,
        '冲突复核必须保留旧版本并创建修订版本。',
      );
    }
    if (context.isHighImpact &&
        context.validGroundingCount == 0 &&
        to != XiangjiClaimState.epistemicDebt &&
        to != XiangjiClaimState.unresolved &&
        to != XiangjiClaimState.retired) {
      return XiangjiTransitionDecision<XiangjiClaimState>.reject(
        from,
        to,
        '无根据的高影响前提必须登记为认识债务或未决。',
      );
    }
    return XiangjiTransitionDecision<XiangjiClaimState>.allow(from, to);
  }
}

class XiangjiProviderFileStateMachine {
  const XiangjiProviderFileStateMachine();

  static const Map<XiangjiProviderFileState, Set<XiangjiProviderFileState>>
      _edges = <XiangjiProviderFileState, Set<XiangjiProviderFileState>>{
    XiangjiProviderFileState.notUploaded: <XiangjiProviderFileState>{
      XiangjiProviderFileState.uploading,
    },
    XiangjiProviderFileState.uploading: <XiangjiProviderFileState>{
      XiangjiProviderFileState.processing,
      XiangjiProviderFileState.ready,
      XiangjiProviderFileState.failed,
    },
    XiangjiProviderFileState.processing: <XiangjiProviderFileState>{
      XiangjiProviderFileState.ready,
      XiangjiProviderFileState.failed,
    },
    XiangjiProviderFileState.ready: <XiangjiProviderFileState>{
      XiangjiProviderFileState.failed,
      XiangjiProviderFileState.deleting,
    },
    XiangjiProviderFileState.failed: <XiangjiProviderFileState>{
      XiangjiProviderFileState.uploading,
      XiangjiProviderFileState.deleting,
    },
    XiangjiProviderFileState.deleting: <XiangjiProviderFileState>{
      XiangjiProviderFileState.deleted,
      XiangjiProviderFileState.failed,
    },
    XiangjiProviderFileState.deleted: <XiangjiProviderFileState>{
      XiangjiProviderFileState.uploading,
    },
  };

  XiangjiTransitionDecision<XiangjiProviderFileState> evaluate(
    XiangjiProviderFileState from,
    XiangjiProviderFileState to, {
    required XiangjiProviderCapability capability,
    String remoteFileId = '',
    bool providerDeleteConfirmed = false,
  }) {
    if (!(_edges[from]?.contains(to) ?? false)) {
      return XiangjiTransitionDecision<XiangjiProviderFileState>.reject(
        from,
        to,
        '不合法的远程文件状态迁移：${from.wire} -> ${to.wire}',
      );
    }
    if (to == XiangjiProviderFileState.ready &&
        (!capability.mayClaimPersistentStorage || remoteFileId.isEmpty)) {
      return XiangjiTransitionDecision<XiangjiProviderFileState>.reject(
        from,
        to,
        '服务商未验证持久文件与复用能力，或缺少 remote_file_id，不能标记 READY/永久保存。',
      );
    }
    if (to == XiangjiProviderFileState.deleted &&
        capability.supportsDelete &&
        !providerDeleteConfirmed) {
      return XiangjiTransitionDecision<XiangjiProviderFileState>.reject(
        from,
        to,
        '远程删除尚未确认，不能把本地状态伪装为 DELETED。',
      );
    }
    return XiangjiTransitionDecision<XiangjiProviderFileState>.allow(from, to);
  }
}

class XiangjiKnowledgeItemStateMachine {
  const XiangjiKnowledgeItemStateMachine();

  XiangjiTransitionDecision<XiangjiKnowledgeItemState> evaluate(
    XiangjiKnowledgeItemState from,
    XiangjiKnowledgeItemState to, {
    int realEvidenceCount = 0,
    int distinctEventCount = 0,
    bool userExplicitlyConfirmed = false,
    bool hasScope = false,
    bool counterexamplesPreserved = false,
    bool hasStrongConflict = false,
  }) {
    if (hasStrongConflict && to != XiangjiKnowledgeItemState.conflicted) {
      return XiangjiTransitionDecision<XiangjiKnowledgeItemState>.reject(
        from,
        to,
        '新现实/原著/关键证据产生强冲突，必须保留冲突并进入复核。',
      );
    }
    if (to == XiangjiKnowledgeItemState.supported && realEvidenceCount == 0) {
      return XiangjiTransitionDecision<XiangjiKnowledgeItemState>.reject(
        from,
        to,
        '单次 AI 推断不能升级为 SUPPORTED；至少需要真实 Experience/Evidence。',
      );
    }
    if (to == XiangjiKnowledgeItemState.stable &&
        (!(distinctEventCount >= 2 || userExplicitlyConfirmed) ||
            !hasScope ||
            !counterexamplesPreserved)) {
      return XiangjiTransitionDecision<XiangjiKnowledgeItemState>.reject(
        from,
        to,
        '个人规则升级需多次真实支持或用户确认，并保留范围、反例与版本。',
      );
    }
    return XiangjiTransitionDecision<XiangjiKnowledgeItemState>.allow(from, to);
  }
}

class XiangjiEpistemicAssessmentInput {
  const XiangjiEpistemicAssessmentInput({
    this.basisType = XiangjiBasisType.unknown,
    this.directness = 0,
    this.validGroundingCount = 0,
    this.criticalPremiseCount = 0,
    this.groundedCriticalPremiseCount = 0,
    this.independentValidation = 0,
    this.hasWeakCounterexample = false,
    this.hasStrongCounterexample = false,
    this.isStale = false,
    this.systematicity = 'unknown',
    this.isHighImpact = false,
    this.weakestPremise = '',
  });

  final XiangjiBasisType basisType;
  final int directness;
  final int validGroundingCount;
  final int criticalPremiseCount;
  final int groundedCriticalPremiseCount;
  final int independentValidation;
  final bool hasWeakCounterexample;
  final bool hasStrongCounterexample;
  final bool isStale;
  final String systematicity;
  final bool isHighImpact;
  final String weakestPremise;
}

class XiangjiEpistemicEngine {
  const XiangjiEpistemicEngine();

  XiangjiEpistemicProfile assess(XiangjiEpistemicAssessmentInput input) {
    final complete = input.criticalPremiseCount == 0
        ? input.validGroundingCount > 0
        : input.groundedCriticalPremiseCount >= input.criticalPremiseCount;
    final completeness = complete
        ? 'good'
        : input.groundedCriticalPremiseCount > 0 ||
                input.validGroundingCount > 0
            ? 'partial'
            : 'weak';
    final counterexample = input.hasStrongCounterexample
        ? 'strong'
        : input.hasWeakCounterexample
            ? 'weak'
            : 'none';
    final summary = input.hasStrongCounterexample
        ? XiangjiSummaryStatus.conflicted
        : input.validGroundingCount == 0 && input.isHighImpact
            ? XiangjiSummaryStatus.highDebt
            : input.validGroundingCount == 0
                ? XiangjiSummaryStatus.unresolved
                : complete &&
                        input.independentValidation > 0 &&
                        !input.isStale
                    ? XiangjiSummaryStatus.strongSupport
                    : XiangjiSummaryStatus.provisional;
    return XiangjiEpistemicProfile(
      basisType: input.basisType,
      directness: input.directness,
      completeness: completeness,
      independentValidation: input.independentValidation,
      counterexampleState: counterexample,
      freshness: input.isStale ? 'stale' : 'fresh',
      summaryStatus: summary,
      systematicity: input.systematicity,
      weakestPremise: input.weakestPremise,
    );
  }

  XiangjiClaimState claimStateFor(XiangjiEpistemicProfile profile) =>
      switch (profile.summaryStatus) {
        XiangjiSummaryStatus.strongSupport => XiangjiClaimState.grounded,
        XiangjiSummaryStatus.provisional => XiangjiClaimState.provisional,
        XiangjiSummaryStatus.unresolved => XiangjiClaimState.unresolved,
        XiangjiSummaryStatus.highDebt => XiangjiClaimState.epistemicDebt,
        XiangjiSummaryStatus.conflicted => XiangjiClaimState.conflicted,
      };

  /// The output avoids false precision and keeps systematicity separate.
  String humanSummary(XiangjiEpistemicProfile profile) {
    final status = switch (profile.summaryStatus) {
      XiangjiSummaryStatus.strongSupport => '较强支持',
      XiangjiSummaryStatus.provisional => '暂时支持',
      XiangjiSummaryStatus.unresolved => '未决',
      XiangjiSummaryStatus.highDebt => '高认识债务',
      XiangjiSummaryStatus.conflicted => '与现实冲突',
    };
    return '认识状态：$status；系统化程度：${profile.systematicity}；'
        '根据：${profile.basisType.name}；独立来源：${profile.independentValidation}；'
        '反例：${profile.counterexampleState}；时效：${profile.freshness}。';
  }
}

class XiangjiGroundingNode {
  const XiangjiGroundingNode({
    required this.id,
    required this.type,
    this.text = '',
  });

  final String id;
  final String type;
  final String text;

  bool get isSpring => type == 'experience' || type == 'evidence';
}

class XiangjiGroundingEdge {
  const XiangjiGroundingEdge({
    required this.from,
    required this.to,
    this.relation = 'GROUNDED_BY',
  });

  final String from;
  final String to;
  final String relation;
}

class XiangjiGroundingAudit {
  const XiangjiGroundingAudit({
    required this.springPaths,
    required this.cycles,
    required this.ungroundedLeaves,
  });

  final List<List<String>> springPaths;
  final List<List<String>> cycles;
  final List<String> ungroundedLeaves;

  bool get hasGrounding => springPaths.isNotEmpty;
  bool get hasConceptCycle => cycles.isNotEmpty;
}

class XiangjiGroundingGraph {
  const XiangjiGroundingGraph();

  XiangjiGroundingAudit audit({
    required String rootId,
    required List<XiangjiGroundingNode> nodes,
    required List<XiangjiGroundingEdge> edges,
  }) {
    final byId = <String, XiangjiGroundingNode>{
      for (final node in nodes) node.id: node,
    };
    final adjacency = <String, List<String>>{};
    for (final edge in edges) {
      if (edge.relation == 'GROUNDED_BY' || edge.relation == 'DERIVED_FROM') {
        adjacency.putIfAbsent(edge.from, () => <String>[]).add(edge.to);
      }
    }
    final springs = <List<String>>[];
    final cycles = <List<String>>[];
    final leaves = <String>[];

    void walk(String current, List<String> path, Set<String> active) {
      if (active.contains(current)) {
        final start = path.indexOf(current);
        cycles.add(<String>[...path.sublist(start < 0 ? 0 : start), current]);
        return;
      }
      final node = byId[current];
      final nextPath = <String>[...path, current];
      if (node?.isSpring ?? false) {
        springs.add(nextPath);
        return;
      }
      final next = adjacency[current] ?? const <String>[];
      if (next.isEmpty) {
        leaves.add(current);
        return;
      }
      final nextActive = <String>{...active, current};
      for (final id in next) {
        walk(id, nextPath, nextActive);
      }
    }

    walk(rootId, const <String>[], <String>{});
    return XiangjiGroundingAudit(
      springPaths: _dedupePaths(springs),
      cycles: _dedupePaths(cycles),
      ungroundedLeaves: leaves.toSet().toList(),
    );
  }

  List<List<String>> _dedupePaths(List<List<String>> paths) {
    final seen = <String>{};
    return paths.where((path) => seen.add(path.join('>'))).toList();
  }
}

class XiangjiRuleRequest {
  const XiangjiRuleRequest({
    required this.requestId,
    this.rawText = '',
    this.isMajorDecision = false,
    this.isHighRisk = false,
    this.isIrreversible = false,
    this.hasHighEpistemicDebt = false,
    this.hasUserConfirmation = false,
    this.aiInferencePresentedAsFact = false,
    this.abstractComplexityUsedAsEvidence = false,
    this.proofHasUngroundedPremise = false,
    this.directPerceptionMissingConditions = false,
    this.semanticSimilarityUsedAsGrounding = false,
    this.realityResultMissing = false,
  });

  final String requestId;
  final String rawText;
  final bool isMajorDecision;
  final bool isHighRisk;
  final bool isIrreversible;
  final bool hasHighEpistemicDebt;
  final bool hasUserConfirmation;
  final bool aiInferencePresentedAsFact;
  final bool abstractComplexityUsedAsEvidence;
  final bool proofHasUngroundedPremise;
  final bool directPerceptionMissingConditions;
  final bool semanticSimilarityUsedAsGrounding;
  final bool realityResultMissing;
}

class XiangjiRuleHit {
  const XiangjiRuleHit({
    required this.ruleId,
    required this.requirementIds,
    required this.message,
    required this.action,
    required this.blocking,
  });

  final String ruleId;
  final List<String> requirementIds;
  final String message;
  final String action;
  final bool blocking;
}

class XiangjiRulePreflightResult {
  const XiangjiRulePreflightResult({
    required this.hits,
    required this.alertState,
    required this.executionFrozen,
  });

  final List<XiangjiRuleHit> hits;
  final XiangjiAlertState alertState;
  final bool executionFrozen;

  List<String> get ruleIds => hits.map((hit) => hit.ruleId).toList();
}

/// Offline K0 guard. These rules are code/data rules, not optional RAG text.
class XiangjiK0RuleEngine {
  const XiangjiK0RuleEngine();

  XiangjiRulePreflightResult preflight(XiangjiRuleRequest request) {
    final hits = <XiangjiRuleHit>[];
    void add(
      String id,
      List<String> requirements,
      String message,
      String action, {
      bool blocking = false,
    }) {
      hits.add(XiangjiRuleHit(
        ruleId: id,
        requirementIds: requirements,
        message: message,
        action: action,
        blocking: blocking,
      ));
    }

    if (request.aiInferencePresentedAsFact) {
      add(
        'K0-RULE-002',
        const <String>['EP-001', 'EP-002', 'KB-002', 'KB-007'],
        'AI 推断不能覆盖用户原话或写成外部事实。',
        '把内容降为 interpretation/hypothesis，并保留来源。',
        blocking: true,
      );
    }
    if (request.abstractComplexityUsedAsEvidence) {
      add(
        'K0-RULE-014',
        const <String>['EP-014', 'EP-015'],
        '抽象性、学术性和系统复杂度不提供确定性加成。',
        '分别展示系统化程度与认识根据。',
        blocking: true,
      );
    }
    if (request.proofHasUngroundedPremise) {
      add(
        'K0-RULE-016',
        const <String>['EP-016'],
        '推理结构成立不能补救无根据的关键前提。',
        '标记前提未决并创建认识债务。',
        blocking: true,
      );
    }
    if (request.directPerceptionMissingConditions) {
      add(
        'K0-RULE-017',
        const <String>['EP-017'],
        '直接知觉也不自动无误。',
        '补充观察条件、替代解释和可能误差。',
      );
    }
    if (request.semanticSimilarityUsedAsGrounding) {
      add(
        'K0-RULE-025',
        const <String>['KB-025'],
        '向量相似度只负责召回，不能成为 Evidence/GroundingRelation。',
        '把召回内容标记为 candidate context，另行核查来源。',
        blocking: true,
      );
    }
    if (request.isMajorDecision && request.hasHighEpistemicDebt) {
      add(
        'K0-RULE-007',
        const <String>['EP-007', 'PS-013'],
        '高影响决策的关键前提仍有高认识债务。',
        '优先生成侦察、可逆试验或外部复核。',
        blocking: true,
      );
    }
    if (request.isMajorDecision && !request.hasUserConfirmation) {
      add(
        'K0-RULE-020',
        const <String>['ST-020'],
        '重大策略尚未由用户明确决断。',
        '只展示可选方案，不进入执行。',
        blocking: true,
      );
    }
    if (request.isHighRisk &&
        request.isIrreversible &&
        request.hasHighEpistemicDebt) {
      add(
        'K0-RULE-RISK',
        const <String>['AC-006'],
        '不可逆高风险决策且认识债务高。',
        '冻结推进型 AI 协助，转为安全、补证与专业复核。',
        blocking: true,
      );
    }
    if (request.realityResultMissing) {
      add(
        'K0-RULE-REALITY',
        const <String>['PS-010', 'LG-005'],
        '尚无现实结果，不能宣布问题解决或战役胜利。',
        '收集 3-5 项可观察事实并对账事前预测。',
        blocking: true,
      );
    }

    final frozen = hits.any((hit) => hit.blocking) &&
        request.isHighRisk &&
        request.isIrreversible;
    final alert = frozen
        ? XiangjiAlertState.red
        : hits.any((hit) => hit.blocking)
            ? XiangjiAlertState.yellow
            : XiangjiAlertState.green;
    return XiangjiRulePreflightResult(
      hits: hits,
      alertState: alert,
      executionFrozen: frozen,
    );
  }
}

class XiangjiCertaintyLanguage {
  const XiangjiCertaintyLanguage();

  static final RegExp _absolute = RegExp(
    r'(肯定|必然|已经证明|毫无疑问|一定|永远|所有|唯一)',
  );

  bool containsAbsoluteClaim(String value) => _absolute.hasMatch(value);

  String discipline(String value, XiangjiClaimState state) {
    if (state == XiangjiClaimState.grounded ||
        !containsAbsoluteClaim(value)) {
      return value;
    }
    final cleaned = value
        .replaceAll('已经证明', '当前材料暂时支持')
        .replaceAll('毫无疑问', '按现有材料')
        .replaceAll('肯定', '较可能')
        .replaceAll('必然', '在当前前提成立时可能')
        .replaceAll('一定', '可能')
        .replaceAll('永远', '在已观察范围内多次')
        .replaceAll('所有', '目前观察到的部分')
        .replaceAll('唯一', '当前候选之一');
    return '$cleaned（认识状态：${state.label}；仍需核查关键前提）';
  }
}

class XiangjiMonitorInput {
  const XiangjiMonitorInput({
    this.criticalUnknownCount = 0,
    this.consecutivePredictionMisses = 0,
    this.investmentRisingWithoutResultCycles = 0,
    this.parallelHighLoadCampaigns = 0,
    this.highRiskIrreversible = false,
    this.highEpistemicDebt = false,
    this.opportunityConditionsMet = 0,
    this.opportunityConditionTotal = 0,
    this.conceptRealityConflicts = 0,
    this.strategyResourceDriftCount = 0,
  });

  final int criticalUnknownCount;
  final int consecutivePredictionMisses;
  final int investmentRisingWithoutResultCycles;
  final int parallelHighLoadCampaigns;
  final bool highRiskIrreversible;
  final bool highEpistemicDebt;
  final int opportunityConditionsMet;
  final int opportunityConditionTotal;
  final int conceptRealityConflicts;
  final int strategyResourceDriftCount;
}

class XiangjiMonitorResult {
  const XiangjiMonitorResult(this.state, this.reason, this.defaultAction);

  final XiangjiAlertState state;
  final String reason;
  final String defaultAction;
}

class XiangjiMonitorEngine {
  const XiangjiMonitorEngine();

  XiangjiMonitorResult evaluate(XiangjiMonitorInput input) {
    if (input.highRiskIrreversible && input.highEpistemicDebt) {
      return const XiangjiMonitorResult(
        XiangjiAlertState.red,
        '不可逆高风险与关键认识债务同时存在',
        '冻结推进型协助，先补证并在需要时寻求专业复核',
      );
    }
    if (input.consecutivePredictionMisses >= 2 ||
        input.investmentRisingWithoutResultCycles >= 2 ||
        input.parallelHighLoadCampaigns >= 3 ||
        input.conceptRealityConflicts >= 2 ||
        input.strategyResourceDriftCount >= 2) {
      return const XiangjiMonitorResult(
        XiangjiAlertState.orange,
        '预测-现实持续冲突、投入无效或战线过多',
        '暂停加码，进入红队与战略复核',
      );
    }
    if (input.opportunityConditionTotal > 0 &&
        input.opportunityConditionsMet >= input.opportunityConditionTotal) {
      return const XiangjiMonitorResult(
        XiangjiAlertState.blue,
        '预设机会条件已满足',
        '快速军议，评估是否集中兵力',
      );
    }
    if (input.criticalUnknownCount > 0) {
      return const XiangjiMonitorResult(
        XiangjiAlertState.yellow,
        '存在足以改变决定的关键未知',
        '开始侦察或补充证据',
      );
    }
    if (input.conceptRealityConflicts > 0 ||
        input.strategyResourceDriftCount > 0) {
      return const XiangjiMonitorResult(
        XiangjiAlertState.yellow,
        '出现概念-现实或资源-战略不一致，尚未达到连续偏航门槛',
        '保持当前行动可逆，并在下一复核点核对模型与主战线',
      );
    }
    return const XiangjiMonitorResult(
      XiangjiAlertState.green,
      '当前现实与概念/战略基本一致',
      '继续当前关键行动',
    );
  }
}
