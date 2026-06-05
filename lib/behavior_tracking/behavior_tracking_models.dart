import 'dart:convert';

class BehaviorTrackingRecord {
  final int? id;
  final int createdAtMs;
  final int updatedAtMs;
  final int recordDateMs;
  final String mode;
  final String templateKey;
  final String entryMode;
  final String primaryLayer;
  final String category;
  final String title;
  final String source;
  final String sensitivityLevel;
  final int? startMinute;
  final int? endMinute;
  final String behavior;
  final double? plannedValue;
  final double? actualValue;
  final String unit;
  final String completionState;
  final String reason;
  final String outcome;
  final String emotion;
  final int? emotionIntensity;
  final int? valenceScore;
  final int? arousalScore;
  final int? perceivedControl;
  final String trigger;
  final String cognition;
  final String reaction;
  final String environment;
  final String locationType;
  final String peopleContext;
  final String cueTags;
  final String bodyState;
  final int? sleepDurationMin;
  final int? sleepQuality;
  final int? energyMorning;
  final int? steps;
  final int? exerciseMin;
  final String shortTermResult;
  final String longTermImpact;
  final String alternative;
  final String sleep;
  final String importantBehaviors;
  final String timeWaste;
  final String mood;
  final String tomorrowAdjustment;
  final String notes;
  final List<String> tags;

  const BehaviorTrackingRecord({
    this.id,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.recordDateMs,
    required this.mode,
    required this.templateKey,
    required this.entryMode,
    required this.primaryLayer,
    required this.category,
    required this.title,
    required this.source,
    required this.sensitivityLevel,
    this.startMinute,
    this.endMinute,
    required this.behavior,
    this.plannedValue,
    this.actualValue,
    required this.unit,
    required this.completionState,
    required this.reason,
    required this.outcome,
    required this.emotion,
    this.emotionIntensity,
    this.valenceScore,
    this.arousalScore,
    this.perceivedControl,
    required this.trigger,
    required this.cognition,
    required this.reaction,
    required this.environment,
    required this.locationType,
    required this.peopleContext,
    required this.cueTags,
    required this.bodyState,
    this.sleepDurationMin,
    this.sleepQuality,
    this.energyMorning,
    this.steps,
    this.exerciseMin,
    required this.shortTermResult,
    required this.longTermImpact,
    required this.alternative,
    required this.sleep,
    required this.importantBehaviors,
    required this.timeWaste,
    required this.mood,
    required this.tomorrowAdjustment,
    required this.notes,
    required this.tags,
  });

