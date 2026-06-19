import 'dart:convert';

String _str(dynamic v, [String fallback = '']) => (v ?? fallback).toString();
int _int(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse((v ?? '').toString()) ?? fallback;
List<String> _stringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  if (v is String && v.trim().isNotEmpty) return <String>[v.trim()];
  return <String>[];
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  return <Map<String, dynamic>>[];
}

class SustainableSpiralStage {
  static const String goal = 'goal';
  static const String experiment = 'experiment';
  static const String action = 'action';
  static const String failedOrStuck = 'failed_or_stuck';
  static const String recovery = 'recovery';
  static const String feedback = 'feedback';
  static const String adjustment = 'adjustment';
  static const String restart = 'restart';
  static const String completedCycle = 'completed_cycle';

  static String label(String stage) {
    switch (stage) {
      case action:
        return '行动中';
      case failedOrStuck:
        return '失败/卡住';
      case recovery:
        return '恢复';
      case feedback:
        return '反馈';
      case adjustment:
        return '修正';
      case restart:
        return '再行动';
      case completedCycle:
        return '完成一轮螺旋';
      case experiment:
        return '实验设计';
      default:
        return '目标';
    }
  }

  static String next(String stage) {
    switch (stage) {
      case goal:
        return experiment;
      case experiment:
        return action;
      case action:
        return feedback;
      case failedOrStuck:
        return recovery;
      case recovery:
        return adjustment;
      case feedback:
        return adjustment;
      case adjustment:
        return restart;
      case restart:
        return completedCycle;
      default:
        return experiment;
    }
  }
}

class SustainableModeDetection {
  final String pressureLevel;
  final String recoveryLevel;
  final String perfectionismLevel;
  final String failureFearLevel;
  final String processConnectionLevel;

  const SustainableModeDetection({
    required this.pressureLevel,
    required this.recoveryLevel,
    required this.perfectionismLevel,
    required this.failureFearLevel,
    required this.processConnectionLevel,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'pressure_level': pressureLevel,
        'recovery_level': recoveryLevel,
        'perfectionism_level': perfectionismLevel,
        'failure_fear_level': failureFearLevel,
        'process_connection_level': processConnectionLevel,
      };

  static SustainableModeDetection fromJson(dynamic json) {
    final m = _map(json);
    return SustainableModeDetection(
      pressureLevel: _str(m['pressure_level'], 'medium'),
      recoveryLevel: _str(m['recovery_level'], 'insufficient'),
      perfectionismLevel: _str(m['perfectionism_level'], 'medium'),
      failureFearLevel: _str(m['failure_fear_level'], 'medium'),
      processConnectionLevel: _str(m['process_connection_level'], 'low'),
    );
  }
}

class SustainableValueMapping {
  final List<String> preserve;
  final List<String> adjust;
  final String coreReframe;

  const SustainableValueMapping({required this.preserve, required this.adjust, required this.coreReframe});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'preserve': preserve,
        'adjust': adjust,
        'core_reframe': coreReframe,
      };

  static SustainableValueMapping fromJson(dynamic json) {
    final m = _map(json);
    return SustainableValueMapping(
      preserve: _stringList(m['preserve']),
      adjust: _stringList(m['adjust']),
      coreReframe: _str(m['core_reframe'], '不是降低追求，而是把完美主义直线改造成压力、恢复、失败、反馈与过程组成的卓越螺旋。'),
    );
  }
}

class SustainableObstacleAnalysis {
  final String obstacle;
  final String evidence;
  final String changeableVariable;

  const SustainableObstacleAnalysis({required this.obstacle, required this.evidence, required this.changeableVariable});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'obstacle': obstacle,
        'evidence': evidence,
        'changeable_variable': changeableVariable,
      };

  static SustainableObstacleAnalysis fromJson(dynamic json) {
    final m = _map(json);
    return SustainableObstacleAnalysis(
      obstacle: _str(m['obstacle']),
      evidence: _str(m['evidence']),
      changeableVariable: _str(m['changeable_variable']),
    );
  }
}

