import 'dart:convert';

enum ShameScene {
  firstAid,
  eventRecord,
  healthyTransformation,
  innerChild,
  innerCritic,
  deniedPart,
  relationshipBoundary,
  healthyResponsibility,
  todoGoal,
  dailyReview,
}

extension ShameSceneMeta on ShameScene {
  String get key => name;

  String get title => switch (this) {
        ShameScene.firstAid => '羞耻急救',
        ShameScene.eventRecord => '羞耻事件记录',
        ShameScene.healthyTransformation => '健康羞耻转化',
        ShameScene.innerChild => '内在小孩修复',
        ShameScene.innerCritic => '内在批判声音外化',
        ShameScene.deniedPart => '被否认自我部分整合',
        ShameScene.relationshipBoundary => '关系边界与修复',
        ShameScene.healthyResponsibility => '健康责任训练',
        ShameScene.todoGoal => 'Todo 目标羞耻转化',
        ShameScene.dailyReview => '每日羞耻转化复盘',
      };

  String get inputPrompt => switch (this) {
        ShameScene.firstAid => '此刻脑中最刺痛、最想让你隐藏或逃走的那句话是什么？',
        ShameScene.eventRecord => '发生了什么？脑中最刺痛的一句话是什么？',
        ShameScene.healthyTransformation => '写下一句你正在用来攻击自己的话。',
        ShameScene.innerChild => '当前事件让你想起过去哪个相似场景？',
        ShameScene.innerCritic => '那个批判声音原话怎么说？它像谁的声音？',
        ShameScene.deniedPart => '你最不愿承认自己的哪一部分？它什么时候出现？',
        ShameScene.relationshipBoundary => '发生了什么关系事件？你被羞辱、做错了，还是不敢表达需要？',
        ShameScene.healthyResponsibility => '具体发生了什么行为？它给谁造成了什么影响？',
        ShameScene.todoGoal => '写下 Todo 或目标，以及它让你怎样评价自己。',
        ShameScene.dailyReview => '今天哪个时刻触发了羞耻？你做了或没做什么？',
      };
}

class ShameEvent {
  final String id;
  final int createdAt;
  final int intensity;
  final ShameScene scene;
  final String eventFact;
  final String emotion;
  final String bodyReaction;
  final String toxicLanguage;
  final String sourceVoice;
  final String healthyRewrite;
  final String userResponsibility;
  final String notUserResponsibility;
  final String minimumAction;
  final String fallbackAction;
  final String evidenceSentence;
  final String linkedGoalId;
  final bool actionCompleted;

  const ShameEvent({
    required this.id,
    required this.createdAt,
    required this.intensity,
    required this.scene,
    required this.eventFact,
    required this.emotion,
    required this.bodyReaction,
    required this.toxicLanguage,
    required this.sourceVoice,
    required this.healthyRewrite,
    required this.userResponsibility,
    required this.notUserResponsibility,
    required this.minimumAction,
    required this.fallbackAction,
    required this.evidenceSentence,
    this.linkedGoalId = '',
    this.actionCompleted = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'intensity': intensity,
        'scene': scene.key,
        'event_fact': eventFact,
        'emotion': emotion,
        'body_reaction': bodyReaction,
        'toxic_language': toxicLanguage,
        'source_voice': sourceVoice,
        'healthy_rewrite': healthyRewrite,
        'user_responsibility': userResponsibility,
        'not_user_responsibility': notUserResponsibility,
        'minimum_action': minimumAction,
        'fallback_action': fallbackAction,
        'evidence_sentence': evidenceSentence,
        'linked_goal_id': linkedGoalId,
        'action_completed': actionCompleted ? 1 : 0,
      };

  factory ShameEvent.fromMap(Map<String, Object?> map) {
    final sceneName = '${map['scene'] ?? ''}';
    return ShameEvent(
      id: '${map['id']}',
      createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
      intensity: (map['intensity'] as num?)?.toInt() ?? 0,
      scene: ShameScene.values.firstWhere(
        (value) => value.key == sceneName,
        orElse: () => ShameScene.eventRecord,
      ),
      eventFact: '${map['event_fact'] ?? ''}',
      emotion: '${map['emotion'] ?? ''}',
      bodyReaction: '${map['body_reaction'] ?? ''}',
      toxicLanguage: '${map['toxic_language'] ?? ''}',
      sourceVoice: '${map['source_voice'] ?? ''}',
      healthyRewrite: '${map['healthy_rewrite'] ?? ''}',
      userResponsibility: '${map['user_responsibility'] ?? ''}',
      notUserResponsibility: '${map['not_user_responsibility'] ?? ''}',
      minimumAction: '${map['minimum_action'] ?? ''}',
      fallbackAction: '${map['fallback_action'] ?? ''}',
      evidenceSentence: '${map['evidence_sentence'] ?? ''}',
      linkedGoalId: '${map['linked_goal_id'] ?? ''}',
      actionCompleted: (map['action_completed'] as num?)?.toInt() == 1,
    );
  }
}

class InnerVoice {
  final String id;
  final int createdAt;
  final String voiceText;
  final String sourceGuess;
  final String protectionIntent;
  final String toxicMethod;
  final String healthyRewrite;

