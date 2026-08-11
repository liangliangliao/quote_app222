/// The remote knowledge layer is intentionally separate from both the
/// reviewed package and AI-derived summaries.  It only stores provider-side
/// identifiers and lifecycle metadata; API keys never enter these records.
enum ZxRemoteKnowledgeProvider {
  openai,
  azureOpenAi,
  xgrok,
  gemini,
  claude,
  openRouter,
  edenAi,
  openAiCompatible,
}

extension ZxRemoteKnowledgeProviderX on ZxRemoteKnowledgeProvider {
  String get key {
    switch (this) {
      case ZxRemoteKnowledgeProvider.openai:
        return 'openai';
      case ZxRemoteKnowledgeProvider.azureOpenAi:
        return 'azure_openai';
      case ZxRemoteKnowledgeProvider.xgrok:
        return 'xgrok';
      case ZxRemoteKnowledgeProvider.gemini:
        return 'gemini';
      case ZxRemoteKnowledgeProvider.claude:
        return 'claude';
      case ZxRemoteKnowledgeProvider.openRouter:
        return 'openrouter';
      case ZxRemoteKnowledgeProvider.edenAi:
        return 'edenai';
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return 'openai_compatible';
    }
  }

  String get label {
    switch (this) {
      case ZxRemoteKnowledgeProvider.openai:
        return 'OpenAI · Vector Store';
      case ZxRemoteKnowledgeProvider.azureOpenAi:
        return 'Microsoft Azure OpenAI';
      case ZxRemoteKnowledgeProvider.xgrok:
        return 'xAI Grok · Files';
      case ZxRemoteKnowledgeProvider.gemini:
        return 'Google Gemini · File Search';
      case ZxRemoteKnowledgeProvider.claude:
        return 'Anthropic Claude · Files';
      case ZxRemoteKnowledgeProvider.openRouter:
        return 'OpenRouter · 中转文件库';
      case ZxRemoteKnowledgeProvider.edenAi:
        return 'Eden AI · 临时中转文件';
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return '其他 OpenAI 文件协议服务';
    }
  }

  /// A concise and truthful retention label for the UI. Gemini retains the
  /// indexed knowledge, not the raw uploaded file, so it must not be labelled
  /// as permanent raw-file storage.
  String get retentionLabel {
    switch (this) {
      case ZxRemoteKnowledgeProvider.openai:
        return '文件与向量库保留至你手动删除';
      case ZxRemoteKnowledgeProvider.azureOpenAi:
        return '文件与向量库保存在你的 Azure 资源中，直至手动删除';
      case ZxRemoteKnowledgeProvider.xgrok:
        return '文件保留至你手动删除';
      case ZxRemoteKnowledgeProvider.gemini:
        return '检索索引保留至你手动删除；原始文件按Gemini规则限期保存';
      case ZxRemoteKnowledgeProvider.claude:
        return '文件保留至你手动删除';
      case ZxRemoteKnowledgeProvider.openRouter:
        return '文件保存在 OpenRouter 工作区，直至手动删除';
      case ZxRemoteKnowledgeProvider.edenAi:
        return '临时文件 ID 可重复调用，但默认 7 天自动过期；不是永久书库';
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return '取决于你配置的服务商协议与保留策略';
    }
  }

  String get setupHint {
    switch (this) {
      case ZxRemoteKnowledgeProvider.openai:
        return '使用全局设置中的 OpenAI 密钥，自动建立 Vector Store。';
      case ZxRemoteKnowledgeProvider.azureOpenAi:
        return '填写 Azure OpenAI 资源地址、API Key 和模型部署名，自动建立 Vector Store。';
      case ZxRemoteKnowledgeProvider.xgrok:
        return '使用全局设置中的 xGrok 密钥，后续通过 file_id 直接问书。';
      case ZxRemoteKnowledgeProvider.gemini:
        return '使用全局设置中的 Gemini 密钥，自动建立 File Search Store。';
      case ZxRemoteKnowledgeProvider.claude:
        return '需要在本页保存 Claude API Key；Files API 目前属于 Beta。';
      case ZxRemoteKnowledgeProvider.openRouter:
        return '聊天使用全局 OpenRouter Key；文件上传/删除使用单独的 Management Key。可路由 Claude、Grok、Gemini 等模型。';
      case ZxRemoteKnowledgeProvider.edenAi:
        return '使用全局 Eden AI Key 和模型；可跨 OpenAI、Claude、Gemini 等模型复用 file_id，但文件默认 7 天过期。';
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return '仅适用于明确实现 Files、Vector Store 和 Responses 协议的服务商。';
    }
  }

  bool get isGateway =>
      this == ZxRemoteKnowledgeProvider.openRouter ||
      this == ZxRemoteKnowledgeProvider.edenAi ||
      this == ZxRemoteKnowledgeProvider.openAiCompatible;

