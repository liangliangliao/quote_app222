import 'dart:convert';

import 'james_will_training_models.dart';

class JamesWillHabit {
  final String id;
  final String ideaId;
  final String name;
  final String trigger;
  final String place;
  final String firstBodyAction;
  final String minimumVersion;
  final String standardVersion;
  final String fallbackVersion;
  final int level;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;

  const JamesWillHabit({
    required this.id,
    required this.ideaId,
    required this.name,
    required this.trigger,
    required this.place,
    required this.firstBodyAction,
    required this.minimumVersion,
    required this.standardVersion,
    required this.fallbackVersion,
    required this.level,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  factory JamesWillHabit.fromIdea(JamesWillActionIdea idea, {String trigger = '固定提醒时间到达时', String place = '行动发生的固定地点'}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return JamesWillHabit(
      id: 'habit_${now}_${idea.id.hashCode.abs()}',
      ideaId: idea.id,
      name: idea.originalGoal.length > 18 ? '${idea.originalGoal.substring(0, 18)}…' : idea.originalGoal,
      trigger: trigger,
      place: place,
      firstBodyAction: idea.firstBodyAction,
      minimumVersion: idea.minimumAction,
      standardVersion: idea.actionIdea,
      fallbackVersion: idea.fiveMinuteVersion,
      level: 1,
      status: 'active',
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  factory JamesWillHabit.fromMap(Map<String, Object?> map) => JamesWillHabit(
        id: (map['habit_id'] ?? '').toString(),
        ideaId: (map['idea_id'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        trigger: (map['trigger_text'] ?? '').toString(),
        place: (map['place_text'] ?? '').toString(),
        firstBodyAction: (map['first_body_action'] ?? '').toString(),
        minimumVersion: (map['minimum_version'] ?? '').toString(),
        standardVersion: (map['standard_version'] ?? '').toString(),
        fallbackVersion: (map['fallback_version'] ?? '').toString(),
        level: willIntValue(map['level'], 1).clamp(1, 6).toInt(),
        status: (map['status'] ?? 'active').toString(),
        createdAtMs: willIntValue(map['created_at_ms']),
        updatedAtMs: willIntValue(map['updated_at_ms']),
      );

  JamesWillHabit copyWith({
    String? name,
    String? trigger,
    String? place,
    String? firstBodyAction,
    String? minimumVersion,
    String? standardVersion,
    String? fallbackVersion,
    int? level,
    String? status,
  }) {
    return JamesWillHabit(
      id: id,
      ideaId: ideaId,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      place: place ?? this.place,
      firstBodyAction: firstBodyAction ?? this.firstBodyAction,
      minimumVersion: minimumVersion ?? this.minimumVersion,
      standardVersion: standardVersion ?? this.standardVersion,
      fallbackVersion: fallbackVersion ?? this.fallbackVersion,
      level: (level ?? this.level).clamp(1, 6).toInt(),
      status: status ?? this.status,
      createdAtMs: createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'habit_id': id,
        'idea_id': ideaId,
        'name': name,
        'trigger_text': trigger,
        'place_text': place,
        'first_body_action': firstBodyAction,
        'minimum_version': minimumVersion,
        'standard_version': standardVersion,
        'fallback_version': fallbackVersion,
        'level': level,
        'status': status,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}

class JamesWillWeeklyReport {
  final String id;
  final int fromMs;
  final int toMs;
  final int completedCount;
  final int totalLogs;
  final double averageEffort;
  final int recoveryCount;
  final String dominantObstacle;
  final String bestActionIdea;
  final String growthLevel;
  final String summary;
  final String nextExperiment;
  final int createdAtMs;

  const JamesWillWeeklyReport({
    required this.id,
    required this.fromMs,
    required this.toMs,
    required this.completedCount,
    required this.totalLogs,
    required this.averageEffort,
    required this.recoveryCount,
    required this.dominantObstacle,
    required this.bestActionIdea,
    required this.growthLevel,
    required this.summary,
    required this.nextExperiment,
    required this.createdAtMs,
  });

  factory JamesWillWeeklyReport.fromLogs(List<JamesWillLog> logs, {String aiSummary = '', String aiNextExperiment = ''}) {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)).millisecondsSinceEpoch;
    final inRange = logs.where((e) => e.createdAtMs >= from && e.createdAtMs <= to).toList(growable: false);
    final total = inRange.length;
    final completed = inRange.where((e) => e.completed).length;
    final effort = total == 0 ? 0.0 : inRange.fold<int>(0, (sum, e) => sum + e.effortAttentionScore) / total;
    final recoveries = inRange.fold<int>(0, (sum, e) => sum + e.attentionRecoveryCount);
    final obstacle = _mostCommon(inRange.map((e) => e.beforeObstacle).where((e) => e.trim().isNotEmpty));
    final action = _mostCommon(inRange.map((e) => e.dominantActionIdea).where((e) => e.trim().isNotEmpty));
    final level = JamesWillGrowthLevel.fromLogs(logs).title;
    return JamesWillWeeklyReport(
      id: 'weekly_${DateTime.now().millisecondsSinceEpoch}',
      fromMs: from,
      toMs: to,
      completedCount: completed,
      totalLogs: total,
      averageEffort: effort,
      recoveryCount: recoveries,
      dominantObstacle: obstacle.isEmpty ? '暂无明显阻碍观念' : obstacle,
      bestActionIdea: action.isEmpty ? '暂无稳定行动观念' : action,
      growthLevel: level,
      summary: aiSummary.trim().isEmpty
          ? '本周共记录 $total 次意志训练，完成 $completed 次，平均努力性注意 ${effort.toStringAsFixed(0)}/100。重点不是数量，而是你是否能在阻碍观念存在时把行动观念拉回意识中心。'
          : aiSummary.trim(),
      nextExperiment: aiNextExperiment.trim().isEmpty ? '下周选择一个目标，固定触发条件、地点和第一身体动作，连续执行 7 天实验。' : aiNextExperiment.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory JamesWillWeeklyReport.fromMap(Map<String, Object?> map) => JamesWillWeeklyReport(
        id: (map['report_id'] ?? '').toString(),
        fromMs: willIntValue(map['from_ms']),
        toMs: willIntValue(map['to_ms']),
        completedCount: willIntValue(map['completed_count']),
        totalLogs: willIntValue(map['total_logs']),
        averageEffort: double.tryParse((map['average_effort'] ?? '0').toString()) ?? 0.0,
        recoveryCount: willIntValue(map['recovery_count']),
        dominantObstacle: (map['dominant_obstacle'] ?? '').toString(),
        bestActionIdea: (map['best_action_idea'] ?? '').toString(),
        growthLevel: (map['growth_level'] ?? '').toString(),
        summary: (map['summary'] ?? '').toString(),
        nextExperiment: (map['next_experiment'] ?? '').toString(),
        createdAtMs: willIntValue(map['created_at_ms']),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'report_id': id,
        'from_ms': fromMs,
        'to_ms': toMs,
        'completed_count': completedCount,
        'total_logs': totalLogs,
        'average_effort': averageEffort,
        'recovery_count': recoveryCount,
        'dominant_obstacle': dominantObstacle,
        'best_action_idea': bestActionIdea,
        'growth_level': growthLevel,
        'summary': summary,
        'next_experiment': nextExperiment,
        'created_at_ms': createdAtMs,
      };

  static String _mostCommon(Iterable<String> values) {
    final counts = <String, int>{};
    for (final raw in values) {
      final v = raw.trim();
      if (v.isEmpty) continue;
      counts[v] = (counts[v] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}

class JamesWillPromptConfig {
  final String key;
  final String title;
  final String prompt;
  final int updatedAtMs;

  const JamesWillPromptConfig({required this.key, required this.title, required this.prompt, required this.updatedAtMs});

  factory JamesWillPromptConfig.fromMap(Map<String, Object?> map) => JamesWillPromptConfig(
        key: (map['config_key'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        prompt: (map['prompt_text'] ?? '').toString(),
        updatedAtMs: willIntValue(map['updated_at_ms']),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'config_key': key,
        'title': title,
        'prompt_text': prompt,
        'updated_at_ms': updatedAtMs,
      };
}

class JamesWillGrowthLevel {
  final int level;
  final String title;
  final String description;
  final String nextTraining;

  const JamesWillGrowthLevel({required this.level, required this.title, required this.description, required this.nextTraining});

  factory JamesWillGrowthLevel.fromLogs(List<JamesWillLog> logs) {
    final total = logs.length;
    final completed = logs.where((e) => e.completed).length;
    final recoveries = logs.fold<int>(0, (sum, e) => sum + e.attentionRecoveryCount);
    final avgEffort = total == 0 ? 0.0 : logs.fold<int>(0, (sum, e) => sum + e.effortAttentionScore) / total;
    if (total >= 30 && completed >= 21 && avgEffort >= 75) {
      return const JamesWillGrowthLevel(level: 6, title: 'L6 习惯自动化', description: '正确行动开始从强意志走向固定结构和半自动化。', nextTraining: '把成熟行动绑定固定时间、地点和失败恢复方案。');
    }
    if (total >= 18 && completed >= 12) {
      return const JamesWillGrowthLevel(level: 5, title: 'L5 决定执行', description: '你已经能在决定后进入执行期，而不是每天重新审判目标。', nextTraining: '继续训练决定封存：执行期内只优化行动，不反复推翻选择。');
    }
    if (total >= 10 && recoveries >= 5) {
      return const JamesWillGrowthLevel(level: 4, title: 'L4 犹豫决断', description: '你开始能识别犹豫和分心，并把注意力拉回行动观念。', nextTraining: '遇到重大犹豫时使用 7 天实验决定。');
    }
    if (total >= 5 && avgEffort >= 50) {
      return const JamesWillGrowthLevel(level: 3, title: 'L3 注意力保持', description: '你已经不只是打卡，而是在训练努力性注意。', nextTraining: '把一个行动观念保持 30 秒、1 分钟、5 分钟。');
    }
    if (total >= 1) {
      return const JamesWillGrowthLevel(level: 2, title: 'L2 行动观念生成', description: '你已经开始把抽象目标翻译成最小身体动作。', nextTraining: '每个目标都落到第一身体动作和 5 分钟版本。');
    }
    return const JamesWillGrowthLevel(level: 1, title: 'L1 观念觉察', description: '先看见：当前是哪一个观念在主导你。', nextTraining: '生成第一张行动观念卡，并记录一次阻碍观念。');
  }
}

class JamesWillObstacleIntervention {
  final String obstacle;
  final String nature;
  final String replacement;
  final String firstAction;

  const JamesWillObstacleIntervention({required this.obstacle, required this.nature, required this.replacement, required this.firstAction});

  static List<JamesWillObstacleIntervention> defaultsFor(JamesWillActionIdea idea) {
    final items = <JamesWillObstacleIntervention>[
      JamesWillObstacleIntervention(obstacle: '我太累了', nature: '疲劳观念占据注意力', replacement: '只做最低版本，不追求完整状态', firstAction: idea.firstBodyAction),
      JamesWillObstacleIntervention(obstacle: '等会儿再说', nature: '延迟观念让行动无限后移', replacement: '现在只做 2 分钟', firstAction: idea.minimumAction),
      JamesWillObstacleIntervention(obstacle: '做了也没用', nature: '虚无观念削弱意义', replacement: '一次行动不是改变全部，而是保持方向', firstAction: idea.fiveMinuteVersion),
      JamesWillObstacleIntervention(obstacle: '我怕失败', nature: '恐惧观念把结果想成不可承受', replacement: '先做低风险实验，不做永久承诺', firstAction: '完成一个可撤回的小实验'),
      JamesWillObstacleIntervention(obstacle: '必须做好', nature: '完美主义提高启动门槛', replacement: '先做粗糙版本，再迭代', firstAction: '只完成一个草稿或第一步'),
      JamesWillObstacleIntervention(obstacle: '没心情', nature: '情绪依赖观念阻止身体行动', replacement: '行动可以先于心情', firstAction: idea.firstBodyAction),
    ];
    final custom = idea.obstacleIdeas.map((e) => JamesWillObstacleIntervention(obstacle: e, nature: '用户记录的个人阻碍观念', replacement: idea.replacementIdeas.isEmpty ? '把任务降到最小版本' : idea.replacementIdeas.first, firstAction: idea.minimumAction));
    return <JamesWillObstacleIntervention>[...custom, ...items];
  }
}

class JamesWillControlSplit {
  final List<String> uncontrollable;
  final List<String> controllable;

  const JamesWillControlSplit({required this.uncontrollable, required this.controllable});

  factory JamesWillControlSplit.fromIdea(JamesWillActionIdea idea) {
    final goal = idea.originalGoal;
    return JamesWillControlSplit(
      uncontrollable: <String>[
        '结果是否立刻出现：$goal 不一定马上产生外部结果',
        '他人的评价、机会和环境变化',
        '过去已经发生的失败或拖延',
      ],
      controllable: <String>[
        '今天是否执行第一身体动作：${idea.firstBodyAction}',
        '是否完成最小行动：${idea.minimumAction}',
        '分心后是否把注意力拉回行动观念',
        '复盘后是否降低下一次启动难度',
      ],
    );
  }
}

class JamesWillPleasurePainSplit {
  final String shortComfort;
  final String longCost;
  final String shortPain;
  final String longPower;
  final String minimalNecessaryPain;

  const JamesWillPleasurePainSplit({required this.shortComfort, required this.longCost, required this.shortPain, required this.longPower, required this.minimalNecessaryPain});

  factory JamesWillPleasurePainSplit.fromIdea(JamesWillActionIdea idea) {
    final obstacle = idea.obstacleIdeas.isEmpty ? '逃避当前任务' : idea.obstacleIdeas.first;
    return JamesWillPleasurePainSplit(
      shortComfort: obstacle,
      longCost: '目标继续停留在想法中，行动观念越来越弱。',
      shortPain: '开始时会有抗拒、麻烦、疲惫或害怕失败。',
      longPower: '完成最小行动后获得掌控感、真实反馈和习惯强化。',
      minimalNecessaryPain: '只承受最小必要痛苦：${idea.minimumAction}。',
    );
  }
}

String jamesWillEncodeList(List<String> values) => jsonEncode(values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