  const InnerVoice({
    required this.id,
    required this.createdAt,
    required this.voiceText,
    required this.sourceGuess,
    required this.protectionIntent,
    required this.toxicMethod,
    required this.healthyRewrite,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'voice_text': voiceText,
        'source_guess': sourceGuess,
        'protection_intent': protectionIntent,
        'toxic_method': toxicMethod,
        'healthy_rewrite': healthyRewrite,
      };

  factory InnerVoice.fromMap(Map<String, Object?> map) => InnerVoice(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        voiceText: '${map['voice_text'] ?? ''}',
        sourceGuess: '${map['source_guess'] ?? ''}',
        protectionIntent: '${map['protection_intent'] ?? ''}',
        toxicMethod: '${map['toxic_method'] ?? ''}',
        healthyRewrite: '${map['healthy_rewrite'] ?? ''}',
      );
}

class GoalShameProfile {
  final String id;
  final int createdAt;
  final String goalText;
  final String shameTriggers;
  final String nonShameGoal;
  final String problemTreeJson;
  final String actionTreeJson;
  final String dailyAction;
  final String evidenceSentence;

  const GoalShameProfile({
    required this.id,
    required this.createdAt,
    required this.goalText,
    required this.shameTriggers,
    required this.nonShameGoal,
    required this.problemTreeJson,
    required this.actionTreeJson,
    required this.dailyAction,
    required this.evidenceSentence,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'goal_text': goalText,
        'shame_triggers': shameTriggers,
        'non_shame_goal': nonShameGoal,
        'problem_tree_json': problemTreeJson,
        'action_tree_json': actionTreeJson,
        'daily_action': dailyAction,
        'evidence_sentence': evidenceSentence,
      };

  factory GoalShameProfile.fromMap(Map<String, Object?> map) => GoalShameProfile(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        goalText: '${map['goal_text'] ?? ''}',
        shameTriggers: '${map['shame_triggers'] ?? ''}',
        nonShameGoal: '${map['non_shame_goal'] ?? ''}',
        problemTreeJson: '${map['problem_tree_json'] ?? '[]'}',
        actionTreeJson: '${map['action_tree_json'] ?? '[]'}',
        dailyAction: '${map['daily_action'] ?? ''}',
        evidenceSentence: '${map['evidence_sentence'] ?? ''}',
      );
}

class EvidenceItem {
  final String id;
  final int createdAt;
  final String action;
  final String identityEvidence;
  final String valueAnchor;
  final String sourceEventId;

  const EvidenceItem({
    required this.id,
    required this.createdAt,
    required this.action,
    required this.identityEvidence,
    required this.valueAnchor,
    required this.sourceEventId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt,
        'action': action,
        'identity_evidence': identityEvidence,
        'value_anchor': valueAnchor,
        'source_event_id': sourceEventId,
      };

  factory EvidenceItem.fromMap(Map<String, Object?> map) => EvidenceItem(
        id: '${map['id']}',
        createdAt: (map['created_at'] as num?)?.toInt() ?? 0,
        action: '${map['action'] ?? ''}',
        identityEvidence: '${map['identity_evidence'] ?? ''}',
        valueAnchor: '${map['value_anchor'] ?? ''}',
        sourceEventId: '${map['source_event_id'] ?? ''}',
      );
}

class ShameActionOption {
  final String name;
  final String purpose;
  final List<String> steps;
  final String difficulty;
  final String timeRequired;
  final String evidenceAfterDone;

  const ShameActionOption({
    required this.name,
    required this.purpose,
    required this.steps,
    required this.difficulty,
    required this.timeRequired,
    required this.evidenceAfterDone,
  });

  factory ShameActionOption.fromJson(Map<String, dynamic> json) =>
      ShameActionOption(
        name: '${json['name'] ?? ''}',
        purpose: '${json['purpose'] ?? ''}',
        steps: _strings(json['steps']),
        difficulty: '${json['difficulty'] ?? '低'}',
        timeRequired: '${json['time_required'] ?? ''}',
        evidenceAfterDone: '${json['evidence_after_done'] ?? ''}',
      );
}

class ShameAiResult {
  final ShameScene scene;
  final String valueAnchor;
  final String summary;
  final String eventFact;
  final List<String> emotions;
  final List<String> bodyReactions;
  final List<String> toxicLanguages;
  final List<String> shamePatterns;
  final String healthyMessage;
  final List<String> facts;
  final List<String> interpretations;
  final List<String> identityJudgments;
  final List<String> userResponsibilities;
  final List<String> notUserResponsibilities;
  final List<String> repairableParts;
  final List<String> uncontrollableParts;
  final String toxicVersion;
  final String healthyVersion;
  final String identitySentence;
  final String sourceVoice;
  final String protectionIntent;
  final String boundarySentence;
  final List<ShameActionOption> actionOptions;
  final String minimumAction;
  final String minimumTime;
  final String successStandard;
  final String fallbackAction;
  final List<String> reflectionQuestions;
  final String evidenceSentence;
  final String userChoicePrompt;
  final List<Map<String, dynamic>> problemTree;
  final List<Map<String, dynamic>> actionTree;

