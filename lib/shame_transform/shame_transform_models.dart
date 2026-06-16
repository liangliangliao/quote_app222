import 'dart:convert';

enum ShameScene {
  firstAid,
  eventRecord,
  healthyTransformation,
  innerChild,
  innerCritic,
  deniedPart,
  relationshipBoundary,
  healthyResponsibility,
  todoGoal,
  dailyReview,
  shameIdentification,
  shameNaming,
  shameBinding,
  bridgeRepair,
  culturalShame,
  avoidanceCycle,
  identityRebuild,
  shameDictionary,
  shameCompass,
  affectRecovery,
  beingSeenTraining,
  truePrideReview,
  shameScript,
}

extension ShameSceneMeta on ShameScene {
  String get key => name;

  String get title => switch (this) {
        ShameScene.firstAid => '羞耻急救',
        ShameScene.eventRecord => '羞耻事件记录',
        ShameScene.healthyTransformation => '健康羞耻转化',
        ShameScene.innerChild => '内在小孩修复',
        ShameScene.innerCritic => '内在批判声音外化',
        ShameScene.deniedPart => '被否认自我部分整合',
        ShameScene.relationshipBoundary => '关系边界与修复',
        ShameScene.healthyResponsibility => '健康责任训练',
        ShameScene.todoGoal => 'Todo 目标羞耻转化',
        ShameScene.dailyReview => '每日羞耻转化复盘',
        ShameScene.shameIdentification => '羞耻识别评估',
        ShameScene.shameNaming => '识别并命名羞耻',
        ShameScene.shameBinding => '羞耻绑定解码',
        ShameScene.bridgeRepair => '关系桥梁修复',
        ShameScene.culturalShame => '文化/社会羞耻识别',
        ShameScene.avoidanceCycle => '逃避/拖延羞耻循环',
        ShameScene.identityRebuild => '身份重建卡',
        ShameScene.shameDictionary => '羞耻语言词典',
        ShameScene.shameCompass => '羞耻罗盘识别',
        ShameScene.affectRecovery => '积极情感恢复',
        ShameScene.beingSeenTraining => '被看见训练',
        ShameScene.truePrideReview => '真实骄傲复盘',
        ShameScene.shameScript => '羞耻脚本地图',
      };

  String get inputPrompt => switch (this) {
        ShameScene.firstAid => '此刻脑中最刺痛、最想让你隐藏或逃走的那句话是什么？',
        ShameScene.eventRecord => '发生了什么？脑中最刺痛的一句话是什么？',
        ShameScene.healthyTransformation => '写下一句你正在用来攻击自己的话。',
        ShameScene.innerChild => '当前事件让你想起过去哪个相似场景？',
        ShameScene.innerCritic => '那个批判声音原话怎么说？它像谁的声音？',
        ShameScene.deniedPart => '你最不愿承认自己的哪一部分？它什么时候出现？',
        ShameScene.relationshipBoundary => '发生了什么关系事件？你被羞辱、做错了，还是不敢表达需要？',
        ShameScene.healthyResponsibility => '具体发生了什么行为？它给谁造成了什么影响？',
        ShameScene.todoGoal => '写下 Todo 或目标，以及它让你怎样评价自己。',
        ShameScene.dailyReview => '今天哪个时刻触发了羞耻？你做了或没做什么？',
        ShameScene.shameIdentification => '描述你的行为、态度、身体反应和脑中声音，让 AI 评估它与羞耻概念的一致程度。',
        ShameScene.shameNaming => '发生了什么？最刺痛的感觉是什么？你害怕别人怎么看你？',
        ShameScene.shameBinding => '这次羞耻似乎绑定了你的什么需要、情感或自我部分？',
        ShameScene.bridgeRepair => '这段关系里你期待什么回应？桥梁在哪里断了？',
        ShameScene.culturalShame => '这个羞耻是否和家庭、学校、性别、职业、学历、收入、年龄或社会比较有关？',
        ShameScene.avoidanceCycle => '写下回避、成瘾、刷手机、暴食、拖延或麻木前后的羞耻循环。',
        ShameScene.identityRebuild => '写下一个旧身份脚本，以及一个已经发生的小行动证据。',
        ShameScene.shameDictionary => '选择或描述一个想学习命名的羞耻词，例如暴露羞耻、能力羞耻或关系断裂羞耻。',
        ShameScene.shameCompass => '羞耻后你最自然的反应是什么：退缩、自责、回避，还是攻击他人？',
        ShameScene.affectRecovery => '你原本想靠近、表达、学习、连接或享受什么？它在哪里被打断了？',
        ShameScene.beingSeenTraining => '你希望哪一部分真实自我逐步被看见？现在最担心什么？',
        ShameScene.truePrideReview => '你已经完成了什么行动？行动前承受了什么羞耻、困难或不舒服？',
        ShameScene.shameScript => '写下一个反复出现的羞耻脚本，例如“我不能问问题”。',
      };
}

