import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/kv_dao.dart';
import '../voice_lab/eleven_labs_service.dart';
import '../voice_lab/multi_provider_tts_service.dart';
import '../voice_lab/voice_lab_dao.dart';
import 'global_ai_settings.dart';

class ReadAloudSettings {
  static const providerKey = 'read_aloud.provider';
  static const defaultProvider = 'microsoft';

  static const providers = <String, String>{
    'microsoft': 'Microsoft Azure Speech',
    'iflytek': '讯飞语音',
    'elevenlabs': 'ElevenLabs',
    'xai': 'xAI',
  };
}

class ReadAloudAvailability {
  const ReadAloudAvailability({
    required this.provider,
    required this.providerLabel,
    required this.available,
    required this.reason,
  });

  final String provider;
  final String providerLabel;
  final bool available;
  final String reason;
}

/// Unified reader used by Will Laboratory and other long-form pages.
///
/// Azure / iFlytek / ElevenLabs reuse the credentials and voice choices from
/// “语音与美好的祝福配置”. xAI deliberately reads the global xAI key so there is
/// no second API-key field to keep in sync.
class ReadAloudService {
  ReadAloudService({
    KeyValueDao? kvDao,
    GlobalAiSettings? globalAiSettings,
    MultiProviderTtsService? multiProvider,
    ElevenLabsService? elevenLabs,
    VoiceLabDao? voiceLabDao,
  }) : _kv = kvDao ?? KeyValueDao(),
       _globalAi = globalAiSettings ?? GlobalAiSettings(),
       _multiProvider = multiProvider ?? MultiProviderTtsService(),
       _elevenLabs = elevenLabs ?? ElevenLabsService(),
       _voiceLabDao = voiceLabDao ?? VoiceLabDao();

  final KeyValueDao _kv;
  final GlobalAiSettings _globalAi;
  final MultiProviderTtsService _multiProvider;
  final ElevenLabsService _elevenLabs;
  final VoiceLabDao _voiceLabDao;

  Future<String> getProvider() async {
    var value = (await _kv.getString(ReadAloudSettings.providerKey) ?? '')
        .trim()
        .toLowerCase();
    if (value.isEmpty) {
      // 首次升级沿用“语音与美好的祝福”当前选择，避免用户已经配置讯飞或
      // ElevenLabs，却被新的朗读入口默认切换到尚未配置的 Azure。
      value =
          (await _kv.getString(VoiceProviderSettings.provider) ??
                  ReadAloudSettings.defaultProvider)
              .trim()
              .toLowerCase();
    }
    return ReadAloudSettings.providers.containsKey(value)
        ? value
        : ReadAloudSettings.defaultProvider;
  }

  Future<void> setProvider(String provider) async {
    final value = provider.trim().toLowerCase();
    if (!ReadAloudSettings.providers.containsKey(value)) {
      throw ArgumentError.value(provider, 'provider', '不支持的朗读服务商');
    }
    await _kv.setString(ReadAloudSettings.providerKey, value);
  }

  Future<ReadAloudAvailability> availability([
    String? requestedProvider,
  ]) async {
    final provider = requestedProvider ?? await getProvider();
    final label = ReadAloudSettings.providers[provider] ?? provider;
    switch (provider) {
      case 'microsoft':
        final key =
            (await _kv.getString(VoiceProviderSettings.microsoftApiKey) ?? '')
                .trim();
        return ReadAloudAvailability(
          provider: provider,
          providerLabel: label,
          available: key.isNotEmpty,
          reason: key.isEmpty
              ? '请先在“语音与美好的祝福配置”填写 Microsoft Speech API Key'
              : '使用共享的 Azure Speech 配置',
        );
      case 'iflytek':
        final appId =
            (await _kv.getString(VoiceProviderSettings.iflytekAppId) ?? '')
                .trim();
        final key =
            (await _kv.getString(VoiceProviderSettings.iflytekApiKey) ?? '')
                .trim();
        final secret =
            (await _kv.getString(VoiceProviderSettings.iflytekApiSecret) ?? '')
                .trim();
        final ok = appId.isNotEmpty && key.isNotEmpty && secret.isNotEmpty;
        return ReadAloudAvailability(
          provider: provider,
          providerLabel: label,
          available: ok,
          reason: ok
              ? '使用共享的讯飞 TTS 配置'
              : '请先在“语音与美好的祝福配置”填写讯飞 AppID、APIKey 和 APISecret',
        );
      case 'elevenlabs':
        final key = await _elevenLabs.getApiKey();
        return ReadAloudAvailability(
          provider: provider,
          providerLabel: label,
          available: key.isNotEmpty,
          reason: key.isEmpty
              ? '请先在“语音与美好的祝福配置”填写 ElevenLabs API Key'
              : '使用共享的 ElevenLabs 声音与模型配置',
        );
      case 'xai':
        final key = await _globalAi.getXGrokKey();
        return ReadAloudAvailability(
          provider: provider,
          providerLabel: label,
          available: key.isNotEmpty,
          reason: key.isEmpty
              ? '请先在设置页的全局 AI 中填写 xAI API Key'
              : '使用全局 xAI API Key',
        );
      default:
        return ReadAloudAvailability(
          provider: provider,
          providerLabel: label,
          available: false,
          reason: '暂不支持该朗读服务商',
        );
    }
  }

