import 'dart:convert';

class GoalSettingSegment {
  final String id;
  final int lecture;
  final int indexInLecture;
  final String title;
  final String originalText;
  final List<String> concepts;
  final String whatText;
  final String whyText;
  final List<String> howSteps;
  final List<String> cases;
  final String worldZone;
  final String defaultActionTitle;
  final String defaultActionBody;
  final String reflectionQuestion;

  const GoalSettingSegment({
    required this.id,
    required this.lecture,
    required this.indexInLecture,
    required this.title,
    required this.originalText,
    required this.concepts,
    required this.whatText,
    required this.whyText,
    required this.howSteps,
    required this.cases,
    required this.worldZone,
    required this.defaultActionTitle,
    required this.defaultActionBody,
    required this.reflectionQuestion,
  });
}

class GoalSettingAction {
  final String id;
  final String segmentId;
  final String segmentTitle;
  final String level;
  final String source;
  final String title;
  final String body;
  final List<String> steps;
  final String successCriteria;
  final String fallbackAction;
  final String reviewQuestion;
  final int createdAt;
  final String status;
  final String factLog;
  final String obstacleNote;
  final String nextStepNote;

  const GoalSettingAction({
    required this.id,
    required this.segmentId,
    required this.segmentTitle,
    required this.level,
    required this.source,
    required this.title,
    required this.body,
    required this.steps,
    required this.successCriteria,
    required this.fallbackAction,
    required this.reviewQuestion,
    required this.createdAt,
    this.status = 'todo',
    this.factLog = '',
    this.obstacleNote = '',
    this.nextStepNote = '',
  });

  GoalSettingAction copyWith({
    String? id,
    String? segmentId,
    String? segmentTitle,
    String? level,
    String? source,
    String? title,
    String? body,
    List<String>? steps,
    String? successCriteria,
    String? fallbackAction,
    String? reviewQuestion,
    int? createdAt,
    String? status,
    String? factLog,
    String? obstacleNote,
    String? nextStepNote,
  }) => GoalSettingAction(
        id: id ?? this.id,
        segmentId: segmentId ?? this.segmentId,
        segmentTitle: segmentTitle ?? this.segmentTitle,
        level: level ?? this.level,
        source: source ?? this.source,
        title: title ?? this.title,
        body: body ?? this.body,
        steps: steps ?? this.steps,
        successCriteria: successCriteria ?? this.successCriteria,
        fallbackAction: fallbackAction ?? this.fallbackAction,
        reviewQuestion: reviewQuestion ?? this.reviewQuestion,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        factLog: factLog ?? this.factLog,
        obstacleNote: obstacleNote ?? this.obstacleNote,
        nextStepNote: nextStepNote ?? this.nextStepNote,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'segmentId': segmentId,
        'segmentTitle': segmentTitle,
        'level': level,
        'source': source,
        'title': title,
        'body': body,
        'steps': steps,
        'successCriteria': successCriteria,
        'fallbackAction': fallbackAction,
        'reviewQuestion': reviewQuestion,
        'createdAt': createdAt,
        'status': status,
        'factLog': factLog,
        'obstacleNote': obstacleNote,
        'nextStepNote': nextStepNote,
      };

  static GoalSettingAction fromJson(Map<String, dynamic> json) => GoalSettingAction(
        id: '${json['id'] ?? ''}',
        segmentId: '${json['segmentId'] ?? ''}',
        segmentTitle: '${json['segmentTitle'] ?? ''}',
        level: '${json['level'] ?? 'standard'}',
        source: '${json['source'] ?? 'local'}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        steps: _stringList(json['steps']),
        successCriteria: '${json['successCriteria'] ?? ''}',
        fallbackAction: '${json['fallbackAction'] ?? ''}',
        reviewQuestion: '${json['reviewQuestion'] ?? ''}',
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
        status: '${json['status'] ?? 'todo'}',
        factLog: '${json['factLog'] ?? ''}',
        obstacleNote: '${json['obstacleNote'] ?? ''}',
        nextStepNote: '${json['nextStepNote'] ?? ''}',
      );
}


