import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/kv_dao.dart';
import '../utils/deepseek_logger.dart';
import 'voice_lab_dao.dart';
import 'voice_lab_models.dart';

class ElevenLabsSettings {
  static const apiKey = 'elevenlabs.api_key';
  static const defaultModel = 'elevenlabs.default_tts_model';
  static const outputFormat = 'elevenlabs.output_format';
  static const autoSaveAudio = 'elevenlabs.auto_save_audio';
  static const reuseCache = 'elevenlabs.reuse_cache';

  /// cloned = 使用本地保存的克隆声音档案；premade = 使用 ElevenLabs 免费额度可用的普通/默认声音 voice_id。
  static const ttsVoiceSource = 'elevenlabs.tts_voice_source';
  static const presetVoiceId = 'elevenlabs.preset_voice_id';
  static const presetVoiceName = 'elevenlabs.preset_voice_name';
  static const voiceFilterType = 'elevenlabs.voice_filter_type';
  static const voiceFilterCategory = 'elevenlabs.voice_filter_category';
  static const ttsScene = 'elevenlabs.tts_scene';
  static const ttsSpeed = 'elevenlabs.tts_speed';
  static const ttsStability = 'elevenlabs.tts_stability';
  static const ttsSimilarityBoost = 'elevenlabs.tts_similarity_boost';
  static const ttsStyle = 'elevenlabs.tts_style';
  static const ttsUseSpeakerBoost = 'elevenlabs.tts_use_speaker_boost';
  static const ttsLanguageCode = 'elevenlabs.tts_language_code';
  static const ttsTextNormalization = 'elevenlabs.tts_text_normalization';
  static const ttsSeed = 'elevenlabs.tts_seed';
  static const ttsPreviousText = 'elevenlabs.tts_previous_text';
  static const ttsNextText = 'elevenlabs.tts_next_text';
  static const ttsPauseMode = 'elevenlabs.tts_pause_mode';
  static const meditationAutoPauses = 'elevenlabs.meditation_auto_pauses';
  static const meditationPauseProfile = 'elevenlabs.meditation_pause_profile';
  static const meditationSentenceBreakSec = 'elevenlabs.meditation_sentence_break_sec';
  static const meditationParagraphBreakSec = 'elevenlabs.meditation_paragraph_break_sec';
  static const meditationBreathBreakSec = 'elevenlabs.meditation_breath_break_sec';
  static const meditationTone = 'elevenlabs.meditation_tone';
  static const meditationAutoBreathPauses = 'elevenlabs.meditation_auto_breath_pauses';

  static const teacherName = 'virtual_teacher.name';
  static const teacherPersonaPrompt = 'virtual_teacher.persona_prompt';
  static const teacherOpening = 'virtual_teacher.opening_message';
  static const teacherVoiceProfileId = 'virtual_teacher.voice_profile_id';
  static const teacherEnableVoiceReply = 'virtual_teacher.enable_voice_reply';

  static const defaultTtsModel = 'eleven_multilingual_v2';
  static const defaultOutputFormat = 'mp3_44100_128';
  static const defaultPresetVoiceId = 'JBFqnCBsd6RMkjVDRZzb';
  static const defaultPresetVoiceName = 'ElevenLabs 默认示例声音';
  static const defaultTeacherName = '美好的祝福';
  static const defaultTeacherOpening = '你好，我会用你设置的声音与你对话。你可以把我设置成英语面试教练、哲学老师或行动教练。';
  static const defaultTeacherPersona = '''你是用户App中的“美好的祝福”。
你的任务是用清楚、具体、可执行的方式帮助用户学习、训练和复盘。
要求：
1. 语言简明，不要空泛鼓励；
2. 先理解用户问题，再给出具体步骤；
3. 适合中文语音朗读，句子不要过长；
4. 当用户需要训练时，给出可立即执行的小练习；
5. 不要假装自己是真人，必要时说明你是AI美好的祝福。''';
}

