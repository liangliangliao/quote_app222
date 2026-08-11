import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_state_machine.dart';

class XiangjiKnowledgeRequest {
  const XiangjiKnowledgeRequest({
    required this.requestId,
    required this.query,
    this.problemId = '',
    this.campaignId = '',
    this.claimId = '',
    this.isMajorDecision = false,
    this.isHighRisk = false,
    this.isIrreversible = false,
    this.hasUserConfirmation = false,
    this.askingForOriginalSource = false,
    this.needsLargeRemoteFile = false,
    this.preferredProviderId = '',
    this.authorizedSensitiveContext = false,
    this.aiInferencePresentedAsFact = false,
    this.abstractComplexityUsedAsEvidence = false,
    this.proofHasUngroundedPremise = false,
    this.directPerceptionMissingConditions = false,
    this.semanticSimilarityUsedAsGrounding = false,
    this.realityResultMissing = false,
  });

  final String requestId;
  final String query;
  final String problemId;
  final String campaignId;
  final String claimId;
  final bool isMajorDecision;
  final bool isHighRisk;
  final bool isIrreversible;
  final bool hasUserConfirmation;
  final bool askingForOriginalSource;
  final bool needsLargeRemoteFile;
  final String preferredProviderId;
  final bool authorizedSensitiveContext;
  final bool aiInferencePresentedAsFact;
  final bool abstractComplexityUsedAsEvidence;
  final bool proofHasUngroundedPremise;
  final bool directPerceptionMissingConditions;
  final bool semanticSimilarityUsedAsGrounding;
  final bool realityResultMissing;
}

class XiangjiKnowledgeContext {
  const XiangjiKnowledgeContext({
    required this.preflight,
    required this.currentReality,
    required this.objectClaims,
    required this.personalHistory,
    required this.methodNodes,
    required this.passages,
    required this.providerFiles,
    required this.conflicts,
    required this.trace,
  });

  final XiangjiRulePreflightResult preflight;
  final List<Map<String, Object?>> currentReality;
  final List<Map<String, Object?>> objectClaims;
  final List<Map<String, Object?>> personalHistory;
  final List<Map<String, Object?>> methodNodes;
  final List<Map<String, Object?>> passages;
  final List<XiangjiProviderFileRecord> providerFiles;
  final List<Map<String, Object?>> conflicts;
  final XiangjiRetrievalTrace trace;

  Map<String, Object?> toPromptMap() => <String, Object?>{
        'k0_rule_preflight': preflight.hits
            .map((hit) => <String, Object?>{
                  'rule_id': hit.ruleId,
                  'message': hit.message,
                  'required_action': hit.action,
                  'blocking': hit.blocking,
                })
            .toList(),
        'current_reality': currentReality,
        'current_object_claims': objectClaims,
        'k4_personal_history': personalHistory,
        'k1_k2_k3_method_nodes': methodNodes,
        'original_passages': passages,
        'provider_files': providerFiles
            .map((item) => <String, Object?>{
                  'provider': item.providerId,
                  'source_id': item.sourceId,
                  'remote_file_id': item.remoteFileId,
                  'remote_store_id': item.remoteStoreId,
                  'status': item.state.wire,
                })
            .toList(),
        'unresolved_conflicts': conflicts,
        'retrieval_trace_id': trace.id,
        'warning': '检索结果是候选上下文，不自动成为事实或认识根据。',
      };
}

/// A12 Knowledge Router. Its job is context selection and traceability, not a
/// final life recommendation.
class XiangjiKnowledgeRouter {
  XiangjiKnowledgeRouter({
    XiangjiDao? dao,
    XiangjiK0RuleEngine? ruleEngine,
  })  : _dao = dao ?? XiangjiDao(),
        _ruleEngine = ruleEngine ?? const XiangjiK0RuleEngine();

  final XiangjiDao _dao;
  final XiangjiK0RuleEngine _ruleEngine;

