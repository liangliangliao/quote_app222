import 'dart:convert';

String _str(dynamic v, [String fallback = '']) => (v ?? fallback).toString();
int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse((v ?? '').toString()) ?? fallback;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((key, value) => MapEntry(key.toString(), value));
  if (v is String && v.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is Map) return _map(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

List<String> _stringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  if (v is String && v.trim().isNotEmpty) {
    final text = v.trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return _stringList(decoded);
    } catch (_) {}
    return text.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  return const <String>[];
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => e.map((key, value) => MapEntry(key.toString(), value))).toList(growable: false);
  }
  if (v is String && v.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(v);
      if (decoded is List) return _mapList(decoded);
    } catch (_) {}
  }
  return const <Map<String, dynamic>>[];
}

class RpoMicroAction {
  final String title;
  final int durationMinutes;
  final List<String> steps;

  const RpoMicroAction({
    this.title = '',
    this.durationMinutes = 5,
    this.steps = const <String>[],
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'duration_minutes': durationMinutes,
        'steps': steps,
      };

  factory RpoMicroAction.fromJson(dynamic raw) {
    final m = _map(raw);
    return RpoMicroAction(
      title: _str(m['title']),
      durationMinutes: _int(m['duration_minutes'], 5).clamp(1, 120).toInt(),
      steps: _stringList(m['steps']),
    );
  }
}

class RpoAbcPlan {
  final String affect;
  final String behavior;
  final String cognition;

  const RpoAbcPlan({this.affect = '', this.behavior = '', this.cognition = ''});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'affect': affect,
        'behavior': behavior,
        'cognition': cognition,
      };

  factory RpoAbcPlan.fromJson(dynamic raw) {
    final m = _map(raw);
    return RpoAbcPlan(
      affect: _str(m['affect']),
      behavior: _str(m['behavior']),
      cognition: _str(m['cognition']),
    );
  }
}

class RpoValueBinding {
  final String oldPattern;
  final String boundValue;
  final String painfulForm;
  final String healthyExpression;

  const RpoValueBinding({
    this.oldPattern = '',
    this.boundValue = '',
    this.painfulForm = '',
    this.healthyExpression = '',
  });

  bool get isNotEmpty => oldPattern.trim().isNotEmpty || boundValue.trim().isNotEmpty || healthyExpression.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'old_pattern': oldPattern,
        'bound_value': boundValue,
        'painful_form': painfulForm,
        'healthy_expression': healthyExpression,
      };

  factory RpoValueBinding.fromJson(dynamic raw) {
    final m = _map(raw);
    return RpoValueBinding(
      oldPattern: _str(m['old_pattern']),
      boundValue: _str(m['bound_value']),
      painfulForm: _str(m['painful_form']),
      healthyExpression: _str(m['healthy_expression']),
    );
  }
}

class RpoStretchZone {
  final String currentZone;
  final String nextChallenge;

  const RpoStretchZone({this.currentZone = 'unknown', this.nextChallenge = ''});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'current_zone': currentZone,
        'next_challenge': nextChallenge,
      };

  factory RpoStretchZone.fromJson(dynamic raw) {
    final m = _map(raw);
    return RpoStretchZone(
      currentZone: _str(m['current_zone'], 'unknown'),
      nextChallenge: _str(m['next_challenge']),
    );
  }
}

class RpoStateDiagnosis {
  final String primaryState;
  final String secondaryState;
  final String riskLevel;
  final String recommendedModule;

  const RpoStateDiagnosis({
    this.primaryState = 'mixed',
    this.secondaryState = '',
    this.riskLevel = 'low',
    this.recommendedModule = 'reality_lens',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'primary_state': primaryState,
        'secondary_state': secondaryState,
        'risk_level': riskLevel,
        'recommended_module': recommendedModule,
      };

  factory RpoStateDiagnosis.fromJson(dynamic raw) {
    final m = _map(raw);
    return RpoStateDiagnosis(
      primaryState: _str(m['primary_state'], 'mixed'),
      secondaryState: _str(m['secondary_state']),
      riskLevel: _str(m['risk_level'], 'low'),
      recommendedModule: _str(m['recommended_module'], 'reality_lens'),
    );
  }
}

class RpoPracticeRecord {
  final String id;
  final int createdAtMs;
  final int updatedAtMs;
  final String sceneType;
  final String title;
  final String userInput;
  final RpoStateDiagnosis diagnosis;
  final List<String> coreValues;
  final String realSituation;
  final String oldQuestion;
  final String betterQuestion;
  final String interventionSummary;
  final RpoAbcPlan abcPlan;
  final RpoValueBinding valueBinding;
  final RpoMicroAction microAction;
  final String relationshipAction;
  final String savoringOrMeaningMaking;
  final RpoStretchZone stretchZone;
  final String reflectionQuestion;
  final String identityEvidence;
  final String safetyNote;
  final List<Map<String, dynamic>> displayCards;
  final String rawJson;

