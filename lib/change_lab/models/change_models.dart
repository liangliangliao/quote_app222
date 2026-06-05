import 'package:flutter/foundation.dart';

enum TaskType { light, main, challenge, fallback }

enum ConceptStatus { unread, read, acted, internalized }

@immutable
class ChangeTask {
  const ChangeTask({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.instructions,
    required this.estimatedMinutes,
    required this.fallbackHint,
  });

  final String id;
  final TaskType type;
  final String title;
  final String summary;
  final String instructions;
  final int estimatedMinutes;
  final String fallbackHint;
}

@immutable
class ChangeConcept {
  const ChangeConcept({
    required this.id,
    required this.title,
    required this.module,
    required this.oneLineSummary,
    required this.problemSolved,
    required this.courseEssence,
    required this.classicCase,
    required this.commonSigns,
    required this.tasks,
  });

  final String id;
  final String title;
  final String module;
  final String oneLineSummary;
  final String problemSolved;
  final String courseEssence;
  final String classicCase;
  final List<String> commonSigns;
  final List<ChangeTask> tasks;
}

class ChangeProgress {
  ChangeProgress({
    required this.conceptId,
    this.isRead = false,
    this.actionCount = 0,
    this.reflectionCount = 0,
  });

  final String conceptId;
  bool isRead;
  int actionCount;
  int reflectionCount;

  ConceptStatus get status {
    if (actionCount >= 2 && reflectionCount >= 1) {
      return ConceptStatus.internalized;
    }
    if (actionCount >= 1) {
      return ConceptStatus.acted;
    }
    if (isRead) {
      return ConceptStatus.read;
    }
    return ConceptStatus.unread;
  }
}

class DiagnosisQuestion {
  const DiagnosisQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<DiagnosisOption> options;
}

class DiagnosisOption {
  const DiagnosisOption({
    required this.label,
    required this.suggestedConceptIds,
  });

  final String label;
  final List<String> suggestedConceptIds;
}

class DiagnosisResult {
  const DiagnosisResult({
    required this.summary,
    required this.recommendedConceptIds,
  });

  final String summary;
  final List<String> recommendedConceptIds;
}

@immutable
class ReflectionEntry {
  const ReflectionEntry({
    required this.conceptId,
    required this.taskId,
    required this.text,
    required this.createdAt,
  });

  final String conceptId;
  final String taskId;
  final String text;
  final DateTime createdAt;
}

@immutable
class TaskRunRecord {
  const TaskRunRecord({
    required this.conceptId,
    required this.taskId,
    required this.taskType,
    required this.beforeText,
    required this.actionText,
    required this.afterText,
    required this.beforeScore,
    required this.afterScore,
    required this.createdAt,
  });

  final String conceptId;
  final String taskId;
  final TaskType taskType;
  final String beforeText;
  final String actionText;
  final String afterText;
  final int beforeScore;
  final int afterScore;
  final DateTime createdAt;

  String get combinedReflection {
    return [
      if (beforeText.trim().isNotEmpty) '行动前：${beforeText.trim()}',
      if (actionText.trim().isNotEmpty) '行动中：${actionText.trim()}',
      if (afterText.trim().isNotEmpty) '行动后：${afterText.trim()}',
      '感受变化：$beforeScore → $afterScore',
    ].join('\n');
  }
}

@immutable
class TaskRecommendation {
  const TaskRecommendation({
    required this.concept,
    required this.task,
    required this.reason,
  });

  final ChangeConcept concept;
  final ChangeTask task;
  final String reason;
}


enum ReminderType { pre, moment, interrupt, nextDay }

enum PromptScenario { taskAssigned, taskCompleted, taskFailed, nextDayCheckin, reflectionFollowup }

@immutable
class ReminderTemplate {
  const ReminderTemplate({
    required this.id,
    required this.conceptId,
    required this.taskId,
    required this.type,
    required this.title,
    required this.message,
  });

  final String id;
  final String conceptId;
  final String taskId;
  final ReminderType type;
  final String title;
  final String message;
}

@immutable
class AiPromptTemplate {
  const AiPromptTemplate({
    required this.id,
    required this.conceptId,
    required this.taskId,
    required this.scenario,
    required this.systemGoal,
    required this.prompt,
  });

  final String id;
  final String conceptId;
  final String taskId;
  final PromptScenario scenario;
  final String systemGoal;
  final String prompt;
}

