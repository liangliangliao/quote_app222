import 'dart:convert';

List<String> willStringListFromJson(Object? value) {
  if (value == null) return const <String>[];
  if (value is List) {
    return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }
  final text = value.toString().trim();
  if (text.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(text);
    if (decoded is List) {
      return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
    }
  } catch (_) {}
  return text
      .split(RegExp(r'[\n，,；;、]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

String willStringListToJson(List<String> values) => jsonEncode(values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList());

int willIntValue(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

String willTextValue(Object? value, [String fallback = '']) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? fallback : text;
}

class JamesWillCompetitionItem {
  final String type;
  final String content;
  final int strength;
  final String role;

  const JamesWillCompetitionItem({
    required this.type,
    required this.content,
    required this.strength,
    required this.role,
  });

  factory JamesWillCompetitionItem.fromJson(Map<String, dynamic> json) {
    return JamesWillCompetitionItem(
      type: willTextValue(json['type'], '行动观念'),
      content: willTextValue(json['content'], '打开任务，执行第一步'),
      strength: willIntValue(json['strength'], 60).clamp(0, 100).toInt(),
      role: willTextValue(json['role'], '推动或阻碍行动'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'content': content,
        'strength': strength,
        'role': role,
      };
}

class JamesWillActionIdea {
  final String id;
  final String originalGoal;
  final String goalNote;
  final String coreValue;
  final String actionIdea;
  final String firstBodyAction;
  final String minimumAction;
  final String fiveMinuteVersion;
  final String attentionAnchor;
  final List<String> obstacleIdeas;
  final List<String> replacementIdeas;
  final List<JamesWillCompetitionItem> competitionItems;
  final String coachMessage;
  final String aiProvider;
  final String aiModelLabel;
  final bool aiUsedFallback;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  const JamesWillActionIdea({
    required this.id,
    required this.originalGoal,
    required this.goalNote,
    required this.coreValue,
    required this.actionIdea,
    required this.firstBodyAction,
    required this.minimumAction,
    required this.fiveMinuteVersion,
    required this.attentionAnchor,
    required this.obstacleIdeas,
    required this.replacementIdeas,
    required this.competitionItems,
    required this.coachMessage,
    required this.aiProvider,
    required this.aiModelLabel,
    required this.aiUsedFallback,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory JamesWillActionIdea.local({required String goal, String note = '', Map<String, String>? aiState}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanGoal = goal.trim().isEmpty ? '完成一个重要行动' : goal.trim();
    final lower = cleanGoal.toLowerCase();
    String coreValue = '长期成长、自我负责、重新掌控生活';
    String action = '今天选择一个最小版本，执行 5 分钟';
    String first = '站起来，把身体移动到行动发生的地方';
    String min = '打开相关材料，完成第一小步';
    String five = '只做 5 分钟，不要求一次完成全部';
    if (cleanGoal.contains('工作') || cleanGoal.contains('简历') || cleanGoal.contains('岗位') || lower.contains('job')) {
      coreValue = '生存、自立、现实掌控感';
      action = '今天打开招聘渠道，筛选并投递 1 个岗位';
      first = '打开招聘 App 或简历文档';
      min = '收藏 1 个合适岗位，或修改简历第一句话';
      five = '5 分钟内只处理 1 个岗位或 1 段简历';
    } else if (cleanGoal.contains('学习') || cleanGoal.contains('阅读') || cleanGoal.contains('心理') || lower.contains('study')) {
      coreValue = '理解自己、长期成长、建立方法论';
      action = '今晚阅读或学习 20 分钟';
      first = '坐到书桌前，打开书或学习资料';
      min = '读第一段或完成第一道题';
      five = '只读 5 分钟，只要求进入状态';
    } else if (cleanGoal.contains('运动') || cleanGoal.contains('健身') || lower.contains('exercise')) {
      coreValue = '身体能量、持续性、自我照料';
      action = '今天完成一次低门槛身体训练';
      first = '站起来，穿好鞋或铺开垫子';
      min = '做 3 个深蹲或走 2 分钟';
      five = '只运动 5 分钟，不追求强度';
    } else if (cleanGoal.contains('拖延') || cleanGoal.contains('自律') || cleanGoal.contains('行动')) {
      coreValue = '行动先于心情，把知道变成做到';
      action = '现在启动一个被拖延任务的 5 分钟版本';
      first = '把手机放远，打开任务入口';
      min = '只完成任务的第一小步';
      five = '只做 5 分钟，结束后再决定是否继续';
    }
    final obstacles = <String>['太累了，明天再说', '刷手机更舒服', '做了也不一定有用'];
    final replacements = <String>['只做最低版本', '行动先于心情', '一次行动不是改变全部，而是保持方向'];
    final competition = <JamesWillCompetitionItem>[
      JamesWillCompetitionItem(type: '行动观念', content: action, strength: 62, role: '推动行动'),
      JamesWillCompetitionItem(type: '阻碍观念', content: obstacles[0], strength: 75, role: '降低启动'),
      JamesWillCompetitionItem(type: '逃避观念', content: obstacles[1], strength: 82, role: '转移注意'),
      JamesWillCompetitionItem(type: '价值观念', content: coreValue, strength: 70, role: '支撑长期方向'),
    ];
    return JamesWillActionIdea(
      id: 'will_${now}_${cleanGoal.hashCode.abs()}',
      originalGoal: cleanGoal,
      goalNote: note.trim(),
      coreValue: coreValue,
      actionIdea: action,
      firstBodyAction: first,
      minimumAction: min,
      fiveMinuteVersion: five,
      attentionAnchor: '我只需要让这个行动观念占据 5 分钟。',
      obstacleIdeas: obstacles,
      replacementIdeas: replacements,
      competitionItems: competition,
      coachMessage: '这不是要求你立刻改变全部人生，而是把目标落到此时此刻的一个身体动作。',
      aiProvider: aiState?['provider'] ?? 'local',
      aiModelLabel: aiState?['label'] ?? '本地策略',
      aiUsedFallback: true,
      status: 'active',
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  factory JamesWillActionIdea.fromAiJson({
    required Map<String, dynamic> json,
    required JamesWillActionIdea fallback,
    String? provider,
    String? modelLabel,
    bool usedFallback = false,
  }) {
    final rawCompetition = json['competitionItems'] ?? json['ideaCompetition'] ?? json['competition'];
    final competition = <JamesWillCompetitionItem>[];
    if (rawCompetition is List) {
      for (final item in rawCompetition) {
        if (item is Map) {
          competition.add(JamesWillCompetitionItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return JamesWillActionIdea(
      id: fallback.id,
      originalGoal: willTextValue(json['originalGoal'], fallback.originalGoal),
      goalNote: fallback.goalNote,
      coreValue: willTextValue(json['coreValue'], fallback.coreValue),
      actionIdea: willTextValue(json['actionIdea'], fallback.actionIdea),
      firstBodyAction: willTextValue(json['firstBodyAction'], fallback.firstBodyAction),
      minimumAction: willTextValue(json['minimumAction'], fallback.minimumAction),
      fiveMinuteVersion: willTextValue(json['fiveMinuteVersion'], fallback.fiveMinuteVersion),
      attentionAnchor: willTextValue(json['attentionAnchor'], fallback.attentionAnchor),
      obstacleIdeas: willStringListFromJson(json['obstacleIdeas']).isEmpty ? fallback.obstacleIdeas : willStringListFromJson(json['obstacleIdeas']),
      replacementIdeas: willStringListFromJson(json['replacementIdeas']).isEmpty ? fallback.replacementIdeas : willStringListFromJson(json['replacementIdeas']),
      competitionItems: competition.isEmpty ? fallback.competitionItems : competition,
      coachMessage: willTextValue(json['coachMessage'], fallback.coachMessage),
      aiProvider: provider ?? fallback.aiProvider,
      aiModelLabel: modelLabel ?? fallback.aiModelLabel,
      aiUsedFallback: usedFallback,
      status: fallback.status,
      createdAtMs: fallback.createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory JamesWillActionIdea.fromMap(Map<String, Object?> map) {
    final competition = <JamesWillCompetitionItem>[];
    try {
      final decoded = jsonDecode((map['competition_json'] ?? '[]').toString());
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) competition.add(JamesWillCompetitionItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } catch (_) {}
    return JamesWillActionIdea(
      id: (map['idea_id'] ?? '').toString(),
      originalGoal: (map['original_goal'] ?? '').toString(),
      goalNote: (map['goal_note'] ?? '').toString(),
      coreValue: (map['core_value'] ?? '').toString(),
      actionIdea: (map['action_idea'] ?? '').toString(),
      firstBodyAction: (map['first_body_action'] ?? '').toString(),
      minimumAction: (map['minimum_action'] ?? '').toString(),
      fiveMinuteVersion: (map['five_minute_version'] ?? '').toString(),
      attentionAnchor: (map['attention_anchor'] ?? '').toString(),
      obstacleIdeas: willStringListFromJson(map['obstacle_ideas_json']),
      replacementIdeas: willStringListFromJson(map['replacement_ideas_json']),
      competitionItems: competition,
      coachMessage: (map['coach_message'] ?? '').toString(),
      aiProvider: (map['ai_provider'] ?? '').toString(),
      aiModelLabel: (map['ai_model_label'] ?? '').toString(),
      aiUsedFallback: willIntValue(map['ai_used_fallback']) == 1,
      status: (map['status'] ?? 'active').toString(),
      createdAtMs: willIntValue(map['created_at_ms']),
      updatedAtMs: willIntValue(map['updated_at_ms']),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'idea_id': id,
        'original_goal': originalGoal,
        'goal_note': goalNote,
        'core_value': coreValue,
        'action_idea': actionIdea,
        'first_body_action': firstBodyAction,
        'minimum_action': minimumAction,
        'five_minute_version': fiveMinuteVersion,
        'attention_anchor': attentionAnchor,
        'obstacle_ideas_json': willStringListToJson(obstacleIdeas),
        'replacement_ideas_json': willStringListToJson(replacementIdeas),
        'competition_json': jsonEncode(competitionItems.map((e) => e.toJson()).toList()),
        'coach_message': coachMessage,
        'ai_provider': aiProvider,
        'ai_model_label': aiModelLabel,
        'ai_used_fallback': aiUsedFallback ? 1 : 0,
        'status': status,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}

class JamesWillDecision {
  final String id;
  final String ideaId;
  final String question;
  final String positiveIdea;
  final String negativeIdea;
  final String hesitationType;
  final String decisionType;
  final String strategy;
  final String todayFirstAction;
  final String attentionAnchor;
  final String coachMessage;
  final int sealedUntilMs;
  final int createdAtMs;

  const JamesWillDecision({
    required this.id,
    required this.ideaId,
    required this.question,
    required this.positiveIdea,
    required this.negativeIdea,
    required this.hesitationType,
    required this.decisionType,
    required this.strategy,
    required this.todayFirstAction,
    required this.attentionAnchor,
    required this.coachMessage,
    required this.sealedUntilMs,
    required this.createdAtMs,
  });

  factory JamesWillDecision.local({required String ideaId, required String question, String firstAction = ''}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return JamesWillDecision(
      id: 'decision_${now}_${question.hashCode.abs()}',
      ideaId: ideaId,
      question: question.trim(),
      positiveIdea: '继续执行会带来真实反馈、掌控感和长期价值。',
      negativeIdea: '继续拖延会短期轻松，但让目标停留在想法中。',
      hesitationType: '害怕不可逆 / 短期舒服型犹豫',
      decisionType: '努力压舱型',
      strategy: '采用 7 天实验决定：决定前允许权衡；决定后进入执行期，只优化行动，不反复审判选择。',
      todayFirstAction: firstAction.trim().isEmpty ? '今天完成一次 5 分钟最小行动。' : firstAction.trim(),
      attentionAnchor: '不需要决定一辈子，只决定接下来 7 天做一次真实实验。',
      coachMessage: '把无限犹豫变成有限实验，让真实反馈替代反复空想。',
      sealedUntilMs: now + const Duration(days: 7).inMilliseconds,
      createdAtMs: now,
    );
  }

  factory JamesWillDecision.fromAiJson({required Map<String, dynamic> json, required JamesWillDecision fallback}) {
    final days = willIntValue(json['sealedDays'] ?? json['sealedUntilDays'], 7).clamp(1, 30).toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    return JamesWillDecision(
      id: fallback.id,
      ideaId: fallback.ideaId,
      question: willTextValue(json['question'], fallback.question),
      positiveIdea: willTextValue(json['positiveIdea'], fallback.positiveIdea),
      negativeIdea: willTextValue(json['negativeIdea'], fallback.negativeIdea),
      hesitationType: willTextValue(json['hesitationType'], fallback.hesitationType),
      decisionType: willTextValue(json['decisionType'], fallback.decisionType),
      strategy: willTextValue(json['strategy'], fallback.strategy),
      todayFirstAction: willTextValue(json['todayFirstAction'], fallback.todayFirstAction),
      attentionAnchor: willTextValue(json['attentionAnchor'], fallback.attentionAnchor),
      coachMessage: willTextValue(json['coachMessage'], fallback.coachMessage),
      sealedUntilMs: now + Duration(days: days).inMilliseconds,
      createdAtMs: fallback.createdAtMs,
    );
  }

  factory JamesWillDecision.fromMap(Map<String, Object?> map) => JamesWillDecision(
        id: (map['decision_id'] ?? '').toString(),
        ideaId: (map['idea_id'] ?? '').toString(),
        question: (map['question'] ?? '').toString(),
        positiveIdea: (map['positive_idea'] ?? '').toString(),
        negativeIdea: (map['negative_idea'] ?? '').toString(),
        hesitationType: (map['hesitation_type'] ?? '').toString(),
        decisionType: (map['decision_type'] ?? '').toString(),
        strategy: (map['strategy'] ?? '').toString(),
        todayFirstAction: (map['today_first_action'] ?? '').toString(),
        attentionAnchor: (map['attention_anchor'] ?? '').toString(),
        coachMessage: (map['coach_message'] ?? '').toString(),
        sealedUntilMs: willIntValue(map['sealed_until_ms']),
        createdAtMs: willIntValue(map['created_at_ms']),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'decision_id': id,
        'idea_id': ideaId,
        'question': question,
        'positive_idea': positiveIdea,
        'negative_idea': negativeIdea,
        'hesitation_type': hesitationType,
        'decision_type': decisionType,
        'strategy': strategy,
        'today_first_action': todayFirstAction,
        'attention_anchor': attentionAnchor,
        'coach_message': coachMessage,
        'sealed_until_ms': sealedUntilMs,
        'created_at_ms': createdAtMs,
      };
}

class JamesWillLog {
  final String id;
  final String ideaId;
  final bool completed;
  final String beforeObstacle;
  final String dominantActionIdea;
  final int attentionRecoveryCount;
  final int startDelayMinutes;
  final int effortAttentionScore;
  final String reflection;
  final String aiSummary;
  final int createdAtMs;

  const JamesWillLog({
    required this.id,
    required this.ideaId,
    required this.completed,
    required this.beforeObstacle,
    required this.dominantActionIdea,
    required this.attentionRecoveryCount,
    required this.startDelayMinutes,
    required this.effortAttentionScore,
    required this.reflection,
    required this.aiSummary,
    required this.createdAtMs,
  });

  factory JamesWillLog.create({
    required String ideaId,
    required bool completed,
    required String beforeObstacle,
    required String dominantActionIdea,
    required int attentionRecoveryCount,
    required int startDelayMinutes,
    required int effortAttentionScore,
    required String reflection,
    String aiSummary = '',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return JamesWillLog(
      id: 'will_log_${now}_${ideaId.hashCode.abs()}',
      ideaId: ideaId,
      completed: completed,
      beforeObstacle: beforeObstacle.trim(),
      dominantActionIdea: dominantActionIdea.trim(),
      attentionRecoveryCount: attentionRecoveryCount,
      startDelayMinutes: startDelayMinutes,
      effortAttentionScore: effortAttentionScore.clamp(0, 100).toInt(),
      reflection: reflection.trim(),
      aiSummary: aiSummary.trim(),
      createdAtMs: now,
    );
  }

  factory JamesWillLog.fromMap(Map<String, Object?> map) => JamesWillLog(
        id: (map['log_id'] ?? '').toString(),
        ideaId: (map['idea_id'] ?? '').toString(),
        completed: willIntValue(map['completed']) == 1,
        beforeObstacle: (map['before_obstacle'] ?? '').toString(),
        dominantActionIdea: (map['dominant_action_idea'] ?? '').toString(),
        attentionRecoveryCount: willIntValue(map['attention_recovery_count']),
        startDelayMinutes: willIntValue(map['start_delay_minutes']),
        effortAttentionScore: willIntValue(map['effort_attention_score']),
        reflection: (map['reflection'] ?? '').toString(),
        aiSummary: (map['ai_summary'] ?? '').toString(),
        createdAtMs: willIntValue(map['created_at_ms']),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'log_id': id,
        'idea_id': ideaId,
        'completed': completed ? 1 : 0,
        'before_obstacle': beforeObstacle,
        'dominant_action_idea': dominantActionIdea,
        'attention_recovery_count': attentionRecoveryCount,
        'start_delay_minutes': startDelayMinutes,
        'effort_attention_score': effortAttentionScore,
        'reflection': reflection,
        'ai_summary': aiSummary,
        'created_at_ms': createdAtMs,
      };
}