class SustainableActionExperiment {
  final String type;
  final String title;
  final String suitableWhen;
  final List<String> steps;
  final String timeRequired;
  final String failurePoint;
  final String failureLearningMethod;
  final String recoveryBefore;
  final String recoveryAfter;
  final String processAnchor;

  const SustainableActionExperiment({
    required this.type,
    required this.title,
    required this.suitableWhen,
    required this.steps,
    required this.timeRequired,
    required this.failurePoint,
    required this.failureLearningMethod,
    required this.recoveryBefore,
    required this.recoveryAfter,
    required this.processAnchor,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'title': title,
        'suitable_when': suitableWhen,
        'steps': steps,
        'time_required': timeRequired,
        'failure_point': failurePoint,
        'failure_learning_method': failureLearningMethod,
        'recovery_before': recoveryBefore,
        'recovery_after': recoveryAfter,
        'process_anchor': processAnchor,
      };

  static SustainableActionExperiment fromJson(dynamic json) {
    final m = _map(json);
    return SustainableActionExperiment(
      type: _str(m['type'], 'minimum_action'),
      title: _str(m['title'], '最小行动实验'),
      suitableWhen: _str(m['suitable_when'], '适合能量较低、害怕开始或压力较高时使用。'),
      steps: _stringList(m['steps']),
      timeRequired: _str(m['time_required'], '5分钟'),
      failurePoint: _str(m['failure_point'], '任务过大或开始前自我审判。'),
      failureLearningMethod: _str(m['failure_learning_method'], '失败后只提取一个可改变变量，不做人格否定。'),
      recoveryBefore: _str(m['recovery_before'], '行动前做 3 次慢呼吸。'),
      recoveryAfter: _str(m['recovery_after'], '行动后离开屏幕 3 分钟。'),
      processAnchor: _str(m['process_anchor'], '我正在练习开始，而不是证明自己完美。'),
    );
  }
}

class SustainableRecoveryPlan {
  final List<String> microRecovery;
  final List<String> mediumRecovery;
  final List<String> deepRecovery;
  final String recommendedRhythm;

  const SustainableRecoveryPlan({
    required this.microRecovery,
    required this.mediumRecovery,
    required this.deepRecovery,
    required this.recommendedRhythm,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'micro_recovery': microRecovery,
        'medium_recovery': mediumRecovery,
        'deep_recovery': deepRecovery,
        'recommended_rhythm': recommendedRhythm,
      };

  static SustainableRecoveryPlan fromJson(dynamic json) {
    final m = _map(json);
    return SustainableRecoveryPlan(
      microRecovery: _stringList(m['micro_recovery']),
      mediumRecovery: _stringList(m['medium_recovery']),
      deepRecovery: _stringList(m['deep_recovery']),
      recommendedRhythm: _str(m['recommended_rhythm'], '25分钟行动 + 5分钟恢复'),
    );
  }
}

class SustainableFailureLearning {
  final String possibleFailureType;
  final String ifFailedThen;
  final String learningQuestion;
  final String nextSmallerExperiment;

  const SustainableFailureLearning({
    required this.possibleFailureType,
    required this.ifFailedThen,
    required this.learningQuestion,
    required this.nextSmallerExperiment,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'possible_failure_type': possibleFailureType,
        'if_failed_then': ifFailedThen,
        'learning_question': learningQuestion,
        'next_smaller_experiment': nextSmallerExperiment,
      };

  static SustainableFailureLearning fromJson(dynamic json) {
    final m = _map(json);
    return SustainableFailureLearning(
      possibleFailureType: _str(m['possible_failure_type'], '启动失败 / 完美主义拖延 / 恢复不足'),
      ifFailedThen: _str(m['if_failed_then'], '如果失败，先记录事实，再写一个可改变变量。'),
      learningQuestion: _str(m['learning_question'], '这次失败暴露的是任务大小、能量、环境、情绪，还是失败恐惧？'),
      nextSmallerExperiment: _str(m['next_smaller_experiment'], '把任务缩小到 5 分钟内能开始的一步。'),
    );
  }
}

class SustainableProcessEnjoyment {
  final String meaningConnection;
  final String onePercentExperience;
  final String duringActionReminder;
  final String afterActionReflection;

