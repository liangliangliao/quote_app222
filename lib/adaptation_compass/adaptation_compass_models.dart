import 'dart:convert';

int acInt(dynamic raw, [int fallback = 0]) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString()) ?? fallback;
}

double acDouble(dynamic raw, [double fallback = 0]) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse((raw ?? '').toString()) ?? fallback;
}

String acText(dynamic raw) => (raw ?? '').toString().trim();

List<String> acStringList(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return acStringList(decoded);
    } catch (_) {}
    return text.split(RegExp(r'[,，;；\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  return <String>[raw.toString()];
}

Map<String, dynamic> acMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return acMap(decoded);
    } catch (_) {}
  }
  return <String, dynamic>{};
}

String acEncodeList(List<String> values) => jsonEncode(values);

class AdaptationCompassSession {
  final int id;
  final int createdAtMs;
  final int updatedAtMs;
  final String scene;
  final String userInput;
  final String aiResponse;
  final String eventSummary;
  final String facts;
  final String interpretation;
  final List<String> emotions;
  final List<String> bodySignals;
  final List<String> needs;
  final String defenseLayer;
  final List<String> defenseMechanisms;
  final String protectiveFunction;
  final String longTermCost;
  final String realityCheck;
  final List<String> matureAlternatives;
  final String action10m;
  final String action24h;
  final String action7d;
  final String relationshipImpact;
  final String growthQuestion;
  final String developmentTask;
  final String balanceFocus;
  final String generativityStep;
  final String riskLevel;
  final String rawJson;

  const AdaptationCompassSession({
    this.id = 0,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.scene = 'daily_stress',
    this.userInput = '',
    this.aiResponse = '',
    this.eventSummary = '',
    this.facts = '',
    this.interpretation = '',
    this.emotions = const <String>[],
    this.bodySignals = const <String>[],
    this.needs = const <String>[],
    this.defenseLayer = '未判断',
    this.defenseMechanisms = const <String>[],
    this.protectiveFunction = '',
    this.longTermCost = '',
    this.realityCheck = '',
    this.matureAlternatives = const <String>[],
    this.action10m = '',
    this.action24h = '',
    this.action7d = '',
    this.relationshipImpact = '',
    this.growthQuestion = '',
    this.developmentTask = '',
    this.balanceFocus = '',
    this.generativityStep = '',
    this.riskLevel = 'none',
    this.rawJson = '',
  });