class ElevenLabsTtsPreset {
  final String id;
  final String name;
  final double stability;
  final double similarityBoost;
  final double style;
  final double speed;
  final bool speakerBoost;
  final String v3Tag;
  final String description;
  final String recommendedPauseMode;
  final bool meditationAutoPauses;
  final String meditationPauseProfile;
  final double meditationSentenceBreakSec;
  final double meditationParagraphBreakSec;
  final double meditationBreathBreakSec;
  final String meditationTone;
  final bool meditationAutoBreathPauses;

  const ElevenLabsTtsPreset({
    required this.id,
    required this.name,
    required this.stability,
    required this.similarityBoost,
    required this.style,
    required this.speed,
    required this.speakerBoost,
    this.v3Tag = '',
    this.description = '',
    this.recommendedPauseMode = 'none',
    this.meditationAutoPauses = false,
    this.meditationPauseProfile = 'standard',
    this.meditationSentenceBreakSec = 1.2,
    this.meditationParagraphBreakSec = 2.0,
    this.meditationBreathBreakSec = 2.0,
    this.meditationTone = 'calm',
    this.meditationAutoBreathPauses = false,
  });
}

class ElevenLabsService {
  ElevenLabsService({KeyValueDao? kvDao, VoiceLabDao? voiceDao})
      : _kvDao = kvDao ?? KeyValueDao(),
        _voiceDao = voiceDao ?? VoiceLabDao();

  final KeyValueDao _kvDao;
  final VoiceLabDao _voiceDao;
  static const String _baseUrl = 'https://api.elevenlabs.io';

  static const List<ElevenLabsTtsPreset> scenePresets = <ElevenLabsTtsPreset>[
    ElevenLabsTtsPreset(id: 'stable_reading', name: '稳定朗读', stability: 0.82, similarityBoost: 0.78, style: 0.08, speed: 0.96, speakerBoost: true, description: '平稳、少起伏，适合普通文章和课程短段落。'),
    ElevenLabsTtsPreset(id: 'natural_dialogue', name: '自然对话', stability: 0.55, similarityBoost: 0.80, style: 0.20, speed: 1.00, speakerBoost: true, description: '自然口语表达，适合美好的祝福日常对话。'),
    ElevenLabsTtsPreset(id: 'encouraging', name: '鼓励激励', stability: 0.45, similarityBoost: 0.82, style: 0.36, speed: 1.04, speakerBoost: true, v3Tag: '[encouraging]', description: '更有能量，适合目标训练、行动督促和积极反馈。'),
    ElevenLabsTtsPreset(id: 'strict', name: '严厉督促', stability: 0.52, similarityBoost: 0.82, style: 0.34, speed: 0.96, speakerBoost: true, v3Tag: '[firm]', description: '更坚定，适合提醒、复盘、纠偏。'),
    ElevenLabsTtsPreset(id: 'comfort', name: '温和安慰', stability: 0.64, similarityBoost: 0.80, style: 0.24, speed: 0.92, speakerBoost: true, v3Tag: '[calm]', description: '温柔、缓和，适合情绪安抚。'),
    ElevenLabsTtsPreset(
      id: 'meditation_relax',
      name: '冥想放松',
      stability: 0.78,
      similarityBoost: 0.76,
      style: 0.12,
      speed: 0.82,
      speakerBoost: true,
      v3Tag: '[calm]',
      description: '慢语速、高稳定、低表演、深留白。适合冥想引导、睡前放松、身体扫描、正念呼吸。',
      recommendedPauseMode: 'long',
      meditationAutoPauses: true,
      meditationPauseProfile: 'deep',
      meditationSentenceBreakSec: 1.5,
      meditationParagraphBreakSec: 2.4,
      meditationBreathBreakSec: 2.0,
      meditationTone: 'calm',
      meditationAutoBreathPauses: true,
    ),
    ElevenLabsTtsPreset(id: 'socratic', name: '苏格拉底式追问', stability: 0.56, similarityBoost: 0.80, style: 0.26, speed: 0.96, speakerBoost: true, v3Tag: '[curious]', description: '平静追问，适合引导式思考。'),
    ElevenLabsTtsPreset(id: 'long_form', name: '长文课程讲解', stability: 0.76, similarityBoost: 0.78, style: 0.12, speed: 0.95, speakerBoost: true, description: '适合长文本分段生成，稳定性优先。'),
    ElevenLabsTtsPreset(id: 'fast_reply', name: '低延迟快速回复', stability: 0.58, similarityBoost: 0.75, style: 0.08, speed: 1.08, speakerBoost: false, description: '响应速度优先，音色相似度和细腻度让位于速度。'),
  ];

