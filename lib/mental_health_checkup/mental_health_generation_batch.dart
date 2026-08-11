import 'mental_health_content_governance.dart';

enum CheckupGenerationBatchStatus {
  queued,
  running,
  paused,
  completed,
  cancelled,
}

enum CheckupGenerationJobStatus {
  queued,
  running,
  generated,
  localFallback,
  failed,
  cancelled,
}

class CheckupGenerationBatch {
  final String id;
  final String name;
  final bool useAi;
  final CheckupGenerationBatchStatus status;
  final int totalJobs;
  final int completedJobs;
  final int failedJobs;
  final int createdAtMs;
  final int updatedAtMs;

  const CheckupGenerationBatch({
    required this.id,
    required this.name,
    required this.useAi,
    required this.status,
    required this.totalJobs,
    required this.completedJobs,
    required this.failedJobs,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  double get progress => totalJobs == 0 ? 0 : completedJobs / totalJobs;

  CheckupGenerationBatch copyWith({
    String? name,
    bool? useAi,
    CheckupGenerationBatchStatus? status,
    int? totalJobs,
    int? completedJobs,
    int? failedJobs,
    int? updatedAtMs,
  }) =>
      CheckupGenerationBatch(
        id: id,
        name: name ?? this.name,
        useAi: useAi ?? this.useAi,
        status: status ?? this.status,
        totalJobs: totalJobs ?? this.totalJobs,
        completedJobs: completedJobs ?? this.completedJobs,
        failedJobs: failedJobs ?? this.failedJobs,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'use_ai': useAi,
        'status': status.name,
        'total_jobs': totalJobs,
        'completed_jobs': completedJobs,
        'failed_jobs': failedJobs,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory CheckupGenerationBatch.fromJson(Map<String, dynamic> json) =>
      CheckupGenerationBatch(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        useAi: json['use_ai'] == true,
        status: CheckupGenerationBatchStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => CheckupGenerationBatchStatus.queued,
        ),
        totalJobs: (json['total_jobs'] as num?)?.toInt() ?? 0,
        completedJobs: (json['completed_jobs'] as num?)?.toInt() ?? 0,
        failedJobs: (json['failed_jobs'] as num?)?.toInt() ?? 0,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

class CheckupGenerationJob {
  final String id;
  final String batchId;
  final String indicatorId;
  final String contentCode;
  final bool useAi;
  final CheckupGenerationJobStatus status;
  final int attempts;
  final String candidateId;
  final String error;
  final int createdAtMs;
  final int updatedAtMs;

  const CheckupGenerationJob({
    required this.id,
    required this.batchId,
    required this.indicatorId,
    required this.contentCode,
    required this.useAi,
    required this.status,
    required this.attempts,
    required this.candidateId,
    required this.error,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get terminal =>
      status == CheckupGenerationJobStatus.generated ||
      status == CheckupGenerationJobStatus.localFallback ||
      status == CheckupGenerationJobStatus.cancelled;

  CheckupGenerationJob copyWith({
    CheckupGenerationJobStatus? status,
    int? attempts,
    String? candidateId,
    String? error,
    int? updatedAtMs,
  }) =>
      CheckupGenerationJob(
        id: id,
        batchId: batchId,
        indicatorId: indicatorId,
        contentCode: contentCode,
        useAi: useAi,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        candidateId: candidateId ?? this.candidateId,
        error: error ?? this.error,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'batch_id': batchId,
        'indicator_id': indicatorId,
        'content_code': contentCode,
        'use_ai': useAi,
        'status': status.name,
        'attempts': attempts,
        'candidate_id': candidateId,
        'error': error,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory CheckupGenerationJob.fromJson(Map<String, dynamic> json) =>
      CheckupGenerationJob(
        id: (json['id'] ?? '').toString(),
        batchId: (json['batch_id'] ?? '').toString(),
        indicatorId: (json['indicator_id'] ?? '').toString(),
        contentCode: (json['content_code'] ?? '').toString(),
        useAi: json['use_ai'] == true,
        status: CheckupGenerationJobStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => CheckupGenerationJobStatus.queued,
        ),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        candidateId: (json['candidate_id'] ?? '').toString(),
        error: (json['error'] ?? '').toString(),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );

  static List<CheckupGenerationJob> expandPlans({
    required String batchId,
    required Iterable<CheckupContentGenerationPlan> plans,
    required bool useAi,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final created = clock.millisecondsSinceEpoch;
    final jobs = <CheckupGenerationJob>[];
    for (final plan in plans) {
      final codes = <String>{...plan.itemTypeCodes, ...plan.behaviorLevels};
      for (final code in codes) {
        jobs.add(
          CheckupGenerationJob(
            id: '$batchId|${plan.indicatorId}|$code',
            batchId: batchId,
            indicatorId: plan.indicatorId,
            contentCode: code,
            useAi: useAi,
            status: CheckupGenerationJobStatus.queued,
            attempts: 0,
            candidateId: '',
            error: '',
            createdAtMs: created,
            updatedAtMs: created,
          ),
        );
      }
    }
    return jobs;
  }
}

class CheckupBatchRunResult {
  final CheckupGenerationBatch batch;
  final int processed;
  final int generated;
  final int localFallbacks;
  final int failed;

  const CheckupBatchRunResult({
    required this.batch,
    required this.processed,
    required this.generated,
    required this.localFallbacks,
    required this.failed,
  });
}