class ShameEvent {
  final String id;
  final int createdAt;
  final int intensity;
  final ShameScene scene;
  final String eventFact;
  final String emotion;
  final String bodyReaction;
  final String toxicLanguage;
  final String sourceVoice;
  final String healthyRewrite;
  final String userResponsibility;
  final String notUserResponsibility;
  final String minimumAction;
  final String fallbackAction;
  final String evidenceSentence;
  final String linkedGoalId;
  final bool actionCompleted;
  final String positiveAffect;
  final String originalDesire;
  final String blockingPoint;
  final String shameTrigger;
  final String selfContraction;
  final String compassPrimary;
  final String compassSecondary;
  final String compassShortFunction;
  final String compassLongCost;
  final String truePridePotential;
  final String abilityReflected;
  final String seenRiskLevel;
  final String shameFitLevel;
  final String shameFitExplanation;
  final String shameBehaviorSignals;
  final String shameAttitudeSignals;
  final String nonShamePossibilities;
  final String primaryShameName;
  final String namingSentence;
  final String boundPart;
  final String bridgeRupturePoint;
  final String newIdentityStatement;

  const ShameEvent({
    required this.id,
    required this.createdAt,
    required this.intensity,
    required this.scene,
    required this.eventFact,
    required this.emotion,
    required this.bodyReaction,
    required this.toxicLanguage,
    required this.sourceVoice,
    required this.healthyRewrite,
    required this.userResponsibility,
    required this.notUserResponsibility,
    required this.minimumAction,
    required this.fallbackAction,
    required this.evidenceSentence,
    this.linkedGoalId = '',
    this.actionCompleted = false,
    this.positiveAffect = '',
    this.originalDesire = '',
    this.blockingPoint = '',
    this.shameTrigger = '',
    this.selfContraction = '',
    this.compassPrimary = '',
    this.compassSecondary = '',
    this.compassShortFunction = '',
    this.compassLongCost = '',
    this.truePridePotential = '',
    this.abilityReflected = '',
    this.seenRiskLevel = '',
    this.shameFitLevel = '',
    this.shameFitExplanation = '',
    this.shameBehaviorSignals = '',
    this.shameAttitudeSignals = '',
    this.nonShamePossibilities = '',
    this.primaryShameName = '',
    this.namingSentence = '',
    this.boundPart = '',
    this.bridgeRupturePoint = '',
    this.newIdentityStatement = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'intensity': intensity,
        'scene': scene.key,
        'event_fact': eventFact,
        'emotion': emotion,
        'body_reaction': bodyReaction,
        'toxic_language': toxicLanguage,
        'source_voice': sourceVoice,
        'healthy_rewrite': healthyRewrite,
        'user_responsibility': userResponsibility,
        'not_user_responsibility': notUserResponsibility,
        'minimum_action': minimumAction,
        'fallback_action': fallbackAction,
        'evidence_sentence': evidenceSentence,
        'linked_goal_id': linkedGoalId,
        'action_completed': actionCompleted ? 1 : 0,
        'positive_affect': positiveAffect,
        'original_desire': originalDesire,
        'blocking_point': blockingPoint,
        'shame_trigger': shameTrigger,
        'self_contraction': selfContraction,
        'compass_primary': compassPrimary,
        'compass_secondary': compassSecondary,
        'compass_short_function': compassShortFunction,
        'compass_long_cost': compassLongCost,
        'true_pride_potential': truePridePotential,
        'ability_reflected': abilityReflected,
        'seen_risk_level': seenRiskLevel,
        'shame_fit_level': shameFitLevel,
        'shame_fit_explanation': shameFitExplanation,
        'shame_behavior_signals': shameBehaviorSignals,
        'shame_attitude_signals': shameAttitudeSignals,
        'non_shame_possibilities': nonShamePossibilities,
        'primary_shame_name': primaryShameName,
        'naming_sentence': namingSentence,
        'bound_part': boundPart,
        'bridge_rupture_point': bridgeRupturePoint,
        'new_identity_statement': newIdentityStatement,
      };

  factory ShameEvent.fromMap(Map<String, Object?> map) {
    final sceneName = '${map['scene'] ?? ''}';
    return ShameEvent(
      id: '${map['id']}',
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
      intensity: (map['intensity'] as num?)?.toInt() ?? 0,
      scene: ShameScene.values.firstWhere(
        (value) => value.key == sceneName,
        orElse: () => ShameScene.eventRecord,
      ),
      eventFact: '${map['event_fact'] ?? ''}',
      emotion: '${map['emotion'] ?? ''}',
      bodyReaction: '${map['body_reaction'] ?? ''}',
      toxicLanguage: '${map['toxic_language'] ?? ''}',
      sourceVoice: '${map['source_voice'] ?? ''}',
      healthyRewrite: '${map['healthy_rewrite'] ?? ''}',
      userResponsibility: '${map['user_responsibility'] ?? ''}',
      notUserResponsibility: '${map['not_user_responsibility'] ?? ''}',
      minimumAction: '${map['minimum_action'] ?? ''}',
      fallbackAction: '${map['fallback_action'] ?? ''}',
      evidenceSentence: '${map['evidence_sentence'] ?? ''}',
      linkedGoalId: '${map['linked_goal_id'] ?? ''}',
      actionCompleted: (map['action_completed'] as num?)?.toInt() == 1,
      positiveAffect: '${map['positive_affect'] ?? ''}',
      originalDesire: '${map['original_desire'] ?? ''}',
      blockingPoint: '${map['blocking_point'] ?? ''}',
      shameTrigger: '${map['shame_trigger'] ?? ''}',
      selfContraction: '${map['self_contraction'] ?? ''}',
      compassPrimary: '${map['compass_primary'] ?? ''}',
      compassSecondary: '${map['compass_secondary'] ?? ''}',
      compassShortFunction: '${map['compass_short_function'] ?? ''}',
      compassLongCost: '${map['compass_long_cost'] ?? ''}',
      truePridePotential: '${map['true_pride_potential'] ?? ''}',
      abilityReflected: '${map['ability_reflected'] ?? ''}',
      seenRiskLevel: '${map['seen_risk_level'] ?? ''}',
      shameFitLevel: '${map['shame_fit_level'] ?? ''}',
      shameFitExplanation: '${map['shame_fit_explanation'] ?? ''}',
      shameBehaviorSignals: '${map['shame_behavior_signals'] ?? ''}',
      shameAttitudeSignals: '${map['shame_attitude_signals'] ?? ''}',
      nonShamePossibilities: '${map['non_shame_possibilities'] ?? ''}',
      primaryShameName: '${map['primary_shame_name'] ?? ''}',
      namingSentence: '${map['naming_sentence'] ?? ''}',
      boundPart: '${map['bound_part'] ?? ''}',
      bridgeRupturePoint: '${map['bridge_rupture_point'] ?? ''}',
      newIdentityStatement: '${map['new_identity_statement'] ?? ''}',
    );
  }
}

class InnerVoice {
  final String id;
  final int createdAt;
  final String voiceText;
  final String sourceGuess;
  final String protectionIntent;
  final String toxicMethod;
  final String healthyRewrite;

