import 'mental_health_checkup_models.dart';

enum CheckupContentKind { assessmentItem, behaviorTask }

enum CheckupCandidateStage {
  draft,
  candidate,
  cognitiveInterview,
  pilot,
  official,
  retired,
}

extension CheckupContentKindLabel on CheckupContentKind {
  String get label => switch (this) {
        CheckupContentKind.assessmentItem => '态度/内省题',
        CheckupContentKind.behaviorTask => '行为任务',
      };
}

extension CheckupCandidateStageLabel on CheckupCandidateStage {
  String get label => switch (this) {
        CheckupCandidateStage.draft => '草稿',
        CheckupCandidateStage.candidate => '候选',
        CheckupCandidateStage.cognitiveInterview => '认知访谈',
        CheckupCandidateStage.pilot => '试测',
        CheckupCandidateStage.official => '正式',
        CheckupCandidateStage.retired => '停用',
      };
}

class CheckupContentGenerationPlan {
  final String indicatorId;
  final int lecture;
  final String indicatorName;
  final String indicatorType;
  final List<String> itemTypeCodes;
  final List<String> behaviorLevels;
  final List<String> evidenceIds;
  final List<String> guardrailIndicatorIds;
  final String sourceLevel;
  final String reviewStatus;

  const CheckupContentGenerationPlan({
    required this.indicatorId,
    required this.lecture,
    required this.indicatorName,
    required this.indicatorType,
    required this.itemTypeCodes,
    required this.behaviorLevels,
    required this.evidenceIds,
    required this.guardrailIndicatorIds,
    required this.sourceLevel,
    required this.reviewStatus,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'indicator_id': indicatorId,
        'lecture': lecture,
        'indicator_name': indicatorName,
        'indicator_type': indicatorType,
        'item_type_codes': itemTypeCodes,
        'behavior_levels': behaviorLevels,
        'evidence_ids': evidenceIds,
        'guardrail_indicator_ids': guardrailIndicatorIds,
        'source_level': sourceLevel,
        'review_status': reviewStatus,
      };
}

class CheckupCandidateQuality {
  final double indicatorConsistency;
  final double courseFidelity;
  final double nonDuplication;
  final double measurability;
  final double scaleWindowFit;
  final double bidirectionalLogic;
  final double safety;

  const CheckupCandidateQuality({
    this.indicatorConsistency = 0,
    this.courseFidelity = 0,
    this.nonDuplication = 0,
    this.measurability = 0,
    this.scaleWindowFit = 0,
    this.bidirectionalLogic = 0,
    this.safety = 0,
  });

  double get overall =>
      indicatorConsistency * 0.20 +
      courseFidelity * 0.20 +
      nonDuplication * 0.10 +
      measurability * 0.10 +
      scaleWindowFit * 0.10 +
      bidirectionalLogic * 0.10 +
      safety * 0.20;

  List<String> get gateFailures {
    final failures = <String>[];
    if (indicatorConsistency < 75) failures.add('指标一致性低于75');
    if (courseFidelity < 80) failures.add('课程忠实度低于80');
    if (scaleWindowFit < 80) failures.add('量尺与时间窗匹配低于80');
    if (safety < 90) failures.add('安全性低于90');
    if (overall < 80) failures.add('综合质量低于80');
    return failures;
  }

  bool get passesPublishedThresholds => gateFailures.isEmpty;

  CheckupCandidateQuality copyWith({
    double? indicatorConsistency,
    double? courseFidelity,
    double? nonDuplication,
    double? measurability,
    double? scaleWindowFit,
    double? bidirectionalLogic,
    double? safety,
  }) =>
      CheckupCandidateQuality(
        indicatorConsistency:
            _boundedScore(indicatorConsistency ?? this.indicatorConsistency),
        courseFidelity:
            _boundedScore(courseFidelity ?? this.courseFidelity),
        nonDuplication:
            _boundedScore(nonDuplication ?? this.nonDuplication),
        measurability: _boundedScore(measurability ?? this.measurability),
        scaleWindowFit:
            _boundedScore(scaleWindowFit ?? this.scaleWindowFit),
        bidirectionalLogic:
            _boundedScore(bidirectionalLogic ?? this.bidirectionalLogic),
        safety: _boundedScore(safety ?? this.safety),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'indicator_consistency': indicatorConsistency,
        'course_fidelity': courseFidelity,
        'non_duplication': nonDuplication,
        'measurability': measurability,
        'scale_window_fit': scaleWindowFit,
        'bidirectional_logic': bidirectionalLogic,
        'safety': safety,
        'overall': overall,
      };

