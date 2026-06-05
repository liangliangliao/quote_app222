import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/kv_dao.dart';
import '../voice_lab/eleven_labs_service.dart';
import '../voice_lab/multi_provider_tts_service.dart';
import '../voice_lab/voice_lab_dao.dart';
import '../voice_lab/voice_lab_models.dart';
import 'meditation_models.dart';

class MeditationTtsRuntimeSettings {
  final bool segmentVoiceEnabled;
  final bool autoPrepareSegmentVoice;
  final int maxCacheMb;
  final int aiRetentionDays;
  final String ttsProvider;
  final String voiceSource;
  final String presetVoiceId;
  final String presetVoiceName;
  final String? voiceProfileId;
  final String voiceDisplayName;
  final String resembleVoiceUuid;
  final String resembleVoiceName;
  final String resembleModel;
  final String resembleOutputFormat;
  final String resemblePrecision;
  final int resembleSampleRate;
  final bool resembleUseHd;
  final bool resembleApplyPronunciations;
  final String resembleVoiceType;
  final String resembleMeditationMode;
  final bool resembleMeditationUsePrompt;
  final String resembleMeditationPrompt;
  final double resembleMeditationMaxBreakSec;
  final bool resembleMeditationSplitLongBreaks;
  final String modelId;
  final double stability;
  final double similarityBoost;
  final double style;
  final double speed;
  final bool useSpeakerBoost;
  final String languageCode;
  final String textNormalization;
  final int? seed;
  final String previousText;
  final String nextText;
  final String scene;
  final String pauseMode;
  final bool meditationAutoPauses;
  final String meditationPauseProfile;
  final double meditationSentenceBreakSec;
  final double meditationParagraphBreakSec;
  final double meditationBreathBreakSec;
  final String meditationTone;
  final bool meditationAutoBreathPauses;

  const MeditationTtsRuntimeSettings({
    required this.segmentVoiceEnabled,
    required this.autoPrepareSegmentVoice,
    required this.maxCacheMb,
    required this.aiRetentionDays,
    this.ttsProvider = 'elevenlabs',
    required this.voiceSource,
    required this.presetVoiceId,
    required this.presetVoiceName,
    this.voiceProfileId,
    this.voiceDisplayName = '',
    this.resembleVoiceUuid = '',
    this.resembleVoiceName = 'Resemble AI 冥想声音',
    this.resembleModel = VoiceProviderSettings.defaultResembleModel,
    this.resembleOutputFormat = VoiceProviderSettings.defaultResembleOutputFormat,
    this.resemblePrecision = VoiceProviderSettings.defaultResemblePrecision,
    this.resembleSampleRate = 48000,
    this.resembleUseHd = true,
    this.resembleApplyPronunciations = false,
    this.resembleVoiceType = 'rapid_voice',
    this.resembleMeditationMode = VoiceProviderSettings.defaultResembleMeditationMode,
    this.resembleMeditationUsePrompt = true,
    this.resembleMeditationPrompt = VoiceProviderSettings.defaultResembleMeditationPrompt,
    this.resembleMeditationMaxBreakSec = VoiceProviderSettings.defaultResembleMeditationMaxBreakSec,
    this.resembleMeditationSplitLongBreaks = true,
    required this.modelId,
    required this.stability,
    required this.similarityBoost,
    required this.style,
    required this.speed,
    required this.useSpeakerBoost,
    required this.languageCode,
    required this.textNormalization,
    this.seed,
    required this.previousText,
    required this.nextText,
    required this.scene,
    required this.pauseMode,
    required this.meditationAutoPauses,
    required this.meditationPauseProfile,
    required this.meditationSentenceBreakSec,
    required this.meditationParagraphBreakSec,
    required this.meditationBreathBreakSec,
    required this.meditationTone,
    required this.meditationAutoBreathPauses,
  });

  int get maxCacheBytes => maxCacheMb.clamp(32, 4096).toInt() * 1024 * 1024;

  MeditationTtsRuntimeSettings copyWith({
    bool? segmentVoiceEnabled,
    bool? autoPrepareSegmentVoice,
    int? maxCacheMb,
    int? aiRetentionDays,
    String? ttsProvider,
    String? voiceSource,
    String? presetVoiceId,
    String? presetVoiceName,
    String? voiceProfileId,
    String? voiceDisplayName,
    String? resembleVoiceUuid,
    String? resembleVoiceName,
    String? resembleModel,
    String? resembleOutputFormat,
    String? resemblePrecision,
    int? resembleSampleRate,
    bool? resembleUseHd,
    bool? resembleApplyPronunciations,
    String? resembleVoiceType,
    String? resembleMeditationMode,
    bool? resembleMeditationUsePrompt,
    String? resembleMeditationPrompt,
    double? resembleMeditationMaxBreakSec,
    bool? resembleMeditationSplitLongBreaks,
    String? modelId,
    double? stability,
    double? similarityBoost,
    double? style,
    double? speed,
    bool? useSpeakerBoost,
    String? languageCode,
    String? textNormalization,
    int? seed,
    String? previousText,
    String? nextText,
    String? scene,
    String? pauseMode,
    bool? meditationAutoPauses,
    String? meditationPauseProfile,
    double? meditationSentenceBreakSec,
    double? meditationParagraphBreakSec,
    double? meditationBreathBreakSec,
    String? meditationTone,
    bool? meditationAutoBreathPauses,
  }) {
    return MeditationTtsRuntimeSettings(
      segmentVoiceEnabled: segmentVoiceEnabled ?? this.segmentVoiceEnabled,
      autoPrepareSegmentVoice: autoPrepareSegmentVoice ?? this.autoPrepareSegmentVoice,
      maxCacheMb: maxCacheMb ?? this.maxCacheMb,
      aiRetentionDays: aiRetentionDays ?? this.aiRetentionDays,
      ttsProvider: ttsProvider ?? this.ttsProvider,
      voiceSource: voiceSource ?? this.voiceSource,
      presetVoiceId: presetVoiceId ?? this.presetVoiceId,
      presetVoiceName: presetVoiceName ?? this.presetVoiceName,
      voiceProfileId: voiceProfileId ?? this.voiceProfileId,
      voiceDisplayName: voiceDisplayName ?? this.voiceDisplayName,
      resembleVoiceUuid: resembleVoiceUuid ?? this.resembleVoiceUuid,
      resembleVoiceName: resembleVoiceName ?? this.resembleVoiceName,
      resembleModel: resembleModel ?? this.resembleModel,
      resembleOutputFormat: resembleOutputFormat ?? this.resembleOutputFormat,
      resemblePrecision: resemblePrecision ?? this.resemblePrecision,
      resembleSampleRate: resembleSampleRate ?? this.resembleSampleRate,
      resembleUseHd: resembleUseHd ?? this.resembleUseHd,
      resembleApplyPronunciations: resembleApplyPronunciations ?? this.resembleApplyPronunciations,
      resembleVoiceType: resembleVoiceType ?? this.resembleVoiceType,
      resembleMeditationMode: resembleMeditationMode ?? this.resembleMeditationMode,
      resembleMeditationUsePrompt: resembleMeditationUsePrompt ?? this.resembleMeditationUsePrompt,
      resembleMeditationPrompt: resembleMeditationPrompt ?? this.resembleMeditationPrompt,
      resembleMeditationMaxBreakSec: resembleMeditationMaxBreakSec ?? this.resembleMeditationMaxBreakSec,
      resembleMeditationSplitLongBreaks: resembleMeditationSplitLongBreaks ?? this.resembleMeditationSplitLongBreaks,
      modelId: modelId ?? this.modelId,
      stability: stability ?? this.stability,
      similarityBoost: similarityBoost ?? this.similarityBoost,
      style: style ?? this.style,
      speed: speed ?? this.speed,
      useSpeakerBoost: useSpeakerBoost ?? this.useSpeakerBoost,
      languageCode: languageCode ?? this.languageCode,
      textNormalization: textNormalization ?? this.textNormalization,
      seed: seed ?? this.seed,
      previousText: previousText ?? this.previousText,
      nextText: nextText ?? this.nextText,
      scene: scene ?? this.scene,
      pauseMode: pauseMode ?? this.pauseMode,
      meditationAutoPauses: meditationAutoPauses ?? this.meditationAutoPauses,
      meditationPauseProfile: meditationPauseProfile ?? this.meditationPauseProfile,
      meditationSentenceBreakSec: meditationSentenceBreakSec ?? this.meditationSentenceBreakSec,
      meditationParagraphBreakSec: meditationParagraphBreakSec ?? this.meditationParagraphBreakSec,
      meditationBreathBreakSec: meditationBreathBreakSec ?? this.meditationBreathBreakSec,
      meditationTone: meditationTone ?? this.meditationTone,
      meditationAutoBreathPauses: meditationAutoBreathPauses ?? this.meditationAutoBreathPauses,
    );
  }
}

