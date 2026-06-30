import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/kv_dao.dart';
import '../voice_lab/eleven_labs_service.dart';
import '../voice_lab/multi_provider_tts_service.dart';
import '../voice_lab/voice_lab_dao.dart';
import '../voice_lab/voice_lab_models.dart';
import '../services/unified_ai_service.dart';
import '../services/global_ai_settings.dart';

class VoiceAlarmPage extends StatefulWidget {
  const VoiceAlarmPage({super.key});

  @override
  State<VoiceAlarmPage> createState() => _VoiceAlarmPageState();
}


class _VoiceAlarmEntry {
  const _VoiceAlarmEntry({required this.id, required this.time, required this.text});

  final String id;
  final TimeOfDay time;
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': time.hour,
        'minute': time.minute,
        'text': text,
      };

  static _VoiceAlarmEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = (value['id'] ?? '').toString();
    final hour = (value['hour'] as num?)?.toInt();
    final minute = (value['minute'] as num?)?.toInt();
    if (id.isEmpty || hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return _VoiceAlarmEntry(
      id: id,
      time: TimeOfDay(hour: hour, minute: minute),
      text: (value['text'] ?? '').toString(),
    );
  }
}

class _VoiceAlarmPageState extends State<VoiceAlarmPage> {
  final _text = TextEditingController(text: '早上好，新的一天开始了。愿你平静、专注、充满力量。');
  final _tts = MultiProviderTtsService();
  final _elevenLabs = ElevenLabsService();
  final _kv = KeyValueDao();
  final _voiceDao = VoiceLabDao();
  final _ai = UnifiedAiService();
  final _aiSettings = GlobalAiSettings();
  static const _native = MethodChannel('com.example.quote_app/voice_alarm');
  TimeOfDay _time = TimeOfDay.now();
  String _provider = 'microsoft';
  String _sttProvider = 'microsoft';
  String _sttMode = 'realtime';
  bool _batchAutoSubmit = true;
  double _batchAutoSubmitSilenceMs = 5000;
  double _batchMaxRecordMs = 60000;
  bool _batchAutoCorrect = false;
  String? _customMusic;
  String? _backgroundImage;
  List<String> _customMusics = [];
  List<String> _backgroundImages = [];
  List<_VoiceAlarmEntry> _alarmEntries = [];
  String? _generatedVoice;
  double _speed = 1.0;
  double _pauseSeconds = 0.6;
  String _scene = 'natural_dialogue';
  String _emotion = 'calm';
  final _voiceId = TextEditingController();
  bool _vibrate = true;
  bool _systemMusic = true;
  bool _saving = false;
  bool _loading = true;
  String _mode = 'morning';
  String _frequency = 'daily';
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  double _voiceVolume = 1.0;
  double _musicVolume = 0.4;
  double _stability = 0.55;
  double _styleStrength = 0.25;
  double _pitch = 0;
  int _replayIntervalSeconds = 60;
  bool _resembleHd = true;
  List<Map<String, String>> _savedVoices = [];
  List<VoiceProfile> _voiceProfiles = [];
  final Map<String, List<Map<String, String>>> _catalogRecommendations = {};
  String? _selectedSavedVoicePath;
  List<String> _textHistory = [];
  Map<String, dynamic> _alarmAiConfig = <String, dynamic>{};
  String _alarmAiSystemPrompt = '';
  Map<String, dynamic> _alarmSttConfig = <String, dynamic>{};
  String _speechPreset = 'balanced';
  double _speechCompleteSilenceMs = 2400;
  double _speechPossiblyCompleteSilenceMs = 1600;
  double _speechMinUtteranceMs = 1400;
  double _speechFinalCommitDelayMs = 2800;
  double _speechPartialFallbackDelayMs = 5200;
  double _speechSemanticExtraWaitMs = 0;
  double _speechStableTextMs = 750;
  double _speechMaxUtteranceMs = 22000;
  double _speechMinCommitChars = 5;
  bool _speechSemanticEndpointing = false;

  static const _morningDefault = '早上好，新的一天开始了。愿你平静、专注、充满力量。';
  static const _nightDefault = '晚安，今天辛苦了。放下未完成的事，安心休息，愿你拥有宁静的睡眠。';

  @override
  void initState() {
    super.initState();
    _loadMode('morning');
  }

  @override
  void dispose() {
    _text.dispose();
    _voiceId.dispose();
    super.dispose();
  }

  DateTime _nextTime() => _nextTimeFor(_time);

  String get _configKey => 'voice_alarm.config.$_mode';
  String get _historyKey => 'voice_alarm.text_history.$_mode';

  List<String> _stringListFromConfig(Map<String, dynamic> data, String listKey, String legacyKey) {
    final values = <String>[];
    final rawList = data[listKey];
    if (rawList is List) {
      values.addAll(rawList.map((e) => e.toString()).where((path) => path.trim().isNotEmpty));
    }
    final legacy = data[legacyKey]?.toString() ?? '';
    if (legacy.isNotEmpty) values.add(legacy);
    final seen = <String>{};
    return values.where((path) => seen.add(path)).toList();
  }