  const ShameAiResult({
    required this.scene,
    required this.valueAnchor,
    required this.summary,
    required this.eventFact,
    required this.emotions,
    required this.bodyReactions,
    required this.toxicLanguages,
    required this.shamePatterns,
    required this.healthyMessage,
    required this.facts,
    required this.interpretations,
    required this.identityJudgments,
    required this.userResponsibilities,
    required this.notUserResponsibilities,
    required this.repairableParts,
    required this.uncontrollableParts,
    required this.toxicVersion,
    required this.healthyVersion,
    required this.identitySentence,
    required this.sourceVoice,
    required this.protectionIntent,
    required this.boundarySentence,
    required this.actionOptions,
    required this.minimumAction,
    required this.minimumTime,
    required this.successStandard,
    required this.fallbackAction,
    required this.reflectionQuestions,
    required this.evidenceSentence,
    required this.userChoicePrompt,
    this.problemTree = const [],
    this.actionTree = const [],
  });

  factory ShameAiResult.fromJson(
    Map<String, dynamic> json,
    ShameScene fallbackScene,
  ) {
    final core = _map(json['core_recognition']);
    final factStory = _map(json['fact_vs_story']);
    final responsibility = _map(json['responsibility_boundary']);
    final reframe = _map(json['reframe']);
    final minimum = _map(json['today_minimum_action']);
    final externalization = _map(json['voice_externalization']);
    final sceneName = '${json['scene_key'] ?? ''}';
    final scene = ShameScene.values.firstWhere(
      (value) => value.key == sceneName,
      orElse: () => fallbackScene,
    );
    final rawOptions = json['action_options'];
    final options = rawOptions is List
        ? rawOptions
            .whereType<Map>()
            .map((item) => ShameActionOption.fromJson(
                Map<String, dynamic>.from(item)))
            .toList()
        : <ShameActionOption>[];
    return ShameAiResult(
      scene: scene,
      valueAnchor: '${json['value_anchor'] ?? '我不是错误本身'}',
      summary: '${json['user_input_summary'] ?? ''}',
      eventFact: '${core['event_fact'] ?? ''}',
      emotions: _strings(core['emotion']),
      bodyReactions: _strings(core['body_reaction']),
      toxicLanguages: _strings(core['toxic_shame_language']),
      shamePatterns: _strings(core['shame_patterns']),
      healthyMessage: '${core['healthy_shame_message'] ?? ''}',
      facts: _strings(factStory['facts']),
      interpretations: _strings(factStory['interpretations']),
      identityJudgments: _strings(factStory['identity_judgments']),
      userResponsibilities: _strings(responsibility['user_responsibility']),
      notUserResponsibilities:
          _strings(responsibility['not_user_responsibility']),
      repairableParts: _strings(responsibility['repairable_part']),
      uncontrollableParts: _strings(responsibility['uncontrollable_part']),
      toxicVersion: '${reframe['toxic_version'] ?? ''}',
      healthyVersion: '${reframe['healthy_version'] ?? ''}',
      identitySentence: '${reframe['new_identity_sentence'] ?? ''}',
      sourceVoice: '${externalization['source_voice'] ?? ''}',
      protectionIntent: '${externalization['protection_intent'] ?? ''}',
      boundarySentence: '${json['boundary_sentence'] ?? ''}',
      actionOptions: options,
      minimumAction: '${minimum['action'] ?? ''}',
      minimumTime: '${minimum['time_required'] ?? ''}',
      successStandard: '${minimum['success_standard'] ?? ''}',
      fallbackAction: '${minimum['fallback'] ?? ''}',
      reflectionQuestions: _strings(json['reflection_questions']),
      evidenceSentence: '${json['evidence_sentence'] ?? ''}',
      userChoicePrompt: '${json['user_choice_prompt'] ?? ''}',
      problemTree: _mapList(json['problem_tree']),
      actionTree: _mapList(json['action_tree']),
    );
  }
}

List<String> _strings(dynamic value) => value is List
    ? value.map((item) => '$item').where((item) => item.trim().isNotEmpty).toList()
    : <String>[];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> extractJsonObject(String raw) {
  var text = raw
      .trim()
      .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
      .replaceFirst(RegExp(r'\s*```$'), '');
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) text = text.substring(start, end + 1);
  final decoded = jsonDecode(text);
  return decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : <String, dynamic>{};
}
