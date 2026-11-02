import 'cognitive_models.dart';
import 'cognitive_store.dart';

class CognitiveRecordProposal {
  final CognitiveNote previous, candidate;
  final bool requiresRevision;
  const CognitiveRecordProposal(
      this.previous, this.candidate, this.requiresRevision);
}

/// Bridges one existing business record to its lightweight revision history.
/// It neither invokes a solver nor reads any other business record's originals.
class CognitiveRecordAdapter {
  final CognitiveStore store;
  CognitiveRecordAdapter({CognitiveStore? store})
      : store = store ?? CognitiveStore();

  Future<CognitiveRecordProposal> capture(CognitiveNote candidate) async {
    final notes = await store.forRecord(
        candidate.selection.module, candidate.selection.recordId);
    final previous = notes
        .where((n) =>
            n.task == CognitiveTask.reflection &&
            n.modelInfo == 'existing_record_snapshot')
        .firstOrNull;
    if (previous == null) {
      await store.save(candidate);
      return CognitiveRecordProposal(candidate, candidate, false);
    }
    final same = previous.currentSnapshot == candidate.id &&
        previous.currentJudgment == candidate.analysis.summary;
    return CognitiveRecordProposal(previous, candidate, !same);
  }

  Future<CognitiveNote> revise(CognitiveRecordProposal proposal,
      {required String judgment,
      required String evidence,
      String reason = ''}) async {
    final old = proposal.previous;
    return store.updateIfUnchanged(
        old,
        (current) => current.revise(
            judgment: judgment,
            evidence: evidence,
            reason: reason,
            sourceSnapshot: proposal.candidate.id));
  }
}
