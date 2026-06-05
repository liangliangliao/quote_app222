import 'dart:convert';

class HappinessUnit {
  final String id;
  final int lecture;
  final int indexInLecture;
  final String title;
  final String oneLiner;
  final String fullContent;
  final String summary;
  final List<String> concepts;
  final List<String> tags;
  final String whatText;
  final String whyText;
  final List<String> howSteps;
  final List<String> courseCases;
  final List<String> lifeCases;
  final String defaultActionTitle;
  final String defaultActionBody;
  final String scene;
  final String reflectionQuestion;

  const HappinessUnit({
    required this.id,
    required this.lecture,
    required this.indexInLecture,
    required this.title,
    required this.oneLiner,
    required this.fullContent,
    required this.summary,
    required this.concepts,
    required this.tags,
    required this.whatText,
    required this.whyText,
    required this.howSteps,
    required this.courseCases,
    required this.lifeCases,
    required this.defaultActionTitle,
    required this.defaultActionBody,
    required this.scene,
    required this.reflectionQuestion,
  });
}

class HappinessAction {
  final String id;
  final String unitId;
  final String unitTitle;
  final String source; // default / ai / user_custom
  final String title;
  final String body;
  final String difficulty;
  final String duration;
  final String successCriteria;
  final String fallbackAction;
  final String reviewQuestion;
  final int createdAt;
  final String status; // todo / doing / done / skipped
  final String factLog;
  final String planNote;
  final String obstacleNote;
  final String nextStepNote;
  final String realityRole;
  final String realityVersion;
  final List<String> steps;
  final List<bool> stepMarks;

  const HappinessAction({
    required this.id,
    required this.unitId,
    required this.unitTitle,
    required this.source,
    required this.title,
    required this.body,
    required this.difficulty,
    required this.duration,
    required this.successCriteria,
    required this.fallbackAction,
    required this.reviewQuestion,
    required this.createdAt,
    this.status = 'todo',
    this.factLog = '',
    this.planNote = '',
    this.obstacleNote = '',
    this.nextStepNote = '',
    this.realityRole = '',
    this.realityVersion = '',
    this.steps = const <String>[],
    this.stepMarks = const <bool>[],
  });

  bool get done => status == 'done';

  HappinessAction copyWith({String? status, String? factLog, String? planNote, String? obstacleNote, String? nextStepNote, String? realityRole, String? realityVersion, List<String>? steps, List<bool>? stepMarks}) => HappinessAction(
        id: id,
        unitId: unitId,
        unitTitle: unitTitle,
        source: source,
        title: title,
        body: body,
        difficulty: difficulty,
        duration: duration,
        successCriteria: successCriteria,
        fallbackAction: fallbackAction,
        reviewQuestion: reviewQuestion,
        createdAt: createdAt,
        status: status ?? this.status,
        factLog: factLog ?? this.factLog,
        planNote: planNote ?? this.planNote,
        obstacleNote: obstacleNote ?? this.obstacleNote,
        nextStepNote: nextStepNote ?? this.nextStepNote,
        realityRole: realityRole ?? this.realityRole,
        realityVersion: realityVersion ?? this.realityVersion,
        steps: steps ?? this.steps,
        stepMarks: stepMarks ?? this.stepMarks,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'unitTitle': unitTitle,
        'source': source,
        'title': title,
        'body': body,
        'difficulty': difficulty,
        'duration': duration,
        'successCriteria': successCriteria,
        'fallbackAction': fallbackAction,
        'reviewQuestion': reviewQuestion,
        'createdAt': createdAt,
        'status': status,
        'factLog': factLog,
        'planNote': planNote,
        'obstacleNote': obstacleNote,
        'nextStepNote': nextStepNote,
        'realityRole': realityRole,
        'realityVersion': realityVersion,
        'steps': steps,
        'stepMarks': stepMarks,
        'done': done ? 1 : 0,
      };

