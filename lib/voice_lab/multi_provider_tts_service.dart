import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/kv_dao.dart';
import '../utils/deepseek_logger.dart';
import 'voice_lab_dao.dart';
import 'voice_lab_models.dart';

/// Voice/TTS provider keys shared by the “语音与美好的祝福” module.
/// Existing ElevenLabs keys are kept in ElevenLabsSettings for backwards compatibility.
class VoiceProviderSettings {
  static const provider = 'voice_lab.tts_provider'; // elevenlabs / resemble / minimax / microsoft / iflytek

  static const microsoftApiKey = 'microsoft_speech.api_key';
  static const microsoftRegion = 'microsoft_speech.region';
  static const microsoftEndpoint = 'microsoft_speech.endpoint';
  static const microsoftVoice = 'microsoft_speech.voice';
  static const microsoftLanguage = 'microsoft_speech.language';
  static const microsoftOutputFormat = 'microsoft_speech.output_format';
  static const microsoftRecognitionEndpoint = 'microsoft_speech.recognition_endpoint';
  static const microsoftProfanity = 'microsoft_speech.profanity';
  static const microsoftContinuousListening = 'microsoft_speech.continuous_listening';

  static const resembleApiKey = 'resemble.api_key';
  static const resembleVoiceUuid = 'resemble.voice_uuid';
  static const resembleVoiceName = 'resemble.voice_name';
  static const resembleModel = 'resemble.model';
  static const resembleOutputFormat = 'resemble.output_format';
  static const resembleSampleRate = 'resemble.sample_rate';
  static const resemblePrecision = 'resemble.precision';
  static const resembleUseHd = 'resemble.use_hd';
  static const resembleApplyPronunciations = 'resemble.apply_pronunciations';
  static const resembleVoiceType = 'resemble.voice_type';
  static const resembleRecordingTranscript = 'resemble.recording_transcript';
  static const resembleMeditationMode = 'resemble.meditation_mode';
  static const resembleMeditationUsePrompt = 'resemble.meditation_use_prompt';
  static const resembleMeditationPrompt = 'resemble.meditation_prompt';
  static const resembleMeditationMaxBreakSec = 'resemble.meditation_max_break_sec';
  static const resembleMeditationSplitLongBreaks = 'resemble.meditation_split_long_breaks';

  static const minimaxApiKey = 'minimax.api_key';
  static const minimaxGroupId = 'minimax.group_id';
  static const minimaxEndpoint = 'minimax.endpoint';
  static const minimaxModel = 'minimax.model';
  static const minimaxVoiceId = 'minimax.voice_id';
  static const minimaxVoiceName = 'minimax.voice_name';
  static const minimaxFormat = 'minimax.format';
  static const minimaxSampleRate = 'minimax.sample_rate';
  static const minimaxBitrate = 'minimax.bitrate';
  static const minimaxChannel = 'minimax.channel';
  static const minimaxVolume = 'minimax.volume';
  static const minimaxPitch = 'minimax.pitch';
  static const minimaxEmotion = 'minimax.emotion';
  static const minimaxLanguageBoost = 'minimax.language_boost';
  static const minimaxTextNormalization = 'minimax.text_normalization';
  static const minimaxSoundEffects = 'minimax.sound_effects';
  static const minimaxVoiceModifyPitch = 'minimax.voice_modify_pitch';
  static const minimaxVoiceModifyIntensity = 'minimax.voice_modify_intensity';
  static const minimaxVoiceModifyTimbre = 'minimax.voice_modify_timbre';

  static const iflytekAppId = 'iflytek.app_id';
  static const iflytekApiKey = 'iflytek.api_key';
  static const iflytekApiSecret = 'iflytek.api_secret';
  static const iflytekEndpoint = 'iflytek.endpoint';
  static const iflytekVoiceName = 'iflytek.voice_name';
  static const iflytekAudioEncoding = 'iflytek.audio_encoding';
  static const iflytekSampleRate = 'iflytek.sample_rate';
  static const iflytekLanguage = 'iflytek.language';
  static const iflytekAccent = 'iflytek.accent';
  static const iflytekSttEndpoint = 'iflytek.stt_endpoint';

  static const defaultProvider = 'elevenlabs';
  static const defaultResembleModel = ''; // empty = let Resemble choose the best model for the voice
  static const defaultResembleOutputFormat = 'mp3';
  static const defaultResemblePrecision = 'PCM_16';
  static const defaultResembleMeditationMode = 'expert_ssml';
  static const defaultResembleMeditationPrompt = 'calm Chinese mindfulness meditation guide, slow gentle voice, soft warm tone, spacious pauses, no performance, no excitement, soothing and reassuring';
  static const defaultResembleMeditationMaxBreakSec = 3.0;
  static const defaultMiniMaxEndpoint = 'https://api.minimax.io/v1/t2a_v2';
  static const defaultMiniMaxModel = 'speech-2.8-hd';
  static const defaultMiniMaxVoiceId = 'Chinese_Mandarin_Ordinary';
  static const defaultMiniMaxVoiceName = 'MiniMax 普通中文声音';
  static const defaultMicrosoftRegion = 'eastasia';
  static const defaultMicrosoftVoice = 'zh-CN-XiaoxiaoNeural';
  static const defaultMicrosoftLanguage = 'zh-CN';
  static const defaultMicrosoftOutputFormat = 'audio-24khz-48kbitrate-mono-mp3';
  static const defaultIflytekEndpoint = 'https://tts-api.xfyun.cn/v2/tts';
  static const defaultIflytekSttEndpoint = 'https://iat-api.xfyun.cn/v2/iat';
  static const defaultIflytekVoiceName = 'xiaoyan';
  static const defaultIflytekAudioEncoding = 'lame';
  static const defaultIflytekSampleRate = '16000';
  static const defaultIflytekLanguage = 'zh_cn';
  static const defaultIflytekAccent = 'mandarin';
}

class MultiProviderTtsService {
  MultiProviderTtsService({KeyValueDao? kvDao, VoiceLabDao? voiceDao})
      : _kvDao = kvDao ?? KeyValueDao(),
        _voiceDao = voiceDao ?? VoiceLabDao();

  final KeyValueDao _kvDao;
  final VoiceLabDao _voiceDao;

  Future<String> getProvider() async {
    final raw = (await _kvDao.getString(VoiceProviderSettings.provider) ?? VoiceProviderSettings.defaultProvider).trim();
    if (raw == 'resemble' || raw == 'minimax' || raw == 'microsoft' || raw == 'iflytek' || raw == 'elevenlabs') return raw;
    return VoiceProviderSettings.defaultProvider;
  }

  String microsoftTtsEndpoint(String region, String customEndpoint) {
    final custom = customEndpoint.trim();
    if (custom.contains('/cognitiveservices/v1')) return custom;
    return 'https://${region.trim()}.tts.speech.microsoft.com/cognitiveservices/v1';
  }

  String microsoftRecognitionEndpoint(String region, String language, String customEndpoint) {
    final custom = customEndpoint.trim();
    if (custom.isNotEmpty) return custom;
    return 'https://${region.trim()}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1'
        '?language=${Uri.encodeQueryComponent(language)}&format=detailed';
  }


  Future<bool> testIflytekConnection({String? appId, String? apiKey, String? apiSecret, String? endpoint}) async {
    await synthesizeIflytekToFile(text: '连接测试', appId: appId, apiKey: apiKey, apiSecret: apiSecret, endpoint: endpoint, forceNoCache: true);
    return true;
  }

  Future<List<ProviderCatalogOption>> listIflytekVoices() async {
    return const <ProviderCatalogOption>[
      ProviderCatalogOption(id: 'xiaoyan', name: '讯飞小燕', category: 'standard', description: '普通话女声，适合祝福与闹钟'),
      ProviderCatalogOption(id: 'aisjiuxu', name: '讯飞许久', category: 'standard', description: '普通话男声，沉稳清晰'),
      ProviderCatalogOption(id: 'aisxping', name: '讯飞小萍', category: 'standard', description: '温柔女声，适合晚安'),
      ProviderCatalogOption(id: 'aisjinger', name: '讯飞小婧', category: 'standard', description: '明亮女声，适合早安'),
    ];
  }