  const InnerVoice({
    required this.id,
    required this.createdAt,
    required this.voiceText,
    required this.sourceGuess,
    required this.protectionIntent,
    required this.toxicMethod,
    required this.healthyRewrite,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'voice_text': voiceText,
        'source_guess': sourceGuess,
        'protection_intent': protectionIntent,
        'toxic_method': toxicMethod,
        'healthy_rewrite': healthyRewrite,
      };

  factory InnerVoice.fromMap(Map<String, Object?> map) => InnerVoice(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        voiceText: '${map['voice_text'] ?? ''}',
        sourceGuess: '${map['source_guess'] ?? ''}',
        protectionIntent: '${map['protection_intent'] ?? ''}',
        toxicMethod: '${map['toxic_method'] ?? ''}',
        healthyRewrite: '${map['healthy_rewrite'] ?? ''}',
      );
}

class GoalShameProfile {
  final String id;
  final int createdAt;
  final String goalText;
  final String shameTriggers;
  final String nonShameGoal;
  final String problemTreeJson;
  final String actionTreeJson;
  final String dailyAction;
  final String evidenceSentence;
  final String goalPositiveAffect;
  final String goalShameRisksJson;
  final String compassRisksJson;
  final String exposureLadderJson;
  final String truePrideStandard;

  const GoalShameProfile({
    required this.id,
    required this.createdAt,
    required this.goalText,
    required this.shameTriggers,
    required this.nonShameGoal,
    required this.problemTreeJson,
    required this.actionTreeJson,
    required this.dailyAction,
    required this.evidenceSentence,
    this.goalPositiveAffect = '',
    this.goalShameRisksJson = '[]',
    this.compassRisksJson = '[]',
    this.exposureLadderJson = '[]',
    this.truePrideStandard = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'goal_text': goalText,
        'shame_triggers': shameTriggers,
        'non_shame_goal': nonShameGoal,
        'problem_tree_json': problemTreeJson,
        'action_tree_json': actionTreeJson,
        'daily_action': dailyAction,
        'evidence_sentence': evidenceSentence,
        'goal_positive_affect': goalPositiveAffect,
        'goal_shame_risks_json': goalShameRisksJson,
        'compass_risks_json': compassRisksJson,
        'exposure_ladder_json': exposureLadderJson,
        'true_pride_standard': truePrideStandard,
      };

  factory GoalShameProfile.fromMap(Map<String, Object?> map) => GoalShameProfile(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        goalText: '${map['goal_text'] ?? ''}',
        shameTriggers: '${map['shame_triggers'] ?? ''}',
        nonShameGoal: '${map['non_shame_goal'] ?? ''}',
        problemTreeJson: '${map['problem_tree_json'] ?? '[]'}',
        actionTreeJson: '${map['action_tree_json'] ?? '[]'}',
        dailyAction: '${map['daily_action'] ?? ''}',
        evidenceSentence: '${map['evidence_sentence'] ?? ''}',
        goalPositiveAffect: '${map['goal_positive_affect'] ?? ''}',
        goalShameRisksJson: '${map['goal_shame_risks_json'] ?? '[]'}',
        compassRisksJson: '${map['compass_risks_json'] ?? '[]'}',
        exposureLadderJson: '${map['exposure_ladder_json'] ?? '[]'}',
        truePrideStandard: '${map['true_pride_standard'] ?? ''}',
      );
}

class EvidenceItem {
  final String id;
  final int createdAt;
  final String action;
  final String identityEvidence;
  final String valueAnchor;
  final String sourceEventId;
  final String shameRiskCarried;
  final String compassTurn;
  final String positiveAffectRestored;
  final String abilityReflected;
  final String truePrideSentence;

