import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/unified_ai_service.dart';

class AiAssistantMediaCapabilities {
  const AiAssistantMediaCapabilities({
    required this.provider,
    required this.model,
    required this.speech,
    required this.image,
    required this.video,
    required this.speechReason,
    required this.imageReason,
    required this.videoReason,
  });

  const AiAssistantMediaCapabilities.unavailable({
    this.provider = '',
    this.model = '',
    this.speechReason = '当前模型不支持朗读',
    this.imageReason = '当前模型不支持图片生成',
    this.videoReason = '当前模型不支持视频生成',
  }) : speech = false,
       image = false,
       video = false;

  final String provider;
  final String model;
  final bool speech;
  final bool image;
  final bool video;
  final String speechReason;
  final String imageReason;
  final String videoReason;
}

class AiAssistantGeneratedMedia {
  const AiAssistantGeneratedMedia({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.provider,
    required this.model,
    this.remoteUrl,
  });

  final String path;
  final String name;
  final String mimeType;
  final String provider;
  final String model;
  final String? remoteUrl;
}

class AiAssistantMediaService {
  AiAssistantMediaService({UnifiedAiService? unifiedAiService})
    : _unifiedAi = unifiedAiService ?? UnifiedAiService();

  final UnifiedAiService _unifiedAi;

  static const _xaiImageModel = 'grok-imagine-image-2.0';
  static const _xaiVideoModel = 'grok-imagine-video-1.5';
  static const _edenSpeechModel = 'audio/tts/elevenlabs';
  static const _edenImageModel = 'image/generation/openai';
  static const _edenVideoModel = 'video/generation_async/replicate';

  Future<AiAssistantMediaCapabilities> resolveCapabilities([
    UnifiedAiResolvedConfig? resolved,
  ]) async {
    final cfg = resolved ?? await _unifiedAi.resolveGlobalConfig();
    if (!cfg.available || cfg.apiKey.trim().isEmpty) {
      return AiAssistantMediaCapabilities.unavailable(
        provider: cfg.provider,
        model: cfg.model,
        speechReason: '当前服务商尚未配置 API Key',
        imageReason: '当前服务商尚未配置 API Key',
        videoReason: '当前服务商尚未配置 API Key',
      );
    }
    if (cfg.provider == 'xgrok') {
      return AiAssistantMediaCapabilities(
        provider: cfg.provider,
        model: cfg.model,
        speech: true,
        image: true,
        video: true,
        speechReason: 'xAI TTS · eve',
        imageReason: 'xAI · $_xaiImageModel',
        videoReason: 'xAI · $_xaiVideoModel',
      );
    }
    if (cfg.provider == 'edenai') {
      return AiAssistantMediaCapabilities(
        provider: cfg.provider,
        model: cfg.model,
        speech: true,
        image: true,
        video: true,
        speechReason: 'Eden AI 中转 · $_edenSpeechModel',
        imageReason: 'Eden AI 中转 · $_edenImageModel',
        videoReason: 'Eden AI 中转 · $_edenVideoModel',
      );
    }
    if (cfg.provider == 'openrouter') {
      final results = await Future.wait<Set<String>>([
        _openRouterModelIds(
          cfg,
          Uri.parse(
            'https://openrouter.ai/api/v1/models?output_modalities=speech',
          ),
        ),
        _openRouterModelIds(
          cfg,
          Uri.parse('https://openrouter.ai/api/v1/images/models'),
        ),
        _openRouterModelIds(
          cfg,
          Uri.parse('https://openrouter.ai/api/v1/videos/models'),
        ),
      ]);
      final speech = results[0].contains(cfg.model);
      final image = results[1].contains(cfg.model);
      final video = results[2].contains(cfg.model);
      return AiAssistantMediaCapabilities(
        provider: cfg.provider,
        model: cfg.model,
        speech: speech,
        image: image,
        video: video,
        speechReason: speech
            ? 'OpenRouter · ${cfg.model}'
            : '当前 OpenRouter 模型未声明 speech 输出能力',
        imageReason: image
            ? 'OpenRouter · ${cfg.model}'
            : '当前 OpenRouter 模型不在图片生成模型列表中',
        videoReason: video
            ? 'OpenRouter · ${cfg.model}'
            : '当前 OpenRouter 模型不在视频生成模型列表中',
      );
    }
    return AiAssistantMediaCapabilities.unavailable(
      provider: cfg.provider,
      model: cfg.model,
      speechReason: '当前模型没有可用的文字转语音接口',
      imageReason: '当前模型没有可用的图片生成接口',
      videoReason: '当前模型没有可用的视频生成接口',
    );
  }