  bool get supportsImmediateDelete =>
      this != ZxRemoteKnowledgeProvider.edenAi;

  bool get isPersistentKnowledge =>
      this != ZxRemoteKnowledgeProvider.edenAi &&
      this != ZxRemoteKnowledgeProvider.openAiCompatible;

  static ZxRemoteKnowledgeProvider parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'xgrok':
      case 'grok':
      case 'xai':
        return ZxRemoteKnowledgeProvider.xgrok;
      case 'gemini':
      case 'google':
        return ZxRemoteKnowledgeProvider.gemini;
      case 'claude':
      case 'anthropic':
        return ZxRemoteKnowledgeProvider.claude;
      case 'azure':
      case 'azure_openai':
      case 'azureopenai':
        return ZxRemoteKnowledgeProvider.azureOpenAi;
      case 'openrouter':
        return ZxRemoteKnowledgeProvider.openRouter;
      case 'eden':
      case 'eden_ai':
      case 'edenai':
        return ZxRemoteKnowledgeProvider.edenAi;
      case 'openai_compatible':
      case 'compatible':
        return ZxRemoteKnowledgeProvider.openAiCompatible;
      case 'openai':
      default:
        return ZxRemoteKnowledgeProvider.openai;
    }
  }
}

enum ZxRemoteKnowledgeStatus { ready, processing, failed, deleted }

extension ZxRemoteKnowledgeStatusX on ZxRemoteKnowledgeStatus {
  String get key {
    switch (this) {
      case ZxRemoteKnowledgeStatus.ready:
        return 'ready';
      case ZxRemoteKnowledgeStatus.processing:
        return 'processing';
      case ZxRemoteKnowledgeStatus.failed:
        return 'failed';
      case ZxRemoteKnowledgeStatus.deleted:
        return 'deleted';
    }
  }

  String get label {
    switch (this) {
      case ZxRemoteKnowledgeStatus.ready:
        return '远端书库已就绪';
      case ZxRemoteKnowledgeStatus.processing:
        return '正在建立索引';
      case ZxRemoteKnowledgeStatus.failed:
        return '远端同步失败';
      case ZxRemoteKnowledgeStatus.deleted:
        return '已从服务商删除';
    }
  }

  static ZxRemoteKnowledgeStatus parse(Object? raw) {
    switch (raw?.toString()) {
      case 'processing':
        return ZxRemoteKnowledgeStatus.processing;
      case 'failed':
        return ZxRemoteKnowledgeStatus.failed;
      case 'deleted':
        return ZxRemoteKnowledgeStatus.deleted;
      case 'ready':
      default:
        return ZxRemoteKnowledgeStatus.ready;
    }
  }
}