class GoalSettingUnderstandingResult {
  final String whatText;
  final String whyText;
  final String howText;
  final String realCase;
  final String provider;
  final String modelLabel;

  const GoalSettingUnderstandingResult({
    required this.whatText,
    required this.whyText,
    required this.howText,
    required this.realCase,
    required this.provider,
    required this.modelLabel,
  });

  Map<String, dynamic> toJson() => {
        'whatText': whatText,
        'whyText': whyText,
        'howText': howText,
        'realCase': realCase,
        'provider': provider,
        'modelLabel': modelLabel,
      };

  static GoalSettingUnderstandingResult fromJson(Map<String, dynamic> json) => GoalSettingUnderstandingResult(
        whatText: '${json['whatText'] ?? ''}',
        whyText: '${json['whyText'] ?? ''}',
        howText: '${json['howText'] ?? ''}',
        realCase: '${json['realCase'] ?? ''}',
        provider: '${json['provider'] ?? 'local'}',
        modelLabel: '${json['modelLabel'] ?? '本地策略'}',
      );
}

class GoalSettingActionDraftBundle {
  final String segmentId;
  final String userConcern;
  final List<GoalSettingAction> actions;
  final String provider;
  final String modelLabel;
  final int updatedAt;
  final bool usedFallback;
  final String generationNote;
  final String rawResponse;

  const GoalSettingActionDraftBundle({
    required this.segmentId,
    required this.userConcern,
    required this.actions,
    required this.provider,
    required this.modelLabel,
    required this.updatedAt,
    this.usedFallback = false,
    this.generationNote = '',
    this.rawResponse = '',
  });

  Map<String, dynamic> toJson() => {
        'segmentId': segmentId,
        'userConcern': userConcern,
        'actions': actions.map((e) => e.toJson()).toList(),
        'provider': provider,
        'modelLabel': modelLabel,
        'updatedAt': updatedAt,
        'usedFallback': usedFallback,
        'generationNote': generationNote,
        'rawResponse': rawResponse,
      };

  static GoalSettingActionDraftBundle fromJson(Map<String, dynamic> json) => GoalSettingActionDraftBundle(
        segmentId: '${json['segmentId'] ?? ''}',
        userConcern: '${json['userConcern'] ?? ''}',
        actions: _actionsFromDynamic(json['actions']),
        provider: '${json['provider'] ?? 'local'}',
        modelLabel: '${json['modelLabel'] ?? '本地策略'}',
        updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
        usedFallback: json['usedFallback'] == true || '${json['usedFallback']}' == 'true',
        generationNote: '${json['generationNote'] ?? ''}',
        rawResponse: '${json['rawResponse'] ?? ''}',
      );
}

class GoalSettingReview {
  final String id;
  final String segmentId;
  final String segmentTitle;
  final String fact;
  final String feeling;
  final String action;
  final String result;
  final String summary;
  final int createdAt;
  final List<String> evidenceBasis;
  final String learningSummary;
  final String abstractConcept;
  final String retrospectiveGuidance;
  final List<String> retryPlan;
  final String courseAnchor;
  final String sourceActionTitle;
  final String resultJudgement;
  final String resultReasonAnalysis;
  final String strengthsFound;
  final String weaknessesOrBlindspots;
  final String patternInduction;
  final List<String> relatedKnowledgeConcepts;
  final String theoryElevation;
  final String courseConnection;
  final String retryPlanTitle;
  final String retryVisualPlan;
  final Map<String, dynamic> extraSections;