class MeditationSegmentCacheKey {
  final String textHash;
  final String voiceKey;
  final String modelId;

  const MeditationSegmentCacheKey({
    required this.textHash,
    required this.voiceKey,
    required this.modelId,
  });
}

class MeditationSegmentSynthesisResult {
  final TtsAudioFile audio;
  final String textHash;
  final String voiceKey;
  final String modelId;

  const MeditationSegmentSynthesisResult({
    required this.audio,
    required this.textHash,
    required this.voiceKey,
    required this.modelId,
  });
}

class MeditationBackgroundSound {
  final String id;
  final String label;
  final String description;

  const MeditationBackgroundSound({required this.id, required this.label, required this.description});
}

class MeditationAudioService {
  MeditationAudioService({
    ElevenLabsService? elevenLabsService,
    MultiProviderTtsService? multiProviderTtsService,
    VoiceLabDao? voiceDao,
    KeyValueDao? kvDao,
  })  : _voiceDao = voiceDao ?? VoiceLabDao(),
        _kvDao = kvDao ?? KeyValueDao(),
        _elevenLabsService = elevenLabsService ?? ElevenLabsService(voiceDao: voiceDao ?? VoiceLabDao()),
        _multiProviderTtsService = multiProviderTtsService ?? MultiProviderTtsService(kvDao: kvDao ?? KeyValueDao(), voiceDao: voiceDao ?? VoiceLabDao());

  final VoiceLabDao _voiceDao;
  final KeyValueDao _kvDao;
  final ElevenLabsService _elevenLabsService;
  final MultiProviderTtsService _multiProviderTtsService;
  final FlutterTts _systemTts = FlutterTts();

  static const List<MeditationBackgroundSound> backgroundSounds = <MeditationBackgroundSound>[
    MeditationBackgroundSound(id: 'none', label: '无背景音', description: '只保留呼吸与文字引导'),
    MeditationBackgroundSound(id: 'rain', label: '雨声', description: '稳定、细密、适合反刍中断'),
    MeditationBackgroundSound(id: 'ocean', label: '海浪', description: '缓慢起伏，适合睡前放松'),
    MeditationBackgroundSound(id: 'forest', label: '森林', description: '轻微自然声，适合身体扫描'),
    MeditationBackgroundSound(id: 'night', label: '夜晚', description: '低频安静，适合入睡练习'),
    MeditationBackgroundSound(id: 'white_noise', label: '白噪音', description: '遮蔽杂音，适合专注回收'),
  ];

  static const String segmentVoiceEnabledKey = 'meditation.tts.segment_voice_enabled';
  static const String autoPrepareSegmentVoiceKey = 'meditation.tts.auto_prepare_segment_voice';
  static const String maxCacheMbKey = 'meditation.tts.max_cache_mb';
  static const String aiRetentionDaysKey = 'meditation.tts.ai_retention_days';

  double _parseDouble(String? value, double fallback) => double.tryParse((value ?? '').trim()) ?? fallback;
  int _parseInt(String? value, int fallback) => int.tryParse((value ?? '').trim()) ?? fallback;
  bool _parseBool(String? value, bool fallback) => value == null ? fallback : (value == '1' || value.toLowerCase() == 'true');