  Future<String> synthesizeIflytekToFile({
    required String text,
    String? appId,
    String? apiKey,
    String? apiSecret,
    String? endpoint,
    String? voiceName,
    String? encoding,
    String? sampleRate,
    double speed = 1.0,
    double volume = 1.0,
    double pitch = 0,
    bool forceNoCache = false,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) throw StateError('请输入需要转换成语音的文字');
    final id = (appId ?? await _kvDao.getString(VoiceProviderSettings.iflytekAppId) ?? '').trim();
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.iflytekApiKey) ?? '').trim();
    final secret = (apiSecret ?? await _kvDao.getString(VoiceProviderSettings.iflytekApiSecret) ?? '').trim();
    if (id.isEmpty || key.isEmpty || secret.isEmpty) throw StateError('请先填写讯飞开放平台 AppID、APIKey、APISecret');
    final url = (endpoint ?? await _kvDao.getString(VoiceProviderSettings.iflytekEndpoint) ?? VoiceProviderSettings.defaultIflytekEndpoint).trim();
    final vcn = (voiceName ?? await _kvDao.getString(VoiceProviderSettings.iflytekVoiceName) ?? VoiceProviderSettings.defaultIflytekVoiceName).trim();
    final aue = (encoding ?? await _kvDao.getString(VoiceProviderSettings.iflytekAudioEncoding) ?? VoiceProviderSettings.defaultIflytekAudioEncoding).trim();
    final auf = 'audio/L16;rate=${(sampleRate ?? await _kvDao.getString(VoiceProviderSettings.iflytekSampleRate) ?? VoiceProviderSettings.defaultIflytekSampleRate).trim()}';
    final uri = Uri.parse(url);
    final date = HttpDate.format(DateTime.now().toUtc());
    final signatureOrigin = 'host: ${uri.host}\ndate: $date\nPOST ${uri.path} HTTP/1.1';
    final hmacSha256 = Hmac(sha256, utf8.encode(secret));
    final signature = base64Encode(hmacSha256.convert(utf8.encode(signatureOrigin)).bytes);
    final authorizationOrigin = 'api_key="$key", algorithm="hmac-sha256", headers="host date request-line", signature="$signature"';
    final authed = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'authorization': base64Encode(utf8.encode(authorizationOrigin)),
      'date': date,
      'host': uri.host,
    });
    final body = {
      'common': {'app_id': id},
      'business': {
        'aue': aue,
        'auf': auf,
        'vcn': vcn,
        'tte': 'UTF8',
        'speed': ((speed.clamp(0.5, 2.0) - 0.5) / 1.5 * 100).round().clamp(0, 100),
        'volume': (volume.clamp(0.0, 1.0) * 100).round().clamp(0, 100),
        'pitch': ((pitch.clamp(-20.0, 20.0) + 20) / 40 * 100).round().clamp(0, 100),
      },
      'data': {'status': 2, 'text': base64Encode(utf8.encode(cleanText))},
    };
    final resp = await http.post(authed, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 90));
    if (resp.statusCode < 200 || resp.statusCode >= 300) throw StateError('讯飞 TTS 失败：HTTP ${resp.statusCode} ${resp.body}');
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final code = (decoded['code'] as num?)?.toInt() ?? -1;
    if (code != 0) throw StateError('讯飞 TTS 失败：${decoded['message'] ?? resp.body}');
    final audio = ((decoded['data'] as Map?)?['audio'] ?? '').toString();
    if (audio.isEmpty) throw StateError('讯飞 TTS 未返回音频：${resp.body}');
    final bytes = base64Decode(audio);
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'voice_lab_audio'));
    await folder.create(recursive: true);
    final ext = aue == 'raw' ? 'pcm' : (aue == 'lame' ? 'mp3' : aue);
    final file = File(p.join(folder.path, 'iflytek_${DateTime.now().millisecondsSinceEpoch}.$ext'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<bool> testMicrosoftConnection({
    String? apiKey,
    String? region,
    String? endpoint,
  }) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.microsoftApiKey) ?? '').trim();
    final location = (region ?? await _kvDao.getString(VoiceProviderSettings.microsoftRegion) ?? VoiceProviderSettings.defaultMicrosoftRegion).trim();
    if (key.isEmpty) throw StateError('请先填写 Microsoft Speech API Key');
    if (location.isEmpty && (endpoint ?? '').trim().isEmpty) throw StateError('请填写 Azure Region / Location 或自定义 Endpoint');
    final uri = Uri.parse(microsoftTtsEndpoint(location, endpoint ?? ''));
    final response = await http.post(
      uri,
      headers: {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': VoiceProviderSettings.defaultMicrosoftOutputFormat,
        'User-Agent': 'quote_app',
      },
      body: '<speak version="1.0" xml:lang="zh-CN"><voice name="${VoiceProviderSettings.defaultMicrosoftVoice}">连接测试</voice></speak>',
    ).timeout(const Duration(seconds: 40));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Microsoft Speech 测试失败：HTTP ${response.statusCode} ${response.body}');
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('Microsoft Speech Endpoint 返回成功状态但没有音频。请清空自定义 Endpoint，并确认 Region 与 Azure Speech 资源一致。');
    }
    return true;
  }

  Future<List<ProviderCatalogOption>> listMicrosoftVoices({
    String? apiKey,
    String? region,
  }) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.microsoftApiKey) ?? '').trim();
    final location = (region ?? await _kvDao.getString(VoiceProviderSettings.microsoftRegion) ?? VoiceProviderSettings.defaultMicrosoftRegion).trim();
    if (key.isEmpty) throw StateError('请先填写 Microsoft Speech API Key');
    if (location.isEmpty) throw StateError('请先填写 Microsoft Speech Region / Location');
    final uri = Uri.parse('https://$location.tts.speech.microsoft.com/cognitiveservices/voices/list');
    final response = await http.get(uri, headers: {
      'Ocp-Apim-Subscription-Key': key,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('获取 Microsoft 声音列表失败：HTTP ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <ProviderCatalogOption>[];
    return decoded.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final id = (item['ShortName'] ?? item['Name'] ?? '').toString();
      final locale = (item['Locale'] ?? '').toString();
      final localName = (item['LocalName'] ?? item['DisplayName'] ?? id).toString();
      final gender = (item['Gender'] ?? '').toString();
      final styles = item['StyleList'] is List ? (item['StyleList'] as List).join('、') : '';
      return ProviderCatalogOption(
        id: id,
        name: '$localName${locale.isEmpty ? '' : ' · $locale'}',
        category: gender,
        description: styles.isEmpty ? gender : '$gender · 风格：$styles',
        extra: {
          'locale': locale,
          'gender': gender,
          'voiceType': (item['VoiceType'] ?? '').toString(),
        },
      );
    }).where((voice) => voice.id.isNotEmpty).toList();
  }

  Future<String> synthesizeMicrosoftToFile({
    required String text,
    String? apiKey,
    String? region,
    String? endpoint,
    String? voice,
    String? language,
    String? outputFormat,
    double rate = 1,
    double pitch = 0,
    double volume = 1,
    double pauseSeconds = 0,
    String style = '',
  }) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.microsoftApiKey) ?? '').trim();
    final location = (region ?? await _kvDao.getString(VoiceProviderSettings.microsoftRegion) ?? VoiceProviderSettings.defaultMicrosoftRegion).trim();
    final selectedVoice = (voice ?? await _kvDao.getString(VoiceProviderSettings.microsoftVoice) ?? VoiceProviderSettings.defaultMicrosoftVoice).trim();
    final locale = (language ?? await _kvDao.getString(VoiceProviderSettings.microsoftLanguage) ?? VoiceProviderSettings.defaultMicrosoftLanguage).trim();
    final format = (outputFormat ?? await _kvDao.getString(VoiceProviderSettings.microsoftOutputFormat) ?? VoiceProviderSettings.defaultMicrosoftOutputFormat).trim();
    if (key.isEmpty) throw StateError('未配置 Microsoft Speech API Key');
    final uri = Uri.parse(microsoftTtsEndpoint(location, endpoint ?? await _kvDao.getString(VoiceProviderSettings.microsoftEndpoint) ?? ''));
    var escaped = const HtmlEscape().convert(text);
    if (pauseSeconds > 0) {
      final breakTag = '<break time="${pauseSeconds.clamp(0.1, 5.0).toStringAsFixed(1)}s"/>';
      escaped = escaped.replaceAllMapped(RegExp(r'([。！？!?；;])'), (match) => '${match.group(1)}$breakTag');
    }
    final ratePercent = ((rate - 1) * 100).round();
    final pitchPercent = pitch.round();
    final volumePercent = ((volume.clamp(0.0, 1.0) - 1) * 100).round();
    final prosody = '<prosody rate="${ratePercent >= 0 ? '+' : ''}$ratePercent%" pitch="${pitchPercent >= 0 ? '+' : ''}$pitchPercent%" volume="${volumePercent >= 0 ? '+' : ''}$volumePercent%">$escaped</prosody>';
    final styled = style.trim().isEmpty ? prosody : '<mstts:express-as style="${const HtmlEscape().convert(style.trim())}">$prosody</mstts:express-as>';
    String buildSsml(String content) =>
        '<speak version="1.0" xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="$locale"><voice name="$selectedVoice">$content</voice></speak>';
    Future<http.Response> send(Uri target, String body) => http.post(target, headers: {
      'Ocp-Apim-Subscription-Key': key,
      'Content-Type': 'application/ssml+xml',
      'X-Microsoft-OutputFormat': format,
      'User-Agent': 'quote_app',
    }, body: body).timeout(const Duration(seconds: 90));
    var response = await send(uri, buildSsml(styled));
    if ((response.statusCode < 200 || response.statusCode >= 300) && style.trim().isNotEmpty) {
      response = await send(uri, buildSsml(prosody));
    }
    final regionalUri = Uri.parse(microsoftTtsEndpoint(location, ''));
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        response.bodyBytes.isEmpty &&
        uri != regionalUri) {
      response = await send(regionalUri, buildSsml(prosody));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Microsoft TTS 失败：HTTP ${response.statusCode} ${response.body}');
    }
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'voice_lab_audio'));
    await folder.create(recursive: true);
    if (response.bodyBytes.length < 128) {
      final requestId = response.headers['x-requestid'] ?? response.headers['x-request-id'] ?? '无';
      throw StateError('Microsoft TTS 未返回有效音频（${response.bodyBytes.length} bytes）。请确认 Region 与语音资源一致；Endpoint 可留空让系统自动生成。requestId=$requestId');
    }
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final bytes = response.bodyBytes;
    final isWave = contentType.contains('wav') ||
        contentType.contains('riff') ||
        (bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46);
    final isMp3 = contentType.contains('mpeg') ||
        contentType.contains('mp3') ||
        (bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
        (bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0);
    if (!isWave && !isMp3) {
      throw StateError('Microsoft TTS 返回了无法识别的音频格式：${contentType.isEmpty ? 'unknown' : contentType}');
    }
    final ext = isWave ? 'wav' : 'mp3';
    final file = File(p.join(folder.path, 'microsoft_${DateTime.now().millisecondsSinceEpoch}.$ext'));
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  Future<String> recognizeMicrosoftWav({
    required List<int> wavBytes,
    String? apiKey,
    String? region,
    String? endpoint,
    String? language,
    String profanity = 'masked',
  }) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.microsoftApiKey) ?? '').trim();
    final location = (region ?? await _kvDao.getString(VoiceProviderSettings.microsoftRegion) ?? VoiceProviderSettings.defaultMicrosoftRegion).trim();
    final locale = (language ?? await _kvDao.getString(VoiceProviderSettings.microsoftLanguage) ?? VoiceProviderSettings.defaultMicrosoftLanguage).trim();
    if (key.isEmpty) throw StateError('未配置 Microsoft Speech API Key');
    final uri = Uri.parse(microsoftRecognitionEndpoint(
      location,
      locale,
      endpoint ?? await _kvDao.getString(VoiceProviderSettings.microsoftRecognitionEndpoint) ?? '',
    )).replace(queryParameters: {
      ...Uri.parse(microsoftRecognitionEndpoint(location, locale, endpoint ?? '')).queryParameters,
      'profanity': profanity,
    });
    final response = await http.post(uri, headers: {
      'Ocp-Apim-Subscription-Key': key,
      'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
      'Accept': 'application/json',
    }, body: wavBytes).timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Microsoft STT 失败：HTTP ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final best = decoded['NBest'];
      final bestText = best is List && best.isNotEmpty && best.first is Map
          ? (best.first as Map)['Display']
          : null;
      return (decoded['DisplayText'] ?? decoded['Text'] ?? bestText ?? '').toString();
    }
    return '';
  }

  Future<bool> isAutoSaveEnabled() async {
    final v = await _kvDao.getString('elevenlabs.auto_save_audio');
    return v == null || v == '1' || v.toLowerCase() == 'true';
  }

  Future<bool> isCacheEnabled() async {
    final v = await _kvDao.getString('elevenlabs.reuse_cache');
    return v == null || v == '1' || v.toLowerCase() == 'true';
  }

  Future<VoiceProfile> addManualVoiceProfile({
    required String provider,
    required String displayName,
    required String externalVoiceId,
    String language = 'zh',
    bool makeDefault = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final pvd = _normalizeProvider(provider);
    final profile = VoiceProfile(
      id: voiceLabUid('voice'),
      provider: pvd,
      displayName: displayName.trim().isEmpty ? _providerName(pvd) : displayName.trim(),
      elevenlabsVoiceId: externalVoiceId.trim(),
      cloneType: 'manual_$pvd',
      language: language,
      status: 'ready',
      isDefault: makeDefault,
      createdAt: now,
      updatedAt: now,
    );
    await _voiceDao.upsertVoiceProfile(profile, makeDefault: makeDefault);
    return profile;
  }

  Future<bool> testResembleConnection({String? apiKey}) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.resembleApiKey) ?? '').trim();
    if (key.isEmpty) throw StateError('请先填写 Resemble AI API Token');
    // Resemble v2 voices list requires page >= 1 and page_size between 10 and 1000.
    // Keep test-connection lightweight by requesting the minimum valid page_size.
    final uri = Uri.parse('https://app.resemble.ai/api/v2/voices').replace(queryParameters: const {
      'page': '1',
      'page_size': '10',
    });
    await DeepSeekLogger.logRequest(
      provider: 'Resemble AI',
      module: 'voice_lab.resemble.test_connection',
      endpoint: uri.toString(),
      method: 'GET',
      model: 'voices/list',
      headers: const {'Authorization': 'Bearer ***REDACTED***'},
      body: const {'action': 'list_voices'},
    );
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $key'}).timeout(const Duration(seconds: 35));
    await DeepSeekLogger.logResponse(
      provider: 'Resemble AI',
      module: 'voice_lab.resemble.test_connection',
      endpoint: uri.toString(),
      model: 'voices/list',
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Resemble AI 测试失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    return true;
  }

  Future<bool> testMiniMaxConnection({String? apiKey, String? endpoint}) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.minimaxApiKey) ?? '').trim();
    if (key.isEmpty) throw StateError('请先填写 MiniMax API Key');
    final uri = Uri.parse((endpoint ?? await _kvDao.getString(VoiceProviderSettings.minimaxEndpoint) ?? VoiceProviderSettings.defaultMiniMaxEndpoint).trim());
    final body = <String, dynamic>{
      'model': VoiceProviderSettings.defaultMiniMaxModel,
      'text': '测试',
      'stream': false,
      'language_boost': 'Chinese',
      'output_format': 'hex',
      'voice_setting': {'voice_id': VoiceProviderSettings.defaultMiniMaxVoiceId, 'speed': 1, 'vol': 1, 'pitch': 0},
      'audio_setting': {'sample_rate': 32000, 'bitrate': 128000, 'format': 'mp3', 'channel': 1},
    };
    final resp = await http
        .post(uri, headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('MiniMax 测试失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    return true;
  }


  Future<List<ProviderCatalogOption>> listResembleVoices({String? apiKey, int pageSize = 50}) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.resembleApiKey) ?? '').trim();
    if (key.isEmpty) throw StateError('请先填写 Resemble AI API Token');
    final uri = Uri.parse('https://app.resemble.ai/api/v2/voices').replace(queryParameters: {
      'page': '1',
      'page_size': pageSize.clamp(10, 1000).toString(),
    });
    await DeepSeekLogger.logRequest(
      provider: 'Resemble AI',
      module: 'voice_lab.resemble.list_voices',
      endpoint: uri.toString(),
      method: 'GET',
      model: 'voices/list',
      headers: const {'Authorization': 'Bearer ***REDACTED***'},
      body: const {'action': 'list_voices'},
    );
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $key'}).timeout(const Duration(seconds: 45));
    await DeepSeekLogger.logResponse(
      provider: 'Resemble AI',
      module: 'voice_lab.resemble.list_voices',
      endpoint: uri.toString(),
      model: 'voices/list',
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw StateError('Resemble Token 无效或无权访问声音列表。请重新复制 API Token，并确认所选 voice_uuid 属于当前账号/团队。');
      }
      throw StateError('获取 Resemble 声音列表失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    final raw = decoded is Map
        ? (decoded['items'] ?? decoded['voices'] ?? decoded['data'] ?? decoded['results'])
        : decoded;
    if (raw is! List) return const <ProviderCatalogOption>[];
    return raw.whereType<Map>().map((item) {
      final m = Map<String, dynamic>.from(item);
      final id = (m['uuid'] ?? m['voice_uuid'] ?? m['id'] ?? '').toString();
      final name = (m['name'] ?? m['title'] ?? id).toString();
      final category = (m['voice_type'] ?? m['type'] ?? m['category'] ?? '').toString();
      final description = (m['description'] ?? m['use_case'] ?? '').toString();
      final extra = <String, String>{};
      for (final key in const ['language', 'gender', 'age', 'accent', 'status']) {
        final value = m[key];
        if (value != null && value.toString().trim().isNotEmpty) extra[key] = value.toString();
      }
      return ProviderCatalogOption(id: id, name: name, category: category, description: description, extra: extra);
    }).where((v) => v.id.trim().isNotEmpty).toList();
  }

  Future<List<ProviderCatalogOption>> listResembleModels() async {
    // Resemble synchronous TTS normally lets the platform choose the compatible Chatterbox
    // variant for the selected voice. Sending an unsupported model id can cause provider
    // errors, so expose only safe choices.
    return const <ProviderCatalogOption>[
      ProviderCatalogOption(id: '', name: '自动选择 / Chatterbox', description: '推荐：不显式传 model，由 Resemble 按 voice_uuid 自动选择默认兼容模型'),
      ProviderCatalogOption(id: 'chatterbox-turbo', name: 'Chatterbox Turbo', description: '低延迟；主要适合 Rapid English / 预制声音；若失败请改回自动选择'),
    ];
  }

  Future<List<ProviderCatalogOption>> listMiniMaxModels({String? apiKey}) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.minimaxApiKey) ?? '').trim();
    if (key.isEmpty) throw StateError('请先填写 MiniMax API Key');
    final uri = Uri.parse('https://api.minimax.io/v1/models');
    try {
      await DeepSeekLogger.logRequest(
        provider: 'MiniMax',
        module: 'voice_lab.minimax.list_models',
        endpoint: uri.toString(),
        method: 'GET',
        model: 'models/list',
        headers: const {'Authorization': 'Bearer ***REDACTED***'},
        body: const {'action': 'list_models'},
      );
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $key'}).timeout(const Duration(seconds: 45));
      await DeepSeekLogger.logResponse(
        provider: 'MiniMax',
        module: 'voice_lab.minimax.list_models',
        endpoint: uri.toString(),
        model: 'models/list',
        statusCode: resp.statusCode,
        body: _shortBody(resp.body),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        final raw = decoded is Map ? (decoded['data'] ?? decoded['models'] ?? decoded['items']) : decoded;
        final list = raw is List
            ? raw.whereType<Map>().map((item) {
                final m = Map<String, dynamic>.from(item);
                final id = (m['id'] ?? m['model'] ?? m['model_id'] ?? '').toString();
                final name = (m['name'] ?? id).toString();
                final description = (m['description'] ?? m['owned_by'] ?? '').toString();
                return ProviderCatalogOption(id: id, name: name, description: description, category: 'account');
              }).where((e) => e.id.trim().isNotEmpty && e.id.toLowerCase().contains('speech')).toList()
            : <ProviderCatalogOption>[];
        if (list.isNotEmpty) return list;
      }
    } catch (_) {
      // Fall back to the official/recommended Speech model IDs below.
    }
    return const <ProviderCatalogOption>[
      ProviderCatalogOption(id: 'speech-2.8-hd', name: 'Speech 2.8 HD', description: '最新 HD，高质量，适合冥想/旁白/长音频'),
      ProviderCatalogOption(id: 'speech-2.8-turbo', name: 'Speech 2.8 Turbo', description: '低延迟，适合实时对话'),
      ProviderCatalogOption(id: 'speech-2.6-hd', name: 'Speech 2.6 HD', description: '稳定 HD 版本'),
      ProviderCatalogOption(id: 'speech-2.6-turbo', name: 'Speech 2.6 Turbo', description: '高性价比低延迟'),
      ProviderCatalogOption(id: 'speech-02-hd', name: 'Speech 02 HD', description: '经典 HD 模型'),
      ProviderCatalogOption(id: 'speech-02-turbo', name: 'Speech 02 Turbo', description: '经典 Turbo 模型'),
    ];
  }

  Future<List<ProviderCatalogOption>> listMiniMaxVoices({String? apiKey, String voiceType = 'all'}) async {
    final key = (apiKey ?? await _kvDao.getString(VoiceProviderSettings.minimaxApiKey) ?? '').trim();
    if (key.isEmpty) throw StateError('请先填写 MiniMax API Key');
    final uri = Uri.parse('https://api.minimax.io/v1/get_voice');
    final body = {'voice_type': voiceType.trim().isEmpty ? 'all' : voiceType.trim()};
    await DeepSeekLogger.logRequest(
      provider: 'MiniMax',
      module: 'voice_lab.minimax.list_voices',
      endpoint: uri.toString(),
      method: 'POST',
      model: 'get_voice',
      headers: const {'Authorization': 'Bearer ***REDACTED***', 'Content-Type': 'application/json'},
      body: body,
    );
    final resp = await http.post(uri, headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    await DeepSeekLogger.logResponse(
      provider: 'MiniMax',
      module: 'voice_lab.minimax.list_voices',
      endpoint: uri.toString(),
      model: 'get_voice',
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('获取 MiniMax 声音列表失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    final out = <ProviderCatalogOption>[];
    if (decoded is Map) {
      void addList(String key, String category) {
        final raw = decoded[key];
        if (raw is! List) return;
        for (final item in raw.whereType<Map>()) {
          final m = Map<String, dynamic>.from(item);
          final id = (m['voice_id'] ?? m['voiceId'] ?? m['id'] ?? '').toString();
          final name = (m['voice_name'] ?? m['voiceName'] ?? m['name'] ?? id).toString();
          final description = (m['description'] ?? m['voice_desc'] ?? '').toString();
          final extra = <String, String>{};
          for (final k in const ['language', 'gender', 'age', 'accent']) {
            final v = m[k];
            if (v != null && v.toString().trim().isNotEmpty) extra[k] = v.toString();
          }
          if (id.trim().isNotEmpty) out.add(ProviderCatalogOption(id: id, name: name, category: category, description: description, extra: extra));
        }
      }
      addList('system_voice', 'system');
      addList('voice_cloning', 'voice_cloning');
      addList('voice_generation', 'voice_generation');
      addList('voices', 'voices');
      addList('data', 'data');
    }
    if (out.isNotEmpty) return out;
    return const <ProviderCatalogOption>[
      ProviderCatalogOption(id: 'Chinese_Mandarin_Ordinary', name: '普通中文', category: 'system'),
      ProviderCatalogOption(id: 'Wise_Woman', name: 'Wise Woman', category: 'system'),
      ProviderCatalogOption(id: 'Calm_Woman', name: 'Calm Woman', category: 'system', description: '冥想/安抚推荐'),
      ProviderCatalogOption(id: 'Patient_Man', name: 'Patient Man', category: 'system', description: '平稳耐心男声'),
      ProviderCatalogOption(id: 'Friendly_Person', name: 'Friendly Person', category: 'system'),
      ProviderCatalogOption(id: 'Deep_Voice_Man', name: 'Deep Voice Man', category: 'system'),
    ];
  }

  Future<VoiceProfile> createResembleVoiceClone({
    required String displayName,
    required String sampleAudioPath,
    String transcript = '',
    String language = 'zh-CN',
    String voiceType = 'rapid_voice',
    bool makeDefault = true,
  }) async {
    final apiKey = (await _kvDao.getString(VoiceProviderSettings.resembleApiKey) ?? '').trim();
    if (apiKey.isEmpty) throw StateError('请先填写 Resemble AI API Token');
    final sample = File(sampleAudioPath);
    if (!await sample.exists()) throw StateError('声音样本文件不存在');

    final createUri = Uri.parse('https://app.resemble.ai/api/v2/voices');
    final createBody = <String, dynamic>{
      'name': displayName.trim().isEmpty ? 'Resemble 克隆声音' : displayName.trim(),
      'language': language,
      'voice_type': voiceType.trim().isEmpty ? 'rapid_voice' : voiceType.trim(),
    };
    final createResp = await http
        .post(createUri, headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}, body: jsonEncode(createBody))
        .timeout(const Duration(seconds: 60));
    if (createResp.statusCode < 200 || createResp.statusCode >= 300) {
      throw StateError('Resemble 创建声音失败：HTTP ${createResp.statusCode} ${createResp.body}');
    }
    final createJson = jsonDecode(createResp.body) as Map<String, dynamic>;
    final voiceUuid = _extractResembleVoiceUuid(createJson);
    if (voiceUuid.isEmpty) throw StateError('Resemble 未返回 voice uuid：${createResp.body}');

    final uploadUri = Uri.parse('https://app.resemble.ai/api/v2/voices/$voiceUuid/recordings');
    final uploadReq = http.MultipartRequest('POST', uploadUri);
    uploadReq.headers['Authorization'] = 'Bearer $apiKey';
    uploadReq.fields['name'] = p.basename(sampleAudioPath);
    uploadReq.fields['text'] = transcript.trim().isEmpty ? '用于创建语音克隆的授权声音样本。' : transcript.trim();
    uploadReq.fields['emotion'] = 'neutral';
    uploadReq.fields['is_active'] = 'true';
    uploadReq.files.add(await http.MultipartFile.fromPath('file', sampleAudioPath));
    final uploadStreamed = await uploadReq.send().timeout(const Duration(seconds: 120));
    final uploadBody = await uploadStreamed.stream.bytesToString();
    if (uploadStreamed.statusCode < 200 || uploadStreamed.statusCode >= 300) {
      throw StateError('Resemble 上传样本失败：HTTP ${uploadStreamed.statusCode} $uploadBody');
    }

    final buildUri = Uri.parse('https://app.resemble.ai/api/v2/voices/$voiceUuid/build');
    final buildResp = await http
        .post(buildUri, headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}, body: jsonEncode({'fill': false}))
        .timeout(const Duration(seconds: 60));
    if (buildResp.statusCode < 200 || buildResp.statusCode >= 300) {
      throw StateError('Resemble 启动训练失败：HTTP ${buildResp.statusCode} ${buildResp.body}');
    }

    return addManualVoiceProfile(
      provider: 'resemble',
      displayName: displayName.trim().isEmpty ? 'Resemble 克隆声音' : displayName.trim(),
      externalVoiceId: voiceUuid,
      language: language,
      makeDefault: makeDefault,
    );
  }

  Future<VoiceProfile> createMiniMaxVoiceClone({
    required String displayName,
    required String sampleAudioPath,
    String customVoiceId = '',
    String promptAudioPath = '',
    String promptText = '',
    String previewText = '现在，慢慢闭上眼睛。把注意力放在你的呼吸上。',
    String model = VoiceProviderSettings.defaultMiniMaxModel,
    bool makeDefault = true,
  }) async {
    final apiKey = (await _kvDao.getString(VoiceProviderSettings.minimaxApiKey) ?? '').trim();
    if (apiKey.isEmpty) throw StateError('请先填写 MiniMax API Key');
    final source = File(sampleAudioPath);
    if (!await source.exists()) throw StateError('MiniMax 克隆声音样本文件不存在');
    final voiceId = customVoiceId.trim().isEmpty ? 'qapp_${DateTime.now().millisecondsSinceEpoch}' : customVoiceId.trim();

    final sourceFileId = await _uploadMiniMaxFile(apiKey: apiKey, filePath: sampleAudioPath, purpose: 'voice_clone');
    String? promptFileId;
    if (promptAudioPath.trim().isNotEmpty && await File(promptAudioPath).exists()) {
      promptFileId = await _uploadMiniMaxFile(apiKey: apiKey, filePath: promptAudioPath, purpose: 'prompt_audio');
    }
    final cloneUri = Uri.parse('https://api.minimax.io/v1/voice_clone');
    final payload = <String, dynamic>{
      'file_id': sourceFileId,
      'voice_id': voiceId,
      'text': previewText.trim().isEmpty ? '现在，慢慢闭上眼睛。把注意力放在你的呼吸上。' : previewText.trim(),
      'model': model.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxModel : model.trim(),
    };
    if (promptFileId != null) {
      payload['clone_prompt'] = <String, dynamic>{
        'prompt_audio': promptFileId,
        'prompt_text': promptText.trim().isEmpty ? 'This voice sounds natural, calm, and pleasant.' : promptText.trim(),
      };
    }
    final resp = await http
        .post(cloneUri, headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('MiniMax 克隆声音失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    return addManualVoiceProfile(
      provider: 'minimax',
      displayName: displayName.trim().isEmpty ? 'MiniMax 克隆声音' : displayName.trim(),
      externalVoiceId: voiceId,
      language: 'zh',
      makeDefault: makeDefault,
    );
  }

  Future<TtsAudioFile> synthesizeResembleAndSave({
    required String text,
    required String voiceUuid,
    String voiceDisplayName = '',
    String? voiceProfileId,
    String moduleName = 'voice_lab_resemble_tts',
    String model = VoiceProviderSettings.defaultResembleModel,
    String outputFormat = VoiceProviderSettings.defaultResembleOutputFormat,
    String precision = VoiceProviderSettings.defaultResemblePrecision,
    int sampleRate = 48000,
    bool useHd = false,
    bool applyCustomPronunciations = false,
    double speed = 1.0,
    String scene = 'natural_dialogue',
    bool meditationAutoPauses = false,
    String meditationPauseProfile = 'standard',
    double meditationSentenceBreakSec = 1.5,
    double meditationParagraphBreakSec = 2.4,
    double meditationBreathBreakSec = 2.0,
    String meditationTone = 'calm',
    bool meditationAutoBreathPauses = true,
    String resembleMeditationMode = VoiceProviderSettings.defaultResembleMeditationMode,
    bool resembleMeditationUsePrompt = true,
    String resembleMeditationPrompt = VoiceProviderSettings.defaultResembleMeditationPrompt,
    double resembleMeditationMaxBreakSec = VoiceProviderSettings.defaultResembleMeditationMaxBreakSec,
    bool resembleMeditationSplitLongBreaks = true,
    bool forceRegenerate = false,
  }) async {
    final cleanText = text.trim();
    final cleanVoice = voiceUuid.trim();
    if (cleanText.isEmpty) throw StateError('请输入需要转换成语音的文字');
    if (cleanVoice.isEmpty) throw StateError('请填写或选择 Resemble voice_uuid');
    final apiKey = (await _kvDao.getString(VoiceProviderSettings.resembleApiKey) ?? '').trim();
    if (apiKey.isEmpty) throw StateError('请先填写 Resemble AI API Token');
    final finalText = _prepareResembleText(
      cleanText,
      speed: speed,
      scene: scene,
      autoPauses: meditationAutoPauses,
      sentenceBreakSec: meditationSentenceBreakSec,
      paragraphBreakSec: meditationParagraphBreakSec,
      breathBreakSec: meditationBreathBreakSec,
      autoBreathPauses: meditationAutoBreathPauses,
      tone: meditationTone,
      resembleMode: resembleMeditationMode,
      resembleUsePrompt: resembleMeditationUsePrompt,
      resemblePrompt: resembleMeditationPrompt,
      resembleMaxBreakSec: resembleMeditationMaxBreakSec,
      resembleSplitLongBreaks: resembleMeditationSplitLongBreaks,
    );
    final cacheParts = <Object?>['resemble', cleanText, cleanVoice, model, outputFormat, precision, sampleRate, useHd, applyCustomPronunciations, speed, scene, meditationAutoPauses, meditationPauseProfile, meditationSentenceBreakSec, meditationParagraphBreakSec, meditationBreathBreakSec, meditationTone, meditationAutoBreathPauses, resembleMeditationMode, resembleMeditationUsePrompt, resembleMeditationPrompt, resembleMeditationMaxBreakSec, resembleMeditationSplitLongBreaks];
    final textHash = sha256.convert(utf8.encode(cacheParts.join('|'))).toString();
    if (!forceRegenerate && await isCacheEnabled()) {
      final cached = await _voiceDao.findCachedAudioByVoiceKey(textHash, voiceProfileId ?? cleanVoice);
      if (cached != null && File(cached.audioFilePath).existsSync()) return cached;
    }
    final uri = Uri.parse('https://f.cluster.resemble.ai/synthesize');
    final effectiveOutputFormat = outputFormat.trim().isEmpty ? 'mp3' : outputFormat.trim().toLowerCase();
    final selectedModel = _normalizeResembleModel(model);
    final body = _buildResembleSynthesisBody(
      voiceUuid: cleanVoice,
      data: finalText,
      outputFormat: effectiveOutputFormat,
      precision: precision,
      sampleRate: sampleRate,
      useHd: useHd,
      applyCustomPronunciations: applyCustomPronunciations,
      model: selectedModel,
    );
    var resp = await _postResembleSynthesize(uri, apiKey, body);

    // Resemble may return HTTP 500 for unsupported combinations such as old/invalid model ids,
    // MP3 + WAV precision, or prosody-heavy SSML on Chatterbox voices. Retry once with a
    // minimal plain-text payload so users can distinguish real account/voice problems from
    // parameter incompatibility.
    if (resp.statusCode >= 500 && (finalText != cleanText || body.length > 3)) {
      final fallbackBody = <String, dynamic>{
        'voice_uuid': cleanVoice,
        'data': cleanText,
        'output_format': effectiveOutputFormat,
      };
      resp = await _postResembleSynthesize(uri, apiKey, fallbackBody, retry: true);
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw StateError('Resemble TTS 未授权：当前 Token 无效，或无权使用 voice_uuid=$cleanVoice。请在配置页重新查询并选择当前 Token 返回的声音。');
      }
      throw StateError('Resemble TTS 失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    final bytes = _extractResembleAudioBytes(resp);
    return _saveAudioBytes(
      bytes: bytes,
      provider: 'resemble',
      voiceId: cleanVoice,
      voiceProfileId: voiceProfileId,
      voiceDisplayName: voiceDisplayName,
      voiceSource: voiceProfileId == null ? 'resemble_manual' : 'cloned',
      moduleName: moduleName,
      sourceText: cleanText,
      textHash: textHash,
      modelId: model.trim().isEmpty ? 'resemble_default' : model,
      extension: effectiveOutputFormat == 'wav' ? 'wav' : 'mp3',
      mimeType: effectiveOutputFormat == 'wav' ? 'audio/wav' : 'audio/mpeg',
      speed: speed,
      scene: scene,
      meditationAutoPauses: meditationAutoPauses,
      meditationPauseProfile: meditationPauseProfile,
      meditationSentenceBreakSec: meditationSentenceBreakSec,
      meditationParagraphBreakSec: meditationParagraphBreakSec,
      meditationBreathBreakSec: meditationBreathBreakSec,
      meditationTone: meditationTone,
      meditationAutoBreathPauses: meditationAutoBreathPauses,
    );
  }

  Future<TtsAudioFile> synthesizeMiniMaxAndSave({
    required String text,
    required String voiceId,
    String voiceDisplayName = '',
    String? voiceProfileId,
    String moduleName = 'voice_lab_minimax_tts',
    String model = VoiceProviderSettings.defaultMiniMaxModel,
    String endpoint = VoiceProviderSettings.defaultMiniMaxEndpoint,
    double speed = 1.0,
    double volume = 1.0,
    int pitch = 0,
    String emotion = 'calm',
    String languageBoost = 'auto',
    bool textNormalization = true,
    String format = 'mp3',
    int sampleRate = 32000,
    int bitrate = 128000,
    int channel = 1,
    String soundEffects = '',
    int voiceModifyPitch = 0,
    int voiceModifyIntensity = 0,
    int voiceModifyTimbre = 0,
    String scene = 'natural_dialogue',
    bool meditationAutoPauses = false,
    String meditationPauseProfile = 'standard',
    double meditationSentenceBreakSec = 1.5,
    double meditationParagraphBreakSec = 2.4,
    double meditationBreathBreakSec = 2.0,
    String meditationTone = 'calm',
    bool meditationAutoBreathPauses = true,
    bool forceRegenerate = false,
  }) async {
    final cleanText = text.trim();
    final cleanVoice = voiceId.trim();
    if (cleanText.isEmpty) throw StateError('请输入需要转换成语音的文字');
    if (cleanVoice.isEmpty) throw StateError('请填写或选择 MiniMax voice_id');
    final apiKey = (await _kvDao.getString(VoiceProviderSettings.minimaxApiKey) ?? '').trim();
    if (apiKey.isEmpty) throw StateError('请先填写 MiniMax API Key');
    final finalText = _prepareMiniMaxText(
      cleanText,
      scene: scene,
      autoPauses: meditationAutoPauses,
      sentenceBreakSec: meditationSentenceBreakSec,
      paragraphBreakSec: meditationParagraphBreakSec,
      breathBreakSec: meditationBreathBreakSec,
      autoBreathPauses: meditationAutoBreathPauses,
      tone: meditationTone,
    );
    final effectiveModel = model.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxModel : model.trim();
    final effectiveEndpoint = endpoint.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxEndpoint : endpoint.trim();
    final effectiveFormat = format.trim().isEmpty ? 'mp3' : format.trim();
    final cacheParts = <Object?>['minimax', cleanText, cleanVoice, effectiveModel, effectiveEndpoint, speed, volume, pitch, emotion, languageBoost, textNormalization, effectiveFormat, sampleRate, bitrate, channel, soundEffects, voiceModifyPitch, voiceModifyIntensity, voiceModifyTimbre, scene, meditationAutoPauses, meditationPauseProfile, meditationSentenceBreakSec, meditationParagraphBreakSec, meditationBreathBreakSec, meditationTone, meditationAutoBreathPauses];
    final textHash = sha256.convert(utf8.encode(cacheParts.join('|'))).toString();
    if (!forceRegenerate && await isCacheEnabled()) {
      final cached = await _voiceDao.findCachedAudioByVoiceKey(textHash, voiceProfileId ?? cleanVoice);
      if (cached != null && File(cached.audioFilePath).existsSync()) return cached;
    }

    final body = <String, dynamic>{
      'model': effectiveModel,
      'text': finalText,
      'stream': false,
      'language_boost': languageBoost.trim().isEmpty ? 'auto' : languageBoost.trim(),
      'output_format': 'hex',
      'voice_setting': <String, dynamic>{
        'voice_id': cleanVoice,
        'speed': speed.clamp(0.5, 2.0),
        'vol': volume.clamp(0.0, 10.0),
        'pitch': pitch.clamp(-12, 12),
        'english_normalization': textNormalization,
      },
      'audio_setting': <String, dynamic>{
        'sample_rate': sampleRate,
        'bitrate': bitrate,
        'format': effectiveFormat,
        'channel': channel,
      },
    };
    if (emotion.trim().isNotEmpty && emotion != 'none') {
      (body['voice_setting'] as Map<String, dynamic>)['emotion'] = emotion.trim();
    }
    if (soundEffects.trim().isNotEmpty || voiceModifyPitch != 0 || voiceModifyIntensity != 0 || voiceModifyTimbre != 0) {
      body['voice_modify'] = <String, dynamic>{
        'pitch': voiceModifyPitch,
        'intensity': voiceModifyIntensity,
        'timbre': voiceModifyTimbre,
        if (soundEffects.trim().isNotEmpty) 'sound_effects': soundEffects.trim(),
      };
    }

    final uri = Uri.parse(effectiveEndpoint);
    final selectedModel = model.trim().isEmpty || model.trim().toLowerCase() == 'auto' ? '' : model.trim();
    if (selectedModel.isNotEmpty) body['model'] = selectedModel;
    final resp = await http
        .post(uri, headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 180));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('MiniMax TTS 失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final baseResp = decoded['base_resp'];
    if (baseResp is Map && (baseResp['status_code'] ?? 0) is num && (baseResp['status_code'] as num).toInt() != 0) {
      throw StateError('MiniMax TTS 失败：${baseResp['status_msg'] ?? resp.body}');
    }
    final data = decoded['data'];
    final hexAudio = data is Map ? (data['audio'] ?? '').toString() : '';
    if (hexAudio.isEmpty) throw StateError('MiniMax 未返回 data.audio：${resp.body}');
    final bytes = _decodeHex(hexAudio);
    return _saveAudioBytes(
      bytes: bytes,
      provider: 'minimax',
      voiceId: cleanVoice,
      voiceProfileId: voiceProfileId,
      voiceDisplayName: voiceDisplayName,
      voiceSource: voiceProfileId == null ? 'minimax_system' : 'cloned',
      moduleName: moduleName,
      sourceText: cleanText,
      textHash: textHash,
      modelId: effectiveModel,
      extension: effectiveFormat,
      mimeType: effectiveFormat == 'wav' ? 'audio/wav' : (effectiveFormat == 'flac' ? 'audio/flac' : 'audio/mpeg'),
      speed: speed,
      scene: scene,
      meditationAutoPauses: meditationAutoPauses,
      meditationPauseProfile: meditationPauseProfile,
      meditationSentenceBreakSec: meditationSentenceBreakSec,
      meditationParagraphBreakSec: meditationParagraphBreakSec,
      meditationBreathBreakSec: meditationBreathBreakSec,
      meditationTone: meditationTone,
      meditationAutoBreathPauses: meditationAutoBreathPauses,
    );
  }


  static String _normalizeResembleModel(String model) {
    final raw = model.trim().toLowerCase();
    if (raw.isEmpty || raw == 'auto' || raw == 'chatterbox' || raw == 'tts-v4') return '';
    if (raw == 'chatterbox-turbo' || raw == 'tts-v4-turbo') return 'chatterbox-turbo';
    // Unknown model ids are intentionally omitted. Unsupported model values can trigger
    // provider-side 500 errors on Resemble, while omitting the field is the documented safe path.
    return '';
  }

  static Map<String, dynamic> _buildResembleSynthesisBody({
    required String voiceUuid,
    required String data,
    required String outputFormat,
    required String precision,
    required int sampleRate,
    required bool useHd,
    required bool applyCustomPronunciations,
    required String model,
  }) {
    final body = <String, dynamic>{
      'voice_uuid': voiceUuid,
      'data': data,
      'output_format': outputFormat == 'wav' ? 'wav' : 'mp3',
    };
    // precision is only meaningful for WAV. Sending it with MP3 can fail on some accounts.
    if (body['output_format'] == 'wav') {
      final p = precision.trim().isEmpty ? VoiceProviderSettings.defaultResemblePrecision : precision.trim();
      if (const {'MULAW', 'PCM_16', 'PCM_24', 'PCM_32'}.contains(p)) body['precision'] = p;
    }
    if (const {8000, 16000, 22050, 24000, 44100, 48000}.contains(sampleRate)) {
      body['sample_rate'] = sampleRate;
    }
    if (useHd) body['use_hd'] = true;
    if (applyCustomPronunciations) body['apply_custom_pronunciations'] = true;
    if (model.isNotEmpty) body['model'] = model;
    return body;
  }


  static List<int> _extractResembleAudioBytes(http.Response resp) {
    final contentType = (resp.headers['content-type'] ?? resp.headers['Content-Type'] ?? '').toLowerCase();
    final rawText = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();

    // Some gateways / account modes may return raw audio bytes instead of JSON.
    if (contentType.startsWith('audio/') || _looksLikeAudioBytes(resp.bodyBytes)) {
      return resp.bodyBytes;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawText);
    } catch (_) {
      decoded = null;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map['success'] == false) {
        throw StateError('Resemble TTS 失败：${map['message'] ?? rawText}');
      }
      final audioContent = _findStringValue(map, const [
        'audio_content',
        'audioContent',
        'audio',
        'data',
        'base64',
      ]);
      if (audioContent == null || audioContent.trim().isEmpty) {
        throw StateError('Resemble 未返回 audio_content：${_shortBody(rawText)}');
      }
      return _decodePossibleBase64Audio(audioContent, originalBodyBytes: resp.bodyBytes);
    }

    if (decoded is String && decoded.trim().isNotEmpty) {
      return _decodePossibleBase64Audio(decoded, originalBodyBytes: resp.bodyBytes);
    }

    // Resemble docs state synchronous synthesis returns JSON with audio_content, but in
    // practice some responses can be a bare base64 string such as "SUQz..." for MP3.
    // Accept that form so the app can still save/play the generated audio.
    if (rawText.isNotEmpty) {
      return _decodePossibleBase64Audio(rawText, originalBodyBytes: resp.bodyBytes);
    }
    throw StateError('Resemble TTS 返回为空');
  }

  static String? _findStringValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is Map) {
        final nested = _findStringValue(Map<String, dynamic>.from(value), keys);
        if (nested != null && nested.trim().isNotEmpty) return nested;
      }
    }
    return null;
  }

  static List<int> _decodePossibleBase64Audio(String value, {required List<int> originalBodyBytes}) {
    var raw = value.trim();
    if (raw.startsWith('data:')) {
      final comma = raw.indexOf(',');
      if (comma >= 0) raw = raw.substring(comma + 1);
    }
    // Remove optional JSON quotes and all whitespace/newlines. Do not show the full value in
    // errors because it can be a very long audio payload.
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      raw = raw.substring(1, raw.length - 1);
    }
    raw = raw.replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) throw StateError('Resemble 返回的音频内容为空');

    List<int>? tryDecode(String candidate) {
      try {
        return base64Decode(_padBase64(candidate));
      } catch (_) {
        try {
          return base64Url.decode(_padBase64(candidate.replaceAll('+', '-').replaceAll('/', '_')));
        } catch (_) {
          return null;
        }
      }
    }

    final decoded = tryDecode(raw);
    if (decoded != null && decoded.isNotEmpty) return decoded;

    // If the body is already binary audio but the server omitted an audio content-type,
    // preserve it rather than failing with a base64 FormatException.
    if (_looksLikeAudioBytes(originalBodyBytes)) return originalBodyBytes;
    throw StateError('Resemble 返回的音频不是有效 base64，开头：${_shortBody(raw)}');
  }

  static String _padBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) return value;
    return value + List.filled(4 - remainder, '=').join();
  }

  static bool _looksLikeAudioBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    // MP3 with ID3 header
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return true;
    // MP3 frame sync
    if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) return true;
    // WAV RIFF
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    // FLAC
    if (bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43) return true;
    // Ogg
    if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) return true;
    return false;
  }

  static Future<http.Response> _postResembleSynthesize(
    Uri uri,
    String apiKey,
    Map<String, dynamic> body, {
    bool retry = false,
  }) async {
    await DeepSeekLogger.logRequest(
      provider: 'Resemble AI',
      module: retry ? 'voice_lab.resemble.tts_retry_minimal' : 'voice_lab.resemble.tts',
      endpoint: uri.toString(),
      method: 'POST',
      model: (body['model'] ?? 'auto').toString(),
      headers: const {'Authorization': 'Bearer ***REDACTED***', 'Content-Type': 'application/json'},
      body: <String, dynamic>{
        ...body,
        'data': _shortBody((body['data'] ?? '').toString()),
      },
    );
    final resp = await http
        .post(uri, headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 120));
    await DeepSeekLogger.logResponse(
      provider: 'Resemble AI',
      module: retry ? 'voice_lab.resemble.tts_retry_minimal' : 'voice_lab.resemble.tts',
      endpoint: uri.toString(),
      model: (body['model'] ?? 'auto').toString(),
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    return resp;
  }

  Future<String> _uploadMiniMaxFile({required String apiKey, required String filePath, required String purpose}) async {
    final f = File(filePath);
    if (!await f.exists()) throw StateError('MiniMax 上传文件不存在：$filePath');
    final uri = Uri.parse('https://api.minimax.io/v1/files/upload');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $apiKey';
    req.fields['purpose'] = purpose;
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError('MiniMax 文件上传失败：HTTP ${streamed.statusCode} $body');
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final file = decoded['file'];
    final fileId = file is Map ? (file['file_id'] ?? '').toString() : '';
    if (fileId.isEmpty) throw StateError('MiniMax 上传未返回 file_id：$body');
    return fileId;
  }

  Future<TtsAudioFile> _saveAudioBytes({
    required List<int> bytes,
    required String provider,
    required String voiceId,
    String? voiceProfileId,
    required String voiceDisplayName,
    required String voiceSource,
    required String moduleName,
    required String sourceText,
    required String textHash,
    required String modelId,
    required String extension,
    required String mimeType,
    required double speed,
    required String scene,
    required bool meditationAutoPauses,
    required String meditationPauseProfile,
    required double meditationSentenceBreakSec,
    required double meditationParagraphBreakSec,
    required double meditationBreathBreakSec,
    required String meditationTone,
    required bool meditationAutoBreathPauses,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final ttsDir = Directory(p.join(docs.path, 'tts_audio'));
    if (!await ttsDir.exists()) await ttsDir.create(recursive: true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeModule = moduleName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    final ext = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').isEmpty ? 'mp3' : extension.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '');
    final fileName = 'tts_${provider}_${safeModule}_$now.$ext';
    final file = File(p.join(ttsDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    final audio = TtsAudioFile(
      id: voiceLabUid('tts'),
      moduleName: moduleName,
      sourceText: sourceText,
      textHash: textHash,
      provider: provider,
      elevenlabsVoiceId: voiceId,
      voiceProfileId: voiceProfileId,
      modelId: modelId,
      audioFileName: fileName,
      audioFilePath: file.path,
      mimeType: mimeType,
      fileSize: await file.length(),
      voiceSource: voiceSource,
      voiceDisplayName: voiceDisplayName,
      ttsSpeed: speed,
      scene: scene,
      meditationAutoPauses: meditationAutoPauses,
      meditationPauseProfile: meditationPauseProfile,
      meditationSentenceBreakSec: meditationSentenceBreakSec,
      meditationParagraphBreakSec: meditationParagraphBreakSec,
      meditationBreathBreakSec: meditationBreathBreakSec,
      meditationTone: meditationTone,
      meditationAutoBreathPauses: meditationAutoBreathPauses,
      createdAt: now,
      updatedAt: now,
    );
    if (await isAutoSaveEnabled()) await _voiceDao.insertTtsAudio(audio);
    return audio;
  }

  static String _prepareResembleText(
    String text, {
    required double speed,
    required String scene,
    required bool autoPauses,
    required double sentenceBreakSec,
    required double paragraphBreakSec,
    required double breathBreakSec,
    required bool autoBreathPauses,
    required String tone,
    required String resembleMode,
    required bool resembleUsePrompt,
    required String resemblePrompt,
    required double resembleMaxBreakSec,
    required bool resembleSplitLongBreaks,
  }) {
    // Resemble Chatterbox voices are usually selected by voice_uuid. For meditation, the
    // most reliable control is: carefully inserted SSML breaks + an optional voice direction
    // prompt. We intentionally avoid <prosody> because it can trigger provider errors on
    // some Chatterbox voices; speed is expressed through the prompt and pause structure.
    var result = text.trim();
    if (scene == 'meditation_relax') {
      final mode = resembleMode.trim().isEmpty ? VoiceProviderSettings.defaultResembleMeditationMode : resembleMode.trim();
      final allowSsmlBreaks = mode != 'plain_prompt';
      if (autoPauses && allowSsmlBreaks) {
        result = _applySsmlBreaks(
          result,
          sentenceBreakSec: sentenceBreakSec,
          paragraphBreakSec: paragraphBreakSec,
          breathBreakSec: breathBreakSec,
          autoBreathPauses: autoBreathPauses,
          maxBreakSec: resembleMaxBreakSec,
          splitLongBreaks: resembleSplitLongBreaks,
        );
      }
      if (!result.startsWith('<speak')) {
        final usePromptForMode = mode != 'breaks_only' && resembleUsePrompt;
        final prompt = usePromptForMode
            ? (resemblePrompt.trim().isEmpty ? _resembleMeditationPrompt(tone) : resemblePrompt.trim())
            : '';
        final promptAttr = prompt.isEmpty ? '' : ' prompt="${_xmlEscape(prompt)}"';
        if (allowSsmlBreaks || promptAttr.isNotEmpty) {
          result = '<speak$promptAttr>$result</speak>';
        }
      }
    }
    return result;
  }

  static String _prepareMiniMaxText(
    String text, {
    required String scene,
    required bool autoPauses,
    required double sentenceBreakSec,
    required double paragraphBreakSec,
    required double breathBreakSec,
    required bool autoBreathPauses,
    required String tone,
  }) {
    var result = text.trim();
    if (scene == 'meditation_relax' && autoPauses) {
      result = _applyMiniMaxBreaks(result, sentenceBreakSec: sentenceBreakSec, paragraphBreakSec: paragraphBreakSec, breathBreakSec: breathBreakSec, autoBreathPauses: autoBreathPauses);
    }
    if (scene == 'meditation_relax') {
      final tag = tone == 'whisper' ? '(breath)' : '(sighs)';
      if (!result.startsWith('(')) result = '$tag $result';
    }
    return result;
  }


  static String _ssmlRate(double speed, {required bool meditation}) {
    final v = speed.clamp(0.5, 2.0).toDouble();
    if (meditation && v > 0.92) return 'slow';
    if (v <= 0.75) return 'x-slow';
    if (v < 0.95) return 'slow';
    if (v <= 1.08) return 'medium';
    if (v <= 1.25) return 'fast';
    return 'x-fast';
  }

  static String _resembleMeditationPrompt(String tone) {
    return switch (tone) {
      'whisper' => 'whispering Chinese meditation guide, very slow breathy delivery, intimate but clear, long spacious pauses, no excitement',
      'soft' => 'soft gentle Chinese meditation guide, slow and reassuring, light breath, smooth phrasing, spacious pauses',
      'warm' => 'warm comforting Chinese meditation guide, slow stable tone, gentle encouragement, soothing and safe',
      'healing' => 'healing mindful Chinese meditation guide, calm therapeutic tone, slow breath rhythm, spacious silence, sleep-friendly',
      _ => 'calm peaceful Chinese mindfulness meditation guide, slow stable voice, soft tone, long pauses, relaxed breathing rhythm',
    };
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _applySsmlBreaks(String text, {required double sentenceBreakSec, required double paragraphBreakSec, required double breathBreakSec, required bool autoBreathPauses, required double maxBreakSec, bool splitLongBreaks = false}) {
    String tag(double seconds) => _ssmlBreakTag(seconds, maxBreakSec: maxBreakSec, splitLongBreaks: splitLongBreaks);
    var result = text
        .split(RegExp(r'\n{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ${tag(paragraphBreakSec)}\n\n');
    result = result.replaceAllMapped(RegExp(r'([。！？!?；;])(?=\s*[^<\n])'), (m) => '${m.group(1)} ${tag(sentenceBreakSec)}');
    if (autoBreathPauses) {
      result = result.replaceAllMapped(RegExp(r'(吸气|呼气|深吸一口气|慢慢吸气|慢慢呼气|闭上眼睛|放松肩膀)([。！？!?,，、]?)'), (m) => '${m.group(1)}${m.group(2)} ${tag(breathBreakSec)}');
    }
    return result;
  }

  static String _ssmlBreakTag(double seconds, {required double maxBreakSec, required bool splitLongBreaks}) {
    final maxSingle = _clampPause(maxBreakSec, 10.0).clamp(0.3, 10.0).toDouble();
    var remaining = _clampPause(seconds, 60.0).clamp(0.01, 60.0).toDouble();
    if (!splitLongBreaks || remaining <= maxSingle) {
      return '<break time="${remaining.clamp(0.01, maxSingle).toStringAsFixed(2)}s" />';
    }
    final parts = <String>[];
    while (remaining > maxSingle + 0.05 && parts.length < 200) {
      parts.add('<break time="${maxSingle.toStringAsFixed(2)}s" />');
      remaining -= maxSingle;
    }
    if (remaining > 0.05) parts.add('<break time="${remaining.toStringAsFixed(2)}s" />');
    return parts.join(' ');
  }

  static String _applyMiniMaxBreaks(String text, {required double sentenceBreakSec, required double paragraphBreakSec, required double breathBreakSec, required bool autoBreathPauses}) {
    String tag(double seconds) => '<#${_clampPause(seconds, 99.99).toStringAsFixed(2)}#>';
    var result = text
        .split(RegExp(r'\n{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ${tag(paragraphBreakSec)}\n\n');
    result = result.replaceAllMapped(RegExp(r'([。！？!?；;])(?=\s*[^<\n])'), (m) => '${m.group(1)} ${tag(sentenceBreakSec)}');
    if (autoBreathPauses) {
      result = result.replaceAllMapped(RegExp(r'(吸气|呼气|深吸一口气|慢慢吸气|慢慢呼气|闭上眼睛|放松肩膀)([。！？!?,，、]?)'), (m) => '${m.group(1)}${m.group(2)} ${tag(breathBreakSec)}');
    }
    return result;
  }

  static double _clampPause(double seconds, double max) {
    if (seconds.isNaN || seconds.isInfinite) return 1.5;
    return seconds.clamp(0.01, max).toDouble();
  }

  static List<int> _decodeHex(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.length.isOdd) throw StateError('MiniMax 返回的 hex 音频长度异常');
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static String _extractResembleVoiceUuid(Map<String, dynamic> json) {
    final item = json['item'];
    if (item is Map) return (item['uuid'] ?? item['id'] ?? '').toString();
    return (json['uuid'] ?? json['id'] ?? '').toString();
  }

  static String _normalizeProvider(String provider) {
    final p = provider.trim().toLowerCase();
    if (p == 'resemble' || p == 'minimax' || p == 'elevenlabs') return p;
    return 'elevenlabs';
  }

  static String _providerName(String provider) {
    return switch (_normalizeProvider(provider)) {
      'resemble' => 'Resemble AI 声音',
      'minimax' => 'MiniMax 声音',
      _ => 'ElevenLabs 声音',
    };
  }

  static String _shortBody(String body) {
    if (body.length <= 1200) return body;
    return '${body.substring(0, 1200)}...(truncated)';
  }
}