  Future<List<String>> synthesizeSpeech(String text) async {
    final cfg = await _unifiedAi.resolveGlobalConfig();
    final capabilities = await resolveCapabilities(cfg);
    if (!capabilities.speech) throw StateError(capabilities.speechReason);
    final chunks = _splitText(text.trim(), 6500);
    final paths = <String>[];
    for (final chunk in chunks) {
      paths.add(await _synthesizeSpeechChunk(cfg, chunk));
    }
    return paths;
  }

  Future<AiAssistantGeneratedMedia> generateImage(String prompt) async {
    final cfg = await _unifiedAi.resolveGlobalConfig();
    final capabilities = await resolveCapabilities(cfg);
    if (!capabilities.image) throw StateError(capabilities.imageReason);
    switch (cfg.provider) {
      case 'xgrok':
        return _generateXaiImage(cfg, prompt);
      case 'openrouter':
        return _generateOpenRouterImage(cfg, prompt);
      case 'edenai':
        return _generateEdenImage(cfg, prompt);
      default:
        throw StateError(capabilities.imageReason);
    }
  }

  Future<AiAssistantGeneratedMedia> generateVideo(String prompt) async {
    final cfg = await _unifiedAi.resolveGlobalConfig();
    final capabilities = await resolveCapabilities(cfg);
    if (!capabilities.video) throw StateError(capabilities.videoReason);
    switch (cfg.provider) {
      case 'xgrok':
        return _generateXaiVideo(cfg, prompt);
      case 'openrouter':
        return _generateOpenRouterVideo(cfg, prompt);
      case 'edenai':
        return _generateEdenVideo(cfg, prompt);
      default:
        throw StateError(capabilities.videoReason);
    }
  }

  Future<String> _synthesizeSpeechChunk(
    UnifiedAiResolvedConfig cfg,
    String text,
  ) async {
    final dir = await _mediaDirectory();
    final digest = sha256
        .convert(utf8.encode('${cfg.provider}|${cfg.model}|$text'))
        .toString();
    final output = File(p.join(dir.path, 'speech_$digest.mp3'));
    if (await output.exists() && await output.length() > 128)
      return output.path;

    late http.Response response;
    if (cfg.provider == 'xgrok') {
      response = await http
          .post(
            Uri.parse('https://api.x.ai/v1/tts'),
            headers: _jsonHeaders(cfg, accept: 'audio/mpeg'),
            body: jsonEncode({
              'text': text,
              'voice_id': 'eve',
              'language': 'zh',
            }),
          )
          .timeout(const Duration(seconds: 120));
    } else if (cfg.provider == 'openrouter') {
      response = await http
          .post(
            Uri.parse('https://openrouter.ai/api/v1/audio/speech'),
            headers: _jsonHeaders(cfg, accept: 'audio/mpeg'),
            body: jsonEncode({
              'model': cfg.model,
              'input': text,
              'voice': 'alloy',
              'response_format': 'mp3',
            }),
          )
          .timeout(const Duration(seconds: 120));
    } else {
      response = await http
          .post(
            Uri.parse('https://api.edenai.run/v3/audio/speech'),
            headers: _jsonHeaders(cfg, accept: 'audio/mpeg'),
            body: jsonEncode({
              'model': _edenSpeechModel,
              'input': text,
              'voice': 'Rachel',
            }),
          )
          .timeout(const Duration(seconds: 120));
    }
    _ensureSuccess(response, '${cfg.provider} 朗读');
    if (response.bodyBytes.length < 128)
      throw StateError('${cfg.provider} 未返回有效音频');
    await output.writeAsBytes(response.bodyBytes, flush: true);
    return output.path;
  }

