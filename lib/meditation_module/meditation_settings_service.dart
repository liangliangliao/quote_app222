import '../data/kv_dao.dart';

class MeditationFeatureSettings {
  final bool showWeeklyAiSummary;
  final bool showCompletionRecordPage;
  final bool showCompletionFeedbackCard;
  final bool showCompletionMoodRatings;
  final bool showCompletionNoteInput;
  final bool showPracticeAiFeedback;
  final bool loopPlaybackEnabled;
  final int autoExitMinutes;

  const MeditationFeatureSettings({
    required this.showWeeklyAiSummary,
    required this.showCompletionRecordPage,
    required this.showCompletionFeedbackCard,
    required this.showCompletionMoodRatings,
    required this.showCompletionNoteInput,
    required this.showPracticeAiFeedback,
    required this.loopPlaybackEnabled,
    required this.autoExitMinutes,
  });

  factory MeditationFeatureSettings.defaults() => const MeditationFeatureSettings(
        showWeeklyAiSummary: true,
        showCompletionRecordPage: true,
        showCompletionFeedbackCard: true,
        showCompletionMoodRatings: true,
        showCompletionNoteInput: true,
        showPracticeAiFeedback: true,
        loopPlaybackEnabled: false,
        autoExitMinutes: 0,
      );

  MeditationFeatureSettings copyWith({
    bool? showWeeklyAiSummary,
    bool? showCompletionRecordPage,
    bool? showCompletionFeedbackCard,
    bool? showCompletionMoodRatings,
    bool? showCompletionNoteInput,
    bool? showPracticeAiFeedback,
    bool? loopPlaybackEnabled,
    int? autoExitMinutes,
  }) {
    return MeditationFeatureSettings(
      showWeeklyAiSummary: showWeeklyAiSummary ?? this.showWeeklyAiSummary,
      showCompletionRecordPage: showCompletionRecordPage ?? this.showCompletionRecordPage,
      showCompletionFeedbackCard: showCompletionFeedbackCard ?? this.showCompletionFeedbackCard,
      showCompletionMoodRatings: showCompletionMoodRatings ?? this.showCompletionMoodRatings,
      showCompletionNoteInput: showCompletionNoteInput ?? this.showCompletionNoteInput,
      showPracticeAiFeedback: showPracticeAiFeedback ?? this.showPracticeAiFeedback,
      loopPlaybackEnabled: loopPlaybackEnabled ?? this.loopPlaybackEnabled,
      autoExitMinutes: autoExitMinutes ?? this.autoExitMinutes,
    );
  }
}

class MeditationSettingsService {
  MeditationSettingsService({KeyValueDao? kvDao}) : _kvDao = kvDao ?? KeyValueDao();

  final KeyValueDao _kvDao;

  static const String showWeeklyAiSummaryKey = 'meditation.feature.show_weekly_ai_summary';
  static const String showCompletionRecordPageKey = 'meditation.feature.show_completion_record_page';
  static const String showCompletionFeedbackCardKey = 'meditation.feature.show_completion_feedback_card';
  static const String showCompletionMoodRatingsKey = 'meditation.feature.show_completion_mood_ratings';
  static const String showCompletionNoteInputKey = 'meditation.feature.show_completion_note_input';
  static const String showPracticeAiFeedbackKey = 'meditation.feature.show_practice_ai_feedback';
  static const String loopPlaybackEnabledKey = 'meditation.playback.loop_enabled';
  static const String autoExitMinutesKey = 'meditation.playback.auto_exit_minutes';

  bool _parseBool(String? value, bool fallback) {
    if (value == null) return fallback;
    final raw = value.trim().toLowerCase();
    return raw == '1' || raw == 'true' || raw == 'yes';
  }

  int _parseInt(String? value, int fallback) => int.tryParse((value ?? '').trim()) ?? fallback;

  Future<MeditationFeatureSettings> load() async {
    final defaults = MeditationFeatureSettings.defaults();
    return MeditationFeatureSettings(
      showWeeklyAiSummary: _parseBool(await _kvDao.getString(showWeeklyAiSummaryKey), defaults.showWeeklyAiSummary),
      showCompletionRecordPage: _parseBool(await _kvDao.getString(showCompletionRecordPageKey), defaults.showCompletionRecordPage),
      showCompletionFeedbackCard: _parseBool(await _kvDao.getString(showCompletionFeedbackCardKey), defaults.showCompletionFeedbackCard),
      showCompletionMoodRatings: _parseBool(await _kvDao.getString(showCompletionMoodRatingsKey), defaults.showCompletionMoodRatings),
      showCompletionNoteInput: _parseBool(await _kvDao.getString(showCompletionNoteInputKey), defaults.showCompletionNoteInput),
      showPracticeAiFeedback: _parseBool(await _kvDao.getString(showPracticeAiFeedbackKey), defaults.showPracticeAiFeedback),
      loopPlaybackEnabled: _parseBool(await _kvDao.getString(loopPlaybackEnabledKey), defaults.loopPlaybackEnabled),
      autoExitMinutes: _parseInt(await _kvDao.getString(autoExitMinutesKey), defaults.autoExitMinutes).clamp(0, 24 * 60).toInt(),
    );
  }

  Future<void> save(MeditationFeatureSettings settings) async {
    await _kvDao.setString(showWeeklyAiSummaryKey, settings.showWeeklyAiSummary ? '1' : '0');
    await _kvDao.setString(showCompletionRecordPageKey, settings.showCompletionRecordPage ? '1' : '0');
    await _kvDao.setString(showCompletionFeedbackCardKey, settings.showCompletionFeedbackCard ? '1' : '0');
    await _kvDao.setString(showCompletionMoodRatingsKey, settings.showCompletionMoodRatings ? '1' : '0');
    await _kvDao.setString(showCompletionNoteInputKey, settings.showCompletionNoteInput ? '1' : '0');
    await _kvDao.setString(showPracticeAiFeedbackKey, settings.showPracticeAiFeedback ? '1' : '0');
    await _kvDao.setString(loopPlaybackEnabledKey, settings.loopPlaybackEnabled ? '1' : '0');
    await _kvDao.setString(autoExitMinutesKey, settings.autoExitMinutes.toString());
  }
}
