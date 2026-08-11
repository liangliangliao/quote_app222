import 'mental_health_checkup_models.dart';
import 'mental_health_content_governance.dart';

class CheckupIndicatorCandidateQuality {
  final double courseEvidenceFit;
  final double constructClarity;
  final double nonDuplication;
  final double measurability;
  final double bidirectionalBalance;
  final double actionability;
  final double safety;

  const CheckupIndicatorCandidateQuality({
    this.courseEvidenceFit = 0,
    this.constructClarity = 0,
    this.nonDuplication = 0,
    this.measurability = 0,
    this.bidirectionalBalance = 0,
    this.actionability = 0,
    this.safety = 0,
  });

  double get overall =>
      courseEvidenceFit * 0.20 +
      constructClarity * 0.15 +
      nonDuplication * 0.15 +
      measurability * 0.15 +
      bidirectionalBalance * 0.10 +
      actionability * 0.10 +
      safety * 0.15;

  List<String> get gateFailures {
    final failures = <String>[];
    if (courseEvidenceFit < 80) failures.add('课程证据适配低于80');
    if (constructClarity < 80) failures.add('构念清晰度低于80');
    if (nonDuplication < 80) failures.add('非重复性低于80');
    if (measurability < 75) failures.add('可测量性低于75');
    if (bidirectionalBalance < 75) failures.add('双向解释低于75');
    if (safety < 90) failures.add('安全性低于90');
    if (overall < 80) failures.add('综合质量低于80');
    return failures;
  }

  bool get passesPublishedThresholds => gateFailures.isEmpty;

  CheckupIndicatorCandidateQuality copyWith({
    double? courseEvidenceFit,
    double? constructClarity,
    double? nonDuplication,
    double? measurability,
    double? bidirectionalBalance,
    double? actionability,
    double? safety,
  }) =>
      CheckupIndicatorCandidateQuality(
        courseEvidenceFit: _boundedIndicatorScore(
          courseEvidenceFit ?? this.courseEvidenceFit,
        ),
        constructClarity: _boundedIndicatorScore(
          constructClarity ?? this.constructClarity,
        ),
        nonDuplication: _boundedIndicatorScore(
          nonDuplication ?? this.nonDuplication,
        ),
        measurability:
            _boundedIndicatorScore(measurability ?? this.measurability),
        bidirectionalBalance: _boundedIndicatorScore(
          bidirectionalBalance ?? this.bidirectionalBalance,
        ),
        actionability:
            _boundedIndicatorScore(actionability ?? this.actionability),
        safety: _boundedIndicatorScore(safety ?? this.safety),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'course_evidence_fit': courseEvidenceFit,
        'construct_clarity': constructClarity,
        'non_duplication': nonDuplication,
        'measurability': measurability,
        'bidirectional_balance': bidirectionalBalance,
        'actionability': actionability,
        'safety': safety,
        'overall': overall,
      };

  factory CheckupIndicatorCandidateQuality.fromJson(
    Map<String, dynamic> json,
  ) =>
      CheckupIndicatorCandidateQuality(
        courseEvidenceFit: _boundedIndicatorScore(
          (json['course_evidence_fit'] as num?)?.toDouble(),
        ),
        constructClarity: _boundedIndicatorScore(
          (json['construct_clarity'] as num?)?.toDouble(),
        ),
        nonDuplication: _boundedIndicatorScore(
          (json['non_duplication'] as num?)?.toDouble(),
        ),
        measurability: _boundedIndicatorScore(
          (json['measurability'] as num?)?.toDouble(),
        ),
        bidirectionalBalance: _boundedIndicatorScore(
          (json['bidirectional_balance'] as num?)?.toDouble(),
        ),
        actionability: _boundedIndicatorScore(
          (json['actionability'] as num?)?.toDouble(),
        ),
        safety: _boundedIndicatorScore((json['safety'] as num?)?.toDouble()),
      );
}

