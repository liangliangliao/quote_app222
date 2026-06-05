import 'dart:convert';

class StressUnit {
  final String id;
  final int sortOrder;
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

  const StressUnit({
    required this.id,
    required this.sortOrder,
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

class StressAction {
  final String id;
  final String unitId;
  final String unitTitle;
  final String source;
  final String title;
  final String body;
  final String difficulty;
  final String duration;
  final String successCriteria;
  final String fallbackAction;
  final String reviewQuestion;
  final int createdAt;
  final String status; // todo / doing / done / partial / failed / skipped
  final String factLog;
  final String obstacleNote;
  final String nextStepNote;
  final List<String> steps;
  final List<bool> stepMarks;

  const StressAction({
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
    this.obstacleNote = '',
    this.nextStepNote = '',
    this.steps = const <String>[],
    this.stepMarks = const <bool>[],
  });

  StressAction copyWith({
    String? status,
    String? factLog,
    String? obstacleNote,
    String? nextStepNote,
    List<String>? steps,
    List<bool>? stepMarks,
  }) {
    return StressAction(
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
      obstacleNote: obstacleNote ?? this.obstacleNote,
      nextStepNote: nextStepNote ?? this.nextStepNote,
      steps: steps ?? this.steps,
      stepMarks: stepMarks ?? this.stepMarks,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
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
        'obstacleNote': obstacleNote,
        'nextStepNote': nextStepNote,
        'steps': steps,
        'stepMarks': stepMarks,
      };

  static StressAction fromJson(Map<String, dynamic> json) => StressAction(
        id: '${json['id'] ?? ''}',
        unitId: '${json['unitId'] ?? ''}',
        unitTitle: '${json['unitTitle'] ?? ''}',
        source: '${json['source'] ?? 'default'}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        difficulty: '${json['difficulty'] ?? 'L1'}',
        duration: '${json['duration'] ?? '10分钟'}',
        successCriteria: '${json['successCriteria'] ?? ''}',
        fallbackAction: '${json['fallbackAction'] ?? ''}',
        reviewQuestion: '${json['reviewQuestion'] ?? ''}',
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
        status: '${json['status'] ?? 'todo'}',
        factLog: '${json['factLog'] ?? ''}',
        obstacleNote: '${json['obstacleNote'] ?? ''}',
        nextStepNote: '${json['nextStepNote'] ?? ''}',
        steps: _parseSteps(json['steps']),
        stepMarks: _parseStepMarks(json['stepMarks']),
      );
}

class StressReviewEntry {
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

  const StressReviewEntry({
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

  Map<String, dynamic> toJson() => <String, dynamic>{
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

  static StressReviewEntry fromJson(Map<String, dynamic> json) => StressReviewEntry(
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



class StressPersonaProfile {
  final String role;
  final String roleLabel;
  final List<String> stressTags;
  final String currentFocus;
  final String energyStyle;
  final String supportStyle;
  final String changeTempo;
  final String avoidancePattern;
  final int updatedAt;

  const StressPersonaProfile({
    required this.role,
    required this.roleLabel,
    required this.stressTags,
    required this.currentFocus,
    required this.energyStyle,
    required this.supportStyle,
    required this.changeTempo,
    required this.avoidancePattern,
    required this.updatedAt,
  });

  factory StressPersonaProfile.initial() => StressPersonaProfile(
        role: 'mixed',
        roleLabel: '多角色学习者',
        stressTags: const <String>['恢复不足', '任务过载'],
        currentFocus: '先恢复再推进',
        energyStyle: '容易长期硬撑',
        supportStyle: '需要先看清问题再行动',
        changeTempo: '适合从小动作慢慢推进',
        avoidancePattern: '容易被任务过大与过多压住',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  StressPersonaProfile copyWith({
    String? role,
    String? roleLabel,
    List<String>? stressTags,
    String? currentFocus,
    String? energyStyle,
    String? supportStyle,
    String? changeTempo,
    String? avoidancePattern,
    int? updatedAt,
  }) {
    return StressPersonaProfile(
      role: role ?? this.role,
      roleLabel: roleLabel ?? this.roleLabel,
      stressTags: stressTags ?? this.stressTags,
      currentFocus: currentFocus ?? this.currentFocus,
      energyStyle: energyStyle ?? this.energyStyle,
      supportStyle: supportStyle ?? this.supportStyle,
      changeTempo: changeTempo ?? this.changeTempo,
      avoidancePattern: avoidancePattern ?? this.avoidancePattern,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        'roleLabel': roleLabel,
        'stressTags': stressTags,
        'currentFocus': currentFocus,
        'energyStyle': energyStyle,
        'supportStyle': supportStyle,
        'changeTempo': changeTempo,
        'avoidancePattern': avoidancePattern,
        'updatedAt': updatedAt,
      };

  static StressPersonaProfile fromJson(Map<String, dynamic> json) => StressPersonaProfile(
        role: '${json['role'] ?? 'mixed'}',
        roleLabel: '${json['roleLabel'] ?? '多角色学习者'}',
        stressTags: _parseStringList(json['stressTags']),
        currentFocus: '${json['currentFocus'] ?? '先恢复再推进'}',
        energyStyle: '${json['energyStyle'] ?? '容易长期硬撑'}',
        supportStyle: '${json['supportStyle'] ?? '需要先看清问题再行动'}',
        changeTempo: '${json['changeTempo'] ?? '适合从小动作慢慢推进'}',
        avoidancePattern: '${json['avoidancePattern'] ?? '容易被任务过大与过多压住'}',
        updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
      );
}

class StressSceneSession {
  final String id;
  final String unitId;
  final String unitTitle;
  final String sceneName;
  final String choiceTitle;
  final String feedback;
  final String actionHint;
  final int focus;
  final int recovery;
  final int pressure;
  final int createdAt;

  const StressSceneSession({
    required this.id,
    required this.unitId,
    required this.unitTitle,
    required this.sceneName,
    required this.choiceTitle,
    required this.feedback,
    required this.actionHint,
    required this.focus,
    required this.recovery,
    required this.pressure,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'unitId': unitId,
        'unitTitle': unitTitle,
        'sceneName': sceneName,
        'choiceTitle': choiceTitle,
        'feedback': feedback,
        'actionHint': actionHint,
        'focus': focus,
        'recovery': recovery,
        'pressure': pressure,
        'createdAt': createdAt,
      };

  static StressSceneSession fromJson(Map<String, dynamic> json) => StressSceneSession(
        id: '${json['id'] ?? ''}',
        unitId: '${json['unitId'] ?? ''}',
        unitTitle: '${json['unitTitle'] ?? ''}',
        sceneName: '${json['sceneName'] ?? ''}',
        choiceTitle: '${json['choiceTitle'] ?? ''}',
        feedback: '${json['feedback'] ?? ''}',
        actionHint: '${json['actionHint'] ?? ''}',
        focus: int.tryParse('${json['focus'] ?? 0}') ?? 0,
        recovery: int.tryParse('${json['recovery'] ?? 0}') ?? 0,
        pressure: int.tryParse('${json['pressure'] ?? 0}') ?? 0,
        createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
      );
}

class StressActionPlanResult {
  final String problemJudgment;
  final String todayMinimalAction;
  final List<String> weekChain;
  final String recoveryAction;
  final String reviewQuestion;
  final String provider;
  final String modelLabel;
  final String raw;

  const StressActionPlanResult({
    required this.problemJudgment,
    required this.todayMinimalAction,
    required this.weekChain,
    required this.recoveryAction,
    required this.reviewQuestion,
    required this.provider,
    required this.modelLabel,
    required this.raw,
  });

  factory StressActionPlanResult.fallback(StressUnit unit, {String concern = ''}) {
    final baseSteps = unit.howSteps.take(4).toList();
    return StressActionPlanResult(
      problemJudgment: concern.trim().isEmpty ? '当前更像是「${unit.concepts.isNotEmpty ? unit.concepts.first : unit.title}」相关问题。' : '你的困扰更像“${concern.trim()}”与「${unit.concepts.isNotEmpty ? unit.concepts.first : unit.title}」交织。',
      todayMinimalAction: unit.defaultActionBody.split('。').first.trim().isEmpty ? unit.defaultActionTitle : '${unit.defaultActionTitle}：${unit.defaultActionBody.split('。').first.trim()}。',
      weekChain: baseSteps.isEmpty ? <String>[unit.defaultActionTitle, '记录一次事实', '做一次复盘'] : baseSteps,
      recoveryAction: '如果今天做不动，就把动作缩小到 5 分钟版本，并只记录一个事实。',
      reviewQuestion: unit.reflectionQuestion,
      provider: 'local',
      modelLabel: '本地回退',
      raw: '',
    );
  }

  factory StressActionPlanResult.fromMap(Map<String, dynamic> map, {required String provider, required String modelLabel, String raw = ''}) {
    return StressActionPlanResult(
      problemJudgment: '${map['problem_judgment'] ?? ''}',
      todayMinimalAction: '${map['today_minimal_action'] ?? ''}',
      weekChain: _parseStringList(map['week_chain']),
      recoveryAction: '${map['recovery_action'] ?? ''}',
      reviewQuestion: '${map['review_question'] ?? ''}',
      provider: provider,
      modelLabel: modelLabel,
      raw: raw,
    );
  }
}

class StressInsightResult {
  final String summary;
  final List<String> patterns;
  final String nextFocus;
  final String todayAction;
  final String provider;
  final String modelLabel;
  final String raw;

  const StressInsightResult({
    required this.summary,
    required this.patterns,
    required this.nextFocus,
    required this.todayAction,
    required this.provider,
    required this.modelLabel,
    required this.raw,
  });

  factory StressInsightResult.fallback({required List<StressAction> actions, required List<StressReviewEntry> reviews}) {
    final undone = actions.where((e) => e.status != 'done').length;
    final done = actions.where((e) => e.status == 'done').length;
    final latestReview = reviews.isNotEmpty ? reviews.first : null;
    final patterns = <String>[
      if (undone > done) '你最近“生成行动”多于“真正完成行动”，更需要把动作再缩小。',
      if (done > 0) '你已经开始形成“学习 → 行动 → 复盘”的闭环。',
      if (latestReview != null && latestReview.feeling.trim().isNotEmpty) '最近最强的主观感受：${latestReview.feeling.trim()}。',
    ];
    return StressInsightResult(
      summary: patterns.isEmpty ? '先完成一次最小行动与一次事实记录，系统会更容易识别你的真实模式。' : patterns.join('\n'),
      patterns: patterns,
      nextFocus: undone > done ? '先把一条现有行动做成 5~10 分钟版本。' : '继续保持一个单元、一条行动、一条复盘的节奏。',
      todayAction: actions.isNotEmpty ? actions.first.title : '从课程列表中选择一个当前最贴近现实的问题单元。',
      provider: 'local',
      modelLabel: '本地回退',
      raw: '',
    );
  }

  factory StressInsightResult.fromMap(Map<String, dynamic> map, {required String provider, required String modelLabel, String raw = ''}) {
    return StressInsightResult(
      summary: '${map['summary'] ?? ''}',
      patterns: _parseStringList(map['patterns']),
      nextFocus: '${map['next_focus'] ?? ''}',
      todayAction: '${map['today_action'] ?? ''}',
      provider: provider,
      modelLabel: modelLabel,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'summary': summary,
        'patterns': patterns,
        'next_focus': nextFocus,
        'today_action': todayAction,
        'provider': provider,
        'model_label': modelLabel,
        'raw': raw,
      };

  static StressInsightResult? fromJsonMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return StressInsightResult(
      summary: '${map['summary'] ?? ''}',
      patterns: _parseStringList(map['patterns']),
      nextFocus: '${map['next_focus'] ?? ''}',
      todayAction: '${map['today_action'] ?? ''}',
      provider: '${map['provider'] ?? 'local'}',
      modelLabel: '${map['model_label'] ?? '本地回退'}',
      raw: '${map['raw'] ?? ''}',
    );
  }
}

class StressGrowthPoint {
  final String label;
  final int learned;
  final int acted;
  final int reviewed;
  final int simulated;

  const StressGrowthPoint({
    required this.label,
    required this.learned,
    required this.acted,
    required this.reviewed,
    required this.simulated,
  });

  int get score => learned + acted * 2 + reviewed * 2 + simulated;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'learned': learned,
        'acted': acted,
        'reviewed': reviewed,
        'simulated': simulated,
      };

  static StressGrowthPoint fromJson(Map<String, dynamic> json) => StressGrowthPoint(
        label: '${json['label'] ?? ''}',
        learned: int.tryParse('${json['learned'] ?? 0}') ?? 0,
        acted: int.tryParse('${json['acted'] ?? 0}') ?? 0,
        reviewed: int.tryParse('${json['reviewed'] ?? 0}') ?? 0,
        simulated: int.tryParse('${json['simulated'] ?? 0}') ?? 0,
      );
}

class StressGrowthReport {
  final String summary;
  final String majorGain;
  final String fragileLoop;
  final String nextQuest;
  final String storyTitle;
  final String storyBody;
  final String monthFocus;
  final List<StressGrowthPoint> curve;
  final String provider;
  final String modelLabel;
  final String raw;

  const StressGrowthReport({
    required this.summary,
    required this.majorGain,
    required this.fragileLoop,
    required this.nextQuest,
    required this.storyTitle,
    required this.storyBody,
    required this.monthFocus,
    required this.curve,
    required this.provider,
    required this.modelLabel,
    required this.raw,
  });

  factory StressGrowthReport.fallback({
    required List<StressAction> actions,
    required List<StressReviewEntry> reviews,
    required List<StressSceneSession> sessions,
    StressPersonaProfile? persona,
    List<StressGrowthPoint> curve = const <StressGrowthPoint>[],
  }) {
    final doneCount = actions.where((e) => e.status == 'done' || e.status == 'partial').length;
    final failCount = actions.where((e) => e.status == 'failed').length;
    final pressureHeavy = sessions.where((e) => e.pressure >= 60).length;
    final latestFeeling = reviews.isNotEmpty ? reviews.first.feeling.trim() : '';
    final storyRole = persona?.roleLabel ?? '学习者';
    final focus = persona?.currentFocus ?? '先恢复再推进';
    final gain = doneCount > 0
        ? '你已经有 $doneCount 次把课程概念真正带回现实的记录。'
        : '你已经开始积累自己的真实问题样本，而不是只停在理解层面。';
    final fragile = failCount > doneCount
        ? '你现在最脆弱的回路是：生成行动很多，但动作入口还偏大。'
        : (pressureHeavy > 0 ? '你最近在高压力场景里更容易沿用旧模式，需要给恢复和边界留出空间。' : '你当前的系统仍需要更多真实行动数据，才能看清最脆弱的回路。');
    return StressGrowthReport(
      summary: '第三层功能开始关注长期成长：不只看单次行动，而是看你如何在一段时间里形成自己的稳定节律、脆弱回路与修复路径。',
      majorGain: gain,
      fragileLoop: fragile,
      nextQuest: '接下来 7 天，只盯住一个最常重复的卡点，把它做成最小可执行版本并连续记录。',
      storyTitle: '当前剧情：$storyRole 的修复升级线',
      storyBody: '你当前最核心的剧情不是“做更多”，而是围绕“$focus”建立一个更稳定、更可持续的行动结构。${latestFeeling.isEmpty ? '' : '最近最强的主观感受是“$latestFeeling”，它值得被纳入你的长期节律设计。'}',
      monthFocus: '本月重点：减少一个旧的高损耗回路，建立一个新的低门槛固定动作。',
      curve: curve,
      provider: 'local',
      modelLabel: '本地回退',
      raw: '',
    );
  }

  factory StressGrowthReport.fromMap(Map<String, dynamic> map, {required String provider, required String modelLabel, String raw = '', List<StressGrowthPoint> curve = const <StressGrowthPoint>[]}) {
    return StressGrowthReport(
      summary: '${map['summary'] ?? ''}',
      majorGain: '${map['major_gain'] ?? ''}',
      fragileLoop: '${map['fragile_loop'] ?? ''}',
      nextQuest: '${map['next_quest'] ?? ''}',
      storyTitle: '${map['story_title'] ?? ''}',
      storyBody: '${map['story_body'] ?? ''}',
      monthFocus: '${map['month_focus'] ?? ''}',
      curve: curve,
      provider: provider,
      modelLabel: modelLabel,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'summary': summary,
        'major_gain': majorGain,
        'fragile_loop': fragileLoop,
        'next_quest': nextQuest,
        'story_title': storyTitle,
        'story_body': storyBody,
        'month_focus': monthFocus,
        'curve': curve.map((e) => e.toJson()).toList(),
        'provider': provider,
        'model_label': modelLabel,
        'raw': raw,
      };

  static StressGrowthReport? fromJsonMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return StressGrowthReport(
      summary: '${map['summary'] ?? ''}',
      majorGain: '${map['major_gain'] ?? ''}',
      fragileLoop: '${map['fragile_loop'] ?? ''}',
      nextQuest: '${map['next_quest'] ?? ''}',
      storyTitle: '${map['story_title'] ?? ''}',
      storyBody: '${map['story_body'] ?? ''}',
      monthFocus: '${map['month_focus'] ?? ''}',
      curve: ((map['curve'] is List) ? (map['curve'] as List).whereType<Map>().map((e) => StressGrowthPoint.fromJson(Map<String, dynamic>.from(e))).toList() : <StressGrowthPoint>[]),
      provider: '${map['provider'] ?? 'local'}',
      modelLabel: '${map['model_label'] ?? '本地回退'}',
      raw: '${map['raw'] ?? ''}',
    );
  }
}

class StressWeeklyReport {
  final String weekLabel;
  final String headline;
  final String summary;
  final List<String> wins;
  final List<String> blockers;
  final String nextFocus;
  final String recommendedUnitId;
  final String nextAction;
  final String provider;
  final String modelLabel;
  final String raw;

  const StressWeeklyReport({
    required this.weekLabel,
    required this.headline,
    required this.summary,
    required this.wins,
    required this.blockers,
    required this.nextFocus,
    required this.recommendedUnitId,
    required this.nextAction,
    required this.provider,
    required this.modelLabel,
    required this.raw,
  });

  factory StressWeeklyReport.fallback({required List<StressAction> actions, required List<StressReviewEntry> reviews, required List<StressSceneSession> sessions}) {
    final completed = actions.where((e) => e.status == 'done' || e.status == 'partial').toList();
    final blockers = <String>[
      if (actions.where((e) => e.status == 'failed').isNotEmpty) '失败多发生在动作入口偏大或开始前阻力过强。',
      if (sessions.where((e) => e.pressure >= 60).isNotEmpty) '高压力场景下更容易回到旧模式。',
      if (reviews.isNotEmpty && reviews.first.feeling.trim().isNotEmpty) '最近的情绪线索：${reviews.first.feeling.trim()}。',
    ];
    final wins = <String>[
      if (completed.isNotEmpty) '本周已有 ${completed.length} 次把课程带回现实。',
      if (sessions.isNotEmpty) '你已经开始用知行城做低成本预演。',
      if (reviews.isNotEmpty) '你已经留下了 ${reviews.length} 条复盘样本。',
    ];
    final unitId = completed.isNotEmpty ? completed.first.unitId : (reviews.isNotEmpty ? reviews.first.unitId : 'S01');
    return StressWeeklyReport(
      weekLabel: '本周',
      headline: completed.isNotEmpty ? '本周开始形成“学 → 做 → 复”的节律' : '本周更适合先把入口缩小，再追求完整闭环',
      summary: blockers.isEmpty ? '本周数据还不多，先做一次最小行动、一次事实记录，再回来生成更稳定的周报。' : '本周最明显的主题是：${blockers.first.replaceAll('。', '')}，所以接下来最值得做的不是加任务，而是做减法并守住一个小动作。',
      wins: wins.isEmpty ? <String>['你已经开始积累真实数据，而不是只停在理解。'] : wins,
      blockers: blockers.isEmpty ? <String>['当前还缺少足够样本来识别主要阻碍。'] : blockers,
      nextFocus: completed.isNotEmpty ? '守住一条已经发生过的有效动作，把它变成重复出现。' : '把一条动作缩到 5~10 分钟，并只记录一个事实。',
      recommendedUnitId: unitId,
      nextAction: completed.isNotEmpty ? '回到「${completed.first.title}」对应单元，再做一次同款行动。' : '从当前最贴近现实的问题单元开始，先生成一个最小行动。',
      provider: 'local',
      modelLabel: '本地回退',
      raw: '',
    );
  }

  factory StressWeeklyReport.fromMap(Map<String, dynamic> map, {required String provider, required String modelLabel, String raw = ''}) {
    return StressWeeklyReport(
      weekLabel: '${map['week_label'] ?? '本周'}',
      headline: '${map['headline'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      wins: _parseStringList(map['wins']),
      blockers: _parseStringList(map['blockers']),
      nextFocus: '${map['next_focus'] ?? ''}',
      recommendedUnitId: '${map['recommended_unit_id'] ?? 'S01'}',
      nextAction: '${map['next_action'] ?? ''}',
      provider: provider,
      modelLabel: modelLabel,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'week_label': weekLabel,
        'headline': headline,
        'summary': summary,
        'wins': wins,
        'blockers': blockers,
        'next_focus': nextFocus,
        'recommended_unit_id': recommendedUnitId,
        'next_action': nextAction,
        'provider': provider,
        'model_label': modelLabel,
        'raw': raw,
      };

  static StressWeeklyReport? fromJsonMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return StressWeeklyReport(
      weekLabel: '${map['week_label'] ?? '本周'}',
      headline: '${map['headline'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      wins: _parseStringList(map['wins']),
      blockers: _parseStringList(map['blockers']),
      nextFocus: '${map['next_focus'] ?? ''}',
      recommendedUnitId: '${map['recommended_unit_id'] ?? 'S01'}',
      nextAction: '${map['next_action'] ?? ''}',
      provider: '${map['provider'] ?? 'local'}',
      modelLabel: '${map['model_label'] ?? '本地回退'}',
      raw: '${map['raw'] ?? ''}',
    );
  }
}

class StressMonthlyReport {
  final String monthLabel;
  final String headline;
  final String summary;
  final List<String> shifts;
  final List<String> loops;
  final String nextMonthFocus;
  final String recommendedUnitId;
  final String nextExperiment;
  final String provider;
  final String modelLabel;
  final String raw;

  const StressMonthlyReport({
    required this.monthLabel,
    required this.headline,
    required this.summary,
    required this.shifts,
    required this.loops,
    required this.nextMonthFocus,
    required this.recommendedUnitId,
    required this.nextExperiment,
    required this.provider,
    required this.modelLabel,
    required this.raw,
  });

  factory StressMonthlyReport.fallback({required List<StressAction> actions, required List<StressReviewEntry> reviews, required List<StressSceneSession> sessions, StressGrowthReport? growthReport}) {
    final acted = actions.where((e) => e.status == 'done' || e.status == 'partial').length;
    final loops = <String>[
      if (actions.where((e) => e.status == 'failed').length > acted) '旧回路仍表现为：任务生成多，稳定执行少。',
      if (sessions.where((e) => e.pressure >= 60).isNotEmpty) '遇到高压力时更容易回到旧的应对方式。',
      if (reviews.isNotEmpty) '复盘里反复出现的情绪值得进入下月主线。',
    ];
    final shifts = <String>[
      if (acted > 0) '你已经把部分课程概念带回现实，而不再只是阅读。',
      if (sessions.isNotEmpty) '你开始把虚拟场景当作现实前的预演。',
      if (growthReport != null && growthReport.majorGain.trim().isNotEmpty) growthReport.majorGain,
    ];
    final unitId = actions.isNotEmpty ? actions.first.unitId : (reviews.isNotEmpty ? reviews.first.unitId : 'S01');
    return StressMonthlyReport(
      monthLabel: '本月',
      headline: acted > 0 ? '本月主题：从零散努力，走向可持续节律' : '本月主题：先把系统跑起来，再谈提高强度',
      summary: '月度复盘更关心“你在反复形成什么结构”。当前最值得注意的是：${(loops.isNotEmpty ? loops.first : '系统样本还不够多').replaceAll('。', '')}。',
      shifts: shifts.isEmpty ? <String>['你已经开始积累自己的成长样本。'] : shifts,
      loops: loops.isEmpty ? <String>['目前还需要更多真实行动与复盘，才能识别月度旧回路。'] : loops,
      nextMonthFocus: growthReport?.monthFocus ?? '下个月只盯住一条最容易失守的链路，优先做减法与最小动作。',
      recommendedUnitId: unitId,
      nextExperiment: '连续 7 天守住一个固定动作，并在失败时记录事实而不是直接放弃。',
      provider: 'local',
      modelLabel: '本地回退',
      raw: '',
    );
  }

  factory StressMonthlyReport.fromMap(Map<String, dynamic> map, {required String provider, required String modelLabel, String raw = ''}) {
    return StressMonthlyReport(
      monthLabel: '${map['month_label'] ?? '本月'}',
      headline: '${map['headline'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      shifts: _parseStringList(map['shifts']),
      loops: _parseStringList(map['loops']),
      nextMonthFocus: '${map['next_month_focus'] ?? ''}',
      recommendedUnitId: '${map['recommended_unit_id'] ?? 'S01'}',
      nextExperiment: '${map['next_experiment'] ?? ''}',
      provider: provider,
      modelLabel: modelLabel,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'month_label': monthLabel,
        'headline': headline,
        'summary': summary,
        'shifts': shifts,
        'loops': loops,
        'next_month_focus': nextMonthFocus,
        'recommended_unit_id': recommendedUnitId,
        'next_experiment': nextExperiment,
        'provider': provider,
        'model_label': modelLabel,
        'raw': raw,
      };

  static StressMonthlyReport? fromJsonMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return StressMonthlyReport(
      monthLabel: '${map['month_label'] ?? '本月'}',
      headline: '${map['headline'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      shifts: _parseStringList(map['shifts']),
      loops: _parseStringList(map['loops']),
      nextMonthFocus: '${map['next_month_focus'] ?? ''}',
      recommendedUnitId: '${map['recommended_unit_id'] ?? 'S01'}',
      nextExperiment: '${map['next_experiment'] ?? ''}',
      provider: '${map['provider'] ?? 'local'}',
      modelLabel: '${map['model_label'] ?? '本地回退'}',
      raw: '${map['raw'] ?? ''}',
    );
  }
}

class StressProblemRoute {
  final String problem;
  final String summary;
  final List<String> recommendedUnitIds;
  final List<String> reasons;
  final String quickStart;
  final String provider;
  final String modelLabel;
  final String raw;

  const StressProblemRoute({
    required this.problem,
    required this.summary,
    required this.recommendedUnitIds,
    required this.reasons,
    required this.quickStart,
    required this.provider,
    required this.modelLabel,
    required this.raw,
  });

  factory StressProblemRoute.fallback({required String problem, required List<StressUnit> units}) {
    final picked = units.take(3).toList();
    return StressProblemRoute(
      problem: problem,
      summary: '你当前的困扰更适合先从这几段课切入：先理解问题结构，再进入一个最小行动。',
      recommendedUnitIds: picked.map((e) => e.id).toList(),
      reasons: picked.map((e) => '「${e.title}」与“$problem”最接近，因为它直接处理 ${e.concepts.take(2).join('、')}。').toList(),
      quickStart: picked.isNotEmpty ? '先从「${picked.first.title}」开始，再做它的一条最小行动。' : '先选择一个当前最贴近现实的问题单元。',
      provider: 'local',
      modelLabel: '本地推荐',
      raw: '',
    );
  }

  factory StressProblemRoute.fromMap(Map<String, dynamic> map, {required String provider, required String modelLabel, String raw = ''}) {
    return StressProblemRoute(
      problem: '${map['problem'] ?? ''}',
      summary: '${map['summary'] ?? ''}',
      recommendedUnitIds: _parseStringList(map['recommended_unit_ids']),
      reasons: _parseStringList(map['reasons']),
      quickStart: '${map['quick_start'] ?? ''}',
      provider: provider,
      modelLabel: modelLabel,
      raw: raw,
    );
  }
}

List<String> _parseStringList(dynamic raw) {
  if (raw is List) return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.split(RegExp(r'[\n；;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return <String>[];
}

List<bool> _parseStepMarks(dynamic raw) {
  if (raw is List) return raw.map((e) => e == true || '$e' == '1' || '$e'.toLowerCase() == 'true').toList();
  return <bool>[];
}

List<String> _parseSteps(dynamic raw) {
  if (raw is List) return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.split(RegExp(r'\n+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return <String>[];
}

List<StressAction> stressActionsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <StressAction>[];
  try {
    final list = jsonDecode(raw);
    if (list is List) {
      return list.whereType<Map>().map((e) => StressAction.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  } catch (_) {}
  return <StressAction>[];
}

String stressActionsToString(List<StressAction> items) => jsonEncode(items.map((e) => e.toJson()).toList());

List<StressReviewEntry> stressReviewsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <StressReviewEntry>[];
  try {
    final list = jsonDecode(raw);
    if (list is List) {
      return list.whereType<Map>().map((e) => StressReviewEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  } catch (_) {}
  return <StressReviewEntry>[];
}

String stressReviewsToString(List<StressReviewEntry> items) => jsonEncode(items.map((e) => e.toJson()).toList());


List<StressSceneSession> stressSceneSessionsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <StressSceneSession>[];
  try {
    final list = jsonDecode(raw);
    if (list is List) {
      return list.whereType<Map>().map((e) => StressSceneSession.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  } catch (_) {}
  return <StressSceneSession>[];
}

String stressSceneSessionsToString(List<StressSceneSession> items) => jsonEncode(items.map((e) => e.toJson()).toList());
