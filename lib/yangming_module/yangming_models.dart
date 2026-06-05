import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class YangmingLesson {
  final String id;
  final String group;
  final String title;
  final String source;
  final String originalTextSlot;
  final String detailedExplanationSlot;
  final List<String> coreConcepts;
  final List<String> problemTypes;
  final List<String> scenarioCases;
  final List<String> actionPlans;
  final String missionTitle;
  final String missionWorld;
  final String missionSetup;
  final List<YangmingMissionChoice> missionChoices;
  final List<String> reviewPrompts;

  const YangmingLesson({
    required this.id,
    required this.group,
    required this.title,
    required this.source,
    required this.originalTextSlot,
    required this.detailedExplanationSlot,
    required this.coreConcepts,
    required this.problemTypes,
    required this.scenarioCases,
    required this.actionPlans,
    required this.missionTitle,
    required this.missionWorld,
    required this.missionSetup,
    required this.missionChoices,
    required this.reviewPrompts,
  });
}

class YangmingMissionChoice {
  final String id;
  final String label;
  final String feedback;
  final int willDelta;
  final int awarenessDelta;
  final int integrationDelta;

  const YangmingMissionChoice({
    required this.id,
    required this.label,
    required this.feedback,
    required this.willDelta,
    required this.awarenessDelta,
    required this.integrationDelta,
  });

  factory YangmingMissionChoice.fromMap(Map<String, dynamic> map) => YangmingMissionChoice(
        id: (map['id'] ?? '').toString(),
        label: (map['label'] ?? '').toString(),
        feedback: (map['feedback'] ?? '').toString(),
        willDelta: int.tryParse((map['will_delta'] ?? map['willDelta'] ?? '0').toString()) ?? 0,
        awarenessDelta: int.tryParse((map['awareness_delta'] ?? map['awarenessDelta'] ?? '0').toString()) ?? 0,
        integrationDelta: int.tryParse((map['integration_delta'] ?? map['integrationDelta'] ?? '0').toString()) ?? 0,
      );
}

class YangmingMissionRound {
  final String id;
  final String title;
  final String prompt;
  final List<YangmingMissionChoice> choices;
  final String guide;

  const YangmingMissionRound({
    required this.id,
    required this.title,
    required this.prompt,
    required this.choices,
    required this.guide,
  });

  factory YangmingMissionRound.fromMap(Map<String, dynamic> map) => YangmingMissionRound(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        prompt: (map['prompt'] ?? '').toString(),
        choices: ((map['choices'] ?? const <dynamic>[]) as List)
            .whereType<Map>()
            .map((e) => YangmingMissionChoice.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        guide: (map['guide'] ?? '').toString(),
      );
}

class YangmingMissionConfig {
  final String lessonId;
  final String title;
  final String world;
  final int version;
  final List<YangmingMissionRound> rounds;
  final YangmingMissionSummaryProfile summaryProfile;

  const YangmingMissionConfig({
    required this.lessonId,
    required this.title,
    required this.world,
    required this.version,
    required this.rounds,
    required this.summaryProfile,
  });