  Future<AiAssistantGeneratedMedia> _generateXaiImage(
    UnifiedAiResolvedConfig cfg,
    String prompt,
  ) async {
    final response = await http
        .post(
          Uri.parse('https://api.x.ai/v1/images/generations'),
          headers: _jsonHeaders(cfg),
          body: jsonEncode({
            'model': _xaiImageModel,
            'prompt': prompt,
            'response_format': 'url',
          }),
        )
        .timeout(const Duration(minutes: 3));
    _ensureSuccess(response, 'xAI 图片生成');
    final decoded = _decodeMap(response.body);
    final item = _firstMap(decoded['data']);
    return _saveImageResult(cfg, item, model: _xaiImageModel);
  }

  Future<AiAssistantGeneratedMedia> _generateOpenRouterImage(
    UnifiedAiResolvedConfig cfg,
    String prompt,
  ) async {
    final response = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/images'),
          headers: _jsonHeaders(cfg),
          body: jsonEncode({
            'model': cfg.model,
            'prompt': prompt,
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(minutes: 3));
    _ensureSuccess(response, 'OpenRouter 图片生成');
    final decoded = _decodeMap(response.body);
    return _saveImageResult(cfg, _firstMap(decoded['data']), model: cfg.model);
  }

  Future<AiAssistantGeneratedMedia> _generateEdenImage(
    UnifiedAiResolvedConfig cfg,
    String prompt,
  ) async {
    final response = await http
        .post(
          Uri.parse('https://api.edenai.run/v3/universal-ai'),
          headers: _jsonHeaders(cfg),
          body: jsonEncode({'model': _edenImageModel, 'prompt': prompt}),
        )
        .timeout(const Duration(minutes: 3));
    _ensureSuccess(response, 'Eden AI 图片生成');
    final decoded = _decodeMap(response.body);
    final url = _findString(decoded, const ['image_resource_url', 'url']);
    if (url.isEmpty) throw StateError('Eden AI 图片生成响应中没有图片地址');
    return _downloadMedia(
      cfg,
      url,
      extension: 'png',
      mimeType: 'image/png',
      model: _edenImageModel,
      prefix: 'image',
    );
  }

  Future<AiAssistantGeneratedMedia> _generateXaiVideo(
    UnifiedAiResolvedConfig cfg,
    String prompt,
  ) async {
    final create = await http
        .post(
          Uri.parse('https://api.x.ai/v1/videos/generations'),
          headers: _jsonHeaders(cfg),
          body: jsonEncode({'model': _xaiVideoModel, 'prompt': prompt}),
        )
        .timeout(const Duration(minutes: 2));
    _ensureSuccess(create, 'xAI 视频生成');
    final requestId = _findString(_decodeMap(create.body), const [
      'request_id',
      'id',
    ]);
    if (requestId.isEmpty) throw StateError('xAI 视频生成未返回 request_id');
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final status = await http
          .get(
            Uri.parse(
              'https://api.x.ai/v1/videos/${Uri.encodeComponent(requestId)}',
            ),
            headers: _authHeaders(cfg),
          )
          .timeout(const Duration(seconds: 45));
      _ensureSuccess(status, 'xAI 视频状态查询');
      final decoded = _decodeMap(status.body);
      final state = _findString(decoded, const [
        'status',
        'state',
      ]).toLowerCase();
      final url = _findString(decoded, const ['url', 'video_url']);
      if (url.isNotEmpty &&
          (state.isEmpty ||
              state == 'done' ||
              state == 'completed' ||
              state == 'succeeded')) {
        return _downloadMedia(
          cfg,
          url,
          extension: 'mp4',
          mimeType: 'video/mp4',
          model: _xaiVideoModel,
          prefix: 'video',
        );
      }
      if (state == 'failed' || state == 'error' || state == 'cancelled')
        throw StateError('xAI 视频生成失败：$state');
    }
    throw StateError('xAI 视频生成超时，请稍后重试');
  }

