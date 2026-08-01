import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../ai_assistant/ai_assistant_file_text_extractor.dart';
import '../data/dao.dart';
import '../data/kv_dao.dart';
import '../services/global_ai_settings.dart';
import 'zhixing_dao.dart';
import 'zhixing_extended_models.dart';
import 'zhixing_remote_knowledge_models.dart';

/// Stores remote-provider configuration separately from the app-wide chat
/// provider. Direct providers and named gateways reuse global credentials
/// where possible; Azure, Claude and custom file protocols remain opt-in.
class ZxRemoteKnowledgeSettings {
  ZxRemoteKnowledgeSettings({
    ConfigDao? configDao,
    KeyValueDao? kvDao,
    GlobalAiSettings? globalSettings,
  })  : _configDao = configDao ?? ConfigDao(),
        _kv = kvDao ?? KeyValueDao(),
        _global = globalSettings ?? GlobalAiSettings();

  static const String providerKey = 'zhixing_remote_knowledge_provider_v1';
  static const String claudeKeyKey = 'zhixing_remote_knowledge_claude_key_v1';
  static const String claudeModelKey =
      'zhixing_remote_knowledge_claude_model_v1';
  static const String azureKeyKey =
      'zhixing_remote_knowledge_azure_key_v1';
  static const String azureEndpointKey =
      'zhixing_remote_knowledge_azure_endpoint_v1';
  static const String azureModelKey =
      'zhixing_remote_knowledge_azure_model_v1';
  static const String openRouterFileKeyKey =
      'zhixing_remote_knowledge_openrouter_file_key_v1';
  static const String compatibleKeyKey =
      'zhixing_remote_knowledge_compatible_key_v1';
  static const String compatibleBaseUrlKey =
      'zhixing_remote_knowledge_compatible_base_url_v1';
  static const String compatibleModelKey =
      'zhixing_remote_knowledge_compatible_model_v1';

  final ConfigDao _configDao;
  final KeyValueDao _kv;
  final GlobalAiSettings _global;

  Future<ZxRemoteKnowledgeProvider> selectedProvider() async {
    final saved = (await _kv.getString(providerKey) ?? '').trim();
    if (saved.isNotEmpty) return ZxRemoteKnowledgeProviderX.parse(saved);
    final global = await _global.getState();
    final provider = (global['provider'] ?? '').trim();
    switch (provider) {
      case 'openai':
        return ZxRemoteKnowledgeProvider.openai;
      case 'xgrok':
        return ZxRemoteKnowledgeProvider.xgrok;
      case 'gemini':
        return ZxRemoteKnowledgeProvider.gemini;
      case 'openrouter':
        return ZxRemoteKnowledgeProvider.openRouter;
      case 'edenai':
        return ZxRemoteKnowledgeProvider.edenAi;
      default:
        // A generic chat endpoint may not expose Files + Vector Stores.
        // Make the user explicitly choose/configure a compatible server instead
        // of silently sending book files to an arbitrary global endpoint.
        return ZxRemoteKnowledgeProvider.openAiCompatible;
    }
  }

