import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai_assistant/ai_assistant_file_text_extractor.dart';
import '../zhixing_tree/zhixing_extended_models.dart';
import '../zhixing_tree/zhixing_remote_knowledge_models.dart';
import '../zhixing_tree/zhixing_remote_knowledge_service.dart';
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

class XiangjiKnowledgeImportService {
  XiangjiKnowledgeImportService({XiangjiDao? dao})
      : _dao = dao ?? XiangjiDao();

  static const int maxImportBytes = 50 * 1024 * 1024;
  static const int passageCharacters = 1800;

  final XiangjiDao _dao;
  final AiAssistantFileTextExtractor _extractor =
      AiAssistantFileTextExtractor();

  Future<XiangjiKnowledgeSourceRecord> importFile({
    required File file,
    required String title,
    required XiangjiKnowledgeLayer layer,
    String kind = 'book',
    String sensitivity = 'normal',
  }) async {
    if (!await file.exists()) throw ArgumentError('所选文件不存在。');
    final size = await file.length();
    if (size <= 0 || size > maxImportBytes) {
      throw ArgumentError('知识文件不能为空且需小于 50 MB。');
    }
    final digest = await sha256.bind(file.openRead()).first;
    final checksum = digest.toString();
    final existing = (await _dao.knowledgeSources())
        .where((source) => source.contentHash == checksum)
        .toList();
    if (existing.isNotEmpty) return existing.first;

    final now = DateTime.now().millisecondsSinceEpoch;
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'xiangji', 'knowledge'));
    await directory.create(recursive: true);
    final safeName = _safeFileName(p.basename(file.path));
    final destination = File(
      p.join(directory.path, '${checksum.substring(0, 12)}_$safeName'),
    );
    await file.copy(destination.path);
    final mime = _mimeForName(safeName);
    String extracted = '';
    String parseStatus = 'FAILED';
    String indexStatus = 'LOCAL_ONLY';
    String lastError = '';
    try {
      extracted = (await _extractor.extract(
            destination,
            safeName,
            mimeType: mime,
            sizeBytes: size,
          )) ??
          '';
      parseStatus = extracted.trim().isEmpty ? 'FAILED' : 'PARSED';
      indexStatus = extracted.trim().isEmpty ? 'LOCAL_ONLY' : 'INDEXED';
      if (extracted.trim().isEmpty) lastError = '未能提取文字；本地原文件仍已保存。';
    } catch (error) {
      lastError = _safeError(error);
    }
    final sourceId = 'xfs_${checksum.substring(0, 20)}';
    final record = XiangjiKnowledgeSourceRecord(
      id: sourceId,
      layer: layer,
      kind: kind,
      title: title.trim().isEmpty ? p.basenameWithoutExtension(safeName) : title.trim(),
      status: XiangjiKnowledgeSourceStatus.active,
      version: '1',
      contentHash: checksum,
      localUri: destination.path,
      mime: mime,
      parseStatus: parseStatus,
      indexStatus: indexStatus,
      sensitivity: sensitivity,
      createdAtMs: now,
      updatedAtMs: now,
    );
    final documentId = '$sourceId-document';
    await _dao.saveKnowledgeSource(
      source: record,
      documentId: documentId,
      byteSize: size,
      lastError: lastError,
    );
    if (extracted.trim().isNotEmpty) {
      final chunks = _chunk(extracted.trim(), passageCharacters);
      await _dao.savePassages(<Map<String, Object?>>[
        for (var index = 0; index < chunks.length; index++)
          <String, Object?>{
            'id': '$documentId-p${index + 1}',
            'document_id': documentId,
            'source_id': sourceId,
            'chapter': '',
            'section': '',
            'locator': '${record.title} · 文本段 ${index + 1}',
            'original_text': chunks[index],
            'translation': '',
            'page_range': '',
            'text_kind': 'parsed_source_text',
            'created_at_ms': now,
          },
      ]);
    }
    return record;
  }

  List<String> _chunk(String text, int maxCharacters) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    final chunks = <String>[];
    var buffer = StringBuffer();
    for (final paragraph in paragraphs) {
      if (buffer.length > 0 && buffer.length + paragraph.length > maxCharacters) {
        chunks.add(buffer.toString().trim());
        buffer = StringBuffer();
      }
      if (paragraph.length <= maxCharacters) {
        buffer.writeln(paragraph);
      } else {
        if (buffer.length > 0) {
          chunks.add(buffer.toString().trim());
          buffer = StringBuffer();
        }
        for (var start = 0; start < paragraph.length; start += maxCharacters) {
          final end =
              (start + maxCharacters).clamp(0, paragraph.length).toInt();
          chunks.add(paragraph.substring(start, end));
        }
      }
    }
    if (buffer.length > 0) chunks.add(buffer.toString().trim());
    return chunks;
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._\-\u4e00-\u9fff]'), '_');
    return sanitized.isEmpty ? 'knowledge_file' : sanitized;
  }

  String _mimeForName(String value) {
    final lower = value.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.epub')) return 'application/epub+zip';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.json')) return 'application/json';
    return 'text/plain';
  }

  String _safeError(Object error) {
    final text = error.toString().replaceAll(
          RegExp(
            r'(api[_ -]?key|authorization|bearer)\s*[:=]\s*[^\s,}]+',
            caseSensitive: false,
          ),
          r'$1=[已隐藏]',
        );
    return text.length <= 500 ? text : text.substring(0, 500);
  }
}