  const GoalSettingReview({
    required this.id,
    required this.segmentId,
    required this.segmentTitle,
    required this.fact,
    required this.feeling,
    required this.action,
    required this.result,
    required this.summary,
    required this.createdAt,
    this.evidenceBasis = const <String>[],
    this.learningSummary = '',
    this.abstractConcept = '',
    this.retrospectiveGuidance = '',
    this.retryPlan = const <String>[],
    this.courseAnchor = '',
    this.sourceActionTitle = '',
    this.resultJudgement = '',
    this.resultReasonAnalysis = '',
    this.strengthsFound = '',
    this.weaknessesOrBlindspots = '',
    this.patternInduction = '',
    this.relatedKnowledgeConcepts = const <String>[],
    this.theoryElevation = '',
    this.courseConnection = '',
    this.retryPlanTitle = '',
    this.retryVisualPlan = '',
    this.extraSections = const <String, dynamic>{},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'segmentId': segmentId,
        'segmentTitle': segmentTitle,
        'fact': fact,
        'feeling': feeling,
        'action': action,
        'result': result,
        'summary': summary,
        'createdAt': createdAt,
        'evidenceBasis': evidenceBasis,
        'learningSummary': learningSummary,
        'abstractConcept': abstractConcept,
        'retrospectiveGuidance': retrospectiveGuidance,
        'retryPlan': retryPlan,
        'courseAnchor': courseAnchor,
        'sourceActionTitle': sourceActionTitle,
        'resultJudgement': resultJudgement,
        'resultReasonAnalysis': resultReasonAnalysis,
        'strengthsFound': strengthsFound,
        'weaknessesOrBlindspots': weaknessesOrBlindspots,
        'patternInduction': patternInduction,
        'relatedKnowledgeConcepts': relatedKnowledgeConcepts,
        'theoryElevation': theoryElevation,
        'courseConnection': courseConnection,
        'retryPlanTitle': retryPlanTitle,
        'retryVisualPlan': retryVisualPlan,
        'extraSections': extraSections,
      };

  static GoalSettingReview fromJson(Map<String, dynamic> json) => GoalSettingReview(
        id: '${json['id'] ?? ''}',
        segmentId: '${json['segmentId'] ?? ''}',
        segmentTitle: '${json['segmentTitle'] ?? ''}',
        fact: '${json['fact'] ?? ''}',
        feeling: '${json['feeling'] ?? ''}',
        action: '${json['action'] ?? ''}',
        result: '${json['result'] ?? ''}',
        summary: '${json['summary'] ?? ''}',
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
        evidenceBasis: _stringList(json['evidenceBasis']),
        learningSummary: '${json['learningSummary'] ?? ''}',
        abstractConcept: '${json['abstractConcept'] ?? ''}',
        retrospectiveGuidance: '${json['retrospectiveGuidance'] ?? ''}',
        retryPlan: _stringList(json['retryPlan']),
        courseAnchor: '${json['courseAnchor'] ?? ''}',
        sourceActionTitle: '${json['sourceActionTitle'] ?? ''}',
        resultJudgement: '${json['resultJudgement'] ?? ''}',
        resultReasonAnalysis: '${json['resultReasonAnalysis'] ?? ''}',
        strengthsFound: '${json['strengthsFound'] ?? ''}',
        weaknessesOrBlindspots: '${json['weaknessesOrBlindspots'] ?? ''}',
        patternInduction: '${json['patternInduction'] ?? ''}',
        relatedKnowledgeConcepts: _stringList(json['relatedKnowledgeConcepts']).isNotEmpty ? _stringList(json['relatedKnowledgeConcepts']) : _stringList(json['related_knowledge_concepts']),
        theoryElevation: '${json['theoryElevation'] ?? json['theory_elevation'] ?? ''}',
        courseConnection: '${json['courseConnection'] ?? ''}',
        retryPlanTitle: '${json['retryPlanTitle'] ?? ''}',
        retryVisualPlan: '${json['retryVisualPlan'] ?? ''}',
        extraSections: _dynamicMap(json['extraSections']).isNotEmpty ? _dynamicMap(json['extraSections']) : _dynamicMap(json['extra_sections']),
      );
}

class GoalSettingFactRecord {
  final String id;
  final String actionId;
  final String segmentId;
  final String actionTitle;
  final String fact;
  final String feedback;
  final String result;
  final String evidence;
  final int createdAt;

