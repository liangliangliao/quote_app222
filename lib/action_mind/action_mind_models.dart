
import 'dart:convert';

List<String> _stringList(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return _stringList(decoded);
    } catch (_) {}
    return text.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  return <String>[raw.toString()];
}

Map<String, dynamic> _map(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return _map(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

int _intValue(dynamic raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString()) ?? fallback;
}

bool _boolValue(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = (raw ?? '').toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes' || text == 'completed';
}

class ActionMindProfile {
  final List<String> coreValues;
  final String identityDirection;
  final String lifeDomains;
  final String intrinsicAnchor;
  final String externalPressures;
  final String commonDefenses;
  final String commonEmotions;
  final String environmentCues;
  final String socialPatterns;
  final int updatedAtMs;

  const ActionMindProfile({
    this.coreValues = const <String>[],
    this.identityDirection = '',
    this.lifeDomains = '',
    this.intrinsicAnchor = '',
    this.externalPressures = '',
    this.commonDefenses = '',
    this.commonEmotions = '',
    this.environmentCues = '',
    this.socialPatterns = '',
    this.updatedAtMs = 0,
  });

  ActionMindProfile copyWith({
    List<String>? coreValues,
    String? identityDirection,
    String? lifeDomains,
    String? intrinsicAnchor,
    String? externalPressures,
    String? commonDefenses,
    String? commonEmotions,
    String? environmentCues,
    String? socialPatterns,
    int? updatedAtMs,
  }) => ActionMindProfile(
        coreValues: coreValues ?? this.coreValues,
        identityDirection: identityDirection ?? this.identityDirection,
        lifeDomains: lifeDomains ?? this.lifeDomains,
        intrinsicAnchor: intrinsicAnchor ?? this.intrinsicAnchor,
        externalPressures: externalPressures ?? this.externalPressures,
        commonDefenses: commonDefenses ?? this.commonDefenses,
        commonEmotions: commonEmotions ?? this.commonEmotions,
        environmentCues: environmentCues ?? this.environmentCues,
        socialPatterns: socialPatterns ?? this.socialPatterns,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'core_values': coreValues,
        'identity_direction': identityDirection,
        'life_domains': lifeDomains,
        'intrinsic_anchor': intrinsicAnchor,
        'external_pressures': externalPressures,
        'common_defenses': commonDefenses,
        'common_emotions': commonEmotions,
        'environment_cues': environmentCues,
        'social_patterns': socialPatterns,
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  factory ActionMindProfile.fromJson(Map<String, dynamic> json) => ActionMindProfile(
        coreValues: _stringList(json['core_values']),
        identityDirection: (json['identity_direction'] ?? '').toString(),
        lifeDomains: (json['life_domains'] ?? '').toString(),
        intrinsicAnchor: (json['intrinsic_anchor'] ?? '').toString(),
        externalPressures: (json['external_pressures'] ?? '').toString(),
        commonDefenses: (json['common_defenses'] ?? '').toString(),
        commonEmotions: (json['common_emotions'] ?? '').toString(),
        environmentCues: (json['environment_cues'] ?? '').toString(),
        socialPatterns: (json['social_patterns'] ?? '').toString(),
        updatedAtMs: _intValue(json['updated_at_ms']),
      );

  factory ActionMindProfile.fromRaw(String raw) {
    if (raw.trim().isEmpty) return const ActionMindProfile();
    try {
      return ActionMindProfile.fromJson(_map(raw));
    } catch (_) {
      return const ActionMindProfile();
    }
  }
}

class ActionMindGoal {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final String title;
  final String rawWish;
  final String deepGoal;
  final String goalSource;
  final String intrinsicExternal;
  final String approachAvoidance;
  final String idealOught;
  final String identityLayer;
  final String valueLayer;
  final String projectLayer;
  final String actionLayer;
  final String obstacles;
  final String conflicts;
  final String status;
  final int autonomyScore;
  final int meaningScore;
  final int feasibilityScore;
  final int resourceFitScore;

  const ActionMindGoal({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.title = '',
    this.rawWish = '',
    this.deepGoal = '',
    this.goalSource = '',
    this.intrinsicExternal = '',
    this.approachAvoidance = '',
    this.idealOught = '',
    this.identityLayer = '',
    this.valueLayer = '',
    this.projectLayer = '',
    this.actionLayer = '',
    this.obstacles = '',
    this.conflicts = '',
    this.status = 'active',
    this.autonomyScore = 5,
    this.meaningScore = 5,
    this.feasibilityScore = 5,
    this.resourceFitScore = 5,
  });

  bool get isActive => status != 'archived' && status != 'completed' && status != 'paused';

  ActionMindGoal copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? title,
    String? rawWish,
    String? deepGoal,
    String? goalSource,
    String? intrinsicExternal,
    String? approachAvoidance,
    String? idealOught,
    String? identityLayer,
    String? valueLayer,
    String? projectLayer,
    String? actionLayer,
    String? obstacles,
    String? conflicts,
    String? status,
    int? autonomyScore,
    int? meaningScore,
    int? feasibilityScore,
    int? resourceFitScore,
  }) => ActionMindGoal(
        id: id ?? this.id,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        title: title ?? this.title,
        rawWish: rawWish ?? this.rawWish,
        deepGoal: deepGoal ?? this.deepGoal,
        goalSource: goalSource ?? this.goalSource,
        intrinsicExternal: intrinsicExternal ?? this.intrinsicExternal,
        approachAvoidance: approachAvoidance ?? this.approachAvoidance,
        idealOught: idealOught ?? this.idealOught,
        identityLayer: identityLayer ?? this.identityLayer,
        valueLayer: valueLayer ?? this.valueLayer,
        projectLayer: projectLayer ?? this.projectLayer,
        actionLayer: actionLayer ?? this.actionLayer,
        obstacles: obstacles ?? this.obstacles,
        conflicts: conflicts ?? this.conflicts,
        status: status ?? this.status,
        autonomyScore: autonomyScore ?? this.autonomyScore,
        meaningScore: meaningScore ?? this.meaningScore,
        feasibilityScore: feasibilityScore ?? this.feasibilityScore,
        resourceFitScore: resourceFitScore ?? this.resourceFitScore,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'title': title,
        'raw_wish': rawWish,
        'deep_goal': deepGoal,
        'goal_source': goalSource,
        'intrinsic_external': intrinsicExternal,
        'approach_avoidance': approachAvoidance,
        'ideal_ought': idealOught,
        'identity_layer': identityLayer,
        'value_layer': valueLayer,
        'project_layer': projectLayer,
        'action_layer': actionLayer,
        'obstacles': obstacles,
        'conflicts': conflicts,
        'status': status,
        'autonomy_score': autonomyScore,
        'meaning_score': meaningScore,
        'feasibility_score': feasibilityScore,
        'resource_fit_score': resourceFitScore,
      };

  factory ActionMindGoal.fromJson(Map<String, dynamic> json) => ActionMindGoal(
        id: _intValue(json['id']),
        createdAtMs: _intValue(json['created_at_ms']),
        updatedAtMs: _intValue(json['updated_at_ms']),
        title: (json['title'] ?? '').toString(),
        rawWish: (json['raw_wish'] ?? '').toString(),
        deepGoal: (json['deep_goal'] ?? '').toString(),
        goalSource: (json['goal_source'] ?? '').toString(),
        intrinsicExternal: (json['intrinsic_external'] ?? '').toString(),
        approachAvoidance: (json['approach_avoidance'] ?? '').toString(),
        idealOught: (json['ideal_ought'] ?? '').toString(),
        identityLayer: (json['identity_layer'] ?? '').toString(),
        valueLayer: (json['value_layer'] ?? '').toString(),
        projectLayer: (json['project_layer'] ?? '').toString(),
        actionLayer: (json['action_layer'] ?? '').toString(),
        obstacles: (json['obstacles'] ?? '').toString(),
        conflicts: (json['conflicts'] ?? '').toString(),
        status: (json['status'] ?? 'active').toString(),
        autonomyScore: _intValue(json['autonomy_score'], 5),
        meaningScore: _intValue(json['meaning_score'], 5),
        feasibilityScore: _intValue(json['feasibility_score'], 5),
        resourceFitScore: _intValue(json['resource_fit_score'], 5),
      );

  factory ActionMindGoal.fromRaw(String raw) => ActionMindGoal.fromJson(_map(raw));
}