  AdaptationCompassSession copyWith({
    int? id,
    int? createdAtMs,
    int? updatedAtMs,
    String? scene,
    String? userInput,
    String? aiResponse,
    String? eventSummary,
    String? facts,
    String? interpretation,
    List<String>? emotions,
    List<String>? bodySignals,
    List<String>? needs,
    String? defenseLayer,
    List<String>? defenseMechanisms,
    String? protectiveFunction,
    String? longTermCost,
    String? realityCheck,
    List<String>? matureAlternatives,
    String? action10m,
    String? action24h,
    String? action7d,
    String? relationshipImpact,
    String? growthQuestion,
    String? developmentTask,
    String? balanceFocus,
    String? generativityStep,
    String? riskLevel,
    String? rawJson,
  }) => AdaptationCompassSession(
        id: id ?? this.id,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        scene: scene ?? this.scene,
        userInput: userInput ?? this.userInput,
        aiResponse: aiResponse ?? this.aiResponse,
        eventSummary: eventSummary ?? this.eventSummary,
        facts: facts ?? this.facts,
        interpretation: interpretation ?? this.interpretation,
        emotions: emotions ?? this.emotions,
        bodySignals: bodySignals ?? this.bodySignals,
        needs: needs ?? this.needs,
        defenseLayer: defenseLayer ?? this.defenseLayer,
        defenseMechanisms: defenseMechanisms ?? this.defenseMechanisms,
        protectiveFunction: protectiveFunction ?? this.protectiveFunction,
        longTermCost: longTermCost ?? this.longTermCost,
        realityCheck: realityCheck ?? this.realityCheck,
        matureAlternatives: matureAlternatives ?? this.matureAlternatives,
        action10m: action10m ?? this.action10m,
        action24h: action24h ?? this.action24h,
        action7d: action7d ?? this.action7d,
        relationshipImpact: relationshipImpact ?? this.relationshipImpact,
        growthQuestion: growthQuestion ?? this.growthQuestion,
        developmentTask: developmentTask ?? this.developmentTask,
        balanceFocus: balanceFocus ?? this.balanceFocus,
        generativityStep: generativityStep ?? this.generativityStep,
        riskLevel: riskLevel ?? this.riskLevel,
        rawJson: rawJson ?? this.rawJson,
      );

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'scene': scene,
        'user_input': userInput,
        'ai_response': aiResponse,
        'event_summary': eventSummary,
        'facts': facts,
        'interpretation': interpretation,
        'emotions_json': acEncodeList(emotions),
        'body_signals_json': acEncodeList(bodySignals),
        'needs_json': acEncodeList(needs),
        'defense_layer': defenseLayer,
        'defense_mechanisms_json': acEncodeList(defenseMechanisms),
        'protective_function': protectiveFunction,
        'long_term_cost': longTermCost,
        'reality_check': realityCheck,
        'mature_alternatives_json': acEncodeList(matureAlternatives),
        'action_10m': action10m,
        'action_24h': action24h,
        'action_7d': action7d,
        'relationship_impact': relationshipImpact,
        'growth_question': growthQuestion,
        'development_task': developmentTask,
        'balance_focus': balanceFocus,
        'generativity_step': generativityStep,
        'risk_level': riskLevel,
        'raw_json': rawJson,
      };

  factory AdaptationCompassSession.fromDb(Map<String, dynamic> map) => AdaptationCompassSession(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        updatedAtMs: acInt(map['updated_at_ms']),
        scene: acText(map['scene']).isEmpty ? 'daily_stress' : acText(map['scene']),
        userInput: acText(map['user_input']),
        aiResponse: acText(map['ai_response']),
        eventSummary: acText(map['event_summary']),
        facts: acText(map['facts']),
        interpretation: acText(map['interpretation']),
        emotions: acStringList(map['emotions_json']),
        bodySignals: acStringList(map['body_signals_json']),
        needs: acStringList(map['needs_json']),
        defenseLayer: acText(map['defense_layer']).isEmpty ? '未判断' : acText(map['defense_layer']),
        defenseMechanisms: acStringList(map['defense_mechanisms_json']),
        protectiveFunction: acText(map['protective_function']),
        longTermCost: acText(map['long_term_cost']),
        realityCheck: acText(map['reality_check']),
        matureAlternatives: acStringList(map['mature_alternatives_json']),
        action10m: acText(map['action_10m']),
        action24h: acText(map['action_24h']),
        action7d: acText(map['action_7d']),
        relationshipImpact: acText(map['relationship_impact']),
        growthQuestion: acText(map['growth_question']),
        developmentTask: acText(map['development_task']),
        balanceFocus: acText(map['balance_focus']),
        generativityStep: acText(map['generativity_step']),
        riskLevel: acText(map['risk_level']).isEmpty ? 'none' : acText(map['risk_level']),
        rawJson: acText(map['raw_json']),
      );

  factory AdaptationCompassSession.fromJson(Map<String, dynamic> json, {required String userInput, required String scene}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    final actions = acMap(map['concrete_actions']);
    return AdaptationCompassSession(
      createdAtMs: acInt(map['created_at_ms'], now),
      updatedAtMs: acInt(map['updated_at_ms'], now),
      scene: acText(map['scene']).isEmpty ? scene : acText(map['scene']),
      userInput: acText(map['user_input']).isEmpty ? userInput : acText(map['user_input']),
      aiResponse: acText(map['ai_response']).isEmpty ? acText(map['response_markdown']) : acText(map['ai_response']),
      eventSummary: acText(map['event_summary']),
      facts: acText(map['facts']),
      interpretation: acText(map['interpretation']),
      emotions: acStringList(map['emotions']),
      bodySignals: acStringList(map['body_signals']),
      needs: acStringList(map['needs']),
      defenseLayer: acText(map['defense_layer']).isEmpty ? '未判断' : acText(map['defense_layer']),
      defenseMechanisms: acStringList(map['defense_mechanisms']),
      protectiveFunction: acText(map['protective_function']),
      longTermCost: acText(map['long_term_cost']),
      realityCheck: acText(map['reality_check']),
      matureAlternatives: acStringList(map['mature_alternatives']),
      action10m: acText(map['action_10m']).isEmpty ? acText(actions['10_minutes']) : acText(map['action_10m']),
      action24h: acText(map['action_24h']).isEmpty ? acText(actions['24_hours']) : acText(map['action_24h']),
      action7d: acText(map['action_7d']).isEmpty ? acText(actions['7_days']) : acText(map['action_7d']),
      relationshipImpact: acText(map['relationship_impact']),
      growthQuestion: acText(map['long_term_growth_question']).isEmpty ? acText(map['growth_question']) : acText(map['long_term_growth_question']),
      developmentTask: acText(map['development_task']),
      balanceFocus: acText(map['balance_focus']),
      generativityStep: acText(map['generativity_step']),
      riskLevel: acText(map['risk_level']).isEmpty ? 'none' : acText(map['risk_level']),
      rawJson: jsonEncode(map),
    );
  }
}