  Future<List<String>> synthesize({
    required String text,
    String moduleName = 'read_aloud',
    String? provider,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) throw StateError('没有可朗读的文字');
    final selected = provider ?? await getProvider();
    final state = await availability(selected);
    if (!state.available) throw StateError(state.reason);

    final chunks = _splitText(clean, maxChars: selected == 'xai' ? 7000 : 4000);
    final files = <String>[];
    for (var index = 0; index < chunks.length; index++) {
      files.add(
        await _synthesizeChunk(
          chunks[index],
          provider: selected,
          moduleName: moduleName,
          chunkIndex: index,
        ),
      );
    }
    return files;
  }

  Future<String> _synthesizeChunk(
    String text, {
    required String provider,
    required String moduleName,
    required int chunkIndex,
  }) async {
    final cacheDir = await _cacheDirectory();
    final hash = sha256.convert(utf8.encode('$provider|$text')).toString();
    final cached = File(p.join(cacheDir.path, '${provider}_$hash.mp3'));
    if (await cached.exists() && await cached.length() > 128)
      return cached.path;

    String generatedPath;
    switch (provider) {
      case 'microsoft':
        generatedPath = await _multiProvider.synthesizeMicrosoftToFile(
          text: text,
        );
        break;
      case 'iflytek':
        generatedPath = await _multiProvider.synthesizeIflytekToFile(
          text: text,
        );
        break;
      case 'elevenlabs':
        generatedPath = await _synthesizeElevenLabs(
          text,
          moduleName: moduleName,
        );
        break;
      case 'xai':
        return _synthesizeXai(text, cached);
      default:
        throw StateError('暂不支持该朗读服务商');
    }
    final source = File(generatedPath);
    if (!await source.exists()) throw StateError('朗读服务未生成音频文件');
    await source.copy(cached.path);
    return cached.path;
  }

  Future<String> _synthesizeElevenLabs(
    String text, {
    required String moduleName,
  }) async {
    final source =
        (await _kv.getString(ElevenLabsSettings.ttsVoiceSource) ?? 'premade')
            .trim();
    if (source == 'cloned') {
      final profile = await _voiceLabDao.getDefaultVoiceProfile();
      if (profile != null && profile.provider == 'elevenlabs') {
        final audio = await _elevenLabs.synthesizeAndSave(
          text: text,
          voiceProfile: profile,
          moduleName: moduleName,
          scene: 'long_form',
          stability: 0.76,
          similarityBoost: 0.78,
          style: 0.12,
          speed: 0.95,
        );
        return audio.audioFilePath;
      }
    }
    final voiceId =
        (await _kv.getString(ElevenLabsSettings.presetVoiceId) ??
                ElevenLabsSettings.defaultPresetVoiceId)
            .trim();
    final voiceName =
        (await _kv.getString(ElevenLabsSettings.presetVoiceName) ??
                ElevenLabsSettings.defaultPresetVoiceName)
            .trim();
    final audio = await _elevenLabs.synthesizeAndSaveByVoiceId(
      text: text,
      voiceId: voiceId.isEmpty
          ? ElevenLabsSettings.defaultPresetVoiceId
          : voiceId,
      voiceSource: 'premade',
      voiceDisplayName: voiceName,
      moduleName: moduleName,
      scene: 'long_form',
      stability: 0.76,
      similarityBoost: 0.78,
      style: 0.12,
      speed: 0.95,
    );
    return audio.audioFilePath;
  }

  Future<String> _synthesizeXai(String text, File output) async {
    final apiKey = await _globalAi.getXGrokKey();
    if (apiKey.isEmpty) throw StateError('请先在设置页填写 xAI API Key');
    final response = await http
        .post(
          Uri.parse('https://api.x.ai/v1/tts'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({'text': text, 'voice_id': 'eve', 'language': 'zh'}),
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'xAI 文字转语音失败：HTTP ${response.statusCode} ${_shortBody(response.body)}',
      );
    }
    if (response.bodyBytes.length < 128) throw StateError('xAI 文字转语音未返回有效音频');
    await output.writeAsBytes(response.bodyBytes, flush: true);
    return output.path;
  }

  Future<Directory> _cacheDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'read_aloud_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<String> _splitText(String text, {required int maxChars}) {
    if (text.length <= maxChars) return [text];
    final chunks = <String>[];
    var rest = text;
    while (rest.length > maxChars) {
      var cut = maxChars;
      final floor = (maxChars * 0.55).round();
      for (var i = maxChars; i >= floor; i--) {
        if ('。！？!?；;\n'.contains(rest[i - 1])) {
          cut = i;
          break;
        }
      }
      chunks.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trimLeft();
    }
    if (rest.trim().isNotEmpty) chunks.add(rest.trim());
    return chunks;
  }

  String _shortBody(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= 240 ? clean : '${clean.substring(0, 240)}…';
  }
}