class ActionMindPlan {
  final int id;
  final int goalId;
  final int createdAtMs;
  final int updatedAtMs;
  final String trigger;
  final String action;
  final String obstaclePlan;
  final String temptationPlan;
  final String minimumAction;
  final String standardAction;
  final String challengeAction;
  final String environmentCue;
  final String status;

  const ActionMindPlan({
    this.id = 0,
    this.goalId = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.trigger = '',
    this.action = '',
    this.obstaclePlan = '',
    this.temptationPlan = '',
    this.minimumAction = '',
    this.standardAction = '',
    this.challengeAction = '',
    this.environmentCue = '',
    this.status = 'active',
  });

  bool get hasPlan => trigger.trim().isNotEmpty || action.trim().isNotEmpty || minimumAction.trim().isNotEmpty;
  String get ifThen => '如果$trigger，我就$action。';

  ActionMindPlan copyWith({
    int? id,
    int? goalId,
    int? createdAtMs,
    int? updatedAtMs,
    String? trigger,
    String? action,
    String? obstaclePlan,
    String? temptationPlan,
    String? minimumAction,
    String? standardAction,
    String? challengeAction,
    String? environmentCue,
    String? status,
  }) => ActionMindPlan(
        id: id ?? this.id,
        goalId: goalId ?? this.goalId,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        trigger: trigger ?? this.trigger,
        action: action ?? this.action,
        obstaclePlan: obstaclePlan ?? this.obstaclePlan,
        temptationPlan: temptationPlan ?? this.temptationPlan,
        minimumAction: minimumAction ?? this.minimumAction,
        standardAction: standardAction ?? this.standardAction,
        challengeAction: challengeAction ?? this.challengeAction,
        environmentCue: environmentCue ?? this.environmentCue,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'trigger': trigger,
        'action': action,
        'obstacle_plan': obstaclePlan,
        'temptation_plan': temptationPlan,
        'minimum_action': minimumAction,
        'standard_action': standardAction,
        'challenge_action': challengeAction,
        'environment_cue': environmentCue,
        'status': status,
      };