  static HappinessAction fromJson(Map<String, dynamic> json) => HappinessAction(
        id: '${json['id'] ?? ''}',
        unitId: '${json['unitId'] ?? ''}',
        unitTitle: '${json['unitTitle'] ?? ''}',
        source: '${json['source'] ?? 'default'}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        difficulty: '${json['difficulty'] ?? 'Easy'}',
        duration: '${json['duration'] ?? '10分钟'}',
        successCriteria: '${json['successCriteria'] ?? ''}',
        fallbackAction: '${json['fallbackAction'] ?? ''}',
        reviewQuestion: '${json['reviewQuestion'] ?? ''}',
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
        status: _parseStatus(json),
        factLog: '${json['factLog'] ?? ''}',
        planNote: '${json['planNote'] ?? ''}',
        obstacleNote: '${json['obstacleNote'] ?? ''}',
        nextStepNote: '${json['nextStepNote'] ?? ''}',
        realityRole: '${json['realityRole'] ?? ''}',
        realityVersion: '${json['realityVersion'] ?? ''}',
        steps: _parseSteps(json['steps']),
        stepMarks: _parseStepMarks(json['stepMarks']),
      );
}

class HappinessReviewEntry {
  final String id;
  final String unitId;
  final String unitTitle;
  final String fact;
  final String feeling;
  final String thought;
  final String action;
  final String outcome;
  final String aiSummary;
  final int createdAt;

  const HappinessReviewEntry({
    required this.id,
    required this.unitId,
    required this.unitTitle,
    required this.fact,
    required this.feeling,
    required this.thought,
    required this.action,
    required this.outcome,
    required this.aiSummary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'unitTitle': unitTitle,
        'fact': fact,
        'feeling': feeling,
        'thought': thought,
        'action': action,
        'outcome': outcome,
        'aiSummary': aiSummary,
        'createdAt': createdAt,
      };

  static HappinessReviewEntry fromJson(Map<String, dynamic> json) => HappinessReviewEntry(
        id: '${json['id'] ?? ''}',
        unitId: '${json['unitId'] ?? ''}',
        unitTitle: '${json['unitTitle'] ?? ''}',
        fact: '${json['fact'] ?? ''}',
        feeling: '${json['feeling'] ?? ''}',
        thought: '${json['thought'] ?? ''}',
        action: '${json['action'] ?? ''}',
        outcome: '${json['outcome'] ?? ''}',
        aiSummary: '${json['aiSummary'] ?? ''}',
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
      );
}




List<bool> _parseStepMarks(dynamic raw) {
  if (raw is List) return raw.map((e) => e == true || '$e' == '1' || '$e'.toLowerCase() == 'true').toList();
  return <bool>[];
}

List<String> _parseSteps(dynamic raw) {
  if (raw is List) return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
  if (raw is String && raw.trim().isNotEmpty) {
    return raw
        .split(RegExp(r'\n+'))
        .map((e) => e.replaceFirst(RegExp(r'^\d+[\.|、]\s*'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return <String>[];
}

String _parseStatus(Map<String, dynamic> json) {
  final raw = '${json['status'] ?? ''}'.trim();
  if (raw.isNotEmpty) return raw;
  final done = '${json['done'] ?? 0}' == '1' || json['done'] == true;
  return done ? 'done' : 'todo';
}

List<HappinessAction> actionsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <HappinessAction>[];
  try {
    final list = jsonDecode(raw);
    if (list is List) {
      return list.whereType<Map>().map((e) => HappinessAction.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  } catch (_) {}
  return <HappinessAction>[];
}

String actionsToString(List<HappinessAction> items) => jsonEncode(items.map((e) => e.toJson()).toList());

List<HappinessReviewEntry> reviewsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <HappinessReviewEntry>[];
  try {
    final list = jsonDecode(raw);
    if (list is List) {
      return list.whereType<Map>().map((e) => HappinessReviewEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  } catch (_) {}
  return <HappinessReviewEntry>[];
}

String reviewsToString(List<HappinessReviewEntry> items) => jsonEncode(items.map((e) => e.toJson()).toList());
