class TodoMeaningCompassSnapshot {
  const TodoMeaningCompassSnapshot({
    required this.snapshotId,
    required this.createdAtMs,
    required this.situation,
    required this.unavoidableQuestion,
    required this.recurringResponsibility,
    required this.waitingPerson,
    required this.uniqueTask,
    required this.avoidedResponsibility,
    required this.primaryPath,
    required this.responsibilityClarity,
    required this.futureAnchorStrength,
    required this.selfTranscendence,
    required this.attitudeFreedom,
    required this.currentMeaningQuestion,
    required this.nextResponse,
  });

  final String snapshotId;
  final int createdAtMs;
  final String situation;
  final String unavoidableQuestion;
  final String recurringResponsibility;
  final String waitingPerson;
  final String uniqueTask;
  final String avoidedResponsibility;
  final String primaryPath;
  final int responsibilityClarity;
  final int futureAnchorStrength;
  final int selfTranscendence;
  final int attitudeFreedom;
  final String currentMeaningQuestion;
  final String nextResponse;

  factory TodoMeaningCompassSnapshot.fromMap(Map<String, Object?> row) => TodoMeaningCompassSnapshot(
        snapshotId: (row['snapshot_id'] ?? '').toString(),
        createdAtMs: _meaningInt(row['created_at_ms']),
        situation: (row['situation'] ?? '').toString(),
        unavoidableQuestion: (row['unavoidable_question'] ?? '').toString(),
        recurringResponsibility: (row['recurring_responsibility'] ?? '').toString(),
        waitingPerson: (row['waiting_person'] ?? '').toString(),
        uniqueTask: (row['unique_task'] ?? '').toString(),
        avoidedResponsibility: (row['avoided_responsibility'] ?? '').toString(),
        primaryPath: (row['primary_path'] ?? 'creation').toString(),
        responsibilityClarity: _meaningInt(row['responsibility_clarity']),
        futureAnchorStrength: _meaningInt(row['future_anchor_strength']),
        selfTranscendence: _meaningInt(row['self_transcendence']),
        attitudeFreedom: _meaningInt(row['attitude_freedom']),
        currentMeaningQuestion: (row['current_meaning_question'] ?? '').toString(),
        nextResponse: (row['next_response'] ?? '').toString(),
      );
}

class TodoMeaningFutureAnchor {
  const TodoMeaningFutureAnchor({
    required this.anchorId,
    required this.anchorType,
    required this.title,
    required this.whyText,
    required this.todayHow,
    required this.status,
    required this.createdAtMs,
  });

  final String anchorId;
  final String anchorType;
  final String title;
  final String whyText;
  final String todayHow;
  final String status;
  final int createdAtMs;

  factory TodoMeaningFutureAnchor.fromMap(Map<String, Object?> row) => TodoMeaningFutureAnchor(
        anchorId: (row['anchor_id'] ?? '').toString(),
        anchorType: (row['anchor_type'] ?? 'work').toString(),
        title: (row['title'] ?? '').toString(),
        whyText: (row['why_text'] ?? '').toString(),
        todayHow: (row['today_how'] ?? '').toString(),
        status: (row['status'] ?? 'active').toString(),
        createdAtMs: _meaningInt(row['created_at_ms']),
      );
}

class TodoMeaningArchiveEntry {
  const TodoMeaningArchiveEntry({
    required this.entryId,
    required this.entryType,
    required this.title,
    required this.evidence,
    required this.happenedOn,
    required this.createdAtMs,
    this.goalId = '',
    this.stepId = '',
  });

  final String entryId;
  final String entryType;
  final String title;
  final String evidence;
  final String happenedOn;
  final int createdAtMs;
  final String goalId;
  final String stepId;

  factory TodoMeaningArchiveEntry.fromMap(Map<String, Object?> row) => TodoMeaningArchiveEntry(
        entryId: (row['entry_id'] ?? '').toString(),
        entryType: (row['entry_type'] ?? 'completed').toString(),
        title: (row['title'] ?? '').toString(),
        evidence: (row['evidence'] ?? '').toString(),
        happenedOn: (row['happened_on'] ?? '').toString(),
        createdAtMs: _meaningInt(row['created_at_ms']),
        goalId: (row['goal_id'] ?? '').toString(),
        stepId: (row['step_id'] ?? '').toString(),
      );
}

class TodoMeaningHardshipRecord {
  const TodoMeaningHardshipRecord({
    required this.recordId,
    required this.situation,
    required this.controllability,
    required this.controllablePart,
    required this.remainingChoice,
    required this.dignifiedAction,
    required this.supportNeeded,
    required this.createdAtMs,
  });

  final String recordId;
  final String situation;
  final String controllability;
  final String controllablePart;
  final String remainingChoice;
  final String dignifiedAction;
  final String supportNeeded;
  final int createdAtMs;

  factory TodoMeaningHardshipRecord.fromMap(Map<String, Object?> row) => TodoMeaningHardshipRecord(
        recordId: (row['record_id'] ?? '').toString(),
        situation: (row['situation'] ?? '').toString(),
        controllability: (row['controllability'] ?? 'partial').toString(),
        controllablePart: (row['controllable_part'] ?? '').toString(),
        remainingChoice: (row['remaining_choice'] ?? '').toString(),
        dignifiedAction: (row['dignified_action'] ?? '').toString(),
        supportNeeded: (row['support_needed'] ?? '').toString(),
        createdAtMs: _meaningInt(row['created_at_ms']),
      );
}

int _meaningInt(Object? value) {
  if (value is int) return value;
  return int.tryParse((value ?? '').toString()) ?? 0;
}