  Future<ZxRemoteKnowledgeConfig> resolve({
    ZxRemoteKnowledgeProvider? provider,
  }) async {
    final target = provider ?? await selectedProvider();
    switch (target) {
      case ZxRemoteKnowledgeProvider.openai:
        final row = await _configDao.getOne();
        final endpoint = (row['endpoint'] ?? '').toString().trim();
        final model = await _global.getModelForProvider('openai');
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: (row['api_key'] ?? '').toString().trim(),
          model: model,
          baseUrl: _openAiBase(endpoint),
        );
      case ZxRemoteKnowledgeProvider.azureOpenAi:
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: (await _kv.getString(azureKeyKey) ?? '').trim(),
          model: (await _kv.getString(azureModelKey) ?? '').trim(),
          baseUrl: _azureOpenAiBase(
            (await _kv.getString(azureEndpointKey) ?? '').trim(),
          ),
        );
      case ZxRemoteKnowledgeProvider.xgrok:
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: await _global.getXGrokKey(),
          model: await _global.getModelForProvider('xgrok'),
          baseUrl: 'https://api.x.ai/v1',
        );
      case ZxRemoteKnowledgeProvider.gemini:
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: await _global.getGeminiKey(),
          model: _geminiModel(await _global.getModelForProvider('gemini')),
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        );
      case ZxRemoteKnowledgeProvider.claude:
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: (await _kv.getString(claudeKeyKey) ?? '').trim(),
          model: (await _kv.getString(claudeModelKey) ??
                  'claude-sonnet-4-5')
              .trim(),
          baseUrl: 'https://api.anthropic.com/v1',
        );
      case ZxRemoteKnowledgeProvider.openRouter:
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: await _configDao.getOpenRouterKey(),
          fileApiKey:
              (await _kv.getString(openRouterFileKeyKey) ?? '').trim(),
          model: await _global.getModelForProvider('openrouter'),
          baseUrl: 'https://openrouter.ai/api/v1',
        );
      case ZxRemoteKnowledgeProvider.edenAi:
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: await _global.getEdenAiKey(),
          model: await _global.getModelForProvider('edenai'),
          baseUrl: 'https://api.edenai.run/v3',
        );
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        final rawBaseUrl =
            (await _kv.getString(compatibleBaseUrlKey) ?? '').trim();
        return ZxRemoteKnowledgeConfig(
          provider: target,
          apiKey: (await _kv.getString(compatibleKeyKey) ?? '').trim(),
          model: (await _kv.getString(compatibleModelKey) ??
                  'gpt-4.1-mini')
              .trim(),
          baseUrl: rawBaseUrl.isEmpty ? '' : _openAiBase(rawBaseUrl),
        );
    }
  }

  Future<Map<String, String>> editableValues() async => <String, String>{
        'claude_key': (await _kv.getString(claudeKeyKey) ?? '').trim(),
        'claude_model':
            (await _kv.getString(claudeModelKey) ?? 'claude-sonnet-4-5')
                .trim(),
        'azure_key': (await _kv.getString(azureKeyKey) ?? '').trim(),
        'azure_endpoint':
            (await _kv.getString(azureEndpointKey) ?? '').trim(),
        'azure_model': (await _kv.getString(azureModelKey) ?? '').trim(),
        'openrouter_file_key':
            (await _kv.getString(openRouterFileKeyKey) ?? '').trim(),
        'compatible_key':
            (await _kv.getString(compatibleKeyKey) ?? '').trim(),
        'compatible_base_url':
            (await _kv.getString(compatibleBaseUrlKey) ?? '').trim(),
        'compatible_model':
            (await _kv.getString(compatibleModelKey) ?? 'gpt-4.1-mini')
                .trim(),
      };

  Future<void> save({
    required ZxRemoteKnowledgeProvider provider,
    String claudeKey = '',
    String claudeModel = '',
    String azureKey = '',
    String azureEndpoint = '',
    String azureModel = '',
    String openRouterFileKey = '',
    String compatibleKey = '',
    String compatibleBaseUrl = '',
    String compatibleModel = '',
  }) async {
    await _kv.setString(providerKey, provider.key);
    if (provider == ZxRemoteKnowledgeProvider.claude) {
      await _kv.setString(claudeKeyKey, claudeKey.trim());
      await _kv.setString(
        claudeModelKey,
        claudeModel.trim().isEmpty ? 'claude-sonnet-4-5' : claudeModel.trim(),
      );
    }
    if (provider == ZxRemoteKnowledgeProvider.azureOpenAi) {
      await _kv.setString(azureKeyKey, azureKey.trim());
      await _kv.setString(azureEndpointKey, azureEndpoint.trim());
      await _kv.setString(azureModelKey, azureModel.trim());
    }
    if (provider == ZxRemoteKnowledgeProvider.openRouter) {
      await _kv.setString(openRouterFileKeyKey, openRouterFileKey.trim());
    }
    if (provider == ZxRemoteKnowledgeProvider.openAiCompatible) {
      await _kv.setString(compatibleKeyKey, compatibleKey.trim());
      await _kv.setString(compatibleBaseUrlKey, compatibleBaseUrl.trim());
      await _kv.setString(
        compatibleModelKey,
        compatibleModel.trim().isEmpty
            ? 'gpt-4.1-mini'
            : compatibleModel.trim(),
      );
    }
  }

  static String _geminiModel(String raw) =>
      raw.startsWith('models/') ? raw.substring('models/'.length) : raw;

  static String _openAiBase(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return 'https://api.openai.com/v1';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    const suffixes = <String>[
      '/responses',
      '/chat/completions',
      '/v1/responses',
      '/v1/chat/completions',
    ];
    for (final suffix in suffixes) {
      if (value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }
    if (value.endsWith('/v1')) return value;
    return '$value/v1';
  }

  static String _azureOpenAiBase(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) return '';
    final openAiPath = value.indexOf('/openai/');
    if (openAiPath >= 0) {
      value = value.substring(0, openAiPath);
    }
    return '$value/openai/v1';
  }
}