  String encode() => jsonEncode(toJson());

  factory ActionMindPlan.fromJson(Map<String, dynamic> json) => ActionMindPlan(
        id: _intValue(json['id']),
        goalId: _intValue(json['goal_id']),
        createdAtMs: _intValue(json['created_at_ms']),
        updatedAtMs: _intValue(json['updated_at_ms']),
        trigger: (json['trigger'] ?? '').toString(),
        action: (json['action'] ?? '').toString(),
        obstaclePlan: (json['obstacle_plan'] ?? '').toString(),
        temptationPlan: (json['temptation_plan'] ?? '').toString(),
        minimumAction: (json['minimum_action'] ?? '').toString(),
        standardAction: (json['standard_action'] ?? '').toString(),
        challengeAction: (json['challenge_action'] ?? '').toString(),
        environmentCue: (json['environment_cue'] ?? '').toString(),
        status: (json['status'] ?? 'active').toString(),
      );
}

class ActionMindEmotionLog {
  final int id;
  final int createdAtMs;
  final String emotion;
  final String trigger;
  final String blockedGoal;
  final String signal;
  final String recoveryAction;
  final String nextAction;

  const ActionMindEmotionLog({
    this.id = 0,
    this.createdAtMs = 0,
    this.emotion = '',
    this.trigger = '',
    this.blockedGoal = '',
    this.signal = '',
    this.recoveryAction = '',
    this.nextAction = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'emotion': emotion,
        'trigger': trigger,
        'blocked_goal': blockedGoal,
        'signal': signal,
        'recovery_action': recoveryAction,
        'next_action': nextAction,
      };

  factory ActionMindEmotionLog.fromJson(Map<String, dynamic> json) => ActionMindEmotionLog(
        id: _intValue(json['id']),
        createdAtMs: _intValue(json['created_at_ms']),
        emotion: (json['emotion'] ?? '').toString(),
        trigger: (json['trigger'] ?? '').toString(),
        blockedGoal: (json['blocked_goal'] ?? '').toString(),
        signal: (json['signal'] ?? '').toString(),
        recoveryAction: (json['recovery_action'] ?? '').toString(),
        nextAction: (json['next_action'] ?? '').toString(),
      );
}

class ActionMindReview {
  final int id;
  final int goalId;
  final int planId;
  final int createdAtMs;
  final bool completed;
  final String gap;
  final String cause;
  final String emotionFeedback;
  final String learned;
  final String nextIfThen;

