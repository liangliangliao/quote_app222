import 'dart:convert';

enum CheckupSafetyStatus { clear, uncertain, alert }

enum CheckupPlanStatus { active, paused, completed, maintenance }

class CheckupAnswerChoice {
  final String label;
  final double value;

  const CheckupAnswerChoice(this.label, this.value);
}

class CheckupQuestion {
  final String id;
  final String group;
  final String kind;
  final String prompt;
  final String scaleLabel;
  final String direction;
  final String? indicatorId;
  final String sourceLevel;
  final bool required;
  final String? domainId;
  final int? lecture;
  final String? evidenceLocation;
  final List<CheckupAnswerChoice> choices;

  const CheckupQuestion({
    required this.id,
    required this.group,
    required this.kind,
    required this.prompt,
    required this.scaleLabel,
    required this.direction,
    required this.sourceLevel,
    required this.required,
    required this.choices,
    this.indicatorId,
    this.domainId,
    this.lecture,
    this.evidenceLocation,
  });

  bool get isSafety => id.startsWith('B20-S');
  bool get isFunction => id == 'B20-F1' || id == 'B20-F2';
  bool get isKnowledge => id.startsWith('B20-K');
  bool get isOpenCheck => id == 'B20-Q1';
}

class CheckupModeSpec {
  final String id;
  final String name;
  final String duration;
  final int baseQuestionCount;
  final int maxQuestionCount;
  final String fixedContent;
  final String actionCount;
  final String useCase;
  final String coverageLevel;

  const CheckupModeSpec({
    required this.id,
    required this.name,
    required this.duration,
    required this.baseQuestionCount,
    required this.maxQuestionCount,
    required this.fixedContent,
    required this.actionCount,
    required this.useCase,
    required this.coverageLevel,
  });
}

class CheckupIndicator {
  final String id;
  final int lecture;
  final String area;
  final String name;
  final String type;
  final String definitionLocation;
  final String lowLocation;
  final String highLocation;
  final String actionLocation;
  final int directEvidenceCount;
  final String directness;
  final String reviewStatus;

  const CheckupIndicator({
    required this.id,
    required this.lecture,
    required this.area,
    required this.name,
    required this.type,
    required this.definitionLocation,
    required this.lowLocation,
    required this.highLocation,
    required this.actionLocation,
    required this.directEvidenceCount,
    required this.directness,
    required this.reviewStatus,
  });
}

class CheckupDiagnosisPattern {
  final String id;
  final String name;
  final List<String> triggerIndicatorIds;
  final String mechanism;
  final List<String> prescriptionIds;
  final String priorityAction;
  final String evidenceNeeded;
  final String exclusions;
  final String confidenceRule;
  final String reviewStatus;

  const CheckupDiagnosisPattern({
    required this.id,
    required this.name,
    required this.triggerIndicatorIds,
    required this.mechanism,
    required this.prescriptionIds,
    required this.priorityAction,
    required this.evidenceNeeded,
    required this.exclusions,
    required this.confidenceRule,
    required this.reviewStatus,
  });
}

class CheckupPrescription {
  final String id;
  final int lecture;
  final String theme;
  final String primaryIndicatorId;
  final String primaryIndicator;
  final String actionLocation;
  final String mechanism;
  final String startingAction;
  final String deepeningAction;
  final String microDose;
  final String startingDose;
  final String consolidationDose;
  final String trialPeriod;
  final String outcomeEvidence;
  final String stopRule;
  final String sourceLevel;
  final String reviewStatus;

  const CheckupPrescription({
    required this.id,
    required this.lecture,
    required this.theme,
    required this.primaryIndicatorId,
    required this.primaryIndicator,
    required this.actionLocation,
    required this.mechanism,
    required this.startingAction,
    required this.deepeningAction,
    required this.microDose,
    required this.startingDose,
    required this.consolidationDose,
    required this.trialPeriod,
    required this.outcomeEvidence,
    required this.stopRule,
    required this.sourceLevel,
    required this.reviewStatus,
  });
}