class AdaptationCompassAction {
  final int id;
  final int createdAtMs;
  final int dueAtMs;
  final int completedAtMs;
  final int sourceSessionId;
  final String title;
  final String domain;
  final String horizon;
  final String status;
  final String reflection;

  const AdaptationCompassAction({
    this.id = 0,
    this.createdAtMs = 0,
    this.dueAtMs = 0,
    this.completedAtMs = 0,
    this.sourceSessionId = 0,
    this.title = '',
    this.domain = '现实行动',
    this.horizon = '10m',
    this.status = 'open',
    this.reflection = '',
  });

  AdaptationCompassAction copyWith({
    int? id,
    int? createdAtMs,
    int? dueAtMs,
    int? completedAtMs,
    int? sourceSessionId,
    String? title,
    String? domain,
    String? horizon,
    String? status,
    String? reflection,
  }) => AdaptationCompassAction(
        id: id ?? this.id,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        dueAtMs: dueAtMs ?? this.dueAtMs,
        completedAtMs: completedAtMs ?? this.completedAtMs,
        sourceSessionId: sourceSessionId ?? this.sourceSessionId,
        title: title ?? this.title,
        domain: domain ?? this.domain,
        horizon: horizon ?? this.horizon,
        status: status ?? this.status,
        reflection: reflection ?? this.reflection,
      );

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'due_at_ms': dueAtMs,
        'completed_at_ms': completedAtMs,
        'source_session_id': sourceSessionId,
        'title': title,
        'domain': domain,
        'horizon': horizon,
        'status': status,
        'reflection': reflection,
      };

  factory AdaptationCompassAction.fromDb(Map<String, dynamic> map) => AdaptationCompassAction(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        dueAtMs: acInt(map['due_at_ms']),
        completedAtMs: acInt(map['completed_at_ms']),
        sourceSessionId: acInt(map['source_session_id']),
        title: acText(map['title']),
        domain: acText(map['domain']),
        horizon: acText(map['horizon']),
        status: acText(map['status']).isEmpty ? 'open' : acText(map['status']),
        reflection: acText(map['reflection']),
      );
}

class AdaptationCompassBalanceEntry {
  final int id;
  final int createdAtMs;
  final int work;
  final int love;
  final int play;
  final int body;
  final String note;

  const AdaptationCompassBalanceEntry({
    this.id = 0,
    this.createdAtMs = 0,
    this.work = 0,
    this.love = 0,
    this.play = 0,
    this.body = 0,
    this.note = '',
  });

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'work_score': work,
        'love_score': love,
        'play_score': play,
        'body_score': body,
        'note': note,
      };

  factory AdaptationCompassBalanceEntry.fromDb(Map<String, dynamic> map) => AdaptationCompassBalanceEntry(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        work: acInt(map['work_score']),
        love: acInt(map['love_score']),
        play: acInt(map['play_score']),
        body: acInt(map['body_score']),
        note: acText(map['note']),
      );
}