  const ActionMindReview({
    this.id = 0,
    this.goalId = 0,
    this.planId = 0,
    this.createdAtMs = 0,
    this.completed = false,
    this.gap = '',
    this.cause = '',
    this.emotionFeedback = '',
    this.learned = '',
    this.nextIfThen = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'goal_id': goalId,
        'plan_id': planId,
        'created_at_ms': createdAtMs,
        'completed': completed,
        'gap': gap,
        'cause': cause,
        'emotion_feedback': emotionFeedback,
        'learned': learned,
        'next_if_then': nextIfThen,
      };

  factory ActionMindReview.fromJson(Map<String, dynamic> json) => ActionMindReview(
        id: _intValue(json['id']),
        goalId: _intValue(json['goal_id']),
        planId: _intValue(json['plan_id']),
        createdAtMs: _intValue(json['created_at_ms']),
        completed: _boolValue(json['completed']),
        gap: (json['gap'] ?? '').toString(),
        cause: (json['cause'] ?? '').toString(),
        emotionFeedback: (json['emotion_feedback'] ?? '').toString(),
        learned: (json['learned'] ?? '').toString(),
        nextIfThen: (json['next_if_then'] ?? '').toString(),
      );
}

class ActionMindSession {
  final int id;
  final int createdAtMs;
  final String scene;
  final String userInput;
  final String aiResponse;
  final String targetClarification;
  final String mechanismDiagnosis;
  final String rewrittenGoal;
  final String realityObstacle;
  final String processSimulation;
  final ActionMindPlan plan;
  final String emotionHandling;
  final String socialCorrection;
  final String feedbackQuestions;
  final String finalAction;
  final String riskLevel;
  final String rawJson;

  const ActionMindSession({
    this.id = 0,
    this.createdAtMs = 0,
    this.scene = '',
    this.userInput = '',
    this.aiResponse = '',
    this.targetClarification = '',
    this.mechanismDiagnosis = '',
    this.rewrittenGoal = '',
    this.realityObstacle = '',
    this.processSimulation = '',
    this.plan = const ActionMindPlan(),
    this.emotionHandling = '',
    this.socialCorrection = '',
    this.feedbackQuestions = '',
    this.finalAction = '',
    this.riskLevel = 'none',
    this.rawJson = '',
  });