  Future<XiangjiKnowledgeContext> route(XiangjiKnowledgeRequest request) async {
    final openDebts = await _dao.debts(problemId: request.problemId);
    final hasHighDebt = openDebts.any((row) =>
        <String>{'high', 'critical'}
            .contains((row['decision_impact'] ?? '').toString()));
    final preflight = _ruleEngine.preflight(XiangjiRuleRequest(
      requestId: request.requestId,
      rawText: request.query,
      isMajorDecision: request.isMajorDecision,
      isHighRisk: request.isHighRisk,
      isIrreversible: request.isIrreversible,
      hasHighEpistemicDebt: hasHighDebt,
      hasUserConfirmation: request.hasUserConfirmation,
      aiInferencePresentedAsFact: request.aiInferencePresentedAsFact,
      abstractComplexityUsedAsEvidence:
          request.abstractComplexityUsedAsEvidence,
      proofHasUngroundedPremise: request.proofHasUngroundedPremise,
      directPerceptionMissingConditions:
          request.directPerceptionMissingConditions,
      semanticSimilarityUsedAsGrounding:
          request.semanticSimilarityUsedAsGrounding,
      realityResultMissing: request.realityResultMissing,
    ));

    final reality = <Map<String, Object?>>[];
    final claims = <Map<String, Object?>>[];
    if (request.problemId.isNotEmpty) {
      final experiences = await _dao.experiencesForProblem(request.problemId);
      final evidence = await _dao.evidenceForProblem(request.problemId);
      for (final row in experiences) {
        if ((row['is_user_wording'] ?? 0) == 1 ||
            request.authorizedSensitiveContext ||
            (row['experience_type'] ?? '').toString() != 'raw_context') {
          reality.add(<String, Object?>{
            'kind': 'experience',
            'id': row['id'],
            'type': row['experience_type'],
            'content': row['content'],
            'is_user_wording': row['is_user_wording'],
            'observation_conditions': row['observation_conditions_json'],
          });
        }
      }
      for (final row in evidence) {
        reality.add(<String, Object?>{
          'kind': 'evidence',
          'id': row['id'],
          'type': row['evidence_type'],
          'content': row['content'],
          'source_ref': row['source_ref'],
        });
      }
      claims.addAll(await _dao.claimsForProblem(request.problemId));
    }

    final personalHistory = <Map<String, Object?>>[
      ...await _dao.personalRules(limit: 12),
      ...await _dao.candidateKnowledge(),
    ];
    final methodNodes = await _dao.knowledgeNodes(
      layers: const <XiangjiKnowledgeLayer>[
        XiangjiKnowledgeLayer.k1,
        XiangjiKnowledgeLayer.k2,
        XiangjiKnowledgeLayer.k3,
      ],
      limit: 40,
    );
    final passages = request.askingForOriginalSource
        ? await _dao.searchPassages(request.query, limit: 12)
        : const <Map<String, Object?>>[];
    final allProviderFiles = await _dao.providerFiles();
    final providerFiles = <XiangjiProviderFileRecord>[];
    final rejected = <String>[];
    if (request.needsLargeRemoteFile) {
      for (final item in allProviderFiles) {
        if (!item.usable) {
          rejected.add(
            '${item.providerId}:${item.sourceId}:${item.isExpired ? 'expired' : item.state.wire}',
          );
          continue;
        }
        if (request.preferredProviderId.isNotEmpty &&
            item.providerId != request.preferredProviderId) {
          rejected.add('${item.providerId}:${item.sourceId}:not_preferred');
          continue;
        }
        providerFiles.add(item);
      }
    }
    final conflicts = (await _dao.knowledgeConflicts())
        .where((row) =>
            (row['resolution_status'] ?? '').toString() == 'unresolved')
        .toList();

    final routePlan = <String>[
      '1.current_reality',
      '2.k0_rule_preflight',
      if (request.problemId.isNotEmpty || request.campaignId.isNotEmpty)
        '3.current_problem_campaign_graph',
      '4.k4_personal_history',
      '5.k1_k2_method_knowledge',
      if (methodNodes.isNotEmpty) '6.k3_thinker_knowledge_if_relevant',
      if (request.askingForOriginalSource) '7.original_source_retriever',
      if (request.needsLargeRemoteFile) '8.provider_knowledge_client',
    ];
    final sourcesUsed = <String>[
      ...reality.map((row) => (row['id'] ?? '').toString()),
      ...claims.map((row) => (row['id'] ?? '').toString()),
      ...personalHistory.map((row) => (row['id'] ?? '').toString()),
      ...methodNodes.map((row) => (row['id'] ?? '').toString()),
      ...passages.map((row) => (row['id'] ?? '').toString()),
      ...providerFiles.map((item) => item.id),
    ].where((id) => id.isNotEmpty).toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    final trace = XiangjiRetrievalTrace(
      id: '${request.requestId}-trace-$now',
      requestId: request.requestId,
      objectRefs: <String>[
        if (request.problemId.isNotEmpty) 'problem:${request.problemId}',
        if (request.campaignId.isNotEmpty) 'campaign:${request.campaignId}',
        if (request.claimId.isNotEmpty) 'claim:${request.claimId}',
      ],
      routePlan: routePlan,
      sourcesUsed: sourcesUsed,
      rejectedSources: rejected,
      conflicts: conflicts
          .map((row) => '${row['left_ref']} <> ${row['right_ref']}')
          .toList(),
      ruleIds: preflight.ruleIds,
      debtIds:
          openDebts.map((row) => (row['id'] ?? '').toString()).toList(),
      state: XiangjiRetrievalSessionState.assembled,
      createdAtMs: now,
    );
    await _dao.saveRetrievalTrace(trace);
    return XiangjiKnowledgeContext(
      preflight: preflight,
      currentReality: reality,
      objectClaims: claims,
      personalHistory: personalHistory,
      methodNodes: methodNodes,
      passages: passages,
      providerFiles: providerFiles,
      conflicts: conflicts,
      trace: trace,
    );
  }
}

class XiangjiSourceRetriever {
  XiangjiSourceRetriever({XiangjiDao? dao}) : _dao = dao ?? XiangjiDao();

  final XiangjiDao _dao;

  Future<List<Map<String, Object?>>> byQuery(String query) =>
      _dao.searchPassages(query);

  Future<List<Map<String, Object?>>> bySource(String sourceId) =>
      _dao.sourcePassages(sourceId);
}