  factory YangmingMissionConfig.fromMap(Map<String, dynamic> map) {
    final rounds = ((map['rounds'] ?? const <dynamic>[]) as List)
        .whereType<Map>()
        .map((e) => YangmingMissionRound.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return YangmingMissionConfig(
      lessonId: (map['lesson_id'] ?? map['lessonId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      world: (map['world'] ?? '').toString(),
      version: int.tryParse((map['version'] ?? '1').toString()) ?? 1,
      rounds: rounds,
      summaryProfile: YangmingMissionSummaryProfile.fromMap(Map<String, dynamic>.from((map['summary'] ?? const <String, dynamic>{}) as Map)),
    );
  }
}

class YangmingMissionSummaryProfile {
  final YangmingMissionRouteProfile high;
  final YangmingMissionRouteProfile mid;
  final YangmingMissionRouteProfile low;

  const YangmingMissionSummaryProfile({
    required this.high,
    required this.mid,
    required this.low,
  });

  factory YangmingMissionSummaryProfile.fromMap(Map<String, dynamic> map) => YangmingMissionSummaryProfile(
        high: YangmingMissionRouteProfile.fromMap(Map<String, dynamic>.from((map['high'] ?? const <String, dynamic>{}) as Map), fallbackTag: '知行已接上', fallbackDiagnosis: '你已经把课程、情境和现实动作重新接上。'),
        mid: YangmingMissionRouteProfile.fromMap(Map<String, dynamic>.from((map['mid'] ?? const <String, dynamic>{}) as Map), fallbackTag: '已看见，但还不稳', fallbackDiagnosis: '你已经看见了结构，但现实迁移和守持还不够稳定。'),
        low: YangmingMissionRouteProfile.fromMap(Map<String, dynamic>.from((map['low'] ?? const <String, dynamic>{}) as Map), fallbackTag: '仍在自动路径里', fallbackDiagnosis: '你更像被旧路径带着走，下一步要把断开的地方重新接上。'),
      );
}

class YangmingMissionRouteProfile {
  final String routeTag;
  final String diagnosis;

  const YangmingMissionRouteProfile({required this.routeTag, required this.diagnosis});

  factory YangmingMissionRouteProfile.fromMap(Map<String, dynamic> map, {required String fallbackTag, required String fallbackDiagnosis}) => YangmingMissionRouteProfile(
        routeTag: (map['route_tag'] ?? map['routeTag'] ?? fallbackTag).toString(),
        diagnosis: (map['diagnosis'] ?? fallbackDiagnosis).toString(),
      );
}

class YangmingMissionSummary {
  final int willScore;
  final int awarenessScore;
  final int integrationScore;
  final String routeTag;
  final String diagnosis;
  final String realityTask;
  final String reviewQuestion;

  const YangmingMissionSummary({
    required this.willScore,
    required this.awarenessScore,
    required this.integrationScore,
    required this.routeTag,
    required this.diagnosis,
    required this.realityTask,
    required this.reviewQuestion,
  });
}

List<YangmingMissionRound> buildMissionRounds(YangmingLesson lesson, {YangmingMissionConfig? config}) {
  if (config != null && config.rounds.isNotEmpty) return config.rounds;
  final String problem1 = lesson.problemTypes.isNotEmpty ? lesson.problemTypes.first : '知行断裂';
  final String problem2 = lesson.problemTypes.length > 1 ? lesson.problemTypes[1] : problem1;
  final String action1 = lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '今天先完成一个10分钟内可启动的动作';
  final String action2 = lesson.actionPlans.length > 1 ? lesson.actionPlans[1] : action1;
  final String review1 = lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪一刻最能体现这段课程的关键问题？';
  final String review2 = lesson.reviewPrompts.length > 1 ? lesson.reviewPrompts[1] : review1;
  final String concept1 = lesson.coreConcepts.isNotEmpty ? lesson.coreConcepts.first : lesson.title;
  final String concept2 = lesson.coreConcepts.length > 1 ? lesson.coreConcepts[1] : concept1;

  return <YangmingMissionRound>[
    YangmingMissionRound(
      id: 'round_1_scene',
      title: '第一轮：进入情境',
      prompt: lesson.missionSetup,
      choices: lesson.missionChoices,
      guide: '先看见你面对情境时的第一反应，它常常就是平时的自动路径。',
    ),
    YangmingMissionRound(
      id: 'round_2_inner',
      title: '第二轮：辨认内在结构',
      prompt: '如果把刚才的反应放回现实，你当前更像卡在什么地方？请不要急着自我解释，先识别结构。',
      choices: <YangmingMissionChoice>[
        YangmingMissionChoice(
          id: 'A',
          label: '先把问题归给环境、别人或时机',
          feedback: '这会让你暂时轻松，但真正的卡点被继续遮住。',
          willDelta: -1,
          awarenessDelta: -2,
          integrationDelta: -1,
        ),
        YangmingMissionChoice(
          id: 'B',
          label: '承认当前更像“$problem1”，先看见再说',
          feedback: '你开始把问题从情绪层带回结构层，觉察正在变清楚。',
          willDelta: 1,
          awarenessDelta: 2,
          integrationDelta: 1,
        ),
        YangmingMissionChoice(
          id: 'C',
          label: '直接用“$concept1 / $concept2”对照眼前情境',
          feedback: '你把课程概念带回了情境本身，知与行开始重新接上。',
          willDelta: 2,
          awarenessDelta: 3,
          integrationDelta: 3,
        ),
      ],
      guide: '这一轮不是求对错，而是把“我不舒服”翻译成“我现在卡在哪一种问题结构里”。',
    ),
    YangmingMissionRound(
      id: 'round_3_action',
      title: '第三轮：现实迁移',
      prompt: '现在不要停在理解上。请决定：你要把这次关卡，怎样搬回今天的真实生活？',
      choices: <YangmingMissionChoice>[
        YangmingMissionChoice(
          id: 'A',
          label: '先记住，等以后有状态再做',
          feedback: '你再次把迁移推迟，虚拟世界和现实世界重新断开了。',
          willDelta: -2,
          awarenessDelta: 0,
          integrationDelta: -3,
        ),
        YangmingMissionChoice(
          id: 'B',
          label: '先写下复盘问题：“$review1”',
          feedback: '你开始搭桥，但还缺一小步现实动作来完成闭环。',
          willDelta: 1,
          awarenessDelta: 2,
          integrationDelta: 1,
        ),
        YangmingMissionChoice(
          id: 'C',
          label: '立即带走现实动作：“$action1”',
          feedback: '你完成了从情境、结构到现实动作的迁移，这正是原 PRD 里虚拟世界的目的。',
          willDelta: 3,
          awarenessDelta: 1,
          integrationDelta: 4,
        ),
      ],
      guide: '这一轮决定的是：这次操练会不会真的改变你今天的生活。',
    ),
    YangmingMissionRound(
      id: 'round_4_reinforce',
      title: '第四轮：守持与补救',
      prompt: '如果现实里没有一次做到，你准备如何避免“全盘放弃”，而是继续把工夫接回去？',
      choices: <YangmingMissionChoice>[
        YangmingMissionChoice(
          id: 'A',
          label: '没做到就算了，说明现在还不适合',
          feedback: '这会把一次失手放大成整体否定，守持会在这里断掉。',
          willDelta: -2,
          awarenessDelta: -1,
          integrationDelta: -2,
        ),
        YangmingMissionChoice(
          id: 'B',
          label: '回到复盘问题：“$review2”再看一次',
          feedback: '你没有让训练断掉，而是在失败后保住了回看的通道。',
          willDelta: 1,
          awarenessDelta: 2,
          integrationDelta: 2,
        ),
        YangmingMissionChoice(
          id: 'C',
          label: '动作再缩小一半，继续做：“$action2”',
          feedback: '你开始具备真正的守持能力：不中断地把路接回去。',
          willDelta: 3,
          awarenessDelta: 2,
          integrationDelta: 3,
        ),
      ],
      guide: '真正的训练，不是一次选对，而是在失手后还能把工夫接回来。',
    ),
  ];
}

YangmingMissionSummary summarizeMissionRun({
  required YangmingLesson lesson,
  required List<YangmingMissionChoice> pickedChoices,
  YangmingMissionConfig? config,
}) {
  final int willScore = pickedChoices.fold(0, (sum, item) => sum + item.willDelta);
  final int awarenessScore = pickedChoices.fold(0, (sum, item) => sum + item.awarenessDelta);
  final int integrationScore = pickedChoices.fold(0, (sum, item) => sum + item.integrationDelta);
  final String action1 = lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '今天先做一个10分钟内可启动的小动作';
  final String action2 = lesson.actionPlans.length > 1 ? lesson.actionPlans[1] : action1;
  final String review = lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪一刻最能体现这段课程的关键问题？';

  late final String routeTag;
  late final String diagnosis;
  late final String realityTask;

  final summaryProfile = config?.summaryProfile;
  if (integrationScore >= 8 && willScore >= 6) {
    routeTag = summaryProfile?.high.routeTag ?? '知行已接上';
    diagnosis = summaryProfile?.high.diagnosis ?? '这次操练里，你不只是做了较好的选择，还把课程概念、现实情境和后续守持接在了一起。接下来重点不是再多想，而是把这条路线在现实里真正走一次。';
    realityTask = action1;
  } else if (awarenessScore >= 4) {
    routeTag = summaryProfile?.mid.routeTag ?? '已看见，但还不稳';
    diagnosis = summaryProfile?.mid.diagnosis ?? '你已经能识别自己的问题结构，也愿意回看，但现实迁移和守持还不够稳定。最重要的是把动作再缩小，避免“理解很多、启动很慢”。';
    realityTask = action2;
  } else {
    routeTag = summaryProfile?.low.routeTag ?? '仍在自动路径里';
    diagnosis = summaryProfile?.low.diagnosis ?? '这次更像是被自动反应带着走：要么把问题推给外界，要么把训练推迟到以后。下一步不要追求复杂修正，只先做一个最小动作，把断开的地方重新接上。';
    realityTask = action1;
  }

  return YangmingMissionSummary(
    willScore: willScore,
    awarenessScore: awarenessScore,
    integrationScore: integrationScore,
    routeTag: routeTag,
    diagnosis: diagnosis,
    realityTask: realityTask,
    reviewQuestion: review,
  );
}


Future<Map<String, YangmingMissionConfig>> loadYangmingMissionConfigs() async {
  try {
    final raw = await rootBundle.loadString('assets/yangming_module/mission_state_machines.json');
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return <String, YangmingMissionConfig>{};
    final configs = ((decoded['configs'] ?? const <dynamic>[]) as List)
        .whereType<Map>()
        .map((e) => YangmingMissionConfig.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.lessonId.trim().isNotEmpty)
        .toList();
    return <String, YangmingMissionConfig>{for (final c in configs) c.lessonId: c};
  } catch (_) {
    return <String, YangmingMissionConfig>{};
  }
}

class YangmingPersonaProfile {
  final String roleIdentity;
  final String personalityTendency;
  final String commonBias;
  final String stressTrigger;
  final String supportStyle;
  final String updatedAt;

  const YangmingPersonaProfile({
    required this.roleIdentity,
    required this.personalityTendency,
    required this.commonBias,
    required this.stressTrigger,
    required this.supportStyle,
    required this.updatedAt,
  });

  static const YangmingPersonaProfile empty = YangmingPersonaProfile(
    roleIdentity: '',
    personalityTendency: '',
    commonBias: '',
    stressTrigger: '',
    supportStyle: '',
    updatedAt: '',
  );

  bool get hasAnyProfile =>
      roleIdentity.trim().isNotEmpty ||
      personalityTendency.trim().isNotEmpty ||
      commonBias.trim().isNotEmpty ||
      stressTrigger.trim().isNotEmpty ||
      supportStyle.trim().isNotEmpty;

  String get summaryLine {
    final parts = <String>[
      if (roleIdentity.trim().isNotEmpty) '角色：$roleIdentity',
      if (personalityTendency.trim().isNotEmpty) '倾向：$personalityTendency',
      if (commonBias.trim().isNotEmpty) '偏差：$commonBias',
    ];
    return parts.join(' · ');
  }

  YangmingPersonaProfile copyWith({
    String? roleIdentity,
    String? personalityTendency,
    String? commonBias,
    String? stressTrigger,
    String? supportStyle,
    String? updatedAt,
  }) {
    return YangmingPersonaProfile(
      roleIdentity: roleIdentity ?? this.roleIdentity,
      personalityTendency: personalityTendency ?? this.personalityTendency,
      commonBias: commonBias ?? this.commonBias,
      stressTrigger: stressTrigger ?? this.stressTrigger,
      supportStyle: supportStyle ?? this.supportStyle,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'roleIdentity': roleIdentity,
        'personalityTendency': personalityTendency,
        'commonBias': commonBias,
        'stressTrigger': stressTrigger,
        'supportStyle': supportStyle,
        'updatedAt': updatedAt,
      };

  factory YangmingPersonaProfile.fromJson(Map<String, dynamic> json) => YangmingPersonaProfile(
        roleIdentity: (json['roleIdentity'] ?? json['role_identity'] ?? '').toString(),
        personalityTendency: (json['personalityTendency'] ?? json['personality_tendency'] ?? '').toString(),
        commonBias: (json['commonBias'] ?? json['common_bias'] ?? '').toString(),
        stressTrigger: (json['stressTrigger'] ?? json['stress_trigger'] ?? '').toString(),
        supportStyle: (json['supportStyle'] ?? json['support_style'] ?? '').toString(),
        updatedAt: (json['updatedAt'] ?? json['updated_at'] ?? '').toString(),
      );
}

class YangmingLessonContent {

  final String lessonId;
  final String originalText;
  final String detailedExplanation;
  final String source;
  final String updatedAt;

  const YangmingLessonContent({
    required this.lessonId,
    required this.originalText,
    required this.detailedExplanation,
    required this.source,
    required this.updatedAt,
  });

  bool get hasAnyContent => originalText.trim().isNotEmpty || detailedExplanation.trim().isNotEmpty;

  YangmingLessonContent copyWith({
    String? lessonId,
    String? originalText,
    String? detailedExplanation,
    String? source,
    String? updatedAt,
  }) {
    return YangmingLessonContent(
      lessonId: lessonId ?? this.lessonId,
      originalText: originalText ?? this.originalText,
      detailedExplanation: detailedExplanation ?? this.detailedExplanation,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lessonId': lessonId,
        'originalText': originalText,
        'detailedExplanation': detailedExplanation,
        'source': source,
        'updatedAt': updatedAt,
      };

  factory YangmingLessonContent.fromJson(Map<String, dynamic> json) {
    final original = (json['originalText'] ?? json['original_text'] ?? json['text'] ?? '').toString();
    final detailed = (json['detailedExplanation'] ?? json['detailed_explanation'] ?? json['explanation'] ?? json['deepAnalysis'] ?? json['deep_analysis'] ?? json['analysis'] ?? '').toString();
    return YangmingLessonContent(
      lessonId: (json['lessonId'] ?? json['lesson_id'] ?? json['id'] ?? '').toString(),
      originalText: original,
      detailedExplanation: detailed,
      source: (json['source'] ?? 'manual').toString(),
      updatedAt: (json['updatedAt'] ?? json['updated_at'] ?? '').toString(),
    );
  }
}

class YangmingAction {
  final String id;
  final String lessonId;
  final String lessonTitle;
  final String taskTitle;
  final String instruction;
  final String status; // todo doing done
  final String createdAt;
  final String updatedAt;
  final String source; // manual ai mission review_followup
  final String fact;
  final String diagnosisSummary;
  final String nextStepSuggestion;
  final String reviewQuestion;
  final String lessonRecommendationId;
  final String lessonRecommendationTitle;
  final String lastAiDiagnosisAt;

  const YangmingAction({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.taskTitle,
    required this.instruction,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    required this.fact,
    required this.diagnosisSummary,
    required this.nextStepSuggestion,
    required this.reviewQuestion,
    required this.lessonRecommendationId,
    required this.lessonRecommendationTitle,
    required this.lastAiDiagnosisAt,
  });

  YangmingAction copyWith({
    String? id,
    String? lessonId,
    String? lessonTitle,
    String? taskTitle,
    String? instruction,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? source,
    String? fact,
    String? diagnosisSummary,
    String? nextStepSuggestion,
    String? reviewQuestion,
    String? lessonRecommendationId,
    String? lessonRecommendationTitle,
    String? lastAiDiagnosisAt,
  }) {
    return YangmingAction(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      taskTitle: taskTitle ?? this.taskTitle,
      instruction: instruction ?? this.instruction,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      fact: fact ?? this.fact,
      diagnosisSummary: diagnosisSummary ?? this.diagnosisSummary,
      nextStepSuggestion: nextStepSuggestion ?? this.nextStepSuggestion,
      reviewQuestion: reviewQuestion ?? this.reviewQuestion,
      lessonRecommendationId: lessonRecommendationId ?? this.lessonRecommendationId,
      lessonRecommendationTitle: lessonRecommendationTitle ?? this.lessonRecommendationTitle,
      lastAiDiagnosisAt: lastAiDiagnosisAt ?? this.lastAiDiagnosisAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'taskTitle': taskTitle,
        'instruction': instruction,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'source': source,
        'fact': fact,
        'diagnosisSummary': diagnosisSummary,
        'nextStepSuggestion': nextStepSuggestion,
        'reviewQuestion': reviewQuestion,
        'lessonRecommendationId': lessonRecommendationId,
        'lessonRecommendationTitle': lessonRecommendationTitle,
        'lastAiDiagnosisAt': lastAiDiagnosisAt,
      };

  factory YangmingAction.fromJson(Map<String, dynamic> json) => YangmingAction(
        id: (json['id'] ?? '').toString(),
        lessonId: (json['lessonId'] ?? '').toString(),
        lessonTitle: (json['lessonTitle'] ?? '').toString(),
        taskTitle: (json['taskTitle'] ?? '').toString(),
        instruction: (json['instruction'] ?? '').toString(),
        status: (json['status'] ?? 'todo').toString(),
        createdAt: (json['createdAt'] ?? '').toString(),
        updatedAt: (json['updatedAt'] ?? '').toString(),
        source: (json['source'] ?? 'manual').toString(),
        fact: (json['fact'] ?? '').toString(),
        diagnosisSummary: (json['diagnosisSummary'] ?? '').toString(),
        nextStepSuggestion: (json['nextStepSuggestion'] ?? '').toString(),
        reviewQuestion: (json['reviewQuestion'] ?? '').toString(),
        lessonRecommendationId: (json['lessonRecommendationId'] ?? '').toString(),
        lessonRecommendationTitle: (json['lessonRecommendationTitle'] ?? '').toString(),
        lastAiDiagnosisAt: (json['lastAiDiagnosisAt'] ?? '').toString(),
      );
}

class YangmingTrainingPlanResult {
  final int durationDays;
  final String planTheme;
  final String planSummary;
  final List<String> dailyTasks;
  final List<String> guardrails;
  final List<String> checkpoints;
  final List<String> reviewPrompts;
  final String raw;

  const YangmingTrainingPlanResult({
    required this.durationDays,
    required this.planTheme,
    required this.planSummary,
    required this.dailyTasks,
    required this.guardrails,
    required this.checkpoints,
    required this.reviewPrompts,
    required this.raw,
  });

  factory YangmingTrainingPlanResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingTrainingPlanResult(
        durationDays: int.tryParse((map['duration_days'] ?? map['durationDays'] ?? '3').toString()) ?? 3,
        planTheme: (map['plan_theme'] ?? map['planTheme'] ?? '').toString(),
        planSummary: (map['plan_summary'] ?? map['planSummary'] ?? '').toString(),
        dailyTasks: ((map['daily_tasks'] ?? map['dailyTasks'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        guardrails: ((map['guardrails'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        checkpoints: ((map['checkpoints'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        reviewPrompts: ((map['review_prompts'] ?? map['reviewPrompts'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        raw: raw,
      );

  factory YangmingTrainingPlanResult.fallback(YangmingLesson lesson, int durationDays) {
    final baseActions = lesson.actionPlans.where((e) => e.trim().isNotEmpty).toList();
    final baseReviews = lesson.reviewPrompts.where((e) => e.trim().isNotEmpty).toList();
    final tasks = <String>[];
    for (int i = 0; i < durationDays; i++) {
      final action = baseActions.isNotEmpty ? baseActions[i % baseActions.length] : '今天先完成一个可观察的小动作';
      tasks.add('第${i + 1}天：$action');
    }
    return YangmingTrainingPlanResult(
      durationDays: durationDays,
      planTheme: '${lesson.title} · ${durationDays}天守持计划',
      planSummary: '把这段课程的关键义理压缩成一段连续训练：不是只懂一次，而是连续${durationDays}天在现实里反复接上。',
      dailyTasks: tasks,
      guardrails: <String>[
        '不要追求一步到位，只守住今天这一小步。',
        '如果失手，不做整体否定，当天缩小动作继续接上。',
      ],
      checkpoints: <String>[
        '第1天：先把动作真正启动。',
        durationDays >= 7 ? '第4天：检查是不是又回到旧自动路径。' : '中段：检查是否把动作做成了口头承诺。',
        '最后一天：回答一次“这段课程怎样进入了我的现实生活？”',
      ],
      reviewPrompts: baseReviews.isNotEmpty ? baseReviews.take(3).toList() : <String>['今天哪一刻最能体现这段课程的关键问题？'],
      raw: 'fallback',
    );
  }
}

class YangmingTrainingPlan {
  final String id;
  final String lessonId;
  final String lessonTitle;
  final int durationDays;
  final String planTheme;
  final String planSummary;
  final List<String> dailyTasks;
  final List<String> guardrails;
  final List<String> checkpoints;
  final List<String> reviewPrompts;
  final String status;
  final String source;
  final String createdAt;
  final String updatedAt;

  const YangmingTrainingPlan({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.durationDays,
    required this.planTheme,
    required this.planSummary,
    required this.dailyTasks,
    required this.guardrails,
    required this.checkpoints,
    required this.reviewPrompts,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  YangmingTrainingPlan copyWith({
    String? id,
    String? lessonId,
    String? lessonTitle,
    int? durationDays,
    String? planTheme,
    String? planSummary,
    List<String>? dailyTasks,
    List<String>? guardrails,
    List<String>? checkpoints,
    List<String>? reviewPrompts,
    String? status,
    String? source,
    String? createdAt,
    String? updatedAt,
  }) => YangmingTrainingPlan(
        id: id ?? this.id,
        lessonId: lessonId ?? this.lessonId,
        lessonTitle: lessonTitle ?? this.lessonTitle,
        durationDays: durationDays ?? this.durationDays,
        planTheme: planTheme ?? this.planTheme,
        planSummary: planSummary ?? this.planSummary,
        dailyTasks: dailyTasks ?? this.dailyTasks,
        guardrails: guardrails ?? this.guardrails,
        checkpoints: checkpoints ?? this.checkpoints,
        reviewPrompts: reviewPrompts ?? this.reviewPrompts,
        status: status ?? this.status,
        source: source ?? this.source,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'durationDays': durationDays,
        'planTheme': planTheme,
        'planSummary': planSummary,
        'dailyTasks': dailyTasks,
        'guardrails': guardrails,
        'checkpoints': checkpoints,
        'reviewPrompts': reviewPrompts,
        'status': status,
        'source': source,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory YangmingTrainingPlan.fromJson(Map<String, dynamic> json) => YangmingTrainingPlan(
        id: (json['id'] ?? '').toString(),
        lessonId: (json['lessonId'] ?? '').toString(),
        lessonTitle: (json['lessonTitle'] ?? '').toString(),
        durationDays: int.tryParse((json['durationDays'] ?? '3').toString()) ?? 3,
        planTheme: (json['planTheme'] ?? '').toString(),
        planSummary: (json['planSummary'] ?? '').toString(),
        dailyTasks: ((json['dailyTasks'] ?? const []) as List).map((e) => e.toString()).toList(),
        guardrails: ((json['guardrails'] ?? const []) as List).map((e) => e.toString()).toList(),
        checkpoints: ((json['checkpoints'] ?? const []) as List).map((e) => e.toString()).toList(),
        reviewPrompts: ((json['reviewPrompts'] ?? const []) as List).map((e) => e.toString()).toList(),
        status: (json['status'] ?? 'active').toString(),
        source: (json['source'] ?? 'ai_training_plan').toString(),
        createdAt: (json['createdAt'] ?? '').toString(),
        updatedAt: (json['updatedAt'] ?? '').toString(),
      );
}

class YangmingTrainingDayCheckin {
  final int dayIndex;
  final String task;
  final bool done;
  final String fact;
  final String reflection;
  final String checkedAt;

  const YangmingTrainingDayCheckin({
    required this.dayIndex,
    required this.task,
    required this.done,
    required this.fact,
    required this.reflection,
    required this.checkedAt,
  });

  YangmingTrainingDayCheckin copyWith({
    int? dayIndex,
    String? task,
    bool? done,
    String? fact,
    String? reflection,
    String? checkedAt,
  }) => YangmingTrainingDayCheckin(
        dayIndex: dayIndex ?? this.dayIndex,
        task: task ?? this.task,
        done: done ?? this.done,
        fact: fact ?? this.fact,
        reflection: reflection ?? this.reflection,
        checkedAt: checkedAt ?? this.checkedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dayIndex': dayIndex,
        'task': task,
        'done': done,
        'fact': fact,
        'reflection': reflection,
        'checkedAt': checkedAt,
      };

  factory YangmingTrainingDayCheckin.fromJson(Map<String, dynamic> json) => YangmingTrainingDayCheckin(
        dayIndex: int.tryParse((json['dayIndex'] ?? json['day_index'] ?? '0').toString()) ?? 0,
        task: (json['task'] ?? '').toString(),
        done: json['done'] == true,
        fact: (json['fact'] ?? '').toString(),
        reflection: (json['reflection'] ?? '').toString(),
        checkedAt: (json['checkedAt'] ?? json['checked_at'] ?? '').toString(),
      );
}

class YangmingTrainingTrace {
  final String planId;
  final String lessonId;
  final String lessonTitle;
  final List<YangmingTrainingDayCheckin> days;
  final String latestCorrection;
  final String latestWeeklySummary;
  final String updatedAt;

  const YangmingTrainingTrace({
    required this.planId,
    required this.lessonId,
    required this.lessonTitle,
    required this.days,
    required this.latestCorrection,
    required this.latestWeeklySummary,
    required this.updatedAt,
  });

  int get completedDays => days.where((e) => e.done).length;
  bool get hasAnyProgress => days.any((e) => e.done || e.fact.trim().isNotEmpty || e.reflection.trim().isNotEmpty);

  YangmingTrainingTrace copyWith({
    String? planId,
    String? lessonId,
    String? lessonTitle,
    List<YangmingTrainingDayCheckin>? days,
    String? latestCorrection,
    String? latestWeeklySummary,
    String? updatedAt,
  }) => YangmingTrainingTrace(
        planId: planId ?? this.planId,
        lessonId: lessonId ?? this.lessonId,
        lessonTitle: lessonTitle ?? this.lessonTitle,
        days: days ?? this.days,
        latestCorrection: latestCorrection ?? this.latestCorrection,
        latestWeeklySummary: latestWeeklySummary ?? this.latestWeeklySummary,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'planId': planId,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'days': days.map((e) => e.toJson()).toList(),
        'latestCorrection': latestCorrection,
        'latestWeeklySummary': latestWeeklySummary,
        'updatedAt': updatedAt,
      };

  factory YangmingTrainingTrace.fromJson(Map<String, dynamic> json) => YangmingTrainingTrace(
        planId: (json['planId'] ?? '').toString(),
        lessonId: (json['lessonId'] ?? '').toString(),
        lessonTitle: (json['lessonTitle'] ?? '').toString(),
        days: ((json['days'] ?? const []) as List).map((e) => YangmingTrainingDayCheckin.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        latestCorrection: (json['latestCorrection'] ?? '').toString(),
        latestWeeklySummary: (json['latestWeeklySummary'] ?? '').toString(),
        updatedAt: (json['updatedAt'] ?? '').toString(),
      );

  factory YangmingTrainingTrace.emptyForPlan(YangmingTrainingPlan plan) => YangmingTrainingTrace(
        planId: plan.id,
        lessonId: plan.lessonId,
        lessonTitle: plan.lessonTitle,
        days: List<YangmingTrainingDayCheckin>.generate(
          plan.dailyTasks.length,
          (index) => YangmingTrainingDayCheckin(
            dayIndex: index + 1,
            task: plan.dailyTasks[index],
            done: false,
            fact: '',
            reflection: '',
            checkedAt: '',
          ),
        ),
        latestCorrection: '',
        latestWeeklySummary: '',
        updatedAt: '',
      );
}

class YangmingTrainingCorrectionResult {
  final String mainPattern;
  final String keepDoing;
  final String adjustNow;
  final String nextFocus;
  final String reminder;
  final String raw;

  const YangmingTrainingCorrectionResult({
    required this.mainPattern,
    required this.keepDoing,
    required this.adjustNow,
    required this.nextFocus,
    required this.reminder,
    required this.raw,
  });

  factory YangmingTrainingCorrectionResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingTrainingCorrectionResult(
        mainPattern: (map['main_pattern'] ?? map['mainPattern'] ?? '').toString(),
        keepDoing: (map['keep_doing'] ?? map['keepDoing'] ?? '').toString(),
        adjustNow: (map['adjust_now'] ?? map['adjustNow'] ?? '').toString(),
        nextFocus: (map['next_focus'] ?? map['nextFocus'] ?? '').toString(),
        reminder: (map['reminder'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingTrainingCorrectionResult.fallback(YangmingTrainingPlan plan, YangmingTrainingTrace trace) => YangmingTrainingCorrectionResult(
        mainPattern: trace.completedDays <= 1 ? '计划刚开始，最需要的是把节奏稳住。' : '你已经开始行动，但守持还不够稳定。',
        keepDoing: plan.guardrails.isNotEmpty ? plan.guardrails.first : '继续保持每天至少一个最小动作。',
        adjustNow: trace.days.firstWhere((e) => !e.done, orElse: () => trace.days.first).task,
        nextFocus: '未来3天重点不是求多，而是把最小动作连续接上。',
        reminder: '不要因为中间有起伏就把整个训练推翻。',
        raw: 'fallback',
      );
}

class YangmingTrainingWeeklySummaryResult {
  final String completionSignal;
  final String biggestShift;
  final String recurringObstacle;
  final String nextWeekFocus;
  final String reminder;
  final String raw;

  const YangmingTrainingWeeklySummaryResult({
    required this.completionSignal,
    required this.biggestShift,
    required this.recurringObstacle,
    required this.nextWeekFocus,
    required this.reminder,
    required this.raw,
  });

  factory YangmingTrainingWeeklySummaryResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingTrainingWeeklySummaryResult(
        completionSignal: (map['completion_signal'] ?? map['completionSignal'] ?? '').toString(),
        biggestShift: (map['biggest_shift'] ?? map['biggestShift'] ?? '').toString(),
        recurringObstacle: (map['recurring_obstacle'] ?? map['recurringObstacle'] ?? '').toString(),
        nextWeekFocus: (map['next_week_focus'] ?? map['nextWeekFocus'] ?? '').toString(),
        reminder: (map['reminder'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingTrainingWeeklySummaryResult.fallback(YangmingTrainingPlan plan, YangmingTrainingTrace trace) => YangmingTrainingWeeklySummaryResult(
        completionSignal: '已完成${trace.completedDays}/${plan.dailyTasks.length}天。',
        biggestShift: trace.hasAnyProgress ? '你已经开始把课程从理解层往现实行为层推进。' : '这周最大的信号是：你仍需要先把训练真正启动。',
        recurringObstacle: '高频障碍往往不在不知道，而在中途失守后没有及时接回。',
        nextWeekFocus: '下一周最重要的是减少动作门槛，并把复盘问题真正用起来。',
        reminder: '真正的训练不是完美执行，而是连续把工夫接回现实。',
        raw: 'fallback',
      );
}

class YangmingNextCycleRecommendationResult {
  final String recommendedLessonId;
  final String recommendedLessonTitle;
  final int recommendedDurationDays;
  final String recommendationSummary;
  final String whyThisLesson;
  final String whyThisDuration;
  final String trainingFocus;
  final List<String> starterActions;
  final List<String> reviewPrompts;
  final String raw;

  const YangmingNextCycleRecommendationResult({
    required this.recommendedLessonId,
    required this.recommendedLessonTitle,
    required this.recommendedDurationDays,
    required this.recommendationSummary,
    required this.whyThisLesson,
    required this.whyThisDuration,
    required this.trainingFocus,
    required this.starterActions,
    required this.reviewPrompts,
    required this.raw,
  });


  Map<String, dynamic> toJson() => <String, dynamic>{
        'recommended_lesson_id': recommendedLessonId,
        'recommended_lesson_title': recommendedLessonTitle,
        'recommended_duration_days': recommendedDurationDays,
        'recommendation_summary': recommendationSummary,
        'why_this_lesson': whyThisLesson,
        'why_this_duration': whyThisDuration,
        'training_focus': trainingFocus,
        'starter_actions': starterActions,
        'review_prompts': reviewPrompts,
        'raw': raw,
      };

  factory YangmingNextCycleRecommendationResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingNextCycleRecommendationResult(
        recommendedLessonId: (map['recommended_lesson_id'] ?? map['recommendedLessonId'] ?? '').toString(),
        recommendedLessonTitle: (map['recommended_lesson_title'] ?? map['recommendedLessonTitle'] ?? '').toString(),
        recommendedDurationDays: int.tryParse((map['recommended_duration_days'] ?? map['recommendedDurationDays'] ?? '7').toString()) ?? 7,
        recommendationSummary: (map['recommendation_summary'] ?? map['recommendationSummary'] ?? '').toString(),
        whyThisLesson: (map['why_this_lesson'] ?? map['whyThisLesson'] ?? '').toString(),
        whyThisDuration: (map['why_this_duration'] ?? map['whyThisDuration'] ?? '').toString(),
        trainingFocus: (map['training_focus'] ?? map['trainingFocus'] ?? '').toString(),
        starterActions: ((map['starter_actions'] ?? map['starterActions'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        reviewPrompts: ((map['review_prompts'] ?? map['reviewPrompts'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        raw: raw,
      );

  factory YangmingNextCycleRecommendationResult.fallback({required YangmingLesson currentLesson, required YangmingTrainingPlan currentPlan, required YangmingTrainingTrace trace}) {
    final nextDays = currentPlan.durationDays >= 14 ? 14 : (currentPlan.durationDays >= 7 ? 7 : 3);
    return YangmingNextCycleRecommendationResult(
      recommendedLessonId: currentLesson.id,
      recommendedLessonTitle: currentLesson.title,
      recommendedDurationDays: nextDays,
      recommendationSummary: trace.completedDays == 0
          ? '先不要急着跳到新主题，建议继续围绕当前课程把训练真正启动。'
          : '建议先围绕当前课程再做一轮更稳的守持，把已经出现的变化压实。',
      whyThisLesson: '当前主要模式还没有完全走出原课程的问题结构，继续围绕这一段更容易形成稳定改观。',
      whyThisDuration: nextDays == 3 ? '先用3天把动作重新接上。' : (nextDays == 7 ? '7天更适合把节奏稳定下来。' : '14天更适合把守持拉长。'),
      trainingFocus: trace.completedDays == 0 ? '降低门槛、先启动，不要继续停留在理解层。' : '减少起伏、增加守持，把最小动作真正做成连续轨迹。',
      starterActions: currentLesson.actionPlans.take(3).toList(),
      reviewPrompts: currentLesson.reviewPrompts.take(3).toList(),
      raw: 'fallback',
    );
  }
}

class YangmingGrowthNavigatorResult {
  final String recommendedLessonId;
  final String recommendedLessonTitle;
  final String recommendedMissionTitle;
  final int recommendedDurationDays;
  final String recommendationSummary;
  final String whyThisLesson;
  final String whyThisMission;
  final String whyThisDuration;
  final String nextAction;
  final String reviewQuestion;
  final String source;
  final String raw;

  const YangmingGrowthNavigatorResult({
    required this.recommendedLessonId,
    required this.recommendedLessonTitle,
    required this.recommendedMissionTitle,
    required this.recommendedDurationDays,
    required this.recommendationSummary,
    required this.whyThisLesson,
    required this.whyThisMission,
    required this.whyThisDuration,
    required this.nextAction,
    required this.reviewQuestion,
    required this.source,
    required this.raw,
  });


  Map<String, dynamic> toJson() => <String, dynamic>{
        'recommended_lesson_id': recommendedLessonId,
        'recommended_lesson_title': recommendedLessonTitle,
        'recommended_mission_title': recommendedMissionTitle,
        'recommended_duration_days': recommendedDurationDays,
        'recommendation_summary': recommendationSummary,
        'why_this_lesson': whyThisLesson,
        'why_this_mission': whyThisMission,
        'why_this_duration': whyThisDuration,
        'next_action': nextAction,
        'review_question': reviewQuestion,
        'source': source,
        'raw': raw,
      };

  factory YangmingGrowthNavigatorResult.fromMap(Map<String, dynamic> map, {String raw = '', String source = 'ai'}) => YangmingGrowthNavigatorResult(
        recommendedLessonId: (map['recommended_lesson_id'] ?? map['recommendedLessonId'] ?? '').toString(),
        recommendedLessonTitle: (map['recommended_lesson_title'] ?? map['recommendedLessonTitle'] ?? '').toString(),
        recommendedMissionTitle: (map['recommended_mission_title'] ?? map['recommendedMissionTitle'] ?? '').toString(),
        recommendedDurationDays: int.tryParse((map['recommended_duration_days'] ?? map['recommendedDurationDays'] ?? '3').toString()) ?? 3,
        recommendationSummary: (map['recommendation_summary'] ?? map['recommendationSummary'] ?? '').toString(),
        whyThisLesson: (map['why_this_lesson'] ?? map['whyThisLesson'] ?? '').toString(),
        whyThisMission: (map['why_this_mission'] ?? map['whyThisMission'] ?? '').toString(),
        whyThisDuration: (map['why_this_duration'] ?? map['whyThisDuration'] ?? '').toString(),
        nextAction: (map['next_action'] ?? map['nextAction'] ?? '').toString(),
        reviewQuestion: (map['review_question'] ?? map['reviewQuestion'] ?? '').toString(),
        source: source,
        raw: raw,
      );

  factory YangmingGrowthNavigatorResult.fallback({
    required YangmingLesson lesson,
    required int durationDays,
    required String summary,
    required String whyLesson,
    required String whyMission,
    required String whyDuration,
    required String nextAction,
    required String reviewQuestion,
    String source = 'heuristic',
  }) => YangmingGrowthNavigatorResult(
        recommendedLessonId: lesson.id,
        recommendedLessonTitle: lesson.title,
        recommendedMissionTitle: lesson.missionTitle,
        recommendedDurationDays: durationDays,
        recommendationSummary: summary,
        whyThisLesson: whyLesson,
        whyThisMission: whyMission,
        whyThisDuration: whyDuration,
        nextAction: nextAction,
        reviewQuestion: reviewQuestion,
        source: source,
  
      raw: source,
      );
}

class YangmingDailyCockpitResult {
  final String headline;
  final String todayFocus;
  final String todayAction;
  final String trainingPrompt;
  final String reflectionQuestion;
  final String recommendedLessonId;
  final String recommendedLessonTitle;
  final String recommendedMissionTitle;
  final String linkedPlanId;
  final String linkedPlanTheme;
  final String source;
  final String raw;

  const YangmingDailyCockpitResult({
    required this.headline,
    required this.todayFocus,
    required this.todayAction,
    required this.trainingPrompt,
    required this.reflectionQuestion,
    required this.recommendedLessonId,
    required this.recommendedLessonTitle,
    required this.recommendedMissionTitle,
    required this.linkedPlanId,
    required this.linkedPlanTheme,
    required this.source,
    required this.raw,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'headline': headline,
        'today_focus': todayFocus,
        'today_action': todayAction,
        'training_prompt': trainingPrompt,
        'reflection_question': reflectionQuestion,
        'recommended_lesson_id': recommendedLessonId,
        'recommended_lesson_title': recommendedLessonTitle,
        'recommended_mission_title': recommendedMissionTitle,
        'linked_plan_id': linkedPlanId,
        'linked_plan_theme': linkedPlanTheme,
        'source': source,
        'raw': raw,
      };

  factory YangmingDailyCockpitResult.fromMap(Map<String, dynamic> map, {String raw = '', String source = 'ai'}) => YangmingDailyCockpitResult(
        headline: (map['headline'] ?? '').toString(),
        todayFocus: (map['today_focus'] ?? map['todayFocus'] ?? '').toString(),
        todayAction: (map['today_action'] ?? map['todayAction'] ?? '').toString(),
        trainingPrompt: (map['training_prompt'] ?? map['trainingPrompt'] ?? '').toString(),
        reflectionQuestion: (map['reflection_question'] ?? map['reflectionQuestion'] ?? '').toString(),
        recommendedLessonId: (map['recommended_lesson_id'] ?? map['recommendedLessonId'] ?? '').toString(),
        recommendedLessonTitle: (map['recommended_lesson_title'] ?? map['recommendedLessonTitle'] ?? '').toString(),
        recommendedMissionTitle: (map['recommended_mission_title'] ?? map['recommendedMissionTitle'] ?? '').toString(),
        linkedPlanId: (map['linked_plan_id'] ?? map['linkedPlanId'] ?? '').toString(),
        linkedPlanTheme: (map['linked_plan_theme'] ?? map['linkedPlanTheme'] ?? '').toString(),
        source: source,
        raw: raw,
      );

  factory YangmingDailyCockpitResult.fallback({
    required YangmingLesson lesson,
    required String headline,
    required String todayFocus,
    required String todayAction,
    required String trainingPrompt,
    required String reflectionQuestion,
    String linkedPlanId = '',
    String linkedPlanTheme = '',
    String source = 'heuristic',
  }) => YangmingDailyCockpitResult(
        headline: headline,
        todayFocus: todayFocus,
        todayAction: todayAction,
        trainingPrompt: trainingPrompt,
        reflectionQuestion: reflectionQuestion,
        recommendedLessonId: lesson.id,
        recommendedLessonTitle: lesson.title,
        recommendedMissionTitle: lesson.missionTitle,
        linkedPlanId: linkedPlanId,
        linkedPlanTheme: linkedPlanTheme,
        source: source,
        raw: source,
      );
}

class YangmingReviewEntry {
  final String id;
  final String lessonId;
  final String lessonTitle;
  final String fact;
  final String reflection;
  final String aiSummary;
  final String createdAt;

  const YangmingReviewEntry({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.fact,
    required this.reflection,
    required this.aiSummary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'fact': fact,
        'reflection': reflection,
        'aiSummary': aiSummary,
        'createdAt': createdAt,
      };

  factory YangmingReviewEntry.fromJson(Map<String, dynamic> json) => YangmingReviewEntry(
        id: (json['id'] ?? '').toString(),
        lessonId: (json['lessonId'] ?? '').toString(),
        lessonTitle: (json['lessonTitle'] ?? '').toString(),
        fact: (json['fact'] ?? '').toString(),
        reflection: (json['reflection'] ?? '').toString(),
        aiSummary: (json['aiSummary'] ?? '').toString(),
        createdAt: (json['createdAt'] ?? '').toString(),
      );
}

List<Map<String, dynamic>> decodeJsonList(String raw) {
  if (raw.trim().isEmpty) return <Map<String, dynamic>>[];
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
  } catch (_) {}
  return <Map<String, dynamic>>[];
}



class YangmingAdaptiveMissionResult {
  final String branchTag;
  final String personaLens;
  final String trainingFocus;
  final String concernMirror;
  final String missionReminder;
  final YangmingMissionRound? dynamicInnerRound;
  final YangmingMissionRound? dynamicActionRound;
  final String bridgeAction;
  final String reviewQuestion;
  final String raw;

  const YangmingAdaptiveMissionResult({
    required this.branchTag,
    required this.personaLens,
    required this.trainingFocus,
    required this.concernMirror,
    required this.missionReminder,
    required this.dynamicInnerRound,
    required this.dynamicActionRound,
    required this.bridgeAction,
    required this.reviewQuestion,
    required this.raw,
  });

  bool get hasDynamicRounds => dynamicInnerRound != null || dynamicActionRound != null;

  factory YangmingAdaptiveMissionResult.fromMap(Map<String, dynamic> map, {String raw = ''}) {
    YangmingMissionRound? parseRound(dynamic data, String fallbackId) {
      if (data is! Map) return null;
      final source = Map<String, dynamic>.from(data);
      final choiceList = ((source['choices'] ?? const <dynamic>[]) as List)
          .whereType<Map>()
          .map((e) => YangmingMissionChoice.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.id.trim().isNotEmpty && e.label.trim().isNotEmpty)
          .toList();
      if (choiceList.isEmpty) return null;
      return YangmingMissionRound(
        id: (source['id'] ?? fallbackId).toString(),
        title: (source['title'] ?? '').toString().trim().isEmpty ? 'AI 动态分支' : (source['title'] ?? '').toString(),
        prompt: (source['prompt'] ?? '').toString(),
        choices: choiceList,
        guide: (source['guide'] ?? '').toString(),
      );
    }

    return YangmingAdaptiveMissionResult(
      branchTag: (map['branch_tag'] ?? map['branchTag'] ?? 'AI动态分支').toString(),
      personaLens: (map['persona_lens'] ?? map['personaLens'] ?? '').toString(),
      trainingFocus: (map['training_focus'] ?? map['trainingFocus'] ?? '').toString(),
      concernMirror: (map['concern_mirror'] ?? map['concernMirror'] ?? '').toString(),
      missionReminder: (map['mission_reminder'] ?? map['missionReminder'] ?? '').toString(),
      dynamicInnerRound: parseRound(map['dynamic_inner_round'] ?? map['dynamicInnerRound'], 'round_2_inner_ai'),
      dynamicActionRound: parseRound(map['dynamic_action_round'] ?? map['dynamicActionRound'], 'round_3_action_ai'),
      bridgeAction: (map['bridge_action'] ?? map['bridgeAction'] ?? '').toString(),
      reviewQuestion: (map['review_question'] ?? map['reviewQuestion'] ?? '').toString(),
      raw: raw,
    );
  }

  factory YangmingAdaptiveMissionResult.fallback(YangmingLesson lesson, String concern) => YangmingAdaptiveMissionResult(
        branchTag: 'AI动态分支未生成',
        personaLens: '暂未识别人格倾向',
        trainingFocus: '先完成默认四轮状态机，再从记录中识别你的稳定倾向。',
        concernMirror: concern.trim(),
        missionReminder: '当前回退到默认状态机。你可以继续用这段课的固定四轮来完成训练。',
        dynamicInnerRound: null,
        dynamicActionRound: null,
        bridgeAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '今天先做一个最小动作',
        reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪一刻最能体现这段课程的关键问题？',
        raw: '',
      );
}

class YangmingExplainResult {
  final String coreProblem;
  final List<String> keyPoints;
  final List<String> misunderstandings;
  final String caseAnalysis;
  final String minimalAction;
  final String raw;

  const YangmingExplainResult({
    required this.coreProblem,
    required this.keyPoints,
    required this.misunderstandings,
    required this.caseAnalysis,
    required this.minimalAction,
    required this.raw,
  });

  factory YangmingExplainResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingExplainResult(
        coreProblem: (map['core_problem'] ?? map['coreProblem'] ?? '').toString(),
        keyPoints: ((map['key_points'] ?? map['keyPoints'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        misunderstandings: ((map['misunderstandings'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        caseAnalysis: (map['case_analysis'] ?? map['caseAnalysis'] ?? '').toString(),
        minimalAction: (map['minimal_action'] ?? map['minimalAction'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingExplainResult.fallback(YangmingLesson lesson) => YangmingExplainResult(
        coreProblem: '这段课程要解决的核心问题，是把“知道”真正落实到现实行动，而不是停留在观念或口头层面。',
        keyPoints: <String>[
          '先用课程解释自己当下的现实问题，而不是停留在概念记忆。',
          '把抽象义理压缩到一个可观察的行为场景里。',
          '今天先做一条最小行动，再回来看理解是否更深。',
        ],
        misunderstandings: <String>[
          '以为理解很多就等于已经会做。',
          '以为必须等完全想通后才能开始行动。',
          '以为一次做不到就说明自己不适合这条路。',
        ],
        caseAnalysis: '你可以从“我明明知道该做，但迟迟没做”的一件小事切入，借这段课程观察自己真正卡住的是知行断裂、志不真切，还是行动门槛设置过大。',
        minimalAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '今天先做一个10分钟内可启动的动作。',
        raw: 'fallback',
      );
}

class YangmingActionPlanResult {
  final String problemJudgment;
  final String todayMinimalAction;
  final List<String> weekChain;
  final String recoveryAction;
  final String reviewQuestion;
  final String raw;

  const YangmingActionPlanResult({
    required this.problemJudgment,
    required this.todayMinimalAction,
    required this.weekChain,
    required this.recoveryAction,
    required this.reviewQuestion,
    required this.raw,
  });

  factory YangmingActionPlanResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingActionPlanResult(
        problemJudgment: (map['problem_judgment'] ?? map['problemJudgment'] ?? '').toString(),
        todayMinimalAction: (map['today_minimal_action'] ?? map['todayMinimalAction'] ?? '').toString(),
        weekChain: ((map['week_chain'] ?? map['weekChain'] ?? const []) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(),
        recoveryAction: (map['recovery_action'] ?? map['recoveryAction'] ?? '').toString(),
        reviewQuestion: (map['review_question'] ?? map['reviewQuestion'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingActionPlanResult.fallback(YangmingLesson lesson) => YangmingActionPlanResult(
        problemJudgment: '当前更像是“知道一些，但还没有真正进入现实行动”，也可能夹杂行动门槛过大。',
        todayMinimalAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '今天先启动一个10分钟内可完成的小动作。',
        weekChain: <String>[
          '先把问题改写成一句可观察事实。',
          '把任务拆到今天就能启动的最小动作。',
          '做完后立刻记录前后念头变化。',
          '晚上只复盘一个最关键偏差。',
        ],
        recoveryAction: '如果今天没做成，不要全盘放弃，把动作再缩小一半，改成明天最早时段先做。',
        reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪一刻最能体现知行断裂？',
        raw: 'fallback',
      );
}


class YangmingActionDiagnosisResult {
  final String mainProblemStructure;
  final String likelyBias;
  final String factAdvice;
  final String nextMicroAction;
  final String reviewQuestion;
  final String recommendedLessonId;
  final String recommendedLessonTitle;
  final String raw;

  const YangmingActionDiagnosisResult({
    required this.mainProblemStructure,
    required this.likelyBias,
    required this.factAdvice,
    required this.nextMicroAction,
    required this.reviewQuestion,
    required this.recommendedLessonId,
    required this.recommendedLessonTitle,
    required this.raw,
  });

  factory YangmingActionDiagnosisResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingActionDiagnosisResult(
        mainProblemStructure: (map['main_problem_structure'] ?? map['mainProblemStructure'] ?? '').toString(),
        likelyBias: (map['likely_bias'] ?? map['likelyBias'] ?? '').toString(),
        factAdvice: (map['fact_advice'] ?? map['factAdvice'] ?? '').toString(),
        nextMicroAction: (map['next_micro_action'] ?? map['nextMicroAction'] ?? '').toString(),
        reviewQuestion: (map['review_question'] ?? map['reviewQuestion'] ?? '').toString(),
        recommendedLessonId: (map['recommended_lesson_id'] ?? map['recommendedLessonId'] ?? '').toString(),
        recommendedLessonTitle: (map['recommended_lesson_title'] ?? map['recommendedLessonTitle'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingActionDiagnosisResult.fallback(YangmingLesson lesson, String fact) => YangmingActionDiagnosisResult(
        mainProblemStructure: '当前更像是在现实执行中出现知行断裂：并非完全不懂，而是事实记录不够清楚，导致行动纠偏也不够具体。',
        likelyBias: '常见偏差是把情绪解释当成事实，或者把一次失手放大为整体失败。',
        factAdvice: fact.trim().isEmpty ? '先补事实：发生了什么、和谁有关、你做了什么、结果怎样。' : '先把事实和感受分开，再判断到底卡在起念、行动门槛还是守持中断。',
        nextMicroAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '明天先做一个10分钟内可启动的动作。',
        reviewQuestion: lesson.reviewPrompts.isNotEmpty ? lesson.reviewPrompts.first : '今天哪一刻最能体现知行断裂？',
        recommendedLessonId: lesson.id,
        recommendedLessonTitle: lesson.title,
        raw: 'fallback',
      );
}

class YangmingDiagnosisMatch {
  final String lessonId;
  final String title;
  final String reason;

  const YangmingDiagnosisMatch({required this.lessonId, required this.title, required this.reason});

  factory YangmingDiagnosisMatch.fromMap(Map<String, dynamic> map) => YangmingDiagnosisMatch(
        lessonId: (map['lesson_id'] ?? map['lessonId'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        reason: (map['reason'] ?? '').toString(),
      );
}

class YangmingDiagnosisResult {
  final List<YangmingDiagnosisMatch> topMatches;
  final String mainProblemStructure;
  final String recommendedStartLessonId;
  final String recommendedStartLessonTitle;
  final String raw;

  const YangmingDiagnosisResult({
    required this.topMatches,
    required this.mainProblemStructure,
    required this.recommendedStartLessonId,
    required this.recommendedStartLessonTitle,
    required this.raw,
  });

  factory YangmingDiagnosisResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingDiagnosisResult(
        topMatches: ((map['top_matches'] ?? map['topMatches'] ?? const []) as List)
            .whereType<Map>()
            .map((e) => YangmingDiagnosisMatch.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        mainProblemStructure: (map['main_problem_structure'] ?? map['mainProblemStructure'] ?? '').toString(),
        recommendedStartLessonId: (map['recommended_start_lesson_id'] ?? map['recommendedStartLessonId'] ?? '').toString(),
        recommendedStartLessonTitle: (map['recommended_start_lesson_title'] ?? map['recommendedStartLessonTitle'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingDiagnosisResult.fallback(List<YangmingLesson> lessons) {
    final first = lessons.isNotEmpty ? lessons.first : null;
    return YangmingDiagnosisResult(
      topMatches: first == null
          ? const <YangmingDiagnosisMatch>[]
          : <YangmingDiagnosisMatch>[
              YangmingDiagnosisMatch(lessonId: first.id, title: first.title, reason: '本地模式下先从一段最基础的课程开始，把现实问题压缩为一个可观察动作。'),
            ],
      mainProblemStructure: '当前先按“知而未行或志向不稳”处理，重点不是继续想，而是先做一个最小动作。',
      recommendedStartLessonId: first?.id ?? '',
      recommendedStartLessonTitle: first?.title ?? '',
      raw: 'fallback',
    );
  }
}

class YangmingReviewResult {
  final String mainProblem;
  final String affirmation;
  final String correction;
  final String nextAction;
  final String reminder;
  final String raw;

  const YangmingReviewResult({
    required this.mainProblem,
    required this.affirmation,
    required this.correction,
    required this.nextAction,
    required this.reminder,
    required this.raw,
  });

  factory YangmingReviewResult.fromMap(Map<String, dynamic> map, {String raw = ''}) => YangmingReviewResult(
        mainProblem: (map['main_problem'] ?? map['mainProblem'] ?? '').toString(),
        affirmation: (map['affirmation'] ?? '').toString(),
        correction: (map['correction'] ?? '').toString(),
        nextAction: (map['next_action'] ?? map['nextAction'] ?? '').toString(),
        reminder: (map['reminder'] ?? '').toString(),
        raw: raw,
      );

  factory YangmingReviewResult.fallback(YangmingLesson lesson) => YangmingReviewResult(
        mainProblem: '这次最主要的问题，通常不在你懂得不够，而在于现实动作启动太慢，或起念之后没有及时调整。',
        affirmation: '你已经开始记录事实并愿意复盘，这本身就是把课程落到生活里的关键一步。',
        correction: '下一步要更聚焦：不要同时修很多点，只抓一个最关键偏差。',
        nextAction: lesson.actionPlans.isNotEmpty ? lesson.actionPlans.first : '明天先做一个10分钟内可启动的动作。',
        reminder: '先事实，后评判；先动作，后求完美。',
        raw: 'fallback',
      );
}


List<YangmingLessonContent> parseImportedLessonContents(String raw, Set<String> validLessonIds) {
  if (raw.trim().isEmpty) return <YangmingLessonContent>[];
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return <YangmingLessonContent>[];
  }

  final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
  if (decoded is List) {
    for (final dynamic item in decoded) {
      if (item is Map) entries.add(Map<String, dynamic>.from(item));
    }
  } else if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    if (map['lessons'] is List) {
      for (final dynamic item in map['lessons'] as List) {
        if (item is Map) entries.add(Map<String, dynamic>.from(item));
      }
    } else if ((map['lessonId'] ?? map['lesson_id'] ?? map['id']) != null) {
      entries.add(map);
    } else {
      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (!validLessonIds.contains(entry.key)) continue;
        if (entry.value is Map) {
          final item = Map<String, dynamic>.from(entry.value as Map);
          item['lessonId'] = entry.key;
          entries.add(item);
        }
      }
    }
  }

  final List<YangmingLessonContent> result = <YangmingLessonContent>[];
  for (final Map<String, dynamic> item in entries) {
    final content = YangmingLessonContent.fromJson(item);
    if (!validLessonIds.contains(content.lessonId)) continue;
    if (!content.hasAnyContent) continue;
    result.add(content.copyWith(updatedAt: content.updatedAt.isEmpty ? DateTime.now().toIso8601String() : content.updatedAt));
  }
  return result;
}
