import 'dart:convert';

List<String> dcStringList(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return dcStringList(decoded);
    } catch (_) {}
    return text.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  return <String>[raw.toString()];
}

Map<String, dynamic> dcMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return dcMap(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

int dcInt(dynamic raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString()) ?? fallback;
}

String dcText(dynamic raw) => (raw ?? '').toString().trim();

class DefenseCompassProfile {
  final List<String> currentThemes;
  final String commonDefenses;
  final String commonTriggers;
  final String avoidedDomains;
  final String relationshipPatterns;
  final String supportResources;
  final String safetyNotes;
  final int updatedAtMs;

  const DefenseCompassProfile({
    this.currentThemes = const <String>[],
    this.commonDefenses = '',
    this.commonTriggers = '',
    this.avoidedDomains = '',
    this.relationshipPatterns = '',
    this.supportResources = '',
    this.safetyNotes = '',
    this.updatedAtMs = 0,
  });

  DefenseCompassProfile copyWith({
    List<String>? currentThemes,
    String? commonDefenses,
    String? commonTriggers,
    String? avoidedDomains,
    String? relationshipPatterns,
    String? supportResources,
    String? safetyNotes,
    int? updatedAtMs,
  }) => DefenseCompassProfile(
        currentThemes: currentThemes ?? this.currentThemes,
        commonDefenses: commonDefenses ?? this.commonDefenses,
        commonTriggers: commonTriggers ?? this.commonTriggers,
        avoidedDomains: avoidedDomains ?? this.avoidedDomains,
        relationshipPatterns: relationshipPatterns ?? this.relationshipPatterns,
        supportResources: supportResources ?? this.supportResources,
        safetyNotes: safetyNotes ?? this.safetyNotes,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'current_themes': currentThemes,
        'common_defenses': commonDefenses,
        'common_triggers': commonTriggers,
        'avoided_domains': avoidedDomains,
        'relationship_patterns': relationshipPatterns,
        'support_resources': supportResources,
        'safety_notes': safetyNotes,
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  factory DefenseCompassProfile.fromJson(Map<String, dynamic> json) => DefenseCompassProfile(
        currentThemes: dcStringList(json['current_themes']),
        commonDefenses: dcText(json['common_defenses']),
        commonTriggers: dcText(json['common_triggers']),
        avoidedDomains: dcText(json['avoided_domains']),
        relationshipPatterns: dcText(json['relationship_patterns']),
        supportResources: dcText(json['support_resources']),
        safetyNotes: dcText(json['safety_notes']),
        updatedAtMs: dcInt(json['updated_at_ms']),
      );

  factory DefenseCompassProfile.fromRaw(String raw) {
    if (raw.trim().isEmpty) return const DefenseCompassProfile();
    return DefenseCompassProfile.fromJson(dcMap(raw));
  }
}

class DefenseCompassSession {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final String scene;
  final String outputMode;
  final String userInput;
  final String aiResponse;
  final String eventSummary;
  final String facts;
  final String interpretation;
  final List<String> emotions;
  final List<String> hiddenEmotions;
  final List<String> idWishes;
  final List<String> superegoProhibitions;
  final String externalReality;
  final String primaryAnxietySource;
  final String anxietyExplanation;
  final List<String> defenseMechanisms;
  final String defenseEvidence;
  final String protectiveFunction;
  final String longTermCost;
  final String realityCheck;
  final String microAction;
  final String outputCardType;
  final String riskLevel;
  final String rawJson;

  const DefenseCompassSession({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.scene = 'event_analysis',
    this.outputMode = 'standard',
    this.userInput = '',
    this.aiResponse = '',
    this.eventSummary = '',
    this.facts = '',
    this.interpretation = '',
    this.emotions = const <String>[],
    this.hiddenEmotions = const <String>[],
    this.idWishes = const <String>[],
    this.superegoProhibitions = const <String>[],
    this.externalReality = '',
    this.primaryAnxietySource = '',
    this.anxietyExplanation = '',
    this.defenseMechanisms = const <String>[],
    this.defenseEvidence = '',
    this.protectiveFunction = '',
    this.longTermCost = '',
    this.realityCheck = '',
    this.microAction = '',
    this.outputCardType = 'standard_analysis',
    this.riskLevel = 'none',
    this.rawJson = '',
  });

