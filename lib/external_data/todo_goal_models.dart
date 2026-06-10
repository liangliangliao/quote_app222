import 'dart:convert';

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value.toInt() == 1;
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'fallback';
}

String _firstText(Map<String, Object?> row, List<String> keys, [String fallback = '']) {
  for (final key in keys) {
    final text = (row[key] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

class TodoGoalAnalysisResult {
  const TodoGoalAnalysisResult({
    required this.goalTitle,
    required this.deepMeaning,
    required this.desiredIdentity,
    required this.goalCategory,
    required this.goalOriginType,
    required this.selfConcordanceScore,
    required this.processValue,
    required this.obstacleSummary,
    required this.todayMinimumAction,
    required this.minimumStandard,
    this.simplifiedStandard = '',
    required this.recommendedStandard,
    required this.stretchStandard,
    required this.difficultyScore,
    required this.zoneType,
    required this.coachMessage,
    required this.provider,
    this.solutionPlans = const <TodoGoalSolutionPlan>[],
    required this.modelLabel,
    this.rawResponse = '',
    this.usedFallback = false,
    this.resultGoal = '',
    this.valueGoal = '',
    this.processGoal = '',
    this.coreValues = '',
    this.autonomyScore = 0,
    this.valueAlignmentScore = 0,
    this.interestConnectionScore = 0,
    this.passionScore = 0,
    this.feasibilityScore = 0,
    this.externalPressureScore = 0,
    this.processHappinessScore = 0,
    this.goalType = '',
    this.currentStage = '',
    this.actionPlace = '',
    this.startTrigger = '',
    this.completionQuestion = '',
    this.processAction = '',
    this.valueAction = '',
    this.experiencePrompt = '',
    this.userNeedInterpretation = '',
    this.keyUncertainties = '',
    this.clarifyingQuestions = '',
    this.possibleDirections = '',
    this.referenceCases = '',
    this.recommendationRationale = '',
    this.userDecisionPrompt = '',
  });

  final String goalTitle;
  final String deepMeaning;
  final String desiredIdentity;
  final String goalCategory;
  final String goalOriginType;
  final int selfConcordanceScore;
  final String processValue;
  final String obstacleSummary;
  final String todayMinimumAction;
  final String minimumStandard;
  final String simplifiedStandard;
  final String recommendedStandard;
  final String stretchStandard;
  final int difficultyScore;
  final String zoneType;
  final String coachMessage;
  final String provider;
  final List<TodoGoalSolutionPlan> solutionPlans;
  final String modelLabel;
  final String rawResponse;
  final bool usedFallback;
  final String resultGoal;
  final String valueGoal;
  final String processGoal;
  final String coreValues;
  final int autonomyScore;
  final int valueAlignmentScore;
  final int interestConnectionScore;
  final int passionScore;
  final int feasibilityScore;
  final int externalPressureScore;
  final int processHappinessScore;
  final String goalType;
  final String currentStage;
  final String actionPlace;
  final String startTrigger;
  final String completionQuestion;
  final String processAction;
  final String valueAction;
  final String experiencePrompt;
  final String userNeedInterpretation;
  final String keyUncertainties;
  final String clarifyingQuestions;
  final String possibleDirections;
  final String referenceCases;
  final String recommendationRationale;
  final String userDecisionPrompt;

  Map<String, Object?> toJson() => <String, Object?>{
        'goalTitle': goalTitle,
        'deepMeaning': deepMeaning,
        'desiredIdentity': desiredIdentity,
        'goalCategory': goalCategory,
        'goalOriginType': goalOriginType,
        'selfConcordanceScore': selfConcordanceScore,
        'processValue': processValue,
        'obstacleSummary': obstacleSummary,
        'todayMinimumAction': todayMinimumAction,
        'minimumStandard': minimumStandard,
        'simplifiedStandard': simplifiedStandard,
        'recommendedStandard': recommendedStandard,
        'stretchStandard': stretchStandard,
        'difficultyScore': difficultyScore,
        'zoneType': zoneType,
        'coachMessage': coachMessage,
        'provider': provider,
        'solutionPlans': solutionPlans.map((e) => e.toJson()).toList(),
        'modelLabel': modelLabel,
        'usedFallback': usedFallback,
        'resultGoal': resultGoal,
        'valueGoal': valueGoal,
        'processGoal': processGoal,
        'coreValues': coreValues,
        'autonomyScore': autonomyScore,
        'valueAlignmentScore': valueAlignmentScore,
        'interestConnectionScore': interestConnectionScore,
        'passionScore': passionScore,
        'feasibilityScore': feasibilityScore,
        'externalPressureScore': externalPressureScore,
        'processHappinessScore': processHappinessScore,
        'goalType': goalType,
        'currentStage': currentStage,
        'actionPlace': actionPlace,
        'startTrigger': startTrigger,
        'completionQuestion': completionQuestion,
        'processAction': processAction,
        'valueAction': valueAction,
        'experiencePrompt': experiencePrompt,
        'userNeedInterpretation': userNeedInterpretation,
        'keyUncertainties': keyUncertainties,
        'clarifyingQuestions': clarifyingQuestions,
        'possibleDirections': possibleDirections,
        'referenceCases': referenceCases,
        'recommendationRationale': recommendationRationale,
        'userDecisionPrompt': userDecisionPrompt,
      };
}

class TodoGoalWeeklySummaryResult {
  const TodoGoalWeeklySummaryResult({
    required this.alignmentInsight,
    required this.processInsight,
    required this.valueEvidence,
    required this.adjustmentAdvice,
    required this.nextWeekFocus,
    required this.provider,
    required this.modelLabel,
    this.usedFallback = false,
  });

  final String alignmentInsight;
  final String processInsight;
  final String valueEvidence;
  final String adjustmentAdvice;
  final String nextWeekFocus;
  final String provider;
  final String modelLabel;
  final bool usedFallback;
}

class TodoGoalReviewResult {
  const TodoGoalReviewResult({
    required this.summary,
    required this.processInsight,
    required this.meaningConnection,
    required this.tomorrowNextStep,
    required this.encouragement,
    required this.provider,
    required this.modelLabel,
    this.rawResponse = '',
    this.usedFallback = false,
    this.nextStepOptions = '',
    this.decisionPrompt = '',
    this.factReflection = '',
    this.bodySignal = '',
    this.cognitionPattern = '',
    this.emotionLabel = '',
    this.growthPattern = '',
    this.valueQuestion = '',
    this.feedbackInsight = '',
    this.authenticExpression = '',
    this.actionExperiment = '',
    this.actionWhen = '',
    this.actionEvidence = '',
    this.followUpQuestion = '',
  });

  final String summary;
  final String processInsight;
  final String meaningConnection;
  final String tomorrowNextStep;
  final String encouragement;
  final String provider;
  final String modelLabel;
  final String rawResponse;
  final bool usedFallback;
  final String nextStepOptions;
  final String decisionPrompt;
  final String factReflection;
  final String bodySignal;
  final String cognitionPattern;
  final String emotionLabel;
  final String growthPattern;
  final String valueQuestion;
  final String feedbackInsight;
  final String authenticExpression;
  final String actionExperiment;
  final String actionWhen;
  final String actionEvidence;
  final String followUpQuestion;

  Map<String, Object?> toJson() => <String, Object?>{
        'summary': summary,
        'processInsight': processInsight,
        'meaningConnection': meaningConnection,
        'tomorrowNextStep': tomorrowNextStep,
        'encouragement': encouragement,
        'provider': provider,
        'modelLabel': modelLabel,
        'usedFallback': usedFallback,
        'nextStepOptions': nextStepOptions,
        'decisionPrompt': decisionPrompt,
        'factReflection': factReflection,
        'bodySignal': bodySignal,
        'cognitionPattern': cognitionPattern,
        'emotionLabel': emotionLabel,
        'growthPattern': growthPattern,
        'valueQuestion': valueQuestion,
        'feedbackInsight': feedbackInsight,
        'authenticExpression': authenticExpression,
        'actionExperiment': actionExperiment,
        'actionWhen': actionWhen,
        'actionEvidence': actionEvidence,
        'followUpQuestion': followUpQuestion,
      };
}

class TodoGoalProfile {
  const TodoGoalProfile({
    required this.goalId,
    required this.sourceType,
    required this.sourceTaskId,
    required this.sourceListId,
    required this.goalTitle,
    required this.deepMeaning,
    required this.desiredIdentity,
    required this.goalCategory,
    required this.goalOriginType,
    required this.selfConcordanceScore,
    required this.processValue,
    required this.obstacleSummary,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.aiProvider = '',
    this.aiModelLabel = '',
    this.aiUsedFallback = false,
    this.resultGoal = '',
    this.valueGoal = '',
    this.processGoal = '',
    this.coreValues = '',
    this.autonomyScore = 0,
    this.valueAlignmentScore = 0,
    this.interestConnectionScore = 0,
    this.passionScore = 0,
    this.feasibilityScore = 0,
    this.externalPressureScore = 0,
    this.processHappinessScore = 0,
    this.goalType = '',
    this.currentStage = '',
    this.userNeedInterpretation = '',
    this.keyUncertainties = '',
    this.clarifyingQuestions = '',
    this.possibleDirections = '',
    this.referenceCases = '',
    this.recommendationRationale = '',
    this.userDecisionPrompt = '',
  });

  final String goalId;
  final String sourceType;
  final String sourceTaskId;
  final String sourceListId;
  final String goalTitle;
  final String deepMeaning;
  final String desiredIdentity;
  final String goalCategory;
  final String goalOriginType;
  final int selfConcordanceScore;
  final String processValue;
  final String obstacleSummary;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;
  final String aiProvider;
  final String aiModelLabel;
  final bool aiUsedFallback;
  final String resultGoal;
  final String valueGoal;
  final String processGoal;
  final String coreValues;
  final int autonomyScore;
  final int valueAlignmentScore;
  final int interestConnectionScore;
  final int passionScore;
  final int feasibilityScore;
  final int externalPressureScore;
  final int processHappinessScore;
  final String goalType;
  final String currentStage;
  final String userNeedInterpretation;
  final String keyUncertainties;
  final String clarifyingQuestions;
  final String possibleDirections;
  final String referenceCases;
  final String recommendationRationale;
  final String userDecisionPrompt;

  List<String> get coreValueList => coreValues
      .split(RegExp(r'[,，、|]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  bool get needsRealignment => externalPressureScore >= 70 || selfConcordanceScore < 45;

  bool get lacksProcessDesign => processGoal.trim().isEmpty || processHappinessScore < 45;

  bool get isLikelyFallbackAnalysis {
    final provider = aiProvider.trim().toLowerCase();
    final model = aiModelLabel.trim().toLowerCase();
    if (aiUsedFallback) return true;
    if (provider.isEmpty || provider == 'local' || provider == 'fallback') return true;
    if (model.contains('本地') || model.contains('local')) return true;
    // v54: the explicit AI metadata is the source of truth. Earlier builds also
    // guessed fallback from generic phrases such as “方向线索”, which could be
    // generated by a real model and caused successful AI results to be displayed
    // as local fallback. Do not classify real provider results by text alone.
    return false;
  }

  factory TodoGoalProfile.fromMap(Map<String, Object?> row) => TodoGoalProfile(
        goalId: (row['goal_id'] ?? '').toString(),
        sourceType: (row['source_type'] ?? '').toString(),
        sourceTaskId: (row['source_task_id'] ?? '').toString(),
        sourceListId: (row['source_list_id'] ?? '').toString(),
        goalTitle: (row['goal_title'] ?? '').toString(),
        deepMeaning: (row['deep_meaning'] ?? '').toString(),
        desiredIdentity: (row['desired_identity'] ?? '').toString(),
        goalCategory: (row['goal_category'] ?? '').toString(),
        goalOriginType: (row['goal_origin_type'] ?? '').toString(),
        selfConcordanceScore: _toInt(row['self_concordance_score']),
        processValue: (row['process_value'] ?? '').toString(),
        obstacleSummary: (row['obstacle_summary'] ?? '').toString(),
        status: (row['status'] ?? 'active').toString(),
        createdAtMs: _toInt(row['created_at_ms']),
        updatedAtMs: _toInt(row['updated_at_ms']),
        aiProvider: (row['ai_provider'] ?? '').toString(),
        aiModelLabel: (row['ai_model_label'] ?? '').toString(),
        aiUsedFallback: _toBool(row['ai_used_fallback']),
        resultGoal: (row['result_goal'] ?? '').toString(),
        valueGoal: (row['value_goal'] ?? '').toString(),
        processGoal: (row['process_goal'] ?? '').toString(),
        coreValues: (row['core_values'] ?? '').toString(),
        autonomyScore: _toInt(row['autonomy_score']),
        valueAlignmentScore: _toInt(row['value_alignment_score']),
        interestConnectionScore: _toInt(row['interest_connection_score']),
        passionScore: _toInt(row['passion_score']),
        feasibilityScore: _toInt(row['feasibility_score']),
        externalPressureScore: _toInt(row['external_pressure_score']),
        processHappinessScore: _toInt(row['process_happiness_score']),
        goalType: (row['goal_type'] ?? '').toString(),
        currentStage: (row['current_stage'] ?? '').toString(),
        userNeedInterpretation: (row['user_need_interpretation'] ?? '').toString(),
        keyUncertainties: (row['key_uncertainties'] ?? '').toString(),
        clarifyingQuestions: (row['clarifying_questions'] ?? '').toString(),
        possibleDirections: (row['possible_directions'] ?? '').toString(),
        referenceCases: (row['reference_cases'] ?? '').toString(),
        recommendationRationale: (row['recommendation_rationale'] ?? '').toString(),
        userDecisionPrompt: (row['user_decision_prompt'] ?? '').toString(),
      );
}

class TodoGoalActionStep {
  const TodoGoalActionStep({
    required this.stepId,
    required this.goalId,
    required this.sourceTaskId,
    required this.title,
    required this.minimumStandard,
    this.simplifiedStandard = '',
    required this.recommendedStandard,
    required this.stretchStandard,
    required this.difficultyScore,
    required this.zoneType,
    required this.plannedDate,
    required this.plannedTime,
    required this.status,
    required this.completedAtMs,
    required this.writeBackToTodo,
    required this.remoteTaskId,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.goalTitle = '',
    this.deepMeaning = '',
    this.processValue = '',
    this.sourceListId = '',
    this.parentStepId = '',
    this.parentStepTitle = '',
    this.stepLevel = 1,
    this.sortOrder = 0,
    this.actionPlace = '',
    this.startTrigger = '',
    this.completionQuestion = '',
    this.actionType = 'result',
    this.experienceIntention = '',
  });

  final String stepId;
  final String goalId;
  final String sourceTaskId;
  final String title;
  final String minimumStandard;
  final String simplifiedStandard;
  final String recommendedStandard;
  final String stretchStandard;
  final int difficultyScore;
  final String zoneType;
  final String plannedDate;
  final String plannedTime;
  final String status;
  final int completedAtMs;
  final bool writeBackToTodo;
  final String remoteTaskId;
  final int createdAtMs;
  final int updatedAtMs;
  final String goalTitle;
  final String deepMeaning;
  final String processValue;
  final String sourceListId;
  final String parentStepId;
  final String parentStepTitle;
  final int stepLevel;
  final int sortOrder;
  final String actionPlace;
  final String startTrigger;
  final String completionQuestion;
  final String actionType;
  final String experienceIntention;

  String get actionTypeLabel {
    switch (actionType) {
      case 'process':
        return '过程型行动';
      case 'value':
        return '价值型行动';
      default:
        return '结果型行动';
    }
  }

  bool get isCompleted => status == 'completed';
  bool get hasParentStep => parentStepId.trim().isNotEmpty;
  String get parentLabel => hasParentStep
      ? (parentStepTitle.trim().isEmpty ? '上一步行动' : parentStepTitle.trim())
      : (goalTitle.trim().isEmpty ? '父目标' : goalTitle.trim());

  factory TodoGoalActionStep.fromMap(Map<String, Object?> row) => TodoGoalActionStep(
        stepId: (row['step_id'] ?? '').toString(),
        goalId: (row['goal_id'] ?? '').toString(),
        sourceTaskId: (row['source_task_id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        minimumStandard: (row['minimum_standard'] ?? '').toString(),
        simplifiedStandard: (row['simplified_standard'] ?? '').toString(),
        recommendedStandard: (row['recommended_standard'] ?? '').toString(),
        stretchStandard: (row['stretch_standard'] ?? '').toString(),
        difficultyScore: _toInt(row['difficulty_score']),
        zoneType: (row['zone_type'] ?? '').toString(),
        plannedDate: (row['planned_date'] ?? '').toString(),
        plannedTime: (row['planned_time'] ?? '').toString(),
        status: (row['status'] ?? 'not_started').toString(),
        completedAtMs: _toInt(row['completed_at_ms']),
        writeBackToTodo: _toInt(row['write_back_to_todo']) == 1,
        remoteTaskId: (row['remote_task_id'] ?? '').toString(),
        createdAtMs: _toInt(row['created_at_ms']),
        updatedAtMs: _toInt(row['updated_at_ms']),
        goalTitle: (row['goal_title'] ?? '').toString(),
        deepMeaning: (row['deep_meaning'] ?? '').toString(),
        processValue: (row['process_value'] ?? '').toString(),
        sourceListId: (row['source_list_id'] ?? '').toString(),
        parentStepId: (row['parent_step_id'] ?? '').toString(),
        parentStepTitle: (row['parent_step_title'] ?? '').toString(),
        stepLevel: _toInt(row['step_level']) == 0 ? 1 : _toInt(row['step_level']),
        sortOrder: _toInt(row['sort_order']),
        actionPlace: (row['action_place'] ?? '').toString(),
        startTrigger: (row['start_trigger'] ?? '').toString(),
        completionQuestion: (row['completion_question'] ?? '').toString(),
        actionType: (row['action_type'] ?? 'result').toString(),
        experienceIntention: (row['experience_intention'] ?? '').toString(),
      );
}

class TodoGoalReflection {
  const TodoGoalReflection({
    required this.reflectionId,
    required this.goalId,
    required this.stepId,
    required this.reflectionDate,
    required this.whatDone,
    required this.whyDone,
    required this.processExperience,
    required this.obstacle,
    required this.tomorrowNextStep,
    required this.aiSummary,
    required this.moodScore,
    required this.meaningScore,
    required this.processScore,
    required this.createdAtMs,
    this.goalTitle = '',
    this.bodySignal = '',
    this.emotionLabel = '',
    this.cognition = '',
    this.authenticTruth = '',
    this.feedbackSource = '',
    this.feedbackContent = '',
    this.feedbackLearning = '',
    this.corePattern = '',
    this.coreValue = '',
    this.actionExperiment = '',
    this.actionWhen = '',
    this.actionEvidence = '',
    this.followUpQuestion = '',
    this.reviewMode = 'daily',
  });

  final String reflectionId;
  final String goalId;
  final String stepId;
  final String reflectionDate;
  final String whatDone;
  final String whyDone;
  final String processExperience;
  final String obstacle;
  final String tomorrowNextStep;
  final String aiSummary;
  final int moodScore;
  final int meaningScore;
  final int processScore;
  final int createdAtMs;
  final String goalTitle;
  final String bodySignal;
  final String emotionLabel;
  final String cognition;
  final String authenticTruth;
  final String feedbackSource;
  final String feedbackContent;
  final String feedbackLearning;
  final String corePattern;
  final String coreValue;
  final String actionExperiment;
  final String actionWhen;
  final String actionEvidence;
  final String followUpQuestion;
  final String reviewMode;

  factory TodoGoalReflection.fromMap(Map<String, Object?> row) => TodoGoalReflection(
        reflectionId: (row['reflection_id'] ?? '').toString(),
        goalId: (row['goal_id'] ?? '').toString(),
        stepId: (row['step_id'] ?? '').toString(),
        reflectionDate: (row['reflection_date'] ?? '').toString(),
        whatDone: (row['what_done'] ?? '').toString(),
        whyDone: (row['why_done'] ?? '').toString(),
        processExperience: (row['process_experience'] ?? '').toString(),
        obstacle: (row['obstacle'] ?? '').toString(),
        tomorrowNextStep: (row['tomorrow_next_step'] ?? '').toString(),
        aiSummary: (row['ai_summary'] ?? '').toString(),
        moodScore: _toInt(row['mood_score']),
        meaningScore: _toInt(row['meaning_score']),
        processScore: _toInt(row['process_score']),
        createdAtMs: _toInt(row['created_at_ms']),
        goalTitle: (row['goal_title'] ?? '').toString(),
        bodySignal: (row['body_signal'] ?? '').toString(),
        emotionLabel: (row['emotion_label'] ?? '').toString(),
        cognition: (row['cognition'] ?? '').toString(),
        authenticTruth: (row['authentic_truth'] ?? '').toString(),
        feedbackSource: (row['feedback_source'] ?? '').toString(),
        feedbackContent: (row['feedback_content'] ?? '').toString(),
        feedbackLearning: (row['feedback_learning'] ?? '').toString(),
        corePattern: (row['core_pattern'] ?? '').toString(),
        coreValue: (row['core_value'] ?? '').toString(),
        actionExperiment: (row['action_experiment'] ?? '').toString(),
        actionWhen: (row['action_when'] ?? '').toString(),
        actionEvidence: (row['action_evidence'] ?? '').toString(),
        followUpQuestion: (row['follow_up_question'] ?? '').toString(),
        reviewMode: (row['review_mode'] ?? 'daily').toString(),
      );
}



class TodoGoalSolutionGenerationResult {
  const TodoGoalSolutionGenerationResult({
    required this.plans,
    required this.provider,
    required this.modelLabel,
    this.rawResponse = '',
    this.usedFallback = false,
  });

  final List<TodoGoalSolutionPlan> plans;
  final String provider;
  final String modelLabel;
  final String rawResponse;
  final bool usedFallback;

  Map<String, Object?> toJson() => <String, Object?>{
        'plans': plans.map((plan) => plan.toJson()).toList(),
        'provider': provider,
        'modelLabel': modelLabel,
        'usedFallback': usedFallback,
      };
}

class TodoGoalSolutionPlan {
  const TodoGoalSolutionPlan({
    required this.solutionId,
    required this.goalId,
    required this.sourceTaskId,
    required this.title,
    required this.methodName,
    required this.methodBasis,
    required this.zoneType,
    required this.coreValueFocus,
    required this.summary,
    required this.riskNotes,
    required this.isSelected,
    required this.status,
    required this.sortOrder,
    required this.rawJson,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.nodes = const <TodoGoalProblemNode>[],
    this.problemDefinition = '',
    this.knownFacts = '',
    this.keyAssumptions = '',
    this.rootCauseAnalysis = '',
    this.optionComparison = '',
    this.evidencePlan = '',
    this.successMetrics = '',
    this.stopConditions = '',
    this.userChoiceGuidance = '',
  });

  final String solutionId;
  final String goalId;
  final String sourceTaskId;
  final String title;
  final String methodName;
  final String methodBasis;
  final String zoneType;
  final String coreValueFocus;
  final String summary;
  final String riskNotes;
  final bool isSelected;
  final String status;
  final int sortOrder;
  final String rawJson;
  final int createdAtMs;
  final int updatedAtMs;
  final List<TodoGoalProblemNode> nodes;
  final String problemDefinition;
  final String knownFacts;
  final String keyAssumptions;
  final String rootCauseAnalysis;
  final String optionComparison;
  final String evidencePlan;
  final String successMetrics;
  final String stopConditions;
  final String userChoiceGuidance;

  bool get isComfort => zoneType == 'comfort';
  bool get isStretch => zoneType == 'stretch';
  bool get isPanic => zoneType == 'panic';
  String get zoneLabel => zoneType == 'comfort' ? '舒适区方案' : (zoneType == 'panic' ? '恐慌区方案' : '拉伸区方案');

  factory TodoGoalSolutionPlan.fromMap(Map<String, Object?> row) => TodoGoalSolutionPlan(
        solutionId: _firstText(row, const ['solution_id', 'plan_id']),
        goalId: _firstText(row, const ['goal_id']),
        sourceTaskId: _firstText(row, const ['source_task_id', 'task_id']),
        title: _firstText(row, const ['title', 'plan_title', 'plan_name'], 'AI问题解决方案'),
        methodName: _firstText(row, const ['method_name', 'scientific_method', 'method'], '科学问题解决法'),
        methodBasis: _firstText(row, const ['method_basis', 'basis'], '问题分解、执行意图、反馈调节'),
        zoneType: _normalizeZoneValue(_firstText(row, const ['zone_type', 'zone'], 'stretch')),
        coreValueFocus: _firstText(row, const ['core_value_focus', 'value_focus']),
        summary: _firstText(row, const ['summary', 'plan_summary']),
        riskNotes: _firstText(row, const ['risk_notes', 'risk_note']),
        isSelected: _toInt(row['is_selected']) == 1,
        status: (row['status'] ?? 'candidate').toString(),
        sortOrder: _toInt(row['sort_order']),
        rawJson: (row['raw_json'] ?? '').toString(),
        createdAtMs: _toInt(row['created_at_ms']),
        updatedAtMs: _toInt(row['updated_at_ms']),
        problemDefinition: (row['problem_definition'] ?? '').toString(),
        knownFacts: (row['known_facts'] ?? '').toString(),
        keyAssumptions: (row['key_assumptions'] ?? '').toString(),
        rootCauseAnalysis: (row['root_cause_analysis'] ?? '').toString(),
        optionComparison: (row['option_comparison'] ?? '').toString(),
        evidencePlan: (row['evidence_plan'] ?? '').toString(),
        successMetrics: (row['success_metrics'] ?? '').toString(),
        stopConditions: (row['stop_conditions'] ?? '').toString(),
        userChoiceGuidance: (row['user_choice_guidance'] ?? '').toString(),
      );

  factory TodoGoalSolutionPlan.fromJson(Map<String, dynamic> json, {int sortOrder = 0}) {
    final nodesRaw = _readJsonListAny(json, const <String>[
      'nodes',
      'problemNodes',
      'problem_nodes',
      'problemTree',
      'problem_tree',
      'tree',
      'steps',
      '问题树',
      '问题节点',
      '节点',
      '子问题',
      '步骤',
    ]);
    final nodes = <TodoGoalProblemNode>[];
    for (var i = 0; i < nodesRaw.length; i++) {
      final item = nodesRaw[i];
      if (item is Map<String, dynamic>) {
        nodes.add(TodoGoalProblemNode.fromJson(item, sequenceOrder: i));
      } else if (item is Map) {
        nodes.add(TodoGoalProblemNode.fromJson(Map<String, dynamic>.from(item), sequenceOrder: i));
      }
    }
    return TodoGoalSolutionPlan(
      solutionId: '',
      goalId: '',
      sourceTaskId: '',
      title: _readJsonTextAny(json, const <String>['title', 'planTitle', 'plan_title', 'planName', 'plan_name', 'name', '方案名称', '方案标题', '标题'], '问题解决方案'),
      methodName: _readJsonTextAny(json, const <String>['methodName', 'method_name', 'scientificMethod', 'scientific_method', 'method', '方法', '科学方法', '问题解决方法'], '科学问题解决法'),
      methodBasis: _readJsonTextAny(json, const <String>['methodBasis', 'method_basis', 'basis', 'scientificBasis', 'scientific_basis', '依据', '科学依据', '方法依据'], '问题分解、执行意图、反馈调节'),
      zoneType: _normalizeZoneValue(_readJsonTextAny(json, const <String>['zoneType', 'zone_type', 'zone', 'difficultyZone', 'difficulty_zone', '区域', '难度区间'], 'stretch')),
      coreValueFocus: _readJsonTextAny(json, const <String>['coreValueFocus', 'core_value_focus', 'valueFocus', 'value_focus', '核心价值', '价值焦点', '价值体系体现'], '目标服务当下、过程重于抵达、自我和谐、拉伸而非恐慌'),
      summary: _readJsonTextAny(json, const <String>['summary', 'planSummary', 'plan_summary', '摘要', '方案摘要'], ''),
      riskNotes: _readJsonTextAny(json, const <String>['riskNotes', 'risk_notes', 'riskNote', 'risk_note', 'risks', '风险', '风险说明', '适用边界'], ''),
      isSelected: false,
      status: 'candidate',
      sortOrder: sortOrder,
      rawJson: '',
      createdAtMs: 0,
      updatedAtMs: 0,
      nodes: nodes,
      problemDefinition: _readJsonTextAny(json, const <String>['problemDefinition', 'problem_definition', '问题定义'], ''),
      knownFacts: _readJsonTextAny(json, const <String>['knownFacts', 'known_facts', '已知事实'], ''),
      keyAssumptions: _readJsonTextAny(json, const <String>['keyAssumptions', 'key_assumptions', '关键假设'], ''),
      rootCauseAnalysis: _readJsonTextAny(json, const <String>['rootCauseAnalysis', 'root_cause_analysis', '根因分析'], ''),
      optionComparison: _readJsonTextAny(json, const <String>['optionComparison', 'option_comparison', '方案比较'], ''),
      evidencePlan: _readJsonTextAny(json, const <String>['evidencePlan', 'evidence_plan', '证据计划'], ''),
      successMetrics: _readJsonTextAny(json, const <String>['successMetrics', 'success_metrics', '成功指标'], ''),
      stopConditions: _readJsonTextAny(json, const <String>['stopConditions', 'stop_conditions', '停止条件'], ''),
      userChoiceGuidance: _readJsonTextAny(json, const <String>['userChoiceGuidance', 'user_choice_guidance', '用户选择建议'], ''),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'solutionId': solutionId,
        'goalId': goalId,
        'sourceTaskId': sourceTaskId,
        'title': title,
        'methodName': methodName,
        'methodBasis': methodBasis,
        'zoneType': zoneType,
        'coreValueFocus': coreValueFocus,
        'summary': summary,
        'riskNotes': riskNotes,
        'isSelected': isSelected,
        'status': status,
        'sortOrder': sortOrder,
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'problemDefinition': problemDefinition,
        'knownFacts': knownFacts,
        'keyAssumptions': keyAssumptions,
        'rootCauseAnalysis': rootCauseAnalysis,
        'optionComparison': optionComparison,
        'evidencePlan': evidencePlan,
        'successMetrics': successMetrics,
        'stopConditions': stopConditions,
        'userChoiceGuidance': userChoiceGuidance,
      };
}

class TodoGoalProblemNode {
  const TodoGoalProblemNode({
    required this.nodeId,
    required this.goalId,
    required this.solutionId,
    required this.parentNodeId,
    required this.relationType,
    required this.nodeType,
    required this.title,
    required this.description,
    required this.acceptanceCriteria,
    required this.actionableStep,
    required this.zoneType,
    required this.difficultyScore,
    required this.estimatedMinutes,
    required this.sequenceOrder,
    required this.dependenciesJson,
    required this.status,
    required this.completionNote,
    required this.aiReviewJson,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.tempNodeId = '',
    this.tempParentNodeId = '',
    this.logicQuestion = '',
    this.knownFacts = '',
    this.assumptions = '',
    this.evidenceNeeded = '',
    this.decisionRule = '',
    this.actionWhen = '',
    this.actionWhere = '',
    this.actionObject = '',
    this.actionProcedure = '',
    this.actionOutput = '',
  });

  final String nodeId;
  final String goalId;
  final String solutionId;
  final String parentNodeId;
  final String relationType;
  final String nodeType;
  final String title;
  final String description;
  final String acceptanceCriteria;
  final String actionableStep;
  final String zoneType;
  final int difficultyScore;
  final int estimatedMinutes;
  final int sequenceOrder;
  final String dependenciesJson;
  final String status;
  final String completionNote;
  final String aiReviewJson;
  final int createdAtMs;
  final int updatedAtMs;
  final String tempNodeId;
  final String tempParentNodeId;
  final String logicQuestion;
  final String knownFacts;
  final String assumptions;
  final String evidenceNeeded;
  final String decisionRule;
  final String actionWhen;
  final String actionWhere;
  final String actionObject;
  final String actionProcedure;
  final String actionOutput;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isActionable => actionableStep.trim().isNotEmpty || nodeType == 'action';
  bool get hasConcreteActionContract => actionWhen.trim().isNotEmpty && actionWhere.trim().isNotEmpty && actionObject.trim().isNotEmpty && actionProcedure.trim().isNotEmpty && actionOutput.trim().isNotEmpty && acceptanceCriteria.trim().isNotEmpty;
  String get displayAction => actionableStep.trim().isEmpty ? title : actionableStep.trim();
  String get concreteActionText => <String>[
        '时间/触发：$actionWhen',
        '地点/工具：$actionWhere',
        '对象：$actionObject',
        '步骤：$actionProcedure',
        '产出：$actionOutput',
      ].join('；');

  List<String> get resolvedDependencyNodeIds {
    final raw = dependenciesJson.trim();
    if (raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toList(growable: false);
      }
    } catch (_) {
      // Legacy AI responses may have stored Dart-style list strings.
    }
    return raw
        .replaceAll(RegExp(r'^[\[\{]+|[\]\}]+$'), '')
        .split(RegExp(r'[,，、|]'))
        .map((value) => value.replaceAll(RegExp(r'''^[\s"']+|[\s"']+$'''), '').trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String get relationTypeLabel {
    switch (relationType.trim().toLowerCase()) {
      case 'and':
        return '全部子问题都要解决';
      case 'or':
        return '任选一条有效路径';
      case 'sequence':
        return '按顺序推进';
      case 'dependency':
      case 'network':
        return '存在交叉依赖';
      default:
        return '父子分解';
    }
  }

  factory TodoGoalProblemNode.fromMap(Map<String, Object?> row) => TodoGoalProblemNode(
        nodeId: (row['node_id'] ?? '').toString(),
        goalId: (row['goal_id'] ?? '').toString(),
        solutionId: (row['solution_id'] ?? '').toString(),
        parentNodeId: (row['parent_node_id'] ?? '').toString(),
        relationType: (row['relation_type'] ?? 'tree').toString(),
        nodeType: (row['node_type'] ?? 'problem').toString(),
        title: (row['title'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        acceptanceCriteria: (row['acceptance_criteria'] ?? '').toString(),
        actionableStep: (row['actionable_step'] ?? '').toString(),
        zoneType: _normalizeZoneValue((row['zone_type'] ?? 'stretch').toString()),
        difficultyScore: _toInt(row['difficulty_score']) == 0 ? 5 : _toInt(row['difficulty_score']),
        estimatedMinutes: _toInt(row['estimated_minutes']),
        sequenceOrder: _toInt(row['sequence_order']),
        dependenciesJson: (row['dependencies_json'] ?? '').toString(),
        status: (row['status'] ?? 'not_started').toString(),
        completionNote: (row['completion_note'] ?? '').toString(),
        aiReviewJson: (row['ai_review_json'] ?? '').toString(),
        createdAtMs: _toInt(row['created_at_ms']),
        updatedAtMs: _toInt(row['updated_at_ms']),
        logicQuestion: (row['logic_question'] ?? '').toString(),
        knownFacts: (row['known_facts'] ?? '').toString(),
        assumptions: (row['assumptions'] ?? '').toString(),
        evidenceNeeded: (row['evidence_needed'] ?? '').toString(),
        decisionRule: (row['decision_rule'] ?? '').toString(),
        actionWhen: (row['action_when'] ?? '').toString(),
        actionWhere: (row['action_where'] ?? '').toString(),
        actionObject: (row['action_object'] ?? '').toString(),
        actionProcedure: (row['action_procedure'] ?? '').toString(),
        actionOutput: (row['action_output'] ?? '').toString(),
      );

  factory TodoGoalProblemNode.fromJson(Map<String, dynamic> json, {int sequenceOrder = 0}) => TodoGoalProblemNode(
        nodeId: '',
        goalId: '',
        solutionId: '',
        parentNodeId: '',
        relationType: _readJsonTextAny(json, const <String>['relationType', 'relation_type', 'relation', '关系类型'], 'tree'),
        nodeType: _readJsonTextAny(json, const <String>['nodeType', 'node_type', 'type', '节点类型', '类型'], 'problem'),
        title: _readJsonTextAny(json, const <String>['title', 'nodeTitle', 'node_title', 'name', '标题', '节点标题', '子问题'], '子问题'),
        description: _readJsonTextAny(json, const <String>['description', 'desc', '说明', '描述'], ''),
        acceptanceCriteria: _readJsonTextAny(json, const <String>['acceptanceCriteria', 'acceptance_criteria', 'doneCriteria', 'done_criteria', 'completionCriteria', '完成标准', '验收标准'], '能用事实判断是否完成'),
        actionableStep: _readJsonTextAny(json, const <String>['actionableStep', 'actionable_step', 'action', 'step', '具体行动', '可执行动作', '行动', '最小行动'], ''),
        zoneType: _normalizeZoneValue(_readJsonTextAny(json, const <String>['zoneType', 'zone_type', 'zone', '难度区间', '区域'], 'stretch')),
        difficultyScore: _readJsonIntAny(json, const <String>['difficultyScore', 'difficulty_score', 'difficulty', '难度', '难度分'], 5),
        estimatedMinutes: _readJsonIntAny(json, const <String>['estimatedMinutes', 'estimated_minutes', 'minutes', 'durationMinutes', '预计分钟', '耗时分钟'], 5),
        sequenceOrder: _readJsonIntAny(json, const <String>['sequenceOrder', 'sequence_order', 'sortOrder', 'sort_order', 'order', '顺序'], sequenceOrder),
        dependenciesJson: _encodeJsonField(_readJsonDynamic(json, const <String>['dependencies', 'dependenciesJson', 'dependencies_json', '依赖'])),
        status: 'not_started',
        completionNote: '',
        aiReviewJson: '',
        createdAtMs: 0,
        updatedAtMs: 0,
        tempNodeId: _readJsonTextAny(json, const <String>['id', 'nodeId', 'node_id', '节点ID'], ''),
        tempParentNodeId: _readJsonTextAny(json, const <String>['parentId', 'parentNodeId', 'parent_node_id', 'parent_id', '父节点ID'], ''),
        logicQuestion: _readJsonTextAny(json, const <String>['logicQuestion', 'logic_question', '逻辑问题'], ''),
        knownFacts: _readJsonTextAny(json, const <String>['knownFacts', 'known_facts', '已知事实'], ''),
        assumptions: _readJsonTextAny(json, const <String>['assumptions', '假设'], ''),
        evidenceNeeded: _readJsonTextAny(json, const <String>['evidenceNeeded', 'evidence_needed', '所需证据'], ''),
        decisionRule: _readJsonTextAny(json, const <String>['decisionRule', 'decision_rule', '判断规则'], ''),
        actionWhen: _readJsonTextAny(json, const <String>['actionWhen', 'action_when', 'when', '时间触发', '时间', '触发'], ''),
        actionWhere: _readJsonTextAny(json, const <String>['actionWhere', 'action_where', 'where', '地点工具', '地点', '工具'], ''),
        actionObject: _readJsonTextAny(json, const <String>['actionObject', 'action_object', 'object', '行动对象', '对象'], ''),
        actionProcedure: _readJsonTextAny(json, const <String>['actionProcedure', 'action_procedure', 'procedure', 'steps', '操作步骤', '步骤'], ''),
        actionOutput: _readJsonTextAny(json, const <String>['actionOutput', 'action_output', 'output', 'deliverable', '产出物', '产出'], ''),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'nodeId': nodeId,
        'goalId': goalId,
        'solutionId': solutionId,
        'parentNodeId': parentNodeId,
        'relationType': relationType,
        'nodeType': nodeType,
        'title': title,
        'description': description,
        'acceptanceCriteria': acceptanceCriteria,
        'actionableStep': actionableStep,
        'zoneType': zoneType,
        'difficultyScore': difficultyScore,
        'estimatedMinutes': estimatedMinutes,
        'sequenceOrder': sequenceOrder,
        'dependenciesJson': dependenciesJson,
        'status': status,
        'completionNote': completionNote,
        'logicQuestion': logicQuestion,
        'knownFacts': knownFacts,
        'assumptions': assumptions,
        'evidenceNeeded': evidenceNeeded,
        'decisionRule': decisionRule,
        'actionWhen': actionWhen,
        'actionWhere': actionWhere,
        'actionObject': actionObject,
        'actionProcedure': actionProcedure,
        'actionOutput': actionOutput,
      };
}

class TodoGoalAlternativeStep {
  const TodoGoalAlternativeStep({
    required this.title,
    required this.rationale,
    required this.minimumStandard,
    required this.recommendedStandard,
    required this.zoneType,
    required this.difficultyScore,
    this.actionWhen = '',
    this.actionWhere = '',
    this.actionObject = '',
    this.actionProcedure = '',
    this.actionOutput = '',
  });

  final String title;
  final String rationale;
  final String minimumStandard;
  final String recommendedStandard;
  final String zoneType;
  final int difficultyScore;
  final String actionWhen;
  final String actionWhere;
  final String actionObject;
  final String actionProcedure;
  final String actionOutput;

  factory TodoGoalAlternativeStep.fromJson(Map<String, dynamic> json) => TodoGoalAlternativeStep(
        title: _readJsonTextAny(json, const <String>['title', 'action', 'step', 'name', '标题', '行动', '替代步骤'], '替代步骤'),
        rationale: _readJsonTextAny(json, const <String>['rationale', 'why', 'reason', '理由', '为什么更适合'], '让步骤更小、更清晰、更贴近当前阻力。'),
        minimumStandard: _readJsonTextAny(json, const <String>['minimumStandard', 'minimum_standard', '最低标准'], '先做2-5分钟，能开始即可。'),
        recommendedStandard: _readJsonTextAny(json, const <String>['recommendedStandard', 'recommended_standard', '推荐标准'], '完成一个可观察动作并记录事实。'),
        zoneType: _normalizeZoneValue(_readJsonTextAny(json, const <String>['zoneType', 'zone_type', 'zone', '难度区间'], 'stretch')),
        difficultyScore: _readJsonIntAny(json, const <String>['difficultyScore', 'difficulty_score', 'difficulty', '难度'], 3),
        actionWhen: _readJsonTextAny(json, const <String>['actionWhen', 'action_when', 'when', '时间触发'], ''),
        actionWhere: _readJsonTextAny(json, const <String>['actionWhere', 'action_where', 'where', '地点工具'], ''),
        actionObject: _readJsonTextAny(json, const <String>['actionObject', 'action_object', 'object', '行动对象'], ''),
        actionProcedure: _readJsonTextAny(json, const <String>['actionProcedure', 'action_procedure', 'procedure', '操作步骤'], ''),
        actionOutput: _readJsonTextAny(json, const <String>['actionOutput', 'action_output', 'output', '产出物'], ''),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'title': title,
        'rationale': rationale,
        'minimumStandard': minimumStandard,
        'recommendedStandard': recommendedStandard,
        'zoneType': zoneType,
        'difficultyScore': difficultyScore,
        'actionWhen': actionWhen,
        'actionWhere': actionWhere,
        'actionObject': actionObject,
        'actionProcedure': actionProcedure,
        'actionOutput': actionOutput,
      };
}

class TodoGoalStepRecoveryResult {
  const TodoGoalStepRecoveryResult({
    required this.failureDiagnosis,
    required this.restartGuidance,
    required this.principleFit,
    required this.alternatives,
    required this.restructureWarning,
    required this.provider,
    required this.modelLabel,
    this.rawResponse = '',
    this.usedFallback = false,
  });

  final String failureDiagnosis;
  final String restartGuidance;
  final String principleFit;
  final List<TodoGoalAlternativeStep> alternatives;
  final String restructureWarning;
  final String provider;
  final String modelLabel;
  final String rawResponse;
  final bool usedFallback;

  Map<String, Object?> toJson() => <String, Object?>{
        'failureDiagnosis': failureDiagnosis,
        'restartGuidance': restartGuidance,
        'principleFit': principleFit,
        'alternatives': alternatives.map((e) => e.toJson()).toList(),
        'restructureWarning': restructureWarning,
        'provider': provider,
        'modelLabel': modelLabel,
        'usedFallback': usedFallback,
      };
}


String _encodeJsonField(Object? value) {
  if (value == null) return '';
  if (value is List || value is Map) return jsonEncode(value);
  return value.toString().trim();
}

Object? _readJsonDynamic(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  return null;
}

String _readJsonText(Map<String, dynamic> json, String key, String fallback) {
  return _readJsonTextAny(json, <String>[key], fallback);
}

String _readJsonTextAny(Map<String, dynamic> json, List<String> keys, String fallback) {
  final value = _readJsonDynamic(json, keys);
  final text = value == null ? '' : value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _readJsonIntAny(Map<String, dynamic> json, List<String> keys, int fallback) {
  final value = _readJsonDynamic(json, keys);
  if (value is int) return value == 0 ? fallback : value;
  if (value is num) return value.toInt() == 0 ? fallback : value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<dynamic> _readJsonListAny(Map<String, dynamic> json, List<String> keys) {
  final value = _readJsonDynamic(json, keys);
  return value is List ? value : <dynamic>[];
}

String _normalizeZoneValue(String value) {
  final v = value.trim().toLowerCase();
  if (v.contains('panic') || v.contains('恐慌')) return 'panic';
  if (v.contains('comfort') || v.contains('舒适')) return 'comfort';
  return 'stretch';
}

class TodoGoalRitual {
  const TodoGoalRitual({
    required this.ritualId,
    required this.goalId,
    required this.triggerText,
    required this.minimumAction,
    required this.minimumMinutes,
    required this.rewardOrRecord,
    required this.environmentDesign,
    required this.frictionPlan,
    required this.stabilityScore,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.goalTitle = '',
    this.checkInCount = 0,
    this.completedCheckIns = 0,
    this.blockedCheckIns = 0,
    this.lastCheckInAtMs = 0,
  });

  final String ritualId;
  final String goalId;
  final String triggerText;
  final String minimumAction;
  final int minimumMinutes;
  final String rewardOrRecord;
  final String environmentDesign;
  final String frictionPlan;
  final int stabilityScore;
  final String status;
  final int createdAtMs;
  final int updatedAtMs;
  final String goalTitle;
  final int checkInCount;
  final int completedCheckIns;
  final int blockedCheckIns;
  final int lastCheckInAtMs;

  factory TodoGoalRitual.fromMap(Map<String, Object?> row) => TodoGoalRitual(
        ritualId: (row['ritual_id'] ?? '').toString(),
        goalId: (row['goal_id'] ?? '').toString(),
        triggerText: (row['trigger_text'] ?? '').toString(),
        minimumAction: (row['minimum_action'] ?? '').toString(),
        minimumMinutes: _toInt(row['minimum_minutes']),
        rewardOrRecord: (row['reward_or_record'] ?? '').toString(),
        environmentDesign: (row['environment_design'] ?? '').toString(),
        frictionPlan: (row['friction_plan'] ?? '').toString(),
        stabilityScore: _toInt(row['stability_score']),
        status: (row['status'] ?? 'active').toString(),
        createdAtMs: _toInt(row['created_at_ms']),
        updatedAtMs: _toInt(row['updated_at_ms']),
        goalTitle: (row['goal_title'] ?? '').toString(),
        checkInCount: _toInt(row['check_in_count']),
        completedCheckIns: _toInt(row['completed_check_ins']),
        blockedCheckIns: _toInt(row['blocked_check_ins']),
        lastCheckInAtMs: _toInt(row['last_check_in_at_ms']),
      );
}

class TodoGoalEffortEntry {
  const TodoGoalEffortEntry({
    required this.entryId,
    required this.goalId,
    required this.stepId,
    required this.effortDate,
    required this.effortMinutes,
    required this.energyLevel,
    required this.emotionState,
    required this.availableMinutes,
    required this.zoneType,
    required this.effortType,
    required this.investmentText,
    required this.obstacle,
    required this.strategyUsed,
    required this.smallProgress,
    required this.nextMinimumStep,
    required this.timeInLearning,
    required this.identityEvidence,
    required this.gratitudeText,
    required this.joyScore,
    required this.reflectionDepth,
    required this.strategyChanged,
    required this.returnedAfterBreak,
    required this.createdAtMs,
    this.goalTitle = '',
    this.frictionCategory = '',
    this.effortContext = '',
    this.cycleStage = '',
    this.relationshipQuality = 0,
    this.recoveryGapHours = 0,
  });

  final String entryId;
  final String goalId;
  final String stepId;
  final String effortDate;
  final int effortMinutes;
  final String energyLevel;
  final String emotionState;
  final int availableMinutes;
  final String zoneType;
  final String effortType;
  final String investmentText;
  final String obstacle;
  final String strategyUsed;
  final String smallProgress;
  final String nextMinimumStep;
  final String timeInLearning;
  final String identityEvidence;
  final String gratitudeText;
  final int joyScore;
  final int reflectionDepth;
  final bool strategyChanged;
  final bool returnedAfterBreak;
  final int createdAtMs;
  final String goalTitle;
  final String frictionCategory;
  final String effortContext;
  final String cycleStage;
  final int relationshipQuality;
  final int recoveryGapHours;

  String get zoneLabel => zoneType == 'comfort' ? '舒适区' : (zoneType == 'panic' ? '恐慌区' : '拉伸区');
  String get effortTypeLabel {
    switch (effortType) {
      case 'relationship': return '关系投入';
      case 'deep_work': return '深度努力';
      case 'recovery': return '恢复与孵化';
      default: return '目标行动';
    }
  }

  String get frictionLabel {
    switch (frictionCategory) {
      case 'too_hard': return '任务太难或太大';
      case 'too_busy': return '时间不足';
      case 'too_tired': return '精力不足';
      case 'forgot': return '触发器不清楚';
      case 'no_meaning': return '意义感不足';
      case 'emotion_low': return '情绪阻力';
      case 'environment': return '环境或工具阻力';
      default: return obstacle.trim();
    }
  }

  String get contextLabel {
    switch (effortContext) {
      case 'partner': return '伴侣';
      case 'parent': return '父母';
      case 'child': return '孩子';
      case 'friend': return '朋友';
      case 'colleague': return '同事';
      case 'self': return '自己';
      default: return '';
    }
  }

  String get cycleStageLabel {
    switch (cycleStage) {
      case 'prepare': return '准备';
      case 'immerse': return '沉浸';
      case 'incubate': return '孵化';
      case 'insight': return '洞察';
      case 'polish': return '打磨';
      default: return '';
    }
  }

  factory TodoGoalEffortEntry.fromMap(Map<String, Object?> row) => TodoGoalEffortEntry(
        entryId: (row['entry_id'] ?? '').toString(),
        goalId: (row['goal_id'] ?? '').toString(),
        stepId: (row['step_id'] ?? '').toString(),
        effortDate: (row['effort_date'] ?? '').toString(),
        effortMinutes: _toInt(row['effort_minutes']),
        energyLevel: (row['energy_level'] ?? 'medium').toString(),
        emotionState: (row['emotion_state'] ?? 'stable').toString(),
        availableMinutes: _toInt(row['available_minutes']),
        zoneType: (row['zone_type'] ?? 'stretch').toString(),
        effortType: (row['effort_type'] ?? 'goal').toString(),
        investmentText: (row['investment_text'] ?? '').toString(),
        obstacle: (row['obstacle'] ?? '').toString(),
        strategyUsed: (row['strategy_used'] ?? '').toString(),
        smallProgress: (row['small_progress'] ?? '').toString(),
        nextMinimumStep: (row['next_minimum_step'] ?? '').toString(),
        timeInLearning: (row['time_in_learning'] ?? '').toString(),
        identityEvidence: (row['identity_evidence'] ?? '').toString(),
        gratitudeText: (row['gratitude_text'] ?? '').toString(),
        joyScore: _toInt(row['joy_score']),
        reflectionDepth: _toInt(row['reflection_depth']),
        strategyChanged: _toInt(row['strategy_changed']) == 1,
        returnedAfterBreak: _toInt(row['returned_after_break']) == 1,
        createdAtMs: _toInt(row['created_at_ms']),
        goalTitle: (row['goal_title'] ?? '').toString(),
        frictionCategory: (row['friction_category'] ?? '').toString(),
        effortContext: (row['effort_context'] ?? '').toString(),
        cycleStage: (row['cycle_stage'] ?? '').toString(),
        relationshipQuality: _toInt(row['relationship_quality']),
        recoveryGapHours: _toInt(row['recovery_gap_hours']),
      );
}

class TodoGoalEffortSummary {
  const TodoGoalEffortSummary({
    required this.meaningfulEfforts,
    required this.effortMinutes,
    required this.returnCount,
    required this.stretchCount,
    required this.reflectionCount,
    required this.strategyChangeCount,
    required this.relationshipInvestmentCount,
    required this.averageJoy,
    required this.commonObstacle,
    this.panicCount = 0,
    this.ritualCount = 0,
    this.ritualStability = 0,
    this.adaptiveRitualCount = 0,
    this.averageRecoveryHours = 0,
    this.bestHourLabel = '',
  });

  final int meaningfulEfforts;
  final int effortMinutes;
  final int returnCount;
  final int stretchCount;
  final int reflectionCount;
  final int strategyChangeCount;
  final int relationshipInvestmentCount;
  final double averageJoy;
  final String commonObstacle;
  final int panicCount;
  final int ritualCount;
  final double ritualStability;
  final int adaptiveRitualCount;
  final double averageRecoveryHours;
  final String bestHourLabel;
}
