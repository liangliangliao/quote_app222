
import 'dart:convert';

class PositivePsychSegment {
  final String id;
  final int lecture;
  final int indexInLecture;
  final String title;
  final String subtitle;
  final String originalText;
  final List<String> concepts;
  final String whatText;
  final String whyText;
  final List<String> howSteps;
  final List<String> cases;
  final String scene;
  final String defaultActionTitle;
  final String defaultActionBody;
  final String reflectionQuestion;

  const PositivePsychSegment({
    required this.id,
    required this.lecture,
    required this.indexInLecture,
    required this.title,
    required this.subtitle,
    required this.originalText,
    required this.concepts,
    required this.whatText,
    required this.whyText,
    required this.howSteps,
    required this.cases,
    required this.scene,
    required this.defaultActionTitle,
    required this.defaultActionBody,
    required this.reflectionQuestion,
  });
}

class PositivePsychAction {
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

  const PositivePsychAction({
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

  PositivePsychAction copyWith({
    String? status,
    String? factLog,
    String? obstacleNote,
    String? nextStepNote,
  }) => PositivePsychAction(
    id: id,
    segmentId: segmentId,
    segmentTitle: segmentTitle,
    level: level,
    source: source,
    title: title,
    body: body,
    steps: steps,
    successCriteria: successCriteria,
    fallbackAction: fallbackAction,
    reviewQuestion: reviewQuestion,
    createdAt: createdAt,
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

  static PositivePsychAction fromJson(Map<String, dynamic> json) => PositivePsychAction(
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

class PositivePsychReview {
  final String id;
  final String segmentId;
  final String segmentTitle;
  final String fact;
  final String thought;
  final String feeling;
  final String action;
  final String result;
  final String summary;
  final int createdAt;

  const PositivePsychReview({
    required this.id,
    required this.segmentId,
    required this.segmentTitle,
    required this.fact,
    required this.thought,
    required this.feeling,
    required this.action,
    required this.result,
    required this.summary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'segmentId': segmentId,
    'segmentTitle': segmentTitle,
    'fact': fact,
    'thought': thought,
    'feeling': feeling,
    'action': action,
    'result': result,
    'summary': summary,
    'createdAt': createdAt,
  };

  static PositivePsychReview fromJson(Map<String, dynamic> json) => PositivePsychReview(
    id: '${json['id'] ?? ''}',
    segmentId: '${json['segmentId'] ?? ''}',
    segmentTitle: '${json['segmentTitle'] ?? ''}',
    fact: '${json['fact'] ?? ''}',
    thought: '${json['thought'] ?? ''}',
    feeling: '${json['feeling'] ?? ''}',
    action: '${json['action'] ?? ''}',
    result: '${json['result'] ?? ''}',
    summary: '${json['summary'] ?? ''}',
    createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
  );
}


class PositivePsychPersonaProfile {
  final String selfType;
  final String currentFocus;
  final String currentProblem;
  final String biasType;
  final String growthGoal;
  final int updatedAt;

  const PositivePsychPersonaProfile({
    required this.selfType,
    required this.currentFocus,
    required this.currentProblem,
    required this.biasType,
    required this.growthGoal,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'selfType': selfType,
    'currentFocus': currentFocus,
    'currentProblem': currentProblem,
    'biasType': biasType,
    'growthGoal': growthGoal,
    'updatedAt': updatedAt,
  };

  static PositivePsychPersonaProfile fromJson(Map<String, dynamic> json) => PositivePsychPersonaProfile(
    selfType: '${json['selfType'] ?? 'mixed'}',
    currentFocus: '${json['currentFocus'] ?? '工作与学习'}',
    currentProblem: '${json['currentProblem'] ?? ''}',
    biasType: '${json['biasType'] ?? 'mixed'}',
    growthGoal: '${json['growthGoal'] ?? ''}',
    updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
  );
}

class PositivePsychWorldState {
  final List<String> unlockedNodes;
  final String currentNode;
  final int updatedAt;

  const PositivePsychWorldState({
    required this.unlockedNodes,
    required this.currentNode,
    required this.updatedAt,
  });

  PositivePsychWorldState copyWith({
    List<String>? unlockedNodes,
    String? currentNode,
    int? updatedAt,
  }) => PositivePsychWorldState(
    unlockedNodes: unlockedNodes ?? this.unlockedNodes,
    currentNode: currentNode ?? this.currentNode,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'unlockedNodes': unlockedNodes,
    'currentNode': currentNode,
    'updatedAt': updatedAt,
  };

  static PositivePsychWorldState fromJson(Map<String, dynamic> json) => PositivePsychWorldState(
    unlockedNodes: _stringList(json['unlockedNodes']),
    currentNode: '${json['currentNode'] ?? '解释风格学院'}',
    updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
  );
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((e) => '$e').toList();
  return <String>[];
}

String actionsToString(List<PositivePsychAction> items) => jsonEncode(items.map((e) => e.toJson()).toList());
List<PositivePsychAction> actionsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <PositivePsychAction>[];
  try {
    final obj = jsonDecode(raw);
    if (obj is List) return obj.map((e) => PositivePsychAction.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } catch (_) {}
  return <PositivePsychAction>[];
}

String reviewsToString(List<PositivePsychReview> items) => jsonEncode(items.map((e) => e.toJson()).toList());
List<PositivePsychReview> reviewsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <PositivePsychReview>[];
  try {
    final obj = jsonDecode(raw);
    if (obj is List) return obj.map((e) => PositivePsychReview.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } catch (_) {}
  return <PositivePsychReview>[];
}


String? personaToString(PositivePsychPersonaProfile? item) => item == null ? null : jsonEncode(item.toJson());
PositivePsychPersonaProfile? personaFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final obj = jsonDecode(raw);
    if (obj is Map) return PositivePsychPersonaProfile.fromJson(Map<String, dynamic>.from(obj));
  } catch (_) {}
  return null;
}

String? worldStateToString(PositivePsychWorldState? item) => item == null ? null : jsonEncode(item.toJson());
PositivePsychWorldState? worldStateFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final obj = jsonDecode(raw);
    if (obj is Map) return PositivePsychWorldState.fromJson(Map<String, dynamic>.from(obj));
  } catch (_) {}
  return null;
}
