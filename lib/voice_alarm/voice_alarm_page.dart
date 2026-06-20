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
  String? _customMusic;
  String? _backgroundImage;
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

  DateTime _nextTime() {
    final now = DateTime.now();
    var value = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (!value.isAfter(now)) value = value.add(const Duration(days: 1));
    final allowed = _effectiveWeekdays();
    var guard = 0;
    while (!allowed.contains(value.weekday) && guard < 8) {
      value = value.add(const Duration(days: 1));
      guard++;
    }
    return value;
  }

  String get _configKey => 'voice_alarm.config.$_mode';
  String get _historyKey => 'voice_alarm.text_history.$_mode';

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
      _sttProvider = (data['sttProvider'] ?? 'microsoft').toString() == 'iflytek' ? 'iflytek' : 'microsoft';
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
      _resembleHd = data['resembleHd'] as bool? ?? true;
      _vibrate = data['vibrate'] as bool? ?? true;
      _systemMusic = data['systemMusic'] as bool? ?? true;
      final savedTime = DateTime.tryParse((data['time'] ?? '').toString());
      if (savedTime != null) _time = TimeOfDay.fromDateTime(savedTime);
      _customMusic = data['musicPath']?.toString().isEmpty == false ? data['musicPath'].toString() : null;
      _backgroundImage = data['backgroundPath']?.toString().isEmpty == false ? data['backgroundPath'].toString() : null;
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
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _customMusic = path);
  }

  Future<void> _pickBackground() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _backgroundImage = path);
  }

  Future<bool> _ensureVoiceInteractionReady() async {
    final mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      final requested = await Permission.microphone.request();
      if (!requested.isGranted) {
        _toast('语音唤醒、AI 对话和语音关闭闹钟需要麦克风权限；请授权后重新保存闹钟');
        return false;
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
    };
  }

  Future<void> _schedule() async {
    if (_text.text.trim().isEmpty) {
      _toast('请输入闹钟朗读内容');
      return;
    }
    setState(() => _saving = true);
    try {
      final hasPermission = await _native.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      if (!hasPermission) {
        // Voice alarms use AlarmManager.setAlarmClock as the primary delivery
        // path, which is allowed for alarm-clock style reminders even when the
        // optional exact-alarm permission is not granted.  Do not abort saving
        // here; otherwise users who skip the system permission page end up with
        // no native alarm registered when the app process is later killed.
        await _native.invokeMethod<void>('requestExactAlarmPermission');
        _toast('将继续保存语音闹钟；授权“闹钟和提醒”可增强兜底精确触发能力');
      }
      if (!await _ensureVoiceInteractionReady()) return;
      await _refreshAlarmAiConfig();
      _generatedVoice = _selectedSavedVoicePath ?? await _generateVoiceFile();
      if (_selectedSavedVoicePath == null) await _rememberGeneratedVoice(_generatedVoice!);
      final when = _nextTime();
      await _kv.setString('voice_alarm.time', when.toIso8601String());
      await _kv.setString('voice_alarm.text', _text.text.trim());
      await _kv.setString('voice_alarm.provider', _provider);
      await _kv.setString('voice_alarm.voice_file', _generatedVoice ?? '');
      await _kv.setString('voice_alarm.music_file', _customMusic ?? '');
      await _kv.setString('voice_alarm.vibrate', _vibrate ? '1' : '0');
      await _kv.setString('voice_alarm.system_music', _systemMusic ? '1' : '0');
      final config = _payloadMap()
        ..['savedVoicePath'] = _selectedSavedVoicePath ?? ''
        ..['time'] = when.toIso8601String();
      await _kv.setString(_configKey, jsonEncode(config));
      final text = _text.text.trim();
      _textHistory = <String>[text, ..._textHistory.where((item) => item != text)].take(20).toList();
      await _kv.setString(_historyKey, jsonEncode(_textHistory));
      final payload = _payload();
      await _native.invokeMethod<void>('schedule', {
        'atMs': when.millisecondsSinceEpoch,
        'payload': payload,
      });
      _toast('已注册 Android 系统精确闹钟；App 在后台或进程被清理后仍可响铃');
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
      _generatedVoice = _selectedSavedVoicePath ?? await _generateVoiceFile();
      if (_selectedSavedVoicePath == null) await _rememberGeneratedVoice(_generatedVoice!);
      await _native.invokeMethod<void>('testRing', {'payload': _payload()});
    } catch (e) {
      _toast('测试失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _payload() {
    return jsonEncode(_payloadMap());
  }

  Map<String, dynamic> _payloadMap() {
    return {
      'text': _text.text.trim(),
      'provider': _provider,
      'sttProvider': _sttProvider,
      'voicePath': _generatedVoice ?? '',
      'musicPath': _customMusic ?? '',
      'backgroundPath': _backgroundImage ?? '',
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
                  ],
                  selected: {_sttProvider},
                  onSelectionChanged: (value) => setState(() => _sttProvider = value.first),
                ),
                const SizedBox(height: 8),
                const Text('实时语音转文字服务选择会随闹钟保存；请先在“语音与美好的祝福配置”中填好对应 Microsoft 或讯飞 STT 参数。全屏页会把该选择与对应参数一同带入闹钟 payload，用于实时转文字与 AI 对话链路。', style: TextStyle(color: Colors.black54)),
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
                title: const Text('自定义音乐'),
                subtitle: Text(_customMusic == null ? '未选择' : _customMusic!.split('/').last),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickMusic,
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('全屏闹钟背景图片'),
                subtitle: Text(_backgroundImage == null ? '未选择，使用默认渐变背景' : _backgroundImage!.split('/').last),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickBackground,
              ),
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
            label: Text(_saving ? '正在生成语音并设置…' : '保存并启用语音闹钟'),
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
