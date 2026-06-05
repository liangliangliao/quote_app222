import 'dart:convert';



class GoalCourseProgress {
  final String sourceCourse;
  final String sourceCourseName;
  final int totalCount;
  final int reviewedCount;
  final int favoriteCount;
  final int difficultCount;
  final int keyCount;

  const GoalCourseProgress({
    required this.sourceCourse,
    required this.sourceCourseName,
    required this.totalCount,
    required this.reviewedCount,
    required this.favoriteCount,
    required this.difficultCount,
    required this.keyCount,
  });

  double get completionRate => totalCount == 0 ? 0 : reviewedCount / totalCount;
}

class GoalModuleProgress {
  final String moduleGroup;
  final String sourceCourse;
  final int totalCount;
  final int reviewedCount;
  final int favoriteCount;
  final int difficultCount;
  final int keyCount;

  const GoalModuleProgress({
    required this.moduleGroup,
    required this.sourceCourse,
    required this.totalCount,
    required this.reviewedCount,
    required this.favoriteCount,
    required this.difficultCount,
    required this.keyCount,
  });

  double get completionRate => totalCount == 0 ? 0 : reviewedCount / totalCount;
}

class GoalCompletionRitualState {
  final String ritualKey;
  final int shownAtMs;

  const GoalCompletionRitualState({
    required this.ritualKey,
    required this.shownAtMs,
  });

  const GoalCompletionRitualState.empty(this.ritualKey) : shownAtMs = 0;

  Map<String, Object?> toRow() => {
        'ritual_key': ritualKey,
        'shown_at_ms': shownAtMs,
      };

