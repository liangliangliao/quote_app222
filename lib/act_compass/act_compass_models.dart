import 'dart:convert';

/// 独立模块：行愿 Compass / ACT 心理灵活性与价值行动系统。
///
/// 本模块只使用 act_compass_* 表与 act_compass_* KV key，
/// 不继承、不复用其他成长模块的数据模型，确保模块边界清晰。
class ActCompassProfile {
  final List<String> coreValues;
  final String identityDirection;
  final String lifeDomains;
  final String commonStories;
  final String avoidancePatterns;
  final String effectivePractices;
  final int updatedAtMs;

  const ActCompassProfile({
    this.coreValues = const <String>[],
    this.identityDirection = '',
    this.lifeDomains = '',
    this.commonStories = '',
    this.avoidancePatterns = '',
    this.effectivePractices = '',
    this.updatedAtMs = 0,
  });

  ActCompassProfile copyWith({
    List<String>? coreValues,
    String? identityDirection,
    String? lifeDomains,
    String? commonStories,
    String? avoidancePatterns,
    String? effectivePractices,
    int? updatedAtMs,
  }) {
    return ActCompassProfile(
      coreValues: coreValues ?? this.coreValues,
      identityDirection: identityDirection ?? this.identityDirection,
      lifeDomains: lifeDomains ?? this.lifeDomains,
      commonStories: commonStories ?? this.commonStories,
      avoidancePatterns: avoidancePatterns ?? this.avoidancePatterns,
      effectivePractices: effectivePractices ?? this.effectivePractices,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'core_values': coreValues,
        'identity_direction': identityDirection,
        'life_domains': lifeDomains,
        'common_stories': commonStories,
        'avoidance_patterns': avoidancePatterns,
        'effective_practices': effectivePractices,
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  factory ActCompassProfile.fromJson(Map<String, dynamic> json) => ActCompassProfile(
        coreValues: _stringList(json['core_values']),
        identityDirection: (json['identity_direction'] ?? '').toString(),
        lifeDomains: (json['life_domains'] ?? '').toString(),
        commonStories: (json['common_stories'] ?? '').toString(),
        avoidancePatterns: (json['avoidance_patterns'] ?? '').toString(),
        effectivePractices: (json['effective_practices'] ?? '').toString(),
        updatedAtMs: _intValue(json['updated_at_ms']),
      );

  static ActCompassProfile fromRaw(String raw) {
    if (raw.trim().isEmpty) return const ActCompassProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return ActCompassProfile.fromJson(decoded);
      if (decoded is Map) return ActCompassProfile.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const ActCompassProfile();
  }
}

class ActCompassFlexRadar {
  final int presentMoment;
  final int defusion;
  final int acceptance;
  final int selfAsContext;
  final int values;
  final int committedAction;

  const ActCompassFlexRadar({
    this.presentMoment = 5,
    this.defusion = 5,
    this.acceptance = 5,
    this.selfAsContext = 5,
    this.values = 5,
    this.committedAction = 5,
  });

  double get average => (presentMoment + defusion + acceptance + selfAsContext + values + committedAction) / 6.0;

  String get weakestLabel {
    final items = <MapEntry<String, int>>[
      MapEntry<String, int>('当下觉察', presentMoment),
      MapEntry<String, int>('认知解离', defusion),
      MapEntry<String, int>('接纳', acceptance),
      MapEntry<String, int>('观察者自我', selfAsContext),
      MapEntry<String, int>('价值连接', values),
      MapEntry<String, int>('承诺行动', committedAction),
    ]..sort((a, b) => a.value.compareTo(b.value));
    return items.first.key;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'present_moment': presentMoment,
        'defusion': defusion,
        'acceptance': acceptance,
        'self_as_context': selfAsContext,
        'values': values,
        'committed_action': committedAction,
      };

  String encode() => jsonEncode(toJson());

  factory ActCompassFlexRadar.fromJson(Map<String, dynamic> json) => ActCompassFlexRadar(
        presentMoment: _intValue(json['present_moment']).clamp(0, 10).toInt(),
        defusion: _intValue(json['defusion']).clamp(0, 10).toInt(),
        acceptance: _intValue(json['acceptance']).clamp(0, 10).toInt(),
        selfAsContext: _intValue(json['self_as_context']).clamp(0, 10).toInt(),
        values: _intValue(json['values']).clamp(0, 10).toInt(),
        committedAction: _intValue(json['committed_action']).clamp(0, 10).toInt(),
      );

  static ActCompassFlexRadar fromRaw(String raw) {
    if (raw.trim().isEmpty) return const ActCompassFlexRadar();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return ActCompassFlexRadar.fromJson(decoded);
      if (decoded is Map) return ActCompassFlexRadar.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const ActCompassFlexRadar();
  }
}

class ActCompassIfThenPlan {
  final String ifText;
  final String thenText;

  const ActCompassIfThenPlan({this.ifText = '', this.thenText = ''});

  Map<String, dynamic> toJson() => <String, dynamic>{'if': ifText, 'then': thenText};

  factory ActCompassIfThenPlan.fromJson(Map<String, dynamic> json) => ActCompassIfThenPlan(
        ifText: (json['if'] ?? json['if_text'] ?? '').toString(),
        thenText: (json['then'] ?? json['then_text'] ?? '').toString(),
      );
}

class ActCompassActionCard {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final int? sourceSessionId;
  final String valueDirection;
  final String obstacle;
  final String thoughtStory;
  final String defusionSentence;
  final String acceptanceSentence;
  final String microAction;
  final String startTime;
  final String duration;
  final String successCriteria;
  final String ifPainThen;
  final String status;

  const ActCompassActionCard({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.sourceSessionId,
    this.valueDirection = '',
    this.obstacle = '',
    this.thoughtStory = '',
    this.defusionSentence = '',
    this.acceptanceSentence = '',
    this.microAction = '',
    this.startTime = '',
    this.duration = '',
    this.successCriteria = '',
    this.ifPainThen = '',
    this.status = 'active',
  });

  bool get hasAction => microAction.trim().isNotEmpty;

  ActCompassActionCard copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    int? sourceSessionId,
    String? valueDirection,
    String? obstacle,
    String? thoughtStory,
    String? defusionSentence,
    String? acceptanceSentence,
    String? microAction,
    String? startTime,
    String? duration,
    String? successCriteria,
    String? ifPainThen,
    String? status,
  }) {
    return ActCompassActionCard(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      valueDirection: valueDirection ?? this.valueDirection,
      obstacle: obstacle ?? this.obstacle,
      thoughtStory: thoughtStory ?? this.thoughtStory,
      defusionSentence: defusionSentence ?? this.defusionSentence,
      acceptanceSentence: acceptanceSentence ?? this.acceptanceSentence,
      microAction: microAction ?? this.microAction,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      successCriteria: successCriteria ?? this.successCriteria,
      ifPainThen: ifPainThen ?? this.ifPainThen,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value_direction': valueDirection,
        'obstacle': obstacle,
        'thought_story': thoughtStory,
        'defusion_sentence': defusionSentence,
        'acceptance_sentence': acceptanceSentence,
        'micro_action': microAction,
        'start_time': startTime,
        'duration': duration,
        'success_criteria': successCriteria,
        'if_pain_then': ifPainThen,
        'status': status,
      };

  String encode() => jsonEncode(toJson());

  factory ActCompassActionCard.fromJson(Map<String, dynamic> json) => ActCompassActionCard(
        valueDirection: (json['value_direction'] ?? json['value'] ?? '').toString(),
        obstacle: (json['obstacle'] ?? '').toString(),
        thoughtStory: (json['thought_story'] ?? json['story'] ?? '').toString(),
        defusionSentence: (json['defusion_sentence'] ?? '').toString(),
        acceptanceSentence: (json['acceptance_sentence'] ?? '').toString(),
        microAction: (json['micro_action'] ?? json['action'] ?? '').toString(),
        startTime: (json['start_time'] ?? '').toString(),
        duration: (json['duration'] ?? '').toString(),
        successCriteria: (json['success_criteria'] ?? '').toString(),
        ifPainThen: (json['if_pain_then'] ?? json['if_then'] ?? '').toString(),
        status: (json['status'] ?? 'active').toString(),
      );

  factory ActCompassActionCard.fromMap(Map<String, Object?> row) => ActCompassActionCard(
        id: _intValue(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        updatedAtMs: _intValue(row['updated_at_ms']),
        sourceSessionId: row['source_session_id'] == null ? null : _intValue(row['source_session_id']),
        valueDirection: (row['value_direction'] ?? '').toString(),
        obstacle: (row['obstacle'] ?? '').toString(),
        thoughtStory: (row['thought_story'] ?? '').toString(),
        defusionSentence: (row['defusion_sentence'] ?? '').toString(),
        acceptanceSentence: (row['acceptance_sentence'] ?? '').toString(),
        microAction: (row['micro_action'] ?? '').toString(),
        startTime: (row['start_time'] ?? '').toString(),
        duration: (row['duration'] ?? '').toString(),
        successCriteria: (row['success_criteria'] ?? '').toString(),
        ifPainThen: (row['if_pain_then'] ?? '').toString(),
        status: (row['status'] ?? 'active').toString(),
      );
}

class ActCompassSessionRecord {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final String scene;
  final String userInput;
  final String aiResponse;
  final List<String> focusProcesses;
  final String heardSummary;
  final String processObservation;
  final String groundingPractice;
  final String thoughtStory;
  final String defusionSentence;
  final String acceptanceSentence;
  final List<String> values;
  final ActCompassActionCard actionCard;
  final List<String> reviewQuestions;
  final String riskLevel;
  final String outputMode;
  final String rawJson;

  const ActCompassSessionRecord({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.scene = 'daily_checkin',
    this.userInput = '',
    this.aiResponse = '',
    this.focusProcesses = const <String>[],
    this.heardSummary = '',
    this.processObservation = '',
    this.groundingPractice = '',
    this.thoughtStory = '',
    this.defusionSentence = '',
    this.acceptanceSentence = '',
    this.values = const <String>[],
    this.actionCard = const ActCompassActionCard(),
    this.reviewQuestions = const <String>[],
    this.riskLevel = 'none',
    this.outputMode = 'common',
    this.rawJson = '',
  });

  bool get isSafetyRisk => riskLevel == 'high' || riskLevel == 'crisis';

  ActCompassSessionRecord copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? scene,
    String? userInput,
    String? aiResponse,
    List<String>? focusProcesses,
    String? heardSummary,
    String? processObservation,
    String? groundingPractice,
    String? thoughtStory,
    String? defusionSentence,
    String? acceptanceSentence,
    List<String>? values,
    ActCompassActionCard? actionCard,
    List<String>? reviewQuestions,
    String? riskLevel,
    String? outputMode,
    String? rawJson,
  }) {
    return ActCompassSessionRecord(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      scene: scene ?? this.scene,
      userInput: userInput ?? this.userInput,
      aiResponse: aiResponse ?? this.aiResponse,
      focusProcesses: focusProcesses ?? this.focusProcesses,
      heardSummary: heardSummary ?? this.heardSummary,
      processObservation: processObservation ?? this.processObservation,
      groundingPractice: groundingPractice ?? this.groundingPractice,
      thoughtStory: thoughtStory ?? this.thoughtStory,
      defusionSentence: defusionSentence ?? this.defusionSentence,
      acceptanceSentence: acceptanceSentence ?? this.acceptanceSentence,
      values: values ?? this.values,
      actionCard: actionCard ?? this.actionCard,
      reviewQuestions: reviewQuestions ?? this.reviewQuestions,
      riskLevel: riskLevel ?? this.riskLevel,
      outputMode: outputMode ?? this.outputMode,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  factory ActCompassSessionRecord.fromMap(Map<String, Object?> row) => ActCompassSessionRecord(
        id: _intValue(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        updatedAtMs: _intValue(row['updated_at_ms']),
        scene: (row['scene'] ?? '').toString(),
        userInput: (row['user_input'] ?? '').toString(),
        aiResponse: (row['ai_response'] ?? '').toString(),
        focusProcesses: _stringListFromRaw(row['focus_processes_json']),
        heardSummary: (row['heard_summary'] ?? '').toString(),
        processObservation: (row['process_observation'] ?? '').toString(),
        groundingPractice: (row['grounding_practice'] ?? '').toString(),
        thoughtStory: (row['thought_story'] ?? '').toString(),
        defusionSentence: (row['defusion_sentence'] ?? '').toString(),
        acceptanceSentence: (row['acceptance_sentence'] ?? '').toString(),
        values: _stringListFromRaw(row['values_json']),
        actionCard: _actionFromRaw(row['action_json']),
        reviewQuestions: _stringListFromRaw(row['review_questions_json']),
        riskLevel: (row['risk_level'] ?? 'none').toString(),
        outputMode: (row['output_mode'] ?? 'common').toString(),
        rawJson: (row['raw_json'] ?? '').toString(),
      );
}

class ActCompassReviewRecord {
  final int id;
  final int actionId;
  final int createdAtMs;
  final bool completed;
  final String whatHappened;
  final String valuesLived;
  final String experiences;
  final String learned;
  final String nextAction;
  final String selfThanks;

  const ActCompassReviewRecord({
    this.id = 0,
    this.actionId = 0,
    this.createdAtMs = 0,
    this.completed = false,
    this.whatHappened = '',
    this.valuesLived = '',
    this.experiences = '',
    this.learned = '',
    this.nextAction = '',
    this.selfThanks = '',
  });

  factory ActCompassReviewRecord.fromMap(Map<String, Object?> row) => ActCompassReviewRecord(
        id: _intValue(row['id']),
        actionId: _intValue(row['action_id']),
        createdAtMs: _intValue(row['created_at_ms']),
        completed: _intValue(row['completed']) == 1,
        whatHappened: (row['what_happened'] ?? '').toString(),
        valuesLived: (row['values_lived'] ?? '').toString(),
        experiences: (row['experiences'] ?? '').toString(),
        learned: (row['learned'] ?? '').toString(),
        nextAction: (row['next_action'] ?? '').toString(),
        selfThanks: (row['self_thanks'] ?? '').toString(),
      );
}

class ActCompassStats {
  final int sessionCount;
  final int actionCount;
  final int completedActionCount;
  final int reviewCount;
  final int valueActionCount;
  final int practiceCount;
  final int experimentCount;
  final int activeExperimentCount;

  const ActCompassStats({
    this.sessionCount = 0,
    this.actionCount = 0,
    this.completedActionCount = 0,
    this.reviewCount = 0,
    this.valueActionCount = 0,
    this.practiceCount = 0,
    this.experimentCount = 0,
    this.activeExperimentCount = 0,
  });
}

List<String> _stringList(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  return raw
      .toString()
      .split(RegExp(r'[,，;；\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

List<String> _stringListFromRaw(dynamic raw) {
  if (raw == null) return const <String>[];
  final s = raw.toString();
  if (s.trim().isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(s);
    return _stringList(decoded);
  } catch (_) {
    return _stringList(s);
  }
}

ActCompassActionCard _actionFromRaw(dynamic raw) {
  if (raw == null || raw.toString().trim().isEmpty) return const ActCompassActionCard();
  try {
    final decoded = jsonDecode(raw.toString());
    if (decoded is Map<String, dynamic>) return ActCompassActionCard.fromJson(decoded);
    if (decoded is Map) return ActCompassActionCard.fromJson(decoded.cast<String, dynamic>());
  } catch (_) {}
  return const ActCompassActionCard();
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class ActCompassPracticeLog {
  final int id;
  final int createdAtMs;
  final String process;
  final String scene;
  final String title;
  final String userInput;
  final String aiGuidance;
  final String valueDirection;
  final String learned;
  final int durationMinutes;

  const ActCompassPracticeLog({
    this.id = 0,
    this.createdAtMs = 0,
    this.process = '',
    this.scene = '',
    this.title = '',
    this.userInput = '',
    this.aiGuidance = '',
    this.valueDirection = '',
    this.learned = '',
    this.durationMinutes = 0,
  });

  factory ActCompassPracticeLog.fromMap(Map<String, Object?> row) => ActCompassPracticeLog(
        id: _intValue(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        process: (row['process'] ?? '').toString(),
        scene: (row['scene'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        userInput: (row['user_input'] ?? '').toString(),
        aiGuidance: (row['ai_guidance'] ?? '').toString(),
        valueDirection: (row['value_direction'] ?? '').toString(),
        learned: (row['learned'] ?? '').toString(),
        durationMinutes: _intValue(row['duration_minutes']),
      );
}

class ActCompassValueExperiment {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final String title;
  final String valueDirection;
  final String whyItMatters;
  final String experimentSteps;
  final String expectedObstacle;
  final String actResponse;
  final int startAtMs;
  final int endAtMs;
  final String status;
  final String review;

  const ActCompassValueExperiment({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.title = '',
    this.valueDirection = '',
    this.whyItMatters = '',
    this.experimentSteps = '',
    this.expectedObstacle = '',
    this.actResponse = '',
    this.startAtMs = 0,
    this.endAtMs = 0,
    this.status = 'active',
    this.review = '',
  });

  ActCompassValueExperiment copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? title,
    String? valueDirection,
    String? whyItMatters,
    String? experimentSteps,
    String? expectedObstacle,
    String? actResponse,
    int? startAtMs,
    int? endAtMs,
    String? status,
    String? review,
  }) {
    return ActCompassValueExperiment(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      title: title ?? this.title,
      valueDirection: valueDirection ?? this.valueDirection,
      whyItMatters: whyItMatters ?? this.whyItMatters,
      experimentSteps: experimentSteps ?? this.experimentSteps,
      expectedObstacle: expectedObstacle ?? this.expectedObstacle,
      actResponse: actResponse ?? this.actResponse,
      startAtMs: startAtMs ?? this.startAtMs,
      endAtMs: endAtMs ?? this.endAtMs,
      status: status ?? this.status,
      review: review ?? this.review,
    );
  }

  factory ActCompassValueExperiment.fromMap(Map<String, Object?> row) => ActCompassValueExperiment(
        id: _intValue(row['id']),
        createdAtMs: _intValue(row['created_at_ms']),
        updatedAtMs: _intValue(row['updated_at_ms']),
        title: (row['title'] ?? '').toString(),
        valueDirection: (row['value_direction'] ?? '').toString(),
        whyItMatters: (row['why_it_matters'] ?? '').toString(),
        experimentSteps: (row['experiment_steps'] ?? '').toString(),
        expectedObstacle: (row['expected_obstacle'] ?? '').toString(),
        actResponse: (row['act_response'] ?? '').toString(),
        startAtMs: _intValue(row['start_at_ms']),
        endAtMs: _intValue(row['end_at_ms']),
        status: (row['status'] ?? 'active').toString(),
        review: (row['review'] ?? '').toString(),
      );
}

class ActCompassPersonalizationSnapshot {
  final List<String> frequentStories;
  final List<String> frequentObstacles;
  final List<String> frequentValues;
  final List<String> effectiveResponses;
  final String weakestProcess;
  final String nextFocus;

  const ActCompassPersonalizationSnapshot({
    this.frequentStories = const <String>[],
    this.frequentObstacles = const <String>[],
    this.frequentValues = const <String>[],
    this.effectiveResponses = const <String>[],
    this.weakestProcess = '',
    this.nextFocus = '',
  });
}
