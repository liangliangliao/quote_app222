class ChangePathActionCard {
  const ChangePathActionCard({
    required this.cardId,
    required this.goalId,
    required this.stepId,
    required this.sourceTaskId,
    required this.sourceListId,
    required this.changeGoal,
    required this.oldPattern,
    required this.preservedValue,
    required this.resistanceType,
    required this.action,
    required this.difficulty,
    required this.zone,
    required this.completionStandard,
    required this.failurePlan,
    required this.actionMeaning,
    required this.reviewQuestion,
    required this.status,
    required this.createdAtMs,
    this.startedAtMs = 0,
    this.completedAtMs = 0,
  });

  final String cardId;
  final String goalId;
  final String stepId;
  final String sourceTaskId;
  final String sourceListId;
  final String changeGoal;
  final String oldPattern;
  final String preservedValue;
  final String resistanceType;
  final String action;
  final int difficulty;
  final String zone;
  final String completionStandard;
  final String failurePlan;
  final String actionMeaning;
  final String reviewQuestion;
  final String status;
  final int createdAtMs;
  final int startedAtMs;
  final int completedAtMs;

  bool get isCompleted => status == 'completed';
  bool get isStarted => startedAtMs > 0;
  String get zoneLabel => zone == 'comfort' ? '舒适区' : zone == 'panic' ? '恐慌区' : '拉伸区';

  factory ChangePathActionCard.fromMap(Map<String, Object?> row) => ChangePathActionCard(
        cardId: '${row['card_id'] ?? ''}',
        goalId: '${row['goal_id'] ?? ''}',
        stepId: '${row['step_id'] ?? ''}',
        sourceTaskId: '${row['source_task_id'] ?? ''}',
        sourceListId: '${row['source_list_id'] ?? ''}',
        changeGoal: '${row['change_goal'] ?? ''}',
        oldPattern: '${row['old_pattern'] ?? ''}',
        preservedValue: '${row['preserved_value'] ?? ''}',
        resistanceType: '${row['resistance_type'] ?? ''}',
        action: '${row['action_text'] ?? ''}',
        difficulty: _int(row['difficulty'], 5),
        zone: '${row['zone_type'] ?? 'stretch'}',
        completionStandard: '${row['completion_standard'] ?? ''}',
        failurePlan: '${row['failure_plan'] ?? ''}',
        actionMeaning: '${row['action_meaning'] ?? ''}',
        reviewQuestion: '${row['review_question'] ?? ''}',
        status: '${row['status'] ?? 'ready'}',
        createdAtMs: _int(row['created_at_ms']),
        startedAtMs: _int(row['started_at_ms']),
        completedAtMs: _int(row['completed_at_ms']),
      );
}

class ChangePathEvidence {
  const ChangePathEvidence({
    required this.evidenceId,
    required this.goalId,
    required this.cardId,
    required this.evidenceDate,
    required this.oldBelief,
    required this.action,
    required this.difficulty,
    required this.prediction,
    required this.actualResult,
    required this.newEvidence,
    required this.newBelief,
    required this.createdAtMs,
  });

  final String evidenceId;
  final String goalId;
  final String cardId;
  final String evidenceDate;
  final String oldBelief;
  final String action;
  final int difficulty;
  final String prediction;
  final String actualResult;
  final String newEvidence;
  final String newBelief;
  final int createdAtMs;

  factory ChangePathEvidence.fromMap(Map<String, Object?> row) => ChangePathEvidence(
        evidenceId: '${row['evidence_id'] ?? ''}',
        goalId: '${row['goal_id'] ?? ''}',
        cardId: '${row['card_id'] ?? ''}',
        evidenceDate: '${row['evidence_date'] ?? ''}',
        oldBelief: '${row['old_belief'] ?? ''}',
        action: '${row['action_text'] ?? ''}',
        difficulty: _int(row['difficulty'], 5),
        prediction: '${row['prediction_text'] ?? ''}',
        actualResult: '${row['actual_result'] ?? ''}',
        newEvidence: '${row['new_evidence'] ?? ''}',
        newBelief: '${row['new_belief'] ?? ''}',
        createdAtMs: _int(row['created_at_ms']),
      );
}

class ChangePathAbcJournal {
  const ChangePathAbcJournal({
    required this.journalId,
    required this.goalId,
    required this.journalDate,
    required this.emotion,
    required this.emotionIntensity,
    required this.bodySignal,
    required this.actionTaken,
    required this.avoidance,
    required this.stretchAction,
    required this.oldInterpretation,
    required this.freedomCheck,
    required this.newInterpretation,
    required this.createdAtMs,
  });

  final String journalId;
  final String goalId;
  final String journalDate;
  final String emotion;
  final int emotionIntensity;
  final String bodySignal;
  final String actionTaken;
  final String avoidance;
  final String stretchAction;
  final String oldInterpretation;
  final String freedomCheck;
  final String newInterpretation;
  final int createdAtMs;

  factory ChangePathAbcJournal.fromMap(Map<String, Object?> row) => ChangePathAbcJournal(
        journalId: '${row['journal_id'] ?? ''}',
        goalId: '${row['goal_id'] ?? ''}',
        journalDate: '${row['journal_date'] ?? ''}',
        emotion: '${row['emotion'] ?? ''}',
        emotionIntensity: _int(row['emotion_intensity'], 5),
        bodySignal: '${row['body_signal'] ?? ''}',
        actionTaken: '${row['action_taken'] ?? ''}',
        avoidance: '${row['avoidance'] ?? ''}',
        stretchAction: '${row['stretch_action'] ?? ''}',
        oldInterpretation: '${row['old_interpretation'] ?? ''}',
        freedomCheck: '${row['freedom_check'] ?? ''}',
        newInterpretation: '${row['new_interpretation'] ?? ''}',
        createdAtMs: _int(row['created_at_ms']),
      );
}

class ChangePathResistanceDiagnosis {
  const ChangePathResistanceDiagnosis({required this.type, required this.explanation, required this.adjustment});
  final String type;
  final String explanation;
  final String adjustment;
}

class ChangePathMapSnapshot {
  const ChangePathMapSnapshot({
    required this.theme,
    required this.oldPattern,
    required this.preservedValue,
    required this.strongestResistance,
    required this.newBehavior,
    required this.evidenceCount,
    required this.completedActions,
    required this.reviewCount,
    required this.newIdentity,
  });
  final String theme;
  final String oldPattern;
  final String preservedValue;
  final String strongestResistance;
  final String newBehavior;
  final int evidenceCount;
  final int completedActions;
  final int reviewCount;
  final String newIdentity;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}
