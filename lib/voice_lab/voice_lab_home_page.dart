import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/kv_dao.dart';
import 'eleven_labs_service.dart';
import 'multi_provider_tts_service.dart';
import 'tts_audio_library_page.dart';
import 'virtual_teacher_page.dart';
import 'voice_clone_page.dart';
import 'voice_lab_dao.dart';
import 'voice_lab_models.dart';

class VoiceLabHomePage extends StatefulWidget {
  const VoiceLabHomePage({super.key});

  @override
  State<VoiceLabHomePage> createState() => _VoiceLabHomePageState();
}

class _VoiceLabHomePageState extends State<VoiceLabHomePage> {
  final KeyValueDao _kvDao = KeyValueDao();
  final VoiceLabDao _dao = VoiceLabDao();
  final ElevenLabsService _service = ElevenLabsService();
  final MultiProviderTtsService _multiService = MultiProviderTtsService();
  final AudioPlayer _player = AudioPlayer();

  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController(text: ElevenLabsSettings.defaultTtsModel);
  final TextEditingController _outputFormatCtrl = TextEditingController(text: ElevenLabsSettings.defaultOutputFormat);
  final TextEditingController _ttsTextCtrl = TextEditingController(text: '你好，我是你的美好的祝福。我们从一个很小的行动开始。');
  final TextEditingController _teacherNameCtrl = TextEditingController(text: ElevenLabsSettings.defaultTeacherName);
  final TextEditingController _teacherPersonaCtrl = TextEditingController(text: ElevenLabsSettings.defaultTeacherPersona);
  final TextEditingController _presetVoiceIdCtrl = TextEditingController(text: ElevenLabsSettings.defaultPresetVoiceId);
  final TextEditingController _presetVoiceNameCtrl = TextEditingController(text: ElevenLabsSettings.defaultPresetVoiceName);
  final TextEditingController _voiceSearchCtrl = TextEditingController();
  final TextEditingController _languageCodeCtrl = TextEditingController(text: 'zh');
  final TextEditingController _seedCtrl = TextEditingController();
  final TextEditingController _previousTextCtrl = TextEditingController();
  final TextEditingController _nextTextCtrl = TextEditingController();
  final TextEditingController _resembleApiKeyCtrl = TextEditingController();
  final TextEditingController _resembleVoiceUuidCtrl = TextEditingController();
  final TextEditingController _resembleVoiceNameCtrl = TextEditingController(text: 'Resemble AI 冥想声音');
  final TextEditingController _resembleModelCtrl = TextEditingController(text: VoiceProviderSettings.defaultResembleModel);
  final TextEditingController _resembleSampleRateCtrl = TextEditingController(text: '48000');
  final TextEditingController _resembleMeditationPromptCtrl = TextEditingController(text: VoiceProviderSettings.defaultResembleMeditationPrompt);
  final TextEditingController _minimaxApiKeyCtrl = TextEditingController();
  final TextEditingController _minimaxGroupIdCtrl = TextEditingController();
  final TextEditingController _minimaxEndpointCtrl = TextEditingController(text: VoiceProviderSettings.defaultMiniMaxEndpoint);
  final TextEditingController _minimaxModelCtrl = TextEditingController(text: VoiceProviderSettings.defaultMiniMaxModel);
  final TextEditingController _minimaxVoiceIdCtrl = TextEditingController(text: VoiceProviderSettings.defaultMiniMaxVoiceId);
  final TextEditingController _minimaxVoiceNameCtrl = TextEditingController(text: VoiceProviderSettings.defaultMiniMaxVoiceName);
  final TextEditingController _minimaxSampleRateCtrl = TextEditingController(text: '32000');
  final TextEditingController _minimaxBitrateCtrl = TextEditingController(text: '128000');
  final TextEditingController _minimaxLanguageBoostCtrl = TextEditingController(text: 'auto');
  final TextEditingController _microsoftApiKeyCtrl = TextEditingController();
  final TextEditingController _microsoftRegionCtrl = TextEditingController(text: VoiceProviderSettings.defaultMicrosoftRegion);
  final TextEditingController _microsoftEndpointCtrl = TextEditingController();
  final TextEditingController _microsoftRecognitionEndpointCtrl = TextEditingController();
  final TextEditingController _microsoftVoiceCtrl = TextEditingController(text: VoiceProviderSettings.defaultMicrosoftVoice);
  final TextEditingController _microsoftLanguageCtrl = TextEditingController(text: VoiceProviderSettings.defaultMicrosoftLanguage);
  final TextEditingController _microsoftOutputFormatCtrl = TextEditingController(text: VoiceProviderSettings.defaultMicrosoftOutputFormat);

  List<VoiceProfile> _voices = <VoiceProfile>[];
  List<ElevenLabsVoiceOption> _voiceOptions = <ElevenLabsVoiceOption>[];
  List<ElevenLabsModelOption> _elevenModelOptions = <ElevenLabsModelOption>[];
  List<ProviderCatalogOption> _resembleVoiceOptions = <ProviderCatalogOption>[];
  List<ProviderCatalogOption> _resembleModelOptions = <ProviderCatalogOption>[];
  List<ProviderCatalogOption> _minimaxVoiceOptions = <ProviderCatalogOption>[];
  List<ProviderCatalogOption> _minimaxModelOptions = <ProviderCatalogOption>[];
  VoiceProfile? _selectedVoice;
  String _ttsVoiceSource = 'premade';
  String _ttsProvider = VoiceProviderSettings.defaultProvider;
  String _resembleOutputFormat = VoiceProviderSettings.defaultResembleOutputFormat;
  String _resemblePrecision = VoiceProviderSettings.defaultResemblePrecision;
  bool _resembleUseHd = false;
  bool _resembleApplyPronunciations = false;
  String _resembleVoiceType = 'rapid_voice';
  String _resembleMeditationMode = VoiceProviderSettings.defaultResembleMeditationMode;
  bool _resembleMeditationUsePrompt = true;
  double _resembleMeditationMaxBreakSec = VoiceProviderSettings.defaultResembleMeditationMaxBreakSec;
  bool _resembleMeditationSplitLongBreaks = true;
  double _minimaxVolume = 1.0;
  int _minimaxPitch = 0;
  String _minimaxEmotion = 'calm';
  String _minimaxLanguageBoost = 'auto';
  bool _minimaxTextNormalization = true;
  String _minimaxFormat = 'mp3';
  int _minimaxChannel = 1;
  String _minimaxSoundEffects = '';
  int _minimaxVoiceModifyPitch = 0;
  int _minimaxVoiceModifyIntensity = 0;
  int _minimaxVoiceModifyTimbre = 0;
  String _voiceFilterType = 'default';
  String _voiceFilterCategory = 'premade';
  String _ttsScene = 'natural_dialogue';
  String _textNormalization = 'auto';
  String _pauseMode = 'none';
  bool _meditationAutoPauses = false;
  String _meditationPauseProfile = 'standard';
  double _meditationSentenceBreakSec = 1.5;
  double _meditationParagraphBreakSec = 2.4;
  double _meditationBreathBreakSec = 2.0;
  String _meditationTone = 'calm';
  bool _meditationAutoBreathPauses = true;
  double _ttsSpeed = 1.0;
  double _ttsStability = 0.55;
  double _ttsSimilarityBoost = 0.8;
  double _ttsStyle = 0.2;
  bool _ttsUseSpeakerBoost = true;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _generating = false;
  bool _loadingVoices = false;
  bool _loadingModels = false;
  bool _autoSave = true;
  bool _reuseCache = true;
  bool _teacherVoiceReply = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _outputFormatCtrl.dispose();
    _ttsTextCtrl.dispose();
    _teacherNameCtrl.dispose();
    _teacherPersonaCtrl.dispose();
    _presetVoiceIdCtrl.dispose();
    _presetVoiceNameCtrl.dispose();
    _voiceSearchCtrl.dispose();
    _languageCodeCtrl.dispose();
    _seedCtrl.dispose();
    _previousTextCtrl.dispose();
    _nextTextCtrl.dispose();
    _resembleApiKeyCtrl.dispose();
    _resembleVoiceUuidCtrl.dispose();
    _resembleVoiceNameCtrl.dispose();
    _resembleModelCtrl.dispose();
    _resembleSampleRateCtrl.dispose();
    _resembleMeditationPromptCtrl.dispose();
    _minimaxApiKeyCtrl.dispose();
    _minimaxGroupIdCtrl.dispose();
    _minimaxEndpointCtrl.dispose();
    _minimaxModelCtrl.dispose();
    _minimaxVoiceIdCtrl.dispose();
    _minimaxVoiceNameCtrl.dispose();
    _minimaxSampleRateCtrl.dispose();
    _minimaxBitrateCtrl.dispose();
    _minimaxLanguageBoostCtrl.dispose();
    _microsoftApiKeyCtrl.dispose();
    _microsoftRegionCtrl.dispose();
    _microsoftEndpointCtrl.dispose();
    _microsoftRecognitionEndpointCtrl.dispose();
    _microsoftVoiceCtrl.dispose();
    _microsoftLanguageCtrl.dispose();
    _microsoftOutputFormatCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  double _parseDouble(String? v, double fallback) => double.tryParse((v ?? '').trim()) ?? fallback;