  const RpoPracticeRecord({
    required this.id,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.sceneType,
    required this.title,
    required this.userInput,
    required this.diagnosis,
    this.coreValues = const <String>[],
    this.realSituation = '',
    this.oldQuestion = '',
    this.betterQuestion = '',
    this.interventionSummary = '',
    this.abcPlan = const RpoAbcPlan(),
    this.valueBinding = const RpoValueBinding(),
    this.microAction = const RpoMicroAction(),
    this.relationshipAction = '',
    this.savoringOrMeaningMaking = '',
    this.stretchZone = const RpoStretchZone(),
    this.reflectionQuestion = '',
    this.identityEvidence = '',
    this.safetyNote = '',
    this.displayCards = const <Map<String, dynamic>>[],
    this.rawJson = '',
  });

  String get riskLevel => diagnosis.riskLevel;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'module': 'realistic_positivity_os',
        'course_reference': '《哈佛积极心理学》Lecture 9–10',
        'scene_type': sceneType,
        'title': title,
        'original_input': userInput,
        'state_diagnosis': diagnosis.toJson(),
        'core_values': coreValues,
        'real_situation': realSituation,
        'old_question': oldQuestion,
        'better_question': betterQuestion,
        'intervention_summary': interventionSummary,
        'abc_plan': abcPlan.toJson(),
        'value_binding': valueBinding.toJson(),
        'micro_action': microAction.toJson(),
        'relationship_action': relationshipAction,
        'savoring_or_meaning_making': savoringOrMeaningMaking,
        'stretch_zone': stretchZone.toJson(),
        'reflection_question': reflectionQuestion,
        'identity_evidence': identityEvidence,
        'safety_note': safetyNote,
        'display_cards': displayCards,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory RpoPracticeRecord.fromJson(Map<String, dynamic> json, {String? fallbackInput}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final scene = _str(json['scene_type'], _str(json['recommended_module'], 'reality_lens'));
    final diagnosis = RpoStateDiagnosis.fromJson(json['state_diagnosis']);
    return RpoPracticeRecord(
      id: _str(json['id'], 'rpo_${now}_${scene.hashCode.abs()}'),
      createdAtMs: _int(json['created_at_ms'], now),
      updatedAtMs: _int(json['updated_at_ms'], now),
      sceneType: scene,
      title: _str(json['title'], '真实积极行动卡'),
      userInput: _str(json['original_input'], fallbackInput ?? ''),
      diagnosis: diagnosis,
      coreValues: _stringList(json['core_values']),
      realSituation: _str(json['real_situation']),
      oldQuestion: _str(json['old_question']),
      betterQuestion: _str(json['better_question']),
      interventionSummary: _str(json['intervention_summary']),
      abcPlan: RpoAbcPlan.fromJson(json['abc_plan']),
      valueBinding: RpoValueBinding.fromJson(json['value_binding']),
      microAction: RpoMicroAction.fromJson(json['micro_action']),
      relationshipAction: _str(json['relationship_action']),
      savoringOrMeaningMaking: _str(json['savoring_or_meaning_making']),
      stretchZone: RpoStretchZone.fromJson(json['stretch_zone']),
      reflectionQuestion: _str(json['reflection_question']),
      identityEvidence: _str(json['identity_evidence']),
      safetyNote: _str(json['safety_note']),
      displayCards: _mapList(json['display_cards']),
      rawJson: jsonEncode(json),
    );
  }

  static RpoPracticeRecord fromRow(Map<String, Object?> row) {
    final payloadText = (row['payload_json'] ?? '{}').toString();
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(payloadText);
      payload = decoded is Map ? decoded.map((key, value) => MapEntry(key.toString(), value)) : <String, dynamic>{};
    } catch (_) {
      payload = <String, dynamic>{};
    }
    payload['id'] = _str(row['id'], _str(payload['id']));
    payload['scene_type'] = _str(row['scene_type'], _str(payload['scene_type']));
    payload['title'] = _str(row['title'], _str(payload['title']));
    payload['original_input'] = _str(row['user_input'], _str(payload['original_input']));
    payload['created_at_ms'] = _int(row['created_at_ms'], _int(payload['created_at_ms']));
    payload['updated_at_ms'] = _int(row['updated_at_ms'], _int(payload['updated_at_ms']));
    return RpoPracticeRecord.fromJson(payload);
  }
}

class RpoProfile {
  final List<String> commonEmotions;
  final List<String> commonOldQuestions;
  final List<String> commonPatterns;
  final List<String> currentTroubles;
  final List<String> supportPeople;
  final List<String> relationshipMap;
  final List<String> stretchAreas;
  final List<String> gratitudeAssets;
  final List<String> peakExperiences;
  final List<String> identityEvidence;
  final List<RpoValueBinding> valueBindings;
  final int updatedAtMs;