  static GoalCompletionRitualState fromRow(Map<String, Object?> r) => GoalCompletionRitualState(
        ritualKey: (r['ritual_key'] ?? '').toString(),
        shownAtMs: (r['shown_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalCompletionRitual {
  final String ritualKey;
  final String sourceCourse;
  final String sourceCourseName;
  final String moduleGroup;
  final int totalCount;
  final int reviewedCount;
  final String summaryTitle;
  final String summaryText;
  final String nextTitle;
  final String nextSubtitle;
  final String? nextSegmentId;
  final String? nextConceptId;

  const GoalCompletionRitual({
    required this.ritualKey,
    required this.sourceCourse,
    required this.sourceCourseName,
    required this.moduleGroup,
    required this.totalCount,
    required this.reviewedCount,
    required this.summaryTitle,
    required this.summaryText,
    required this.nextTitle,
    required this.nextSubtitle,
    this.nextSegmentId,
    this.nextConceptId,
  });

  double get completionRate => totalCount == 0 ? 0 : reviewedCount / totalCount;
}



class GoalModuleReflection {
  final String ritualKey;
  final String sourceCourse;
  final String moduleGroup;
  final String summaryText;
  final String insightText;
  final String actionText;
  final int updatedAtMs;

  const GoalModuleReflection({
    required this.ritualKey,
    required this.sourceCourse,
    required this.moduleGroup,
    required this.summaryText,
    required this.insightText,
    required this.actionText,
    required this.updatedAtMs,
  });

  const GoalModuleReflection.empty({
    required this.ritualKey,
    required this.sourceCourse,
    required this.moduleGroup,
  })  : summaryText = '',
        insightText = '',
        actionText = '',
        updatedAtMs = 0;

  bool get hasContent => summaryText.trim().isNotEmpty || insightText.trim().isNotEmpty || actionText.trim().isNotEmpty;

  Map<String, Object?> toRow() => {
        'ritual_key': ritualKey,
        'source_course': sourceCourse,
        'module_group': moduleGroup,
        'summary_text': summaryText,
        'insight_text': insightText,
        'action_text': actionText,
        'updated_at_ms': updatedAtMs,
      };

  static GoalModuleReflection fromRow(Map<String, Object?> r) => GoalModuleReflection(
        ritualKey: (r['ritual_key'] ?? '').toString(),
        sourceCourse: (r['source_course'] ?? '').toString(),
        moduleGroup: (r['module_group'] ?? '').toString(),
        summaryText: (r['summary_text'] ?? '').toString(),
        insightText: (r['insight_text'] ?? '').toString(),
        actionText: (r['action_text'] ?? '').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}



class GoalModuleReviewProgress {
  final String ritualKey;
  final String sourceCourse;
  final String sourceCourseName;
  final String moduleGroup;
  final int totalSegments;
  final int reviewedSegments;
  final bool hasReflection;
  final bool hasActionStep;
  final int actionCount;
  final int followupCount;
  final int updatedAtMs;

  const GoalModuleReviewProgress({
    required this.ritualKey,
    required this.sourceCourse,
    required this.sourceCourseName,
    required this.moduleGroup,
    required this.totalSegments,
    required this.reviewedSegments,
    required this.hasReflection,
    required this.hasActionStep,
    required this.actionCount,
    required this.followupCount,
    required this.updatedAtMs,
  });

  double get completionRate => totalSegments == 0 ? 0 : reviewedSegments / totalSegments;
  bool get enteredActionLoop => actionCount > 0;
  bool get enteredFollowupLoop => followupCount > 0;
}

class GoalCourseSegment {
  final String segmentId;
  final int segmentNo;
  final String sourceCourse;
  final String sourceCourseName;
  final String sectionTitle;
  final String segmentText;
  final String moduleGroup;
  final String tagsJson;
  final int isLocked;

  GoalCourseSegment({
    required this.segmentId,
    required this.segmentNo,
    required this.sourceCourse,
    required this.sourceCourseName,
    required this.sectionTitle,
    required this.segmentText,
    required this.moduleGroup,
    required this.tagsJson,
    this.isLocked = 1,
  });

  List<String> get tags {
    try {
      final v = json.decode(tagsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Map<String, Object?> toRow() => {
        'segment_id': segmentId,
        'segment_no': segmentNo,
        'source_course': sourceCourse,
        'source_course_name': sourceCourseName,
        'section_title': sectionTitle,
        'segment_text': segmentText,
        'module_group': moduleGroup,
        'tags_json': tagsJson,
        'is_locked': isLocked,
      };

  static GoalCourseSegment fromRow(Map<String, Object?> r) => GoalCourseSegment(
        segmentId: (r['segment_id'] ?? '').toString(),
        segmentNo: (r['segment_no'] as num?)?.toInt() ?? 0,
        sourceCourse: (r['source_course'] ?? '').toString(),
        sourceCourseName: (r['source_course_name'] ?? '').toString(),
        sectionTitle: (r['section_title'] ?? '').toString(),
        segmentText: (r['segment_text'] ?? '').toString(),
        moduleGroup: (r['module_group'] ?? '').toString(),
        tagsJson: (r['tags_json'] ?? '[]').toString(),
        isLocked: (r['is_locked'] as num?)?.toInt() ?? 1,
      );
}

class GoalSegmentReview {
  final String segmentId;
  final int reviewedAtMs;
  final bool isFavorited;
  final bool isDifficult;
  final bool isKey;

  const GoalSegmentReview({
    required this.segmentId,
    required this.reviewedAtMs,
    required this.isFavorited,
    required this.isDifficult,
    required this.isKey,
  });

  const GoalSegmentReview.empty(this.segmentId)
      : reviewedAtMs = 0,
        isFavorited = false,
        isDifficult = false,
        isKey = false;

  static GoalSegmentReview fromRow(Map<String, Object?> r) => GoalSegmentReview(
        segmentId: (r['segment_id'] ?? '').toString(),
        reviewedAtMs: (r['reviewed_at_ms'] as num?)?.toInt() ?? 0,
        isFavorited: ((r['is_favorited'] as num?)?.toInt() ?? 0) == 1,
        isDifficult: ((r['is_difficult'] as num?)?.toInt() ?? 0) == 1,
        isKey: ((r['is_key'] as num?)?.toInt() ?? 0) == 1,
      );
}

class GoalReviewedSegment {
  final GoalCourseSegment segment;
  final GoalSegmentReview review;

  GoalReviewedSegment({required this.segment, required this.review});
}

class GoalConceptCard {
  final String conceptId;
  final String segmentId;
  final String conceptTitle;
  final String oneLineDefinition;
  final String whatIsIt;
  final String whyItMatters;
  final String interactionType;
  final String interactionDescription;
  final String reflectionJson;

  GoalConceptCard({
    required this.conceptId,
    required this.segmentId,
    required this.conceptTitle,
    required this.oneLineDefinition,
    required this.whatIsIt,
    required this.whyItMatters,
    required this.interactionType,
    required this.interactionDescription,
    required this.reflectionJson,
  });

  List<String> get reflections {
    try {
      final v = json.decode(reflectionJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Map<String, Object?> toRow() => {
        'concept_id': conceptId,
        'segment_id': segmentId,
        'concept_title': conceptTitle,
        'one_line_definition': oneLineDefinition,
        'what_is_it': whatIsIt,
        'why_it_matters': whyItMatters,
        'interaction_type': interactionType,
        'interaction_description': interactionDescription,
        'reflection_json': reflectionJson,
      };

  static GoalConceptCard fromRow(Map<String, Object?> r) => GoalConceptCard(
        conceptId: (r['concept_id'] ?? '').toString(),
        segmentId: (r['segment_id'] ?? '').toString(),
        conceptTitle: (r['concept_title'] ?? '').toString(),
        oneLineDefinition: (r['one_line_definition'] ?? '').toString(),
        whatIsIt: (r['what_is_it'] ?? '').toString(),
        whyItMatters: (r['why_it_matters'] ?? '').toString(),
        interactionType: (r['interaction_type'] ?? '').toString(),
        interactionDescription: (r['interaction_description'] ?? '').toString(),
        reflectionJson: (r['reflection_json'] ?? '[]').toString(),
      );
}


class GoalConceptProgressStats {
  final String conceptId;
  final int actionCount;
  final double avgCompletionRate;
  final int followupCount;
  final int continueCount;
  final int adjustCount;
  final int releaseCount;
  final int lastCompletedAtMs;

  const GoalConceptProgressStats({
    required this.conceptId,
    required this.actionCount,
    required this.avgCompletionRate,
    required this.followupCount,
    required this.continueCount,
    required this.adjustCount,
    required this.releaseCount,
    required this.lastCompletedAtMs,
  });

  const GoalConceptProgressStats.empty(this.conceptId)
      : actionCount = 0,
        avgCompletionRate = 0,
        followupCount = 0,
        continueCount = 0,
        adjustCount = 0,
        releaseCount = 0,
        lastCompletedAtMs = 0;

  int get avgCompletionPercent => (avgCompletionRate * 100).round();
  bool get hasData => actionCount > 0 || followupCount > 0;
}

class GoalActionTemplate {
  final String actionId;
  final String segmentId;
  final String conceptId;
  final String actionTitle;
  final String actionLevel;
  final String goalOfAction;
  final String stepsJson;
  final int durationMin;
  final String failurePlan;
  final String feedbackJson;

  GoalActionTemplate({
    required this.actionId,
    required this.segmentId,
    required this.conceptId,
    required this.actionTitle,
    required this.actionLevel,
    required this.goalOfAction,
    required this.stepsJson,
    required this.durationMin,
    required this.failurePlan,
    required this.feedbackJson,
  });

  List<String> get steps {
    try {
      final v = json.decode(stepsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  List<String> get feedbackFields {
    try {
      final v = json.decode(feedbackJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Map<String, Object?> toRow() => {
        'action_id': actionId,
        'segment_id': segmentId,
        'concept_id': conceptId,
        'action_title': actionTitle,
        'action_level': actionLevel,
        'goal_of_action': goalOfAction,
        'steps_json': stepsJson,
        'duration_min': durationMin,
        'failure_plan': failurePlan,
        'feedback_json': feedbackJson,
      };

  static GoalActionTemplate fromRow(Map<String, Object?> r) => GoalActionTemplate(
        actionId: (r['action_id'] ?? '').toString(),
        segmentId: (r['segment_id'] ?? '').toString(),
        conceptId: (r['concept_id'] ?? '').toString(),
        actionTitle: (r['action_title'] ?? '').toString(),
        actionLevel: (r['action_level'] ?? '').toString(),
        goalOfAction: (r['goal_of_action'] ?? '').toString(),
        stepsJson: (r['steps_json'] ?? '[]').toString(),
        durationMin: (r['duration_min'] as num?)?.toInt() ?? 0,
        failurePlan: (r['failure_plan'] ?? '').toString(),
        feedbackJson: (r['feedback_json'] ?? '[]').toString(),
      );
}


class GoalSceneActionSuggestion {
  final GoalActionTemplate action;
  final String conceptTitle;
  final String segmentTitle;
  final String sceneReason;

  GoalSceneActionSuggestion({
    required this.action,
    required this.conceptTitle,
    required this.segmentTitle,
    required this.sceneReason,
  });
}

class GoalActionRecord {
  final int id;
  final String actionId;
  final String conceptId;
  final String segmentId;
  final int startedAtMs;
  final int completedAtMs;
  final double completionRate;
  final String feedbackJson;
  final String reflectionText;

  GoalActionRecord({
    required this.id,
    required this.actionId,
    required this.conceptId,
    required this.segmentId,
    required this.startedAtMs,
    required this.completedAtMs,
    required this.completionRate,
    required this.feedbackJson,
    required this.reflectionText,
  });

  Map<String, String> get feedbackMap {
    try {
      final v = json.decode(feedbackJson);
      if (v is Map) {
        return v.map((key, value) => MapEntry(key.toString(), (value ?? '').toString()));
      }
    } catch (_) {}
    return const {};
  }

  static GoalActionRecord fromRow(Map<String, Object?> r) => GoalActionRecord(
        id: (r['id'] as num?)?.toInt() ?? 0,
        actionId: (r['action_id'] ?? '').toString(),
        conceptId: (r['concept_id'] ?? '').toString(),
        segmentId: (r['segment_id'] ?? '').toString(),
        startedAtMs: (r['started_at_ms'] as num?)?.toInt() ?? 0,
        completedAtMs: (r['completed_at_ms'] as num?)?.toInt() ?? 0,
        completionRate: (r['completion_rate'] as num?)?.toDouble() ?? 0,
        feedbackJson: (r['feedback_json'] ?? '{}').toString(),
        reflectionText: (r['reflection_text'] ?? '').toString(),
      );
}

class GoalActionRecordView {
  final GoalActionRecord record;
  final String actionTitle;
  final String conceptTitle;
  final String segmentTitle;
  final String followupDecision;
  final int followupUpdatedAtMs;

  GoalActionRecordView({
    required this.record,
    required this.actionTitle,
    required this.conceptTitle,
    required this.segmentTitle,
    this.followupDecision = '',
    this.followupUpdatedAtMs = 0,
  });

  bool get hasFollowup => followupDecision.trim().isNotEmpty;
}

class GoalActionFollowup {
  final int actionRecordId;
  final String decision;
  final String reflectionText;
  final String nextStep;
  final String weeklyFocus;
  final int updatedAtMs;

  const GoalActionFollowup({
    required this.actionRecordId,
    required this.decision,
    required this.reflectionText,
    required this.nextStep,
    required this.weeklyFocus,
    required this.updatedAtMs,
  });

  const GoalActionFollowup.empty(this.actionRecordId)
      : decision = '',
        reflectionText = '',
        nextStep = '',
        weeklyFocus = '',
        updatedAtMs = 0;

  bool get hasContent =>
      decision.trim().isNotEmpty ||
      reflectionText.trim().isNotEmpty ||
      nextStep.trim().isNotEmpty ||
      weeklyFocus.trim().isNotEmpty;

  Map<String, Object?> toRow() => {
        'action_record_id': actionRecordId,
        'decision': decision,
        'reflection_text': reflectionText,
        'next_step': nextStep,
        'weekly_focus': weeklyFocus,
        'updated_at_ms': updatedAtMs,
      };

  static GoalActionFollowup fromRow(Map<String, Object?> r) => GoalActionFollowup(
        actionRecordId: (r['action_record_id'] as num?)?.toInt() ?? 0,
        decision: (r['decision'] ?? '').toString(),
        reflectionText: (r['reflection_text'] ?? '').toString(),
        nextStep: (r['next_step'] ?? '').toString(),
        weeklyFocus: (r['weekly_focus'] ?? '').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalActionRecordBundle {
  final GoalActionRecordView view;
  final GoalActionFollowup followup;

  GoalActionRecordBundle({required this.view, required this.followup});
}

class GoalWorkshopActionOverview {
  final GoalActionRecordView? latestAction;
  final GoalActionRecordView? pendingAction;

  const GoalWorkshopActionOverview({
    required this.latestAction,
    required this.pendingAction,
  });

  bool get hasAny => latestAction != null || pendingAction != null;
}

class GoalModuleReviewActionOverview {
  final GoalActionRecordView? latestAction;
  final GoalActionRecordView? pendingAction;

  const GoalModuleReviewActionOverview({
    required this.latestAction,
    required this.pendingAction,
  });

  bool get hasAny => latestAction != null || pendingAction != null;
}

class GoalWorkshopDraft {
  final String identityStatement;
  final String vision;
  final String whyText;
  final String realityProblem;
  final String externalExpectation;
  final String competingGoal;
  final String lifeline;
  final double stretchScore;
  final String weeklyGoal;
  final String firstStep;
  final String ifThenText;
  final int updatedAtMs;

  GoalWorkshopDraft({
    required this.identityStatement,
    required this.vision,
    required this.whyText,
    required this.realityProblem,
    required this.externalExpectation,
    required this.competingGoal,
    required this.lifeline,
    required this.stretchScore,
    required this.weeklyGoal,
    required this.firstStep,
    required this.ifThenText,
    required this.updatedAtMs,
  });

  factory GoalWorkshopDraft.empty() => GoalWorkshopDraft(
        identityStatement: '',
        vision: '',
        whyText: '',
        realityProblem: '',
        externalExpectation: '',
        competingGoal: '',
        lifeline: '',
        stretchScore: 5,
        weeklyGoal: '',
        firstStep: '',
        ifThenText: '',
        updatedAtMs: 0,
      );

  double get completionRate {
    final fields = [
      identityStatement,
      vision,
      whyText,
      realityProblem,
      externalExpectation,
      competingGoal,
      lifeline,
      weeklyGoal,
      firstStep,
      ifThenText,
    ];
    final filled = fields.where((e) => e.trim().isNotEmpty).length;
    return filled / fields.length;
  }

  int get consistencyScore {
    double score = 0;
    if (vision.trim().isNotEmpty) score += 18;
    if (whyText.trim().isNotEmpty) score += 14;
    if (lifeline.trim().isNotEmpty) score += 10;
    if (weeklyGoal.trim().isNotEmpty) score += 14;
    if (firstStep.trim().isNotEmpty) score += 14;
    if (ifThenText.trim().isNotEmpty) score += 12;
    if (identityStatement.trim().isNotEmpty) score += 6;
    if (realityProblem.trim().isNotEmpty) score += 4;
    if (externalExpectation.trim().isNotEmpty) score += 4;
    if (competingGoal.trim().isNotEmpty) score += 4;
    score += (stretchScore >= 4 && stretchScore <= 8) ? 10 : 4;
    return score.round().clamp(0, 100) as int;
  }

  int _keywordHits(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    var count = 0;
    for (final keyword in keywords) {
      final k = keyword.toLowerCase();
      if (k.isNotEmpty && lower.contains(k)) count += 1;
    }
    return count;
  }

    String get _pressureText => [vision, whyText, externalExpectation, realityProblem].join('\n');
  String get _conflictText => [competingGoal, realityProblem, weeklyGoal, firstStep].join('\n');

int get externalPressureScore {
    final explicit = externalExpectation.trim().isNotEmpty ? 28 : 0;
    final hits = _keywordHits(_pressureText, const [
      '应该', '别人', '父母', '家人', '同学', '社会', '稳定', '体面', '证明', '不能输', '期待', '面子', '比较', '必须',
    ]);
    return ((explicit + hits * 8).clamp(0, 100) as num).toInt();
  }

  int get conflictScore {
    final explicit = competingGoal.trim().isNotEmpty ? 30 : 0;
    final hits = _keywordHits(_conflictText, const [
      '同时', '兼顾', '冲突', '时间不够', '精力', '家庭', '工作', '学习', '健康', '赚钱', '考研', '带娃', '副业',
    ]);
    final stretchPenalty = stretchScore >= 8.5 ? 8 : 0;
    return ((explicit + hits * 7 + stretchPenalty).clamp(0, 100) as num).toInt();
  }

  int get stretchRiskScore {
    if (stretchScore <= 2.5) return 28;
    if (stretchScore >= 9) return 45;
    if (stretchScore >= 8) return 28;
    return 6;
  }

  int get alignmentScore {
    final riskPenalty = (externalPressureScore * 0.30) + (conflictScore * 0.30) + (stretchRiskScore * 0.18);
    final score = consistencyScore - riskPenalty.round();
    return (score.clamp(0, 100) as num).toInt();
  }

  String get alignmentLevel {
    if (alignmentScore >= 80) return '高一致';
    if (alignmentScore >= 60) return '中等一致';
    return '需要校准';
  }

  List<String> get detectedRisks {
    final risks = <String>[];
    if (externalPressureScore >= 40) risks.add('外界期待偏强');
    if (conflictScore >= 40) risks.add('存在竞争性目标');
    if (stretchScore <= 2.5) risks.add('目标拉力偏低');
    if (stretchScore >= 8.5) risks.add('目标拉力偏高');
    if (whyText.trim().isEmpty) risks.add('why 还不够清晰');
    if (firstStep.trim().isEmpty) risks.add('缺少可执行的第一步');
    return risks;
  }

  List<String> get adjustmentSuggestions {
    final suggestions = <String>[];
    if (externalPressureScore >= 40) {
      suggestions.add('把“外界期待我做什么”和“我真正想追求什么”分开写，先不要混在一个目标里。');
    }
    if (competingGoal.trim().isNotEmpty || conflictScore >= 40) {
      suggestions.add('把竞争性目标拆出来，明确本周只能优先推进哪一条，避免同时拉扯。');
    }
    if (stretchScore <= 2.5) {
      suggestions.add('当前目标可能太安全，试着把本周推进提高半级，让它更能点燃你。');
    } else if (stretchScore >= 8.5) {
      suggestions.add('当前目标可能太压人，建议把它拆成更小台阶，再写进本周推进和 if-then。');
    }
    if (whyText.trim().isEmpty) {
      suggestions.add('先补上 why：如果这个目标做成了，它会让你更像什么样的人？');
    }
    if (firstStep.trim().isEmpty) {
      suggestions.add('补一条“明天第一步”，把目标从想法拉回日程表。');
    }
    if (suggestions.isEmpty) {
      suggestions.add('当前目标结构比较稳，接下来更适合持续执行与复盘。');
    }
    return suggestions;
  }

  Map<String, Object?> toRow() => {
        'id': 1,
        'identity_statement': identityStatement,
        'vision': vision,
        'why_text': whyText,
        'reality_problem': realityProblem,
        'external_expectation': externalExpectation,
        'competing_goal': competingGoal,
        'lifeline': lifeline,
        'stretch_score': stretchScore,
        'weekly_goal': weeklyGoal,
        'first_step': firstStep,
        'if_then_text': ifThenText,
        'updated_at_ms': updatedAtMs,
      };

  static GoalWorkshopDraft fromRow(Map<String, Object?> r) => GoalWorkshopDraft(
        identityStatement: (r['identity_statement'] ?? '').toString(),
        vision: (r['vision'] ?? '').toString(),
        whyText: (r['why_text'] ?? '').toString(),
        realityProblem: (r['reality_problem'] ?? '').toString(),
        externalExpectation: (r['external_expectation'] ?? '').toString(),
        competingGoal: (r['competing_goal'] ?? '').toString(),
        lifeline: (r['lifeline'] ?? '').toString(),
        stretchScore: (r['stretch_score'] as num?)?.toDouble() ?? 5,
        weeklyGoal: (r['weekly_goal'] ?? '').toString(),
        firstStep: (r['first_step'] ?? '').toString(),
        ifThenText: (r['if_then_text'] ?? '').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}



class GoalWorldProfile {
  final String roleTitle;
  final String lifeArea;
  final String realEvent;
  final String currentFeeling;
  final String desiredIdentity;
  final int updatedAtMs;

  const GoalWorldProfile({
    required this.roleTitle,
    required this.lifeArea,
    required this.realEvent,
    required this.currentFeeling,
    required this.desiredIdentity,
    required this.updatedAtMs,
  });

  factory GoalWorldProfile.empty() => const GoalWorldProfile(
        roleTitle: '',
        lifeArea: '',
        realEvent: '',
        currentFeeling: '',
        desiredIdentity: '',
        updatedAtMs: 0,
      );

  bool get hasContent =>
      roleTitle.trim().isNotEmpty ||
      lifeArea.trim().isNotEmpty ||
      realEvent.trim().isNotEmpty ||
      currentFeeling.trim().isNotEmpty ||
      desiredIdentity.trim().isNotEmpty;

  double get completionRate {
    final fields = [roleTitle, lifeArea, realEvent, currentFeeling, desiredIdentity];
    final filled = fields.where((e) => e.trim().isNotEmpty).length;
    return filled / fields.length;
  }

  String get profileTitle => roleTitle.trim().isEmpty ? '未设定世界身份' : roleTitle.trim();

  String get summaryLine {
    final parts = <String>[];
    if (lifeArea.trim().isNotEmpty) parts.add(lifeArea.trim());
    if (currentFeeling.trim().isNotEmpty) parts.add(currentFeeling.trim());
    if (desiredIdentity.trim().isNotEmpty) parts.add('想练习成：${desiredIdentity.trim()}');
    return parts.join(' · ');
  }

  Map<String, Object?> toRow() => {
        'id': 1,
        'role_title': roleTitle,
        'life_area': lifeArea,
        'real_event': realEvent,
        'current_feeling': currentFeeling,
        'desired_identity': desiredIdentity,
        'updated_at_ms': updatedAtMs,
      };

  static GoalWorldProfile fromRow(Map<String, Object?> r) => GoalWorldProfile(
        roleTitle: (r['role_title'] ?? '').toString(),
        lifeArea: (r['life_area'] ?? '').toString(),
        realEvent: (r['real_event'] ?? '').toString(),
        currentFeeling: (r['current_feeling'] ?? '').toString(),
        desiredIdentity: (r['desired_identity'] ?? '').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalWorldSceneProgress {
  final String sceneId;
  final String completedTaskIdsJson;
  final String realityNote;
  final bool rewardClaimed;
  final String activeTaskId;
  final int rewardClaimedAtMs;
  final String simulationChoiceId;
  final String simulationReflection;
  final String branchCompletedTaskIdsJson;
  final String activeBranchTaskId;
  final int updatedAtMs;

  const GoalWorldSceneProgress({
    required this.sceneId,
    required this.completedTaskIdsJson,
    required this.realityNote,
    required this.rewardClaimed,
    required this.activeTaskId,
    required this.rewardClaimedAtMs,
    required this.simulationChoiceId,
    required this.simulationReflection,
    required this.branchCompletedTaskIdsJson,
    required this.activeBranchTaskId,
    required this.updatedAtMs,
  });

  const GoalWorldSceneProgress.empty(this.sceneId)
      : completedTaskIdsJson = '[]',
        realityNote = '',
        rewardClaimed = false,
        activeTaskId = '',
        rewardClaimedAtMs = 0,
        simulationChoiceId = '',
        simulationReflection = '',
        branchCompletedTaskIdsJson = '[]',
        activeBranchTaskId = '',
        updatedAtMs = 0;

  List<String> get completedTaskIds {
    try {
      final v = json.decode(completedTaskIdsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  List<String> get completedBranchTaskIds {
    try {
      final v = json.decode(branchCompletedTaskIdsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Map<String, Object?> toRow() => {
        'scene_id': sceneId,
        'completed_task_ids_json': completedTaskIdsJson,
        'reality_note': realityNote,
        'reward_claimed': rewardClaimed ? 1 : 0,
        'active_task_id': activeTaskId,
        'reward_claimed_at_ms': rewardClaimedAtMs,
        'simulation_choice_id': simulationChoiceId,
        'simulation_reflection': simulationReflection,
        'branch_completed_task_ids_json': branchCompletedTaskIdsJson,
        'active_branch_task_id': activeBranchTaskId,
        'updated_at_ms': updatedAtMs,
      };

  static GoalWorldSceneProgress fromRow(Map<String, Object?> r) => GoalWorldSceneProgress(
        sceneId: (r['scene_id'] ?? '').toString(),
        completedTaskIdsJson: (r['completed_task_ids_json'] ?? '[]').toString(),
        realityNote: (r['reality_note'] ?? '').toString(),
        rewardClaimed: ((r['reward_claimed'] as num?)?.toInt() ?? 0) == 1,
        activeTaskId: (r['active_task_id'] ?? '').toString(),
        rewardClaimedAtMs: (r['reward_claimed_at_ms'] as num?)?.toInt() ?? 0,
        simulationChoiceId: (r['simulation_choice_id'] ?? '').toString(),
        simulationReflection: (r['simulation_reflection'] ?? '').toString(),
        branchCompletedTaskIdsJson: (r['branch_completed_task_ids_json'] ?? '[]').toString(),
        activeBranchTaskId: (r['active_branch_task_id'] ?? '').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalWorldTimelineEvent {
  final int id;
  final String sceneId;
  final String eventType;
  final String title;
  final String body;
  final String branchChoiceId;
  final int createdAtMs;

  const GoalWorldTimelineEvent({
    required this.id,
    required this.sceneId,
    required this.eventType,
    required this.title,
    required this.body,
    required this.branchChoiceId,
    required this.createdAtMs,
  });

  const GoalWorldTimelineEvent.empty()
      : id = 0,
        sceneId = '',
        eventType = '',
        title = '',
        body = '',
        branchChoiceId = '',
        createdAtMs = 0;

  static GoalWorldTimelineEvent fromRow(Map<String, Object?> r) => GoalWorldTimelineEvent(
        id: (r['id'] as num?)?.toInt() ?? 0,
        sceneId: (r['scene_id'] ?? '').toString(),
        eventType: (r['event_type'] ?? '').toString(),
        title: (r['title'] ?? '').toString(),
        body: (r['body'] ?? '').toString(),
        branchChoiceId: (r['branch_choice_id'] ?? '').toString(),
        createdAtMs: (r['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalWorldStatusSnapshot {
  final int id;
  final String sourceType;
  final String sourceId;
  final int clarity;
  final int alignment;
  final int momentum;
  final String note;
  final int createdAtMs;

  const GoalWorldStatusSnapshot({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.clarity,
    required this.alignment,
    required this.momentum,
    required this.note,
    required this.createdAtMs,
  });

  static GoalWorldStatusSnapshot fromRow(Map<String, Object?> r) => GoalWorldStatusSnapshot(
        id: (r['id'] as num?)?.toInt() ?? 0,
        sourceType: (r['source_type'] ?? '').toString(),
        sourceId: (r['source_id'] ?? '').toString(),
        clarity: (r['clarity'] as num?)?.toInt() ?? 0,
        alignment: (r['alignment'] as num?)?.toInt() ?? 0,
        momentum: (r['momentum'] as num?)?.toInt() ?? 0,
        note: (r['note'] ?? '').toString(),
        createdAtMs: (r['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalWorldGrowthTrajectory {
  final GoalWorldStatusSnapshot? firstSnapshot;
  final GoalWorldStatusSnapshot? latestSnapshot;
  final List<GoalWorldStatusSnapshot> recentSnapshots;

  const GoalWorldGrowthTrajectory({
    required this.firstSnapshot,
    required this.latestSnapshot,
    required this.recentSnapshots,
  });

  const GoalWorldGrowthTrajectory.empty()
      : firstSnapshot = null,
        latestSnapshot = null,
        recentSnapshots = const <GoalWorldStatusSnapshot>[];

  bool get hasData => latestSnapshot != null;

  int get clarityDelta => hasData && firstSnapshot != null ? latestSnapshot!.clarity - firstSnapshot!.clarity : 0;
  int get alignmentDelta => hasData && firstSnapshot != null ? latestSnapshot!.alignment - firstSnapshot!.alignment : 0;
  int get momentumDelta => hasData && firstSnapshot != null ? latestSnapshot!.momentum - firstSnapshot!.momentum : 0;

  String get headline {
    if (!hasData) return '你的角色成长轨迹会随着真实身份、场景选择和现实行动逐步出现。';
    final total = clarityDelta + alignmentDelta + momentumDelta;
    if (total >= 18) return '你已经明显在把试验场里的练习，变成更稳定的成长轨迹。';
    if (total >= 6) return '你的角色状态正在缓慢抬升，继续把一次次选择带回现实。';
    if (total <= -6) return '最近的练习还没有稳定转成成长，先回到最小而真实的一步。';
    return '你的成长轨迹已经开始出现，关键是保持小步但连续的推进。';
  }
}


class GoalWorldIdentityEvolution {
  final String stageKey;
  final String stageTitle;
  final String stageSubtitle;
  final String headline;
  final String evidenceJson;
  final int updatedAtMs;

  const GoalWorldIdentityEvolution({
    required this.stageKey,
    required this.stageTitle,
    required this.stageSubtitle,
    required this.headline,
    required this.evidenceJson,
    required this.updatedAtMs,
  });

  const GoalWorldIdentityEvolution.empty()
      : stageKey = '',
        stageTitle = '',
        stageSubtitle = '',
        headline = '',
        evidenceJson = '[]',
        updatedAtMs = 0;

  List<String> get evidence {
    try {
      final v = json.decode(evidenceJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  bool get hasContent => stageKey.trim().isNotEmpty || headline.trim().isNotEmpty;

  Map<String, Object?> toRow() => {
        'id': 1,
        'stage_key': stageKey,
        'stage_title': stageTitle,
        'stage_subtitle': stageSubtitle,
        'headline': headline,
        'evidence_json': evidenceJson,
        'updated_at_ms': updatedAtMs,
      };

  static GoalWorldIdentityEvolution fromRow(Map<String, Object?> r) => GoalWorldIdentityEvolution(
        stageKey: (r['stage_key'] ?? '').toString(),
        stageTitle: (r['stage_title'] ?? '').toString(),
        stageSubtitle: (r['stage_subtitle'] ?? '').toString(),
        headline: (r['headline'] ?? '').toString(),
        evidenceJson: (r['evidence_json'] ?? '[]').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalWorldPracticeTimelineSummary {
  final GoalWorldTimelineEvent? latestIdentityShift;
  final GoalWorldStatusSnapshot? previousSnapshot;
  final GoalWorldStatusSnapshot? latestSnapshot;
  final String strongestSceneId;
  final String strongestSceneTitle;
  final String strongestSceneReason;
  final List<GoalWorldTimelineEvent> recentEvents;

  const GoalWorldPracticeTimelineSummary({
    required this.latestIdentityShift,
    required this.previousSnapshot,
    required this.latestSnapshot,
    required this.strongestSceneId,
    required this.strongestSceneTitle,
    required this.strongestSceneReason,
    required this.recentEvents,
  });

  const GoalWorldPracticeTimelineSummary.empty()
      : latestIdentityShift = null,
        previousSnapshot = null,
        latestSnapshot = null,
        strongestSceneId = '',
        strongestSceneTitle = '',
        strongestSceneReason = '',
        recentEvents = const <GoalWorldTimelineEvent>[];

  bool get hasIdentityShift => latestIdentityShift != null;
  bool get hasBeforeAfter => latestSnapshot != null && previousSnapshot != null;
  bool get hasStrongestScene => strongestSceneId.trim().isNotEmpty;

  int get clarityDelta => hasBeforeAfter ? latestSnapshot!.clarity - previousSnapshot!.clarity : 0;
  int get alignmentDelta => hasBeforeAfter ? latestSnapshot!.alignment - previousSnapshot!.alignment : 0;
  int get momentumDelta => hasBeforeAfter ? latestSnapshot!.momentum - previousSnapshot!.momentum : 0;

  String get headline {
    if (hasIdentityShift) {
      return latestIdentityShift!.title;
    }
    if (hasBeforeAfter) {
      return '最近一次练习，正在让你的角色状态发生变化。';
    }
    return '当你持续把场景练习带回现实后，这里会形成一条更清晰的人生练习时间轴。';
  }
}


class GoalWorldRecentIdentityLeapDetail {
  final GoalWorldTimelineEvent? latestShift;
  final GoalWorldStatusSnapshot? beforeSnapshot;
  final GoalWorldStatusSnapshot? afterSnapshot;
  final String strongestSceneId;
  final String strongestSceneTitle;
  final String strongestSceneReason;
  final String headline;
  final List<String> evidence;

  const GoalWorldRecentIdentityLeapDetail({
    required this.latestShift,
    required this.beforeSnapshot,
    required this.afterSnapshot,
    required this.strongestSceneId,
    required this.strongestSceneTitle,
    required this.strongestSceneReason,
    required this.headline,
    required this.evidence,
  });

  const GoalWorldRecentIdentityLeapDetail.empty()
      : latestShift = null,
        beforeSnapshot = null,
        afterSnapshot = null,
        strongestSceneId = '',
        strongestSceneTitle = '',
        strongestSceneReason = '',
        headline = '',
        evidence = const <String>[];

  bool get hasShift => latestShift != null;
  bool get hasBeforeAfter => beforeSnapshot != null && afterSnapshot != null;
  bool get hasStrongestScene => strongestSceneId.trim().isNotEmpty;

  int get clarityDelta => hasBeforeAfter ? afterSnapshot!.clarity - beforeSnapshot!.clarity : 0;
  int get alignmentDelta => hasBeforeAfter ? afterSnapshot!.alignment - beforeSnapshot!.alignment : 0;
  int get momentumDelta => hasBeforeAfter ? afterSnapshot!.momentum - beforeSnapshot!.momentum : 0;
}

class GoalWorldSevenDayTrendPoint {
  final String dateKey;
  final String label;
  final int clarity;
  final int alignment;
  final int momentum;
  final bool hasData;

  const GoalWorldSevenDayTrendPoint({
    required this.dateKey,
    required this.label,
    required this.clarity,
    required this.alignment,
    required this.momentum,
    required this.hasData,
  });

  const GoalWorldSevenDayTrendPoint.empty({required this.dateKey, required this.label})
      : clarity = 0,
        alignment = 0,
        momentum = 0,
        hasData = false;
}
class GoalContinueState {
  final String stateKey;
  final String targetId;
  final double scrollOffset;
  final String extraJson;
  final int updatedAtMs;

  const GoalContinueState({
    required this.stateKey,
    required this.targetId,
    required this.scrollOffset,
    required this.extraJson,
    required this.updatedAtMs,
  });

  const GoalContinueState.empty(this.stateKey)
      : targetId = '',
        scrollOffset = 0,
        extraJson = '{}',
        updatedAtMs = 0;

  Map<String, String> get extraMap {
    try {
      final v = json.decode(extraJson);
      if (v is Map) {
        return v.map((key, value) => MapEntry(key.toString(), (value ?? '').toString()));
      }
    } catch (_) {}
    return const {};
  }

  Map<String, Object?> toRow() => {
        'state_key': stateKey,
        'target_id': targetId,
        'scroll_offset': scrollOffset,
        'extra_json': extraJson,
        'updated_at_ms': updatedAtMs,
      };

  static GoalContinueState fromRow(Map<String, Object?> r) => GoalContinueState(
        stateKey: (r['state_key'] ?? '').toString(),
        targetId: (r['target_id'] ?? '').toString(),
        scrollOffset: (r['scroll_offset'] as num?)?.toDouble() ?? 0,
        extraJson: (r['extra_json'] ?? '{}').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class GoalActionDraft {
  final String actionId;
  final String conceptId;
  final String segmentId;
  final int startedAtMs;
  final String actionTitle;
  final String actionLevel;
  final String goalOfAction;
  final String stepsJson;
  final int durationMin;
  final String failurePlan;
  final String feedbackFieldsJson;
  final String checkedJson;
  final String feedbackValuesJson;
  final String reflectionText;
  final String conceptTitleSnapshot;
  final String segmentTitleSnapshot;
  final int updatedAtMs;

  const GoalActionDraft({
    required this.actionId,
    required this.conceptId,
    required this.segmentId,
    required this.startedAtMs,
    required this.actionTitle,
    required this.actionLevel,
    required this.goalOfAction,
    required this.stepsJson,
    required this.durationMin,
    required this.failurePlan,
    required this.feedbackFieldsJson,
    required this.checkedJson,
    required this.feedbackValuesJson,
    required this.reflectionText,
    required this.conceptTitleSnapshot,
    required this.segmentTitleSnapshot,
    required this.updatedAtMs,
  });

  List<String> get steps {
    try {
      final v = json.decode(stepsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  List<String> get feedbackFields {
    try {
      final v = json.decode(feedbackFieldsJson);
      if (v is List) return v.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  List<bool> get checks {
    try {
      final v = json.decode(checkedJson);
      if (v is List) return v.map((e) => e == true || e.toString() == 'true' || e.toString() == '1').toList();
    } catch (_) {}
    return List<bool>.filled(steps.length, false);
  }

  Map<String, String> get feedbackValues {
    try {
      final v = json.decode(feedbackValuesJson);
      if (v is Map) {
        return v.map((key, value) => MapEntry(key.toString(), (value ?? '').toString()));
      }
    } catch (_) {}
    return const {};
  }

  double get completionRate {
    final total = steps.isEmpty ? 1 : steps.length;
    final done = checks.where((e) => e).length;
    return done / total;
  }

  GoalActionTemplate toTemplate() => GoalActionTemplate(
        actionId: actionId,
        segmentId: segmentId,
        conceptId: conceptId,
        actionTitle: actionTitle,
        actionLevel: actionLevel,
        goalOfAction: goalOfAction,
        stepsJson: stepsJson,
        durationMin: durationMin,
        failurePlan: failurePlan,
        feedbackJson: feedbackFieldsJson,
      );

  Map<String, Object?> toRow() => {
        'action_id': actionId,
        'concept_id': conceptId,
        'segment_id': segmentId,
        'started_at_ms': startedAtMs,
        'action_title': actionTitle,
        'action_level': actionLevel,
        'goal_of_action': goalOfAction,
        'steps_json': stepsJson,
        'duration_min': durationMin,
        'failure_plan': failurePlan,
        'feedback_fields_json': feedbackFieldsJson,
        'checked_json': checkedJson,
        'feedback_values_json': feedbackValuesJson,
        'reflection_text': reflectionText,
        'concept_title_snapshot': conceptTitleSnapshot,
        'segment_title_snapshot': segmentTitleSnapshot,
        'updated_at_ms': updatedAtMs,
      };

  static GoalActionDraft fromRow(Map<String, Object?> r) => GoalActionDraft(
        actionId: (r['action_id'] ?? '').toString(),
        conceptId: (r['concept_id'] ?? '').toString(),
        segmentId: (r['segment_id'] ?? '').toString(),
        startedAtMs: (r['started_at_ms'] as num?)?.toInt() ?? 0,
        actionTitle: (r['action_title'] ?? '').toString(),
        actionLevel: (r['action_level'] ?? '').toString(),
        goalOfAction: (r['goal_of_action'] ?? '').toString(),
        stepsJson: (r['steps_json'] ?? '[]').toString(),
        durationMin: (r['duration_min'] as num?)?.toInt() ?? 0,
        failurePlan: (r['failure_plan'] ?? '').toString(),
        feedbackFieldsJson: (r['feedback_fields_json'] ?? '[]').toString(),
        checkedJson: (r['checked_json'] ?? '[]').toString(),
        feedbackValuesJson: (r['feedback_values_json'] ?? '{}').toString(),
        reflectionText: (r['reflection_text'] ?? '').toString(),
        conceptTitleSnapshot: (r['concept_title_snapshot'] ?? '').toString(),
        segmentTitleSnapshot: (r['segment_title_snapshot'] ?? '').toString(),
        updatedAtMs: (r['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}
