import 'dart:math' as math;

import 'zhixing_models.dart';

class ZxSafetyGate {
  const ZxSafetyGate();

  static const List<String> _acuteRiskTerms = <String>[
    '自杀',
    '自伤',
    '伤害别人',
    '杀人',
    '不想活',
    '活不下去',
    '立即报复',
    '失控伤人',
  ];

  static const List<String> _professionalTerms = <String>[
    '停药',
    '换药',
    '加药',
    '诊断疾病',
    '法律诉讼',
    '投资全部',
    '借高利贷',
    '创伤暴露',
  ];

  ZxSafetyDecision evaluate(ZxSituationInput input) {
    final allText = <String>[
      input.goalTitle,
      input.recentEvent,
      input.targetBehavior,
      input.thought,
      input.emotion,
      input.urge,
      input.previousAttempts,
    ].join(' ');
    final acuteKeyword =
        _acuteRiskTerms.any((term) => allText.contains(term));
    final professionalKeyword =
        _professionalTerms.any((term) => allText.contains(term));

    if (input.acuteDanger || input.severeFunctionLoss || acuteKeyword) {
      return const ZxSafetyDecision(
        risk: ZxRiskLevel.r4,
        actionAllowed: false,
        requiresSecondConfirmation: false,
        maximumDifficulty: ZxDifficulty.l0,
        suggestedStage: ZxStage.s0,
        reasons: <String>[
          '当前信息提示即时安全或严重功能风险。',
          '普通成长任务可能延误必要的现实支持。',
        ],
        safeNextStep:
            '先停止普通挑战，联系当地紧急服务、合格专业人员，或立即请可信赖的人陪伴并协助获得现实支持。',
      );
    }

    if (input.professionalDecision || professionalKeyword) {
      return const ZxSafetyDecision(
        risk: ZxRiskLevel.r3,
        actionAllowed: false,
        requiresSecondConfirmation: false,
        maximumDifficulty: ZxDifficulty.l0,
        suggestedStage: ZxStage.s0,
        reasons: <String>[
          '该决定涉及医疗、药物、法律、重大财务或其他专业判断。',
          '本系统只能协助准备事实、问题和求助路径，不能给执行指令。',
        ],
        safeNextStep: '先整理事实、风险和想咨询的问题，再联系相应的合格专业人员。',
      );
    }

    if (input.thirdPartyImpact || input.irreversibleImpact) {
      return const ZxSafetyDecision(
        risk: ZxRiskLevel.r2,
        actionAllowed: true,
        requiresSecondConfirmation: true,
        maximumDifficulty: ZxDifficulty.l3,
        suggestedStage: ZxStage.s4,
        reasons: <String>[
          '行动可能影响第三方权益，或包含难以撤销的后果。',
          '需要延迟确认、受影响者检查和清楚停止条件。',
        ],
        safeNextStep: '先完成影响者、同意、可逆性和退出路径检查，再决定是否执行。',
      );
    }

    if (input.capacity < 0.35 ||
        input.availableMinutes <= 2 ||
        input.bodyCapacity < 0.25) {
      return const ZxSafetyDecision(
        risk: ZxRiskLevel.r1,
        actionAllowed: true,
        requiresSecondConfirmation: false,
        maximumDifficulty: ZxDifficulty.l1,
        suggestedStage: ZxStage.s0,
        reasons: <String>[
          '当前身体、注意、睡眠或可用时间不足。',
          '容量门槛要求先恢复、求助、减负或使用L0/L1行动。',
        ],
        safeNextStep: '选择一个30秒至5分钟、可随时停止的恢复或求助动作。',
      );
    }

    if (input.availableMinutes < 30 || input.capacity < 0.6) {
      return const ZxSafetyDecision(
        risk: ZxRiskLevel.r1,
        actionAllowed: true,
        requiresSecondConfirmation: false,
        maximumDifficulty: ZxDifficulty.l2,
        suggestedStage: ZxStage.s1,
        reasons: <String>['行动可撤销，但需要把负荷控制在当前时间和容量内。'],
        safeNextStep: '从最小或标准档开始，并保留明确停止条件。',
      );
    }

    return const ZxSafetyDecision(
      risk: ZxRiskLevel.r0,
      actionAllowed: true,
      requiresSecondConfirmation: false,
      maximumDifficulty: ZxDifficulty.l3,
      suggestedStage: ZxStage.s2,
      reasons: <String>['当前未发现需要阻断普通低风险行动的硬门槛。'],
      safeNextStep: '继续进行情境化障碍诊断，并从可逆行动开始。',
    );
  }
}

class ZxBehaviourDiagnoser {
  final ZxSafetyGate safetyGate;

  const ZxBehaviourDiagnoser({
    this.safetyGate = const ZxSafetyGate(),
  });