  DateTime _nextTimeFor(TimeOfDay time) {
    final now = DateTime.now();
    var value = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!value.isAfter(now)) value = value.add(const Duration(days: 1));
    final allowed = _effectiveWeekdays();
    var guard = 0;
    while (!allowed.contains(value.weekday) && guard < 8) {
      value = value.add(const Duration(days: 1));
      guard++;
    }
    return value;
  }

  Future<void> _loadMode(String mode) async {
    setState(() {
      _loading = true;
      _mode = mode;
    });
    final raw = await _kv.getString('voice_alarm.config.$mode');
    final historyRaw = await _kv.getString('voice_alarm.text_history.$mode');
    final audios = await _voiceDao.listTtsAudio();
    final generatedRaw = await _kv.getString('voice_alarm.generated_audio');
    final profiles = await _voiceDao.listVoiceProfiles();
    final data = raw == null || raw.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final history = historyRaw == null || historyRaw.isEmpty ? <String>[] : List<String>.from(jsonDecode(historyRaw) as List);
    if (!mounted) return;
    setState(() {
      _voiceProfiles = profiles;
      _text.text = (data['text'] ?? (mode == 'morning' ? _morningDefault : _nightDefault)).toString();
      _provider = (data['provider'] ?? 'microsoft').toString();
      final loadedSttProvider = (data['sttProvider'] ?? 'microsoft').toString();
      _sttProvider = ['microsoft', 'iflytek', 'xai'].contains(loadedSttProvider) ? loadedSttProvider : 'microsoft';
      final loadedSttMode = (data['sttMode'] ?? 'realtime').toString();
      _sttMode = ['realtime', 'batch'].contains(loadedSttMode) ? loadedSttMode : 'realtime';
      final batchStt = data['batchStt'] is Map ? Map<String, dynamic>.from(data['batchStt'] as Map) : <String, dynamic>{};
      _batchAutoSubmit = batchStt['autoSubmit'] as bool? ?? true;
      _batchAutoSubmitSilenceMs = (batchStt['autoSubmitSilenceMs'] as num?)?.toDouble() ?? 5000;
      _batchMaxRecordMs = (batchStt['maxRecordMs'] as num?)?.toDouble() ?? 60000;
      _batchAutoCorrect = batchStt['autoCorrect'] as bool? ?? false;
      final recommendations = _recommendedVoices(_provider, mode);
      _voiceId.text = (data['voiceId'] ?? (recommendations.isEmpty ? '' : recommendations.first['id'])).toString();
      _speed = (data['speed'] as num?)?.toDouble() ?? (mode == 'morning' ? 1.05 : 0.88);
      _pauseSeconds = (data['pauseSeconds'] as num?)?.toDouble() ?? (mode == 'morning' ? 0.35 : 0.9);
      _scene = (data['scene'] ?? (mode == 'morning' ? 'morning_blessing' : 'meditation_relax')).toString();
      _emotion = (data['emotion'] ?? (mode == 'morning' ? 'cheerful' : 'calm')).toString();
      _frequency = (data['frequency'] ?? 'daily').toString();
      _weekdays = (data['weekdays'] is List ? (data['weekdays'] as List).map((e) => (e as num).toInt()).toSet() : {1, 2, 3, 4, 5, 6, 7});
      _voiceVolume = (data['voiceVolume'] as num?)?.toDouble() ?? 1;
      _musicVolume = (data['musicVolume'] as num?)?.toDouble() ?? 0.4;
      _stability = (data['stability'] as num?)?.toDouble() ?? 0.55;
      _styleStrength = (data['styleStrength'] as num?)?.toDouble() ?? 0.25;
      _pitch = (data['pitch'] as num?)?.toDouble() ?? 0;
      _replayIntervalSeconds = (data['replayIntervalSeconds'] as num?)?.toInt() ?? 60;
      final endpointing = data['voiceEndpointing'] is Map ? Map<String, dynamic>.from(data['voiceEndpointing'] as Map) : <String, dynamic>{};
      _speechPreset = ['fast', 'balanced', 'complete', 'long'].contains((endpointing['preset'] ?? 'balanced').toString()) ? (endpointing['preset'] ?? 'balanced').toString() : 'balanced';
      _speechCompleteSilenceMs = (endpointing['completeSilenceMs'] as num?)?.toDouble() ?? 2400;
      _speechPossiblyCompleteSilenceMs = (endpointing['possiblyCompleteSilenceMs'] as num?)?.toDouble() ?? 1600;
      _speechMinUtteranceMs = (endpointing['minUtteranceMs'] as num?)?.toDouble() ?? 1400;
      _speechFinalCommitDelayMs = (endpointing['finalCommitDelayMs'] as num?)?.toDouble() ?? 2800;
      _speechPartialFallbackDelayMs = (endpointing['partialFallbackDelayMs'] as num?)?.toDouble() ?? 5200;
      _speechSemanticExtraWaitMs = (endpointing['semanticExtraWaitMs'] as num?)?.toDouble() ?? 0;
      _speechStableTextMs = (endpointing['stableTextMs'] as num?)?.toDouble() ?? 750;
      _speechMaxUtteranceMs = (endpointing['maxUtteranceMs'] as num?)?.toDouble() ?? 22000;
      _speechMinCommitChars = (endpointing['minCommitChars'] as num?)?.toDouble() ?? 5;
      _speechSemanticEndpointing = endpointing['semanticEndpointing'] as bool? ?? false;
      _resembleHd = data['resembleHd'] as bool? ?? true;
      _vibrate = data['vibrate'] as bool? ?? true;
      _systemMusic = data['systemMusic'] as bool? ?? true;
      final savedTime = DateTime.tryParse((data['time'] ?? '').toString());
      if (savedTime != null) _time = TimeOfDay.fromDateTime(savedTime);
      _customMusics = _stringListFromConfig(data, 'musicPaths', 'musicPath');
      _backgroundImages = _stringListFromConfig(data, 'backgroundPaths', 'backgroundPath');
      _customMusic = _customMusics.isNotEmpty ? _customMusics.first : null;
      _backgroundImage = _backgroundImages.isNotEmpty ? _backgroundImages.first : null;
      _alarmEntries = (data['alarms'] is List ? data['alarms'] as List : const [])
          .map(_VoiceAlarmEntry.fromJson)
          .whereType<_VoiceAlarmEntry>()
          .toList();
      _selectedSavedVoicePath = data['savedVoicePath']?.toString().isEmpty == false ? data['savedVoicePath'].toString() : null;
      final generated = generatedRaw == null || generatedRaw.isEmpty
          ? <Map<String, String>>[]
          : (jsonDecode(generatedRaw) as List).whereType<Map>().map((e) => Map<String, String>.from(e)).toList();
      _savedVoices = [
        ...generated.where((a) => File(a['path'] ?? '').existsSync()),
        ...audios.where((a) => a.moduleName.startsWith('voice_alarm_') && File(a.audioFilePath).existsSync()).map((a) => {
              'path': a.audioFilePath,
              'label': '${a.voiceDisplayName} · ${a.sourceText}',
            }),
      ];
      _textHistory = history;
      _loading = false;
    });
    await _refreshProviderRecommendations();
  }

  Future<void> _refreshProviderRecommendations() async {
    try {
      List<Map<String, String>> options = [];
      if (_provider == 'resemble') {
        final voices = await _tts.listResembleVoices(pageSize: 100);
        final chinese = voices.where((v) => '${v.name} ${v.description} ${v.extra['language'] ?? ''}'.toLowerCase().contains(RegExp(r'zh|chinese|mandarin|中文'))).toList();
        options = (chinese.isEmpty ? voices : chinese).take(2).map((v) => {'id': v.id, 'name': '${v.name} · 当前 Token 已授权'}).toList();
      } else if (_provider == 'elevenlabs') {
        final voices = await _elevenLabs.listVoices(search: 'Chinese');
        options = voices.take(2).map((v) => {'id': v.voiceId, 'name': '${v.name} · 中文/多语言'}).toList();
      }
      if (options.isNotEmpty && mounted) setState(() => _catalogRecommendations[_provider] = options);
    } catch (_) {
      // 保留本地声音档案推荐；API 凭据错误会在实际保存/测试时显示明确错误。
    }
  }

  List<Map<String, String>> _recommendedVoices(String provider, String mode) {
    if (provider == 'microsoft') {
      return mode == 'morning'
          ? const [
              {'id': 'zh-CN-XiaoxiaoNeural', 'name': '晓晓 · 明亮自然'},
              {'id': 'zh-CN-YunxiNeural', 'name': '云希 · 青年活力'},
            ]
          : const [
              {'id': 'zh-CN-XiaoyiNeural', 'name': '晓伊 · 柔和女声'},
              {'id': 'zh-CN-YunyangNeural', 'name': '云扬 · 沉稳男声'},
            ];
    }
    if (provider == 'minimax') {
      return mode == 'morning'
          ? const [
              {'id': 'female-shaonv', 'name': '少女中文女声 · 清亮早安'},
              {'id': 'presenter_male', 'name': '主持人中文男声 · 清晰唤醒'},
            ]
          : const [
              {'id': 'audiobook_female_1', 'name': '有声书中文女声 · 舒缓晚安'},
              {'id': 'male-qn-qingse', 'name': '青涩中文男声 · 温和陪伴'},
            ];
    }
    final catalog = _catalogRecommendations[provider] ?? const <Map<String, String>>[];
    if (catalog.length >= 2) return catalog.take(2).toList();
    final matched = _voiceProfiles.where((profile) => profile.provider == provider).take(2).map((profile) {
      return {'id': profile.elevenlabsVoiceId, 'name': '${profile.displayName} · 中文/多语言'};
    }).toList();
    if (matched.length >= 2) return matched;
    return [
      ...matched,
      {'id': _voiceId.text, 'name': provider == 'resemble' ? '当前账号授权中文声音' : '当前配置中文/多语言声音'},
      {'id': '', 'name': '请在美好祝福配置中再添加一个中文声音'},
    ].where((item) => item['id']!.isNotEmpty).fold<List<Map<String, String>>>([], (list, item) {
      if (!list.any((existing) => existing['id'] == item['id'])) list.add(item);
      return list;
    });
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    final paths = result?.files.map((file) => file.path).whereType<String>().where((path) => path.isNotEmpty).toList() ?? const <String>[];
    if (paths.isEmpty || !mounted) return;
    setState(() {
      _customMusics = <String>{..._customMusics, ...paths}.toList();
      _customMusic = (_customMusics.isEmpty ? null : _customMusics.first);
      _systemMusic = true;
    });
    await _persistDraftConfig();
  }

  Future<void> _pickBackground() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    final paths = result?.files.map((file) => file.path).whereType<String>().where((path) => path.isNotEmpty).toList() ?? const <String>[];
    if (paths.isEmpty || !mounted) return;
    setState(() {
      _backgroundImages = <String>{..._backgroundImages, ...paths}.toList();
      _backgroundImage = (_backgroundImages.isEmpty ? null : _backgroundImages.first);
    });
    await _persistDraftConfig();
  }

  Future<void> _persistDraftConfig() async {
    final config = _payloadMap()
      ..['savedVoicePath'] = _selectedSavedVoicePath ?? ''
      ..['time'] = _nextTime().toIso8601String();
    await _kv.setString(_configKey, jsonEncode(config));
  }

  Future<void> _removeAlarmEntry(_VoiceAlarmEntry alarm) async {
    setState(() => _alarmEntries = _alarmEntries.where((item) => item.id != alarm.id).toList());
    await _persistDraftConfig();
    try {
      await _native.invokeMethod<void>('cancelAlarm', {'alarmId': alarm.id});
      _toast('已删除并取消 ${alarm.time.format(context)} 的闹钟');
    } catch (e) {
      _toast('已从列表删除；取消系统闹钟失败：$e');
    }
  }

  Future<bool> _ensureVoiceInteractionReady() async {
    final mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      final requested = await Permission.microphone.request();
      if (!requested.isGranted) {
        _toast('未授权麦克风：仍会保存并响铃，但语音唤醒、AI 对话和语音关闭闹钟将不可用');
      }
    }
    final notification = await Permission.notification.status;
    if (!notification.isGranted) {
      final requested = await Permission.notification.request();
      if (!requested.isGranted) {
        _toast('未授权通知：仍会保存闹钟，但锁屏全屏通知和后台提醒可靠性会下降');
      }
    }
    return true;
  }

  Future<void> _refreshAlarmAiConfig() async {
    try {
      final cfg = await _ai.resolveGlobalConfig();
      _alarmAiSystemPrompt = _mode == 'night'
          ? await _aiSettings.getVoiceAlarmNightAssistantPrompt()
          : await _aiSettings.getVoiceAlarmMorningAssistantPrompt();
      _alarmAiConfig = <String, dynamic>{
        'provider': cfg.provider,
        'model': cfg.model,
        'endpoint': cfg.endpoint,
        'apiKey': cfg.apiKey,
        'available': cfg.available,
        'label': cfg.label,
      };
    } catch (_) {
      _alarmAiConfig = <String, dynamic>{'available': false};
    }
    await _refreshAlarmSttConfig();
  }

  Future<void> _refreshAlarmSttConfig() async {
    final microsoftRegion = await _kv.getString(VoiceProviderSettings.microsoftRegion) ?? VoiceProviderSettings.defaultMicrosoftRegion;
    final microsoftLanguage = await _kv.getString(VoiceProviderSettings.microsoftLanguage) ?? VoiceProviderSettings.defaultMicrosoftLanguage;
    _alarmSttConfig = <String, dynamic>{
      'provider': _sttProvider,
      'microsoft': {
        'apiKey': await _kv.getString(VoiceProviderSettings.microsoftApiKey) ?? '',
        'region': microsoftRegion,
        'endpoint': await _kv.getString(VoiceProviderSettings.microsoftRecognitionEndpoint) ?? '',
        'language': microsoftLanguage,
      },
      'iflytek': {
        'appId': await _kv.getString(VoiceProviderSettings.iflytekAppId) ?? '',
        'apiKey': await _kv.getString(VoiceProviderSettings.iflytekApiKey) ?? '',
        'apiSecret': await _kv.getString(VoiceProviderSettings.iflytekApiSecret) ?? '',
        'endpoint': await _kv.getString(VoiceProviderSettings.iflytekSttEndpoint) ?? VoiceProviderSettings.defaultIflytekSttEndpoint,
        'language': await _kv.getString(VoiceProviderSettings.iflytekLanguage) ?? VoiceProviderSettings.defaultIflytekLanguage,
        'accent': await _kv.getString(VoiceProviderSettings.iflytekAccent) ?? VoiceProviderSettings.defaultIflytekAccent,
      },
      'xai': {
        'apiKey': await _aiSettings.getXGrokKey(),
        'endpoint': await _kv.getString('xai.stt.endpoint') ?? 'https://api.x.ai/v1/stt',
        'streamingEndpoint': await _kv.getString('xai.stt.streaming_endpoint') ?? 'wss://api.x.ai/v1/stt',
        'language': await _kv.getString('xai.stt.language') ?? '',
        'sampleRate': 16000,
        'encoding': 'pcm',
        'interimResults': true,
      },
    };
  }

  void _applySpeechPreset(String preset) {
    setState(() {
      _speechPreset = preset;
      switch (preset) {
        case 'fast':
          _speechCompleteSilenceMs = 900;
          _speechPossiblyCompleteSilenceMs = 700;
          _speechMinUtteranceMs = 500;
          _speechFinalCommitDelayMs = 900;
          _speechPartialFallbackDelayMs = 1800;
          _speechSemanticExtraWaitMs = 0;
          _speechStableTextMs = 500;
          _speechMaxUtteranceMs = 12000;
          _speechMinCommitChars = 1;
          _speechSemanticEndpointing = false;
          break;
        case 'complete':
          _speechCompleteSilenceMs = 2200;
          _speechPossiblyCompleteSilenceMs = 1500;
          _speechMinUtteranceMs = 800;
          _speechFinalCommitDelayMs = 2100;
          _speechPartialFallbackDelayMs = 3600;
          _speechSemanticExtraWaitMs = 0;
          _speechStableTextMs = 1000;
          _speechMaxUtteranceMs = 35000;
          _speechMinCommitChars = 1;
          _speechSemanticEndpointing = false;
          break;
        case 'long':
          _speechCompleteSilenceMs = 3200;
          _speechPossiblyCompleteSilenceMs = 2200;
          _speechMinUtteranceMs = 1000;
          _speechFinalCommitDelayMs = 3200;
          _speechPartialFallbackDelayMs = 5200;
          _speechSemanticExtraWaitMs = 0;
          _speechStableTextMs = 1400;
          _speechMaxUtteranceMs = 60000;
          _speechMinCommitChars = 1;
          _speechSemanticEndpointing = false;
          break;
        default:
          _speechPreset = 'balanced';
          _speechCompleteSilenceMs = 1400;
          _speechPossiblyCompleteSilenceMs = 1000;
          _speechMinUtteranceMs = 600;
          _speechFinalCommitDelayMs = 1300;
          _speechPartialFallbackDelayMs = 2600;
          _speechSemanticExtraWaitMs = 0;
          _speechStableTextMs = 750;
          _speechMaxUtteranceMs = 22000;
          _speechMinCommitChars = 1;
          _speechSemanticEndpointing = false;
      }
    });
  }

  Map<String, dynamic> _voiceEndpointingMap() {
    final complete = _speechCompleteSilenceMs.round();
    final possibly = _speechPossiblyCompleteSilenceMs.round().clamp(500, complete - 100).toInt();
    final minUtterance = _speechMinUtteranceMs.round();
    final commit = _speechFinalCommitDelayMs.round();
    return {
      'preset': _speechPreset,
      'completeSilenceMs': complete,
      'possiblyCompleteSilenceMs': possibly,
      'minUtteranceMs': minUtterance,
      'finalCommitDelayMs': commit,
      'partialFallbackDelayMs': _speechPartialFallbackDelayMs.round().clamp(commit, 10000).toInt(),
      'semanticExtraWaitMs': _speechSemanticExtraWaitMs.round(),
      'stableTextMs': _speechStableTextMs.round().clamp(300, 3000).toInt(),
      'maxUtteranceMs': _speechMaxUtteranceMs.round().clamp(8000, 60000).toInt(),
      'minCommitChars': _speechMinCommitChars.round(),
      'semanticEndpointing': false,
    };
  }

  Map<String, dynamic> _batchSttMap() {
    final silence = _batchAutoSubmitSilenceMs.round().clamp(800, 30000).toInt();
    final maxRecord = _batchMaxRecordMs.round().clamp(5000, 300000).toInt();
    // 长句不等到 maxRecord 才提交；但不要切得太碎，否则短片段更容易被服务商识别成残句。
    final segmentMax = maxRecord < 30000 ? maxRecord : 30000;
    return {
      'mode': _sttMode,
      'autoSubmit': _batchAutoSubmit,
      'autoSubmitSilenceMs': silence,
      'manualSubmit': true,
      'maxRecordMs': maxRecord,
      'segmentMaxMs': segmentMax,
      'autoCorrect': _batchAutoCorrect,
      'bestResult': true,
    };
  }

  Future<void> _schedule() async {
    if (_text.text.trim().isEmpty) {
      _toast('请输入闹钟朗读内容');
      return;
    }
    if (_effectiveWeekdays().isEmpty) {
      _toast('请至少选择一个重复日期，否则闹钟没有可触发的日期');
      return;
    }
    setState(() => _saving = true);
    try {
      final hasPermission = await _native.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      if (!hasPermission) {
        await _native.invokeMethod<bool>('requestExactAlarmPermission');
        _toast('将继续保存语音闹钟；授权“闹钟和提醒”可增强后台/熄屏准点触发能力');
      }
      final canFullScreen = await _native.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
      if (!canFullScreen) {
        await _native.invokeMethod<bool>('requestFullScreenIntentPermission');
        _toast('请允许“全屏通知/全屏提醒”，否则锁屏时可能只能显示通知横幅，无法自动弹出全屏闹钟');
      }
      // 不再在保存闹钟时主动弹出系统电量/省电策略页面。
      // 这个页面在很多 ROM 上会打断用户保存流程，且容易被误解为 App 强制跳转。
      // 闹钟仍会保存；如用户遇到被后台清理导致不响，可在说明/诊断入口中手动打开电池无限制、自启动、锁屏显示等设置。
      try {
        final ignoreBattery = await _native.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
        if (!ignoreBattery) {
          _toast('已保存闹钟。若之后发现清理后台后不响，可手动把本应用设为电池“无限制/允许后台运行”。');
        }
      } catch (_) {
        // 省电状态检查失败不影响闹钟保存。
      }
      final channelImportant = await _native.invokeMethod<bool>('isAlarmNotificationChannelImportant') ?? true;
      if (!channelImportant) {
        await _native.invokeMethod<bool>('openAlarmNotificationChannelSettings');
        _toast('请把“语音闹钟响铃”通知类别设为高优先级/允许弹出，否则锁屏全屏闹钟可能被系统静默处理');
      }
      if (!await _ensureVoiceInteractionReady()) return;
      await _refreshAlarmAiConfig();
      try {
        _generatedVoice = _selectedSavedVoicePath ?? await _generateVoiceFile();
        if (_selectedSavedVoicePath == null && _generatedVoice != null) await _rememberGeneratedVoice(_generatedVoice!);
      } catch (e) {
        // Voice file generation depends on third-party TTS credentials/network.
        // Do not let that prevent the native alarm from being registered; the
        // ringing service can read the alarm text with platform TTS as fallback.
        _generatedVoice = null;
        _toast('语音文件生成失败，将使用系统语音兜底播报并继续保存闹钟：$e');
      }
      final text = _text.text.trim();
      final when = _nextTime();
      final alarmId = '$_mode-${_time.hour.toString().padLeft(2, '0')}${_time.minute.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch}';
      await _kv.setString('voice_alarm.time', when.toIso8601String());
      await _kv.setString('voice_alarm.text', _text.text.trim());
      await _kv.setString('voice_alarm.provider', _provider);
      await _kv.setString('voice_alarm.voice_file', _generatedVoice ?? '');
      await _kv.setString('voice_alarm.music_file', _customMusic ?? '');
      await _kv.setString('voice_alarm.vibrate', _vibrate ? '1' : '0');
      await _kv.setString('voice_alarm.system_music', _systemMusic ? '1' : '0');
      final entry = _VoiceAlarmEntry(id: alarmId, time: _time, text: text);
      _alarmEntries = <_VoiceAlarmEntry>[entry, ..._alarmEntries.where((item) => item.id != alarmId)];
      final config = _payloadMap(alarmId: alarmId)
        ..['savedVoicePath'] = _selectedSavedVoicePath ?? ''
        ..['time'] = when.toIso8601String();
      await _kv.setString(_configKey, jsonEncode(config));
      _textHistory = <String>[text, ..._textHistory.where((item) => item != text)].take(20).toList();
      await _kv.setString(_historyKey, jsonEncode(_textHistory));
      final payload = _payload(alarmId: alarmId);
      await _native.invokeMethod<void>('schedule', {
        'atMs': when.millisecondsSinceEpoch,
        'payload': payload,
      });
      _toast('已添加 ${_mode == 'morning' ? '起床' : '睡觉'}闹钟 ${_time.format(context)}；当前模块共 ${_alarmEntries.length} 组');
      setState(() {});
    } catch (e) {
      _toast('设置失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _generateVoiceFile() async {
    final text = _text.text.trim();
    if (_provider == 'microsoft') {
      return _tts.synthesizeMicrosoftToFile(
        text: text,
        voice: _voiceId.text.trim().isEmpty ? null : _voiceId.text.trim(),
        rate: _speed,
        pitch: _pitch,
        pauseSeconds: _pauseSeconds,
        style: _emotion == 'none' ? '' : _emotion,
      );
    }
    if (_provider == 'resemble') {
      final voiceUuid = _voiceId.text.trim().isNotEmpty
          ? _voiceId.text.trim()
          : (await _kv.getString(VoiceProviderSettings.resembleVoiceUuid) ?? '').trim();
      if (voiceUuid.isEmpty) throw StateError('请先在“语音与美好的祝福配置”中选择 Resemble voice_uuid');
      final allowed = await _tts.listResembleVoices();
      if (!allowed.any((voice) => voice.id == voiceUuid)) {
        throw StateError('当前 Resemble Token 无权使用 voice_uuid=$voiceUuid。请回到语音配置页查询声音，并选择当前 Token 返回的声音。');
      }
      final audio = await _tts.synthesizeResembleAndSave(
        text: text,
        voiceUuid: voiceUuid,
        voiceDisplayName: await _kv.getString(VoiceProviderSettings.resembleVoiceName) ?? 'Resemble AI',
        moduleName: 'voice_alarm_resemble',
        speed: _speed,
        scene: _scene,
        meditationAutoPauses: _pauseSeconds > 0,
        meditationSentenceBreakSec: _pauseSeconds,
        meditationParagraphBreakSec: (_pauseSeconds * 1.6).clamp(0.2, 5.0).toDouble(),
        meditationTone: _emotion,
        useHd: _resembleHd,
      );
      return audio.audioFilePath;
    }
    if (_provider == 'iflytek') {
      return _tts.synthesizeIflytekToFile(
        text: text,
        voiceName: _voiceId.text.trim().isEmpty ? null : _voiceId.text.trim(),
        speed: _speed,
        pitch: _pitch,
        volume: _voiceVolume,
      );
    }
    if (_provider == 'minimax') {
      final voiceId = _voiceId.text.trim().isNotEmpty
          ? _voiceId.text.trim()
          : (await _kv.getString(VoiceProviderSettings.minimaxVoiceId) ?? VoiceProviderSettings.defaultMiniMaxVoiceId).trim();
      final audio = await _tts.synthesizeMiniMaxAndSave(
        text: text,
        voiceId: voiceId,
        voiceDisplayName: await _kv.getString(VoiceProviderSettings.minimaxVoiceName) ?? VoiceProviderSettings.defaultMiniMaxVoiceName,
        moduleName: 'voice_alarm_minimax',
        speed: _speed,
        emotion: _emotion,
        pitch: _pitch.round(),
        scene: _scene,
        meditationAutoPauses: _pauseSeconds > 0,
        meditationSentenceBreakSec: _pauseSeconds,
      );
      return audio.audioFilePath;
    }
    final voiceId = _voiceId.text.trim().isNotEmpty
        ? _voiceId.text.trim()
        : (await _kv.getString(ElevenLabsSettings.presetVoiceId) ?? ElevenLabsSettings.defaultPresetVoiceId).trim();
    final audio = await _elevenLabs.synthesizeAndSaveByVoiceId(
      text: text,
      voiceId: voiceId,
      voiceSource: 'premade',
      voiceDisplayName: await _kv.getString(ElevenLabsSettings.presetVoiceName) ?? ElevenLabsSettings.defaultPresetVoiceName,
      moduleName: 'voice_alarm_elevenlabs',
      speed: _speed,
      stability: _stability,
      style: _styleStrength,
      scene: _scene,
      pauseMode: _pauseSeconds > 0 ? 'punctuation' : 'none',
    );
    return audio.audioFilePath;
  }

  Future<void> _rememberGeneratedVoice(String path) async {
    final raw = await _kv.getString('voice_alarm.generated_audio');
    final current = raw == null || raw.isEmpty
        ? <Map<String, String>>[]
        : (jsonDecode(raw) as List).whereType<Map>().map((e) => Map<String, String>.from(e)).toList();
    final next = <Map<String, String>>[
      {
        'path': path,
        'label': '${_mode == 'morning' ? '早安' : '晚安'} · $_provider · ${_text.text.trim()}',
      },
      ...current.where((item) => item['path'] != path),
    ].take(40).toList();
    await _kv.setString('voice_alarm.generated_audio', jsonEncode(next));
  }

  Future<void> _ring() async {
    setState(() => _saving = true);
    try {
      if (!await _ensureVoiceInteractionReady()) return;
      await _refreshAlarmAiConfig();
      try {
        _generatedVoice = _selectedSavedVoicePath ?? await _generateVoiceFile();
        if (_selectedSavedVoicePath == null && _generatedVoice != null) await _rememberGeneratedVoice(_generatedVoice!);
      } catch (e) {
        // Voice file generation depends on third-party TTS credentials/network.
        // Do not let that prevent the native alarm from being registered; the
        // ringing service can read the alarm text with platform TTS as fallback.
        _generatedVoice = null;
        _toast('语音文件生成失败，将使用系统语音兜底播报并继续保存闹钟：$e');
      }
      await _native.invokeMethod<void>('testRing', {'payload': _payload()});
    } catch (e) {
      _toast('测试失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _payload({String? alarmId}) {
    return jsonEncode(_payloadMap(alarmId: alarmId));
  }

  Map<String, dynamic> _payloadMap({String? alarmId}) {
    return {
      'text': _text.text.trim(),
      'provider': _provider,
      'sttProvider': _sttProvider,
      'sttMode': _sttMode,
      'batchStt': _batchSttMap(),
      'voicePath': _generatedVoice ?? '',
      'alarmId': alarmId ?? '',
      'musicPath': (_customMusics.isEmpty ? null : _customMusics.first) ?? _customMusic ?? '',
      'musicPaths': _customMusics,
      'backgroundPath': (_backgroundImages.isEmpty ? null : _backgroundImages.first) ?? _backgroundImage ?? '',
      'backgroundPaths': _backgroundImages,
      'alarms': _alarmEntries.map((alarm) => alarm.toJson()).toList(),
      'vibrate': _vibrate,
      'systemMusic': _systemMusic,
      'hour': _time.hour,
      'minute': _time.minute,
      'speed': _speed,
      'pauseSeconds': _pauseSeconds,
      'scene': _scene,
      'emotion': _emotion,
      'voiceId': _voiceId.text.trim(),
      'mode': _mode,
      'frequency': _frequency,
      'weekdays': _effectiveWeekdays().toList()..sort(),
      'voiceVolume': _voiceVolume,
      'musicVolume': _musicVolume,
      'stability': _stability,
      'styleStrength': _styleStrength,
      'pitch': _pitch,
      'resembleHd': _resembleHd,
      'replayIntervalSeconds': _replayIntervalSeconds,
      'aiConfig': _alarmAiConfig,
      'aiSystemPrompt': _alarmAiSystemPrompt,
      'sttConfig': _alarmSttConfig,
      'voiceEndpointing': _voiceEndpointingMap(),
    };
  }

  Set<int> _effectiveWeekdays() {
    if (_frequency == 'weekdays') return {1, 2, 3, 4, 5};
    if (_frequency == 'daily') return {1, 2, 3, 4, 5, 6, 7};
    return _weekdays;
  }

  Future<void> _generateAiText() async {
    setState(() => _saving = true);
    try {
      final template = await _aiSettings.getVoiceAlarmContentPrompt();
      final prompt = template.replaceAll('{{mode}}', _mode == 'morning' ? '早上起床' : '晚上睡觉');
      final result = await _ai.generateText(prompt: prompt, purpose: 'voice_alarm.content', maxTokens: 300, temperature: 0.8);
      if (result.trim().isEmpty) throw StateError('AI 未返回内容，请检查全局 AI 配置');
      setState(() => _text.text = result.trim());
    } catch (e) {
      _toast('AI 生成失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final next = _nextTime();
    return Scaffold(
      appBar: AppBar(title: const Text('语音闹钟')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'morning', icon: Icon(Icons.wb_sunny_outlined), label: Text('早上起床')),
              ButtonSegment(value: 'night', icon: Icon(Icons.bedtime_outlined), label: Text('晚上睡觉')),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => _loadMode(value.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('提醒时间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm),
                  title: Text(_time.format(context), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                  subtitle: Text('下一次：${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await showTimePicker(context: context, initialTime: _time);
                    if (value != null) setState(() => _time = value);
                  },
                ),
              ]),
            ),
          ),
          if (_alarmEntries.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_mode == 'morning' ? '起床' : '睡觉'}闹钟列表（${_alarmEntries.length} 组）', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._alarmEntries.map((alarm) {
                    final nextAt = _nextTimeFor(alarm.time);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm_on_outlined),
                      title: Text(alarm.time.format(context)),
                      subtitle: Text('${nextAt.month.toString().padLeft(2, '0')}-${nextAt.day.toString().padLeft(2, '0')} 下一次响铃 · ${alarm.text.isEmpty ? '使用当前朗读内容' : alarm.text}'),
                      trailing: IconButton(
                        tooltip: '删除这组闹钟',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _saving ? null : () => _removeAlarmEntry(alarm),
                      ),
                      onTap: () => setState(() {
                        _time = alarm.time;
                        if (alarm.text.isNotEmpty) _text.text = alarm.text;
                      }),
                    );
                  }),
                ]),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('语音内容与服务商', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _text, maxLines: 4, decoration: const InputDecoration(labelText: '到点朗读内容', border: OutlineInputBorder())),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(onPressed: () => setState(() => _text.text = _mode == 'morning' ? _morningDefault : _nightDefault), child: const Text('使用默认内容')),
                    TextButton.icon(onPressed: _saving ? null : _generateAiText, icon: const Icon(Icons.auto_awesome), label: const Text('AI 生成')),
                    if (_textHistory.isNotEmpty)
                      PopupMenuButton<String>(
                        onSelected: (value) => setState(() => _text.text = value),
                        itemBuilder: (_) => _textHistory.map((item) => PopupMenuItem(value: item, child: Text(item, maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
                        child: const Padding(padding: EdgeInsets.all(8), child: Text('历史内容')),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _provider,
                  decoration: const InputDecoration(labelText: '文字转语音服务商', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'microsoft', child: Text('Microsoft Azure Speech（默认）')),
                    DropdownMenuItem(value: 'elevenlabs', child: Text('ElevenLabs')),
                    DropdownMenuItem(value: 'resemble', child: Text('Resemble AI')),
                    DropdownMenuItem(value: 'minimax', child: Text('MiniMax')),
                    DropdownMenuItem(value: 'iflytek', child: Text('讯飞语音')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _provider = value ?? 'microsoft';
                      final recommendations = _recommendedVoices(_provider, _mode);
                      _voiceId.text = recommendations.isEmpty ? '' : recommendations.first['id'] ?? '';
                      _selectedSavedVoicePath = null;
                    });
                    _refreshProviderRecommendations();
                  },
                ),
                const SizedBox(height: 8),
                const Text('服务商参数复用“设置 → 语音与美好的祝福配置”。支持 Microsoft、ElevenLabs、Resemble、MiniMax 与讯飞语音预生成闹钟语音。', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'microsoft', label: Text('微软识别'), icon: Icon(Icons.cloud_outlined)),
                    ButtonSegment(value: 'iflytek', label: Text('讯飞识别'), icon: Icon(Icons.record_voice_over_outlined)),
                    ButtonSegment(value: 'xai', label: Text('xAI 识别'), icon: Icon(Icons.auto_awesome_outlined)),
                  ],
                  selected: {_sttProvider},
                  onSelectionChanged: (value) => setState(() => _sttProvider = value.first),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'realtime', label: Text('实时识别'), icon: Icon(Icons.graphic_eq_outlined)),
                    ButtonSegment(value: 'batch', label: Text('非实时录音识别'), icon: Icon(Icons.upload_file_outlined)),
                  ],
                  selected: {_sttMode},
                  onSelectionChanged: (value) => setState(() => _sttMode = value.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _sttMode == 'batch'
                      ? '非实时模式采用自动待命的聊天输入框逻辑：无需手动开启录音，空闲时自动监听；确认你开始说话后才保存本轮 utterance，说完静音或手动发送后只上传这一条完整录音。'
                      : '实时模式会持续收音并边识别边显示候选文本；xAI 使用 WebSocket 流式 STT，讯飞支持动态修正，微软使用短句连续识别。',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  _sttProvider == 'iflytek'
                      ? '讯飞实时模式支持动态修正；非实时模式会录完整段后走 IAT 引擎，并使用 eos 后端点参数避免服务端在自然停顿处提前结束。'
                      : _sttProvider == 'xai'
                          ? 'xAI 支持 REST 文件转写和 WebSocket 实时转写；API Key 复用全局 xGrok/xAI 配置。非实时请求会自动忽略 xAI 不支持的 language 格式化参数，中文优先建议对比测试讯飞/微软。'
                          : 'Microsoft 实时模式按短句连续识别；非实时模式会把完整录音一次提交给 Azure Speech detailed 识别，优先使用 NBest 最佳结果。',
                  style: const TextStyle(color: Colors.deepOrange, fontSize: 12.5),
                ),
                if (_sttMode == 'batch') ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.amber.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: const [Icon(Icons.mic_external_on_outlined), SizedBox(width: 8), Text('非实时录音提交策略', style: TextStyle(fontWeight: FontWeight.bold))]),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('无人声自动提交录音'),
                          subtitle: Text('检测到用户停止说话 ${(_batchAutoSubmitSilenceMs / 1000).toStringAsFixed(1)} 秒后自动提交'),
                          value: _batchAutoSubmit,
                          onChanged: (value) => setState(() => _batchAutoSubmit = value),
                        ),
                        Text('自动提交静音时长 ${(_batchAutoSubmitSilenceMs / 1000).toStringAsFixed(1)} 秒'),
                        Slider(value: _batchAutoSubmitSilenceMs, min: 1000, max: 15000, divisions: 28, onChanged: (value) => setState(() => _batchAutoSubmitSilenceMs = value)),
                        Text('兜底最长录音 ${(_batchMaxRecordMs / 1000).round()} 秒'),
                        Slider(value: _batchMaxRecordMs, min: 10000, max: 180000, divisions: 34, onChanged: (value) => setState(() => _batchMaxRecordMs = value)),
                        const Text('严格单轮：不再滚动转写、不再后台排队、不再多段合并。用户说话前只保留很短预录音，确认开口后才建立本轮音频；说完静音后自动提交。', style: TextStyle(color: Colors.black54)),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('返回最佳结果并自动纠错'),
                          subtitle: const Text('优先使用服务商 best/NBest/final 结果；如果已配置全局 AI，会对非实时转写做错别字、同音字和标点纠正。'),
                          value: _batchAutoCorrect,
                          onChanged: (value) => setState(() => _batchAutoCorrect = value),
                        ),
                        const Text('全屏闹钟页会显示“等待说话 / 已检测到声音 / 静音倒计时 / 识别中 / 识别完成 / 可重试”等状态；语音转文字结果保留在主文本区，不会被录音状态覆盖。', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 6),
                        const Text('借鉴点：更接近按住说话/语音输入框的语义，但无需手动开始。VAD 只负责自动发现开口与结束；开口前长空白不进入上传音频，播报期间不录入 STT，服务端返回最终文字后才进入 AI。', style: TextStyle(color: Colors.black45, fontSize: 12.5)),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  color: Colors.blueGrey.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: const [Icon(Icons.hearing_outlined), SizedBox(width: 8), Text('实时语音句段提交策略', style: TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _speechPreset,
                        decoration: const InputDecoration(labelText: '体验预设', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'fast', child: Text('极速自动提交：短指令')),
                          DropdownMenuItem(value: 'balanced', child: Text('自然自动提交：默认推荐')),
                          DropdownMenuItem(value: 'complete', child: Text('长句自动提交：连续表达')),
                          DropdownMenuItem(value: 'long', child: Text('慢语速自动提交：停顿较多')),
                        ],
                        onChanged: (value) => _applySpeechPreset(value ?? 'balanced'),
                      ),
                      const Text('实时模式的自动提交不再依赖“语义完整度猜测”；系统只看听写文本是否停止变化、麦克风是否进入稳定静音。', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 8),
                      Text('自动提交静音 ${(_speechCompleteSilenceMs / 1000).toStringAsFixed(1)} 秒'),
                      Slider(value: _speechCompleteSilenceMs, min: 700, max: 6000, divisions: 53, onChanged: (value) => setState(() {
                        _speechCompleteSilenceMs = value;
                        if (_speechPossiblyCompleteSilenceMs >= _speechCompleteSilenceMs) {
                          _speechPossiblyCompleteSilenceMs = (_speechCompleteSilenceMs - 100).clamp(500, 5000).toDouble();
                        }
                      })),
                      Text('候选静音阈值 ${(_speechPossiblyCompleteSilenceMs / 1000).toStringAsFixed(1)} 秒'),
                      Slider(value: _speechPossiblyCompleteSilenceMs.clamp(500, (_speechCompleteSilenceMs - 100).clamp(500, 5000)).toDouble(), min: 500, max: (_speechCompleteSilenceMs - 100).clamp(500, 5000).toDouble(), divisions: 45, onChanged: (value) => setState(() => _speechPossiblyCompleteSilenceMs = value)),
                      Text('AI 提交等待 ${(_speechFinalCommitDelayMs / 1000).toStringAsFixed(1)} 秒'),
                      Slider(value: _speechFinalCommitDelayMs, min: 800, max: 8000, divisions: 72, onChanged: (value) => setState(() {
                        _speechFinalCommitDelayMs = value;
                        if (_speechPartialFallbackDelayMs < _speechFinalCommitDelayMs) _speechPartialFallbackDelayMs = _speechFinalCommitDelayMs;
                      })),
                      Text('文本稳定等待 ${(_speechStableTextMs / 1000).toStringAsFixed(1)} 秒'),
                      Slider(value: _speechStableTextMs, min: 300, max: 3000, divisions: 27, onChanged: (value) => setState(() => _speechStableTextMs = value)),
                      Text('Partial 兜底等待 ${(_speechPartialFallbackDelayMs / 1000).toStringAsFixed(1)} 秒'),
                      Slider(value: _speechPartialFallbackDelayMs.clamp(_speechFinalCommitDelayMs, 10000).toDouble(), min: _speechFinalCommitDelayMs, max: 10000, divisions: 80, onChanged: (value) => setState(() => _speechPartialFallbackDelayMs = value)),
                      Text('最短说话时长 ${(_speechMinUtteranceMs / 1000).toStringAsFixed(1)} 秒'),
                      Slider(value: _speechMinUtteranceMs, min: 500, max: 6000, divisions: 55, onChanged: (value) => setState(() => _speechMinUtteranceMs = value)),
                      Text('单段最长等待 ${(_speechMaxUtteranceMs / 1000).round()} 秒'),
                      Slider(value: _speechMaxUtteranceMs, min: 8000, max: 60000, divisions: 52, onChanged: (value) => setState(() => _speechMaxUtteranceMs = value)),
                      const Text('极短噪声过滤：1～2 个无意义语气词会被忽略，正常短句不会被字数拦截。', style: TextStyle(color: Colors.black54)),
                      const Text('调大“自动提交静音 / 文本稳定等待 / AI提交等待”可减少碎片提交；调小则响应更快。实时模式会自动提交，不要求用户点击确认。', style: TextStyle(color: Colors.black54)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _voiceId,
                  decoration: const InputDecoration(
                    labelText: '闹钟专用声音 ID（可留空）',
                    helperText: 'Microsoft 可填写 Neural Voice；其他服务商留空时使用美好祝福模块当前声音',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _recommendedVoices(_provider, _mode).any((v) => v['id'] == _voiceId.text) ? _voiceId.text : null,
                  decoration: InputDecoration(labelText: '${_mode == 'morning' ? '早安' : '晚安'}推荐中文声音（2个）', border: const OutlineInputBorder()),
                  items: _recommendedVoices(_provider, _mode)
                      .where((v) => (v['id'] ?? '').isNotEmpty)
                      .map((v) => DropdownMenuItem(value: v['id'], child: Text(v['name'] ?? v['id']!)))
                      .toList(),
                  onChanged: (value) => setState(() => _voiceId.text = value ?? ''),
                ),
                if (_savedVoices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                  value: _savedVoices.any((a) => a['path'] == _selectedSavedVoicePath) ? _selectedSavedVoicePath : '',
                    decoration: const InputDecoration(labelText: '复用本地已生成语音', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('不复用，按当前配置重新生成')),
                      ..._savedVoices.take(30).map((a) => DropdownMenuItem(value: a['path'], child: Text(a['label'] ?? a['path'] ?? '', overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (value) => setState(() => _selectedSavedVoicePath = (value ?? '').isEmpty ? null : value),
                  ),
                ],
                const SizedBox(height: 12),
                Text('语速 ${_speed.toStringAsFixed(2)}×'),
                Slider(value: _speed, min: 0.5, max: 1.5, divisions: 20, onChanged: (value) => setState(() => _speed = value)),
                Text('句末停顿 ${_pauseSeconds.toStringAsFixed(1)} 秒'),
                Slider(value: _pauseSeconds, min: 0, max: 3, divisions: 30, onChanged: (value) => setState(() => _pauseSeconds = value)),
                DropdownButtonFormField<String>(
                  value: _scene,
                  decoration: const InputDecoration(labelText: '场景匹配', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'natural_dialogue', child: Text('自然对话')),
                    DropdownMenuItem(value: 'morning_blessing', child: Text('清晨祝福')),
                    DropdownMenuItem(value: 'meditation_relax', child: Text('冥想放松')),
                    DropdownMenuItem(value: 'energetic', child: Text('活力唤醒')),
                  ],
                  onChanged: (value) => setState(() => _scene = value ?? 'natural_dialogue'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _emotion,
                  decoration: const InputDecoration(labelText: '情绪 / 风格', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('默认')),
                    DropdownMenuItem(value: 'calm', child: Text('平静 calm')),
                    DropdownMenuItem(value: 'cheerful', child: Text('愉快 cheerful')),
                    DropdownMenuItem(value: 'gentle', child: Text('温柔 gentle')),
                    DropdownMenuItem(value: 'excited', child: Text('振奋 excited')),
                  ],
                  onChanged: (value) => setState(() => _emotion = value ?? 'calm'),
                ),
                const SizedBox(height: 8),
                if (_provider == 'microsoft') ...[
                  Text('Microsoft 音调 ${_pitch.round()}%'),
                  Slider(value: _pitch, min: -20, max: 20, divisions: 40, onChanged: (value) => setState(() => _pitch = value)),
                  const Text('Azure 使用 Neural Voice、SSML 语速/音调/停顿与支持的 speaking style；不支持的 style 会自动回退普通语气。', style: TextStyle(color: Colors.black54)),
                ] else if (_provider == 'elevenlabs') ...[
                  Text('ElevenLabs 稳定度 ${_stability.toStringAsFixed(2)}'),
                  Slider(value: _stability, min: 0, max: 1, divisions: 20, onChanged: (value) => setState(() => _stability = value)),
                  Text('风格强度 ${_styleStrength.toStringAsFixed(2)}'),
                  Slider(value: _styleStrength, min: 0, max: 1, divisions: 20, onChanged: (value) => setState(() => _styleStrength = value)),
                ] else if (_provider == 'resemble') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Resemble HD 合成'),
                    subtitle: const Text('同时使用当前 Token 授权 voice_uuid、SSML 停顿、语速和冥想语气参数'),
                    value: _resembleHd,
                    onChanged: (value) => setState(() => _resembleHd = value),
                  ),
                ] else if (_provider == 'minimax') ...[
                  Text('MiniMax 音调 ${_pitch.round()}'),
                  Slider(value: _pitch, min: -12, max: 12, divisions: 24, onChanged: (value) => setState(() => _pitch = value)),
                  const Text('MiniMax 使用 speed、pitch、emotion、中文 voice_id 与场景停顿参数。', style: TextStyle(color: Colors.black54)),
                ] else ...[
                  Text('讯飞音调 ${_pitch.round()}'),
                  Slider(value: _pitch, min: -20, max: 20, divisions: 40, onChanged: (value) => setState(() => _pitch = value)),
                  const Text('讯飞语音使用美好祝福配置页中的 AppID / APIKey / APISecret / Endpoint，并支持闹钟专用发音人 vcn。', style: TextStyle(color: Colors.black54)),
                ],
              ]),
            ),
          ),
          Card(
            child: Column(children: [
              ListTile(
                title: const Text('重复频率'),
                subtitle: DropdownButton<String>(
                  value: _frequency,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('每天')),
                    DropdownMenuItem(value: 'weekdays', child: Text('工作日（周一至周五）')),
                    DropdownMenuItem(value: 'custom', child: Text('自定义星期')),
                  ],
                  onChanged: (value) => setState(() => _frequency = value ?? 'daily'),
                ),
              ),
              if (_frequency == 'custom')
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return FilterChip(
                      label: Text('周${const ['一', '二', '三', '四', '五', '六', '日'][index]}'),
                      selected: _weekdays.contains(day),
                      onSelected: (selected) => setState(() => selected ? _weekdays.add(day) : _weekdays.remove(day)),
                    );
                  }),
                ),
              SwitchListTile(title: const Text('震动'), subtitle: const Text('同时启用系统通知震动'), value: _vibrate, onChanged: (value) => setState(() => _vibrate = value)),
              SwitchListTile(title: const Text('系统闹钟音乐'), subtitle: const Text('未选择自定义音乐时使用系统提醒通道'), value: _systemMusic, onChanged: (value) => setState(() => _systemMusic = value)),
              ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: const Text('背景音乐（多选，响铃时随机播放）'),
                subtitle: Text(_customMusics.isEmpty ? '未选择' : '已选择 ${_customMusics.length} 首：${_customMusics.first.split('/').last}'),
                trailing: const Icon(Icons.add),
                onTap: _pickMusic,
              ),
              if (_customMusics.isNotEmpty)
                ..._customMusics.map((path) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      title: Text(path.split('/').last, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: '删除背景音乐',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          setState(() {
                            _customMusics = _customMusics.where((item) => item != path).toList();
                            _customMusic = (_customMusics.isEmpty ? null : _customMusics.first);
                          });
                          await _persistDraftConfig();
                        },
                      ),
                    )),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('全屏闹钟背景图片（多选，响铃时随机轮播）'),
                subtitle: Text(_backgroundImages.isEmpty ? '未选择，使用默认渐变背景' : '已选择 ${_backgroundImages.length} 张：${_backgroundImages.first.split('/').last}'),
                trailing: const Icon(Icons.add),
                onTap: _pickBackground,
              ),
              if (_backgroundImages.isNotEmpty)
                ..._backgroundImages.map((path) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      title: Text(path.split('/').last, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: '删除背景图片',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          setState(() {
                            _backgroundImages = _backgroundImages.where((item) => item != path).toList();
                            _backgroundImage = (_backgroundImages.isEmpty ? null : _backgroundImages.first);
                          });
                          await _persistDraftConfig();
                        },
                      ),
                    )),
              ListTile(
                title: Text('闹钟语音重播间隔 $_replayIntervalSeconds 秒'),
                subtitle: Slider(value: _replayIntervalSeconds.toDouble(), min: 15, max: 300, divisions: 19, onChanged: (value) => setState(() => _replayIntervalSeconds = value.round())),
              ),
              ListTile(
                title: Text('语音音量 ${(_voiceVolume * 100).round()}%'),
                subtitle: Slider(value: _voiceVolume, min: 0, max: 1, divisions: 20, onChanged: (value) => setState(() => _voiceVolume = value)),
              ),
              ListTile(
                title: Text('背景音乐音量 ${(_musicVolume * 100).round()}%'),
                subtitle: Slider(value: _musicVolume, min: 0, max: 1, divisions: 20, onChanged: (value) => setState(() => _musicVolume = value)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _schedule,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.alarm_add),
            label: Text(_saving ? '正在生成语音并设置…' : '添加当前配置为一组闹钟'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _ring, icon: const Icon(Icons.play_arrow), label: const Text('立即测试闹钟与稍后提醒')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _native.invokeMethod<void>('snooze', {'payload': _payload()});
                    await _native.invokeMethod<void>('stopRing');
                    _toast('已通过 Android 系统设置为 5 分钟后再次提醒');
                  },
                  icon: const Icon(Icons.snooze),
                  label: const Text('5分钟后提醒'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _native.invokeMethod<void>('stopRing'),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('停止响铃'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