  Future<MeditationTtsRuntimeSettings> loadTtsRuntimeSettings({String? sessionKey}) async {
    final sceneRaw = await _kvDao.getString(ElevenLabsSettings.ttsScene);
    final scene = ElevenLabsService.scenePresets.any((e) => e.id == sceneRaw) ? sceneRaw! : 'meditation_relax';
    final preset = ElevenLabsService.presetById(scene);
    final source = await _kvDao.getString(ElevenLabsSettings.ttsVoiceSource) ?? 'premade';
    final selectedVoiceId = await _kvDao.getString(ElevenLabsSettings.teacherVoiceProfileId);
    final profile = selectedVoiceId == null || selectedVoiceId.trim().isEmpty
        ? await _voiceDao.getDefaultVoiceProfile()
        : (await _voiceDao.getVoiceProfileById(selectedVoiceId.trim()) ?? await _voiceDao.getDefaultVoiceProfile());
    final seedText = await _kvDao.getString(ElevenLabsSettings.ttsSeed) ?? '';
    final rawProvider = await _kvDao.getString(VoiceProviderSettings.provider) ?? VoiceProviderSettings.defaultProvider;
    final ttsProvider = rawProvider == 'resemble' ? 'resemble' : 'elevenlabs';
    final resembleSampleRateText = await _kvDao.getString(VoiceProviderSettings.resembleSampleRate) ?? '48000';
    final resembleMaxBreakText = await _kvDao.getString(VoiceProviderSettings.resembleMeditationMaxBreakSec);
    final settings = MeditationTtsRuntimeSettings(
      segmentVoiceEnabled: _parseBool(await _kvDao.getString(segmentVoiceEnabledKey), false),
      autoPrepareSegmentVoice: _parseBool(await _kvDao.getString(autoPrepareSegmentVoiceKey), true),
      maxCacheMb: _parseInt(await _kvDao.getString(maxCacheMbKey), 300).clamp(32, 4096).toInt(),
      aiRetentionDays: _parseInt(await _kvDao.getString(aiRetentionDaysKey), 14).clamp(1, 3650).toInt(),
      ttsProvider: ttsProvider,
      voiceSource: source == 'cloned' ? 'cloned' : 'premade',
      presetVoiceId: await _kvDao.getString(ElevenLabsSettings.presetVoiceId) ?? ElevenLabsSettings.defaultPresetVoiceId,
      presetVoiceName: await _kvDao.getString(ElevenLabsSettings.presetVoiceName) ?? ElevenLabsSettings.defaultPresetVoiceName,
      voiceProfileId: profile?.id,
      voiceDisplayName: profile?.displayName ?? '',
      resembleVoiceUuid: await _kvDao.getString(VoiceProviderSettings.resembleVoiceUuid) ?? '',
      resembleVoiceName: await _kvDao.getString(VoiceProviderSettings.resembleVoiceName) ?? 'Resemble AI 冥想声音',
      resembleModel: await _kvDao.getString(VoiceProviderSettings.resembleModel) ?? VoiceProviderSettings.defaultResembleModel,
      resembleOutputFormat: await _kvDao.getString(VoiceProviderSettings.resembleOutputFormat) ?? VoiceProviderSettings.defaultResembleOutputFormat,
      resemblePrecision: await _kvDao.getString(VoiceProviderSettings.resemblePrecision) ?? VoiceProviderSettings.defaultResemblePrecision,
      resembleSampleRate: _parseInt(resembleSampleRateText, 48000).clamp(8000, 96000).toInt(),
      resembleUseHd: _parseBool(await _kvDao.getString(VoiceProviderSettings.resembleUseHd), true),
      resembleApplyPronunciations: _parseBool(await _kvDao.getString(VoiceProviderSettings.resembleApplyPronunciations), false),
      resembleVoiceType: await _kvDao.getString(VoiceProviderSettings.resembleVoiceType) ?? 'rapid_voice',
      resembleMeditationMode: await _kvDao.getString(VoiceProviderSettings.resembleMeditationMode) ?? VoiceProviderSettings.defaultResembleMeditationMode,
      resembleMeditationUsePrompt: _parseBool(await _kvDao.getString(VoiceProviderSettings.resembleMeditationUsePrompt), true),
      resembleMeditationPrompt: await _kvDao.getString(VoiceProviderSettings.resembleMeditationPrompt) ?? VoiceProviderSettings.defaultResembleMeditationPrompt,
      resembleMeditationMaxBreakSec: _parseDouble(resembleMaxBreakText, VoiceProviderSettings.defaultResembleMeditationMaxBreakSec).clamp(0.3, 10.0).toDouble(),
      resembleMeditationSplitLongBreaks: _parseBool(await _kvDao.getString(VoiceProviderSettings.resembleMeditationSplitLongBreaks), true),
      modelId: await _kvDao.getString(ElevenLabsSettings.defaultModel) ?? ElevenLabsSettings.defaultTtsModel,
      stability: _parseDouble(await _kvDao.getString(ElevenLabsSettings.ttsStability), preset.stability).clamp(0.0, 1.0).toDouble(),
      similarityBoost: _parseDouble(await _kvDao.getString(ElevenLabsSettings.ttsSimilarityBoost), preset.similarityBoost).clamp(0.0, 1.0).toDouble(),
      style: _parseDouble(await _kvDao.getString(ElevenLabsSettings.ttsStyle), preset.style).clamp(0.0, 1.0).toDouble(),
      speed: _parseDouble(await _kvDao.getString(ElevenLabsSettings.ttsSpeed), preset.speed).clamp(0.7, 1.2).toDouble(),
      useSpeakerBoost: _parseBool(await _kvDao.getString(ElevenLabsSettings.ttsUseSpeakerBoost), preset.speakerBoost),
      languageCode: await _kvDao.getString(ElevenLabsSettings.ttsLanguageCode) ?? 'zh',
      textNormalization: await _kvDao.getString(ElevenLabsSettings.ttsTextNormalization) ?? 'auto',
      seed: seedText.trim().isEmpty ? null : int.tryParse(seedText.trim()),
      previousText: await _kvDao.getString(ElevenLabsSettings.ttsPreviousText) ?? '',
      nextText: await _kvDao.getString(ElevenLabsSettings.ttsNextText) ?? '',
      scene: scene,
      pauseMode: await _kvDao.getString(ElevenLabsSettings.ttsPauseMode) ?? preset.recommendedPauseMode,
      meditationAutoPauses: _parseBool(await _kvDao.getString(ElevenLabsSettings.meditationAutoPauses), preset.meditationAutoPauses),
      meditationPauseProfile: await _kvDao.getString(ElevenLabsSettings.meditationPauseProfile) ?? preset.meditationPauseProfile,
      meditationSentenceBreakSec: _parseDouble(await _kvDao.getString(ElevenLabsSettings.meditationSentenceBreakSec), preset.meditationSentenceBreakSec).clamp(0.3, 60.0).toDouble(),
      meditationParagraphBreakSec: _parseDouble(await _kvDao.getString(ElevenLabsSettings.meditationParagraphBreakSec), preset.meditationParagraphBreakSec).clamp(0.3, 60.0).toDouble(),
      meditationBreathBreakSec: _parseDouble(await _kvDao.getString(ElevenLabsSettings.meditationBreathBreakSec), preset.meditationBreathBreakSec).clamp(0.3, 60.0).toDouble(),
      meditationTone: await _kvDao.getString(ElevenLabsSettings.meditationTone) ?? preset.meditationTone,
      meditationAutoBreathPauses: _parseBool(await _kvDao.getString(ElevenLabsSettings.meditationAutoBreathPauses), preset.meditationAutoBreathPauses),
    );
    return _applySessionTtsVoiceOverride(settings, sessionKey);
  }

