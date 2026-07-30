import 'dart:convert';
import 'dart:math' as math;

enum ZxStage { s0, s1, s2, s3, s4, s5 }

enum ZxDifficulty { l0, l1, l2, l3, l4 }

enum ZxRiskLevel { r0, r1, r2, r3, r4 }

enum ZxBarrier {
  physicalCapability,
  psychologicalCapability,
  physicalOpportunity,
  socialOpportunity,
  reflectiveMotivation,
  automaticMotivation,
  valueEthics,
  selfEfficacy,
  capacity,
}

enum ZxProofType { selfReport, processTrace, outcomeTrace, collaborator, learning }

enum ZxActionStatus { proposed, active, completed, learned, paused, stopped }

enum ZxCompletionStatus { completed, notCompleted, safetyDowngrade, exited }

enum ZxLearningStatus { none, updated, strong }

extension ZxStageX on ZxStage {
  String get code => name.toUpperCase();

  String get label => switch (this) {
        ZxStage.s0 => '安全与恢复',
        ZxStage.s1 => '行动复苏',
        ZxStage.s2 => '行动力提高',
        ZxStage.s3 => '执行力增强',
        ZxStage.s4 => '自我治理',
        ZxStage.s5 => '行动王者',
      };

  static ZxStage parse(Object? raw) => ZxStage.values.firstWhere(
        (value) => value.name == raw.toString().toLowerCase(),
        orElse: () => ZxStage.s1,
      );
}

extension ZxDifficultyX on ZxDifficulty {
  String get code => name.toUpperCase();

  String get label => switch (this) {
        ZxDifficulty.l0 => 'L0 · 恢复/求助',
        ZxDifficulty.l1 => 'L1 · 最小行动',
        ZxDifficulty.l2 => 'L2 · 标准行动',
        ZxDifficulty.l3 => 'L3 · 多步骤行动',
        ZxDifficulty.l4 => 'L4 · 长期/公开挑战',
      };

  int get baseCompletionCoins => switch (this) {
        ZxDifficulty.l0 => 2,
        ZxDifficulty.l1 => 5,
        ZxDifficulty.l2 => 10,
        ZxDifficulty.l3 => 18,
        ZxDifficulty.l4 => 30,
      };

  int get baseLearningCoins => switch (this) {
        ZxDifficulty.l0 => 1,
        ZxDifficulty.l1 => 2,
        ZxDifficulty.l2 => 4,
        ZxDifficulty.l3 => 6,
        ZxDifficulty.l4 => 8,
      };

  int get dailyEffectiveLimit => switch (this) {
        ZxDifficulty.l0 => 5,
        ZxDifficulty.l1 => 4,
        ZxDifficulty.l2 => 3,
        ZxDifficulty.l3 => 2,
        ZxDifficulty.l4 => 1,
      };

  static ZxDifficulty parse(Object? raw) => ZxDifficulty.values.firstWhere(
        (value) => value.name == raw.toString().toLowerCase(),
        orElse: () => ZxDifficulty.l1,
      );
}

extension ZxRiskLevelX on ZxRiskLevel {
  String get code => name.toUpperCase();

  String get label => switch (this) {
        ZxRiskLevel.r0 => 'R0 · 低影响',
        ZxRiskLevel.r1 => 'R1 · 可撤销',
        ZxRiskLevel.r2 => 'R2 · 需二次确认',
        ZxRiskLevel.r3 => 'R3 · 需要专业判断',
        ZxRiskLevel.r4 => 'R4 · 即时安全优先',
      };

  static ZxRiskLevel parse(Object? raw) => ZxRiskLevel.values.firstWhere(
        (value) => value.name == raw.toString().toLowerCase(),
        orElse: () => ZxRiskLevel.r0,
      );
}

extension ZxBarrierX on ZxBarrier {
  String get key => switch (this) {
        ZxBarrier.physicalCapability => 'physical_capability',
        ZxBarrier.psychologicalCapability => 'psychological_capability',
        ZxBarrier.physicalOpportunity => 'physical_opportunity',
        ZxBarrier.socialOpportunity => 'social_opportunity',
        ZxBarrier.reflectiveMotivation => 'reflective_motivation',
        ZxBarrier.automaticMotivation => 'automatic_motivation',
        ZxBarrier.valueEthics => 'value_ethics',
        ZxBarrier.selfEfficacy => 'self_efficacy',
        ZxBarrier.capacity => 'capacity',
      };

  String get label => switch (this) {
        ZxBarrier.physicalCapability => '身体能力',
        ZxBarrier.psychologicalCapability => '心理/技能能力',
        ZxBarrier.physicalOpportunity => '物理机会',
        ZxBarrier.socialOpportunity => '社会机会',
        ZxBarrier.reflectiveMotivation => '反思动机',
        ZxBarrier.automaticMotivation => '自动动机/回避',
        ZxBarrier.valueEthics => '价值与伦理冲突',
        ZxBarrier.selfEfficacy => '任务特定效能',
        ZxBarrier.capacity => '行动容量',
      };