  static ElevenLabsTtsPreset presetById(String id) {
    return scenePresets.firstWhere(
      (p) => p.id == id,
      orElse: () => scenePresets.firstWhere((p) => p.id == 'natural_dialogue'),
    );
  }

  static bool isMeditationScene(String scene) => scene == 'meditation_relax';

  Future<String> getApiKey() async => (await _kvDao.getString(ElevenLabsSettings.apiKey) ?? '').trim();

  Future<String> getDefaultTtsModel() async {
    final v = (await _kvDao.getString(ElevenLabsSettings.defaultModel) ?? '').trim();
    return v.isEmpty ? ElevenLabsSettings.defaultTtsModel : v;
  }

  Future<String> getOutputFormat() async {
    final v = (await _kvDao.getString(ElevenLabsSettings.outputFormat) ?? '').trim();
    return v.isEmpty ? ElevenLabsSettings.defaultOutputFormat : v;
  }

  Future<bool> isAutoSaveEnabled() async {
    final v = await _kvDao.getString(ElevenLabsSettings.autoSaveAudio);
    return v == null || v == '1' || v.toLowerCase() == 'true';
  }

  Future<bool> isCacheEnabled() async {
    final v = await _kvDao.getString(ElevenLabsSettings.reuseCache);
    return v == null || v == '1' || v.toLowerCase() == 'true';
  }