  DateTime get recordDate => DateTime.fromMillisecondsSinceEpoch(recordDateMs);
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  int? get durationMinutes {
    if (startMinute == null || endMinute == null) return null;
    var diff = endMinute! - startMinute!;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  String get timeRangeLabel {
    if (startMinute == null && endMinute == null) return '';
    String fmt(int? m) {
      if (m == null) return '--:--';
      final h = (m ~/ 60).toString().padLeft(2, '0');
      final mm = (m % 60).toString().padLeft(2, '0');
      return '$h:$mm';
    }
    return '${fmt(startMinute)}–${fmt(endMinute)}';
  }

  String get oneLineSummary {
    for (final text in [behavior, reason, outcome, trigger, cognition, notes]) {
      final v = text.trim();
      if (v.isNotEmpty) return v;
    }
    return '还没有填写详细内容';
  }

  BehaviorTrackingRecord copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    int? recordDateMs,
    String? mode,
    String? templateKey,
    String? entryMode,
    String? primaryLayer,
    String? category,
    String? title,
    String? source,
    String? sensitivityLevel,
    int? startMinute,
    int? endMinute,
    bool clearStartMinute = false,
    bool clearEndMinute = false,
    String? behavior,
    double? plannedValue,
    bool clearPlannedValue = false,
    double? actualValue,
    bool clearActualValue = false,
    String? unit,
    String? completionState,
    String? reason,
    String? outcome,
    String? emotion,
    int? emotionIntensity,
    bool clearEmotionIntensity = false,
    int? valenceScore,
    bool clearValenceScore = false,
    int? arousalScore,
    bool clearArousalScore = false,
    int? perceivedControl,
    bool clearPerceivedControl = false,
    String? trigger,
    String? cognition,
    String? reaction,
    String? environment,
    String? locationType,
    String? peopleContext,
    String? cueTags,
    String? bodyState,
    int? sleepDurationMin,
    bool clearSleepDurationMin = false,
    int? sleepQuality,
    bool clearSleepQuality = false,
    int? energyMorning,
    bool clearEnergyMorning = false,
    int? steps,
    bool clearSteps = false,
    int? exerciseMin,
    bool clearExerciseMin = false,
    String? shortTermResult,
    String? longTermImpact,
    String? alternative,
    String? sleep,
    String? importantBehaviors,
    String? timeWaste,
    String? mood,
    String? tomorrowAdjustment,
    String? notes,
    List<String>? tags,
  }) {
    return BehaviorTrackingRecord(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      recordDateMs: recordDateMs ?? this.recordDateMs,
      mode: mode ?? this.mode,
      templateKey: templateKey ?? this.templateKey,
      entryMode: entryMode ?? this.entryMode,
      primaryLayer: primaryLayer ?? this.primaryLayer,
      category: category ?? this.category,
      title: title ?? this.title,
      source: source ?? this.source,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      startMinute: clearStartMinute ? null : (startMinute ?? this.startMinute),
      endMinute: clearEndMinute ? null : (endMinute ?? this.endMinute),
      behavior: behavior ?? this.behavior,
      plannedValue: clearPlannedValue ? null : (plannedValue ?? this.plannedValue),
      actualValue: clearActualValue ? null : (actualValue ?? this.actualValue),
      unit: unit ?? this.unit,
      completionState: completionState ?? this.completionState,
      reason: reason ?? this.reason,
      outcome: outcome ?? this.outcome,
      emotion: emotion ?? this.emotion,
      emotionIntensity: clearEmotionIntensity ? null : (emotionIntensity ?? this.emotionIntensity),
      valenceScore: clearValenceScore ? null : (valenceScore ?? this.valenceScore),
      arousalScore: clearArousalScore ? null : (arousalScore ?? this.arousalScore),
      perceivedControl: clearPerceivedControl ? null : (perceivedControl ?? this.perceivedControl),
      trigger: trigger ?? this.trigger,
      cognition: cognition ?? this.cognition,
      reaction: reaction ?? this.reaction,
      environment: environment ?? this.environment,
      locationType: locationType ?? this.locationType,
      peopleContext: peopleContext ?? this.peopleContext,
      cueTags: cueTags ?? this.cueTags,
      bodyState: bodyState ?? this.bodyState,
      sleepDurationMin: clearSleepDurationMin ? null : (sleepDurationMin ?? this.sleepDurationMin),
      sleepQuality: clearSleepQuality ? null : (sleepQuality ?? this.sleepQuality),
      energyMorning: clearEnergyMorning ? null : (energyMorning ?? this.energyMorning),
      steps: clearSteps ? null : (steps ?? this.steps),
      exerciseMin: clearExerciseMin ? null : (exerciseMin ?? this.exerciseMin),
      shortTermResult: shortTermResult ?? this.shortTermResult,
      longTermImpact: longTermImpact ?? this.longTermImpact,
      alternative: alternative ?? this.alternative,
      sleep: sleep ?? this.sleep,
      importantBehaviors: importantBehaviors ?? this.importantBehaviors,
      timeWaste: timeWaste ?? this.timeWaste,
      mood: mood ?? this.mood,
      tomorrowAdjustment: tomorrowAdjustment ?? this.tomorrowAdjustment,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at_ms': createdAtMs,
      'updated_at_ms': updatedAtMs,
      'record_date_ms': recordDateMs,
      'mode': mode,
      'template_key': templateKey,
      'entry_mode': entryMode,
      'primary_layer': primaryLayer,
      'category': category,
      'title': title,
      'source': source,
      'sensitivity_level': sensitivityLevel,
      'start_minute': startMinute,
      'end_minute': endMinute,
      'behavior': behavior,
      'planned_value': plannedValue,
      'actual_value': actualValue,
      'unit': unit,
      'completion_state': completionState,
      'reason': reason,
      'outcome': outcome,
      'emotion': emotion,
      'emotion_intensity': emotionIntensity,
      'valence_score': valenceScore,
      'arousal_score': arousalScore,
      'perceived_control': perceivedControl,
      'trigger_text': trigger,
      'cognition': cognition,
      'reaction': reaction,
      'environment': environment,
      'location_type': locationType,
      'people_context': peopleContext,
      'cue_tags': cueTags,
      'body_state': bodyState,
      'sleep_duration_min': sleepDurationMin,
      'sleep_quality': sleepQuality,
      'energy_morning': energyMorning,
      'steps': steps,
      'exercise_min': exerciseMin,
      'short_term_result': shortTermResult,
      'long_term_impact': longTermImpact,
      'alternative': alternative,
      'sleep': sleep,
      'important_behaviors': importantBehaviors,
      'time_waste': timeWaste,
      'mood': mood,
      'tomorrow_adjustment': tomorrowAdjustment,
      'notes': notes,
      'tags_json': jsonEncode(tags),
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

    String str(String key) => (map[key] ?? '').toString();

    double? nullableDouble(String key) {
      final v = map[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    List<String> parseTags() {
      try {
        final decoded = jsonDecode(str('tags_json'));
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
      mode: str('mode').isEmpty ? str('entry_mode') : str('mode'),
      templateKey: str('template_key'),
      entryMode: str('entry_mode').isEmpty ? str('mode') : str('entry_mode'),
      primaryLayer: str('primary_layer'),
      category: str('category'),
      title: str('title'),
      source: str('source').isEmpty ? 'manual' : str('source'),
      sensitivityLevel: str('sensitivity_level').isEmpty ? 'normal' : str('sensitivity_level'),
      startMinute: nullableInt('start_minute'),
      endMinute: nullableInt('end_minute'),
      behavior: str('behavior'),
      plannedValue: nullableDouble('planned_value'),
      actualValue: nullableDouble('actual_value'),
      unit: str('unit'),
      completionState: str('completion_state'),
      reason: str('reason'),
      outcome: str('outcome'),
      emotion: str('emotion'),
      emotionIntensity: nullableInt('emotion_intensity'),
      valenceScore: nullableInt('valence_score'),
      arousalScore: nullableInt('arousal_score'),
      perceivedControl: nullableInt('perceived_control'),
      trigger: str('trigger_text'),
      cognition: str('cognition'),
      reaction: str('reaction'),
      environment: str('environment'),
      locationType: str('location_type'),
      peopleContext: str('people_context'),
      cueTags: str('cue_tags'),
      bodyState: str('body_state'),
      sleepDurationMin: nullableInt('sleep_duration_min'),
      sleepQuality: nullableInt('sleep_quality'),
      energyMorning: nullableInt('energy_morning'),
      steps: nullableInt('steps'),
      exerciseMin: nullableInt('exercise_min'),
      shortTermResult: str('short_term_result'),
      longTermImpact: str('long_term_impact'),
      alternative: str('alternative'),
      sleep: str('sleep'),
      importantBehaviors: str('important_behaviors'),
      timeWaste: str('time_waste'),
      mood: str('mood'),
      tomorrowAdjustment: str('tomorrow_adjustment'),
      notes: str('notes'),
      tags: parseTags(),
    );
  }

  factory BehaviorTrackingRecord.blank({String mode = 'full_observation', String primaryLayer = '时间层面'}) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return BehaviorTrackingRecord(
      createdAtMs: now.millisecondsSinceEpoch,
      updatedAtMs: now.millisecondsSinceEpoch,
      recordDateMs: day.millisecondsSinceEpoch,
      mode: mode,
      templateKey: BehaviorTrackingTemplate.templateKeyForMode(mode),
      entryMode: mode,
      primaryLayer: primaryLayer,
      category: '',
      title: '',
      source: 'manual',
      sensitivityLevel: primaryLayer.contains('情绪') || primaryLayer.contains('认知') ? 'personal_sensitive' : 'normal',
      behavior: '',
      unit: '',
      completionState: '',
      reason: '',
      outcome: '',
      emotion: '',
      trigger: '',
      cognition: '',
      reaction: '',
      environment: '',
      locationType: '',
      peopleContext: '',
      cueTags: '',
      bodyState: '',
      shortTermResult: '',
      longTermImpact: '',
      alternative: '',
      sleep: '',
      importantBehaviors: '',
      timeWaste: '',
      mood: '',
      tomorrowAdjustment: '',
      notes: '',
      tags: const <String>[],
    );
  }
}


class BehaviorTrackingTemplate {
  final String key;
  final String name;
  final String purpose;
  final String defaultEntryMode;
  final List<String> fieldKeys;
  final List<String> completionRules;
  final bool isDefault;

  const BehaviorTrackingTemplate({
    required this.key,
    required this.name,
    required this.purpose,
    required this.defaultEntryMode,
    required this.fieldKeys,
    required this.completionRules,
    this.isDefault = true,
  });

  static String templateKeyForMode(String mode) {
    switch (mode) {
      case 'daily_template':
        return 'daily_six_default';
      case 'time_block':
        return 'time_block_default';
      case 'trigger_behavior_result':
        return 'tbr_default';
      case 'emotion':
      case 'cognition':
        return 'thought_record_default';
      case 'body':
        return 'body_snapshot_default';
      default:
        return 'quick_or_full_default';
    }
  }
}

const behaviorTrackingTemplates = <BehaviorTrackingTemplate>[
  BehaviorTrackingTemplate(
    key: 'daily_six_default',
    name: '每日六项',
    purpose: '用固定 6 问完成晚间日报，先记录事实，再留下明日调整。',
    defaultEntryMode: 'nightly_prompt',
    fieldKeys: ['sleep', 'important_behaviors', 'time_waste', 'mood', 'trigger_text', 'tomorrow_adjustment'],
    completionRules: ['min_3_answers'],
  ),
  BehaviorTrackingTemplate(
    key: 'time_block_default',
    name: '时间块记录',
    purpose: '记录开始/结束、类别、专注评分与来源，看清时间流向。',
    defaultEntryMode: 'timer_manual_import',
    fieldKeys: ['start_minute', 'end_minute', 'category', 'behavior', 'source'],
    completionRules: ['require_start_end_or_duration'],
  ),
  BehaviorTrackingTemplate(
    key: 'tbr_default',
    name: '触发—行为—结果',
    purpose: '事件后快速记录触发与行为，复盘时补长期影响与替代方案。',
    defaultEntryMode: 'incident_hotkey',
    fieldKeys: ['trigger_text', 'behavior', 'short_term_result', 'long_term_impact', 'alternative'],
    completionRules: ['require_trigger_and_behavior'],
  ),
  BehaviorTrackingTemplate(
    key: 'thought_record_default',
    name: '情绪—想法记录',
    purpose: '记录情绪强度、自动想法、替代想法与 if-then 计划。',
    defaultEntryMode: 'event_or_review',
    fieldKeys: ['emotion', 'emotion_intensity', 'cognition', 'alternative'],
    completionRules: ['require_emotion_or_thought'],
  ),
  BehaviorTrackingTemplate(
    key: 'body_snapshot_default',
    name: '身体快照',
    purpose: '手工或可选导入睡眠、精力、步数与运动，不影响核心记录。',
    defaultEntryMode: 'daily_snapshot',
    fieldKeys: ['sleep_duration_min', 'sleep_quality', 'energy_morning', 'steps', 'exercise_min'],
    completionRules: ['optional_health_permission'],
  ),
];

class BehaviorLayerInfo {
  final String name;
  final String subtitle;
  final String example;
  final String mode;

  const BehaviorLayerInfo({required this.name, required this.subtitle, required this.example, required this.mode});
}

const behaviorLayerInfos = <BehaviorLayerInfo>[
  BehaviorLayerInfo(name: '时间层面', subtitle: '我把时间花在哪里', example: '22:00–01:00 刷短视频 3 小时', mode: 'time_block'),
  BehaviorLayerInfo(name: '行为层面', subtitle: '我具体做了哪些事', example: '运动20分钟 / 做题8道 / 买了什么', mode: 'behavior'),
  BehaviorLayerInfo(name: '情绪层面', subtitle: '什么情况下有什么感受', example: '被批评→委屈8/10→回避', mode: 'emotion'),
  BehaviorLayerInfo(name: '认知层面', subtitle: '当时脑中自动想法', example: '反正做不完→直接不做', mode: 'cognition'),
  BehaviorLayerInfo(name: '结果层面', subtitle: '短期舒服与长期影响', example: '刷视频当下放松，次日疲惫', mode: 'result'),
  BehaviorLayerInfo(name: '环境层面', subtitle: '地点、人、物如何影响我', example: '手机在手边→容易分心', mode: 'environment'),
  BehaviorLayerInfo(name: '身体状态', subtitle: '睡眠饮食运动如何影响行为', example: '睡眠不足→精力低→拖延', mode: 'body'),
];

const behaviorCategories = <String>['工作/学习', '娱乐', '生活事务', '休息', '人际', '健康', '自律', '消费', '其他'];
