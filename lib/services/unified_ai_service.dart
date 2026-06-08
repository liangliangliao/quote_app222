import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/dao.dart';
import '../utils/deepseek_logger.dart';
import 'global_ai_settings.dart';
import 'global_ai_request_settings.dart';

class UnifiedAiResolvedConfig {
  final String provider;
  final String apiKey;
  final String model;
  final String endpoint;
  final String label;
  final String displayModel;
  final bool available;

  const UnifiedAiResolvedConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    required this.endpoint,
    required this.label,
    required this.displayModel,
    required this.available,
  });
}

class UnifiedAiContentPart {
  final String type;
  final String? text;
  final String? imageUrl;
  final String? fileName;
  final String? fileData;
  final String? fileId;
  final String? mimeType;

  const UnifiedAiContentPart._({
    required this.type,
    this.text,
    this.imageUrl,
    this.fileName,
    this.fileData,
    this.fileId,
    this.mimeType,
  });

  const UnifiedAiContentPart.text(String value) : this._(type: 'text', text: value);
  const UnifiedAiContentPart.imageUrl(String value) : this._(type: 'image_url', imageUrl: value);
  const UnifiedAiContentPart.fileData({required String filename, required String dataUrl, String? mimeType})
      : this._(type: 'file', fileName: filename, fileData: dataUrl, mimeType: mimeType);
  const UnifiedAiContentPart.fileId({required String fileId, String? filename, String? mimeType})
      : this._(type: 'file', fileId: fileId, fileName: filename, mimeType: mimeType);

  bool get isImage => type == 'image_url';
  bool get isFile => type == 'file';

  Map<String, dynamic> toChatJson() {
    if (type == 'image_url') {
      return <String, dynamic>{
        'type': 'image_url',
        'image_url': <String, dynamic>{'url': imageUrl ?? ''},
      };
    }
    if (type == 'file') {
      final file = <String, dynamic>{};
      if ((fileId ?? '').trim().isNotEmpty) file['file_id'] = fileId!.trim();
      if ((fileName ?? '').trim().isNotEmpty) file['filename'] = fileName!.trim();
      if ((fileData ?? '').trim().isNotEmpty) file['file_data'] = fileData!.trim();
      if ((mimeType ?? '').trim().isNotEmpty) file['mime_type'] = mimeType!.trim();
      return <String, dynamic>{'type': 'file', 'file': file};
    }
    return <String, dynamic>{'type': 'text', 'text': text ?? ''};
  }

  Map<String, dynamic> toResponsesJson() {
    if (type == 'image_url') {
      return <String, dynamic>{'type': 'input_image', 'image_url': imageUrl ?? ''};
    }
    if (type == 'file') {
      final file = <String, dynamic>{'type': 'input_file'};
      if ((fileId ?? '').trim().isNotEmpty) file['file_id'] = fileId!.trim();
      if ((fileName ?? '').trim().isNotEmpty) file['filename'] = fileName!.trim();
      if ((fileData ?? '').trim().isNotEmpty) file['file_data'] = fileData!.trim();
      return file;
    }
    return <String, dynamic>{'type': 'input_text', 'text': text ?? ''};
  }

  String toPlainText() {
    if (type == 'image_url') return '[图片附件]';
    if (type == 'file') return '[文件附件：${fileName ?? fileId ?? 'file'}]';
    return text ?? '';
  }
}

class UnifiedAiChatMessage {
  final String role;
  final String content;
  final List<UnifiedAiContentPart> parts;

  const UnifiedAiChatMessage({
    required this.role,
    required this.content,
    this.parts = const <UnifiedAiContentPart>[],
  });

  bool get hasParts => parts.isNotEmpty;

  Map<String, dynamic> toJson({
    bool supportsVision = false,
    bool supportsFiles = false,
    bool openAiResponses = false,
  }) {
    final allowedParts = parts.where((p) {
      if (p.isImage) return supportsVision;
      if (p.isFile) return supportsFiles;
      return true;
    }).toList();
    if (allowedParts.isNotEmpty) {
      final contentParts = <Map<String, dynamic>>[];
      if (content.trim().isNotEmpty) {
        contentParts.add(openAiResponses
            ? <String, dynamic>{'type': 'input_text', 'text': content.trim()}
            : <String, dynamic>{'type': 'text', 'text': content.trim()});
      }
      contentParts.addAll(allowedParts.map((e) => openAiResponses ? e.toResponsesJson() : e.toChatJson()));
      return <String, dynamic>{'role': role, 'content': contentParts};
    }
    final fallback = StringBuffer(content.trim());
    if (parts.isNotEmpty) {
      if (fallback.isNotEmpty) fallback.writeln();
      for (final part in parts) {
        final text = part.toPlainText().trim();
        if (text.isNotEmpty) fallback.writeln(text);
      }
    }
    return <String, dynamic>{'role': role, 'content': fallback.toString().trim()};
  }
}

class UnifiedAiService {
  UnifiedAiService();

  final ConfigDao _configDao = ConfigDao();
  final GlobalAiSettings _settings = GlobalAiSettings();
  final GlobalAiRequestSettings _requestSettings = GlobalAiRequestSettings();