  bool get isSafetyRisk => riskLevel == 'high' || riskLevel == 'crisis';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'scene': scene,
        'user_input': userInput,
        'ai_response': aiResponse,
        'target_clarification': targetClarification,
        'mechanism_diagnosis': mechanismDiagnosis,
        'rewritten_goal': rewrittenGoal,
        'reality_obstacle': realityObstacle,
        'process_simulation': processSimulation,
        'plan': plan.toJson(),
        'emotion_handling': emotionHandling,
        'social_correction': socialCorrection,
        'feedback_questions': feedbackQuestions,
        'final_action': finalAction,
        'risk_level': riskLevel,
        'raw_json': rawJson,
      };

  factory ActionMindSession.fromJson(Map<String, dynamic> json) => ActionMindSession(
        id: _intValue(json['id']),
        createdAtMs: _intValue(json['created_at_ms']),
        scene: (json['scene'] ?? '').toString(),
        userInput: (json['user_input'] ?? '').toString(),
        aiResponse: (json['ai_response'] ?? '').toString(),
        targetClarification: (json['target_clarification'] ?? '').toString(),
        mechanismDiagnosis: (json['mechanism_diagnosis'] ?? '').toString(),
        rewrittenGoal: (json['rewritten_goal'] ?? '').toString(),
        realityObstacle: (json['reality_obstacle'] ?? '').toString(),
        processSimulation: (json['process_simulation'] ?? '').toString(),
        plan: ActionMindPlan.fromJson(_map(json['plan'] ?? json['plan_json'])),
        emotionHandling: (json['emotion_handling'] ?? '').toString(),
        socialCorrection: (json['social_correction'] ?? '').toString(),
        feedbackQuestions: (json['feedback_questions'] ?? '').toString(),
        finalAction: (json['final_action'] ?? '').toString(),
        riskLevel: (json['risk_level'] ?? 'none').toString(),
        rawJson: (json['raw_json'] ?? '').toString(),
      );
}

class ActionMindStats {
  final int sessionCount;
  final int goalCount;
  final int activeGoalCount;
  final int planCount;
  final int reviewCount;
  final int emotionCount;

  const ActionMindStats({
    this.sessionCount = 0,
    this.goalCount = 0,
    this.activeGoalCount = 0,
    this.planCount = 0,
    this.reviewCount = 0,
    this.emotionCount = 0,
  });
}

class ActionMindToolRun {
  final int id;
  final int createdAtMs;
  final String toolId;
  final String scene;
  final String title;
  final String userInput;
  final String aiResponse;
  final String extractedGoal;
  final String extractedPlan;
  final String nextAction;
  final String status;