@immutable
class WorldScene {
  const WorldScene({
    required this.id,
    required this.title,
    required this.description,
    required this.sceneGoal,
    required this.realWorldRule,
    required this.conceptIds,
    required this.unlockConceptIds,
    this.requiredStatus = ConceptStatus.read,
    this.nextWorldIds = const [],
  });

  final String id;
  final String title;
  final String description;
  final String sceneGoal;
  final String realWorldRule;
  final List<String> conceptIds;
  final List<String> unlockConceptIds;
  final ConceptStatus requiredStatus;
  final List<String> nextWorldIds;
}


enum TaskInstanceStatus { planned, inProgress, completed, failed, restarted, skipped }


enum WorldMissionStatus { locked, active, completed }

@immutable
class WorldMissionStage {
  const WorldMissionStage({
    required this.id,
    required this.worldId,
    required this.stageNo,
    required this.title,
    required this.summary,
    required this.actionTarget,
    required this.requiredConceptIds,
    required this.rewardText,
    this.suggestedTaskType = TaskType.main,
  });

  final String id;
  final String worldId;
  final int stageNo;
  final String title;
  final String summary;
  final int actionTarget;
  final List<String> requiredConceptIds;
  final String rewardText;
  final TaskType suggestedTaskType;
}

@immutable
class CoachDialogueTurn {
  const CoachDialogueTurn({
    required this.speaker,
    required this.message,
    this.emphasis = '',
  });

  final String speaker;
  final String message;
  final String emphasis;
}

@immutable
class ChangeTaskInstance {
  const ChangeTaskInstance({
    required this.id,
    required this.conceptId,
    required this.taskId,
    required this.taskType,
    required this.plannedFor,
    required this.createdAt,
    required this.status,
    this.assignedReason = '',
    this.failureReason = '',
    this.parentInstanceId,
    this.isFromWeeklyPlan = false,
    this.startedAt,
    this.completedAt,
    this.failCount = 0,
  });

  final String id;
  final String conceptId;
  final String taskId;
  final TaskType taskType;
  final DateTime plannedFor;
  final DateTime createdAt;
  final TaskInstanceStatus status;
  final String assignedReason;
  final String failureReason;
  final String? parentInstanceId;
  final bool isFromWeeklyPlan;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int failCount;

  bool get isOpen =>
      status == TaskInstanceStatus.planned || status == TaskInstanceStatus.inProgress;

  ChangeTaskInstance copyWith({
    String? id,
    String? conceptId,
    String? taskId,
    TaskType? taskType,
    DateTime? plannedFor,
    DateTime? createdAt,
    TaskInstanceStatus? status,
    String? assignedReason,
    String? failureReason,
    String? parentInstanceId,
    bool? isFromWeeklyPlan,
    DateTime? startedAt,
    DateTime? completedAt,
    int? failCount,
  }) {
    return ChangeTaskInstance(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      taskId: taskId ?? this.taskId,
      taskType: taskType ?? this.taskType,
      plannedFor: plannedFor ?? this.plannedFor,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      assignedReason: assignedReason ?? this.assignedReason,
      failureReason: failureReason ?? this.failureReason,
      parentInstanceId: parentInstanceId ?? this.parentInstanceId,
      isFromWeeklyPlan: isFromWeeklyPlan ?? this.isFromWeeklyPlan,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      failCount: failCount ?? this.failCount,
    );
  }
}

@immutable
class WeeklyPlan {
  const WeeklyPlan({
    required this.id,
    required this.weekKey,
    required this.createdAt,
    required this.focusConceptIds,
    required this.taskInstanceIds,
    required this.summary,
  });

  final String id;
  final String weekKey;
  final DateTime createdAt;
  final List<String> focusConceptIds;
  final List<String> taskInstanceIds;
  final String summary;
}


enum ReminderScheduleStatus { pending, done, dismissed }

@immutable
class ReminderSchedule {
  const ReminderSchedule({
    required this.id,
    required this.instanceId,
    required this.conceptId,
    required this.taskId,
    required this.type,
    required this.scheduledFor,
    required this.createdAt,
    required this.title,
    required this.message,
    this.status = ReminderScheduleStatus.pending,
    this.worldId,
    this.completedAt,
  });

  final String id;
  final String instanceId;
  final String conceptId;
  final String taskId;
  final ReminderType type;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final String title;
  final String message;
  final ReminderScheduleStatus status;
  final String? worldId;
  final DateTime? completedAt;

  bool get isPending => status == ReminderScheduleStatus.pending;
  bool get isDue => isPending && !scheduledFor.isAfter(DateTime.now());