  static const String openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const String openRouterModelsEndpoint = 'https://openrouter.ai/api/v1/models';
  static const String deepSeekEndpoint = 'https://api.deepseek.com/chat/completions';
  static const String deepSeekModelsEndpoint = 'https://api.deepseek.com/models';
  static const String openAiModelsEndpoint = 'https://api.openai.com/v1/models';
  static const String openAiResponsesEndpoint = 'https://api.openai.com/v1/responses';
  static const String edenAiChatCompletionsEndpoint = 'https://api.edenai.run/v3/chat/completions';
  static const String edenAiModelsEndpoint = 'https://api.edenai.run/v3/models';

  Future<UnifiedAiResolvedConfig> resolveGlobalConfig({String? forcedProvider, String? forcedModel}) async {
    final global = await _configDao.getOne();
    final state = forcedProvider == null && forcedModel == null
        ? await _settings.getState()
        : <String, String>{
            'provider': (forcedProvider ?? 'deepseek').trim().toLowerCase(),
            'model': (forcedModel ?? '').trim(),
          };

    final provider = _normalizeProvider(state['provider']);
    final openAiKey = (global['api_key'] ?? '').toString().trim();
    final openAiModel = ((forcedProvider == 'openai' ? forcedModel : null) ?? state['openai_model'] ?? state['model'] ?? (global['model'] ?? 'gpt-5').toString()).trim();
    final openAiEndpoint = (global['endpoint'] ?? openAiResponsesEndpoint).toString().trim().isEmpty
        ? openAiResponsesEndpoint
        : (global['endpoint'] ?? openAiResponsesEndpoint).toString().trim();

    final deepSeekKey = (await _configDao.getDeepseekKey()).trim();
    final deepSeekModel = ((forcedProvider == 'deepseek' ? forcedModel : null) ?? state['deepseek_model'] ?? state['model'] ?? await _configDao.getDeepseekModel()).trim();

    final openRouterKey = (await _configDao.getOpenRouterKey()).trim();
    final openRouterModel = ((forcedProvider == 'openrouter' ? forcedModel : null) ?? state['openrouter_model'] ?? state['model'] ?? '').trim();

    final edenAiKey = await _settings.getEdenAiKey();
    final edenAiModel = ((forcedProvider == 'edenai' ? forcedModel : null) ?? state['edenai_model'] ?? state['model'] ?? GlobalAiSettings.edenAiDefaultModel).trim();

    switch (provider) {
      case 'openai':
        final model = openAiModel.isEmpty ? 'gpt-5' : openAiModel;
        return UnifiedAiResolvedConfig(
          provider: 'openai',
          apiKey: openAiKey,
          model: model,
          endpoint: openAiEndpoint,
          label: 'OpenAI · $model',
          displayModel: model,
          available: openAiKey.isNotEmpty,
        );
      case 'openrouter':
        final model = openRouterModel.isEmpty ? 'openai/gpt-4.1-mini' : openRouterModel;
        return UnifiedAiResolvedConfig(
          provider: 'openrouter',
          apiKey: openRouterKey,
          model: model,
          endpoint: openRouterEndpoint,
          label: 'OpenRouter · $model',
          displayModel: 'openrouter / $model',
          available: openRouterKey.isNotEmpty,
        );
      case 'edenai':
        final model = edenAiModel.isEmpty ? GlobalAiSettings.edenAiDefaultModel : edenAiModel;
        return UnifiedAiResolvedConfig(
          provider: 'edenai',
          apiKey: edenAiKey,
          model: model,
          endpoint: edenAiChatCompletionsEndpoint,
          label: 'Eden AI · $model',
          displayModel: model,
          available: edenAiKey.isNotEmpty,
        );
      case 'deepseek':
      default:
        var model = deepSeekModel;
        if (model.isEmpty) model = 'deepseek-reasoner';
        return UnifiedAiResolvedConfig(
          provider: 'deepseek',
          apiKey: deepSeekKey,
          model: model,
          endpoint: deepSeekEndpoint,
          label: 'DeepSeek · $model',
          displayModel: model,
          available: deepSeekKey.isNotEmpty,
        );
    }
  }