  DefenseCompassSession copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? scene,
    String? outputMode,
    String? userInput,
    String? aiResponse,
    String? eventSummary,
    String? facts,
    String? interpretation,
    List<String>? emotions,
    List<String>? hiddenEmotions,
    List<String>? idWishes,
    List<String>? superegoProhibitions,
    String? externalReality,
    String? primaryAnxietySource,
    String? anxietyExplanation,
    List<String>? defenseMechanisms,
    String? defenseEvidence,
    String? protectiveFunction,
    String? longTermCost,
    String? realityCheck,
    String? microAction,
    String? outputCardType,
    String? riskLevel,
    String? rawJson,
  }) => DefenseCompassSession(
        id: id ?? this.id,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        scene: scene ?? this.scene,
        outputMode: outputMode ?? this.outputMode,
        userInput: userInput ?? this.userInput,
        aiResponse: aiResponse ?? this.aiResponse,
        eventSummary: eventSummary ?? this.eventSummary,
        facts: facts ?? this.facts,
        interpretation: interpretation ?? this.interpretation,
        emotions: emotions ?? this.emotions,
        hiddenEmotions: hiddenEmotions ?? this.hiddenEmotions,
        idWishes: idWishes ?? this.idWishes,
        superegoProhibitions: superegoProhibitions ?? this.superegoProhibitions,
        externalReality: externalReality ?? this.externalReality,
        primaryAnxietySource: primaryAnxietySource ?? this.primaryAnxietySource,
        anxietyExplanation: anxietyExplanation ?? this.anxietyExplanation,
        defenseMechanisms: defenseMechanisms ?? this.defenseMechanisms,
        defenseEvidence: defenseEvidence ?? this.defenseEvidence,
        protectiveFunction: protectiveFunction ?? this.protectiveFunction,
        longTermCost: longTermCost ?? this.longTermCost,
        realityCheck: realityCheck ?? this.realityCheck,
        microAction: microAction ?? this.microAction,
        outputCardType: outputCardType ?? this.outputCardType,
        riskLevel: riskLevel ?? this.riskLevel,
        rawJson: rawJson ?? this.rawJson,
      );

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'scene': scene,
        'output_mode': outputMode,
        'user_input': userInput,
        'ai_response': aiResponse,
        'event_summary': eventSummary,
        'facts': facts,
        'interpretation': interpretation,
        'emotions_json': jsonEncode(emotions),
        'hidden_emotions_json': jsonEncode(hiddenEmotions),
        'id_wishes_json': jsonEncode(idWishes),
        'superego_prohibitions_json': jsonEncode(superegoProhibitions),
        'external_reality': externalReality,
        'primary_anxiety_source': primaryAnxietySource,
        'anxiety_explanation': anxietyExplanation,
        'defense_mechanisms_json': jsonEncode(defenseMechanisms),
        'defense_evidence': defenseEvidence,
        'protective_function': protectiveFunction,
        'long_term_cost': longTermCost,
        'reality_check': realityCheck,
        'micro_action': microAction,
        'output_card_type': outputCardType,
        'risk_level': riskLevel,
        'raw_json': rawJson,
      };

  factory DefenseCompassSession.fromDb(Map<String, dynamic> map) => DefenseCompassSession(
        id: dcInt(map['id']),
        createdAtMs: dcInt(map['created_at_ms']),
        updatedAtMs: dcInt(map['updated_at_ms']),
        scene: dcText(map['scene']).isEmpty ? 'event_analysis' : dcText(map['scene']),
        outputMode: dcText(map['output_mode']).isEmpty ? 'standard' : dcText(map['output_mode']),
        userInput: dcText(map['user_input']),
        aiResponse: dcText(map['ai_response']),
        eventSummary: dcText(map['event_summary']),
        facts: dcText(map['facts']),
        interpretation: dcText(map['interpretation']),
        emotions: dcStringList(map['emotions_json']),
        hiddenEmotions: dcStringList(map['hidden_emotions_json']),
        idWishes: dcStringList(map['id_wishes_json']),
        superegoProhibitions: dcStringList(map['superego_prohibitions_json']),
        externalReality: dcText(map['external_reality']),
        primaryAnxietySource: dcText(map['primary_anxiety_source']),
        anxietyExplanation: dcText(map['anxiety_explanation']),
        defenseMechanisms: dcStringList(map['defense_mechanisms_json']),
        defenseEvidence: dcText(map['defense_evidence']),
        protectiveFunction: dcText(map['protective_function']),
        longTermCost: dcText(map['long_term_cost']),
        realityCheck: dcText(map['reality_check']),
        microAction: dcText(map['micro_action']),
        outputCardType: dcText(map['output_card_type']).isEmpty ? 'standard_analysis' : dcText(map['output_card_type']),
        riskLevel: dcText(map['risk_level']).isEmpty ? 'none' : dcText(map['risk_level']),
        rawJson: dcText(map['raw_json']),
      );

  factory DefenseCompassSession.fromJson(Map<String, dynamic> json, {required String userInput, required String scene, required String outputMode}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DefenseCompassSession(
      createdAtMs: dcInt(json['created_at_ms'], now),
      updatedAtMs: dcInt(json['updated_at_ms'], now),
      scene: dcText(json['scene']).isEmpty ? scene : dcText(json['scene']),
      outputMode: outputMode,
      userInput: userInput,
      aiResponse: dcText(json['ai_response']),
      eventSummary: dcText(json['event_summary']),
      facts: dcText(json['facts']),
      interpretation: dcText(json['interpretation']),
      emotions: dcStringList(json['emotions']),
      hiddenEmotions: dcStringList(json['hidden_emotions']),
      idWishes: dcStringList(json['id_wishes']),
      superegoProhibitions: dcStringList(json['superego_prohibitions']),
      externalReality: dcText(json['external_reality']),
      primaryAnxietySource: dcText(json['primary_anxiety_source']),
      anxietyExplanation: dcText(json['anxiety_explanation']),
      defenseMechanisms: dcStringList(json['defense_mechanisms']),
      defenseEvidence: dcText(json['defense_evidence']),
      protectiveFunction: dcText(json['protective_function']),
      longTermCost: dcText(json['long_term_cost']),
      realityCheck: dcText(json['reality_check']),
      microAction: dcText(json['micro_action']),
      outputCardType: dcText(json['output_card_type']).isEmpty ? 'standard_analysis' : dcText(json['output_card_type']),
      riskLevel: dcText(json['risk_level']).isEmpty ? 'none' : dcText(json['risk_level']),
      rawJson: jsonEncode(json),
    );
  }
}