  const GoalSettingFactRecord({
    required this.id,
    required this.actionId,
    required this.segmentId,
    required this.actionTitle,
    required this.fact,
    required this.feedback,
    required this.result,
    required this.evidence,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actionId': actionId,
        'segmentId': segmentId,
        'actionTitle': actionTitle,
        'fact': fact,
        'feedback': feedback,
        'result': result,
        'evidence': evidence,
        'createdAt': createdAt,
      };

  static GoalSettingFactRecord fromJson(Map<String, dynamic> json) => GoalSettingFactRecord(
        id: '${json['id'] ?? ''}',
        actionId: '${json['actionId'] ?? ''}',
        segmentId: '${json['segmentId'] ?? ''}',
        actionTitle: '${json['actionTitle'] ?? ''}',
        fact: '${json['fact'] ?? ''}',
        feedback: '${json['feedback'] ?? ''}',
        result: '${json['result'] ?? ''}',
        evidence: '${json['evidence'] ?? ''}',
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
      );
}

class GoalSettingActionLoopInsight {
  final String actionId;
  final String segmentId;
  final List<String> evidenceBasis;
  final String experienceRecap;
  final String resultJudgement;
  final String resultReasonAnalysis;
  final String strengthsFound;
  final String weaknessesOrBlindspots;
  final String patternInduction;
  final List<String> relatedKnowledgeConcepts;
  final String theoryElevation;
  final String courseConnection;
  final String retrospectiveGuidance;
  final String retryPlanTitle;
  final String retryVisualPlan;
  final List<String> retryPlanSteps;
  final String closureSummary;
  final String provider;
  final String modelLabel;
  final bool usedFallback;
  final String generationNote;
  final String promptSource;
  final String promptSourceLabel;
  final String promptSourceNote;
  final String promptTemplateUsed;
  final String requestPrompt;
  final String rawResponse;
  final String retryRawResponse;
  final String fallbackReason;
  final List<String> debugTrace;
  final Map<String, dynamic> extraSections;
  final int createdAt;

  const GoalSettingActionLoopInsight({
    required this.actionId,
    required this.segmentId,
    required this.evidenceBasis,
    required this.experienceRecap,
    required this.resultJudgement,
    required this.resultReasonAnalysis,
    required this.strengthsFound,
    required this.weaknessesOrBlindspots,
    required this.patternInduction,
    required this.relatedKnowledgeConcepts,
    required this.theoryElevation,
    required this.courseConnection,
    required this.retrospectiveGuidance,
    required this.retryPlanTitle,
    required this.retryVisualPlan,
    required this.retryPlanSteps,
    required this.closureSummary,
    required this.provider,
    required this.modelLabel,
    this.usedFallback = false,
    this.generationNote = '',
    this.promptSource = '',
    this.promptSourceLabel = '',
    this.promptSourceNote = '',
    this.promptTemplateUsed = '',
    this.requestPrompt = '',
    this.rawResponse = '',
    this.retryRawResponse = '',
    this.fallbackReason = '',
    this.debugTrace = const <String>[],
    this.extraSections = const <String, dynamic>{},
    required this.createdAt,
  });

  String get factSummary => experienceRecap;
  String get feedbackSummary => resultReasonAnalysis;
  String get abstractConcept => patternInduction;
  String get guidanceSummary => retrospectiveGuidance;
  List<String> get nextChain {
    final items = <String>[];
    if (retryPlanTitle.trim().isNotEmpty) items.add(retryPlanTitle.trim());
    if (retryVisualPlan.trim().isNotEmpty) items.add(retryVisualPlan.trim());
    items.addAll(retryPlanSteps.where((e) => e.trim().isNotEmpty));
    return items;
  }

  Map<String, dynamic> toJson() => {
        'actionId': actionId,
        'segmentId': segmentId,
        'evidenceBasis': evidenceBasis,
        'experienceRecap': experienceRecap,
        'resultJudgement': resultJudgement,
        'resultReasonAnalysis': resultReasonAnalysis,
        'strengthsFound': strengthsFound,
        'weaknessesOrBlindspots': weaknessesOrBlindspots,
        'patternInduction': patternInduction,
        'relatedKnowledgeConcepts': relatedKnowledgeConcepts,
        'theoryElevation': theoryElevation,
        'courseConnection': courseConnection,
        'retrospectiveGuidance': retrospectiveGuidance,
        'retryPlanTitle': retryPlanTitle,
        'retryVisualPlan': retryVisualPlan,
        'retryPlanSteps': retryPlanSteps,
        'closureSummary': closureSummary,
        'provider': provider,
        'modelLabel': modelLabel,
        'usedFallback': usedFallback,
        'generationNote': generationNote,
        'promptSource': promptSource,
        'promptSourceLabel': promptSourceLabel,
        'promptSourceNote': promptSourceNote,
        'promptTemplateUsed': promptTemplateUsed,
        'requestPrompt': requestPrompt,
        'rawResponse': rawResponse,
        'retryRawResponse': retryRawResponse,
        'fallbackReason': fallbackReason,
        'debugTrace': debugTrace,
        'extraSections': extraSections,
        'createdAt': createdAt,
      };