  Future<List<String>> fetchAvailableModels(String provider) async {
    final cfg = await resolveGlobalConfig(forcedProvider: provider);
    final requestCfg = await _requestSettings.getConfig();
    if (!cfg.available) return <String>[];
    final normalized = _normalizeProvider(provider);
    final uri = Uri.parse(
      normalized == 'openrouter'
          ? openRouterModelsEndpoint
          : normalized == 'edenai'
              ? edenAiModelsEndpoint
              : normalized == 'openai'
                  ? openAiModelsEndpoint
                  : deepSeekModelsEndpoint,
    );
    final headers = <String, String>{
      'Authorization': 'Bearer ${cfg.apiKey}',
      if (normalized == 'edenai') 'Accept': 'application/json',
      if (normalized == 'edenai') 'Connection': 'close',
      if (normalized == 'openrouter') 'X-OpenRouter-Title': 'Quote App',
    };
    final module = 'settings.global_models.$normalized';
    try {
      await DeepSeekLogger.logRequest(
        provider: _providerLabel(normalized),
        module: module,
        endpoint: uri.toString(),
        headers: headers,
        body: const <String, dynamic>{'action': 'list_models'},
        method: 'GET',
        model: 'models/list',
      );
      final resp = await http.get(uri, headers: headers).timeout(requestCfg.resolveTimeout(const Duration(seconds: 20)));
      await DeepSeekLogger.logResponse(
        provider: _providerLabel(normalized),
        module: module,
        endpoint: uri.toString(),
        statusCode: resp.statusCode,
        body: resp.body,
        model: 'models/list',
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) return <String>[];
      final decoded = jsonDecode(resp.body);
      final list = _extractModelList(decoded);
      if (list.isEmpty) return <String>[];
      final uniq = <String>[];
      final seen = <String>{};
      if (normalized == 'edenai') {
        // Eden AI supports smart routing with @edenai; expose it as a safe
        // debugging option even when it is not returned by the model list.
        seen.add('@edenai');
        uniq.add('@edenai');
      }
      for (final item in list) {
        if (seen.add(item)) uniq.add(item);
      }
      final smartRouter = normalized == 'edenai' && uniq.isNotEmpty && uniq.first == '@edenai';
      final rest = smartRouter ? uniq.skip(1).toList() : List<String>.from(uniq);
      rest.sort();
      return smartRouter ? <String>['@edenai', ...rest] : rest;
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: _providerLabel(normalized),
        module: module,
        endpoint: uri.toString(),
        error: e,
        stackTrace: st,
        model: 'models/list',
      );
      return <String>[];
    }
  }

  Future<String> generateText({
    required String prompt,
    required String purpose,
    String? systemPrompt,
    int maxTokens = 1800,
    bool expectJson = false,
    String? forcedProvider,
    String? forcedModel,
    double? temperature,
  }) async {
    final cfg = await resolveGlobalConfig(forcedProvider: forcedProvider, forcedModel: forcedModel);
    final requestCfg = await _requestSettings.getConfig();
    final effectiveMaxTokens = requestCfg.resolveMaxTokens(maxTokens);
    final effectiveTemperature = requestCfg.resolveTemperature(temperature);
    final effectiveTopP = requestCfg.resolveTopP();
    var effectiveTimeout = requestCfg.resolveTimeout(const Duration(seconds: 90));
    var effectiveRetryCount = requestCfg.resolveRetryCount();
    var effectiveRetryDelayMs = requestCfg.resolveRetryDelayMs();
    // Movie episode generation calls many small JSON tasks. OpenRouter may
    // return temporary upstream 429 for a selected provider even when the
    // OpenRouter key itself is valid. Give this task a small local retry budget
    // and longer delay so a transient upstream limit does not immediately fail
    // the whole movie episode workflow.
    if (cfg.provider == 'openrouter' && purpose.contains('movie_role_lab.episode_script')) {
      if (effectiveRetryCount < 2) effectiveRetryCount = 2;
      if (effectiveRetryDelayMs < 8000) effectiveRetryDelayMs = 8000;
    }
    // Streaming lets the server return response headers as soon as generation
    // starts instead of waiting for a complete long response. This reduces the
    // chance of `Connection closed before full header was received` on slow
    // models. It does not increase token cost by itself. Retries still stay
    // fully user-controlled: leaving the retry count empty or 0 sends only one
    // request, which avoids duplicate billing on paid gateways.
    if ((cfg.provider == 'edenai' ||
            cfg.provider == 'openai' ||
            cfg.provider == 'openrouter' ||
            cfg.provider == 'deepseek') &&
        effectiveTimeout < const Duration(seconds: 120)) {
      effectiveTimeout = const Duration(seconds: 120);
    }
    if (!cfg.available) return '';
    switch (cfg.provider) {
      case 'openai':
        return _callOpenAi(
          endpoint: cfg.endpoint,
          apiKey: cfg.apiKey,
          model: cfg.model,
          prompt: prompt,
          purpose: purpose,
          systemPrompt: systemPrompt,
          maxTokens: effectiveMaxTokens,
          expectJson: expectJson,
          temperature: effectiveTemperature,
          topP: effectiveTopP,
          timeout: effectiveTimeout,
          retryCount: effectiveRetryCount,
          retryDelayMs: effectiveRetryDelayMs,
        );
      case 'openrouter':
        return _callChatProvider(
          provider: 'openrouter',
          endpoint: cfg.endpoint,
          apiKey: cfg.apiKey,
          model: cfg.model,
          prompt: prompt,
          purpose: purpose,
          systemPrompt: systemPrompt,
          maxTokens: effectiveMaxTokens,
          expectJson: expectJson,
          temperature: effectiveTemperature,
          topP: effectiveTopP,
          timeout: effectiveTimeout,
          retryCount: effectiveRetryCount,
          retryDelayMs: effectiveRetryDelayMs,
        );
      case 'edenai':
        return _callChatProvider(
          provider: 'edenai',
          endpoint: cfg.endpoint,
          apiKey: cfg.apiKey,
          model: cfg.model,
          prompt: prompt,
          purpose: purpose,
          systemPrompt: systemPrompt,
          maxTokens: effectiveMaxTokens,
          expectJson: expectJson,
          temperature: effectiveTemperature,
          topP: effectiveTopP,
          timeout: effectiveTimeout,
          retryCount: effectiveRetryCount,
          retryDelayMs: effectiveRetryDelayMs,
        );
      case 'deepseek':
      default:
        return _callChatProvider(
          provider: 'deepseek',
          endpoint: cfg.endpoint,
          apiKey: cfg.apiKey,
          model: cfg.model,
          prompt: prompt,
          purpose: purpose,
          systemPrompt: systemPrompt,
          maxTokens: effectiveMaxTokens,
          expectJson: expectJson,
          temperature: effectiveTemperature,
          topP: effectiveTopP,
          timeout: effectiveTimeout,
          retryCount: effectiveRetryCount,
          retryDelayMs: effectiveRetryDelayMs,
        );
    }
  }

  Future<String> generateChatMessages({
    required List<UnifiedAiChatMessage> messages,
    String purpose = 'ai_assistant.chat',
    int maxTokens = 2200,
    String? forcedProvider,
    String? forcedModel,
    double? temperature,
  }) async {
    final cleaned = <UnifiedAiChatMessage>[];
    for (final message in messages) {
      final role = message.role.trim().toLowerCase();
      final content = message.content.trim();
      final hasParts = message.parts.isNotEmpty;
      if (content.isEmpty && !hasParts) continue;
      if (role == 'user' || role == 'assistant' || role == 'system') {
        cleaned.add(UnifiedAiChatMessage(role: role, content: content, parts: message.parts));
      }
    }
    if (cleaned.isEmpty) return '';

    final cfg = await resolveGlobalConfig(forcedProvider: forcedProvider, forcedModel: forcedModel);
    if (!cfg.available) return '';
    final requestCfg = await _requestSettings.getConfig();
    final effectiveMaxTokens = requestCfg.resolveMaxTokens(maxTokens);
    final effectiveTemperature = requestCfg.resolveTemperature(temperature);
    final effectiveTopP = requestCfg.resolveTopP();
    final effectiveTimeout = requestCfg.resolveTimeout(const Duration(seconds: 120));
    final effectiveRetryCount = requestCfg.resolveRetryCount();
    final effectiveRetryDelayMs = requestCfg.resolveRetryDelayMs();

    switch (cfg.provider) {
      case 'openai':
        return _callOpenAiMessages(
          endpoint: cfg.endpoint,
          apiKey: cfg.apiKey,
          model: cfg.model,
          messages: cleaned,
          purpose: purpose,
          maxTokens: effectiveMaxTokens,
          temperature: effectiveTemperature,
          topP: effectiveTopP,
          timeout: effectiveTimeout,
          retryCount: effectiveRetryCount,
          retryDelayMs: effectiveRetryDelayMs,
        );
      case 'openrouter':
      case 'edenai':
      case 'deepseek':
      default:
        return _callChatProviderMessages(
          provider: cfg.provider,
          endpoint: cfg.endpoint,
          apiKey: cfg.apiKey,
          model: cfg.model,
          messages: cleaned,
          purpose: purpose,
          maxTokens: effectiveMaxTokens,
          temperature: effectiveTemperature,
          topP: effectiveTopP,
          timeout: effectiveTimeout,
          retryCount: effectiveRetryCount,
          retryDelayMs: effectiveRetryDelayMs,
        );
    }
  }

  Future<String> _callOpenAiMessages({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<UnifiedAiChatMessage> messages,
    required String purpose,
    required int maxTokens,
    double? temperature,
    double? topP,
    required Duration timeout,
    required int retryCount,
    required int retryDelayMs,
  }) async {
    final uri = Uri.parse(endpoint.isEmpty ? openAiResponsesEndpoint : endpoint);
    final isChat = uri.path.endsWith('/chat/completions');
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close',
    };
    final body = isChat
        ? <String, dynamic>{
            'model': model,
            'messages': messages.map((e) => e.toJson(supportsVision: true, supportsFiles: true, openAiResponses: false)).toList(),
            'max_tokens': maxTokens,
            if (temperature != null) 'temperature': temperature,
            if (topP != null) 'top_p': topP,
            'stream': false,
          }
        : <String, dynamic>{
            'model': model,
            'input': messages.map((e) => e.toJson(supportsVision: true, supportsFiles: true, openAiResponses: true)).toList(),
            'max_output_tokens': maxTokens,
            if (temperature != null) 'temperature': temperature,
            if (topP != null) 'top_p': topP,
            'stream': false,
          };
    return _postForText(
      provider: 'openai',
      endpoint: uri.toString(),
      headers: headers,
      body: body,
      purpose: purpose,
      model: model,
      timeout: timeout,
      retryCount: retryCount,
      retryDelayMs: retryDelayMs,
    );
  }

  Future<String> _callChatProviderMessages({
    required String provider,
    required String endpoint,
    required String apiKey,
    required String model,
    required List<UnifiedAiChatMessage> messages,
    required String purpose,
    required int maxTokens,
    double? temperature,
    double? topP,
    required Duration timeout,
    required int retryCount,
    required int retryDelayMs,
  }) async {
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close',
      if (provider == 'openrouter') 'X-OpenRouter-Title': 'Quote App',
    };
    final hasFileParts = messages.any((message) => message.parts.any((part) => part.isFile));
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map((e) => e.toJson(
        supportsVision: _supportsVisionInput(provider, model),
        supportsFiles: _supportsFileInput(provider, model),
      )).toList(),
      'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (provider == 'openrouter' && hasFileParts)
        'plugins': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'file-parser',
            'pdf': <String, dynamic>{'engine': 'cloudflare-ai'},
          },
        ],
      'stream': false,
    };
    return _postForText(
      provider: provider,
      endpoint: endpoint,
      headers: headers,
      body: body,
      purpose: purpose,
      model: model,
      timeout: timeout,
      retryCount: retryCount,
      retryDelayMs: retryDelayMs,
    );
  }

  Future<String> _callOpenAi({
    required String endpoint,
    required String apiKey,
    required String model,
    required String prompt,
    required String purpose,
    String? systemPrompt,
    required int maxTokens,
    required bool expectJson,
    double? temperature,
    double? topP,
    required Duration timeout,
    required int retryCount,
    required int retryDelayMs,
  }) async {
    final uri = Uri.parse(endpoint.isEmpty ? openAiResponsesEndpoint : endpoint);
    // JSON tasks are intentionally non-streaming. Several reasoning models
    // stream long `reasoning_content` chunks before final `content`; if the
    // generation is truncated, downstream parsers see no valid JSON even though
    // HTTP succeeds. Non-streaming requests return a single final body that is
    // much safer for strict jsonDecode-based tasks.
    final stream = !expectJson;
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
      'Connection': 'close',
    };
    final isChat = uri.path.endsWith('/chat/completions');
    final body = isChat
        ? <String, dynamic>{
            'model': model,
            'messages': <Map<String, String>>[
              if ((systemPrompt ?? '').trim().isNotEmpty) <String, String>{'role': 'system', 'content': systemPrompt!.trim()},
              <String, String>{'role': 'user', 'content': prompt},
            ],
            'max_tokens': maxTokens,
            if (temperature != null) 'temperature': temperature,
            if (topP != null) 'top_p': topP,
            if (expectJson) 'response_format': <String, dynamic>{'type': 'json_object'},
            'stream': stream,
          }
        : <String, dynamic>{
            'model': model,
            'input': <Map<String, String>>[
              if ((systemPrompt ?? '').trim().isNotEmpty) <String, String>{'role': 'system', 'content': systemPrompt!.trim()},
              <String, String>{'role': 'user', 'content': prompt},
            ],
            'max_output_tokens': maxTokens,
            if (temperature != null) 'temperature': temperature,
            if (topP != null) 'top_p': topP,
            if (expectJson)
              'text': <String, dynamic>{
                'format': <String, dynamic>{'type': 'json_object'},
              },
            'stream': stream,
          };
    return _postForText(
      provider: 'openai',
      endpoint: uri.toString(),
      headers: headers,
      body: body,
      purpose: purpose,
      model: model,
      timeout: timeout,
      retryCount: retryCount,
      retryDelayMs: retryDelayMs,
    );
  }

  Future<String> _callChatProvider({
    required String provider,
    required String endpoint,
    required String apiKey,
    required String model,
    required String prompt,
    required String purpose,
    String? systemPrompt,
    required int maxTokens,
    required bool expectJson,
    double? temperature,
    double? topP,
    required Duration timeout,
    required int retryCount,
    required int retryDelayMs,
  }) async {
    // JSON tasks are intentionally non-streaming. DeepSeek/OpenRouter
    // reasoning-compatible streams often emit `reasoning_content` with
    // `delta.content = null` for a long time. For tasks that must return a
    // parseable JSON object, prefer a single final response body.
    final stream = !expectJson;
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
      'Connection': 'close',
      if (provider == 'openrouter') 'X-OpenRouter-Title': 'Quote App',
    };
    final useResponseFormat = _shouldUseJsonResponseFormat(provider, model, expectJson);
    final body = <String, dynamic>{
      'model': model,
      'messages': <Map<String, String>>[
        if ((systemPrompt ?? '').trim().isNotEmpty) <String, String>{'role': 'system', 'content': systemPrompt!.trim()},
        <String, String>{'role': 'user', 'content': prompt},
      ],
      'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (useResponseFormat) 'response_format': <String, dynamic>{'type': 'json_object'},
      // OpenRouter 上的部分深度思考/推理模型会先输出很长的
      // reasoning_content，而最终 content 为空或超时。严格 JSON 任务
      // 不需要思考过程，因此尽量压低并排除推理流，避免“接口成功但正文为空”。
      if (provider == 'openrouter' && expectJson)
        'reasoning': <String, dynamic>{
          'effort': 'low',
          'exclude': true,
        },
      'stream': stream,
    };
    return _postForText(
      provider: provider,
      endpoint: endpoint,
      headers: headers,
      body: body,
      purpose: purpose,
      model: model,
      timeout: timeout,
      retryCount: retryCount,
      retryDelayMs: retryDelayMs,
    );
  }


  bool _supportsVisionInput(String provider, String model) {
    final p = _normalizeProvider(provider);
    final m = model.toLowerCase();
    if (p == 'deepseek') return false;
    if (p == 'openai') return _looksLikeVisionModel(m);
    if (p == 'openrouter') return _looksLikeVisionModel(m);
    if (p == 'edenai') return _looksLikeVisionModel(m) || m.contains('openai/') || m.contains('gpt-');
    return false;
  }

  bool _supportsFileInput(String provider, String model) {
    final p = _normalizeProvider(provider);
    if (p == 'deepseek') return false;
    if (p == 'openai') return true;
    if (p == 'openrouter') return true;
    if (p == 'edenai') return true;
    return false;
  }

  bool _looksLikeVisionModel(String model) {
    final m = model.trim().toLowerCase();
    if (m.isEmpty) return false;
    final negativeSignals = <String>['embedding', 'rerank', 'text-embedding'];
    if (negativeSignals.any(m.contains)) return false;
    final positiveSignals = <String>[
      'vision',
      '-vl',
      '/vl',
      'vl-',
      'qwen-vl',
      'qwen2-vl',
      'qwen2.5-vl',
      'qwen3-vl',
      'gpt-4o',
      'gpt-4.1',
      'gpt-5',
      'o4-mini',
      'gemini',
      'claude',
      'pixtral',
      'llava',
      'llama-3.2-11b-vision',
      'llama-3.2-90b-vision',
      'mistral-small-3.2',
      'grok-vision',
      'gemma-3',
      'molmo',
      'internvl',
      'kimi-vl',
      'reka',
      'omni',
      'multimodal',
    ];
    return positiveSignals.any(m.contains);
  }

  Future<String?> uploadEdenAiAssistantFile({
    required String apiKey,
    required File file,
    required String filename,
    String purpose = 'assistants',
  }) async {
    final uri = Uri.parse('https://api.edenai.run/v3/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['purpose'] = purpose
      ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: filename));
    await DeepSeekLogger.logRequest(
      provider: 'Eden AI',
      module: 'ai_assistant.attachment.edenai_upload',
      endpoint: uri.toString(),
      headers: <String, String>{'Authorization': 'Bearer ***REDACTED***'},
      body: <String, Object?>{'filename': filename, 'purpose': purpose, 'size_bytes': await file.length()},
      method: 'POST',
      model: 'file_upload',
    );
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final body = await streamed.stream.transform(utf8.decoder).join();
      await DeepSeekLogger.logResponse(
        provider: 'Eden AI',
        module: 'ai_assistant.attachment.edenai_upload',
        endpoint: uri.toString(),
        statusCode: streamed.statusCode,
        body: body,
        model: 'file_upload',
      );
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final id = (decoded['file_id'] ?? decoded['id'] ?? '').toString().trim();
        return id.isEmpty ? null : id;
      }
      return null;
    } catch (e, st) {
      await DeepSeekLogger.logError(
        provider: 'Eden AI',
        module: 'ai_assistant.attachment.edenai_upload',
        endpoint: uri.toString(),
        error: e,
        stackTrace: st,
        model: 'file_upload',
      );
      return null;
    }
  }

  bool _isRetryableStatusCode(int statusCode) {
    return statusCode == 408 || statusCode == 409 || statusCode == 429 || statusCode >= 500;
  }

  Duration _retryDelay({
    required int attempt,
    required int retryDelayMs,
    Map<String, String>? headers,
    int? statusCode,
  }) {
    final retryAfter = headers == null ? null : headers['retry-after'];
    final seconds = retryAfter == null ? null : int.tryParse(retryAfter.trim());
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds.clamp(1, 90).toInt());
    }
    final base = retryDelayMs <= 0 ? 800 : retryDelayMs;
    final multiplier = statusCode == 429 ? attempt + 2 : attempt + 1;
    final capped = (base * multiplier).clamp(800, statusCode == 429 ? 45000 : 20000).toInt();
    return Duration(milliseconds: capped);
  }

  Future<String> _postForText({
    required String provider,
    required String endpoint,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String purpose,
    required String model,
    required Duration timeout,
    required int retryCount,
    required int retryDelayMs,
  }) async {
    final module = 'unified_ai.$purpose';
    await DeepSeekLogger.logRequest(
      provider: _providerLabel(provider),
      module: module,
      endpoint: endpoint,
      headers: headers,
      body: body,
      model: model,
    );
    if (body['stream'] == true) {
      return _postStreamForText(
        provider: provider,
        endpoint: endpoint,
        headers: headers,
        body: body,
        purpose: purpose,
        model: model,
        timeout: timeout,
        retryCount: retryCount,
        retryDelayMs: retryDelayMs,
      );
    }
    Object? lastError;
    StackTrace? lastStack;
    final attempts = retryCount + 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final resp = await http.post(Uri.parse(endpoint), headers: headers, body: jsonEncode(body)).timeout(timeout);
        await DeepSeekLogger.logResponse(
          provider: _providerLabel(provider),
          module: module,
          endpoint: endpoint,
          statusCode: resp.statusCode,
          body: resp.body,
          model: model,
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final text = extractText(resp.body).trim();
          if (text.isNotEmpty) return text;
          lastError = Exception('HTTP ${resp.statusCode}: provider returned empty assistant content. Body: ${resp.body}');
          lastStack = StackTrace.current;
          if (attempt + 1 < attempts) {
            await Future<void>.delayed(_retryDelay(attempt: attempt, retryDelayMs: retryDelayMs, statusCode: resp.statusCode));
            continue;
          }
          break;
        }
        lastError = Exception('HTTP ${resp.statusCode}: ${resp.body}');
        lastStack = StackTrace.current;
        final retryable = _isRetryableStatusCode(resp.statusCode);
        if (retryable && attempt + 1 < attempts) {
          await Future<void>.delayed(_retryDelay(
            attempt: attempt,
            retryDelayMs: retryDelayMs,
            headers: resp.headers,
            statusCode: resp.statusCode,
          ));
          continue;
        }
        break;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(_retryDelay(attempt: attempt, retryDelayMs: retryDelayMs));
          continue;
        }
      }
    }
    final error = lastError ?? Exception('unknown unified ai error');
    await DeepSeekLogger.logError(
      provider: _providerLabel(provider),
      module: module,
      endpoint: endpoint,
      error: error,
      stackTrace: lastStack,
      model: model,
    );
    throw error;
  }

  Future<String> _postStreamForText({
    required String provider,
    required String endpoint,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String purpose,
    required String model,
    required Duration timeout,
    required int retryCount,
    required int retryDelayMs,
  }) async {
    final module = 'unified_ai.$purpose';
    Object? lastError;
    StackTrace? lastStack;
    final attempts = retryCount + 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final rawStream = StringBuffer();
      final textBuffer = StringBuffer();
      try {
        final request = http.Request('POST', Uri.parse(endpoint));
        request.headers.addAll(headers);
        request.body = jsonEncode(body);
        final streamed = await request.send().timeout(timeout);
        await for (final line in streamed.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(timeout)) {
          rawStream.writeln(line);
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.startsWith('data:')) {
            final payload = trimmed.substring(5).trim();
            if (payload.isEmpty || payload == '[DONE]') continue;
            final piece = extractText(payload);
            if (piece.isNotEmpty) textBuffer.write(piece);
          } else if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            final piece = extractText(trimmed);
            if (piece.isNotEmpty) textBuffer.write(piece);
          }
        }
        final rawBody = rawStream.toString();
        await DeepSeekLogger.logResponse(
          provider: _providerLabel(provider),
          module: module,
          endpoint: endpoint,
          statusCode: streamed.statusCode,
          body: rawBody,
          model: model,
        );
        if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
          final text = textBuffer.toString().trim();
          if (text.isNotEmpty) return text;
          // rawBody is an SSE transcript, not a single JSON response body.
          // Returning the raw `data:` lines makes downstream JSON parsing fail even
          // though the HTTP call itself succeeded. Extract only final assistant
          // content chunks; DeepSeek-compatible reasoning chunks use
          // `reasoning_content` and are not valid final answers.
          final sseText = extractFinalTextFromSseStream(rawBody).trim();
          if (sseText.isNotEmpty) return sseText;
          lastError = Exception('HTTP ${streamed.statusCode}: provider stream ended without final assistant content.');
          lastStack = StackTrace.current;
          if (attempt + 1 < attempts) {
            await Future<void>.delayed(_retryDelay(attempt: attempt, retryDelayMs: retryDelayMs, statusCode: streamed.statusCode));
            continue;
          }
          break;
        }
        lastError = Exception('HTTP ${streamed.statusCode}: $rawBody');
        lastStack = StackTrace.current;
        final retryable = _isRetryableStatusCode(streamed.statusCode);
        if (retryable && attempt + 1 < attempts) {
          await Future<void>.delayed(_retryDelay(
            attempt: attempt,
            retryDelayMs: retryDelayMs,
            statusCode: streamed.statusCode,
          ));
          continue;
        }
        break;
      } catch (e, st) {
        lastError = rawStream.isEmpty ? e : Exception('$e\nPartial stream:\n$rawStream');
        lastStack = st;
        final partialText = textBuffer.toString().trim();
        if (partialText.isNotEmpty) {
          await DeepSeekLogger.logError(
            provider: _providerLabel(provider),
            module: module,
            endpoint: endpoint,
            error: Exception('$e\nPartial stream text length: ${partialText.length}'),
            stackTrace: st,
            model: model,
          );
          return partialText;
        }
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(_retryDelay(attempt: attempt, retryDelayMs: retryDelayMs));
          continue;
        }
      }
    }
    final error = lastError ?? Exception('unknown unified ai streaming error');
    await DeepSeekLogger.logError(
      provider: _providerLabel(provider),
      module: module,
      endpoint: endpoint,
      error: error,
      stackTrace: lastStack,
      model: model,
    );
    throw error;
  }

  static String extractFinalTextFromSseStream(String rawStream) {
    final buffer = StringBuffer();
    for (final rawLine in const LineSplitter().convert(rawStream)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      String payload;
      if (line.startsWith('data:')) {
        payload = line.substring(5).trim();
      } else if (line.startsWith('{') || line.startsWith('[')) {
        payload = line;
      } else {
        continue;
      }
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final decoded = jsonDecode(payload);
        final piece = extractTextFromDecoded(decoded);
        if (piece.trim().isNotEmpty) buffer.write(piece);
      } catch (_) {
        // Ignore malformed/partial SSE lines. The raw stream is already logged.
      }
    }
    return buffer.toString();
  }

  static String extractText(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      return extractTextFromDecoded(decoded);
    } catch (_) {
      return rawBody;
    }
  }

  static String extractTextFromDecoded(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      // OpenAI Responses streaming sends small SSE payloads such as:
      // {"type":"response.output_text.delta", "delta":"..."}.
      final directDelta = decoded['delta'];
      if (directDelta is String && directDelta.isNotEmpty) return directDelta;
      final directOutputText = decoded['output_text'];
      if (directOutputText is String && directOutputText.trim().isNotEmpty) {
        return directOutputText.trim();
      }
      final response = decoded['response'];
      if (response is Map<String, dynamic>) {
        final responseText = extractTextFromDecoded(response);
        if (responseText.trim().isNotEmpty) return responseText.trim();
      }
      final output = decoded['output'];
      if (output is List) {
        for (final item in output) {
          if (item is Map && item['content'] is List) {
            for (final c in item['content'] as List) {
              if (c is Map) {
                final type = (c['type'] ?? '').toString();
                if (type == 'output_text' || type == 'text') {
                  final text = (c['text'] ?? '').toString();
                  if (text.trim().isNotEmpty) return text.trim();
                }
              }
            }
          }
        }
      }
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final delta = first['delta'];
          if (delta is Map) {
            final content = delta['content'];
            if (content is String && content.trim().isNotEmpty) return content;
            if (content is List) {
              final buffer = StringBuffer();
              for (final item in content) {
                if (item is Map) {
                  final text = (item['text'] ?? item['content'] ?? '').toString();
                  if (text.isNotEmpty) buffer.write(text);
                }
              }
              if (buffer.toString().trim().isNotEmpty) return buffer.toString();
            }
          }
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String && content.trim().isNotEmpty) return content.trim();
            if (content is List) {
              for (final item in content) {
                if (item is Map) {
                  final text = (item['text'] ?? item['content'] ?? '').toString();
                  if (text.trim().isNotEmpty) return text.trim();
                }
              }
            }
            // v55: some DeepSeek-compatible reasoning models may return the
            // useful text in reasoning_content while final content is empty.
            // For target conversion this is still better than silently falling
            // back to local templates; downstream parsers will validate/repair it.
            final reasoning = (message['reasoning_content'] ?? message['reasoningContent'] ?? message['reasoning'] ?? message['thinking'] ?? '').toString();
            if (reasoning.trim().isNotEmpty) return reasoning.trim();
          }
          final text = (first['text'] ?? first['reasoning_content'] ?? first['reasoningContent'] ?? '').toString();
          if (text.trim().isNotEmpty) return text.trim();
        }
      }
      final content = (decoded['content'] ?? '').toString();
      if (content.trim().isNotEmpty) return content.trim();
    }
    return '';
  }

  static bool _shouldUseJsonResponseFormat(String provider, String model, bool expectJson) {
    if (!expectJson) return false;
    final normalizedProvider = _normalizeProvider(provider);
    final normalizedModel = model.toLowerCase();
    if (normalizedProvider == 'openrouter' && normalizedModel.contains('gpt-oss')) {
      return false;
    }
    return true;
  }

  static List<String> _extractModelList(dynamic decoded) {
    List<dynamic>? list;
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) {
        list = decoded['data'] as List<dynamic>;
      } else if (decoded['models'] is List) {
        list = decoded['models'] as List<dynamic>;
      }
    } else if (decoded is List) {
      list = decoded;
    }
    final models = <String>[];
    if (list == null) return models;
    for (final item in list) {
      if (item is String) {
        final v = item.trim();
        if (v.isNotEmpty) models.add(v);
      } else if (item is Map<String, dynamic>) {
        final raw = item['id'] ?? item['slug'] ?? item['model'] ?? item['name'];
        final v = (raw ?? '').toString().trim();
        if (v.isNotEmpty) models.add(v);
      }
    }
    return models;
  }

  static String _normalizeProvider(String? provider) {
    final p = (provider ?? '').trim().toLowerCase();
    if (p == 'openai') return 'openai';
    if (p == 'openrouter') return 'openrouter';
    if (p == 'edenai') return 'edenai';
    return 'deepseek';
  }

  static String _providerLabel(String provider) {
    switch (_normalizeProvider(provider)) {
      case 'openai':
        return 'OpenAI';
      case 'openrouter':
        return 'OpenRouter';
      case 'edenai':
        return 'Eden AI';
      case 'deepseek':
      default:
        return 'DeepSeek';
    }
  }
}
