import 'dart:convert';

class BehaviorTrackingRecord {
  final int? id;
  final int createdAtMs;
  final int updatedAtMs;
  final int recordDateMs;

  final String mode;
  final String entryMode;
  final String templateKey;
  final String methodName;
  final String primaryLayer;
  final String category;
  final String title;
  final String source;
  final String privacyLevel;

  // 时间层面
  final int? startMinute;
  final int? endMinute;
  final String projectKey;
  final int? focusScore;

  // 行为层面
  final String behavior;
  final String reason;
  final String outcome;
  final double? plannedValue;
  final double? actualValue;
  final String unit;
  final String completionState;
  final String evidenceType;
  final List<String> reasonTags;

  // 情绪层面
  final String emotion;
  final String emotionSecondary;
  final int? emotionIntensity;
  final int? valenceScore;
  final int? arousalScore;
  final int? perceivedControl;

  // 认知层面
  final String trigger;
  final String cognition;
  final String reaction;
  final String automaticThought;
  final int? beliefStrength;
  final List<String> distortionCodes;
  final String alternativeThought;
  final String ifPlan;
  final String thenPlan;

  // 结果层面
  final String shortTermResult;
  final String longTermImpact;
  final int? benefitScore;
  final int? regretScore;
  final String goalAlignment;
  final int? nextDayEnergyDelta;
  final String alternative;

  // 环境层面
  final String environment;
  final String locationType;
  final String peopleContext;
  final String phoneDistance;
  final int? noiseLevel;
  final int? workspaceClutter;
  final List<String> cueTags;

  // 身体状态层面
  final String bodyState;
  final String sleep;
  final int? sleepStartMinute;
  final int? sleepEndMinute;
  final int? sleepDurationMin;
  final int? sleepQuality;
  final int? energyMorning;
  final int? caffeineMg;
  final int? steps;
  final int? exerciseMin;

  // 每日/复盘模板
  final String importantBehaviors;
  final String timeWaste;
  final String mood;
  final String tomorrowAdjustment;
  final String notes;
  final List<String> tags;
  final String templateAnswersJson;

  const BehaviorTrackingRecord({
    this.id,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.recordDateMs,
    required this.mode,
    required this.entryMode,
    required this.templateKey,
    required this.methodName,
    required this.primaryLayer,
    required this.category,
    required this.title,
    required this.source,
    required this.privacyLevel,
    this.startMinute,
    this.endMinute,
    required this.projectKey,
    this.focusScore,
    required this.behavior,
    required this.reason,
    required this.outcome,
    this.plannedValue,
    this.actualValue,
    required this.unit,
    required this.completionState,
    required this.evidenceType,
    required this.reasonTags,
    required this.emotion,
    required this.emotionSecondary,
    this.emotionIntensity,
    this.valenceScore,
    this.arousalScore,
    this.perceivedControl,
    required this.trigger,
    required this.cognition,
    required this.reaction,
    required this.automaticThought,
    this.beliefStrength,
    required this.distortionCodes,
    required this.alternativeThought,
    required this.ifPlan,
    required this.thenPlan,
    required this.shortTermResult,
    required this.longTermImpact,
    this.benefitScore,
    this.regretScore,
    required this.goalAlignment,
    this.nextDayEnergyDelta,
    required this.alternative,
    required this.environment,
    required this.locationType,
    required this.peopleContext,
    required this.phoneDistance,
    this.noiseLevel,
    this.workspaceClutter,
    required this.cueTags,
    required this.bodyState,
    required this.sleep,
    this.sleepStartMinute,
    this.sleepEndMinute,
    this.sleepDurationMin,
    this.sleepQuality,
    this.energyMorning,
    this.caffeineMg,
    this.steps,
    this.exerciseMin,
    required this.importantBehaviors,
    required this.timeWaste,
    required this.mood,
    required this.tomorrowAdjustment,
    required this.notes,
    required this.tags,
    required this.templateAnswersJson,
  });