  static ZxBarrier parse(Object? raw) {
    final value = raw.toString();
    return ZxBarrier.values.firstWhere(
      (item) => item.key == value || item.name == value,
      orElse: () => ZxBarrier.automaticMotivation,
    );
  }
}

class ZxGoal {
  final int id;
  final String title;
  final String domain;
  final String valueDirection;
  final double autonomy;
  final ZxStage stage;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  const ZxGoal({
    this.id = 0,
    required this.title,
    this.domain = 'general',
    this.valueDirection = '',
    this.autonomy = 0.5,
    this.stage = ZxStage.s1,
    this.status = 'active',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'title': title,
        'domain': domain,
        'value_direction': valueDirection,
        'autonomy': autonomy,
        'stage': stage.name,
        'status': status,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory ZxGoal.fromMap(Map<String, Object?> map) => ZxGoal(
        id: _asInt(map['id']),
        title: (map['title'] ?? '').toString(),
        domain: (map['domain'] ?? 'general').toString(),
        valueDirection: (map['value_direction'] ?? '').toString(),
        autonomy: _asDouble(map['autonomy'], 0.5),
        stage: ZxStageX.parse(map['stage']),
        status: (map['status'] ?? 'active').toString(),
        createdAtMs: _asInt(map['created_at_ms']),
        updatedAtMs: _asInt(map['updated_at_ms']),
      );
}

class ZxSituationInput {
  final int goalId;
  final String goalTitle;
  final String recentEvent;
  final String targetBehavior;
  final String valueReason;
  final String thought;
  final String emotion;
  final String urge;
  final String actualAction;
  final String cue;
  final int availableMinutes;
  final double bodyCapacity;
  final double attentionCapacity;
  final double sleepCapacity;
  final double autonomy;
  final double importance;
  final double selfEfficacy;
  final bool knowsHow;
  final bool hasTime;
  final bool hasTools;
  final bool hasSupport;
  final bool waitingForMood;
  final bool positiveFantasy;
  final bool ethicalConflict;
  final bool thirdPartyImpact;
  final bool irreversibleImpact;
  final bool professionalDecision;
  final bool acuteDanger;
  final bool severeFunctionLoss;
  final String previousAttempts;

  const ZxSituationInput({
    this.goalId = 0,
    required this.goalTitle,
    required this.recentEvent,
    required this.targetBehavior,
    this.valueReason = '',
    this.thought = '',
    this.emotion = '',
    this.urge = '',
    this.actualAction = '',
    this.cue = '',
    this.availableMinutes = 5,
    this.bodyCapacity = 0.6,
    this.attentionCapacity = 0.6,
    this.sleepCapacity = 0.6,
    this.autonomy = 0.6,
    this.importance = 0.7,
    this.selfEfficacy = 0.5,
    this.knowsHow = true,
    this.hasTime = true,
    this.hasTools = true,
    this.hasSupport = true,
    this.waitingForMood = false,
    this.positiveFantasy = false,
    this.ethicalConflict = false,
    this.thirdPartyImpact = false,
    this.irreversibleImpact = false,
    this.professionalDecision = false,
    this.acuteDanger = false,
    this.severeFunctionLoss = false,
    this.previousAttempts = '',
  });

  double get capacity =>
      ((bodyCapacity + attentionCapacity + sleepCapacity) / 3)
          .clamp(0.0, 1.0)
          .toDouble();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goal_id': goalId,
        'goal_title': goalTitle,
        'recent_event': recentEvent,
        'target_behavior': targetBehavior,
        'value_reason': valueReason,
        'thought': thought,
        'emotion': emotion,
        'urge': urge,
        'actual_action': actualAction,
        'cue': cue,
        'available_minutes': availableMinutes,
        'body_capacity': bodyCapacity,
        'attention_capacity': attentionCapacity,
        'sleep_capacity': sleepCapacity,
        'autonomy': autonomy,
        'importance': importance,
        'self_efficacy': selfEfficacy,
        'knows_how': knowsHow,
        'has_time': hasTime,
        'has_tools': hasTools,
        'has_support': hasSupport,
        'waiting_for_mood': waitingForMood,
        'positive_fantasy': positiveFantasy,
        'ethical_conflict': ethicalConflict,
        'third_party_impact': thirdPartyImpact,
        'irreversible_impact': irreversibleImpact,
        'professional_decision': professionalDecision,
        'acute_danger': acuteDanger,
        'severe_function_loss': severeFunctionLoss,
        'previous_attempts': previousAttempts,
      };

  factory ZxSituationInput.fromJson(Map<String, dynamic> map) => ZxSituationInput(
        goalId: _asInt(map['goal_id']),
        goalTitle: (map['goal_title'] ?? '').toString(),
        recentEvent: (map['recent_event'] ?? '').toString(),
        targetBehavior: (map['target_behavior'] ?? '').toString(),
        valueReason: (map['value_reason'] ?? '').toString(),
        thought: (map['thought'] ?? '').toString(),
        emotion: (map['emotion'] ?? '').toString(),
        urge: (map['urge'] ?? '').toString(),
        actualAction: (map['actual_action'] ?? '').toString(),
        cue: (map['cue'] ?? '').toString(),
        availableMinutes: _asInt(map['available_minutes'], 5),
        bodyCapacity: _asDouble(map['body_capacity'], 0.6),
        attentionCapacity: _asDouble(map['attention_capacity'], 0.6),
        sleepCapacity: _asDouble(map['sleep_capacity'], 0.6),
        autonomy: _asDouble(map['autonomy'], 0.6),
        importance: _asDouble(map['importance'], 0.7),
        selfEfficacy: _asDouble(map['self_efficacy'], 0.5),
        knowsHow: _asBool(map['knows_how'], true),
        hasTime: _asBool(map['has_time'], true),
        hasTools: _asBool(map['has_tools'], true),
        hasSupport: _asBool(map['has_support'], true),
        waitingForMood: _asBool(map['waiting_for_mood']),
        positiveFantasy: _asBool(map['positive_fantasy']),
        ethicalConflict: _asBool(map['ethical_conflict']),
        thirdPartyImpact: _asBool(map['third_party_impact']),
        irreversibleImpact: _asBool(map['irreversible_impact']),
        professionalDecision: _asBool(map['professional_decision']),
        acuteDanger: _asBool(map['acute_danger']),
        severeFunctionLoss: _asBool(map['severe_function_loss']),
        previousAttempts: (map['previous_attempts'] ?? '').toString(),
      );
}

class ZxSafetyDecision {
  final ZxRiskLevel risk;
  final bool actionAllowed;
  final bool requiresSecondConfirmation;
  final ZxDifficulty maximumDifficulty;
  final ZxStage suggestedStage;
  final List<String> reasons;
  final String safeNextStep;