class XiangjiProviderService {
  XiangjiProviderService({
    XiangjiDao? dao,
    ZxRemoteKnowledgeService? providerService,
  })  : _dao = dao ?? XiangjiDao(),
        _providerService = providerService ?? ZxRemoteKnowledgeService();

  final XiangjiDao _dao;
  final ZxRemoteKnowledgeService _providerService;
  final XiangjiProviderFileStateMachine _stateMachine =
      const XiangjiProviderFileStateMachine();

  Future<XiangjiProviderFileRecord> syncSource({
    required String sourceId,
    required String providerId,
  }) async {
    final source = await _dao.knowledgeSource(sourceId);
    if (source == null) throw ArgumentError('本地知识源不存在。');
    final capability = await _dao.providerCapability(providerId);
    if (capability == null) throw ArgumentError('未知 AI 服务商。');
    if (!capability.mayClaimPersistentStorage) {
      throw StateError('${capability.label} 不支持或尚未验证持久文件复用；系统不会创建虚假的 READY 记录。');
    }
    final file = File(source.localUri);
    if (!await file.exists()) throw StateError('本地源文件已丢失，不能上传。');
    final previous = (await _dao.providerFiles(sourceId: sourceId))
        .where((item) => item.providerId == providerId)
        .toList();
    final existing = previous.isEmpty ? null : previous.first;
    final numericId = _stableNumericId(source.id);
    final book = ZxAiBook(
      id: numericId,
      thinker: '向己知识中心',
      title: source.title,
      fileName: p.basename(source.localUri),
      localPath: source.localUri,
      mimeType: source.mime,
      byteSize: await file.length(),
      sha256: source.contentHash,
      createdAtMs: source.createdAtMs,
    );
    final provider = ZxRemoteKnowledgeProviderX.parse(providerId);
    final previousRemote = existing == null
        ? null
        : ZxRemoteKnowledgeItem(
            bookId: numericId,
            provider: provider,
            remoteFileId: existing.remoteFileId,
            remoteStoreId: existing.remoteStoreId,
            retentionLabel: existing.retentionInfo,
            expiresAtMs: existing.expiresAtMs,
            status: _toRemoteState(existing.state),
          );
    final id = existing?.id ?? 'xfp_${source.id}_$providerId';
    final uploading = XiangjiProviderFileRecord(
      id: id,
      providerId: providerId,
      sourceId: source.id,
      state: XiangjiProviderFileState.uploading,
      remoteFileId: existing?.remoteFileId ?? '',
      remoteStoreId: existing?.remoteStoreId ?? '',
      retentionInfo: capability.retentionPolicy,
      uploadedAtMs: existing?.uploadedAtMs ?? 0,
      expiresAtMs: existing?.expiresAtMs ?? 0,
    );
    await _dao.saveProviderFile(uploading);
    try {
      final result = await _providerService.syncExternalBook(
        book,
        provider: provider,
        existing: previousRemote,
      );
      final nextState = result.status == ZxRemoteKnowledgeStatus.ready
          ? XiangjiProviderFileState.ready
          : result.status == ZxRemoteKnowledgeStatus.processing
              ? XiangjiProviderFileState.processing
              : XiangjiProviderFileState.failed;
      if (nextState == XiangjiProviderFileState.ready) {
        _stateMachine
            .evaluate(
              XiangjiProviderFileState.uploading,
              nextState,
              capability: capability,
              remoteFileId: result.remoteFileId.isEmpty
                  ? result.remoteDocumentId
                  : result.remoteFileId,
            )
            .requireAllowed();
      }
      final saved = XiangjiProviderFileRecord(
        id: id,
        providerId: providerId,
        sourceId: source.id,
        state: nextState,
        remoteFileId: result.remoteFileId.isEmpty
            ? result.remoteDocumentId
            : result.remoteFileId,
        remoteStoreId: result.remoteStoreId,
        retentionInfo: result.retentionLabel.isEmpty
            ? capability.retentionPolicy
            : result.retentionLabel,
        lastError: result.lastError,
        uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
        expiresAtMs: result.expiresAtMs,
      );
      await _dao.saveProviderFile(saved);
      return saved;
    } catch (error) {
      final failed = XiangjiProviderFileRecord(
        id: id,
        providerId: providerId,
        sourceId: source.id,
        state: XiangjiProviderFileState.failed,
        remoteFileId: existing?.remoteFileId ?? '',
        remoteStoreId: existing?.remoteStoreId ?? '',
        retentionInfo: capability.retentionPolicy,
        lastError: error.toString(),
        uploadedAtMs: existing?.uploadedAtMs ?? 0,
        expiresAtMs: existing?.expiresAtMs ?? 0,
      );
      await _dao.saveProviderFile(failed);
      rethrow;
    }
  }