  factory CheckupCandidateQuality.fromJson(Map<String, dynamic> json) =>
      CheckupCandidateQuality(
        indicatorConsistency:
            _boundedScore((json['indicator_consistency'] as num?)?.toDouble()),
        courseFidelity:
            _boundedScore((json['course_fidelity'] as num?)?.toDouble()),
        nonDuplication:
            _boundedScore((json['non_duplication'] as num?)?.toDouble()),
        measurability:
            _boundedScore((json['measurability'] as num?)?.toDouble()),
        scaleWindowFit:
            _boundedScore((json['scale_window_fit'] as num?)?.toDouble()),
        bidirectionalLogic:
            _boundedScore((json['bidirectional_logic'] as num?)?.toDouble()),
        safety: _boundedScore((json['safety'] as num?)?.toDouble()),
      );

  static double _boundedScore(double? value) =>
      (value ?? 0).clamp(0, 100).toDouble();
}

class CheckupContentCandidate {
  final String candidateId;
  final String? parentCandidateId;
  final CheckupContentKind kind;
  final String primaryIndicatorId;
  final String indicatorName;
  final String indicatorType;
  final String contentCode;
  final String content;
  final String scaleOrDuration;
  final String scoringDirection;
  final String recallWindow;
  final List<String> answerOptions;
  final int? correctAnswerIndex;
  final List<String> courseEvidenceIds;
  final String sourceLevel;
  final String constructRationale;
  final List<String> guardrailIndicatorIds;
  final String safetyRule;
  final String smallerVersion;
  final String counterEvidencePrompt;
  final CheckupCandidateQuality quality;
  final CheckupCandidateStage stage;
  final bool evidenceReviewPassed;
  final bool constructReviewPassed;
  final bool cognitiveInterviewPassed;
  final bool pilotPassed;
  final int pilotSampleSize;
  final String pilotNotes;
  final String author;
  final String reviewer;
  final String signer;
  final String retirementReason;
  final String modelVersion;
  final String promptVersion;
  final String indicatorVersion;
  final String courseVersion;
  final int version;
  final int createdAtMs;
  final int updatedAtMs;