  const ZxSafetyDecision({
    required this.risk,
    required this.actionAllowed,
    required this.requiresSecondConfirmation,
    required this.maximumDifficulty,
    required this.suggestedStage,
    required this.reasons,
    required this.safeNextStep,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'risk': risk.name,
        'action_allowed': actionAllowed,
        'requires_second_confirmation': requiresSecondConfirmation,
        'maximum_difficulty': maximumDifficulty.name,
        'suggested_stage': suggestedStage.name,
        'reasons': reasons,
        'safe_next_step': safeNextStep,
      };

  factory ZxSafetyDecision.fromJson(Map<String, dynamic> map) => ZxSafetyDecision(
        risk: ZxRiskLevelX.parse(map['risk']),
        actionAllowed: _asBool(map['action_allowed']),
        requiresSecondConfirmation: _asBool(map['requires_second_confirmation']),
        maximumDifficulty: ZxDifficultyX.parse(map['maximum_difficulty']),
        suggestedStage: ZxStageX.parse(map['suggested_stage']),
        reasons: _stringList(map['reasons']),
        safeNextStep: (map['safe_next_step'] ?? '').toString(),
      );
}

class ZxBarrierHypothesis {
  final ZxBarrier barrier;
  final double score;
  final double confidence;
  final List<String> evidence;
  final List<String> counterEvidence;

  const ZxBarrierHypothesis({
    required this.barrier,
    required this.score,
    required this.confidence,
    required this.evidence,
    this.counterEvidence = const <String>[],
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barrier': barrier.key,
        'score': score,
        'confidence': confidence,
        'evidence': evidence,
        'counter_evidence': counterEvidence,
      };

  factory ZxBarrierHypothesis.fromJson(Map<String, dynamic> map) =>
      ZxBarrierHypothesis(
        barrier: ZxBarrierX.parse(map['barrier']),
        score: _asDouble(map['score']),
        confidence: _asDouble(map['confidence']),
        evidence: _stringList(map['evidence']),
        counterEvidence: _stringList(map['counter_evidence']),
      );
}

class ZxDiagnosisResult {
  final ZxSafetyDecision safety;
  final String targetBehavior;
  final List<ZxBarrierHypothesis> hypotheses;
  final ZxStage stage;
  final ZxDifficulty suggestedDifficulty;
  final double overallConfidence;
  final int createdAtMs;

  const ZxDiagnosisResult({
    required this.safety,
    required this.targetBehavior,
    required this.hypotheses,
    required this.stage,
    required this.suggestedDifficulty,
    required this.overallConfidence,
    this.createdAtMs = 0,
  });