class CheckupAnswer {
  final String questionId;
  final String label;
  final double value;
  final int answeredAtMs;
  final int responseDurationMs;

  const CheckupAnswer({
    required this.questionId,
    required this.label,
    required this.value,
    required this.answeredAtMs,
    this.responseDurationMs = 0,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'question_id': questionId,
        'label': label,
        'value': value,
        'answered_at_ms': answeredAtMs,
        'response_duration_ms': responseDurationMs,
      };

  factory CheckupAnswer.fromJson(Map<String, dynamic> json) => CheckupAnswer(
        questionId: (json['question_id'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        value: (json['value'] as num?)?.toDouble() ?? 0,
        answeredAtMs: (json['answered_at_ms'] as num?)?.toInt() ?? 0,
        responseDurationMs:
            (json['response_duration_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupDomainResult {
  final String id;
  final String name;
  final double score;
  final String level;
  final int answered;
  final int expected;
  final List<String> indicatorIds;

  const CheckupDomainResult({
    required this.id,
    required this.name,
    required this.score,
    required this.level,
    required this.answered,
    required this.expected,
    required this.indicatorIds,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'score': score,
        'level': level,
        'answered': answered,
        'expected': expected,
        'indicator_ids': indicatorIds,
      };

  factory CheckupDomainResult.fromJson(Map<String, dynamic> json) =>
      CheckupDomainResult(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        score: (json['score'] as num?)?.toDouble() ?? 0,
        level: (json['level'] ?? '').toString(),
        answered: (json['answered'] as num?)?.toInt() ?? 0,
        expected: (json['expected'] as num?)?.toInt() ?? 0,
        indicatorIds: (json['indicator_ids'] as List? ?? const <Object?>[])
            .map((e) => e.toString())
            .toList(growable: false),
      );
}

class CheckupDiagnosisResult {
  final String patternId;
  final String name;
  final String mechanism;
  final double confidence;
  final String confidenceLevel;
  final bool candidateOnly;
  final List<String> supportingEvidence;
  final List<String> conflictingEvidence;
  final List<String> alternativeHypotheses;
  final List<String> prescriptionIds;
  final String reviewStatus;

  const CheckupDiagnosisResult({
    required this.patternId,
    required this.name,
    required this.mechanism,
    required this.confidence,
    required this.confidenceLevel,
    required this.candidateOnly,
    required this.supportingEvidence,
    required this.conflictingEvidence,
    required this.alternativeHypotheses,
    required this.prescriptionIds,
    required this.reviewStatus,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'pattern_id': patternId,
        'name': name,
        'mechanism': mechanism,
        'confidence': confidence,
        'confidence_level': confidenceLevel,
        'candidate_only': candidateOnly,
        'supporting_evidence': supportingEvidence,
        'conflicting_evidence': conflictingEvidence,
        'alternative_hypotheses': alternativeHypotheses,
        'prescription_ids': prescriptionIds,
        'review_status': reviewStatus,
      };

  factory CheckupDiagnosisResult.fromJson(Map<String, dynamic> json) =>
      CheckupDiagnosisResult(
        patternId: (json['pattern_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        mechanism: (json['mechanism'] ?? '').toString(),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        confidenceLevel: (json['confidence_level'] ?? '').toString(),
        candidateOnly: json['candidate_only'] == true,
        supportingEvidence:
            (json['supporting_evidence'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        conflictingEvidence:
            (json['conflicting_evidence'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        alternativeHypotheses:
            (json['alternative_hypotheses'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        prescriptionIds:
            (json['prescription_ids'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        reviewStatus: (json['review_status'] ?? '').toString(),
      );
}

class CheckupPrescriptionRecommendation {
  final String prescriptionId;
  final int lecture;
  final String theme;
  final String target;
  final String startingAction;
  final String deepeningAction;
  final String dose;
  final String trialPeriod;
  final String evidenceLocation;
  final String sourceLevel;
  final String stopRule;

  const CheckupPrescriptionRecommendation({
    required this.prescriptionId,
    required this.lecture,
    required this.theme,
    required this.target,
    required this.startingAction,
    required this.deepeningAction,
    required this.dose,
    required this.trialPeriod,
    required this.evidenceLocation,
    required this.sourceLevel,
    required this.stopRule,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'prescription_id': prescriptionId,
        'lecture': lecture,
        'theme': theme,
        'target': target,
        'starting_action': startingAction,
        'deepening_action': deepeningAction,
        'dose': dose,
        'trial_period': trialPeriod,
        'evidence_location': evidenceLocation,
        'source_level': sourceLevel,
        'stop_rule': stopRule,
      };

  factory CheckupPrescriptionRecommendation.fromJson(
          Map<String, dynamic> json) =>
      CheckupPrescriptionRecommendation(
        prescriptionId: (json['prescription_id'] ?? '').toString(),
        lecture: (json['lecture'] as num?)?.toInt() ?? 0,
        theme: (json['theme'] ?? '').toString(),
        target: (json['target'] ?? '').toString(),
        startingAction: (json['starting_action'] ?? '').toString(),
        deepeningAction: (json['deepening_action'] ?? '').toString(),
        dose: (json['dose'] ?? '').toString(),
        trialPeriod: (json['trial_period'] ?? '').toString(),
        evidenceLocation: (json['evidence_location'] ?? '').toString(),
        sourceLevel: (json['source_level'] ?? '').toString(),
        stopRule: (json['stop_rule'] ?? '').toString(),
      );
}

class CheckupReport {
  final String id;
  final String sessionId;
  final String modeId;
  final int createdAtMs;
  final String ruleVersion;
  final String seedVersion;
  final CheckupSafetyStatus safetyStatus;
  final double overallScore;
  final double? knowledgeScore;
  final double? attitudeScore;
  final double? behaviorScore;
  final double? attitudeBehaviorConsistency;
  final double? knowledgeBehaviorConsistency;
  final double? kabIntegratedScore;
  final double coverage;
  final double dataQuality;
  final int functionImpact;
  final bool uncoveredConcern;
  final List<CheckupDomainResult> domains;
  final List<CheckupDiagnosisResult> diagnoses;
  final List<CheckupPrescriptionRecommendation> prescriptions;
  final List<String> surfaceFindings;
  final List<String> courseEvidence;
  final List<String> sourceBoundaries;
  final int? nextRetestAtMs;

  const CheckupReport({
    required this.id,
    required this.sessionId,
    required this.modeId,
    required this.createdAtMs,
    required this.ruleVersion,
    this.seedVersion = 'unknown',
    required this.safetyStatus,
    required this.overallScore,
    this.knowledgeScore,
    this.attitudeScore,
    this.behaviorScore,
    this.attitudeBehaviorConsistency,
    this.knowledgeBehaviorConsistency,
    this.kabIntegratedScore,
    required this.coverage,
    required this.dataQuality,
    required this.functionImpact,
    required this.uncoveredConcern,
    required this.domains,
    required this.diagnoses,
    required this.prescriptions,
    required this.surfaceFindings,
    required this.courseEvidence,
    required this.sourceBoundaries,
    required this.nextRetestAtMs,
  });

  bool get safetyClear => safetyStatus == CheckupSafetyStatus.clear;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'session_id': sessionId,
        'mode_id': modeId,
        'created_at_ms': createdAtMs,
        'rule_version': ruleVersion,
        'seed_version': seedVersion,
        'safety_status': safetyStatus.name,
        'overall_score': overallScore,
        'knowledge_score': knowledgeScore,
        'attitude_score': attitudeScore,
        'behavior_score': behaviorScore,
        'attitude_behavior_consistency': attitudeBehaviorConsistency,
        'knowledge_behavior_consistency': knowledgeBehaviorConsistency,
        'kab_integrated_score': kabIntegratedScore,
        'coverage': coverage,
        'data_quality': dataQuality,
        'function_impact': functionImpact,
        'uncovered_concern': uncoveredConcern,
        'domains': domains.map((e) => e.toJson()).toList(growable: false),
        'diagnoses':
            diagnoses.map((e) => e.toJson()).toList(growable: false),
        'prescriptions':
            prescriptions.map((e) => e.toJson()).toList(growable: false),
        'surface_findings': surfaceFindings,
        'course_evidence': courseEvidence,
        'source_boundaries': sourceBoundaries,
        'next_retest_at_ms': nextRetestAtMs,
      };

  factory CheckupReport.fromJson(Map<String, dynamic> json) => CheckupReport(
        id: (json['id'] ?? '').toString(),
        sessionId: (json['session_id'] ?? '').toString(),
        modeId: (json['mode_id'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        ruleVersion: (json['rule_version'] ?? '2.5').toString(),
        seedVersion: (json['seed_version'] ?? 'legacy').toString(),
        safetyStatus: CheckupSafetyStatus.values.firstWhere(
          (e) => e.name == json['safety_status'],
          orElse: () => CheckupSafetyStatus.uncertain,
        ),
        overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0,
        knowledgeScore: (json['knowledge_score'] as num?)?.toDouble(),
        attitudeScore: (json['attitude_score'] as num?)?.toDouble(),
        behaviorScore: (json['behavior_score'] as num?)?.toDouble(),
        attitudeBehaviorConsistency:
            (json['attitude_behavior_consistency'] as num?)?.toDouble(),
        knowledgeBehaviorConsistency:
            (json['knowledge_behavior_consistency'] as num?)?.toDouble(),
        kabIntegratedScore:
            (json['kab_integrated_score'] as num?)?.toDouble(),
        coverage: (json['coverage'] as num?)?.toDouble() ?? 0,
        dataQuality: (json['data_quality'] as num?)?.toDouble() ?? 0,
        functionImpact: (json['function_impact'] as num?)?.toInt() ?? 0,
        uncoveredConcern: json['uncovered_concern'] == true,
        domains: (json['domains'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => CheckupDomainResult.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(growable: false),
        diagnoses: (json['diagnoses'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => CheckupDiagnosisResult.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(growable: false),
        prescriptions: (json['prescriptions'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => CheckupPrescriptionRecommendation.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(growable: false),
        surfaceFindings:
            (json['surface_findings'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        courseEvidence:
            (json['course_evidence'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        sourceBoundaries:
            (json['source_boundaries'] as List? ?? const <Object?>[])
                .map((e) => e.toString())
                .toList(growable: false),
        nextRetestAtMs: (json['next_retest_at_ms'] as num?)?.toInt(),
      );
}

class CheckupSession {
  final String id;
  final String modeId;
  final String modeName;
  final int startedAtMs;
  final int completedAtMs;
  final List<CheckupAnswer> answers;
  final CheckupReport report;

  const CheckupSession({
    required this.id,
    required this.modeId,
    required this.modeName,
    required this.startedAtMs,
    required this.completedAtMs,
    required this.answers,
    required this.report,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'mode_id': modeId,
        'mode_name': modeName,
        'started_at_ms': startedAtMs,
        'completed_at_ms': completedAtMs,
        'answers': answers.map((e) => e.toJson()).toList(growable: false),
        'report': report.toJson(),
      };

  factory CheckupSession.fromJson(Map<String, dynamic> json) => CheckupSession(
        id: (json['id'] ?? '').toString(),
        modeId: (json['mode_id'] ?? '').toString(),
        modeName: (json['mode_name'] ?? '').toString(),
        startedAtMs: (json['started_at_ms'] as num?)?.toInt() ?? 0,
        completedAtMs: (json['completed_at_ms'] as num?)?.toInt() ?? 0,
        answers: (json['answers'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) =>
                CheckupAnswer.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        report: CheckupReport.fromJson(
            Map<String, dynamic>.from(json['report'] as Map? ?? const {})),
      );
}

class CheckupExecutionLog {
  final int createdAtMs;
  final bool completed;
  final double effort;
  final double benefit;
  final double functionChange;
  final double overuseRisk;

  const CheckupExecutionLog({
    required this.createdAtMs,
    required this.completed,
    required this.effort,
    required this.benefit,
    required this.functionChange,
    required this.overuseRisk,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'created_at_ms': createdAtMs,
        'completed': completed,
        'effort': effort,
        'benefit': benefit,
        'function_change': functionChange,
        'overuse_risk': overuseRisk,
      };

  factory CheckupExecutionLog.fromJson(Map<String, dynamic> json) =>
      CheckupExecutionLog(
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        completed: json['completed'] == true,
        effort: (json['effort'] as num?)?.toDouble() ?? 0,
        benefit: (json['benefit'] as num?)?.toDouble() ?? 0,
        functionChange:
            (json['function_change'] as num?)?.toDouble() ?? 0,
        overuseRisk: (json['overuse_risk'] as num?)?.toDouble() ?? 0,
      );
}

class CheckupPrescriptionPlan {
  final String id;
  final String sourceReportId;
  final CheckupPrescriptionRecommendation prescription;
  final CheckupPlanStatus status;
  final String doseStage;
  final int startedAtMs;
  final int nextRetestAtMs;
  final List<CheckupExecutionLog> logs;

  const CheckupPrescriptionPlan({
    required this.id,
    required this.sourceReportId,
    required this.prescription,
    required this.status,
    required this.doseStage,
    required this.startedAtMs,
    required this.nextRetestAtMs,
    required this.logs,
  });

  double get completionRate {
    if (logs.isEmpty) return 0;
    return logs.where((e) => e.completed).length / logs.length * 100;
  }

  double get averageBenefit {
    if (logs.isEmpty) return 0;
    return logs.map((e) => e.benefit).reduce((a, b) => a + b) / logs.length;
  }

  double get averageOveruseRisk {
    if (logs.isEmpty) return 0;
    return logs.map((e) => e.overuseRisk).reduce((a, b) => a + b) /
        logs.length;
  }

  CheckupPrescriptionPlan copyWith({
    CheckupPlanStatus? status,
    String? doseStage,
    int? nextRetestAtMs,
    List<CheckupExecutionLog>? logs,
  }) =>
      CheckupPrescriptionPlan(
        id: id,
        sourceReportId: sourceReportId,
        prescription: prescription,
        status: status ?? this.status,
        doseStage: doseStage ?? this.doseStage,
        startedAtMs: startedAtMs,
        nextRetestAtMs: nextRetestAtMs ?? this.nextRetestAtMs,
        logs: logs ?? this.logs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'source_report_id': sourceReportId,
        'prescription': prescription.toJson(),
        'status': status.name,
        'dose_stage': doseStage,
        'started_at_ms': startedAtMs,
        'next_retest_at_ms': nextRetestAtMs,
        'logs': logs.map((e) => e.toJson()).toList(growable: false),
      };

  factory CheckupPrescriptionPlan.fromJson(Map<String, dynamic> json) =>
      CheckupPrescriptionPlan(
        id: (json['id'] ?? '').toString(),
        sourceReportId: (json['source_report_id'] ?? '').toString(),
        prescription: CheckupPrescriptionRecommendation.fromJson(
          Map<String, dynamic>.from(
              json['prescription'] as Map? ?? const {}),
        ),
        status: CheckupPlanStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => CheckupPlanStatus.active,
        ),
        doseStage: (json['dose_stage'] ?? '微量').toString(),
        startedAtMs: (json['started_at_ms'] as num?)?.toInt() ?? 0,
        nextRetestAtMs:
            (json['next_retest_at_ms'] as num?)?.toInt() ?? 0,
        logs: (json['logs'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => CheckupExecutionLog.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class CheckupRetestRecord {
  final String id;
  final String planId;
  final String baselineReportId;
  final String retestReportId;
  final int createdAtMs;
  final double scoreChange;
  final double functionChange;
  final double executionRate;
  final double overuseRisk;
  final double retestScore;
  final int retestFunctionImpact;
  final bool safetyClear;
  final String decision;
  final String reason;

  const CheckupRetestRecord({
    required this.id,
    required this.planId,
    required this.baselineReportId,
    required this.retestReportId,
    required this.createdAtMs,
    required this.scoreChange,
    required this.functionChange,
    required this.executionRate,
    required this.overuseRisk,
    this.retestScore = 0,
    this.retestFunctionImpact = 4,
    this.safetyClear = false,
    required this.decision,
    required this.reason,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'plan_id': planId,
        'baseline_report_id': baselineReportId,
        'retest_report_id': retestReportId,
        'created_at_ms': createdAtMs,
        'score_change': scoreChange,
        'function_change': functionChange,
        'execution_rate': executionRate,
        'overuse_risk': overuseRisk,
        'retest_score': retestScore,
        'retest_function_impact': retestFunctionImpact,
        'safety_clear': safetyClear,
        'decision': decision,
        'reason': reason,
      };

  factory CheckupRetestRecord.fromJson(Map<String, dynamic> json) =>
      CheckupRetestRecord(
        id: (json['id'] ?? '').toString(),
        planId: (json['plan_id'] ?? '').toString(),
        baselineReportId: (json['baseline_report_id'] ?? '').toString(),
        retestReportId: (json['retest_report_id'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        scoreChange: (json['score_change'] as num?)?.toDouble() ?? 0,
        functionChange:
            (json['function_change'] as num?)?.toDouble() ?? 0,
        executionRate: (json['execution_rate'] as num?)?.toDouble() ?? 0,
        overuseRisk: (json['overuse_risk'] as num?)?.toDouble() ?? 0,
        retestScore: (json['retest_score'] as num?)?.toDouble() ?? 0,
        retestFunctionImpact:
            (json['retest_function_impact'] as num?)?.toInt() ?? 4,
        safetyClear: json['safety_clear'] == true,
        decision: (json['decision'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );
}

class MentalHealthCheckupSettings {
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int quietStartHour;
  final int quietEndHour;
  final bool lockScreenPrivacy;
  final bool secureScreen;
  final String emergencyNumber;
  final String crisisNumber;

  const MentalHealthCheckupSettings({
    this.remindersEnabled = false,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.quietStartHour = 22,
    this.quietEndHour = 8,
    this.lockScreenPrivacy = true,
    this.secureScreen = false,
    this.emergencyNumber = '',
    this.crisisNumber = '',
  });

  MentalHealthCheckupSettings copyWith({
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? quietStartHour,
    int? quietEndHour,
    bool? lockScreenPrivacy,
    bool? secureScreen,
    String? emergencyNumber,
    String? crisisNumber,
  }) =>
      MentalHealthCheckupSettings(
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietEndHour: quietEndHour ?? this.quietEndHour,
        lockScreenPrivacy: lockScreenPrivacy ?? this.lockScreenPrivacy,
        secureScreen: secureScreen ?? this.secureScreen,
        emergencyNumber: emergencyNumber ?? this.emergencyNumber,
        crisisNumber: crisisNumber ?? this.crisisNumber,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'reminders_enabled': remindersEnabled,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
        'quiet_start_hour': quietStartHour,
        'quiet_end_hour': quietEndHour,
        'lock_screen_privacy': lockScreenPrivacy,
        'secure_screen': secureScreen,
        'emergency_number': emergencyNumber,
        'crisis_number': crisisNumber,
      };

  factory MentalHealthCheckupSettings.fromJson(Map<String, dynamic> json) =>
      MentalHealthCheckupSettings(
        remindersEnabled: json['reminders_enabled'] == true,
        reminderHour: ((json['reminder_hour'] as num?)?.toInt() ?? 19)
            .clamp(0, 23)
            .toInt(),
        reminderMinute: ((json['reminder_minute'] as num?)?.toInt() ?? 0)
            .clamp(0, 59)
            .toInt(),
        quietStartHour:
            ((json['quiet_start_hour'] as num?)?.toInt() ?? 22)
                .clamp(0, 23)
                .toInt(),
        quietEndHour: ((json['quiet_end_hour'] as num?)?.toInt() ?? 8)
            .clamp(0, 23)
            .toInt(),
        lockScreenPrivacy: json['lock_screen_privacy'] != false,
        secureScreen: json['secure_screen'] == true,
        emergencyNumber: (json['emergency_number'] ?? '').toString(),
        crisisNumber: (json['crisis_number'] ?? '').toString(),
      );
}

class MentalHealthCheckupState {
  final int schemaVersion;
  final String installId;
  final bool onboardingAccepted;
  final MentalHealthCheckupSettings settings;
  final List<CheckupSession> sessions;
  final List<CheckupPrescriptionPlan> plans;
  final List<CheckupRetestRecord> retests;

  const MentalHealthCheckupState({
    this.schemaVersion = 4,
    this.installId = '',
    this.onboardingAccepted = false,
    this.settings = const MentalHealthCheckupSettings(),
    this.sessions = const <CheckupSession>[],
    this.plans = const <CheckupPrescriptionPlan>[],
    this.retests = const <CheckupRetestRecord>[],
  });

  CheckupSession? get latestSession => sessions.isEmpty ? null : sessions.first;

  CheckupPrescriptionPlan? get activePlan {
    for (final plan in plans) {
      if (plan.status == CheckupPlanStatus.active ||
          plan.status == CheckupPlanStatus.maintenance) {
        return plan;
      }
    }
    // Keep the most recently paused plan reachable so the user can resume it
    // from the action tab. Completed plans stay in the archive only.
    for (final plan in plans) {
      if (plan.status == CheckupPlanStatus.paused) return plan;
    }
    return null;
  }

  MentalHealthCheckupState copyWith({
    String? installId,
    bool? onboardingAccepted,
    MentalHealthCheckupSettings? settings,
    List<CheckupSession>? sessions,
    List<CheckupPrescriptionPlan>? plans,
    List<CheckupRetestRecord>? retests,
  }) =>
      MentalHealthCheckupState(
        schemaVersion: schemaVersion,
        installId: installId ?? this.installId,
        onboardingAccepted: onboardingAccepted ?? this.onboardingAccepted,
        settings: settings ?? this.settings,
        sessions: sessions ?? this.sessions,
        plans: plans ?? this.plans,
        retests: retests ?? this.retests,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schema_version': schemaVersion,
        'install_id': installId,
        'onboarding_accepted': onboardingAccepted,
        'settings': settings.toJson(),
        'sessions': sessions.map((e) => e.toJson()).toList(growable: false),
        'plans': plans.map((e) => e.toJson()).toList(growable: false),
        'retests': retests.map((e) => e.toJson()).toList(growable: false),
      };

  String encode() => jsonEncode(toJson());

  factory MentalHealthCheckupState.decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map) return const MentalHealthCheckupState();
    final json = Map<String, dynamic>.from(value);
    return MentalHealthCheckupState(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      installId: (json['install_id'] ?? '').toString(),
      onboardingAccepted: json['onboarding_accepted'] == true,
      settings: MentalHealthCheckupSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      ),
      sessions: (json['sessions'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((e) =>
              CheckupSession.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      plans: (json['plans'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => CheckupPrescriptionPlan.fromJson(
              Map<String, dynamic>.from(e)))
          .toList(growable: false),
      retests: (json['retests'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => CheckupRetestRecord.fromJson(
              Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}