  static GoalSettingActionLoopInsight fromJson(Map<String, dynamic> json) {
    final legacyFact = '${json['factSummary'] ?? ''}';
    final legacyFeedback = '${json['feedbackSummary'] ?? ''}';
    final legacyAbstract = '${json['abstractConcept'] ?? ''}';
    final legacyGuidance = '${json['guidanceSummary'] ?? ''}';
    final legacyNext = _stringList(json['nextChain']);
    return GoalSettingActionLoopInsight(
      actionId: '${json['actionId'] ?? ''}',
      segmentId: '${json['segmentId'] ?? ''}',
      evidenceBasis: _stringList(json['evidenceBasis']).isNotEmpty ? _stringList(json['evidenceBasis']) : _stringList(json['evidence_basis']),
      experienceRecap: '${json['experienceRecap'] ?? legacyFact}',
      resultJudgement: '${json['resultJudgement'] ?? ''}',
      resultReasonAnalysis: '${json['resultReasonAnalysis'] ?? legacyFeedback}',
      strengthsFound: '${json['strengthsFound'] ?? ''}',
      weaknessesOrBlindspots: '${json['weaknessesOrBlindspots'] ?? ''}',
      patternInduction: '${json['patternInduction'] ?? legacyAbstract}',
      relatedKnowledgeConcepts: _stringList(json['relatedKnowledgeConcepts']).isNotEmpty ? _stringList(json['relatedKnowledgeConcepts']) : _stringList(json['related_knowledge_concepts']),
      theoryElevation: '${json['theoryElevation'] ?? json['theory_elevation'] ?? ''}',
      courseConnection: '${json['courseConnection'] ?? ''}',
      retrospectiveGuidance: '${json['retrospectiveGuidance'] ?? legacyGuidance}',
      retryPlanTitle: '${json['retryPlanTitle'] ?? (legacyNext.isNotEmpty ? legacyNext.first : '')}',
      retryVisualPlan: '${json['retryVisualPlan'] ?? (legacyNext.length > 1 ? legacyNext[1] : '')}',
      retryPlanSteps: _stringList(json['retryPlanSteps']).isNotEmpty ? _stringList(json['retryPlanSteps']) : (legacyNext.length > 2 ? legacyNext.sublist(2) : const <String>[]),
      closureSummary: '${json['closureSummary'] ?? ''}',
      provider: '${json['provider'] ?? 'local'}',
      modelLabel: '${json['modelLabel'] ?? '本地策略'}',
      usedFallback: json['usedFallback'] == true || '${json['usedFallback']}' == 'true',
      generationNote: '${json['generationNote'] ?? ''}',
      promptSource: '${json['promptSource'] ?? ''}',
      promptSourceLabel: '${json['promptSourceLabel'] ?? ''}',
      promptSourceNote: '${json['promptSourceNote'] ?? ''}',
      promptTemplateUsed: '${json['promptTemplateUsed'] ?? ''}',
      requestPrompt: '${json['requestPrompt'] ?? ''}',
      rawResponse: '${json['rawResponse'] ?? ''}',
      retryRawResponse: '${json['retryRawResponse'] ?? ''}',
      fallbackReason: '${json['fallbackReason'] ?? ''}',
      debugTrace: _stringList(json['debugTrace']),
      extraSections: _dynamicMap(json['extraSections']).isNotEmpty ? _dynamicMap(json['extraSections']) : _dynamicMap(json['extra_sections']),
      createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
    );
  }
}

class GoalSettingPersonaProfile {
  final String lifeRole;
  final String currentFocus;
  final String currentProblem;
  final String currentGoal;
  final String motivationBlock;
  final int updatedAt;

