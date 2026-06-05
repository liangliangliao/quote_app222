class VoiceProfile {
  final String id;
  final String provider;
  final String displayName;
  final String elevenlabsVoiceId;
  final String cloneType;
  final String? sampleAudioPath;
  final String? consentAudioPath;
  final String language;
  final String status;
  final bool isDefault;
  final int createdAt;
  final int updatedAt;

  const VoiceProfile({
    required this.id,
    this.provider = 'elevenlabs',
    required this.displayName,
    required this.elevenlabsVoiceId,
    this.cloneType = 'instant',
    this.sampleAudioPath,
    this.consentAudioPath,
    this.language = 'zh',
    this.status = 'ready',
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'provider': provider,
        'display_name': displayName,
        'elevenlabs_voice_id': elevenlabsVoiceId,
        'clone_type': cloneType,
        'sample_audio_path': sampleAudioPath,
        'consent_audio_path': consentAudioPath,
        'language': language,
        'status': status,
        'is_default': isDefault ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory VoiceProfile.fromMap(Map<String, Object?> map) {
    return VoiceProfile(
      id: (map['id'] ?? '').toString(),
      provider: (map['provider'] ?? 'elevenlabs').toString(),
      displayName: (map['display_name'] ?? '').toString(),
      elevenlabsVoiceId: (map['elevenlabs_voice_id'] ?? '').toString(),
      cloneType: (map['clone_type'] ?? 'instant').toString(),
      sampleAudioPath: map['sample_audio_path']?.toString(),
      consentAudioPath: map['consent_audio_path']?.toString(),
      language: (map['language'] ?? 'zh').toString(),
      status: (map['status'] ?? 'ready').toString(),
      isDefault: ((map['is_default'] ?? 0) as num).toInt() == 1,
      createdAt: ((map['created_at'] ?? 0) as num).toInt(),
      updatedAt: ((map['updated_at'] ?? 0) as num).toInt(),
    );
  }
}

class ElevenLabsVoiceOption {
  final String voiceId;
  final String name;
  final String category;
  final String description;
  final String previewUrl;
  final Map<String, String> labels;
  final double? stability;
  final double? similarityBoost;
  final double? style;
  final double? speed;
  final bool? useSpeakerBoost;

  const ElevenLabsVoiceOption({
    required this.voiceId,
    required this.name,
    this.category = '',
    this.description = '',
    this.previewUrl = '',
    this.labels = const <String, String>{},
    this.stability,
    this.similarityBoost,
    this.style,
    this.speed,
    this.useSpeakerBoost,
  });

  factory ElevenLabsVoiceOption.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final labels = <String, String>{};
    if (rawLabels is Map) {
      rawLabels.forEach((key, value) => labels[key.toString()] = value.toString());
    }
    final settings = json['settings'];
    double? asDouble(Object? v) => v is num ? v.toDouble() : double.tryParse((v ?? '').toString());
    return ElevenLabsVoiceOption(
      voiceId: (json['voice_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      previewUrl: (json['preview_url'] ?? '').toString(),
      labels: labels,
      stability: settings is Map ? asDouble(settings['stability']) : null,
      similarityBoost: settings is Map ? asDouble(settings['similarity_boost']) : null,
      style: settings is Map ? asDouble(settings['style']) : null,
      speed: settings is Map ? asDouble(settings['speed']) : null,
      useSpeakerBoost: settings is Map ? settings['use_speaker_boost'] == true : null,
    );
  }

  String get labelSummary {
    final parts = <String>[];
    if (category.trim().isNotEmpty) parts.add(category.trim());
    for (final key in const ['gender', 'age', 'accent', 'use_case', 'description']) {
      final v = labels[key];
      if (v != null && v.trim().isNotEmpty) parts.add(v.trim());
    }
    return parts.take(5).join(' · ');
  }
}


class ElevenLabsModelOption {
  final String modelId;
  final String name;
  final String description;
  final bool canDoTextToSpeech;
  final bool canUseStyle;
  final bool canUseSpeakerBoost;
  final bool canUseTextNormalization;
  final bool canUseLanguageCode;

  const ElevenLabsModelOption({
    required this.modelId,
    required this.name,
    this.description = '',
    this.canDoTextToSpeech = true,
    this.canUseStyle = true,
    this.canUseSpeakerBoost = true,
    this.canUseTextNormalization = true,
    this.canUseLanguageCode = true,
  });

  factory ElevenLabsModelOption.fromJson(Map<String, dynamic> json) {
    bool asBool(Object? v, {bool fallback = true}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      final raw = v.toString().toLowerCase().trim();
      if (raw == 'true' || raw == '1' || raw == 'yes') return true;
      if (raw == 'false' || raw == '0' || raw == 'no') return false;
      return fallback;
    }

    return ElevenLabsModelOption(
      modelId: (json['model_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['model_id'] ?? json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      canDoTextToSpeech: asBool(json['can_do_text_to_speech'], fallback: true),
      canUseStyle: asBool(json['can_use_style'], fallback: true),
      canUseSpeakerBoost: asBool(json['can_use_speaker_boost'], fallback: true),
      canUseTextNormalization: asBool(json['can_use_text_normalization'], fallback: true),
      canUseLanguageCode: asBool(json['can_use_language_code'], fallback: true),
    );
  }

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName == modelId) return modelId;
    return '$trimmedName · $modelId';
  }
}


class ProviderCatalogOption {
  final String id;
  final String name;
  final String description;
  final String category;
  final Map<String, String> extra;

  const ProviderCatalogOption({
    required this.id,
    required this.name,
    this.description = '',
    this.category = '',
    this.extra = const <String, String>{},
  });

  String get displayName {
    final n = name.trim();
    if (n.isEmpty || n == id) return id;
    return '$n · $id';
  }

  String get subtitle {
    final parts = <String>[];
    if (category.trim().isNotEmpty) parts.add(category.trim());
    if (description.trim().isNotEmpty) parts.add(description.trim());
    for (final e in extra.entries.take(4)) {
      if (e.value.trim().isNotEmpty) parts.add('${e.key}: ${e.value}');
    }
    return parts.join(' · ');
  }
}

class TtsAudioFile {
  final String id;
  final String moduleName;
  final String sourceText;
  final String textHash;
  final String provider;
  final String elevenlabsVoiceId;
  final String? voiceProfileId;
  final String modelId;
  final String audioFileName;
  final String audioFilePath;
  final String mimeType;
  final int fileSize;
  final int durationMs;
  final bool isDownloaded;
  final String? downloadedUri;
  final String? downloadedFileName;
  final String voiceSource;
  final String voiceDisplayName;
  final double ttsSpeed;
  final double ttsStability;
  final double ttsSimilarityBoost;
  final double ttsStyle;
  final bool ttsUseSpeakerBoost;
  final String languageCode;
  final String textNormalization;
  final String scene;
  final String pauseMode;
  final bool meditationAutoPauses;
  final String meditationPauseProfile;
  final double meditationSentenceBreakSec;
  final double meditationParagraphBreakSec;
  final double meditationBreathBreakSec;
  final String meditationTone;
  final bool meditationAutoBreathPauses;
  final int createdAt;
  final int updatedAt;

  const TtsAudioFile({
    required this.id,
    required this.moduleName,
    required this.sourceText,
    required this.textHash,
    this.provider = 'elevenlabs',
    required this.elevenlabsVoiceId,
    this.voiceProfileId,
    required this.modelId,
    required this.audioFileName,
    required this.audioFilePath,
    this.mimeType = 'audio/mpeg',
    this.fileSize = 0,
    this.durationMs = 0,
    this.isDownloaded = false,
    this.downloadedUri,
    this.downloadedFileName,
    this.voiceSource = 'cloned',
    this.voiceDisplayName = '',
    this.ttsSpeed = 1.0,
    this.ttsStability = 0.55,
    this.ttsSimilarityBoost = 0.8,
    this.ttsStyle = 0.2,
    this.ttsUseSpeakerBoost = true,
    this.languageCode = '',
    this.textNormalization = 'auto',
    this.scene = 'natural_dialogue',
    this.pauseMode = 'none',
    this.meditationAutoPauses = false,
    this.meditationPauseProfile = 'standard',
    this.meditationSentenceBreakSec = 1.5,
    this.meditationParagraphBreakSec = 2.4,
    this.meditationBreathBreakSec = 2.0,
    this.meditationTone = 'calm',
    this.meditationAutoBreathPauses = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'module_name': moduleName,
        'source_text': sourceText,
        'text_hash': textHash,
        'provider': provider,
        'elevenlabs_voice_id': elevenlabsVoiceId,
        'voice_profile_id': voiceProfileId,
        'model_id': modelId,
        'audio_file_name': audioFileName,
        'audio_file_path': audioFilePath,
        'mime_type': mimeType,
        'file_size': fileSize,
        'duration_ms': durationMs,
        'is_downloaded': isDownloaded ? 1 : 0,
        'downloaded_uri': downloadedUri,
        'downloaded_file_name': downloadedFileName,
        'voice_source': voiceSource,
        'voice_display_name': voiceDisplayName,
        'tts_speed': ttsSpeed,
        'tts_stability': ttsStability,
        'tts_similarity_boost': ttsSimilarityBoost,
        'tts_style': ttsStyle,
        'tts_use_speaker_boost': ttsUseSpeakerBoost ? 1 : 0,
        'language_code': languageCode,
        'text_normalization': textNormalization,
        'scene': scene,
        'pause_mode': pauseMode,
        'meditation_auto_pauses': meditationAutoPauses ? 1 : 0,
        'meditation_pause_profile': meditationPauseProfile,
        'meditation_sentence_break_sec': meditationSentenceBreakSec,
        'meditation_paragraph_break_sec': meditationParagraphBreakSec,
        'meditation_breath_break_sec': meditationBreathBreakSec,
        'meditation_tone': meditationTone,
        'meditation_auto_breath_pauses': meditationAutoBreathPauses ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory TtsAudioFile.fromMap(Map<String, Object?> map) {
    double asDouble(String key, double fallback) {
      final v = map[key];
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString()) ?? fallback;
    }

    return TtsAudioFile(
      id: (map['id'] ?? '').toString(),
      moduleName: (map['module_name'] ?? '').toString(),
      sourceText: (map['source_text'] ?? '').toString(),
      textHash: (map['text_hash'] ?? '').toString(),
      provider: (map['provider'] ?? 'elevenlabs').toString(),
      elevenlabsVoiceId: (map['elevenlabs_voice_id'] ?? '').toString(),
      voiceProfileId: map['voice_profile_id']?.toString(),
      modelId: (map['model_id'] ?? 'eleven_multilingual_v2').toString(),
      audioFileName: (map['audio_file_name'] ?? '').toString(),
      audioFilePath: (map['audio_file_path'] ?? '').toString(),
      mimeType: (map['mime_type'] ?? 'audio/mpeg').toString(),
      fileSize: ((map['file_size'] ?? 0) as num).toInt(),
      durationMs: ((map['duration_ms'] ?? 0) as num).toInt(),
      isDownloaded: ((map['is_downloaded'] ?? 0) as num).toInt() == 1,
      downloadedUri: map['downloaded_uri']?.toString(),
      downloadedFileName: map['downloaded_file_name']?.toString(),
      voiceSource: (map['voice_source'] ?? 'cloned').toString(),
      voiceDisplayName: (map['voice_display_name'] ?? '').toString(),
      ttsSpeed: asDouble('tts_speed', 1.0),
      ttsStability: asDouble('tts_stability', 0.55),
      ttsSimilarityBoost: asDouble('tts_similarity_boost', 0.8),
      ttsStyle: asDouble('tts_style', 0.2),
      ttsUseSpeakerBoost: ((map['tts_use_speaker_boost'] ?? 1) as num).toInt() == 1,
      languageCode: (map['language_code'] ?? '').toString(),
      textNormalization: (map['text_normalization'] ?? 'auto').toString(),
      scene: (map['scene'] ?? 'natural_dialogue').toString(),
      pauseMode: (map['pause_mode'] ?? 'none').toString(),
      meditationAutoPauses: ((map['meditation_auto_pauses'] ?? 0) as num).toInt() == 1,
      meditationPauseProfile: (map['meditation_pause_profile'] ?? 'standard').toString(),
      meditationSentenceBreakSec: asDouble('meditation_sentence_break_sec', 1.5),
      meditationParagraphBreakSec: asDouble('meditation_paragraph_break_sec', 2.4),
      meditationBreathBreakSec: asDouble('meditation_breath_break_sec', 2.0),
      meditationTone: (map['meditation_tone'] ?? 'calm').toString(),
      meditationAutoBreathPauses: ((map['meditation_auto_breath_pauses'] ?? 1) as num).toInt() == 1,
      createdAt: ((map['created_at'] ?? 0) as num).toInt(),
      updatedAt: ((map['updated_at'] ?? 0) as num).toInt(),
    );
  }
}