  Future<bool> testConnection() async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) throw StateError('请先填写 ElevenLabs API Key');
    final uri = Uri.parse('$_baseUrl/v1/models');
    await DeepSeekLogger.logRequest(
      provider: 'ElevenLabs',
      module: 'voice_lab.test_connection',
      endpoint: uri.toString(),
      method: 'GET',
      model: 'models/list',
      headers: const {'xi-api-key': '***REDACTED***'},
      body: const {'action': 'list_models'},
    );
    final resp = await http.get(uri, headers: {'xi-api-key': apiKey}).timeout(const Duration(seconds: 25));
    await DeepSeekLogger.logResponse(
      provider: 'ElevenLabs',
      module: 'voice_lab.test_connection',
      endpoint: uri.toString(),
      model: 'models/list',
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('ElevenLabs Key 测试失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    return true;
  }

  Future<List<ElevenLabsModelOption>> listModels() async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) throw StateError('请先填写 ElevenLabs API Key');
    final uri = Uri.parse('$_baseUrl/v1/models');
    await DeepSeekLogger.logRequest(
      provider: 'ElevenLabs',
      module: 'voice_lab.list_models',
      endpoint: uri.toString(),
      method: 'GET',
      model: 'models/list',
      headers: const {'xi-api-key': '***REDACTED***'},
      body: const {'action': 'list_models'},
    );
    final resp = await http.get(uri, headers: {'xi-api-key': apiKey}).timeout(const Duration(seconds: 35));
    await DeepSeekLogger.logResponse(
      provider: 'ElevenLabs',
      module: 'voice_lab.list_models',
      endpoint: uri.toString(),
      model: 'models/list',
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('获取 ElevenLabs 模型列表失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    final raw = decoded is List ? decoded : (decoded is Map ? decoded['models'] : null);
    if (raw is! List) return const <ElevenLabsModelOption>[];
    return raw
        .whereType<Map>()
        .map((e) => ElevenLabsModelOption.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.modelId.trim().isNotEmpty && m.canDoTextToSpeech)
        .toList();
  }

  Future<List<ElevenLabsVoiceOption>> listVoices({
    String voiceType = 'default',
    String category = 'premade',
    String search = '',
    int pageSize = 50,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) throw StateError('请先填写 ElevenLabs API Key');
    final params = <String, String>{
      'page_size': pageSize.clamp(1, 100).toString(),
    };
    if (voiceType.trim().isNotEmpty && voiceType != 'all') params['voice_type'] = voiceType.trim();
    if (category.trim().isNotEmpty && category != 'all') params['category'] = category.trim();
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    final uri = Uri.parse('$_baseUrl/v2/voices').replace(queryParameters: params);
    await DeepSeekLogger.logRequest(
      provider: 'ElevenLabs',
      module: 'voice_lab.list_voices',
      endpoint: uri.toString(),
      method: 'GET',
      model: 'voices/list',
      headers: const {'xi-api-key': '***REDACTED***'},
      body: params,
    );
    final resp = await http.get(uri, headers: {'xi-api-key': apiKey}).timeout(const Duration(seconds: 35));
    await DeepSeekLogger.logResponse(
      provider: 'ElevenLabs',
      module: 'voice_lab.list_voices',
      endpoint: uri.toString(),
      model: 'voices/list',
      statusCode: resp.statusCode,
      body: _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('获取 ElevenLabs 声音列表失败：HTTP ${resp.statusCode} ${resp.body}');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = decoded['voices'];
    if (raw is! List) return const <ElevenLabsVoiceOption>[];
    return raw
        .whereType<Map>()
        .map((e) => ElevenLabsVoiceOption.fromJson(Map<String, dynamic>.from(e)))
        .where((v) => v.voiceId.trim().isNotEmpty)
        .toList();
  }

  Future<VoiceProfile> addManualVoiceProfile({
    required String displayName,
    required String elevenlabsVoiceId,
    String language = 'zh',
    bool makeDefault = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = VoiceProfile(
      id: voiceLabUid('voice'),
      displayName: displayName.trim().isEmpty ? 'ElevenLabs 声音' : displayName.trim(),
      elevenlabsVoiceId: elevenlabsVoiceId.trim(),
      cloneType: 'manual',
      language: language,
      status: 'ready',
      isDefault: makeDefault,
      createdAt: now,
      updatedAt: now,
    );
    await _voiceDao.upsertVoiceProfile(profile, makeDefault: makeDefault);
    return profile;
  }

  Future<VoiceProfile> createInstantVoiceClone({
    required String displayName,
    required String sampleAudioPath,
    String? description,
    String language = 'zh',
    bool removeBackgroundNoise = false,
    bool makeDefault = true,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) throw StateError('请先在“语音与美好的祝福配置”中填写 ElevenLabs API Key');
    final f = File(sampleAudioPath);
    if (!await f.exists()) throw StateError('声音样本文件不存在');
    final uri = Uri.parse('$_baseUrl/v1/voices/add');
    final req = http.MultipartRequest('POST', uri);
    req.headers['xi-api-key'] = apiKey;
    req.fields['name'] = displayName.trim();
    req.fields['description'] = (description ?? 'Created from Quote App virtual teacher module').trim();
    req.fields['remove_background_noise'] = removeBackgroundNoise ? 'true' : 'false';
    req.files.add(await http.MultipartFile.fromPath('files', sampleAudioPath));

    await DeepSeekLogger.logRequest(
      provider: 'ElevenLabs',
      module: 'voice_lab.create_instant_voice_clone',
      endpoint: uri.toString(),
      method: 'POST',
      model: 'instant_voice_clone',
      headers: const {'xi-api-key': '***REDACTED***'},
      body: <String, dynamic>{
        'name': displayName,
        'description': description,
        'remove_background_noise': removeBackgroundNoise,
        'language': language,
        'file_name': p.basename(sampleAudioPath),
      },
    );

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final respBody = await streamed.stream.bytesToString();
    await DeepSeekLogger.logResponse(
      provider: 'ElevenLabs',
      module: 'voice_lab.create_instant_voice_clone',
      endpoint: uri.toString(),
      model: 'instant_voice_clone',
      statusCode: streamed.statusCode,
      body: _shortBody(respBody),
    );
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError('创建声音克隆失败：HTTP ${streamed.statusCode} $respBody');
    }
    final decoded = jsonDecode(respBody) as Map<String, dynamic>;
    final voiceId = (decoded['voice_id'] ?? '').toString().trim();
    if (voiceId.isEmpty) throw StateError('ElevenLabs 未返回 voice_id');
    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = VoiceProfile(
      id: voiceLabUid('voice'),
      displayName: displayName.trim(),
      elevenlabsVoiceId: voiceId,
      cloneType: 'instant',
      sampleAudioPath: sampleAudioPath,
      language: language,
      status: 'ready',
      isDefault: makeDefault,
      createdAt: now,
      updatedAt: now,
    );
    await _voiceDao.upsertVoiceProfile(profile, makeDefault: makeDefault);
    return profile;
  }

  Future<TtsAudioFile> synthesizeAndSave({
    required String text,
    required VoiceProfile voiceProfile,
    String moduleName = 'voice_lab',
    String? modelId,
    double stability = 0.55,
    double similarityBoost = 0.8,
    double style = 0.2,
    double speed = 1.0,
    bool useSpeakerBoost = true,
    String languageCode = '',
    String textNormalization = 'auto',
    int? seed,
    String previousText = '',
    String nextText = '',
    String scene = 'natural_dialogue',
    String pauseMode = 'none',
    bool meditationAutoPauses = false,
    String meditationPauseProfile = 'standard',
    double meditationSentenceBreakSec = 1.5,
    double meditationParagraphBreakSec = 2.4,
    double meditationBreathBreakSec = 2.0,
    String meditationTone = 'calm',
    bool meditationAutoBreathPauses = true,
    bool forceRegenerate = false,
  }) async {
    return synthesizeAndSaveByVoiceId(
      text: text,
      voiceId: voiceProfile.elevenlabsVoiceId,
      voiceSource: 'cloned',
      voiceProfileId: voiceProfile.id,
      voiceDisplayName: voiceProfile.displayName,
      moduleName: moduleName,
      modelId: modelId,
      stability: stability,
      similarityBoost: similarityBoost,
      style: style,
      speed: speed,
      useSpeakerBoost: useSpeakerBoost,
      languageCode: languageCode,
      textNormalization: textNormalization,
      seed: seed,
      previousText: previousText,
      nextText: nextText,
      scene: scene,
      pauseMode: pauseMode,
      meditationAutoPauses: meditationAutoPauses,
      meditationPauseProfile: meditationPauseProfile,
      meditationSentenceBreakSec: meditationSentenceBreakSec,
      meditationParagraphBreakSec: meditationParagraphBreakSec,
      meditationBreathBreakSec: meditationBreathBreakSec,
      meditationTone: meditationTone,
      meditationAutoBreathPauses: meditationAutoBreathPauses,
      forceRegenerate: forceRegenerate,
    );
  }

  Future<TtsAudioFile> synthesizeAndSaveByVoiceId({
    required String text,
    required String voiceId,
    String voiceSource = 'premade',
    String? voiceProfileId,
    String voiceDisplayName = '',
    String moduleName = 'voice_lab',
    String? modelId,
    double stability = 0.55,
    double similarityBoost = 0.8,
    double style = 0.2,
    double speed = 1.0,
    bool useSpeakerBoost = true,
    String languageCode = '',
    String textNormalization = 'auto',
    int? seed,
    String previousText = '',
    String nextText = '',
    String scene = 'natural_dialogue',
    String pauseMode = 'none',
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
    if (cleanText.isEmpty) throw StateError('请输入需要转换成语音的文字');
    final cleanVoiceId = voiceId.trim();
    if (cleanVoiceId.isEmpty) throw StateError('请先选择或填写 ElevenLabs voice_id');
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) throw StateError('请先填写 ElevenLabs API Key');
    final configuredModel = (modelId ?? (await getDefaultTtsModel())).trim();
    final effectiveModel = configuredModel.isEmpty ? ElevenLabsSettings.defaultTtsModel : configuredModel;
    final outputFormat = await getOutputFormat();
    final normalized = textNormalization.trim().isEmpty ? 'auto' : textNormalization.trim();
    final finalText = _prepareTextForGeneration(
      cleanText,
      scene: scene,
      pauseMode: pauseMode,
      modelId: effectiveModel,
      meditationAutoPauses: meditationAutoPauses,
      meditationPauseProfile: meditationPauseProfile,
      meditationSentenceBreakSec: meditationSentenceBreakSec,
      meditationParagraphBreakSec: meditationParagraphBreakSec,
      meditationBreathBreakSec: meditationBreathBreakSec,
      meditationTone: meditationTone,
      meditationAutoBreathPauses: meditationAutoBreathPauses,
    );
    final cacheParts = <Object?>[
      cleanText,
      cleanVoiceId,
      voiceProfileId ?? '',
      effectiveModel,
      stability,
      similarityBoost,
      style,
      speed,
      useSpeakerBoost,
      languageCode,
      normalized,
      seed ?? '',
      previousText,
      nextText,
      scene,
      pauseMode,
      meditationAutoPauses,
      meditationPauseProfile,
      meditationSentenceBreakSec,
      meditationParagraphBreakSec,
      meditationBreathBreakSec,
      meditationTone,
      meditationAutoBreathPauses,
      outputFormat,
    ];
    final textHash = sha256.convert(utf8.encode(cacheParts.join('|'))).toString();
    final cacheKey = (voiceProfileId ?? '').trim().isNotEmpty ? voiceProfileId!.trim() : cleanVoiceId;

    if (!forceRegenerate && await isCacheEnabled()) {
      final cached = await _voiceDao.findCachedAudioByVoiceKey(textHash, cacheKey);
      if (cached != null && File(cached.audioFilePath).existsSync()) return cached;
    }

    final uri = Uri.parse('$_baseUrl/v1/text-to-speech/${Uri.encodeComponent(cleanVoiceId)}?output_format=${Uri.encodeQueryComponent(outputFormat)}');
    final body = <String, dynamic>{
      'text': finalText,
      'model_id': effectiveModel,
      'voice_settings': <String, dynamic>{
        'stability': stability.clamp(0.0, 1.0),
        'similarity_boost': similarityBoost.clamp(0.0, 1.0),
        'style': style.clamp(0.0, 1.0),
        'use_speaker_boost': useSpeakerBoost,
        'speed': speed.clamp(0.7, 1.2),
      },
    };
    if (languageCode.trim().isNotEmpty) body['language_code'] = languageCode.trim();
    if (normalized == 'auto' || normalized == 'on' || normalized == 'off') body['apply_text_normalization'] = normalized;
    if (seed != null) body['seed'] = seed.clamp(0, 4294967295);
    if (previousText.trim().isNotEmpty) body['previous_text'] = previousText.trim();
    if (nextText.trim().isNotEmpty) body['next_text'] = nextText.trim();

    await DeepSeekLogger.logRequest(
      provider: 'ElevenLabs',
      module: 'voice_lab.text_to_speech.$moduleName',
      endpoint: uri.toString(),
      method: 'POST',
      model: effectiveModel,
      headers: const {'xi-api-key': '***REDACTED***', 'Content-Type': 'application/json'},
      body: <String, dynamic>{
        ...body,
        'voice_source': voiceSource,
        'voice_display_name': voiceDisplayName,
        'pause_mode': pauseMode,
        'scene': scene,
        'meditation_auto_pauses': meditationAutoPauses,
        'meditation_pause_profile': meditationPauseProfile,
        'meditation_sentence_break_sec': meditationSentenceBreakSec,
        'meditation_paragraph_break_sec': meditationParagraphBreakSec,
        'meditation_breath_break_sec': meditationBreathBreakSec,
        'meditation_tone': meditationTone,
        'meditation_auto_breath_pauses': meditationAutoBreathPauses,
        'text_preview': cleanText.length > 120 ? '${cleanText.substring(0, 120)}...' : cleanText,
      },
    );
    final resp = await http
        .post(
          uri,
          headers: {'xi-api-key': apiKey, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
    await DeepSeekLogger.logResponse(
      provider: 'ElevenLabs',
      module: 'voice_lab.text_to_speech.$moduleName',
      endpoint: uri.toString(),
      model: effectiveModel,
      statusCode: resp.statusCode,
      body: resp.statusCode >= 200 && resp.statusCode < 300 ? 'audio bytes: ${resp.bodyBytes.length}' : _shortBody(resp.body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('ElevenLabs TTS 失败：HTTP ${resp.statusCode} ${resp.body}');
    }

    final docs = await getApplicationDocumentsDirectory();
    final ttsDir = Directory(p.join(docs.path, 'tts_audio'));
    if (!await ttsDir.exists()) await ttsDir.create(recursive: true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final safeModule = moduleName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    final fileName = 'tts_${safeModule}_$now.mp3';
    final file = File(p.join(ttsDir.path, fileName));
    await file.writeAsBytes(resp.bodyBytes, flush: true);

    final audio = TtsAudioFile(
      id: voiceLabUid('tts'),
      moduleName: moduleName,
      sourceText: cleanText,
      textHash: textHash,
      elevenlabsVoiceId: cleanVoiceId,
      voiceProfileId: voiceProfileId,
      modelId: effectiveModel,
      audioFileName: fileName,
      audioFilePath: file.path,
      fileSize: await file.length(),
      voiceSource: voiceSource,
      voiceDisplayName: voiceDisplayName,
      ttsSpeed: speed,
      ttsStability: stability,
      ttsSimilarityBoost: similarityBoost,
      ttsStyle: style,
      ttsUseSpeakerBoost: useSpeakerBoost,
      languageCode: languageCode,
      textNormalization: normalized,
      scene: scene,
      pauseMode: pauseMode,
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
    if (await isAutoSaveEnabled()) {
      await _voiceDao.insertTtsAudio(audio);
    }
    return audio;
  }

  Future<String> exportAudioToDownloads(TtsAudioFile audio) async {
    final file = File(audio.audioFilePath);
    if (!await file.exists()) throw StateError('音频文件不存在，无法下载');
    const ch = MethodChannel('native.scheduler');
    final saved = await ch.invokeMethod<String>('saveAudioToDownloads', <String, Object?>{
      'path': audio.audioFilePath,
      'name': audio.audioFileName,
      'mime': audio.mimeType,
    });
    final savedPath = (saved ?? '').trim();
    await _voiceDao.markAudioDownloaded(audio.id, savedPath, audio.audioFileName);
    return savedPath;
  }

  Future<void> deleteAudioRecordAndFile(TtsAudioFile audio) async {
    try {
      final f = File(audio.audioFilePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _voiceDao.deleteTtsAudio(audio.id);
  }

  static String _prepareTextForGeneration(
    String text, {
    required String scene,
    required String pauseMode,
    required String modelId,
    bool meditationAutoPauses = false,
    String meditationPauseProfile = 'standard',
    double meditationSentenceBreakSec = 1.5,
    double meditationParagraphBreakSec = 2.4,
    double meditationBreathBreakSec = 2.0,
    String meditationTone = 'calm',
    bool meditationAutoBreathPauses = true,
  }) {
    var result = text.trim();
    final supportsV3Tags = modelId.toLowerCase().contains('v3');
    if (isMeditationScene(scene) && meditationAutoPauses) {
      result = _applyMeditationPauses(
        result,
        supportsV3Tags: supportsV3Tags,
        profile: meditationPauseProfile,
        sentenceBreakSec: meditationSentenceBreakSec,
        paragraphBreakSec: meditationParagraphBreakSec,
        breathBreakSec: meditationBreathBreakSec,
        autoBreathPauses: meditationAutoBreathPauses,
      );
    } else if (pauseMode != 'none') {
      result = _applyPauseMode(result, pauseMode);
    }
    final preset = presetById(scene);
    if (supportsV3Tags) {
      final tag = isMeditationScene(scene) ? _meditationV3ToneTag(meditationTone) : preset.v3Tag.trim();
      if (tag.isNotEmpty && !result.trimLeft().startsWith('[')) {
        result = '$tag $result';
      }
    }
    return result;
  }

  static String _applyPauseMode(String text, String mode) {
    final gap = switch (mode) {
      'short' => '。 ',
      'medium' => '。\n',
      'long' => '。\n\n',
      _ => ' ',
    };
    final lines = text
        .split(RegExp(r'\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.length <= 1) return text;
    return lines.join(gap);
  }

  static String _applyMeditationPauses(
    String text, {
    required bool supportsV3Tags,
    required String profile,
    required double sentenceBreakSec,
    required double paragraphBreakSec,
    required double breathBreakSec,
    required bool autoBreathPauses,
  }) {
    final sentence = _clampBreakSeconds(sentenceBreakSec);
    final paragraph = _clampBreakSeconds(paragraphBreakSec);
    final breath = _clampBreakSeconds(breathBreakSec);
    String sentencePause() => supportsV3Tags ? _v3PauseTag(sentence) : '<break time="${sentence.toStringAsFixed(1)}s" />';
    String paragraphPause() => supportsV3Tags ? _v3PauseTag(paragraph) : '<break time="${paragraph.toStringAsFixed(1)}s" />';
    String breathPause() => supportsV3Tags ? _v3PauseTag(breath) : '<break time="${breath.toStringAsFixed(1)}s" />';

    var result = text.trim();
    final paragraphGap = ' ${paragraphPause()}\n\n';
    result = result
        .split(RegExp(r'\n{2,}'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(paragraphGap);

    final sentenceGap = profile == 'light' ? '' : ' ${sentencePause()}';
    if (sentenceGap.isNotEmpty) {
      result = result.replaceAllMapped(RegExp(r'([。！？!?；;])(?=\s*[^<\n])'), (m) => '${m.group(1)}$sentenceGap');
    }

    if (autoBreathPauses) {
      result = result.replaceAllMapped(
        RegExp(r'(吸气|呼气|深吸一口气|慢慢吸气|慢慢呼气|闭上眼睛|放松肩膀)([。！？!?,，、]?)'),
        (m) => '${m.group(1)}${m.group(2)} ${breathPause()}',
      );
    }

    return result.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  static double _clampBreakSeconds(double value) {
    if (value.isNaN || value.isInfinite) return 1.5;
    return value.clamp(0.3, 60.0).toDouble();
  }

  static String _v3PauseTag(double seconds) {
    if (seconds >= 2.0) return '[long pause]';
    if (seconds >= 1.0) return '[pause]';
    return '[short pause]';
  }

  static String _meditationV3ToneTag(String tone) {
    return switch (tone) {
      'soft' => '[softly]',
      'whisper' => '[whispering]',
      'warm' => '[warmly]',
      'healing' => '[calm]',
      _ => '[calm]',
    };
  }

  static String _shortBody(String body) {
    if (body.length <= 1200) return body;
    return '${body.substring(0, 1200)}...(truncated)';
  }
}