/// Native provider adapters for reusable provider-side source references. A
/// call is allowed only when every selected book has a saved, unexpired and
/// ready provider record. Temporary gateway files are labelled explicitly.
class ZxRemoteKnowledgeService {
  ZxRemoteKnowledgeService({
    ZxDao? dao,
    ZxRemoteKnowledgeSettings? settings,
    http.Client? client,
  })  : _dao = dao ?? ZxDao(),
        _settings = settings ?? ZxRemoteKnowledgeSettings(),
        _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 45);
  static const String _anthropicVersion = '2023-06-01';
  static const String _anthropicFilesBeta = 'files-api-2025-04-14';

  final ZxDao _dao;
  final ZxRemoteKnowledgeSettings _settings;
  final http.Client _client;
  final AiAssistantFileTextExtractor _extractor =
      AiAssistantFileTextExtractor();

  Future<ZxRemoteKnowledgeProvider> selectedProvider() =>
      _settings.selectedProvider();

  Future<ZxRemoteKnowledgeConfig> currentConfig({
    ZxRemoteKnowledgeProvider? provider,
  }) =>
      _settings.resolve(provider: provider);

  Future<Map<String, String>> editableSettings() => _settings.editableValues();

  Future<void> saveSettings({
    required ZxRemoteKnowledgeProvider provider,
    String claudeKey = '',
    String claudeModel = '',
    String azureKey = '',
    String azureEndpoint = '',
    String azureModel = '',
    String openRouterFileKey = '',
    String compatibleKey = '',
    String compatibleBaseUrl = '',
    String compatibleModel = '',
  }) =>
      _settings.save(
        provider: provider,
        claudeKey: claudeKey,
        claudeModel: claudeModel,
        azureKey: azureKey,
        azureEndpoint: azureEndpoint,
        azureModel: azureModel,
        openRouterFileKey: openRouterFileKey,
        compatibleKey: compatibleKey,
        compatibleBaseUrl: compatibleBaseUrl,
        compatibleModel: compatibleModel,
      );

  Future<List<ZxRemoteKnowledgeItem>> items({
    ZxRemoteKnowledgeProvider? provider,
  }) =>
      _dao.remoteKnowledgeItems(provider: provider, includeDeleted: true);

  Future<bool> hasReadyBooks({
    required List<int> bookIds,
    required ZxRemoteKnowledgeProvider provider,
  }) async {
    if (bookIds.isEmpty) return false;
    final items = await _dao.remoteKnowledgeItems(
      provider: provider,
      bookIds: bookIds,
    );
    final byBook = <int, ZxRemoteKnowledgeItem>{
      for (final item in items) item.bookId: item,
    };
    return bookIds.every((id) => byBook[id]?.isReady ?? false);
  }

  /// Uploads books once and saves the returned provider identifiers. Existing
  /// ready records are reused, so later analysis and questions never re-upload
  /// the same source file.
  Future<List<ZxRemoteKnowledgeItem>> syncBooks(
    List<ZxAiBook> books, {
    ZxRemoteKnowledgeProvider? provider,
  }) async {
    if (books.isEmpty) throw ArgumentError('请至少选择一本著作。');
    final config = await _settings.resolve(provider: provider);
    _ensureConfigured(config);
    final results = <ZxRemoteKnowledgeItem>[];
    for (final book in books) {
      final existing = await _dao.remoteKnowledgeItem(
        bookId: book.id,
        provider: config.provider,
      );
      if (existing?.isReady ?? false) {
        results.add(existing!);
        continue;
      }
      try {
        final item = await _syncBook(book, config, existing: existing);
        results.add(await _dao.saveRemoteKnowledgeItem(item));
      } catch (error) {
        final failed = (existing ??
                ZxRemoteKnowledgeItem(
                  bookId: book.id,
                  provider: config.provider,
                  retentionLabel: config.provider.retentionLabel,
                  providerModel: config.model,
                ))
            .copyWith(
          status: ZxRemoteKnowledgeStatus.failed,
          lastError: _safeError(error),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        results.add(await _dao.saveRemoteKnowledgeItem(failed));
      }
    }
    return results;
  }

  Future<ZxRemoteKnowledgeAnswer> askBooks({
    required List<int> bookIds,
    required ZxRemoteKnowledgeProvider provider,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 1800,
  }) async {
    final config = await _settings.resolve(provider: provider);
    _ensureConfigured(config);
    final items = await _readyItems(bookIds, provider);
    switch (provider) {
      case ZxRemoteKnowledgeProvider.openai:
      case ZxRemoteKnowledgeProvider.azureOpenAi:
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return _askOpenAiStore(
          config: config,
          items: items,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
        );
      case ZxRemoteKnowledgeProvider.xgrok:
        return _askXGrokFiles(
          config: config,
          items: items,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
        );
      case ZxRemoteKnowledgeProvider.gemini:
        return _askGeminiStore(
          config: config,
          items: items,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
      case ZxRemoteKnowledgeProvider.claude:
        return _askClaudeFiles(
          config: config,
          items: items,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
        );
      case ZxRemoteKnowledgeProvider.openRouter:
        return _askResponseFileIds(
          config: config,
          items: items,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          operation: '基于 OpenRouter 工作区文件回答',
        );
      case ZxRemoteKnowledgeProvider.edenAi:
        return _askEdenFiles(
          config: config,
          items: items,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
        );
    }
  }

  /// Deletes the actual provider resource first, then leaves a local tombstone
  /// so the UI can prove that this remote copy is no longer selectable.
  Future<ZxRemoteKnowledgeItem> deleteRemoteCopy(
    ZxRemoteKnowledgeItem item,
  ) async {
    if (item.status == ZxRemoteKnowledgeStatus.deleted) return item;
    if (item.provider == ZxRemoteKnowledgeProvider.edenAi) {
      // Eden AI V3 exposes automatic expiry (normally seven days) but no
      // public immediate file-delete endpoint. No credential is needed to
      // stop selecting the saved ID locally while the provider expires it.
      return _dao.saveRemoteKnowledgeItem(
        item.copyWith(
          status: ZxRemoteKnowledgeStatus.deleted,
          lastError: '已停止在本应用中使用；Eden AI 未提供即时删除文件接口，远端副本将在到期时间自动删除。',
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    final config = await _settings.resolve(provider: item.provider);
    _ensureConfigured(config);
    switch (item.provider) {
      case ZxRemoteKnowledgeProvider.openai:
      case ZxRemoteKnowledgeProvider.azureOpenAi:
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        if (item.remoteStoreId.isNotEmpty && item.remoteFileId.isNotEmpty) {
          await _deleteIgnoringNotFound(
            Uri.parse(
              '${config.baseUrl}/vector_stores/${Uri.encodeComponent(item.remoteStoreId)}/files/${Uri.encodeComponent(item.remoteFileId)}',
            ),
            _openAiHeaders(config),
          );
        }
        if (item.remoteFileId.isNotEmpty) {
          await _deleteIgnoringNotFound(
            Uri.parse(
              '${config.baseUrl}/files/${Uri.encodeComponent(item.remoteFileId)}',
            ),
            _openAiHeaders(config),
          );
        }
        break;
      case ZxRemoteKnowledgeProvider.xgrok:
        await _deleteIgnoringNotFound(
          Uri.parse(
            '${config.baseUrl}/files/${Uri.encodeComponent(item.remoteFileId)}',
          ),
          _bearer(config.apiKey),
        );
        break;
      case ZxRemoteKnowledgeProvider.gemini:
        if (item.remoteDocumentId.isEmpty ||
            !item.remoteDocumentId.startsWith('fileSearchStores/')) {
          throw StateError('Gemini 文档仍在建立索引，暂时无法确认删除。');
        }
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/${item.remoteDocumentId}?key=${Uri.encodeQueryComponent(config.apiKey)}&force=true',
        );
        await _deleteIgnoringNotFound(uri, const <String, String>{});
        break;
      case ZxRemoteKnowledgeProvider.claude:
        await _deleteIgnoringNotFound(
          Uri.parse(
            '${config.baseUrl}/files/${Uri.encodeComponent(item.remoteFileId)}',
          ),
          _claudeHeaders(config.apiKey),
        );
        break;
      case ZxRemoteKnowledgeProvider.openRouter:
        await _deleteIgnoringNotFound(
          Uri.parse(
            '${config.baseUrl}/files/${Uri.encodeComponent(item.remoteFileId)}',
          ),
          _bearer(config.fileApiKey),
        );
        break;
      case ZxRemoteKnowledgeProvider.edenAi:
        // Handled before configuration because there is no delete request.
        break;
    }
    return _dao.saveRemoteKnowledgeItem(
      item.copyWith(
        status: ZxRemoteKnowledgeStatus.deleted,
        lastError: '',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<ZxRemoteKnowledgeItem> _syncBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config, {
    ZxRemoteKnowledgeItem? existing,
  }) async {
    switch (config.provider) {
      case ZxRemoteKnowledgeProvider.openai:
      case ZxRemoteKnowledgeProvider.azureOpenAi:
      case ZxRemoteKnowledgeProvider.openAiCompatible:
        return _syncOpenAiBook(book, config, existing: existing);
      case ZxRemoteKnowledgeProvider.xgrok:
        return _syncXGrokBook(book, config);
      case ZxRemoteKnowledgeProvider.gemini:
        return _syncGeminiBook(book, config, existing: existing);
      case ZxRemoteKnowledgeProvider.claude:
        return _syncClaudeBook(book, config);
      case ZxRemoteKnowledgeProvider.openRouter:
        return _syncOpenRouterBook(book, config);
      case ZxRemoteKnowledgeProvider.edenAi:
        return _syncEdenBook(book, config);
    }
  }

  Future<ZxRemoteKnowledgeItem> _syncOpenAiBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config, {
    ZxRemoteKnowledgeItem? existing,
  }) async {
    if (existing?.status == ZxRemoteKnowledgeStatus.processing &&
        existing?.remoteStoreId.isNotEmpty == true &&
        existing?.remoteFileId.isNotEmpty == true) {
      final ready = await _pollOpenAiFile(
        config,
        existing!.remoteStoreId,
        existing.remoteFileId,
      );
      return existing.copyWith(
        status: ready
            ? ZxRemoteKnowledgeStatus.ready
            : ZxRemoteKnowledgeStatus.processing,
        lastError: '',
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
    final storeId = existing?.remoteStoreId.isNotEmpty == true
        ? existing!.remoteStoreId
        : await _ensureOpenAiStore(book.thinker, config);
    final uploaded = await _uploadMultipart(
      Uri.parse('${config.baseUrl}/files'),
      _openAiHeaders(config),
      file: File(book.localPath),
      filename: book.fileName,
      mimeType: book.mimeType,
      fields: const <String, String>{'purpose': 'assistants'},
    );
    final fileId = (uploaded['id'] ?? '').toString();
    if (fileId.isEmpty) throw const FormatException('服务商没有返回文件ID。');
    try {
      await _postJson(
        Uri.parse(
          '${config.baseUrl}/vector_stores/${Uri.encodeComponent(storeId)}/files',
        ),
        _openAiHeaders(config),
        <String, Object?>{'file_id': fileId},
        operation: '附加到远端知识库',
      );
      final ready = await _pollOpenAiFile(config, storeId, fileId);
      return ZxRemoteKnowledgeItem(
        bookId: book.id,
        provider: config.provider,
        remoteFileId: fileId,
        remoteStoreId: storeId,
        storageKind: 'vector_store',
        retentionLabel: config.provider.retentionLabel,
        providerModel: config.model,
        status: ready
            ? ZxRemoteKnowledgeStatus.ready
            : ZxRemoteKnowledgeStatus.processing,
        lastError: '',
        createdAtMs: existing?.createdAtMs ??
            DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      try {
        await _deleteIgnoringNotFound(
          Uri.parse('${config.baseUrl}/files/${Uri.encodeComponent(fileId)}'),
          _openAiHeaders(config),
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<String> _ensureOpenAiStore(
    String thinker,
    ZxRemoteKnowledgeConfig config,
  ) async {
    final existing = await _dao.remoteKnowledgeStore(
      provider: config.provider,
      thinker: thinker,
    );
    if (existing != null && existing.remoteStoreId.isNotEmpty) {
      return existing.remoteStoreId;
    }
    final response = await _postJson(
      Uri.parse('${config.baseUrl}/vector_stores'),
      _openAiHeaders(config),
      <String, Object?>{'name': '知行树 · ${thinker.trim()}'},
      operation: '创建远端知识库',
    );
    final storeId = (response['id'] ?? '').toString();
    if (storeId.isEmpty) throw const FormatException('服务商没有返回知识库ID。');
    await _dao.saveRemoteKnowledgeStore(
      ZxRemoteKnowledgeStore(
        provider: config.provider,
        thinker: thinker.trim(),
        remoteStoreId: storeId,
        providerModel: config.model,
        status: ZxRemoteKnowledgeStatus.ready,
      ),
    );
    return storeId;
  }

  Future<bool> _pollOpenAiFile(
    ZxRemoteKnowledgeConfig config,
    String storeId,
    String fileId,
  ) async {
    final uri = Uri.parse(
      '${config.baseUrl}/vector_stores/${Uri.encodeComponent(storeId)}/files/${Uri.encodeComponent(fileId)}',
    );
    for (var attempt = 0; attempt < 8; attempt++) {
      final response = await _client
          .get(uri, headers: _openAiHeaders(config))
          .timeout(_timeout);
      final payload = _jsonObject(response, operation: '查询远端索引状态');
      final status = (payload['status'] ?? '').toString().toLowerCase();
      if (status == 'completed') return true;
      if (status == 'failed' || status == 'cancelled') {
        throw StateError('服务商未能完成该著作的远端索引。');
      }
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
    return false;
  }

  Future<ZxRemoteKnowledgeItem> _syncXGrokBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config,
  ) async {
    final response = await _uploadMultipart(
      Uri.parse('${config.baseUrl}/files'),
      _bearer(config.apiKey),
      file: File(book.localPath),
      filename: book.fileName,
      mimeType: book.mimeType,
      fields: const <String, String>{'purpose': 'assistants'},
    );
    final fileId = (response['id'] ?? '').toString();
    if (fileId.isEmpty) throw const FormatException('xGrok没有返回文件ID。');
    return ZxRemoteKnowledgeItem(
      bookId: book.id,
      provider: config.provider,
      remoteFileId: fileId,
      storageKind: 'provider_file',
      retentionLabel: config.provider.retentionLabel,
      providerModel: config.model,
      status: ZxRemoteKnowledgeStatus.ready,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<ZxRemoteKnowledgeItem> _syncOpenRouterBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config,
  ) async {
    final response = await _uploadMultipart(
      Uri.parse('${config.baseUrl}/files'),
      _bearer(config.fileApiKey),
      file: File(book.localPath),
      filename: book.fileName,
      mimeType: book.mimeType,
    );
    final fileId = (response['id'] ?? '').toString().trim();
    if (fileId.isEmpty) {
      throw const FormatException('OpenRouter没有返回工作区文件ID。');
    }
    return ZxRemoteKnowledgeItem(
      bookId: book.id,
      provider: config.provider,
      remoteFileId: fileId,
      storageKind: 'openrouter_workspace_file',
      retentionLabel: config.provider.retentionLabel,
      providerModel: config.model,
      status: ZxRemoteKnowledgeStatus.ready,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<ZxRemoteKnowledgeItem> _syncEdenBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config,
  ) async {
    final response = await _uploadMultipart(
      Uri.parse('${config.baseUrl}/upload'),
      _bearer(config.apiKey),
      file: File(book.localPath),
      filename: book.fileName,
      mimeType: book.mimeType,
      fields: const <String, String>{'purpose': 'assistants'},
    );
    final fileId = (response['file_id'] ?? response['id'] ?? '')
        .toString()
        .trim();
    if (fileId.isEmpty) throw const FormatException('Eden AI没有返回file_id。');
    final now = DateTime.now();
    final expiresAt = DateTime.tryParse(
          (response['expires_at'] ?? '').toString(),
        ) ??
        now.add(const Duration(days: 7));
    return ZxRemoteKnowledgeItem(
      bookId: book.id,
      provider: config.provider,
      remoteFileId: fileId,
      storageKind: 'eden_gateway_file_7d',
      retentionLabel: config.provider.retentionLabel,
      providerModel: config.model,
      expiresAtMs: expiresAt.millisecondsSinceEpoch,
      status: ZxRemoteKnowledgeStatus.ready,
      createdAtMs: now.millisecondsSinceEpoch,
      updatedAtMs: now.millisecondsSinceEpoch,
    );
  }

  Future<ZxRemoteKnowledgeItem> _syncGeminiBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config, {
    ZxRemoteKnowledgeItem? existing,
  }) async {
    if (existing?.status == ZxRemoteKnowledgeStatus.processing &&
        existing?.remoteDocumentId.isNotEmpty == true) {
      final refreshed = await _refreshGeminiOperation(
        existing!,
        config,
        expectedFileName: book.fileName,
      );
      if (refreshed != null) return refreshed;
      // The provider still owns an in-flight indexing operation. Never upload
      // the same book again merely because the user tapped refresh.
      return existing.copyWith(
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    }
    final storeId = existing?.remoteStoreId.isNotEmpty == true
        ? existing!.remoteStoreId
        : await _ensureGeminiStore(book.thinker, config);
    final operation = await _uploadGeminiToStore(book, config, storeId);
    var documentId = _geminiDocumentId(operation);
    if (operation['done'] == true && documentId.isEmpty) {
      documentId = await _findGeminiDocumentId(
        config,
        storeId,
        expectedFileName: book.fileName,
      );
    }
    if (operation['done'] == true && documentId.isEmpty) {
      throw StateError('Gemini索引已结束，但没有返回可检索文档ID。');
    }
    final done = documentId.isNotEmpty;
    return ZxRemoteKnowledgeItem(
      bookId: book.id,
      provider: config.provider,
      remoteStoreId: storeId,
      remoteDocumentId: documentId.isNotEmpty
          ? documentId
          : (operation['name'] ?? '').toString(),
      storageKind: 'file_search_store',
      retentionLabel: config.provider.retentionLabel,
      providerModel: config.model,
      status: done
          ? ZxRemoteKnowledgeStatus.ready
          : ZxRemoteKnowledgeStatus.processing,
      createdAtMs: existing?.createdAtMs ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String> _ensureGeminiStore(
    String thinker,
    ZxRemoteKnowledgeConfig config,
  ) async {
    final existing = await _dao.remoteKnowledgeStore(
      provider: ZxRemoteKnowledgeProvider.gemini,
      thinker: thinker,
    );
    if (existing != null && existing.remoteStoreId.isNotEmpty) {
      return existing.remoteStoreId;
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/fileSearchStores?key=${Uri.encodeQueryComponent(config.apiKey)}',
    );
    final response = await _postJson(
      uri,
      const <String, String>{},
      <String, Object?>{
        'displayName': '知行树 · ${thinker.trim()}',
        'embeddingModel': 'models/gemini-embedding-2',
      },
      operation: '创建 Gemini File Search Store',
    );
    final storeId = (response['name'] ?? '').toString();
    if (storeId.isEmpty) throw const FormatException('Gemini没有返回知识库ID。');
    await _dao.saveRemoteKnowledgeStore(
      ZxRemoteKnowledgeStore(
        provider: ZxRemoteKnowledgeProvider.gemini,
        thinker: thinker.trim(),
        remoteStoreId: storeId,
        providerModel: config.model,
      ),
    );
    return storeId;
  }

  Future<Map<String, dynamic>> _uploadGeminiToStore(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config,
    String storeId,
  ) async {
    final file = File(book.localPath);
    if (!await file.exists()) throw ArgumentError('本机著作文件不存在。');
    final bytes = await file.readAsBytes();
    final startUri = Uri.parse(
      'https://generativelanguage.googleapis.com/upload/v1beta/${storeId}:uploadToFileSearchStore?key=${Uri.encodeQueryComponent(config.apiKey)}',
    );
    final started = await _client
        .post(
          startUri,
          headers: <String, String>{
            'X-Goog-Upload-Protocol': 'resumable',
            'X-Goog-Upload-Command': 'start',
            'X-Goog-Upload-Header-Content-Length': bytes.length.toString(),
            'X-Goog-Upload-Header-Content-Type': book.mimeType,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, Object?>{'displayName': book.fileName}),
        )
        .timeout(_timeout);
    if (started.statusCode < 200 || started.statusCode >= 300) {
      throw StateError('Gemini 初始化远端上传失败（HTTP ${started.statusCode}）。');
    }
    final uploadUrl = started.headers['x-goog-upload-url']?.trim() ?? '';
    if (uploadUrl.isEmpty) throw const FormatException('Gemini没有返回上传地址。');
    final completed = await _client
        .post(
          Uri.parse(uploadUrl),
          headers: <String, String>{
            'Content-Length': bytes.length.toString(),
            'X-Goog-Upload-Offset': '0',
            'X-Goog-Upload-Command': 'upload, finalize',
          },
          body: bytes,
        )
        .timeout(_timeout);
    return _jsonObject(completed, operation: '上传到 Gemini File Search');
  }

  Future<ZxRemoteKnowledgeItem?> _refreshGeminiOperation(
    ZxRemoteKnowledgeItem item,
    ZxRemoteKnowledgeConfig config, {
    required String expectedFileName,
  }) async {
    final operation = item.remoteDocumentId;
    if (!operation.startsWith('operations/')) return null;
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$operation?key=${Uri.encodeQueryComponent(config.apiKey)}',
    );
    final response = await _client.get(uri).timeout(_timeout);
    final payload = _jsonObject(response, operation: '查询 Gemini 索引状态');
    if (payload['done'] != true) return null;
    var documentId = _geminiDocumentId(payload);
    if (documentId.isEmpty) {
      documentId = await _findGeminiDocumentId(
        config,
        item.remoteStoreId,
        expectedFileName: expectedFileName,
      );
    }
    if (documentId.isEmpty) {
      throw StateError('Gemini索引已结束，但没有返回可检索文档ID。');
    }
    return item.copyWith(
      remoteDocumentId: documentId,
      status: ZxRemoteKnowledgeStatus.ready,
      lastError: '',
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Depending on the API revision, a completed upload operation may expose
  /// the newly indexed document under a different response field.  Listing
  /// the store gives us a stable fall-back ID that can later be deleted.
  Future<String> _findGeminiDocumentId(
    ZxRemoteKnowledgeConfig config,
    String storeId, {
    required String expectedFileName,
  }) async {
    if (storeId.trim().isEmpty) return '';
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$storeId/documents?key=${Uri.encodeQueryComponent(config.apiKey)}',
    );
    final response = await _client.get(uri).timeout(_timeout);
    final payload = _jsonObject(response, operation: '查询 Gemini 远端文档');
    final rawDocuments = payload['fileSearchDocuments'] ??
        payload['documents'] ??
        payload['file_search_documents'];
    if (rawDocuments is! List) return '';
    final expected = expectedFileName.trim();
    for (final raw in rawDocuments) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString().trim();
      final displayName =
          (raw['displayName'] ?? raw['display_name'] ?? '').toString().trim();
      if (name.isNotEmpty && (expected.isEmpty || displayName == expected)) {
        return name;
      }
    }
    return '';
  }

  Future<ZxRemoteKnowledgeItem> _syncClaudeBook(
    ZxAiBook book,
    ZxRemoteKnowledgeConfig config,
  ) async {
    final prepared = await _prepareClaudeFile(book);
    try {
      final response = await _uploadMultipart(
        Uri.parse('${config.baseUrl}/files'),
        _claudeHeaders(config.apiKey),
        file: prepared.file,
        filename: prepared.filename,
        mimeType: prepared.mimeType,
      );
      final fileId = (response['id'] ?? '').toString();
      if (fileId.isEmpty) throw const FormatException('Claude没有返回文件ID。');
      return ZxRemoteKnowledgeItem(
        bookId: book.id,
        provider: config.provider,
        remoteFileId: fileId,
        storageKind: 'provider_file',
        retentionLabel: config.provider.retentionLabel,
        providerModel: config.model,
        status: ZxRemoteKnowledgeStatus.ready,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } finally {
      if (prepared.temporary) {
        try {
          await prepared.file.delete();
        } catch (_) {}
      }
    }
  }

  Future<_PreparedRemoteFile> _prepareClaudeFile(ZxAiBook book) async {
    if (book.mimeType == 'application/pdf' ||
        book.mimeType == 'text/plain' ||
        book.mimeType == 'text/markdown') {
      return _PreparedRemoteFile(
        file: File(book.localPath),
        filename: book.fileName,
        mimeType: book.mimeType == 'text/markdown'
            ? 'text/plain'
            : book.mimeType,
      );
    }
    final extracted = await _extractor.extract(
      File(book.localPath),
      book.fileName,
      mimeType: book.mimeType,
      sizeBytes: book.byteSize,
    );
    if ((extracted ?? '').trim().isEmpty) {
      throw StateError('Claude远端书库需要PDF或可提取的文本格式。');
    }
    final directory = await Directory.systemTemp.createTemp('zhixing_claude_');
    final file = File('${directory.path}${Platform.pathSeparator}${book.fileName}.txt');
    await file.writeAsString(extracted!);
    return _PreparedRemoteFile(
      file: file,
      filename: '${book.title}.txt',
      mimeType: 'text/plain',
      temporary: true,
    );
  }

  Future<List<ZxRemoteKnowledgeItem>> _readyItems(
    List<int> bookIds,
    ZxRemoteKnowledgeProvider provider,
  ) async {
    if (bookIds.isEmpty) throw ArgumentError('没有可查询的著作。');
    final items = await _dao.remoteKnowledgeItems(
      provider: provider,
      bookIds: bookIds,
    );
    final byBook = <int, ZxRemoteKnowledgeItem>{
      for (final item in items) item.bookId: item,
    };
    final missing = bookIds
        .where((id) => byBook[id] == null || !byBook[id]!.isReady)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError('仍有${missing.length}本著作未在远端书库就绪；请先同步或等待索引完成。');
    }
    return bookIds.map((id) => byBook[id]!).toList(growable: false);
  }

  Future<ZxRemoteKnowledgeAnswer> _askOpenAiStore({
    required ZxRemoteKnowledgeConfig config,
    required List<ZxRemoteKnowledgeItem> items,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
  }) async {
    final stores = items
        .map((item) => item.remoteStoreId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final response = await _postJson(
      Uri.parse('${config.baseUrl}/responses'),
      _openAiHeaders(config),
      <String, Object?>{
        'model': config.model,
        'input': <Object?>[
          <String, Object?>{
            'role': 'system',
            'content': <Object?>[
              <String, Object?>{'type': 'input_text', 'text': systemPrompt},
            ],
          },
          <String, Object?>{
            'role': 'user',
            'content': <Object?>[
              <String, Object?>{'type': 'input_text', 'text': userPrompt},
            ],
          },
        ],
        'tools': <Object?>[
          <String, Object?>{
            'type': 'file_search',
            'vector_store_ids': stores,
          },
        ],
        'max_output_tokens': maxTokens,
      },
      operation: '基于远端书库回答',
    );
    return ZxRemoteKnowledgeAnswer(
      text: _responseText(response),
      provider: config.provider,
      modelLabel: config.label,
    );
  }

  Future<ZxRemoteKnowledgeAnswer> _askXGrokFiles({
    required ZxRemoteKnowledgeConfig config,
    required List<ZxRemoteKnowledgeItem> items,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
  }) async {
    return _askResponseFileIds(
      config: config,
      items: items,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
      operation: '基于 Grok 远端书库回答',
    );
  }

  Future<ZxRemoteKnowledgeAnswer> _askResponseFileIds({
    required ZxRemoteKnowledgeConfig config,
    required List<ZxRemoteKnowledgeItem> items,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required String operation,
  }) async {
    final content = <Object?>[
      <String, Object?>{
        'type': 'input_text',
        'text': '$systemPrompt\n\n$userPrompt',
      },
      ...items.map(
        (item) => <String, Object?>{
          'type': 'input_file',
          'file_id': item.remoteFileId,
        },
      ),
    ];
    final response = await _postJson(
      Uri.parse('${config.baseUrl}/responses'),
      _bearer(config.apiKey),
      <String, Object?>{
        'model': config.model,
        'input': <Object?>[
          <String, Object?>{'role': 'user', 'content': content},
        ],
        'max_output_tokens': maxTokens,
      },
      operation: operation,
    );
    return ZxRemoteKnowledgeAnswer(
      text: _responseText(response),
      provider: config.provider,
      modelLabel: config.label,
    );
  }

  Future<ZxRemoteKnowledgeAnswer> _askEdenFiles({
    required ZxRemoteKnowledgeConfig config,
    required List<ZxRemoteKnowledgeItem> items,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
  }) async {
    final response = await _postJson(
      Uri.parse('${config.baseUrl}/chat/completions'),
      _bearer(config.apiKey),
      <String, Object?>{
        'model': config.model,
        'messages': <Object?>[
          <String, Object?>{'role': 'system', 'content': systemPrompt},
          <String, Object?>{
            'role': 'user',
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': userPrompt},
              ...items.map(
                (item) => <String, Object?>{
                  'type': 'file',
                  'file': <String, Object?>{'file_id': item.remoteFileId},
                },
              ),
            ],
          },
        ],
        'max_tokens': maxTokens,
      },
      operation: '基于 Eden AI 临时文件 ID 回答',
    );
    return ZxRemoteKnowledgeAnswer(
      text: _chatText(response),
      provider: config.provider,
      modelLabel: config.label,
    );
  }

  Future<ZxRemoteKnowledgeAnswer> _askGeminiStore({
    required ZxRemoteKnowledgeConfig config,
    required List<ZxRemoteKnowledgeItem> items,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final stores = items
        .map((item) => item.remoteStoreId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final response = await _postJson(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
      <String, String>{'x-goog-api-key': config.apiKey},
      <String, Object?>{
        'model': config.model,
        'input': <Object?>[
          <String, Object?>{
            'type': 'text',
            'text': '$systemPrompt\n\n$userPrompt',
          },
        ],
        'tools': <Object?>[
          <String, Object?>{
            'type': 'file_search',
            'file_search_store_names': stores,
          },
        ],
      },
      operation: '基于 Gemini File Search 回答',
    );
    final text = _geminiText(response);
    if (text.isEmpty) throw const FormatException('Gemini没有返回可读答案。');
    return ZxRemoteKnowledgeAnswer(
      text: text,
      provider: config.provider,
      modelLabel: config.label,
    );
  }

  Future<ZxRemoteKnowledgeAnswer> _askClaudeFiles({
    required ZxRemoteKnowledgeConfig config,
    required List<ZxRemoteKnowledgeItem> items,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
  }) async {
    final response = await _postJson(
      Uri.parse('${config.baseUrl}/messages'),
      _claudeHeaders(config.apiKey),
      <String, Object?>{
        'model': config.model,
        'max_tokens': maxTokens,
        'system': systemPrompt,
        'messages': <Object?>[
          <String, Object?>{
            'role': 'user',
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': userPrompt},
              ...items.map(
                (item) => <String, Object?>{
                  'type': 'document',
                  'source': <String, Object?>{
                    'type': 'file',
                    'file_id': item.remoteFileId,
                  },
                  'citations': <String, Object?>{'enabled': true},
                },
              ),
            ],
          },
        ],
      },
      operation: '基于 Claude 远端书库回答',
    );
    final text = _claudeText(response);
    if (text.isEmpty) throw const FormatException('Claude没有返回可读答案。');
    return ZxRemoteKnowledgeAnswer(
      text: text,
      provider: config.provider,
      modelLabel: config.label,
    );
  }

  Future<Map<String, dynamic>> _uploadMultipart(
    Uri uri,
    Map<String, String> headers, {
    required File file,
    required String filename,
    required String mimeType,
    Map<String, String> fields = const <String, String>{},
  }) async {
    if (!await file.exists()) throw ArgumentError('本机著作文件不存在。');
    final request = http.MultipartRequest('POST', uri)..headers.addAll(headers);
    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
      ),
    );
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _jsonObject(response, operation: '上传著作到AI服务商');
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body, {
    required String operation,
  }) async {
    final response = await _client
        .post(
          uri,
          headers: <String, String>{
            ...headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _jsonObject(response, operation: operation);
  }

  Future<void> _deleteIgnoringNotFound(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final response = await _client.delete(uri, headers: headers).timeout(_timeout);
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('删除远端副本失败（HTTP ${response.statusCode}）。');
    }
  }

  static Map<String, String> _bearer(String key) => <String, String>{
        'Authorization': 'Bearer ${key.trim()}',
      };

  static Map<String, String> _openAiHeaders(
    ZxRemoteKnowledgeConfig config,
  ) =>
      config.provider == ZxRemoteKnowledgeProvider.azureOpenAi
          ? <String, String>{'api-key': config.apiKey.trim()}
          : _bearer(config.apiKey);

  static Map<String, String> _claudeHeaders(String key) => <String, String>{
        'x-api-key': key.trim(),
        'anthropic-version': _anthropicVersion,
        'anthropic-beta': _anthropicFilesBeta,
      };

  static void _ensureConfigured(ZxRemoteKnowledgeConfig config) {
    if (config.apiKey.trim().isEmpty) {
      throw StateError('${config.provider.label}尚未配置可用密钥。');
    }
    if (config.model.trim().isEmpty) {
      throw StateError('${config.provider.label}尚未配置模型。');
    }
    if ((config.provider == ZxRemoteKnowledgeProvider.openAiCompatible ||
            config.provider == ZxRemoteKnowledgeProvider.azureOpenAi) &&
        config.baseUrl.trim().isEmpty) {
      throw StateError('请填写服务商的 API 基地址。');
    }
    if (config.provider == ZxRemoteKnowledgeProvider.openRouter &&
        config.fileApiKey.trim().isEmpty) {
      throw StateError('请配置 OpenRouter Management Key；普通推理 Key 不能管理工作区文件。');
    }
  }

  static Map<String, dynamic> _jsonObject(
    http.Response response, {
    required String operation,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$operation失败（HTTP ${response.statusCode}）。');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw FormatException('$operation没有返回有效JSON。');
  }

  static String _responseText(Map<String, dynamic> response) {
    final direct = (response['output_text'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final output = response['output'];
    if (output is List) {
      final parts = <String>[];
      for (final item in output) {
        if (item is! Map) continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final block in content) {
          if (block is! Map) continue;
          final text = (block['text'] ?? block['output_text'] ?? '')
              .toString()
              .trim();
          if (text.isNotEmpty) parts.add(text);
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
    throw const FormatException('服务商没有返回可读答案。');
  }

  static String _chatText(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final message = (choices.first as Map)['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String && content.trim().isNotEmpty) {
          return content.trim();
        }
        if (content is List) {
          final parts = content
              .whereType<Map>()
              .map((part) => (part['text'] ?? '').toString().trim())
              .where((text) => text.isNotEmpty)
              .toList(growable: false);
          if (parts.isNotEmpty) return parts.join('\n');
        }
      }
    }
    throw const FormatException('中转服务商没有返回可读答案。');
  }

  static String _geminiText(Map<String, dynamic> response) {
    final direct = (response['output_text'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final steps = response['steps'];
    if (steps is! List) return '';
    final chunks = <String>[];
    for (final step in steps) {
      if (step is! Map || step['type'] != 'model_output') continue;
      final content = step['content'];
      if (content is! List) continue;
      for (final block in content) {
        if (block is! Map) continue;
        final text = (block['text'] ?? '').toString().trim();
        if (text.isNotEmpty) chunks.add(text);
      }
    }
    return chunks.join('\n');
  }

  static String _claudeText(Map<String, dynamic> response) {
    final content = response['content'];
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .map((item) => (item['text'] ?? '').toString().trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  static String _geminiDocumentId(Map<String, dynamic> operation) {
    final response = operation['response'];
    if (response is Map) {
      for (final key in const <String>[
        'document',
        'fileSearchDocument',
        'file_search_document',
      ]) {
        final document = response[key];
        if (document is Map) {
          final id = (document['name'] ?? '').toString().trim();
          if (id.isNotEmpty) return id;
        }
      }
      final direct = (response['name'] ?? '').toString().trim();
      if (direct.startsWith('fileSearchStores/')) return direct;
    }
    for (final key in const <String>[
      'document',
      'fileSearchDocument',
      'file_search_document',
    ]) {
      final document = operation[key];
      if (document is Map) {
        final id = (document['name'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
    }
    return '';
  }

  static String _safeError(Object error) {
    final raw = error.toString();
    // Provider responses and accidental request diagnostics can contain too
    // much information. Keep only a compact user-visible reason.
    return raw.length <= 180 ? raw : '${raw.substring(0, 177)}...';
  }
}

class _PreparedRemoteFile {
  const _PreparedRemoteFile({
    required this.file,
    required this.filename,
    required this.mimeType,
    this.temporary = false,
  });

  final File file;
  final String filename;
  final String mimeType;
  final bool temporary;
}