  ZxBarrierHypothesis get primary => hypotheses.isEmpty
      ? const ZxBarrierHypothesis(
          barrier: ZxBarrier.automaticMotivation,
          score: 0.5,
          confidence: 0.3,
          evidence: <String>['信息不足，先用低负荷行动求证。'],
        )
      : hypotheses.first;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'safety': safety.toJson(),
        'target_behavior': targetBehavior,
        'hypotheses': hypotheses.map((item) => item.toJson()).toList(),
        'stage': stage.name,
        'suggested_difficulty': suggestedDifficulty.name,
        'overall_confidence': overallConfidence,
        'created_at_ms': createdAtMs,
      };

  String encode() => jsonEncode(toJson());

  factory ZxDiagnosisResult.fromJson(Map<String, dynamic> map) =>
      ZxDiagnosisResult(
        safety: ZxSafetyDecision.fromJson(
          Map<String, dynamic>.from(map['safety'] as Map? ?? const {}),
        ),
        targetBehavior: (map['target_behavior'] ?? '').toString(),
        hypotheses: _mapList(map['hypotheses'])
            .map(ZxBarrierHypothesis.fromJson)
            .toList(growable: false),
        stage: ZxStageX.parse(map['stage']),
        suggestedDifficulty: ZxDifficultyX.parse(map['suggested_difficulty']),
        overallConfidence: _asDouble(map['overall_confidence']),
        createdAtMs: _asInt(map['created_at_ms']),
      );
}

class ZxWork {
  final String sourceId;
  final int batch;
  final String title;
  final String author;
  final String evidenceRole;
  final String evidenceTier;

  const ZxWork({
    required this.sourceId,
    required this.batch,
    required this.title,
    required this.author,
    required this.evidenceRole,
    required this.evidenceTier,
  });

  factory ZxWork.fromJson(Map<String, dynamic> map) => ZxWork(
        sourceId: (map['source_id'] ?? '').toString(),
        batch: _asInt(map['batch']),
        title: (map['title'] ?? '').toString(),
        author: (map['author'] ?? '').toString(),
        evidenceRole: (map['evidence_role'] ?? '').toString(),
        evidenceTier: (map['evidence_tier'] ?? '').toString(),
      );
}

class ZxEvidenceItem {
  final String id;
  final String sourceId;
  final String locator;
  final String title;
  final String summary;
  final String use;
  final String boundary;
  final String contentType;
  final List<String> tags;

  const ZxEvidenceItem({
    required this.id,
    required this.sourceId,
    required this.locator,
    required this.title,
    required this.summary,
    required this.use,
    required this.boundary,
    required this.contentType,
    required this.tags,
  });

  String get searchableText =>
      '$sourceId $locator $title $summary $use $boundary ${tags.join(' ')}';