class AdaptationCompassProfile {
  final String values;
  final String repeatedDefenses;
  final String relationshipPatterns;
  final String childhoodClimate;
  final String developmentTask;
  final String safetyResources;
  final int updatedAtMs;

  const AdaptationCompassProfile({
    this.values = '',
    this.repeatedDefenses = '',
    this.relationshipPatterns = '',
    this.childhoodClimate = '',
    this.developmentTask = '',
    this.safetyResources = '',
    this.updatedAtMs = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'values': values,
        'repeated_defenses': repeatedDefenses,
        'relationship_patterns': relationshipPatterns,
        'childhood_climate': childhoodClimate,
        'development_task': developmentTask,
        'safety_resources': safetyResources,
        'updated_at_ms': updatedAtMs,
      };

  String encode() => jsonEncode(toJson());

  factory AdaptationCompassProfile.fromRaw(String raw) {
    final map = acMap(raw);
    return AdaptationCompassProfile(
      values: acText(map['values']),
      repeatedDefenses: acText(map['repeated_defenses']),
      relationshipPatterns: acText(map['relationship_patterns']),
      childhoodClimate: acText(map['childhood_climate']),
      developmentTask: acText(map['development_task']),
      safetyResources: acText(map['safety_resources']),
      updatedAtMs: acInt(map['updated_at_ms']),
    );
  }
}

class AdaptationCompassStats {
  final int sessionCount;
  final int openActions;
  final int doneActions;
  final int matureDefenseHits;
  final int immatureDefenseHits;
  final int neuroticDefenseHits;
  final int riskHits;
  final double avgWork;
  final double avgLove;
  final double avgPlay;
  final double avgBody;

  const AdaptationCompassStats({
    this.sessionCount = 0,
    this.openActions = 0,
    this.doneActions = 0,
    this.matureDefenseHits = 0,
    this.immatureDefenseHits = 0,
    this.neuroticDefenseHits = 0,
    this.riskHits = 0,
    this.avgWork = 0,
    this.avgLove = 0,
    this.avgPlay = 0,
    this.avgBody = 0,
  });
}

class AdaptationCompassRelationshipEntry {
  final int id;
  final int createdAtMs;
  final String name;
  final String type;
  final int trust;
  final int intimacy;
  final int conflict;
  final int support;
  final int boundary;
  final String note;

  const AdaptationCompassRelationshipEntry({
    this.id = 0,
    this.createdAtMs = 0,
    this.name = '',
    this.type = '安全关系',
    this.trust = 5,
    this.intimacy = 5,
    this.conflict = 3,
    this.support = 5,
    this.boundary = 5,
    this.note = '',
  });

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'name': name,
        'type': type,
        'trust_score': trust,
        'intimacy_score': intimacy,
        'conflict_score': conflict,
        'support_score': support,
        'boundary_score': boundary,
        'note': note,
      };

  factory AdaptationCompassRelationshipEntry.fromDb(Map<String, dynamic> map) => AdaptationCompassRelationshipEntry(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        name: acText(map['name']),
        type: acText(map['type']).isEmpty ? '安全关系' : acText(map['type']),
        trust: acInt(map['trust_score'], 5),
        intimacy: acInt(map['intimacy_score'], 5),
        conflict: acInt(map['conflict_score'], 3),
        support: acInt(map['support_score'], 5),
        boundary: acInt(map['boundary_score'], 5),
        note: acText(map['note']),
      );
}

class AdaptationCompassTimelineEntry {
  final int id;
  final int createdAtMs;
  final String chapter;
  final String event;
  final String oldAdaptation;
  final String matureShift;
  final String evidence;