  const EvidenceItem({
    required this.id,
    required this.createdAt,
    required this.action,
    required this.identityEvidence,
    required this.valueAnchor,
    required this.sourceEventId,
    this.shameRiskCarried = '',
    this.compassTurn = '',
    this.positiveAffectRestored = '',
    this.abilityReflected = '',
    this.truePrideSentence = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'action': action,
        'identity_evidence': identityEvidence,
        'value_anchor': valueAnchor,
        'source_event_id': sourceEventId,
        'shame_risk_carried': shameRiskCarried,
        'compass_turn': compassTurn,
        'positive_affect_restored': positiveAffectRestored,
        'ability_reflected': abilityReflected,
        'true_pride_sentence': truePrideSentence,
      };

  factory EvidenceItem.fromMap(Map<String, Object?> map) => EvidenceItem(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        action: '${map['action'] ?? ''}',
        identityEvidence: '${map['identity_evidence'] ?? ''}',
        valueAnchor: '${map['value_anchor'] ?? ''}',
        sourceEventId: '${map['source_event_id'] ?? ''}',
        shameRiskCarried: '${map['shame_risk_carried'] ?? ''}',
        compassTurn: '${map['compass_turn'] ?? ''}',
        positiveAffectRestored: '${map['positive_affect_restored'] ?? ''}',
        abilityReflected: '${map['ability_reflected'] ?? ''}',
        truePrideSentence: '${map['true_pride_sentence'] ?? ''}',
      );
}

class ShameScript {
  final String id;
  final int createdAt;
  final String oldScript;
  final String triggerScene;
  final String protectionFunction;
  final String longTermCost;
  final String newScript;
  final String experimentAction;
  final String reviewEvidence;

  const ShameScript({
    required this.id,
    required this.createdAt,
    required this.oldScript,
    required this.triggerScene,
    required this.protectionFunction,
    required this.longTermCost,
    required this.newScript,
    required this.experimentAction,
    required this.reviewEvidence,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'old_script': oldScript,
        'trigger_scene': triggerScene,
        'protection_function': protectionFunction,
        'long_term_cost': longTermCost,
        'new_script': newScript,
        'experiment_action': experimentAction,
        'review_evidence': reviewEvidence,
      };

  factory ShameScript.fromMap(Map<String, Object?> map) => ShameScript(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        oldScript: '${map['old_script'] ?? ''}',
        triggerScene: '${map['trigger_scene'] ?? ''}',
        protectionFunction: '${map['protection_function'] ?? ''}',
        longTermCost: '${map['long_term_cost'] ?? ''}',
        newScript: '${map['new_script'] ?? ''}',
        experimentAction: '${map['experiment_action'] ?? ''}',
        reviewEvidence: '${map['review_evidence'] ?? ''}',
      );
}

class AffectRecoveryLog {
  final String id;
  final int createdAt;
  final String affectType;
  final String blockedByShame;
  final String recoveryAction;
  final String microJoy;
  final bool sharedOrNot;
  final String truePrideAfterAction;

  const AffectRecoveryLog({
    required this.id,
    required this.createdAt,
    required this.affectType,
    required this.blockedByShame,
    required this.recoveryAction,
    required this.microJoy,
    required this.sharedOrNot,
    required this.truePrideAfterAction,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'affect_type': affectType,
        'blocked_by_shame': blockedByShame,
        'recovery_action': recoveryAction,
        'micro_joy': microJoy,
        'shared_or_not': sharedOrNot ? 1 : 0,
        'true_pride_after_action': truePrideAfterAction,
      };

  factory AffectRecoveryLog.fromMap(Map<String, Object?> map) => AffectRecoveryLog(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        affectType: '${map['affect_type'] ?? ''}',
        blockedByShame: '${map['blocked_by_shame'] ?? ''}',
        recoveryAction: '${map['recovery_action'] ?? ''}',
        microJoy: '${map['micro_joy'] ?? ''}',
        sharedOrNot: (map['shared_or_not'] as num?)?.toInt() == 1,
        truePrideAfterAction: '${map['true_pride_after_action'] ?? ''}',
      );
}

class ShameActionOption {
  final String name;
  final String purpose;
  final List<String> steps;
  final String difficulty;
  final String timeRequired;
  final String evidenceAfterDone;
  final String shameExposureLevel;
  final String compassRisk;
  final String truePrideAfterDone;

  const ShameActionOption({
    required this.name,
    required this.purpose,
    required this.steps,
    required this.difficulty,
    required this.timeRequired,
    required this.evidenceAfterDone,
    this.shameExposureLevel = '',
    this.compassRisk = '',
    this.truePrideAfterDone = '',
  });