  ReminderSchedule copyWith({
    String? id,
    String? instanceId,
    String? conceptId,
    String? taskId,
    ReminderType? type,
    DateTime? scheduledFor,
    DateTime? createdAt,
    String? title,
    String? message,
    ReminderScheduleStatus? status,
    String? worldId,
    DateTime? completedAt,
  }) {
    return ReminderSchedule(
      id: id ?? this.id,
      instanceId: instanceId ?? this.instanceId,
      conceptId: conceptId ?? this.conceptId,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      message: message ?? this.message,
      status: status ?? this.status,
      worldId: worldId ?? this.worldId,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}



@immutable
class WorldMissionRecord {
  const WorldMissionRecord({
    required this.missionId,
    this.progressCount = 0,
    this.unlockedAt,
    this.completedAt,
    this.rewardClaimedAt,
    this.lastProgressAt,
    this.contributionRunKeys = const [],
  });

  final String missionId;
  final int progressCount;
  final DateTime? unlockedAt;
  final DateTime? completedAt;
  final DateTime? rewardClaimedAt;
  final DateTime? lastProgressAt;
  final List<String> contributionRunKeys;

  bool get isUnlocked => unlockedAt != null;
  bool get isCompleted => completedAt != null;
  bool get isRewardClaimed => rewardClaimedAt != null;

  WorldMissionRecord copyWith({
    String? missionId,
    int? progressCount,
    DateTime? unlockedAt,
    DateTime? completedAt,
    DateTime? rewardClaimedAt,
    DateTime? lastProgressAt,
    List<String>? contributionRunKeys,
  }) {
    return WorldMissionRecord(
      missionId: missionId ?? this.missionId,
      progressCount: progressCount ?? this.progressCount,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      completedAt: completedAt ?? this.completedAt,
      rewardClaimedAt: rewardClaimedAt ?? this.rewardClaimedAt,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      contributionRunKeys: contributionRunKeys ?? this.contributionRunKeys,
    );
  }
}

@immutable
class WorldRewardEvent {
  const WorldRewardEvent({
    required this.id,
    required this.worldId,
    required this.missionId,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String worldId;
  final String missionId;
  final String title;
  final String message;
  final DateTime createdAt;
}



enum TimelineItemType { action, reflection, reward, unlock }

@immutable
class GrowthTimelineItem {
  const GrowthTimelineItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.conceptId,
    this.worldId,
    this.missionId,
    this.accentLabel = '',
  });

  final String id;
  final TimelineItemType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? conceptId;
  final String? worldId;
  final String? missionId;
  final String accentLabel;
}

@immutable
class WorldProgress {
  const WorldProgress({
    required this.worldId,
    required this.unlocked,
    required this.completed,
    required this.completedActions,
    required this.targetActions,
    this.lastActionAt,
  });

  final String worldId;
  final bool unlocked;
  final bool completed;
  final int completedActions;
  final int targetActions;
  final DateTime? lastActionAt;

  double get ratio {
    if (targetActions <= 0) return completed ? 1 : 0;
    final value = completedActions / targetActions;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}


@immutable
class CourseParagraphRecord {
  const CourseParagraphRecord({
    required this.id,
    required this.conceptId,
    required this.sectionType,
    required this.paragraphIndex,
    this.isFavorite = false,
    this.inReviewList = false,
    this.note = '',
    required this.updatedAt,
  });

  final String id;
  final String conceptId;
  final String sectionType;
  final int paragraphIndex;
  final bool isFavorite;
  final bool inReviewList;
  final String note;
  final DateTime updatedAt;

  CourseParagraphRecord copyWith({
    String? id,
    String? conceptId,
    String? sectionType,
    int? paragraphIndex,
    bool? isFavorite,
    bool? inReviewList,
    String? note,
    DateTime? updatedAt,
  }) {
    return CourseParagraphRecord(
      id: id ?? this.id,
      conceptId: conceptId ?? this.conceptId,
      sectionType: sectionType ?? this.sectionType,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      inReviewList: inReviewList ?? this.inReviewList,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class CourseParagraphView {
  const CourseParagraphView({
    required this.record,
    required this.conceptTitle,
    required this.lectureLabel,
    required this.blockTitle,
    required this.text,
    required this.keyPoint,
  });

  final CourseParagraphRecord record;
  final String conceptTitle;
  final String lectureLabel;
  final String blockTitle;
  final String text;
  final String keyPoint;
}
