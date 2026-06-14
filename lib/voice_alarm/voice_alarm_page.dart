import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/kv_dao.dart';
import '../voice_lab/eleven_labs_service.dart';
import '../voice_lab/multi_provider_tts_service.dart';

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
  static const _native = MethodChannel('com.example.quote_app/voice_alarm');
  TimeOfDay _time = TimeOfDay.now();
  String _provider = 'microsoft';
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
    return value;
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

  Future<void> _schedule() async {
    if (_text.text.trim().isEmpty) {
      _toast('请输入闹钟朗读内容');
      return;
    }
    setState(() => _saving = true);
    try {
      final hasPermission = await _native.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      if (!hasPermission) {
        await _native.invokeMethod<void>('requestExactAlarmPermission');
        _toast('请在系统页面允许“闹钟和提醒”，返回后再次点击保存');
        return;
      }
      _generatedVoice = await _generateVoiceFile();
      final when = _nextTime();
      await _kv.setString('voice_alarm.time', when.toIso8601String());
      await _kv.setString('voice_alarm.text', _text.text.trim());
      await _kv.setString('voice_alarm.provider', _provider);
      await _kv.setString('voice_alarm.voice_file', _generatedVoice ?? '');
      await _kv.setString('voice_alarm.music_file', _customMusic ?? '');
      await _kv.setString('voice_alarm.vibrate', _vibrate ? '1' : '0');
      await _kv.setString('voice_alarm.system_music', _systemMusic ? '1' : '0');
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
      );
      return audio.audioFilePath;
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
      scene: _scene,
      pauseMode: _pauseSeconds > 0 ? 'punctuation' : 'none',
    );
    return audio.audioFilePath;
  }

  Future<void> _ring() async {
    setState(() => _saving = true);
    try {
      _generatedVoice = await _generateVoiceFile();
      await _native.invokeMethod<void>('testRing', {'payload': _payload()});
    } catch (e) {
      _toast('测试失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _payload() {
    return jsonEncode({
      'text': _text.text.trim(),
      'provider': _provider,
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
    });
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final next = _nextTime();
    return Scaffold(
      appBar: AppBar(title: const Text('语音闹钟')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _provider,
                  decoration: const InputDecoration(labelText: '文字转语音服务商', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'microsoft', child: Text('Microsoft Azure Speech（默认）')),
                    DropdownMenuItem(value: 'elevenlabs', child: Text('ElevenLabs')),
                    DropdownMenuItem(value: 'resemble', child: Text('Resemble AI')),
                    DropdownMenuItem(value: 'minimax', child: Text('MiniMax')),
                  ],
                  onChanged: (value) => setState(() => _provider = value ?? 'microsoft'),
                ),
                const SizedBox(height: 8),
                const Text('服务商参数复用“设置 → 语音与美好的祝福配置”。当前版本会为微软服务预先生成闹钟语音。', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                TextField(
                  controller: _voiceId,
                  decoration: const InputDecoration(
                    labelText: '闹钟专用声音 ID（可留空）',
                    helperText: 'Microsoft 可填写 Neural Voice；其他服务商留空时使用美好祝福模块当前声音',
                    border: OutlineInputBorder(),
                  ),
                ),
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
              ]),
            ),
          ),
          Card(
            child: Column(children: [
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