  const RpoProfile({
    this.commonEmotions = const <String>[],
    this.commonOldQuestions = const <String>[],
    this.commonPatterns = const <String>[],
    this.currentTroubles = const <String>[],
    this.supportPeople = const <String>[],
    this.relationshipMap = const <String>[],
    this.stretchAreas = const <String>[],
    this.gratitudeAssets = const <String>[],
    this.peakExperiences = const <String>[],
    this.identityEvidence = const <String>[],
    this.valueBindings = const <RpoValueBinding>[],
    this.updatedAtMs = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'common_emotions': commonEmotions,
        'common_old_questions': commonOldQuestions,
        'common_patterns': commonPatterns,
        'current_troubles': currentTroubles,
        'support_people': supportPeople,
        'relationship_map': relationshipMap,
        'stretch_areas': stretchAreas,
        'gratitude_assets': gratitudeAssets,
        'peak_experiences': peakExperiences,
        'identity_evidence': identityEvidence,
        'value_bindings': valueBindings.map((e) => e.toJson()).toList(growable: false),
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  String toPromptContext() {
    return <String>[
      if (commonEmotions.isNotEmpty) '常见情绪：${commonEmotions.join('，')}',
      if (commonOldQuestions.isNotEmpty) '常见旧问题：${commonOldQuestions.join('；')}',
      if (commonPatterns.isNotEmpty) '常见旧模式：${commonPatterns.join('，')}',
      if (currentTroubles.isNotEmpty) '当前困扰：${currentTroubles.join('，')}',
      if (valueBindings.isNotEmpty) '已知价值绑定：${valueBindings.map((e) => '${e.oldPattern}→${e.boundValue}→${e.healthyExpression}').join('；')}',
      if (supportPeople.isNotEmpty) '支持关系：${supportPeople.join('，')}',
      if (relationshipMap.isNotEmpty) '关系地图：${relationshipMap.join('，')}',
      if (stretchAreas.isNotEmpty) 'Stretch 方向：${stretchAreas.join('，')}',
      if (gratitudeAssets.isNotEmpty) '感恩资产：${gratitudeAssets.take(8).join('，')}',
      if (peakExperiences.isNotEmpty) '高峰体验：${peakExperiences.take(5).join('，')}',
      if (identityEvidence.isNotEmpty) '新身份证据：${identityEvidence.take(8).join('；')}',
    ].join('\n');
  }

  String recentContextHint() {
    return <String>[
      if (identityEvidence.isNotEmpty) '最近可调用的新身份证据：${identityEvidence.take(5).join('；')}',
      if (gratitudeAssets.isNotEmpty) '最近可调用的感恩资产：${gratitudeAssets.take(5).join('；')}',
      if (peakExperiences.isNotEmpty) '最近可重温的高峰体验：${peakExperiences.take(3).join('；')}',
      if (currentTroubles.isNotEmpty) '近期核心困扰：${currentTroubles.take(5).join('；')}',
      if (stretchAreas.isNotEmpty) '近期 Stretch 方向：${stretchAreas.take(5).join('；')}',
    ].join('\n');
  }

  factory RpoProfile.fromJson(Map<String, dynamic> json) => RpoProfile(
        commonEmotions: _stringList(json['common_emotions']),
        commonOldQuestions: _stringList(json['common_old_questions']),
        commonPatterns: _stringList(json['common_patterns']),
        currentTroubles: _stringList(json['current_troubles']),
        supportPeople: _stringList(json['support_people']),
        relationshipMap: _stringList(json['relationship_map']),
        stretchAreas: _stringList(json['stretch_areas']),
        gratitudeAssets: _stringList(json['gratitude_assets']),
        peakExperiences: _stringList(json['peak_experiences']),
        identityEvidence: _stringList(json['identity_evidence']),
        valueBindings: _mapList(json['value_bindings']).map((e) => RpoValueBinding.fromJson(e)).toList(growable: false),
        updatedAtMs: _int(json['updated_at_ms']),
      );

  factory RpoProfile.fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const RpoProfile();
    try {
      return RpoProfile.fromJson(_map(raw));
    } catch (_) {
      return const RpoProfile();
    }
  }
}

class RpoStats {
  final int totalRecords;
  final int gratitudeCount;
  final int emotionCount;
  final int changeCount;
  final int actionCount;
  final int stretchCount;
  final int relationshipCount;
  final int peakCount;
  final int crisisCount;
  final int identityEvidenceCount;

  const RpoStats({
    this.totalRecords = 0,
    this.gratitudeCount = 0,
    this.emotionCount = 0,
    this.changeCount = 0,
    this.actionCount = 0,
    this.stretchCount = 0,
    this.relationshipCount = 0,
    this.peakCount = 0,
    this.crisisCount = 0,
    this.identityEvidenceCount = 0,
  });
}