  factory ShameActionOption.fromJson(Map<String, dynamic> json) =>
      ShameActionOption(
        name: '${json['name'] ?? ''}',
        purpose: '${json['purpose'] ?? ''}',
        steps: _strings(json['steps']),
        difficulty: '${json['difficulty'] ?? '低'}',
        timeRequired: '${json['time_required'] ?? ''}',
        evidenceAfterDone: '${json['evidence_after_done'] ?? ''}',
        shameExposureLevel: '${json['shame_exposure_level'] ?? ''}',
        compassRisk: '${json['compass_risk'] ?? ''}',
        truePrideAfterDone: '${json['true_pride_after_done'] ?? ''}',
      );
}

class ShameAiResult {
  final ShameScene scene;
  final String valueAnchor;
  final String summary;
  final String eventFact;
  final List<String> emotions;
  final List<String> bodyReactions;
  final List<String> toxicLanguages;
  final List<String> shamePatterns;
  final String healthyMessage;
  final String shameFitLevel;
  final String shameFitScore;
  final String shameFitExplanation;
  final List<String> shameBehaviorSignals;
  final List<String> shameAttitudeSignals;
  final List<String> shameBodySignals;
  final List<String> shameLanguageSignals;
  final List<String> nonShamePossibilities;
  final String identificationSummary;
  final String safetyHasUrgentRisk;
  final String riskNote;
  final String primaryShameName;
  final List<String> secondaryShameNames;
  final List<String> shameTexture;
  final String dignityWound;
  final String belongingRupture;
  final String beingSeenFear;
  final String namingSentence;
  final String namingConfidence;
  final String boundPart;
  final String normalNeed;
  final String shameContamination;
  final String immatureExpression;
  final String matureExpression;
  final String unbindingAction;
  final String reclaimingSentence;
  final String bridgeRelevant;
  final String relationshipExpectation;
  final String bridgeRupturePoint;
  final String internalizedMessage;
  final String repairPossibility;
  final String caringRepairDirection;
  final String oldIdentityScript;
  final String identityShameName;
  final String identityExperienceReframe;
  final String reclaimedSelfPart;
  final String newIdentityStatement;
  final String identityEvidenceSentence;
  final String identityTruePrideSentence;
  final List<String> facts;
  final List<String> interpretations;
  final List<String> identityJudgments;
  final List<String> userResponsibilities;
  final List<String> notUserResponsibilities;
  final List<String> repairableParts;
  final List<String> uncontrollableParts;
  final String toxicVersion;
  final String healthyVersion;
  final String identitySentence;
  final String sourceVoice;
  final String protectionIntent;
  final String boundarySentence;
  final List<ShameActionOption> actionOptions;
  final String minimumAction;
  final String minimumTime;
  final String successStandard;
  final String fallbackAction;
  final List<String> reflectionQuestions;
  final String evidenceSentence;
  final String userChoicePrompt;
  final List<Map<String, dynamic>> problemTree;
  final List<Map<String, dynamic>> actionTree;
  final List<String> originalPositiveAffects;
  final String originalDesire;
  final String blockingPoint;
  final String shameTrigger;
  final List<String> selfContractions;
  final String compassPrimary;
  final String compassSecondary;
  final List<String> compassEvidence;
  final String compassShortFunction;
  final String compassLongCost;
  final String compassTurningDirection;
  final String interestRecoveryAction;
  final String joyRecoveryAction;
  final String connectionAction;
  final String exposureLevel;
  final String affectRecoveryWhy;
  final String minimumShameRisk;
  final String minimumTruePrideStandard;
  final String truePrideAction;
  final String difficultyCarried;
  final String abilityReflected;
  final String positiveAffectRestored;
  final String truePrideSentence;
  final String safetyNote;
  final bool usedFallback;
  final String provider;
  final String modelLabel;
  final String fallbackReason;
  final String rawResponse;

  const ShameAiResult({
    required this.scene,
    required this.valueAnchor,
    required this.summary,
    required this.eventFact,
    required this.emotions,
    required this.bodyReactions,
    required this.toxicLanguages,
    required this.shamePatterns,
    required this.healthyMessage,
    this.shameFitLevel = '',
    this.shameFitScore = '',
    this.shameFitExplanation = '',
    this.shameBehaviorSignals = const [],
    this.shameAttitudeSignals = const [],
    this.shameBodySignals = const [],
    this.shameLanguageSignals = const [],
    this.nonShamePossibilities = const [],
    this.identificationSummary = '',
    this.safetyHasUrgentRisk = '',
    this.riskNote = '',
    this.primaryShameName = '',
    this.secondaryShameNames = const [],
    this.shameTexture = const [],
    this.dignityWound = '',
    this.belongingRupture = '',
    this.beingSeenFear = '',
    this.namingSentence = '',
    this.namingConfidence = '',
    this.boundPart = '',
    this.normalNeed = '',
    this.shameContamination = '',
    this.immatureExpression = '',
    this.matureExpression = '',
    this.unbindingAction = '',
    this.reclaimingSentence = '',
    this.bridgeRelevant = '',
    this.relationshipExpectation = '',
    this.bridgeRupturePoint = '',
    this.internalizedMessage = '',
    this.repairPossibility = '',
    this.caringRepairDirection = '',
    this.oldIdentityScript = '',
    this.identityShameName = '',
    this.identityExperienceReframe = '',
    this.reclaimedSelfPart = '',
    this.newIdentityStatement = '',
    this.identityEvidenceSentence = '',
    this.identityTruePrideSentence = '',
    required this.facts,
    required this.interpretations,
    required this.identityJudgments,
    required this.userResponsibilities,
    required this.notUserResponsibilities,
    required this.repairableParts,
    required this.uncontrollableParts,
    required this.toxicVersion,
    required this.healthyVersion,
    required this.identitySentence,
    required this.sourceVoice,
    required this.protectionIntent,
    required this.boundarySentence,
    required this.actionOptions,
    required this.minimumAction,
    required this.minimumTime,
    required this.successStandard,
    required this.fallbackAction,
    required this.reflectionQuestions,
    required this.evidenceSentence,
    required this.userChoicePrompt,
    this.problemTree = const [],
    this.actionTree = const [],
    this.originalPositiveAffects = const [],
    this.originalDesire = '',
    this.blockingPoint = '',
    this.shameTrigger = '',
    this.selfContractions = const [],
    this.compassPrimary = '',
    this.compassSecondary = '',
    this.compassEvidence = const [],
    this.compassShortFunction = '',
    this.compassLongCost = '',
    this.compassTurningDirection = '',
    this.interestRecoveryAction = '',
    this.joyRecoveryAction = '',
    this.connectionAction = '',
    this.exposureLevel = '',
    this.affectRecoveryWhy = '',
    this.minimumShameRisk = '',
    this.minimumTruePrideStandard = '',
    this.truePrideAction = '',
    this.difficultyCarried = '',
    this.abilityReflected = '',
    this.positiveAffectRestored = '',
    this.truePrideSentence = '',
    this.safetyNote = '',
    this.usedFallback = false,
    this.provider = '',
    this.modelLabel = '',
    this.fallbackReason = '',
    this.rawResponse = '',
  });

