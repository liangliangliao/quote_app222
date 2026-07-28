import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'mental_health_content_governance.dart';

enum CheckupExpertReviewRole {
  courseExpert,
  measurementReviewer,
  safetyReviewer,
}

extension CheckupExpertReviewRoleLabel on CheckupExpertReviewRole {
  String get label => switch (this) {
        CheckupExpertReviewRole.courseExpert => '课程专家',
        CheckupExpertReviewRole.measurementReviewer => '测量与构念审核',
        CheckupExpertReviewRole.safetyReviewer => '安全审核',
      };
}

enum CheckupSeedTargetKind {
  indicator,
  evidenceRelation,
  diagnosisPattern,
  prescription,
}

extension CheckupSeedTargetKindLabel on CheckupSeedTargetKind {
  String get label => switch (this) {
        CheckupSeedTargetKind.indicator => '指标',
        CheckupSeedTargetKind.evidenceRelation => '指标—证据关系',
        CheckupSeedTargetKind.diagnosisPattern => '课程机制模式',
        CheckupSeedTargetKind.prescription => '课程行动处方',
      };
}

class CheckupExpertReviewRecord {
  final String id;
  final String candidateId;
  final String candidateFingerprint;
  final String reviewerId;
  final CheckupExpertReviewRole role;
  final CheckupCandidateQuality quality;
  final bool passed;
  final String note;
  final int createdAtMs;