  const SustainableProcessEnjoyment({
    required this.meaningConnection,
    required this.onePercentExperience,
    required this.duringActionReminder,
    required this.afterActionReflection,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'meaning_connection': meaningConnection,
        'one_percent_experience': onePercentExperience,
        'during_action_reminder': duringActionReminder,
        'after_action_reflection': afterActionReflection,
      };

  static SustainableProcessEnjoyment fromJson(dynamic json) {
    final m = _map(json);
    return SustainableProcessEnjoyment(
      meaningConnection: _str(m['meaning_connection'], '这个行动连接到长期成长、能力和自由。'),
      onePercentExperience: _str(m['one_percent_experience'], '只寻找 1% 的掌控感或能力感。'),
      duringActionReminder: _str(m['during_action_reminder'], '我不需要完美完成，只需要真实开始并获得反馈。'),
      afterActionReflection: _str(m['after_action_reflection'], '这次行动里，哪一小部分值得保留？'),
    );
  }
}

class SustainableTodoWriteback {
  final String nextTodoTitle;
  final List<String> nextTodoSteps;
  final String parentGoal;
  final String statusLabel;
  final List<String> evidenceTags;

  const SustainableTodoWriteback({
    required this.nextTodoTitle,
    required this.nextTodoSteps,
    required this.parentGoal,
    required this.statusLabel,
    required this.evidenceTags,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'next_todo_title': nextTodoTitle,
        'next_todo_steps': nextTodoSteps,
        'parent_goal': parentGoal,
        'status_label': statusLabel,
        'evidence_tags': evidenceTags,
      };

  static SustainableTodoWriteback fromJson(dynamic json) {
    final m = _map(json);
    return SustainableTodoWriteback(
      nextTodoTitle: _str(m['next_todo_title'], '完成一个 5 分钟最小行动实验'),
      nextTodoSteps: _stringList(m['next_todo_steps']),
      parentGoal: _str(m['parent_goal']),
      statusLabel: _str(m['status_label'], 'attempted'),
      evidenceTags: _stringList(m['evidence_tags']),
    );
  }
}

class SustainableEvidenceLog {
  final String id;
  final String caseId;
  final String experimentType;
  final String type;
  final String title;
  final String note;
  final List<String> details;
  final String spiralStage;
  final String aiSummary;
  final String generatedTodoId;
  final int createdAtMs;

  const SustainableEvidenceLog({
    required this.id,
    required this.caseId,
    required this.experimentType,
    required this.type,
    required this.title,
    required this.note,
    required this.details,
    this.spiralStage = '',
    this.aiSummary = '',
    this.generatedTodoId = '',
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'case_id': caseId,
        'experiment_type': experimentType,
        'type': type,
        'title': title,
        'note': note,
        'details': details,
        'spiral_stage': spiralStage,
        'ai_summary': aiSummary,
        'generated_todo_id': generatedTodoId,
        'created_at_ms': createdAtMs,
      };

  static SustainableEvidenceLog fromJson(dynamic json) {
    final m = _map(json);
    return SustainableEvidenceLog(
      id: _str(m['id']),
      caseId: _str(m['case_id']),
      experimentType: _str(m['experiment_type']),
      type: _str(m['type'], 'action'),
      title: _str(m['title'], '成长证据'),
      note: _str(m['note']),
      details: _stringList(m['details']),
      spiralStage: _str(m['spiral_stage']),
      aiSummary: _str(m['ai_summary']),
      generatedTodoId: _str(m['generated_todo_id']),
      createdAtMs: _int(m['created_at_ms'], DateTime.now().millisecondsSinceEpoch),
    );
  }
}

class SustainableDailyReview {
  final String id;
  final String reviewType;
  final String title;
  final String summary;
  final List<String> actionEvidence;
  final List<String> failurePatterns;
  final List<String> recoveryInsights;
  final List<String> processInsights;
  final String nextOneVariable;
  final int createdAtMs;