  factory ZxEvidenceItem.fromJson(Map<String, dynamic> map) => ZxEvidenceItem(
        id: (map['id'] ?? '').toString(),
        sourceId: (map['source_id'] ?? '').toString(),
        locator: (map['locator'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        summary: (map['summary'] ?? '').toString(),
        use: (map['use'] ?? '').toString(),
        boundary: (map['boundary'] ?? '').toString(),
        contentType: (map['content_type'] ?? 'original_claim').toString(),
        tags: _stringList(map['tags']),
      );
}

class ZxThinkerLens {
  final String id;
  final String sourceId;
  final String thinker;
  final String name;
  final String coreQuestion;
  final String mechanism;
  final String bestFit;
  final String nonFit;
  final String prerequisites;
  final String contraindications;
  final List<ZxBarrier> barriers;
  final List<ZxStage> stages;
  final List<ZxDifficulty> difficulties;
  final List<String> methods;
  final List<String> actionTemplates;
  final List<String> tensionLinks;
  final List<String> evidenceLinks;
  final double evidenceDirectness;
  final String reviewStatus;

  const ZxThinkerLens({
    required this.id,
    required this.sourceId,
    required this.thinker,
    required this.name,
    required this.coreQuestion,
    required this.mechanism,
    required this.bestFit,
    required this.nonFit,
    required this.prerequisites,
    required this.contraindications,
    required this.barriers,
    required this.stages,
    required this.difficulties,
    required this.methods,
    required this.actionTemplates,
    required this.tensionLinks,
    required this.evidenceLinks,
    required this.evidenceDirectness,
    required this.reviewStatus,
  });

  String get searchableText =>
      '$thinker $name $coreQuestion $mechanism $bestFit $nonFit '
      '${methods.join(' ')} ${actionTemplates.join(' ')} ${evidenceLinks.join(' ')}';

  factory ZxThinkerLens.fromJson(Map<String, dynamic> map) => ZxThinkerLens(
        id: (map['lens_id'] ?? '').toString(),
        sourceId: (map['source_id'] ?? '').toString(),
        thinker: (map['thinker'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        coreQuestion: (map['core_question'] ?? '').toString(),
        mechanism: (map['mechanism'] ?? '').toString(),
        bestFit: (map['best_fit'] ?? '').toString(),
        nonFit: (map['non_fit'] ?? '').toString(),
        prerequisites: (map['prerequisites'] ?? '').toString(),
        contraindications: (map['contraindications'] ?? '').toString(),
        barriers: _stringList(map['barriers']).map(ZxBarrierX.parse).toList(),
        stages: _stringList(map['stages']).map(ZxStageX.parse).toList(),
        difficulties:
            _stringList(map['difficulties']).map(ZxDifficultyX.parse).toList(),
        methods: _stringList(map['methods']),
        actionTemplates: _stringList(map['action_templates']),
        tensionLinks: _stringList(map['tension_links']),
        evidenceLinks: _stringList(map['evidence_links']),
        evidenceDirectness: _asDouble(map['evidence_directness'], 0.7),
        reviewStatus: (map['review_status'] ?? 'approved').toString(),
      );
}

class ZxFitScore {
  final String lensId;
  final Map<String, double> components;
  final double conflictPenalty;
  final double safetyPenalty;
  final double total;
  final bool disqualified;
  final List<String> reasons;

  const ZxFitScore({
    required this.lensId,
    required this.components,
    required this.conflictPenalty,
    required this.safetyPenalty,
    required this.total,
    required this.disqualified,
    required this.reasons,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lens_id': lensId,
        'components': components,
        'conflict_penalty': conflictPenalty,
        'safety_penalty': safetyPenalty,
        'total': total,
        'disqualified': disqualified,
        'reasons': reasons,
      };

  factory ZxFitScore.fromJson(Map<String, dynamic> map) => ZxFitScore(
        lensId: (map['lens_id'] ?? '').toString(),
        components: _doubleMap(map['components']),
        conflictPenalty: _asDouble(map['conflict_penalty']),
        safetyPenalty: _asDouble(map['safety_penalty']),
        total: _asDouble(map['total']),
        disqualified: _asBool(map['disqualified']),
        reasons: _stringList(map['reasons']),
      );
}

class ZxMatchResult {
  final ZxThinkerLens primary;
  final ZxThinkerLens? complementary;
  final List<ZxFitScore> ranking;
  final bool lowMatch;
  final String lowMatchReason;
  final double uncertainty;
  final List<String> conflictNotes;
  final int createdAtMs;

  const ZxMatchResult({
    required this.primary,
    this.complementary,
    required this.ranking,
    required this.lowMatch,
    required this.lowMatchReason,
    required this.uncertainty,
    required this.conflictNotes,
    this.createdAtMs = 0,
  });

  ZxFitScore? scoreFor(String lensId) {
    for (final item in ranking) {
      if (item.lensId == lensId) return item;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'primary_lens_id': primary.id,
        'complementary_lens_id': complementary?.id,
        'ranking': ranking.map((item) => item.toJson()).toList(),
        'low_match': lowMatch,
        'low_match_reason': lowMatchReason,
        'uncertainty': uncertainty,
        'conflict_notes': conflictNotes,
        'created_at_ms': createdAtMs,
      };
}

class ZxActionPrescription {
  final String id;
  final int goalId;
  final String goalTitle;
  final String targetBehavior;
  final String primaryLensId;
  final String complementaryLensId;
  final ZxBarrier primaryBarrier;
  final ZxStage stage;
  final ZxDifficulty difficulty;
  final ZxRiskLevel risk;
  final String thoughtLens;
  final String mainAction;
  final String lowerLoadAlternative;
  final String challengeAlternative;
  final String cue;
  final String response;
  final List<String> supportChanges;
  final List<String> stopConditions;
  final List<ZxProofType> proofOptions;
  final String completionDefinition;
  final String reviewQuestion;
  final List<String> evidenceLocators;
  final double uncertainty;
  final ZxActionStatus status;
  final int createdAtMs;
  final int updatedAtMs;

  const ZxActionPrescription({
    required this.id,
    this.goalId = 0,
    required this.goalTitle,
    required this.targetBehavior,
    required this.primaryLensId,
    this.complementaryLensId = '',
    required this.primaryBarrier,
    required this.stage,
    required this.difficulty,
    required this.risk,
    required this.thoughtLens,
    required this.mainAction,
    required this.lowerLoadAlternative,
    required this.challengeAlternative,
    required this.cue,
    required this.response,
    required this.supportChanges,
    required this.stopConditions,
    required this.proofOptions,
    required this.completionDefinition,
    required this.reviewQuestion,
    required this.evidenceLocators,
    required this.uncertainty,
    this.status = ZxActionStatus.proposed,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  ZxActionPrescription copyWith({
    int? goalId,
    String? mainAction,
    String? lowerLoadAlternative,
    String? challengeAlternative,
    ZxDifficulty? difficulty,
    ZxActionStatus? status,
    int? updatedAtMs,
  }) =>
      ZxActionPrescription(
        id: id,
        goalId: goalId ?? this.goalId,
        goalTitle: goalTitle,
        targetBehavior: targetBehavior,
        primaryLensId: primaryLensId,
        complementaryLensId: complementaryLensId,
        primaryBarrier: primaryBarrier,
        stage: stage,
        difficulty: difficulty ?? this.difficulty,
        risk: risk,
        thoughtLens: thoughtLens,
        mainAction: mainAction ?? this.mainAction,
        lowerLoadAlternative:
            lowerLoadAlternative ?? this.lowerLoadAlternative,
        challengeAlternative: challengeAlternative ?? this.challengeAlternative,
        cue: cue,
        response: response,
        supportChanges: supportChanges,
        stopConditions: stopConditions,
        proofOptions: proofOptions,
        completionDefinition: completionDefinition,
        reviewQuestion: reviewQuestion,
        evidenceLocators: evidenceLocators,
        uncertainty: uncertainty,
        status: status ?? this.status,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'goal_title': goalTitle,
        'target_behavior': targetBehavior,
        'primary_lens_id': primaryLensId,
        'complementary_lens_id': complementaryLensId,
        'primary_barrier': primaryBarrier.key,
        'stage': stage.name,
        'difficulty': difficulty.name,
        'risk': risk.name,
        'thought_lens': thoughtLens,
        'main_action': mainAction,
        'lower_load_alternative': lowerLoadAlternative,
        'challenge_alternative': challengeAlternative,
        'cue': cue,
        'response': response,
        'support_changes': supportChanges,
        'stop_conditions': stopConditions,
        'proof_options': proofOptions.map((item) => item.name).toList(),
        'completion_definition': completionDefinition,
        'review_question': reviewQuestion,
        'evidence_locators': evidenceLocators,
        'uncertainty': uncertainty,
        'status': status.name,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  factory ZxActionPrescription.fromJson(Map<String, dynamic> map) =>
      ZxActionPrescription(
        id: (map['id'] ?? '').toString(),
        goalId: _asInt(map['goal_id']),
        goalTitle: (map['goal_title'] ?? '').toString(),
        targetBehavior: (map['target_behavior'] ?? '').toString(),
        primaryLensId: (map['primary_lens_id'] ?? '').toString(),
        complementaryLensId: (map['complementary_lens_id'] ?? '').toString(),
        primaryBarrier: ZxBarrierX.parse(map['primary_barrier']),
        stage: ZxStageX.parse(map['stage']),
        difficulty: ZxDifficultyX.parse(map['difficulty']),
        risk: ZxRiskLevelX.parse(map['risk']),
        thoughtLens: (map['thought_lens'] ?? '').toString(),
        mainAction: (map['main_action'] ?? '').toString(),
        lowerLoadAlternative:
            (map['lower_load_alternative'] ?? '').toString(),
        challengeAlternative: (map['challenge_alternative'] ?? '').toString(),
        cue: (map['cue'] ?? '').toString(),
        response: (map['response'] ?? '').toString(),
        supportChanges: _stringList(map['support_changes']),
        stopConditions: _stringList(map['stop_conditions']),
        proofOptions: _stringList(map['proof_options'])
            .map(
              (raw) => ZxProofType.values.firstWhere(
                (item) => item.name == raw,
                orElse: () => ZxProofType.selfReport,
              ),
            )
            .toList(),
        completionDefinition: (map['completion_definition'] ?? '').toString(),
        reviewQuestion: (map['review_question'] ?? '').toString(),
        evidenceLocators: _stringList(map['evidence_locators']),
        uncertainty: _asDouble(map['uncertainty'], 0.4),
        status: ZxActionStatus.values.firstWhere(
          (item) => item.name == map['status'],
          orElse: () => ZxActionStatus.proposed,
        ),
        createdAtMs: _asInt(map['created_at_ms']),
        updatedAtMs: _asInt(map['updated_at_ms']),
      );

  factory ZxActionPrescription.fromMap(Map<String, Object?> row) {
    final raw = (row['prescription_json'] ?? '{}').toString();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final item = ZxActionPrescription.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        return item.copyWith(
          goalId: _asInt(row['goal_id'], item.goalId),
          status: ZxActionStatus.values.firstWhere(
            (value) => value.name == (row['status'] ?? '').toString(),
            orElse: () => item.status,
          ),
          updatedAtMs: _asInt(row['updated_at_ms'], item.updatedAtMs),
        );
      }
    } catch (_) {}
    return ZxActionPrescription(
      id: (row['action_uid'] ?? '').toString(),
      goalId: _asInt(row['goal_id']),
      goalTitle: '',
      targetBehavior: '',
      primaryLensId: 'BCW_COMB',
      primaryBarrier: ZxBarrier.automaticMotivation,
      stage: ZxStage.s1,
      difficulty: ZxDifficulty.l1,
      risk: ZxRiskLevel.r0,
      thoughtLens: '',
      mainAction: (row['title'] ?? '').toString(),
      lowerLoadAlternative: '',
      challengeAlternative: '',
      cue: '',
      response: '',
      supportChanges: const <String>[],
      stopConditions: const <String>['如出现安全、健康或明显过载风险，立即停止。'],
      proofOptions: const <ZxProofType>[ZxProofType.selfReport],
      completionDefinition: '',
      reviewQuestion: '',
      evidenceLocators: const <String>[],
      uncertainty: 0.7,
      status: ZxActionStatus.values.firstWhere(
        (value) => value.name == (row['status'] ?? '').toString(),
        orElse: () => ZxActionStatus.proposed,
      ),
      createdAtMs: _asInt(row['created_at_ms']),
      updatedAtMs: _asInt(row['updated_at_ms']),
    );
  }
}

class ZxReviewInput {
  final ZxCompletionStatus completion;
  final ZxLearningStatus learning;
  final ZxProofType proofType;
  final String whatHappened;
  final String hypothesisUpdate;
  final String difficultyFit;
  final String consequences;
  final String nextDecision;
  final String nextAction;
  final bool safeDowngrade;
  final int reflectionDepth;

  const ZxReviewInput({
    required this.completion,
    required this.learning,
    required this.proofType,
    required this.whatHappened,
    required this.hypothesisUpdate,
    required this.difficultyFit,
    required this.consequences,
    required this.nextDecision,
    required this.nextAction,
    this.safeDowngrade = false,
    this.reflectionDepth = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'completion': completion.name,
        'learning': learning.name,
        'proof_type': proofType.name,
        'what_happened': whatHappened,
        'hypothesis_update': hypothesisUpdate,
        'difficulty_fit': difficultyFit,
        'consequences': consequences,
        'next_decision': nextDecision,
        'next_action': nextAction,
        'safe_downgrade': safeDowngrade,
        'reflection_depth': reflectionDepth,
      };
}

class ZxRewardOutcome {
  final int completionCoins;
  final int learningCoins;
  final int totalCoins;
  final double xp;
  final String abilityDimension;
  final double proofFactor;
  final double reflectionFactor;
  final double calibrationFactor;
  final double noveltyFactor;
  final bool dailyCapApplied;
  final List<String> explanations;

  const ZxRewardOutcome({
    required this.completionCoins,
    required this.learningCoins,
    required this.totalCoins,
    required this.xp,
    required this.abilityDimension,
    required this.proofFactor,
    required this.reflectionFactor,
    required this.calibrationFactor,
    required this.noveltyFactor,
    required this.dailyCapApplied,
    required this.explanations,
  });
}

class ZxTreeState {
  final double water;
  final double sunlight;
  final double fertilizer;
  final double growth;
  final int coins;
  final String stage;
  final String mode;
  final bool dormant;
  final bool gamificationEnabled;
  final int lastActivityMs;
  final int lowVitalitySinceMs;
  final Map<String, double> abilityXp;

  const ZxTreeState({
    this.water = 55,
    this.sunlight = 55,
    this.fertilizer = 55,
    this.growth = 0,
    this.coins = 0,
    this.stage = 'seed',
    this.mode = 'normal',
    this.dormant = false,
    this.gamificationEnabled = true,
    this.lastActivityMs = 0,
    this.lowVitalitySinceMs = 0,
    this.abilityXp = const <String, double>{
      '选择力': 0,
      '启动力': 0,
      '持续力': 0,
      '修正力': 0,
      '贡献力': 0,
    },
  });

  double get vitality {
    final w = water.clamp(0.0, 100.0).toDouble() / 100;
    final s = sunlight.clamp(0.0, 100.0).toDouble() / 100;
    final f = fertilizer.clamp(0.0, 100.0).toDouble() / 100;
    return 100 * math.pow(w * s * f, 1 / 3).toDouble();
  }

  double get balanceFactor {
    final values = <double>[water, sunlight, fertilizer];
    final maximum =
        values.reduce((a, b) => math.max(a, b).toDouble());
    final minimum =
        values.reduce((a, b) => math.min(a, b).toDouble());
    if (maximum <= 0) return 0.6;
    return 0.6 + 0.4 * minimum / maximum;
  }

  String get visualState {
    if (dormant) return '休眠';
    if (vitality < 30) return '枯萎';
    if (vitality < 50) return '褪色';
    return '生长';
  }

  ZxTreeState copyWith({
    double? water,
    double? sunlight,
    double? fertilizer,
    double? growth,
    int? coins,
    String? stage,
    String? mode,
    bool? dormant,
    bool? gamificationEnabled,
    int? lastActivityMs,
    int? lowVitalitySinceMs,
    Map<String, double>? abilityXp,
  }) =>
      ZxTreeState(
        water: water ?? this.water,
        sunlight: sunlight ?? this.sunlight,
        fertilizer: fertilizer ?? this.fertilizer,
        growth: growth ?? this.growth,
        coins: coins ?? this.coins,
        stage: stage ?? this.stage,
        mode: mode ?? this.mode,
        dormant: dormant ?? this.dormant,
        gamificationEnabled:
            gamificationEnabled ?? this.gamificationEnabled,
        lastActivityMs: lastActivityMs ?? this.lastActivityMs,
        lowVitalitySinceMs: lowVitalitySinceMs ?? this.lowVitalitySinceMs,
        abilityXp: abilityXp ?? this.abilityXp,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'water': water,
        'sunlight': sunlight,
        'fertilizer': fertilizer,
        'growth': growth,
        'coins': coins,
        'stage': stage,
        'mode': mode,
        'dormant': dormant,
        'gamification_enabled': gamificationEnabled,
        'last_activity_ms': lastActivityMs,
        'low_vitality_since_ms': lowVitalitySinceMs,
        'ability_xp': abilityXp,
      };

  factory ZxTreeState.fromJson(Map<String, dynamic> map) => ZxTreeState(
        water: _asDouble(map['water'], 55),
        sunlight: _asDouble(map['sunlight'], 55),
        fertilizer: _asDouble(map['fertilizer'], 55),
        growth: _asDouble(map['growth']),
        coins: _asInt(map['coins']),
        stage: (map['stage'] ?? 'seed').toString(),
        mode: (map['mode'] ?? 'normal').toString(),
        dormant: _asBool(map['dormant']),
        gamificationEnabled: _asBool(map['gamification_enabled'], true),
        lastActivityMs: _asInt(map['last_activity_ms']),
        lowVitalitySinceMs: _asInt(map['low_vitality_since_ms']),
        abilityXp: _doubleMap(map['ability_xp']),
      );
}

class ZxChallenge {
  final String id;
  final String dimension;
  final String title;
  final String purpose;
  final ZxBarrier barrier;
  final ZxStage stage;
  final ZxDifficulty difficulty;
  final ZxRiskLevel risk;
  final String action;
  final String lowerLoadAlternative;
  final String proof;
  final String stopCondition;
  final List<String> evidenceLocators;

  const ZxChallenge({
    required this.id,
    required this.dimension,
    required this.title,
    required this.purpose,
    required this.barrier,
    required this.stage,
    required this.difficulty,
    required this.risk,
    required this.action,
    required this.lowerLoadAlternative,
    required this.proof,
    required this.stopCondition,
    required this.evidenceLocators,
  });
}

class ZxCandidateLens {
  final int id;
  final String gap;
  final String concept;
  final String thinker;
  final String work;
  final String sourceUri;
  final String addedValue;
  final String risks;
  final String status;
  final int createdAtMs;

  const ZxCandidateLens({
    this.id = 0,
    required this.gap,
    required this.concept,
    required this.thinker,
    required this.work,
    required this.sourceUri,
    required this.addedValue,
    required this.risks,
    this.status = 'candidate',
    this.createdAtMs = 0,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'gap': gap,
        'concept': concept,
        'thinker': thinker,
        'work': work,
        'source_uri': sourceUri,
        'added_value': addedValue,
        'risks': risks,
        'status': status,
        'created_at_ms': createdAtMs,
      };

  factory ZxCandidateLens.fromMap(Map<String, Object?> map) => ZxCandidateLens(
        id: _asInt(map['id']),
        gap: (map['gap'] ?? '').toString(),
        concept: (map['concept'] ?? '').toString(),
        thinker: (map['thinker'] ?? '').toString(),
        work: (map['work'] ?? '').toString(),
        sourceUri: (map['source_uri'] ?? '').toString(),
        addedValue: (map['added_value'] ?? '').toString(),
        risks: (map['risks'] ?? '').toString(),
        status: (map['status'] ?? 'candidate').toString(),
        createdAtMs: _asInt(map['created_at_ms']),
      );
}

class ZxKnowledgeSearchResult {
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final String summary;
  final String locator;
  final double score;

  const ZxKnowledgeSearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.locator,
    required this.score,
  });
}

int _asInt(Object? raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

double _asDouble(Object? raw, [double fallback = 0]) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? fallback;
}

bool _asBool(Object? raw, [bool fallback = false]) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final value = raw?.toString().toLowerCase();
  if (value == 'true' || value == '1') return true;
  if (value == 'false' || value == '0') return false;
  return fallback;
}

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(RegExp(r'[,，;；\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, double> _doubleMap(Object? raw) {
  if (raw is! Map) return const <String, double>{};
  return raw.map(
    (key, value) => MapEntry(key.toString(), _asDouble(value)),
  );
}