  Future<AiAssistantGeneratedMedia> _generateOpenRouterVideo(
    UnifiedAiResolvedConfig cfg,
    String prompt,
  ) async {
    final create = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/videos'),
          headers: _jsonHeaders(cfg),
          body: jsonEncode({'model': cfg.model, 'prompt': prompt}),
        )
        .timeout(const Duration(minutes: 2));
    _ensureSuccess(create, 'OpenRouter 视频生成');
    final initial = _decodeMap(create.body);
    final id = _findString(initial, const ['id', 'request_id']);
    final providedPollingUrl = _findString(initial, const ['polling_url']);
    if (id.isEmpty && providedPollingUrl.isEmpty)
      throw StateError('OpenRouter 视频生成未返回任务 ID');
    final pollingUrl = providedPollingUrl.isNotEmpty
        ? providedPollingUrl
        : 'https://openrouter.ai/api/v1/videos/${Uri.encodeComponent(id)}';
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final status = await http
          .get(Uri.parse(pollingUrl), headers: _authHeaders(cfg))
          .timeout(const Duration(seconds: 45));
      _ensureSuccess(status, 'OpenRouter 视频状态查询');
      final decoded = _decodeMap(status.body);
      final state = _findString(decoded, const [
        'status',
        'state',
      ]).toLowerCase();
      final url = _firstUrl(decoded);
      if (url.isNotEmpty &&
          (state.isEmpty ||
              state == 'completed' ||
              state == 'succeeded' ||
              state == 'done')) {
        return _downloadMedia(
          cfg,
          url,
          extension: 'mp4',
          mimeType: 'video/mp4',
          model: cfg.model,
          prefix: 'video',
        );
      }
      if (state == 'failed' || state == 'error' || state == 'cancelled')
        throw StateError('OpenRouter 视频生成失败：$state');
    }
    throw StateError('OpenRouter 视频生成超时，请稍后重试');
  }

  Future<AiAssistantGeneratedMedia> _generateEdenVideo(
    UnifiedAiResolvedConfig cfg,
    String prompt,
  ) async {
    final create = await http
        .post(
          Uri.parse('https://api.edenai.run/v3/universal-ai/async'),
          headers: _jsonHeaders(cfg),
          body: jsonEncode({'model': _edenVideoModel, 'prompt': prompt}),
        )
        .timeout(const Duration(minutes: 2));
    _ensureSuccess(create, 'Eden AI 视频生成');
    final jobId = _findString(_decodeMap(create.body), const ['job_id', 'id']);
    if (jobId.isEmpty) throw StateError('Eden AI 视频生成未返回 job_id');
    for (var attempt = 0; attempt < 120; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final status = await http
          .get(
            Uri.parse(
              'https://api.edenai.run/v3/universal-ai/async/${Uri.encodeComponent(jobId)}',
            ),
            headers: _authHeaders(cfg),
          )
          .timeout(const Duration(seconds: 45));
      _ensureSuccess(status, 'Eden AI 视频状态查询');
      final decoded = _decodeMap(status.body);
      final state = _findString(decoded, const [
        'status',
        'state',
      ]).toLowerCase();
      final url = _findString(decoded, const ['video_resource_url', 'url']);
      if (url.isNotEmpty &&
          (state.isEmpty ||
              state == 'completed' ||
              state == 'succeeded' ||
              state == 'done' ||
              state == 'finished')) {
        return _downloadMedia(
          cfg,
          url,
          extension: 'mp4',
          mimeType: 'video/mp4',
          model: _edenVideoModel,
          prefix: 'video',
        );
      }
      if (state == 'failed' || state == 'error' || state == 'cancelled')
        throw StateError('Eden AI 视频生成失败：$state');
    }
    throw StateError('Eden AI 视频生成超时，请稍后重试');
  }

  Future<AiAssistantGeneratedMedia> _saveImageResult(
    UnifiedAiResolvedConfig cfg,
    Map<String, dynamic> item, {
    required String model,
  }) async {
    final b64 = (item['b64_json'] ?? item['base64'] ?? '').toString().trim();
    final mime = (item['media_type'] ?? item['mime_type'] ?? 'image/png')
        .toString();
    if (b64.isNotEmpty) {
      final dir = await _mediaDirectory();
      final ext = mime.contains('jpeg')
          ? 'jpg'
          : (mime.contains('webp') ? 'webp' : 'png');
      final file = File(
        p.join(dir.path, 'image_${DateTime.now().millisecondsSinceEpoch}.$ext'),
      );
      await file.writeAsBytes(
        base64Decode(
          b64.contains(',') ? b64.substring(b64.indexOf(',') + 1) : b64,
        ),
        flush: true,
      );
      return AiAssistantGeneratedMedia(
        path: file.path,
        name: p.basename(file.path),
        mimeType: mime,
        provider: cfg.provider,
        model: model,
      );
    }
    final url = _findString(item, const ['url', 'image_url']);
    if (url.isEmpty) throw StateError('${cfg.provider} 图片生成响应中没有图片数据');
    return _downloadMedia(
      cfg,
      url,
      extension: 'png',
      mimeType: 'image/png',
      model: model,
      prefix: 'image',
    );
  }

  Future<AiAssistantGeneratedMedia> _downloadMedia(
    UnifiedAiResolvedConfig cfg,
    String url, {
    required String extension,
    required String mimeType,
    required String model,
    required String prefix,
  }) async {
    var response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 3));
    if (response.statusCode == 401 || response.statusCode == 403) {
      response = await http
          .get(Uri.parse(url), headers: _authHeaders(cfg))
          .timeout(const Duration(minutes: 3));
    }
    _ensureSuccess(response, '生成媒体下载');
    final dir = await _mediaDirectory();
    final file = File(
      p.join(
        dir.path,
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension',
      ),
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return AiAssistantGeneratedMedia(
      path: file.path,
      name: p.basename(file.path),
      mimeType: mimeType,
      provider: cfg.provider,
      model: model,
      remoteUrl: url,
    );
  }

  Future<Set<String>> _openRouterModelIds(
    UnifiedAiResolvedConfig cfg,
    Uri uri,
  ) async {
    try {
      final response = await http
          .get(uri, headers: _authHeaders(cfg))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300)
        return <String>{};
      final decoded = _decodeMap(response.body);
      final raw = decoded['data'] ?? decoded['models'];
      if (raw is! List) return <String>{};
      return raw
          .whereType<Map>()
          .map((item) => (item['id'] ?? item['model'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Map<String, String> _authHeaders(UnifiedAiResolvedConfig cfg) => {
    'Authorization': 'Bearer ${cfg.apiKey}',
  };

  Map<String, String> _jsonHeaders(
    UnifiedAiResolvedConfig cfg, {
    String accept = 'application/json',
  }) => {
    ..._authHeaders(cfg),
    'Content-Type': 'application/json',
    'Accept': accept,
  };

  void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final short = body.length <= 300 ? body : '${body.substring(0, 300)}…';
    throw StateError('$action失败：HTTP ${response.statusCode} $short');
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('服务返回的不是 JSON 对象');
  }

  Map<String, dynamic> _firstMap(Object? value) {
    if (value is List && value.isNotEmpty && value.first is Map)
      return Map<String, dynamic>.from(value.first as Map);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _findString(Object? value, List<String> keys) {
    if (value is Map) {
      for (final key in keys) {
        final candidate = value[key];
        if (candidate is String && candidate.trim().isNotEmpty)
          return candidate.trim();
      }
      for (final child in value.values) {
        final found = _findString(child, keys);
        if (found.isNotEmpty) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findString(child, keys);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  String _firstUrl(Object? value) {
    if (value is Map) {
      for (final key in const ['unsigned_urls', 'urls']) {
        final urls = value[key];
        if (urls is List && urls.isNotEmpty && urls.first is String)
          return urls.first.toString();
      }
      final direct = _findString(value, const ['video_url', 'url']);
      if (direct.isNotEmpty) return direct;
    }
    return '';
  }

  Future<Directory> _mediaDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ai_assistant_generated'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<String> _splitText(String text, int maxChars) {
    if (text.isEmpty) throw StateError('没有可朗读的文字');
    if (text.length <= maxChars) return [text];
    final out = <String>[];
    var rest = text;
    while (rest.length > maxChars) {
      var cut = maxChars;
      for (var i = maxChars; i > maxChars ~/ 2; i--) {
        if ('。！？!?；;\n'.contains(rest[i - 1])) {
          cut = i;
          break;
        }
      }
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trimLeft();
    }
    if (rest.trim().isNotEmpty) out.add(rest.trim());
    return out;
  }
}
