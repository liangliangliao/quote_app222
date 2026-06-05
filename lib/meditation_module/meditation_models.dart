class MeditationStep {
  final int startSecond;
  final String text;
  final int pauseAfterSeconds;
  final String? intent;

  const MeditationStep({
    required this.startSecond,
    required this.text,
    this.pauseAfterSeconds = 0,
    this.intent,
  });

  Map<String, dynamic> toJson() => {
        'start': startSecond,
        'text': text,
        'pause_after_seconds': pauseAfterSeconds,
        if ((intent ?? '').trim().isNotEmpty) 'intent': intent,
      };
}

class MeditationSessionTemplate {
  final String key;
  final String title;
  final String type;
  final String category;
  final String description;
  final int durationSeconds;
  final bool isSleep;
  final String source;
  final List<MeditationStep> steps;
  final String endingReflection;

  const MeditationSessionTemplate({
    required this.key,
    required this.title,
    required this.type,
    required this.category,
    required this.description,
    required this.durationSeconds,
    required this.steps,
    required this.endingReflection,
    this.isSleep = false,
    this.source = 'built_in',
  });

  int get durationMinutes => (durationSeconds / 60).round();
  bool get isAiGenerated => source == 'ai_generated';
}

class MeditationRecord {
  final int? id;
  final String sessionKey;
  final String title;
  final String type;
  final int startedAt;
  final int? endedAt;
  final int durationSeconds;
  final bool completed;
  final int? beforeMood;
  final int? afterMood;
  final int? distractionLevel;
  final int? bodyRelaxLevel;
  final String? currentState;
  final String? note;
  final String? aiFeedback;
  final int createdAt;

  const MeditationRecord({
    this.id,
    required this.sessionKey,
    required this.title,
    required this.type,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.completed,
    this.beforeMood,
    this.afterMood,
    this.distractionLevel,
    this.bodyRelaxLevel,
    this.currentState,
    this.note,
    this.aiFeedback,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_key': sessionKey,
        'title': title,
        'type': type,
        'started_at': startedAt,
        'ended_at': endedAt,
        'duration_seconds': durationSeconds,
        'completed': completed ? 1 : 0,
        'before_mood': beforeMood,
        'after_mood': afterMood,
        'distraction_level': distractionLevel,
        'body_relax_level': bodyRelaxLevel,
        'current_state': currentState,
        'note': note,
        'ai_feedback': aiFeedback,
        'created_at': createdAt,
      };

  factory MeditationRecord.fromMap(Map<String, dynamic> map) {
    int? asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return MeditationRecord(
      id: asInt(map['id']),
      sessionKey: (map['session_key'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      startedAt: asInt(map['started_at']) ?? 0,
      endedAt: asInt(map['ended_at']),
      durationSeconds: asInt(map['duration_seconds']) ?? 0,
      completed: (asInt(map['completed']) ?? 0) == 1,
      beforeMood: asInt(map['before_mood']),
      afterMood: asInt(map['after_mood']),
      distractionLevel: asInt(map['distraction_level']),
      bodyRelaxLevel: asInt(map['body_relax_level']),
      currentState: map['current_state']?.toString(),
      note: map['note']?.toString(),
      aiFeedback: map['ai_feedback']?.toString(),
      createdAt: asInt(map['created_at']) ?? 0,
    );
  }
}

class MeditationStats {
  final int totalSeconds;
  final int todaySeconds;
  final int weekCompletedCount;
  final int streakDays;
  final int totalCompletedCount;
  final String? mostUsedType;

  const MeditationStats({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.weekCompletedCount,
    required this.streakDays,
    required this.totalCompletedCount,
    this.mostUsedType,
  });
}


class MeditationWeeklySummary {
  final int? id;
  final String weekStart;
  final String weekEnd;
  final String summaryText;
  final String? statsJson;
  final int? aiOutputId;
  final int createdAt;
  final int updatedAt;

  const MeditationWeeklySummary({
    this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.summaryText,
    this.statsJson,
    this.aiOutputId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'week_start': weekStart,
        'week_end': weekEnd,
        'summary_text': summaryText,
        'stats_json': statsJson,
        'ai_output_id': aiOutputId,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory MeditationWeeklySummary.fromMap(Map<String, dynamic> map) {
    int? asInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    return MeditationWeeklySummary(
      id: asInt(map['id']),
      weekStart: (map['week_start'] ?? '').toString(),
      weekEnd: (map['week_end'] ?? '').toString(),
      summaryText: (map['summary_text'] ?? '').toString(),
      statsJson: map['stats_json']?.toString(),
      aiOutputId: asInt(map['ai_output_id']),
      createdAt: asInt(map['created_at']) ?? 0,
      updatedAt: asInt(map['updated_at']) ?? 0,
    );
  }
}

class MeditationSegmentAudioCache {
  final int? id;
  final String sessionKey;
  final String sessionTitle;
  final String sessionSource;
  final int segmentIndex;
  final int startSecond;
  final String textHash;
  final String voiceKey;
  final String provider;
  final String model;
  final String? ttsAudioId;
  final String audioPath;
  final int fileSize;
  final bool keepForever;
  final int lastUsedAt;
  final int createdAt;
  final int updatedAt;

  const MeditationSegmentAudioCache({
    this.id,
    required this.sessionKey,
    required this.sessionTitle,
    required this.sessionSource,
    required this.segmentIndex,
    required this.startSecond,
    required this.textHash,
    required this.voiceKey,
    required this.provider,
    required this.model,
    this.ttsAudioId,
    required this.audioPath,
    required this.fileSize,
    required this.keepForever,
    required this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'session_key': sessionKey,
        'session_title': sessionTitle,
        'session_source': sessionSource,
        'segment_index': segmentIndex,
        'start_second': startSecond,
        'text_hash': textHash,
        'voice_key': voiceKey,
        'provider': provider,
        'model': model,
        'tts_audio_id': ttsAudioId,
        'audio_path': audioPath,
        'file_size': fileSize,
        'keep_forever': keepForever ? 1 : 0,
        'last_used_at': lastUsedAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory MeditationSegmentAudioCache.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse((value ?? '').toString()) ?? 0;
    }

    return MeditationSegmentAudioCache(
      id: map['id'] == null ? null : asInt(map['id']),
      sessionKey: (map['session_key'] ?? '').toString(),
      sessionTitle: (map['session_title'] ?? '').toString(),
      sessionSource: (map['session_source'] ?? '').toString(),
      segmentIndex: asInt(map['segment_index']),
      startSecond: asInt(map['start_second']),
      textHash: (map['text_hash'] ?? '').toString(),
      voiceKey: (map['voice_key'] ?? '').toString(),
      provider: (map['provider'] ?? 'elevenlabs').toString(),
      model: (map['model'] ?? '').toString(),
      ttsAudioId: map['tts_audio_id']?.toString(),
      audioPath: (map['audio_path'] ?? '').toString(),
      fileSize: asInt(map['file_size']),
      keepForever: asInt(map['keep_forever']) == 1,
      lastUsedAt: asInt(map['last_used_at']),
      createdAt: asInt(map['created_at']),
      updatedAt: asInt(map['updated_at']),
    );
  }
}

class MeditationAudioCacheStats {
  final int fileCount;
  final int totalBytes;
  final int protectedCount;
  final int protectedBytes;

  const MeditationAudioCacheStats({
    required this.fileCount,
    required this.totalBytes,
    required this.protectedCount,
    required this.protectedBytes,
  });

  String get totalSizeText => formatBytes(totalBytes);
  String get protectedSizeText => formatBytes(protectedBytes);

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
  }
}