  const ActionMindToolRun({
    this.id = 0,
    this.createdAtMs = 0,
    this.toolId = '',
    this.scene = '',
    this.title = '',
    this.userInput = '',
    this.aiResponse = '',
    this.extractedGoal = '',
    this.extractedPlan = '',
    this.nextAction = '',
    this.status = 'active',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'tool_id': toolId,
        'scene': scene,
        'title': title,
        'user_input': userInput,
        'ai_response': aiResponse,
        'extracted_goal': extractedGoal,
        'extracted_plan': extractedPlan,
        'next_action': nextAction,
        'status': status,
      };

  factory ActionMindToolRun.fromJson(Map<String, dynamic> json) => ActionMindToolRun(
        id: _intValue(json['id']),
        createdAtMs: _intValue(json['created_at_ms']),
        toolId: (json['tool_id'] ?? '').toString(),
        scene: (json['scene'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        userInput: (json['user_input'] ?? '').toString(),
        aiResponse: (json['ai_response'] ?? '').toString(),
        extractedGoal: (json['extracted_goal'] ?? '').toString(),
        extractedPlan: (json['extracted_plan'] ?? '').toString(),
        nextAction: (json['next_action'] ?? '').toString(),
        status: (json['status'] ?? 'active').toString(),
      );
}

class ActionMindDailyCard {
  final int id;
  final String dateKey;
  final int createdAtMs;
  final String mainGoal;
  final String emotion;
  final String energy;
  final String obstacle;
  final String ifThen;
  final String minimumAction;
  final String standardAction;
  final String challengeAction;
  final String recoveryAction;
  final String aiResponse;

  const ActionMindDailyCard({
    this.id = 0,
    this.dateKey = '',
    this.createdAtMs = 0,
    this.mainGoal = '',
    this.emotion = '',
    this.energy = '',
    this.obstacle = '',
    this.ifThen = '',
    this.minimumAction = '',
    this.standardAction = '',
    this.challengeAction = '',
    this.recoveryAction = '',
    this.aiResponse = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date_key': dateKey,
        'created_at_ms': createdAtMs,
        'main_goal': mainGoal,
        'emotion': emotion,
        'energy': energy,
        'obstacle': obstacle,
        'if_then': ifThen,
        'minimum_action': minimumAction,
        'standard_action': standardAction,
        'challenge_action': challengeAction,
        'recovery_action': recoveryAction,
        'ai_response': aiResponse,
      };

  factory ActionMindDailyCard.fromJson(Map<String, dynamic> json) => ActionMindDailyCard(
        id: _intValue(json['id']),
        dateKey: (json['date_key'] ?? '').toString(),
        createdAtMs: _intValue(json['created_at_ms']),
        mainGoal: (json['main_goal'] ?? '').toString(),
        emotion: (json['emotion'] ?? '').toString(),
        energy: (json['energy'] ?? '').toString(),
        obstacle: (json['obstacle'] ?? '').toString(),
        ifThen: (json['if_then'] ?? '').toString(),
        minimumAction: (json['minimum_action'] ?? '').toString(),
        standardAction: (json['standard_action'] ?? '').toString(),
        challengeAction: (json['challenge_action'] ?? '').toString(),
        recoveryAction: (json['recovery_action'] ?? '').toString(),
        aiResponse: (json['ai_response'] ?? '').toString(),
      );
}

class ActionMindLifeSnapshot {
  final int id;
  final int createdAtMs;
  final String periodKey;
  final String identityDirection;
  final String primaryGoal;
  final String supportingGoals;
  final String conflictGoals;
  final String pausedGoals;
  final String lowMaintenanceGoals;
  final String weeklyFocus;
  final String aiResponse;

  const ActionMindLifeSnapshot({
    this.id = 0,
    this.createdAtMs = 0,
    this.periodKey = '',
    this.identityDirection = '',
    this.primaryGoal = '',
    this.supportingGoals = '',
    this.conflictGoals = '',
    this.pausedGoals = '',
    this.lowMaintenanceGoals = '',
    this.weeklyFocus = '',
    this.aiResponse = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'created_at_ms': createdAtMs,
        'period_key': periodKey,
        'identity_direction': identityDirection,
        'primary_goal': primaryGoal,
        'supporting_goals': supportingGoals,
        'conflict_goals': conflictGoals,
        'paused_goals': pausedGoals,
        'low_maintenance_goals': lowMaintenanceGoals,
        'weekly_focus': weeklyFocus,
        'ai_response': aiResponse,
      };

  factory ActionMindLifeSnapshot.fromJson(Map<String, dynamic> json) => ActionMindLifeSnapshot(
        id: _intValue(json['id']),
        createdAtMs: _intValue(json['created_at_ms']),
        periodKey: (json['period_key'] ?? '').toString(),
        identityDirection: (json['identity_direction'] ?? '').toString(),
        primaryGoal: (json['primary_goal'] ?? '').toString(),
        supportingGoals: (json['supporting_goals'] ?? '').toString(),
        conflictGoals: (json['conflict_goals'] ?? '').toString(),
        pausedGoals: (json['paused_goals'] ?? '').toString(),
        lowMaintenanceGoals: (json['low_maintenance_goals'] ?? '').toString(),
        weeklyFocus: (json['weekly_focus'] ?? '').toString(),
        aiResponse: (json['ai_response'] ?? '').toString(),
      );
}
