import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../voice_lab/eleven_labs_service.dart';
import '../voice_lab/multi_provider_tts_service.dart';
import '../voice_lab/voice_lab_models.dart';
import 'meditation_ai_service.dart';
import 'meditation_audio_service.dart';
import 'meditation_dao.dart';
import 'meditation_models.dart';
import 'meditation_settings_service.dart';

class MeditationPlayerPage extends StatefulWidget {
  final MeditationSessionTemplate session;
  final String currentState;
  final bool timerOnly;
  final MeditationFeatureSettings? featureSettings;

  const MeditationPlayerPage({
    super.key,
    required this.session,
    this.currentState = '日常练习',
    this.timerOnly = false,
    this.featureSettings,
  });

  @override
  State<MeditationPlayerPage> createState() => _MeditationPlayerPageState();
}

class _MeditationPlayerPageState extends State<MeditationPlayerPage> with TickerProviderStateMixin {
  late final AnimationController _breathController;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = false;
  bool _practiceStarted = false;
  bool _blockingAutoAudioPreparation = false;
  bool _audioPreparationFailed = false;
  bool _audioSetupLoading = true;
  late int _startedAt;
  final MeditationAudioService _audioService = MeditationAudioService();
  final MeditationDao _dao = MeditationDao();
  final MeditationSettingsService _settingsService = MeditationSettingsService();
  final AudioPlayer _guidedPlayer = AudioPlayer();
  final AudioPlayer _backgroundPlayer = AudioPlayer();
  TtsAudioFile? _guidedAudio;
  bool _generatingGuidedAudio = false;
  bool _guidedAudioPlaying = false;
  bool _backgroundPlaying = false;
  String _selectedBackground = 'none';
  double _voiceVolume = 0.92;
  double _backgroundVolume = 0.26;
  int _sleepTimerMinutes = 0;
  String? _audioStatus;
  MeditationTtsRuntimeSettings? _ttsSettings;
  bool _segmentVoiceEnabled = false;
  bool _autoPrepareSegmentVoice = false;
  bool _preparingSegmentAudio = false;
  int _segmentPreparedCount = 0;
  int _segmentTotalCount = 0;
  int _currentSegmentIndex = 0;
  final Map<int, MeditationSegmentAudioCache> _segmentAudioByIndex = <int, MeditationSegmentAudioCache>{};
  bool _keepCurrentSessionAudio = false;
  MeditationAudioCacheStats? _cacheStats;
  MeditationFeatureSettings _featureSettings = MeditationFeatureSettings.defaults();
  int _totalPracticeSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now().millisecondsSinceEpoch;
    _featureSettings = widget.featureSettings ?? MeditationFeatureSettings.defaults();
    _sleepTimerMinutes = _featureSettings.autoExitMinutes;
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _guidedPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _guidedAudioPlaying = false);
    });
    _currentSegmentIndex = _findCurrentStepIndex(_elapsedSeconds);
    _loadFeatureSettingsAndAudio();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAllAudio();
    _guidedPlayer.dispose();
    _backgroundPlayer.dispose();
    _breathController.dispose();
    super.dispose();
  }


  Future<void> _loadFeatureSettingsAndAudio() async {
    try {
      final settings = await _settingsService.load();
      if (mounted) {
        setState(() {
          _featureSettings = settings;
          _sleepTimerMinutes = settings.autoExitMinutes;
        });
      }
    } catch (_) {}
    await _loadSegmentAudioSettings();
  }

  Future<void> _loadSegmentAudioSettings() async {
    try {
      final settings = await _audioService.loadTtsRuntimeSettings(sessionKey: widget.session.key);
      final keep = await _dao.isSegmentAudioCacheProtected(widget.session.key);
      final stats = await _dao.loadSegmentAudioCacheStats();
      var matchingCaches = settings.segmentVoiceEnabled && !widget.timerOnly
          ? await _loadMatchingSegmentCaches(settings)
          : <int, MeditationSegmentAudioCache>{};
      // 保存当前冥想的 TTS 参数不会自动使旧语音失效。
      // 只有用户点击“重新生成”时才会按新参数覆盖生成。
      // 因此如果当前参数没有命中缓存，但该冥想已有完整逐句语音，继续沿用原缓存。
      if (settings.segmentVoiceEnabled && !widget.timerOnly && !_hasCompleteSegmentCache(matchingCaches)) {
        final existingCompleteCaches = await _loadAnyCompleteSegmentCachesForCurrentSession();
        if (_hasCompleteSegmentCache(existingCompleteCaches)) {
          matchingCaches = existingCompleteCaches;
        }
      }
      if (!mounted) return;
      setState(() {
        _ttsSettings = settings;
        _segmentVoiceEnabled = settings.segmentVoiceEnabled;
        _autoPrepareSegmentVoice = settings.autoPrepareSegmentVoice;
        _keepCurrentSessionAudio = keep;
        _cacheStats = stats;
        _segmentAudioByIndex
          ..clear()
          ..addAll(matchingCaches);
        _audioStatus = settings.segmentVoiceEnabled
            ? '已从缓存加载逐句语音 ${matchingCaches.length}/${widget.session.steps.length}。'
            : '逐句同步语音未开启。';
      });

      if (widget.timerOnly) {
        await _startPractice(playCurrentSegment: false);
        return;
      }

      if (!settings.segmentVoiceEnabled) {
        await _startPractice(playCurrentSegment: false);
        return;
      }

      if (settings.autoPrepareSegmentVoice) {
        final complete = _hasCompleteSegmentCache(matchingCaches);
        if (complete) {
          if (!mounted) return;
          setState(() => _audioStatus = '逐句语音已从缓存加载完成，即将开始冥想。');
          await _startPractice(playCurrentSegment: true);
        } else {
          if (!mounted) return;
          setState(() {
            _blockingAutoAudioPreparation = true;
            _audioPreparationFailed = false;
            _audioSetupLoading = false;
            _segmentPreparedCount = matchingCaches.length;
            _segmentTotalCount = widget.session.steps.where((e) => e.text.trim().isNotEmpty).length;
            _audioStatus = '准备进度：$_segmentPreparedCount/$_segmentTotalCount';
          });
          await _prepareSegmentAudios(forceRegenerate: false, playAfter: true);
        }
      } else {
        await _startPractice(playCurrentSegment: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _audioStatus = '读取冥想语音设置失败：$e';
          _audioPreparationFailed = true;
          _audioSetupLoading = false;
          _blockingAutoAudioPreparation = false;
        });
        await _startPractice(playCurrentSegment: false);
      }
    }
  }

  Future<void> _startPractice({bool playCurrentSegment = true}) async {
    if (_practiceStarted || !mounted) return;
    setState(() {
      _practiceStarted = true;
      _running = true;
      _blockingAutoAudioPreparation = false;
      _audioPreparationFailed = false;
      _audioSetupLoading = false;
    });
    _startedAt = DateTime.now().millisecondsSinceEpoch;
    _totalPracticeSeconds = 0;
    _breathController.repeat(reverse: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (playCurrentSegment && _segmentVoiceEnabled && !widget.timerOnly) {
      await _playSegmentVoice(_currentSegmentIndex);
    }
  }

  bool _hasCompleteSegmentCache(Map<int, MeditationSegmentAudioCache> caches) {
    if (widget.session.steps.isEmpty) return false;
    for (var i = 0; i < widget.session.steps.length; i++) {
      final step = widget.session.steps[i];
      if (step.text.trim().isEmpty) continue;
      final cache = caches[i];
      if (cache == null || !File(cache.audioPath).existsSync()) return false;
    }
    return true;
  }

  Future<Map<int, MeditationSegmentAudioCache>> _loadMatchingSegmentCaches(MeditationTtsRuntimeSettings settings) async {
    final result = <int, MeditationSegmentAudioCache>{};
    for (var i = 0; i < widget.session.steps.length; i++) {
      final step = widget.session.steps[i];
      if (step.text.trim().isEmpty) continue;
      try {
        final key = await _audioService.resolveSegmentCacheKey(step: step, settings: settings);
        final cache = await _dao.findSegmentAudioCache(
          sessionKey: widget.session.key,
          segmentIndex: i,
          textHash: key.textHash,
          voiceKey: key.voiceKey,
          model: key.modelId,
        );
        if (cache != null && File(cache.audioPath).existsSync()) {
          result[i] = cache;
        }
      } catch (_) {}
    }
    return result;
  }

  Future<Map<int, MeditationSegmentAudioCache>> _loadAnyCompleteSegmentCachesForCurrentSession() async {
    final allCaches = await _dao.segmentAudioCachesForSession(widget.session.key);
    if (allCaches.isEmpty) return <int, MeditationSegmentAudioCache>{};
    final latestByIndex = <int, MeditationSegmentAudioCache>{};
    for (final cache in allCaches) {
      if (cache.segmentIndex < 0 || cache.segmentIndex >= widget.session.steps.length) continue;
      if (!File(cache.audioPath).existsSync()) continue;
      final current = latestByIndex[cache.segmentIndex];
      if (current == null || cache.updatedAt > current.updatedAt || cache.lastUsedAt > current.lastUsedAt) {
        latestByIndex[cache.segmentIndex] = cache;
      }
    }
    return latestByIndex;
  }

  int _findCurrentStepIndex(int elapsedSeconds) {
    if (widget.session.steps.isEmpty) return 0;
    var index = 0;
    for (var i = 0; i < widget.session.steps.length; i++) {
      if (elapsedSeconds >= widget.session.steps[i].startSecond) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  Future<void> _reloadSegmentCaches() async {
    final settings = _ttsSettings ?? await _audioService.loadTtsRuntimeSettings(sessionKey: widget.session.key);
    var caches = await _loadMatchingSegmentCaches(settings);
    if (!_hasCompleteSegmentCache(caches)) {
      final existingCompleteCaches = await _loadAnyCompleteSegmentCachesForCurrentSession();
      if (_hasCompleteSegmentCache(existingCompleteCaches)) {
        caches = existingCompleteCaches;
      }
    }
    final stats = await _dao.loadSegmentAudioCacheStats();
    if (!mounted) return;
    setState(() {
      _cacheStats = stats;
      _segmentAudioByIndex
        ..clear()
        ..addAll(caches);
    });
  }

  Future<void> _prepareSegmentAudios({bool forceRegenerate = false, bool playAfter = false}) async {
    if (widget.timerOnly) return;
    final settings = _ttsSettings ?? await _audioService.loadTtsRuntimeSettings(sessionKey: widget.session.key);
    final total = widget.session.steps.where((e) => e.text.trim().isNotEmpty).length;
    if (forceRegenerate) {
      await _guidedPlayer.stop();
      await _audioService.stopSystemTts();
      await _dao.deleteSegmentAudioCachesForSession(widget.session.key);
      _segmentAudioByIndex.clear();
    }
    final existingCaches = forceRegenerate
        ? <int, MeditationSegmentAudioCache>{}
        : await _loadAnyCompleteSegmentCachesForCurrentSession();
    setState(() {
      _ttsSettings = settings;
      _preparingSegmentAudio = true;
      _audioSetupLoading = false;
      _segmentPreparedCount = 0;
      _segmentTotalCount = total;
      _audioPreparationFailed = false;
      if (forceRegenerate) {
        _segmentAudioByIndex.clear();
      }
      if (settings.autoPrepareSegmentVoice && settings.segmentVoiceEnabled && !_practiceStarted) {
        _blockingAutoAudioPreparation = true;
      }
      _audioStatus = forceRegenerate
          ? '正在按新参数重新生成逐句语音：0/$_segmentTotalCount'
          : '准备进度：0/$_segmentTotalCount';
    });
    try {
      var prepared = 0;
      for (var i = 0; i < widget.session.steps.length; i++) {
        final step = widget.session.steps[i];
        if (step.text.trim().isEmpty) continue;
        final now = DateTime.now().millisecondsSinceEpoch;
        MeditationSegmentAudioCache? cache;

        if (!forceRegenerate) {
          // 保存参数不会让旧缓存失效：优先使用该冥想当前已有的最新片段缓存。
          cache = existingCaches[i];
          if (cache != null && !File(cache.audioPath).existsSync()) cache = null;
          if (cache == null) {
            final key = await _audioService.resolveSegmentCacheKey(step: step, settings: settings);
            cache = await _dao.findSegmentAudioCache(
              sessionKey: widget.session.key,
              segmentIndex: i,
              textHash: key.textHash,
              voiceKey: key.voiceKey,
              model: key.modelId,
            );
            if (cache != null && !File(cache.audioPath).existsSync()) cache = null;
          }
        }

        if (cache == null) {
          if (!mounted) return;
          setState(() => _audioStatus = forceRegenerate ? '正在按新参数重新生成逐句语音：$prepared/$_segmentTotalCount' : '准备进度：$prepared/$_segmentTotalCount');
          final result = await _audioService.synthesizeSegmentGuidedAudio(
            step: step,
            settings: settings,
            forceRegenerate: forceRegenerate,
          );
          final audioFile = File(result.audio.audioFilePath);
          final fileSize = await audioFile.exists() ? await audioFile.length() : result.audio.fileSize;
          cache = MeditationSegmentAudioCache(
            sessionKey: widget.session.key,
            sessionTitle: widget.session.title,
            sessionSource: widget.session.source,
            segmentIndex: i,
            startSecond: step.startSecond,
            textHash: result.textHash,
            voiceKey: result.voiceKey,
            provider: result.audio.provider,
            model: result.modelId,
            ttsAudioId: result.audio.id,
            audioPath: result.audio.audioFilePath,
            fileSize: fileSize,
            keepForever: _keepCurrentSessionAudio,
            lastUsedAt: now,
            createdAt: now,
            updatedAt: now,
          );
          await _dao.upsertSegmentAudioCache(cache);
        } else {
          if (cache.id != null) await _dao.markSegmentAudioUsed(cache.id!);
        }

        prepared += 1;
        if (!mounted) return;
        setState(() {
          _segmentPreparedCount = prepared;
          _segmentAudioByIndex[i] = cache!;
          _audioStatus = forceRegenerate ? '正在按新参数重新生成逐句语音：$_segmentPreparedCount/$_segmentTotalCount' : '准备进度：$_segmentPreparedCount/$_segmentTotalCount';
        });
      }
      await _dao.cleanupSegmentAudioCache(
        maxBytes: settings.maxCacheBytes,
        aiRetentionDays: settings.aiRetentionDays,
      );
      await _reloadSegmentCaches();
      if (!mounted) return;
      setState(() {
        _audioStatus = forceRegenerate ? '逐句语音已按新参数重新生成完成。' : '逐句语音已准备完成。';
        _blockingAutoAudioPreparation = false;
        _audioPreparationFailed = false;
      });
      if (forceRegenerate && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('逐句语音已重新生成完成，可直接播放新语音。')),
        );
      }
      if (playAfter && settings.segmentVoiceEnabled) {
        if (!_practiceStarted) {
          await _startPractice(playCurrentSegment: true);
        } else if (_running) {
          await _playSegmentVoice(_currentSegmentIndex);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _audioStatus = '逐句语音准备失败：$e';
        _audioPreparationFailed = true;
        _blockingAutoAudioPreparation = !_practiceStarted;
      });
    } finally {
      if (mounted) setState(() => _preparingSegmentAudio = false);
    }
  }

  Future<void> _playSegmentVoice(int index) async {
    if (!_segmentVoiceEnabled || widget.timerOnly || !_running) return;
    if (index < 0 || index >= widget.session.steps.length) return;
    final step = widget.session.steps[index];
    final cache = _segmentAudioByIndex[index];
    try {
      await _guidedPlayer.stop();
      await _audioService.stopSystemTts();
      if (cache != null && File(cache.audioPath).existsSync()) {
        await _guidedPlayer.setVolume(_voiceVolume);
        await _guidedPlayer.play(DeviceFileSource(cache.audioPath), volume: _voiceVolume);
        if (cache.id != null) await _dao.markSegmentAudioUsed(cache.id!);
        if (mounted) {
          setState(() {
            _guidedAudioPlaying = true;
            _audioStatus = '正在播放第 ${index + 1} 段逐句语音。';
          });
        }
      } else {
        await _audioService.speakWithSystemTts(step.text, volume: _voiceVolume);
        if (mounted) {
          setState(() {
            _guidedAudioPlaying = true;
            _audioStatus = '第 ${index + 1} 段未缓存，已临时使用系统朗读。';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _audioStatus = '当前句语音播放失败：$e');
    }
  }

  Future<void> _saveSegmentTtsSettings(MeditationTtsRuntimeSettings settings, {bool prepareNow = false}) async {
    await _audioService.saveTtsRuntimeSettings(settings, sessionKey: widget.session.key);
    if (!mounted) return;
    setState(() {
      _ttsSettings = settings;
      _segmentVoiceEnabled = settings.segmentVoiceEnabled;
      _autoPrepareSegmentVoice = settings.autoPrepareSegmentVoice;
      _audioStatus = '本冥想的语音参数已保存；不会重新生成，旧缓存仍会继续使用。';
    });
    if (prepareNow && settings.segmentVoiceEnabled) {
      await _prepareSegmentAudios(forceRegenerate: false, playAfter: true);
    } else {
      await _reloadSegmentCaches();
      if (settings.segmentVoiceEnabled) {
        await _playSegmentVoice(_currentSegmentIndex);
      }
    }
  }

  Future<void> _setKeepCurrentSessionAudio(bool keep) async {
    await _dao.setSegmentAudioKeepForeverForSession(widget.session.key, keep);
    if (!mounted) return;
    setState(() {
      _keepCurrentSessionAudio = keep;
      _audioStatus = keep ? '本次冥想语音已设为长期保留。' : '本次冥想语音已取消长期保留。';
    });
    await _reloadSegmentCaches();
  }

  Future<void> _cleanupCache({required bool all, required bool unprotectedOnly}) async {
    final settings = _ttsSettings ?? await _audioService.loadTtsRuntimeSettings(sessionKey: widget.session.key);
    final count = await _dao.cleanupSegmentAudioCache(
      maxBytes: settings.maxCacheBytes,
      aiRetentionDays: settings.aiRetentionDays,
      clearAll: all,
      clearUnprotected: unprotectedOnly,
    );
    await _reloadSegmentCaches();
    if (!mounted) return;
    setState(() => _audioStatus = '已清理 $count 个冥想语音片段缓存。');
  }

  Future<void> _stopAllAudio() async {
    try {
      await _guidedPlayer.stop();
      await _backgroundPlayer.stop();
      await _audioService.stopSystemTts();
    } catch (_) {}
  }

  Future<void> _pauseAllAudio() async {
    try {
      await _guidedPlayer.pause();
      await _backgroundPlayer.pause();
      await _audioService.pauseSystemTts();
    } catch (_) {}
  }

  Future<void> _resumeAmbientAudio() async {
    try {
      if (_guidedAudioPlaying) await _guidedPlayer.resume();
      if (_backgroundPlaying) await _backgroundPlayer.resume();
    } catch (_) {}
  }

  Future<void> _toggleGuidedAudio({bool forceRegenerate = false}) async {
    if (_guidedAudioPlaying) {
      await _guidedPlayer.pause();
      await _audioService.pauseSystemTts();
      if (mounted) {
        setState(() {
          _guidedAudioPlaying = false;
          _audioStatus = '语音引导已暂停。';
        });
      }
      return;
    }

    final cached = _guidedAudio;
    if (!forceRegenerate && cached != null && File(cached.audioFilePath).existsSync()) {
      await _guidedPlayer.setVolume(_voiceVolume);
      await _guidedPlayer.play(DeviceFileSource(cached.audioFilePath), volume: _voiceVolume);
      if (mounted) {
        setState(() {
          _guidedAudioPlaying = true;
          _audioStatus = '正在播放已缓存语音引导。';
        });
      }
      return;
    }

    setState(() {
      _generatingGuidedAudio = true;
      _audioStatus = '正在生成语音引导……';
    });
    try {
      final audio = await _audioService.synthesizeGuidedAudio(
        session: widget.session,
        forceRegenerate: forceRegenerate,
      );
      if (!mounted) return;
      _guidedAudio = audio;
      await _guidedPlayer.setVolume(_voiceVolume);
      await _guidedPlayer.play(DeviceFileSource(audio.audioFilePath), volume: _voiceVolume);
      setState(() {
        _guidedAudioPlaying = true;
        _audioStatus = '语音已生成并缓存，正在播放。';
      });
    } catch (e) {
      if (!mounted) return;
      final fallbackText = _audioService.buildGuidedSpeechText(widget.session);
      try {
        await _audioService.speakWithSystemTts(fallbackText, volume: _voiceVolume);
        setState(() {
          _guidedAudioPlaying = true;
          _audioStatus = '未能生成缓存音频，已改用系统朗读：$e';
        });
      } catch (inner) {
        setState(() => _audioStatus = '语音引导不可用：$e / $inner');
      }
    } finally {
      if (mounted) setState(() => _generatingGuidedAudio = false);
    }
  }

  Future<void> _changeBackgroundSound(String soundId) async {
    setState(() {
      _selectedBackground = soundId;
      _audioStatus = soundId == 'none' ? '已关闭背景音。' : '正在准备背景音……';
    });
    try {
      await _backgroundPlayer.stop();
      if (soundId == 'none') {
        if (mounted) setState(() => _backgroundPlaying = false);
        return;
      }
      final path = await _audioService.prepareBackgroundSound(soundId);
      if (path.isEmpty) return;
      await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
      await _backgroundPlayer.setVolume(_backgroundVolume);
      await _backgroundPlayer.play(DeviceFileSource(path), volume: _backgroundVolume);
      if (!mounted) return;
      setState(() {
        _backgroundPlaying = true;
        _audioStatus = '背景音已开启：${_backgroundLabel(soundId)}。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _backgroundPlaying = false;
        _audioStatus = '背景音开启失败：$e';
      });
    }
  }

  String _backgroundLabel(String soundId) {
    for (final item in MeditationAudioService.backgroundSounds) {
      if (item.id == soundId) return item.label;
    }
    return '无背景音';
  }

  Future<void> _openAudioSheet() async {
    final base = _ttsSettings ?? await _audioService.loadTtsRuntimeSettings(sessionKey: widget.session.key);
    var draft = base;
    String? sheetMessage;
    var availableVoices = <ElevenLabsVoiceOption>[
      ElevenLabsVoiceOption(
        voiceId: base.presetVoiceId,
        name: base.presetVoiceName.trim().isEmpty ? base.presetVoiceId : base.presetVoiceName,
        category: '当前',
      ),
    ];
    var availableModels = <ElevenLabsModelOption>[
      ElevenLabsModelOption(modelId: base.modelId, name: base.modelId),
    ];
    var availableResembleVoices = <ProviderCatalogOption>[
      ProviderCatalogOption(
        id: base.resembleVoiceUuid,
        name: base.resembleVoiceName.trim().isEmpty ? (base.resembleVoiceUuid.trim().isEmpty ? '未选择 Resemble voice_uuid' : base.resembleVoiceUuid) : base.resembleVoiceName,
        category: '当前',
      ),
    ];
    var availableResembleModels = <ProviderCatalogOption>[
      ProviderCatalogOption(
        id: base.resembleModel,
        name: base.resembleModel.trim().isEmpty ? '自动选择 / Chatterbox' : base.resembleModel,
        description: base.resembleModel.trim().isEmpty ? '推荐：让 Resemble 自动选择兼容模型' : '',
      ),
    ];
    var availableResembleProfiles = await _audioService.loadVoiceProfilesByProvider('resemble');
    var loadingElevenLabsOptions = false;
    var loadingResembleOptions = false;
    String? elevenLabsOptionsError;
    String? resembleOptionsError;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> loadElevenLabsOptionsOnTap() async {
              if (loadingElevenLabsOptions) return;
              loadingElevenLabsOptions = true;
              elevenLabsOptionsError = null;
              setSheetState(() {});
              try {
                final voices = await _audioService.loadPremadeVoiceOptions();
                final models = await _audioService.loadTtsModelOptions();
                final mergedVoices = <String, ElevenLabsVoiceOption>{
                  for (final v in availableVoices) v.voiceId: v,
                  for (final v in voices) v.voiceId: v,
                }.values.toList();
                final mergedModels = <String, ElevenLabsModelOption>{
                  for (final m in availableModels) m.modelId: m,
                  for (final m in models) m.modelId: m,
                }.values.toList();
                availableVoices = mergedVoices;
                availableModels = mergedModels;
              } catch (e) {
                elevenLabsOptionsError = '声音或模型列表加载失败：$e';
              } finally {
                loadingElevenLabsOptions = false;
                if (context.mounted) setSheetState(() {});
              }
            }

            Future<void> loadResembleOptionsOnTap() async {
              if (loadingResembleOptions) return;
              loadingResembleOptions = true;
              resembleOptionsError = null;
              setSheetState(() {});
              try {
                final voices = await _audioService.loadResembleVoiceOptions();
                final models = await _audioService.loadResembleModelOptions();
                final profiles = await _audioService.loadVoiceProfilesByProvider('resemble');
                final mergedVoices = <String, ProviderCatalogOption>{
                  for (final v in availableResembleVoices) v.id: v,
                  for (final v in voices) v.id: v,
                }.values.toList();
                final mergedModels = <String, ProviderCatalogOption>{
                  for (final m in availableResembleModels) m.id: m,
                  for (final m in models) m.id: m,
                }.values.toList();
                availableResembleVoices = mergedVoices;
                availableResembleModels = mergedModels;
                availableResembleProfiles = profiles;
              } catch (e) {
                resembleOptionsError = 'Resemble 声音或模型列表加载失败：$e';
              } finally {
                loadingResembleOptions = false;
                if (context.mounted) setSheetState(() {});
              }
            }


            Future<void> refresh(Future<void> Function() action) async {
              await action();
              if (context.mounted) setSheetState(() {});
            }

            void updateDraft(MeditationTtsRuntimeSettings value) {
              draft = value;
              setSheetState(() {});
            }

            Widget sectionTitle(String text) => Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                );

            Widget sliderRow({required String label, required double value, required double min, required double max, int? divisions, required ValueChanged<double> onChanged, String suffix = ''}) {
              return Row(
                children: [
                  SizedBox(width: 92, child: Text(label)),
                  Expanded(
                    child: Slider(
                      value: value.clamp(min, max).toDouble(),
                      min: min,
                      max: max,
                      divisions: divisions,
                      label: '${value.toStringAsFixed(value >= 10 ? 0 : 2)}$suffix',
                      onChanged: onChanged,
                    ),
                  ),
                  SizedBox(width: 54, child: Text('${value.toStringAsFixed(value >= 10 ? 0 : 2)}$suffix', textAlign: TextAlign.right)),
                ],
              );
            }

            final cacheStats = _cacheStats;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('语音与背景音', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        '逐句同步语音会把每一句冥想脚本生成独立音频片段，并在该句文字出现时立即播放。片段会受缓存上限、过期天数和长期保留开关管理。',
                        style: TextStyle(color: Colors.black.withOpacity(0.58), height: 1.45),
                      ),
                      sectionTitle('逐句同步语音'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('开启逐句同步语音'),
                        subtitle: const Text('当前句子出现在页面时，立刻播放对应语音片段。'),
                        value: draft.segmentVoiceEnabled,
                        onChanged: (v) => updateDraft(draft.copyWith(segmentVoiceEnabled: v)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('进入播放页自动准备语音'),
                        subtitle: const Text('会消耗 TTS 额度；关闭后可手动点击“准备逐句语音”。'),
                        value: draft.autoPrepareSegmentVoice,
                        onChanged: (v) => updateDraft(draft.copyWith(autoPrepareSegmentVoice: v)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _preparingSegmentAudio
                                  ? null
                                  : () => refresh(() async {
                                        await _saveSegmentTtsSettings(draft, prepareNow: true);
                                      }),
                              icon: _preparingSegmentAudio
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.graphic_eq),
                              label: Text(_preparingSegmentAudio ? '准备中 $_segmentPreparedCount/$_segmentTotalCount' : '保存参数并补齐缺失语音'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _preparingSegmentAudio
                                ? null
                                : () => refresh(() async {
                                      await _saveSegmentTtsSettings(draft);
                                      await _prepareSegmentAudios(forceRegenerate: true, playAfter: draft.segmentVoiceEnabled);
                                    }),
                            child: const Text('重新生成并覆盖'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('长期保留本次冥想语音'),
                        subtitle: const Text('开启后，本次冥想的语音片段不会被自动清理。'),
                        value: _keepCurrentSessionAudio,
                        onChanged: (v) => refresh(() => _setKeepCurrentSessionAudio(v)),
                      ),
                      sectionTitle('文字转语音平台'),
                      Text(
                        '当前冥想可单独选择 ElevenLabs 或 Resemble AI。不同平台的声音、模型和专属参数彼此独立，只保存到当前冥想，不影响其他冥想已经生成并缓存的语音。',
                        style: TextStyle(color: Colors.black.withOpacity(0.56), fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('ElevenLabs'),
                            selected: draft.ttsProvider != 'resemble',
                            onSelected: (_) => updateDraft(draft.copyWith(ttsProvider: 'elevenlabs')),
                          ),
                          ChoiceChip(
                            label: const Text('Resemble AI'),
                            selected: draft.ttsProvider == 'resemble',
                            onSelected: (_) => updateDraft(draft.copyWith(ttsProvider: 'resemble')),
                          ),
                        ],
                      ),
                      if (draft.ttsProvider != 'resemble') ...[
                        sectionTitle('ElevenLabs 声音与模型'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('普通声音'),
                              selected: draft.voiceSource == 'premade',
                              onSelected: (_) => updateDraft(draft.copyWith(voiceSource: 'premade')),
                            ),
                            ChoiceChip(
                              label: const Text('克隆声音'),
                              selected: draft.voiceSource == 'cloned',
                              onSelected: (_) => updateDraft(draft.copyWith(voiceSource: 'cloned')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (loadingElevenLabsOptions) ...[
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 8),
                          const Text('正在按本次点击加载 ElevenLabs 普通声音和 TTS 模型列表……', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 8),
                        ],
                        if ((elevenLabsOptionsError ?? '').isNotEmpty) ...[
                          Text(elevenLabsOptionsError!, style: const TextStyle(fontSize: 12, color: Colors.deepOrange, height: 1.4)),
                          const SizedBox(height: 8),
                        ],
                        DropdownButtonFormField<String>(
                          value: availableVoices.any((v) => v.voiceId == draft.presetVoiceId) ? draft.presetVoiceId : availableVoices.first.voiceId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '普通声音 voice_id', border: OutlineInputBorder()),
                          onTap: loadElevenLabsOptionsOnTap,
                          items: availableVoices.map((voice) {
                            final title = voice.name.trim().isEmpty ? voice.voiceId : voice.name.trim();
                            final sub = voice.labelSummary.trim().isEmpty ? voice.voiceId : '${voice.labelSummary} · ${voice.voiceId}';
                            return DropdownMenuItem<String>(
                              value: voice.voiceId,
                              child: Text('$title\n$sub', maxLines: 2, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: draft.voiceSource == 'premade'
                              ? (v) {
                                  if (v == null) return;
                                  final selected = availableVoices.firstWhere(
                                    (voice) => voice.voiceId == v,
                                    orElse: () => ElevenLabsVoiceOption(voiceId: v, name: v),
                                  );
                                  updateDraft(draft.copyWith(
                                    presetVoiceId: selected.voiceId,
                                    presetVoiceName: selected.name.trim().isEmpty ? selected.voiceId : selected.name.trim(),
                                  ));
                                }
                              : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: availableModels.any((m) => m.modelId == draft.modelId) ? draft.modelId : availableModels.first.modelId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'TTS 模型 model_id', border: OutlineInputBorder()),
                          onTap: loadElevenLabsOptionsOnTap,
                          items: availableModels.map((model) {
                            final desc = model.description.trim();
                            return DropdownMenuItem<String>(
                              value: model.modelId,
                              child: Text(desc.isEmpty ? model.displayName : '${model.displayName}\n$desc', maxLines: 2, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            final selectedModel = (v ?? ElevenLabsSettings.defaultTtsModel).trim();
                            updateDraft(draft.copyWith(modelId: selectedModel.isEmpty ? ElevenLabsSettings.defaultTtsModel : selectedModel));
                          },
                        ),
                        sliderRow(label: '稳定性', value: draft.stability, min: 0, max: 1, divisions: 20, onChanged: (v) => updateDraft(draft.copyWith(stability: v))),
                        sliderRow(label: '相似度', value: draft.similarityBoost, min: 0, max: 1, divisions: 20, onChanged: (v) => updateDraft(draft.copyWith(similarityBoost: v))),
                        sliderRow(label: '风格', value: draft.style, min: 0, max: 1, divisions: 20, onChanged: (v) => updateDraft(draft.copyWith(style: v))),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Speaker Boost'),
                          value: draft.useSpeakerBoost,
                          onChanged: (v) => updateDraft(draft.copyWith(useSpeakerBoost: v)),
                        ),
                        Row(
                          children: [
                            const Text('文本规范化'),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: <String>['auto', 'on', 'off'].contains(draft.textNormalization) ? draft.textNormalization : 'auto',
                              items: const [
                                DropdownMenuItem(value: 'auto', child: Text('auto')),
                                DropdownMenuItem(value: 'on', child: Text('on')),
                                DropdownMenuItem(value: 'off', child: Text('off')),
                              ],
                              onChanged: (v) => updateDraft(draft.copyWith(textNormalization: v ?? 'auto')),
                            ),
                            const SizedBox(width: 20),
                            const Text('语言'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: draft.languageCode,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                onChanged: (v) => draft = draft.copyWith(languageCode: v.trim()),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        sectionTitle('Resemble AI 声音与模型'),
                        const Text(
                          'Resemble AI 使用 voice_uuid、模型、SSML/Prompt 和高清合成参数。这里的 Resemble 参数与 ElevenLabs 参数独立，只保存到当前冥想。',
                          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('账号已有 voice_uuid'),
                              selected: draft.voiceSource == 'premade',
                              onSelected: (_) => updateDraft(draft.copyWith(voiceSource: 'premade')),
                            ),
                            ChoiceChip(
                              label: const Text('Resemble 克隆声音'),
                              selected: draft.voiceSource == 'cloned',
                              onSelected: (_) => updateDraft(draft.copyWith(voiceSource: 'cloned')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (loadingResembleOptions) ...[
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 8),
                          const Text('正在按本次点击加载 Resemble 声音和模型列表……', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 8),
                        ],
                        if ((resembleOptionsError ?? '').isNotEmpty) ...[
                          Text(resembleOptionsError!, style: const TextStyle(fontSize: 12, color: Colors.deepOrange, height: 1.4)),
                          const SizedBox(height: 8),
                        ],
                        if (draft.voiceSource == 'cloned') ...[
                          DropdownButtonFormField<String>(
                            value: availableResembleProfiles.any((p) => p.id == (draft.voiceProfileId ?? '')) ? draft.voiceProfileId : (availableResembleProfiles.isNotEmpty ? availableResembleProfiles.first.id : null),
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'App 内 Resemble 克隆声音', border: OutlineInputBorder()),
                            onTap: loadResembleOptionsOnTap,
                            items: availableResembleProfiles.map((profile) {
                              return DropdownMenuItem<String>(
                                value: profile.id,
                                child: Text('${profile.displayName}\nvoice_uuid: ${profile.elevenlabsVoiceId}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final selected = availableResembleProfiles.firstWhere((profile) => profile.id == v);
                              updateDraft(draft.copyWith(
                                voiceProfileId: selected.id,
                                voiceDisplayName: selected.displayName,
                                resembleVoiceUuid: selected.elevenlabsVoiceId,
                                resembleVoiceName: selected.displayName,
                              ));
                            },
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            value: availableResembleVoices.any((v) => v.id == draft.resembleVoiceUuid) ? draft.resembleVoiceUuid : availableResembleVoices.first.id,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Resemble voice_uuid', border: OutlineInputBorder()),
                            onTap: loadResembleOptionsOnTap,
                            items: availableResembleVoices.map((voice) {
                              final title = voice.name.trim().isEmpty ? voice.id : voice.name.trim();
                              final sub = voice.subtitle.trim().isEmpty ? voice.id : '${voice.subtitle} · ${voice.id}';
                              return DropdownMenuItem<String>(
                                value: voice.id,
                                child: Text('$title\n$sub', maxLines: 2, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              final selected = availableResembleVoices.firstWhere(
                                (voice) => voice.id == v,
                                orElse: () => ProviderCatalogOption(id: v, name: v),
                              );
                              updateDraft(draft.copyWith(
                                resembleVoiceUuid: selected.id,
                                resembleVoiceName: selected.name.trim().isEmpty ? selected.id : selected.name.trim(),
                              ));
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: draft.resembleVoiceUuid,
                            decoration: const InputDecoration(labelText: '也可手动粘贴 Resemble voice_uuid', border: OutlineInputBorder()),
                            onChanged: (v) => draft = draft.copyWith(resembleVoiceUuid: v.trim(), resembleVoiceName: draft.resembleVoiceName.trim().isEmpty ? v.trim() : draft.resembleVoiceName),
                          ),
                        ],
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: availableResembleModels.any((m) => m.id == draft.resembleModel) ? draft.resembleModel : availableResembleModels.first.id,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Resemble 模型', border: OutlineInputBorder()),
                          onTap: loadResembleOptionsOnTap,
                          items: availableResembleModels.map((model) {
                            final desc = model.description.trim();
                            return DropdownMenuItem<String>(
                              value: model.id,
                              child: Text(desc.isEmpty ? model.displayName : '${model.displayName}\n$desc', maxLines: 2, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => updateDraft(draft.copyWith(resembleModel: v ?? VoiceProviderSettings.defaultResembleModel)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('输出'),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: <String>['mp3', 'wav'].contains(draft.resembleOutputFormat) ? draft.resembleOutputFormat : 'mp3',
                              items: const [DropdownMenuItem(value: 'mp3', child: Text('mp3')), DropdownMenuItem(value: 'wav', child: Text('wav'))],
                              onChanged: (v) => updateDraft(draft.copyWith(resembleOutputFormat: v ?? 'mp3')),
                            ),
                            const SizedBox(width: 18),
                            const Text('精度'),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: <String>['MULAW', 'PCM_16', 'PCM_24', 'PCM_32'].contains(draft.resemblePrecision) ? draft.resemblePrecision : 'PCM_16',
                              items: const [
                                DropdownMenuItem(value: 'MULAW', child: Text('MULAW')),
                                DropdownMenuItem(value: 'PCM_16', child: Text('PCM_16')),
                                DropdownMenuItem(value: 'PCM_24', child: Text('PCM_24')),
                                DropdownMenuItem(value: 'PCM_32', child: Text('PCM_32')),
                              ],
                              onChanged: (v) => updateDraft(draft.copyWith(resemblePrecision: v ?? 'PCM_16')),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('采样率'),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                initialValue: draft.resembleSampleRate.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                onChanged: (v) => draft = draft.copyWith(resembleSampleRate: int.tryParse(v.trim()) ?? draft.resembleSampleRate),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('HD'),
                                value: draft.resembleUseHd,
                                onChanged: (v) => updateDraft(draft.copyWith(resembleUseHd: v)),
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('应用 Resemble 自定义发音'),
                          value: draft.resembleApplyPronunciations,
                          onChanged: (v) => updateDraft(draft.copyWith(resembleApplyPronunciations: v)),
                        ),
                        sectionTitle('Resemble 冥想专家参数'),
                        DropdownButtonFormField<String>(
                          value: <String>['expert_ssml', 'breaks_only', 'plain_prompt'].contains(draft.resembleMeditationMode) ? draft.resembleMeditationMode : VoiceProviderSettings.defaultResembleMeditationMode,
                          decoration: const InputDecoration(labelText: 'Resemble 冥想合成模式', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'expert_ssml', child: Text('专家 SSML + Prompt')),
                            DropdownMenuItem(value: 'breaks_only', child: Text('仅 SSML 停顿')),
                            DropdownMenuItem(value: 'plain_prompt', child: Text('仅 Prompt，不加 SSML')),
                          ],
                          onChanged: (v) => updateDraft(draft.copyWith(resembleMeditationMode: v ?? VoiceProviderSettings.defaultResembleMeditationMode)),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('使用 Resemble 冥想导演 Prompt'),
                          value: draft.resembleMeditationUsePrompt,
                          onChanged: (v) => updateDraft(draft.copyWith(resembleMeditationUsePrompt: v)),
                        ),
                        TextFormField(
                          initialValue: draft.resembleMeditationPrompt,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Resemble 冥想 Prompt', border: OutlineInputBorder()),
                          onChanged: (v) => draft = draft.copyWith(resembleMeditationPrompt: v.trim()),
                        ),
                        sliderRow(label: '单个break', value: draft.resembleMeditationMaxBreakSec, min: 0.3, max: 10, divisions: 97, suffix: 's', onChanged: (v) => updateDraft(draft.copyWith(resembleMeditationMaxBreakSec: v))),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('拆分长停顿'),
                          subtitle: const Text('长留白会拆成多个较短 break，降低 Resemble 服务端报错和怪声概率。'),
                          value: draft.resembleMeditationSplitLongBreaks,
                          onChanged: (v) => updateDraft(draft.copyWith(resembleMeditationSplitLongBreaks: v)),
                        ),
                      ],
                      sectionTitle('通用冥想语速与场景'),
                      Row(
                        children: [
                          const Text('场景'),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<String>(
                              value: ElevenLabsService.scenePresets.any((e) => e.id == draft.scene) ? draft.scene : 'meditation_relax',
                              isExpanded: true,
                              items: ElevenLabsService.scenePresets.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                final preset = ElevenLabsService.presetById(v);
                                updateDraft(draft.copyWith(
                                  scene: v,
                                  stability: draft.ttsProvider == 'resemble' ? draft.stability : preset.stability,
                                  similarityBoost: draft.ttsProvider == 'resemble' ? draft.similarityBoost : preset.similarityBoost,
                                  style: draft.ttsProvider == 'resemble' ? draft.style : preset.style,
                                  speed: preset.speed,
                                  useSpeakerBoost: draft.ttsProvider == 'resemble' ? draft.useSpeakerBoost : preset.speakerBoost,
                                  pauseMode: preset.recommendedPauseMode,
                                  meditationAutoPauses: preset.meditationAutoPauses,
                                  meditationPauseProfile: preset.meditationPauseProfile,
                                  meditationSentenceBreakSec: preset.meditationSentenceBreakSec,
                                  meditationParagraphBreakSec: preset.meditationParagraphBreakSec,
                                  meditationBreathBreakSec: preset.meditationBreathBreakSec,
                                  meditationTone: preset.meditationTone,
                                  meditationAutoBreathPauses: preset.meditationAutoBreathPauses,
                                ));
                              },
                            ),
                          ),
                        ],
                      ),
                      sliderRow(label: '语速', value: draft.speed, min: 0.7, max: 1.2, divisions: 10, onChanged: (v) => updateDraft(draft.copyWith(speed: v))),
                      sectionTitle('冥想停顿参数'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动加入冥想停顿'),
                        value: draft.meditationAutoPauses,
                        onChanged: (v) => updateDraft(draft.copyWith(meditationAutoPauses: v)),
                      ),
                      Row(
                        children: [
                          const Text('停顿模式'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: <String>['none', 'short', 'medium', 'long'].contains(draft.pauseMode) ? draft.pauseMode : 'long',
                            items: const [
                              DropdownMenuItem(value: 'none', child: Text('无')),
                              DropdownMenuItem(value: 'short', child: Text('短')),
                              DropdownMenuItem(value: 'medium', child: Text('中')),
                              DropdownMenuItem(value: 'long', child: Text('长')),
                            ],
                            onChanged: (v) => updateDraft(draft.copyWith(pauseMode: v ?? 'long')),
                          ),
                          const SizedBox(width: 18),
                          const Text('冥想档位'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: <String>['light', 'standard', 'deep', 'custom'].contains(draft.meditationPauseProfile) ? draft.meditationPauseProfile : 'deep',
                            items: const [
                              DropdownMenuItem(value: 'light', child: Text('轻')),
                              DropdownMenuItem(value: 'standard', child: Text('标准')),
                              DropdownMenuItem(value: 'deep', child: Text('深')),
                              DropdownMenuItem(value: 'custom', child: Text('自定义')),
                            ],
                            onChanged: (v) => updateDraft(draft.copyWith(meditationPauseProfile: v ?? 'deep')),
                          ),
                        ],
                      ),
                      sliderRow(label: '句间', value: draft.meditationSentenceBreakSec, min: 0.3, max: 60, divisions: 597, suffix: 's', onChanged: (v) => updateDraft(draft.copyWith(meditationSentenceBreakSec: v, meditationPauseProfile: 'custom'))),
                      sliderRow(label: '段落', value: draft.meditationParagraphBreakSec, min: 0.3, max: 60, divisions: 597, suffix: 's', onChanged: (v) => updateDraft(draft.copyWith(meditationParagraphBreakSec: v, meditationPauseProfile: 'custom'))),
                      sliderRow(label: '呼吸', value: draft.meditationBreathBreakSec, min: 0.3, max: 60, divisions: 597, suffix: 's', onChanged: (v) => updateDraft(draft.copyWith(meditationBreathBreakSec: v, meditationPauseProfile: 'custom'))),
                      Row(
                        children: [
                          const Text('语气'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: <String>['calm', 'soft', 'whisper', 'warm', 'healing'].contains(draft.meditationTone) ? draft.meditationTone : 'calm',
                            items: const [
                              DropdownMenuItem(value: 'calm', child: Text('平静')),
                              DropdownMenuItem(value: 'soft', child: Text('轻柔')),
                              DropdownMenuItem(value: 'whisper', child: Text('耳语')),
                              DropdownMenuItem(value: 'warm', child: Text('温暖')),
                              DropdownMenuItem(value: 'healing', child: Text('疗愈')),
                            ],
                            onChanged: (v) => updateDraft(draft.copyWith(meditationTone: v ?? 'calm')),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('呼吸词停顿'),
                              value: draft.meditationAutoBreathPauses,
                              onChanged: (v) => updateDraft(draft.copyWith(meditationAutoBreathPauses: v)),
                            ),
                          ),
                        ],
                      ),
                      sectionTitle('音量与背景音'),
                      Row(
                        children: [
                          const Text('语音音量'),
                          Expanded(
                            child: Slider(
                              value: _voiceVolume,
                              min: 0,
                              max: 1,
                              divisions: 10,
                              label: '${(_voiceVolume * 100).round()}%',
                              onChanged: (v) async {
                                setState(() => _voiceVolume = v);
                                setSheetState(() {});
                                await _guidedPlayer.setVolume(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MeditationAudioService.backgroundSounds.map((sound) {
                          return ChoiceChip(
                            label: Text(sound.label),
                            selected: _selectedBackground == sound.id,
                            onSelected: (_) => refresh(() => _changeBackgroundSound(sound.id)),
                          );
                        }).toList(),
                      ),
                      Row(
                        children: [
                          const Text('背景音量'),
                          Expanded(
                            child: Slider(
                              value: _backgroundVolume,
                              min: 0,
                              max: 1,
                              divisions: 10,
                              label: '${(_backgroundVolume * 100).round()}%',
                              onChanged: (v) async {
                                setState(() => _backgroundVolume = v);
                                setSheetState(() {});
                                await _backgroundPlayer.setVolume(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      sectionTitle('播放循环与自动结束'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('循环重复当前冥想'),
                        subtitle: const Text('播放到结尾后从第一句重新开始，直到手动完成或达到自动结束时间。'),
                        value: _featureSettings.loopPlaybackEnabled,
                        onChanged: (v) async {
                          final next = _featureSettings.copyWith(loopPlaybackEnabled: v);
                          await _settingsService.save(next);
                          setState(() => _featureSettings = next);
                          setSheetState(() {});
                        },
                      ),
                      const Text('定时自动结束并退出', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <int>[0, 5, 10, 15, 20, 30, 45, 60, 90, 120].map((m) {
                          return ChoiceChip(
                            label: Text(m == 0 ? '关闭' : '$m 分钟'),
                            selected: _sleepTimerMinutes == m,
                            onSelected: (_) async {
                              final next = _featureSettings.copyWith(autoExitMinutes: m);
                              await _settingsService.save(next);
                              setState(() {
                                _featureSettings = next;
                                _sleepTimerMinutes = m;
                              });
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      sectionTitle('缓存管理'),
                      Text('当前缓存：${cacheStats?.totalSizeText ?? '--'} / ${cacheStats?.fileCount ?? 0} 个片段；长期保留：${cacheStats?.protectedSizeText ?? '--'} / ${cacheStats?.protectedCount ?? 0} 个。', style: const TextStyle(height: 1.45)),
                      sliderRow(label: '上限', value: draft.maxCacheMb.toDouble(), min: 32, max: 1024, divisions: 31, suffix: 'MB', onChanged: (v) => updateDraft(draft.copyWith(maxCacheMb: v.round()))),
                      sliderRow(label: 'AI保留', value: draft.aiRetentionDays.toDouble(), min: 1, max: 60, divisions: 59, suffix: '天', onChanged: (v) => updateDraft(draft.copyWith(aiRetentionDays: v.round()))),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => refresh(() => _cleanupCache(all: false, unprotectedOnly: true)),
                              child: const Text('清理未长期保留缓存'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => refresh(() => _cleanupCache(all: true, unprotectedOnly: false)),
                              child: const Text('清理全部缓存'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => refresh(() => _saveSegmentTtsSettings(draft)),
                              icon: const Icon(Icons.save),
                              label: const Text('保存参数'),
                            ),
                          ),
                        ],
                      ),
                      sectionTitle('整段语音（兼容旧模式）'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _generatingGuidedAudio ? null : () => refresh(() => _toggleGuidedAudio()),
                              icon: _generatingGuidedAudio
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(_guidedAudioPlaying ? Icons.pause : Icons.record_voice_over),
                              label: Text(_generatingGuidedAudio ? '生成中……' : (_guidedAudioPlaying ? '暂停整段语音' : '生成/播放整段语音')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _generatingGuidedAudio ? null : () => refresh(() => _toggleGuidedAudio(forceRegenerate: true)),
                            child: const Text('重生成'),
                          ),
                        ],
                      ),
                      if ((_audioStatus ?? '').isNotEmpty || (sheetMessage ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text((_audioStatus ?? sheetMessage ?? ''), style: const TextStyle(height: 1.45)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _tick() {
    if (!_running) return;
    final nextTotalSeconds = _totalPracticeSeconds + 1;
    var nextElapsed = _elapsedSeconds + 1;

    if (_sleepTimerMinutes > 0 && nextTotalSeconds >= _sleepTimerMinutes * 60) {
      setState(() {
        _totalPracticeSeconds = nextTotalSeconds;
        _elapsedSeconds = nextElapsed.clamp(0, widget.session.durationSeconds).toInt();
      });
      _finish(completed: true);
      return;
    }

    if (nextElapsed >= widget.session.durationSeconds) {
      if (_featureSettings.loopPlaybackEnabled && !widget.timerOnly) {
        nextElapsed = 0;
      } else {
        setState(() {
          _totalPracticeSeconds = nextTotalSeconds;
          _elapsedSeconds = widget.session.durationSeconds;
        });
        _finish(completed: true);
        return;
      }
    }

    final nextIndex = _findCurrentStepIndex(nextElapsed);
    final changed = nextIndex != _currentSegmentIndex || nextElapsed == 0;
    setState(() {
      _totalPracticeSeconds = nextTotalSeconds;
      _elapsedSeconds = nextElapsed;
      if (changed) _currentSegmentIndex = nextIndex;
    });
    if (changed && _segmentVoiceEnabled) {
      _playSegmentVoice(nextIndex);
    }
  }


  MeditationStep _currentStep() {
    if (widget.session.steps.isEmpty) {
      return const MeditationStep(startSecond: 0, text: '现在，先坐下来，感受身体和呼吸。');
    }
    final index = _currentSegmentIndex.clamp(0, widget.session.steps.length - 1).toInt();
    return widget.session.steps[index];
  }

  Future<void> _finish({required bool completed}) async {
    _timer?.cancel();
    _breathController.stop();
    await _stopAllAudio();
    if (!mounted) return;
    if (completed) {
      final actualSeconds = math.max(_totalPracticeSeconds > 0 ? _totalPracticeSeconds : _elapsedSeconds, 1);
      if (!_featureSettings.showCompletionRecordPage) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await _dao.insertRecord(
          MeditationRecord(
            sessionKey: widget.session.key,
            title: widget.session.title,
            type: widget.session.type,
            startedAt: _startedAt,
            endedAt: now,
            durationSeconds: actualSeconds,
            completed: true,
            currentState: widget.currentState,
            createdAt: now,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MeditationCompletionPage(
            session: widget.session,
            currentState: widget.currentState,
            startedAt: _startedAt,
            actualSeconds: actualSeconds,
            timerOnly: widget.timerOnly,
            featureSettings: _featureSettings,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _confirmExit() async {
    await _pauseAllAudio();
    setState(() => _running = false);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束本次练习？'),
        content: const Text('这次练习尚未完成。你可以继续，也可以结束后稍后再练。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('继续练习')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('结束')),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldExit == true) {
      await _finish(completed: false);
    } else {
      if (!_practiceStarted) {
        setState(() => _running = false);
        return;
      }
      setState(() => _running = true);
      _breathController.repeat(reverse: true);
      if (_segmentVoiceEnabled) {
        await _playSegmentVoice(_currentSegmentIndex);
        if (_backgroundPlaying) await _backgroundPlayer.resume();
      } else {
        await _resumeAmbientAudio();
      }
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isSleep = widget.session.isSleep;
    final autoExitRemaining = _sleepTimerMinutes > 0 ? math.max(_sleepTimerMinutes * 60 - _totalPracticeSeconds, 0) : null;
    final remaining = autoExitRemaining ?? math.max(widget.session.durationSeconds - _elapsedSeconds, 0);
    final progress = _sleepTimerMinutes > 0
        ? (_totalPracticeSeconds / (_sleepTimerMinutes * 60)).clamp(0.0, 1.0)
        : (_elapsedSeconds / widget.session.durationSeconds).clamp(0.0, 1.0);
    final currentText = widget.timerOnly ? '安静地坐一会儿。分心时，知道分心，然后回来。' : _currentStep().text;
    final waitingForAudio = !_practiceStarted && (_blockingAutoAudioPreparation || _preparingSegmentAudio || _audioPreparationFailed);
    final bg = isSleep ? const Color(0xFF101322) : const Color(0xFFF7F8FC);
    final fg = isSleep ? Colors.white : const Color(0xFF1F2430);

    return WillPopScope(
      onWillPop: () async {
        await _confirmExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          title: Text(widget.session.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmExit,
          ),
          actions: [
            IconButton(
              tooltip: '语音与背景音',
              icon: const Icon(Icons.tune),
              onPressed: _openAudioSheet,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: isSleep ? Colors.white12 : Colors.black12,
                ),
                const SizedBox(height: 18),
                Text(
                  waitingForAudio ? '准备进度 $_segmentPreparedCount/$_segmentTotalCount' : _formatTime(remaining),
                  style: TextStyle(fontSize: 18, color: fg.withOpacity(0.72), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: _openAudioSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSleep ? Colors.white.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: fg.withOpacity(0.10)),
                    ),
                    child: Text(
                      "${_segmentVoiceEnabled ? (_preparingSegmentAudio ? '准备进度 $_segmentPreparedCount/$_segmentTotalCount' : '逐句语音${_segmentAudioByIndex.isEmpty ? '未准备' : '已缓存'}') : '整段语音${_guidedAudioPlaying ? '播放中' : (_guidedAudio == null ? '未生成' : '已缓存')}'} · 背景：${_backgroundLabel(_selectedBackground)}${_featureSettings.loopPlaybackEnabled ? ' · 循环' : ''}${_sleepTimerMinutes > 0 ? ' · ${_sleepTimerMinutes}分钟结束' : ''}",
                      style: TextStyle(fontSize: 12, color: fg.withOpacity(0.68)),
                    ),
                  ),
                ),
                if (waitingForAudio) ...[
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSleep ? Colors.white.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isSleep
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_audioPreparationFailed) ...[
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              value: _segmentTotalCount > 0 ? (_segmentPreparedCount / _segmentTotalCount).clamp(0.0, 1.0) : null,
                              color: isSleep ? Colors.white : const Color(0xFF5DAE74),
                              backgroundColor: (isSleep ? Colors.white : const Color(0xFF5DAE74)).withOpacity(0.14),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '努力准备中  $_segmentPreparedCount / $_segmentTotalCount',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: _segmentTotalCount > 0 ? (_segmentPreparedCount / _segmentTotalCount).clamp(0.0, 1.0) : null,
                              minHeight: 7,
                              color: isSleep ? Colors.white : const Color(0xFF5DAE74),
                              backgroundColor: (isSleep ? Colors.white : const Color(0xFF5DAE74)).withOpacity(0.14),
                            ),
                          ),
                        ] else ...[
                          Icon(Icons.error_outline, size: 36, color: Colors.deepOrange.withOpacity(0.9)),
                          const SizedBox(height: 12),
                          Text(
                            '准备失败',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _audioStatus ?? '请检查 ElevenLabs API Key、声音或模型配置后重试。',
                            textAlign: TextAlign.center,
                            style: TextStyle(height: 1.45, color: fg.withOpacity(0.68)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: fg,
                            side: BorderSide(color: fg.withOpacity(0.26)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _confirmExit,
                          icon: const Icon(Icons.close),
                          label: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _preparingSegmentAudio ? null : () => _prepareSegmentAudios(forceRegenerate: false, playAfter: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试准备'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                const Spacer(),
                AnimatedBuilder(
                  animation: _breathController,
                  builder: (context, child) {
                    final value = Curves.easeInOutCubic.transform(_breathController.value);
                    final size = 112.0 + 156.0 * value;
                    final circleColor = isSleep ? const Color(0xFFBFEFD0) : const Color(0xFFCFF6D6);
                    final edgeColor = isSleep ? const Color(0xFFE2FFE9) : const Color(0xFF79C58A);
                    final isInhaling = _breathController.status == AnimationStatus.forward;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor.withOpacity(isSleep ? 0.22 + 0.18 * value : 0.48 + 0.22 * value),
                        border: Border.all(color: edgeColor.withOpacity(0.48 + 0.22 * value), width: 2.6),
                        boxShadow: [
                          BoxShadow(
                            color: edgeColor.withOpacity(0.12 + 0.10 * value),
                            blurRadius: 26 + 16 * value,
                            spreadRadius: 4 + 8 * value,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isInhaling ? '吸气' : '呼气',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg.withOpacity(0.84)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSleep ? Colors.white.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSleep
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Text(
                    currentText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, height: 1.65, color: fg, fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: fg,
                          side: BorderSide(color: fg.withOpacity(0.26)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          setState(() => _running = !_running);
                          if (_running) {
                            _breathController.repeat(reverse: true);
                            if (_segmentVoiceEnabled) {
                              await _playSegmentVoice(_currentSegmentIndex);
                              if (_backgroundPlaying) await _backgroundPlayer.resume();
                            } else {
                              await _resumeAmbientAudio();
                            }
                          } else {
                            _breathController.stop();
                            await _pauseAllAudio();
                          }
                        },
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? '暂停' : '继续'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _finish(completed: true),
                        icon: const Icon(Icons.check),
                        label: const Text('完成'),
                      ),
                    ),
                  ],
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeditationCompletionPage extends StatefulWidget {
  final MeditationSessionTemplate session;
  final String currentState;
  final int startedAt;
  final int actualSeconds;
  final bool timerOnly;
  final MeditationFeatureSettings featureSettings;

  const MeditationCompletionPage({
    super.key,
    required this.session,
    required this.currentState,
    required this.startedAt,
    required this.actualSeconds,
    this.timerOnly = false,
    required this.featureSettings,
  });

  @override
  State<MeditationCompletionPage> createState() => _MeditationCompletionPageState();
}

class _MeditationCompletionPageState extends State<MeditationCompletionPage> {
  final _dao = MeditationDao();
  final _aiService = MeditationAiService();
  final _noteController = TextEditingController();
  double _beforeMood = 6;
  double _afterMood = 4;
  double _distraction = 5;
  double _relax = 5;
  bool _saving = false;
  bool _generatingFeedback = false;
  String? _aiFeedback;
  String? _aiFeedbackError;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final feedback = widget.featureSettings.showCompletionFeedbackCard
        ? ((_aiFeedback ?? '').trim().isNotEmpty ? _aiFeedback!.trim() : _buildLocalFeedback())
        : null;
    await _dao.insertRecord(
      MeditationRecord(
        sessionKey: widget.session.key,
        title: widget.session.title,
        type: widget.session.type,
        startedAt: widget.startedAt,
        endedAt: now,
        durationSeconds: widget.actualSeconds,
        completed: true,
        beforeMood: _beforeMood.round(),
        afterMood: _afterMood.round(),
        distractionLevel: _distraction.round(),
        bodyRelaxLevel: _relax.round(),
        currentState: widget.currentState,
        note: widget.featureSettings.showCompletionNoteInput && _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        aiFeedback: feedback,
        createdAt: now,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _generateAiFeedback() async {
    if (!widget.featureSettings.showPracticeAiFeedback) return;
    setState(() {
      _generatingFeedback = true;
      _aiFeedbackError = null;
    });
    try {
      final text = await _aiService.generatePracticeFeedback(
        session: widget.session,
        currentState: widget.currentState,
        actualSeconds: widget.actualSeconds,
        beforeMood: _beforeMood.round(),
        afterMood: _afterMood.round(),
        distractionLevel: _distraction.round(),
        bodyRelaxLevel: _relax.round(),
        userNote: _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        if (text.trim().isEmpty) {
          _aiFeedbackError = 'AI 反馈暂时不可用，保存时会使用本地反馈文案。';
        } else {
          _aiFeedback = text.trim();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiFeedbackError = 'AI 反馈生成失败：$e');
    } finally {
      if (mounted) setState(() => _generatingFeedback = false);
    }
  }

  String _buildLocalFeedback() {
    final delta = _beforeMood.round() - _afterMood.round();
    if (!widget.featureSettings.showCompletionMoodRatings) {
      return widget.session.endingReflection;
    }
    if (widget.timerOnly) {
      return '你完成了一次无引导练习。安静坐下本身，就是把注意力交还给自己的动作。';
    }
    if (delta > 0) {
      return '练习前后已经出现了一点变化。关键不是彻底没有念头，而是你已经开始知道如何回来。';
    }
    if (_distraction.round() >= 7) {
      return '今天分心很多也没有关系。冥想训练的不是没有杂念，而是看见杂念后再次回来。';
    }
    return widget.session.endingReflection;
  }

  Widget _slider(String title, double value, ValueChanged<double> onChanged, {String left = '低', String right = '高'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(value.round().toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(value: value, min: 0, max: 10, divisions: 10, label: value.round().toString(), onChanged: onChanged),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(right, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ],
    );
  }

  Widget _aiFeedbackSection() {
    final localFeedback = _buildLocalFeedback();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI 练习后反馈', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            (_aiFeedback ?? '').trim().isEmpty ? '当前会先使用本地反馈：$localFeedback' : _aiFeedback!,
            style: const TextStyle(height: 1.55),
          ),
          if ((_aiFeedbackError ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_aiFeedbackError!, style: const TextStyle(color: Colors.deepOrange, height: 1.4)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _generatingFeedback ? null : _generateAiFeedback,
            icon: _generatingFeedback
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_generatingFeedback ? '正在生成反馈……' : '生成AI反馈'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.featureSettings.showCompletionFeedbackCard
        ? ((_aiFeedback ?? '').trim().isNotEmpty ? _aiFeedback!.trim() : _buildLocalFeedback())
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('完成记录')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (widget.featureSettings.showCompletionFeedbackCard)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('你已经完成一次回到自己的练习', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(feedback ?? '', style: const TextStyle(fontSize: 15, height: 1.55)),
              ],
            ),
          ),
          if (widget.featureSettings.showCompletionFeedbackCard) const SizedBox(height: 20),
          if (widget.featureSettings.showCompletionMoodRatings) ...[
          _slider('练习前的紧张/烦乱程度', _beforeMood, (v) => setState(() => _beforeMood = v), left: '平静', right: '很强'),
          const SizedBox(height: 16),
          _slider('练习后的紧张/烦乱程度', _afterMood, (v) => setState(() => _afterMood = v), left: '平静', right: '很强'),
          const SizedBox(height: 16),
          _slider('练习中的分心程度', _distraction, (v) => setState(() => _distraction = v), left: '少', right: '多'),
          const SizedBox(height: 16),
          _slider('身体放松程度', _relax, (v) => setState(() => _relax = v), left: '紧绷', right: '放松'),
          const SizedBox(height: 18),
          ],
          if (widget.featureSettings.showCompletionNoteInput) ...[
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '一句觉察（可选）',
              hintText: '例如：我注意到自己又被白天那件事带走了。',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 18),
          ],
          if (widget.featureSettings.showPracticeAiFeedback) ...[
          _aiFeedbackSection(),
          const SizedBox(height: 18),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('保存练习记录'),
          ),
        ],
      ),
    );
  }
}
