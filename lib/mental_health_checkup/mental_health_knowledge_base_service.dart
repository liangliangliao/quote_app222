import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../services/unified_ai_service.dart';
import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_repository.dart';
import 'mental_health_knowledge_models.dart';

class CheckupKnowledgeProviderSnapshot {
  final UnifiedAiResolvedConfig config;
  final String accountFingerprint;
  final bool supportsPersistentFile;
  final CheckupProviderKnowledgeResource? activeResource;

  const CheckupKnowledgeProviderSnapshot({
    required this.config,
    required this.accountFingerprint,
    required this.supportsPersistentFile,
    required this.activeResource,
  });
}

class MentalHealthKnowledgeBaseService {
  final MentalHealthCheckupRepository repository;
  final UnifiedAiService ai;

  MentalHealthKnowledgeBaseService({
    required this.repository,
    UnifiedAiService? aiService,
  }) : ai = aiService ?? UnifiedAiService();

  Future<CheckupKnowledgeProviderSnapshot> snapshot({
    required MentalHealthCheckupCatalog catalog,
  }) async {
    final config = await ai.resolveGlobalConfig();
    final fingerprint = _accountFingerprint(config);
    final corpus = await repository.buildCourseKnowledgeCorpus(
      catalog: catalog,
    );
    final resources = await repository.loadProviderKnowledgeResources(
      provider: config.provider,
      accountFingerprint: fingerprint,
    );
    CheckupProviderKnowledgeResource? active;
    for (final resource in resources) {
      final matches = resource.matchesCourse(
        version: corpus.courseVersion,
        sha256: corpus.sourceSha256,
      );
      if (resource.ready && matches) {
        active = resource;
        break;
      }
      if (resource.enabled &&
          resource.status == CheckupKnowledgeResourceStatus.ready &&
          !matches) {
        await repository.saveProviderKnowledgeResource(
          resource.copyWith(
            enabled: false,
            status: CheckupKnowledgeResourceStatus.stale,
            failureReason: '本地课程知识已变化，请重新上传后再启用。',
            lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    }
    return CheckupKnowledgeProviderSnapshot(
      config: config,
      accountFingerprint: fingerprint,
      supportsPersistentFile: ai.supportsPersistentKnowledgeFile(
        config.provider,
      ),
      activeResource: active,
    );
  }

  Future<CheckupProviderKnowledgeResource> uploadCurrentCourse({
    required MentalHealthCheckupCatalog catalog,
  }) async {
    final config = await ai.resolveGlobalConfig();
    if (!config.available) {
      throw StateError('请先在全局AI设置中配置供应商和API密钥');
    }
    if (!ai.supportsPersistentKnowledgeFile(config.provider)) {
      throw UnsupportedError('${config.label}暂不支持持久文件ID；系统将继续使用本地RAG。');
    }
    final corpus = await repository.buildCourseKnowledgeCorpus(
      catalog: catalog,
    );
    final fingerprint = _accountFingerprint(config);
    final id = 'provider-kb-${config.provider}-$fingerprint-'
        '${corpus.sourceSha256.substring(0, 16)}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final uploading = CheckupProviderKnowledgeResource(
      id: id,
      provider: config.provider,
      providerLabel: config.label,
      accountFingerprint: fingerprint,
      providerFileId: '',
      providerResourceId: '',
      courseVersion: corpus.courseVersion,
      sourceSha256: corpus.sourceSha256,
      fileName: corpus.fileName,
      byteCount: corpus.bytes.length,
      status: CheckupKnowledgeResourceStatus.uploading,
      enabled: false,
      uploadedAtMs: now,
      lastVerifiedAtMs: now,
    );
    await repository.saveProviderKnowledgeResource(uploading);
    UnifiedAiUploadedFile? uploaded;
    try {
      uploaded = await ai.uploadKnowledgeFileBytes(
        bytes: Uint8List.fromList(corpus.bytes),
        filename: corpus.fileName,
      );
    } catch (_) {
      final failed = uploading.copyWith(
        status: CheckupKnowledgeResourceStatus.failed,
        failureReason: '供应商上传请求异常',
        lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await repository.saveProviderKnowledgeResource(failed);
      return failed;
    }
    if (uploaded == null) {
      final failed = uploading.copyWith(
        status: CheckupKnowledgeResourceStatus.failed,
        failureReason: '供应商没有返回可复用的文件ID',
        lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await repository.saveProviderKnowledgeResource(failed);
      return failed;
    }
    final ready = uploading.copyWith(
      providerFileId: uploaded.fileId,
      providerResourceId: uploaded.resourceId,
      byteCount: uploaded.byteCount,
      status: CheckupKnowledgeResourceStatus.ready,
      enabled: true,
      lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
      failureReason: '',
    );
    await repository.saveProviderKnowledgeResource(ready);
    return ready;
  }

  Future<void> setEnabled(
    CheckupProviderKnowledgeResource resource,
    bool enabled,
  ) =>
      repository.saveProviderKnowledgeResource(
        resource.copyWith(
          enabled: enabled,
          lastVerifiedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<bool> deleteOrDetach(CheckupProviderKnowledgeResource resource) async {
    final deleted = await ai.deleteKnowledgeFile(
      provider: resource.provider,
      fileId: resource.providerFileId,
    );
    await repository.detachProviderKnowledgeResource(resource.id);
    return deleted;
  }

  Future<CheckupProviderKnowledgeResource?> activeResource({
    required MentalHealthCheckupCatalog catalog,
  }) async {
    final value = await snapshot(catalog: catalog);
    return value.activeResource;
  }

  static String _accountFingerprint(UnifiedAiResolvedConfig config) {
    if (!config.available) return 'unconfigured';
    final bytes = utf8.encode('${config.provider}:${config.apiKey}');
    return sha256.convert(bytes).toString().substring(0, 20);
  }
}