  const GoalSettingPersonaProfile({
    required this.lifeRole,
    required this.currentFocus,
    required this.currentProblem,
    required this.currentGoal,
    required this.motivationBlock,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'lifeRole': lifeRole,
        'currentFocus': currentFocus,
        'currentProblem': currentProblem,
        'currentGoal': currentGoal,
        'motivationBlock': motivationBlock,
        'updatedAt': updatedAt,
      };

  static GoalSettingPersonaProfile fromJson(Map<String, dynamic> json) => GoalSettingPersonaProfile(
        lifeRole: '${json['lifeRole'] ?? '探索者'}',
        currentFocus: '${json['currentFocus'] ?? '目标设定'}',
        currentProblem: '${json['currentProblem'] ?? ''}',
        currentGoal: '${json['currentGoal'] ?? ''}',
        motivationBlock: '${json['motivationBlock'] ?? ''}',
        updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
      );
}

class GoalSettingWorldState {
  final List<String> unlockedZones;
  final String currentZone;
  final int updatedAt;

  const GoalSettingWorldState({
    required this.unlockedZones,
    required this.currentZone,
    required this.updatedAt,
  });

  GoalSettingWorldState copyWith({
    List<String>? unlockedZones,
    String? currentZone,
    int? updatedAt,
  }) => GoalSettingWorldState(
        unlockedZones: unlockedZones ?? this.unlockedZones,
        currentZone: currentZone ?? this.currentZone,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'unlockedZones': unlockedZones,
        'currentZone': currentZone,
        'updatedAt': updatedAt,
      };

  static GoalSettingWorldState fromJson(Map<String, dynamic> json) => GoalSettingWorldState(
        unlockedZones: _stringList(json['unlockedZones']),
        currentZone: '${json['currentZone'] ?? '聚焦之塔'}',
        updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
      );
}


List<GoalSettingAction> _actionsFromDynamic(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => GoalSettingAction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => GoalSettingAction.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
  }
  return <GoalSettingAction>[];
}


Map<String, dynamic> _dynamicMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const <String, dynamic>{};
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((e) => '$e').toList();
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded.map((e) => '$e').toList();
    } catch (_) {}
  }
  return const <String>[];
}

String actionsToString(List<GoalSettingAction> actions) => jsonEncode(actions.map((e) => e.toJson()).toList());
List<GoalSettingAction> actionsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <GoalSettingAction>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.whereType<Map>().map((e) => GoalSettingAction.fromJson(Map<String, dynamic>.from(e))).toList();
  } catch (_) {}
  return const <GoalSettingAction>[];
}

String reviewsToString(List<GoalSettingReview> reviews) => jsonEncode(reviews.map((e) => e.toJson()).toList());
List<GoalSettingReview> reviewsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <GoalSettingReview>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.whereType<Map>().map((e) => GoalSettingReview.fromJson(Map<String, dynamic>.from(e))).toList();
  } catch (_) {}
  return const <GoalSettingReview>[];
}

String? personaToString(GoalSettingPersonaProfile? persona) => persona == null ? null : jsonEncode(persona.toJson());
GoalSettingPersonaProfile? personaFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return GoalSettingPersonaProfile.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {}
  return null;
}

String? worldStateToString(GoalSettingWorldState? state) => state == null ? null : jsonEncode(state.toJson());
GoalSettingWorldState? worldStateFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return GoalSettingWorldState.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {}
  return null;
}


String factRecordsToString(List<GoalSettingFactRecord> items) => jsonEncode(items.map((e) => e.toJson()).toList());
List<GoalSettingFactRecord> factRecordsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <GoalSettingFactRecord>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.whereType<Map>().map((e) => GoalSettingFactRecord.fromJson(Map<String, dynamic>.from(e))).toList();
  } catch (_) {}
  return const <GoalSettingFactRecord>[];
}

String? loopInsightToString(GoalSettingActionLoopInsight? item) => item == null ? null : jsonEncode(item.toJson());
GoalSettingActionLoopInsight? loopInsightFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return GoalSettingActionLoopInsight.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {}
  return null;
}