class CheckupIndicatorCandidate {
  final String candidateId;
  final String? parentCandidateId;
  final String proposedIndicatorId;
  final int lecture;
  final String area;
  final String name;
  final String indicatorType;
  final String definition;
  final String lowPattern;
  final String highPattern;
  final String misuseRisk;
  final String functionalSignal;
  final String definitionLocation;
  final String lowLocation;
  final String highLocation;
  final String actionLocation;
  final List<String> evidenceLocationIds;
  final List<String> guardrailIndicatorIds;
  final List<String> possibleDuplicateIndicatorIds;
  final String sourceLevel;
  final String constructRationale;
  final String safetyBoundary;
  final CheckupIndicatorCandidateQuality quality;
  final CheckupCandidateStage stage;
  final bool evidenceReviewPassed;
  final bool constructReviewPassed;
  final bool expertReviewPassed;
  final bool cognitiveInterviewPassed;
  final bool pilotPassed;
  final int pilotSampleSize;
  final String pilotNotes;
  final String author;
  final String reviewer;
  final String signer;
  final String retirementReason;
  final int version;
  final String modelVersion;
  final String promptVersion;
  final String courseVersion;
  final int createdAtMs;
  final int updatedAtMs;

  const CheckupIndicatorCandidate({
    required this.candidateId,
    this.parentCandidateId,
    required this.proposedIndicatorId,
    required this.lecture,
    required this.area,
    required this.name,
    required this.indicatorType,
    required this.definition,
    required this.lowPattern,
    required this.highPattern,
    required this.misuseRisk,
    required this.functionalSignal,
    required this.definitionLocation,
    required this.lowLocation,
    required this.highLocation,
    required this.actionLocation,
    required this.evidenceLocationIds,
    required this.guardrailIndicatorIds,
    required this.possibleDuplicateIndicatorIds,
    required this.sourceLevel,
    required this.constructRationale,
    required this.safetyBoundary,
    required this.quality,
    this.stage = CheckupCandidateStage.draft,
    this.evidenceReviewPassed = false,
    this.constructReviewPassed = false,
    this.expertReviewPassed = false,
    this.cognitiveInterviewPassed = false,
    this.pilotPassed = false,
    this.pilotSampleSize = 0,
    this.pilotNotes = '',
    required this.author,
    this.reviewer = '',
    this.signer = '',
    this.retirementReason = '',
    this.version = 1,
    required this.modelVersion,
    required this.promptVersion,
    required this.courseVersion,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isReadOnly =>
      stage == CheckupCandidateStage.official ||
      stage == CheckupCandidateStage.retired;

  CheckupIndicatorCandidate copyWith({
    String? candidateId,
    String? parentCandidateId,
    String? proposedIndicatorId,
    int? lecture,
    String? area,
    String? name,
    String? indicatorType,
    String? definition,
    String? lowPattern,
    String? highPattern,
    String? misuseRisk,
    String? functionalSignal,
    String? definitionLocation,
    String? lowLocation,
    String? highLocation,
    String? actionLocation,
    List<String>? evidenceLocationIds,
    List<String>? guardrailIndicatorIds,
    List<String>? possibleDuplicateIndicatorIds,
    String? sourceLevel,
    String? constructRationale,
    String? safetyBoundary,
    CheckupIndicatorCandidateQuality? quality,
    CheckupCandidateStage? stage,
    bool? evidenceReviewPassed,
    bool? constructReviewPassed,
    bool? expertReviewPassed,
    bool? cognitiveInterviewPassed,
    bool? pilotPassed,
    int? pilotSampleSize,
    String? pilotNotes,
    String? author,
    String? reviewer,
    String? signer,
    String? retirementReason,
    int? version,
    String? modelVersion,
    String? promptVersion,
    String? courseVersion,
    int? createdAtMs,
    int? updatedAtMs,
  }) =>
      CheckupIndicatorCandidate(
        candidateId: candidateId ?? this.candidateId,
        parentCandidateId: parentCandidateId ?? this.parentCandidateId,
        proposedIndicatorId: proposedIndicatorId ?? this.proposedIndicatorId,
        lecture: lecture ?? this.lecture,
        area: area ?? this.area,
        name: name ?? this.name,
        indicatorType: indicatorType ?? this.indicatorType,
        definition: definition ?? this.definition,
        lowPattern: lowPattern ?? this.lowPattern,
        highPattern: highPattern ?? this.highPattern,
        misuseRisk: misuseRisk ?? this.misuseRisk,
        functionalSignal: functionalSignal ?? this.functionalSignal,
        definitionLocation: definitionLocation ?? this.definitionLocation,
        lowLocation: lowLocation ?? this.lowLocation,
        highLocation: highLocation ?? this.highLocation,
        actionLocation: actionLocation ?? this.actionLocation,
        evidenceLocationIds: evidenceLocationIds ?? this.evidenceLocationIds,
        guardrailIndicatorIds:
            guardrailIndicatorIds ?? this.guardrailIndicatorIds,
        possibleDuplicateIndicatorIds:
            possibleDuplicateIndicatorIds ?? this.possibleDuplicateIndicatorIds,
        sourceLevel: sourceLevel ?? this.sourceLevel,
        constructRationale: constructRationale ?? this.constructRationale,
        safetyBoundary: safetyBoundary ?? this.safetyBoundary,
        quality: quality ?? this.quality,
        stage: stage ?? this.stage,
        evidenceReviewPassed: evidenceReviewPassed ?? this.evidenceReviewPassed,
        constructReviewPassed:
            constructReviewPassed ?? this.constructReviewPassed,
        expertReviewPassed: expertReviewPassed ?? this.expertReviewPassed,
        cognitiveInterviewPassed:
            cognitiveInterviewPassed ?? this.cognitiveInterviewPassed,
        pilotPassed: pilotPassed ?? this.pilotPassed,
        pilotSampleSize: pilotSampleSize ?? this.pilotSampleSize,
        pilotNotes: pilotNotes ?? this.pilotNotes,
        author: author ?? this.author,
        reviewer: reviewer ?? this.reviewer,
        signer: signer ?? this.signer,
        retirementReason: retirementReason ?? this.retirementReason,
        version: version ?? this.version,
        modelVersion: modelVersion ?? this.modelVersion,
        promptVersion: promptVersion ?? this.promptVersion,
        courseVersion: courseVersion ?? this.courseVersion,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'candidate_id': candidateId,
        'parent_candidate_id': parentCandidateId,
        'proposed_indicator_id': proposedIndicatorId,
        'lecture': lecture,
        'area': area,
        'name': name,
        'indicator_type': indicatorType,
        'definition': definition,
        'low_pattern': lowPattern,
        'high_pattern': highPattern,
        'misuse_risk': misuseRisk,
        'functional_signal': functionalSignal,
        'definition_location': definitionLocation,
        'low_location': lowLocation,
        'high_location': highLocation,
        'action_location': actionLocation,
        'evidence_location_ids': evidenceLocationIds,
        'guardrail_indicator_ids': guardrailIndicatorIds,
        'possible_duplicate_indicator_ids': possibleDuplicateIndicatorIds,
        'source_level': sourceLevel,
        'construct_rationale': constructRationale,
        'safety_boundary': safetyBoundary,
        'quality': quality.toJson(),
        'stage': stage.name,
        'evidence_review_passed': evidenceReviewPassed,
        'construct_review_passed': constructReviewPassed,
        'expert_review_passed': expertReviewPassed,
        'cognitive_interview_passed': cognitiveInterviewPassed,
        'pilot_passed': pilotPassed,
        'pilot_sample_size': pilotSampleSize,
        'pilot_notes': pilotNotes,
        'author': author,
        'reviewer': reviewer,
        'signer': signer,
        'retirement_reason': retirementReason,
        'version': version,
        'model_version': modelVersion,
        'prompt_version': promptVersion,
        'course_version': courseVersion,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory CheckupIndicatorCandidate.fromJson(Map<String, dynamic> json) =>
      CheckupIndicatorCandidate(
        candidateId: (json['candidate_id'] ?? '').toString(),
        parentCandidateId: json['parent_candidate_id']?.toString(),
        proposedIndicatorId: (json['proposed_indicator_id'] ?? '').toString(),
        lecture: (json['lecture'] as num?)?.toInt() ?? 0,
        area: (json['area'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        indicatorType: (json['indicator_type'] ?? '').toString(),
        definition: (json['definition'] ?? '').toString(),
        lowPattern: (json['low_pattern'] ?? '').toString(),
        highPattern: (json['high_pattern'] ?? '').toString(),
        misuseRisk: (json['misuse_risk'] ?? '').toString(),
        functionalSignal: (json['functional_signal'] ?? '').toString(),
        definitionLocation: (json['definition_location'] ?? '').toString(),
        lowLocation: (json['low_location'] ?? '').toString(),
        highLocation: (json['high_location'] ?? '').toString(),
        actionLocation: (json['action_location'] ?? '').toString(),
        evidenceLocationIds: _indicatorStringList(
          json['evidence_location_ids'],
        ),
        guardrailIndicatorIds: _indicatorStringList(
          json['guardrail_indicator_ids'],
        ),
        possibleDuplicateIndicatorIds: _indicatorStringList(
          json['possible_duplicate_indicator_ids'],
        ),
        sourceLevel: (json['source_level'] ?? '').toString(),
        constructRationale: (json['construct_rationale'] ?? '').toString(),
        safetyBoundary: (json['safety_boundary'] ?? '').toString(),
        quality: CheckupIndicatorCandidateQuality.fromJson(
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
        expertReviewPassed: json['expert_review_passed'] == true,
        cognitiveInterviewPassed: json['cognitive_interview_passed'] == true,
        pilotPassed: json['pilot_passed'] == true,
        pilotSampleSize: (json['pilot_sample_size'] as num?)?.toInt() ?? 0,
        pilotNotes: (json['pilot_notes'] ?? '').toString(),
        author: (json['author'] ?? '').toString(),
        reviewer: (json['reviewer'] ?? '').toString(),
        signer: (json['signer'] ?? '').toString(),
        retirementReason: (json['retirement_reason'] ?? '').toString(),
        version: (json['version'] as num?)?.toInt() ?? 1,
        modelVersion: (json['model_version'] ?? '').toString(),
        promptVersion: (json['prompt_version'] ?? '').toString(),
        courseVersion: (json['course_version'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );

  CheckupIndicator toPublishedIndicator() => CheckupIndicator(
        id: proposedIndicatorId,
        lecture: lecture,
        area: area,
        name: name,
        type: indicatorType,
        definitionLocation: definitionLocation,
        lowLocation: lowLocation,
        highLocation: highLocation,
        actionLocation: actionLocation,
        directEvidenceCount: evidenceLocationIds.length,
        directness: sourceLevel.startsWith('C1') ? '直接证据较强' : '课程机制推导',
        reviewStatus: '已由课程专家签发',
      );
}

class CheckupIndicatorAuditEvent {
  final String id;
  final String candidateId;
  final CheckupCandidateStage fromStage;
  final CheckupCandidateStage toStage;
  final String actor;
  final String note;
  final int createdAtMs;

  const CheckupIndicatorAuditEvent({
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

  factory CheckupIndicatorAuditEvent.fromJson(Map<String, dynamic> json) =>
      CheckupIndicatorAuditEvent(
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

class CheckupIndicatorCandidateValidation {
  final List<String> blockingIssues;
  final List<String> warnings;

  const CheckupIndicatorCandidateValidation({
    required this.blockingIssues,
    required this.warnings,
  });

  bool get valid => blockingIssues.isEmpty;
}

class CheckupIndicatorTransition {
  final CheckupIndicatorCandidate candidate;
  final CheckupIndicatorAuditEvent auditEvent;

  const CheckupIndicatorTransition({
    required this.candidate,
    required this.auditEvent,
  });
}

class MentalHealthIndicatorGovernanceEngine {
  static const Set<String> supportedTypes = <String>{
    '保护型',
    '风险型',
    '平衡型',
    '功能结果',
    '哨兵型',
  };

  const MentalHealthIndicatorGovernanceEngine();

  CheckupIndicatorCandidate createLocalDraft({
    required int lecture,
    required String area,
    required String courseVersion,
    required List<String> evidenceLocationIds,
    List<String> existingIndicatorIds = const <String>[],
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final sequence = clock.microsecondsSinceEpoch;
    final proposedId = 'IC-L${lecture.toString().padLeft(2, '0')}-$sequence';
    return CheckupIndicatorCandidate(
      candidateId: 'IND-CAND-$sequence',
      proposedIndicatorId: proposedId,
      lecture: lecture,
      area: area.trim().isEmpty ? '待归类' : area.trim(),
      name: '待定义的课程候选指标',
      indicatorType: '平衡型',
      definition: '请根据课程证据定义单一、可观察且可复验的构念。',
      lowPattern: '待独立审核低端表现。',
      highPattern: '待独立审核高端表现与适用边界。',
      misuseRisk: '待检查僵化、高端误用和过度化风险。',
      functionalSignal: '待说明学习、工作、关系或自我照护中的现实表现。',
      definitionLocation:
          evidenceLocationIds.isEmpty ? '' : evidenceLocationIds.first,
      lowLocation: evidenceLocationIds.length > 1 ? evidenceLocationIds[1] : '',
      highLocation:
          evidenceLocationIds.length > 2 ? evidenceLocationIds[2] : '',
      actionLocation:
          evidenceLocationIds.length > 3 ? evidenceLocationIds[3] : '',
      evidenceLocationIds: evidenceLocationIds.toSet().toList(),
      guardrailIndicatorIds: const <String>[],
      possibleDuplicateIndicatorIds: existingIndicatorIds.take(5).toList(),
      sourceLevel: 'C2课程机制推导',
      constructRationale: '本地模板只建立治理骨架，不代表课程已经直接支持。',
      safetyBoundary: '不得将课程候选指标解释为医学疾病或人格定论。',
      quality: const CheckupIndicatorCandidateQuality(
        courseEvidenceFit: 60,
        constructClarity: 60,
        nonDuplication: 50,
        measurability: 60,
        bidirectionalBalance: 60,
        actionability: 60,
        safety: 95,
      ),
      author: '本地编辑者',
      modelVersion: 'local-template',
      promptVersion: 'indicator-governance-v1',
      courseVersion: courseVersion,
      createdAtMs: clock.millisecondsSinceEpoch,
      updatedAtMs: clock.millisecondsSinceEpoch,
    );
  }

  CheckupIndicatorCandidateValidation validate(
    CheckupIndicatorCandidate candidate, {
    Iterable<CheckupIndicator> existingIndicators = const <CheckupIndicator>[],
  }) {
    final blocking = <String>[];
    final warnings = <String>[];
    if (candidate.candidateId.trim().isEmpty) blocking.add('缺少candidate_id');
    if (candidate.proposedIndicatorId.trim().isEmpty) {
      blocking.add('缺少proposed_indicator_id');
    } else if (!RegExp(
      r'^IC-L\d{2}-\d+(?:-[A-Za-z0-9._-]+)?$',
    ).hasMatch(candidate.proposedIndicatorId)) {
      blocking.add('候选指标ID格式无效');
    }
    if (candidate.lecture < 1 || candidate.lecture > 23) {
      blocking.add('Lecture必须在1—23之间');
    }
    if (candidate.name.trim().length < 2) blocking.add('候选指标名称过短');
    if (!supportedTypes.contains(candidate.indicatorType)) {
      blocking.add('指标类型不受支持');
    }
    if (candidate.definition.trim().length < 12) blocking.add('构念定义不足');
    if (candidate.lowPattern.trim().isEmpty) blocking.add('缺少低端表现');
    if (candidate.highPattern.trim().isEmpty) blocking.add('缺少高端表现');
    if (candidate.misuseRisk.trim().isEmpty) blocking.add('缺少高端误用风险');
    if (candidate.functionalSignal.trim().isEmpty) blocking.add('缺少功能结果');
    if (candidate.evidenceLocationIds.isEmpty ||
        candidate.definitionLocation.trim().isEmpty) {
      blocking.add('没有可定位的课程证据');
    }
    final evidenceIds = candidate.evidenceLocationIds.toSet();
    for (final location in <String>[
      candidate.definitionLocation,
      candidate.lowLocation,
      candidate.highLocation,
      candidate.actionLocation,
    ].where((value) => value.trim().isNotEmpty)) {
      if (!evidenceIds.contains(location)) {
        blocking.add('角色定位ID必须同时列入全部课程证据ID');
        break;
      }
    }
    if (candidate.sourceLevel != 'C1候选直接证据' &&
        candidate.sourceLevel != 'C2课程机制推导') {
      blocking.add('来源等级必须明确为C1或C2候选');
    }
    if (candidate.constructRationale.trim().isEmpty) {
      blocking.add('缺少单一构念说明');
    }
    if (candidate.safetyBoundary.trim().isEmpty) {
      blocking.add('缺少安全边界');
    }
    blocking.addAll(candidate.quality.gateFailures);

    final normalizedName = candidate.name.trim().toLowerCase();
    final exactDuplicate = existingIndicators.any(
      (indicator) =>
          indicator.id != candidate.proposedIndicatorId &&
          indicator.name.trim().toLowerCase() == normalizedName,
    );
    if (exactDuplicate) blocking.add('与现有指标名称完全重复');
    if (candidate.possibleDuplicateIndicatorIds.isNotEmpty) {
      warnings.add('存在可能重复指标，必须逐项记录保留或合并理由');
    }
    if (candidate.guardrailIndicatorIds.isEmpty) {
      warnings.add('尚未绑定制衡指标');
    }
    return CheckupIndicatorCandidateValidation(
      blockingIssues: blocking,
      warnings: warnings,
    );
  }

  CheckupIndicatorTransition transition({
    required CheckupIndicatorCandidate candidate,
    required CheckupCandidateStage target,
    required String actor,
    required String note,
    Iterable<CheckupIndicator> existingIndicators = const <CheckupIndicator>[],
    DateTime? now,
  }) {
    final normalizedActor = actor.trim();
    if (normalizedActor.isEmpty) throw StateError('必须记录操作人');
    if (!_allowedTargets(candidate.stage).contains(target)) {
      throw StateError('不允许从${candidate.stage.label}直接进入${target.label}');
    }
    if (target == CheckupCandidateStage.candidate) {
      final validation = validate(
        candidate,
        existingIndicators: existingIndicators,
      );
      if (!validation.valid) {
        throw StateError(validation.blockingIssues.join('；'));
      }
    }
    if (target == CheckupCandidateStage.cognitiveInterview) {
      if (!candidate.evidenceReviewPassed ||
          !candidate.constructReviewPassed ||
          !candidate.expertReviewPassed) {
        throw StateError('进入认知访谈前必须通过证据、构念和课程专家审核');
      }
      if (_sameIndicatorIdentity(candidate.author, normalizedActor) ||
          normalizedActor.toLowerCase().contains('ai')) {
        throw StateError('独立审核人不能与作者相同，也不能由AI代签');
      }
    }
    if (target == CheckupCandidateStage.pilot &&
        !candidate.cognitiveInterviewPassed) {
      throw StateError('进入试测前必须通过目标用户认知访谈');
    }
    if (target == CheckupCandidateStage.official) {
      final validation = validate(
        candidate,
        existingIndicators: existingIndicators,
      );
      if (!validation.valid) {
        throw StateError(validation.blockingIssues.join('；'));
      }
      if (!candidate.evidenceReviewPassed ||
          !candidate.constructReviewPassed ||
          !candidate.expertReviewPassed ||
          !candidate.cognitiveInterviewPassed) {
        throw StateError('正式发布前全部人工审核与认知访谈必须保持通过');
      }
      if (!candidate.pilotPassed || candidate.pilotSampleSize <= 0) {
        throw StateError('正式发布前必须完成并通过小样本试测');
      }
      if (normalizedActor.toLowerCase().contains('ai')) {
        throw StateError('AI不能签发正式指标');
      }
      if (_sameIndicatorIdentity(candidate.author, normalizedActor) ||
          _sameIndicatorIdentity(candidate.reviewer, normalizedActor)) {
        throw StateError('签发人不能与作者或独立审核人相同');
      }
      if (!candidate.quality.passesPublishedThresholds) {
        throw StateError(candidate.quality.gateFailures.join('；'));
      }
    }
    if ((target == CheckupCandidateStage.cognitiveInterview ||
            target == CheckupCandidateStage.pilot ||
            target == CheckupCandidateStage.official) &&
        note.trim().isEmpty) {
      throw StateError('该阶段变更必须记录依据或结果');
    }
    if (target == CheckupCandidateStage.retired && note.trim().isEmpty) {
      throw StateError('停用正式指标必须记录原因');
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
    return CheckupIndicatorTransition(
      candidate: next,
      auditEvent: CheckupIndicatorAuditEvent(
        id: 'indicator-audit-${candidate.candidateId}-'
            '${clock.microsecondsSinceEpoch}',
        candidateId: candidate.candidateId,
        fromStage: candidate.stage,
        toStage: target,
        actor: normalizedActor,
        note: note.trim(),
        createdAtMs: clock.millisecondsSinceEpoch,
      ),
    );
  }

  CheckupIndicatorCandidate reviseOfficial({
    required CheckupIndicatorCandidate official,
    required String author,
    DateTime? now,
  }) {
    if (official.stage != CheckupCandidateStage.official &&
        official.stage != CheckupCandidateStage.retired) {
      throw StateError('只有正式或已停用指标可以派生修订版');
    }
    final clock = now ?? DateTime.now();
    return official.copyWith(
      candidateId: '${official.candidateId}-R${official.version + 1}-'
          '${clock.microsecondsSinceEpoch}',
      parentCandidateId: official.candidateId,
      proposedIndicatorId: official.proposedIndicatorId,
      stage: CheckupCandidateStage.draft,
      evidenceReviewPassed: false,
      constructReviewPassed: false,
      expertReviewPassed: false,
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

  static bool _sameIndicatorIdentity(String left, String right) =>
      left.trim().toLowerCase() == right.trim().toLowerCase();
}

double _boundedIndicatorScore(double? value) =>
    (value ?? 0).clamp(0, 100).toDouble();

List<String> _indicatorStringList(Object? value) =>
    (value as List? ?? const <Object?>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