  const CheckupExpertReviewRecord({
    required this.id,
    required this.candidateId,
    required this.candidateFingerprint,
    required this.reviewerId,
    required this.role,
    required this.quality,
    required this.passed,
    required this.note,
    required this.createdAtMs,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'candidate_id': candidateId,
        'candidate_fingerprint': candidateFingerprint,
        'reviewer_id': reviewerId,
        'role': role.name,
        'quality': quality.toJson(),
        'passed': passed,
        'note': note,
        'created_at_ms': createdAtMs,
      };

  factory CheckupExpertReviewRecord.fromJson(Map<String, dynamic> json) =>
      CheckupExpertReviewRecord(
        id: (json['id'] ?? '').toString(),
        candidateId: (json['candidate_id'] ?? '').toString(),
        candidateFingerprint:
            (json['candidate_fingerprint'] ?? '').toString(),
        reviewerId: (json['reviewer_id'] ?? '').toString(),
        role: CheckupExpertReviewRole.values.firstWhere(
          (value) => value.name == json['role'],
          orElse: () => CheckupExpertReviewRole.courseExpert,
        ),
        quality: CheckupCandidateQuality.fromJson(
          Map<String, dynamic>.from(
            json['quality'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        passed: json['passed'] == true,
        note: (json['note'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupCognitiveInterviewRecord {
  final String id;
  final String candidateId;
  final String candidateFingerprint;
  final String participantKey;
  final bool understoodConstruct;
  final bool understoodRecallWindow;
  final bool optionsClear;
  final bool doubleBarrelDetected;
  final bool leadingLanguageDetected;
  final bool burdenAcceptable;
  final String note;
  final int createdAtMs;

  const CheckupCognitiveInterviewRecord({
    required this.id,
    required this.candidateId,
    required this.candidateFingerprint,
    required this.participantKey,
    required this.understoodConstruct,
    required this.understoodRecallWindow,
    required this.optionsClear,
    required this.doubleBarrelDetected,
    required this.leadingLanguageDetected,
    required this.burdenAcceptable,
    required this.note,
    required this.createdAtMs,
  });

  bool get misunderstood =>
      !understoodConstruct || !understoodRecallWindow || !optionsClear;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'candidate_id': candidateId,
        'candidate_fingerprint': candidateFingerprint,
        'participant_key': participantKey,
        'understood_construct': understoodConstruct,
        'understood_recall_window': understoodRecallWindow,
        'options_clear': optionsClear,
        'double_barrel_detected': doubleBarrelDetected,
        'leading_language_detected': leadingLanguageDetected,
        'burden_acceptable': burdenAcceptable,
        'note': note,
        'created_at_ms': createdAtMs,
      };

  factory CheckupCognitiveInterviewRecord.fromJson(
    Map<String, dynamic> json,
  ) =>
      CheckupCognitiveInterviewRecord(
        id: (json['id'] ?? '').toString(),
        candidateId: (json['candidate_id'] ?? '').toString(),
        candidateFingerprint:
            (json['candidate_fingerprint'] ?? '').toString(),
        participantKey: (json['participant_key'] ?? '').toString(),
        understoodConstruct: json['understood_construct'] == true,
        understoodRecallWindow: json['understood_recall_window'] == true,
        optionsClear: json['options_clear'] == true,
        doubleBarrelDetected: json['double_barrel_detected'] == true,
        leadingLanguageDetected: json['leading_language_detected'] == true,
        burdenAcceptable: json['burden_acceptable'] == true,
        note: (json['note'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupPilotObservation {
  final String id;
  final String candidateId;
  final String candidateFingerprint;
  final String participantKey;
  final bool missing;
  final int completionTimeMs;
  final double? itemScore;
  final double? restScore;
  final double? retestScore;
  final double? behaviorCriterion;
  final String fairnessGroup;
  final bool? expectedAlarm;
  final bool? actualAlarm;
  final int createdAtMs;

  const CheckupPilotObservation({
    required this.id,
    required this.candidateId,
    required this.candidateFingerprint,
    required this.participantKey,
    required this.missing,
    required this.completionTimeMs,
    this.itemScore,
    this.restScore,
    this.retestScore,
    this.behaviorCriterion,
    this.fairnessGroup = '',
    this.expectedAlarm,
    this.actualAlarm,
    required this.createdAtMs,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'candidate_id': candidateId,
        'candidate_fingerprint': candidateFingerprint,
        'participant_key': participantKey,
        'missing': missing,
        'completion_time_ms': completionTimeMs,
        'item_score': itemScore,
        'rest_score': restScore,
        'retest_score': retestScore,
        'behavior_criterion': behaviorCriterion,
        'fairness_group': fairnessGroup,
        'expected_alarm': expectedAlarm,
        'actual_alarm': actualAlarm,
        'created_at_ms': createdAtMs,
      };

  factory CheckupPilotObservation.fromJson(Map<String, dynamic> json) =>
      CheckupPilotObservation(
        id: (json['id'] ?? '').toString(),
        candidateId: (json['candidate_id'] ?? '').toString(),
        candidateFingerprint:
            (json['candidate_fingerprint'] ?? '').toString(),
        participantKey: (json['participant_key'] ?? '').toString(),
        missing: json['missing'] == true,
        completionTimeMs:
            (json['completion_time_ms'] as num?)?.toInt() ?? 0,
        itemScore: (json['item_score'] as num?)?.toDouble(),
        restScore: (json['rest_score'] as num?)?.toDouble(),
        retestScore: (json['retest_score'] as num?)?.toDouble(),
        behaviorCriterion:
            (json['behavior_criterion'] as num?)?.toDouble(),
        fairnessGroup: (json['fairness_group'] ?? '').toString(),
        expectedAlarm: json['expected_alarm'] as bool?,
        actualAlarm: json['actual_alarm'] as bool?,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupSeedReviewRecord {
  final String id;
  final CheckupSeedTargetKind targetKind;
  final String targetId;
  final String reviewerId;
  final String reviewerRole;
  final bool courseAccuracyPassed;
  final bool terminologyPassed;
  final bool safetyPassed;
  final String sourceVersion;
  final String note;
  final int createdAtMs;

  const CheckupSeedReviewRecord({
    required this.id,
    required this.targetKind,
    required this.targetId,
    required this.reviewerId,
    required this.reviewerRole,
    required this.courseAccuracyPassed,
    required this.terminologyPassed,
    required this.safetyPassed,
    required this.sourceVersion,
    required this.note,
    required this.createdAtMs,
  });

  bool get passed =>
      reviewerId.trim().isNotEmpty &&
      !reviewerId.toLowerCase().contains('ai') &&
      courseAccuracyPassed &&
      terminologyPassed &&
      safetyPassed;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'target_kind': targetKind.name,
        'target_id': targetId,
        'reviewer_id': reviewerId,
        'reviewer_role': reviewerRole,
        'course_accuracy_passed': courseAccuracyPassed,
        'terminology_passed': terminologyPassed,
        'safety_passed': safetyPassed,
        'source_version': sourceVersion,
        'note': note,
        'created_at_ms': createdAtMs,
      };

  factory CheckupSeedReviewRecord.fromJson(Map<String, dynamic> json) =>
      CheckupSeedReviewRecord(
        id: (json['id'] ?? '').toString(),
        targetKind: CheckupSeedTargetKind.values.firstWhere(
          (value) => value.name == json['target_kind'],
          orElse: () => CheckupSeedTargetKind.indicator,
        ),
        targetId: (json['target_id'] ?? '').toString(),
        reviewerId: (json['reviewer_id'] ?? '').toString(),
        reviewerRole: (json['reviewer_role'] ?? '').toString(),
        courseAccuracyPassed: json['course_accuracy_passed'] == true,
        terminologyPassed: json['terminology_passed'] == true,
        safetyPassed: json['safety_passed'] == true,
        sourceVersion: (json['source_version'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupValidationProtocol {
  static const CheckupValidationProtocol v25 =
      CheckupValidationProtocol(
    version: 'V2.5-D1-validation-1',
    minCognitiveParticipants: 5,
    maxMisunderstandingRate: 0.20,
    maxDoubleBarrelRate: 0.10,
    maxLeadingLanguageRate: 0.10,
    maxUnacceptableBurdenRate: 0.20,
    minPilotParticipants: 30,
    maxMissingRate: 0.10,
    maxMedianCompletionTimeMs: 120000,
    maxFloorOrCeilingRate: 0.80,
    minCorrelationPairs: 10,
    minItemRestCorrelation: 0.20,
    minRetestCorrelation: 0.60,
    minCriterionCorrelation: 0.20,
    minFairnessGroupSize: 5,
    maxNormalizedGroupGap: 0.25,
    minAlarmSensitivity: 0.80,
    minAlarmSpecificity: 0.70,
  );

  final String version;
  final int minCognitiveParticipants;
  final double maxMisunderstandingRate;
  final double maxDoubleBarrelRate;
  final double maxLeadingLanguageRate;
  final double maxUnacceptableBurdenRate;
  final int minPilotParticipants;
  final double maxMissingRate;
  final int maxMedianCompletionTimeMs;
  final double maxFloorOrCeilingRate;
  final int minCorrelationPairs;
  final double minItemRestCorrelation;
  final double minRetestCorrelation;
  final double minCriterionCorrelation;
  final int minFairnessGroupSize;
  final double maxNormalizedGroupGap;
  final double minAlarmSensitivity;
  final double minAlarmSpecificity;

  const CheckupValidationProtocol({
    required this.version,
    required this.minCognitiveParticipants,
    required this.maxMisunderstandingRate,
    required this.maxDoubleBarrelRate,
    required this.maxLeadingLanguageRate,
    required this.maxUnacceptableBurdenRate,
    required this.minPilotParticipants,
    required this.maxMissingRate,
    required this.maxMedianCompletionTimeMs,
    required this.maxFloorOrCeilingRate,
    required this.minCorrelationPairs,
    required this.minItemRestCorrelation,
    required this.minRetestCorrelation,
    required this.minCriterionCorrelation,
    required this.minFairnessGroupSize,
    required this.maxNormalizedGroupGap,
    required this.minAlarmSensitivity,
    required this.minAlarmSpecificity,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'version': version,
        'min_cognitive_participants': minCognitiveParticipants,
        'max_misunderstanding_rate': maxMisunderstandingRate,
        'max_double_barrel_rate': maxDoubleBarrelRate,
        'max_leading_language_rate': maxLeadingLanguageRate,
        'max_unacceptable_burden_rate': maxUnacceptableBurdenRate,
        'min_pilot_participants': minPilotParticipants,
        'max_missing_rate': maxMissingRate,
        'max_median_completion_time_ms': maxMedianCompletionTimeMs,
        'max_floor_or_ceiling_rate': maxFloorOrCeilingRate,
        'min_correlation_pairs': minCorrelationPairs,
        'min_item_rest_correlation': minItemRestCorrelation,
        'min_retest_correlation': minRetestCorrelation,
        'min_criterion_correlation': minCriterionCorrelation,
        'min_fairness_group_size': minFairnessGroupSize,
        'max_normalized_group_gap': maxNormalizedGroupGap,
        'min_alarm_sensitivity': minAlarmSensitivity,
        'min_alarm_specificity': minAlarmSpecificity,
      };
}

class CheckupValidationDossier {
  final List<CheckupExpertReviewRecord> expertReviews;
  final List<CheckupCognitiveInterviewRecord> cognitiveInterviews;
  final List<CheckupPilotObservation> pilotObservations;

  const CheckupValidationDossier({
    this.expertReviews = const <CheckupExpertReviewRecord>[],
    this.cognitiveInterviews =
        const <CheckupCognitiveInterviewRecord>[],
    this.pilotObservations = const <CheckupPilotObservation>[],
  });
}

class CheckupValidationDecision {
  final bool evidenceReviewPassed;
  final bool constructReviewPassed;
  final bool safetyReviewPassed;
  final bool cognitiveInterviewPassed;
  final bool pilotPassed;
  final int cognitiveSampleSize;
  final int pilotSampleSize;
  final CheckupCandidateQuality reviewedQuality;
  final Map<String, double> metrics;
  final List<String> blockingIssues;
  final List<String> warnings;
  final String protocolVersion;

  const CheckupValidationDecision({
    required this.evidenceReviewPassed,
    required this.constructReviewPassed,
    required this.safetyReviewPassed,
    required this.cognitiveInterviewPassed,
    required this.pilotPassed,
    required this.cognitiveSampleSize,
    required this.pilotSampleSize,
    required this.reviewedQuality,
    required this.metrics,
    required this.blockingIssues,
    required this.warnings,
    required this.protocolVersion,
  });

  bool get readyForHumanSignature =>
      blockingIssues.isEmpty &&
      evidenceReviewPassed &&
      constructReviewPassed &&
      safetyReviewPassed &&
      cognitiveInterviewPassed &&
      pilotPassed &&
      reviewedQuality.passesPublishedThresholds;

  String summary() {
    final parts = <String>[
      '协议$protocolVersion',
      '认知访谈$cognitiveSampleSize人',
      '试测$pilotSampleSize人',
      if (blockingIssues.isEmpty)
        '全部机器可核验门槛通过'
      else
        '仍有${blockingIssues.length}项阻断',
    ];
    return parts.join('；');
  }
}

class MentalHealthValidationEngine {
  final CheckupValidationProtocol protocol;

  const MentalHealthValidationEngine({
    this.protocol = CheckupValidationProtocol.v25,
  });

  CheckupValidationDecision evaluate({
    required CheckupContentCandidate candidate,
    required CheckupValidationDossier dossier,
  }) {
    final blocking = <String>[];
    final warnings = <String>[];
    final fingerprint = candidateFingerprint(candidate);
    final staleRecordCount = <Object>[
      ...dossier.expertReviews,
      ...dossier.cognitiveInterviews,
      ...dossier.pilotObservations,
    ].where((record) {
      if (record is CheckupExpertReviewRecord) {
        return record.candidateId == candidate.candidateId &&
            record.candidateFingerprint != fingerprint;
      }
      if (record is CheckupCognitiveInterviewRecord) {
        return record.candidateId == candidate.candidateId &&
            record.candidateFingerprint != fingerprint;
      }
      final observation = record as CheckupPilotObservation;
      return observation.candidateId == candidate.candidateId &&
          observation.candidateFingerprint != fingerprint;
    }).length;
    if (staleRecordCount > 0) {
      warnings.add('已忽略$staleRecordCount条与当前内容指纹不一致的旧验证记录');
    }
    final reviews = _latestExpertReviews(
      dossier.expertReviews
          .where(
            (record) =>
                record.candidateId == candidate.candidateId &&
                record.candidateFingerprint == fingerprint,
          ),
    );
    final courseReviews = reviews
        .where((record) =>
            record.role == CheckupExpertReviewRole.courseExpert &&
            record.passed)
        .toList(growable: false);
    final measurementReviews = reviews
        .where((record) =>
            record.role == CheckupExpertReviewRole.measurementReviewer &&
            record.passed)
        .toList(growable: false);
    final safetyReviews = reviews
        .where((record) =>
            record.role == CheckupExpertReviewRole.safetyReviewer &&
            record.passed)
        .toList(growable: false);
    final evidencePassed = courseReviews.isNotEmpty;
    final constructPassed = measurementReviews.isNotEmpty;
    final requiresDedicatedSafetyReview =
        candidate.indicatorType.contains('风险');
    final safetyPassed =
        !requiresDedicatedSafetyReview || safetyReviews.isNotEmpty;
    if (!evidencePassed) blocking.add('缺少通过的课程专家证据审核');
    if (!constructPassed) blocking.add('缺少通过的独立构念与测量审核');
    if (!safetyPassed) blocking.add('风险型内容缺少独立安全审核');
    final courseIds =
        courseReviews.map((record) => _identity(record.reviewerId)).toSet();
    final measurementIds = measurementReviews
        .map((record) => _identity(record.reviewerId))
        .toSet();
    final safetyIds =
        safetyReviews.map((record) => _identity(record.reviewerId)).toSet();
    final authorId = _identity(candidate.author);
    if (reviews.any(
      (record) =>
          record.passed &&
          _identity(record.reviewerId) == authorId,
    )) {
      blocking.add('作者不能审核自己创建的内容');
    }
    if (reviews.any(
      (record) =>
          record.passed &&
          _identity(record.reviewerId).contains('ai'),
    )) {
      blocking.add('AI身份不能作为人工审核人');
    }
    if (courseIds.intersection(measurementIds).isNotEmpty) {
      blocking.add('课程审核人与测量审核人必须相互独立');
    }
    if (requiresDedicatedSafetyReview &&
        safetyIds.intersection(<String>{
          ...courseIds,
          ...measurementIds,
        }).isNotEmpty) {
      blocking.add('风险型内容的安全审核人必须独立于课程和测量审核人');
    }
    final reviewedQuality = _reviewedQuality(reviews, candidate.quality);
    blocking.addAll(reviewedQuality.gateFailures);

    final interviews = _latestCognitiveInterviews(
      dossier.cognitiveInterviews
          .where(
            (record) =>
                record.candidateId == candidate.candidateId &&
                record.candidateFingerprint == fingerprint,
          ),
    );
    final cognitiveN = interviews.length;
    final misunderstandingRate =
        _rate(interviews.where((record) => record.misunderstood).length, cognitiveN);
    final doubleBarrelRate = _rate(
      interviews.where((record) => record.doubleBarrelDetected).length,
      cognitiveN,
    );
    final leadingRate = _rate(
      interviews.where((record) => record.leadingLanguageDetected).length,
      cognitiveN,
    );
    final burdenRate = _rate(
      interviews.where((record) => !record.burdenAcceptable).length,
      cognitiveN,
    );
    final cognitivePassed =
        cognitiveN >= protocol.minCognitiveParticipants &&
        misunderstandingRate <= protocol.maxMisunderstandingRate &&
        doubleBarrelRate <= protocol.maxDoubleBarrelRate &&
        leadingRate <= protocol.maxLeadingLanguageRate &&
        burdenRate <= protocol.maxUnacceptableBurdenRate;
    if (cognitiveN < protocol.minCognitiveParticipants) {
      blocking.add(
        '认知访谈样本不足：$cognitiveN/'
        '${protocol.minCognitiveParticipants}',
      );
    }
    if (misunderstandingRate > protocol.maxMisunderstandingRate) {
      blocking.add('认知访谈误解率超过暂行门槛');
    }
    if (doubleBarrelRate > protocol.maxDoubleBarrelRate) {
      blocking.add('双重问题检出率超过暂行门槛');
    }
    if (leadingRate > protocol.maxLeadingLanguageRate) {
      blocking.add('诱导措辞检出率超过暂行门槛');
    }
    if (burdenRate > protocol.maxUnacceptableBurdenRate) {
      blocking.add('不可接受负担率超过暂行门槛');
    }

    final observations = _latestPilotObservations(
      dossier.pilotObservations
          .where(
            (record) =>
                record.candidateId == candidate.candidateId &&
                record.candidateFingerprint == fingerprint,
          ),
    );
    final pilotN = observations.length;
    final complete = observations
        .where((record) => !record.missing)
        .toList(growable: false);
    final missingRate =
        _rate(observations.where((record) => record.missing).length, pilotN);
    final completionMedian = _median(
      complete
          .map((record) => record.completionTimeMs.toDouble())
          .where((value) => value > 0)
          .toList(growable: false),
    );
    final timedObservationCount = complete
        .where((record) => record.completionTimeMs > 0)
        .length;
    final scored = complete
        .where((record) => record.itemScore != null)
        .toList(growable: false);
    final scoreBounds = _scoreBounds(candidate);
    final floorRate = scored.isEmpty
        ? 0.0
        : _rate(
            scored
                .where((record) => record.itemScore == scoreBounds.$1)
                .length,
            scored.length,
          );
    final ceilingRate = scored.isEmpty
        ? 0.0
        : _rate(
            scored
                .where((record) => record.itemScore == scoreBounds.$2)
                .length,
            scored.length,
          );
    final itemRestPairs = complete
        .where(
          (record) => record.itemScore != null && record.restScore != null,
        )
        .map((record) => (record.itemScore!, record.restScore!))
        .toList(growable: false);
    final retestPairs = complete
        .where(
          (record) => record.itemScore != null && record.retestScore != null,
        )
        .map((record) => (record.itemScore!, record.retestScore!))
        .toList(growable: false);
    final criterionPairs = complete
        .where(
          (record) =>
              record.itemScore != null && record.behaviorCriterion != null,
        )
        .map((record) => (record.itemScore!, record.behaviorCriterion!))
        .toList(growable: false);
    final itemRest = _correlation(itemRestPairs);
    final retest = _correlation(retestPairs);
    final criterion = _correlation(criterionPairs);
    final fairnessGap = _normalizedGroupGap(
      observations: complete,
      minScore: scoreBounds.$1,
      maxScore: scoreBounds.$2,
    );
    final alarm = _alarmMetrics(complete);
    var pilotPassed =
        pilotN >= protocol.minPilotParticipants &&
        missingRate <= protocol.maxMissingRate &&
        timedObservationCount == complete.length &&
        (completionMedian == 0 ||
            completionMedian <= protocol.maxMedianCompletionTimeMs) &&
        max(floorRate, ceilingRate) <= protocol.maxFloorOrCeilingRate;
    if (candidate.kind == CheckupContentKind.assessmentItem) {
      if (itemRestPairs.length < protocol.minCorrelationPairs) {
        pilotPassed = false;
        blocking.add('题目区分度配对样本不足');
      } else if ((itemRest ?? -1) < protocol.minItemRestCorrelation) {
        pilotPassed = false;
        blocking.add('题目区分度低于暂行门槛');
      }
      if (retestPairs.length < protocol.minCorrelationPairs) {
        pilotPassed = false;
        blocking.add('重测配对样本不足');
      } else if ((retest ?? -1) < protocol.minRetestCorrelation) {
        pilotPassed = false;
        blocking.add('重测稳定性低于暂行门槛');
      }
    } else {
      if (criterionPairs.length < protocol.minCorrelationPairs) {
        pilotPassed = false;
        blocking.add('行为效标配对样本不足');
      } else if ((criterion ?? -1) < protocol.minCriterionCorrelation) {
        pilotPassed = false;
        blocking.add('行为效标关联低于暂行门槛');
      }
    }
    if (pilotN < protocol.minPilotParticipants) {
      blocking.add(
        '试测样本不足：$pilotN/${protocol.minPilotParticipants}',
      );
    }
    if (missingRate > protocol.maxMissingRate) {
      pilotPassed = false;
      blocking.add('试测缺失率超过暂行门槛');
    }
    if (completionMedian > protocol.maxMedianCompletionTimeMs) {
      pilotPassed = false;
      blocking.add('完成时间中位数超过暂行门槛');
    }
    if (timedObservationCount != complete.length) {
      pilotPassed = false;
      blocking.add('已完成样本的完成时间记录不完整');
    }
    if (max(floorRate, ceilingRate) >
        protocol.maxFloorOrCeilingRate) {
      pilotPassed = false;
      blocking.add('地板或天花板效应超过暂行门槛');
    }
    if (fairnessGap == null) {
      pilotPassed = false;
      blocking.add('缺少达到组内样本要求的公平性比较');
    } else if (fairnessGap > protocol.maxNormalizedGroupGap) {
      pilotPassed = false;
      blocking.add('群体标准化差异超过暂行门槛');
    }
    if (alarm.$3 > 0) {
      if (alarm.$1 < protocol.minAlarmSensitivity ||
          alarm.$2 < protocol.minAlarmSpecificity) {
        pilotPassed = false;
        blocking.add('报警敏感度或特异度低于暂行门槛');
      }
    } else if (requiresDedicatedSafetyReview) {
      pilotPassed = false;
      blocking.add('风险型内容缺少报警校准样本');
    }

    return CheckupValidationDecision(
      evidenceReviewPassed: evidencePassed,
      constructReviewPassed: constructPassed,
      safetyReviewPassed: safetyPassed,
      cognitiveInterviewPassed: cognitivePassed,
      pilotPassed: pilotPassed,
      cognitiveSampleSize: cognitiveN,
      pilotSampleSize: pilotN,
      reviewedQuality: reviewedQuality,
      metrics: <String, double>{
        'cognitive_misunderstanding_rate': misunderstandingRate,
        'cognitive_double_barrel_rate': doubleBarrelRate,
        'cognitive_leading_rate': leadingRate,
        'cognitive_burden_rate': burdenRate,
        'pilot_missing_rate': missingRate,
        'pilot_median_completion_ms': completionMedian,
        'pilot_floor_rate': floorRate,
        'pilot_ceiling_rate': ceilingRate,
        if (itemRest != null) 'item_rest_correlation': itemRest,
        if (retest != null) 'retest_correlation': retest,
        if (criterion != null) 'criterion_correlation': criterion,
        if (fairnessGap != null) 'normalized_group_gap': fairnessGap,
        if (alarm.$3 > 0) 'alarm_sensitivity': alarm.$1,
        if (alarm.$3 > 0) 'alarm_specificity': alarm.$2,
      },
      blockingIssues: blocking.toSet().toList(growable: false),
      warnings: warnings,
      protocolVersion: protocol.version,
    );
  }

  CheckupContentCandidate applyDecision({
    required CheckupContentCandidate candidate,
    required CheckupValidationDecision decision,
    DateTime? now,
  }) =>
      candidate.copyWith(
        evidenceReviewPassed: decision.evidenceReviewPassed,
        constructReviewPassed: decision.constructReviewPassed,
        cognitiveInterviewPassed: decision.cognitiveInterviewPassed,
        pilotPassed: decision.pilotPassed,
        pilotSampleSize: decision.pilotSampleSize,
        pilotNotes: decision.summary(),
        quality: decision.reviewedQuality,
        updatedAtMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
      );

  static String participantKey({
    required String studySalt,
    required String localAlias,
  }) {
    final normalizedSalt = studySalt.trim();
    final normalizedAlias = localAlias.trim();
    if (normalizedSalt.length < 8 || normalizedAlias.isEmpty) {
      throw ArgumentError('研究盐至少8个字符，参与者本地代号不能为空');
    }
    return sha256
        .convert(utf8.encode('$normalizedSalt\u001f$normalizedAlias'))
        .toString();
  }

  static String candidateFingerprint(CheckupContentCandidate candidate) {
    final canonical = <String, Object?>{
      'candidate_id': candidate.candidateId,
      'parent_candidate_id': candidate.parentCandidateId,
      'kind': candidate.kind.name,
      'primary_indicator_id': candidate.primaryIndicatorId,
      'indicator_name': candidate.indicatorName,
      'indicator_type': candidate.indicatorType,
      'content_code': candidate.contentCode,
      'content': candidate.content,
      'scale_or_duration': candidate.scaleOrDuration,
      'scoring_direction': candidate.scoringDirection,
      'recall_window': candidate.recallWindow,
      'answer_options': candidate.answerOptions,
      'correct_answer_index': candidate.correctAnswerIndex,
      'course_evidence_ids': candidate.courseEvidenceIds,
      'source_level': candidate.sourceLevel,
      'construct_rationale': candidate.constructRationale,
      'guardrail_indicator_ids': candidate.guardrailIndicatorIds,
      'safety_rule': candidate.safetyRule,
      'smaller_version': candidate.smallerVersion,
      'counter_evidence_prompt': candidate.counterEvidencePrompt,
      'author': candidate.author,
      'model_version': candidate.modelVersion,
      'prompt_version': candidate.promptVersion,
      'indicator_version': candidate.indicatorVersion,
      'course_version': candidate.courseVersion,
      'version': candidate.version,
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static List<CheckupExpertReviewRecord> _latestExpertReviews(
    Iterable<CheckupExpertReviewRecord> records,
  ) {
    final latest = <String, CheckupExpertReviewRecord>{};
    for (final record in records) {
      final key = '${_identity(record.reviewerId)}|${record.role.name}';
      final previous = latest[key];
      if (previous == null || record.createdAtMs > previous.createdAtMs) {
        latest[key] = record;
      }
    }
    return latest.values.toList(growable: false);
  }

  static List<CheckupCognitiveInterviewRecord> _latestCognitiveInterviews(
    Iterable<CheckupCognitiveInterviewRecord> records,
  ) {
    final latest = <String, CheckupCognitiveInterviewRecord>{};
    for (final record in records) {
      if (record.participantKey.trim().isEmpty) continue;
      final previous = latest[record.participantKey];
      if (previous == null || record.createdAtMs > previous.createdAtMs) {
        latest[record.participantKey] = record;
      }
    }
    return latest.values.toList(growable: false);
  }

  static List<CheckupPilotObservation> _latestPilotObservations(
    Iterable<CheckupPilotObservation> records,
  ) {
    final latest = <String, CheckupPilotObservation>{};
    for (final record in records) {
      if (record.participantKey.trim().isEmpty) continue;
      final previous = latest[record.participantKey];
      if (previous == null || record.createdAtMs > previous.createdAtMs) {
        latest[record.participantKey] = record;
      }
    }
    return latest.values.toList(growable: false);
  }

  static CheckupCandidateQuality _reviewedQuality(
    List<CheckupExpertReviewRecord> reviews,
    CheckupCandidateQuality fallback,
  ) {
    final passed = reviews.where((record) => record.passed).toList();
    if (passed.isEmpty) return fallback;
    double average(double Function(CheckupCandidateQuality) read) =>
        passed.map((record) => read(record.quality)).reduce((a, b) => a + b) /
        passed.length;
    return CheckupCandidateQuality(
      indicatorConsistency:
          average((quality) => quality.indicatorConsistency),
      courseFidelity: average((quality) => quality.courseFidelity),
      nonDuplication: average((quality) => quality.nonDuplication),
      measurability: average((quality) => quality.measurability),
      scaleWindowFit: average((quality) => quality.scaleWindowFit),
      bidirectionalLogic:
          average((quality) => quality.bidirectionalLogic),
      safety: average((quality) => quality.safety),
    );
  }

  static double _rate(int numerator, int denominator) =>
      denominator <= 0 ? 0 : numerator / denominator;

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.of(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static double? _correlation(List<(double, double)> pairs) {
    if (pairs.length < 2) return null;
    final meanX = pairs.map((pair) => pair.$1).reduce((a, b) => a + b) /
        pairs.length;
    final meanY = pairs.map((pair) => pair.$2).reduce((a, b) => a + b) /
        pairs.length;
    var numerator = 0.0;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final pair in pairs) {
      final dx = pair.$1 - meanX;
      final dy = pair.$2 - meanY;
      numerator += dx * dy;
      sumX += dx * dx;
      sumY += dy * dy;
    }
    final denominator = sqrt(sumX * sumY);
    if (denominator == 0) return null;
    return numerator / denominator;
  }

  static (double, double) _scoreBounds(
    CheckupContentCandidate candidate,
  ) {
    if (candidate.scaleOrDuration.contains('1—5') ||
        candidate.scaleOrDuration.contains('1-5')) {
      return (1, 5);
    }
    return (0, 4);
  }

  double? _normalizedGroupGap({
    required List<CheckupPilotObservation> observations,
    required double minScore,
    required double maxScore,
  }) {
    final groups = <String, List<double>>{};
    for (final observation in observations) {
      final group = observation.fairnessGroup.trim();
      final score = observation.itemScore;
      if (group.isEmpty || score == null) continue;
      groups.putIfAbsent(group, () => <double>[]).add(score);
    }
    final eligible = groups.values
        .where((values) => values.length >= protocol.minFairnessGroupSize)
        .toList(growable: false);
    if (eligible.length < 2 || maxScore <= minScore) return null;
    final means = eligible
        .map((values) => values.reduce((a, b) => a + b) / values.length)
        .toList(growable: false);
    final highest = means.reduce((left, right) => left > right ? left : right);
    final lowest = means.reduce((left, right) => left < right ? left : right);
    return (highest - lowest) / (maxScore - minScore);
  }

  static (double, double, int) _alarmMetrics(
    List<CheckupPilotObservation> observations,
  ) {
    var truePositive = 0;
    var falseNegative = 0;
    var trueNegative = 0;
    var falsePositive = 0;
    for (final observation in observations) {
      final expected = observation.expectedAlarm;
      final actual = observation.actualAlarm;
      if (expected == null || actual == null) continue;
      if (expected && actual) truePositive++;
      if (expected && !actual) falseNegative++;
      if (!expected && !actual) trueNegative++;
      if (!expected && actual) falsePositive++;
    }
    final positive = truePositive + falseNegative;
    final negative = trueNegative + falsePositive;
    final sensitivity = positive == 0 ? 0.0 : truePositive / positive;
    final specificity = negative == 0 ? 0.0 : trueNegative / negative;
    return (
      sensitivity,
      specificity,
      positive + negative,
    );
  }

  static String _identity(String value) => value.trim().toLowerCase();
}

class CheckupValidationEnvelope {
  static const String type = 'mental_health_validation_v1';

  static String create({
    required String courseVersion,
    required String blueprintVersion,
    required List<CheckupContentCandidate> candidates,
    required List<CheckupExpertReviewRecord> expertReviews,
    required List<CheckupCognitiveInterviewRecord> cognitiveInterviews,
    required List<CheckupPilotObservation> pilotObservations,
    required List<CheckupSeedReviewRecord> seedReviews,
    Map<String, Object?> seedTargets = const <String, Object?>{},
    DateTime? now,
  }) {
    final payload = <String, Object?>{
      'course_version': courseVersion,
      'blueprint_version': blueprintVersion,
      'protocol': CheckupValidationProtocol.v25.toJson(),
      'exported_at_ms': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'candidates':
          candidates.map((candidate) => candidate.toJson()).toList(),
      'expert_reviews':
          expertReviews.map((record) => record.toJson()).toList(),
      'cognitive_interviews':
          cognitiveInterviews.map((record) => record.toJson()).toList(),
      'pilot_observations':
          pilotObservations.map((record) => record.toJson()).toList(),
      'seed_reviews': seedReviews.map((record) => record.toJson()).toList(),
      'seed_targets': seedTargets,
    };
    final payloadJson = jsonEncode(payload);
    return jsonEncode(<String, Object?>{
      'type': type,
      'payload_json': payloadJson,
      'sha256': sha256.convert(utf8.encode(payloadJson)).toString(),
    });
  }

  static Map<String, dynamic> validateAndDecode({
    required String raw,
    required String expectedCourseVersion,
    required String expectedBlueprintVersion,
  }) {
    final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (envelope['type'] != type) {
      throw const FormatException('验证包类型不匹配');
    }
    final payloadJson = (envelope['payload_json'] ?? '').toString();
    final expectedHash = (envelope['sha256'] ?? '').toString().toLowerCase();
    final actualHash = sha256.convert(utf8.encode(payloadJson)).toString();
    if (payloadJson.isEmpty || actualHash != expectedHash) {
      throw const FormatException('验证包内容校验失败');
    }
    final payload = Map<String, dynamic>.from(jsonDecode(payloadJson) as Map);
    if (payload['course_version'] != expectedCourseVersion) {
      throw FormatException(
        '课程版本不兼容：${payload['course_version']}',
      );
    }
    if (payload['blueprint_version'] != expectedBlueprintVersion) {
      throw FormatException(
        '内容蓝图版本不兼容：${payload['blueprint_version']}',
      );
    }
    return payload;
  }
}