class DefenseCompassAction {
  final int id;
  final int sessionId;
  final int createdAtMs;
  final int updatedAtMs;
  final String actionType;
  final String actionText;
  final String difficulty;
  final String status;
  final String reflection;
  final String afterEmotion;

  const DefenseCompassAction({
    this.id = 0,
    this.sessionId = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.actionType = 'micro_action',
    this.actionText = '',
    this.difficulty = 'low',
    this.status = 'open',
    this.reflection = '',
    this.afterEmotion = '',
  });

  DefenseCompassAction copyWith({
    int? id,
    int? sessionId,
    int? createdAtMs,
    int? updatedAtMs,
    String? actionType,
    String? actionText,
    String? difficulty,
    String? status,
    String? reflection,
    String? afterEmotion,
  }) => DefenseCompassAction(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        actionType: actionType ?? this.actionType,
        actionText: actionText ?? this.actionText,
        difficulty: difficulty ?? this.difficulty,
        status: status ?? this.status,
        reflection: reflection ?? this.reflection,
        afterEmotion: afterEmotion ?? this.afterEmotion,
      );

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'session_id': sessionId,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'action_type': actionType,
        'action_text': actionText,
        'difficulty': difficulty,
        'status': status,
        'reflection': reflection,
        'after_emotion': afterEmotion,
      };

  factory DefenseCompassAction.fromDb(Map<String, dynamic> map) => DefenseCompassAction(
        id: dcInt(map['id']),
        sessionId: dcInt(map['session_id']),
        createdAtMs: dcInt(map['created_at_ms']),
        updatedAtMs: dcInt(map['updated_at_ms']),
        actionType: dcText(map['action_type']),
        actionText: dcText(map['action_text']),
        difficulty: dcText(map['difficulty']).isEmpty ? 'low' : dcText(map['difficulty']),
        status: dcText(map['status']).isEmpty ? 'open' : dcText(map['status']),
        reflection: dcText(map['reflection']),
        afterEmotion: dcText(map['after_emotion']),
      );
}


