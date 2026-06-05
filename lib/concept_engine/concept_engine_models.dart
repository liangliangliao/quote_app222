import 'dart:convert';

class ConceptDirection {
  final String name;
  final String domain;
  final String difficulty;
  final String whyFit;
  final List<String> trainingFocus;

  const ConceptDirection({
    required this.name,
    required this.domain,
    required this.difficulty,
    required this.whyFit,
    required this.trainingFocus,
  });

  factory ConceptDirection.fromJson(Map<String, dynamic> json) => ConceptDirection(
        name: (json['name'] ?? '').toString(),
        domain: (json['domain'] ?? '').toString(),
        difficulty: (json['difficulty'] ?? '').toString(),
        whyFit: (json['why_fit'] ?? '').toString(),
        trainingFocus: ((json['training_focus'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'domain': domain,
        'difficulty': difficulty,
        'why_fit': whyFit,
        'training_focus': trainingFocus,
      };
}

class ConceptParseResult {
  final String concept;
  final String domain;
  final List<String> definitions;
  final List<String> intuitiveDescriptions;
  final List<String> behaviors;
  final List<String> misunderstandings;
  final List<ConceptDirection> directions;

  const ConceptParseResult({
    required this.concept,
    required this.domain,
    required this.definitions,
    required this.intuitiveDescriptions,
    required this.behaviors,
    required this.misunderstandings,
    required this.directions,
  });

  ConceptParseResult copyWith({
    String? concept,
    String? domain,
    List<String>? definitions,
    List<String>? intuitiveDescriptions,
    List<String>? behaviors,
    List<String>? misunderstandings,
    List<ConceptDirection>? directions,
  }) {
    return ConceptParseResult(
      concept: concept ?? this.concept,
      domain: domain ?? this.domain,
      definitions: definitions ?? this.definitions,
      intuitiveDescriptions: intuitiveDescriptions ?? this.intuitiveDescriptions,
      behaviors: behaviors ?? this.behaviors,
      misunderstandings: misunderstandings ?? this.misunderstandings,
      directions: directions ?? this.directions,
    );
  }

  factory ConceptParseResult.fromJson(Map<String, dynamic> json) => ConceptParseResult(
        concept: (json['concept'] ?? '').toString(),
        domain: (json['domain'] ?? '').toString(),
        definitions: ((json['definitions'] as List?) ?? const []).map((e) => e.toString()).toList(),
        intuitiveDescriptions: ((json['intuitive_descriptions'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        behaviors: ((json['behaviors'] as List?) ?? const []).map((e) => e.toString()).toList(),
        misunderstandings: ((json['misunderstandings'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        directions: ((json['directions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ConceptDirection.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'concept': concept,
        'domain': domain,
        'definitions': definitions,
        'intuitive_descriptions': intuitiveDescriptions,
        'behaviors': behaviors,
        'misunderstandings': misunderstandings,
        'directions': directions.map((e) => e.toJson()).toList(),
      };
}

class BehaviorActionNode {
  final String id;
  final String title;
  final String detail;
  final String status;

  const BehaviorActionNode({
    required this.id,
    required this.title,
    required this.detail,
    this.status = '未开始',
  });

  BehaviorActionNode copyWith({
    String? id,
    String? title,
    String? detail,
    String? status,
  }) {
    return BehaviorActionNode(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
    );
  }

  factory BehaviorActionNode.fromJson(Map<String, dynamic> json) => BehaviorActionNode(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        detail: (json['detail'] ?? json['description'] ?? '').toString(),
        status: (json['status'] ?? '未开始').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'status': status,
      };
}

class BehaviorActionChain {
  final String chainId;
  final String concept;
  final String domain;
  final String goal;
  final String behavior;
  final String title;
  final String summary;
  final List<BehaviorActionNode> nodes;
  final DateTime createdAt;

  const BehaviorActionChain({
    required this.chainId,
    required this.concept,
    required this.domain,
    required this.goal,
    required this.behavior,
    required this.title,
    required this.summary,
    required this.nodes,
    required this.createdAt,
  });

  BehaviorActionChain copyWith({
    String? chainId,
    String? concept,
    String? domain,
    String? goal,
    String? behavior,
    String? title,
    String? summary,
    List<BehaviorActionNode>? nodes,
    DateTime? createdAt,
  }) {
    return BehaviorActionChain(
      chainId: chainId ?? this.chainId,
      concept: concept ?? this.concept,
      domain: domain ?? this.domain,
      goal: goal ?? this.goal,
      behavior: behavior ?? this.behavior,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      nodes: nodes ?? this.nodes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BehaviorActionChain.fromJson(Map<String, dynamic> json) => BehaviorActionChain(
        chainId: (json['chain_id'] ?? '').toString(),
        concept: (json['concept'] ?? '').toString(),
        domain: (json['domain'] ?? '').toString(),
        goal: (json['goal'] ?? '').toString(),
        behavior: (json['behavior'] ?? '').toString(),
        title: (json['title'] ?? json['chain_title'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        nodes: ((json['nodes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BehaviorActionNode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'chain_id': chainId,
        'concept': concept,
        'domain': domain,
        'goal': goal,
        'behavior': behavior,
        'title': title,
        'summary': summary,
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class SceneNpc {
  final String name;
  final String role;
  final String motivation;
  final String attitude;

  const SceneNpc({
    required this.name,
    required this.role,
    required this.motivation,
    required this.attitude,
  });

  factory SceneNpc.fromJson(Map<String, dynamic> json) => SceneNpc(
        name: (json['name'] ?? '').toString(),
        role: (json['role'] ?? '').toString(),
        motivation: (json['motivation'] ?? '').toString(),
        attitude: (json['attitude'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'motivation': motivation,
        'attitude': attitude,
      };
}

class SceneOption {
  final String sceneId;
  final String title;
  final String userRole;
  final String goal;
  final String background;
  final List<String> constraints;
  final List<SceneNpc> keyNpcs;
  final List<String> normalEvents;
  final List<String> abnormalEvents;
  final List<String> successCriteria;
  final List<String> failureCriteria;
  final List<String> trainingFocus;
  final int estimatedTurns;

  const SceneOption({
    required this.sceneId,
    required this.title,
    required this.userRole,
    required this.goal,
    required this.background,
    required this.constraints,
    required this.keyNpcs,
    required this.normalEvents,
    required this.abnormalEvents,
    required this.successCriteria,
    required this.failureCriteria,
    required this.trainingFocus,
    required this.estimatedTurns,
  });

  factory SceneOption.fromJson(Map<String, dynamic> json) => SceneOption(
        sceneId: (json['scene_id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        userRole: (json['user_role'] ?? '').toString(),
        goal: (json['goal'] ?? '').toString(),
        background: (json['background'] ?? '').toString(),
        constraints: ((json['constraints'] as List?) ?? const []).map((e) => e.toString()).toList(),
        keyNpcs: ((json['key_npcs'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SceneNpc.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        normalEvents: ((json['normal_events'] as List?) ?? const []).map((e) => e.toString()).toList(),
        abnormalEvents: ((json['abnormal_events'] as List?) ?? const []).map((e) => e.toString()).toList(),
        successCriteria: ((json['success_criteria'] as List?) ?? const []).map((e) => e.toString()).toList(),
        failureCriteria: ((json['failure_criteria'] as List?) ?? const []).map((e) => e.toString()).toList(),
        trainingFocus: ((json['training_focus'] as List?) ?? const []).map((e) => e.toString()).toList(),
        estimatedTurns: int.tryParse((json['estimated_turns'] ?? '6').toString()) ?? 6,
      );

  Map<String, dynamic> toJson() => {
        'scene_id': sceneId,
        'title': title,
        'user_role': userRole,
        'goal': goal,
        'background': background,
        'constraints': constraints,
        'key_npcs': keyNpcs.map((e) => e.toJson()).toList(),
        'normal_events': normalEvents,
        'abnormal_events': abnormalEvents,
        'success_criteria': successCriteria,
        'failure_criteria': failureCriteria,
        'training_focus': trainingFocus,
        'estimated_turns': estimatedTurns,
      };
}

class ChallengeMessage {
  final String role;
  final String content;
  final DateTime createdAt;

  const ChallengeMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChallengeMessage.fromJson(Map<String, dynamic> json) => ChallengeMessage(
        role: (json['role'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };
}

class ChallengeWorldState {
  final int trustScore;
  final int riskScore;
  final int timeLeft;
  final int goalProgress;
  final int teamStability;
  final int emotionTension;
  final int turnNo;
  final bool finished;
  final String finishReason;

  const ChallengeWorldState({
    required this.trustScore,
    required this.riskScore,
    required this.timeLeft,
    required this.goalProgress,
    required this.teamStability,
    required this.emotionTension,
    required this.turnNo,
    required this.finished,
    required this.finishReason,
  });

  factory ChallengeWorldState.initial() => const ChallengeWorldState(
        trustScore: 50,
        riskScore: 35,
        timeLeft: 100,
        goalProgress: 0,
        teamStability: 60,
        emotionTension: 30,
        turnNo: 0,
        finished: false,
        finishReason: '',
      );

  factory ChallengeWorldState.fromJson(Map<String, dynamic> json) => ChallengeWorldState(
        trustScore: int.tryParse((json['trust_score'] ?? '50').toString()) ?? 50,
        riskScore: int.tryParse((json['risk_score'] ?? '35').toString()) ?? 35,
        timeLeft: int.tryParse((json['time_left'] ?? '100').toString()) ?? 100,
        goalProgress: int.tryParse((json['goal_progress'] ?? '0').toString()) ?? 0,
        teamStability: int.tryParse((json['team_stability'] ?? '60').toString()) ?? 60,
        emotionTension: int.tryParse((json['emotion_tension'] ?? '30').toString()) ?? 30,
        turnNo: int.tryParse((json['turn_no'] ?? '0').toString()) ?? 0,
        finished: (json['finished'] ?? false) == true,
        finishReason: (json['finish_reason'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'trust_score': trustScore,
        'risk_score': riskScore,
        'time_left': timeLeft,
        'goal_progress': goalProgress,
        'team_stability': teamStability,
        'emotion_tension': emotionTension,
        'turn_no': turnNo,
        'finished': finished,
        'finish_reason': finishReason,
      };

  ChallengeWorldState copyWith({
    int? trustScore,
    int? riskScore,
    int? timeLeft,
    int? goalProgress,
    int? teamStability,
    int? emotionTension,
    int? turnNo,
    bool? finished,
    String? finishReason,
  }) {
    return ChallengeWorldState(
      trustScore: trustScore ?? this.trustScore,
      riskScore: riskScore ?? this.riskScore,
      timeLeft: timeLeft ?? this.timeLeft,
      goalProgress: goalProgress ?? this.goalProgress,
      teamStability: teamStability ?? this.teamStability,
      emotionTension: emotionTension ?? this.emotionTension,
      turnNo: turnNo ?? this.turnNo,
      finished: finished ?? this.finished,
      finishReason: finishReason ?? this.finishReason,
    );
  }
}

class ChallengeTurnResult {
  final String assistantReply;
  final ChallengeWorldState state;
  final List<String> actionTags;
  final List<String> triggeredEvents;

  const ChallengeTurnResult({
    required this.assistantReply,
    required this.state,
    required this.actionTags,
    required this.triggeredEvents,
  });
}

class ReplayActionSuggestion {
  final String problem;
  final String betterAction;
  final String examplePhrase;

  const ReplayActionSuggestion({
    required this.problem,
    required this.betterAction,
    required this.examplePhrase,
  });

  factory ReplayActionSuggestion.fromJson(Map<String, dynamic> json) => ReplayActionSuggestion(
        problem: (json['problem'] ?? '').toString(),
        betterAction: (json['better_action'] ?? '').toString(),
        examplePhrase: (json['example_phrase'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'problem': problem,
        'better_action': betterAction,
        'example_phrase': examplePhrase,
      };
}

class ReplayResult {
  final int totalScore;
  final String resultLabel;
  final String summary;
  final List<String> strengths;
  final List<String> mistakes;
  final List<String> turningPoints;
  final List<String> rootCauses;
  final List<String> ignoredSignals;
  final List<ReplayActionSuggestion> betterActions;
  final List<String> nextTrainingFocus;
  final Map<String, int> dimensionScores;

  const ReplayResult({
    required this.totalScore,
    required this.resultLabel,
    required this.summary,
    required this.strengths,
    required this.mistakes,
    required this.turningPoints,
    required this.rootCauses,
    required this.ignoredSignals,
    required this.betterActions,
    required this.nextTrainingFocus,
    this.dimensionScores = const {},
  });

  factory ReplayResult.fromJson(Map<String, dynamic> json) => ReplayResult(
        totalScore: int.tryParse((json['total_score'] ?? '0').toString()) ?? 0,
        resultLabel: (json['result_label'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        strengths: ((json['strengths'] as List?) ?? const []).map((e) => e.toString()).toList(),
        mistakes: ((json['mistakes'] as List?) ?? const []).map((e) => e.toString()).toList(),
        turningPoints: ((json['turning_points'] as List?) ?? const []).map((e) => e.toString()).toList(),
        rootCauses: ((json['root_causes'] as List?) ?? const []).map((e) => e.toString()).toList(),
        ignoredSignals: ((json['ignored_signals'] as List?) ?? const []).map((e) => e.toString()).toList(),
        betterActions: ((json['better_actions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ReplayActionSuggestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        nextTrainingFocus: ((json['next_training_focus'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        dimensionScores: ((json['dimension_scores'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0)),
      );

  Map<String, dynamic> toJson() => {
        'total_score': totalScore,
        'result_label': resultLabel,
        'summary': summary,
        'strengths': strengths,
        'mistakes': mistakes,
        'turning_points': turningPoints,
        'root_causes': rootCauses,
        'ignored_signals': ignoredSignals,
        'better_actions': betterActions.map((e) => e.toJson()).toList(),
        'next_training_focus': nextTrainingFocus,
        'dimension_scores': dimensionScores,
      };
}

class ConceptEngineSessionRecord {
  final int? id;
  final String concept;
  final String domain;
  final String goal;
  final String sceneTitle;
  final String provider;
  final String model;
  final String transportMode;
  final String sessionKey;
  final String cabinType;
  final String processJson;
  final String resultLabel;
  final int totalScore;
  final String summary;
  final DateTime createdAt;
  final String stateJson;
  final String replayJson;
  final String historyJson;
  final String sceneJson;
  final String actionTagsJson;
  final String triggeredEventsJson;

  const ConceptEngineSessionRecord({
    required this.id,
    required this.concept,
    required this.domain,
    required this.goal,
    required this.sceneTitle,
    required this.provider,
    required this.model,
    required this.transportMode,
    required this.sessionKey,
    required this.cabinType,
    required this.processJson,
    required this.resultLabel,
    required this.totalScore,
    required this.summary,
    required this.createdAt,
    required this.stateJson,
    required this.replayJson,
    required this.historyJson,
    required this.sceneJson,
    required this.actionTagsJson,
    required this.triggeredEventsJson,
  });

  factory ConceptEngineSessionRecord.fromMap(Map<String, dynamic> map) => ConceptEngineSessionRecord(
        id: map['id'] is int ? map['id'] as int : int.tryParse((map['id'] ?? '').toString()),
        concept: (map['concept'] ?? '').toString(),
        domain: (map['domain'] ?? '').toString(),
        goal: (map['goal'] ?? '').toString(),
        sceneTitle: (map['scene_title'] ?? '').toString(),
        provider: (map['provider'] ?? 'deepseek').toString(),
        model: (map['model'] ?? '').toString(),
        transportMode: (map['transport_mode'] ?? 'direct').toString(),
        sessionKey: (map['session_key'] ?? '').toString(),
        cabinType: (map['cabin_type'] ?? '').toString(),
        processJson: (map['process_json'] ?? '{}').toString(),
        resultLabel: (map['result_label'] ?? '').toString(),
        totalScore: int.tryParse((map['total_score'] ?? '0').toString()) ?? 0,
        summary: (map['summary'] ?? '').toString(),
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
        stateJson: (map['state_json'] ?? '{}').toString(),
        replayJson: (map['replay_json'] ?? '{}').toString(),
        historyJson: (map['history_json'] ?? '[]').toString(),
        sceneJson: (map['scene_json'] ?? '{}').toString(),
        actionTagsJson: (map['action_tags_json'] ?? '[]').toString(),
        triggeredEventsJson: (map['triggered_events_json'] ?? '[]').toString(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'concept': concept,
        'domain': domain,
        'goal': goal,
        'scene_title': sceneTitle,
        'provider': provider,
        'model': model,
        'transport_mode': transportMode,
        'session_key': sessionKey,
        'cabin_type': cabinType,
        'process_json': processJson,
        'result_label': resultLabel,
        'total_score': totalScore,
        'summary': summary,
        'created_at': createdAt.toIso8601String(),
        'state_json': stateJson,
        'replay_json': replayJson,
        'history_json': historyJson,
        'scene_json': sceneJson,
        'action_tags_json': actionTagsJson,
        'triggered_events_json': triggeredEventsJson,
      };

  String get providerLabel => provider == 'openai'
      ? 'OpenAI'
      : provider == 'openrouter'
          ? 'OpenRouter'
          : provider == 'edenai'
              ? 'Eden AI'
              : 'DeepSeek';

  Map<String, dynamic> get processMap {
    try {
      final raw = jsonDecode(processJson);
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return const {};
    } catch (_) {
      return const {};
    }
  }

  ReplayResult? get replayOrNull {
    try {
      return ReplayResult.fromJson(jsonDecode(replayJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  ChallengeWorldState? get stateOrNull {
    try {
      return ChallengeWorldState.fromJson(jsonDecode(stateJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  SceneOption? get sceneOrNull {
    try {
      return SceneOption.fromJson(jsonDecode(sceneJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<ChallengeMessage> get history {
    try {
      return (jsonDecode(historyJson) as List)
          .whereType<Map>()
          .map((e) => ChallengeMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> get actionTags {
    try {
      return (jsonDecode(actionTagsJson) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> get triggeredEvents {
    try {
      return (jsonDecode(triggeredEventsJson) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }
}


class ConceptWorldProfile {
  final int totalXp;
  final int level;
  final int totalRuns;
  final int successfulRuns;
  final int streak;
  final List<String> achievements;
  final DateTime updatedAt;

  const ConceptWorldProfile({
    required this.totalXp,
    required this.level,
    required this.totalRuns,
    required this.successfulRuns,
    required this.streak,
    required this.achievements,
    required this.updatedAt,
  });

  factory ConceptWorldProfile.initial() => ConceptWorldProfile(
        totalXp: 0,
        level: 1,
        totalRuns: 0,
        successfulRuns: 0,
        streak: 0,
        achievements: const [],
        updatedAt: DateTime.now(),
      );

  factory ConceptWorldProfile.fromMap(Map<String, dynamic> map) => ConceptWorldProfile(
        totalXp: int.tryParse((map['total_xp'] ?? '0').toString()) ?? 0,
        level: int.tryParse((map['level'] ?? '1').toString()) ?? 1,
        totalRuns: int.tryParse((map['total_runs'] ?? '0').toString()) ?? 0,
        successfulRuns: int.tryParse((map['successful_runs'] ?? '0').toString()) ?? 0,
        streak: int.tryParse((map['streak'] ?? '0').toString()) ?? 0,
        achievements: (() {
          try {
            return (jsonDecode((map['achievements_json'] ?? '[]').toString()) as List).map((e) => e.toString()).toList();
          } catch (_) {
            return <String>[];
          }
        })(),
        updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'total_xp': totalXp,
        'level': level,
        'total_runs': totalRuns,
        'successful_runs': successfulRuns,
        'streak': streak,
        'achievements_json': jsonEncode(achievements),
        'updated_at': updatedAt.toIso8601String(),
      };

  int get xpIntoCurrentLevel => totalXp % 100;
  int get xpToNextLevel => 100 - xpIntoCurrentLevel;
}

class ConceptWorldRewardResult {
  final ConceptWorldProfile profile;
  final int xpGained;
  final List<String> unlockedAchievements;
  final List<String> unlockedZones;
  final List<String> worldEvents;
  final String zoneId;
  final int anomalyLevelAfter;

  const ConceptWorldRewardResult({
    required this.profile,
    required this.xpGained,
    required this.unlockedAchievements,
    required this.unlockedZones,
    required this.worldEvents,
    required this.zoneId,
    required this.anomalyLevelAfter,
  });
}

class ConceptWorldZoneState {
  final String zoneId;
  final bool unlocked;
  final int clearedCount;
  final int failedCount;
  final int anomalyLevel;
  final DateTime updatedAt;

  const ConceptWorldZoneState({
    required this.zoneId,
    required this.unlocked,
    required this.clearedCount,
    required this.failedCount,
    required this.anomalyLevel,
    required this.updatedAt,
  });

  factory ConceptWorldZoneState.initial(String zoneId, {bool unlocked = false}) => ConceptWorldZoneState(
        zoneId: zoneId,
        unlocked: unlocked,
        clearedCount: 0,
        failedCount: 0,
        anomalyLevel: 0,
        updatedAt: DateTime.now(),
      );

  factory ConceptWorldZoneState.fromMap(Map<String, dynamic> map) => ConceptWorldZoneState(
        zoneId: (map['zone_id'] ?? '').toString(),
        unlocked: (map['unlocked'] ?? 0).toString() == '1' || map['unlocked'] == true,
        clearedCount: int.tryParse((map['cleared_count'] ?? '0').toString()) ?? 0,
        failedCount: int.tryParse((map['failed_count'] ?? '0').toString()) ?? 0,
        anomalyLevel: int.tryParse((map['anomaly_level'] ?? '0').toString()) ?? 0,
        updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'zone_id': zoneId,
        'unlocked': unlocked ? 1 : 0,
        'cleared_count': clearedCount,
        'failed_count': failedCount,
        'anomaly_level': anomalyLevel,
        'updated_at': updatedAt.toIso8601String(),
      };

  ConceptWorldZoneState copyWith({
    bool? unlocked,
    int? clearedCount,
    int? failedCount,
    int? anomalyLevel,
    DateTime? updatedAt,
  }) {
    return ConceptWorldZoneState(
      zoneId: zoneId,
      unlocked: unlocked ?? this.unlocked,
      clearedCount: clearedCount ?? this.clearedCount,
      failedCount: failedCount ?? this.failedCount,
      anomalyLevel: anomalyLevel ?? this.anomalyLevel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get anomalyLabel {
    switch (anomalyLevel) {
      case 3:
        return '失控';
      case 2:
        return '高危';
      case 1:
        return '波动';
      default:
        return '稳定';
    }
  }
}

class ConceptWorldMapData {
  final ConceptWorldProfile profile;
  final List<ConceptWorldZoneState> zones;

  const ConceptWorldMapData({
    required this.profile,
    required this.zones,
  });

  ConceptWorldZoneState stateFor(String zoneId) {
    return zones.firstWhere(
      (e) => e.zoneId == zoneId,
      orElse: () => ConceptWorldZoneState.initial(zoneId),
    );
  }

  int get totalAnomalyLevel => zones.fold<int>(0, (sum, z) => sum + z.anomalyLevel);
}

class ConceptWorldZone {
  final String id;
  final String title;
  final String subtitle;
  final String defaultDomain;
  final String description;
  final String unlockRequirement;
  final IconDataFallback icon;

  const ConceptWorldZone({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.defaultDomain,
    required this.description,
    required this.unlockRequirement,
    required this.icon,
  });
}

class IconDataFallback {
  final int codePoint;
  const IconDataFallback(this.codePoint);
}

class ConceptWorldMission {
  final String zoneId;
  final String zoneTitle;
  final SceneOption scene;
  final int rewardXp;
  final int dangerLevel;
  final String badgeHint;

  const ConceptWorldMission({
    required this.zoneId,
    required this.zoneTitle,
    required this.scene,
    required this.rewardXp,
    required this.dangerLevel,
    required this.badgeHint,
  });
}

String conceptWorldZoneIdForDomain(String domain) {
  final d = domain.trim();
  if (d.contains('团队')) return 'team';
  if (d.contains('生活') || d.contains('关系') || d.contains('家庭')) return 'life';
  return 'work';
}

String conceptWorldZoneTitleForDomain(String domain) {
  switch (conceptWorldZoneIdForDomain(domain)) {
    case 'team':
      return '团队指挥塔';
    case 'life':
      return '关系实验室';
    default:
      return '职场训练基地';
  }
}