  const AdaptationCompassTimelineEntry({
    this.id = 0,
    this.createdAtMs = 0,
    this.chapter = '当前阶段',
    this.event = '',
    this.oldAdaptation = '',
    this.matureShift = '',
    this.evidence = '',
  });

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'chapter': chapter,
        'event': event,
        'old_adaptation': oldAdaptation,
        'mature_shift': matureShift,
        'evidence': evidence,
      };

  factory AdaptationCompassTimelineEntry.fromDb(Map<String, dynamic> map) => AdaptationCompassTimelineEntry(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        chapter: acText(map['chapter']).isEmpty ? '当前阶段' : acText(map['chapter']),
        event: acText(map['event']),
        oldAdaptation: acText(map['old_adaptation']),
        matureShift: acText(map['mature_shift']),
        evidence: acText(map['evidence']),
      );
}

class AdaptationCompassContributionEntry {
  final int id;
  final int createdAtMs;
  final String target;
  final String form;
  final String motivation;
  final String boundary;
  final String result;
  final int meaning;

  const AdaptationCompassContributionEntry({
    this.id = 0,
    this.createdAtMs = 0,
    this.target = '',
    this.form = '经验分享',
    this.motivation = '',
    this.boundary = '',
    this.result = '',
    this.meaning = 5,
  });

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'target': target,
        'form': form,
        'motivation': motivation,
        'boundary': boundary,
        'result': result,
        'meaning_score': meaning,
      };

  factory AdaptationCompassContributionEntry.fromDb(Map<String, dynamic> map) => AdaptationCompassContributionEntry(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        target: acText(map['target']),
        form: acText(map['form']).isEmpty ? '经验分享' : acText(map['form']),
        motivation: acText(map['motivation']),
        boundary: acText(map['boundary']),
        result: acText(map['result']),
        meaning: acInt(map['meaning_score'], 5),
      );
}

class AdaptationCompassHealthEntry {
  final int id;
  final int createdAtMs;
  final int sleepQuality;
  final int alcoholRisk;
  final int exerciseMinutes;
  final int stressBody;
  final String symptoms;
  final String note;

  const AdaptationCompassHealthEntry({
    this.id = 0,
    this.createdAtMs = 0,
    this.sleepQuality = 5,
    this.alcoholRisk = 0,
    this.exerciseMinutes = 0,
    this.stressBody = 5,
    this.symptoms = '',
    this.note = '',
  });

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'sleep_quality': sleepQuality,
        'alcohol_risk': alcoholRisk,
        'exercise_minutes': exerciseMinutes,
        'stress_body': stressBody,
        'symptoms': symptoms,
        'note': note,
      };

  factory AdaptationCompassHealthEntry.fromDb(Map<String, dynamic> map) => AdaptationCompassHealthEntry(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        sleepQuality: acInt(map['sleep_quality'], 5),
        alcoholRisk: acInt(map['alcohol_risk']),
        exerciseMinutes: acInt(map['exercise_minutes']),
        stressBody: acInt(map['stress_body'], 5),
        symptoms: acText(map['symptoms']),
        note: acText(map['note']),
      );
}

class AdaptationCompassCourseProgress {
  final int id;
  final int createdAtMs;
  final int week;
  final String title;
  final String status;
  final String reflection;

  const AdaptationCompassCourseProgress({
    this.id = 0,
    this.createdAtMs = 0,
    this.week = 1,
    this.title = '',
    this.status = 'done',
    this.reflection = '',
  });

  Map<String, dynamic> toDb() => <String, dynamic>{
        if (id > 0) 'id': id,
        'created_at_ms': createdAtMs,
        'week': week,
        'title': title,
        'status': status,
        'reflection': reflection,
      };

  factory AdaptationCompassCourseProgress.fromDb(Map<String, dynamic> map) => AdaptationCompassCourseProgress(
        id: acInt(map['id']),
        createdAtMs: acInt(map['created_at_ms']),
        week: acInt(map['week'], 1),
        title: acText(map['title']),
        status: acText(map['status']).isEmpty ? 'done' : acText(map['status']),
        reflection: acText(map['reflection']),
      );
}