  const SustainableDailyReview({
    required this.id,
    required this.reviewType,
    required this.title,
    required this.summary,
    required this.actionEvidence,
    required this.failurePatterns,
    required this.recoveryInsights,
    required this.processInsights,
    required this.nextOneVariable,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'review_type': reviewType,
        'title': title,
        'summary': summary,
        'action_evidence': actionEvidence,
        'failure_patterns': failurePatterns,
        'recovery_insights': recoveryInsights,
        'process_insights': processInsights,
        'next_one_variable': nextOneVariable,
        'created_at_ms': createdAtMs,
      };

  static SustainableDailyReview fromJson(dynamic json) {
    final m = _map(json);
    return SustainableDailyReview(
      id: _str(m['id'], 'sr_${DateTime.now().microsecondsSinceEpoch}'),
      reviewType: _str(m['review_type'], 'daily'),
      title: _str(m['title'], '可持续卓越复盘'),
      summary: _str(m['summary']),
      actionEvidence: _stringList(m['action_evidence']),
      failurePatterns: _stringList(m['failure_patterns']),
      recoveryInsights: _stringList(m['recovery_insights']),
      processInsights: _stringList(m['process_insights']),
      nextOneVariable: _str(m['next_one_variable']),
      createdAtMs: _int(m['created_at_ms'], DateTime.now().millisecondsSinceEpoch),
    );
  }
}

class SustainableExcellenceCase {
  final String id;
  final String source;
  final String sourceTodoId;
  final String sourceListId;
  final String linkedTodoTaskId;
  final List<String> generatedTodoTaskIds;
  final String title;
  final String coreTheme;
  final String userGoal;
  final String currentStateSummary;
  final SustainableModeDetection modeDetection;
  final SustainableValueMapping valueMapping;
  final List<SustainableObstacleAnalysis> obstacleAnalysis;
  final List<SustainableActionExperiment> actionExperiments;
  final SustainableRecoveryPlan recoveryPlan;
  final SustainableFailureLearning failureLearning;
  final SustainableProcessEnjoyment processEnjoyment;
  final SustainableTodoWriteback todoWriteback;
  final List<String> reflectionQuestions;
  final String coachMessage;
  final String riskNote;
  final String provider;
  final String modelLabel;
  final String selectedExperimentType;
  final String spiralStage;
  final int spiralCycleCount;
  final String lastFailureType;
  final int lastRecoveryAtMs;
  final int lastActionAtMs;
  final String nextRecommendedStage;
  final int archivedAtMs;
  final List<SustainableEvidenceLog> logs;
  final int createdAtMs;
  final int updatedAtMs;

