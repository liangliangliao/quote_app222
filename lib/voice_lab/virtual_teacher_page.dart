import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import '../services/unified_ai_service.dart';
import 'eleven_labs_service.dart';
import 'multi_provider_tts_service.dart';
import 'voice_lab_dao.dart';
import 'voice_lab_models.dart';

class VirtualTeacherPage extends StatefulWidget {
  const VirtualTeacherPage({super.key});

  @override
  State<VirtualTeacherPage> createState() => _VirtualTeacherPageState();
}

class _TeacherMessage {
  final bool fromUser;
  final String text;
  final String? audioPath;

  const _TeacherMessage({required this.fromUser, required this.text, this.audioPath});
}

class _VirtualTeacherPageState extends State<VirtualTeacherPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final AudioPlayer _player = AudioPlayer();
  final KeyValueDao _kvDao = KeyValueDao();
  final VoiceLabDao _voiceDao = VoiceLabDao();
  final ElevenLabsService _ttsService = ElevenLabsService();
  final MultiProviderTtsService _multiTtsService = MultiProviderTtsService();
  final UnifiedAiService _aiService = UnifiedAiService();

  List<_TeacherMessage> _messages = <_TeacherMessage>[];
  String _teacherName = ElevenLabsSettings.defaultTeacherName;
  String _personaPrompt = ElevenLabsSettings.defaultTeacherPersona;
  bool _enableVoice = true;
  String _ttsVoiceSource = 'premade';
  String _ttsProvider = VoiceProviderSettings.defaultProvider;
  String _presetVoiceId = ElevenLabsSettings.defaultPresetVoiceId;
  String _presetVoiceName = ElevenLabsSettings.defaultPresetVoiceName;
  String _resembleVoiceUuid = '';
  String _resembleVoiceName = 'Resemble AI 冥想声音';
  String _resembleModel = VoiceProviderSettings.defaultResembleModel;
  String _resembleOutputFormat = VoiceProviderSettings.defaultResembleOutputFormat;
  String _resemblePrecision = VoiceProviderSettings.defaultResemblePrecision;
  int _resembleSampleRate = 48000;
  bool _resembleUseHd = false;
  bool _resembleApplyPronunciations = false;
  String _resembleMeditationMode = VoiceProviderSettings.defaultResembleMeditationMode;
  bool _resembleMeditationUsePrompt = true;
  String _resembleMeditationPrompt = VoiceProviderSettings.defaultResembleMeditationPrompt;
  double _resembleMeditationMaxBreakSec = VoiceProviderSettings.defaultResembleMeditationMaxBreakSec;
  bool _resembleMeditationSplitLongBreaks = true;
  String _minimaxEndpoint = VoiceProviderSettings.defaultMiniMaxEndpoint;
  String _minimaxModel = VoiceProviderSettings.defaultMiniMaxModel;
  String _minimaxVoiceId = VoiceProviderSettings.defaultMiniMaxVoiceId;
  String _minimaxVoiceName = VoiceProviderSettings.defaultMiniMaxVoiceName;
  String _minimaxFormat = 'mp3';
  int _minimaxSampleRate = 32000;
  int _minimaxBitrate = 128000;
  int _minimaxChannel = 1;
  double _minimaxVolume = 1.0;
  int _minimaxPitch = 0;
  String _minimaxEmotion = 'calm';
  String _minimaxLanguageBoost = 'auto';
  bool _minimaxTextNormalization = true;
  String _ttsScene = 'natural_dialogue';
  double _ttsSpeed = 1.0;
  double _ttsStability = 0.55;
  double _ttsSimilarityBoost = 0.8;
  double _ttsStyle = 0.2;
  bool _ttsUseSpeakerBoost = true;
  String _languageCode = 'zh';
  String _textNormalization = 'auto';
  String _pauseMode = 'none';
  bool _meditationAutoPauses = false;
  String _meditationPauseProfile = 'standard';
  double _meditationSentenceBreakSec = 1.5;
  double _meditationParagraphBreakSec = 2.4;
  double _meditationBreathBreakSec = 2.0;
  String _meditationTone = 'calm';
  bool _meditationAutoBreathPauses = true;
  VoiceProfile? _voiceProfile;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final name = await _kvDao.getString(ElevenLabsSettings.teacherName);
    final prompt = await _kvDao.getString(ElevenLabsSettings.teacherPersonaPrompt);
    final enable = await _kvDao.getString(ElevenLabsSettings.teacherEnableVoiceReply);
    final source = await _kvDao.getString(ElevenLabsSettings.ttsVoiceSource) ?? 'premade';
    final provider = await _kvDao.getString(VoiceProviderSettings.provider) ?? VoiceProviderSettings.defaultProvider;
    final resembleVoiceUuid = await _kvDao.getString(VoiceProviderSettings.resembleVoiceUuid) ?? '';
    final resembleVoiceName = await _kvDao.getString(VoiceProviderSettings.resembleVoiceName) ?? 'Resemble AI 冥想声音';
    final resembleModel = await _kvDao.getString(VoiceProviderSettings.resembleModel) ?? VoiceProviderSettings.defaultResembleModel;
    final resembleOutputFormat = await _kvDao.getString(VoiceProviderSettings.resembleOutputFormat) ?? VoiceProviderSettings.defaultResembleOutputFormat;
    final resemblePrecision = await _kvDao.getString(VoiceProviderSettings.resemblePrecision) ?? VoiceProviderSettings.defaultResemblePrecision;
    final resembleSampleRate = int.tryParse(await _kvDao.getString(VoiceProviderSettings.resembleSampleRate) ?? '') ?? 48000;
    final resembleUseHd = await _kvDao.getString(VoiceProviderSettings.resembleUseHd);
    final resembleApplyPron = await _kvDao.getString(VoiceProviderSettings.resembleApplyPronunciations);
    final resembleMeditationMode = await _kvDao.getString(VoiceProviderSettings.resembleMeditationMode) ?? VoiceProviderSettings.defaultResembleMeditationMode;
    final resembleMeditationUsePrompt = await _kvDao.getString(VoiceProviderSettings.resembleMeditationUsePrompt);
    final resembleMeditationPrompt = await _kvDao.getString(VoiceProviderSettings.resembleMeditationPrompt) ?? VoiceProviderSettings.defaultResembleMeditationPrompt;
    final resembleMeditationMaxBreakSec = double.tryParse(await _kvDao.getString(VoiceProviderSettings.resembleMeditationMaxBreakSec) ?? '') ?? VoiceProviderSettings.defaultResembleMeditationMaxBreakSec;
    final resembleMeditationSplitLongBreaks = await _kvDao.getString(VoiceProviderSettings.resembleMeditationSplitLongBreaks);
    final minimaxEndpoint = await _kvDao.getString(VoiceProviderSettings.minimaxEndpoint) ?? VoiceProviderSettings.defaultMiniMaxEndpoint;
    final minimaxModel = await _kvDao.getString(VoiceProviderSettings.minimaxModel) ?? VoiceProviderSettings.defaultMiniMaxModel;
    final minimaxVoiceId = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceId) ?? VoiceProviderSettings.defaultMiniMaxVoiceId;
    final minimaxVoiceName = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceName) ?? VoiceProviderSettings.defaultMiniMaxVoiceName;
    final minimaxFormat = await _kvDao.getString(VoiceProviderSettings.minimaxFormat) ?? 'mp3';
    final minimaxSampleRate = int.tryParse(await _kvDao.getString(VoiceProviderSettings.minimaxSampleRate) ?? '') ?? 32000;
    final minimaxBitrate = int.tryParse(await _kvDao.getString(VoiceProviderSettings.minimaxBitrate) ?? '') ?? 128000;
    final minimaxChannel = int.tryParse(await _kvDao.getString(VoiceProviderSettings.minimaxChannel) ?? '') ?? 1;
    final minimaxVolume = double.tryParse(await _kvDao.getString(VoiceProviderSettings.minimaxVolume) ?? '') ?? 1.0;
    final minimaxPitch = int.tryParse(await _kvDao.getString(VoiceProviderSettings.minimaxPitch) ?? '') ?? 0;
    final minimaxEmotion = await _kvDao.getString(VoiceProviderSettings.minimaxEmotion) ?? 'calm';
    final minimaxLanguageBoost = await _kvDao.getString(VoiceProviderSettings.minimaxLanguageBoost) ?? 'auto';
    final minimaxTextNorm = await _kvDao.getString(VoiceProviderSettings.minimaxTextNormalization);
    final presetVoiceId = await _kvDao.getString(ElevenLabsSettings.presetVoiceId) ?? ElevenLabsSettings.defaultPresetVoiceId;
    final presetVoiceName = await _kvDao.getString(ElevenLabsSettings.presetVoiceName) ?? ElevenLabsSettings.defaultPresetVoiceName;
    final scene = await _kvDao.getString(ElevenLabsSettings.ttsScene) ?? 'natural_dialogue';
    final speed = double.tryParse(await _kvDao.getString(ElevenLabsSettings.ttsSpeed) ?? '') ?? ElevenLabsService.presetById(scene).speed;
    final stability = double.tryParse(await _kvDao.getString(ElevenLabsSettings.ttsStability) ?? '') ?? ElevenLabsService.presetById(scene).stability;
    final similarity = double.tryParse(await _kvDao.getString(ElevenLabsSettings.ttsSimilarityBoost) ?? '') ?? ElevenLabsService.presetById(scene).similarityBoost;
    final style = double.tryParse(await _kvDao.getString(ElevenLabsSettings.ttsStyle) ?? '') ?? ElevenLabsService.presetById(scene).style;
    final boost = await _kvDao.getString(ElevenLabsSettings.ttsUseSpeakerBoost);
    final languageCode = await _kvDao.getString(ElevenLabsSettings.ttsLanguageCode) ?? 'zh';
    final textNorm = await _kvDao.getString(ElevenLabsSettings.ttsTextNormalization) ?? 'auto';
    final pause = await _kvDao.getString(ElevenLabsSettings.ttsPauseMode) ?? 'none';
    final medAuto = await _kvDao.getString(ElevenLabsSettings.meditationAutoPauses);
    final medProfile = await _kvDao.getString(ElevenLabsSettings.meditationPauseProfile) ?? ElevenLabsService.presetById(scene).meditationPauseProfile;
    final medSentence = double.tryParse(await _kvDao.getString(ElevenLabsSettings.meditationSentenceBreakSec) ?? '') ?? ElevenLabsService.presetById(scene).meditationSentenceBreakSec;
    final medParagraph = double.tryParse(await _kvDao.getString(ElevenLabsSettings.meditationParagraphBreakSec) ?? '') ?? ElevenLabsService.presetById(scene).meditationParagraphBreakSec;
    final medBreath = double.tryParse(await _kvDao.getString(ElevenLabsSettings.meditationBreathBreakSec) ?? '') ?? ElevenLabsService.presetById(scene).meditationBreathBreakSec;
    final medTone = await _kvDao.getString(ElevenLabsSettings.meditationTone) ?? ElevenLabsService.presetById(scene).meditationTone;
    final medBreathAuto = await _kvDao.getString(ElevenLabsSettings.meditationAutoBreathPauses);
    final voiceId = await _kvDao.getString(ElevenLabsSettings.teacherVoiceProfileId);
    VoiceProfile? profile;
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      profile = await _voiceDao.getVoiceProfileById(voiceId.trim());
    }
    profile ??= await _voiceDao.getDefaultVoiceProfile();
    if (!mounted) return;
    setState(() {
      _teacherName = (name ?? '').trim().isEmpty ? ElevenLabsSettings.defaultTeacherName : name!.trim();
      _personaPrompt = (prompt ?? '').trim().isEmpty ? ElevenLabsSettings.defaultTeacherPersona : prompt!.trim();
      _enableVoice = enable == null || enable == '1' || enable.toLowerCase() == 'true';
      _ttsVoiceSource = source == 'cloned' ? 'cloned' : 'premade';
      _ttsProvider = <String>['elevenlabs', 'resemble', 'minimax'].contains(provider) ? provider : VoiceProviderSettings.defaultProvider;
      _resembleVoiceUuid = resembleVoiceUuid.trim();
      _resembleVoiceName = resembleVoiceName.trim().isEmpty ? 'Resemble AI 冥想声音' : resembleVoiceName.trim();
      _resembleModel = resembleModel.trim().isEmpty ? VoiceProviderSettings.defaultResembleModel : resembleModel.trim();
      _resembleOutputFormat = resembleOutputFormat;
      _resemblePrecision = resemblePrecision;
      _resembleSampleRate = resembleSampleRate;
      _resembleUseHd = resembleUseHd == '1' || resembleUseHd?.toLowerCase() == 'true';
      _resembleApplyPronunciations = resembleApplyPron == '1' || resembleApplyPron?.toLowerCase() == 'true';
      _resembleMeditationMode = <String>['expert_ssml', 'safe_breaks', 'breaks_only', 'plain_prompt'].contains(resembleMeditationMode) ? resembleMeditationMode : VoiceProviderSettings.defaultResembleMeditationMode;
      _resembleMeditationUsePrompt = resembleMeditationUsePrompt == null || resembleMeditationUsePrompt == '1' || resembleMeditationUsePrompt.toLowerCase() == 'true';
      _resembleMeditationPrompt = resembleMeditationPrompt.trim().isEmpty ? VoiceProviderSettings.defaultResembleMeditationPrompt : resembleMeditationPrompt.trim();
      _resembleMeditationMaxBreakSec = resembleMeditationMaxBreakSec.clamp(0.3, 10.0).toDouble();
      _resembleMeditationSplitLongBreaks = resembleMeditationSplitLongBreaks == null || resembleMeditationSplitLongBreaks == '1' || resembleMeditationSplitLongBreaks.toLowerCase() == 'true';
      _minimaxEndpoint = minimaxEndpoint.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxEndpoint : minimaxEndpoint.trim();
      _minimaxModel = minimaxModel.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxModel : minimaxModel.trim();
      _minimaxVoiceId = minimaxVoiceId.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxVoiceId : minimaxVoiceId.trim();
      _minimaxVoiceName = minimaxVoiceName.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxVoiceName : minimaxVoiceName.trim();
      _minimaxFormat = minimaxFormat;
      _minimaxSampleRate = minimaxSampleRate;
      _minimaxBitrate = minimaxBitrate;
      _minimaxChannel = minimaxChannel == 2 ? 2 : 1;
      _minimaxVolume = minimaxVolume.clamp(0.0, 10.0).toDouble();
      _minimaxPitch = minimaxPitch.clamp(-12, 12).toInt();
      _minimaxEmotion = minimaxEmotion;
      _minimaxLanguageBoost = minimaxLanguageBoost;
      _minimaxTextNormalization = minimaxTextNorm == null || minimaxTextNorm == '1' || minimaxTextNorm.toLowerCase() == 'true';
      _presetVoiceId = presetVoiceId.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceId : presetVoiceId.trim();
      _presetVoiceName = presetVoiceName.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceName : presetVoiceName.trim();
      _ttsScene = scene;
      _ttsSpeed = speed.clamp(provider == 'minimax' ? 0.5 : 0.7, provider == 'minimax' ? 2.0 : 1.2).toDouble();
      _ttsStability = stability.clamp(0.0, 1.0).toDouble();
      _ttsSimilarityBoost = similarity.clamp(0.0, 1.0).toDouble();
      _ttsStyle = style.clamp(0.0, 1.0).toDouble();
      _ttsUseSpeakerBoost = boost == null || boost == '1' || boost.toLowerCase() == 'true';
      _languageCode = languageCode.trim();
      _textNormalization = <String>['auto', 'on', 'off'].contains(textNorm) ? textNorm : 'auto';
      _pauseMode = <String>['none', 'short', 'medium', 'long'].contains(pause) ? pause : ElevenLabsService.presetById(scene).recommendedPauseMode;
      _meditationAutoPauses = medAuto == null ? ElevenLabsService.presetById(scene).meditationAutoPauses : (medAuto == '1' || medAuto.toLowerCase() == 'true');
      _meditationPauseProfile = <String>['light', 'standard', 'deep', 'custom'].contains(medProfile) ? medProfile : ElevenLabsService.presetById(scene).meditationPauseProfile;
      _meditationSentenceBreakSec = medSentence.clamp(0.3, 60.0).toDouble();
      _meditationParagraphBreakSec = medParagraph.clamp(0.3, 60.0).toDouble();
      _meditationBreathBreakSec = medBreath.clamp(0.3, 60.0).toDouble();
      _meditationTone = <String>['calm', 'soft', 'whisper', 'warm', 'healing'].contains(medTone) ? medTone : ElevenLabsService.presetById(scene).meditationTone;
      _meditationAutoBreathPauses = medBreathAuto == null ? ElevenLabsService.presetById(scene).meditationAutoBreathPauses : (medBreathAuto == '1' || medBreathAuto.toLowerCase() == 'true');
      _voiceProfile = profile;
      _messages = <_TeacherMessage>[
        _TeacherMessage(
          fromUser: false,
          text: ElevenLabsSettings.defaultTeacherOpening,
        ),
      ];
    });
  }

  Future<void> _send() async {
    final userText = _inputCtrl.text.trim();
    if (userText.isEmpty || _sending) return;
    _inputCtrl.clear();
    setState(() {
      _messages.add(_TeacherMessage(fromUser: true, text: userText));
      _sending = true;
    });
    _scrollLater();

    try {
      final recentMessages = _messages.length > 12 ? _messages.sublist(_messages.length - 12) : _messages;
      final history = recentMessages.map((m) => '${m.fromUser ? '用户' : _teacherName}：${m.text}').join('\n');
      final prompt = '''下面是你与用户的对话历史：
$history

用户最新输入：$userText

请你以“$_teacherName”的身份回答。回答要适合语音朗读，尽量分段清楚、句子短一些。''';
      final reply = await _aiService.generateText(
        purpose: 'virtual_teacher.chat',
        systemPrompt: _personaPrompt,
        prompt: prompt,
        maxTokens: 1200,
        temperature: 0.7,
      );
      final text = reply.trim().isEmpty ? '我暂时没有生成有效回答，请检查全局 AI 模型配置。' : reply.trim();
      String? audioPath;
      if (_enableVoice) {
        TtsAudioFile? audio;
        if (_ttsProvider == 'resemble') {
          final profile = _ttsVoiceSource == 'cloned' && _voiceProfile?.provider == 'resemble' ? _voiceProfile : null;
          final voiceUuid = profile?.elevenlabsVoiceId ?? _resembleVoiceUuid;
          if (voiceUuid.trim().isNotEmpty) {
            audio = await _multiTtsService.synthesizeResembleAndSave(
              text: text,
              voiceUuid: voiceUuid,
              voiceDisplayName: profile?.displayName ?? _resembleVoiceName,
              voiceProfileId: profile?.id,
              moduleName: 'virtual_teacher',
              model: _resembleModel,
              outputFormat: _resembleOutputFormat,
              precision: _resemblePrecision,
              sampleRate: _resembleSampleRate,
              useHd: _resembleUseHd,
              applyCustomPronunciations: _resembleApplyPronunciations,
              speed: _ttsSpeed,
              scene: _ttsScene,
              meditationAutoPauses: _meditationAutoPauses,
              meditationPauseProfile: _meditationPauseProfile,
              meditationSentenceBreakSec: _meditationSentenceBreakSec,
              meditationParagraphBreakSec: _meditationParagraphBreakSec,
              meditationBreathBreakSec: _meditationBreathBreakSec,
              meditationTone: _meditationTone,
              meditationAutoBreathPauses: _meditationAutoBreathPauses,
              resembleMeditationMode: _resembleMeditationMode,
              resembleMeditationUsePrompt: _resembleMeditationUsePrompt,
              resembleMeditationPrompt: _resembleMeditationPrompt,
              resembleMeditationMaxBreakSec: _resembleMeditationMaxBreakSec,
              resembleMeditationSplitLongBreaks: _resembleMeditationSplitLongBreaks,
            );
          }
        } else if (_ttsProvider == 'minimax') {
          final profile = _ttsVoiceSource == 'cloned' && _voiceProfile?.provider == 'minimax' ? _voiceProfile : null;
          final voiceId = profile?.elevenlabsVoiceId ?? _minimaxVoiceId;
          if (voiceId.trim().isNotEmpty) {
            audio = await _multiTtsService.synthesizeMiniMaxAndSave(
              text: text,
              voiceId: voiceId,
              voiceDisplayName: profile?.displayName ?? _minimaxVoiceName,
              voiceProfileId: profile?.id,
              moduleName: 'virtual_teacher',
              model: _minimaxModel,
              endpoint: _minimaxEndpoint,
              speed: _ttsSpeed,
              volume: _minimaxVolume,
              pitch: _minimaxPitch,
              emotion: _minimaxEmotion,
              languageBoost: _minimaxLanguageBoost,
              textNormalization: _minimaxTextNormalization,
              format: _minimaxFormat,
              sampleRate: _minimaxSampleRate,
              bitrate: _minimaxBitrate,
              channel: _minimaxChannel,
              scene: _ttsScene,
              meditationAutoPauses: _meditationAutoPauses,
              meditationPauseProfile: _meditationPauseProfile,
              meditationSentenceBreakSec: _meditationSentenceBreakSec,
              meditationParagraphBreakSec: _meditationParagraphBreakSec,
              meditationBreathBreakSec: _meditationBreathBreakSec,
              meditationTone: _meditationTone,
              meditationAutoBreathPauses: _meditationAutoBreathPauses,
            );
          }
        } else if (_ttsVoiceSource == 'cloned' && _voiceProfile != null) {
          audio = await _ttsService.synthesizeAndSave(
            text: text,
            voiceProfile: _voiceProfile!,
            moduleName: 'virtual_teacher',
            stability: _ttsStability,
            similarityBoost: _ttsSimilarityBoost,
            style: _ttsStyle,
            speed: _ttsSpeed,
            useSpeakerBoost: _ttsUseSpeakerBoost,
            languageCode: _languageCode,
            textNormalization: _textNormalization,
            scene: _ttsScene,
            pauseMode: _pauseMode,
            meditationAutoPauses: _meditationAutoPauses,
            meditationPauseProfile: _meditationPauseProfile,
            meditationSentenceBreakSec: _meditationSentenceBreakSec,
            meditationParagraphBreakSec: _meditationParagraphBreakSec,
            meditationBreathBreakSec: _meditationBreathBreakSec,
            meditationTone: _meditationTone,
            meditationAutoBreathPauses: _meditationAutoBreathPauses,
          );
        } else if (_ttsVoiceSource == 'premade' && _presetVoiceId.trim().isNotEmpty) {
          audio = await _ttsService.synthesizeAndSaveByVoiceId(
            text: text,
            voiceId: _presetVoiceId,
            voiceSource: 'premade',
            voiceDisplayName: _presetVoiceName,
            moduleName: 'virtual_teacher',
            stability: _ttsStability,
            similarityBoost: _ttsSimilarityBoost,
            style: _ttsStyle,
            speed: _ttsSpeed,
            useSpeakerBoost: _ttsUseSpeakerBoost,
            languageCode: _languageCode,
            textNormalization: _textNormalization,
            scene: _ttsScene,
            pauseMode: _pauseMode,
            meditationAutoPauses: _meditationAutoPauses,
            meditationPauseProfile: _meditationPauseProfile,
            meditationSentenceBreakSec: _meditationSentenceBreakSec,
            meditationParagraphBreakSec: _meditationParagraphBreakSec,
            meditationBreathBreakSec: _meditationBreathBreakSec,
            meditationTone: _meditationTone,
            meditationAutoBreathPauses: _meditationAutoBreathPauses,
          );
        }
        audioPath = audio?.audioFilePath;
        if (audioPath != null && File(audioPath).existsSync()) {
          await _player.stop();
          await _player.play(DeviceFileSource(audioPath));
        }
      }
      if (!mounted) return;
      setState(() {
        _messages.add(_TeacherMessage(fromUser: false, text: text, audioPath: audioPath));
      });
      _scrollLater();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_TeacherMessage(fromUser: false, text: '生成失败：$e'));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _providerDisplayName(String provider) {
    return switch (provider) {
      'resemble' => 'Resemble AI',
      'minimax' => 'MiniMax',
      _ => 'ElevenLabs',
    };
  }

  Future<void> _play(String path) async {
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('音频文件已不存在')));
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  @override
  Widget build(BuildContext context) {
    final voiceName = _ttsProvider == 'resemble' ? (_ttsVoiceSource == 'cloned' ? (_voiceProfile?.displayName ?? '未绑定 Resemble 克隆声音') : _resembleVoiceName) : (_ttsProvider == 'minimax' ? (_ttsVoiceSource == 'cloned' ? (_voiceProfile?.displayName ?? '未绑定 MiniMax 克隆声音') : _minimaxVoiceName) : (_ttsVoiceSource == 'premade' ? _presetVoiceName : (_voiceProfile?.displayName ?? '未绑定声音')));
    return Scaffold(
      appBar: AppBar(
        title: Text(_teacherName),
        actions: [
          IconButton(onPressed: _loadConfig, icon: const Icon(Icons.refresh), tooltip: '重新读取配置'),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('服务商：${_providerDisplayName(_ttsProvider)}  ·  当前声音：$voiceName  ·  语音回复：${_enableVoice ? '开启' : '关闭'}', style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final msg = _messages[index];
                final align = msg.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                final color = msg.fromUser ? Colors.blue.shade50 : Colors.grey.shade100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: align,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg.fromUser ? '我' : _teacherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(msg.text),
                            if (msg.audioPath != null) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _play(msg.audioPath!),
                                icon: const Icon(Icons.volume_up),
                                label: const Text('播放语音'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '输入你想和美好的祝福说的话',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