  factory ShameAiResult.fromJson(
    Map<String, dynamic> json,
    ShameScene fallbackScene,
  ) {
    final safety = _map(json['safety_check']);
    final core = _map(json['core_recognition']);
    final identification = _map(json['shame_identification']);
    final naming = _map(json['shame_naming']);
    final bind = _map(json['shame_bind']);
    final bridge = _map(json['interpersonal_bridge']);
    final identityCard = _map(json['identity_card']);
    final factStory = _map(json['fact_vs_story']).isNotEmpty
        ? _map(json['fact_vs_story'])
        : _map(json['fact_story_identity']);
    final responsibility = _map(json['responsibility_boundary']);
    final reframe = _map(json['reframe']).isNotEmpty
        ? _map(json['reframe'])
        : _map(json['caring_reframe']);
    final minimum = _map(json['today_minimum_action']);
    final externalization = _map(json['voice_externalization']);
    final affectBlock = _map(json['positive_affect_block']);
    final compass = _map(json['shame_compass']);
    final affectRecovery = _map(json['affect_recovery']);
    final pride = _map(json['true_pride_record']);
    final sceneName = '${json['scene_key'] ?? ''}';
    final scene = ShameScene.values.firstWhere(
      (value) => value.key == sceneName,
      orElse: () => fallbackScene,
    );
    final rawOptions = json['action_options'];
    final options = rawOptions is List
        ? rawOptions
            .whereType<Map>()
            .map((item) => ShameActionOption.fromJson(
                Map<String, dynamic>.from(item)))
            .toList()
        : <ShameActionOption>[];
    return ShameAiResult(
      scene: scene,
      valueAnchor: '${json['value_anchor'] ?? '我不是错误本身'}',
      summary: '${json['user_input_summary'] ?? ''}',
      eventFact: '${core['event_fact'] ?? factStory['facts'] ?? ''}',
      emotions: _strings(core['emotion']),
      bodyReactions: _strings(core['body_reaction']),
      toxicLanguages: _strings(core['toxic_shame_language']),
      shamePatterns: _strings(core['shame_patterns']),
      healthyMessage: '${core['healthy_shame_message'] ?? reframe['healthy_shame_message'] ?? ''}',
      shameFitLevel: '${identification['fit_level'] ?? ''}',
      shameFitScore: '${identification['fit_score'] ?? ''}',
      shameFitExplanation: '${identification['fit_explanation'] ?? ''}',
      shameBehaviorSignals: _strings(identification['behavior_signals']),
      shameAttitudeSignals: _strings(identification['attitude_signals']),
      shameBodySignals: _strings(identification['body_signals']),
      shameLanguageSignals: _strings(identification['language_signals']),
      nonShamePossibilities: _strings(identification['non_shame_possibilities']),
      identificationSummary: '${identification['identification_summary'] ?? ''}',
      safetyHasUrgentRisk: '${safety['has_urgent_risk'] ?? ''}',
      riskNote: '${safety['risk_note'] ?? ''}',
      primaryShameName: '${naming['primary_shame_name'] ?? ''}',
      secondaryShameNames: _strings(naming['secondary_shame_names']),
      shameTexture: _strings(naming['shame_texture']),
      dignityWound: '${naming['dignity_wound'] ?? ''}',
      belongingRupture: '${naming['belonging_rupture'] ?? ''}',
      beingSeenFear: '${naming['being_seen_fear'] ?? ''}',
      namingSentence: '${naming['naming_sentence'] ?? ''}',
      namingConfidence: '${naming['naming_confidence'] ?? ''}',
      boundPart: '${bind['bound_part'] ?? ''}',
      normalNeed: '${bind['normal_need'] ?? ''}',
      shameContamination: '${bind['shame_contamination'] ?? ''}',
      immatureExpression: '${bind['immature_expression'] ?? ''}',
      matureExpression: '${bind['mature_expression'] ?? ''}',
      unbindingAction: '${bind['unbinding_action'] ?? ''}',
      reclaimingSentence: '${bind['reclaiming_sentence'] ?? ''}',
      bridgeRelevant: '${bridge['is_relevant'] ?? ''}',
      relationshipExpectation: '${bridge['relationship_expectation'] ?? ''}',
      bridgeRupturePoint: '${bridge['rupture_point'] ?? ''}',
      internalizedMessage: '${bridge['internalized_message'] ?? ''}',
      repairPossibility: '${bridge['repair_possibility'] ?? ''}',
      caringRepairDirection: '${bridge['caring_repair_direction'] ?? ''}',
      oldIdentityScript: '${identityCard['old_identity_script'] ?? ''}',
      identityShameName: '${identityCard['shame_name'] ?? ''}',
      identityExperienceReframe: '${identityCard['experience_reframe'] ?? ''}',
      reclaimedSelfPart: '${identityCard['reclaimed_self_part'] ?? ''}',
      newIdentityStatement: '${identityCard['new_identity_statement'] ?? ''}',
      identityEvidenceSentence: '${identityCard['evidence_sentence'] ?? ''}',
      identityTruePrideSentence: '${identityCard['true_pride_sentence'] ?? ''}',
      facts: _strings(factStory['facts']),
      interpretations: _strings(factStory['interpretations']),
      identityJudgments: _strings(factStory['identity_judgments']),
      userResponsibilities: _strings(responsibility['user_responsibility']),
      notUserResponsibilities:
          _strings(responsibility['not_user_responsibility']),
      repairableParts: _strings(responsibility['repairable_part']),
      uncontrollableParts: _strings(responsibility['uncontrollable_part']),
      toxicVersion: '${reframe['toxic_version'] ?? ''}',
      healthyVersion: '${reframe['healthy_version'] ?? reframe['healthy_shame_message'] ?? reframe['not_cheap_comfort'] ?? ''}',
      identitySentence: '${reframe['new_identity_sentence'] ?? ''}',
      sourceVoice: '${externalization['source_voice'] ?? ''}',
      protectionIntent: '${externalization['protection_intent'] ?? ''}',
      boundarySentence: '${json['boundary_sentence'] ?? responsibility['boundary_sentence'] ?? ''}',
      actionOptions: options,
      minimumAction: '${minimum['action'] ?? ''}',
      minimumTime: '${minimum['time_required'] ?? ''}',
      successStandard: '${minimum['success_standard'] ?? ''}',
      fallbackAction: '${minimum['fallback'] ?? ''}',
      reflectionQuestions: _strings(json['reflection_questions']),
      evidenceSentence: '${json['evidence_sentence'] ?? ''}',
      userChoicePrompt: '${json['user_choice_prompt'] ?? ''}',
      problemTree: _mapList(json['problem_tree']),
      actionTree: _mapList(json['action_tree']),
      originalPositiveAffects: _strings(affectBlock['original_positive_affect']),
      originalDesire: '${affectBlock['original_desire'] ?? ''}',
      blockingPoint: '${affectBlock['blocking_point'] ?? ''}',
      shameTrigger: '${affectBlock['shame_trigger'] ?? ''}',
      selfContractions: _strings(affectBlock['self_contraction']),
      compassPrimary: '${compass['primary_direction'] ?? ''}',
      compassSecondary: '${compass['secondary_direction'] ?? ''}',
      compassEvidence: _strings(compass['evidence']),
      compassShortFunction: '${compass['short_term_function'] ?? ''}',
      compassLongCost: '${compass['long_term_cost'] ?? ''}',
      compassTurningDirection: '${compass['turning_direction'] ?? ''}',
      interestRecoveryAction: '${affectRecovery['interest_recovery_action'] ?? ''}',
      joyRecoveryAction: '${affectRecovery['joy_recovery_action'] ?? ''}',
      connectionAction: '${affectRecovery['connection_action'] ?? ''}',
      exposureLevel: '${affectRecovery['exposure_level'] ?? ''}',
      affectRecoveryWhy: '${affectRecovery['why_it_matters'] ?? ''}',
      minimumShameRisk: '${minimum['shame_risk'] ?? ''}',
      minimumTruePrideStandard: '${minimum['true_pride_standard'] ?? ''}',
      truePrideAction: '${pride['action_done_or_to_do'] ?? ''}',
      difficultyCarried: '${pride['difficulty_carried'] ?? ''}',
      abilityReflected: '${pride['ability_reflected'] ?? ''}',
      positiveAffectRestored: '${pride['positive_affect_restored'] ?? ''}',
      truePrideSentence: '${pride['true_pride_sentence'] ?? ''}',
      safetyNote: '${json['safety_note'] ?? ''}',
    );
  }