class DefenseCompassReport {
  final int id;
  final int createdAtMs;
  final String reportType;
  final String periodLabel;
  final String title;
  final String content;
  final String rawJson;

  const DefenseCompassReport({
    this.id = 0,
    this.createdAtMs = 0,
    this.reportType = 'monthly_review',
    this.periodLabel = '',
    this.title = '',
    this.content = '',
    this.rawJson = '',
  });

  DefenseCompassReport copyWith({
    int? id,
    int? createdAtMs,
    String? reportType,
    String? periodLabel,
    String? title,
    String? content,
    String? rawJson,
  }) => DefenseCompassReport(
        id: id ?? this.id,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        reportType: reportType ?? this.reportType,
        periodLabel: periodLabel ?? this.periodLabel,
        title: title ?? this.title,
        content: content ?? this.content,
        rawJson: rawJson ?? this.rawJson,
      );

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'report_type': reportType,
        'period_label': periodLabel,
        'title': title,
        'content': content,
        'raw_json': rawJson,
      };

  factory DefenseCompassReport.fromDb(Map<String, dynamic> map) => DefenseCompassReport(
        id: dcInt(map['id']),
        createdAtMs: dcInt(map['created_at_ms']),
        reportType: dcText(map['report_type']).isEmpty ? 'monthly_review' : dcText(map['report_type']),
        periodLabel: dcText(map['period_label']),
        title: dcText(map['title']),
        content: dcText(map['content']),
        rawJson: dcText(map['raw_json']),
      );
}

class DefenseCompassCourseProgress {
  final String courseId;
  final int updatedAtMs;
  final bool completed;
  final String note;

  const DefenseCompassCourseProgress({
    required this.courseId,
    this.updatedAtMs = 0,
    this.completed = false,
    this.note = '',
  });

  DefenseCompassCourseProgress copyWith({
    String? courseId,
    int? updatedAtMs,
    bool? completed,
    String? note,
  }) => DefenseCompassCourseProgress(
        courseId: courseId ?? this.courseId,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        completed: completed ?? this.completed,
        note: note ?? this.note,
      );

  Map<String, dynamic> toDb() => <String, dynamic>{
        'course_id': courseId,
        'updated_at_ms': updatedAtMs,
        'completed': completed ? 1 : 0,
        'note': note,
      };

  factory DefenseCompassCourseProgress.fromDb(Map<String, dynamic> map) => DefenseCompassCourseProgress(
        courseId: dcText(map['course_id']),
        updatedAtMs: dcInt(map['updated_at_ms']),
        completed: dcInt(map['completed']) == 1,
        note: dcText(map['note']),
      );
}

class DefenseCompassStats {
  final int sessionCount;
  final int actionCount;
  final int completedActionCount;
  final int reportCount;
  final int completedCourseCount;
  final Map<String, int> defenseCounts;
  final Map<String, int> anxietyCounts;
  final Map<String, int> sceneCounts;
  final Map<String, int> actionTypeCounts;
  final Map<String, int> actionStatusCounts;

  const DefenseCompassStats({
    this.sessionCount = 0,
    this.actionCount = 0,
    this.completedActionCount = 0,
    this.reportCount = 0,
    this.completedCourseCount = 0,
    this.defenseCounts = const <String, int>{},
    this.anxietyCounts = const <String, int>{},
    this.sceneCounts = const <String, int>{},
    this.actionTypeCounts = const <String, int>{},
    this.actionStatusCounts = const <String, int>{},
  });
}

class DefenseCompassCourseCard {
  final String title;
  final String subtitle;
  final String body;
  final List<String> practices;

  const DefenseCompassCourseCard({
    required this.title,
    required this.subtitle,
    required this.body,
    this.practices = const <String>[],
  });
}
