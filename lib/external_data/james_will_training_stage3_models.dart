import 'dart:convert';

import 'james_will_training_models.dart';

class JamesWillSevenDayExperiment {
  final String id;
  final String ideaId;
  final String title;
  final String coreValue;
  final String triggerText;
  final String placeText;
  final String firstBodyAction;
  final String minimumVersion;
  final String standardVersion;
  final String fallbackVersion;
  final List<String> dailyPlan;
  final String recoveryPlan;
  final int currentDay;
  final String status;
  final int sealedUntilMs;
  final String aiSummary;
  final int createdAtMs;
  final int updatedAtMs;

  const JamesWillSevenDayExperiment({
    required this.id,
    required this.ideaId,
    required this.title,
    required this.coreValue,
    required this.triggerText,
    required this.placeText,
    required this.firstBodyAction,
    required this.minimumVersion,
    required this.standardVersion,
    required this.fallbackVersion,
    required this.dailyPlan,
    required this.recoveryPlan,
    required this.currentDay,
    required this.status,
    required this.sealedUntilMs,
    required this.aiSummary,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory JamesWillSevenDayExperiment.fromIdea(JamesWillActionIdea idea) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final plans = List<String>.generate(7, (index) {
      final day = index + 1;
      if (day == 1) return '第1天：只完成最小行动：${idea.minimumAction}。重点是启动，而不是完成很多。';
      if (day == 2) return '第2天：固定触发条件后执行：${idea.firstBodyAction}。记录启动阻力。';
      if (day == 3) return '第3天：执行5分钟版本：${idea.fiveMinuteVersion}。分心后至少拉回1次。';
      if (day == 4) return '第4天：继续5分钟版本，并识别最强阻碍观念。';
      if (day == 5) return '第5天：在相同地点执行标准行动的一半：${idea.actionIdea}。';
      if (day == 6) return '第6天：执行标准行动；如果抗拒强烈，就退回最小行动。';
      return '第7天：完成一次行动并复盘：这个目标是否值得进入下一轮7天实验？';
    });
    return JamesWillSevenDayExperiment(
      id: 'experiment_${now}_${idea.id.hashCode.abs()}',
      ideaId: idea.id,
      title: '7天实验：${idea.originalGoal.length > 18 ? '${idea.originalGoal.substring(0, 18)}…' : idea.originalGoal}',
      coreValue: idea.coreValue,
      triggerText: '每天固定一个容易出现的触发点，例如晚饭后、起床后或下班到家后。',
      placeText: '固定在最容易开始的地点。',
      firstBodyAction: idea.firstBodyAction,
      minimumVersion: idea.minimumAction,
      standardVersion: idea.actionIdea,
      fallbackVersion: idea.fiveMinuteVersion,
      dailyPlan: plans,
      recoveryPlan: '失败当天不补偿、不自责；只记录断点，第二天退回最小行动：${idea.minimumAction}。',
      currentDay: 1,
      status: 'active',
      sealedUntilMs: now + const Duration(days: 7).inMilliseconds,
      aiSummary: '这是一个可撤回、可复盘、可封存的7天实验。执行期内不重新审判目标，只优化行动。',
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  factory JamesWillSevenDayExperiment.fromAiJson({required Map<String, dynamic> json, required JamesWillSevenDayExperiment fallback}) {
    final days = willStringListFromJson(json['dailyPlan']);
    return fallback.copyWith(
      title: willTextValue(json['title'], fallback.title),
      coreValue: willTextValue(json['coreValue'], fallback.coreValue),
      triggerText: willTextValue(json['triggerText'], fallback.triggerText),
      placeText: willTextValue(json['placeText'], fallback.placeText),
      firstBodyAction: willTextValue(json['firstBodyAction'], fallback.firstBodyAction),
      minimumVersion: willTextValue(json['minimumVersion'], fallback.minimumVersion),
      standardVersion: willTextValue(json['standardVersion'], fallback.standardVersion),
      fallbackVersion: willTextValue(json['fallbackVersion'], fallback.fallbackVersion),
      dailyPlan: days.length >= 7 ? days.take(7).toList(growable: false) : fallback.dailyPlan,
      recoveryPlan: willTextValue(json['recoveryPlan'], fallback.recoveryPlan),
      aiSummary: willTextValue(json['aiSummary'], fallback.aiSummary),
    );
  }

  factory JamesWillSevenDayExperiment.fromMap(Map<String, Object?> map) => JamesWillSevenDayExperiment(
        id: (map['experiment_id'] ?? '').toString(),
        ideaId: (map['idea_id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        coreValue: (map['core_value'] ?? '').toString(),
        triggerText: (map['trigger_text'] ?? '').toString(),
        placeText: (map['place_text'] ?? '').toString(),
        firstBodyAction: (map['first_body_action'] ?? '').toString(),
        minimumVersion: (map['minimum_version'] ?? '').toString(),
        standardVersion: (map['standard_version'] ?? '').toString(),
        fallbackVersion: (map['fallback_version'] ?? '').toString(),
        dailyPlan: willStringListFromJson(map['daily_plan_json']),
        recoveryPlan: (map['recovery_plan'] ?? '').toString(),
        currentDay: willIntValue(map['current_day'], 1).clamp(1, 7).toInt(),
        status: (map['status'] ?? 'active').toString(),
        sealedUntilMs: willIntValue(map['sealed_until_ms']),
        aiSummary: (map['ai_summary'] ?? '').toString(),
        createdAtMs: willIntValue(map['created_at_ms']),
        updatedAtMs: willIntValue(map['updated_at_ms']),
      );

  JamesWillSevenDayExperiment copyWith({
    String? title,
    String? coreValue,
    String? triggerText,
    String? placeText,
    String? firstBodyAction,
    String? minimumVersion,
    String? standardVersion,
    String? fallbackVersion,
    List<String>? dailyPlan,
    String? recoveryPlan,
    int? currentDay,
    String? status,
    int? sealedUntilMs,
    String? aiSummary,
  }) {
    return JamesWillSevenDayExperiment(
      id: id,
      ideaId: ideaId,
      title: title ?? this.title,
      coreValue: coreValue ?? this.coreValue,
      triggerText: triggerText ?? this.triggerText,
      placeText: placeText ?? this.placeText,
      firstBodyAction: firstBodyAction ?? this.firstBodyAction,
      minimumVersion: minimumVersion ?? this.minimumVersion,
      standardVersion: standardVersion ?? this.standardVersion,
      fallbackVersion: fallbackVersion ?? this.fallbackVersion,
      dailyPlan: dailyPlan ?? this.dailyPlan,
      recoveryPlan: recoveryPlan ?? this.recoveryPlan,
      currentDay: (currentDay ?? this.currentDay).clamp(1, 7).toInt(),
      status: status ?? this.status,
      sealedUntilMs: sealedUntilMs ?? this.sealedUntilMs,
      aiSummary: aiSummary ?? this.aiSummary,
      createdAtMs: createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'experiment_id': id,
        'idea_id': ideaId,
        'title': title,
        'core_value': coreValue,
        'trigger_text': triggerText,
        'place_text': placeText,
        'first_body_action': firstBodyAction,
        'minimum_version': minimumVersion,
        'standard_version': standardVersion,
        'fallback_version': fallbackVersion,
        'daily_plan_json': jsonEncode(dailyPlan),
        'recovery_plan': recoveryPlan,
        'current_day': currentDay,
        'status': status,
        'sealed_until_ms': sealedUntilMs,
        'ai_summary': aiSummary,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}

class JamesWillCooldownPlan {
  final String id;
  final String ideaId;
  final String triggerText;
  final String decisionText;
  final String riskLevel;
  final String reason;
  final int coolUntilMs;
  final List<String> checkQuestions;
  final String fallbackAction;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  const JamesWillCooldownPlan({
    required this.id,
    required this.ideaId,
    required this.triggerText,
    required this.decisionText,
    required this.riskLevel,
    required this.reason,
    required this.coolUntilMs,
    required this.checkQuestions,
    required this.fallbackAction,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory JamesWillCooldownPlan.fromIdea(JamesWillActionIdea idea, {String decisionText = ''}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return JamesWillCooldownPlan(
      id: 'cooldown_${now}_${idea.id.hashCode.abs()}',
      ideaId: idea.id,
      triggerText: idea.obstacleIdeas.isEmpty ? '突然想用一个大决定结束不舒服' : idea.obstacleIdeas.first,
      decisionText: decisionText.trim().isEmpty ? '暂不做重大决定，先回到最小行动。' : decisionText.trim(),
      riskLevel: '中等：可能由短期情绪、疲惫或逃避观念推动。',
      reason: '詹姆斯式决策中，内在自动爆发型决定需要冷却：先把冲动和价值判断分开。',
      coolUntilMs: now + const Duration(hours: 24).inMilliseconds,
      checkQuestions: const <String>[
        '我是在选择长期价值，还是在逃离当前不舒服？',
        '继续等待24小时会不会损失关键机会？',
        '这个决定是否可撤回、可实验、可复盘？',
        '有没有一个更小、更安全的第一步？',
      ],
      fallbackAction: idea.minimumAction,
      status: 'cooling',
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  factory JamesWillCooldownPlan.fromAiJson({required Map<String, dynamic> json, required JamesWillCooldownPlan fallback}) {
    final minutes = willIntValue(json['coolMinutes'], 24 * 60).clamp(10, 72 * 60).toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final questions = willStringListFromJson(json['checkQuestions']);
    return fallback.copyWith(
      triggerText: willTextValue(json['triggerText'], fallback.triggerText),
      decisionText: willTextValue(json['decisionText'], fallback.decisionText),
      riskLevel: willTextValue(json['riskLevel'], fallback.riskLevel),
      reason: willTextValue(json['reason'], fallback.reason),
      coolUntilMs: now + Duration(minutes: minutes).inMilliseconds,
      checkQuestions: questions.isEmpty ? fallback.checkQuestions : questions.take(6).toList(growable: false),
      fallbackAction: willTextValue(json['fallbackAction'], fallback.fallbackAction),
    );
  }

  factory JamesWillCooldownPlan.fromMap(Map<String, Object?> map) => JamesWillCooldownPlan(
        id: (map['cooldown_id'] ?? '').toString(),
        ideaId: (map['idea_id'] ?? '').toString(),
        triggerText: (map['trigger_text'] ?? '').toString(),
        decisionText: (map['decision_text'] ?? '').toString(),
        riskLevel: (map['risk_level'] ?? '').toString(),
        reason: (map['reason'] ?? '').toString(),
        coolUntilMs: willIntValue(map['cool_until_ms']),
        checkQuestions: willStringListFromJson(map['check_questions_json']),
        fallbackAction: (map['fallback_action'] ?? '').toString(),
        status: (map['status'] ?? 'cooling').toString(),
        createdAtMs: willIntValue(map['created_at_ms']),
        updatedAtMs: willIntValue(map['updated_at_ms']),
      );

  JamesWillCooldownPlan copyWith({
    String? triggerText,
    String? decisionText,
    String? riskLevel,
    String? reason,
    int? coolUntilMs,
    List<String>? checkQuestions,
    String? fallbackAction,
    String? status,
  }) {
    return JamesWillCooldownPlan(
      id: id,
      ideaId: ideaId,
      triggerText: triggerText ?? this.triggerText,
      decisionText: decisionText ?? this.decisionText,
      riskLevel: riskLevel ?? this.riskLevel,
      reason: reason ?? this.reason,
      coolUntilMs: coolUntilMs ?? this.coolUntilMs,
      checkQuestions: checkQuestions ?? this.checkQuestions,
      fallbackAction: fallbackAction ?? this.fallbackAction,
      status: status ?? this.status,
      createdAtMs: createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'cooldown_id': id,
        'idea_id': ideaId,
        'trigger_text': triggerText,
        'decision_text': decisionText,
        'risk_level': riskLevel,
        'reason': reason,
        'cool_until_ms': coolUntilMs,
        'check_questions_json': jsonEncode(checkQuestions),
        'fallback_action': fallbackAction,
        'status': status,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}

class JamesWillValueMapSnapshot {
  final String id;
  final String summary;
  final List<String> valueNodes;
  final List<String> actionNodes;
  final List<String> links;
  final int createdAtMs;

  const JamesWillValueMapSnapshot({
    required this.id,
    required this.summary,
    required this.valueNodes,
    required this.actionNodes,
    required this.links,
    required this.createdAtMs,
  });

  factory JamesWillValueMapSnapshot.fromIdeas(List<JamesWillActionIdea> ideas, List<JamesWillLog> logs, {String aiSummary = ''}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final values = <String>{};
    final actions = <String>[];
    final links = <String>[];
    for (final idea in ideas.take(20)) {
      final value = idea.coreValue.trim().isEmpty ? '未命名核心价值' : idea.coreValue.trim();
      values.add(value);
      actions.add(idea.actionIdea);
      links.add('$value → ${idea.firstBodyAction} → ${idea.minimumAction}');
    }
    final completed = logs.where((e) => e.completed).length;
    final summary = aiSummary.trim().isEmpty
        ? '当前长期价值地图包含 ${values.length} 个核心价值、${actions.length} 个行动观念和 $completed 次完成记录。重点是让价值不要停留在口号中，而要连接到第一身体动作和7天实验。'
        : aiSummary.trim();
    return JamesWillValueMapSnapshot(
      id: 'value_map_$now',
      summary: summary,
      valueNodes: values.take(12).toList(growable: false),
      actionNodes: actions.take(20).toList(growable: false),
      links: links.take(20).toList(growable: false),
      createdAtMs: now,
    );
  }

  factory JamesWillValueMapSnapshot.fromMap(Map<String, Object?> map) => JamesWillValueMapSnapshot(
        id: (map['snapshot_id'] ?? '').toString(),
        summary: (map['summary'] ?? '').toString(),
        valueNodes: willStringListFromJson(map['value_nodes_json']),
        actionNodes: willStringListFromJson(map['action_nodes_json']),
        links: willStringListFromJson(map['links_json']),
        createdAtMs: willIntValue(map['created_at_ms']),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'snapshot_id': id,
        'summary': summary,
        'value_nodes_json': jsonEncode(valueNodes),
        'action_nodes_json': jsonEncode(actionNodes),
        'links_json': jsonEncode(links),
        'created_at_ms': createdAtMs,
      };
}

class JamesWillDailyTrend {
  final int dayStartMs;
  final int total;
  final int completed;
  final int averageEffort;
  final int recoveries;

  const JamesWillDailyTrend({required this.dayStartMs, required this.total, required this.completed, required this.averageEffort, required this.recoveries});

  static List<JamesWillDailyTrend> fromLogs(List<JamesWillLog> logs, {String? ideaId, int days = 14}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <JamesWillDailyTrend>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final start = day.millisecondsSinceEpoch;
      final end = day.add(const Duration(days: 1)).millisecondsSinceEpoch;
      final items = logs.where((e) => (ideaId == null || e.ideaId == ideaId) && e.createdAtMs >= start && e.createdAtMs < end).toList(growable: false);
      final total = items.length;
      final completed = items.where((e) => e.completed).length;
      final effort = total == 0 ? 0 : (items.fold<int>(0, (sum, e) => sum + e.effortAttentionScore) / total).round();
      final recoveries = items.fold<int>(0, (sum, e) => sum + e.attentionRecoveryCount);
      result.add(JamesWillDailyTrend(dayStartMs: start, total: total, completed: completed, averageEffort: effort, recoveries: recoveries));
    }
    return result;
  }
}