class ZxRemoteKnowledgeStore {
  const ZxRemoteKnowledgeStore({
    this.id = 0,
    required this.provider,
    required this.thinker,
    required this.remoteStoreId,
    this.providerModel = '',
    this.status = ZxRemoteKnowledgeStatus.ready,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final int id;
  final ZxRemoteKnowledgeProvider provider;
  final String thinker;
  final String remoteStoreId;
  final String providerModel;
  final ZxRemoteKnowledgeStatus status;
  final int createdAtMs;
  final int updatedAtMs;

  Map<String, Object?> toMap() => <String, Object?>{
        'provider': provider.key,
        'thinker': thinker,
        'remote_store_id': remoteStoreId,
        'provider_model': providerModel,
        'status': status.key,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory ZxRemoteKnowledgeStore.fromMap(Map<String, Object?> row) =>
      ZxRemoteKnowledgeStore(
        id: _remoteInt(row['id']),
        provider: ZxRemoteKnowledgeProviderX.parse(row['provider']),
        thinker: (row['thinker'] ?? '').toString(),
        remoteStoreId: (row['remote_store_id'] ?? '').toString(),
        providerModel: (row['provider_model'] ?? '').toString(),
        status: ZxRemoteKnowledgeStatusX.parse(row['status']),
        createdAtMs: _remoteInt(row['created_at_ms']),
        updatedAtMs: _remoteInt(row['updated_at_ms']),
      );
}

class ZxRemoteKnowledgeItem {
  const ZxRemoteKnowledgeItem({
    this.id = 0,
    required this.bookId,
    required this.provider,
    this.remoteFileId = '',
    this.remoteStoreId = '',
    this.remoteDocumentId = '',
    this.storageKind = '',
    this.retentionLabel = '',
    this.providerModel = '',
    this.expiresAtMs = 0,
    this.status = ZxRemoteKnowledgeStatus.ready,
    this.lastError = '',
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final int id;
  final int bookId;
  final ZxRemoteKnowledgeProvider provider;
  final String remoteFileId;
  final String remoteStoreId;
  final String remoteDocumentId;
  final String storageKind;
  final String retentionLabel;
  final String providerModel;
  final int expiresAtMs;
  final ZxRemoteKnowledgeStatus status;
  final String lastError;
  final int createdAtMs;
  final int updatedAtMs;

  bool get isExpired =>
      expiresAtMs > 0 && expiresAtMs <= DateTime.now().millisecondsSinceEpoch;

  bool get isReady {
    if (status != ZxRemoteKnowledgeStatus.ready) return false;
    if (isExpired) return false;
    switch (provider) {
      case ZxRemoteKnowledgeProvider.openai:
      case ZxRemoteKnowledgeProvider.azureOpenAi:
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return remoteFileId.isNotEmpty && remoteStoreId.isNotEmpty;
      case ZxRemoteKnowledgeProvider.gemini:
        return remoteStoreId.isNotEmpty && remoteDocumentId.isNotEmpty;
      case ZxRemoteKnowledgeProvider.xgrok:
      case ZxRemoteKnowledgeProvider.claude:
      case ZxRemoteKnowledgeProvider.openRouter:
      case ZxRemoteKnowledgeProvider.edenAi:
        return remoteFileId.isNotEmpty;
    }
  }

  ZxRemoteKnowledgeItem copyWith({
    String? remoteFileId,
    String? remoteStoreId,
    String? remoteDocumentId,
    String? storageKind,
    String? retentionLabel,
    String? providerModel,
    int? expiresAtMs,
    ZxRemoteKnowledgeStatus? status,
    String? lastError,
    int? updatedAtMs,
  }) =>
      ZxRemoteKnowledgeItem(
        id: id,
        bookId: bookId,
        provider: provider,
        remoteFileId: remoteFileId ?? this.remoteFileId,
        remoteStoreId: remoteStoreId ?? this.remoteStoreId,
        remoteDocumentId: remoteDocumentId ?? this.remoteDocumentId,
        storageKind: storageKind ?? this.storageKind,
        retentionLabel: retentionLabel ?? this.retentionLabel,
        providerModel: providerModel ?? this.providerModel,
        expiresAtMs: expiresAtMs ?? this.expiresAtMs,
        status: status ?? this.status,
        lastError: lastError ?? this.lastError,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'book_id': bookId,
        'provider': provider.key,
        'remote_file_id': remoteFileId,
        'remote_store_id': remoteStoreId,
        'remote_document_id': remoteDocumentId,
        'storage_kind': storageKind,
        'retention_label': retentionLabel,
        'provider_model': providerModel,
        'expires_at_ms': expiresAtMs,
        'status': status.key,
        'last_error': lastError,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory ZxRemoteKnowledgeItem.fromMap(Map<String, Object?> row) =>
      ZxRemoteKnowledgeItem(
        id: _remoteInt(row['id']),
        bookId: _remoteInt(row['book_id']),
        provider: ZxRemoteKnowledgeProviderX.parse(row['provider']),
        remoteFileId: (row['remote_file_id'] ?? '').toString(),
        remoteStoreId: (row['remote_store_id'] ?? '').toString(),
        remoteDocumentId: (row['remote_document_id'] ?? '').toString(),
        storageKind: (row['storage_kind'] ?? '').toString(),
        retentionLabel: (row['retention_label'] ?? '').toString(),
        providerModel: (row['provider_model'] ?? '').toString(),
        expiresAtMs: _remoteInt(row['expires_at_ms']),
        status: ZxRemoteKnowledgeStatusX.parse(row['status']),
        lastError: (row['last_error'] ?? '').toString(),
        createdAtMs: _remoteInt(row['created_at_ms']),
        updatedAtMs: _remoteInt(row['updated_at_ms']),
      );
}

class ZxRemoteKnowledgeConfig {
  const ZxRemoteKnowledgeConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.baseUrl = '',
    this.fileApiKey = '',
  });

  final ZxRemoteKnowledgeProvider provider;
  final String apiKey;
  final String model;
  final String baseUrl;
  final String fileApiKey;

  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      (provider != ZxRemoteKnowledgeProvider.openRouter ||
          fileApiKey.trim().isNotEmpty) &&
      ((provider != ZxRemoteKnowledgeProvider.openAiCompatible &&
              provider != ZxRemoteKnowledgeProvider.azureOpenAi) ||
          baseUrl.trim().isNotEmpty);

  String get label => '${provider.label} · $model';
}

class ZxRemoteKnowledgeAnswer {
  const ZxRemoteKnowledgeAnswer({
    required this.text,
    required this.provider,
    required this.modelLabel,
  });

  final String text;
  final ZxRemoteKnowledgeProvider provider;
  final String modelLabel;
}

int _remoteInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