  void _selectProvider(String provider) {
    final normalized = <String>['elevenlabs', 'resemble', 'minimax', 'microsoft'].contains(provider) ? provider : VoiceProviderSettings.defaultProvider;
    setState(() {
      _ttsProvider = normalized;
      final providerVoices = _voices.where((v) => v.provider == normalized).toList();
      if (_selectedVoice?.provider != normalized) {
        _selectedVoice = providerVoices.isEmpty ? null : providerVoices.first;
      }
      // For non-ElevenLabs providers, “premade” means manually selected/system voice_id.
      // Keep user choice if possible; otherwise choose cloned when a matching local profile exists.
      if (_ttsVoiceSource == 'cloned' && _selectedVoice == null) {
        _ttsVoiceSource = 'premade';
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final apiKey = await _kvDao.getString(ElevenLabsSettings.apiKey) ?? '';
      final provider = await _kvDao.getString(VoiceProviderSettings.provider) ?? VoiceProviderSettings.defaultProvider;
      final resembleApiKey = await _kvDao.getString(VoiceProviderSettings.resembleApiKey) ?? '';
      final resembleVoiceUuid = await _kvDao.getString(VoiceProviderSettings.resembleVoiceUuid) ?? '';
      final resembleVoiceName = await _kvDao.getString(VoiceProviderSettings.resembleVoiceName) ?? 'Resemble AI 冥想声音';
      final resembleModel = await _kvDao.getString(VoiceProviderSettings.resembleModel) ?? VoiceProviderSettings.defaultResembleModel;
      final resembleOutput = await _kvDao.getString(VoiceProviderSettings.resembleOutputFormat) ?? VoiceProviderSettings.defaultResembleOutputFormat;
      final resemblePrecision = await _kvDao.getString(VoiceProviderSettings.resemblePrecision) ?? VoiceProviderSettings.defaultResemblePrecision;
      final resembleSampleRate = await _kvDao.getString(VoiceProviderSettings.resembleSampleRate) ?? '48000';
      final resembleHd = await _kvDao.getString(VoiceProviderSettings.resembleUseHd);
      final resemblePron = await _kvDao.getString(VoiceProviderSettings.resembleApplyPronunciations);
      final resembleVoiceType = await _kvDao.getString(VoiceProviderSettings.resembleVoiceType) ?? 'rapid_voice';
      final resembleMeditationMode = await _kvDao.getString(VoiceProviderSettings.resembleMeditationMode) ?? VoiceProviderSettings.defaultResembleMeditationMode;
      final resembleMeditationUsePrompt = await _kvDao.getString(VoiceProviderSettings.resembleMeditationUsePrompt);
      final resembleMeditationPrompt = await _kvDao.getString(VoiceProviderSettings.resembleMeditationPrompt) ?? VoiceProviderSettings.defaultResembleMeditationPrompt;
      final resembleMeditationMaxBreakSec = await _kvDao.getString(VoiceProviderSettings.resembleMeditationMaxBreakSec);
      final resembleMeditationSplitLongBreaks = await _kvDao.getString(VoiceProviderSettings.resembleMeditationSplitLongBreaks);
      final minimaxApiKey = await _kvDao.getString(VoiceProviderSettings.minimaxApiKey) ?? '';
      final minimaxGroupId = await _kvDao.getString(VoiceProviderSettings.minimaxGroupId) ?? '';
      final minimaxEndpoint = await _kvDao.getString(VoiceProviderSettings.minimaxEndpoint) ?? VoiceProviderSettings.defaultMiniMaxEndpoint;
      final minimaxModel = await _kvDao.getString(VoiceProviderSettings.minimaxModel) ?? VoiceProviderSettings.defaultMiniMaxModel;
      final minimaxVoiceId = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceId) ?? VoiceProviderSettings.defaultMiniMaxVoiceId;
      final minimaxVoiceName = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceName) ?? VoiceProviderSettings.defaultMiniMaxVoiceName;
      final minimaxFormat = await _kvDao.getString(VoiceProviderSettings.minimaxFormat) ?? 'mp3';
      final minimaxSampleRate = await _kvDao.getString(VoiceProviderSettings.minimaxSampleRate) ?? '32000';
      final minimaxBitrate = await _kvDao.getString(VoiceProviderSettings.minimaxBitrate) ?? '128000';
      final minimaxChannel = await _kvDao.getString(VoiceProviderSettings.minimaxChannel) ?? '1';
      final minimaxVolume = await _kvDao.getString(VoiceProviderSettings.minimaxVolume);
      final minimaxPitch = await _kvDao.getString(VoiceProviderSettings.minimaxPitch);
      final minimaxEmotion = await _kvDao.getString(VoiceProviderSettings.minimaxEmotion) ?? 'calm';
      final minimaxLanguageBoost = await _kvDao.getString(VoiceProviderSettings.minimaxLanguageBoost) ?? 'auto';
      final minimaxTextNorm = await _kvDao.getString(VoiceProviderSettings.minimaxTextNormalization);
      final minimaxSoundEffects = await _kvDao.getString(VoiceProviderSettings.minimaxSoundEffects) ?? '';
      final minimaxVmPitch = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceModifyPitch);
      final minimaxVmIntensity = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceModifyIntensity);
      final minimaxVmTimbre = await _kvDao.getString(VoiceProviderSettings.minimaxVoiceModifyTimbre);
      final microsoftApiKey = await _kvDao.getString(VoiceProviderSettings.microsoftApiKey) ?? '';
      final microsoftRegion = await _kvDao.getString(VoiceProviderSettings.microsoftRegion) ?? VoiceProviderSettings.defaultMicrosoftRegion;
      final microsoftEndpoint = await _kvDao.getString(VoiceProviderSettings.microsoftEndpoint) ?? '';
      final microsoftRecognitionEndpoint = await _kvDao.getString(VoiceProviderSettings.microsoftRecognitionEndpoint) ?? '';
      final microsoftVoice = await _kvDao.getString(VoiceProviderSettings.microsoftVoice) ?? VoiceProviderSettings.defaultMicrosoftVoice;
      final microsoftLanguage = await _kvDao.getString(VoiceProviderSettings.microsoftLanguage) ?? VoiceProviderSettings.defaultMicrosoftLanguage;
      final microsoftOutputFormat = await _kvDao.getString(VoiceProviderSettings.microsoftOutputFormat) ?? VoiceProviderSettings.defaultMicrosoftOutputFormat;
      final model = await _kvDao.getString(ElevenLabsSettings.defaultModel) ?? ElevenLabsSettings.defaultTtsModel;
      final out = await _kvDao.getString(ElevenLabsSettings.outputFormat) ?? ElevenLabsSettings.defaultOutputFormat;
      final autoSave = await _kvDao.getString(ElevenLabsSettings.autoSaveAudio);
      final reuse = await _kvDao.getString(ElevenLabsSettings.reuseCache);
      final source = await _kvDao.getString(ElevenLabsSettings.ttsVoiceSource) ?? 'premade';
      final presetVoiceId = await _kvDao.getString(ElevenLabsSettings.presetVoiceId) ?? ElevenLabsSettings.defaultPresetVoiceId;
      final presetVoiceName = await _kvDao.getString(ElevenLabsSettings.presetVoiceName) ?? ElevenLabsSettings.defaultPresetVoiceName;
      final voiceType = await _kvDao.getString(ElevenLabsSettings.voiceFilterType) ?? 'default';
      final category = await _kvDao.getString(ElevenLabsSettings.voiceFilterCategory) ?? 'premade';
      final scene = await _kvDao.getString(ElevenLabsSettings.ttsScene) ?? 'natural_dialogue';
      final speed = await _kvDao.getString(ElevenLabsSettings.ttsSpeed);
      final stability = await _kvDao.getString(ElevenLabsSettings.ttsStability);
      final sim = await _kvDao.getString(ElevenLabsSettings.ttsSimilarityBoost);
      final style = await _kvDao.getString(ElevenLabsSettings.ttsStyle);
      final boost = await _kvDao.getString(ElevenLabsSettings.ttsUseSpeakerBoost);
      final language = await _kvDao.getString(ElevenLabsSettings.ttsLanguageCode) ?? 'zh';
      final textNorm = await _kvDao.getString(ElevenLabsSettings.ttsTextNormalization) ?? 'auto';
      final seed = await _kvDao.getString(ElevenLabsSettings.ttsSeed) ?? '';
      final prev = await _kvDao.getString(ElevenLabsSettings.ttsPreviousText) ?? '';
      final next = await _kvDao.getString(ElevenLabsSettings.ttsNextText) ?? '';
      final pause = await _kvDao.getString(ElevenLabsSettings.ttsPauseMode) ?? 'none';
      final medAuto = await _kvDao.getString(ElevenLabsSettings.meditationAutoPauses);
      final medProfile = await _kvDao.getString(ElevenLabsSettings.meditationPauseProfile) ?? ElevenLabsService.presetById(scene).meditationPauseProfile;
      final medSentence = await _kvDao.getString(ElevenLabsSettings.meditationSentenceBreakSec);
      final medParagraph = await _kvDao.getString(ElevenLabsSettings.meditationParagraphBreakSec);
      final medBreath = await _kvDao.getString(ElevenLabsSettings.meditationBreathBreakSec);
      final medTone = await _kvDao.getString(ElevenLabsSettings.meditationTone) ?? ElevenLabsService.presetById(scene).meditationTone;
      final medBreathAuto = await _kvDao.getString(ElevenLabsSettings.meditationAutoBreathPauses);
      final teacherName = await _kvDao.getString(ElevenLabsSettings.teacherName) ?? ElevenLabsSettings.defaultTeacherName;
      final persona = await _kvDao.getString(ElevenLabsSettings.teacherPersonaPrompt) ?? ElevenLabsSettings.defaultTeacherPersona;
      final teacherVoice = await _kvDao.getString(ElevenLabsSettings.teacherEnableVoiceReply);
      final selectedVoiceId = await _kvDao.getString(ElevenLabsSettings.teacherVoiceProfileId);
      final voices = await _dao.listVoiceProfiles();
      VoiceProfile? selected;
      if (selectedVoiceId != null && selectedVoiceId.isNotEmpty) {
        for (final v in voices) {
          if (v.id == selectedVoiceId) selected = v;
        }
      }
      selected ??= voices.where((v) => v.isDefault).isNotEmpty ? voices.firstWhere((v) => v.isDefault) : (voices.isEmpty ? null : voices.first);
      if (!mounted) return;
      setState(() {
        _apiKeyCtrl.text = apiKey;
        _ttsProvider = <String>['elevenlabs', 'resemble', 'minimax', 'microsoft'].contains(provider) ? provider : VoiceProviderSettings.defaultProvider;
        _microsoftApiKeyCtrl.text = microsoftApiKey;
        _microsoftRegionCtrl.text = microsoftRegion;
        _microsoftEndpointCtrl.text = microsoftEndpoint;
        _microsoftRecognitionEndpointCtrl.text = microsoftRecognitionEndpoint;
        _microsoftVoiceCtrl.text = microsoftVoice;
        _microsoftLanguageCtrl.text = microsoftLanguage;
        _microsoftOutputFormatCtrl.text = microsoftOutputFormat;
        _resembleApiKeyCtrl.text = resembleApiKey;
        _resembleVoiceUuidCtrl.text = resembleVoiceUuid;
        _resembleVoiceNameCtrl.text = resembleVoiceName;
        _resembleModelCtrl.text = resembleModel;
        _resembleOutputFormat = <String>['mp3', 'wav'].contains(resembleOutput) ? resembleOutput : VoiceProviderSettings.defaultResembleOutputFormat;
        _resemblePrecision = <String>['MULAW', 'PCM_16', 'PCM_24', 'PCM_32'].contains(resemblePrecision) ? resemblePrecision : VoiceProviderSettings.defaultResemblePrecision;
        _resembleSampleRateCtrl.text = resembleSampleRate;
        _resembleUseHd = resembleHd == '1' || resembleHd?.toLowerCase() == 'true';
        _resembleApplyPronunciations = resemblePron == '1' || resemblePron?.toLowerCase() == 'true';
        _resembleVoiceType = <String>['rapid_voice', 'professional'].contains(resembleVoiceType) ? resembleVoiceType : 'rapid_voice';
        _resembleMeditationMode = <String>['expert_ssml', 'safe_breaks', 'breaks_only', 'plain_prompt'].contains(resembleMeditationMode) ? resembleMeditationMode : VoiceProviderSettings.defaultResembleMeditationMode;
        _resembleMeditationUsePrompt = resembleMeditationUsePrompt == null || resembleMeditationUsePrompt == '1' || resembleMeditationUsePrompt.toLowerCase() == 'true';
        _resembleMeditationPromptCtrl.text = resembleMeditationPrompt;
        _resembleMeditationMaxBreakSec = _parseDouble(resembleMeditationMaxBreakSec, VoiceProviderSettings.defaultResembleMeditationMaxBreakSec).clamp(0.3, 10.0).toDouble();
        _resembleMeditationSplitLongBreaks = resembleMeditationSplitLongBreaks == null || resembleMeditationSplitLongBreaks == '1' || resembleMeditationSplitLongBreaks.toLowerCase() == 'true';
        _minimaxApiKeyCtrl.text = minimaxApiKey;
        _minimaxGroupIdCtrl.text = minimaxGroupId;
        _minimaxEndpointCtrl.text = minimaxEndpoint;
        _minimaxModelCtrl.text = minimaxModel;
        _minimaxVoiceIdCtrl.text = minimaxVoiceId;
        _minimaxVoiceNameCtrl.text = minimaxVoiceName;
        _minimaxFormat = <String>['mp3', 'wav', 'flac', 'pcm'].contains(minimaxFormat) ? minimaxFormat : 'mp3';
        _minimaxSampleRateCtrl.text = minimaxSampleRate;
        _minimaxBitrateCtrl.text = minimaxBitrate;
        _minimaxChannel = int.tryParse(minimaxChannel) == 2 ? 2 : 1;
        _minimaxVolume = _parseDouble(minimaxVolume, 1.0).clamp(0.0, 10.0).toDouble();
        _minimaxPitch = (int.tryParse(minimaxPitch ?? '') ?? 0).clamp(-12, 12).toInt();
        _minimaxEmotion = <String>['none', 'happy', 'sad', 'angry', 'fearful', 'disgusted', 'surprised', 'calm', 'fluent'].contains(minimaxEmotion) ? minimaxEmotion : 'calm';
        _minimaxLanguageBoost = minimaxLanguageBoost;
        _minimaxLanguageBoostCtrl.text = minimaxLanguageBoost;
        _minimaxTextNormalization = minimaxTextNorm == null || minimaxTextNorm == '1' || minimaxTextNorm.toLowerCase() == 'true';
        _minimaxSoundEffects = minimaxSoundEffects;
        _minimaxVoiceModifyPitch = (int.tryParse(minimaxVmPitch ?? '') ?? 0).clamp(-100, 100).toInt();
        _minimaxVoiceModifyIntensity = (int.tryParse(minimaxVmIntensity ?? '') ?? 0).clamp(-100, 100).toInt();
        _minimaxVoiceModifyTimbre = (int.tryParse(minimaxVmTimbre ?? '') ?? 0).clamp(-100, 100).toInt();
        _modelCtrl.text = model;
        _outputFormatCtrl.text = out;
        _autoSave = autoSave == null || autoSave == '1' || autoSave.toLowerCase() == 'true';
        _reuseCache = reuse == null || reuse == '1' || reuse.toLowerCase() == 'true';
        _ttsVoiceSource = source == 'cloned' ? 'cloned' : 'premade';
        _presetVoiceIdCtrl.text = presetVoiceId;
        _presetVoiceNameCtrl.text = presetVoiceName;
        _voiceFilterType = voiceType;
        _voiceFilterCategory = category;
        final safeScene = ElevenLabsService.scenePresets.any((e) => e.id == scene) ? scene : 'natural_dialogue';
        _ttsScene = safeScene;
        _ttsSpeed = _parseDouble(speed, ElevenLabsService.presetById(safeScene).speed).clamp(0.7, 1.2).toDouble();
        _ttsStability = _parseDouble(stability, ElevenLabsService.presetById(safeScene).stability).clamp(0.0, 1.0).toDouble();
        _ttsSimilarityBoost = _parseDouble(sim, ElevenLabsService.presetById(safeScene).similarityBoost).clamp(0.0, 1.0).toDouble();
        _ttsStyle = _parseDouble(style, ElevenLabsService.presetById(safeScene).style).clamp(0.0, 1.0).toDouble();
        _ttsUseSpeakerBoost = boost == null || boost == '1' || boost.toLowerCase() == 'true';
        _languageCodeCtrl.text = language;
        _textNormalization = <String>['auto', 'on', 'off'].contains(textNorm) ? textNorm : 'auto';
        _seedCtrl.text = seed;
        _previousTextCtrl.text = prev;
        _nextTextCtrl.text = next;
        _pauseMode = <String>['none', 'short', 'medium', 'long'].contains(pause) ? pause : ElevenLabsService.presetById(safeScene).recommendedPauseMode;
        _meditationAutoPauses = medAuto == null ? ElevenLabsService.presetById(safeScene).meditationAutoPauses : (medAuto == '1' || medAuto.toLowerCase() == 'true');
        _meditationPauseProfile = <String>['light', 'standard', 'deep', 'custom'].contains(medProfile) ? medProfile : ElevenLabsService.presetById(safeScene).meditationPauseProfile;
        _meditationSentenceBreakSec = _parseDouble(medSentence, ElevenLabsService.presetById(safeScene).meditationSentenceBreakSec).clamp(0.3, 60.0).toDouble();
        _meditationParagraphBreakSec = _parseDouble(medParagraph, ElevenLabsService.presetById(safeScene).meditationParagraphBreakSec).clamp(0.3, 60.0).toDouble();
        _meditationBreathBreakSec = _parseDouble(medBreath, ElevenLabsService.presetById(safeScene).meditationBreathBreakSec).clamp(0.3, 60.0).toDouble();
        _meditationTone = <String>['calm', 'soft', 'whisper', 'warm', 'healing'].contains(medTone) ? medTone : ElevenLabsService.presetById(safeScene).meditationTone;
        _meditationAutoBreathPauses = medBreathAuto == null ? ElevenLabsService.presetById(safeScene).meditationAutoBreathPauses : (medBreathAuto == '1' || medBreathAuto.toLowerCase() == 'true');
        _teacherNameCtrl.text = teacherName;
        _teacherPersonaCtrl.text = persona;
        _teacherVoiceReply = teacherVoice == null || teacherVoice == '1' || teacherVoice.toLowerCase() == 'true';
        _voices = voices;
        final currentSelected = selected;
        if (currentSelected != null && currentSelected.provider != _ttsProvider) {
          final sameProvider = voices.where((v) => v.provider == _ttsProvider).toList();
          selected = sameProvider.isEmpty ? null : sameProvider.first;
        }
        _selectedVoice = selected;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save({bool showToast = true}) async {
    setState(() => _saving = true);
    try {
      await _kvDao.setString(VoiceProviderSettings.provider, _ttsProvider);
      await _kvDao.setString(VoiceProviderSettings.resembleApiKey, _resembleApiKeyCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.resembleVoiceUuid, _resembleVoiceUuidCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.resembleVoiceName, _resembleVoiceNameCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.resembleModel, _resembleModelCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultResembleModel : _resembleModelCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.resembleOutputFormat, _resembleOutputFormat);
      await _kvDao.setString(VoiceProviderSettings.resemblePrecision, _resemblePrecision);
      await _kvDao.setString(VoiceProviderSettings.resembleSampleRate, _resembleSampleRateCtrl.text.trim().isEmpty ? '48000' : _resembleSampleRateCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.resembleUseHd, _resembleUseHd ? '1' : '0');
      await _kvDao.setString(VoiceProviderSettings.resembleApplyPronunciations, _resembleApplyPronunciations ? '1' : '0');
      await _kvDao.setString(VoiceProviderSettings.resembleVoiceType, _resembleVoiceType);
      await _kvDao.setString(VoiceProviderSettings.resembleMeditationMode, _resembleMeditationMode);
      await _kvDao.setString(VoiceProviderSettings.resembleMeditationUsePrompt, _resembleMeditationUsePrompt ? '1' : '0');
      await _kvDao.setString(VoiceProviderSettings.resembleMeditationPrompt, _resembleMeditationPromptCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultResembleMeditationPrompt : _resembleMeditationPromptCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.resembleMeditationMaxBreakSec, _resembleMeditationMaxBreakSec.toStringAsFixed(1));
      await _kvDao.setString(VoiceProviderSettings.resembleMeditationSplitLongBreaks, _resembleMeditationSplitLongBreaks ? '1' : '0');
      await _kvDao.setString(VoiceProviderSettings.minimaxApiKey, _minimaxApiKeyCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxGroupId, _minimaxGroupIdCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxEndpoint, _minimaxEndpointCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxEndpoint : _minimaxEndpointCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxModel, _minimaxModelCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxModel : _minimaxModelCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxVoiceId, _minimaxVoiceIdCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxVoiceId : _minimaxVoiceIdCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxVoiceName, _minimaxVoiceNameCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxVoiceName : _minimaxVoiceNameCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxFormat, _minimaxFormat);
      await _kvDao.setString(VoiceProviderSettings.minimaxSampleRate, _minimaxSampleRateCtrl.text.trim().isEmpty ? '32000' : _minimaxSampleRateCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxBitrate, _minimaxBitrateCtrl.text.trim().isEmpty ? '128000' : _minimaxBitrateCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxChannel, _minimaxChannel.toString());
      await _kvDao.setString(VoiceProviderSettings.minimaxVolume, _minimaxVolume.toStringAsFixed(2));
      await _kvDao.setString(VoiceProviderSettings.minimaxPitch, _minimaxPitch.toString());
      await _kvDao.setString(VoiceProviderSettings.minimaxEmotion, _minimaxEmotion);
      await _kvDao.setString(VoiceProviderSettings.minimaxLanguageBoost, _minimaxLanguageBoostCtrl.text.trim().isEmpty ? 'auto' : _minimaxLanguageBoostCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.minimaxTextNormalization, _minimaxTextNormalization ? '1' : '0');
      await _kvDao.setString(VoiceProviderSettings.minimaxSoundEffects, _minimaxSoundEffects);
      await _kvDao.setString(VoiceProviderSettings.minimaxVoiceModifyPitch, _minimaxVoiceModifyPitch.toString());
      await _kvDao.setString(VoiceProviderSettings.minimaxVoiceModifyIntensity, _minimaxVoiceModifyIntensity.toString());
      await _kvDao.setString(VoiceProviderSettings.minimaxVoiceModifyTimbre, _minimaxVoiceModifyTimbre.toString());
      await _kvDao.setString(VoiceProviderSettings.microsoftApiKey, _microsoftApiKeyCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.microsoftRegion, _microsoftRegionCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.microsoftEndpoint, _microsoftEndpointCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.microsoftRecognitionEndpoint, _microsoftRecognitionEndpointCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.microsoftVoice, _microsoftVoiceCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.microsoftLanguage, _microsoftLanguageCtrl.text.trim());
      await _kvDao.setString(VoiceProviderSettings.microsoftOutputFormat, _microsoftOutputFormatCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.apiKey, _apiKeyCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.defaultModel, _modelCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultTtsModel : _modelCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.outputFormat, _outputFormatCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultOutputFormat : _outputFormatCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.autoSaveAudio, _autoSave ? '1' : '0');
      await _kvDao.setString(ElevenLabsSettings.reuseCache, _reuseCache ? '1' : '0');
      await _kvDao.setString(ElevenLabsSettings.ttsVoiceSource, _ttsVoiceSource);
      await _kvDao.setString(ElevenLabsSettings.presetVoiceId, _presetVoiceIdCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceId : _presetVoiceIdCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.presetVoiceName, _presetVoiceNameCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultPresetVoiceName : _presetVoiceNameCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.voiceFilterType, _voiceFilterType);
      await _kvDao.setString(ElevenLabsSettings.voiceFilterCategory, _voiceFilterCategory);
      await _kvDao.setString(ElevenLabsSettings.ttsScene, _ttsScene);
      await _kvDao.setString(ElevenLabsSettings.ttsSpeed, _ttsSpeed.toStringAsFixed(2));
      await _kvDao.setString(ElevenLabsSettings.ttsStability, _ttsStability.toStringAsFixed(2));
      await _kvDao.setString(ElevenLabsSettings.ttsSimilarityBoost, _ttsSimilarityBoost.toStringAsFixed(2));
      await _kvDao.setString(ElevenLabsSettings.ttsStyle, _ttsStyle.toStringAsFixed(2));
      await _kvDao.setString(ElevenLabsSettings.ttsUseSpeakerBoost, _ttsUseSpeakerBoost ? '1' : '0');
      await _kvDao.setString(ElevenLabsSettings.ttsLanguageCode, _languageCodeCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.ttsTextNormalization, _textNormalization);
      await _kvDao.setString(ElevenLabsSettings.ttsSeed, _seedCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.ttsPreviousText, _previousTextCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.ttsNextText, _nextTextCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.ttsPauseMode, _pauseMode);
      await _kvDao.setString(ElevenLabsSettings.meditationAutoPauses, _meditationAutoPauses ? '1' : '0');
      await _kvDao.setString(ElevenLabsSettings.meditationPauseProfile, _meditationPauseProfile);
      await _kvDao.setString(ElevenLabsSettings.meditationSentenceBreakSec, _meditationSentenceBreakSec.toStringAsFixed(1));
      await _kvDao.setString(ElevenLabsSettings.meditationParagraphBreakSec, _meditationParagraphBreakSec.toStringAsFixed(1));
      await _kvDao.setString(ElevenLabsSettings.meditationBreathBreakSec, _meditationBreathBreakSec.toStringAsFixed(1));
      await _kvDao.setString(ElevenLabsSettings.meditationTone, _meditationTone);
      await _kvDao.setString(ElevenLabsSettings.meditationAutoBreathPauses, _meditationAutoBreathPauses ? '1' : '0');
      await _kvDao.setString(ElevenLabsSettings.teacherName, _teacherNameCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultTeacherName : _teacherNameCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.teacherPersonaPrompt, _teacherPersonaCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultTeacherPersona : _teacherPersonaCtrl.text.trim());
      await _kvDao.setString(ElevenLabsSettings.teacherEnableVoiceReply, _teacherVoiceReply ? '1' : '0');
      if (_selectedVoice != null) {
        await _kvDao.setString(ElevenLabsSettings.teacherVoiceProfileId, _selectedVoice!.id);
        await _dao.setDefaultVoiceProfile(_selectedVoice!.id);
      }
      if (showToast) _toast('已保存语音与美好的祝福配置');
      await _load();
    } catch (e) {
      _toast('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testKey() async {
    await _save(showToast: false);
    setState(() => _testing = true);
    try {
      if (_ttsProvider == 'resemble') {
        await _multiService.testResembleConnection(apiKey: _resembleApiKeyCtrl.text.trim());
        _toast('Resemble AI API Token 可用');
      } else if (_ttsProvider == 'minimax') {
        await _multiService.testMiniMaxConnection(apiKey: _minimaxApiKeyCtrl.text.trim(), endpoint: _minimaxEndpointCtrl.text.trim());
        _toast('MiniMax API Key 可用');
      } else if (_ttsProvider == 'microsoft') {
        await _multiService.testMicrosoftConnection(apiKey: _microsoftApiKeyCtrl.text.trim(), region: _microsoftRegionCtrl.text.trim(), endpoint: _microsoftEndpointCtrl.text.trim());
        _toast('Microsoft Speech API Key、Region 与 Endpoint 可用');
      } else {
        await _service.testConnection();
        _toast('ElevenLabs API Key 可用');
      }
    } catch (e) {
      _toast('测试失败：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _fetchVoices() async {
    await _save(showToast: false);
    setState(() => _loadingVoices = true);
    try {
      if (_ttsProvider == 'resemble') {
        final voices = await _multiService.listResembleVoices(apiKey: _resembleApiKeyCtrl.text.trim());
        if (!mounted) return;
        setState(() => _resembleVoiceOptions = voices);
        _toast('已获取 ${voices.length} 个 Resemble AI 声音');
      } else if (_ttsProvider == 'microsoft') {
        final path = await _multiService.synthesizeMicrosoftToFile(
          text: text,
          apiKey: _microsoftApiKeyCtrl.text.trim(),
          region: _microsoftRegionCtrl.text.trim(),
          endpoint: _microsoftEndpointCtrl.text.trim(),
          voice: _microsoftVoiceCtrl.text.trim(),
          language: _microsoftLanguageCtrl.text.trim(),
          outputFormat: _microsoftOutputFormatCtrl.text.trim(),
          rate: _ttsSpeed,
        );
        await _player.stop();
        await _player.play(DeviceFileSource(path));
        _toast('Microsoft 语音已生成并保存');
        return;
      } else if (_ttsProvider == 'minimax') {
        final voices = await _multiService.listMiniMaxVoices(apiKey: _minimaxApiKeyCtrl.text.trim());
        if (!mounted) return;
        setState(() => _minimaxVoiceOptions = voices);
        _toast('已获取 ${voices.length} 个 MiniMax 声音');
      } else {
        final voices = await _service.listVoices(
          voiceType: _voiceFilterType,
          category: _voiceFilterCategory,
          search: _voiceSearchCtrl.text,
        );
        if (!mounted) return;
        setState(() => _voiceOptions = voices);
        _toast('已获取 ${voices.length} 个 ElevenLabs 声音');
      }
    } catch (e) {
      _toast('获取声音列表失败：$e');
    } finally {
      if (mounted) setState(() => _loadingVoices = false);
    }
  }

  Future<void> _fetchModels() async {
    await _save(showToast: false);
    setState(() => _loadingModels = true);
    try {
      if (_ttsProvider == 'resemble') {
        final models = await _multiService.listResembleModels();
        if (!mounted) return;
        setState(() => _resembleModelOptions = models);
        _toast('已加载 Resemble AI 可选模型/模式');
      } else if (_ttsProvider == 'minimax') {
        final models = await _multiService.listMiniMaxModels(apiKey: _minimaxApiKeyCtrl.text.trim());
        if (!mounted) return;
        setState(() => _minimaxModelOptions = models);
        _toast('已获取 ${models.length} 个 MiniMax 模型');
      } else {
        final models = await _service.listModels();
        if (!mounted) return;
        setState(() => _elevenModelOptions = models);
        _toast('已获取 ${models.length} 个 ElevenLabs TTS 模型');
      }
    } catch (e) {
      _toast('获取模型列表失败：$e');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _applyScenePreset(String scene) {
    final preset = ElevenLabsService.presetById(scene);
    setState(() {
      _ttsScene = scene;
      _ttsSpeed = preset.speed;
      _ttsStability = preset.stability;
      _ttsSimilarityBoost = preset.similarityBoost;
      _ttsStyle = preset.style;
      _ttsUseSpeakerBoost = preset.speakerBoost;
      _pauseMode = preset.recommendedPauseMode;
      _meditationAutoPauses = preset.meditationAutoPauses;
      _meditationPauseProfile = preset.meditationPauseProfile;
      _meditationSentenceBreakSec = preset.meditationSentenceBreakSec;
      _meditationParagraphBreakSec = preset.meditationParagraphBreakSec;
      _meditationBreathBreakSec = preset.meditationBreathBreakSec;
      _meditationTone = preset.meditationTone;
      _meditationAutoBreathPauses = preset.meditationAutoBreathPauses;
    });
  }

  Future<void> _generateTts() async {
    final text = _ttsTextCtrl.text.trim();
    if (text.isEmpty) {
      _toast('请输入文字');
      return;
    }
    await _save(showToast: false);
    setState(() => _generating = true);
    try {
      final seedText = _seedCtrl.text.trim();
      final parsedSeed = seedText.isEmpty ? null : int.tryParse(seedText);
      TtsAudioFile audio;
      if (_ttsProvider == 'resemble') {
        final selected = _ttsVoiceSource == 'cloned' && _selectedVoice?.provider == 'resemble' ? _selectedVoice : null;
        final voiceUuid = selected?.elevenlabsVoiceId ?? _resembleVoiceUuidCtrl.text.trim();
        if (voiceUuid.isEmpty) {
          _toast('请先填写 Resemble voice_uuid，或新建/选择 Resemble 克隆声音档案');
          return;
        }
        audio = await _multiService.synthesizeResembleAndSave(
          text: text,
          voiceUuid: voiceUuid,
          voiceDisplayName: selected?.displayName ?? _resembleVoiceNameCtrl.text.trim(),
          voiceProfileId: selected?.id,
          moduleName: 'voice_lab_resemble_tts',
          model: _resembleModelCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultResembleModel : _resembleModelCtrl.text.trim(),
          outputFormat: _resembleOutputFormat,
          precision: _resemblePrecision,
          sampleRate: int.tryParse(_resembleSampleRateCtrl.text.trim()) ?? 48000,
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
          resembleMeditationPrompt: _resembleMeditationPromptCtrl.text.trim(),
          resembleMeditationMaxBreakSec: _resembleMeditationMaxBreakSec,
          resembleMeditationSplitLongBreaks: _resembleMeditationSplitLongBreaks,
        );
      } else if (_ttsProvider == 'minimax') {
        final selected = _ttsVoiceSource == 'cloned' && _selectedVoice?.provider == 'minimax' ? _selectedVoice : null;
        final voiceId = selected?.elevenlabsVoiceId ?? _minimaxVoiceIdCtrl.text.trim();
        if (voiceId.isEmpty) {
          _toast('请先填写 MiniMax voice_id，或新建/选择 MiniMax 克隆声音档案');
          return;
        }
        audio = await _multiService.synthesizeMiniMaxAndSave(
          text: text,
          voiceId: voiceId,
          voiceDisplayName: selected?.displayName ?? _minimaxVoiceNameCtrl.text.trim(),
          voiceProfileId: selected?.id,
          moduleName: 'voice_lab_minimax_tts',
          model: _minimaxModelCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxModel : _minimaxModelCtrl.text.trim(),
          endpoint: _minimaxEndpointCtrl.text.trim().isEmpty ? VoiceProviderSettings.defaultMiniMaxEndpoint : _minimaxEndpointCtrl.text.trim(),
          speed: _ttsSpeed,
          volume: _minimaxVolume,
          pitch: _minimaxPitch,
          emotion: _minimaxEmotion,
          languageBoost: _minimaxLanguageBoost,
          textNormalization: _minimaxTextNormalization,
          format: _minimaxFormat,
          sampleRate: int.tryParse(_minimaxSampleRateCtrl.text.trim()) ?? 32000,
          bitrate: int.tryParse(_minimaxBitrateCtrl.text.trim()) ?? 128000,
          channel: _minimaxChannel,
          soundEffects: _minimaxSoundEffects,
          voiceModifyPitch: _minimaxVoiceModifyPitch,
          voiceModifyIntensity: _minimaxVoiceModifyIntensity,
          voiceModifyTimbre: _minimaxVoiceModifyTimbre,
          scene: _ttsScene,
          meditationAutoPauses: _meditationAutoPauses,
          meditationPauseProfile: _meditationPauseProfile,
          meditationSentenceBreakSec: _meditationSentenceBreakSec,
          meditationParagraphBreakSec: _meditationParagraphBreakSec,
          meditationBreathBreakSec: _meditationBreathBreakSec,
          meditationTone: _meditationTone,
          meditationAutoBreathPauses: _meditationAutoBreathPauses,
        );
      } else if (_ttsVoiceSource == 'cloned') {
        final voice = _selectedVoice;
        if (voice == null || voice.provider != 'elevenlabs') {
          _toast('请先新建或选择一个 ElevenLabs 克隆声音，或切换到普通声音');
          return;
        }
        audio = await _service.synthesizeAndSave(
          text: text,
          voiceProfile: voice,
          moduleName: 'voice_lab_manual_tts',
          modelId: _modelCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultTtsModel : _modelCtrl.text.trim(),
          stability: _ttsStability,
          similarityBoost: _ttsSimilarityBoost,
          style: _ttsStyle,
          speed: _ttsSpeed,
          useSpeakerBoost: _ttsUseSpeakerBoost,
          languageCode: _languageCodeCtrl.text.trim(),
          textNormalization: _textNormalization,
          seed: parsedSeed,
          previousText: _previousTextCtrl.text.trim(),
          nextText: _nextTextCtrl.text.trim(),
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
      } else {
        final voiceId = _presetVoiceIdCtrl.text.trim();
        if (voiceId.isEmpty) {
          _toast('请先填写或从列表选择一个 ElevenLabs 普通声音 voice_id');
          return;
        }
        audio = await _service.synthesizeAndSaveByVoiceId(
          text: text,
          voiceId: voiceId,
          voiceSource: 'premade',
          voiceDisplayName: _presetVoiceNameCtrl.text.trim(),
          moduleName: 'voice_lab_free_quota_tts',
          modelId: _modelCtrl.text.trim().isEmpty ? ElevenLabsSettings.defaultTtsModel : _modelCtrl.text.trim(),
          stability: _ttsStability,
          similarityBoost: _ttsSimilarityBoost,
          style: _ttsStyle,
          speed: _ttsSpeed,
          useSpeakerBoost: _ttsUseSpeakerBoost,
          languageCode: _languageCodeCtrl.text.trim(),
          textNormalization: _textNormalization,
          seed: parsedSeed,
          previousText: _previousTextCtrl.text.trim(),
          nextText: _nextTextCtrl.text.trim(),
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
      if (File(audio.audioFilePath).existsSync()) {
        await _player.stop();
        await _player.play(DeviceFileSource(audio.audioFilePath));
      }
      _toast('已生成并自动保存到语音文件库');
    } catch (e) {
      _toast('生成失败：$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openClonePage() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const VoiceClonePage()));
    if (changed == true) await _load();
  }

  Future<void> _deleteVoice(VoiceProfile voice) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除声音档案'),
        content: Text('将删除 App 本地保存的声音档案“${voice.displayName}”。这不会自动删除 ${_providerDisplayName(voice.provider)} 平台云端声音。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _dao.deleteVoiceProfile(voice.id);
    if (_selectedVoice?.id == voice.id) _selectedVoice = null;
    _toast('已删除本地声音档案');
    await _load();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语音与美好的祝福配置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _providerSelectCard(),
                const SizedBox(height: 12),
                _apiConfigCard(),
                const SizedBox(height: 12),
                _voiceSourceCard(),
                const SizedBox(height: 12),
                _voiceProfilesCard(),
                const SizedBox(height: 12),
                _ttsParametersCard(),
                const SizedBox(height: 12),
                _manualTtsCard(),
                const SizedBox(height: 12),
                _teacherConfigCard(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                  label: const Text('保存全部配置'),
                ),
              ],
            ),
    );
  }

  Widget _providerSelectCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文字转语音服务商', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('可在 ElevenLabs、Resemble AI、MiniMax 之间自由切换；三者都可使用克隆声音档案，并共享语音文件库、下载、删除、缓存和冥想场景参数。', style: TextStyle(color: Colors.grey)),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'elevenlabs',
              groupValue: _ttsProvider,
              title: const Text('ElevenLabs'),
              subtitle: const Text('适合免费额度测试、普通声音、Instant Voice Cloning、v3 标签和多语言 TTS。'),
              onChanged: (v) => _selectProvider(v ?? 'elevenlabs'),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'resemble',
              groupValue: _ttsProvider,
              title: const Text('Resemble AI'),
              subtitle: const Text('适合 Rapid / Professional voice clone；TTS 返回 base64 音频，支持 SSML/HD/自定义发音。'),
              onChanged: (v) => _selectProvider(v ?? 'resemble'),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'minimax',
              groupValue: _ttsProvider,
              title: const Text('MiniMax'),
              subtitle: const Text('适合中文、多情绪、超长停顿 <#x#>、速度/音量/音调/音效和快速克隆声音。'),
              onChanged: (v) => _selectProvider(v ?? 'minimax'),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'microsoft',
              groupValue: _ttsProvider,
              title: const Text('Microsoft Azure Speech'),
              subtitle: const Text('支持 Neural TTS、SSML、区域/自定义 Endpoint，以及语音转文字和持续监听配置。'),
              onChanged: (v) => _selectProvider(v ?? 'microsoft'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apiConfigCard() {
    final providerName = _providerDisplayName(_ttsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$providerName API 配置', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text('当前只显示 $providerName 相关配置；切换服务商后，其他平台 API Key、模型、声音 ID 会自动隐藏，避免误操作。', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            if (_ttsProvider == 'elevenlabs') ...[
              TextField(
                controller: _apiKeyCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'ElevenLabs API Key', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: '默认 TTS 模型', helperText: '可点击“查询模型”自动列出当前 API Key 可用模型', border: OutlineInputBorder()),
              ),
              if (_elevenModelOptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._elevenModelOptions.take(12).map((model) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_modelCtrl.text.trim() == model.modelId ? Icons.radio_button_checked : Icons.radio_button_off),
                      title: Text(model.displayName),
                      subtitle: model.description.trim().isEmpty ? null : Text(model.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => setState(() => _modelCtrl.text = model.modelId),
                    )),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _outputFormatCtrl,
                decoration: const InputDecoration(labelText: '输出格式', helperText: '免费/入门推荐：mp3_44100_128；高码率/PCM 可能需要更高套餐', border: OutlineInputBorder()),
              ),
            ] else if (_ttsProvider == 'resemble') ...[
              TextField(
                controller: _resembleApiKeyCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Resemble API Token', helperText: '来自 app.resemble.ai/account/api', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _resembleModelCtrl,
                decoration: const InputDecoration(labelText: 'Resemble TTS 模型', helperText: '可留空，由 Resemble 按 voice_uuid 自动选择；也可点“查询模型”选择建议项', border: OutlineInputBorder()),
              ),
              if (_resembleModelOptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._resembleModelOptions.map((model) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_resembleModelCtrl.text.trim() == model.id ? Icons.radio_button_checked : Icons.radio_button_off),
                      title: Text(model.displayName),
                      subtitle: model.description.trim().isEmpty ? null : Text(model.description),
                      onTap: () => setState(() => _resembleModelCtrl.text = model.id),
                    )),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _resembleOutputFormat,
                  decoration: const InputDecoration(labelText: '输出格式', border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: 'mp3', child: Text('mp3')), DropdownMenuItem(value: 'wav', child: Text('wav'))],
                  onChanged: (v) => setState(() => _resembleOutputFormat = v ?? 'mp3'),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _resemblePrecision,
                  decoration: const InputDecoration(labelText: 'WAV 精度', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'PCM_16', child: Text('PCM_16')),
                    DropdownMenuItem(value: 'PCM_24', child: Text('PCM_24')),
                    DropdownMenuItem(value: 'PCM_32', child: Text('PCM_32')),
                    DropdownMenuItem(value: 'MULAW', child: Text('MULAW')),
                  ],
                  onChanged: (v) => setState(() => _resemblePrecision = v ?? 'PCM_16'),
                )),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _resembleSampleRateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '采样率 sample_rate', helperText: '常用 48000 / 44100 / 32000', border: OutlineInputBorder())),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('use_hd'), subtitle: const Text('开启 HD 合成，质量更好但延迟可能增加；冥想长音频建议开启。'), value: _resembleUseHd, onChanged: (v) => setState(() => _resembleUseHd = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('应用团队自定义发音'), subtitle: const Text('apply_custom_pronunciations；适合专有名词/外语冥想词汇。'), value: _resembleApplyPronunciations, onChanged: (v) => setState(() => _resembleApplyPronunciations = v)),
              TextButton.icon(
                onPressed: () => setState(() {
                  _resembleOutputFormat = 'mp3';
                  _resembleSampleRateCtrl.text = '48000';
                  _resembleUseHd = true;
                  _resembleApplyPronunciations = false;
                  _resembleModelCtrl.text = VoiceProviderSettings.defaultResembleModel;
                }),
                icon: const Icon(Icons.spa_outlined),
                label: const Text('套用 Resemble 冥想音质推荐'),
              ),
            ] else if (_ttsProvider == 'microsoft') ...[
              TextField(controller: _microsoftApiKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Microsoft Speech API Key', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _microsoftRegionCtrl, decoration: const InputDecoration(labelText: 'Region / Location', helperText: '例如 eastasia、southeastasia；必须与 Azure Speech 资源一致', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _microsoftEndpointCtrl, decoration: const InputDecoration(labelText: 'TTS Endpoint（可留空自动生成）', helperText: '留空使用 https://{region}.tts.speech.microsoft.com/cognitiveservices/v1', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _microsoftRecognitionEndpointCtrl, decoration: const InputDecoration(labelText: 'STT Endpoint（可留空自动生成）', helperText: '支持 Azure 自定义语音识别 Endpoint', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _microsoftVoiceCtrl, decoration: const InputDecoration(labelText: 'Neural Voice', helperText: '默认 zh-CN-XiaoxiaoNeural', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _microsoftLanguageCtrl, decoration: const InputDecoration(labelText: 'TTS / STT 语言', helperText: '例如 zh-CN、en-US', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _microsoftOutputFormatCtrl, decoration: const InputDecoration(labelText: 'X-Microsoft-OutputFormat', helperText: '默认 audio-24khz-48kbitrate-mono-mp3', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.hearing_outlined),
                title: Text('语音转文字与持续监听'),
                subtitle: Text('已保存识别 Endpoint、语言和密钥。持续监听采用短句自动续听，避免移动端系统静默超时；麦克风权限会在实际使用时申请。'),
              ),
            ] else ...[
              TextField(controller: _minimaxApiKeyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'MiniMax API Key', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _minimaxGroupIdCtrl, decoration: const InputDecoration(labelText: 'Group ID，可留空', helperText: '新版 Bearer 通常不强制；旧区域/旧接口可能需要', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _minimaxEndpointCtrl, decoration: const InputDecoration(labelText: 'T2A HTTP Endpoint', helperText: '默认 https://api.minimax.io/v1/t2a_v2', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _minimaxModelCtrl, decoration: const InputDecoration(labelText: 'MiniMax TTS 模型', helperText: '可点击“查询模型”自动获取当前 Key 可用模型；推荐 speech-2.8-hd', border: OutlineInputBorder())),
              if (_minimaxModelOptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._minimaxModelOptions.take(12).map((model) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_minimaxModelCtrl.text.trim() == model.id ? Icons.radio_button_checked : Icons.radio_button_off),
                      title: Text(model.displayName),
                      subtitle: model.subtitle.trim().isEmpty ? null : Text(model.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => setState(() => _minimaxModelCtrl.text = model.id),
                    )),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(value: _minimaxFormat, decoration: const InputDecoration(labelText: '格式', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'mp3', child: Text('mp3')), DropdownMenuItem(value: 'wav', child: Text('wav')), DropdownMenuItem(value: 'flac', child: Text('flac')), DropdownMenuItem(value: 'pcm', child: Text('pcm'))], onChanged: (v) => setState(() => _minimaxFormat = v ?? 'mp3'))),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<int>(value: _minimaxChannel, decoration: const InputDecoration(labelText: '声道', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 1, child: Text('mono 1')), DropdownMenuItem(value: 2, child: Text('stereo 2'))], onChanged: (v) => setState(() => _minimaxChannel = v ?? 1))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _minimaxSampleRateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'sample_rate', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _minimaxBitrateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'bitrate', border: OutlineInputBorder()))),
              ]),
            ],
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动保存生成的语音文件'),
              subtitle: const Text('保存到 App 内部目录，并写入数据库记录'),
              value: _autoSave,
              onChanged: (v) => setState(() => _autoSave = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('重复文本复用缓存语音'),
              subtitle: Text('同一服务商、同一声音、同一文本、同一参数复用缓存，避免重复消耗 ${providerName} 额度'),
              value: _reuseCache,
              onChanged: (v) => setState(() => _reuseCache = v),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testKey,
                  icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                  label: const Text('测试连接'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingModels ? null : _fetchModels,
                  icon: _loadingModels ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.model_training_outlined),
                  label: const Text('查询模型'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingVoices ? null : _fetchVoices,
                  icon: _loadingVoices ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.record_voice_over_outlined),
                  label: const Text('查询声音'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TtsAudioLibraryPage())),
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('语音文件库'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceSourceCard() {
    if (_ttsProvider == 'resemble') return _resembleVoiceSourceCard();
    if (_ttsProvider == 'minimax') return _minimaxVoiceSourceCard();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文字转语音声音来源', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('免费额度可直接使用 ElevenLabs 普通/默认声音做 TTS；声音克隆仍需对应套餐能力。', style: TextStyle(color: Colors.grey)),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'premade',
              groupValue: _ttsVoiceSource,
              title: const Text('使用免费额度普通声音'),
              subtitle: Text("voice_id：${_presetVoiceIdCtrl.text.trim().isEmpty ? '未选择' : _presetVoiceIdCtrl.text.trim()}"),
              onChanged: (v) => setState(() => _ttsVoiceSource = v ?? 'premade'),
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'cloned',
              groupValue: _ttsVoiceSource,
              title: const Text('使用克隆声音档案'),
              subtitle: Text(_selectedVoice == null ? '当前没有选中克隆声音' : '当前克隆声音：${_selectedVoice!.displayName}'),
              onChanged: (v) => setState(() => _ttsVoiceSource = v ?? 'cloned'),
            ),
            const Divider(),
            const Text('普通声音选择', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _dropdown('声音范围', _voiceFilterType, const {'default': '默认声音', 'personal': '个人声音', 'workspace': '工作区', 'saved': '已保存', 'all': '全部'}, (v) => setState(() => _voiceFilterType = v))),
                const SizedBox(width: 8),
                Expanded(child: _dropdown('类别', _voiceFilterCategory, const {'premade': '预制', 'cloned': '克隆', 'generated': '生成', 'professional': '专业', 'all': '全部'}, (v) => setState(() => _voiceFilterCategory = v))),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _voiceSearchCtrl,
              decoration: const InputDecoration(labelText: '搜索声音名称 / 标签，可留空', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingVoices ? null : _fetchVoices,
                  icon: _loadingVoices ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download_outlined),
                  label: const Text('获取声音列表'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _presetVoiceIdCtrl.text = ElevenLabsSettings.defaultPresetVoiceId;
                      _presetVoiceNameCtrl.text = ElevenLabsSettings.defaultPresetVoiceName;
                      _ttsVoiceSource = 'premade';
                    });
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复默认示例声音'),
                ),
              ],
            ),
            if (_voiceOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._voiceOptions.take(30).map((voice) {
                final selected = _presetVoiceIdCtrl.text.trim() == voice.voiceId;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(voice.name.isEmpty ? voice.voiceId : voice.name),
                  subtitle: Text("${voice.voiceId}\n${voice.labelSummary}${voice.description.isNotEmpty ? '\n${voice.description}' : ''}", maxLines: 3, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  onTap: () => setState(() {
                    _presetVoiceIdCtrl.text = voice.voiceId;
                    _presetVoiceNameCtrl.text = voice.name.isEmpty ? voice.voiceId : voice.name;
                    _ttsVoiceSource = 'premade';
                    if (voice.speed != null) _ttsSpeed = voice.speed!.clamp(0.7, 1.2).toDouble();
                    if (voice.stability != null) _ttsStability = voice.stability!.clamp(0.0, 1.0).toDouble();
                    if (voice.similarityBoost != null) _ttsSimilarityBoost = voice.similarityBoost!.clamp(0.0, 1.0).toDouble();
                    if (voice.style != null) _ttsStyle = voice.style!.clamp(0.0, 1.0).toDouble();
                    if (voice.useSpeakerBoost != null) _ttsUseSpeakerBoost = voice.useSpeakerBoost!;
                  }),
                );
              }),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _presetVoiceNameCtrl,
              decoration: const InputDecoration(labelText: '普通声音显示名称', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _presetVoiceIdCtrl,
              decoration: const InputDecoration(labelText: '普通声音 voice_id，可手动粘贴', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resembleVoiceSourceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Resemble AI 声音选择', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('只显示 Resemble 相关声音。点击“查询声音”会按当前 API Token 拉取账号可访问的 voice_uuid；也可手动粘贴已有 voice_uuid。', style: TextStyle(color: Colors.grey)),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'premade', groupValue: _ttsVoiceSource, title: const Text('使用账号已有 / 手动选择的 voice_uuid'), subtitle: Text(_resembleVoiceUuidCtrl.text.trim().isEmpty ? '未选择 Resemble voice_uuid' : _resembleVoiceUuidCtrl.text.trim()), onChanged: (v) => setState(() => _ttsVoiceSource = v ?? 'premade')),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'cloned', groupValue: _ttsVoiceSource, title: const Text('使用 App 内 Resemble 克隆声音档案'), subtitle: Text(_selectedVoice?.provider == 'resemble' ? '当前：${_selectedVoice!.displayName}' : '当前未选择 Resemble 克隆声音'), onChanged: (v) => setState(() => _ttsVoiceSource = v ?? 'cloned')),
          const Divider(),
          if (_resembleVoiceOptions.isNotEmpty) ...[
            const Text('账号可用 Resemble 声音', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ..._resembleVoiceOptions.take(30).map((voice) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_resembleVoiceUuidCtrl.text.trim() == voice.id ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(voice.displayName),
                  subtitle: Text(voice.subtitle.isEmpty ? voice.id : '${voice.id}\n${voice.subtitle}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  onTap: () => setState(() {
                    _resembleVoiceUuidCtrl.text = voice.id;
                    _resembleVoiceNameCtrl.text = voice.name.trim().isEmpty ? voice.id : voice.name;
                    _ttsVoiceSource = 'premade';
                  }),
                )),
            const Divider(),
          ],
          TextField(controller: _resembleVoiceNameCtrl, decoration: const InputDecoration(labelText: '声音显示名称', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _resembleVoiceUuidCtrl, decoration: const InputDecoration(labelText: 'Resemble voice_uuid，可手动粘贴', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: _resembleVoiceType, decoration: const InputDecoration(labelText: '新建克隆时的类型', helperText: '仅用于“新建”声音档案；现有 voice_uuid 不受影响', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'rapid_voice', child: Text('Rapid Voice Clone')), DropdownMenuItem(value: 'professional', child: Text('Professional Clone'))], onChanged: (v) => setState(() => _resembleVoiceType = v ?? 'rapid_voice')),
        ]),
      ),
    );
  }

  Widget _minimaxVoiceSourceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MiniMax 声音选择', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('只显示 MiniMax 相关声音。点击“查询声音”会调用 /v1/get_voice 获取 system / voice_cloning / voice_generation 下当前账号可用 voice_id。', style: TextStyle(color: Colors.grey)),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'premade', groupValue: _ttsVoiceSource, title: const Text('使用 MiniMax 系统/账号 voice_id'), subtitle: Text(_minimaxVoiceIdCtrl.text.trim().isEmpty ? '未选择 MiniMax voice_id' : _minimaxVoiceIdCtrl.text.trim()), onChanged: (v) => setState(() => _ttsVoiceSource = v ?? 'premade')),
          RadioListTile<String>(contentPadding: EdgeInsets.zero, value: 'cloned', groupValue: _ttsVoiceSource, title: const Text('使用 App 内 MiniMax 克隆声音档案'), subtitle: Text(_selectedVoice?.provider == 'minimax' ? '当前：${_selectedVoice!.displayName}' : '当前未选择 MiniMax 克隆声音'), onChanged: (v) => setState(() => _ttsVoiceSource = v ?? 'cloned')),
          const Divider(),
          if (_minimaxVoiceOptions.isNotEmpty) ...[
            const Text('账号可用 MiniMax 声音', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ..._minimaxVoiceOptions.take(60).map((voice) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_minimaxVoiceIdCtrl.text.trim() == voice.id ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(voice.displayName),
                  subtitle: Text(voice.subtitle.isEmpty ? voice.id : '${voice.id}\n${voice.subtitle}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  onTap: () => setState(() {
                    _minimaxVoiceIdCtrl.text = voice.id;
                    _minimaxVoiceNameCtrl.text = voice.name.trim().isEmpty ? voice.id : voice.name;
                    _ttsVoiceSource = 'premade';
                  }),
                )),
            const Divider(),
          ],
          TextField(controller: _minimaxVoiceNameCtrl, decoration: const InputDecoration(labelText: '声音显示名称', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _minimaxVoiceIdCtrl, decoration: const InputDecoration(labelText: 'MiniMax voice_id，可手动粘贴', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TextButton.icon(onPressed: () => setState(() { _minimaxVoiceIdCtrl.text = VoiceProviderSettings.defaultMiniMaxVoiceId; _minimaxVoiceNameCtrl.text = VoiceProviderSettings.defaultMiniMaxVoiceName; _ttsVoiceSource = 'premade'; }), icon: const Icon(Icons.restore), label: const Text('恢复示例 voice_id')),
          ]),
        ]),
      ),
    );
  }

  Widget _voiceProfilesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('克隆声音档案', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                OutlinedButton.icon(onPressed: _openClonePage, icon: const Icon(Icons.add), label: const Text('新建')),
              ],
            ),
            const SizedBox(height: 8),
            if (_voices.where((v) => v.provider == _ttsProvider).isEmpty)
              Text('还没有 ${_providerDisplayName(_ttsProvider)} 声音档案。可通过“新建”创建克隆声音，或在上方手动粘贴已有 voice_id / voice_uuid。', style: const TextStyle(color: Colors.grey))
            else
              ..._voices.where((v) => v.provider == _ttsProvider).map((voice) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: voice.id,
                    groupValue: _selectedVoice?.id,
                    title: Text("${voice.displayName}${voice.isDefault ? '（默认）' : ''}"),
                    subtitle: Text('${voice.provider == 'resemble' ? 'voice_uuid' : 'voice_id'}: ${voice.elevenlabsVoiceId}\n服务商：${_providerDisplayName(voice.provider)}  类型：${voice.cloneType}  状态：${voice.status}'),
                    isThreeLine: true,
                    onChanged: (id) => setState(() {
                      _selectedVoice = voice;
                      _ttsVoiceSource = 'cloned';
                    }),
                    secondary: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteVoice(voice)),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _ttsParametersCard() {
    final providerName = _providerDisplayName(_ttsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$providerName TTS 参数', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _ttsScene,
              decoration: const InputDecoration(labelText: '表达场景', border: OutlineInputBorder()),
              items: ElevenLabsService.scenePresets.map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.name))).toList(),
              onChanged: (v) {
                if (v != null) _applyScenePreset(v);
              },
            ),
            const SizedBox(height: 6),
            Text(ElevenLabsService.presetById(_ttsScene).description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            _slider('语速 speed', _ttsSpeed, _ttsProvider == 'minimax' ? 0.5 : 0.7, _ttsProvider == 'minimax' ? 2.0 : 1.2, (v) => setState(() => _ttsSpeed = v), help: '1.0 为正常语速；冥想建议 0.75–0.9。'),
            if (_ttsProvider == 'elevenlabs') ...[
              _slider('稳定性 stability', _ttsStability, 0.0, 1.0, (v) => setState(() => _ttsStability = v), help: 'ElevenLabs：越高越稳定，越低越有情绪变化。'),
              _slider('相似度 similarity_boost', _ttsSimilarityBoost, 0.0, 1.0, (v) => setState(() => _ttsSimilarityBoost = v), help: 'ElevenLabs：对克隆声音更重要；越高越像原声但可能放大噪声。'),
              _slider('风格强度 style', _ttsStyle, 0.0, 1.0, (v) => setState(() => _ttsStyle = v), help: 'ElevenLabs：增强风格表达，过高可能不稳定。'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('use_speaker_boost'),
                subtitle: const Text('ElevenLabs：提升说话人相似度，但可能增加生成时间'),
                value: _ttsUseSpeakerBoost,
                onChanged: (v) => setState(() => _ttsUseSpeakerBoost = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _languageCodeCtrl,
                      decoration: const InputDecoration(labelText: '语言代码 language_code', helperText: '中文 zh，可留空', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _textNormalization,
                      decoration: const InputDecoration(labelText: '文本规范化', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('auto')),
                        DropdownMenuItem(value: 'on', child: Text('on')),
                        DropdownMenuItem(value: 'off', child: Text('off')),
                      ],
                      onChanged: (v) => setState(() => _textNormalization = v ?? 'auto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _pauseMode,
                decoration: const InputDecoration(labelText: 'ElevenLabs 段落停顿风格', helperText: '非冥想普通文本中，通过换行/标点增强自然停顿。', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('不额外处理')),
                  DropdownMenuItem(value: 'short', child: Text('短停顿')),
                  DropdownMenuItem(value: 'medium', child: Text('中停顿')),
                  DropdownMenuItem(value: 'long', child: Text('长停顿')),
                ],
                onChanged: (v) => setState(() => _pauseMode = v ?? 'none'),
              ),
            ] else if (_ttsProvider == 'resemble') ...[
              const Text('Resemble AI 的音色稳定度、相似度主要由 voice_uuid 对应模型决定；本页只保留速度、SSML/HD、采样率、冥想停顿等有效参数，避免误配 ElevenLabs 专用参数。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ] else ...[
              _slider('MiniMax 音量 vol', _minimaxVolume, 0.0, 10.0, (v) => setState(() => _minimaxVolume = v), help: 'MiniMax voice_setting.vol，推荐 1.0。'),
              _slider('MiniMax 音调 pitch', _minimaxPitch.toDouble(), -12.0, 12.0, (v) => setState(() => _minimaxPitch = v.round()), help: 'MiniMax voice_setting.pitch，负数更低沉，正数更明亮。'),
              DropdownButtonFormField<String>(
                value: _minimaxEmotion,
                decoration: const InputDecoration(labelText: 'MiniMax 情感 emotion', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('不指定')),
                  DropdownMenuItem(value: 'calm', child: Text('calm 平静 / 冥想推荐')),
                  DropdownMenuItem(value: 'fluent', child: Text('fluent 流畅')),
                  DropdownMenuItem(value: 'happy', child: Text('happy 开心')),
                  DropdownMenuItem(value: 'sad', child: Text('sad 悲伤')),
                  DropdownMenuItem(value: 'angry', child: Text('angry 愤怒')),
                  DropdownMenuItem(value: 'fearful', child: Text('fearful 害怕')),
                  DropdownMenuItem(value: 'disgusted', child: Text('disgusted 厌恶')),
                  DropdownMenuItem(value: 'surprised', child: Text('surprised 惊讶')),
                ],
                onChanged: (v) => setState(() => _minimaxEmotion = v ?? 'calm'),
              ),
              const SizedBox(height: 8),
              TextField(decoration: const InputDecoration(labelText: 'MiniMax language_boost', helperText: 'auto / Chinese / English / Japanese 等', border: OutlineInputBorder()), controller: _minimaxLanguageBoostCtrl, onChanged: (v) => _minimaxLanguageBoost = v),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('MiniMax 文本规范化'), subtitle: const Text('english_normalization / text normalization'), value: _minimaxTextNormalization, onChanged: (v) => setState(() => _minimaxTextNormalization = v)),
              DropdownButtonFormField<String>(value: <String>['none', 'spacious_echo'].contains(_minimaxSoundEffects) ? (_minimaxSoundEffects.isEmpty ? 'none' : _minimaxSoundEffects) : 'none', decoration: const InputDecoration(labelText: 'MiniMax 声场/音效 voice_modify.sound_effects', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'none', child: Text('无')), DropdownMenuItem(value: 'spacious_echo', child: Text('spacious_echo 空间回声'))], onChanged: (v) => setState(() => _minimaxSoundEffects = v == 'none' ? '' : (v ?? ''))),
            ],
            _meditationParametersPanel(),
            if (_ttsProvider == 'elevenlabs') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _seedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'seed，可留空', helperText: 'ElevenLabs：用于尽量复现同样采样，不保证完全确定。', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('ElevenLabs 连续性上下文 previous_text / next_text'),
                subtitle: const Text('适合把长文分段生成时保持语气连续。'),
                children: [
                  TextField(controller: _previousTextCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'previous_text：当前文本前面的上下文', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: _nextTextCtrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'next_text：当前文本后面的上下文', border: OutlineInputBorder())),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meditationParametersPanel() {
    if (!ElevenLabsService.isMeditationScene(_ttsScene)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.indigo.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.indigo.withOpacity(0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.self_improvement, size: 20),
              SizedBox(width: 6),
              Expanded(child: Text('冥想模式专用参数', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '冥想配音会在原文基础上自动强化慢语速、稳定感、留白和呼吸停顿。ElevenLabs 使用 break/v3 标签；Resemble 使用 SSML/prompt；MiniMax 使用 <#秒数#> 固定停顿。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用冥想自动停顿'),
            subtitle: const Text('按句子、段落、呼吸词自动加入停顿，适合冥想引导和睡前放松。'),
            value: _meditationAutoPauses,
            onChanged: (v) => setState(() => _meditationAutoPauses = v),
          ),
          DropdownButtonFormField<String>(
            value: _meditationPauseProfile,
            decoration: const InputDecoration(labelText: '留白深度', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'light', child: Text('轻留白：只保留段落/呼吸停顿')),
              DropdownMenuItem(value: 'standard', child: Text('标准留白：句间和段落都有停顿')),
              DropdownMenuItem(value: 'deep', child: Text('深留白：更适合深度放松/睡前')),
              DropdownMenuItem(value: 'custom', child: Text('自定义：完全按下方秒数')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _meditationPauseProfile = v;
                if (v == 'light') {
                  _meditationSentenceBreakSec = 0.8;
                  _meditationParagraphBreakSec = 1.5;
                  _meditationBreathBreakSec = 1.4;
                } else if (v == 'standard') {
                  _meditationSentenceBreakSec = 1.2;
                  _meditationParagraphBreakSec = 2.0;
                  _meditationBreathBreakSec = 1.8;
                } else if (v == 'deep') {
                  _meditationSentenceBreakSec = 1.5;
                  _meditationParagraphBreakSec = 2.4;
                  _meditationBreathBreakSec = 2.0;
                }
              });
            },
          ),
          const SizedBox(height: 8),
          _slider('句间停顿 秒', _meditationSentenceBreakSec, 0.3, 60.0, (v) => setState(() {
            _meditationSentenceBreakSec = v;
            _meditationPauseProfile = 'custom';
          }), help: '每个句号、问号、感叹号后的停顿。'),
          _slider('段落停顿 秒', _meditationParagraphBreakSec, 0.3, 60.0, (v) => setState(() {
            _meditationParagraphBreakSec = v;
            _meditationPauseProfile = 'custom';
          }), help: '空行或段落之间的停顿。'),
          _slider('呼吸提示停顿 秒', _meditationBreathBreakSec, 0.3, 60.0, (v) => setState(() {
            _meditationBreathBreakSec = v;
            _meditationPauseProfile = 'custom';
          }), help: '“吸气、呼气、闭上眼睛、放松肩膀”等词后的停顿。'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动识别呼吸提示词'),
            subtitle: const Text('命中“吸气/呼气/闭上眼睛/放松肩膀”等词时自动插入更长停顿。'),
            value: _meditationAutoBreathPauses,
            onChanged: (v) => setState(() => _meditationAutoBreathPauses = v),
          ),
          DropdownButtonFormField<String>(
            value: _meditationTone,
            decoration: InputDecoration(labelText: _ttsProvider == 'resemble' ? '冥想语气方向 / Prompt tone' : '冥想语气标签（eleven_v3 时生效）', border: const OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'calm', child: Text('calm 平静')),
              DropdownMenuItem(value: 'soft', child: Text('soft 轻柔')),
              DropdownMenuItem(value: 'whisper', child: Text('whisper 低语')),
              DropdownMenuItem(value: 'warm', child: Text('warm 温暖')),
              DropdownMenuItem(value: 'healing', child: Text('healing 疗愈')),
            ],
            onChanged: (v) => setState(() => _meditationTone = v ?? 'calm'),
          ),
          if (_ttsProvider == 'resemble') ...[
            const SizedBox(height: 10),
            _resembleMeditationExpertPanel(),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _ttsTextCtrl.text = '现在，慢慢闭上眼睛。\n\n把注意力放在你的呼吸上。\n\n吸气。\n呼气。\n\n你不需要努力改变什么，只需要允许自己，安静地待在这里。';
                }),
                icon: const Icon(Icons.text_snippet_outlined),
                label: const Text('填入冥想测试文本'),
              ),
              TextButton.icon(
                onPressed: () {
                  final preset = ElevenLabsService.presetById('meditation_relax');
                  setState(() {
                    _ttsScene = preset.id;
                    _ttsSpeed = preset.speed;
                    _ttsStability = preset.stability;
                    _ttsSimilarityBoost = preset.similarityBoost;
                    _ttsStyle = preset.style;
                    _ttsUseSpeakerBoost = preset.speakerBoost;
                    _pauseMode = preset.recommendedPauseMode;
                    _meditationAutoPauses = preset.meditationAutoPauses;
                    _meditationPauseProfile = preset.meditationPauseProfile;
                    _meditationSentenceBreakSec = preset.meditationSentenceBreakSec;
                    _meditationParagraphBreakSec = preset.meditationParagraphBreakSec;
                    _meditationBreathBreakSec = preset.meditationBreathBreakSec;
                    _meditationTone = preset.meditationTone;
                    _meditationAutoBreathPauses = preset.meditationAutoBreathPauses;
                  });
                },
                icon: const Icon(Icons.restore),
                label: const Text('恢复冥想推荐参数'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resembleMeditationExpertPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(10),
        color: Colors.deepPurple.withOpacity(0.035),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resemble AI 冥想专家参数', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Resemble 冥想效果主要由 voice_uuid、SSML 停顿、prompt 指令和高清合成共同决定。这里避免使用容易报错的 prosody 语速标签，改用安全停顿和导演提示控制“慢、稳、柔、留白”。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _resembleMeditationMode,
            decoration: const InputDecoration(labelText: 'Resemble 冥想合成模式', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'expert_ssml', child: Text('专家 SSML + Prompt（推荐）')),
              DropdownMenuItem(value: 'safe_breaks', child: Text('安全 SSML + Prompt')),
              DropdownMenuItem(value: 'breaks_only', child: Text('只插入停顿，不加 prompt')),
              DropdownMenuItem(value: 'plain_prompt', child: Text('只加 prompt，不插入停顿')),
            ],
            onChanged: (v) => setState(() => _resembleMeditationMode = v ?? VoiceProviderSettings.defaultResembleMeditationMode),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用 Resemble 冥想导演 prompt'),
            subtitle: const Text('用于引导声音更像冥想老师：慢、轻、温柔、留白充分。'),
            value: _resembleMeditationUsePrompt,
            onChanged: (v) => setState(() => _resembleMeditationUsePrompt = v),
          ),
          TextField(
            controller: _resembleMeditationPromptCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Resemble 冥想 prompt',
              helperText: '建议用英文描述声音方向；留空则按上方语气自动生成。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _slider('Resemble 单个 break 最大秒数', _resembleMeditationMaxBreakSec, 0.3, 10.0, (v) => setState(() => _resembleMeditationMaxBreakSec = v), help: '建议 2–3 秒。长停顿会被拆成多个 break，降低服务端报错和怪声概率。'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('长停顿拆分为多个 break'),
            subtitle: const Text('例如 12 秒留白会拆成 3s + 3s + 3s + 3s，更适合 Resemble 冥想生成。'),
            value: _resembleMeditationSplitLongBreaks,
            onChanged: (v) => setState(() => _resembleMeditationSplitLongBreaks = v),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TextButton.icon(
              onPressed: () => setState(() {
                _resembleMeditationMode = VoiceProviderSettings.defaultResembleMeditationMode;
                _resembleMeditationUsePrompt = true;
                _resembleMeditationPromptCtrl.text = VoiceProviderSettings.defaultResembleMeditationPrompt;
                _resembleMeditationMaxBreakSec = VoiceProviderSettings.defaultResembleMeditationMaxBreakSec;
                _resembleMeditationSplitLongBreaks = true;
                _ttsSpeed = 0.82;
                _resembleUseHd = true;
                _resembleOutputFormat = 'mp3';
                _resembleSampleRateCtrl.text = '48000';
              }),
              icon: const Icon(Icons.restore),
              label: const Text('恢复 Resemble 冥想专家参数'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _manualTtsCard() {
    final sourceText = _ttsProvider == 'resemble'
        ? (_ttsVoiceSource == 'cloned' && _selectedVoice?.provider == 'resemble'
            ? 'Resemble 克隆声音：${_selectedVoice!.displayName}'
            : 'Resemble voice_uuid：${_resembleVoiceNameCtrl.text.trim().isEmpty ? _resembleVoiceUuidCtrl.text.trim() : _resembleVoiceNameCtrl.text.trim()}')
        : (_ttsProvider == 'minimax'
            ? (_ttsVoiceSource == 'cloned' && _selectedVoice?.provider == 'minimax'
                ? 'MiniMax 克隆声音：${_selectedVoice!.displayName}'
                : 'MiniMax voice_id：${_minimaxVoiceNameCtrl.text.trim().isEmpty ? _minimaxVoiceIdCtrl.text.trim() : _minimaxVoiceNameCtrl.text.trim()}')
            : (_ttsVoiceSource == 'cloned'
                ? (_selectedVoice == null ? '克隆声音：未选择' : '克隆声音：${_selectedVoice!.displayName}')
                : "普通声音：${_presetVoiceNameCtrl.text.trim().isEmpty ? _presetVoiceIdCtrl.text.trim() : _presetVoiceNameCtrl.text.trim()}"));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文字转语音测试', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('$sourceText\n生成后会自动进入“语音文件库”，可播放、删除、下载到 Download 目录。', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: _ttsTextCtrl,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: '要朗读的文字', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _generating ? null : _generateTts,
              icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.record_voice_over),
              label: const Text('生成并播放'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teacherConfigCard() {
    final voiceSummary = _ttsProvider == 'resemble'
        ? (_ttsVoiceSource == 'cloned' && _selectedVoice?.provider == 'resemble'
            ? '美好的祝福将使用 Resemble 克隆声音：${_selectedVoice!.displayName}'
            : '美好的祝福将使用 Resemble voice_uuid：${_resembleVoiceNameCtrl.text.trim().isEmpty ? _resembleVoiceUuidCtrl.text.trim() : _resembleVoiceNameCtrl.text.trim()}')
        : (_ttsProvider == 'minimax'
            ? (_ttsVoiceSource == 'cloned' && _selectedVoice?.provider == 'minimax'
                ? '美好的祝福将使用 MiniMax 克隆声音：${_selectedVoice!.displayName}'
                : '美好的祝福将使用 MiniMax voice_id：${_minimaxVoiceNameCtrl.text.trim().isEmpty ? _minimaxVoiceIdCtrl.text.trim() : _minimaxVoiceNameCtrl.text.trim()}')
            : (_ttsVoiceSource == 'premade'
                ? "美好的祝福将使用 ElevenLabs 普通声音：${_presetVoiceNameCtrl.text.trim().isEmpty ? _presetVoiceIdCtrl.text.trim() : _presetVoiceNameCtrl.text.trim()}"
                : (_selectedVoice == null ? '当前还没有绑定 ElevenLabs 克隆声音' : '绑定 ElevenLabs 克隆声音：${_selectedVoice!.displayName}')));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('美好的祝福配置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _teacherNameCtrl,
              decoration: const InputDecoration(labelText: '老师名称', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _teacherPersonaCtrl,
              minLines: 6,
              maxLines: 14,
              decoration: const InputDecoration(labelText: '老师人格 / 教学风格提示词', border: OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('美好的祝福开启语音回复'),
              subtitle: Text(voiceSummary),
              value: _teacherVoiceReply,
              onChanged: (v) => setState(() => _teacherVoiceReply = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await _save(showToast: false);
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VirtualTeacherPage()));
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('进入美好的祝福对话'),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _teacherPersonaCtrl.text = ElevenLabsSettings.defaultTeacherPersona),
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复默认提示词'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _providerDisplayName(String provider) {
    return switch (provider) {
      'resemble' => 'Resemble AI',
      'minimax' => 'MiniMax',
      'microsoft' => 'Microsoft Azure Speech',
      _ => 'ElevenLabs',
    };
  }

  Widget _dropdown(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    final safeValue = options.containsKey(value) ? value : options.keys.first;
    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged, {String? help}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('$label：${value.toStringAsFixed(2)}')),
            if (help != null) Tooltip(message: help, child: const Icon(Icons.info_outline, size: 18)),
          ],
        ),
        Slider(value: value, min: min, max: max, divisions: max > 10 ? 120 : 50, label: value.toStringAsFixed(max > 10 ? 1 : 2), onChanged: onChanged),
      ],
    );
  }
}
