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

export 'xiangji_knowledge_route_core.dart';

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