  ShameAiResult copyWithSource({
    required bool usedFallback,
    required String provider,
    required String modelLabel,
    String fallbackReason = '',
    String rawResponse = '',
  }) =>
      ShameAiResult(
        scene: scene,
        valueAnchor: valueAnchor,
        summary: summary,
        eventFact: eventFact,
        emotions: emotions,
        bodyReactions: bodyReactions,
        toxicLanguages: toxicLanguages,
        shamePatterns: shamePatterns,
        healthyMessage: healthyMessage,
        shameFitLevel: shameFitLevel,
        shameFitScore: shameFitScore,
        shameFitExplanation: shameFitExplanation,
        shameBehaviorSignals: shameBehaviorSignals,
        shameAttitudeSignals: shameAttitudeSignals,
        shameBodySignals: shameBodySignals,
        shameLanguageSignals: shameLanguageSignals,
        nonShamePossibilities: nonShamePossibilities,
        identificationSummary: identificationSummary,
        safetyHasUrgentRisk: safetyHasUrgentRisk,
        riskNote: riskNote,
        primaryShameName: primaryShameName,
        secondaryShameNames: secondaryShameNames,
        shameTexture: shameTexture,
        dignityWound: dignityWound,
        belongingRupture: belongingRupture,
        beingSeenFear: beingSeenFear,
        namingSentence: namingSentence,
        namingConfidence: namingConfidence,
        boundPart: boundPart,
        normalNeed: normalNeed,
        shameContamination: shameContamination,
        immatureExpression: immatureExpression,
        matureExpression: matureExpression,
        unbindingAction: unbindingAction,
        reclaimingSentence: reclaimingSentence,
        bridgeRelevant: bridgeRelevant,
        relationshipExpectation: relationshipExpectation,
        bridgeRupturePoint: bridgeRupturePoint,
        internalizedMessage: internalizedMessage,
        repairPossibility: repairPossibility,
        caringRepairDirection: caringRepairDirection,
        oldIdentityScript: oldIdentityScript,
        identityShameName: identityShameName,
        identityExperienceReframe: identityExperienceReframe,
        reclaimedSelfPart: reclaimedSelfPart,
        newIdentityStatement: newIdentityStatement,
        identityEvidenceSentence: identityEvidenceSentence,
        identityTruePrideSentence: identityTruePrideSentence,
        facts: facts,
        interpretations: interpretations,
        identityJudgments: identityJudgments,
        userResponsibilities: userResponsibilities,
        notUserResponsibilities: notUserResponsibilities,
        repairableParts: repairableParts,
        uncontrollableParts: uncontrollableParts,
        toxicVersion: toxicVersion,
        healthyVersion: healthyVersion,
        identitySentence: identitySentence,
        sourceVoice: sourceVoice,
        protectionIntent: protectionIntent,
        boundarySentence: boundarySentence,
        actionOptions: actionOptions,
        minimumAction: minimumAction,
        minimumTime: minimumTime,
        successStandard: successStandard,
        fallbackAction: fallbackAction,
        reflectionQuestions: reflectionQuestions,
        evidenceSentence: evidenceSentence,
        userChoicePrompt: userChoicePrompt,
        problemTree: problemTree,
        actionTree: actionTree,
        originalPositiveAffects: originalPositiveAffects,
        originalDesire: originalDesire,
        blockingPoint: blockingPoint,
        shameTrigger: shameTrigger,
        selfContractions: selfContractions,
        compassPrimary: compassPrimary,
        compassSecondary: compassSecondary,
        compassEvidence: compassEvidence,
        compassShortFunction: compassShortFunction,
        compassLongCost: compassLongCost,
        compassTurningDirection: compassTurningDirection,
        interestRecoveryAction: interestRecoveryAction,
        joyRecoveryAction: joyRecoveryAction,
        connectionAction: connectionAction,
        exposureLevel: exposureLevel,
        affectRecoveryWhy: affectRecoveryWhy,
        minimumShameRisk: minimumShameRisk,
        minimumTruePrideStandard: minimumTruePrideStandard,
        truePrideAction: truePrideAction,
        difficultyCarried: difficultyCarried,
        abilityReflected: abilityReflected,
        positiveAffectRestored: positiveAffectRestored,
        truePrideSentence: truePrideSentence,
        safetyNote: safetyNote,
        usedFallback: usedFallback,
        provider: provider,
        modelLabel: modelLabel,
        fallbackReason: fallbackReason,
        rawResponse: rawResponse,
      );