  ZxDiagnosisResult diagnose(ZxSituationInput input) {
    final safety = safetyGate.evaluate(input);
    final raw = <ZxBarrier, _HypothesisDraft>{
      ZxBarrier.physicalCapability: _HypothesisDraft(),
      ZxBarrier.psychologicalCapability: _HypothesisDraft(),
      ZxBarrier.physicalOpportunity: _HypothesisDraft(),
      ZxBarrier.socialOpportunity: _HypothesisDraft(),
      ZxBarrier.reflectiveMotivation: _HypothesisDraft(),
      ZxBarrier.automaticMotivation: _HypothesisDraft(),
      ZxBarrier.valueEthics: _HypothesisDraft(),
      ZxBarrier.selfEfficacy: _HypothesisDraft(),
      ZxBarrier.capacity: _HypothesisDraft(),
    };

    void add(ZxBarrier barrier, double score, String evidence) {
      raw[barrier]!.score += score;
      raw[barrier]!.evidence.add(evidence);
    }

    void counter(ZxBarrier barrier, String evidence) {
      raw[barrier]!.counterEvidence.add(evidence);
    }

    final capacityGap =
        (1 - input.capacity).clamp(0.0, 1.0).toDouble();
    add(
      ZxBarrier.capacity,
      capacityGap * 1.4,
      '身体、注意与睡眠综合容量为${(input.capacity * 100).round()}%。',
    );
    add(
      ZxBarrier.physicalCapability,
      (1 - input.bodyCapacity).clamp(0.0, 1.0).toDouble(),
      '身体容量为${(input.bodyCapacity * 100).round()}%。',
    );

    if (!input.knowsHow) {
      add(
        ZxBarrier.psychologicalCapability,
        1.25,
        '用户尚不清楚怎样完成目标行为或缺少必要子技能。',
      );
    } else {
      counter(ZxBarrier.psychologicalCapability, '用户报告基本知道怎样做。');
    }

    if (!input.hasTime) {
      add(ZxBarrier.physicalOpportunity, 1.35, '当前没有稳定可用时间。');
    } else {
      counter(ZxBarrier.physicalOpportunity, '用户报告存在可用时间。');
    }
    if (!input.hasTools) {
      add(ZxBarrier.physicalOpportunity, 1.15, '完成行为所需工具或空间尚未就位。');
    }
    if (input.availableMinutes <= 5) {
      add(
        ZxBarrier.physicalOpportunity,
        0.45,
        '当前可用时间只有${input.availableMinutes}分钟。',
      );
    }

    if (!input.hasSupport) {
      add(ZxBarrier.socialOpportunity, 1.0, '缺少协作者、支持或角色接口。');
    } else {
      counter(ZxBarrier.socialOpportunity, '用户报告存在可用支持。');
    }
    if (input.thirdPartyImpact) {
      add(
        ZxBarrier.socialOpportunity,
        0.6,
        '行动影响第三方，需要同意、协商或角色澄清。',
      );
    }

    if (input.autonomy < 0.45) {
      add(
        ZxBarrier.reflectiveMotivation,
        (0.55 - input.autonomy) * 2.2 + 0.45,
        '目标自主度仅为${(input.autonomy * 100).round()}%，可能主要由外控或内摄推动。',
      );
    } else {
      counter(ZxBarrier.reflectiveMotivation, '用户对目标有一定自主认领。');
    }
    if (input.importance < 0.45 || input.valueReason.trim().isEmpty) {
      add(
        ZxBarrier.reflectiveMotivation,
        0.65,
        '重要性或价值理由尚不清楚。',
      );
    }
    if (input.positiveFantasy) {
      add(
        ZxBarrier.reflectiveMotivation,
        0.8,
        '用户报告较多成功想象，但现实障碍和可行性尚未完成心理对照。',
      );
    }

    if (input.waitingForMood) {
      add(
        ZxBarrier.automaticMotivation,
        1.2,
        '行动被设置为“先有状态/先消除不适”的条件。',
      );
    }
    if (input.emotion.trim().isNotEmpty || input.urge.trim().isNotEmpty) {
      add(
        ZxBarrier.automaticMotivation,
        0.45,
        '最近事件包含明显情绪或行动冲动，需要现场功能分析。',
      );
    }
    final avoidanceText =
        '${input.actualAction} ${input.previousAttempts} ${input.urge}';
    if (RegExp(r'刷|逃|拖|回避|躺|不敢|等状态|放弃').hasMatch(avoidanceText)) {
      add(
        ZxBarrier.automaticMotivation,
        0.85,
        '既往反应提示短期回避可能在现场占优。',
      );
    }

    if (input.ethicalConflict) {
      add(
        ZxBarrier.valueEthics,
        1.45,
        '用户明确报告价值、责任或第三方权益冲突。',
      );
    }
    if (input.valueReason.trim().isEmpty) {
      add(ZxBarrier.valueEthics, 0.3, '目标尚未说明服务谁、为何值得。');
    }

    if (input.selfEfficacy < 0.55) {
      add(
        ZxBarrier.selfEfficacy,
        (0.65 - input.selfEfficacy)
                .clamp(0.0, 1.0)
                .toDouble() *
            1.7 +
            0.3,
        '对此具体任务的成功把握为${(input.selfEfficacy * 100).round()}%。',
      );
    } else {
      counter(ZxBarrier.selfEfficacy, '用户对此任务已有中等以上把握。');
    }
    if (RegExp(r'我就是|肯定不行|做不到|没能力|坚持不了')
        .hasMatch(input.thought)) {
      add(
        ZxBarrier.selfEfficacy,
        0.75,
        '想法把具体失败泛化为稳定无能力判断。',
      );
    }

    final maximum = raw.values
        .map((item) => item.score)
        .fold<double>(0.01, (a, b) => math.max(a, b).toDouble());
    final hypotheses = raw.entries
        .map(
          (entry) => ZxBarrierHypothesis(
            barrier: entry.key,
            score: (entry.value.score / maximum)
                .clamp(0.0, 1.0)
                .toDouble(),
            confidence: _confidence(
              evidenceCount: entry.value.evidence.length,
              counterEvidenceCount: entry.value.counterEvidence.length,
              normalizedScore:
                  (entry.value.score / maximum)
                      .clamp(0.0, 1.0)
                      .toDouble(),
            ),
            evidence: entry.value.evidence.isEmpty
                ? <String>['当前没有足够证据支持该假设。']
                : entry.value.evidence,
            counterEvidence: entry.value.counterEvidence,
          ),
        )
        .where((item) => item.score >= 0.18)
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    final selected = hypotheses.take(3).toList(growable: false);
    final stage = _stageFor(input, safety, selected);
    final difficulty = _difficultyFor(input, safety, stage);
    final evidenceCount =
        selected.fold<int>(0, (sum, item) => sum + item.evidence.length);
    final confidence =
        (0.35 + evidenceCount * 0.06 + input.recentEvent.trim().length / 600)
            .clamp(0.35, 0.88);

    return ZxDiagnosisResult(
      safety: safety,
      targetBehavior: input.targetBehavior.trim(),
      hypotheses: selected,
      stage: stage,
      suggestedDifficulty: difficulty,
      overallConfidence: confidence.toDouble(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static double _confidence({
    required int evidenceCount,
    required int counterEvidenceCount,
    required double normalizedScore,
  }) {
    final evidenceTerm = math.min(0.28, evidenceCount * 0.09);
    final counterPenalty = math.min(0.16, counterEvidenceCount * 0.05);
    return (0.32 + normalizedScore * 0.42 + evidenceTerm - counterPenalty)
        .clamp(0.2, 0.92)
        .toDouble();
  }

  static ZxStage _stageFor(
    ZxSituationInput input,
    ZxSafetyDecision safety,
    List<ZxBarrierHypothesis> hypotheses,
  ) {
    if (safety.risk == ZxRiskLevel.r3 ||
        safety.risk == ZxRiskLevel.r4 ||
        input.capacity < 0.35) {
      return ZxStage.s0;
    }
    final primary = hypotheses.isEmpty ? null : hypotheses.first.barrier;
    if (primary == ZxBarrier.valueEthics && input.selfEfficacy >= 0.65) {
      return ZxStage.s4;
    }
    if (input.selfEfficacy < 0.4 ||
        primary == ZxBarrier.automaticMotivation ||
        primary == ZxBarrier.capacity) {
      return ZxStage.s1;
    }
    if (!input.knowsHow ||
        primary == ZxBarrier.psychologicalCapability ||
        primary == ZxBarrier.selfEfficacy) {
      return ZxStage.s2;
    }
    if (input.previousAttempts.trim().isNotEmpty) return ZxStage.s3;
    return safety.suggestedStage;
  }

  static ZxDifficulty _difficultyFor(
    ZxSituationInput input,
    ZxSafetyDecision safety,
    ZxStage stage,
  ) {
    final proposed = switch (stage) {
      ZxStage.s0 => ZxDifficulty.l0,
      ZxStage.s1 => ZxDifficulty.l1,
      ZxStage.s2 => input.availableMinutes >= 10
          ? ZxDifficulty.l2
          : ZxDifficulty.l1,
      ZxStage.s3 => input.availableMinutes >= 30
          ? ZxDifficulty.l3
          : ZxDifficulty.l2,
      ZxStage.s4 || ZxStage.s5 => input.availableMinutes >= 30
          ? ZxDifficulty.l3
          : ZxDifficulty.l2,
    };
    return _minDifficulty(proposed, safety.maximumDifficulty);
  }
}

class ZxThinkerMatcher {
  const ZxThinkerMatcher();

  ZxMatchResult match({
    required ZxSituationInput input,
    required ZxDiagnosisResult diagnosis,
    required List<ZxThinkerLens> lenses,
    Map<String, double> historicalResponse = const <String, double>{},
    Set<String> disabledLensIds = const <String>{},
  }) {
    if (lenses.isEmpty) {
      throw ArgumentError.value(lenses, 'lenses', 'Knowledge lenses are empty.');
    }
    final scores = <ZxFitScore>[];
    for (final lens in lenses) {
      scores.add(
        _scoreLens(
          input: input,
          diagnosis: diagnosis,
          lens: lens,
          history: historicalResponse[lens.id] ?? 0.5,
          disabled: disabledLensIds.contains(lens.id),
        ),
      );
    }
    scores.sort((a, b) => b.total.compareTo(a.total));
    final available = scores.where((item) => !item.disqualified).toList();
    final firstScore = available.isEmpty ? scores.first : available.first;
    final primary = lenses.firstWhere(
      (lens) => lens.id == firstScore.lensId,
      orElse: () => lenses.first,
    );
    final complementScore = _chooseComplement(
      primary: primary,
      ranking: available.skip(1),
      lenses: lenses,
      diagnosis: diagnosis,
    );
    final complementary = complementScore == null
        ? null
        : lenses.firstWhere(
            (lens) => lens.id == complementScore.lensId,
            orElse: () => primary,
          );

    final secondScore = available.length > 1 ? available[1] : null;
    final closeCompetition = secondScore != null &&
        (firstScore.total - secondScore.total).abs() < 0.08 &&
        _differentDirection(primary, lenses.firstWhere(
          (lens) => lens.id == secondScore.lensId,
          orElse: () => primary,
        ));
    final missingPrerequisite = !diagnosis.safety.actionAllowed;
    final lowMatch =
        firstScore.total < 0.55 || closeCompetition || missingPrerequisite;
    final reason = missingPrerequisite
        ? '安全或专业判断硬门槛使现有低风险思想动作均不适用。'
        : firstScore.total < 0.55
            ? '最高匹配低于0.55，可能是信息不足、目标未定义、文化/知识缺口或现有理论不足。'
            : closeCompetition
                ? '前两名差距小于0.08且解释方向不同，需要用户改选或用现实行动求证。'
                : '';

    final uncertainty =
        (1 - (diagnosis.overallConfidence * 0.55 + firstScore.total * 0.45))
            .clamp(0.05, 0.85)
            .toDouble();
    return ZxMatchResult(
      primary: primary,
      complementary: complementary == primary ? null : complementary,
      ranking: scores,
      lowMatch: lowMatch,
      lowMatchReason: reason,
      uncertainty: uncertainty,
      conflictNotes: <String>[
        ...primary.tensionLinks,
        if (complementary != null) ...complementary.tensionLinks.take(1),
      ].toSet().take(3).toList(growable: false),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  ZxFitScore _scoreLens({
    required ZxSituationInput input,
    required ZxDiagnosisResult diagnosis,
    required ZxThinkerLens lens,
    required double history,
    required bool disabled,
  }) {
    final primaryBarrier = diagnosis.primary.barrier;
    final secondaryBarriers =
        diagnosis.hypotheses.skip(1).map((item) => item.barrier).toSet();
    final barrierMatch = lens.barriers.contains(primaryBarrier)
        ? 1.0
        : lens.barriers.any(secondaryBarriers.contains)
            ? 0.72
            : 0.25;
    final stageMatch = lens.stages.contains(diagnosis.stage)
        ? 1.0
        : lens.stages.any(
            (stage) => (stage.index - diagnosis.stage.index).abs() == 1,
          )
            ? 0.65
            : 0.2;
    final methodCompatibility = _methodCompatibility(input, diagnosis, lens);
    final valueMeaningCompatibility =
        _valueMeaningCompatibility(input, diagnosis, lens);
    final evidenceDirectness =
        lens.evidenceDirectness.clamp(0.0, 1.0).toDouble();
    final capacityCompatibility =
        _capacityCompatibility(input, diagnosis, lens);
    final historyResponse = history.clamp(0.0, 1.0).toDouble();

    var conflictPenalty = 0.0;
    if (input.capacity < 0.35 &&
        lens.stages.every((stage) => stage.index >= ZxStage.s2.index)) {
      conflictPenalty += 0.18;
    }
    if (!input.hasTime &&
        !lens.barriers.contains(ZxBarrier.physicalOpportunity) &&
        lens.barriers.contains(ZxBarrier.reflectiveMotivation)) {
      conflictPenalty += 0.12;
    }
    if (input.ethicalConflict &&
        !lens.barriers.contains(ZxBarrier.valueEthics)) {
      conflictPenalty += 0.08;
    }

    var safetyPenalty = 0.0;
    var disqualified = disabled || lens.reviewStatus.startsWith('rejected');
    if (!diagnosis.safety.actionAllowed) {
      safetyPenalty = 0.5;
    }
    if (diagnosis.safety.risk.index >= ZxRiskLevel.r3.index &&
        lens.id != 'BCW_COMB' &&
        lens.id != 'MMP_CAPACITY') {
      disqualified = true;
    }

    final components = <String, double>{
      '障碍匹配': barrierMatch,
      '阶段匹配': stageMatch,
      '方法相容': methodCompatibility,
      '价值/意义相容': valueMeaningCompatibility,
      '证据直接性': evidenceDirectness,
      '容量相容': capacityCompatibility,
      '历史反应': historyResponse,
    };
    final weighted = 0.30 * barrierMatch +
        0.18 * stageMatch +
        0.14 * methodCompatibility +
        0.12 * valueMeaningCompatibility +
        0.10 * evidenceDirectness +
        0.08 * capacityCompatibility +
        0.08 * historyResponse;
    final total = disqualified
        ? 0.0
        : (weighted - conflictPenalty - safetyPenalty).clamp(0, 1);
    final reasons = <String>[
      if (barrierMatch >= 0.9) '直接覆盖首要障碍“${primaryBarrier.label}”。',
      if (stageMatch >= 0.9) '适用于当前${diagnosis.stage.label}阶段。',
      if (methodCompatibility >= 0.75) '方法与当前情境和用户输入相容。',
      if (evidenceDirectness >= 0.75) '对相近行为机制具有较直接证据。',
      if (conflictPenalty > 0) '存在前提或盲点，已施加冲突惩罚。',
      if (safetyPenalty > 0) '安全门槛限制了自动建议。',
      if (disabled) '用户已禁用该思想镜头。',
    ];
    return ZxFitScore(
      lensId: lens.id,
      components: components,
      conflictPenalty: conflictPenalty,
      safetyPenalty: safetyPenalty,
      total: total.toDouble(),
      disqualified: disqualified,
      reasons: reasons,
    );
  }

  static double _methodCompatibility(
    ZxSituationInput input,
    ZxDiagnosisResult diagnosis,
    ZxThinkerLens lens,
  ) {
    final methods = lens.methods.join(' ');
    if (input.waitingForMood &&
        (methods.contains('接纳') ||
            methods.contains('行为') ||
            methods.contains('分级'))) {
      return 0.95;
    }
    if (!input.knowsHow &&
        (methods.contains('子技能') ||
            methods.contains('示范') ||
            methods.contains('演练'))) {
      return 0.95;
    }
    if ((!input.hasTime || !input.hasTools) &&
        (methods.contains('环境') || methods.contains('COM-B'))) {
      return 0.95;
    }
    if (input.positiveFantasy &&
        (methods.contains('心理对照') || methods.contains('WOOP'))) {
      return 1.0;
    }
    if (diagnosis.primary.barrier == ZxBarrier.valueEthics &&
        (methods.contains('价值') ||
            methods.contains('意义') ||
            methods.contains('责任') ||
            methods.contains('谱系'))) {
      return 0.92;
    }
    return lens.barriers.contains(diagnosis.primary.barrier) ? 0.76 : 0.52;
  }

  static double _valueMeaningCompatibility(
    ZxSituationInput input,
    ZxDiagnosisResult diagnosis,
    ZxThinkerLens lens,
  ) {
    if (input.valueReason.trim().isNotEmpty &&
        (lens.methods.join(' ').contains('价值') ||
            lens.methods.join(' ').contains('意义') ||
            lens.id == 'WY_KNOW_ACT')) {
      return 0.9;
    }
    if (diagnosis.primary.barrier == ZxBarrier.valueEthics) {
      return lens.barriers.contains(ZxBarrier.valueEthics) ? 0.95 : 0.35;
    }
    return 0.65;
  }

  static double _capacityCompatibility(
    ZxSituationInput input,
    ZxDiagnosisResult diagnosis,
    ZxThinkerLens lens,
  ) {
    if (input.capacity < 0.4) {
      if (lens.stages.contains(ZxStage.s0) ||
          lens.barriers.contains(ZxBarrier.capacity)) {
        return 1.0;
      }
      return 0.25;
    }
    if (lens.difficulties.contains(diagnosis.suggestedDifficulty)) return 0.9;
    return 0.55;
  }

  static ZxFitScore? _chooseComplement({
    required ZxThinkerLens primary,
    required Iterable<ZxFitScore> ranking,
    required List<ZxThinkerLens> lenses,
    required ZxDiagnosisResult diagnosis,
  }) {
    final secondary = diagnosis.hypotheses.length > 1
        ? diagnosis.hypotheses[1].barrier
        : null;
    for (final score in ranking) {
      if (score.disqualified || score.total < 0.4) continue;
      final lens = lenses.firstWhere(
        (item) => item.id == score.lensId,
        orElse: () => primary,
      );
      if (lens.id == primary.id) continue;
      if (secondary != null && lens.barriers.contains(secondary)) return score;
      if (lens.sourceId != primary.sourceId &&
          !lens.barriers.toSet().containsAll(primary.barriers)) {
        return score;
      }
    }
    return null;
  }

  static bool _differentDirection(
    ZxThinkerLens first,
    ZxThinkerLens second,
  ) {
    final shared = first.barriers.toSet().intersection(second.barriers.toSet());
    final firstMethods = first.methods.toSet();
    final methodShared = firstMethods.intersection(second.methods.toSet());
    return shared.isEmpty || methodShared.isEmpty;
  }
}

class ZxActionGenerator {
  const ZxActionGenerator();

  ZxActionPrescription? generate({
    required ZxSituationInput input,
    required ZxDiagnosisResult diagnosis,
    required ZxMatchResult match,
    ZxDifficulty? selectedDifficulty,
  }) {
    if (!diagnosis.safety.actionAllowed) return null;
    final difficulty = _minDifficulty(
      selectedDifficulty ?? diagnosis.suggestedDifficulty,
      diagnosis.safety.maximumDifficulty,
    );
    final barrier = diagnosis.primary.barrier;
    final action = _actionFor(input, barrier, difficulty);
    final lower = _lowerActionFor(input, barrier);
    final challenge = _challengeActionFor(input, barrier, difficulty);
    final cue = input.cue.trim().isEmpty
        ? '当我下一次进入“${input.goalTitle.trim()}”的现实情境时'
        : input.cue.trim();
    final support = _supportFor(input, barrier);
    final stop = _stopConditions(input, diagnosis);
    final proof = <ZxProofType>[
      ZxProofType.selfReport,
      if (barrier != ZxBarrier.valueEthics) ZxProofType.processTrace,
      if (barrier == ZxBarrier.valueEthics) ZxProofType.learning,
    ];
    final locators = <String>[
      ...match.primary.evidenceLinks.take(2),
      if (match.complementary != null)
        ...match.complementary!.evidenceLinks.take(1),
    ].toSet().toList(growable: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = ZxActionPrescription(
      id: 'zx_${now}_${barrier.key}',
      goalId: input.goalId,
      goalTitle: input.goalTitle.trim(),
      targetBehavior: input.targetBehavior.trim(),
      primaryLensId: match.primary.id,
      complementaryLensId: match.complementary?.id ?? '',
      primaryBarrier: barrier,
      stage: diagnosis.stage,
      difficulty: difficulty,
      risk: diagnosis.safety.risk,
      thoughtLens: match.primary.mechanism,
      mainAction: action,
      lowerLoadAlternative: lower,
      challengeAlternative: challenge,
      cue: cue,
      response: action,
      supportChanges: support,
      stopConditions: stop,
      proofOptions: proof,
      completionDefinition: _completionDefinition(barrier, action),
      reviewQuestion: '事实发生了什么？“${barrier.label}”这一假设被支持还是被反驳？',
      evidenceLocators: locators,
      uncertainty: match.uncertainty,
      status: ZxActionStatus.proposed,
      createdAtMs: now,
      updatedAtMs: now,
    );
    final issues = validate(item);
    if (issues.isNotEmpty) {
      throw StateError('Generated action did not pass quality validation: $issues');
    }
    return item;
  }

  List<String> validate(ZxActionPrescription item) {
    final issues = <String>[];
    if (item.mainAction.trim().isEmpty) issues.add('主动作为空');
    if (item.targetBehavior.trim().isEmpty) issues.add('目标行为为空');
    if (item.stopConditions.isEmpty) issues.add('缺少停止条件');
    if (item.proofOptions.isEmpty) issues.add('缺少完成证明');
    if (item.completionDefinition.trim().isEmpty) issues.add('缺少完成定义');
    if (item.reviewQuestion.trim().isEmpty) issues.add('缺少复盘问题');
    if (item.evidenceLocators.isEmpty) issues.add('缺少证据定位');
    if (item.risk.index >= ZxRiskLevel.r3.index) {
      issues.add('R3/R4不得生成普通执行动作');
    }
    if (RegExp(r'保证|一定成功|让对方|治愈|必须坚持到底').hasMatch(item.mainAction)) {
      issues.add('动作包含不可控结果或绝对化要求');
    }
    return issues;
  }

  static String _actionFor(
    ZxSituationInput input,
    ZxBarrier barrier,
    ZxDifficulty difficulty,
  ) {
    final target = input.targetBehavior.trim();
    final minutes = _minutesFor(difficulty, input.availableMinutes);
    return switch (barrier) {
      ZxBarrier.physicalCapability =>
        '先做$minutes分钟无痛、可停止的“$target”准备或最轻步骤，并记录身体反应。',
      ZxBarrier.psychologicalCapability =>
        '只练“$target”所需的第一个子技能$minutes分钟；先看一个近似示范，再自己做一次。',
      ZxBarrier.physicalOpportunity =>
        '用$minutes分钟把“$target”的时间、工具和入口准备到位；本轮完成标准只是让下一次可以直接开始。',
      ZxBarrier.socialOpportunity =>
        '向一位具体协作者提出一个可回答的请求：确认“$target”的时间、角色或支持接口。',
      ZxBarrier.reflectiveMotivation => input.positiveFantasy
          ? '完成一次简版WOOP：写下愿望、最佳结果、当前关键障碍；若愿望可行，再为障碍写一个如果—那么计划。'
          : '写下“$target”服务谁、体现什么价值、付出什么代价，然后选择继续、修改或退出中的一个。',
      ZxBarrier.automaticMotivation =>
        '不等待情绪消失：命名当下感受和头脑故事，然后接触“$target”的第一个可见入口$minutes分钟。',
      ZxBarrier.valueEthics =>
        '暂不推进结果；写下“$target”会让谁受益、谁承担代价、是否需要同意，以及你能负责的边界。',
      ZxBarrier.selfEfficacy =>
        '选择比现有掌握证据略高的一步，尝试“$target”中的$minutes分钟单元；行动前后各记录一次成功把握。',
      ZxBarrier.capacity =>
        '从睡眠、饮食、身体、秩序、关系或求助中选一项，完成一个$minutes分钟的恢复/支持动作。',
    };
  }

  static String _lowerActionFor(
    ZxSituationInput input,
    ZxBarrier barrier,
  ) {
    final target = input.targetBehavior.trim();
    return switch (barrier) {
      ZxBarrier.physicalCapability || ZxBarrier.capacity =>
        '只做30秒安全检查：确认身体状态、停止条件，并决定休息、求助或准备。',
      ZxBarrier.psychologicalCapability =>
        '只写出“$target”的第一个子步骤，暂不执行后续步骤。',
      ZxBarrier.physicalOpportunity =>
        '只把一个必要工具放到可见位置，或预留一个两分钟入口。',
      ZxBarrier.socialOpportunity =>
        '只写好一条具体求助信息，确认无风险后再发送。',
      ZxBarrier.reflectiveMotivation || ZxBarrier.valueEthics =>
        '只回答：如果没人评价，我是否仍愿意做“$target”？为什么？',
      ZxBarrier.automaticMotivation =>
        '只打开入口并停留30秒；允许不适存在，不要求继续。',
      ZxBarrier.selfEfficacy =>
        '只回忆并写下一条与此具体任务相近的掌握证据。',
    };
  }

  static String _challengeActionFor(
    ZxSituationInput input,
    ZxBarrier barrier,
    ZxDifficulty difficulty,
  ) {
    final target = input.targetBehavior.trim();
    if (difficulty.index >= ZxDifficulty.l3.index) {
      return '在条件充足并再次确认后，把“$target”组织成一个30至90分钟的完整反馈单位，并请一位相关者提供信息性反馈。';
    }
    return switch (barrier) {
      ZxBarrier.socialOpportunity =>
        '完成一次角色澄清对话，并把双方同意的下一接口写下来。',
      ZxBarrier.valueEthics =>
        '比较三种思想路径和长期后果，形成一页可修改的行动协议。',
      _ =>
        '在标准动作安全完成后，将同一机制迁移到第二个不同情境，并比较条件差异。',
    };
  }

  static List<String> _supportFor(
    ZxSituationInput input,
    ZxBarrier barrier,
  ) =>
      <String>[
        if (!input.hasTools) '先补齐一个必要工具，不把工具缺失解释为没动力。',
        if (!input.hasTime) '先与现实承诺协商一个可保护的时间块。',
        if (!input.hasSupport) '确定一位可提供信息、协作或陪伴的人。',
        if (barrier == ZxBarrier.automaticMotivation) '关闭一个高频干扰入口。',
        if (barrier == ZxBarrier.psychologicalCapability) '准备一个示范、清单或演练。',
        '只保留当前一个主动作，其他建议暂存。',
      ];

  static List<String> _stopConditions(
    ZxSituationInput input,
    ZxDiagnosisResult diagnosis,
  ) =>
      <String>[
        '出现疼痛明显加重、眩晕、严重睡眠不足或功能恶化时立即停止。',
        '出现自伤、他伤、急性危险或严重失控信息时退出普通任务并优先获得现实支持。',
        if (input.thirdPartyImpact)
          '未获得必要同意，或第三方权益无法保护时不得继续。',
        if (diagnosis.safety.requiresSecondConfirmation)
          '完成影响者、可逆性和延迟确认前，不进入实际执行。',
        '动作负荷超过当前容量时，降级为低负荷替代，不用逞强换取奖励。',
      ];

  static String _completionDefinition(
    ZxBarrier barrier,
    String action,
  ) =>
      barrier == ZxBarrier.valueEthics ||
              barrier == ZxBarrier.reflectiveMotivation
          ? '已作出继续、修改、延后或退出中的清楚选择，并写下一条理由。'
          : '已实际进入并完成上述可观察动作；不要求获得不可控结果。';

  static String _minutesFor(ZxDifficulty difficulty, int available) {
    final suggested = switch (difficulty) {
      ZxDifficulty.l0 => 2,
      ZxDifficulty.l1 => 5,
      ZxDifficulty.l2 => 15,
      ZxDifficulty.l3 => 45,
      ZxDifficulty.l4 => 90,
    };
    return math.max(1, math.min(suggested, math.max(1, available))).toString();
  }
}

class ZxRewardEngine {
  static const int dailyCoinCap = 60;

  const ZxRewardEngine();

  ZxRewardOutcome calculate({
    required ZxActionPrescription action,
    required ZxReviewInput review,
    required int sameActionRewardedCount,
    required int sameDifficultyCountToday,
    required int coinsEarnedToday,
  }) {
    if (action.risk.index >= ZxRiskLevel.r3.index) {
      return _zero('R3/R4行动不能通过普通成长规则获得奖励。');
    }
    if (sameDifficultyCountToday >= action.difficulty.dailyEffectiveLimit) {
      return _zero('${action.difficulty.code}已达到当日有效次数上限。');
    }

    final proofFactor = switch (review.proofType) {
      ZxProofType.selfReport => 0.8,
      ZxProofType.processTrace => 1.0,
      ZxProofType.outcomeTrace => 1.0,
      ZxProofType.collaborator => 1.1,
      ZxProofType.learning => 0.8,
    };
    final reflectionFactor = review.reflectionDepth >= 2 ? 1.15 : 1.0;
    final calibrationFactor = review.safeDowngrade
        ? 1.1
        : review.difficultyFit == '合适'
            ? 1.05
            : review.difficultyFit == '过高'
                ? 0.95
                : 0.9;
    final noveltyFactor =
        math.max(0.7, 1.0 - sameActionRewardedCount * 0.1).toDouble();

    final completed = review.completion == ZxCompletionStatus.completed ||
        review.completion == ZxCompletionStatus.safetyDowngrade ||
        review.completion == ZxCompletionStatus.exited;
    var completionCoins = completed
        ? (action.difficulty.baseCompletionCoins *
                proofFactor *
                reflectionFactor *
                calibrationFactor *
                noveltyFactor)
            .round()
        : 0;
    if (review.completion == ZxCompletionStatus.exited) {
      completionCoins = math.min(completionCoins, 5).toInt();
    }
    var learningCoins = review.learning == ZxLearningStatus.none
        ? 0
        : (action.difficulty.baseLearningCoins *
                reflectionFactor *
                noveltyFactor)
            .round();
    if (!completed && review.learning == ZxLearningStatus.strong) {
      learningCoins = math.max(1, learningCoins).toInt();
    }

    final uncapped = completionCoins + learningCoins;
    final remaining =
        math.max(0, dailyCoinCap - coinsEarnedToday).toInt();
    final awarded = math.min(uncapped, remaining).toInt();
    final capApplied = awarded < uncapped;
    if (capApplied && uncapped > 0) {
      final completionShare = completionCoins / uncapped;
      completionCoins = (awarded * completionShare).round();
      learningCoins =
          math.max(0, awarded - completionCoins).toInt();
    }
    final xp = _xpFor(
      action: action,
      completed: completed,
      learning: review.learning,
      reflectionDepth: review.reflectionDepth,
    );
    return ZxRewardOutcome(
      completionCoins: completionCoins,
      learningCoins: learningCoins,
      totalCoins: completionCoins + learningCoins,
      xp: xp,
      abilityDimension: _abilityFor(action.primaryBarrier),
      proofFactor: proofFactor,
      reflectionFactor: reflectionFactor,
      calibrationFactor: calibrationFactor,
      noveltyFactor: noveltyFactor,
      dailyCapApplied: capApplied,
      explanations: <String>[
        if (completionCoins > 0) '现实动作完成金币：$completionCoins。',
        if (learningCoins > 0) '模型更新学习金币：$learningCoins；未伪装为完成。',
        'Proof ${proofFactor.toStringAsFixed(2)} × Reflection ${reflectionFactor.toStringAsFixed(2)} × Calibration ${calibrationFactor.toStringAsFixed(2)} × Novelty ${noveltyFactor.toStringAsFixed(2)}。',
        if (review.safeDowngrade) '准确安全降级获得校准保护，不奖励逞强。',
        if (capApplied) '已应用单日$dailyCoinCap金币上限。',
      ],
    );
  }

  static double _xpFor({
    required ZxActionPrescription action,
    required bool completed,
    required ZxLearningStatus learning,
    required int reflectionDepth,
  }) {
    var xp = completed ? (action.difficulty.index + 1) * 2.0 : 0.0;
    if (learning != ZxLearningStatus.none) xp += 1.5;
    if (reflectionDepth >= 2) xp += 0.5;
    return xp;
  }

  static String _abilityFor(ZxBarrier barrier) => switch (barrier) {
        ZxBarrier.valueEthics || ZxBarrier.reflectiveMotivation => '选择力',
        ZxBarrier.automaticMotivation ||
        ZxBarrier.selfEfficacy ||
        ZxBarrier.psychologicalCapability =>
          '启动力',
        ZxBarrier.physicalCapability ||
        ZxBarrier.physicalOpportunity ||
        ZxBarrier.capacity =>
          '持续力',
        ZxBarrier.socialOpportunity => '贡献力',
      };

  static ZxRewardOutcome _zero(String reason) => ZxRewardOutcome(
        completionCoins: 0,
        learningCoins: 0,
        totalCoins: 0,
        xp: 0,
        abilityDimension: '修正力',
        proofFactor: 0,
        reflectionFactor: 0,
        calibrationFactor: 0,
        noveltyFactor: 0,
        dailyCapApplied: false,
        explanations: <String>[reason],
      );
}

class ZxTreeExchangeResult {
  final ZxTreeState state;
  final int cost;
  final String resource;
  final double appliedAmount;
  final String message;

  const ZxTreeExchangeResult({
    required this.state,
    required this.cost,
    required this.resource,
    required this.appliedAmount,
    required this.message,
  });
}

class ZxTreeEngine {
  const ZxTreeEngine();

  static const Map<String, int> prices = <String, int>{
    'water': 5,
    'sunlight': 5,
    'fertilizer': 8,
    'balanced': 15,
  };

  ZxTreeState applyReward(
    ZxTreeState state,
    ZxRewardOutcome reward, {
    required ZxStage stage,
    int? nowMs,
  }) {
    final xp = Map<String, double>.from(state.abilityXp);
    xp[reward.abilityDimension] =
        (xp[reward.abilityDimension] ?? 0) + reward.xp;
    if (reward.totalCoins > 0 || reward.xp > 0) {
      xp['修正力'] = (xp['修正力'] ?? 0) +
          (reward.learningCoins > 0 ? 0.5 : 0);
    }
    final recoveryProtection =
        stage == ZxStage.s0 || stage == ZxStage.s1 ? 0.9 : 1.0;
    final growthDelta =
        reward.xp * state.balanceFactor * recoveryProtection;
    final updated = state.copyWith(
      coins: state.coins + reward.totalCoins,
      growth: state.growth + growthDelta,
      abilityXp: xp,
      lastActivityMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      dormant: false,
      mode: 'normal',
    );
    return updated.copyWith(stage: _treeStage(updated));
  }

  ZxTreeExchangeResult exchange(ZxTreeState state, String resource) {
    final cost = prices[resource];
    if (cost == null) {
      return ZxTreeExchangeResult(
        state: state,
        cost: 0,
        resource: resource,
        appliedAmount: 0,
        message: '未知资源。',
      );
    }
    if (state.coins < cost) {
      return ZxTreeExchangeResult(
        state: state,
        cost: cost,
        resource: resource,
        appliedAmount: 0,
        message: '金币不足；能力和晋级不能用金币购买。',
      );
    }
    if (resource == 'balanced' &&
        (state.water >= 70 ||
            state.sunlight >= 70 ||
            state.fertilizer >= 70)) {
      return ZxTreeExchangeResult(
        state: state,
        cost: cost,
        resource: resource,
        appliedAmount: 0,
        message: '平衡礼包只在三项资源都低于70时开放。',
      );
    }
    double add(double current, double requested) {
      final effective = current >= 80 ? requested * 0.5 : requested;
      return math.min(100, current + effective).toDouble();
    }

    var water = state.water;
    var sunlight = state.sunlight;
    var fertilizer = state.fertilizer;
    var amount = 0.0;
    switch (resource) {
      case 'water':
        final next = add(water, 12);
        amount = next - water;
        water = next;
        break;
      case 'sunlight':
        final next = add(sunlight, 12);
        amount = next - sunlight;
        sunlight = next;
        break;
      case 'fertilizer':
        final next = add(fertilizer, 10);
        amount = next - fertilizer;
        fertilizer = next;
        break;
      case 'balanced':
        final nextW = add(water, 8);
        final nextS = add(sunlight, 8);
        final nextF = add(fertilizer, 8);
        amount = (nextW - water) + (nextS - sunlight) + (nextF - fertilizer);
        water = nextW;
        sunlight = nextS;
        fertilizer = nextF;
        break;
    }
    final updated = state.copyWith(
      coins: state.coins - cost,
      water: water,
      sunlight: sunlight,
      fertilizer: fertilizer,
      dormant: false,
      mode: 'normal',
    );
    return ZxTreeExchangeResult(
      state: updated,
      cost: cost,
      resource: resource,
      appliedAmount: amount,
      message: '兑换成功。资源只改变树的状态，不购买能力XP。',
    );
  }

  ZxTreeState refreshTemporalState(
    ZxTreeState state, {
    int? nowMs,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    var lowSince = state.lowVitalitySinceMs;
    var dormant = state.dormant;
    var mode = state.mode;
    if (state.vitality < 30) {
      lowSince = lowSince == 0 ? now : lowSince;
      if (now - lowSince >= const Duration(days: 7).inMilliseconds) {
        mode = 'withered';
      }
    } else {
      lowSince = 0;
      if (!dormant) mode = 'normal';
    }
    if (state.lastActivityMs > 0 &&
        now - state.lastActivityMs >=
            const Duration(days: 14).inMilliseconds) {
      dormant = true;
      mode = 'dormant';
    }
    return state.copyWith(
      lowVitalitySinceMs: lowSince,
      dormant: dormant,
      mode: mode,
    );
  }

  ZxTreeState revive(ZxTreeState state, {int? nowMs}) => state.copyWith(
        dormant: false,
        mode: 'normal',
        water: math.max(20, state.water).toDouble(),
        lastActivityMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
      );

  static String _treeStage(ZxTreeState state) {
    final abilities = state.abilityXp.values.where((value) => value >= 10).length;
    if (state.growth >= 320 &&
        (state.abilityXp['贡献力'] ?? 0) >= 40) {
      return 'towering';
    }
    if (state.growth >= 160 &&
        (state.abilityXp['修正力'] ?? 0) >= 25) {
      return 'canopy';
    }
    if (state.growth >= 60 && abilities >= 2) return 'branching';
    if (abilities >= 2) return 'young';
    if (state.growth > 0) return 'sapling';
    return 'seed';
  }
}

class ZxChallengeFactory {
  const ZxChallengeFactory();

  List<ZxChallenge> buildAll() {
    final result = <ZxChallenge>[];
    for (final seed in _seeds) {
      for (final difficulty in ZxDifficulty.values) {
        final stage = switch (difficulty) {
          ZxDifficulty.l0 => ZxStage.s0,
          ZxDifficulty.l1 => ZxStage.s1,
          ZxDifficulty.l2 => ZxStage.s2,
          ZxDifficulty.l3 => ZxStage.s3,
          ZxDifficulty.l4 => ZxStage.s4,
        };
        final risk = difficulty == ZxDifficulty.l4
            ? ZxRiskLevel.r2
            : difficulty == ZxDifficulty.l3
                ? ZxRiskLevel.r1
                : ZxRiskLevel.r0;
        result.add(
          ZxChallenge(
            id: 'challenge_${seed.key}_${difficulty.name}',
            dimension: seed.dimension,
            title: '${seed.title} · ${difficulty.code}',
            purpose: seed.purpose,
            barrier: seed.barrier,
            stage: stage,
            difficulty: difficulty,
            risk: risk,
            action: _scaledAction(seed, difficulty),
            lowerLoadAlternative: _scaledAction(seed, _lower(difficulty)),
            proof: seed.proof,
            stopCondition:
                '出现安全、健康、明显过载、未经同意的第三方影响时停止或降级。',
            evidenceLocators: seed.evidence,
          ),
        );
      }
    }
    return result;
  }

  static String _scaledAction(
    _ChallengeSeed seed,
    ZxDifficulty difficulty,
  ) {
    final frame = switch (difficulty) {
      ZxDifficulty.l0 => '30秒至2分钟：${seed.low}',
      ZxDifficulty.l1 => '2至5分钟：${seed.low}',
      ZxDifficulty.l2 => '10至25分钟：${seed.standard}',
      ZxDifficulty.l3 => '30至90分钟：${seed.high}',
      ZxDifficulty.l4 =>
        '多日挑战（需二次确认）：${seed.high}；每天只激活一个瓶颈并保留退出路径。',
    };
    return frame;
  }

  static ZxDifficulty _lower(ZxDifficulty value) =>
      value.index == 0 ? value : ZxDifficulty.values[value.index - 1];
}

class _HypothesisDraft {
  double score = 0;
  final List<String> evidence = <String>[];
  final List<String> counterEvidence = <String>[];
}

class _ChallengeSeed {
  final String key;
  final String dimension;
  final String title;
  final String purpose;
  final ZxBarrier barrier;
  final String low;
  final String standard;
  final String high;
  final String proof;
  final List<String> evidence;

  const _ChallengeSeed({
    required this.key,
    required this.dimension,
    required this.title,
    required this.purpose,
    required this.barrier,
    required this.low,
    required this.standard,
    required this.high,
    required this.proof,
    required this.evidence,
  });
}

const List<_ChallengeSeed> _seeds = <_ChallengeSeed>[
  _ChallengeSeed(
    key: 'recovery',
    dimension: '身体与恢复',
    title: '保护行动容量',
    purpose: '让恢复、求助和节律成为行动系统的一部分。',
    barrier: ZxBarrier.capacity,
    low: '喝水、休息、整理就医问题或向可信赖的人求助一项',
    standard: '完成一个不挤压睡眠和用餐的恢复单元，并记录前后状态',
    high: '建立一周恢复节律，识别过载信号并设置保护性休眠',
    proof: '自我确认、恢复记录或本地时间痕迹',
    evidence: <String>['MMP-S002-P0283', 'BA-P0097-B004'],
  ),
  _ChallengeSeed(
    key: 'attention',
    dimension: '注意与启动',
    title: '进入第一步',
    purpose: '让重要动作在关键情境获得注意和入口。',
    barrier: ZxBarrier.automaticMotivation,
    low: '打开唯一入口并停留30秒',
    standard: '设置一个线索并完成一次最小行动',
    high: '在两个干扰情境中自主启动并比较条件',
    proof: '入口时间、清单或自我确认',
    evidence: <String>['WJ-S1181-P0003', 'II-P0001-B004'],
  ),
  _ChallengeSeed(
    key: 'cognition',
    dimension: '认知与判断',
    title: '检验解释',
    purpose: '把阻断行动的想法转成可修订假设。',
    barrier: ZxBarrier.psychologicalCapability,
    low: '写出事实和一个替代解释',
    standard: '为一个预测设计低风险行为实验',
    high: '比较多个竞争假设并评估实际后果',
    proof: '证据表、实验记录或学习证据',
    evidence: <String>['AB-S016-P0004', 'DHT-P0128-B004'],
  ),
  _ChallengeSeed(
    key: 'emotion',
    dimension: '情绪与接纳',
    title: '带着不适行动',
    purpose: '取消“先感觉好”这一不必要行动门槛。',
    barrier: ZxBarrier.automaticMotivation,
    low: '命名感受后做一分钟价值动作',
    standard: '识别回避功能并完成一次分级接触',
    high: '在重要情境中带着不适完成可逆价值行动',
    proof: '行动事实和体验记录',
    evidence: <String>['ACT-S003-P0283', 'BA-P0037-B004'],
  ),
  _ChallengeSeed(
    key: 'meaning',
    dimension: '动机与意义',
    title: '认领方向',
    purpose: '让行动服务用户认可的价值、意义和责任。',
    barrier: ZxBarrier.reflectiveMotivation,
    low: '写出一个“为什么值得”',
    standard: '完成一次自主、价值和代价审查',
    high: '在冲突价值中形成可负责、可修改的选择',
    proof: '选择理由与后续现实动作',
    evidence: <String>['SDT-S018-P0172', 'FRK-S008-P0036'],
  ),
  _ChallengeSeed(
    key: 'mastery',
    dimension: '技能与效能',
    title: '建立掌握证据',
    purpose: '用真实技能和任务特定掌握替代空泛自信。',
    barrier: ZxBarrier.selfEfficacy,
    low: '练一个子技能或观察一个相似榜样',
    standard: '完成略高于现有证据的一步并校准把握',
    high: '掌握新场景并严格说明可迁移范围',
    proof: '过程痕迹、结果痕迹和校准记录',
    evidence: <String>['SEF-S092-P0004', 'SLT-S036-P0002'],
  ),
  _ChallengeSeed(
    key: 'environment',
    dimension: '习惯与环境',
    title: '降低临场负担',
    purpose: '用环境、线索和习惯减少重复决策成本。',
    barrier: ZxBarrier.physicalOpportunity,
    low: '准备一个工具或移除一个干扰',
    standard: '建立一个可撤销的如果—那么入口',
    high: '重构两个场景的默认环境并检查副作用',
    proof: '环境前后记录或本地清单',
    evidence: <String>['DHC-S005-P0003', 'II-P0009-B004'],
  ),
  _ChallengeSeed(
    key: 'relationship',
    dimension: '关系与协作',
    title: '建立社会机会',
    purpose: '把协调、支持和角色接口纳入行动能力。',
    barrier: ZxBarrier.socialOpportunity,
    low: '发出一个具体求助或澄清问题',
    standard: '与协作者确认一个角色和交付接口',
    high: '改善团队协调并收集集体效能证据',
    proof: '自我确认或经同意的协作者确认',
    evidence: <String>['SEF-S490-P0001', 'BCW-P0064-B010'],
  ),
  _ChallengeSeed(
    key: 'ethics',
    dimension: '责任与伦理',
    title: '为后果负责',
    purpose: '防止高效执行错误、操纵或伤害性方向。',
    barrier: ZxBarrier.valueEthics,
    low: '检查谁受益、谁受损、是否需要同意',
    standard: '比较继续、修改、退出的长期后果',
    high: '处理承诺与利益冲突，形成可审计行动协议',
    proof: '影响者检查和选择理由',
    evidence: <String>['WY-S003-P2428', 'DHT-P0046-B003'],
  ),
  _ChallengeSeed(
    key: 'contribution',
    dimension: '创造与贡献',
    title: '超越个人刷量',
    purpose: '把能力用于关系、共同任务和培养他人。',
    barrier: ZxBarrier.socialOpportunity,
    low: '在不越界的前提下帮助一人或分享一个方法',
    standard: '共同完成一个有清楚角色的小任务',
    high: '建立可持续共同项目并逐步撤除自己的支架',
    proof: '双方同意的结果或学习证据',
    evidence: <String>['FRK-S008-P0043', 'SDT-S009-P0041'],
  ),
];

ZxDifficulty _minDifficulty(ZxDifficulty first, ZxDifficulty second) =>
    first.index <= second.index ? first : second;