  Future<void> deleteRemoteCopy(XiangjiProviderFileRecord item) async {
    final capability = await _dao.providerCapability(item.providerId);
    if (capability == null) throw ArgumentError('未知 AI 服务商。');
    if (!capability.supportsDelete) {
      throw StateError('${capability.label} 不支持即时远程删除；只能停止本地使用并等待到期。');
    }
    final deleting = XiangjiProviderFileRecord(
      id: item.id,
      providerId: item.providerId,
      sourceId: item.sourceId,
      state: XiangjiProviderFileState.deleting,
      remoteFileId: item.remoteFileId,
      remoteStoreId: item.remoteStoreId,
      retentionInfo: item.retentionInfo,
      uploadedAtMs: item.uploadedAtMs,
      expiresAtMs: item.expiresAtMs,
    );
    await _dao.saveProviderFile(deleting);
    final provider = ZxRemoteKnowledgeProviderX.parse(item.providerId);
    try {
      await _providerService.deleteExternalCopy(ZxRemoteKnowledgeItem(
        bookId: _stableNumericId(item.sourceId),
        provider: provider,
        remoteFileId: item.remoteFileId,
        remoteStoreId: item.remoteStoreId,
        remoteDocumentId: provider == ZxRemoteKnowledgeProvider.gemini
            ? item.remoteFileId
            : '',
        retentionLabel: item.retentionInfo,
        expiresAtMs: item.expiresAtMs,
      ));
      _stateMachine
          .evaluate(
            XiangjiProviderFileState.deleting,
            XiangjiProviderFileState.deleted,
            capability: capability,
            providerDeleteConfirmed: true,
          )
          .requireAllowed();
      await _dao.saveProviderFile(XiangjiProviderFileRecord(
        id: item.id,
        providerId: item.providerId,
        sourceId: item.sourceId,
        state: XiangjiProviderFileState.deleted,
        retentionInfo: item.retentionInfo,
        uploadedAtMs: item.uploadedAtMs,
      ));
    } catch (error) {
      await _dao.saveProviderFile(XiangjiProviderFileRecord(
        id: item.id,
        providerId: item.providerId,
        sourceId: item.sourceId,
        state: XiangjiProviderFileState.failed,
        remoteFileId: item.remoteFileId,
        remoteStoreId: item.remoteStoreId,
        retentionInfo: item.retentionInfo,
        lastError: '远程删除未确认：$error',
        uploadedAtMs: item.uploadedAtMs,
        expiresAtMs: item.expiresAtMs,
      ));
      rethrow;
    }
  }

