import 'mental_health_checkup_ai_service.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_content_governance.dart';
import 'mental_health_generation_batch.dart';
import 'mental_health_knowledge_base_service.dart';

class MentalHealthGenerationBatchService {
  final MentalHealthCheckupRepository repository;
  final MentalHealthCheckupAiService ai;
  final MentalHealthKnowledgeBaseService knowledgeBase;

  MentalHealthGenerationBatchService({
    required this.repository,
    MentalHealthCheckupAiService? aiService,
    MentalHealthKnowledgeBaseService? knowledgeBaseService,
  })  : ai = aiService ?? MentalHealthCheckupAiService(),
        knowledgeBase = knowledgeBaseService ??
            MentalHealthKnowledgeBaseService(repository: repository);

  Future<CheckupBatchRunResult> runNextChunk({
    required CheckupGenerationBatch batch,
    required MentalHealthCheckupCatalog catalog,
    int maxJobs = 5,
  }) async {
    if (batch.status == CheckupGenerationBatchStatus.cancelled ||
        batch.status == CheckupGenerationBatchStatus.completed) {
      return CheckupBatchRunResult(
        batch: batch,
        processed: 0,
        generated: 0,
        localFallbacks: 0,
        failed: 0,
      );
    }
    await repository.setGenerationBatchStatus(
      batch.id,
      CheckupGenerationBatchStatus.running,
    );
    final jobs = await repository.loadGenerationJobs(
      batch.id,
      statuses: const <CheckupGenerationJobStatus>{
        CheckupGenerationJobStatus.queued,
      },
      limit: maxJobs.clamp(1, 25).toInt(),
    );
    const governance = MentalHealthContentGovernanceEngine();
    final planByIndicator = <String, CheckupContentGenerationPlan>{
      for (final plan in governance.buildGenerationQueue(catalog.indicators))
        plan.indicatorId: plan,
    };
    final providerResource = batch.useAi
        ? await knowledgeBase.activeResource(catalog: catalog)
        : null;
    var generated = 0;
    var fallbacks = 0;
    var failures = 0;
    for (final job in jobs) {
      final started = job.copyWith(
        status: CheckupGenerationJobStatus.running,
        attempts: job.attempts + 1,
        error: '',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await repository.saveGenerationJob(started);
      final plan = planByIndicator[job.indicatorId];
      if (plan == null ||
          !<String>{
            ...plan.itemTypeCodes,
            ...plan.behaviorLevels,
          }.contains(job.contentCode)) {
        failures++;
        await repository.saveGenerationJob(
          started.copyWith(
            status: CheckupGenerationJobStatus.failed,
            error: '生成计划已变化或内容代码无效',
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        continue;
      }
      try {
        if (job.useAi) {
          final traces = await repository.evidenceTracesForIndicators(<String>[
            job.indicatorId,
          ], limit: 16);
          final result = await ai.generateContentCandidate(
            plan: plan,
            contentCode: job.contentCode,
            courseVersion: catalog.validation.version,
            evidenceTraces: traces,
            knowledgeResource: providerResource,
          );
          await repository.saveContentCandidate(result.candidate);
          if (result.usedAi) {
            generated++;
          } else {
            fallbacks++;
          }
          await repository.saveGenerationJob(
            started.copyWith(
              status: result.usedAi
                  ? CheckupGenerationJobStatus.generated
                  : CheckupGenerationJobStatus.localFallback,
              candidateId: result.candidate.candidateId,
              error: result.usedAi ? '' : result.message,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        } else {
          final candidate = governance.createLocalDraft(
            plan: plan,
            contentCode: job.contentCode,
            courseVersion: catalog.validation.version,
          );
          await repository.saveContentCandidate(candidate);
          fallbacks++;
          await repository.saveGenerationJob(
            started.copyWith(
              status: CheckupGenerationJobStatus.localFallback,
              candidateId: candidate.candidateId,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      } catch (error) {
        failures++;
        await repository.saveGenerationJob(
          started.copyWith(
            status: CheckupGenerationJobStatus.failed,
            error: error.toString(),
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }
    final remaining = await repository.loadGenerationJobs(
      batch.id,
      statuses: const <CheckupGenerationJobStatus>{
        CheckupGenerationJobStatus.queued,
        CheckupGenerationJobStatus.running,
      },
      limit: 1,
    );
    final summary = await repository.refreshGenerationBatch(batch.id);
    final updated = await repository.refreshGenerationBatch(
      batch.id,
      forceStatus: remaining.isEmpty && (summary?.failedJobs ?? failures) == 0
          ? CheckupGenerationBatchStatus.completed
          : CheckupGenerationBatchStatus.paused,
    );
    return CheckupBatchRunResult(
      batch: updated ?? batch,
      processed: jobs.length,
      generated: generated,
      localFallbacks: fallbacks,
      failed: failures,
    );
  }
}
