import 'dart:convert';

class ShameEvent {
  final String id;
  final int createdAt;
  final int intensity;
  final String eventFact;
  final String toxicLanguage;
  final String emotion;
  final String bodyReaction;
  final String responsibility;
  final String notResponsibility;
  final String healthyRewrite;
  final String minimumAction;
  final String evidenceSentence;
  final String linkedGoalId;

  const ShameEvent({required this.id, required this.createdAt, required this.intensity, required this.eventFact, required this.toxicLanguage, required this.emotion, required this.bodyReaction, required this.responsibility, required this.notResponsibility, required this.healthyRewrite, required this.minimumAction, required this.evidenceSentence, this.linkedGoalId = ''});

  Map<String, Object?> toMap() => {'id': id, 'created_at': createdAt, 'intensity': intensity, 'event_fact': eventFact, 'toxic_language': toxicLanguage, 'emotion': emotion, 'body_reaction': bodyReaction, 'responsibility': responsibility, 'not_responsibility': notResponsibility, 'healthy_rewrite': healthyRewrite, 'minimum_action': minimumAction, 'evidence_sentence': evidenceSentence, 'linked_goal_id': linkedGoalId};
  factory ShameEvent.fromMap(Map<String, Object?> m) => ShameEvent(id: '${m['id']}', createdAt: (m['created_at'] as num?)?.toInt() ?? 0, intensity: (m['intensity'] as num?)?.toInt() ?? 0, eventFact: '${m['event_fact'] ?? ''}', toxicLanguage: '${m['toxic_language'] ?? ''}', emotion: '${m['emotion'] ?? ''}', bodyReaction: '${m['body_reaction'] ?? ''}', responsibility: '${m['responsibility'] ?? ''}', notResponsibility: '${m['not_responsibility'] ?? ''}', healthyRewrite: '${m['healthy_rewrite'] ?? ''}', minimumAction: '${m['minimum_action'] ?? ''}', evidenceSentence: '${m['evidence_sentence'] ?? ''}', linkedGoalId: '${m['linked_goal_id'] ?? ''}');
}

class ShameAiResult {
  final String valueAnchor, summary, healthyMessage, responsibility, notResponsibility, healthyVersion, identitySentence, minimumAction, fallback, evidenceSentence;
  final List<String> toxicLanguages, facts, interpretations, actions, reflectionQuestions;
  const ShameAiResult({required this.valueAnchor, required this.summary, required this.healthyMessage, required this.responsibility, required this.notResponsibility, required this.healthyVersion, required this.identitySentence, required this.minimumAction, required this.fallback, required this.evidenceSentence, this.toxicLanguages = const [], this.facts = const [], this.interpretations = const [], this.actions = const [], this.reflectionQuestions = const []});
  factory ShameAiResult.fromJson(Map<String, dynamic> j) {
    List<String> list(dynamic v) => v is List ? v.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() : [];
    final core = Map<String, dynamic>.from(j['core_recognition'] is Map ? j['core_recognition'] : {});
    final fvs = Map<String, dynamic>.from(j['fact_vs_story'] is Map ? j['fact_vs_story'] : {});
    final rb = Map<String, dynamic>.from(j['responsibility_boundary'] is Map ? j['responsibility_boundary'] : {});
    final re = Map<String, dynamic>.from(j['reframe'] is Map ? j['reframe'] : {});
    final min = Map<String, dynamic>.from(j['today_minimum_action'] is Map ? j['today_minimum_action'] : {});
    final options = j['action_options'] is List ? j['action_options'] as List : const [];
    return ShameAiResult(valueAnchor: '${j['value_anchor'] ?? '我不是错误本身'}', summary: '${j['user_input_summary'] ?? ''}', healthyMessage: '${core['healthy_shame_message'] ?? ''}', responsibility: list(rb['user_responsibility']).join('；'), notResponsibility: list(rb['not_user_responsibility']).join('；'), healthyVersion: '${re['healthy_version'] ?? ''}', identitySentence: '${re['new_identity_sentence'] ?? ''}', minimumAction: '${min['action'] ?? ''}', fallback: '${min['fallback'] ?? ''}', evidenceSentence: '${j['evidence_sentence'] ?? ''}', toxicLanguages: list(core['toxic_shame_language']), facts: list(fvs['facts']), interpretations: list(fvs['interpretations']), actions: options.map((e) => e is Map ? '${e['name'] ?? ''}：${e['purpose'] ?? ''}' : '$e').where((e) => e.trim().isNotEmpty).toList(), reflectionQuestions: list(j['reflection_questions']));
  }
}

Map<String, dynamic> extractJson(String raw) {
  var text = raw.trim().replaceFirst(RegExp(r'^```(?:json)?\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start >= 0 && end > start) text = text.substring(start, end + 1);
  final decoded = jsonDecode(text);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
}