  const SustainableExcellenceCase({
    required this.id,
    required this.source,
    required this.sourceTodoId,
    required this.sourceListId,
    required this.linkedTodoTaskId,
    required this.generatedTodoTaskIds,
    required this.title,
    required this.coreTheme,
    required this.userGoal,
    required this.currentStateSummary,
    required this.modeDetection,
    required this.valueMapping,
    required this.obstacleAnalysis,
    required this.actionExperiments,
    required this.recoveryPlan,
    required this.failureLearning,
    required this.processEnjoyment,
    required this.todoWriteback,
    required this.reflectionQuestions,
    required this.coachMessage,
    required this.riskNote,
    required this.provider,
    required this.modelLabel,
    required this.selectedExperimentType,
    required this.spiralStage,
    required this.spiralCycleCount,
    required this.lastFailureType,
    required this.lastRecoveryAtMs,
    required this.lastActionAtMs,
    required this.nextRecommendedStage,
    required this.archivedAtMs,
    required this.logs,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isArchived => archivedAtMs > 0;

  SustainableExcellenceCase copyWith({
    String? sourceTodoId,
    String? sourceListId,
    String? linkedTodoTaskId,
    List<String>? generatedTodoTaskIds,
    String? title,
    String? currentStateSummary,
    SustainableModeDetection? modeDetection,
    SustainableValueMapping? valueMapping,
    List<SustainableObstacleAnalysis>? obstacleAnalysis,
    List<SustainableActionExperiment>? actionExperiments,
    SustainableRecoveryPlan? recoveryPlan,
    SustainableFailureLearning? failureLearning,
    SustainableProcessEnjoyment? processEnjoyment,
    SustainableTodoWriteback? todoWriteback,
    List<String>? reflectionQuestions,
    String? coachMessage,
    String? riskNote,
    String? provider,
    String? modelLabel,
    String? selectedExperimentType,
    String? spiralStage,
    int? spiralCycleCount,
    String? lastFailureType,
    int? lastRecoveryAtMs,
    int? lastActionAtMs,
    String? nextRecommendedStage,
    int? archivedAtMs,
    List<SustainableEvidenceLog>? logs,
    int? updatedAtMs,
  }) => SustainableExcellenceCase(
        id: id,
        source: source,
        sourceTodoId: sourceTodoId ?? this.sourceTodoId,
        sourceListId: sourceListId ?? this.sourceListId,
        linkedTodoTaskId: linkedTodoTaskId ?? this.linkedTodoTaskId,
        generatedTodoTaskIds: generatedTodoTaskIds ?? this.generatedTodoTaskIds,
        title: title ?? this.title,
        coreTheme: coreTheme,
        userGoal: userGoal,
        currentStateSummary: currentStateSummary ?? this.currentStateSummary,
        modeDetection: modeDetection ?? this.modeDetection,
        valueMapping: valueMapping ?? this.valueMapping,
        obstacleAnalysis: obstacleAnalysis ?? this.obstacleAnalysis,
        actionExperiments: actionExperiments ?? this.actionExperiments,
        recoveryPlan: recoveryPlan ?? this.recoveryPlan,
        failureLearning: failureLearning ?? this.failureLearning,
        processEnjoyment: processEnjoyment ?? this.processEnjoyment,
        todoWriteback: todoWriteback ?? this.todoWriteback,
        reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
        coachMessage: coachMessage ?? this.coachMessage,
        riskNote: riskNote ?? this.riskNote,
        provider: provider ?? this.provider,
        modelLabel: modelLabel ?? this.modelLabel,
        selectedExperimentType: selectedExperimentType ?? this.selectedExperimentType,
        spiralStage: spiralStage ?? this.spiralStage,
        spiralCycleCount: spiralCycleCount ?? this.spiralCycleCount,
        lastFailureType: lastFailureType ?? this.lastFailureType,
        lastRecoveryAtMs: lastRecoveryAtMs ?? this.lastRecoveryAtMs,
        lastActionAtMs: lastActionAtMs ?? this.lastActionAtMs,
        nextRecommendedStage: nextRecommendedStage ?? this.nextRecommendedStage,
        archivedAtMs: archivedAtMs ?? this.archivedAtMs,
        logs: logs ?? this.logs,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'source': source,
        'source_todo_id': sourceTodoId,
        'source_list_id': sourceListId,
        'linked_todo_task_id': linkedTodoTaskId,
        'generated_todo_task_ids': generatedTodoTaskIds,
        'title': title,
        'module': 'sustainable_excellence_lab',
        'core_theme': coreTheme,
        'user_goal': userGoal,
        'current_state_summary': currentStateSummary,
        'mode_detection': modeDetection.toJson(),
        'value_mapping': valueMapping.toJson(),
        'obstacle_analysis': obstacleAnalysis.map((e) => e.toJson()).toList(),
        'action_experiments': actionExperiments.map((e) => e.toJson()).toList(),
        'recovery_plan': recoveryPlan.toJson(),
        'failure_learning': failureLearning.toJson(),
        'process_enjoyment': processEnjoyment.toJson(),
        'todo_writeback': todoWriteback.toJson(),
        'reflection_questions': reflectionQuestions,
        'coach_message': coachMessage,
        'risk_note': riskNote,
        'provider': provider,
        'model_label': modelLabel,
        'selected_experiment_type': selectedExperimentType,
        'spiral_stage': spiralStage,
        'spiral_cycle_count': spiralCycleCount,
        'last_failure_type': lastFailureType,
        'last_recovery_at_ms': lastRecoveryAtMs,
        'last_action_at_ms': lastActionAtMs,
        'next_recommended_stage': nextRecommendedStage,
        'archived_at_ms': archivedAtMs,
        'logs': logs.map((e) => e.toJson()).toList(),
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static SustainableExcellenceCase fromJson(dynamic json) {
    final m = _map(json);
    final now = DateTime.now().millisecondsSinceEpoch;
    final experiments = _mapList(m['action_experiments']).map(SustainableActionExperiment.fromJson).toList();
    final logs = _mapList(m['logs']).map(SustainableEvidenceLog.fromJson).toList();
    final stage = _str(m['spiral_stage'], logs.isEmpty ? SustainableSpiralStage.experiment : '');
    return SustainableExcellenceCase(
      id: _str(m['id'], 'se_${now}_${m.hashCode.abs()}'),
      source: _str(m['source'], 'manual'),
      sourceTodoId: _str(m['source_todo_id']),
      sourceListId: _str(m['source_list_id']),
      linkedTodoTaskId: _str(m['linked_todo_task_id']),
      generatedTodoTaskIds: _stringList(m['generated_todo_task_ids']),
      title: _str(m['title'], '可持续卓越实验'),
      coreTheme: _str(m['core_theme'], '压力-恢复-失败-反馈-卓越-过程'),
      userGoal: _str(m['user_goal']),
      currentStateSummary: _str(m['current_state_summary']),
      modeDetection: SustainableModeDetection.fromJson(m['mode_detection']),
      valueMapping: SustainableValueMapping.fromJson(m['value_mapping']),
      obstacleAnalysis: _mapList(m['obstacle_analysis']).map(SustainableObstacleAnalysis.fromJson).toList(),
      actionExperiments: experiments.isEmpty ? _fallbackExperiments() : experiments,
      recoveryPlan: SustainableRecoveryPlan.fromJson(m['recovery_plan']),
      failureLearning: SustainableFailureLearning.fromJson(m['failure_learning']),
      processEnjoyment: SustainableProcessEnjoyment.fromJson(m['process_enjoyment']),
      todoWriteback: SustainableTodoWriteback.fromJson(m['todo_writeback']),
      reflectionQuestions: _stringList(m['reflection_questions']),
      coachMessage: _str(m['coach_message']),
      riskNote: _str(m['risk_note']),
      provider: _str(m['provider'], 'local'),
      modelLabel: _str(m['model_label'], '内置策略'),
      selectedExperimentType: _str(m['selected_experiment_type']),
      spiralStage: stage.isEmpty ? _inferStageFromLogs(logs) : stage,
      spiralCycleCount: _int(m['spiral_cycle_count'], _inferCycleCount(logs)),
      lastFailureType: _str(m['last_failure_type']),
      lastRecoveryAtMs: _int(m['last_recovery_at_ms']),
      lastActionAtMs: _int(m['last_action_at_ms']),
      nextRecommendedStage: _str(m['next_recommended_stage'], SustainableSpiralStage.next(stage.isEmpty ? SustainableSpiralStage.experiment : stage)),
      archivedAtMs: _int(m['archived_at_ms']),
      logs: logs,
      createdAtMs: _int(m['created_at_ms'], now),
      updatedAtMs: _int(m['updated_at_ms'], now),
    );
  }

  static String _inferStageFromLogs(List<SustainableEvidenceLog> logs) {
    if (logs.isEmpty) return SustainableSpiralStage.experiment;
    final latest = logs.first.type;
    switch (latest) {
      case 'action':
        return SustainableSpiralStage.action;
      case 'failure_learning':
        return SustainableSpiralStage.failedOrStuck;
      case 'recovery':
        return SustainableSpiralStage.recovery;
      case 'process':
        return SustainableSpiralStage.feedback;
      case 'restart':
        return SustainableSpiralStage.restart;
      default:
        return SustainableSpiralStage.experiment;
    }
  }

  static int _inferCycleCount(List<SustainableEvidenceLog> logs) => logs.where((e) => e.type == 'restart').length;

  static List<SustainableActionExperiment> _fallbackExperiments() => const <SustainableActionExperiment>[
        SustainableActionExperiment(
          type: 'minimum_action',
          title: '5分钟粗糙开始',
          suitableWhen: '适合压力高、害怕失败、迟迟开始不了时。',
          steps: <String>['打开任务材料', '只做第一小步', '停止前写下一句反馈'],
          timeRequired: '5分钟',
          failurePoint: '想一次性做完，导致启动焦虑。',
          failureLearningMethod: '失败后只判断任务是否过大，不评价自己。',
          recoveryBefore: '闭眼呼吸 30 秒，提醒自己这只是实验。',
          recoveryAfter: '离开屏幕 3 分钟，记录一个学习点。',
          processAnchor: '我正在练习开始，而不是证明自己完美。',
        ),
        SustainableActionExperiment(
          type: 'standard_action',
          title: '25分钟行动 + 5分钟恢复',
          suitableWhen: '适合能量中等、可以进入专注但需要节律时。',
          steps: <String>['设定25分钟计时', '完成一个明确小块', '结束后复盘并恢复5分钟'],
          timeRequired: '30分钟',
          failurePoint: '中途分心或想把标准抬太高。',
          failureLearningMethod: '记录分心触发点，下一轮只改一个环境变量。',
          recoveryBefore: '整理桌面，只留下当前材料。',
          recoveryAfter: '伸展、喝水、短暂走动。',
          processAnchor: '我在积累行动证据和能力感。',
        ),
        SustainableActionExperiment(
          type: 'challenge_action',
          title: '提交一个不完美版本',
          suitableWhen: '适合状态较好、任务已有基础但因完美主义迟迟不提交时。',
          steps: <String>['确定最低可提交标准', '完成并提交一个版本', '只收集反馈，不做自我审判'],
          timeRequired: '40-90分钟',
          failurePoint: '反复修改、害怕评价、拖延提交。',
          failureLearningMethod: '把反馈看成版本迭代信息，而不是人格判决。',
          recoveryBefore: '写下“我允许这个版本不完美”。',
          recoveryAfter: '做一次中恢复，暂时不反复检查。',
          processAnchor: '真正的卓越来自反馈循环，不来自无错幻想。',
        ),
      ];
}

String sustainableCasesToString(List<SustainableExcellenceCase> items) => jsonEncode(items.map((e) => e.toJson()).toList());

List<SustainableExcellenceCase> sustainableCasesFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <SustainableExcellenceCase>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map(SustainableExcellenceCase.fromJson).toList();
  } catch (_) {}
  return <SustainableExcellenceCase>[];
}

String sustainableReviewsToString(List<SustainableDailyReview> items) => jsonEncode(items.map((e) => e.toJson()).toList());

List<SustainableDailyReview> sustainableReviewsFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <SustainableDailyReview>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map(SustainableDailyReview.fromJson).toList();
  } catch (_) {}
  return <SustainableDailyReview>[];
}