  const CheckupContentCandidate({
    required this.candidateId,
    this.parentCandidateId,
    required this.kind,
    required this.primaryIndicatorId,
    required this.indicatorName,
    required this.indicatorType,
    required this.contentCode,
    required this.content,
    required this.scaleOrDuration,
    required this.scoringDirection,
    required this.recallWindow,
    this.answerOptions = const <String>[],
    this.correctAnswerIndex,
    required this.courseEvidenceIds,
    required this.sourceLevel,
    required this.constructRationale,
    required this.guardrailIndicatorIds,
    required this.safetyRule,
    required this.smallerVersion,
    required this.counterEvidencePrompt,
    required this.quality,
    this.stage = CheckupCandidateStage.draft,
    this.evidenceReviewPassed = false,
    this.constructReviewPassed = false,
    this.cognitiveInterviewPassed = false,
    this.pilotPassed = false,
    this.pilotSampleSize = 0,
    this.pilotNotes = '',
    required this.author,
    this.reviewer = '',
    this.signer = '',
    this.retirementReason = '',
    required this.modelVersion,
    required this.promptVersion,
    required this.indicatorVersion,
    required this.courseVersion,
    this.version = 1,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isAiAuthored =>
      author.toLowerCase().contains('ai') ||
      modelVersion.trim().isNotEmpty && modelVersion != 'local-template';

  bool get isReadOnly =>
      stage == CheckupCandidateStage.official ||
      stage == CheckupCandidateStage.retired;

  CheckupContentCandidate copyWith({
    String? candidateId,
    String? parentCandidateId,
    CheckupContentKind? kind,
    String? primaryIndicatorId,
    String? indicatorName,
    String? indicatorType,
    String? contentCode,
    String? content,
    String? scaleOrDuration,
    String? scoringDirection,
    String? recallWindow,
    List<String>? answerOptions,
    int? correctAnswerIndex,
    bool clearCorrectAnswer = false,
    List<String>? courseEvidenceIds,
    String? sourceLevel,
    String? constructRationale,
    List<String>? guardrailIndicatorIds,
    String? safetyRule,
    String? smallerVersion,
    String? counterEvidencePrompt,
    CheckupCandidateQuality? quality,
    CheckupCandidateStage? stage,
    bool? evidenceReviewPassed,
    bool? constructReviewPassed,
    bool? cognitiveInterviewPassed,
    bool? pilotPassed,
    int? pilotSampleSize,
    String? pilotNotes,
    String? author,
    String? reviewer,
    String? signer,
    String? retirementReason,
    String? modelVersion,
    String? promptVersion,
    String? indicatorVersion,
    String? courseVersion,
    int? version,
    int? createdAtMs,
    int? updatedAtMs,
  }) =>
      CheckupContentCandidate(
        candidateId: candidateId ?? this.candidateId,
        parentCandidateId: parentCandidateId ?? this.parentCandidateId,
        kind: kind ?? this.kind,
        primaryIndicatorId: primaryIndicatorId ?? this.primaryIndicatorId,
        indicatorName: indicatorName ?? this.indicatorName,
        indicatorType: indicatorType ?? this.indicatorType,
        contentCode: contentCode ?? this.contentCode,
        content: content ?? this.content,
        scaleOrDuration: scaleOrDuration ?? this.scaleOrDuration,
        scoringDirection: scoringDirection ?? this.scoringDirection,
        recallWindow: recallWindow ?? this.recallWindow,
        answerOptions: answerOptions ?? this.answerOptions,
        correctAnswerIndex: clearCorrectAnswer
            ? null
            : correctAnswerIndex ?? this.correctAnswerIndex,
        courseEvidenceIds: courseEvidenceIds ?? this.courseEvidenceIds,
        sourceLevel: sourceLevel ?? this.sourceLevel,
        constructRationale:
            constructRationale ?? this.constructRationale,
        guardrailIndicatorIds:
            guardrailIndicatorIds ?? this.guardrailIndicatorIds,
        safetyRule: safetyRule ?? this.safetyRule,
        smallerVersion: smallerVersion ?? this.smallerVersion,
        counterEvidencePrompt:
            counterEvidencePrompt ?? this.counterEvidencePrompt,
        quality: quality ?? this.quality,
        stage: stage ?? this.stage,
        evidenceReviewPassed:
            evidenceReviewPassed ?? this.evidenceReviewPassed,
        constructReviewPassed:
            constructReviewPassed ?? this.constructReviewPassed,
        cognitiveInterviewPassed:
            cognitiveInterviewPassed ?? this.cognitiveInterviewPassed,
        pilotPassed: pilotPassed ?? this.pilotPassed,
        pilotSampleSize:
            (pilotSampleSize ?? this.pilotSampleSize).clamp(0, 100000).toInt(),
        pilotNotes: pilotNotes ?? this.pilotNotes,
        author: author ?? this.author,
        reviewer: reviewer ?? this.reviewer,
        signer: signer ?? this.signer,
        retirementReason: retirementReason ?? this.retirementReason,
        modelVersion: modelVersion ?? this.modelVersion,
        promptVersion: promptVersion ?? this.promptVersion,
        indicatorVersion: indicatorVersion ?? this.indicatorVersion,
        courseVersion: courseVersion ?? this.courseVersion,
        version: (version ?? this.version).clamp(1, 100000).toInt(),
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'candidate_id': candidateId,
        'parent_candidate_id': parentCandidateId,
        'kind': kind.name,
        'primary_indicator_id': primaryIndicatorId,
        'indicator_name': indicatorName,
        'indicator_type': indicatorType,
        'content_code': contentCode,
        'content': content,
        'scale_or_duration': scaleOrDuration,
        'scoring_direction': scoringDirection,
        'recall_window': recallWindow,
        'answer_options': answerOptions,
        'correct_answer_index': correctAnswerIndex,
        'course_evidence_ids': courseEvidenceIds,
        'source_level': sourceLevel,
        'construct_rationale': constructRationale,
        'guardrail_indicator_ids': guardrailIndicatorIds,
        'safety_rule': safetyRule,
        'smaller_version': smallerVersion,
        'counter_evidence_prompt': counterEvidencePrompt,
        'quality': quality.toJson(),
        'stage': stage.name,
        'evidence_review_passed': evidenceReviewPassed,
        'construct_review_passed': constructReviewPassed,
        'cognitive_interview_passed': cognitiveInterviewPassed,
        'pilot_passed': pilotPassed,
        'pilot_sample_size': pilotSampleSize,
        'pilot_notes': pilotNotes,
        'author': author,
        'reviewer': reviewer,
        'signer': signer,
        'retirement_reason': retirementReason,
        'model_version': modelVersion,
        'prompt_version': promptVersion,
        'indicator_version': indicatorVersion,
        'course_version': courseVersion,
        'version': version,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory CheckupContentCandidate.fromJson(Map<String, dynamic> json) =>
      CheckupContentCandidate(
        candidateId: (json['candidate_id'] ?? '').toString(),
        parentCandidateId: json['parent_candidate_id']?.toString(),
        kind: CheckupContentKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => CheckupContentKind.assessmentItem,
        ),
        primaryIndicatorId:
            (json['primary_indicator_id'] ?? '').toString(),
        indicatorName: (json['indicator_name'] ?? '').toString(),
        indicatorType: (json['indicator_type'] ?? '').toString(),
        contentCode: (json['content_code'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        scaleOrDuration: (json['scale_or_duration'] ?? '').toString(),
        scoringDirection: (json['scoring_direction'] ?? '').toString(),
        recallWindow: (json['recall_window'] ?? '').toString(),
        answerOptions: _stringList(json['answer_options']),
        correctAnswerIndex:
            (json['correct_answer_index'] as num?)?.toInt(),
        courseEvidenceIds: _stringList(json['course_evidence_ids']),
        sourceLevel: (json['source_level'] ?? '').toString(),
        constructRationale:
            (json['construct_rationale'] ?? '').toString(),
        guardrailIndicatorIds:
            _stringList(json['guardrail_indicator_ids']),
        safetyRule: (json['safety_rule'] ?? '').toString(),
        smallerVersion: (json['smaller_version'] ?? '').toString(),
        counterEvidencePrompt:
            (json['counter_evidence_prompt'] ?? '').toString(),
        quality: CheckupCandidateQuality.fromJson(
          Map<String, dynamic>.from(
            json['quality'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        stage: CheckupCandidateStage.values.firstWhere(
          (value) => value.name == json['stage'],
          orElse: () => CheckupCandidateStage.draft,
        ),
        evidenceReviewPassed: json['evidence_review_passed'] == true,
        constructReviewPassed: json['construct_review_passed'] == true,
        cognitiveInterviewPassed:
            json['cognitive_interview_passed'] == true,
        pilotPassed: json['pilot_passed'] == true,
        pilotSampleSize:
            (json['pilot_sample_size'] as num?)?.toInt() ?? 0,
        pilotNotes: (json['pilot_notes'] ?? '').toString(),
        author: (json['author'] ?? '').toString(),
        reviewer: (json['reviewer'] ?? '').toString(),
        signer: (json['signer'] ?? '').toString(),
        retirementReason: (json['retirement_reason'] ?? '').toString(),
        modelVersion: (json['model_version'] ?? '').toString(),
        promptVersion: (json['prompt_version'] ?? '').toString(),
        indicatorVersion: (json['indicator_version'] ?? '').toString(),
        courseVersion: (json['course_version'] ?? '').toString(),
        version: (json['version'] as num?)?.toInt() ?? 1,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupContentAuditEvent {
  final String id;
  final String candidateId;
  final CheckupCandidateStage fromStage;
  final CheckupCandidateStage toStage;
  final String actor;
  final String note;
  final int createdAtMs;

  const CheckupContentAuditEvent({
    required this.id,
    required this.candidateId,
    required this.fromStage,
    required this.toStage,
    required this.actor,
    required this.note,
    required this.createdAtMs,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'candidate_id': candidateId,
        'from_stage': fromStage.name,
        'to_stage': toStage.name,
        'actor': actor,
        'note': note,
        'created_at_ms': createdAtMs,
      };

  factory CheckupContentAuditEvent.fromJson(Map<String, dynamic> json) =>
      CheckupContentAuditEvent(
        id: (json['id'] ?? '').toString(),
        candidateId: (json['candidate_id'] ?? '').toString(),
        fromStage: CheckupCandidateStage.values.firstWhere(
          (value) => value.name == json['from_stage'],
          orElse: () => CheckupCandidateStage.draft,
        ),
        toStage: CheckupCandidateStage.values.firstWhere(
          (value) => value.name == json['to_stage'],
          orElse: () => CheckupCandidateStage.draft,
        ),
        actor: (json['actor'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupCandidateValidation {
  final List<String> blockingIssues;
  final List<String> warnings;

  const CheckupCandidateValidation({
    required this.blockingIssues,
    required this.warnings,
  });

  bool get valid => blockingIssues.isEmpty;
}

class CheckupCandidateTransition {
  final CheckupContentCandidate candidate;
  final CheckupContentAuditEvent auditEvent;

  const CheckupCandidateTransition({
    required this.candidate,
    required this.auditEvent,
  });
}

class MentalHealthContentGovernanceEngine {
  static const List<String> behaviorLevels = <String>[
    'B0',
    'B1',
    'B2',
    'B3',
    'B4',
  ];

  const MentalHealthContentGovernanceEngine();

  List<CheckupContentGenerationPlan> buildGenerationQueue(
    List<CheckupIndicator> indicators,
  ) {
    final byLecture = <int, List<CheckupIndicator>>{};
    for (final indicator in indicators) {
      byLecture.putIfAbsent(
        indicator.lecture,
        () => <CheckupIndicator>[],
      ).add(indicator);
    }
    return indicators.map((indicator) {
      final lecturePeers =
          byLecture[indicator.lecture] ?? const <CheckupIndicator>[];
      final guardrails = lecturePeers
          .where((peer) {
            if (peer.id == indicator.id) return false;
            if (indicator.type.contains('风险')) {
              return peer.type.contains('保护');
            }
            return peer.type.contains('风险');
          })
          .take(2)
          .map((peer) => peer.id)
          .toList(growable: false);
      final evidenceIds = <String>{
        indicator.definitionLocation,
        indicator.lowLocation,
        indicator.highLocation,
        indicator.actionLocation,
      }..removeWhere((value) => value.trim().isEmpty);
      return CheckupContentGenerationPlan(
        indicatorId: indicator.id,
        lecture: indicator.lecture,
        indicatorName: indicator.name,
        indicatorType: indicator.type,
        itemTypeCodes: _itemTypesFor(indicator),
        behaviorLevels: behaviorLevels,
        evidenceIds: evidenceIds.toList(growable: false),
        guardrailIndicatorIds: guardrails,
        sourceLevel: indicator.directness.contains('直接证据较强')
            ? 'C1候选直接证据'
            : 'C2课程机制推导',
        reviewStatus: indicator.reviewStatus,
      );
    }).toList(growable: false);
  }

  CheckupContentCandidate createLocalDraft({
    required CheckupContentGenerationPlan plan,
    required String contentCode,
    required String courseVersion,
    DateTime? now,
    String author = '本地模板',
  }) {
    if (!plan.itemTypeCodes.contains(contentCode) &&
        !plan.behaviorLevels.contains(contentCode)) {
      throw ArgumentError('生成计划不包含内容类型：$contentCode');
    }
    final clock = now ?? DateTime.now();
    final isBehavior = contentCode.startsWith('B');
    final template = isBehavior
        ? _behaviorTemplate(plan, contentCode)
        : _itemTemplate(plan, contentCode);
    final candidateId =
        'AI-C-${plan.indicatorId}-$contentCode-${clock.microsecondsSinceEpoch}';
    return CheckupContentCandidate(
      candidateId: candidateId,
      kind: isBehavior
          ? CheckupContentKind.behaviorTask
          : CheckupContentKind.assessmentItem,
      primaryIndicatorId: plan.indicatorId,
      indicatorName: plan.indicatorName,
      indicatorType: plan.indicatorType,
      contentCode: contentCode,
      content: template.content,
      scaleOrDuration: template.scaleOrDuration,
      scoringDirection: template.scoringDirection,
      recallWindow: template.recallWindow,
      answerOptions: template.answerOptions,
      correctAnswerIndex: template.correctAnswerIndex,
      courseEvidenceIds: plan.evidenceIds,
      sourceLevel: plan.sourceLevel,
      constructRationale:
          '仅测量 ${plan.indicatorId}：${plan.indicatorName}。',
      guardrailIndicatorIds: plan.guardrailIndicatorIds,
      safetyRule: template.safetyRule,
      smallerVersion: template.smallerVersion,
      counterEvidencePrompt: template.counterEvidencePrompt,
      quality: const CheckupCandidateQuality(
        indicatorConsistency: 88,
        courseFidelity: 70,
        nonDuplication: 80,
        measurability: 86,
        scaleWindowFit: 90,
        bidirectionalLogic: 78,
        safety: 92,
      ),
      author: author,
      modelVersion: 'local-template',
      promptVersion: 'content-governance-v1',
      indicatorVersion: 'V2.3-345',
      courseVersion: courseVersion,
      createdAtMs: clock.millisecondsSinceEpoch,
      updatedAtMs: clock.millisecondsSinceEpoch,
    );
  }

  CheckupCandidateValidation validate(CheckupContentCandidate candidate) {
    final blocking = <String>[];
    final warnings = <String>[];
    if (candidate.candidateId.trim().isEmpty) blocking.add('缺少candidate_id');
    if (candidate.primaryIndicatorId.trim().isEmpty) {
      blocking.add('缺少primary_indicator_id');
    }
    if (candidate.content.trim().isEmpty) blocking.add('题干或任务为空');
    if (candidate.scaleOrDuration.trim().isEmpty) {
      blocking.add('缺少量尺或期限');
    }
    if (candidate.scoringDirection.trim().isEmpty) {
      blocking.add('缺少计分方向');
    }
    if (candidate.courseEvidenceIds.isEmpty) blocking.add('无课程证据');
    if (candidate.sourceLevel != 'C1候选直接证据' &&
        candidate.sourceLevel != 'C2课程机制推导') {
      blocking.add('来源等级必须明确为C1或C2候选');
    }
    if (candidate.constructRationale.trim().isEmpty) {
      blocking.add('缺少单一构念理由');
    }
    if (candidate.safetyRule.trim().isEmpty) blocking.add('无安全规则');
    if (candidate.contentCode == 'A3' &&
        candidate.recallWindow.trim().isEmpty) {
      blocking.add('A3近期观察题缺少明确回忆时间窗');
    }
    if (candidate.contentCode == 'A7') {
      if (candidate.answerOptions.length < 3) {
        blocking.add('A7情境判断题至少需要3个选项');
      }
      final correct = candidate.correctAnswerIndex;
      if (correct == null ||
          correct < 0 ||
          correct >= candidate.answerOptions.length) {
        blocking.add('A7情境判断题缺少有效答案');
      }
    }
    if (candidate.kind == CheckupContentKind.behaviorTask) {
      if (candidate.contentCode == 'B0' &&
          !candidate.content.contains('记录') &&
          !candidate.content.contains('观察')) {
        blocking.add('B0只能观察基线，必须要求记录或观察');
      }
      if (candidate.contentCode == 'B1' &&
          candidate.smallerVersion.trim().isEmpty) {
        blocking.add('B1必须提供更小版本');
      }
      if (candidate.contentCode == 'B2' &&
          candidate.counterEvidencePrompt.trim().isEmpty) {
        blocking.add('B2必须保留反证');
      }
      if (candidate.contentCode == 'B4' &&
          candidate.counterEvidencePrompt.trim().isEmpty) {
        blocking.add('B4必须包含跨情境或复发预案证据');
      }
    }
    if (candidate.indicatorType.contains('风险') &&
        candidate.kind == CheckupContentKind.behaviorTask &&
        !candidate.safetyRule.contains('不得练习风险行为')) {
      blocking.add('风险型指标的任务不得让用户练习风险行为');
    }
    blocking.addAll(candidate.quality.gateFailures);
    if (candidate.contentCode == 'A8') {
      warnings.add('A8开放文本只能本地结构化，不得单独触发严重报警');
    }
    if (candidate.guardrailIndicatorIds.isEmpty) {
      warnings.add('尚未绑定制衡指标，正式发布前应人工确认');
    }
    return CheckupCandidateValidation(
      blockingIssues: blocking,
      warnings: warnings,
    );
  }

  CheckupCandidateTransition transition({
    required CheckupContentCandidate candidate,
    required CheckupCandidateStage target,
    required String actor,
    required String note,
    DateTime? now,
  }) {
    final normalizedActor = actor.trim();
    if (normalizedActor.isEmpty) throw StateError('必须记录操作人');
    if (!_allowedTargets(candidate.stage).contains(target)) {
      throw StateError(
        '不允许从${candidate.stage.label}直接进入${target.label}',
      );
    }
    if (target == CheckupCandidateStage.candidate) {
      final validation = validate(candidate);
      if (!validation.valid) {
        throw StateError(validation.blockingIssues.join('；'));
      }
    }
    if (target == CheckupCandidateStage.cognitiveInterview) {
      if (!candidate.evidenceReviewPassed ||
          !candidate.constructReviewPassed) {
        throw StateError('进入认知访谈前必须通过课程证据和构念独立审核');
      }
      if (_sameIdentity(candidate.author, normalizedActor) ||
          normalizedActor.toLowerCase().contains('ai')) {
        throw StateError('独立审核人不能与作者相同，也不能由AI代签');
      }
    }
    if (target == CheckupCandidateStage.pilot &&
        !candidate.cognitiveInterviewPassed) {
      throw StateError('进入试测前必须通过目标用户认知访谈');
    }
    if (target == CheckupCandidateStage.official) {
      if (!candidate.pilotPassed || candidate.pilotSampleSize <= 0) {
        throw StateError('正式发布前必须完成并通过小样本试测');
      }
      if (normalizedActor.toLowerCase().contains('ai')) {
        throw StateError('AI不能签发正式版本');
      }
      if (!candidate.quality.passesPublishedThresholds) {
        throw StateError(candidate.quality.gateFailures.join('；'));
      }
    }
    if (target == CheckupCandidateStage.retired && note.trim().isEmpty) {
      throw StateError('停用正式内容必须记录原因');
    }
    final clock = now ?? DateTime.now();
    final next = candidate.copyWith(
      stage: target,
      reviewer: target == CheckupCandidateStage.cognitiveInterview
          ? normalizedActor
          : candidate.reviewer,
      signer: target == CheckupCandidateStage.official
          ? normalizedActor
          : candidate.signer,
      retirementReason: target == CheckupCandidateStage.retired
          ? note.trim()
          : candidate.retirementReason,
      updatedAtMs: clock.millisecondsSinceEpoch,
    );
    return CheckupCandidateTransition(
      candidate: next,
      auditEvent: CheckupContentAuditEvent(
        id: 'audit-${candidate.candidateId}-${clock.microsecondsSinceEpoch}',
        candidateId: candidate.candidateId,
        fromStage: candidate.stage,
        toStage: target,
        actor: normalizedActor,
        note: note.trim(),
        createdAtMs: clock.millisecondsSinceEpoch,
      ),
    );
  }

  CheckupContentCandidate reviseOfficial({
    required CheckupContentCandidate official,
    required String author,
    DateTime? now,
  }) {
    if (official.stage != CheckupCandidateStage.official &&
        official.stage != CheckupCandidateStage.retired) {
      throw StateError('只有正式或已停用版本可以派生修订版');
    }
    final clock = now ?? DateTime.now();
    return official.copyWith(
      candidateId:
          '${official.candidateId}-R${official.version + 1}-${clock.microsecondsSinceEpoch}',
      parentCandidateId: official.candidateId,
      stage: CheckupCandidateStage.draft,
      evidenceReviewPassed: false,
      constructReviewPassed: false,
      cognitiveInterviewPassed: false,
      pilotPassed: false,
      pilotSampleSize: 0,
      pilotNotes: '',
      author: author.trim().isEmpty ? '本地编辑者' : author.trim(),
      reviewer: '',
      signer: '',
      retirementReason: '',
      version: official.version + 1,
      createdAtMs: clock.millisecondsSinceEpoch,
      updatedAtMs: clock.millisecondsSinceEpoch,
    );
  }

  static List<String> _itemTypesFor(CheckupIndicator indicator) {
    if (indicator.id.contains('-K')) {
      return const <String>['A1', 'A7', 'A9', 'A8'];
    }
    if (indicator.type.contains('风险')) {
      return const <String>['A5', 'A3', 'A4', 'A8'];
    }
    if (indicator.type.contains('功能')) {
      return const <String>['A6F', 'A6I', 'A3', 'A8'];
    }
    return const <String>['A2', 'A3', 'A5', 'A8'];
  }

  static Set<CheckupCandidateStage> _allowedTargets(
    CheckupCandidateStage stage,
  ) =>
      switch (stage) {
        CheckupCandidateStage.draft => <CheckupCandidateStage>{
            CheckupCandidateStage.candidate,
          },
        CheckupCandidateStage.candidate => <CheckupCandidateStage>{
            CheckupCandidateStage.cognitiveInterview,
          },
        CheckupCandidateStage.cognitiveInterview => <CheckupCandidateStage>{
            CheckupCandidateStage.pilot,
          },
        CheckupCandidateStage.pilot => <CheckupCandidateStage>{
            CheckupCandidateStage.official,
          },
        CheckupCandidateStage.official => <CheckupCandidateStage>{
            CheckupCandidateStage.retired,
          },
        CheckupCandidateStage.retired => const <CheckupCandidateStage>{},
      };

  static bool _sameIdentity(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();

  static _CandidateTemplate _itemTemplate(
    CheckupContentGenerationPlan plan,
    String code,
  ) {
    final name = plan.indicatorName;
    const safety =
        '若出现安全风险、现实功能明显恶化或强烈不适，停止普通题目解释并进入安全复核。';
    switch (code) {
      case 'A1':
        return _CandidateTemplate(
          content: '我有把握向他人准确解释“$name”的课程含义。',
          scaleOrDuration: '理解信心1—5',
          scoringDirection: '元认知自评，不进入K分',
          recallWindow: '此刻',
          safetyRule: safety,
        );
      case 'A7':
        return _CandidateTemplate(
          content: '下面哪一种做法最符合课程中“$name”的含义？',
          scaleOrDuration: '情境判断单选',
          scoringDirection: '客观计分',
          recallWindow: '此刻',
          answerOptions: <String>[
            '忽略现实约束，只重复积极口号',
            '结合课程原则、现实证据与有效行动',
            '把一次表现解释为固定人格',
            '只追求打卡，不检查功能结果',
          ],
          correctAnswerIndex: 1,
          safetyRule: safety,
        );
      case 'A9':
        return _CandidateTemplate(
          content: '完成“$name”客观题前，我对自己答对的把握程度是。',
          scaleOrDuration: '信心1—5，并与配套A7比较',
          scoringDirection: '元认知校准',
          recallWindow: '此刻',
          safetyRule: safety,
        );
      case 'A2':
        return _CandidateTemplate(
          content: '我认同“$name”是值得在现实生活中练习的课程原则。',
          scaleOrDuration: '同意度1—5',
          scoringDirection: '越高越健康',
          recallWindow: '当前稳定态度',
          safetyRule: safety,
        );
      case 'A4':
        return _CandidateTemplate(
          content: '即使现实证据与功能结果相反，坚持“$name”也一定正确。',
          scaleOrDuration: '同意度1—5',
          scoringDirection: '越高风险越高',
          recallWindow: '当前稳定态度',
          safetyRule: safety,
        );
      case 'A5':
        return _CandidateTemplate(
          content: '过去14天，当“$name”变得僵化并影响睡眠、关系或责任时，我仍难以及时调整。',
          scaleOrDuration: '频率0—4',
          scoringDirection: '越高风险越高',
          recallWindow: '过去14天',
          safetyRule: safety,
        );
      case 'A6F':
        return _CandidateTemplate(
          content: '过去14天，“$name”相关能力在学习、工作、关系或自我照护中真实出现。',
          scaleOrDuration: '频率0—4',
          scoringDirection: '越高越健康',
          recallWindow: '过去14天',
          safetyRule: safety,
        );
      case 'A6I':
        return _CandidateTemplate(
          content: '过去14天，“$name”相关困难对学习、工作、关系或自我照护造成影响。',
          scaleOrDuration: '影响0—4',
          scoringDirection: '越高风险越高',
          recallWindow: '过去14天',
          safetyRule: safety,
        );
      case 'A8':
        return _CandidateTemplate(
          content: '请回想过去14天一个与“$name”有关的具体事件：发生了什么、你做了什么、结果如何，哪些证据支持或冲突？',
          scaleOrDuration: '本地开放式内省',
          scoringDirection: '只作分析证据，不直接计分',
          recallWindow: '过去14天',
          safetyRule: safety,
        );
      case 'A3':
      default:
        return _CandidateTemplate(
          content: '过去14天，我在真实生活中表现出“$name”相关的可观察行为。',
          scaleOrDuration: '频率0—4',
          scoringDirection: plan.indicatorType.contains('风险')
              ? '越高风险越高'
              : '越高越健康',
          recallWindow: '过去14天',
          safetyRule: safety,
        );
    }
  }

  static _CandidateTemplate _behaviorTemplate(
    CheckupContentGenerationPlan plan,
    String code,
  ) {
    final name = plan.indicatorName;
    final riskRule = plan.indicatorType.contains('风险')
        ? '不得练习风险行为；只观察触发、替代行动和现实功能。'
        : '若痛苦、疲劳、睡眠、关系或现实责任明显恶化，立即减量或暂停。';
    switch (code) {
      case 'B0':
        return _CandidateTemplate(
          content: '连续7天只观察并记录“$name”的真实事件、次数与现实结果，不要求自己改变。',
          scaleOrDuration: '通常7天',
          scoringDirection: '行为基线，独立于干预执行分',
          recallWindow: '连续7天',
          safetyRule: riskRule,
        );
      case 'B1':
        return _CandidateTemplate(
          content: '完成一次5—15分钟的“$name”微型探针，记录行动前后感受与现实结果。',
          scaleOrDuration: '一次5—15分钟',
          scoringDirection: '探针反应，不回写基线',
          recallWindow: '单次',
          smallerVersion: '只完成2分钟或一个最小步骤，并允许跳过。',
          safetyRule: riskRule,
        );
      case 'B2':
        return _CandidateTemplate(
          content: '进行3—7天“$name”短期实验，记录完成率、有效结果、无效结果与环境条件。',
          scaleOrDuration: '通常3—7天',
          scoringDirection: '干预执行与功能结果分开',
          recallWindow: '3—7天',
          smallerVersion: '缩短为1天、一次最小行动。',
          counterEvidencePrompt: '记录至少一条不支持当前课程机制的反证。',
          safetyRule: riskRule,
        );
      case 'B3':
        return _CandidateTemplate(
          content: '把已验证有效的“$name”转成1项生活仪式，连续14—30天记录提示、连续性与障碍修正。',
          scaleOrDuration: '14—30天',
          scoringDirection: '仪式连续性不等于功能改善',
          recallWindow: '14—30天',
          smallerVersion: '仅保留1项仪式并降低频率。',
          counterEvidencePrompt: '记录机械打卡、疲劳或现实功能未改善的证据。',
          safetyRule: riskRule,
        );
      case 'B4':
      default:
        return _CandidateTemplate(
          content: '在至少两个不同情境中应用“$name”，建立30天以上的迁移维持与复发预案。',
          scaleOrDuration: '通常30天以上',
          scoringDirection: '跨情境功能与自主性',
          recallWindow: '30天以上',
          smallerVersion: '先在一个低风险情境中验证。',
          counterEvidencePrompt: '记录跨情境证据、复发信号和恢复预案是否有效。',
          safetyRule: riskRule,
        );
    }
  }
}

class _CandidateTemplate {
  final String content;
  final String scaleOrDuration;
  final String scoringDirection;
  final String recallWindow;
  final List<String> answerOptions;
  final int? correctAnswerIndex;
  final String safetyRule;
  final String smallerVersion;
  final String counterEvidencePrompt;

  const _CandidateTemplate({
    required this.content,
    required this.scaleOrDuration,
    required this.scoringDirection,
    required this.recallWindow,
    this.answerOptions = const <String>[],
    this.correctAnswerIndex,
    required this.safetyRule,
    this.smallerVersion = '',
    this.counterEvidencePrompt = '',
  });
}

List<String> _stringList(Object? value) =>
    (value as List? ?? const <Object?>[])
        .map((item) => item.toString())
        .toList(growable: false);