  bool get hasMeaningfulAiContent =>
      eventFact.trim().isNotEmpty &&
      shameFitLevel.trim().isNotEmpty &&
      identificationSummary.trim().isNotEmpty &&
      primaryShameName.trim().isNotEmpty &&
      namingSentence.trim().isNotEmpty &&
      healthyVersion.trim().isNotEmpty &&
      minimumAction.trim().isNotEmpty &&
      evidenceSentence.trim().isNotEmpty;
}

List<String> _strings(dynamic value) => value is List
    ? value.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList()
    : <String>[];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> extractJsonObject(String raw) {
  final text = raw
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '');
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    final candidate = _firstBalancedJsonObject(text);
    if (candidate.isEmpty) rethrow;
    decoded = jsonDecode(candidate);
  }
  if (decoded is! Map) return <String, dynamic>{};
  var result = Map<String, dynamic>.from(decoded);
  for (final key in const ['data', 'result', 'output', 'response']) {
    final nested = result[key];
    if (nested is Map && !result.containsKey('core_recognition')) {
      result = Map<String, dynamic>.from(nested);
    }
  }
  return result;
}

String _firstBalancedJsonObject(String source) {
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (start < 0) {
      if (char == '{') {
        start = index;
        depth = 1;
      }
      continue;
    }
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(start, index + 1);
    }
  }
  return '';
}
