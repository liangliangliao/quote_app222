import 'dart:convert';

class BehaviorTrackingRecord {
  final int? id;
  final int createdAtMs;
  final int updatedAtMs;
  final int recordDateMs;
  final String mode;
  final String primaryLayer;
  final String category;
  final String title;
  final int? startMinute;
  final int? endMinute;
  final String behavior;
  final String reason;
  final String outcome;
  final String emotion;
  final int? emotionIntensity;
  final String trigger;
  final String cognition;
  final String reaction;
  final String environment;
  final String bodyState;
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
    required this.primaryLayer,
    required this.category,
    required this.title,
    this.startMinute,
    this.endMinute,
    required this.behavior,
    required this.reason,
    required this.outcome,
    required this.emotion,
    this.emotionIntensity,
    required this.trigger,
    required this.cognition,
    required this.reaction,
    required this.environment,
    required this.bodyState,
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
    String? primaryLayer,
    String? category,
    String? title,
    int? startMinute,
    int? endMinute,
    bool clearStartMinute = false,
    bool clearEndMinute = false,
    String? behavior,
    String? reason,
    String? outcome,
    String? emotion,
    int? emotionIntensity,
    bool clearEmotionIntensity = false,
    String? trigger,
    String? cognition,
    String? reaction,
    String? environment,
    String? bodyState,
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
      primaryLayer: primaryLayer ?? this.primaryLayer,
      category: category ?? this.category,
      title: title ?? this.title,
      startMinute: clearStartMinute ? null : (startMinute ?? this.startMinute),
      endMinute: clearEndMinute ? null : (endMinute ?? this.endMinute),
      behavior: behavior ?? this.behavior,
      reason: reason ?? this.reason,
      outcome: outcome ?? this.outcome,
      emotion: emotion ?? this.emotion,
      emotionIntensity: clearEmotionIntensity ? null : (emotionIntensity ?? this.emotionIntensity),
      trigger: trigger ?? this.trigger,
      cognition: cognition ?? this.cognition,
      reaction: reaction ?? this.reaction,
      environment: environment ?? this.environment,
      bodyState: bodyState ?? this.bodyState,
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
      'primary_layer': primaryLayer,
      'category': category,
      'title': title,
      'start_minute': startMinute,
      'end_minute': endMinute,
      'behavior': behavior,
      'reason': reason,
      'outcome': outcome,
      'emotion': emotion,
      'emotion_intensity': emotionIntensity,
      'trigger_text': trigger,
      'cognition': cognition,
      'reaction': reaction,
      'environment': environment,
      'body_state': bodyState,
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
      mode: str('mode'),
      primaryLayer: str('primary_layer'),
      category: str('category'),
      title: str('title'),
      startMinute: nullableInt('start_minute'),
      endMinute: nullableInt('end_minute'),
      behavior: str('behavior'),
      reason: str('reason'),
      outcome: str('outcome'),
      emotion: str('emotion'),
      emotionIntensity: nullableInt('emotion_intensity'),
      trigger: str('trigger_text'),
      cognition: str('cognition'),
      reaction: str('reaction'),
      environment: str('environment'),
      bodyState: str('body_state'),
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
      primaryLayer: primaryLayer,
      category: '',
      title: '',
      behavior: '',
      reason: '',
      outcome: '',
      emotion: '',
      trigger: '',
      cognition: '',
      reaction: '',
      environment: '',
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
