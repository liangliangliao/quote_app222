class TodoFailureGrowthDraft {
  const TodoFailureGrowthDraft({
    required this.patternCode,
    required this.patternLabel,
    required this.factStatement,
    required this.growthReframe,
    required this.learningSignal,
    required this.recoveryPlan,
    required this.experimentTitle,
    required this.minimumStandard,
    required this.reflectionQuestion,
    required this.valueStatement,
  });

  final String patternCode;
  final String patternLabel;
  final String factStatement;
  final String growthReframe;
  final String learningSignal;
  final String recoveryPlan;
  final String experimentTitle;
  final String minimumStandard;
  final String reflectionQuestion;
  final String valueStatement;
}

class TodoFailureGrowthLoop {
  const TodoFailureGrowthLoop({
    required this.loopId,
    required this.goalId,
    required this.goalTitle,
    required this.linkedStepId,
    required this.eventText,
    required this.emotionText,
    required this.automaticThought,
    required this.fearedOutcome,
    required this.patternCode,
    required this.patternLabel,
    required this.factStatement,
    required this.growthReframe,
    required this.learningSignal,
    required this.recoveryPlan,
    required this.experimentTitle,
    required this.minimumStandard,
    required this.reflectionQuestion,
    required this.valueStatement,
    required this.resultText,
    required this.nextRevision,
    required this.status,
    required this.createdAtMs,
    required this.completedAtMs,
  });

  final String loopId;
  final String goalId;
  final String goalTitle;
  final String linkedStepId;
  final String eventText;
  final String emotionText;
  final String automaticThought;
  final String fearedOutcome;
  final String patternCode;
  final String patternLabel;
  final String factStatement;
  final String growthReframe;
  final String learningSignal;
  final String recoveryPlan;
  final String experimentTitle;
  final String minimumStandard;
  final String reflectionQuestion;
  final String valueStatement;
  final String resultText;
  final String nextRevision;
  final String status;
  final int createdAtMs;
  final int completedAtMs;

  bool get isCompleted => status == 'completed';

  factory TodoFailureGrowthLoop.fromMap(Map<String, Object?> row) {
    int asInt(Object? value) => value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
    String text(String key) => (row[key] ?? '').toString();
    return TodoFailureGrowthLoop(
      loopId: text('loop_id'),
      goalId: text('goal_id'),
      goalTitle: text('goal_title'),
      linkedStepId: text('linked_step_id'),
      eventText: text('event_text'),
      emotionText: text('emotion_text'),
      automaticThought: text('automatic_thought'),
      fearedOutcome: text('feared_outcome'),
      patternCode: text('pattern_code'),
      patternLabel: text('pattern_label'),
      factStatement: text('fact_statement'),
      growthReframe: text('growth_reframe'),
      learningSignal: text('learning_signal'),
      recoveryPlan: text('recovery_plan'),
      experimentTitle: text('experiment_title'),
      minimumStandard: text('minimum_standard'),
      reflectionQuestion: text('reflection_question'),
      valueStatement: text('value_statement'),
      resultText: text('result_text'),
      nextRevision: text('next_revision'),
      status: text('status').isEmpty ? 'active' : text('status'),
      createdAtMs: asInt(row['created_at_ms']),
      completedAtMs: asInt(row['completed_at_ms']),
    );
  }
}

class TodoFailureGrowthMetrics {
  const TodoFailureGrowthMetrics({
    required this.attempts,
    required this.reflections,
    required this.feedbackSamples,
    required this.revisions,
    required this.restarts,
    required this.activeExperiments,
  });

  final int attempts;
  final int reflections;
  final int feedbackSamples;
  final int revisions;
  final int restarts;
  final int activeExperiments;
}