  DateTime get recordDate => DateTime.fromMillisecondsSinceEpoch(recordDateMs);
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  int? get durationMinutes {
    if (sleepDurationMin != null && mode == 'body_snapshot') return sleepDurationMin;
    if (startMinute == null || endMinute == null) return null;
    var diff = endMinute! - startMinute!;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  String get timeRangeLabel {
    if (startMinute == null && endMinute == null) return '';
    return '${formatMinute(startMinute)}–${formatMinute(endMinute)}';
  }

  static String formatMinute(int? minute) {
    if (minute == null) return '--:--';
    final safe = minute.clamp(0, 24 * 60 - 1);
    final h = (safe ~/ 60).toString().padLeft(2, '0');
    final m = (safe % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get oneLineSummary {
    for (final text in [behavior, reason, outcome, trigger, automaticThought, cognition, shortTermResult, longTermImpact, environment, bodyState, notes]) {
      final v = text.trim();
      if (v.isNotEmpty) return v;
    }
    return '还没有填写详细内容';
  }

  String get templateLabel {
    final info = behaviorTemplateInfos.where((e) => e.key == templateKey).toList();
    if (info.isNotEmpty) return info.first.name;
    final layer = behaviorLayerInfos.where((e) => e.mode == templateKey || e.mode == mode).toList();
    if (layer.isNotEmpty) return '${layer.first.name}记录';
    if (methodName.trim().isNotEmpty) return methodName.trim();
    return mode;
  }

  BehaviorTrackingRecord copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    int? recordDateMs,
    String? mode,
    String? entryMode,
    String? templateKey,
    String? methodName,
    String? primaryLayer,
    String? category,
    String? title,
    String? source,
    String? privacyLevel,
    int? startMinute,
    int? endMinute,
    bool clearStartMinute = false,
    bool clearEndMinute = false,
    String? projectKey,
    int? focusScore,
    bool clearFocusScore = false,
    String? behavior,
    String? reason,
    String? outcome,
    double? plannedValue,
    double? actualValue,
    bool clearPlannedValue = false,
    bool clearActualValue = false,
    String? unit,
    String? completionState,
    String? evidenceType,
    List<String>? reasonTags,
    String? emotion,
    String? emotionSecondary,
    int? emotionIntensity,
    bool clearEmotionIntensity = false,
    int? valenceScore,
    int? arousalScore,
    int? perceivedControl,
    bool clearValenceScore = false,
    bool clearArousalScore = false,
    bool clearPerceivedControl = false,
    String? trigger,
    String? cognition,
    String? reaction,
    String? automaticThought,
    int? beliefStrength,
    bool clearBeliefStrength = false,
    List<String>? distortionCodes,
    String? alternativeThought,
    String? ifPlan,
    String? thenPlan,
    String? shortTermResult,
    String? longTermImpact,
    int? benefitScore,
    int? regretScore,
    bool clearBenefitScore = false,
    bool clearRegretScore = false,
    String? goalAlignment,
    int? nextDayEnergyDelta,
    bool clearNextDayEnergyDelta = false,
    String? alternative,
    String? environment,
    String? locationType,
    String? peopleContext,
    String? phoneDistance,
    int? noiseLevel,
    int? workspaceClutter,
    bool clearNoiseLevel = false,
    bool clearWorkspaceClutter = false,
    List<String>? cueTags,
    String? bodyState,
    String? sleep,
    int? sleepStartMinute,
    int? sleepEndMinute,
    int? sleepDurationMin,
    int? sleepQuality,
    int? energyMorning,
    int? caffeineMg,
    int? steps,
    int? exerciseMin,
    bool clearSleepStartMinute = false,
    bool clearSleepEndMinute = false,
    bool clearSleepDurationMin = false,
    bool clearSleepQuality = false,
    bool clearEnergyMorning = false,
    bool clearCaffeineMg = false,
    bool clearSteps = false,
    bool clearExerciseMin = false,
    String? importantBehaviors,
    String? timeWaste,
    String? mood,
    String? tomorrowAdjustment,
    String? notes,
    List<String>? tags,
    String? templateAnswersJson,
  }) {
    return BehaviorTrackingRecord(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      recordDateMs: recordDateMs ?? this.recordDateMs,
      mode: mode ?? this.mode,
      entryMode: entryMode ?? this.entryMode,
      templateKey: templateKey ?? this.templateKey,
      methodName: methodName ?? this.methodName,
      primaryLayer: primaryLayer ?? this.primaryLayer,
      category: category ?? this.category,
      title: title ?? this.title,
      source: source ?? this.source,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      startMinute: clearStartMinute ? null : (startMinute ?? this.startMinute),
      endMinute: clearEndMinute ? null : (endMinute ?? this.endMinute),
      projectKey: projectKey ?? this.projectKey,
      focusScore: clearFocusScore ? null : (focusScore ?? this.focusScore),
      behavior: behavior ?? this.behavior,
      reason: reason ?? this.reason,
      outcome: outcome ?? this.outcome,
      plannedValue: clearPlannedValue ? null : (plannedValue ?? this.plannedValue),
      actualValue: clearActualValue ? null : (actualValue ?? this.actualValue),
      unit: unit ?? this.unit,
      completionState: completionState ?? this.completionState,
      evidenceType: evidenceType ?? this.evidenceType,
      reasonTags: reasonTags ?? this.reasonTags,
      emotion: emotion ?? this.emotion,
      emotionSecondary: emotionSecondary ?? this.emotionSecondary,
      emotionIntensity: clearEmotionIntensity ? null : (emotionIntensity ?? this.emotionIntensity),
      valenceScore: clearValenceScore ? null : (valenceScore ?? this.valenceScore),
      arousalScore: clearArousalScore ? null : (arousalScore ?? this.arousalScore),
      perceivedControl: clearPerceivedControl ? null : (perceivedControl ?? this.perceivedControl),
      trigger: trigger ?? this.trigger,
      cognition: cognition ?? this.cognition,
      reaction: reaction ?? this.reaction,
      automaticThought: automaticThought ?? this.automaticThought,
      beliefStrength: clearBeliefStrength ? null : (beliefStrength ?? this.beliefStrength),
      distortionCodes: distortionCodes ?? this.distortionCodes,
      alternativeThought: alternativeThought ?? this.alternativeThought,
      ifPlan: ifPlan ?? this.ifPlan,
      thenPlan: thenPlan ?? this.thenPlan,
      shortTermResult: shortTermResult ?? this.shortTermResult,
      longTermImpact: longTermImpact ?? this.longTermImpact,
      benefitScore: clearBenefitScore ? null : (benefitScore ?? this.benefitScore),
      regretScore: clearRegretScore ? null : (regretScore ?? this.regretScore),
      goalAlignment: goalAlignment ?? this.goalAlignment,
      nextDayEnergyDelta: clearNextDayEnergyDelta ? null : (nextDayEnergyDelta ?? this.nextDayEnergyDelta),
      alternative: alternative ?? this.alternative,
      environment: environment ?? this.environment,
      locationType: locationType ?? this.locationType,
      peopleContext: peopleContext ?? this.peopleContext,
      phoneDistance: phoneDistance ?? this.phoneDistance,
      noiseLevel: clearNoiseLevel ? null : (noiseLevel ?? this.noiseLevel),
      workspaceClutter: clearWorkspaceClutter ? null : (workspaceClutter ?? this.workspaceClutter),
      cueTags: cueTags ?? this.cueTags,
      bodyState: bodyState ?? this.bodyState,
      sleep: sleep ?? this.sleep,
      sleepStartMinute: clearSleepStartMinute ? null : (sleepStartMinute ?? this.sleepStartMinute),
      sleepEndMinute: clearSleepEndMinute ? null : (sleepEndMinute ?? this.sleepEndMinute),
      sleepDurationMin: clearSleepDurationMin ? null : (sleepDurationMin ?? this.sleepDurationMin),
      sleepQuality: clearSleepQuality ? null : (sleepQuality ?? this.sleepQuality),
      energyMorning: clearEnergyMorning ? null : (energyMorning ?? this.energyMorning),
      caffeineMg: clearCaffeineMg ? null : (caffeineMg ?? this.caffeineMg),
      steps: clearSteps ? null : (steps ?? this.steps),
      exerciseMin: clearExerciseMin ? null : (exerciseMin ?? this.exerciseMin),
      importantBehaviors: importantBehaviors ?? this.importantBehaviors,
      timeWaste: timeWaste ?? this.timeWaste,
      mood: mood ?? this.mood,
      tomorrowAdjustment: tomorrowAdjustment ?? this.tomorrowAdjustment,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      templateAnswersJson: templateAnswersJson ?? this.templateAnswersJson,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at_ms': createdAtMs,
      'updated_at_ms': updatedAtMs,
      'record_date_ms': recordDateMs,
      'mode': mode,
      'entry_mode': entryMode,
      'template_key': templateKey,
      'method_name': methodName,
      'primary_layer': primaryLayer,
      'category': category,
      'title': title,
      'source': source,
      'privacy_level': privacyLevel,
      'start_minute': startMinute,
      'end_minute': endMinute,
      'project_key': projectKey,
      'focus_score': focusScore,
      'behavior': behavior,
      'reason': reason,
      'outcome': outcome,
      'planned_value': plannedValue,
      'actual_value': actualValue,
      'unit': unit,
      'completion_state': completionState,
      'evidence_type': evidenceType,
      'reason_tags_json': jsonEncode(reasonTags),
      'emotion': emotion,
      'emotion_secondary': emotionSecondary,
      'emotion_intensity': emotionIntensity,
      'valence_score': valenceScore,
      'arousal_score': arousalScore,
      'perceived_control': perceivedControl,
      'trigger_text': trigger,
      'cognition': cognition,
      'reaction': reaction,
      'automatic_thought': automaticThought,
      'belief_strength': beliefStrength,
      'distortion_codes_json': jsonEncode(distortionCodes),
      'alternative_thought': alternativeThought,
      'if_plan': ifPlan,
      'then_plan': thenPlan,
      'short_term_result': shortTermResult,
      'long_term_impact': longTermImpact,
      'benefit_score': benefitScore,
      'regret_score': regretScore,
      'goal_alignment': goalAlignment,
      'next_day_energy_delta': nextDayEnergyDelta,
      'alternative': alternative,
      'environment': environment,
      'location_type': locationType,
      'people_context': peopleContext,
      'phone_distance': phoneDistance,
      'noise_level': noiseLevel,
      'workspace_clutter': workspaceClutter,
      'cue_tags_json': jsonEncode(cueTags),
      'body_state': bodyState,
      'sleep': sleep,
      'sleep_start_minute': sleepStartMinute,
      'sleep_end_minute': sleepEndMinute,
      'sleep_duration_min': sleepDurationMin,
      'sleep_quality': sleepQuality,
      'energy_morning': energyMorning,
      'caffeine_mg': caffeineMg,
      'steps': steps,
      'exercise_min': exerciseMin,
      'important_behaviors': importantBehaviors,
      'time_waste': timeWaste,
      'mood': mood,
      'tomorrow_adjustment': tomorrowAdjustment,
      'notes': notes,
      'tags_json': jsonEncode(tags),
      'template_answers_json': templateAnswersJson,
    };
  }

  factory BehaviorTrackingRecord.fromMap(Map<String, Object?> map) {
    int intValue(String key, [int fallback = 0]) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    int? nullableInt(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? nullableDouble(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    String str(String key) => (map[key] ?? '').toString();

    List<String> list(String key) {
      try {
        final decoded = jsonDecode(str(key));
        if (decoded is List) {
          return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        }
      } catch (_) {}
      return const <String>[];
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorTrackingRecord(
      id: nullableInt('id'),
      createdAtMs: intValue('created_at_ms', now),
      updatedAtMs: intValue('updated_at_ms', now),
      recordDateMs: intValue('record_date_ms', now),
      mode: str('mode').ifEmpty('full_observation'),
      entryMode: str('entry_mode').ifEmpty('standard'),
      templateKey: str('template_key').ifEmpty(str('mode').ifEmpty('full_observation')),
      methodName: str('method_name'),
      primaryLayer: str('primary_layer').ifEmpty('时间层面'),
      category: str('category'),
      title: str('title'),
      source: str('source').ifEmpty('manual'),
      privacyLevel: str('privacy_level').ifEmpty('local_sensitive'),
      startMinute: nullableInt('start_minute'),
      endMinute: nullableInt('end_minute'),
      projectKey: str('project_key'),
      focusScore: nullableInt('focus_score'),
      behavior: str('behavior'),
      reason: str('reason'),
      outcome: str('outcome'),
      plannedValue: nullableDouble('planned_value'),
      actualValue: nullableDouble('actual_value'),
      unit: str('unit'),
      completionState: str('completion_state'),
      evidenceType: str('evidence_type'),
      reasonTags: list('reason_tags_json'),
      emotion: str('emotion'),
      emotionSecondary: str('emotion_secondary'),
      emotionIntensity: nullableInt('emotion_intensity'),
      valenceScore: nullableInt('valence_score'),
      arousalScore: nullableInt('arousal_score'),
      perceivedControl: nullableInt('perceived_control'),
      trigger: str('trigger_text'),
      cognition: str('cognition'),
      reaction: str('reaction'),
      automaticThought: str('automatic_thought').ifEmpty(str('cognition')),
      beliefStrength: nullableInt('belief_strength'),
      distortionCodes: list('distortion_codes_json'),
      alternativeThought: str('alternative_thought'),
      ifPlan: str('if_plan'),
      thenPlan: str('then_plan'),
      shortTermResult: str('short_term_result'),
      longTermImpact: str('long_term_impact'),
      benefitScore: nullableInt('benefit_score'),
      regretScore: nullableInt('regret_score'),
      goalAlignment: str('goal_alignment'),
      nextDayEnergyDelta: nullableInt('next_day_energy_delta'),
      alternative: str('alternative'),
      environment: str('environment'),
      locationType: str('location_type'),
      peopleContext: str('people_context'),
      phoneDistance: str('phone_distance'),
      noiseLevel: nullableInt('noise_level'),
      workspaceClutter: nullableInt('workspace_clutter'),
      cueTags: list('cue_tags_json'),
      bodyState: str('body_state'),
      sleep: str('sleep'),
      sleepStartMinute: nullableInt('sleep_start_minute'),
      sleepEndMinute: nullableInt('sleep_end_minute'),
      sleepDurationMin: nullableInt('sleep_duration_min'),
      sleepQuality: nullableInt('sleep_quality'),
      energyMorning: nullableInt('energy_morning'),
      caffeineMg: nullableInt('caffeine_mg'),
      steps: nullableInt('steps'),
      exerciseMin: nullableInt('exercise_min'),
      importantBehaviors: str('important_behaviors'),
      timeWaste: str('time_waste'),
      mood: str('mood'),
      tomorrowAdjustment: str('tomorrow_adjustment'),
      notes: str('notes'),
      tags: list('tags_json'),
      templateAnswersJson: str('template_answers_json'),
    );
  }

  factory BehaviorTrackingRecord.blank({String mode = 'full_observation', String primaryLayer = '时间层面', String templateKey = 'full_observation', String entryMode = 'standard'}) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final template = behaviorTemplateInfos.where((e) => e.key == templateKey).toList();
    final method = template.isEmpty ? '' : template.first.method;
    return BehaviorTrackingRecord(
      createdAtMs: now.millisecondsSinceEpoch,
      updatedAtMs: now.millisecondsSinceEpoch,
      recordDateMs: day.millisecondsSinceEpoch,
      mode: mode,
      entryMode: entryMode,
      templateKey: templateKey,
      methodName: method,
      primaryLayer: primaryLayer,
      category: '',
      title: '',
      source: 'manual',
      privacyLevel: 'local_sensitive',
      projectKey: '',
      behavior: '',
      reason: '',
      outcome: '',
      unit: '',
      completionState: '',
      evidenceType: 'manual',
      reasonTags: const <String>[],
      emotion: '',
      emotionSecondary: '',
      trigger: '',
      cognition: '',
      reaction: '',
      automaticThought: '',
      distortionCodes: const <String>[],
      alternativeThought: '',
      ifPlan: '',
      thenPlan: '',
      shortTermResult: '',
      longTermImpact: '',
      goalAlignment: '',
      alternative: '',
      environment: '',
      locationType: '',
      peopleContext: '',
      phoneDistance: '',
      cueTags: const <String>[],
      bodyState: '',
      sleep: '',
      importantBehaviors: '',
      timeWaste: '',
      mood: '',
      tomorrowAdjustment: '',
      notes: '',
      tags: const <String>[],
      templateAnswersJson: '',
    );
  }
}

class BehaviorLayerInfo {
  final String name;
  final String subtitle;
  final String principle;
  final String optimalPractice;
  final String humanFit;
  final String example;
  final String mode;
  final List<String> fields;

  const BehaviorLayerInfo({
    required this.name,
    required this.subtitle,
    required this.principle,
    required this.optimalPractice,
    required this.humanFit,
    required this.example,
    required this.mode,
    required this.fields,
  });
}

const behaviorLayerInfos = <BehaviorLayerInfo>[
  BehaviorLayerInfo(
    name: '时间层面',
    subtitle: '我把时间花在哪里',
    principle: '先记录事实时间块，再判断价值。避免“忙了一天”的模糊感。',
    optimalPractice: '优先用开始/结束时间或番茄钟结束后补记；允许空白块，晚间再补分类。',
    humanFit: '人很难长期手动精确记账，所以默认只要求大块时间和类别，不追求每一分钟完美。',
    example: '22:00–01:00 刷短视频 3 小时，原本计划复习 1 小时。',
    mode: 'time_block',
    fields: ['开始/结束', '类别', '项目', '专注度1-5', '来源'],
  ),
  BehaviorLayerInfo(
    name: '行为层面',
    subtitle: '我具体做了哪些可观察动作',
    principle: '把“堕落/自律差”改写成可观察、可计数、可复盘的行为证据。',
    optimalPractice: '记录动作、数量、单位、计划值与实际值；用“跳过/未适用”代替模糊评价。',
    humanFit: '避免道德评价，降低羞耻感，更容易继续记录。',
    example: '原计划复习 60 分钟，实际刷视频 180 分钟。',
    mode: 'behavior',
    fields: ['动作', '计划值', '实际值', '单位', '完成状态', '原因标签'],
  ),
  BehaviorLayerInfo(
    name: '情绪层面',
    subtitle: '什么情况下有什么感受',
    principle: '很多行为不是懒，而是焦虑、无聊、委屈、疲惫等状态下的自动反应。',
    optimalPractice: '事件后用情绪词 + 强度0-10 + 控制感快速记录；不要求长篇解释。',
    humanFit: '用选择和滑杆代替作文式输入，减少情绪低落时的负担。',
    example: '被批评 → 委屈 8/10 → 回避任务、刷手机。',
    mode: 'emotion',
    fields: ['主情绪', '次情绪', '强度', '愉悦度', '唤醒度', '控制感'],
  ),
  BehaviorLayerInfo(
    name: '认知层面',
    subtitle: '当时脑中自动想法',
    principle: '自动想法会把任务解释成“做不完/学不会/明天再说”，进而驱动拖延。',
    optimalPractice: '只在高情绪、拖延、冲动场景展开认知字段，记录当时脑中最自动出现的那句话。',
    humanFit: '不是每天强迫分析自己，而是在关键节点捕捉最有代表性的想法。',
    example: '看到任务很多：“反正做不完” → 直接不做。',
    mode: 'cognition',
    fields: ['自动想法', '相信程度', '思维模式', '后续反应'],
  ),
  BehaviorLayerInfo(
    name: '结果层面',
    subtitle: '短期结果与长期影响',
    principle: '区分“当下舒服、长期亏损”和“当下费力、长期收益”。',
    optimalPractice: '当场先记短期结果，第二天或周复盘再补长期影响和能量变化。',
    humanFit: '人容易被即时奖励吸引，所以系统要帮用户看见延迟后果。',
    example: '熬夜刷视频：当下放松，第二天疲惫。',
    mode: 'result',
    fields: ['短期结果', '长期影响', '收益分', '后悔分', '目标一致性', '次日能量变化'],
  ),
  BehaviorLayerInfo(
    name: '环境层面',
    subtitle: '地点、人、物如何影响我',
    principle: '很多行为不是意志力问题，而是手机、桌面、地点、同伴、时间段共同塑造的结果。',
    optimalPractice: '优先记录主观环境标签，不默认精确定位；用“手机距离/杂乱度/噪音”等具体因素。',
    humanFit: '把行为放回真实场景中观察，减少抽象自责。',
    example: '手机放在手边、房间杂乱 → 容易分心。',
    mode: 'environment',
    fields: ['地点类型', '在场人', '手机距离', '噪音1-5', '杂乱1-5', '线索标签'],
  ),
  BehaviorLayerInfo(
    name: '身体状态',
    subtitle: '睡眠饮食运动如何影响行为',
    principle: '睡眠不足、饥饿、疲劳会显著降低自控和执行质量。',
    optimalPractice: '每天一次身体快照即可；睡眠、精力、咖啡因、步数、运动时间优先。',
    humanFit: '避免把身体数据做成医疗诊断，只作为自我观察与行动调整线索。',
    example: '睡眠 5.5 小时 → 上午精力低 → 下午拖延。',
    mode: 'body_snapshot',
    fields: ['睡眠', '睡眠质量', '上午精力', '咖啡因', '步数', '运动时间'],
  ),
];

class BehaviorTemplateInfo {
  final String key;
  final String name;
  final String method;
  final String entryMode;
  final String primaryLayer;
  final String description;
  final String whenToUse;
  final List<String> prompts;

  const BehaviorTemplateInfo({
    required this.key,
    required this.name,
    required this.method,
    required this.entryMode,
    required this.primaryLayer,
    required this.description,
    required this.whenToUse,
    required this.prompts,
  });
}

const behaviorTemplateInfos = <BehaviorTemplateInfo>[
  BehaviorTemplateInfo(
    key: 'quick_capture',
    name: '秒级快捷记录',
    method: '快捷打卡',
    entryMode: 'quick_capture',
    primaryLayer: '行为层面',
    description: '先用 5–15 秒留下行为证据，之后有空再补其他层面。',
    whenToUse: '刚完成一个行为、刚失控、刚产生明显情绪时。',
    prompts: ['我刚刚做了什么？', '大概持续多久？', '当时最明显的触发是什么？'],
  ),
  BehaviorTemplateInfo(
    key: 'daily_six',
    name: '每日摘要自动汇总',
    method: '日记法',
    entryMode: 'review_capture',
    primaryLayer: '每日6项',
    description: '自动汇总当天行为记录，生成睡眠、重要行为、时间流向、情绪、触发点和今日观察摘要。',
    whenToUse: '想快速查看当天行为结构时。无需新增记录，系统会根据当天已有记录自动生成摘要。',
    prompts: ['今天已有记录汇总出了什么？', '时间主要流向哪里？', '哪些行为、情绪、情境最常出现？'],
  ),
  BehaviorTemplateInfo(
    key: 'time_block',
    name: '时间块记录',
    method: '时间块记录法',
    entryMode: 'standard',
    primaryLayer: '时间层面',
    description: '记录开始/结束时间、类别、项目与专注度，看见时间流向。',
    whenToUse: '学习、工作、娱乐、通勤、休息等明显时间段结束后。',
    prompts: ['这段时间从几点到几点？', '实际做了什么？', '它属于哪一类？'],
  ),
  BehaviorTemplateInfo(
    key: 'tbr',
    name: '触发—行为—结果',
    method: '触发—行为—结果法',
    entryMode: 'incident_capture',
    primaryLayer: '触发—行为—结果',
    description: '记录某次行为发生前的触发、行为本身以及结果。',
    whenToUse: '刚发生一次印象明显的行为，或晚间补记一段值得观察的片段。',
    prompts: ['触发是什么？', '我做了什么？', '短期结果是什么？较长期影响是什么？'],
  ),
  BehaviorTemplateInfo(
    key: 'emotion_thought',
    name: '情绪—想法记录',
    method: '认知记录法',
    entryMode: 'standard',
    primaryLayer: '情绪层面',
    description: '记录情境、情绪强度、自动想法和后续反应。',
    whenToUse: '焦虑、被批评、拖延、想放弃、强烈内耗或情绪波动时。',
    prompts: ['发生了什么？', '我的情绪强度是多少？', '我当时脑中冒出的第一句话是什么？'],
  ),
  BehaviorTemplateInfo(
    key: 'body_snapshot',
    name: '身体快照',
    method: '数据工具法',
    entryMode: 'daily_snapshot',
    primaryLayer: '身体状态',
    description: '每天一次记录睡眠、精力、运动、咖啡因等身体线索。',
    whenToUse: '早上或晚上补记身体状态，用于解释自控力波动。',
    prompts: ['睡了多久？', '今天精力如何？', '运动和咖啡因情况如何？'],
  ),
  BehaviorTemplateInfo(
    key: 'planned_behavior',
    name: '预设行为确认',
    method: '预设行为',
    entryMode: 'preset_confirmation',
    primaryLayer: '行为层面',
    description: '提前预设固定行为，并在每天确认完成、未完成或跳过。',
    whenToUse: '阅读、运动、复盘、背单词等重复出现的计划行为。',
    prompts: ['今天是否完成？', '实际完成量是多少？', '是否需要记录实际时长？'],
  ),
  BehaviorTemplateInfo(
    key: 'full_observation',
    name: '完整七层观察',
    method: '综合记录',
    entryMode: 'standard',
    primaryLayer: '综合观察',
    description: '从时间、行为、情绪、认知、结果、环境、身体七层完整观察。',
    whenToUse: '想深入记录一次关键行为或一段印象明显的经历。',
    prompts: ['我做了什么？', '当时处在什么情境？', '结果如何？', '身体和环境线索是什么？'],
  ),
];

const behaviorCategories = <String>['屏幕使用时间', '工作/学习', '娱乐', '生活事务', '休息', '人际', '健康', '自律', '消费', '其他'];
const behaviorPresetMissedReasonOptions = <String>[
  '时间安排冲突',
  '身体疲惫/睡眠不足',
  '情绪低落/压力大',
  '临时事件打断',
  '忘记/提醒未看到',
  '任务难度过高',
  '环境不支持',
  '目标不清晰',
  '主动调整优先级',
  '其他',
];
const behaviorUnits = <String>['分钟', '小时', '次', '道题', '页', '杯', '元', '步', '公里'];
const behaviorEmotions = <String>['焦虑', '无聊', '委屈', '生气', '满足', '平静', '兴奋', '疲惫', '羞愧', '孤独'];
const behaviorTriggers = <String>['任务太大', '睡前无聊', '手机在手边', '被批评', '身体疲劳', '环境杂乱', '想奖励自己', '同伴影响'];
const cognitionDistortions = <String>['灾难化', '全或无', '应该化', '读心术', '贴标签', '过度概括', '情绪化推理', '完美主义'];
const privacyLevels = <String>['local_private', 'local_sensitive', 'export_allowed'];


class BehaviorPreset {
  final int? id;
  final int createdAtMs;
  final int updatedAtMs;
  final String name;
  final String category;
  final String primaryLayer;
  final double? targetValue;
  final String unit;
  final int? defaultDurationMin;
  final bool reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;
  final bool reminderFullScreen;
  final bool reminderVibrate;
  final List<int> weekdays;
  final bool active;
  final String notes;
  final int sortOrder;

  const BehaviorPreset({
    this.id,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.name,
    required this.category,
    required this.primaryLayer,
    this.targetValue,
    required this.unit,
    this.defaultDurationMin,
    this.reminderEnabled = false,
    this.reminderHour,
    this.reminderMinute,
    this.reminderFullScreen = true,
    this.reminderVibrate = true,
    required this.weekdays,
    required this.active,
    required this.notes,
    required this.sortOrder,
  });

  bool scheduledOn(DateTime date) => weekdays.isEmpty || weekdays.contains(date.weekday);

  BehaviorPreset copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? name,
    String? category,
    String? primaryLayer,
    double? targetValue,
    bool clearTargetValue = false,
    String? unit,
    int? defaultDurationMin,
    bool clearDefaultDurationMin = false,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool clearReminderTime = false,
    bool? reminderFullScreen,
    bool? reminderVibrate,
    List<int>? weekdays,
    bool? active,
    String? notes,
    int? sortOrder,
  }) {
    return BehaviorPreset(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      name: name ?? this.name,
      category: category ?? this.category,
      primaryLayer: primaryLayer ?? this.primaryLayer,
      targetValue: clearTargetValue ? null : (targetValue ?? this.targetValue),
      unit: unit ?? this.unit,
      defaultDurationMin: clearDefaultDurationMin ? null : (defaultDurationMin ?? this.defaultDurationMin),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: clearReminderTime ? null : (reminderHour ?? this.reminderHour),
      reminderMinute: clearReminderTime ? null : (reminderMinute ?? this.reminderMinute),
      reminderFullScreen: reminderFullScreen ?? this.reminderFullScreen,
      reminderVibrate: reminderVibrate ?? this.reminderVibrate,
      weekdays: weekdays ?? this.weekdays,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'name': name,
        'category': category,
        'primary_layer': primaryLayer,
        'target_value': targetValue,
        'unit': unit,
        'default_duration_min': defaultDurationMin,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
        'reminder_fullscreen': reminderFullScreen ? 1 : 0,
        'reminder_vibrate': reminderVibrate ? 1 : 0,
        'weekdays_json': jsonEncode(weekdays),
        'active': active ? 1 : 0,
        'notes': notes,
        'sort_order': sortOrder,
      };

  factory BehaviorPreset.fromMap(Map<String, Object?> map) {
    int intValue(String key, [int fallback = 0]) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    int? nullableInt(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? nullableDouble(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    List<int> weekdayList() {
      try {
        final decoded = jsonDecode((map['weekdays_json'] ?? '[]').toString());
        if (decoded is List) {
          return decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 7).toList();
        }
      } catch (_) {}
      return const <int>[];
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorPreset(
      id: nullableInt('id'),
      createdAtMs: intValue('created_at_ms', now),
      updatedAtMs: intValue('updated_at_ms', now),
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      primaryLayer: (map['primary_layer'] ?? '').toString().ifEmpty('行为层面'),
      targetValue: nullableDouble('target_value'),
      unit: (map['unit'] ?? '').toString(),
      defaultDurationMin: nullableInt('default_duration_min'),
      reminderEnabled: intValue('reminder_enabled', 0) != 0,
      reminderHour: nullableInt('reminder_hour'),
      reminderMinute: nullableInt('reminder_minute'),
      reminderFullScreen: intValue('reminder_fullscreen', 1) != 0,
      reminderVibrate: intValue('reminder_vibrate', 1) != 0,
      weekdays: weekdayList(),
      active: intValue('active', 1) != 0,
      notes: (map['notes'] ?? '').toString(),
      sortOrder: intValue('sort_order', 0),
    );
  }

  factory BehaviorPreset.blank() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorPreset(
      createdAtMs: now,
      updatedAtMs: now,
      name: '',
      category: '工作/学习',
      primaryLayer: '行为层面',
      unit: '次',
      reminderEnabled: false,
      reminderHour: 21,
      reminderMinute: 0,
      reminderFullScreen: true,
      reminderVibrate: true,
      weekdays: const <int>[],
      active: true,
      notes: '',
      sortOrder: 1000,
    );
  }
}

class BehaviorPresetCheckIn {
  final int? id;
  final int presetId;
  final int checkDateMs;
  final String status;
  final double? actualValue;
  final int? actualDurationMin;
  final String note;
  final String missedReason;
  final bool carryForward;
  final int? reviewedAtMs;
  final int? recordId;
  final int createdAtMs;
  final int updatedAtMs;

  const BehaviorPresetCheckIn({
    this.id,
    required this.presetId,
    required this.checkDateMs,
    required this.status,
    this.actualValue,
    this.actualDurationMin,
    required this.note,
    this.missedReason = '',
    this.carryForward = false,
    this.reviewedAtMs,
    this.recordId,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isDone => status == 'done';
  bool get isMissed => status == 'missed';
  bool get isSkipped => status == 'skipped';

  String get statusLabel {
    switch (status) {
      case 'done':
        return '已完成';
      case 'missed':
        return '未完成';
      case 'skipped':
        return '跳过';
      case 'acknowledged':
        return '已提醒';
      default:
        return '待确认';
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'preset_id': presetId,
        'check_date_ms': checkDateMs,
        'status': status,
        'actual_value': actualValue,
        'actual_duration_min': actualDurationMin,
        'note': note,
        'missed_reason': missedReason,
        'carry_forward': carryForward ? 1 : 0,
        'reviewed_at_ms': reviewedAtMs,
        'record_id': recordId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory BehaviorPresetCheckIn.fromMap(Map<String, Object?> map) {
    int intValue(String key, [int fallback = 0]) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    int? nullableInt(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? nullableDouble(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorPresetCheckIn(
      id: nullableInt('id'),
      presetId: intValue('preset_id'),
      checkDateMs: intValue('check_date_ms', now),
      status: (map['status'] ?? 'pending').toString(),
      actualValue: nullableDouble('actual_value'),
      actualDurationMin: nullableInt('actual_duration_min'),
      note: (map['note'] ?? '').toString(),
      missedReason: (map['missed_reason'] ?? '').toString(),
      carryForward: intValue('carry_forward', 0) != 0,
      reviewedAtMs: nullableInt('reviewed_at_ms'),
      recordId: nullableInt('record_id'),
      createdAtMs: intValue('created_at_ms', now),
      updatedAtMs: intValue('updated_at_ms', now),
    );
  }
}


class BehaviorPresetDailyReviewSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const BehaviorPresetDailyReviewSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  factory BehaviorPresetDailyReviewSettings.defaults() => const BehaviorPresetDailyReviewSettings(
        enabled: true,
        hour: 22,
        minute: 30,
      );

  BehaviorPresetDailyReviewSettings copyWith({bool? enabled, int? hour, int? minute}) => BehaviorPresetDailyReviewSettings(
        enabled: enabled ?? this.enabled,
        hour: (hour ?? this.hour).clamp(0, 23).toInt(),
        minute: (minute ?? this.minute).clamp(0, 59).toInt(),
      );

  String get timeLabel => "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  factory BehaviorPresetDailyReviewSettings.fromJson(Map<String, dynamic> json) {
    final defaults = BehaviorPresetDailyReviewSettings.defaults();
    int intValue(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }
    return BehaviorPresetDailyReviewSettings(
      enabled: json['enabled'] != false,
      hour: intValue('hour', defaults.hour).clamp(0, 23).toInt(),
      minute: intValue('minute', defaults.minute).clamp(0, 59).toInt(),
    );
  }
}

class BehaviorPresetDailyReviewRecord {
  final int? id;
  final int reviewDateMs;
  final int totalCount;
  final int doneCount;
  final int missedCount;
  final double completionRate;
  final String detailsJson;
  final int createdAtMs;
  final int updatedAtMs;

  const BehaviorPresetDailyReviewRecord({
    this.id,
    required this.reviewDateMs,
    required this.totalCount,
    required this.doneCount,
    required this.missedCount,
    required this.completionRate,
    required this.detailsJson,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  DateTime get reviewDate => DateTime.fromMillisecondsSinceEpoch(reviewDateMs);

  Map<String, Object?> toMap() => {
        'id': id,
        'review_date_ms': reviewDateMs,
        'total_count': totalCount,
        'done_count': doneCount,
        'missed_count': missedCount,
        'completion_rate': completionRate,
        'details_json': detailsJson,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory BehaviorPresetDailyReviewRecord.fromMap(Map<String, Object?> map) {
    int intValue(String key, [int fallback = 0]) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    double doubleValue(String key, [double fallback = 0]) {
      final v = map[key];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorPresetDailyReviewRecord(
      id: int.tryParse(map['id']?.toString() ?? ''),
      reviewDateMs: intValue('review_date_ms', now),
      totalCount: intValue('total_count'),
      doneCount: intValue('done_count'),
      missedCount: intValue('missed_count'),
      completionRate: doubleValue('completion_rate'),
      detailsJson: (map['details_json'] ?? '').toString(),
      createdAtMs: intValue('created_at_ms', now),
      updatedAtMs: intValue('updated_at_ms', now),
    );
  }
}


class BehaviorPresetAiAnalysisRecord {
  final int? id;
  final int reviewDateMs;
  final String status;
  final String analysisJson;
  final String rawText;
  final String errorMessage;
  final int createdAtMs;
  final int updatedAtMs;

  const BehaviorPresetAiAnalysisRecord({
    this.id,
    required this.reviewDateMs,
    required this.status,
    required this.analysisJson,
    required this.rawText,
    required this.errorMessage,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  DateTime get reviewDate => DateTime.fromMillisecondsSinceEpoch(reviewDateMs);

  Map<String, dynamic> get decodedAnalysis {
    try {
      final decoded = jsonDecode(analysisJson);
      if (decoded is Map) return decoded.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'review_date_ms': reviewDateMs,
        'status': status,
        'analysis_json': analysisJson,
        'raw_text': rawText,
        'error_message': errorMessage,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory BehaviorPresetAiAnalysisRecord.fromMap(Map<String, Object?> map) {
    int intValue(String key, [int fallback = 0]) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return BehaviorPresetAiAnalysisRecord(
      id: int.tryParse(map['id']?.toString() ?? ''),
      reviewDateMs: intValue('review_date_ms', now),
      status: (map['status'] ?? '').toString(),
      analysisJson: (map['analysis_json'] ?? '').toString(),
      rawText: (map['raw_text'] ?? '').toString(),
      errorMessage: (map['error_message'] ?? '').toString(),
      createdAtMs: intValue('created_at_ms', now),
      updatedAtMs: intValue('updated_at_ms', now),
    );
  }
}

extension BehaviorStringExt on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
