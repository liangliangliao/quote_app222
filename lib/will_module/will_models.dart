class WillModuleSection {
  final String id;
  final String title;
  final String subtitle;
  final int unitCount;
  final List<String> highlights;

  const WillModuleSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unitCount,
    required this.highlights,
  });
}


class WillUnitIndex {
  final String id;
  final String moduleCode;
  final String moduleTitle;
  final String title;
  final String oneLiner;
  final List<String> tags;

  const WillUnitIndex({
    required this.id,
    required this.moduleCode,
    required this.moduleTitle,
    required this.title,
    required this.oneLiner,
    required this.tags,
  });
}


class WillDeepLessonContent {
  final String originalKeyPoint;
  final String coreMeaning;
  final String extension;
  final String realCase;
  final String practiceAction;
  final String ifThen;
  final String mirrorZone;
  final String reviewPrompt;

  const WillDeepLessonContent({
    required this.originalKeyPoint,
    required this.coreMeaning,
    required this.extension,
    required this.realCase,
    required this.practiceAction,
    required this.ifThen,
    required this.mirrorZone,
    required this.reviewPrompt,
  });
}

class WillKnowledgeCard {
  final String id;
  final String sectionId;
  final String label;
  final String title;
  final String oneLiner;
  final String meaning;
  final String realScene;
  final String practicalAction;
  final String reflection;
  final List<String> tags;

  const WillKnowledgeCard({
    required this.id,
    required this.sectionId,
    required this.label,
    required this.title,
    required this.oneLiner,
    required this.meaning,
    required this.realScene,
    required this.practicalAction,
    required this.reflection,
    required this.tags,
  });
}

class WillProblemPath {
  final String title;
  final String summary;
  final List<String> concepts;
  final List<String> actions;
  final List<String> linkedCardIds;

  const WillProblemPath({
    required this.title,
    required this.summary,
    required this.concepts,
    required this.actions,
    required this.linkedCardIds,
  });
}

class WillTaskPlan {
  final String title;
  final String trigger;
  final String action;
  final String feedback;
  final String review;
  final String sampleIf;
  final String sampleThen;
  final List<String> linkedCardIds;

  const WillTaskPlan({
    required this.title,
    required this.trigger,
    required this.action,
    required this.feedback,
    required this.review,
    required this.sampleIf,
    required this.sampleThen,
    required this.linkedCardIds,
  });
}

class WillWorldZone {
  final String title;
  final String subtitle;
  final List<String> skills;
  final String realWorldMapping;
  final String missionTitle;
  final List<String> missionSteps;
  final List<String> linkedCardIds;

  const WillWorldZone({
    required this.title,
    required this.subtitle,
    required this.skills,
    required this.realWorldMapping,
    required this.missionTitle,
    required this.missionSteps,
    required this.linkedCardIds,
  });
}


class WillSavedPlan {
  final int? id;
  final String taskTitle;
  final String ifText;
  final String thenText;
  final int updatedAtMs;

  const WillSavedPlan({
    this.id,
    required this.taskTitle,
    required this.ifText,
    required this.thenText,
    required this.updatedAtMs,
  });
}

class WillReviewEntry {
  final int? id;
  final String taskTitle;
  final int? sourceExecutionId;
  final String dominantIdea;
  final String opposingIdea;
  final String effortPoint;
  final String actionTaken;
  final String nextStep;
  final int updatedAtMs;

  const WillReviewEntry({
    this.id,
    required this.taskTitle,
    this.sourceExecutionId,
    required this.dominantIdea,
    required this.opposingIdea,
    required this.effortPoint,
    required this.actionTaken,
    required this.nextStep,
    required this.updatedAtMs,
  });
}

class WillTaskExecutionEntry {
  final int? id;
  final String taskTitle;
  final String note;
  final int effortLevel;
  final int completedAtMs;

  const WillTaskExecutionEntry({
    this.id,
    required this.taskTitle,
    required this.note,
    required this.effortLevel,
    required this.completedAtMs,
  });
}


class WillDashboardSummary {
  final int planCount;
  final int reviewCount;
  final int executionCount;
  final int taskCount;
  final int zoneVisitCount;

  const WillDashboardSummary({
    required this.planCount,
    required this.reviewCount,
    required this.executionCount,
    required this.taskCount,
    required this.zoneVisitCount,
  });
  int get savedPlanCount => planCount;

}

class WillTaskChainSummary {
  final String taskTitle;
  final int planCount;
  final int executionCount;
  final int reviewCount;
  final int latestExecutionAtMs;
  final int latestReviewAtMs;

  const WillTaskChainSummary({
    required this.taskTitle,
    required this.planCount,
    required this.executionCount,
    required this.reviewCount,
    required this.latestExecutionAtMs,
    required this.latestReviewAtMs,
  });
}


class WillZoneVisitEntry {
  final int? id;
  final String zoneTitle;
  final int visitedAtMs;

  const WillZoneVisitEntry({
    this.id,
    required this.zoneTitle,
    required this.visitedAtMs,
  });
}


class WillStageMilestoneEntry {
  final String stageKey;
  final String stageLabel;
  final String detail;
  final int achievedAtMs;

  const WillStageMilestoneEntry({
    required this.stageKey,
    required this.stageLabel,
    required this.detail,
    required this.achievedAtMs,
  });
}



class WillStageRuntimeState {
  final String currentStageKey;
  final String previousStageKey;
  final int changedAtMs;
  final int notifiedAtMs;

  const WillStageRuntimeState({
    required this.currentStageKey,
    required this.previousStageKey,
    required this.changedAtMs,
    required this.notifiedAtMs,
  });
}

class WillSuggestionState {
  final String suggestionKey;
  final int lastOpenedAtMs;
  final int completedAtMs;
  final int actionCount;

  const WillSuggestionState({
    required this.suggestionKey,
    required this.lastOpenedAtMs,
    required this.completedAtMs,
    required this.actionCount,
  });
}

class WillNamedCount {
  final String label;
  final int count;

  const WillNamedCount({required this.label, required this.count});
}