  String _sessionTtsSettingsKey(String sessionKey) =>
      'meditation.tts.session_voice_settings.${sha256.convert(utf8.encode(sessionKey.trim())).toString()}';

  Future<bool> hasSessionTtsVoiceSettings(String sessionKey) async {
    final key = sessionKey.trim();
    if (key.isEmpty) return false;
    final raw = await _kvDao.getString(_sessionTtsSettingsKey(key));
    return raw != null && raw.trim().isNotEmpty;
  }

  Future<MeditationTtsRuntimeSettings> _applySessionTtsVoiceOverride(
    MeditationTtsRuntimeSettings base,
    String? sessionKey,
  ) async {
    final key = (sessionKey ?? '').trim();
    if (key.isEmpty) return base;
    final raw = await _kvDao.getString(_sessionTtsSettingsKey(key));
    if (raw == null || raw.trim().isEmpty) return base;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return base;
      String? str(String name) => decoded[name]?.toString();
      double? dbl(String name) => decoded[name] == null ? null : double.tryParse(decoded[name].toString());
      int? integer(String name) => decoded[name] == null ? null : int.tryParse(decoded[name].toString());
      bool? boolValue(String name) {
        final value = decoded[name];
        if (value == null) return null;
        if (value is bool) return value;
        final text = value.toString().toLowerCase();
        if (text == '1' || text == 'true') return true;
        if (text == '0' || text == 'false') return false;
        return null;
      }

      return base.copyWith(
        ttsProvider: str('ttsProvider'),
        voiceSource: str('voiceSource'),
        presetVoiceId: str('presetVoiceId'),
        presetVoiceName: str('presetVoiceName'),
        voiceProfileId: str('voiceProfileId'),
        voiceDisplayName: str('voiceDisplayName'),
        resembleVoiceUuid: str('resembleVoiceUuid'),
        resembleVoiceName: str('resembleVoiceName'),
        resembleModel: str('resembleModel'),
        resembleOutputFormat: str('resembleOutputFormat'),
        resemblePrecision: str('resemblePrecision'),
        resembleSampleRate: integer('resembleSampleRate'),
        resembleUseHd: boolValue('resembleUseHd'),
        resembleApplyPronunciations: boolValue('resembleApplyPronunciations'),
        resembleVoiceType: str('resembleVoiceType'),
        resembleMeditationMode: str('resembleMeditationMode'),
        resembleMeditationUsePrompt: boolValue('resembleMeditationUsePrompt'),
        resembleMeditationPrompt: str('resembleMeditationPrompt'),
        resembleMeditationMaxBreakSec: dbl('resembleMeditationMaxBreakSec'),
        resembleMeditationSplitLongBreaks: boolValue('resembleMeditationSplitLongBreaks'),
        modelId: str('modelId'),
        stability: dbl('stability'),
        similarityBoost: dbl('similarityBoost'),
        style: dbl('style'),
        speed: dbl('speed'),
        useSpeakerBoost: boolValue('useSpeakerBoost'),
        languageCode: str('languageCode'),
        textNormalization: str('textNormalization'),
        seed: integer('seed'),
        previousText: str('previousText'),
        nextText: str('nextText'),
        scene: str('scene'),
        pauseMode: str('pauseMode'),
        meditationAutoPauses: boolValue('meditationAutoPauses'),
        meditationPauseProfile: str('meditationPauseProfile'),
        meditationSentenceBreakSec: dbl('meditationSentenceBreakSec'),
        meditationParagraphBreakSec: dbl('meditationParagraphBreakSec'),
        meditationBreathBreakSec: dbl('meditationBreathBreakSec'),
        meditationTone: str('meditationTone'),
        meditationAutoBreathPauses: boolValue('meditationAutoBreathPauses'),
      );
    } catch (_) {
      return base;
    }
  }

  Future<void> _saveSessionTtsVoiceSettings(String sessionKey, MeditationTtsRuntimeSettings settings) async {
    final key = sessionKey.trim();
    if (key.isEmpty) return;
    final payload = <String, dynamic>{
      'ttsProvider': settings.ttsProvider,
      'voiceSource': settings.voiceSource,
      'presetVoiceId': settings.presetVoiceId,
      'presetVoiceName': settings.presetVoiceName,
      'voiceProfileId': settings.voiceProfileId,
      'voiceDisplayName': settings.voiceDisplayName,
      'resembleVoiceUuid': settings.resembleVoiceUuid,
      'resembleVoiceName': settings.resembleVoiceName,
      'resembleModel': settings.resembleModel,
      'resembleOutputFormat': settings.resembleOutputFormat,
      'resemblePrecision': settings.resemblePrecision,
      'resembleSampleRate': settings.resembleSampleRate,
      'resembleUseHd': settings.resembleUseHd,
      'resembleApplyPronunciations': settings.resembleApplyPronunciations,
      'resembleVoiceType': settings.resembleVoiceType,
      'resembleMeditationMode': settings.resembleMeditationMode,
      'resembleMeditationUsePrompt': settings.resembleMeditationUsePrompt,
      'resembleMeditationPrompt': settings.resembleMeditationPrompt,
      'resembleMeditationMaxBreakSec': settings.resembleMeditationMaxBreakSec,
      'resembleMeditationSplitLongBreaks': settings.resembleMeditationSplitLongBreaks,
      'modelId': settings.modelId,
      'stability': settings.stability,
      'similarityBoost': settings.similarityBoost,
      'style': settings.style,
      'speed': settings.speed,
      'useSpeakerBoost': settings.useSpeakerBoost,
      'languageCode': settings.languageCode,
      'textNormalization': settings.textNormalization,
      'seed': settings.seed,
      'previousText': settings.previousText,
      'nextText': settings.nextText,
      'scene': settings.scene,
      'pauseMode': settings.pauseMode,
      'meditationAutoPauses': settings.meditationAutoPauses,
      'meditationPauseProfile': settings.meditationPauseProfile,
      'meditationSentenceBreakSec': settings.meditationSentenceBreakSec,
      'meditationParagraphBreakSec': settings.meditationParagraphBreakSec,
      'meditationBreathBreakSec': settings.meditationBreathBreakSec,
      'meditationTone': settings.meditationTone,
      'meditationAutoBreathPauses': settings.meditationAutoBreathPauses,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _kvDao.setString(_sessionTtsSettingsKey(key), jsonEncode(payload));
  }

  Future<void> saveTtsRuntimeSettings(MeditationTtsRuntimeSettings settings, {String? sessionKey}) async {
    await _kvDao.setString(segmentVoiceEnabledKey, settings.segmentVoiceEnabled ? '1' : '0');
    await _kvDao.setString(autoPrepareSegmentVoiceKey, settings.autoPrepareSegmentVoice ? '1' : '0');
    await _kvDao.setString(maxCacheMbKey, settings.maxCacheMb.toString());
    await _kvDao.setString(aiRetentionDaysKey, settings.aiRetentionDays.toString());
    if ((sessionKey ?? '').trim().isNotEmpty) {
      await _saveSessionTtsVoiceSettings(sessionKey!.trim(), settings);
      return;
    }
    await _kvDao.setString(VoiceProviderSettings.provider, settings.ttsProvider == 'resemble' ? 'resemble' : 'elevenlabs');
    await _kvDao.setString(VoiceProviderSettings.resembleVoiceUuid, settings.resembleVoiceUuid);
    await _kvDao.setString(VoiceProviderSettings.resembleVoiceName, settings.resembleVoiceName);
    await _kvDao.setString(VoiceProviderSettings.resembleModel, settings.resembleModel);
    await _kvDao.setString(VoiceProviderSettings.resembleOutputFormat, settings.resembleOutputFormat);
    await _kvDao.setString(VoiceProviderSettings.resemblePrecision, settings.resemblePrecision);
    await _kvDao.setString(VoiceProviderSettings.resembleSampleRate, settings.resembleSampleRate.toString());
    await _kvDao.setString(VoiceProviderSettings.resembleUseHd, settings.resembleUseHd ? '1' : '0');
    await _kvDao.setString(VoiceProviderSettings.resembleApplyPronunciations, settings.resembleApplyPronunciations ? '1' : '0');
    await _kvDao.setString(VoiceProviderSettings.resembleVoiceType, settings.resembleVoiceType);
    await _kvDao.setString(VoiceProviderSettings.resembleMeditationMode, settings.resembleMeditationMode);
    await _kvDao.setString(VoiceProviderSettings.resembleMeditationUsePrompt, settings.resembleMeditationUsePrompt ? '1' : '0');
    await _kvDao.setString(VoiceProviderSettings.resembleMeditationPrompt, settings.resembleMeditationPrompt);
    await _kvDao.setString(VoiceProviderSettings.resembleMeditationMaxBreakSec, settings.resembleMeditationMaxBreakSec.toStringAsFixed(1));
    await _kvDao.setString(VoiceProviderSettings.resembleMeditationSplitLongBreaks, settings.resembleMeditationSplitLongBreaks ? '1' : '0');
    await _kvDao.setString(ElevenLabsSettings.ttsVoiceSource, settings.voiceSource);
    await _kvDao.setString(ElevenLabsSettings.presetVoiceId, settings.presetVoiceId);
    await _kvDao.setString(ElevenLabsSettings.presetVoiceName, settings.presetVoiceName);
    if ((settings.voiceProfileId ?? '').isNotEmpty) await _kvDao.setString(ElevenLabsSettings.teacherVoiceProfileId, settings.voiceProfileId!);
    await _kvDao.setString(ElevenLabsSettings.defaultModel, settings.modelId);
    await _kvDao.setString(ElevenLabsSettings.ttsStability, settings.stability.toString());
    await _kvDao.setString(ElevenLabsSettings.ttsSimilarityBoost, settings.similarityBoost.toString());
    await _kvDao.setString(ElevenLabsSettings.ttsStyle, settings.style.toString());
    await _kvDao.setString(ElevenLabsSettings.ttsSpeed, settings.speed.toString());
    await _kvDao.setString(ElevenLabsSettings.ttsUseSpeakerBoost, settings.useSpeakerBoost ? '1' : '0');
    await _kvDao.setString(ElevenLabsSettings.ttsLanguageCode, settings.languageCode);
    await _kvDao.setString(ElevenLabsSettings.ttsTextNormalization, settings.textNormalization);
    await _kvDao.setString(ElevenLabsSettings.ttsSeed, settings.seed?.toString() ?? '');
    await _kvDao.setString(ElevenLabsSettings.ttsPreviousText, settings.previousText);
    await _kvDao.setString(ElevenLabsSettings.ttsNextText, settings.nextText);
    await _kvDao.setString(ElevenLabsSettings.ttsScene, settings.scene);
    await _kvDao.setString(ElevenLabsSettings.ttsPauseMode, settings.pauseMode);
    await _kvDao.setString(ElevenLabsSettings.meditationAutoPauses, settings.meditationAutoPauses ? '1' : '0');
    await _kvDao.setString(ElevenLabsSettings.meditationPauseProfile, settings.meditationPauseProfile);
    await _kvDao.setString(ElevenLabsSettings.meditationSentenceBreakSec, settings.meditationSentenceBreakSec.toString());
    await _kvDao.setString(ElevenLabsSettings.meditationParagraphBreakSec, settings.meditationParagraphBreakSec.toString());
    await _kvDao.setString(ElevenLabsSettings.meditationBreathBreakSec, settings.meditationBreathBreakSec.toString());
    await _kvDao.setString(ElevenLabsSettings.meditationTone, settings.meditationTone);
    await _kvDao.setString(ElevenLabsSettings.meditationAutoBreathPauses, settings.meditationAutoBreathPauses ? '1' : '0');
  }

  Future<List<ElevenLabsVoiceOption>> loadPremadeVoiceOptions() async {
    try {
      final voices = await _elevenLabsService.listVoices(
        voiceType: 'all',
        category: 'premade',
        pageSize: 100,
      );
      if (voices.isNotEmpty) return voices;
    } catch (_) {}
    return <ElevenLabsVoiceOption>[
      const ElevenLabsVoiceOption(
        voiceId: ElevenLabsSettings.defaultPresetVoiceId,
        name: ElevenLabsSettings.defaultPresetVoiceName,
        category: 'default',
        description: '未能联网获取声音列表时使用的默认普通声音。',
      ),
    ];
  }

  Future<List<ElevenLabsModelOption>> loadTtsModelOptions() async {
    try {
      final models = await _elevenLabsService.listModels();
      if (models.isNotEmpty) return models;
    } catch (_) {}
    return const <ElevenLabsModelOption>[
      ElevenLabsModelOption(modelId: 'eleven_multilingual_v2', name: 'eleven_multilingual_v2'),
      ElevenLabsModelOption(modelId: 'eleven_v3', name: 'eleven_v3'),
      ElevenLabsModelOption(modelId: 'eleven_flash_v2_5', name: 'eleven_flash_v2_5'),
      ElevenLabsModelOption(modelId: 'eleven_turbo_v2_5', name: 'eleven_turbo_v2_5'),
    ];
  }
  Future<List<ProviderCatalogOption>> loadResembleVoiceOptions() async {
    try {
      final voices = await _multiProviderTtsService.listResembleVoices(pageSize: 100);
      if (voices.isNotEmpty) return voices.map(_annotateResembleMeditationVoice).toList();
    } catch (_) {}
    return const <ProviderCatalogOption>[];
  }

  ProviderCatalogOption _annotateResembleMeditationVoice(ProviderCatalogOption option) {
    final tag = _resembleMeditationVoiceTag(option.name);
    if (tag.isEmpty) return option;
    final description = option.description.trim();
    final taggedDescription = description.contains(tag)
        ? description
        : (description.isEmpty ? tag : '$tag；$description');
    return ProviderCatalogOption(
      id: option.id,
      name: option.name,
      description: taggedDescription,
      category: option.category,
      extra: option.extra,
    );
  }

  String _resembleMeditationVoiceTag(String rawName) {
    final name = rawName.trim().toLowerCase();
    if (name.isEmpty) return '';
    final normalized = name.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized == 'mei') return '推荐·中文柔和冥想';
    if (normalized == 'hao') return '推荐·中文沉稳冥想';
    if (normalized == 'grace') return '推荐·温柔冥想';
    if (normalized == 'linda') return '推荐·成熟稳定';
    if (normalized == 'elaine') return '推荐·平静引导';
    if (normalized == 'evelyn') return '推荐·睡前柔和';
    if (normalized == 'lucy') return '推荐·轻柔入门';
    if (normalized == 'lisa') return '推荐·日常正念';
    if (normalized == 'laura') return '推荐·睡前放松';
    if (normalized == 'sofia') return '推荐·自我接纳';
    if (normalized == 'anaya') return '推荐·安抚柔和';
    if (normalized == 'alma') return '推荐·温暖修复';
    if (normalized == 'luma') return '推荐·睡前轻柔';
    if (normalized == 'eric') return '推荐·男性稳定';
    if (normalized == 'jason') return '推荐·男性通用';
    if (normalized == 'andrew') return '推荐·成熟男声';
    if (normalized == 'ethan') return '推荐·短练习';
    if (normalized == 'gavin') return '推荐·平稳旁白';
    if (normalized.contains('maureen') && normalized.contains('caring')) return '推荐·关怀修复';
    if (normalized.contains('carl bishop') && normalized.contains('conversational')) return '推荐·男性对话式';
    if (normalized.contains('willow') && normalized.contains('whispering')) return '推荐·睡前低语';
    if (normalized.contains('scared') || normalized.contains('angry') || normalized.contains('sad') || normalized.contains('happy')) return '不建议默认冥想·情绪色彩较强';
    if (normalized.contains('announcer')) return '不建议默认冥想·播音感较强';
    if (normalized.contains('titan') || normalized.contains('atlas')) return '备选·力量型定力训练';
    if (normalized.contains('nova')) return '备选·明亮现代声';
    return '';
  }

  Future<List<ProviderCatalogOption>> loadResembleModelOptions() async {
    try {
      return await _multiProviderTtsService.listResembleModels();
    } catch (_) {
      return const <ProviderCatalogOption>[
        ProviderCatalogOption(id: '', name: '自动选择 / Chatterbox', description: '推荐：让 Resemble 按 voice_uuid 自动选择兼容模型'),
        ProviderCatalogOption(id: 'chatterbox-turbo', name: 'Chatterbox Turbo', description: '低延迟；如果失败请改回自动选择'),
      ];
    }
  }

  Future<List<VoiceProfile>> loadVoiceProfilesByProvider(String provider) async {
    final profiles = await _voiceDao.listVoiceProfiles();
    return profiles.where((profile) => profile.provider == provider).toList();
  }


  Future<MeditationSegmentCacheKey> resolveSegmentCacheKey({
    required MeditationStep step,
    required MeditationTtsRuntimeSettings settings,
  }) async {
    final provider = settings.ttsProvider == 'resemble' ? 'resemble' : 'elevenlabs';
    if (provider == 'resemble') {
      final useCloned = settings.voiceSource == 'cloned' && (settings.voiceProfileId ?? '').isNotEmpty;
      final profile = useCloned ? await _voiceDao.getVoiceProfileById(settings.voiceProfileId!) : null;
      final manualVoice = settings.resembleVoiceUuid.trim();
      final voiceUuid = useCloned && profile != null && profile.provider == 'resemble' ? profile.elevenlabsVoiceId : manualVoice;
      final voiceKey = useCloned && profile != null && profile.provider == 'resemble' ? profile.id : voiceUuid;
      final modelKey = 'resemble:${settings.resembleModel.trim().isEmpty ? 'auto' : settings.resembleModel.trim()}';
      return MeditationSegmentCacheKey(
        textHash: segmentHash(step, settings, voiceKey),
        voiceKey: voiceKey,
        modelId: modelKey,
      );
    }
    final useCloned = settings.voiceSource == 'cloned' && (settings.voiceProfileId ?? '').isNotEmpty;
    final profile = useCloned ? await _voiceDao.getVoiceProfileById(settings.voiceProfileId!) : null;
    final presetVoiceKey = settings.presetVoiceId.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceId : settings.presetVoiceId.trim();
    final voiceKey = useCloned && profile != null ? profile.id : presetVoiceKey;
    return MeditationSegmentCacheKey(
      textHash: segmentHash(step, settings, voiceKey),
      voiceKey: voiceKey,
      modelId: settings.modelId,
    );
  }

  String segmentHash(MeditationStep step, MeditationTtsRuntimeSettings settings, String voiceKey) {
    final parts = <Object?>[
      step.text.trim(),
      settings.ttsProvider,
      voiceKey,
      settings.modelId,
      settings.resembleVoiceUuid,
      settings.resembleModel,
      settings.resembleOutputFormat,
      settings.resemblePrecision,
      settings.resembleSampleRate,
      settings.resembleUseHd,
      settings.resembleApplyPronunciations,
      settings.resembleVoiceType,
      settings.resembleMeditationMode,
      settings.resembleMeditationUsePrompt,
      settings.resembleMeditationPrompt,
      settings.resembleMeditationMaxBreakSec,
      settings.resembleMeditationSplitLongBreaks,
      settings.stability,
      settings.similarityBoost,
      settings.style,
      settings.speed,
      settings.useSpeakerBoost,
      settings.languageCode,
      settings.textNormalization,
      settings.seed ?? '',
      settings.previousText,
      settings.nextText,
      settings.scene,
      settings.pauseMode,
      settings.meditationAutoPauses,
      settings.meditationPauseProfile,
      settings.meditationSentenceBreakSec,
      settings.meditationParagraphBreakSec,
      settings.meditationBreathBreakSec,
      settings.meditationTone,
      settings.meditationAutoBreathPauses,
    ];
    return sha256.convert(utf8.encode(parts.join('|'))).toString();
  }

  Future<MeditationSegmentSynthesisResult> synthesizeSegmentGuidedAudio({
    required MeditationStep step,
    required MeditationTtsRuntimeSettings settings,
    bool forceRegenerate = false,
  }) async {
    final text = step.text.trim();
    if (text.isEmpty) throw StateError('当前冥想片段没有可朗读文字');
    final provider = settings.ttsProvider == 'resemble' ? 'resemble' : 'elevenlabs';
    if (provider == 'resemble') {
      final useCloned = settings.voiceSource == 'cloned' && (settings.voiceProfileId ?? '').isNotEmpty;
      final profile = useCloned ? await _voiceDao.getVoiceProfileById(settings.voiceProfileId!) : null;
      final selectedProfile = profile != null && profile.provider == 'resemble' ? profile : null;
      final voiceUuid = selectedProfile?.elevenlabsVoiceId ?? settings.resembleVoiceUuid.trim();
      if (voiceUuid.trim().isEmpty) {
        throw StateError('请先在当前冥想语音设置中选择或填写 Resemble voice_uuid');
      }
      final voiceKey = selectedProfile?.id ?? voiceUuid.trim();
      final textHash = segmentHash(step, settings, voiceKey);
      final modelKey = 'resemble:${settings.resembleModel.trim().isEmpty ? 'auto' : settings.resembleModel.trim()}';
      final audio = await _multiProviderTtsService.synthesizeResembleAndSave(
        text: text,
        voiceUuid: voiceUuid,
        voiceDisplayName: selectedProfile?.displayName ?? settings.resembleVoiceName,
        voiceProfileId: selectedProfile?.id,
        moduleName: 'meditation_segment',
        model: settings.resembleModel,
        outputFormat: settings.resembleOutputFormat,
        precision: settings.resemblePrecision,
        sampleRate: settings.resembleSampleRate,
        useHd: settings.resembleUseHd,
        applyCustomPronunciations: settings.resembleApplyPronunciations,
        speed: settings.speed,
        scene: settings.scene,
        meditationAutoPauses: settings.meditationAutoPauses,
        meditationPauseProfile: settings.meditationPauseProfile,
        meditationSentenceBreakSec: settings.meditationSentenceBreakSec,
        meditationParagraphBreakSec: settings.meditationParagraphBreakSec,
        meditationBreathBreakSec: settings.meditationBreathBreakSec,
        meditationTone: settings.meditationTone,
        meditationAutoBreathPauses: settings.meditationAutoBreathPauses,
        resembleMeditationMode: settings.resembleMeditationMode,
        resembleMeditationUsePrompt: settings.resembleMeditationUsePrompt,
        resembleMeditationPrompt: settings.resembleMeditationPrompt,
        resembleMeditationMaxBreakSec: settings.resembleMeditationMaxBreakSec,
        resembleMeditationSplitLongBreaks: settings.resembleMeditationSplitLongBreaks,
        forceRegenerate: forceRegenerate,
      );
      return MeditationSegmentSynthesisResult(audio: audio, textHash: textHash, voiceKey: voiceKey, modelId: modelKey);
    }

    final useCloned = settings.voiceSource == 'cloned' && (settings.voiceProfileId ?? '').isNotEmpty;
    final profile = useCloned ? await _voiceDao.getVoiceProfileById(settings.voiceProfileId!) : null;
    final presetVoiceKey = settings.presetVoiceId.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceId : settings.presetVoiceId.trim();
    final voiceKey = useCloned && profile != null ? profile.id : presetVoiceKey;
    final textHash = segmentHash(step, settings, voiceKey);
    TtsAudioFile audio;
    if (useCloned && profile != null) {
      audio = await _elevenLabsService.synthesizeAndSave(
        text: text,
        voiceProfile: profile,
        moduleName: 'meditation_segment',
        modelId: settings.modelId,
        stability: settings.stability,
        similarityBoost: settings.similarityBoost,
        style: settings.style,
        speed: settings.speed,
        useSpeakerBoost: settings.useSpeakerBoost,
        languageCode: settings.languageCode,
        textNormalization: settings.textNormalization,
        seed: settings.seed,
        previousText: settings.previousText,
        nextText: settings.nextText,
        scene: settings.scene,
        pauseMode: settings.pauseMode,
        meditationAutoPauses: settings.meditationAutoPauses,
        meditationPauseProfile: settings.meditationPauseProfile,
        meditationSentenceBreakSec: settings.meditationSentenceBreakSec,
        meditationParagraphBreakSec: settings.meditationParagraphBreakSec,
        meditationBreathBreakSec: settings.meditationBreathBreakSec,
        meditationTone: settings.meditationTone,
        meditationAutoBreathPauses: settings.meditationAutoBreathPauses,
        forceRegenerate: forceRegenerate,
      );
    } else {
      final presetVoice = settings.presetVoiceId.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceId : settings.presetVoiceId.trim();
      audio = await _elevenLabsService.synthesizeAndSaveByVoiceId(
        text: text,
        voiceId: presetVoice,
        voiceSource: 'premade',
        voiceDisplayName: settings.presetVoiceName,
        moduleName: 'meditation_segment',
        modelId: settings.modelId,
        stability: settings.stability,
        similarityBoost: settings.similarityBoost,
        style: settings.style,
        speed: settings.speed,
        useSpeakerBoost: settings.useSpeakerBoost,
        languageCode: settings.languageCode,
        textNormalization: settings.textNormalization,
        seed: settings.seed,
        previousText: settings.previousText,
        nextText: settings.nextText,
        scene: settings.scene,
        pauseMode: settings.pauseMode,
        meditationAutoPauses: settings.meditationAutoPauses,
        meditationPauseProfile: settings.meditationPauseProfile,
        meditationSentenceBreakSec: settings.meditationSentenceBreakSec,
        meditationParagraphBreakSec: settings.meditationParagraphBreakSec,
        meditationBreathBreakSec: settings.meditationBreathBreakSec,
        meditationTone: settings.meditationTone,
        meditationAutoBreathPauses: settings.meditationAutoBreathPauses,
        forceRegenerate: forceRegenerate,
      );
    }
    return MeditationSegmentSynthesisResult(audio: audio, textHash: textHash, voiceKey: voiceKey, modelId: settings.modelId);
  }

  Future<TtsAudioFile> synthesizeGuidedAudio({
    required MeditationSessionTemplate session,
    double stability = 0.78,
    double similarityBoost = 0.76,
    double style = 0.12,
    bool forceRegenerate = false,
  }) async {
    final profile = await _voiceDao.getDefaultVoiceProfile();
    if (profile == null) {
      throw StateError('还没有配置默认 ElevenLabs 声音。可先到“语音与美好的祝福配置”添加声音；也可以使用系统朗读。');
    }
    final text = buildGuidedSpeechText(session);
    return _elevenLabsService.synthesizeAndSave(
      text: text,
      voiceProfile: profile,
      moduleName: 'meditation_guided',
      stability: stability,
      similarityBoost: similarityBoost,
      style: style,
      speed: 0.82,
      languageCode: 'zh',
      scene: 'meditation_relax',
      pauseMode: 'long',
      meditationAutoPauses: true,
      meditationPauseProfile: 'deep',
      meditationSentenceBreakSec: 1.5,
      meditationParagraphBreakSec: 2.4,
      meditationBreathBreakSec: 2.0,
      meditationTone: 'calm',
      meditationAutoBreathPauses: true,
      forceRegenerate: forceRegenerate,
    );
  }

  String buildGuidedSpeechText(MeditationSessionTemplate session) {
    final buffer = StringBuffer();
    buffer.writeln(session.title);
    buffer.writeln('现在开始。');
    for (final step in session.steps) {
      final text = step.text.trim();
      if (text.isEmpty) continue;
      buffer.writeln(text);
      buffer.writeln('。');
    }
    if (session.endingReflection.trim().isNotEmpty) {
      buffer.writeln(session.endingReflection.trim());
    }
    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Future<void> speakWithSystemTts(String text, {double volume = 0.9, double rate = 0.36, double pitch = 0.92}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _systemTts.stop();
    await _systemTts.setLanguage('zh-CN');
    await _systemTts.setSpeechRate(rate.clamp(0.2, 0.65).toDouble());
    await _systemTts.setPitch(pitch.clamp(0.6, 1.2).toDouble());
    await _systemTts.setVolume(volume.clamp(0.0, 1.0).toDouble());
    await _systemTts.speak(clean);
  }

  Future<void> stopSystemTts() => _systemTts.stop();
  Future<void> pauseSystemTts() => _systemTts.pause();

  Future<String> prepareBackgroundSound(String soundId) async {
    if (soundId == 'none') return '';
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'meditation_background_sounds'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'meditation_${soundId}_loop.wav'));
    if (await file.exists() && await file.length() > 1024) return file.path;
    final bytes = _generateLoopWav(soundId);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Uint8List _generateLoopWav(String soundId) {
    const sampleRate = 22050;
    const seconds = 24;
    const channels = 1;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    const totalSamples = sampleRate * seconds;
    final rng = math.Random(soundId.hashCode & 0x7fffffff);
    final data = BytesBuilder(copy: false);
    double last = 0;
    double low = 0;

    for (var i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final raw = rng.nextDouble() * 2 - 1;
      last = last * 0.82 + raw * 0.18;
      low = low * 0.992 + raw * 0.008;
      double sample;
      switch (soundId) {
        case 'ocean':
          final wave = 0.45 + 0.38 * math.sin(2 * math.pi * t / 6.8) + 0.12 * math.sin(2 * math.pi * t / 3.2);
          sample = (last * 0.55 + low * 0.45) * wave * 0.55;
          break;
        case 'forest':
          final chirp = (math.sin(2 * math.pi * 1260 * t) * math.max(0, math.sin(2 * math.pi * t / 5.7))) * 0.018;
          sample = last * 0.13 + low * 0.10 + chirp;
          break;
        case 'night':
          sample = low * 0.18 + math.sin(2 * math.pi * 86 * t) * 0.018;
          break;
        case 'white_noise':
          sample = raw * 0.18;
          break;
        case 'rain':
        default:
          final drops = raw * 0.20 + last * 0.18;
          sample = drops;
          break;
      }
      // Soft fade at boundaries to make the loop less abrupt.
      final fadeSamples = sampleRate * 2;
      var fade = 1.0;
      if (i < fadeSamples) fade = i / fadeSamples;
      if (i > totalSamples - fadeSamples) fade = (totalSamples - i) / fadeSamples;
      final clamped = (sample * fade).clamp(-0.95, 0.95);
      final pcm = (clamped * 32767).round();
      data.addByte(pcm & 0xff);
      data.addByte((pcm >> 8) & 0xff);
    }

    final dataBytes = data.toBytes();
    final out = BytesBuilder(copy: false);
    void writeAscii(String s) => out.add(s.codeUnits);
    void writeU16(int v) {
      out.addByte(v & 0xff);
      out.addByte((v >> 8) & 0xff);
    }
    void writeU32(int v) {
      out.addByte(v & 0xff);
      out.addByte((v >> 8) & 0xff);
      out.addByte((v >> 16) & 0xff);
      out.addByte((v >> 24) & 0xff);
    }

    writeAscii('RIFF');
    writeU32(36 + dataBytes.length);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeU32(16);
    writeU16(1);
    writeU16(channels);
    writeU32(sampleRate);
    writeU32(sampleRate * channels * bytesPerSample);
    writeU16(channels * bytesPerSample);
    writeU16(bitsPerSample);
    writeAscii('data');
    writeU32(dataBytes.length);
    out.add(dataBytes);
    return out.toBytes();
  }
}