  int _stableNumericId(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  ZxRemoteKnowledgeStatus _toRemoteState(XiangjiProviderFileState state) =>
      switch (state) {
        XiangjiProviderFileState.ready => ZxRemoteKnowledgeStatus.ready,
        XiangjiProviderFileState.processing ||
        XiangjiProviderFileState.uploading =>
          ZxRemoteKnowledgeStatus.processing,
        XiangjiProviderFileState.deleted => ZxRemoteKnowledgeStatus.deleted,
        _ => ZxRemoteKnowledgeStatus.failed,
      };
}

class XiangjiKnowledgeGovernanceService {
  XiangjiKnowledgeGovernanceService({XiangjiDao? dao})
      : _dao = dao ?? XiangjiDao();

  final XiangjiDao _dao;
  final XiangjiKnowledgeItemStateMachine _machine =
      const XiangjiKnowledgeItemStateMachine();

  Future<XiangjiKnowledgeItemState> validateCandidate({
    required String id,
    required List<String> supportingRefs,
    required List<String> counterRefs,
    required String validationPlan,
    required String scope,
    required int distinctEventCount,
    required bool userExplicitlyConfirmed,
    required bool counterexamplesReviewed,
    bool requestStable = false,
    bool hasStrongConflict = false,
  }) async {
    final candidates = await _dao.candidateKnowledge();
    final rows = candidates.where((row) => row['id'] == id).toList();
    if (rows.isEmpty) throw ArgumentError('候选知识不存在。');
    final rawState = (rows.first['status'] ?? 'CANDIDATE').toString();
    final from = XiangjiKnowledgeItemState.values.firstWhere(
      (value) => value.wire == rawState,
      orElse: () => XiangjiKnowledgeItemState.candidate,
    );
    final target = hasStrongConflict
        ? XiangjiKnowledgeItemState.conflicted
        : requestStable
            ? XiangjiKnowledgeItemState.stable
            : XiangjiKnowledgeItemState.supported;
    final decision = _machine.evaluate(
      from,
      target,
      realEvidenceCount: supportingRefs.length,
      distinctEventCount: distinctEventCount,
      userExplicitlyConfirmed: userExplicitlyConfirmed,
      hasScope: scope.trim().isNotEmpty,
      counterexamplesPreserved: counterexamplesReviewed,
      hasStrongConflict: hasStrongConflict,
    );
    decision.requireAllowed();
    if (validationPlan.trim().isEmpty) {
      throw ArgumentError('请保留后续验证计划。');
    }
    await _dao.applyCandidateValidation(
      id: id,
      state: target,
      supportingRefs: supportingRefs,
      counterRefs: counterRefs,
      validationPlan: validationPlan.trim(),
      scope: scope.trim(),
      distinctEventCount: distinctEventCount,
      userConfirmed: userExplicitlyConfirmed,
    );
    return target;
  }
}
